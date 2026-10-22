from sqlalchemy.orm import Session
from sqlalchemy import extract
from app.models.payment import Payment

from app.models.attendance import Attendance
from app.models.attendance_break import AttendanceBreak
from app.models.user import User

from app.models.student import Student
from app.models.staff import Staff
from app.models.fee import StudentFee
from app.models.salary_slip import SalarySlip
from app.core.timezone import elapsed_between, now_india, today_india


def get_fee_report(db: Session):
    query = (
        db.query(StudentFee, Student, User.name)
        .join(Student, Student.id == StudentFee.student_id)
        .join(User, User.id == Student.user_id)
        .order_by(StudentFee.created_at.desc())
    )

    results = []

    for fee, student, student_name in query.all():
        results.append({
            "student_fee_id": fee.id,
            "student_id": student.id,
            "student_name": student_name,
            "total_amount": fee.total_amount,
            "paid_amount": fee.paid_amount,
            "pending_amount": fee.pending_amount,
            "status": fee.status,
        })

    return results


def get_salary_report(
    db: Session,
    month: int | None = None,
    year: int | None = None,
):
    query = (
        db.query(SalarySlip, Staff, User.name)
        .join(Staff, Staff.id == SalarySlip.staff_id)
        .join(User, User.id == Staff.user_id)
    )

    if month:
        query = query.filter(
            SalarySlip.month == month
        )

    if year:
        query = query.filter(
            SalarySlip.year == year
        )

    query = query.order_by(
        SalarySlip.year.desc(),
        SalarySlip.month.desc()
    )

    results = []

    for slip, staff, staff_name in query.all():
        results.append({
            "slip_id": slip.id,
            "staff_id": staff.id,
            "staff_name": staff_name,
            "month": slip.month,
            "year": slip.year,
            "basic_salary": slip.basic_salary,
            "allowance": slip.allowance,
            "deduction": slip.deduction,
            "net_salary": slip.net_salary,
            "status": slip.status,
        })

    return results


from sqlalchemy import func


def get_reports_summary(db: Session):
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

    from datetime import datetime
    from app.core.timezone import today_india

    today = today_india()

    present_today = (
        db.query(Attendance)
        .filter(
            Attendance.attendance_date == today,
            Attendance.attendance_status == "PRESENT"
        )
        .count()
    )

    late_today = (
        db.query(Attendance)
        .filter(
            Attendance.attendance_date == today,
            Attendance.arrival_status == "LATE"
        )
        .count()
    )

    checked_out_today = (
        db.query(Attendance)
        .filter(
            Attendance.attendance_date == today,
            Attendance.checkout.isnot(None)
        )
        .count()
    )

    pending_fee_students = (
        db.query(StudentFee)
        .filter(StudentFee.pending_amount > 0)
        .count()
    )

    total_pending_fees = (
        db.query(
            func.coalesce(
                func.sum(StudentFee.pending_amount),
                0
            )
        )
        .scalar()
    )

    total_collected_fees = (
        db.query(
            func.coalesce(
                func.sum(Payment.amount),
                0
            )
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
        "total_pending_fees": total_pending_fees,
        "total_collected_fees": total_collected_fees,
    }




def get_attendance_report(
    db: Session,
    start_date=None,
    end_date=None,
):
    query = (
        db.query(Attendance, User.name)
        .join(User, User.id == Attendance.user_id)
    )

    if start_date:
        query = query.filter(
            Attendance.attendance_date >= start_date
        )

    if end_date:
        query = query.filter(
            Attendance.attendance_date <= end_date
        )

    query = query.order_by(
        Attendance.attendance_date.desc()
    )

    results = []

    for attendance, user_name in query.all():
        break_minutes = attendance.total_break_minutes or 0
        if not attendance.checkout:
            breaks = (
                db.query(AttendanceBreak)
                .filter(AttendanceBreak.attendance_id == attendance.id)
                .all()
            )
            break_minutes = sum(
                item.duration_minutes or 0
                for item in breaks
            )
            for item in breaks:
                if item.end_time is None:
                    break_minutes += max(
                        0,
                        int(elapsed_between(item.start_time, now_india()).total_seconds() // 60),
                    )

        work_minutes = attendance.total_work_minutes
        if attendance.check_in and attendance.checkout:
            elapsed_minutes = int(
                elapsed_between(attendance.check_in, attendance.checkout).total_seconds() // 60
            )
            work_minutes = max(0, elapsed_minutes - break_minutes)
        elif (
            attendance.check_in
            and not attendance.checkout
            and attendance.attendance_date == today_india()
        ):
            elapsed_minutes = int(
                elapsed_between(attendance.check_in, now_india()).total_seconds() // 60
            )
            work_minutes = max(0, elapsed_minutes - break_minutes)
        elif not attendance.checkout:
            work_minutes = None

        results.append({
            "attendance_id": attendance.id,
            "user_id": attendance.user_id,
            "user_name": user_name,
            "attendance_date": attendance.attendance_date,
            "check_in": attendance.check_in,
            "checkout": attendance.checkout,
            "attendance_status": attendance.attendance_status,
            "arrival_status": attendance.arrival_status,
            "total_break_minutes": break_minutes,
            "total_work_minutes": work_minutes,
        })

    return results


def get_late_entry_report(
    db: Session,
    start_date=None,
    end_date=None,
):
    query = (
        db.query(Attendance, User.name)
        .join(User, User.id == Attendance.user_id)
        .filter(
            Attendance.arrival_status == "LATE"
        )
    )

    if start_date:
        query = query.filter(
            Attendance.attendance_date >= start_date
        )

    if end_date:
        query = query.filter(
            Attendance.attendance_date <= end_date
        )

    query = query.order_by(
        Attendance.attendance_date.desc()
    )

    results = []

    for attendance, user_name in query.all():
        results.append({
            "attendance_id": attendance.id,
            "user_id": attendance.user_id,
            "user_name": user_name,
            "attendance_date": attendance.attendance_date,
            "check_in": attendance.check_in,
            "arrival_status": attendance.arrival_status,
        })

    return results
