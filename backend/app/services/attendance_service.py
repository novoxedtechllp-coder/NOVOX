from datetime import time

from sqlalchemy import extract
from sqlalchemy.orm import Session

from app.core.timezone import elapsed_between, now_india, today_india
from app.models.attendance import Attendance
from app.models.attendance_break import AttendanceBreak
from app.services.geofence_service import validate_geofence


# ============================================================
# ATTENDANCE SETTINGS
# ============================================================

ATTENDANCE_CUTOFF = time(
    hour=10,
    minute=0,
)


# ============================================================
# GET TODAY'S ATTENDANCE
# ============================================================

def get_today_attendance(
    db: Session,
    user_id: int,
):
    today = today_india()

    return (
        db.query(Attendance)
        .filter(
            Attendance.user_id == user_id,
            Attendance.attendance_date == today,
        )
        .first()
    )


# ============================================================
# CHECK IN
# ============================================================

def check_in_user(
    db: Session,
    user_id: int,
    latitude: float,
    longitude: float,
):
    today = today_india()

    # --------------------------------------------------------
    # Prevent duplicate attendance
    # --------------------------------------------------------

    existing = (
        db.query(Attendance)
        .filter(
            Attendance.user_id == user_id,
            Attendance.attendance_date == today,
        )
        .first()
    )

    if existing:
        return {
            "success": False,
            "message": "Attendance already marked today",
            "attendance": existing,
            "distance": existing.check_in_distance,
        }

    # --------------------------------------------------------
    # Geofence validation
    # --------------------------------------------------------

    geofence = validate_geofence(
        db,
        latitude,
        longitude,
    )

    if not geofence["valid"]:
        return {
            "success": False,
            "message": "Out of Campus",
            "attendance": None,
            "distance": geofence.get("distance"),
        }

    # --------------------------------------------------------
    # Server-side India timestamp
    # --------------------------------------------------------

    current_time = now_india()

    # --------------------------------------------------------
    # Determine arrival status
    # --------------------------------------------------------

    if current_time.time() <= ATTENDANCE_CUTOFF:
        arrival_status = "ON_TIME"
    else:
        arrival_status = "LATE"

    # --------------------------------------------------------
    # Create attendance
    # --------------------------------------------------------

    attendance = Attendance(
        user_id=user_id,
        attendance_date=today,
        check_in=current_time,
        attendance_status="PRESENT",
        arrival_status=arrival_status,
        check_in_latitude=latitude,
        check_in_longitude=longitude,
        check_in_distance=geofence.get("distance"),
        total_break_minutes=0,
        total_work_minutes=0,
    )

    db.add(attendance)
    db.commit()
    db.refresh(attendance)

    return {
        "success": True,
        "message": (
            "Check-in successful"
            if arrival_status == "ON_TIME"
            else "Late entry recorded"
        ),
        "attendance": attendance,
        "distance": geofence.get("distance"),
    }


# ============================================================
# START BREAK
# ============================================================

def start_break(
    db: Session,
    user_id: int,
):
    attendance = get_today_attendance(
        db,
        user_id,
    )

    if not attendance:
        return {
            "success": False,
            "message": "Check-in required before starting a break",
            "break": None,
        }

    if attendance.checkout:
        return {
            "success": False,
            "message": "Already checked out",
            "break": None,
        }

    # --------------------------------------------------------
    # Prevent multiple active breaks
    # --------------------------------------------------------

    active_break = (
        db.query(AttendanceBreak)
        .filter(
            AttendanceBreak.attendance_id == attendance.id,
            AttendanceBreak.end_time.is_(None),
        )
        .first()
    )

    if active_break:
        return {
            "success": False,
            "message": "Break already active",
            "break": active_break,
        }

    # --------------------------------------------------------
    # Server-side timestamp
    # --------------------------------------------------------

    current_time = now_india()

    new_break = AttendanceBreak(
        attendance_id=attendance.id,
        start_time=current_time,
    )

    db.add(new_break)
    db.commit()
    db.refresh(new_break)

    return {
        "success": True,
        "message": "Break started",
        "break": new_break,
    }


