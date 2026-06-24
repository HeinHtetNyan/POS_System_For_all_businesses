from __future__ import annotations

import uuid
from decimal import Decimal
from enum import Enum
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.repositories.audit_repository import AuditRepository


def _to_json_safe(d: dict[str, Any] | None) -> dict[str, Any] | None:
    """Recursively convert non-JSON-serializable types to strings for JSONB storage."""
    if d is None:
        return None
    result: dict[str, Any] = {}
    for k, v in d.items():
        if isinstance(v, uuid.UUID):
            result[k] = str(v)
        elif isinstance(v, Decimal):
            result[k] = str(v)
        elif isinstance(v, Enum):
            result[k] = v.value
        elif isinstance(v, dict):
            result[k] = _to_json_safe(v)
        else:
            result[k] = v
    return result


class AuditService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.audit_repo = AuditRepository(session)

    async def log(
        self,
        action: str,
        actor_user_id: uuid.UUID | None = None,
        tenant_id: uuid.UUID | None = None,
        branch_id: uuid.UUID | None = None,
        entity_type: str | None = None,
        entity_id: Any = None,
        before_state: dict[str, Any] | None = None,
        after_state: dict[str, Any] | None = None,
        metadata: dict[str, Any] | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
        request_id: str | None = None,
    ) -> None:
        await self.audit_repo.create_log(
            action=action,
            actor_user_id=actor_user_id,
            tenant_id=tenant_id,
            branch_id=branch_id,
            entity_type=entity_type,
            entity_id=str(entity_id) if entity_id is not None else None,
            before_state=_to_json_safe(before_state),
            after_state=_to_json_safe(after_state),
            metadata=_to_json_safe(metadata),
            ip_address=ip_address,
            user_agent=user_agent,
            request_id=request_id,
        )
