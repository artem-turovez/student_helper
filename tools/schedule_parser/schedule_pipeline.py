import argparse
import subprocess
import sys
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
PARSED_DIR = BASE_DIR / "parsed"


def run_command(
    command: list[str],
    title: str,
) -> None:
    print()
    print("=" * 80)
    print(title)
    print("=" * 80)
    print("$", " ".join(command))
    print()

    result = subprocess.run(
        command,
        cwd=BASE_DIR,
    )

    if result.returncode != 0:
        print()
        print("=" * 80)
        print("PIPELINE ОСТАНОВЛЕН")
        print("=" * 80)
        print(
            f"Этап завершился с кодом "
            f"{result.returncode}."
        )
        print("=" * 80)

        sys.exit(
            result.returncode
        )


def find_parsed_json(
    pdf_path: Path,
) -> Path:
    json_path = (
        PARSED_DIR
        / f"{pdf_path.stem}.json"
    )

    if not json_path.exists():
        print()
        print("=" * 80)
        print("ОШИБКА")
        print("=" * 80)
        print(
            "После парсинга не найден JSON:"
        )
        print(json_path)
        sys.exit(1)

    return json_path


def ask_for_confirmation(
    pdf_path: Path,
) -> bool:
    print()
    print("=" * 80)
    print("ПОДТВЕРЖДЕНИЕ ПУБЛИКАЦИИ")
    print("=" * 80)
    print(
        "Все проверки успешно пройдены."
    )
    print()
    print(
        f"PDF: {pdf_path.name}"
    )
    print()
    print(
        "Следующий шаг изменит данные "
        "в Firestore."
    )
    print(
        "Будут записаны занятия "
        "из этого расписания."
    )
    print()
    print(
        "Для подтверждения введи:"
    )
    print()
    print("PUBLISH")
    print()

    answer = input(
        "> "
    ).strip()

    return answer == "PUBLISH"


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Безопасный pipeline расписания: "
            "PDF -> JSON -> аудит -> "
            "dry-run -> публикация."
        )
    )

    parser.add_argument(
        "pdf",
        help=(
            "Путь к PDF-файлу "
            "расписания."
        ),
    )

    parser.add_argument(
        "--commit",
        action="store_true",
        help=(
            "После успешных проверок "
            "разрешить публикацию "
            "в Firestore."
        ),
    )

    args = parser.parse_args()

    pdf_path = Path(
        args.pdf
    )

    if not pdf_path.is_absolute():
        pdf_path = (
            BASE_DIR
            / pdf_path
        )

    pdf_path = pdf_path.resolve()

    if not pdf_path.exists():
        print(
            f"Файл не найден: {pdf_path}"
        )
        sys.exit(1)

    if not pdf_path.is_file():
        print(
            "Указанный путь "
            "не является файлом:"
        )
        print(pdf_path)
        sys.exit(1)

    if (
        pdf_path.suffix.lower()
        != ".pdf"
    ):
        print(
            "Необходимо передать PDF-файл."
        )
        sys.exit(1)

    print()
    print("=" * 80)
    print("ОБРАБОТКА РАСПИСАНИЯ")
    print("=" * 80)
    print(
        f"PDF: {pdf_path.name}"
    )
    print()

    if args.commit:
        print(
            "Режим: ПРОВЕРКА + ПУБЛИКАЦИЯ"
        )
    else:
        print(
            "Режим: ТОЛЬКО ПРОВЕРКА"
        )

    print()
    print("Pipeline выполнит:")
    print("  1. Парсинг PDF")
    print("  2. Аудит JSON")
    print("  3. Dry-run Firestore")

    if args.commit:
        print(
            "  4. Подтверждение администратора"
        )
        print(
            "  5. Публикация в Firestore"
        )

    print("=" * 80)

    # -------------------------------------------------
    # 1. PARSER
    # -------------------------------------------------

    run_command(
        [
            sys.executable,
            "parser.py",
            str(pdf_path),
        ],
        "ЭТАП 1 — ПАРСИНГ PDF",
    )

    json_path = find_parsed_json(
        pdf_path
    )

    # -------------------------------------------------
    # 2. AUDIT
    # -------------------------------------------------

    run_command(
        [
            sys.executable,
            "schedule_audit.py",
            str(json_path),
        ],
        "ЭТАП 2 — АУДИТ РАСПИСАНИЯ",
    )

    # -------------------------------------------------
    # 3. DRY RUN
    # -------------------------------------------------

    run_command(
        [
            sys.executable,
            "import_schedule.py",
            str(json_path),
        ],
        "ЭТАП 3 — DRY-RUN FIRESTORE",
    )

    # -------------------------------------------------
    # CHECK-ONLY MODE
    # -------------------------------------------------

    if not args.commit:
        print()
        print("=" * 80)
        print(
            "ПРОВЕРКА УСПЕШНО ЗАВЕРШЕНА"
        )
        print("=" * 80)

        print(
            "✓ PDF успешно распарсен"
        )
        print(
            "✓ JSON прошёл аудит"
        )
        print(
            "✓ Firestore dry-run прошёл"
        )

        print()
        print(
            "Firestore НЕ изменён."
        )

        print()
        print(
            "Для публикации выполни:"
        )
        print()

        print(
            "python schedule_pipeline.py "
            f'"{pdf_path}" --commit'
        )

        print("=" * 80)
        return

    # -------------------------------------------------
    # 4. CONFIRMATION
    # -------------------------------------------------

    if not ask_for_confirmation(
        pdf_path
    ):
        print()
        print("=" * 80)
        print(
            "ПУБЛИКАЦИЯ ОТМЕНЕНА"
        )
        print("=" * 80)
        print(
            "Firestore НЕ изменён."
        )
        print("=" * 80)
        return

    # -------------------------------------------------
    # 5. COMMIT
    # -------------------------------------------------

    run_command(
        [
            sys.executable,
            "import_schedule.py",
            str(json_path),
            "--commit",
        ],
        "ЭТАП 5 — ПУБЛИКАЦИЯ В FIRESTORE",
    )

    print()
    print("=" * 80)
    print(
        "РАСПИСАНИЕ ОПУБЛИКОВАНО"
    )
    print("=" * 80)

    print(
        f"PDF:  {pdf_path.name}"
    )
    print(
        f"JSON: {json_path}"
    )

    print()
    print(
        "✓ PDF успешно распарсен"
    )
    print(
        "✓ JSON прошёл аудит"
    )
    print(
        "✓ Firestore dry-run прошёл"
    )
    print(
        "✓ Публикация подтверждена"
    )
    print(
        "✓ Данные записаны в Firestore"
    )

    print("=" * 80)


if __name__ == "__main__":
    main()