import argparse
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

import pdfplumber


LESSON_TIMES = {
    1: "08:00-09:40",
    2: "09:50-11:30",
    3: "11:50-13:30",
    4: "13:40-15:20",
    5: "15:40-17:20",
    6: "17:30-19:10",
    7: "19:20-21:00",
}

LESSON_STARTS = {
    1: "08:00",
    2: "09:50",
    3: "11:50",
    4: "13:40",
    5: "15:40",
    6: "17:30",
    7: "19:20",
}

GROUP_PATTERN = re.compile(
    r"^\d+[КKкk]\d{4}$"
)

DATE_PATTERN = re.compile(
    r"на\s+(\d{2}\.\d{2}\.\d{4})",
    re.IGNORECASE,
)

TIME_PATTERN = re.compile(
    r"\b(\d{1,2})[:.](\d{2})\s*[-–—]\s*"
    r"(\d{1,2})[:.](\d{2})\b"
)

SIMPLE_ROOM_PATTERN = re.compile(
    r"^(?:"
    r"\d+[а-яА-Яa-zA-Z]?"
    r"|"
    r"\d+[кКkK]\d+"
    r"|"
    r"[са]/[зЗ]"
    r"|"
    r"[бБ]/[зЗ]"
    r"|"
    r"[чЧ][зЗ]"
    r"|"
    r"[са]/"
    r")$"
)

SUBGROUP_ONLY_PATTERN = re.compile(
    r"^\(?\s*([12])\s*подгрупп[аы]\s*\)?$",
    re.IGNORECASE,
)

PRACTICE_WITH_SUBGROUP_PATTERN = re.compile(
    r"^Практика\s+([12])\s*подгрупп[аы]$",
    re.IGNORECASE,
)

SUBJECT_CONTINUATION_WORDS = {
    "язык",
    "литература",
    "подготовка",
    "деятельность",
    "производства",
    "производство",
    "технологии",
    "технология",
    "средства",
    "системы",
    "система",
    "устройства",
    "устройств",
    "приложений",
    "процессов",
    "процессы",
    "оборудование",
    "защиты",
    "защита",
    "информации",
    "проектами",
    "проектов",
    "электроники",
    "электронной",
    "микроэлектронике",
    "микроэлектроники",
    "материалы",
    "компоненты",
    "схемотехника",
    "моделирование",
    "статистика",
}

SUBJECT_START_MARKERS = [
    "иностранн",
    "белорусск",
    "русск",
    "допризывн",
    "медицинск",
    "информационн",
]


def clean_text(value: Any) -> str:
    if value is None:
        return ""

    text = str(value)

    text = text.replace("\u00ad", "")
    text = text.replace("\ufeff", "")
    text = text.replace("\ufffe", "")
    text = text.replace("￾", "")
    text = text.replace("\r", "\n")

    lines = []

    for line in text.split("\n"):
        cleaned = re.sub(
            r"\s+",
            " ",
            line,
        ).strip()

        if cleaned:
            lines.append(cleaned)

    return "\n".join(lines)


def normalize_group(value: str) -> str:
    value = clean_text(value)

    value = value.replace("K", "К")
    value = value.replace("k", "К")
    value = value.replace("к", "К")

    return value


def is_group(value: str) -> bool:
    return bool(
        GROUP_PATTERN.fullmatch(
            normalize_group(value),
        )
    )


def normalize_time(
    value: str,
) -> str | None:
    match = TIME_PATTERN.search(
        value,
    )

    if match is None:
        return None

    start_hour = int(match.group(1))
    start_minute = int(match.group(2))
    end_hour = int(match.group(3))
    end_minute = int(match.group(4))

    return (
        f"{start_hour:02d}:"
        f"{start_minute:02d}-"
        f"{end_hour:02d}:"
        f"{end_minute:02d}"
    )


def time_to_minutes(
    value: str,
) -> int:
    hour, minute = value.split(":")

    return (
        int(hour) * 60
        + int(minute)
    )


