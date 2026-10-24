from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.dependencies import (
    get_db,
    require_role,
)
from app.models.user import User

from app.schemas.student_admin import (
    StudentCreate,
    StudentUpdate,
    StudentAdminResponse,
)

from app.schemas.staff_admin import (
    StaffCreate,
    StaffUpdate,
    StaffResponse,
)

from app.services.admin_management_service import (
    create_student,
    get_students,
    delete_student,
    create_staff,
    get_staff,
    deactivate_staff,
    update_staff,
    update_student,
    set_account_active,
    reset_account_password,
)


router = APIRouter(
    prefix="/admin/management",
    tags=["Admin Management"],
)


class AccountStatusUpdate(BaseModel):
    is_active: bool


class PasswordReset(BaseModel):
    password: str = Field(min_length=6, max_length=72)


def _account_action(role: str, account_id: int, db: Session, action):
    try:
        return action()
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.patch("/{role}/{account_id}/status", dependencies=[Depends(require_role("admin"))])
def update_account_status(role: str, account_id: int, data: AccountStatusUpdate, db: Session = Depends(get_db)):
    if role not in ("students", "staff"):
        raise HTTPException(status_code=404, detail="Account type not found")
    singular_role = "student" if role == "students" else "staff"
    return _account_action(singular_role, account_id, db, lambda: set_account_active(db, singular_role, account_id, data.is_active))


@router.put("/{role}/{account_id}/password", dependencies=[Depends(require_role("admin"))])
def update_account_password(role: str, account_id: int, data: PasswordReset, db: Session = Depends(get_db)):
    if role not in ("students", "staff"):
        raise HTTPException(status_code=404, detail="Account type not found")
    singular_role = "student" if role == "students" else "staff"
    return _account_action(singular_role, account_id, db, lambda: reset_account_password(db, singular_role, account_id, data.password))


# ==========================================
# STUDENTS
# ==========================================

@router.post(
    "/students",
    response_model=StudentAdminResponse,
    dependencies=[Depends(require_role("admin"))],
)
def add_student(
    data: StudentCreate,
    db: Session = Depends(get_db),
):
    try:
        return create_student(db, data)

    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e),
        )


@router.get(
    "/students",
    response_model=list[StudentAdminResponse],
    dependencies=[Depends(require_role("admin"))],
)
def list_students(
    db: Session = Depends(get_db),
):
    return get_students(db)


@router.delete(
    "/students/{student_id}",
    dependencies=[Depends(require_role("admin"))],
)
def remove_student(
    student_id: int,
    db: Session = Depends(get_db),
):
    try:
        delete_student(
            db,
            student_id,
        )

        return {
            "message": "Student and associated data deleted successfully"
        }

    except ValueError as e:
        raise HTTPException(
            status_code=404,
            detail=str(e),
        )


@router.put(
    "/students/{student_id}",
    response_model=StudentAdminResponse,
    dependencies=[Depends(require_role("admin"))],
)
def update_student_route(
    student_id: int,
    data: StudentUpdate,
    db: Session = Depends(get_db),
):
    try:
        return update_student(db, student_id, data)
    except ValueError as e:
        status_code = 400 if "already exists" in str(e) else 404
        raise HTTPException(status_code=status_code, detail=str(e))


# ==========================================
# STAFF
# ==========================================

@router.post(
    "/staff",
    response_model=StaffResponse,
    dependencies=[Depends(require_role("admin"))],
)
def add_staff(
    data: StaffCreate,
    db: Session = Depends(get_db),
):
    try:
        return create_staff(db, data)

    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e),
        )


@router.get(
    "/staff",
    response_model=list[StaffResponse],
    dependencies=[Depends(require_role("admin"))],
)
def list_staff(
    db: Session = Depends(get_db),
):
    return get_staff(db)


@router.delete(
    "/staff/{staff_id}",
    dependencies=[Depends(require_role("admin"))],
)
def disable_staff(
    staff_id: int,
    db: Session = Depends(get_db),
):
    try:
        deactivate_staff(
            db,
            staff_id,
        )

        return {
            "message": "Staff deactivated successfully"
        }

    except ValueError as e:
        raise HTTPException(
            status_code=404,
            detail=str(e),
        )

@router.put(
    "/staff/{staff_id}",
    response_model=StaffResponse,
)
def update_staff_route(
    staff_id: int,
    data: StaffUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("admin")),
):
    return update_staff(
        db=db,
        staff_id=staff_id,
        data=data,
    )
