import argparse
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path
from typing import Any

import firebase_admin
from firebase_admin import credentials, firestore

from teacher_names import (
    TEACHER_NAME_CORRECTIONS,
    normalize_teacher_name,
    normalize_teacher_key,
)


BASE_DIR = Path(__file__).resolve().parent

SERVICE_ACCOUNT_PATH = (
    BASE_DIR / "service-account.json"
)

DEFAULT_JSON_FILES = [
    BASE_DIR / "parsed" / "21.09.2026.json",
    BASE_DIR / "parsed" / "22.09.2026.json",
]


def normalize_for_id(
    value: str,
) -> str:
    """
    Подготавливает имя преподавателя
    для использования в ID документа.
    """

    value = (
        normalize_teacher_name(value)
        .lower()
        .replace("ё", "е")
    )

    value = re.sub(
        r"[^a-zа-я0-9]+",
        "_",
        value,
    )

    return value.strip("_")


def make_teacher_id(
    teacher_name: str,
) -> str:
    """
    Создаёт стабильный ID преподавателя.

    Например:

    Яковлев
    ->
    teacher_яковлев
    """

    normalized = normalize_for_id(
        teacher_name
    )

    if normalized:
        return f"teacher_{normalized}"

    digest = hashlib.sha256(
        teacher_name.encode("utf-8")
    ).hexdigest()[:16]

    return f"teacher_{digest}"


def load_schedule_file(
    path: Path,
) -> dict[str, Any]:
    """
    Загружает JSON расписания
    и проверяет его базовую структуру.
    """

    if not path.exists():
        raise FileNotFoundError(
            f"Файл не найден: {path}"
        )

    with path.open(
        "r",
        encoding="utf-8",
    ) as file:
        data = json.load(file)

    if not isinstance(data, dict):
        raise ValueError(
            f"{path.name}: корень JSON "
            f"должен быть объектом"
        )

    lessons = data.get("lessons")

    if not isinstance(lessons, list):
        raise ValueError(
            f"{path.name}: поле lessons "
            f"должно быть списком"
        )

    return data


def initialize_firestore():
    """
    Подключается к Firestore через
    Firebase Admin SDK.
    """

    if not SERVICE_ACCOUNT_PATH.exists():
        raise FileNotFoundError(
            "Не найден service-account.json.\n"
            f"Ожидаемый путь:\n"
            f"{SERVICE_ACCOUNT_PATH}"
        )

    if not firebase_admin._apps:
        cred = credentials.Certificate(
            str(SERVICE_ACCOUNT_PATH)
        )

        firebase_admin.initialize_app(
            cred
        )

    return firestore.client()


def collect_teachers(
    schedule_files: list[Path],
) -> tuple[
    dict[str, dict[str, Any]],
    dict[str, set[str]],
    int,
]:
    """
    Собирает всех преподавателей
    из нескольких JSON-файлов.

    Возвращает:

    1. канонических преподавателей;
    2. применённые исправления;
    3. количество просмотренных занятий.
    """

    teachers: dict[
        str,
        dict[str, Any],
    ] = {}

    applied_corrections: dict[
        str,
        set[str],
    ] = defaultdict(set)

    total_lessons = 0

    for path in schedule_files:
        data = load_schedule_file(
            path
        )

        lessons = data["lessons"]

        for lesson in lessons:
            if not isinstance(
                lesson,
                dict,
            ):
                continue

            total_lessons += 1

            group_id = str(
                lesson.get(
                    "groupId",
                    "",
                )
            ).strip()

            subject = str(
                lesson.get(
                    "subject",
                    "",
                )
            ).strip()

            date = str(
                lesson.get(
                    "date",
                    "",
                )
            ).strip()

            lesson_teachers = (
                lesson.get(
                    "teachers",
                    [],
                )
            )

            if not isinstance(
                lesson_teachers,
                list,
            ):
                continue

            for raw_name in lesson_teachers:
                raw_name = str(
                    raw_name
                ).strip()

                if not raw_name:
                    continue

                canonical_name = (
                    normalize_teacher_name(
                        raw_name
                    )
                )

                if not canonical_name:
                    continue

                teacher_key = (
                    normalize_teacher_key(
                        canonical_name
                    )
                )

                if (
                    raw_name
                    != canonical_name
                ):
                    applied_corrections[
                        canonical_name
                    ].add(
                        raw_name
                    )

                if teacher_key not in teachers:
                    teachers[
                        teacher_key
                    ] = {
                        "name": (
                            canonical_name
                        ),
                        "teacherId": (
                            make_teacher_id(
                                canonical_name
                            )
                        ),
                        "groupIds": set(),
                        "subjects": set(),
                        "dates": set(),
                        "mentions": 0,
                        "sourceNames": set(),
                    }

                teacher = teachers[
                    teacher_key
                ]

                teacher[
                    "mentions"
                ] += 1

                teacher[
                    "sourceNames"
                ].add(
                    raw_name
                )

                if group_id:
                    teacher[
                        "groupIds"
                    ].add(
                        group_id
                    )

                if subject:
                    teacher[
                        "subjects"
                    ].add(
                        subject
                    )

                if date:
                    teacher[
                        "dates"
                    ].add(
                        date
                    )

    return (
        teachers,
        applied_corrections,
        total_lessons,
    )


