import argparse
import json
import re
from collections import defaultdict
from difflib import SequenceMatcher
from pathlib import Path
from typing import Any


def normalize_text(value: str) -> str:
    """Убирает лишние пробелы и приводит строку к аккуратному виду."""
    return re.sub(r"\s+", " ", str(value or "")).strip()


def normalize_name(value: str) -> str:
    """
    Нормализует имя для сравнения.

    Например:
        '  Сальникова ' -> 'сальникова'
    """
    return normalize_text(value).lower().replace("ё", "е")


def load_json(path: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Загружает JSON парсера. Поддерживает объект с lessons и обычный список."""
    with path.open("r", encoding="utf-8") as file:
        data = json.load(file)

    if isinstance(data, list):
        return {}, data

    if isinstance(data, dict):
        lessons = data.get("lessons")

        if not isinstance(lessons, list):
            raise ValueError(
                f"{path.name}: поле 'lessons' отсутствует или не является списком."
            )

        return data, lessons

    raise ValueError(
        f"{path.name}: неизвестная структура JSON."
    )


def similarity(first: str, second: str) -> float:
    """Возвращает коэффициент похожести двух фамилий."""
    return SequenceMatcher(
        None,
        normalize_name(first),
        normalize_name(second),
    ).ratio()


def collect_teachers(
    json_paths: list[Path],
) -> tuple[
    dict[str, dict[str, Any]],
    list[dict[str, Any]],
]:
    """
    Собирает преподавателей из всех переданных расписаний.

    Для каждого имени сохраняются:
    - количество появлений;
    - предметы;
    - группы;
    - даты;
    - исходные варианты написания;
    - примеры занятий.
    """
    teachers: dict[str, dict[str, Any]] = {}
    loaded_files: list[dict[str, Any]] = []

    for path in json_paths:
        metadata, lessons = load_json(path)

        loaded_files.append(
            {
                "path": path,
                "sourceFile": metadata.get("sourceFile"),
                "date": metadata.get("date"),
                "lessonCount": len(lessons),
            }
        )

        for lesson in lessons:
            lesson_teachers = lesson.get("teachers") or []

            if not isinstance(lesson_teachers, list):
                continue

            for raw_teacher in lesson_teachers:
                teacher = normalize_text(raw_teacher)

                if not teacher:
                    continue

                key = normalize_name(teacher)

                if key not in teachers:
                    teachers[key] = {
                        "displayName": teacher,
                        "variants": set(),
                        "count": 0,
                        "subjects": set(),
                        "groups": set(),
                        "dates": set(),
                        "examples": [],
                    }

                info = teachers[key]

                info["variants"].add(teacher)
                info["count"] += 1

                subject = normalize_text(lesson.get("subject", ""))
                group_id = normalize_text(lesson.get("groupId", ""))
                date = normalize_text(lesson.get("date", ""))

                if subject:
                    info["subjects"].add(subject)

                if group_id:
                    info["groups"].add(group_id)

                if date:
                    info["dates"].add(date)

                if len(info["examples"]) < 5:
                    info["examples"].append(
                        {
                            "date": date,
                            "groupId": group_id,
                            "number": lesson.get("number"),
                            "time": lesson.get("time"),
                            "subject": subject,
                            "rooms": lesson.get("rooms") or [],
                            "sourceText": lesson.get("sourceText", ""),
                        }
                    )

    return teachers, loaded_files


def find_similar_names(
    teachers: dict[str, dict[str, Any]],
    threshold: float = 0.72,
) -> list[tuple[str, str, float]]:
    """
    Ищет фамилии, которые могут быть вариантами одной фамилии.

    Это только подсказка для ручной проверки.
    Автоматического объединения здесь нет.
    """
    names = sorted(
        info["displayName"]
        for info in teachers.values()
    )

    pairs: list[tuple[str, str, float]] = []

    for index, first in enumerate(names):
        for second in names[index + 1:]:
            first_normalized = normalize_name(first)
            second_normalized = normalize_name(second)

            length_difference = abs(
                len(first_normalized) - len(second_normalized)
            )

            # Сильно отличающиеся по длине фамилии нам обычно неинтересны.
            if length_difference > 3:
                continue

            score = similarity(first, second)

            if score >= threshold:
                pairs.append((first, second, score))

    pairs.sort(key=lambda item: item[2], reverse=True)

    return pairs


def print_files(files: list[dict[str, Any]]) -> None:
    print("=" * 78)
    print("АНАЛИЗ ПРЕПОДАВАТЕЛЕЙ")
    print("=" * 78)

    print("\nФайлы:")

    total_lessons = 0

    for item in files:
        path: Path = item["path"]
        lesson_count = item["lessonCount"]
        total_lessons += lesson_count

        print(
            f"  • {path.name}: "
            f"{lesson_count} занятий"
        )

    print(f"\nВсего занятий просмотрено: {total_lessons}")


def print_teacher_list(
    teachers: dict[str, dict[str, Any]],
) -> None:
    print("\n" + "-" * 78)
    print("НАЙДЕННЫЕ ПРЕПОДАВАТЕЛИ")
    print("-" * 78)

    sorted_teachers = sorted(
        teachers.values(),
        key=lambda item: item["displayName"].lower(),
    )

    print(f"\nУникальных вариантов имён: {len(sorted_teachers)}\n")

    for index, info in enumerate(sorted_teachers, start=1):
        subjects = sorted(info["subjects"])
        groups = sorted(info["groups"])
        dates = sorted(info["dates"])

        print(
            f"{index:>3}. {info['displayName']} "
            f"— {info['count']} упомин."
        )

        if subjects:
            print(
                "     Предметы: "
                + ", ".join(subjects)
            )

        if groups:
            print(
                "     Группы: "
                + ", ".join(groups)
            )

        if dates:
            print(
                "     Даты: "
                + ", ".join(dates)
            )


def print_similar_names(
    teachers: dict[str, dict[str, Any]],
    pairs: list[tuple[str, str, float]],
) -> None:
    print("\n" + "-" * 78)
    print("ПОХОЖИЕ ФАМИЛИИ — НУЖНО ПРОВЕРИТЬ")
    print("-" * 78)

    if not pairs:
        print("\nПодозрительно похожих фамилий не найдено.")
        return

    print(
        "\nЭто НЕ означает, что фамилии одинаковые.\n"
        "Скрипт только показывает возможные ошибки распознавания/парсинга.\n"
    )

    lookup = {
        info["displayName"]: info
        for info in teachers.values()
    }

    for first, second, score in pairs:
        first_info = lookup[first]
        second_info = lookup[second]

        print(
            f"{first}  <->  {second} "
            f"({score * 100:.1f}%)"
        )

        print(
            f"  {first}: "
            f"{first_info['count']} упомин., "
            f"группы: {', '.join(sorted(first_info['groups']))}"
        )

        print(
            f"  {second}: "
            f"{second_info['count']} упомин., "
            f"группы: {', '.join(sorted(second_info['groups']))}"
        )

        print()


def print_examples_for_suspicious_names(
    teachers: dict[str, dict[str, Any]],
    pairs: list[tuple[str, str, float]],
) -> None:
    if not pairs:
        return

    print("-" * 78)
    print("ПРИМЕРЫ ИЗ РАСПИСАНИЯ")
    print("-" * 78)

    suspicious_names = set()

    for first, second, _ in pairs:
        suspicious_names.add(first)
        suspicious_names.add(second)

    lookup = {
        info["displayName"]: info
        for info in teachers.values()
    }

    for name in sorted(suspicious_names):
        info = lookup[name]

        print(f"\n{name}")

        for example in info["examples"]:
            print(
                f"  {example['date']} | "
                f"{example['groupId']} | "
                f"пара {example['number']} | "
                f"{example['subject']}"
            )

            if example["rooms"]:
                print(
                    "    Аудитории: "
                    + ", ".join(example["rooms"])
                )

            source_text = normalize_text(
                example.get("sourceText", "")
            )

            if source_text:
                print(
                    f"    Исходный текст: {source_text}"
                )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Анализ преподавателей в JSON-файлах расписания."
        )
    )

    parser.add_argument(
        "json_files",
        nargs="+",
        help="Один или несколько JSON-файлов расписания.",
    )

    parser.add_argument(
        "--similarity",
        type=float,
        default=0.72,
        help=(
            "Минимальный коэффициент похожести фамилий "
            "(по умолчанию 0.72)."
        ),
    )

    args = parser.parse_args()

    paths = [
        Path(value).expanduser().resolve()
        for value in args.json_files
    ]

    for path in paths:
        if not path.exists():
            raise FileNotFoundError(
                f"Файл не найден: {path}"
            )

    teachers, loaded_files = collect_teachers(paths)

    similar_pairs = find_similar_names(
        teachers,
        threshold=args.similarity,
    )

    print_files(loaded_files)
    print_teacher_list(teachers)
    print_similar_names(teachers, similar_pairs)
    print_examples_for_suspicious_names(
        teachers,
        similar_pairs,
    )

    print("\n" + "=" * 78)
    print("АНАЛИЗ ЗАВЕРШЁН")
    print("=" * 78)
    print(
        f"Уникальных вариантов преподавателей: {len(teachers)}"
    )
    print(
        f"Подозрительно похожих пар: {len(similar_pairs)}"
    )
    print("Firestore НЕ изменён.")
    print("=" * 78)


if __name__ == "__main__":
    main()