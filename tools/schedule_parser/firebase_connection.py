import json
import os
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, firestore


BASE_DIR = Path(__file__).resolve().parent

SERVICE_ACCOUNT_PATH = (
    BASE_DIR / "service-account.json"
)

FIREBASE_SERVICE_ACCOUNT_ENV = (
    "FIREBASE_SERVICE_ACCOUNT_JSON"
)


def initialize_firebase() -> None:
    """
    Инициализирует Firebase Admin SDK.

    Приоритет авторизации:

    1. Локальный service-account.json.
    2. FIREBASE_SERVICE_ACCOUNT_JSON
       из переменной окружения.
    3. Application Default Credentials.
    """

    if firebase_admin._apps:
        return

    # Локальная разработка.
    if SERVICE_ACCOUNT_PATH.exists():
        credential = credentials.Certificate(
            str(SERVICE_ACCOUNT_PATH)
        )

        firebase_admin.initialize_app(
            credential
        )

        return

    # Production на Render и других
    # внешних хостингах.
    service_account_json = os.getenv(
        FIREBASE_SERVICE_ACCOUNT_ENV
    )

    if service_account_json:
        try:
            service_account_info = json.loads(
                service_account_json
            )
        except json.JSONDecodeError as error:
            raise RuntimeError(
                "Переменная "
                "FIREBASE_SERVICE_ACCOUNT_JSON "
                "содержит некорректный JSON."
            ) from error

        credential = credentials.Certificate(
            service_account_info
        )

        firebase_admin.initialize_app(
            credential
        )

        return

    # Google Cloud и другие окружения,
    # поддерживающие Application Default
    # Credentials.
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

    elif os.getenv(
        FIREBASE_SERVICE_ACCOUNT_ENV
    ):
        print(
            "Авторизация: "
            "FIREBASE_SERVICE_ACCOUNT_JSON"
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