def check_teacher_id_collisions(
    teachers: dict[
        str,
        dict[str, Any],
    ],
) -> list[
    tuple[
        str,
        str,
        str,
    ]
]:
    """
    Проверяет, не получили ли два
    разных преподавателя одинаковый ID.
    """

    ids: dict[str, str] = {}

    collisions = []

    for teacher in teachers.values():
        teacher_id = teacher[
            "teacherId"
        ]

        name = teacher[
            "name"
        ]

        if teacher_id in ids:
            previous_name = ids[
                teacher_id
            ]

            if (
                normalize_teacher_key(
                    previous_name
                )
                !=
                normalize_teacher_key(
                    name
                )
            ):
                collisions.append(
                    (
                        teacher_id,
                        previous_name,
                        name,
                    )
                )
        else:
            ids[
                teacher_id
            ] = name

    return collisions


def build_firestore_document(
    teacher: dict[str, Any],
) -> dict[str, Any]:
    """
    Формирует документ teachers
    в формате, который использует
    Flutter-приложение.
    """

    return {
        "name": teacher["name"],
        "email": None,
        "phone": None,
        "telegram": None,
        "photoUrl": None,
        "department": None,
        "groupIds": sorted(
            teacher["groupIds"]
        ),
    }


def load_existing_teachers(
    db,
) -> dict[
    str,
    dict[str, Any],
]:
    """
    Загружает существующие документы
    коллекции teachers.
    """

    result = {}

    for document in (
        db.collection(
            "teachers"
        ).stream()
    ):
        result[
            document.id
        ] = (
            document.to_dict()
            or {}
        )

    return result


def analyze_existing_teachers(
    teachers: dict[
        str,
        dict[str, Any],
    ],
    existing_teachers: dict[
        str,
        dict[str, Any],
    ],
) -> tuple[
    list[
        tuple[
            str,
            str,
        ]
    ],
    list[
        tuple[
            str,
            str,
            str,
        ]
    ],
]:
    """
    Проверяет совпадения с уже
    существующими документами Firestore.

    existing_same:
        ID и имя совпадают.

    conflicts:
        ID совпадает, но имя отличается.
    """

    existing_same = []
    conflicts = []

    for teacher in teachers.values():
        teacher_id = teacher[
            "teacherId"
        ]

        teacher_name = teacher[
            "name"
        ]

        existing = (
            existing_teachers.get(
                teacher_id
            )
        )

        if existing is None:
            continue

        existing_name = str(
            existing.get(
                "name",
                "",
            )
        ).strip()

        if (
            normalize_teacher_key(
                existing_name
            )
            ==
            normalize_teacher_key(
                teacher_name
            )
        ):
            existing_same.append(
                (
                    teacher_id,
                    teacher_name,
                )
            )
        else:
            conflicts.append(
                (
                    teacher_id,
                    existing_name,
                    teacher_name,
                )
            )

    return (
        existing_same,
        conflicts,
    )


