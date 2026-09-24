from collections import defaultdict
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore

from teacher_names import (
    is_valid_teacher_name,
    normalize_teacher_name,
)


BASE_DIR = Path(__file__).resolve().parent
SERVICE_ACCOUNT_PATH = BASE_DIR / "service-account.json"


def initialize_firestore():
    if not SERVICE_ACCOUNT_PATH.exists():
        raise FileNotFoundError(
            "Не найден service-account.json.\n"
            f"Ожидаемый путь:\n{SERVICE_ACCOUNT_PATH}"
        )

    if not firebase_admin._apps:
        cred = credentials.Certificate(
            str(SERVICE_ACCOUNT_PATH)
        )
        firebase_admin.initialize_app(cred)

    return firestore.client()


def load_collection(
    db,
    collection_name: str,
) -> dict[str, dict[str, Any]]:
    result = {}

    for document in (
        db.collection(collection_name).stream()
    ):
        result[document.id] = (
            document.to_dict() or {}
        )

    return result


def audit_teachers(
    teachers: dict[str, dict[str, Any]],
) -> list[dict[str, Any]]:
    issues = []

    for teacher_id, data in teachers.items():
        raw_name = str(
            data.get("name") or ""
        ).strip()

        canonical_name = (
            normalize_teacher_name(
                raw_name
            )
        )

        if not raw_name:
            issues.append(
                {
                    "type": "EMPTY_NAME",
                    "teacherId": teacher_id,
                    "name": raw_name,
                    "message": (
                        "Поле name пустое."
                    ),
                }
            )
            continue

        if not is_valid_teacher_name(
            canonical_name
        ):
            issues.append(
                {
                    "type": "INVALID_NAME",
                    "teacherId": teacher_id,
                    "name": raw_name,
                    "message": (
                        "Имя не прошло "
                        "проверку "
                        "is_valid_teacher_name()."
                    ),
                }
            )

        if raw_name != canonical_name:
            issues.append(
                {
                    "type": (
                        "NON_CANONICAL_NAME"
                    ),
                    "teacherId": teacher_id,
                    "name": raw_name,
                    "canonicalName": (
                        canonical_name
                    ),
                    "message": (
                        "Имя отличается "
                        "от канонического."
                    ),
                }
            )

    return issues


def audit_lesson_links(
    lessons: dict[str, dict[str, Any]],
    teachers: dict[str, dict[str, Any]],
) -> tuple[
    list[dict[str, Any]],
    dict[str, list[dict[str, Any]]],
]:
    issues = []

    usage: dict[
        str,
        list[dict[str, Any]],
    ] = defaultdict(list)

    teacher_ids = set(
        teachers.keys()
    )

    for lesson_id, lesson in lessons.items():
        raw_teacher_ids = (
            lesson.get("teacherIds")
        )

        if raw_teacher_ids is None:
            raw_teacher_ids = []

        if not isinstance(
            raw_teacher_ids,
            list,
        ):
            issues.append(
                {
                    "type": (
                        "INVALID_TEACHER_IDS"
                    ),
                    "lessonId": lesson_id,
                    "message": (
                        "teacherIds "
                        "не является массивом."
                    ),
                }
            )
            continue

        group_id = str(
            lesson.get("groupId") or ""
        ).strip()

        subject = str(
            lesson.get("subject") or ""
        ).strip()

        date = str(
            lesson.get("date") or ""
        ).strip()

        number = lesson.get(
            "number"
        )

        for raw_teacher_id in (
            raw_teacher_ids
        ):
            teacher_id = str(
                raw_teacher_id
            ).strip()

            if not teacher_id:
                issues.append(
                    {
                        "type": (
                            "EMPTY_TEACHER_ID"
                        ),
                        "lessonId": (
                            lesson_id
                        ),
                        "message": (
                            "В teacherIds "
                            "обнаружена "
                            "пустая ссылка."
                        ),
                    }
                )
                continue

            lesson_info = {
                "lessonId": lesson_id,
                "date": date,
                "groupId": group_id,
                "number": number,
                "subject": subject,
            }

            usage[
                teacher_id
            ].append(
                lesson_info
            )

            if (
                teacher_id
                not in teacher_ids
            ):
                issues.append(
                    {
                        "type": (
                            "MISSING_TEACHER"
                        ),
                        "lessonId": (
                            lesson_id
                        ),
                        "teacherId": (
                            teacher_id
                        ),
                        "date": date,
                        "groupId": (
                            group_id
                        ),
                        "number": number,
                        "subject": subject,
                        "message": (
                            "teacherIds "
                            "ссылается на "
                            "несуществующий "
                            "документ teachers."
                        ),
                    }
                )

    return issues, usage


def print_teachers(
    teachers: dict[str, dict[str, Any]],
) -> None:
    print("-" * 78)
    print("ВСЕ ПРЕПОДАВАТЕЛИ")
    print("-" * 78)

    sorted_teachers = sorted(
        teachers.items(),
        key=lambda item: str(
            item[1].get("name") or ""
        ).lower(),
    )

    for index, (
        teacher_id,
        data,
    ) in enumerate(
        sorted_teachers,
        start=1,
    ):
        name = str(
            data.get("name") or ""
        ).strip()

        print(
            f"{index:3}. "
            f"{name or '<пустое имя>'}"
        )
        print(
            f"     ID: {teacher_id}"
        )


