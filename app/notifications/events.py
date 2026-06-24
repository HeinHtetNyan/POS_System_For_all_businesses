from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

from app.events.base import DomainEvent
from app.events.publisher import event_publisher
from app.events.types import EventType


@dataclass
class EventPayload:
    """
    Lightweight wrapper used by notification handlers to describe what happened.
    This mirrors the fields callers most often need when constructing notifications.
    """

    event_type: str
    tenant_id: uuid.UUID | None
    payload: dict[str, Any] = field(default_factory=dict)
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @classmethod
    def from_domain_event(cls, event: DomainEvent) -> "EventPayload":
        return cls(
            event_type=event.event_type,
            tenant_id=event.tenant_id,
            payload=event.payload,
            created_at=event.occurred_at,
        )


async def publish_notification_event(
    event_type: str,
    tenant_id: uuid.UUID | None,
    payload: dict[str, Any],
    actor_id: uuid.UUID | None = None,
) -> None:
    """Publish a DomainEvent through the process-level event bus."""
    await event_publisher.publish(
        DomainEvent(
            event_type=event_type,
            tenant_id=tenant_id,
            actor_id=actor_id,
            payload=payload,
        )
    )
