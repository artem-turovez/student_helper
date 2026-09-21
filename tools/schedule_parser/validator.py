import argparse
import json
from pathlib import Path
from typing import Any


GENERIC_SUBJECTS = {
    "",
    "занятие",
}


def load_json(path: Path) -> dict[str, Any]:
    with path.open(
        "r",
        encoding="utf-8",
    ) as file:
        return json.load(file)


def validate_lesson(
    lesson: dict[str, Any],
) -> list[str]:
    problems = []

    subject = str(
        lesson.get(
            "subject",
            "",
        )
    ).strip()

    teachers = lesson.get(
        "teachers",
        [],
    )

    rooms = lesson.get(
        "rooms",
        [],
    )

    lesson_type = str(
        lesson.get(
            "type",
            "",
        )
    ).strip()

    lesson_number = lesson.get(
        "number",
    )

    time = str(
        lesson.get(
            "time",
            "",
        )
    ).strip()

    if subject.lower() in GENERIC_SUBJECTS:
        problems.append(
            "подозрительное название"
        )

    if not teachers:
        problems.append(
            "нет преподавателя"
        )

    if not rooms:
        problems.append(
            "нет аудитории"
        )

    if not isinstance(
        lesson_number,
        int,
    ):
        problems.append(
            "некорректный номер пары"
        )
    elif not 1 <= lesson_number <= 7:
        problems.append(
            "номер пары вне диапазона 1-7"
        )

    if not time:
        problems.append(
            "нет времени"
        )

    if (
        lesson_type.lower()
        == "практика"
        and not lesson.get("subgroup")
    ):
        problems.append(
            "практика без подгруппы"
        )

    return problems


def print_lesson(
    lesson: dict[str, Any],
    problems: list[str],
) -> None:
    print("-" * 70)

    print(
        "Группа:",
        lesson.get(
            "groupId",
            "?",
        ),
    )

    print(
        "Пара:",
        lesson.get(
            "number",
            "?",
        ),
    )

    print(
        "Время:",
        lesson.get(
            "time",
            "?",
        ),
    )

    print(
        "Предмет:",
        lesson.get(
            "subject",
            "?",
        ),
    )

    print(
        "Преподаватели:",
        lesson.get(
            "teachers",
            [],
        ),
    )

    print(
        "Аудитории:",
        lesson.get(
            "rooms",
            [],
        ),
    )

    print(
        "Тип:",
        lesson.get(
            "type",
            "",
        ),
    )

    print(
        "Подгруппа:",
        lesson.get(
            "subgroup",
        ),
    )

    print(
        "Страница:",
        lesson.get(
            "sourcePage",
            "?",
        ),
    )

    print(
        "ПРОБЛЕМЫ:",
        ", ".join(
            problems
        ),
    )

    print(
        "Исходный текст:",
    )

    print(
        lesson.get(
            "sourceText",
            "",
        )
    )


def validate_file(
    path: Path,
) -> None:
    data = load_json(
        path,
    )

    lessons = data.get(
        "lessons",
        [],
    )

    suspicious = []

    for lesson in lessons:
        problems = validate_lesson(
            lesson,
        )

        if problems:
            suspicious.append(
                (
                    lesson,
                    problems,
                )
            )

    print()
    print("=" * 70)
    print(
        f"ПРОВЕРКА: {path.name}"
    )
    print("=" * 70)

    print(
        f"Всего занятий: "
        f"{len(lessons)}"
    )

    print(
        f"Подозрительных: "
        f"{len(suspicious)}"
    )

    print(
        f"Без замечаний: "
        f"{len(lessons) - len(suspicious)}"
    )

    print()

    for lesson, problems in suspicious:
        print_lesson(
            lesson,
            problems,
        )

    print()
    print("=" * 70)
    print()


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Проверка результатов "
            "парсинга расписания"
        )
    )

    parser.add_argument(
        "json_files",
        nargs="+",
        help=(
            "JSON-файлы, созданные "
            "parser.py"
        ),
    )

    args = parser.parse_args()

    for filename in args.json_files:
        path = Path(
            filename
        ).expanduser().resolve()

        if not path.exists():
            print(
                f"Файл не найден: {path}"
            )
            continue

        validate_file(
            path,
        )


if __name__ == "__main__":
    main()