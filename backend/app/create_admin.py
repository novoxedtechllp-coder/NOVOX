
import getpass
import os

from pydantic import EmailStr, TypeAdapter, ValidationError
from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.database.connection import SessionLocal
from app.models.user import User


def create_admin():
    if os.getenv("APP_ENV", "").strip().lower() != "production":
        raise SystemExit(
            "Refusing to create a production administrator unless "
            "APP_ENV=production is set."
        )

    email = input("Administrator email: ").strip().lower()
    name = input("Administrator full name: ").strip()
    phone = input("Phone number (optional): ").strip() or None

    try:
        email = str(TypeAdapter(EmailStr).validate_python(email))
    except ValidationError:
        raise SystemExit("Enter a valid email address.")

    if not name or len(name) > 100:
        raise SystemExit("Name is required and must be at most 100 characters.")

    if len(email) > 150:
        raise SystemExit("Email must be at most 150 characters.")

    if phone and len(phone) > 20:
        raise SystemExit("Phone number must be at most 20 characters.")

    password = getpass.getpass("New password (minimum 12 characters): ")
    confirmation = getpass.getpass("Confirm password: ")

    if password != confirmation:
        raise SystemExit("Passwords do not match.")

    if len(password) < 12:
        raise SystemExit("Use at least 12 characters for the password.")

    db: Session = SessionLocal()

    try:
        existing_user = (
            db.query(User)
            .filter(User.email == email)
            .first()
        )

        if existing_user:
            raise SystemExit(
                "An account with this email already exists. "
                "No changes were made."
            )

        admin = User(
            name=name,
            email=email,
            password_hash=hash_password(password),
            role="admin",
            phone=phone,
            is_active=True,
        )

        db.add(admin)
        db.commit()

        print(f"Administrator created successfully: {email}")

    except SystemExit:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    create_admin()
