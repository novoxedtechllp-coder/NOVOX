from datetime import date
from pydantic import BaseModel, EmailStr, Field


class StudentCreate(BaseModel):
    name: str
    email: EmailStr
    password: str
    phone: str | None = None

    student_code: str
    course: str
    batch: str | None = None
    joining_date: date | None = None

    guardian_name: str | None = None
    guardian_phone: str | None = None
    total_fees: float | None = Field(default=None, ge=0)


class StudentUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    student_code: str | None = None
    course: str | None = None
    batch: str | None = None
    joining_date: date | None = None
    guardian_name: str | None = None
    guardian_phone: str | None = None


class StudentAdminResponse(BaseModel):
    id: int
    user_id: int
    name: str
    email: EmailStr
    phone: str | None
    is_active: bool
    student_code: str
    course: str
    batch: str | None
    joining_date: date | None
    guardian_name: str | None
    guardian_phone: str | None
    total_fees: float = 0