def get_lesson_number_from_time(
    time_value: str | None,
    fallback: int,
) -> int:
    if not time_value:
        return fallback

    start_time = time_value.split("-")[0]

    try:
        start_minutes = time_to_minutes(
            start_time
        )
    except (ValueError, IndexError):
        return fallback

    result = fallback

    for number, standard_time in LESSON_STARTS.items():
        standard_minutes = time_to_minutes(
            standard_time
        )

        if start_minutes >= standard_minutes:
            result = number
        else:
            break

    return result


def extract_date_from_page(
    page,
) -> str | None:
    text = page.extract_text() or ""

    match = DATE_PATTERN.search(
        text
    )

    if match is None:
        return None

    parsed = datetime.strptime(
        match.group(1),
        "%d.%m.%Y",
    )

    return parsed.strftime(
        "%Y-%m-%d"
    )


def unique_values(
    values: list[str],
) -> list[str]:
    result = []

    for value in values:
        value = value.strip()

        if (
            value
            and value not in result
        ):
            result.append(value)

    return result


def is_capitalized_word(
    value: str,
) -> bool:
    value = value.strip(
        ".,;:()[]"
    )

    if not value:
        return False

    if any(
        char.isdigit()
        for char in value
    ):
        return False

    first_letter = None

    for char in value:
        if char.isalpha():
            first_letter = char
            break

    if first_letter is None:
        return False

    return first_letter.isupper()


def normalize_spaced_word(
    line: str,
) -> str:
    """
    Л а г о й к и н а
    ->
    Лагойкина
    """

    words = line.split()

    if len(words) < 4:
        return line

    if not all(
        len(word) == 1
        and word.isalpha()
        for word in words
    ):
        return line

    return "".join(words)


def normalize_broken_subject_text(
    value: str,
) -> str:
    """
    Исправляет очевидные технические
    разрывы внутри названий предметов.
    """

    replacements = [
        (
            r"\bИностранны\s+й\s+язык\b",
            "Иностранный язык",
        ),
        (
            r"\bИностранн\s+ый\s+язык\b",
            "Иностранный язык",
        ),
        (
            r"\bБелорусски\s+й\s+язык\b",
            "Белорусский язык",
        ),
        (
            r"\bБелорусск\s+ий\s+язык\b",
            "Белорусский язык",
        ),
        (
            r"\bРусски\s+й\s+язык\b",
            "Русский язык",
        ),
        (
            r"\bРусск\s+ий\s+язык\b",
            "Русский язык",
        ),
        (
            r"\bмедицинск\s+ая\b",
            "медицинская",
        ),
        (
            r"\bБелорусскийязык\b",
            "Белорусский язык",
        ),
        (
            r"\bРусскийязык\b",
            "Русский язык",
        ),
    ]

    result = value

    for pattern, replacement in replacements:
        result = re.sub(
            pattern,
            replacement,
            result,
            flags=re.IGNORECASE,
        )

    result = re.sub(
        r"\s+",
        " ",
        result,
    ).strip()

    return result


def join_hyphenated_lines(
    lines: list[str],
) -> list[str]:
    """
    Щербакова-
    Шаблова

    ->
    Щербакова-Шаблова

    Также:

    Молчан Щербакова-
    Шаблова

    ->
    Молчан Щербакова-Шаблова
    """

    if not lines:
        return []

    result: list[str] = []
    index = 0

    while index < len(lines):
        current = lines[index].strip()

        if (
            index + 1 < len(lines)
            and current.endswith("-")
        ):
            next_line = (
                lines[index + 1]
                .strip()
            )

            if (
                next_line
                and len(next_line.split()) == 1
                and is_capitalized_word(
                    next_line
                )
            ):
                result.append(
                    current + next_line
                )

                index += 2
                continue

        result.append(current)
        index += 1

    return result


