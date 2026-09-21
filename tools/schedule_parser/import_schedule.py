import argparse
import hashlib
import json
import re
from datetime import datetime
from pathlib import Path
from typing import Any

from firebase_admin import firestore

from firebase_connection import get_firestore_client


def load_schedule(
    json_path: Path,
) -> dict[str, Any]:
    if not json_path.exists():
        raise FileNotFoundError(
            f"JSON не найден: {json_path}"
        )

    with json_path.open(
        "r",
        encoding="utf-8",
    ) as file:
        data = json.load(file)

    if "lessons" not in data:
        raise ValueError(
            "В JSON отсутствует поле lessons."
        )

    return data


def normalize_name(
    value: str,
) -> str:
    value = value.lower().strip()

    value = value.replace(
        "ё",
        "е",
    )

    value = re.sub(
        r"\s+",
        " ",
        value,
    )

    return value


def get_surname(
    full_name: str,
) -> str:
    normalized = normalize_name(
        full_name,
    )

    if not normalized:
        return ""

    return normalized.split()[0]


def load_teachers(
    db,
) -> list[dict[str, Any]]:
    teachers = []

    for document in (
        db.collection("teachers").stream()
    ):
        data = document.to_dict()

        teachers.append(
            {
                "id": document.id,
                "name": (
                    data.get("name", "")
                    or ""
                ).strip(),
                "data": data,
            }
        )

    return teachers


def find_teacher(
    parsed_name: str,
    teachers: list[dict[str, Any]],
) -> dict[str, Any] | None:
    parsed_normalized = normalize_name(
        parsed_name,
    )

    parsed_surname = get_surname(
        parsed_name,
    )

    if not parsed_normalized:
        return None

    # Сначала пытаемся найти точное
    # совпадение полного имени.
    exact_matches = [
        teacher
        for teacher in teachers
        if normalize_name(
            teacher["name"]
        ) == parsed_normalized
    ]

    if len(exact_matches) == 1:
        return exact_matches[0]

    # В PDF чаще всего указана только
    # фамилия преподавателя.
    surname_matches = [
        teacher
        for teacher in teachers
        if get_surname(
            teacher["name"]
        ) == parsed_surname
    ]

    # Связываем автоматически только тогда,
    # когда фамилия однозначна.
    if len(surname_matches) == 1:
        return surname_matches[0]

    return None


def make_lesson_id(
    lesson: dict[str, Any],
) -> str:
    """
    Создаём стабильный ID.

    Один и тот же урок при повторном
    импорте получит тот же ID.

    Подгруппа и время обязательно входят
    в ID, потому что у двух подгрупп может
    быть одинаковый номер пары.
    """

    parts = [
        str(
            lesson.get(
                "date",
                "",
            )
        ),
        str(
            lesson.get(
                "groupId",
                "",
            )
        ),
        str(
            lesson.get(
                "number",
                "",
            )
        ),
        str(
            lesson.get(
                "time",
                "",
            )
        ),
        str(
            lesson.get(
                "subgroup",
                "",
            )
        ),
        str(
            lesson.get(
                "subject",
                "",
            )
        ),
    ]

    source = "|".join(parts)

    digest = hashlib.sha256(
        source.encode("utf-8")
    ).hexdigest()[:16]

    date = (
        str(
            lesson.get(
                "date",
                "",
            )
        )
        .replace("-", "")
    )

    group = re.sub(
        r"[^0-9A-Za-zА-Яа-я]",
        "",
        str(
            lesson.get(
                "groupId",
                "",
            )
        ),
    )

    return (
        f"{date}_"
        f"{group}_"
        f"{digest}"
    )


def parse_firestore_date(
    value: str,
) -> datetime:
    return datetime.strptime(
        value,
        "%Y-%m-%d",
    )


def prepare_lesson(
    lesson: dict[str, Any],
    teachers: list[dict[str, Any]],
) -> tuple[
    dict[str, Any],
    list[str],
]:
    teacher_ids = []
    unmatched = []

    for teacher_name in lesson.get(
        "teachers",
        [],
    ):
        teacher = find_teacher(
            teacher_name,
            teachers,
        )

        if teacher is None:
            unmatched.append(
                teacher_name,
            )
            continue

        teacher_ids.append(
            teacher["id"],
        )

    firestore_lesson = {
        "date": parse_firestore_date(
            lesson["date"]
        ),
        "groupId": lesson.get(
            "groupId",
        ),
        "number": lesson.get(
            "number",
        ),
        "time": lesson.get(
            "time",
            "",
        ),
        "subject": lesson.get(
            "subject",
            "",
        ),
        "teachers": lesson.get(
            "teachers",
            [],
        ),
        "teacherIds": teacher_ids,
        "rooms": lesson.get(
            "rooms",
            [],
        ),
        "type": lesson.get(
            "type",
            "",
        ),
        "subgroup": lesson.get(
            "subgroup",
        ),
    }

    return (
        firestore_lesson,
        unmatched,
    )


