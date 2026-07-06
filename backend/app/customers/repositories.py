from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.customers.models import Customer, CustomerContact, CustomerCounter, CustomerLedger, CustomerNote
from app.repositories.base import BaseRepository


class CustomerCounterRepository(BaseRepository[CustomerCounter]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(CustomerCounter, session)

    async def get_or_create_locked(self, tenant_id: uuid.UUID) -> CustomerCounter:
        """
        Fetch (or create) the per-tenant counter row with SELECT FOR UPDATE.
        The lock is held until the enclosing transaction commits, preventing
        duplicate customer codes under concurrent creation.
        """
        stmt = (
            select(CustomerCounter)
            .where(CustomerCounter.tenant_id == tenant_id)
            .with_for_update()
        )
        result = await self.session.execute(stmt)
        counter = result.scalar_one_or_none()
        if counter is None:
            counter = CustomerCounter(tenant_id=tenant_id, last_seq=0)
            self.session.add(counter)
            await self.session.flush()
        return counter

    async def increment(self, counter: CustomerCounter) -> int:
        counter.last_seq += 1
        await self.session.flush()
        return counter.last_seq


class CustomerRepository(BaseRepository[Customer]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(Customer, session)

    async def get_active_by_id_and_tenant(
        self, customer_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Customer | None:
        stmt = select(Customer).where(
            Customer.id == customer_id,
            Customer.tenant_id == tenant_id,
            Customer.deleted_at.is_(None),
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_active_by_id_and_tenant_locked(
        self, customer_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Customer | None:
        """Same as get_active_by_id_and_tenant, but with SELECT FOR UPDATE —
        use before reading current_balance to mutate it, so two concurrent
        balance-affecting requests for the same customer can't lose an update."""
        stmt = select(Customer).where(
            Customer.id == customer_id,
            Customer.tenant_id == tenant_id,
            Customer.deleted_at.is_(None),
        ).with_for_update()
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_with_contacts(
        self, customer_id: uuid.UUID, tenant_id: uuid.UUID
    ) -> Customer | None:
        stmt = (
            select(Customer)
            .where(
                Customer.id == customer_id,
                Customer.tenant_id == tenant_id,
                Customer.deleted_at.is_(None),
            )
            .options(selectinload(Customer.contacts))
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def phone_exists(
        self,
        tenant_id: uuid.UUID,
        phone: str,
        exclude_id: uuid.UUID | None = None,
    ) -> bool:
        stmt = select(Customer.id).where(
            Customer.tenant_id == tenant_id,
            Customer.phone == phone,
            Customer.deleted_at.is_(None),
        )
        if exclude_id:
            stmt = stmt.where(Customer.id != exclude_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none() is not None

    async def get_by_tenant(
        self,
        tenant_id: uuid.UUID,
        offset: int = 0,
        limit: int = 20,
        is_active: bool | None = None,
    ) -> tuple[list[Customer], int]:
        filters = [Customer.tenant_id == tenant_id, Customer.deleted_at.is_(None)]
        if is_active is not None:
            filters.append(Customer.is_active == is_active)
        return await self.get_all(offset=offset, limit=limit, filters=filters)

    async def search(
        self,
        tenant_id: uuid.UUID,
        query: str,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[Customer], int]:
        pattern = f"%{query}%"
        base_filters = [
            Customer.tenant_id == tenant_id,
            Customer.deleted_at.is_(None),
            or_(
                Customer.name.ilike(pattern),
                Customer.phone.ilike(pattern),
                Customer.customer_code.ilike(pattern),
                Customer.email.ilike(pattern),
            ),
        ]
        return await self.get_all(offset=offset, limit=limit, filters=base_filters)

    async def soft_delete(self, customer: Customer) -> None:
        customer.deleted_at = datetime.now(timezone.utc)
        customer.is_active = False
        await self.session.flush()


class CustomerContactRepository(BaseRepository[CustomerContact]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(CustomerContact, session)

    async def get_by_customer(self, customer_id: uuid.UUID) -> list[CustomerContact]:
        stmt = select(CustomerContact).where(
            CustomerContact.customer_id == customer_id
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_by_id_and_customer(
        self, contact_id: uuid.UUID, customer_id: uuid.UUID
    ) -> CustomerContact | None:
        stmt = select(CustomerContact).where(
            CustomerContact.id == contact_id,
            CustomerContact.customer_id == customer_id,
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()


class CustomerNoteRepository(BaseRepository[CustomerNote]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(CustomerNote, session)

    async def get_by_customer(self, customer_id: uuid.UUID) -> list[CustomerNote]:
        stmt = (
            select(CustomerNote)
            .where(CustomerNote.customer_id == customer_id)
            .order_by(CustomerNote.created_at.desc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())


class CustomerLedgerRepository(BaseRepository[CustomerLedger]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(CustomerLedger, session)

    async def get_by_customer(
        self,
        customer_id: uuid.UUID,
        date_from: datetime | None = None,
        date_to: datetime | None = None,
    ) -> list[CustomerLedger]:
        stmt = (
            select(CustomerLedger)
            .where(CustomerLedger.customer_id == customer_id)
        )
        if date_from:
            stmt = stmt.where(CustomerLedger.created_at >= date_from)
        if date_to:
            stmt = stmt.where(CustomerLedger.created_at <= date_to)
        stmt = stmt.order_by(CustomerLedger.created_at.asc())
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_opening_balance(
        self, customer_id: uuid.UUID, before: datetime
    ) -> Decimal:
        """Return balance_after of the last ledger entry strictly before `before`."""
        from decimal import Decimal as _D
        stmt = (
            select(CustomerLedger.balance_after)
            .where(
                CustomerLedger.customer_id == customer_id,
                CustomerLedger.created_at < before,
            )
            .order_by(CustomerLedger.created_at.desc())
            .limit(1)
        )
        result = await self.session.execute(stmt)
        row = result.scalar_one_or_none()
        return row if row is not None else _D("0")