def print_analysis(
    schedule_files: list[Path],
    teachers: dict[
        str,
        dict[str, Any],
    ],
    applied_corrections: dict[
        str,
        set[str],
    ],
    total_lessons: int,
    existing_teachers: dict[
        str,
        dict[str, Any],
    ],
    existing_same: list[
        tuple[
            str,
            str,
        ]
    ],
    conflicts: list[
        tuple[
            str,
            str,
            str,
        ]
    ],
):
    """
    Выводит полный предварительный
    отчёт перед импортом.
    """

    print(
        "=" * 78
    )

    print(
        "АНАЛИЗ СПРАВОЧНИКА "
        "ПРЕПОДАВАТЕЛЕЙ"
    )

    print(
        "=" * 78
    )

    print()

    print(
        "Файлы расписания:"
    )

    for path in schedule_files:
        print(
            f"  • {path.name}"
        )

    print()

    print(
        "Всего занятий просмотрено: "
        f"{total_lessons}"
    )

    print(
        "Уникальных преподавателей "
        "после исправлений: "
        f"{len(teachers)}"
    )

    print()

    print(
        "-" * 78
    )

    print(
        "ЯВНЫЕ ИСПРАВЛЕНИЯ"
    )

    print(
        "-" * 78
    )

    if not applied_corrections:
        print(
            "Исправления не применялись."
        )
    else:
        for canonical_name in sorted(
            applied_corrections
        ):
            for raw_name in sorted(
                applied_corrections[
                    canonical_name
                ]
            ):
                print(
                    f"  {raw_name} "
                    f"→ {canonical_name}"
                )

    print()

    print(
        "-" * 78
    )

    print(
        "FIRESTORE"
    )

    print(
        "-" * 78
    )

    print(
        "Документов teachers сейчас: "
        f"{len(existing_teachers)}"
    )

    print(
        "Будет подготовлено "
        "преподавателей: "
        f"{len(teachers)}"
    )

    print(
        "Уже существуют с тем же "
        "ID и именем: "
        f"{len(existing_same)}"
    )

    print(
        "Конфликтов ID: "
        f"{len(conflicts)}"
    )

    if conflicts:
        print()

        print(
            "КОНФЛИКТЫ:"
        )

        for (
            teacher_id,
            existing_name,
            new_name,
        ) in conflicts:
            print(
                f"  {teacher_id}"
            )

            print(
                "    Firestore: "
                f"{existing_name}"
            )

            print(
                "    Новый: "
                f"{new_name}"
            )

    print()

    print(
        "-" * 78
    )

    print(
        "БУДУЩИЕ ПРЕПОДАВАТЕЛИ"
    )

    print(
        "-" * 78
    )

    sorted_teachers = sorted(
        teachers.values(),
        key=lambda item: (
            item["name"].lower()
        ),
    )

    for index, teacher in enumerate(
        sorted_teachers,
        start=1,
    ):
        print()

        print(
            f"{index:3}. "
            f"{teacher['name']}"
        )

        print(
            "     ID: "
            f"{teacher['teacherId']}"
        )

        print(
            "     Упоминаний: "
            f"{teacher['mentions']}"
        )

        print(
            "     Группы: "
            + (
                ", ".join(
                    sorted(
                        teacher[
                            "groupIds"
                        ]
                    )
                )
                or "—"
            )
        )

        print(
            "     Предметы: "
            + (
                ", ".join(
                    sorted(
                        teacher[
                            "subjects"
                        ]
                    )
                )
                or "—"
            )
        )

        source_names = sorted(
            teacher[
                "sourceNames"
            ]
        )

        if (
            len(source_names) > 1
            or (
                source_names
                and
                source_names[0]
                != teacher["name"]
            )
        ):
            print(
                "     Исходные варианты: "
                + ", ".join(
                    source_names
                )
            )

    print()

    print(
        "=" * 78
    )

    print(
        "АНАЛИЗ ЗАВЕРШЁН"
    )

    print(
        "=" * 78
    )


