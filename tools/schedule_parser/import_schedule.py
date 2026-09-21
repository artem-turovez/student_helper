import argparse
import hashlib
import json
import re
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any

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

    if not isinstance(data, dict):
        raise ValueError(
            "Корневой элемент JSON должен быть объектом."
        )

    lessons = data.get("lessons")

    if not isinstance(lessons, list):
        raise ValueError(
            "В JSON отсутствует список lessons."
        )

    return data


def normalize_name(
    value: str,
) -> str:
    value = str(value).lower().strip()

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
    teachers: list[dict[str, Any]] = []

    for document in (
        db.collection("teachers").stream()
    ):
        data = document.to_dict() or {}

        name = str(
            data.get(
                "name",
                "",
            )
            or ""
        ).strip()

        teachers.append(
            {
                "id": document.id,
                "name": name,
                "data": data,
            }
        )

    return teachers


def build_teacher_indexes(
    teachers: list[dict[str, Any]],
) -> tuple[
    dict[str, list[dict[str, Any]]],
    dict[str, list[dict[str, Any]]],
]:
    full_name_index: dict[
        str,
        list[dict[str, Any]],
    ] = defaultdict(list)

    surname_index: dict[
        str,
        list[dict[str, Any]],
    ] = defaultdict(list)

    for teacher in teachers:
        name = teacher["name"]

        normalized_name = normalize_name(
            name,
        )

        surname = get_surname(
            name,
        )

        if normalized_name:
            full_name_index[
                normalized_name
            ].append(teacher)

        if surname:
            surname_index[
                surname
            ].append(teacher)

    return (
        dict(full_name_index),
        dict(surname_index),
    )


def find_teacher(
    parsed_name: str,
    full_name_index: dict[
        str,
        list[dict[str, Any]],
    ],
    surname_index: dict[
        str,
        list[dict[str, Any]],
    ],
) -> tuple[
    str,
    dict[str, Any] | None,
    list[dict[str, Any]],
]:
    """
    Возвращает:

    status:
        matched
        unresolved
        ambiguous

    teacher:
        найденный преподаватель
        либо None

    candidates:
        список кандидатов при
        неоднозначном совпадении
    """

    parsed_normalized = normalize_name(
        parsed_name,
    )

    if not parsed_normalized:
        return (
            "unresolved",
            None,
            [],
        )

    exact_matches = full_name_index.get(
        parsed_normalized,
        [],
    )

    if len(exact_matches) == 1:
        return (
            "matched",
            exact_matches[0],
            exact_matches,
        )

    if len(exact_matches) > 1:
        return (
            "ambiguous",
            None,
            exact_matches,
        )

    parsed_surname = get_surname(
        parsed_name,
    )

    if not parsed_surname:
        return (
            "unresolved",
            None,
            [],
        )

    surname_matches = surname_index.get(
        parsed_surname,
        [],
    )

    if len(surname_matches) == 1:
        return (
            "matched",
            surname_matches[0],
            surname_matches,
        )

    if len(surname_matches) > 1:
        return (
            "ambiguous",
            None,
            surname_matches,
        )

    return (
        "unresolved",
        None,
        [],
    )


