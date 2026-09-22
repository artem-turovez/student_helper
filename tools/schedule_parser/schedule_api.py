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
from pydantic import BaseModel

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
    version="1.5.0",
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


def serialize_datetime(
    value,
) -> str | None:
    if value is None:
        return None

    if isinstance(value, datetime):
        return value.isoformat()

    return str(value)


def normalize_optional_text(
    value: str | None,
) -> str | None:
    if value is None:
        return None

    normalized = value.strip()

    return normalized or None


def normalize_string_list(
    value,
) -> list[str]:
    if not isinstance(value, list):
        return []

    return sorted(
        {
            str(item).strip()
            for item in value
            if str(item).strip()
        }
    )


def serialize_user(
    uid: str,
    data: dict,
) -> dict:
    return {
        "uid": uid,
        "name": (
            str(
                data.get("name") or ""
            ).strip()
            or None
        ),
        "email": (
            str(
                data.get("email") or ""
            ).strip()
            or None
        ),
        "role": (
            str(
                data.get("role") or ""
            ).strip()
            or None
        ),
        "groupId": (
            str(
                data.get("groupId") or ""
            ).strip()
            or None
        ),
        "teacherId": (
            str(
                data.get("teacherId") or ""
            ).strip()
            or None
        ),
        "createdAt": serialize_datetime(
            data.get("createdAt")
        ),
    }


def build_teacher_links() -> dict[str, dict]:
    """
    Возвращает связи:
    teacherId -> пользователь.

    Одновременно проверяет целостность данных:
    один teacherId не должен принадлежать
    нескольким аккаунтам.
    """

    links: dict[str, dict] = {}

    documents = db.collection(
        "users"
    ).stream()

    for document in documents:
        data = document.to_dict() or {}

        teacher_id = normalize_optional_text(
            data.get("teacherId")
        )

        if teacher_id is None:
            continue

        existing_link = links.get(
            teacher_id
        )

        if existing_link is not None:
            raise RuntimeError(
                "Обнаружена двойная привязка "
                "преподавателя "
                f"{teacher_id}: "
                f"{existing_link['uid']} и "
                f"{document.id}"
            )

        links[teacher_id] = {
            "uid": document.id,
            "name": normalize_optional_text(
                data.get("name")
            ),
            "email": normalize_optional_text(
                data.get("email")
            ),
            "role": normalize_optional_text(
                data.get("role")
            ),
        }

    return links


def serialize_teacher(
    teacher_id: str,
    data: dict,
    linked_user: dict | None = None,
) -> dict:
    return {
        "teacherId": teacher_id,
        "name": (
            str(
                data.get("name") or ""
            ).strip()
            or teacher_id
        ),
        "email": normalize_optional_text(
            data.get("email")
        ),
        "phone": normalize_optional_text(
            data.get("phone")
        ),
        "telegram": normalize_optional_text(
            data.get("telegram")
        ),
        "photoUrl": normalize_optional_text(
            data.get("photoUrl")
        ),
        "department": normalize_optional_text(
            data.get("department")
        ),
        "groupIds": normalize_string_list(
            data.get("groupIds")
        ),
        "linked": linked_user is not None,
        "userUid": (
            linked_user.get("uid")
            if linked_user is not None
            else None
        ),
        "userName": (
            linked_user.get("name")
            if linked_user is not None
            else None
        ),
        "userEmail": (
            linked_user.get("email")
            if linked_user is not None
            else None
        ),
    }


@app.get("/admin/users")
async def get_admin_users(
    admin: dict = Depends(require_admin),
) -> dict:
    try:
        documents = list(
            db.collection("users").stream()
        )

        users = []

        for document in documents:
            data = document.to_dict() or {}

            users.append(
                serialize_user(
                    document.id,
                    data,
                )
            )

        role_order = {
            "admin": 0,
            "teacher": 1,
            "student": 2,
        }

        users.sort(
            key=lambda user: (
                role_order.get(
                    user.get("role"),
                    99,
                ),
                (
                    user.get("name")
                    or user.get("email")
                    or ""
                ).lower(),
            )
        )

        return {
            "status": "ok",
            "count": len(users),
            "users": users,
            "requestedBy": {
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
            "Ошибка загрузки пользователей:",
            repr(error),
        )

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=(
                "Не удалось загрузить "
                "пользователей."
            ),
        )