def commit_teachers(
    db,
    teachers: dict[
        str,
        dict[str, Any],
    ],
    existing_teachers: dict[
        str,
        dict[str, Any],
    ],
):
    """
    Создаёт только отсутствующих
    преподавателей.

    Уже существующие документы
    не изменяются.
    """

    collection = db.collection(
        "teachers"
    )

    pending = []

    for teacher in teachers.values():
        teacher_id = teacher[
            "teacherId"
        ]

        if (
            teacher_id
            in existing_teachers
        ):
            continue

        pending.append(
            teacher
        )

    if not pending:
        print(
            "Новых преподавателей "
            "для записи нет."
        )

        return 0

    created = 0

    batch_size = 400

    for start in range(
        0,
        len(pending),
        batch_size,
    ):
        chunk = pending[
            start:
            start + batch_size
        ]

        batch = db.batch()

        for teacher in chunk:
            teacher_id = teacher[
                "teacherId"
            ]

            document = (
                build_firestore_document(
                    teacher
                )
            )

            reference = (
                collection.document(
                    teacher_id
                )
            )

            batch.create(
                reference,
                document,
            )

        batch.commit()

        created += len(
            chunk
        )

    return created


def parse_arguments():
    parser = argparse.ArgumentParser(
        description=(
            "Безопасный импорт "
            "преподавателей из "
            "расписания в Firestore"
        )
    )

    parser.add_argument(
        "files",
        nargs="*",
        help=(
            "JSON-файлы расписания. "
            "Если не указаны, "
            "используются 21.09 и 22.09."
        ),
    )

    parser.add_argument(
        "--commit",
        action="store_true",
        help=(
            "Реально записать "
            "преподавателей в Firestore"
        ),
    )

    return parser.parse_args()


def main():
    args = parse_arguments()

    if args.files:
        schedule_files = [
            Path(file).resolve()
            for file in args.files
        ]
    else:
        schedule_files = (
            DEFAULT_JSON_FILES
        )

    (
        teachers,
        applied_corrections,
        total_lessons,
    ) = collect_teachers(
        schedule_files
    )

    collisions = (
        check_teacher_id_collisions(
            teachers
        )
    )

    if collisions:
        print(
            "ОШИБКА: обнаружены "
            "коллизии ID преподавателей."
        )

        for (
            teacher_id,
            first_name,
            second_name,
        ) in collisions:
            print(
                f"{teacher_id}: "
                f"{first_name} / "
                f"{second_name}"
            )

        raise SystemExit(1)

    print(
        "Подключение к Firestore..."
    )

    db = initialize_firestore()

    existing_teachers = (
        load_existing_teachers(
            db
        )
    )

    (
        existing_same,
        conflicts,
    ) = analyze_existing_teachers(
        teachers,
        existing_teachers,
    )

    print_analysis(
        schedule_files,
        teachers,
        applied_corrections,
        total_lessons,
        existing_teachers,
        existing_same,
        conflicts,
    )

    if conflicts:
        print()

        print(
            "Импорт заблокирован: "
            "обнаружены конфликты ID."
        )

        raise SystemExit(1)

    if not args.commit:
        print()

        print(
            "=" * 78
        )

        print(
            "DRY RUN ЗАВЕРШЁН"
        )

        print(
            "=" * 78
        )

        print(
            "Firestore НЕ изменён."
        )

        print(
            "Подготовлено "
            "преподавателей: "
            f"{len(teachers)}"
        )

        print(
            "=" * 78
        )

        print()

        print(
            "Это был только "
            "предварительный просмотр."
        )

        print(
            "Никакие документы "
            "Firestore не были изменены."
        )

        print(
            "Для реальной записи "
            "существует флаг --commit."
        )

        return

    print()

    print(
        "Начинаю запись "
        "преподавателей..."
    )

    created = commit_teachers(
        db,
        teachers,
        existing_teachers,
    )

    print()

    print(
        "=" * 78
    )

    print(
        "ИМПОРТ ЗАВЕРШЁН"
    )

    print(
        "=" * 78
    )

    print(
        "Создано документов: "
        f"{created}"
    )

    print(
        "Существующие документы "
        "не изменялись."
    )

    print(
        "=" * 78
    )


if __name__ == "__main__":
    main()