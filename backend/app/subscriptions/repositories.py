from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.subscriptions.models import (
    PaymentProof,
    SubscriptionHistory,
    SubscriptionPlan,
    TenantSubscription,
)


class SubscriptionPlanRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_id(self, plan_id: uuid.UUID) -> SubscriptionPlan | None:
        stmt = (
            select(SubscriptionPlan)
            .options(selectinload(SubscriptionPlan.entitlements))
            .where(SubscriptionPlan.id == plan_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_code(self, code: str) -> SubscriptionPlan | None:
        stmt = (
            select(SubscriptionPlan)
            .where(SubscriptionPlan.code == code)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_trial_plan(self) -> SubscriptionPlan | None:
        stmt = (
            select(SubscriptionPlan)
            .options(selectinload(SubscriptionPlan.entitlements))
            .where(
                SubscriptionPlan.is_trial.is_(True),
                SubscriptionPlan.is_active.is_(True),
                SubscriptionPlan.is_referral_plan.is_(False),
            )
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_referral_plan(self) -> SubscriptionPlan | None:
        stmt = (
            select(SubscriptionPlan)
            .where(SubscriptionPlan.is_referral_plan.is_(True), SubscriptionPlan.is_active.is_(True))
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_public_plans(self) -> list[SubscriptionPlan]:
        stmt = (
            select(SubscriptionPlan)
            .options(selectinload(SubscriptionPlan.entitlements))
            .where(
                SubscriptionPlan.is_active.is_(True),
                SubscriptionPlan.is_public.is_(True),
                SubscriptionPlan.is_trial.is_(False),
            )
            .order_by(SubscriptionPlan.sort_order, SubscriptionPlan.created_at)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def count_trial_plans(self) -> int:
        stmt = select(func.count()).select_from(SubscriptionPlan).where(
            SubscriptionPlan.is_trial.is_(True),
            SubscriptionPlan.is_active.is_(True),
            SubscriptionPlan.is_referral_plan.is_(False),
        )
        result = await self.session.execute(stmt)
        return result.scalar_one()

    async def get_all(
        self,
        offset: int = 0,
        limit: int = 20,
        include_inactive: bool = False,
    ) -> tuple[list[SubscriptionPlan], int]:
        stmt = (
            select(SubscriptionPlan)
            .options(selectinload(SubscriptionPlan.entitlements))
        )
        count_stmt = select(func.count()).select_from(SubscriptionPlan)
        if not include_inactive:
            stmt = stmt.where(SubscriptionPlan.is_active.is_(True))
            count_stmt = count_stmt.where(SubscriptionPlan.is_active.is_(True))
        stmt = stmt.order_by(SubscriptionPlan.sort_order, SubscriptionPlan.created_at)
        stmt = stmt.offset(offset).limit(limit)
        total_result = await self.session.execute(count_stmt)
        total = total_result.scalar_one()
        result = await self.session.execute(stmt)
        return list(result.scalars().all()), total


class TenantSubscriptionRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    def _with_plan(self, stmt):  # type: ignore[no-untyped-def]
        return stmt.options(
            selectinload(TenantSubscription.plan).selectinload(SubscriptionPlan.entitlements)
        )

    async def get_by_tenant(self, tenant_id: uuid.UUID) -> TenantSubscription | None:
        stmt = self._with_plan(
            select(TenantSubscription).where(TenantSubscription.tenant_id == tenant_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id(self, sub_id: uuid.UUID) -> TenantSubscription | None:
        stmt = self._with_plan(
            select(TenantSubscription).where(TenantSubscription.id == sub_id)
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id_locked(self, sub_id: uuid.UUID) -> TenantSubscription | None:
        """Like get_by_id, but locks the row (SELECT ... FOR UPDATE) first."""
        stmt = self._with_plan(
            select(TenantSubscription)
            .where(TenantSubscription.id == sub_id)
            .with_for_update()
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_tenant_locked(self, tenant_id: uuid.UUID) -> TenantSubscription | None:
        """
        Like get_by_tenant, but locks the row (SELECT ... FOR UPDATE) first.
        Approving a payment proof and cancelling a subscription both
        read-check-then-write this row; without a lock, two concurrent
        requests can both pass validation against the same stale snapshot and
        both apply their side effects (double-extend, double-cancel).
        """
        stmt = self._with_plan(
            select(TenantSubscription)
            .where(TenantSubscription.tenant_id == tenant_id)
            .with_for_update()
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_expiring_trials(self, days: int, now: datetime) -> list[TenantSubscription]:
        from datetime import timedelta
        from app.core.constants import SubscriptionStatus
        window_start = now + timedelta(days=days - 1)
        window_end = now + timedelta(days=days)
        stmt = select(TenantSubscription).where(
            TenantSubscription.status == SubscriptionStatus.TRIAL,
            TenantSubscription.expires_at.is_not(None),
            TenantSubscription.expires_at >= window_start,
            TenantSubscription.expires_at < window_end,
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_expired(self, now: datetime) -> list[TenantSubscription]:
        from app.core.constants import SubscriptionStatus

        stmt = self._with_plan(
            select(TenantSubscription).where(
                TenantSubscription.status.in_([
                    SubscriptionStatus.ACTIVE,
                    SubscriptionStatus.TRIAL,
                ]),
                TenantSubscription.expires_at.is_not(None),
                TenantSubscription.expires_at < now,
            )
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())


class SubscriptionHistoryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def get_by_tenant(
        self, tenant_id: uuid.UUID, offset: int = 0, limit: int = 20
    ) -> tuple[list[SubscriptionHistory], int]:
        count_stmt = (
            select(func.count())
            .select_from(SubscriptionHistory)
            .where(SubscriptionHistory.tenant_id == tenant_id)
        )
        stmt = (
            select(SubscriptionHistory)
            .where(SubscriptionHistory.tenant_id == tenant_id)
            .order_by(SubscriptionHistory.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        total_result = await self.session.execute(count_stmt)
        total = total_result.scalar_one()
        result = await self.session.execute(stmt)
        return list(result.scalars().all()), total


class PaymentProofRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    def _proof_options(self):
        from app.models.tenant import Tenant
        return [
            selectinload(PaymentProof.target_plan),
            selectinload(PaymentProof.tenant),
        ]

    async def get_by_id(self, proof_id: uuid.UUID) -> PaymentProof | None:
        stmt = (
            select(PaymentProof)
            .where(PaymentProof.id == proof_id)
            .options(*self._proof_options())
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id_locked(self, proof_id: uuid.UUID) -> PaymentProof | None:
        """
        Like get_by_id, but locks the row (SELECT ... FOR UPDATE) first — see
        TenantSubscriptionRepository.get_by_tenant_locked for why this matters:
        two concurrent approve/reject calls for the same still-PENDING proof
        must not both pass the status check and both apply their side effects.
        """
        stmt = (
            select(PaymentProof)
            .where(PaymentProof.id == proof_id)
            .options(*self._proof_options())
            .with_for_update()
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_tenant(
        self, tenant_id: uuid.UUID, offset: int = 0, limit: int = 20
    ) -> tuple[list[PaymentProof], int]:
        count_stmt = (
            select(func.count())
            .select_from(PaymentProof)
            .where(PaymentProof.tenant_id == tenant_id)
        )
        stmt = (
            select(PaymentProof)
            .where(PaymentProof.tenant_id == tenant_id)
            .options(*self._proof_options())
            .order_by(PaymentProof.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        total_result = await self.session.execute(count_stmt)
        total = total_result.scalar_one()
        result = await self.session.execute(stmt)
        return list(result.scalars().all()), total

    async def get_approved_by_tenant(self, tenant_id: uuid.UUID) -> list[PaymentProof]:
        """All APPROVED proofs for a tenant, unpaginated — used to reverse every
        commission a reseller may have earned across a subscription's lifetime
        (initial activation, later upgrades) when it's cancelled."""
        from app.core.constants import PaymentProofStatus

        stmt = select(PaymentProof).where(
            PaymentProof.tenant_id == tenant_id,
            PaymentProof.status == PaymentProofStatus.APPROVED,
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_approved_by_subscription_action_and_plan(
        self, subscription_id: uuid.UUID, action_type: str, target_plan_id: uuid.UUID
    ) -> PaymentProof | None:
        """The APPROVED proof (if any) for a specific action_type + target_plan_id
        on a subscription — used to check whether a scheduled downgrade has already
        been paid for and approved, e.g. to block cancelling it once that happens."""
        from app.core.constants import PaymentProofStatus

        stmt = select(PaymentProof).where(
            PaymentProof.subscription_id == subscription_id,
            PaymentProof.action_type == action_type,
            PaymentProof.target_plan_id == target_plan_id,
            PaymentProof.status == PaymentProofStatus.APPROVED,
        )
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def get_pending_by_subscription_and_action(
        self, subscription_id: uuid.UUID, action_type: str
    ) -> list[PaymentProof]:
        """PENDING proofs of a given action_type for a subscription — used to
        reject any in-flight downgrade proof when the pending downgrade it
        would apply is cancelled first, so it can't later be approved as a
        silent no-op."""
        from app.core.constants import PaymentProofStatus

        stmt = select(PaymentProof).where(
            PaymentProof.subscription_id == subscription_id,
            PaymentProof.action_type == action_type,
            PaymentProof.status == PaymentProofStatus.PENDING,
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_all(
        self,
        status: str | None = None,
        offset: int = 0,
        limit: int = 20,
        tenant_id: "uuid.UUID | None" = None,
    ) -> tuple[list[PaymentProof], int]:
        filters = []
        if status:
            filters.append(PaymentProof.status == status)
        if tenant_id:
            filters.append(PaymentProof.tenant_id == tenant_id)
        count_stmt = select(func.count()).select_from(PaymentProof)
        stmt = (
            select(PaymentProof)
            .options(*self._proof_options())
            .order_by(PaymentProof.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        if filters:
            count_stmt = count_stmt.where(*filters)
            stmt = stmt.where(*filters)
        total = (await self.session.execute(count_stmt)).scalar_one()
        result = await self.session.execute(stmt)
        return list(result.scalars().all()), total
