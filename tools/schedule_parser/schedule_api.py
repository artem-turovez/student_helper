from pathlib import Path
import tempfile

import firebase_admin
from fastapi import (
    Depends,
    FastAPI,
    File,
    Header,
    HTTPException,
    UploadFile,
    status,
)
from firebase_admin import auth, credentials, firestore

from parser import parse_pdf
from schedule_audit import audit_json


BASE_DIR = Path(__file__).resolve().parent
SERVICE_ACCOUNT_PATH = BASE_DIR / "service-account.json"

MAX_PDF_SIZE = 15 * 1024 * 1024


def initialize_firebase() -> None:
    if firebase_admin._apps:
        return

    if not SERVICE_ACCOUNT_PATH.exists():
        raise RuntimeError(
            "Не найден service-account.json"
        )

    credential = credentials.Certificate(
        str(SERVICE_ACCOUNT_PATH)
    )

    firebase_admin.initialize_app(
        credential
    )


initialize_firebase()

db = firestore.client()

app = FastAPI(
    title="Student Helper Schedule API",
    version="1.0.0",
)


@app.get("/")
def root() -> dict[str, str]:
    return {
        "service": "Student Helper Schedule API",
        "status": "running",
    }


@app.get("/health")
def health() -> dict[str, str]:
    return {
        "status": "ok",
    }


async def require_admin(
    authorization: str | None = Header(
        default=None
    ),
) -> dict:
    if authorization is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "Отсутствует "
                "Authorization header"
            ),
        )

    prefix = "Bearer "

    if not authorization.startswith(prefix):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "Неверный формат "
                "Authorization header"
            ),
        )

    id_token = authorization[
        len(prefix):
    ].strip()

    if not id_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "Firebase ID token "
                "отсутствует"
            ),
        )

    try:
        decoded_token = auth.verify_id_token(
            id_token
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "Недействительный "
                "Firebase ID token"
            ),
        )

    uid = decoded_token.get("uid")

    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "UID отсутствует "
                "в Firebase token"
            ),
        )

    user_document = (
        db.collection("users")
        .document(uid)
        .get()
    )

    if not user_document.exists:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Профиль пользователя "
                "не найден"
            ),
        )

    user_data = (
        user_document.to_dict()
        or {}
    )

    if user_data.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Доступ разрешён только "
                "администратору"
            ),
        )

    return {
        "uid": uid,
        "email": decoded_token.get(
            "email"
        ),
        "role": "admin",
    }


@app.get("/admin/check")
async def admin_check(
    admin: dict = Depends(
        require_admin
    ),
) -> dict:
    return {
        "status": "ok",
        "message": (
            "Администратор авторизован"
        ),
        "user": admin,
    }


@app.post("/schedule/check")
async def check_schedule(
    file: UploadFile = File(...),
    admin: dict = Depends(
        require_admin
    ),
) -> dict:
    original_name = (
        file.filename
        or "schedule.pdf"
    )

    if not original_name.lower().endswith(
        ".pdf"
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Разрешены только "
                "PDF-файлы"
            ),
        )

    contents = await file.read()

    if not contents:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="PDF-файл пуст",
        )

    if len(contents) > MAX_PDF_SIZE:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=(
                "PDF-файл слишком большой. "
                "Максимальный размер — 15 МБ."
            ),
        )

    if not contents.startswith(b"%PDF"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Содержимое файла "
                "не похоже на PDF"
            ),
        )

    temporary_path: Path | None = None

    try:
        with tempfile.NamedTemporaryFile(
            suffix=".pdf",
            delete=False,
        ) as temporary_file:
            temporary_file.write(
                contents
            )

            temporary_path = Path(
                temporary_file.name
            )

        parsed_data = parse_pdf(
            temporary_path
        )

        issues, stats = audit_json(
            parsed_data
        )

        return {
            "status": (
                "ok"
                if not issues
                else "invalid"
            ),
            "auditPassed": not issues,
            "fileName": original_name,
            "date": stats.get(
                "date",
                parsed_data.get(
                    "date",
                    "",
                ),
            ),
            "lessonCount": stats.get(
                "lessons",
                parsed_data.get(
                    "lessonCount",
                    0,
                ),
            ),
            "groupCount": stats.get(
                "groups",
                0,
            ),
            "subjectCount": stats.get(
                "subjects",
                0,
            ),
            "teacherCount": stats.get(
                "teachers",
                0,
            ),
            "withoutTeacher": stats.get(
                "withoutTeacher",
                0,
            ),
            "withoutRoom": stats.get(
                "withoutRoom",
                0,
            ),
            "issues": issues,
            "issueCount": len(
                issues
            ),
            "checkedBy": {
                "uid": admin["uid"],
                "email": admin.get(
                    "email"
                ),
            },
        }

    except HTTPException:
        raise

    except Exception as error:
        print(
            "Ошибка обработки PDF:",
            repr(error),
        )

        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=(
                "Не удалось обработать "
                "PDF-расписание: "
                f"{error}"
            ),
        )

    finally:
        await file.close()

        if (
            temporary_path is not None
            and temporary_path.exists()
        ):
            try:
                temporary_path.unlink()
            except OSError as error:
                print(
                    "Не удалось удалить "
                    "временный PDF:",
                    error,
                )