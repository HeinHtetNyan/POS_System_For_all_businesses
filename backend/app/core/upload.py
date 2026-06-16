from __future__ import annotations

import os
import uuid
from pathlib import Path

from fastapi import UploadFile

from app.core.config import settings
from app.core.exceptions import ValidationError
from app.core.logging import get_logger

logger = get_logger(__name__)

# Map content-type → canonical extension
_ALLOWED: dict[str, str] = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "application/pdf": ".pdf",
}

# Logo upload: images only, 2 MB max, one file per tenant (overwrites on re-upload)
_LOGO_ALLOWED: dict[str, str] = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
}
_LOGO_MAX_MB = 2

# Magic byte signatures for each allowed MIME type
_MAGIC_BYTES: list[tuple[bytes, str]] = [
    (b"\xff\xd8\xff", "image/jpeg"),
    (b"\x89PNG\r\n\x1a\n", "image/png"),
    (b"%PDF-", "application/pdf"),
]


def _sniff_mime(data: bytes) -> str | None:
    for magic, mime in _MAGIC_BYTES:
        if data[: len(magic)] == magic:
            return mime
    return None


def _upload_root() -> Path:
    return Path(settings.UPLOAD_DIR).resolve()


async def save_payment_proof(
    file: UploadFile,
    tenant_id: uuid.UUID,
) -> str:
    """Validate, save, and return the relative URL path for a payment proof file.

    Raises ValidationError on bad content-type or oversized file.
    Returns a path like ``/uploads/proofs/<tenant_id>/<uuid>.ext``.
    """
    content_type = file.content_type or ""
    if content_type not in _ALLOWED:
        raise ValidationError(
            f"Unsupported file type '{content_type}'. "
            f"Allowed: {', '.join(_ALLOWED)}"
        )

    max_bytes = settings.UPLOAD_MAX_FILE_SIZE_MB * 1024 * 1024
    contents = await file.read()
    if len(contents) > max_bytes:
        raise ValidationError(
            f"File too large. Maximum size is {settings.UPLOAD_MAX_FILE_SIZE_MB} MB."
        )

    # Verify actual file bytes match the declared content-type
    actual_mime = _sniff_mime(contents)
    if actual_mime is None:
        raise ValidationError("File contents do not match any allowed file type.")
    if actual_mime != content_type:
        raise ValidationError(
            f"File contents appear to be '{actual_mime}' but "
            f"Content-Type declared '{content_type}'."
        )

    ext = _ALLOWED[content_type]
    filename = f"{uuid.uuid4().hex}{ext}"

    dest_dir = _upload_root() / "proofs" / str(tenant_id)
    dest_dir.mkdir(parents=True, exist_ok=True)

    dest_path = dest_dir / filename
    dest_path.write_bytes(contents)

    logger.info(
        "payment_proof_saved",
        tenant_id=str(tenant_id),
        filename=filename,
        size=len(contents),
    )

    return f"/uploads/proofs/{tenant_id}/{filename}"


async def save_receipt_logo(file: UploadFile, tenant_id: uuid.UUID) -> str:
    """Validate and save a receipt logo, overwriting any existing one.

    Only JPEG and PNG accepted. Max 2 MB. One logo per tenant.
    Returns a path like ``/uploads/logos/<tenant_id>.ext``.
    """
    content_type = file.content_type or ""
    if content_type not in _LOGO_ALLOWED:
        raise ValidationError(
            f"Unsupported file type '{content_type}'. Allowed: JPEG, PNG"
        )

    max_bytes = _LOGO_MAX_MB * 1024 * 1024
    contents = await file.read()
    if len(contents) > max_bytes:
        raise ValidationError(f"Logo too large. Maximum size is {_LOGO_MAX_MB} MB.")

    actual_mime = _sniff_mime(contents)
    if actual_mime not in _LOGO_ALLOWED:
        raise ValidationError("File contents do not appear to be a valid image.")
    if actual_mime != content_type:
        raise ValidationError(
            f"File contents appear to be '{actual_mime}' but "
            f"Content-Type declared '{content_type}'."
        )

    ext = _LOGO_ALLOWED[content_type]
    logos_dir = _upload_root() / "logos"
    logos_dir.mkdir(parents=True, exist_ok=True)

    # Remove any existing logo for this tenant (handles jpeg↔png switches)
    for old_ext in _LOGO_ALLOWED.values():
        old = logos_dir / f"{tenant_id}{old_ext}"
        if old.exists():
            old.unlink()

    dest = logos_dir / f"{tenant_id}{ext}"
    dest.write_bytes(contents)

    logger.info("receipt_logo_saved", tenant_id=str(tenant_id), ext=ext, size=len(contents))
    return f"/uploads/logos/{tenant_id}{ext}"


def delete_receipt_logo(tenant_id: uuid.UUID) -> None:
    """Remove the receipt logo file for this tenant. Silent if none exists."""
    logos_dir = _upload_root() / "logos"
    for ext in _LOGO_ALLOWED.values():
        path = logos_dir / f"{tenant_id}{ext}"
        if path.exists():
            path.unlink()


def get_receipt_logo_path(tenant_id: uuid.UUID) -> tuple[Path, str] | None:
    """Return (file_path, mime_type) if a logo file exists, else None."""
    logos_dir = _upload_root() / "logos"
    for mime, ext in _LOGO_ALLOWED.items():
        path = logos_dir / f"{tenant_id}{ext}"
        if path.exists():
            return path, mime
    return None


async def save_payment_method_icon(file: UploadFile) -> str:
    """Validate and save a platform payment method icon (JPEG/PNG, max 2 MB).

    Returns a path like ``/uploads/payment-icons/<uuid>.ext``.
    """
    content_type = file.content_type or ""
    if content_type not in _LOGO_ALLOWED:
        raise ValidationError(
            f"Unsupported file type '{content_type}'. Allowed: JPEG, PNG"
        )

    max_bytes = _LOGO_MAX_MB * 1024 * 1024
    contents = await file.read()
    if len(contents) > max_bytes:
        raise ValidationError(f"Icon too large. Maximum size is {_LOGO_MAX_MB} MB.")

    actual_mime = _sniff_mime(contents)
    if actual_mime not in _LOGO_ALLOWED:
        raise ValidationError("File contents do not appear to be a valid image.")
    if actual_mime != content_type:
        raise ValidationError(
            f"File contents appear to be '{actual_mime}' but "
            f"Content-Type declared '{content_type}'."
        )

    ext = _LOGO_ALLOWED[content_type]
    icons_dir = _upload_root() / "payment-icons"
    icons_dir.mkdir(parents=True, exist_ok=True)

    filename = f"{uuid.uuid4().hex}{ext}"
    dest_path = icons_dir / filename
    dest_path.write_bytes(contents)

    logger.info("payment_method_icon_saved", filename=filename, size=len(contents))
    return f"/uploads/payment-icons/{filename}"
