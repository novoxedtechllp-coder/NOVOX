from pydantic import BaseModel
from datetime import date, datetime


class DashboardSummary(BaseModel):
    total_students: int
    total_staff: int

    present_today: int
    late_today: int
    checked_out_today: int

    pending_fee_students: int
    total_pending_amount: float


class AttendanceMonitorItem(BaseModel):
    attendance_id: int
    user_id: int
    user_name: str
    user_role: str
    attendance_date: date
    check_in: datetime | None
    checkout: datetime | None
    attendance_status: str
    arrival_status: str
    check_in_distance: float | None


class PendingFeeItem(BaseModel):
    id: int
    student_id: int
    total_amount: float
    paid_amount: float
    pending_amount: float
    status: str