# ============================================================
# END BREAK
# ============================================================

def end_break(
    db: Session,
    user_id: int,
):
    attendance = get_today_attendance(
        db,
        user_id,
    )

    if not attendance:
        return {
            "success": False,
            "message": "Attendance not found",
            "break": None,
        }

    # --------------------------------------------------------
    # Find active break
    # --------------------------------------------------------

    active_break = (
        db.query(AttendanceBreak)
        .filter(
            AttendanceBreak.attendance_id == attendance.id,
            AttendanceBreak.end_time.is_(None),
        )
        .first()
    )

    if not active_break:
        return {
            "success": False,
            "message": "No active break found",
            "break": None,
        }

    # --------------------------------------------------------
    # End break using server time
    # --------------------------------------------------------

    current_time = now_india()

    active_break.end_time = current_time

    duration = elapsed_between(
        active_break.start_time, current_time
    ).total_seconds() / 60

    active_break.duration_minutes = max(
        0,
        round(duration),
    )

    # --------------------------------------------------------
    # Recalculate total break minutes
    # --------------------------------------------------------

    completed_breaks = (
        db.query(AttendanceBreak)
        .filter(
            AttendanceBreak.attendance_id == attendance.id,
            AttendanceBreak.duration_minutes.is_not(None),
        )
        .all()
    )

    attendance.total_break_minutes = sum(
        item.duration_minutes or 0
        for item in completed_breaks
    )

    db.commit()
    db.refresh(active_break)

    return {
        "success": True,
        "message": "Break ended",
        "break": active_break,
    }


# ============================================================
# CHECKOUT
# ============================================================

