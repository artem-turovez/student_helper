import re


# Только подтверждённые исправления опечаток.
# Никакого fuzzy-исправления автоматически:
# похожие фамилии могут принадлежать разным людям.
TEACHER_NAME_CORRECTIONS = {
    "Бтрим": "Бутрим",
    "Корнлова": "Корнилова",
}


def normalize_spaces(
    value: str,
) -> str:
    return re.sub(
        r"\s+",
        " ",
        str(value or ""),
    ).strip()


def normalize_dashes(
    value: str,
) -> str:
    """
    Нормализует только вид дефиса.

    Важно:
    ведущие и конечные дефисы НЕ удаляются,
    потому что они могут означать ошибку
    разбора PDF.

    Примеры:

    "Щербакова – Шаблова"
        -> "Щербакова-Шаблова"

    "-Шаблова"
        -> "-Шаблова"

    "Шаблова-"
        -> "Шаблова-"
    """

    name = str(value or "")

    name = (
        name
        .replace("–", "-")
        .replace("—", "-")
    )

    name = re.sub(
        r"\s*-\s*",
        "-",
        name,
    )

    return name


def normalize_teacher_name(
    value: str,
) -> str:
    """
    Выполняет только безопасную
    нормализацию имени преподавателя.

    Никакие подозрительные ведущие или
    конечные символы автоматически
    не удаляются.
    """

    name = normalize_spaces(value)
    name = normalize_dashes(name)

    if not name:
        return ""

    return TEACHER_NAME_CORRECTIONS.get(
        name,
        name,
    )


def normalize_teacher_key(
    value: str,
) -> str:
    name = normalize_teacher_name(value)

    return (
        name
        .lower()
        .replace("ё", "е")
        .strip()
    )


def get_teacher_surname(
    value: str,
) -> str:
    name = normalize_teacher_name(value)

    if not name:
        return ""

    return name.split()[0]


def get_teacher_surname_key(
    value: str,
) -> str:
    surname = get_teacher_surname(value)

    return (
        surname
        .lower()
        .replace("ё", "е")
        .strip()
    )


def is_valid_teacher_name(
    value: str,
) -> bool:
    """
    Структурная проверка фамилии.

    Функция не подтверждает существование
    преподавателя, а только проверяет,
    что значение похоже на корректную
    фамилию.
    """

    name = normalize_teacher_name(value)

    if not name:
        return False

    # Сейчас парсер расписания должен
    # возвращать именно фамилию.
    if " " in name:
        return False

    if any(
        char.isdigit()
        for char in name
    ):
        return False

    if (
        len(name) < 3
        or len(name) > 40
    ):
        return False

    # Обычная фамилия:
    # Корнилова
    #
    # Составная фамилия:
    # Щербакова-Шаблова
    #
    # Но:
    # -Шаблова
    # Шаблова-
    # --Шаблова
    # уже не пройдут.
    return (
        re.fullmatch(
            r"[А-ЯЁІЎ][а-яёіў]+"
            r"(?:-[А-ЯЁІЎ][а-яёіў]+)*",
            name,
        )
        is not None
    )