def join_broken_surname_lines(
    lines: list[str],
) -> list[str]:
    """
    Исправляет переносы фамилий:

    Соколовск
    ая
    ->
    Соколовская

    Соколовска
    я Цедрик
    ->
    Соколовская Цедрик

    Служебные слова вроде "ауд"
    продолжением фамилии не считаются.
    """

    if not lines:
        return []

    forbidden_continuations = {
        "ауд",
        "ауд.",
        "язык",
        "подгруппа",
        "подгруппы",
        "корпус",
    }

    result: list[str] = []
    index = 0

    while index < len(lines):
        current = lines[index].strip()

        if index + 1 < len(lines):
            next_line = (
                lines[index + 1]
                .strip()
            )

            current_words = (
                current.split()
            )

            next_words = (
                next_line.split()
            )

            if next_words:
                continuation = (
                    next_words[0]
                    .strip(".,;:()[]")
                    .lower()
                )

                can_join = (
                    len(current_words) == 1
                    and is_capitalized_word(
                        current
                    )
                    and continuation
                    not in forbidden_continuations
                    and re.fullmatch(
                        r"[а-яё]{1,3}",
                        continuation,
                    )
                    is not None
                    and next_words[0].islower()
                )

                if can_join:
                    joined_word = (
                        current
                        + next_words[0]
                    )

                    rest = (
                        next_words[1:]
                    )

                    result.append(
                        " ".join(
                            [
                                joined_word,
                                *rest,
                            ]
                        )
                    )

                    index += 2
                    continue

        result.append(current)
        index += 1

    return result


def normalize_cell_lines(
    lines: list[str],
) -> list[str]:
    normalized = []

    for line in lines:
        line = normalize_spaced_word(
            line.strip()
        )

        if line:
            normalized.append(line)

    normalized = join_hyphenated_lines(
        normalized
    )

    normalized = join_broken_surname_lines(
        normalized
    )

    return normalized


def extract_subgroup(
    text: str,
) -> str | None:
    match = re.search(
        r"([12])\s*подгрупп[аы]",
        text,
        re.IGNORECASE,
    )

    if match is None:
        return None

    return match.group(1)


def remove_subgroup_lines(
    lines: list[str],
) -> list[str]:
    """
    Удаляет отдельные служебные строки:

        1 подгруппа
        (1 подгруппа)
        2 подгруппы

    Значение подгруппы уже было сохранено
    через extract_subgroup().

    Строку вида:
        Практика 1 подгруппа

    не удаляем.
    """

    result: list[str] = []

    for line in lines:
        stripped = line.strip()

        if SUBGROUP_ONLY_PATTERN.fullmatch(
            stripped
        ):
            continue

        result.append(stripped)

    return result


def remove_time_lines(
    lines: list[str],
) -> tuple[
    str | None,
    list[str],
]:
    custom_time = None
    remaining = []

    for line in lines:
        found_time = normalize_time(
            line
        )

        if found_time is None:
            remaining.append(line)
            continue

        custom_time = found_time

        line_without_time = (
            TIME_PATTERN.sub(
                "",
                line,
            ).strip()
        )

        if line_without_time:
            remaining.append(
                line_without_time
            )

    return (
        custom_time,
        remaining,
    )


def looks_like_simple_room(
    value: str,
) -> bool:
    return bool(
        SIMPLE_ROOM_PATTERN.fullmatch(
            value.strip()
        )
    )


def parse_room_line(
    line: str,
) -> list[str] | None:
    """
    Распознаёт строку аудиторий.

    Примеры:

        304
        215 405
        с/з, а/з
        с/з, а/
        2к11 213
        ауд 216
        7 корпус БГУИР ауд 504

    Строки подгрупп сюда не попадают.
    """

    line = line.strip()

    if not line:
        return None

    if SUBGROUP_ONLY_PATTERN.fullmatch(
        line
    ):
        return None

    lowered = line.lower()

    if (
        "корпус" in lowered
        or "бгуир" in lowered
        or "завод" in lowered
    ):
        return [line]

    auditorium_match = re.fullmatch(
        r"ауд\.?\s*(.+)",
        line,
        re.IGNORECASE,
    )

    if auditorium_match:
        room_value = (
            auditorium_match
            .group(1)
            .strip()
        )

        if room_value:
            return [
                f"ауд {room_value}"
            ]

        return None

    parts = [
        part.strip()
        for part in re.split(
            r"[\s,]+",
            line,
        )
        if part.strip()
    ]

    if (
        parts
        and all(
            looks_like_simple_room(
                part
            )
            for part in parts
        )
    ):
        return parts

    return None


