import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


BAD_TEACHER_TOKENS = {
    "МУ",
    "КЭ",
    "МЭУ",
    "ТП",
    "ЗИ",
    "Беларуси",
}

REQUIRED_LESSON_FIELDS = {
    "date",
    "groupId",
    "number",
    "time",
    "subject",
    "teachers",
    "teacherIds",
    "rooms",
    "type",
    "subgroup",
    "sourcePage",
    "sourceText",
}


def load_json(
    path: Path,
) -> dict[str, Any]:
    try:
        with path.open(
            "r",
            encoding="utf-8",
        ) as file:
            data = json.load(file)

    except FileNotFoundError:
        print(
            f"Файл не найден: {path}"
        )
        sys.exit(1)

    except json.JSONDecodeError as error:
        print(
            "JSON повреждён "
            "или имеет неверный формат."
        )
        print(error)
        sys.exit(1)

    if not isinstance(data, dict):
        print(
            "Корень JSON должен "
            "быть объектом."
        )
        sys.exit(1)

    return data


def add_issue(
    issues: list[str],
    index: int,
    lesson: dict[str, Any],
    message: str,
) -> None:
    group_id = lesson.get(
        "groupId",
        "?",
    )

    number = lesson.get(
        "number",
        "?",
    )

    issues.append(
        f"Занятие #{index}: "
        f"{group_id}, пара {number}: "
        f"{message}"
    )


def normalize_subgroup(
    value: Any,
) -> int | None:
    if value is None:
        return None

    if isinstance(value, bool):
        return None

    if isinstance(value, int):
        if value in {1, 2}:
            return value

        return None

    if isinstance(value, str):
        value = value.strip()

        if value in {"1", "2"}:
            return int(value)

    return None


def is_valid_subgroup_value(
    value: Any,
) -> bool:
    if value is None:
        return True

    return (
        normalize_subgroup(value)
        is not None
    )


def audit_lesson(
    lesson: Any,
    index: int,
    issues: list[str],
) -> None:
    if not isinstance(lesson, dict):
        issues.append(
            f"Занятие #{index}: "
            "запись должна быть объектом."
        )
        return

    missing_fields = (
        REQUIRED_LESSON_FIELDS
        - set(lesson.keys())
    )

    if missing_fields:
        add_issue(
            issues,
            index,
            lesson,
            "отсутствуют поля: "
            + ", ".join(
                sorted(missing_fields)
            ),
        )

    group_id = str(
        lesson.get("groupId") or ""
    ).strip()

    subject = str(
        lesson.get("subject") or ""
    ).strip()

    time = str(
        lesson.get("time") or ""
    ).strip()

    source_text = str(
        lesson.get("sourceText") or ""
    ).strip()

    number = lesson.get("number")
    source_page = lesson.get(
        "sourcePage"
    )

    teachers = lesson.get("teachers")
    teacher_ids = lesson.get(
        "teacherIds"
    )
    rooms = lesson.get("rooms")

    if not group_id:
        add_issue(
            issues,
            index,
            lesson,
            "пустой groupId.",
        )

    if not subject:
        add_issue(
            issues,
            index,
            lesson,
            "пустой предмет.",
        )

    if not time:
        add_issue(
            issues,
            index,
            lesson,
            "пустое время.",
        )

    if not source_text:
        add_issue(
            issues,
            index,
            lesson,
            "пустой sourceText.",
        )

    if not isinstance(number, int):
        add_issue(
            issues,
            index,
            lesson,
            (
                "number должен быть "
                "целым числом."
            ),
        )

    elif not 1 <= number <= 7:
        add_issue(
            issues,
            index,
            lesson,
            (
                "неожиданный номер "
                f"пары: {number}."
            ),
        )

    if not isinstance(
        source_page,
        int,
    ):
        add_issue(
            issues,
            index,
            lesson,
            (
                "sourcePage должен быть "
                "целым числом."
            ),
        )

    elif not 1 <= source_page <= 6:
        add_issue(
            issues,
            index,
            lesson,
            (
                "занятие получено с "
                "неожиданной страницы: "
                f"{source_page}."
            ),
        )

    if not isinstance(
        teachers,
        list,
    ):
        add_issue(
            issues,
            index,
            lesson,
            (
                "teachers должен "
                "быть массивом."
            ),
        )
        teachers = []

    if not isinstance(
        teacher_ids,
        list,
    ):
        add_issue(
            issues,
            index,
            lesson,
            (
                "teacherIds должен "
                "быть массивом."
            ),
        )
        teacher_ids = []

    if teacher_ids:
        add_issue(
            issues,
            index,
            lesson,
            (
                "teacherIds должен быть "
                "пустым до импорта "
                "в Firestore."
            ),
        )

    if not isinstance(
        rooms,
        list,
    ):
        add_issue(
            issues,
            index,
            lesson,
            (
                "rooms должен "
                "быть массивом."
            ),
        )
        rooms = []

    if not rooms:
        add_issue(
            issues,
            index,
            lesson,
            "не найдена аудитория.",
        )

    for teacher in teachers:
        teacher_name = str(
            teacher
        ).strip()

        if not teacher_name:
            add_issue(
                issues,
                index,
                lesson,
                (
                    "обнаружено пустое "
                    "имя преподавателя."
                ),
            )
            continue

        if (
            teacher_name
            in BAD_TEACHER_TOKENS
        ):
            add_issue(
                issues,
                index,
                lesson,
                (
                    "подозрительный "
                    "преподаватель: "
                    f"{teacher_name}."
                ),
            )

    raw_subgroup = lesson.get(
        "subgroup"
    )

    subgroup = normalize_subgroup(
        raw_subgroup
    )

    if not is_valid_subgroup_value(
        raw_subgroup
    ):
        add_issue(
            issues,
            index,
            lesson,
            (
                "subgroup должен быть "
                "1, 2 или null."
            ),
        )

    lesson_type = str(
        lesson.get("type") or ""
    ).strip()

    if lesson_type == "Практика":
        source_lower = (
            source_text.lower()
        )

        if "подгруппа" in source_lower:
            if subgroup is None:
                add_issue(
                    issues,
                    index,
                    lesson,
                    (
                        "в sourceText указана "
                        "подгруппа, но она "
                        "не распознана."
                    ),
                )

            if (
                "1 подгруппа"
                in source_lower
                and subgroup != 1
            ):
                add_issue(
                    issues,
                    index,
                    lesson,
                    (
                        "sourceText содержит "
                        "'1 подгруппа', "
                        "но распознано "
                        f"{raw_subgroup}."
                    ),
                )

            if (
                "2 подгруппа"
                in source_lower
                and subgroup != 2
            ):
                add_issue(
                    issues,
                    index,
                    lesson,
                    (
                        "sourceText содержит "
                        "'2 подгруппа', "
                        "но распознано "
                        f"{raw_subgroup}."
                    ),
                )