@app.get("/admin/teachers")
async def get_admin_teachers(
    admin: dict = Depends(require_admin),
) -> dict:
    try:
        teacher_documents = list(
            db.collection(
                "teachers"
            ).stream()
        )

        teacher_links = (
            build_teacher_links()
        )

        teachers = []

        for document in teacher_documents:
            data = document.to_dict() or {}

            teachers.append(
                serialize_teacher(
                    document.id,
                    data,
                    teacher_links.get(
                        document.id
                    ),
                )
            )

        teachers.sort(
            key=lambda teacher: (
                teacher.get("name") or ""
            ).lower()
        )

        linked_count = sum(
            1
            for teacher in teachers
            if teacher["linked"]
        )

        return {
            "status": "ok",
            "count": len(teachers),
            "linkedCount": linked_count,
            "unlinkedCount": (
                len(teachers)
                - linked_count
            ),
            "teachers": teachers,
            "requestedBy": {
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
            "Ошибка загрузки преподавателей:",
            repr(error),
        )

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=(
                "Не удалось загрузить "
                "преподавателей."
            ),
        )


class AdminUserUpdateRequest(BaseModel):
    name: str | None = None
    role: str
    groupId: str | None = None
    teacherId: str | None = None


def validate_teacher_link(
    teacher_id: str,
    user_uid: str,
) -> None:
    """
    Проверяет, что преподаватель существует
    и ещё не связан с другим аккаунтом.
    """

    teacher_snapshot = (
        db.collection("teachers")
        .document(teacher_id)
        .get()
    )

    if not teacher_snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Выбранный преподаватель "
                "не найден."
            ),
        )

    linked_users = list(
        db.collection("users")
        .where(
            filter=FieldFilter(
                "teacherId",
                "==",
                teacher_id,
            )
        )
        .stream()
    )

    for linked_user in linked_users:
        if linked_user.id != user_uid:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Этот преподаватель "
                    "уже привязан к другому "
                    "аккаунту."
                ),
            )


@app.patch("/admin/users/{uid}")
async def update_admin_user(
    uid: str,
    payload: AdminUserUpdateRequest,
    admin: dict = Depends(require_admin),
) -> dict:
    try:
        uid = uid.strip()

        if not uid:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "UID пользователя "
                    "не указан."
                ),
            )

        reference = (
            db.collection("users")
            .document(uid)
        )

        snapshot = reference.get()

        if not snapshot.exists:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=(
                    "Пользователь "
                    "не найден."
                ),
            )

        current_data = (
            snapshot.to_dict() or {}
        )

        role = payload.role.strip().lower()

        allowed_roles = {
            "student",
            "teacher",
            "admin",
        }

        if role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Недопустимая роль "
                    "пользователя."
                ),
            )

        current_role = str(
            current_data.get("role") or ""
        ).strip().lower()

        # Администратор не может случайно
        # снять роль администратора у самого себя.
        if (
            uid == admin["uid"]
            and role != current_role
        ):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    "Нельзя изменить роль "
                    "собственного "
                    "административного "
                    "аккаунта."
                ),
            )

        name = normalize_optional_text(
            payload.name
        )

        group_id = normalize_optional_text(
            payload.groupId
        )

        teacher_id = normalize_optional_text(
            payload.teacherId
        )

        if role == "student":
            teacher_id = None

            if group_id is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=(
                        "Для учащегося "
                        "необходимо указать "
                        "учебную группу."
                    ),
                )

        elif role == "teacher":
            group_id = None

            if teacher_id is None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=(
                        "Для роли преподавателя "
                        "необходимо выбрать "
                        "преподавателя."
                    ),
                )

            validate_teacher_link(
                teacher_id,
                uid,
            )

        elif role == "admin":
            group_id = None
            teacher_id = None

        update_data = {
            "name": name,
            "role": role,
            "groupId": group_id,
            "teacherId": teacher_id,
        }

        reference.update(
            update_data
        )

        updated_snapshot = reference.get()

        updated_data = (
            updated_snapshot.to_dict()
            or {}
        )

        return {
            "status": "ok",
            "message": (
                "Данные пользователя "
                "обновлены"
            ),
            "user": serialize_user(
                uid,
                updated_data,
            ),
            "updatedBy": {
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
            "Ошибка обновления пользователя:",
            repr(error),
        )

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=(
                "Не удалось обновить "
                "пользователя."
            ),
        )


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

        return parse_pdf(
            temporary_path
        )

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
        "issueCount": len(issues),
        "checkedBy": {
            "uid": admin["uid"],
            "email": admin.get(
                "email"
            ),
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

        batch.delete(
            reference
        )

    batch.commit()

    return {
        "written": len(
            prepared
        ),
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
                teachers[
                    teacher_key
                ] = {
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
                str(
                    group_id
                ).strip()
                for group_id in old_group_ids
                if str(
                    group_id
                ).strip()
            }
        )

        merged_group_ids = sorted(
            set(
                normalized_old_group_ids
            )
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