def analyze_import(
    db,
    data: dict[str, Any],
) -> list[
    tuple[
        str,
        dict[str, Any],
    ]
]:
    print()
    print("=" * 70)
    print("АНАЛИЗ ИМПОРТА")
    print("=" * 70)

    print(
        f"Файл: "
        f"{data.get('sourceFile')}"
    )

    print(
        f"Дата: "
        f"{data.get('date')}"
    )

    lessons = data["lessons"]

    print(
        f"Занятий в JSON: "
        f"{len(lessons)}"
    )

    print()
    print(
        "Загрузка преподавателей "
        "из Firestore..."
    )

    teachers = load_teachers(
        db,
    )

    print(
        f"Преподавателей в Firestore: "
        f"{len(teachers)}"
    )

    prepared = []

    matched_names = set()
    unmatched_names = set()

    for lesson in lessons:
        document_id = make_lesson_id(
            lesson,
        )

        firestore_lesson, unmatched = (
            prepare_lesson(
                lesson,
                teachers,
            )
        )

        prepared.append(
            (
                document_id,
                firestore_lesson,
            )
        )

        for teacher_name in lesson.get(
            "teachers",
            [],
        ):
            if teacher_name in unmatched:
                unmatched_names.add(
                    teacher_name
                )
            else:
                matched_names.add(
                    teacher_name
                )

    print()
    print("-" * 70)
    print("ПРЕПОДАВАТЕЛИ")
    print("-" * 70)

    print(
        f"Сопоставлено уникальных имён: "
        f"{len(matched_names)}"
    )

    if matched_names:
        for name in sorted(
            matched_names
        ):
            print(
                f"  ✓ {name}"
            )

    print()

    print(
        f"Не найдено уникальных имён: "
        f"{len(unmatched_names)}"
    )

    if unmatched_names:
        for name in sorted(
            unmatched_names
        ):
            print(
                f"  ! {name}"
            )

    print()
    print("-" * 70)
    print("ПРИМЕРЫ ДОКУМЕНТОВ")
    print("-" * 70)

    for (
        document_id,
        lesson,
    ) in prepared[:5]:
        print()
        print(
            f"ID: {document_id}"
        )

        print(
            f"  {lesson['groupId']} | "
            f"пара {lesson['number']} | "
            f"{lesson['time']}"
        )

        print(
            f"  {lesson['subject']}"
        )

        print(
            f"  teachers: "
            f"{lesson['teachers']}"
        )

        print(
            f"  teacherIds: "
            f"{lesson['teacherIds']}"
        )

        print(
            f"  rooms: "
            f"{lesson['rooms']}"
        )

        print(
            f"  subgroup: "
            f"{lesson['subgroup']}"
        )

    print()
    print("=" * 70)
    print("DRY RUN ЗАВЕРШЁН")
    print("=" * 70)

    print(
        "Firestore НЕ изменён."
    )

    print(
        f"Подготовлено документов: "
        f"{len(prepared)}"
    )

    print("=" * 70)
    print()

    return prepared


def commit_import(
    db,
    prepared: list[
        tuple[
            str,
            dict[str, Any],
        ]
    ],
) -> None:
    print()
    print("=" * 70)
    print("ЗАПИСЬ В FIRESTORE")
    print("=" * 70)

    if not prepared:
        print(
            "Нет документов для записи."
        )
        return

    # Firestore batch имеет ограничение
    # на количество операций.
    # Используем небольшие партии.
    batch_size = 400

    written = 0

    for start in range(
        0,
        len(prepared),
        batch_size,
    ):
        chunk = prepared[
            start:start + batch_size
        ]

        batch = db.batch()

        for (
            document_id,
            lesson,
        ) in chunk:
            reference = (
                db.collection("lessons")
                .document(document_id)
            )

            batch.set(
                reference,
                lesson,
                merge=True,
            )

        batch.commit()

        written += len(
            chunk
        )

        print(
            f"Записано: "
            f"{written}/"
            f"{len(prepared)}"
        )

    print()
    print(
        "Импорт завершён."
    )

    print(
        f"Обработано документов: "
        f"{written}"
    )

    print("=" * 70)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Импорт расписания "
            "из JSON в Firestore"
        )
    )

    parser.add_argument(
        "json",
        help=(
            "JSON, созданный parser.py"
        ),
    )

    parser.add_argument(
        "--commit",
        action="store_true",
        help=(
            "Разрешить реальную запись "
            "в Firestore"
        ),
    )

    args = parser.parse_args()

    json_path = Path(
        args.json
    ).expanduser().resolve()

    data = load_schedule(
        json_path,
    )

    db = get_firestore_client()

    prepared = analyze_import(
        db,
        data,
    )

    if not args.commit:
        print(
            "Это был только предварительный "
            "просмотр."
        )
        print(
            "Для реального импорта существует "
            "флаг --commit."
        )
        return

    print()
    print(
        "ВНИМАНИЕ: включён режим --commit."
    )

    commit_import(
        db,
        prepared,
    )


if __name__ == "__main__":
    main()