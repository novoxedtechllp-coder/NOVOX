from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.student import Student
from app.models.staff import Staff
from app.models.fee import StudentFee
from app.core.security import hash_password


def create_student(db: Session, data):

    existing = (
        db.query(User)
        .filter(User.email == data.email)
        .first()
    )

    if existing:
        raise ValueError("Email already exists")

    existing_student_code = (
        db.query(Student)
        .filter(Student.student_code == data.student_code)
        .first()
    )
    if existing_student_code:
        raise ValueError("Student code already exists")

    user = User(
        name=data.name,
        email=data.email,
        password_hash=hash_password(data.password),
        role="student",
        phone=data.phone,
        is_active=True,
    )

    db.add(user)
    db.flush()

    student = Student(
        user_id=user.id,
        student_code=data.student_code,
        course=data.course,
        batch=data.batch,
        joining_date=data.joining_date,
        guardian_name=data.guardian_name,
        guardian_phone=data.guardian_phone,
    )

    db.add(student)
    try:
        db.flush()
    except IntegrityError as error:
        # The unique constraint remains the final guard if two requests race
        # after the availability check above.
        db.rollback()
        if "student_code" in str(error.orig):
            raise ValueError("Student code already exists") from error
        raise

    if data.total_fees is not None and data.total_fees > 0:
        db.add(
            StudentFee(
                student_id=student.id,
                total_amount=data.total_fees,
                paid_amount=0,
                pending_amount=data.total_fees,
                status="PENDING",
            )
        )

    db.commit()
    db.refresh(student)

    return _student_response(db, student, user)


def get_students(db: Session):
    rows = (
        db.query(Student, User)
        .join(User, User.id == Student.user_id)
        .order_by(Student.id)
        .all()
    )
    return [_student_response(db, student, user) for student, user in rows]


def _student_response(db: Session, student: Student, user: User) -> dict:
    total_fees = (
        db.query(func.coalesce(func.sum(StudentFee.total_amount), 0))
        .filter(StudentFee.student_id == student.id)
        .scalar()
    )
    return {
        "id": student.id,
        "user_id": student.user_id,
        "name": user.name,
        "email": user.email,
        "phone": user.phone,
        "is_active": user.is_active,
        "student_code": student.student_code,
        "course": student.course,
        "batch": student.batch,
        "joining_date": student.joining_date,
        "guardian_name": student.guardian_name,
        "guardian_phone": student.guardian_phone,
        "total_fees": float(total_fees or 0),
    }


def deactivate_student(
    db: Session,
    student_id: int,
):

    student = (
        db.query(Student)
        .filter(Student.id == student_id)
        .first()
    )

    if not student:
        raise ValueError("Student not found")

    user = (
        db.query(User)
        .filter(User.id == student.user_id)
        .first()
    )

    user.is_active = False

    db.commit()

    return student


def create_staff(db: Session, data):

    existing = (
        db.query(User)
        .filter(User.email == data.email)
        .first()
    )

    if existing:
        raise ValueError("Email already exists")

    user = User(
        name=data.name,
        email=data.email,
        password_hash=hash_password(data.password),
        role="staff",
        phone=data.phone,
        is_active=True,
    )

    db.add(user)
    db.flush()

    staff = Staff(
        user_id=user.id,
        employee_code=data.employee_code,
        designation=data.designation,
        department=data.department,
        joining_date=data.joining_date,
    )

    db.add(staff)
    db.commit()
    db.refresh(staff)

    return _staff_response(staff, user)


def get_staff(db: Session):
    rows = (
        db.query(Staff, User)
        .join(User, User.id == Staff.user_id)
        .order_by(Staff.id)
        .all()
    )
    return [_staff_response(staff, user) for staff, user in rows]


def _staff_response(staff: Staff, user: User) -> dict:
    return {
        "id": staff.id,
        "user_id": staff.user_id,
        "employee_code": staff.employee_code,
        "designation": staff.designation,
        "department": staff.department,
        "joining_date": staff.joining_date,
        "name": user.name,
        "email": user.email,
        "phone": user.phone,
        "is_active": user.is_active,
    }


def deactivate_staff(
    db: Session,
    staff_id: int,
):

    staff = (
        db.query(Staff)
        .filter(Staff.id == staff_id)
        .first()
    )

    if not staff:
        raise ValueError("Staff not found")

    user = (
        db.query(User)
        .filter(User.id == staff.user_id)
        .first()
    )

    user.is_active = False

    db.commit()

    return staff


def set_account_active(db: Session, role: str, account_id: int, is_active: bool):
    model = Student if role == "student" else Staff
    account = db.query(model).filter(model.id == account_id).first()
    if not account:
        raise ValueError(f"{role.title()} not found")
    user = db.query(User).filter(User.id == account.user_id).first()
    if not user:
        raise ValueError(f"{role.title()} user account not found")
    user.is_active = is_active
    db.commit()
    return {"is_active": user.is_active}


def reset_account_password(db: Session, role: str, account_id: int, password: str):
    model = Student if role == "student" else Staff
    account = db.query(model).filter(model.id == account_id).first()
    if not account:
        raise ValueError(f"{role.title()} not found")
    user = db.query(User).filter(User.id == account.user_id).first()
    if not user:
        raise ValueError(f"{role.title()} user account not found")
    user.password_hash = hash_password(password)
    db.commit()
    return {"message": "Password reset successfully"}

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.staff import Staff
from app.models.user import User
from app.schemas.staff_admin import StaffUpdate
from app.schemas.student_admin import StudentUpdate


def update_student(db: Session, student_id: int, data: StudentUpdate):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise ValueError("Student not found")

    user = db.query(User).filter(User.id == student.user_id).first()
    if not user:
        raise ValueError("Student user account not found")

    updates = data.model_dump(exclude_unset=True)
    if "student_code" in updates and updates["student_code"] != student.student_code:
        existing = db.query(Student).filter(
            Student.student_code == updates["student_code"],
            Student.id != student_id,
        ).first()
        if existing:
            raise ValueError("Student code already exists")

    for field in ("name", "phone"):
        if field in updates:
            setattr(user, field, updates.pop(field))
    for field, value in updates.items():
        setattr(student, field, value)

    db.commit()
    db.refresh(student)
    return _student_response(db, student, user)


def update_staff(
    db: Session,
    staff_id: int,
    data: StaffUpdate
):
    staff = db.query(Staff).filter(
        Staff.id == staff_id
    ).first()

    if not staff:
        raise HTTPException(
            status_code=404,
            detail="Staff not found"
        )

    user = db.query(User).filter(
        User.id == staff.user_id
    ).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="Staff user account not found"
        )

    if data.name is not None:
        user.name = data.name

    if data.phone is not None:
        user.phone = data.phone

    if data.employee_code is not None:
        staff.employee_code = data.employee_code

    if data.designation is not None:
        staff.designation = data.designation

    if data.department is not None:
        staff.department = data.department

    if data.joining_date is not None:
        staff.joining_date = data.joining_date

    db.commit()
    db.refresh(staff)

    return {
        "id": staff.id,
        "user_id": staff.user_id,
        "employee_code": staff.employee_code,
        "designation": staff.designation,
        "department": staff.department,
        "joining_date": staff.joining_date,
        "name": user.name,
        "email": user.email,
        "phone": user.phone,
        "is_active": user.is_active,
    }

