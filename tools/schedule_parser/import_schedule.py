import argparse
import hashlib
import json
import re
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from google.cloud.firestore_v1.base_query import FieldFilter
from firebase_connection import get_firestore_client
from teacher_names import (
    normalize_teacher_name,
    get_teacher_surname_key,
    is_valid_teacher_name,
)


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

        surname = get_teacher_surname_key(
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

    canonical_name = normalize_teacher_name(
        parsed_name,
    )

    parsed_normalized = normalize_name(
        canonical_name,
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

    parsed_surname = get_teacher_surname_key(
        canonical_name,
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

    # Если корректная фамилия отсутствует в Firestore, это не ошибка:
    # при публикации schedule_api создаст преподавателя автоматически.
    # Используем тот же стабильный teacherId, что и teacher_importer.
    if is_valid_teacher_name(canonical_name):
        from teacher_importer import make_teacher_id

        new_teacher = {
            "id": make_teacher_id(canonical_name),
            "name": canonical_name,
            "data": {},
            "isNew": True,
        }

        return (
            "matched",
            new_teacher,
            [new_teacher],
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

    return (
        datetime.strptime(
            value,
            "%Y-%m-%d",
        )
        .replace(
            tzinfo=timezone.utc,
        )
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
    source_teachers = [
        str(name).strip()
        for name in lesson.get(
            "teachers",
            [],
        )
        if str(name).strip()
    ]

    # В Firestore сохраняем уже канонические
    # имена преподавателей.
    #
    # Например:
    # Бтрим -> Бутрим
    # Корнлова -> Корнилова
    parsed_teachers = [
        normalize_teacher_name(name)
        for name in source_teachers
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
def normalize_value_for_compare(
    value: Any,
) -> Any:
    """
    Приводит значения Firestore и нового
    расписания к одинаковому виду для
    безопасного сравнения.
    """

    if isinstance(
        value,
        datetime,
    ):
        if value.tzinfo is None:
            value = value.replace(
                tzinfo=timezone.utc,
            )

        return (
            value
            .astimezone(timezone.utc)
            .isoformat()
        )

    if isinstance(
        value,
        list,
    ):
        return [
            normalize_value_for_compare(item)
            for item in value
        ]

    if isinstance(
        value,
        dict,
    ):
        return {
            key: normalize_value_for_compare(
                item
            )
            for key, item in value.items()
        }

    return value


def lessons_equal(
    existing: dict[str, Any],
    prepared: dict[str, Any],
) -> bool:
    """
    Сравниваем только поля, которыми
    управляет импорт расписания.
    """

    managed_fields = [
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
    ]

    existing_managed = {
        field: existing.get(field)
        for field in managed_fields
    }

    prepared_managed = {
        field: prepared.get(field)
        for field in managed_fields
    }

    return (
        normalize_value_for_compare(
            existing_managed
        )
        ==
        normalize_value_for_compare(
            prepared_managed
        )
    )


def load_existing_lessons_for_date(
    db,
    schedule_date: str,
) -> dict[str, dict[str, Any]]:
    """
    Загружает из Firestore только занятия
    импортируемой даты.
    """

    start = parse_firestore_date(
        schedule_date
    )

    end = start + timedelta(
        days=1
    )

    query = (
        db.collection("lessons")
        .where(
            filter=FieldFilter(
                "date",
                ">=",
                start,
            )
        )
        .where(
            filter=FieldFilter(
                "date",
                "<",
                end,
            )
        )
    )

    existing: dict[
        str,
        dict[str, Any],
    ] = {}

    for document in query.stream():
        existing[document.id] = (
            document.to_dict()
            or {}
        )

    return existing


def build_sync_plan(
    db,
    schedule_date: str,
    prepared: list[
        tuple[
            str,
            dict[str, Any],
        ]
    ],
) -> dict[str, Any]:
    """
    Сравнивает новое расписание с Firestore.

    Никаких изменений базы эта функция
    не выполняет.
    """

    existing = load_existing_lessons_for_date(
        db,
        schedule_date,
    )

    prepared_by_id = {
        document_id: lesson
        for document_id, lesson in prepared
    }

    create_ids: list[str] = []
    update_ids: list[str] = []
    unchanged_ids: list[str] = []

    for (
        document_id,
        lesson,
    ) in prepared:
        old_lesson = existing.get(
            document_id
        )

        if old_lesson is None:
            create_ids.append(
                document_id
            )
            continue

        if lessons_equal(
            old_lesson,
            lesson,
        ):
            unchanged_ids.append(
                document_id
            )
        else:
            update_ids.append(
                document_id
            )

    delete_ids = sorted(
        set(existing)
        - set(prepared_by_id)
    )

    return {
        "date": schedule_date,
        "existing": existing,
        "prepared": prepared_by_id,
        "create": sorted(create_ids),
        "update": sorted(update_ids),
        "unchanged": sorted(
            unchanged_ids
        ),
        "delete": delete_ids,
    }


def print_sync_plan(
    plan: dict[str, Any],
) -> None:
    print()
    print("=" * 70)
    print(
        "ПЛАН СИНХРОНИЗАЦИИ "
        f"ЗА {plan['date']}"
    )
    print("=" * 70)

    print(
        "В Firestore сейчас: "
        f"{len(plan['existing'])}"
    )

    print(
        "В новом расписании: "
        f"{len(plan['prepared'])}"
    )

    print()
    print(
        "Создать: "
        f"{len(plan['create'])}"
    )

    print(
        "Обновить: "
        f"{len(plan['update'])}"
    )

    print(
        "Без изменений: "
        f"{len(plan['unchanged'])}"
    )

    print(
        "Удалить устаревших: "
        f"{len(plan['delete'])}"
    )

    if plan["delete"]:
        print()
        print(
            "Устаревшие документы, "
            "которые будут удалены "
            "только при --commit:"
        )

        for document_id in plan[
            "delete"
        ]:
            lesson = plan[
                "existing"
            ].get(
                document_id,
                {},
            )

            print(
                "  - "
                f"{document_id} | "
                f"{lesson.get('groupId')} | "
                f"пара "
                f"{lesson.get('number')} | "
                f"{lesson.get('time')} | "
                f"{lesson.get('subject')}"
            )

    print()
    print(
        "На этапе dry-run "
        "Firestore НЕ изменяется."
    )
    print("=" * 70)

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
    if not lessons:
        raise ValueError(
            "JSON не содержит занятий. "
            "Импорт пустого расписания заблокирован, "
            "чтобы не удалить расписание "
            "за весь день."
        )
    schedule_date = str(
        data.get(
            "date",
            "",
        )
        or ""
    ).strip()

    if not schedule_date:
        raise ValueError(
            "В JSON отсутствует корневая дата "
            "расписания."
        )

    # Проверяем формат даты заранее.
    parse_firestore_date(
        schedule_date
    )

    wrong_date_lessons = []

    for index, lesson in enumerate(
        lessons
    ):
        if not isinstance(
            lesson,
            dict,
        ):
            continue

        lesson_date = str(
            lesson.get(
                "date",
                "",
            )
            or ""
        ).strip()

        if lesson_date != schedule_date:
            wrong_date_lessons.append(
                (
                    index + 1,
                    lesson_date,
                    lesson.get(
                        "groupId",
                        "",
                    ),
                )
            )

    if wrong_date_lessons:
        print()
        print("=" * 70)
        print(
            "ИМПОРТ ЗАБЛОКИРОВАН: "
            "НЕСОВПАДЕНИЕ ДАТ"
        )
        print("=" * 70)

        print(
            "Корневая дата расписания: "
            f"{schedule_date}"
        )

        for (
            index,
            lesson_date,
            group_id,
        ) in wrong_date_lessons[:20]:
            print(
                f"  Занятие #{index}: "
                f"date={lesson_date!r}, "
                f"groupId={group_id!r}"
            )

        raise ValueError(
            "В JSON обнаружены занятия "
            "с другой датой."
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

    teacher_problems: list[dict[str, Any]] = []

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
        if unresolved or ambiguous:
            teacher_problems.append(
                {
                    "date": str(
                        lesson.get(
                            "date",
                            "",
                        )
                    ),
                    "groupId": str(
                        lesson.get(
                            "groupId",
                            "",
                        )
                    ),
                    "number": lesson.get(
                        "number"
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
                    "unresolved": list(
                        unresolved
                    ),
                    "ambiguous": dict(
                        ambiguous
                    ),
                }
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
    if teacher_problems:
        print()
        print("-" * 70)
        print("ПРОБЛЕМНЫЕ ЗАНЯТИЯ")
        print("-" * 70)

        for problem in teacher_problems:
            print()

            print(
                f"{problem['date']} | "
                f"{problem['groupId']} | "
                f"пара {problem['number']} | "
                f"{problem['time']} | "
                f"{problem['subject']}"
            )

            for name in problem[
                "unresolved"
            ]:
                print(
                    "  НЕ НАЙДЕН: "
                    f"{name}"
                )

            for (
                name,
                candidates,
            ) in problem[
                "ambiguous"
            ].items():
                print(
                    "  НЕОДНОЗНАЧНО: "
                    f"{name}"
                )

                for candidate in candidates:
                    print(
                        "    -> "
                        f"{candidate}"
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
    if (
        unresolved_names
        or ambiguous_names
        or lessons_not_linked > 0
    ):
        print()
        print("=" * 70)
        print(
            "ИМПОРТ ЗАБЛОКИРОВАН"
        )
        print("=" * 70)

        print(
            "Обнаружены занятия, "
            "для которых не удалось "
            "однозначно определить "
            "преподавателей."
        )

        print(
            "Firestore НЕ изменён."
        )

        print(
            "Исправьте исходные данные "
            "или teacher_names.py, "
            "после чего повторите "
            "проверку."
        )

        print("=" * 70)

        problem_parts: list[str] = []

        if unresolved_names:
            problem_parts.append(
                "не распознаны: "
                + ", ".join(sorted(unresolved_names))
            )

        if ambiguous_names:
            ambiguous_parts = []

            for name in sorted(ambiguous_names):
                candidates = ", ".join(
                    sorted(ambiguous_names[name])
                )

                ambiguous_parts.append(
                    f"{name} (кандидаты: {candidates})"
                )

            problem_parts.append(
                "неоднозначные: "
                + "; ".join(ambiguous_parts)
            )

        if lessons_not_linked > 0:
            problem_parts.append(
                "занятий без полного teacherIds: "
                f"{lessons_not_linked}"
            )

        raise ValueError(
            "Импорт заблокирован. "
            + " | ".join(problem_parts)
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
    plan: dict[str, Any],
) -> None:
    """
    Применяет уже рассчитанный план синхронизации.

    Создаются только новые документы.
    Обновляются только изменённые документы.
    Удаляются только документы из plan["delete"].
    Неизменённые документы не записываются повторно.
    """

    print()
    print("=" * 70)
    print("ЗАПИСЬ В FIRESTORE")
    print("=" * 70)

    create_ids = list(
        plan.get(
            "create",
            [],
        )
    )

    update_ids = list(
        plan.get(
            "update",
            [],
        )
    )

    delete_ids = list(
        plan.get(
            "delete",
            [],
        )
    )

    prepared = plan.get(
        "prepared",
        {},
    )

    operations: list[
        tuple[
            str,
            str,
        ]
    ] = []

    for document_id in create_ids:
        operations.append(
            (
                "set",
                document_id,
            )
        )

    for document_id in update_ids:
        operations.append(
            (
                "set",
                document_id,
            )
        )

    for document_id in delete_ids:
        operations.append(
            (
                "delete",
                document_id,
            )
        )

    if not operations:
        print(
            "Изменений нет. "
            "Firestore не изменён."
        )
        print("=" * 70)
        return

    batch_size = 400
    processed = 0

    for start in range(
        0,
        len(operations),
        batch_size,
    ):
        chunk = operations[
            start:start + batch_size
        ]

        batch = db.batch()

        for (
            action,
            document_id,
        ) in chunk:
            reference = (
                db.collection("lessons")
                .document(document_id)
            )

            if action == "delete":
                batch.delete(
                    reference
                )
                continue

            lesson = prepared.get(
                document_id
            )

            if lesson is None:
                raise ValueError(
                    "Не найдены данные "
                    "подготовленного занятия: "
                    f"{document_id}"
                )

            batch.set(
                reference,
                lesson,
                merge=False,
            )

        batch.commit()

        processed += len(
            chunk
        )

        print(
            "Обработано операций: "
            f"{processed}/"
            f"{len(operations)}"
        )

    print()
    print(
        "Синхронизация завершена."
    )

    print(
        "Создано: "
        f"{len(create_ids)}"
    )

    print(
        "Обновлено: "
        f"{len(update_ids)}"
    )

    print(
        "Удалено: "
        f"{len(delete_ids)}"
    )

    print(
        "Без изменений: "
        f"{len(plan.get('unchanged', []))}"
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
    parser.add_argument(
        "--allow-delete",
        action="store_true",
        help=(
            "Разрешить удаление устаревших "
            "занятий при --commit"
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
    schedule_date = str(
        data.get(
            "date",
            "",
        )
        or ""
    ).strip()

    sync_plan = build_sync_plan(
        db,
        schedule_date,
        prepared,
    ) 

    print_sync_plan(
        sync_plan
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

    if (
        sync_plan["delete"]
        and not args.allow_delete
    ):
        print()
        print("=" * 70)
        print(
            "ЗАПИСЬ ЗАБЛОКИРОВАНА"
        )
        print("=" * 70)

        print(
            "План содержит удаление "
            f"{len(sync_plan['delete'])} "
            "устаревших занятий."
        )

        print(
            "Для удаления необходимо "
            "явно добавить флаг "
            "--allow-delete."
        )

        print(
            "Firestore НЕ изменён."
        )

        raise ValueError(
            "Удаление заблокировано без "
            "--allow-delete."
        )

    print()
    print(
        "ВНИМАНИЕ: включён режим --commit."
    )

    commit_import(
        db,
        sync_plan,
    )


if __name__ == "__main__":
    main()