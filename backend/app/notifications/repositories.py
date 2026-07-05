from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.notifications.models import Notification, NotificationPreference, NotificationRecipient


class NotificationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        *,
        tenant_id: uuid.UUID | None,
        type: str,
        priority: str,
        title: str,
        message: str,
        metadata: dict | None = None,
        expires_at: datetime | None = None,
    ) -> Notification:
        notification = Notification(
            tenant_id=tenant_id,
            type=type,
            priority=priority,
            title=title,
            message=message,
            metadata_=metadata,
            expires_at=expires_at,
        )
        self.session.add(notification)
        await self.session.flush()
        await self.session.refresh(notification)
        return notification

    async def get_by_id(self, notification_id: uuid.UUID) -> Notification | None:
        stmt = (
            select(Notification)
            .options(selectinload(Notification.recipients))
            .where(Notification.id == notification_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id_for_user(
        self, notification_id: uuid.UUID, user_id: uuid.UUID
    ) -> tuple[Notification, bool, datetime | None] | None:
        """Fetch one notification, but only if `user_id` is an actual recipient —
        prevents guessing another user's notification ID to read their data."""
        stmt = (
            select(Notification, NotificationRecipient.is_read, NotificationRecipient.read_at)
            .join(
                NotificationRecipient,
                Notification.id == NotificationRecipient.notification_id,
            )
            .where(
                Notification.id == notification_id,
                NotificationRecipient.user_id == user_id,
            )
        )
        result = await self.session.execute(stmt)
        row = result.first()
        return (row[0], row[1], row[2]) if row else None

    async def list_for_user(
        self,
        user_id: uuid.UUID,
        tenant_id: uuid.UUID | None,
        offset: int = 0,
        limit: int = 20,
        type_filter: str | None = None,
        priority_filter: str | None = None,
        is_read_filter: bool | None = None,
    ) -> tuple[list[tuple[Notification, bool, datetime | None]], int]:
        """Return (notification, is_read, read_at) tuples for a user."""
        base = (
            select(Notification, NotificationRecipient.is_read, NotificationRecipient.read_at)
            .join(
                NotificationRecipient,
                Notification.id == NotificationRecipient.notification_id,
            )
            .where(NotificationRecipient.user_id == user_id)
            .where(
                or_(
                    Notification.expires_at.is_(None),
                    Notification.expires_at > func.now(),
                )
            )
        )

        # Tenant isolation: regular users see their tenant's notifications +
        # platform (NULL tenant) notifications. Super admins with no tenant_id
        # see only platform notifications via the recipient list.
        if tenant_id is not None:
            base = base.where(
                or_(
                    Notification.tenant_id == tenant_id,
                    Notification.tenant_id.is_(None),
                )
            )
        else:
            # super_admin scope — only platform notifications (tenant_id IS NULL)
            base = base.where(Notification.tenant_id.is_(None))

        if type_filter is not None:
            base = base.where(Notification.type == type_filter)
        if priority_filter is not None:
            base = base.where(Notification.priority == priority_filter)
        if is_read_filter is not None:
            base = base.where(NotificationRecipient.is_read == is_read_filter)

        count_stmt = select(func.count()).select_from(base.subquery())
        total_result = await self.session.execute(count_stmt)
        total = total_result.scalar_one()

        stmt = base.order_by(Notification.created_at.desc()).offset(offset).limit(limit)
        result = await self.session.execute(stmt)
        rows = result.all()
        return [(r[0], r[1], r[2]) for r in rows], total

    async def get_unread_count(
        self,
        user_id: uuid.UUID,
        tenant_id: uuid.UUID | None,
    ) -> int:
        base = (
            select(func.count())
            .select_from(Notification)
            .join(
                NotificationRecipient,
                Notification.id == NotificationRecipient.notification_id,
            )
            .where(NotificationRecipient.user_id == user_id)
            .where(NotificationRecipient.is_read.is_(False))
            .where(
                or_(
                    Notification.expires_at.is_(None),
                    Notification.expires_at > func.now(),
                )
            )
        )
        if tenant_id is not None:
            base = base.where(
                or_(
                    Notification.tenant_id == tenant_id,
                    Notification.tenant_id.is_(None),
                )
            )
        else:
            base = base.where(Notification.tenant_id.is_(None))

        result = await self.session.execute(base)
        return result.scalar_one()

    async def delete_expired(self, now: datetime) -> int:
        """Hard-delete notifications whose expires_at has passed."""
        from sqlalchemy import delete

        stmt = delete(Notification).where(
            Notification.expires_at.is_not(None),
            Notification.expires_at < now,
        )
        result = await self.session.execute(stmt)
        await self.session.flush()
        return result.rowcount


class NotificationRecipientRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create(
        self,
        notification_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> NotificationRecipient:
        recipient = NotificationRecipient(
            notification_id=notification_id,
            user_id=user_id,
            is_read=False,
        )
        self.session.add(recipient)
        await self.session.flush()
        await self.session.refresh(recipient)
        return recipient

    async def create_many(
        self,
        notification_id: uuid.UUID,
        user_ids: list[uuid.UUID],
    ) -> list[NotificationRecipient]:
        recipients = [
            NotificationRecipient(
                notification_id=notification_id,
                user_id=uid,
                is_read=False,
            )
            for uid in user_ids
        ]
        self.session.add_all(recipients)
        await self.session.flush()
        return recipients

    async def get_by_notification_and_user(
        self,
        notification_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> NotificationRecipient | None:
        stmt = select(NotificationRecipient).where(
            NotificationRecipient.notification_id == notification_id,
            NotificationRecipient.user_id == user_id,
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def mark_read(
        self,
        recipient: NotificationRecipient,
        now: datetime,
    ) -> NotificationRecipient:
        recipient.is_read = True
        recipient.read_at = now
        await self.session.flush()
        await self.session.refresh(recipient)
        return recipient

    async def mark_all_read(
        self,
        user_id: uuid.UUID,
        tenant_id: uuid.UUID | None,
        now: datetime,
    ) -> int:
        """Mark all unread notifications for a user as read. Returns count updated."""
        if tenant_id is not None:
            tenant_filter = or_(
                Notification.tenant_id == tenant_id,
                Notification.tenant_id.is_(None),
            )
        else:
            tenant_filter = Notification.tenant_id.is_(None)

        eligible_notification_ids = (
            select(Notification.id)
            .join(
                NotificationRecipient,
                Notification.id == NotificationRecipient.notification_id,
            )
            .where(NotificationRecipient.user_id == user_id)
            .where(tenant_filter)
        )

        stmt = (
            update(NotificationRecipient)
            .where(
                NotificationRecipient.user_id == user_id,
                NotificationRecipient.is_read.is_(False),
                NotificationRecipient.notification_id.in_(eligible_notification_ids),
            )
            .values(is_read=True, read_at=now)
        )
        result = await self.session.execute(stmt)
        await self.session.flush()
        return result.rowcount


class NotificationPreferenceRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_user(self, user_id: uuid.UUID) -> NotificationPreference | None:
        stmt = select(NotificationPreference).where(
            NotificationPreference.user_id == user_id
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_or_create(self, user_id: uuid.UUID) -> NotificationPreference:
        pref = await self.get_by_user(user_id)
        if pref is None:
            pref = NotificationPreference(user_id=user_id)
            self.session.add(pref)
            await self.session.flush()
            await self.session.refresh(pref)
        return pref

    async def update(
        self,
        pref: NotificationPreference,
        **kwargs: bool,
    ) -> NotificationPreference:
        for key, value in kwargs.items():
            if value is not None and hasattr(pref, key):
                setattr(pref, key, value)
        await self.session.flush()
        await self.session.refresh(pref)
        return pref
