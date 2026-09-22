from datetime import datetime, timezone
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
from google.cloud.firestore_v1.base_query import FieldFilter

from import_schedule import analyze_import
from parser import parse_pdf
from schedule_audit import audit_json
from teacher_importer import load_existing_teachers


BASE_DIR = Path(__file__).resolve().parent
SERVICE_ACCOUNT_PATH = BASE_DIR / "service-account.json"

MAX_PDF_SIZE = 15 * 1024 * 1024

# Firestore допускает до 500 операций записи в одном batch.
# Оставляем небольшой запас.
MAX_BATCH_OPERATIONS = 450


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
    version="1.2.0",
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
                "Отсутствует Authorization header"
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
                "Firebase ID token отсутствует"
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

    user_data = user_document.to_dict() or {}

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
        "email": decoded_token.get("email"),
        "role": "admin",
    }


@app.get("/admin/check")
async def admin_check(
    admin: dict = Depends(require_admin),
) -> dict:
    return {
        "status": "ok",
        "message": (
            "Администратор авторизован"
        ),
        "user": admin,
    }


async def read_pdf_upload(
    file: UploadFile,
) -> tuple[str, bytes]:
    original_name = (
        file.filename or "schedule.pdf"
    )

    if not original_name.lower().endswith(
        ".pdf"
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Разрешены только PDF-файлы"
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

    return original_name, contents


def parse_pdf_bytes(
    contents: bytes,
) -> dict:
    temporary_path: Path | None = None

    try:
        with tempfile.NamedTemporaryFile(
            suffix=".pdf",
            delete=False,
        ) as temporary_file:
            temporary_file.write(contents)

            temporary_path = Path(
                temporary_file.name
            )

        return parse_pdf(temporary_path)

    finally:
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


def build_check_response(
    original_name: str,
    parsed_data: dict,
    admin: dict,
) -> dict:
    issues, stats = audit_json(
        parsed_data
    )

    return {
        "status": (
            "ok" if not issues else "invalid"
        ),
        "auditPassed": not issues,
        "fileName": original_name,
        "date": stats.get(
            "date",
            parsed_data.get("date", ""),
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
        "issueCount": len(issues),
        "checkedBy": {
            "uid": admin["uid"],
            "email": admin.get("email"),
        },
    }


def parse_schedule_date(
    value: str,
) -> datetime:
    try:
        parsed = datetime.strptime(
            value,
            "%Y-%m-%d",
        )

        return parsed.replace(
            tzinfo=timezone.utc
        )

    except ValueError as error:
        raise ValueError(
            "Некорректная дата "
            f"расписания: {value}"
        ) from error


def get_existing_lesson_ids(
    schedule_date: str,
) -> set[str]:
    firestore_date = parse_schedule_date(
        schedule_date
    )

    documents = (
        db.collection("lessons")
        .where(
            filter=FieldFilter(
                "date",
                "==",
                firestore_date,
            )
        )
        .stream()
    )

    return {
        document.id
        for document in documents
    }


def commit_schedule_replacement(
    prepared: list,
    stale_document_ids: set[str],
) -> dict[str, int]:
    """
    Записывает новое расписание и удаляет
    устаревшие занятия одним Firestore batch.

    Благодаря этому изменения занятий одной
    даты применяются целиком.
    """

    total_operations = (
        len(prepared)
        + len(stale_document_ids)
    )

    if total_operations > MAX_BATCH_OPERATIONS:
        raise ValueError(
            "Слишком много операций для "
            "безопасной атомарной публикации: "
            f"{total_operations}. "
            f"Максимум: {MAX_BATCH_OPERATIONS}."
        )

    batch = db.batch()

    lessons_collection = db.collection(
        "lessons"
    )

    for (
        document_id,
        document_data,
    ) in prepared:
        reference = (
            lessons_collection.document(
                document_id
            )
        )

        batch.set(
            reference,
            document_data,
            merge=False,
        )

    for document_id in sorted(
        stale_document_ids
    ):
        reference = (
            lessons_collection.document(
                document_id
            )
        )

        batch.delete(reference)

    batch.commit()

    return {
        "written": len(prepared),
        "deleted": len(
            stale_document_ids
        ),
        "operations": total_operations,
    }


def upsert_teachers_from_schedule(
    parsed_data: dict,
) -> dict[str, int]:
    lessons = parsed_data.get(
        "lessons",
        [],
    )

    teachers: dict[str, dict] = {}

    from teacher_names import (
        normalize_teacher_key,
        normalize_teacher_name,
    )
    from teacher_importer import (
        make_teacher_id,
    )

    for lesson in lessons:
        if not isinstance(
            lesson,
            dict,
        ):
            continue

        group_id = str(
            lesson.get(
                "groupId",
                "",
            )
            or ""
        ).strip()

        lesson_teachers = lesson.get(
            "teachers"
        )

        if not isinstance(
            lesson_teachers,
            list,
        ):
            continue

        for raw_name in lesson_teachers:
            canonical_name = (
                normalize_teacher_name(
                    str(raw_name)
                )
            )

            if not canonical_name:
                continue

            teacher_key = (
                normalize_teacher_key(
                    canonical_name
                )
            )

            if teacher_key not in teachers:
                teachers[teacher_key] = {
                    "name": canonical_name,
                    "teacherId": (
                        make_teacher_id(
                            canonical_name
                        )
                    ),
                    "groupIds": set(),
                }

            if group_id:
                teachers[
                    teacher_key
                ]["groupIds"].add(
                    group_id
                )

    existing = load_existing_teachers(
        db
    )

    created = 0
    updated = 0

    for teacher in teachers.values():
        teacher_id = teacher[
            "teacherId"
        ]

        existing_document = existing.get(
            teacher_id
        )

        reference = (
            db.collection("teachers")
            .document(teacher_id)
        )

        if existing_document is None:
            document = {
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

            reference.set(
                document,
                merge=False,
            )

            created += 1
            continue

        existing_name = str(
            existing_document.get(
                "name",
                "",
            )
            or ""
        ).strip()

        if (
            existing_name
            and existing_name
            != teacher["name"]
        ):
            raise ValueError(
                "Конфликт преподавателя "
                f"{teacher_id}: "
                f"Firestore='{existing_name}', "
                f"PDF='{teacher['name']}'"
            )

        old_group_ids = (
            existing_document.get(
                "groupIds"
            )
        )

        if not isinstance(
            old_group_ids,
            list,
        ):
            old_group_ids = []

        normalized_old_group_ids = sorted(
            {
                str(group_id).strip()
                for group_id in old_group_ids
                if str(group_id).strip()
            }
        )

        merged_group_ids = sorted(
            set(normalized_old_group_ids)
            | teacher["groupIds"]
        )

        if (
            merged_group_ids
            != normalized_old_group_ids
        ):
            reference.update(
                {
                    "groupIds": (
                        merged_group_ids
                    ),
                }
            )

            updated += 1

    return {
        "created": created,
        "updated": updated,
    }


@app.post("/schedule/check")
async def check_schedule(
    file: UploadFile = File(...),
    admin: dict = Depends(
        require_admin
    ),
) -> dict:
    try:
        (
            original_name,
            contents,
        ) = await read_pdf_upload(
            file
        )

        parsed_data = parse_pdf_bytes(
            contents
        )

        return build_check_response(
            original_name,
            parsed_data,
            admin,
        )

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


@app.post("/schedule/publish")
async def publish_schedule(
    file: UploadFile = File(...),
    admin: dict = Depends(
        require_admin
    ),
) -> dict:
    try:
        (
            original_name,
            contents,
        ) = await read_pdf_upload(
            file
        )

        parsed_data = parse_pdf_bytes(
            contents
        )

        issues, stats = audit_json(
            parsed_data
        )

        if issues:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=(
                    "Расписание не прошло "
                    "проверку и не может "
                    "быть опубликовано."
                ),
            )

        schedule_date = str(
            stats.get("date")
            or parsed_data.get("date")
            or ""
        ).strip()

        if not schedule_date:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail=(
                    "Не удалось определить "
                    "дату расписания."
                ),
            )

        # Сначала проверяем и подготавливаем
        # занятия. На этом этапе занятия
        # ещё не записываются в Firestore.
        prepared = analyze_import(
            db,
            parsed_data,
        )

        new_document_ids = {
            document_id
            for (
                document_id,
                _
            ) in prepared
        }

        existing_document_ids = (
            get_existing_lesson_ids(
                schedule_date
            )
        )

        stale_document_ids = (
            existing_document_ids
            - new_document_ids
        )

        # После успешной подготовки занятий
        # синхронизируем преподавателей.
        teacher_result = (
            upsert_teachers_from_schedule(
                parsed_data
            )
        )

        # Новые занятия + удаление старых
        # выполняются одним batch.
        replacement_result = (
            commit_schedule_replacement(
                prepared,
                stale_document_ids,
            )
        )

        return {
            "status": "ok",
            "message": (
                "Расписание успешно "
                "опубликовано"
            ),
            "fileName": original_name,
            "date": schedule_date,
            "lessonCount": (
                replacement_result[
                    "written"
                ]
            ),
            "previousLessonCount": len(
                existing_document_ids
            ),
            "deletedLessonCount": (
                replacement_result[
                    "deleted"
                ]
            ),
            "teachersCreated": (
                teacher_result[
                    "created"
                ]
            ),
            "teachersUpdated": (
                teacher_result[
                    "updated"
                ]
            ),
            "publishedBy": {
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
            "Ошибка публикации:",
            repr(error),
        )

        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=(
                "Не удалось опубликовать "
                "расписание: "
                f"{error}"
            ),
        )

    finally:
        await file.close()