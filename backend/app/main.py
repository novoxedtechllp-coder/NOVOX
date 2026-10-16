
import logging

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text

from app.core.config import settings
from app.database.base import Base
from app.database.connection import engine

# Register all models before initializing database tables.
import app.models  # noqa: F401

from app.routes.auth import router as auth_router
from app.routes.student import router as student_router
from app.routes.staff import router as staff_router
from app.routes.admin import router as admin_router
from app.routes.attendance import router as attendance_router
from app.routes.fees import router as fees_router
from app.routes.salary import router as salary_router
from app.routes.admin_management import (
    router as admin_management_router,
)
from app.routes.geofence_admin import (
    router as geofence_admin_router,
)
from app.routes.reports import router as reports_router
from app.routes.report_exports import (
    router as report_exports_router,
)
from app.routes.websocket import router as websocket_router


logger = logging.getLogger("novox")

app = FastAPI(
    title=settings.APP_NAME,
    version="1.0.0",
)

# CORS: configure CORS_ALLOW_ORIGIN_REGEX in Railway.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=settings.CORS_ALLOW_ORIGIN_REGEX,
    allow_methods=[
        "GET",
        "POST",
        "PUT",
        "PATCH",
        "DELETE",
        "OPTIONS",
    ],
    allow_headers=[
        "Authorization",
        "Content-Type",
        "Accept",
    ],
    allow_credentials=False,
)


def initialize_database():
    """
    Initialize tables using the existing SQLAlchemy models.

    For future production schema changes, use database migrations
    instead of relying on create_all().
    """
    Base.metadata.create_all(bind=engine)

    inspector = inspect(engine)

    if not inspector.has_table("geofence_settings"):
        logger.warning(
            "geofence_settings table is missing."
        )
        return

    existing_columns = {
        column["name"]
        for column in inspector.get_columns(
            "geofence_settings"
        )
    }

    with engine.begin() as connection:
        for column_name in (
            "south",
            "north",
            "west",
            "east",
        ):
            if column_name not in existing_columns:
                connection.execute(
                    text(
                        "ALTER TABLE geofence_settings "
                        f"ADD COLUMN {column_name} FLOAT NULL"
                    )
                )


# Preserve the existing database initialization behavior.
initialize_database()


# Register API routes.
app.include_router(auth_router)
app.include_router(student_router)
app.include_router(staff_router)
app.include_router(attendance_router)
app.include_router(admin_router)
app.include_router(fees_router)
app.include_router(salary_router)
app.include_router(admin_management_router)
app.include_router(geofence_admin_router)
app.include_router(reports_router)
app.include_router(websocket_router)
app.include_router(report_exports_router)


@app.get("/")
def root():
    return {
        "application": settings.APP_NAME,
        "status": "running",
        "version": "1.0.0",
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
    }


@app.get("/database-test")
def database_test():
    """
    Verify database connectivity without exposing internal
    database exceptions or credentials.
    """
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))

        return {
            "status": "success",
            "database": "MySQL connected",
        }

    except Exception:
        logger.exception(
            "NOVOX database connectivity check failed."
        )

        raise HTTPException(
            status_code=503,
            detail="Database connection unavailable",
        )
