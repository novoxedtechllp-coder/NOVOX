from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import get_db, require_role
from app.models.student import Student


router = APIRouter(
    prefix="/student",
    tags=["Student"],
)


@router.get("/dashboard")
def student_dashboard(
    current_user=Depends(
        require_role("student")
    ),
):
    return {
        "message": "Student dashboard",
        "user_id": current_user.id,
        "name": current_user.name,
        "role": current_user.role,
    }


@router.get("/profile")
def student_profile(
    db: Session = Depends(get_db),
    current_user=Depends(
        require_role("student")
    ),
):
    student = (
        db.query(Student)
        .filter(Student.user_id == current_user.id)
        .first()
    )

    return {
        "id": student.id if student else None,
        "user_id": current_user.id,
        "name": current_user.name,
        "email": current_user.email,
        "phone": current_user.phone,
        "role": current_user.role,
        "student_code": student.student_code if student else None,
        "course": student.course if student else None,
        "batch": student.batch if student else None,
        "joining_date": student.joining_date if student else None,
        "guardian_name": student.guardian_name if student else None,
        "guardian_phone": student.guardian_phone if student else None,
    }