def print_teacher_issues(
    issues: list[dict[str, Any]],
    usage: dict[
        str,
        list[dict[str, Any]],
    ],
) -> None:
    print()
    print("-" * 78)
    print(
        "ПРОБЛЕМЫ В КОЛЛЕКЦИИ TEACHERS"
    )
    print("-" * 78)

    if not issues:
        print()
        print(
            "Проблем в teachers "
            "не найдено."
        )
        return

    grouped: dict[
        str,
        list[dict[str, Any]],
    ] = defaultdict(list)

    for issue in issues:
        grouped[
            issue["type"]
        ].append(
            issue
        )

    for issue_type in sorted(
        grouped
    ):
        current = grouped[
            issue_type
        ]

        print()
        print(
            f"{issue_type}: "
            f"{len(current)}"
        )

        for issue in current:
            teacher_id = issue[
                "teacherId"
            ]

            print()
            print(
                "  Имя: "
                f"{issue.get('name')!r}"
            )
            print(
                f"  ID: {teacher_id}"
            )

            canonical_name = (
                issue.get(
                    "canonicalName"
                )
            )

            if canonical_name:
                print(
                    "  После "
                    "нормализации: "
                    f"{canonical_name!r}"
                )

            print(
                "  "
                + issue["message"]
            )

            references = usage.get(
                teacher_id,
                [],
            )

            print(
                "  Используется "
                "в lessons: "
                f"{len(references)}"
            )

            for lesson in (
                references[:10]
            ):
                print(
                    "    • "
                    f"{lesson['date']} | "
                    f"{lesson['groupId']} | "
                    f"пара "
                    f"{lesson['number']} | "
                    f"{lesson['subject']} | "
                    f"{lesson['lessonId']}"
                )

            if len(references) > 10:
                print(
                    "    ... ещё "
                    f"{len(references) - 10}"
                )


def print_lesson_issues(
    issues: list[dict[str, Any]],
) -> None:
    print()
    print("-" * 78)
    print(
        "ПРОБЛЕМЫ СВЯЗЕЙ "
        "LESSONS → TEACHERS"
    )
    print("-" * 78)

    if not issues:
        print()
        print(
            "Битых ссылок "
            "не найдено."
        )
        return

    grouped: dict[
        str,
        list[dict[str, Any]],
    ] = defaultdict(list)

    for issue in issues:
        grouped[
            issue["type"]
        ].append(
            issue
        )

    for issue_type in sorted(
        grouped
    ):
        current = grouped[
            issue_type
        ]

        print()
        print(
            f"{issue_type}: "
            f"{len(current)}"
        )

        for issue in current[:30]:
            print()

            print(
                "  Lesson: "
                f"{issue.get('lessonId')}"
            )

            if issue.get(
                "teacherId"
            ):
                print(
                    "  Teacher ID: "
                    f"{issue['teacherId']}"
                )

            if issue.get(
                "date"
            ):
                print(
                    "  Дата: "
                    f"{issue['date']}"
                )

            if issue.get(
                "groupId"
            ):
                print(
                    "  Группа: "
                    f"{issue['groupId']}"
                )

            if issue.get(
                "subject"
            ):
                print(
                    "  Предмет: "
                    f"{issue['subject']}"
                )

            print(
                "  "
                + issue["message"]
            )

        if len(current) > 30:
            print()
            print(
                "  ... ещё "
                f"{len(current) - 30}"
            )


def main():
    print(
        "Подключение к Firestore..."
    )

    db = initialize_firestore()

    teachers = load_collection(
        db,
        "teachers",
    )

    lessons = load_collection(
        db,
        "lessons",
    )

    teacher_issues = (
        audit_teachers(
            teachers
        )
    )

    (
        lesson_issues,
        usage,
    ) = audit_lesson_links(
        lessons,
        teachers,
    )

    print()
    print("=" * 78)
    print(
        "АУДИТ FIRESTORE"
    )
    print("=" * 78)

    print()
    print(
        "Документов teachers: "
        f"{len(teachers)}"
    )

    print(
        "Документов lessons: "
        f"{len(lessons)}"
    )

    print()

    print_teachers(
        teachers
    )

    print_teacher_issues(
        teacher_issues,
        usage,
    )

    print_lesson_issues(
        lesson_issues
    )

    print()
    print("=" * 78)
    print(
        "АУДИТ ЗАВЕРШЁН"
    )
    print("=" * 78)

    print(
        "Проблем teachers: "
        f"{len(teacher_issues)}"
    )

    print(
        "Проблем связей lessons: "
        f"{len(lesson_issues)}"
    )

    print(
        "Firestore НЕ изменён."
    )

    print("=" * 78)


if __name__ == "__main__":
    main()