def extract_rooms(
    lines: list[str],
) -> tuple[
    list[str],
    list[str],
]:
    if not lines:
        return [], []

    remaining = lines.copy()
    rooms: list[str] = []

    while remaining:
        room_values = parse_room_line(
            remaining[-1]
        )

        if room_values is None:
            break

        rooms = (
            room_values
            + rooms
        )

        remaining.pop()

    return (
        unique_values(rooms),
        remaining,
    )


def is_practice(
    text: str,
) -> bool:
    lowered = text.lower()

    return (
        "практика" in lowered
        or "практики" in lowered
    )


def is_subject_continuation(
    current_subject: str,
    line: str,
) -> bool:
    """
    Определяет случаи, когда следующая
    строка является продолжением предмета.

    Например:

        Белорусский
        язык

    или:

        Допризывная/медицинск
        ая подготовка
    """

    line = line.strip()

    if not line:
        return False

    lowered_line = line.lower()

    if lowered_line in (
        "язык",
        "литература",
    ):
        return True

    words = lowered_line.split()

    first_word = (
        words[0]
        if words
        else ""
    )

    if (
        first_word
        in SUBJECT_CONTINUATION_WORDS
    ):
        return True

    lowered_subject = (
        current_subject.lower()
    )

    if any(
        marker in lowered_subject
        for marker in SUBJECT_START_MARKERS
    ):
        if (
            lowered_line.startswith(
                "язык"
            )
            or lowered_line.startswith(
                "литератур"
            )
            or lowered_line.startswith(
                "подготов"
            )
        ):
            return True

    return False


def split_subject_and_people(
    lines: list[str],
    practice: bool,
) -> tuple[
    str,
    list[str],
]:
    """
    После удаления времени, подгруппы
    и аудиторий разбирает:

        предмет
        преподаватель
        преподаватель

    Первая смысловая строка всегда
    сохраняется как предмет. Благодаря
    этому аббревиатуры ОАиП, СУБД, ТОЭ
    и т. д. не становятся преподавателями.
    """

    if not lines:
        return "", []

    working = [
        line.strip()
        for line in lines
        if line.strip()
    ]

    if not working:
        return "", []

    subject_lines: list[str] = []
    people_lines: list[str] = []

    first_line = working[0]

    if practice:
        if (
            PRACTICE_WITH_SUBGROUP_PATTERN
            .fullmatch(first_line)
            or first_line.lower()
            == "практика"
        ):
            subject_lines.append(
                "Практика"
            )
        else:
            subject_lines.append(
                first_line
            )
    else:
        subject_lines.append(
            first_line
        )

    index = 1

    while index < len(working):
        line = working[index]

        # Дополнительная страховка.
        if SUBGROUP_ONLY_PATTERN.fullmatch(
            line
        ):
            index += 1
            continue

        if (
            practice
            and PRACTICE_WITH_SUBGROUP_PATTERN
            .fullmatch(line)
        ):
            index += 1
            continue

        current_subject = " ".join(
            subject_lines
        )

        if is_subject_continuation(
            current_subject,
            line,
        ):
            subject_lines.append(
                line
            )
        else:
            people_lines.append(
                line
            )

        index += 1

    subject = normalize_broken_subject_text(
        " ".join(subject_lines)
    )

    teachers: list[str] = []

    for line in people_lines:
        normalized = normalize_spaced_word(
            line
        )

        # Строка с цифрами не может быть
        # строкой преподавателей.
        if any(
            char.isdigit()
            for char in normalized
        ):
            continue

        for word in normalized.split():
            cleaned = word.strip(
                ".,;:()[]"
            )

            if (
                cleaned
                and is_capitalized_word(
                    cleaned
                )
            ):
                teachers.append(
                    cleaned
                )

    return (
        subject,
        unique_values(
            teachers
        ),
    )


