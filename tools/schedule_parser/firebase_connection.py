from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore


BASE_DIR = Path(__file__).resolve().parent

SERVICE_ACCOUNT_PATH = (
    BASE_DIR / "service-account.json"
)


def initialize_firebase() -> None:
    """
    Инициализирует Firebase Admin SDK.

    Локальная разработка:
    используется service-account.json,
    если файл существует.

    Production:
    если локального файла нет,
    Firebase Admin SDK использует
    Application Default Credentials
    окружения сервера.
    """

    if firebase_admin._apps:
        return

    if SERVICE_ACCOUNT_PATH.exists():
        credential = credentials.Certificate(
            str(SERVICE_ACCOUNT_PATH)
        )

        firebase_admin.initialize_app(
            credential
        )

        return

    firebase_admin.initialize_app()


def get_firestore_client():
    initialize_firebase()

    return firestore.client()


def test_connection() -> None:
    print("=" * 60)
    print("ПРОВЕРКА FIREBASE")
    print("=" * 60)

    if SERVICE_ACCOUNT_PATH.exists():
        print(
            "Авторизация: "
            "локальный service-account.json"
        )
    else:
        print(
            "Авторизация: "
            "Application Default Credentials"
        )

    print(
        "Подключение к Firestore..."
    )

    db = get_firestore_client()

    # Получаем небольшое количество документов
    # только для проверки чтения.
    #
    # Никаких записей, изменений или удалений
    # этот код не выполняет.
    documents = (
        db.collection("teachers")
        .limit(3)
        .stream()
    )

    teachers = list(
        documents
    )

    print(
        "Подключение успешно."
    )

    print(
        f"Получено преподавателей "
        f"для проверки: {len(teachers)}"
    )

    for document in teachers:
        data = document.to_dict()

        print(
            f"  {document.id}: "
            f"{data.get('name', 'Без имени')}"
        )

    print("=" * 60)
    print(
        "Firebase Admin SDK работает."
    )
    print("=" * 60)


if __name__ == "__main__":
    test_connection()