def make_lesson_id(
    lesson: dict[str, Any],
) -> str:
    """
    Создаём стабильный ID документа.

    При повторном импорте одного и того же
    занятия будет получен тот же ID.

    В ID входят:
    дата,
    группа,
    номер пары,
    время,
    подгруппа,
    предмет.

    Преподаватели и аудитории специально
    не входят в ID, чтобы исправление этих
    данных не создавало новый документ.
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

    date = str(
        lesson.get(
            "date",
            "",
        )
    ).replace(
        "-",
        "",
    )

    group = re.sub(
        r"[^0-9A-Za-zА-Яа-яЁё]",
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
    if not value:
        raise ValueError(
            "У занятия отсутствует дата."
        )

    return datetime.strptime(
        value,
        "%Y-%m-%d",
    )


def validate_lesson(
    lesson: dict[str, Any],
    index: int,
) -> None:
    required_fields = [
        "date",
        "groupId",
        "number",
        "time",
        "subject",
    ]

    missing = []

    for field in required_fields:
        value = lesson.get(field)

        if value is None:
            missing.append(field)
            continue

        if (
            isinstance(value, str)
            and not value.strip()
        ):
            missing.append(field)

    if missing:
        raise ValueError(
            "Некорректное занятие "
            f"#{index + 1}: отсутствуют поля "
            f"{', '.join(missing)}. "
            f"Данные: {lesson}"
        )

    if not isinstance(
        lesson.get(
            "teachers",
            [],
        ),
        list,
    ):
        raise ValueError(
            "Некорректное занятие "
            f"#{index + 1}: teachers "
            "должен быть списком."
        )

    if not isinstance(
        lesson.get(
            "rooms",
            [],
        ),
        list,
    ):
        raise ValueError(
            "Некорректное занятие "
            f"#{index + 1}: rooms "
            "должен быть списком."
        )


def prepare_lesson(
    lesson: dict[str, Any],
    full_name_index: dict[
        str,
        list[dict[str, Any]],
    ],
    surname_index: dict[
        str,
        list[dict[str, Any]],
    ],
) -> tuple[
    dict[str, Any],
    list[str],
    dict[str, list[str]],
    list[str],
]:
    parsed_teachers = [
        str(name).strip()
        for name in lesson.get(
            "teachers",
            [],
        )
        if str(name).strip()
    ]

    resolved_ids: list[str] = []
    matched: list[str] = []
    unresolved: list[str] = []

    ambiguous: dict[
        str,
        list[str],
    ] = {}

    all_resolved = True

    for teacher_name in parsed_teachers:
        (
            status,
            teacher,
            candidates,
        ) = find_teacher(
            teacher_name,
            full_name_index,
            surname_index,
        )

        if (
            status == "matched"
            and teacher is not None
        ):
            matched.append(
                teacher_name
            )

            resolved_ids.append(
                teacher["id"]
            )

            continue

        all_resolved = False

        if status == "ambiguous":
            ambiguous[
                teacher_name
            ] = [
                (
                    f"{candidate['name']} "
                    f"[{candidate['id']}]"
                )
                for candidate in candidates
            ]

            continue

        unresolved.append(
            teacher_name
        )

    # Критически важно:
    #
    # Flutter использует параллельные массивы:
    #
    # teachers[i] <-> teacherIds[i]
    #
    # Поэтому частично заполненный teacherIds
    # записывать нельзя.
    if (
        parsed_teachers
        and all_resolved
        and len(resolved_ids)
        == len(parsed_teachers)
    ):
        teacher_ids = resolved_ids
    else:
        teacher_ids = []

    firestore_lesson = {
        "date": parse_firestore_date(
            str(
                lesson["date"]
            )
        ),
        "groupId": str(
            lesson.get(
                "groupId",
                "",
            )
        ),
        "number": int(
            lesson.get(
                "number",
                0,
            )
        ),
        "time": str(
            lesson.get(
                "time",
                "",
            )
        ),
        "subject": str(
            lesson.get(
                "subject",
                "",
            )
        ),
        "teachers": parsed_teachers,
        "teacherIds": teacher_ids,
        "rooms": [
            str(room).strip()
            for room in lesson.get(
                "rooms",
                [],
            )
            if str(room).strip()
        ],
        "type": str(
            lesson.get(
                "type",
                "",
            )
            or ""
        ),
        "subgroup": (
            str(
                lesson.get(
                    "subgroup"
                )
            )
            if lesson.get(
                "subgroup"
            ) is not None
            else None
        ),
    }

    return (
        firestore_lesson,
        unresolved,
        ambiguous,
        matched,
    )


def check_document_id_collisions(
    prepared: list[
        tuple[
            str,
            dict[str, Any],
        ]
    ],
) -> None:
    by_id: dict[
        str,
        list[dict[str, Any]],
    ] = defaultdict(list)

    for (
        document_id,
        lesson,
    ) in prepared:
        by_id[
            document_id
        ].append(
            lesson
        )

    collisions = {
        document_id: lessons
        for (
            document_id,
            lessons,
        ) in by_id.items()
        if len(lessons) > 1
    }

    if not collisions:
        return

    print()
    print("=" * 70)
    print("ОШИБКА: ОБНАРУЖЕНЫ КОЛЛИЗИИ ID")
    print("=" * 70)

    for (
        document_id,
        lessons,
    ) in collisions.items():
        print()
        print(
            f"ID: {document_id}"
        )

        for lesson in lessons:
            print(
                "  "
                f"{lesson['groupId']} | "
                f"пара {lesson['number']} | "
                f"{lesson['time']} | "
                f"{lesson['subject']} | "
                f"подгруппа "
                f"{lesson['subgroup']}"
            )

    print()
    print(
        "Импорт остановлен, потому что "
        "несколько занятий получили "
        "одинаковый ID."
    )

    raise ValueError(
        "Обнаружены коллизии ID занятий."
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
        "Проверка структуры занятий..."
    )

    for index, lesson in enumerate(
        lessons
    ):
        if not isinstance(
            lesson,
            dict,
        ):
            raise ValueError(
                "Некорректное занятие "
                f"#{index + 1}: "
                "ожидался объект."
            )

        validate_lesson(
            lesson,
            index,
        )

    print(
        "Структура занятий корректна."
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

    (
        full_name_index,
        surname_index,
    ) = build_teacher_indexes(
        teachers,
    )

    prepared: list[
        tuple[
            str,
            dict[str, Any],
        ]
    ] = []

    matched_names: set[str] = set()
    unresolved_names: set[str] = set()

    ambiguous_names: dict[
        str,
        set[str],
    ] = defaultdict(set)

    lessons_with_teachers = 0
    lessons_fully_linked = 0
    lessons_not_linked = 0
    lessons_without_teachers = 0

    for lesson in lessons:
        document_id = make_lesson_id(
            lesson,
        )

        (
            firestore_lesson,
            unresolved,
            ambiguous,
            matched,
        ) = prepare_lesson(
            lesson,
            full_name_index,
            surname_index,
        )

        prepared.append(
            (
                document_id,
                firestore_lesson,
            )
        )

        matched_names.update(
            matched
        )

        unresolved_names.update(
            unresolved
        )

        for (
            name,
            candidates,
        ) in ambiguous.items():
            ambiguous_names[
                name
            ].update(
                candidates
            )

        parsed_teachers = (
            firestore_lesson[
                "teachers"
            ]
        )

        teacher_ids = (
            firestore_lesson[
                "teacherIds"
            ]
        )

        if not parsed_teachers:
            lessons_without_teachers += 1
        else:
            lessons_with_teachers += 1

            if (
                len(teacher_ids)
                == len(parsed_teachers)
            ):
                lessons_fully_linked += 1
            else:
                lessons_not_linked += 1

    check_document_id_collisions(
        prepared,
    )

    print()
    print(
        "Коллизий ID документов: 0"
    )

    print()
    print("-" * 70)
    print("ПРЕПОДАВАТЕЛИ")
    print("-" * 70)

    print(
        "Сопоставлено уникальных имён: "
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
        "Не найдено в Firestore: "
        f"{len(unresolved_names)}"
    )

    if unresolved_names:
        for name in sorted(
            unresolved_names
        ):
            print(
                f"  ! {name}"
            )

    print()

    print(
        "Неоднозначных имён: "
        f"{len(ambiguous_names)}"
    )

    if ambiguous_names:
        for name in sorted(
            ambiguous_names
        ):
            print(
                f"  ? {name}"
            )

            for candidate in sorted(
                ambiguous_names[name]
            ):
                print(
                    f"      -> {candidate}"
                )

    print()
    print("-" * 70)
    print("СВЯЗЫВАНИЕ ЗАНЯТИЙ")
    print("-" * 70)

    print(
        "Занятий с указанными "
        f"преподавателями: "
        f"{lessons_with_teachers}"
    )

    print(
        "Полностью связанных занятий: "
        f"{lessons_fully_linked}"
    )

    print(
        "Занятий без teacherIds из-за "
        "неполного/неоднозначного "
        f"сопоставления: "
        f"{lessons_not_linked}"
    )

    print(
        "Занятий без преподавателя "
        f"в исходном расписании: "
        f"{lessons_without_teachers}"
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
            "  teachers: "
            f"{lesson['teachers']}"
        )

        print(
            "  teacherIds: "
            f"{lesson['teacherIds']}"
        )

        print(
            "  rooms: "
            f"{lesson['rooms']}"
        )

        print(
            "  subgroup: "
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
        "Подготовлено документов: "
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

    check_document_id_collisions(
        prepared,
    )

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

            # Полностью заменяем документ.
            #
            # Это не оставляет старые поля
            # после изменения схемы данных.
            batch.set(
                reference,
                lesson,
                merge=False,
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
        "Обработано документов: "
        f"{written}"
    )

    print("=" * 70)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Безопасный импорт расписания "
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
            "Никакие документы Firestore "
            "не были изменены."
        )

        print(
            "Для реальной записи существует "
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