def audit_json(
    data: dict[str, Any],
) -> tuple[
    list[str],
    dict[str, Any],
]:
    issues: list[str] = []

    lessons = data.get("lessons")

    if not isinstance(
        lessons,
        list,
    ):
        return (
            [
                "Поле lessons отсутствует "
                "или не является массивом."
            ],
            {},
        )

    declared_count = data.get(
        "lessonCount"
    )

    if declared_count != len(lessons):
        issues.append(
            "lessonCount не совпадает "
            "с фактическим количеством: "
            f"{declared_count} != "
            f"{len(lessons)}."
        )

    groups: set[str] = set()
    subjects: set[str] = set()
    teachers: set[str] = set()

    lessons_without_teacher = 0
    lessons_without_room = 0

    date_counter: Counter[str] = (
        Counter()
    )

    for index, lesson in enumerate(
        lessons,
        start=1,
    ):
        audit_lesson(
            lesson,
            index,
            issues,
        )

        if not isinstance(
            lesson,
            dict,
        ):
            continue

        group_id = str(
            lesson.get("groupId") or ""
        ).strip()

        subject = str(
            lesson.get("subject") or ""
        ).strip()

        lesson_teachers = (
            lesson.get("teachers")
            if isinstance(
                lesson.get("teachers"),
                list,
            )
            else []
        )

        rooms = (
            lesson.get("rooms")
            if isinstance(
                lesson.get("rooms"),
                list,
            )
            else []
        )

        date = str(
            lesson.get("date") or ""
        ).strip()

        if group_id:
            groups.add(group_id)

        if subject:
            subjects.add(subject)

        for teacher in lesson_teachers:
            teacher_name = str(
                teacher
            ).strip()

            if teacher_name:
                teachers.add(
                    teacher_name
                )

        if not lesson_teachers:
            lessons_without_teacher += 1

        if not rooms:
            lessons_without_room += 1

        if date:
            date_counter[date] += 1

    root_date = str(
        data.get("date") or ""
    ).strip()

    if not root_date:
        issues.append(
            "В корне JSON "
            "отсутствует date."
        )

    unexpected_dates = [
        date
        for date in date_counter
        if date != root_date
    ]

    if unexpected_dates:
        issues.append(
            "Внутри lessons найдены "
            "даты, не совпадающие "
            "с корневой date: "
            + ", ".join(
                unexpected_dates
            )
        )

    stats = {
        "lessons": len(lessons),
        "groups": len(groups),
        "subjects": len(subjects),
        "teachers": len(teachers),
        "withoutTeacher":
            lessons_without_teacher,
        "withoutRoom":
            lessons_without_room,
        "date": root_date,
    }

    return issues, stats


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Автоматическая проверка "
            "распарсенного расписания."
        )
    )

    parser.add_argument(
        "json_file",
        help=(
            "Путь к parsed JSON."
        ),
    )

    args = parser.parse_args()

    json_path = Path(
        args.json_file
    ).resolve()

    data = load_json(
        json_path
    )

    issues, stats = audit_json(
        data
    )

    print()
    print("=" * 80)
    print("АУДИТ РАСПИСАНИЯ")
    print("=" * 80)

    if stats:
        print(
            f"Дата: {stats['date']}"
        )
        print(
            f"Занятий: "
            f"{stats['lessons']}"
        )
        print(
            f"Групп: "
            f"{stats['groups']}"
        )
        print(
            f"Предметов: "
            f"{stats['subjects']}"
        )
        print(
            "Вариантов преподавателей: "
            f"{stats['teachers']}"
        )
        print(
            "Без преподавателя: "
            f"{stats['withoutTeacher']}"
        )
        print(
            "Без аудитории: "
            f"{stats['withoutRoom']}"
        )

    print()
    print("-" * 80)

    if issues:
        print(
            "ОБНАРУЖЕНЫ ПРОБЛЕМЫ"
        )
        print("-" * 80)

        for issue in issues:
            print(
                f"  ✗ {issue}"
            )

        print()
        print("=" * 80)
        print(
            "АУДИТ НЕ ПРОЙДЕН"
        )
        print("=" * 80)

        sys.exit(1)

    print(
        "Критических проблем "
        "не найдено."
    )

    print()
    print("=" * 80)
    print("АУДИТ ПРОЙДЕН")
    print("=" * 80)


if __name__ == "__main__":
    main()