def parse_lesson_cell(
    cell: str,
    group_id: str,
    lesson_number: int,
    date: str,
    page_number: int,
) -> dict[str, Any] | None:
    # sourceText сохраняем максимально
    # близким к исходному PDF.
    text = clean_text(
        cell
    )

    if not text:
        return None

    lines = [
        line.strip()
        for line in text.split("\n")
        if line.strip()
    ]

    if not lines:
        return None

    # Сохраняем подгруппу до удаления
    # служебной строки.
    subgroup = extract_subgroup(
        text
    )

    practice = is_practice(
        text
    )

    # Исправляем технические переносы PDF.
    lines = normalize_cell_lines(
        lines
    )

    # Извлекаем нестандартное время.
    custom_time, lines = (
        remove_time_lines(
            lines
        )
    )

    # Удаляем отдельные строки вида
    # "1 подгруппа" и "(2 подгруппа)".
    #
    # Значение уже находится в subgroup.
    lines = remove_subgroup_lines(
        lines
    )

    actual_lesson_number = (
        get_lesson_number_from_time(
            custom_time,
            lesson_number,
        )
    )

    # Аудитории находятся в нижней части
    # ячейки и удаляются до разбора предмета.
    rooms, lines = extract_rooms(
        lines
    )

    subject, teachers = (
        split_subject_and_people(
            lines=lines,
            practice=practice,
        )
    )

    # Ячейка могла содержать только время,
    # например 13:10-13:30.
    if (
        not subject
        and not teachers
        and not rooms
    ):
        return None

    if practice:
        subject = "Практика"

    if not subject:
        subject = "Занятие"

    lesson_type = (
        "Практика"
        if practice
        else ""
    )

    return {
        "date": date,
        "groupId": group_id,
        "number": (
            actual_lesson_number
        ),
        "time": (
            custom_time
            or LESSON_TIMES[
                lesson_number
            ]
        ),
        "subject": subject,
        "teachers": teachers,
        "teacherIds": [],
        "rooms": rooms,
        "type": lesson_type,
        "subgroup": subgroup,
        "sourcePage": page_number,
        "sourceText": text,
    }


def looks_like_schedule_table(
    table: list[list[Any]],
) -> bool:
    if not table:
        return False

    for row in table[:3]:
        if not row:
            continue

        row_text = " ".join(
            clean_text(cell)
            for cell in row
            if cell is not None
        ).lower()

        if (
            "№ группы" in row_text
            and "1 пара" in row_text
        ):
            return True

    return False


def parse_table(
    table: list[list[Any]],
    date: str,
    page_number: int,
) -> list[dict[str, Any]]:
    lessons = []

    for row in table:
        if not row:
            continue

        first_cell = clean_text(
            row[0]
            if len(row) > 0
            else ""
        )

        group_id = normalize_group(
            first_cell
        )

        if not is_group(
            group_id
        ):
            continue

        lesson_cells = row[1:8]

        while len(
            lesson_cells
        ) < 7:
            lesson_cells.append(
                None
            )

        for index, cell in enumerate(
            lesson_cells,
            start=1,
        ):
            parsed = parse_lesson_cell(
                cell=clean_text(
                    cell
                ),
                group_id=group_id,
                lesson_number=index,
                date=date,
                page_number=page_number,
            )

            if parsed is not None:
                lessons.append(
                    parsed
                )

    lessons.sort(
        key=lambda lesson: (
            lesson["groupId"],
            lesson["number"],
            lesson["time"],
            lesson["subgroup"]
            or "",
        )
    )

    return lessons


