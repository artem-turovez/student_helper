import re


# Явно подтверждённые опечатки
# в исходных PDF-расписаниях.
#
# Здесь нельзя использовать
# автоматическое "похожее имя",
# потому что похожие фамилии могут
# принадлежать разным преподавателям.
TEACHER_NAME_CORRECTIONS = {
    "Бтрим": "Бутрим",
    "Корнлова": "Корнилова",
}


def normalize_spaces(
    value: str,
) -> str:
    """
    Убирает лишние пробелы
    и переносы строк.
    """

    return re.sub(
        r"\s+",
        " ",
        str(value),
    ).strip()


def normalize_teacher_name(
    value: str,
) -> str:
    """
    Приводит имя преподавателя
    к каноническому варианту.

    Например:

    Бтрим
    ->
    Бутрим

    Корнлова
    ->
    Корнилова
    """

    name = normalize_spaces(
        value
    )

    if not name:
        return ""

    return (
        TEACHER_NAME_CORRECTIONS
        .get(
            name,
            name,
        )
    )


def normalize_teacher_key(
    value: str,
) -> str:
    """
    Создаёт строку для безопасного
    сравнения имён.

    Используется только для поиска
    совпадений, а не для отображения.
    """

    name = normalize_teacher_name(
        value
    )

    return (
        name
        .lower()
        .replace("ё", "е")
        .strip()
    )


def get_teacher_surname(
    value: str,
) -> str:
    """
    Возвращает фамилию из полного
    имени преподавателя.

    Например:

    Петрова Анна Сергеевна
    ->
    Петрова
    """

    name = normalize_teacher_name(
        value
    )

    if not name:
        return ""

    return name.split()[0]


def get_teacher_surname_key(
    value: str,
) -> str:
    """
    Нормализованный ключ фамилии.

    Например:

    Петрова Анна Сергеевна
    ->
    петрова
    """

    surname = get_teacher_surname(
        value
    )

    return (
        surname
        .lower()
        .replace("ё", "е")
        .strip()
    )