def checkout_user(
    db: Session,
    user_id: int,
):
    attendance = get_today_attendance(
        db,
        user_id,
    )

    if not attendance:
        return {
            "success": False,
            "message": "Attendance not found",
            "attendance": None,
        }

    if attendance.checkout:
        return {
            "success": False,
            "message": "Already checked out",
            "attendance": attendance,
        }

    # --------------------------------------------------------
    # Cannot checkout during active break
    # --------------------------------------------------------

    active_break = (
        db.query(AttendanceBreak)
        .filter(
            AttendanceBreak.attendance_id == attendance.id,
            AttendanceBreak.end_time.is_(None),
        )
        .first()
    )

    if active_break:
        return {
            "success": False,
            "message": "End your break before checkout",
            "attendance": attendance,
        }

    # --------------------------------------------------------
    # Server-side checkout timestamp
    # --------------------------------------------------------

    checkout_time = now_india()

    attendance.checkout = checkout_time

    # --------------------------------------------------------
    # Calculate work duration
    # --------------------------------------------------------

    total_duration = elapsed_between(attendance.check_in, checkout_time)

    total_work_minutes = (
        int(total_duration.total_seconds() // 60)
        - (attendance.total_break_minutes or 0)
    )

    attendance.total_work_minutes = max(
        0,
        total_work_minutes,
    )

    db.commit()
    db.refresh(attendance)

    return {
        "success": True,
        "message": "Checkout successful",
        "attendance": attendance,
    }


# ============================================================
# AUTO CHECKOUT
# ============================================================

def auto_checkout_user(
    db: Session,
    user_id: int,
    latitude: float,
    longitude: float,
):
    attendance = get_today_attendance(
        db,
        user_id,
    )

    if not attendance:
        return {
            "success": False,
            "message": "Today's attendance not found",
            "attendance": None,
        }

    if attendance.checkout:
        return {
            "success": True,
            "message": "Already checked out",
            "attendance": attendance,
        }

    # --------------------------------------------------------
    # Verify current location
    # --------------------------------------------------------

    geofence_result = validate_geofence(
        db,
        latitude,
        longitude,
    )

    # User must be OUTSIDE the campus
    if not geofence_result.get("enforced", True):
        return {
            "success": False,
            "message": "Automatic checkout requires an active geofence",
            "attendance": attendance,
        }

    if geofence_result["valid"]:
        return {
            "success": False,
            "message": "User is still inside campus",
            "attendance": attendance,
        }

    # --------------------------------------------------------
    # If a break is active, close it first
    # --------------------------------------------------------

    active_break = (
        db.query(AttendanceBreak)
        .filter(
            AttendanceBreak.attendance_id == attendance.id,
            AttendanceBreak.end_time.is_(None),
        )
        .first()
    )

    current_time = now_india()

    if active_break:
        active_break.end_time = current_time

        duration = elapsed_between(
            active_break.start_time, current_time
        ).total_seconds() / 60

        active_break.duration_minutes = max(
            0,
            round(duration),
        )

        completed_breaks = (
            db.query(AttendanceBreak)
            .filter(
                AttendanceBreak.attendance_id == attendance.id,
                AttendanceBreak.duration_minutes.is_not(None),
            )
            .all()
        )

        attendance.total_break_minutes = sum(
            item.duration_minutes or 0
            for item in completed_breaks
        )

    # --------------------------------------------------------
    # Checkout
    # --------------------------------------------------------

    attendance.checkout = current_time

    total_duration = elapsed_between(attendance.check_in, current_time)

    total_work_minutes = (
        int(total_duration.total_seconds() // 60)
        - (attendance.total_break_minutes or 0)
    )

    attendance.total_work_minutes = max(
        0,
        total_work_minutes,
    )

    db.commit()
    db.refresh(attendance)

    return {
        "success": True,
        "message": "Auto checkout successful",
        "attendance": attendance,
    }


# ============================================================
# ATTENDANCE HISTORY
# ============================================================

def get_attendance_history(
    db: Session,
    user_id: int,
    month: int | None = None,
    year: int | None = None,
):
    query = (
        db.query(Attendance)
        .filter(
            Attendance.user_id == user_id
        )
    )

    if year is not None:
        query = query.filter(
            extract(
                "year",
                Attendance.attendance_date,
            ) == year
        )

    if month is not None:
        query = query.filter(
            extract(
                "month",
                Attendance.attendance_date,
            ) == month
        )

    records = (
        query
        .order_by(
            Attendance.attendance_date.desc()
        )
        .all()
    )

    if not records:
        return []

    breaks_by_attendance = {record.id: [] for record in records}
    for attendance_break in (
        db.query(AttendanceBreak)
        .filter(
            AttendanceBreak.attendance_id.in_([record.id for record in records])
        )
        .all()
    ):
        breaks_by_attendance[attendance_break.attendance_id].append(attendance_break)

    current_time = now_india()
    today = today_india()
    history = []
    for record in records:
        record_breaks = breaks_by_attendance[record.id]
        active_break = next(
            (item for item in record_breaks if item.end_time is None),
            None,
        )
        break_minutes = 0
        for item in record_breaks:
            if item.duration_minutes is not None:
                break_minutes += item.duration_minutes
            elif item.end_time is not None:
                break_minutes += max(
                    0,
                    int(elapsed_between(item.start_time, item.end_time).total_seconds() // 60),
                )
        if active_break is not None:
            break_minutes += max(
                0,
                int(elapsed_between(active_break.start_time, current_time).total_seconds() // 60),
            )
        elif not record_breaks:
            break_minutes = record.total_break_minutes or 0

        work_minutes = record.total_work_minutes
        if record.checkout and record.check_in:
            elapsed = elapsed_between(record.check_in, record.checkout)
            work_minutes = max(
                0,
                int(elapsed.total_seconds() // 60) - break_minutes,
            )
        elif record.attendance_date == today and record.check_in:
            elapsed = elapsed_between(record.check_in, current_time)
            work_minutes = max(
                0,
                int(elapsed.total_seconds() // 60) - break_minutes,
            )
        elif not record.checkout:
            # Past records without checkout have no reliable end time.
            work_minutes = None

        history.append({
            "id": record.id,
            "attendance_date": record.attendance_date,
            "check_in": record.check_in,
            "checkout": record.checkout,
            "attendance_status": record.attendance_status,
            "arrival_status": record.arrival_status,
            "total_break_minutes": break_minutes,
            "total_work_minutes": work_minutes,
            "active_break": active_break is not None,
            "current_break_start": active_break.start_time if active_break else None,
        })

    return history
