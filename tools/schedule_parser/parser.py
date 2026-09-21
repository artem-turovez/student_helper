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

ROOM_PATTERN = re.compile(
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
    r")$"
)


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

    start_hour = int(
        match.group(1)
    )
    start_minute = int(
        match.group(2)
    )
    end_hour = int(
        match.group(3)
    )
    end_minute = int(
        match.group(4)
    )

    return (
        f"{start_hour:02d}:"
        f"{start_minute:02d}-"
        f"{end_hour:02d}:"
        f"{end_minute:02d}"
    )


def extract_date_from_page(
    page,
) -> str | None:
    text = page.extract_text() or ""

    match = DATE_PATTERN.search(
        text,
    )

    if match is None:
        return None

    parsed = datetime.strptime(
        match.group(1),
        "%d.%m.%Y",
    )

    return parsed.strftime(
        "%Y-%m-%d",
    )


def looks_like_room(
    value: str,
) -> bool:
    value = value.strip()

    if not value:
        return False

    return bool(
        ROOM_PATTERN.fullmatch(
            value,
        )
    )


def is_extended_room_line(
    line: str,
) -> bool:
    lowered = line.lower()

    markers = [
        "корпус",
        "ауд",
        "бгуир",
        "завод",
    ]

    return any(
        marker in lowered
        for marker in markers
    )


def split_room_line(
    line: str,
) -> list[str]:
    line = line.replace(
        ",",
        " ",
    )

    values = []

    for part in line.split():
        cleaned = part.strip()

        if looks_like_room(
            cleaned,
        ):
            values.append(
                cleaned,
            )

    return values


def extract_rooms(
    lines: list[str],
) -> tuple[list[str], list[str]]:
    if not lines:
        return [], []

    remaining = lines.copy()
    rooms: list[str] = []

    while remaining:
        line = remaining[-1]

        if is_extended_room_line(
            line,
        ):
            rooms.insert(
                0,
                line,
            )
            remaining.pop()
            continue

        room_values = split_room_line(
            line,
        )

        if not room_values:
            break

        rooms = (
            room_values + rooms
        )

        remaining.pop()

    return rooms, remaining


def looks_like_teacher_line(
    line: str,
) -> bool:
    if not line:
        return False

    if any(
        char.isdigit()
        for char in line
    ):
        return False

    lowered = line.lower()

    blocked_words = [
        "практика",
        "подгруппа",
        "информационный час",
        "физ к и зд",
        "иностранный язык",
        "русский язык",
        "белорусский язык",
        "математика",
        "физика",
        "химия",
        "биология",
        "история",
        "программирование",
        "схемотехника",
        "разработка",
        "экономика",
        "технология",
        "подготовка",
        "учебная практика",
    ]

    if any(
        word in lowered
        for word in blocked_words
    ):
        return False

    words = line.split()

    if not words:
        return False

    if len(words) > 4:
        return False

    return all(
        word[0].isupper()
        for word in words
        if word
    )


def extract_teachers(
    lines: list[str],
) -> tuple[list[str], list[str]]:
    if not lines:
        return [], []

    possible_index = None

    for index in range(
        len(lines) - 1,
        -1,
        -1,
    ):
        line = lines[index]

        if looks_like_teacher_line(
            line,
        ):
            possible_index = index
            break

    if possible_index is None:
        return [], lines

    teacher_line = lines[
        possible_index
    ]

    teachers = [
        value.strip()
        for value in teacher_line.split()
        if value.strip()
    ]

    remaining = (
        lines[:possible_index]
        + lines[
            possible_index + 1:
        ]
    )

    return teachers, remaining


def extract_subgroup(
    text: str,
) -> str | None:
    match = re.search(
        r"([12])\s*подгрупп[аы]",
        text,
        re.IGNORECASE,
    )

    if match is None:
        match = re.search(
            r"\(([12])\s*подгрупп[аы]\)",
            text,
            re.IGNORECASE,
        )

    if match is None:
        return None

    return match.group(1)


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
            line,
        )

        if found_time is not None:
            custom_time = found_time

            line_without_time = (
                TIME_PATTERN.sub(
                    "",
                    line,
                ).strip()
            )

            if line_without_time:
                remaining.append(
                    line_without_time,
                )
        else:
            remaining.append(
                line,
            )

    return (
        custom_time,
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


def parse_lesson_cell(
    cell: str,
    group_id: str,
    lesson_number: int,
    date: str,
    page_number: int,
) -> dict[str, Any] | None:
    text = clean_text(cell)

    if not text:
        return None

    lines = [
        line.strip()
        for line in text.split("\n")
        if line.strip()
    ]

    if not lines:
        return None

    custom_time, lines = (
        remove_time_lines(
            lines,
        )
    )

    subgroup = extract_subgroup(
        text,
    )

    rooms, lines = extract_rooms(
        lines,
    )

    teachers, lines = (
        extract_teachers(
            lines,
        )
    )

    practice = is_practice(
        text,
    )

    subject_lines = []

    for line in lines:
        if re.fullmatch(
            r"(?:1|2)\s*подгрупп[аы]",
            line,
            re.IGNORECASE,
        ):
            continue

        if re.fullmatch(
            r"Практика\s+[12]\s*подгрупп[аы]",
            line,
            re.IGNORECASE,
        ):
            continue

        subject_lines.append(
            line,
        )

    subject = " ".join(
        subject_lines,
    ).strip()

    # Иногда pdfplumber извлекает из сложной
    # ячейки только время, например:
    #
    # 13:10-13:30
    #
    # Само по себе это не занятие.
    if (
        not subject
        and not teachers
        and not rooms
    ):
        return None

    if practice:
        if (
            not subject
            or re.fullmatch(
                r"Практика(?:\s+[12]\s*подгрупп[аы])?",
                subject,
                re.IGNORECASE,
            )
        ):
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
        "number": lesson_number,
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
            first_cell,
        )

        if not is_group(
            group_id,
        ):
            continue

        lesson_cells = row[1:8]

        while len(
            lesson_cells
        ) < 7:
            lesson_cells.append(
                None,
            )

        for index, cell in enumerate(
            lesson_cells,
            start=1,
        ):
            parsed = parse_lesson_cell(
                cell=clean_text(cell),
                group_id=group_id,
                lesson_number=index,
                date=date,
                page_number=page_number,
            )

            if parsed is not None:
                lessons.append(
                    parsed,
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
            # На первом этапе импортируем только
            # основное расписание дневной формы.
            #
            # Страницы 7 и 8 имеют другую структуру
            # и будут поддерживаться отдельно.
            if page_index > 6:
                continue

            page_date = (
                extract_date_from_page(
                    page,
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
                table_settings,
            )

            page_has_schedule = False

            for table in tables:
                if not looks_like_schedule_table(
                    table,
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
                    page_index,
                )

    if detected_date is None:
        raise ValueError(
            "Не удалось определить дату "
            "расписания из PDF."
        )

    return {
        "sourceFile": pdf_path.name,
        "date": detected_date,
        "schedulePages": schedule_pages,
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
        if lesson["type"] == "Практика"
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
        f"Читаю: {pdf_path.name}"
    )

    data = parse_pdf(
        pdf_path,
    )

    output_path = save_result(
        data,
        Path(args.output),
    )

    print_summary(
        data,
    )

    print(
        "JSON сохранён:"
    )

    print(
        output_path.resolve()
    )


if __name__ == "__main__":
    main()