def parse_pdf(
    pdf_path: Path,
) -> dict[str, Any]:
    lessons = []
    detected_date = None
    schedule_pages = []

    table_settings = {
        "vertical_strategy": "lines",
        "horizontal_strategy": "lines",
        "intersection_tolerance": 5,
        "snap_tolerance": 4,
        "join_tolerance": 4,
        "edge_min_length": 10,
    }

    with pdfplumber.open(
        pdf_path,
    ) as pdf:
        for page_index, page in enumerate(
            pdf.pages,
            start=1,
        ):
            # Пока обрабатываем страницы 1–6.
            #
            # 7 страница имеет другую структуру,
            # 8 страница содержит факультативы.
            if page_index > 6:
                continue

            page_date = (
                extract_date_from_page(
                    page
                )
            )

            if (
                detected_date is None
                and page_date is not None
            ):
                detected_date = (
                    page_date
                )

            tables = page.extract_tables(
                table_settings
            )

            page_has_schedule = False

            for table in tables:
                if not looks_like_schedule_table(
                    table
                ):
                    continue

                if detected_date is None:
                    continue

                page_has_schedule = True

                lessons.extend(
                    parse_table(
                        table=table,
                        date=detected_date,
                        page_number=page_index,
                    )
                )

            if page_has_schedule:
                schedule_pages.append(
                    page_index
                )

    if detected_date is None:
        raise ValueError(
            "Не удалось определить дату "
            "расписания из PDF."
        )

    lessons.sort(
        key=lambda lesson: (
            lesson["groupId"],
            lesson["number"],
            lesson["time"],
            lesson["subgroup"]
            or "",
        )
    )

    return {
        "sourceFile": pdf_path.name,
        "date": detected_date,
        "schedulePages": (
            schedule_pages
        ),
        "lessonCount": len(
            lessons
        ),
        "lessons": lessons,
    }


def save_result(
    data: dict[str, Any],
    output_dir: Path,
) -> Path:
    output_dir.mkdir(
        parents=True,
        exist_ok=True,
    )

    source_name = Path(
        data["sourceFile"]
    ).stem

    output_path = (
        output_dir
        / f"{source_name}.json"
    )

    with output_path.open(
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(
            data,
            file,
            ensure_ascii=False,
            indent=2,
        )

    return output_path


def print_summary(
    data: dict[str, Any],
) -> None:
    print()
    print("=" * 60)
    print("РЕЗУЛЬТАТ ПАРСИНГА")
    print("=" * 60)

    print(
        f"Файл: "
        f"{data['sourceFile']}"
    )

    print(
        f"Дата: "
        f"{data['date']}"
    )

    print(
        "Страницы расписания: "
        f"{data['schedulePages']}"
    )

    print(
        "Найдено занятий: "
        f"{data['lessonCount']}"
    )

    groups = sorted(
        {
            lesson["groupId"]
            for lesson
            in data["lessons"]
        }
    )

    print(
        "Найдено групп: "
        f"{len(groups)}"
    )

    practice_count = sum(
        1
        for lesson in data["lessons"]
        if lesson["type"]
        == "Практика"
    )

    print(
        "Найдено практик: "
        f"{practice_count}"
    )

    print()

    if groups:
        print(
            "Первые группы:"
        )

        for group in groups[:10]:
            count = sum(
                1
                for lesson
                in data["lessons"]
                if lesson[
                    "groupId"
                ] == group
            )

            print(
                f"  {group}: "
                f"{count} занятий"
            )

    print("=" * 60)
    print()


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Парсер PDF-расписания МРК"
        )
    )

    parser.add_argument(
        "pdf",
        help="Путь к PDF-файлу",
    )

    parser.add_argument(
        "--output",
        default="parsed",
        help=(
            "Папка для JSON "
            "(по умолчанию parsed)"
        ),
    )

    args = parser.parse_args()

    pdf_path = Path(
        args.pdf
    ).expanduser().resolve()

    if not pdf_path.exists():
        raise FileNotFoundError(
            f"PDF не найден: "
            f"{pdf_path}"
        )

    print(
        f"Читаю: "
        f"{pdf_path.name}"
    )

    data = parse_pdf(
        pdf_path
    )

    output_path = save_result(
        data,
        Path(args.output),
    )

    print_summary(
        data
    )

    print(
        "JSON сохранён:"
    )

    print(
        output_path.resolve()
    )


if __name__ == "__main__":
    main()