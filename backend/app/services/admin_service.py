from datetime import date

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.attendance import Attendance
from app.models.fee import StudentFee


def get_dashboard_summary(db: Session):

    today = date.today()

    total_students = (
        db.query(User)
        .filter(User.role == "student")
        .count()
    )

    total_staff = (
        db.query(User)
        .filter(User.role == "staff")
        .count()
    )

    today_attendance = (
        db.query(Attendance)
        .filter(
            Attendance.attendance_date == today
        )
    )

    present_today = (
        today_attendance
        .filter(
            Attendance.attendance_status == "PRESENT"
        )
        .count()
    )

    late_today = (
        today_attendance
        .filter(
            Attendance.arrival_status == "LATE"
        )
        .count()
    )

    checked_out_today = (
        today_attendance
        .filter(
            Attendance.checkout.isnot(None)
        )
        .count()
    )

    pending_fee_students = (
        db.query(StudentFee)
        .filter(
            StudentFee.status != "PAID"
        )
        .count()
    )

    total_pending_amount = (
        db.query(
            func.coalesce(
                func.sum(StudentFee.pending_amount),
                0
            )
        )
        .filter(
            StudentFee.status != "PAID"
        )
        .scalar()
    )

    return {
        "total_students": total_students,
        "total_staff": total_staff,
        "present_today": present_today,
        "late_today": late_today,
        "checked_out_today": checked_out_today,
        "pending_fee_students": pending_fee_students,
        "total_pending_amount": float(
            total_pending_amount or 0
        ),
    }


def get_today_attendance(db: Session):

    today = date.today()

    records = (
        db.query(Attendance, User)
        .join(User, User.id == Attendance.user_id)
        .filter(
            Attendance.attendance_date == today,
            User.role.in_(("student", "staff")),
        )
        .order_by(
            Attendance.check_in.desc()
        )
        .all()
    )

    return [
        {
            "attendance_id": record.id,
            "user_id": record.user_id,
            "user_name": user.name,
            "user_role": user.role,
            "attendance_date": record.attendance_date,
            "check_in": record.check_in,
            "checkout": record.checkout,
            "attendance_status": record.attendance_status,
            "arrival_status": record.arrival_status,
            "check_in_distance": record.check_in_distance,
        }
        for record, user in records
    ]


def get_pending_fees(db: Session):

    return (
        db.query(StudentFee)
        .filter(
            StudentFee.status != "PAID"
        )
        .order_by(
            StudentFee.pending_amount.desc()
        )
        .all()
    )
