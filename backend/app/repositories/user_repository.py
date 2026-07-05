from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.user import User, UserBranchAssignment
from app.repositories.base import BaseRepository


class UserRepository(BaseRepository[User]):
    def __init__(self, session: AsyncSession) -> None:
        super().__init__(User, session)

    async def get_by_email(self, email: str) -> User | None:
        # .limit(1): staff emails are only unique per-tenant now (see User model),
        # so two different businesses' staff could share one — without this,
        # scalar_one_or_none() would raise MultipleResultsFound. Callers that
        # need to guarantee a non-staff match should use get_by_email_for_login.
        stmt = select(User).where(User.email == email, User.is_deleted.is_(False)).limit(1)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email_for_login(self, email: str) -> User | None:
        """
        Like get_by_email, but only matches BUSINESS_OWNER/RESELLER/SUPER_ADMIN —
        the roles that log in with plain email+password (no business code).
        Staff emails are only unique per-tenant, so this path must never match
        a staff row: doing so would be ambiguous (which tenant's staff member?)
        and staff must always sign in via business code + phone instead.
        """
        from app.core.constants import UserRole

        stmt = select(User).where(
            User.email == email,
            User.is_deleted.is_(False),
            User.role.in_([UserRole.BUSINESS_OWNER, UserRole.RESELLER, UserRole.SUPER_ADMIN]),
        ).limit(1)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_phone_and_tenant(self, phone: str, tenant_id: uuid.UUID) -> User | None:
        # .limit(1): two staff in the same tenant could already share an identical
        # phone (pre-existing data, not something normalization creates) — without
        # this, scalar_one_or_none() would raise MultipleResultsFound at login.
        stmt = select(User).where(
            User.phone == phone,
            User.tenant_id == tenant_id,
            User.is_deleted.is_(False),
        ).limit(1)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_email_and_tenant(self, email: str, tenant_id: uuid.UUID) -> User | None:
        stmt = select(User).where(
            User.email == email,
            User.tenant_id == tenant_id,
            User.is_deleted.is_(False),
        ).limit(1)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()


    async def get_by_id_active(self, user_id: uuid.UUID) -> User | None:
        stmt = select(User).where(User.id == user_id, User.is_deleted.is_(False))
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_tenant(
        self,
        tenant_id: uuid.UUID,
        offset: int = 0,
        limit: int = 20,
    ) -> tuple[list[User], int]:
        filters = [User.tenant_id == tenant_id, User.is_deleted.is_(False)]
        return await self.get_all(offset=offset, limit=limit, filters=filters)

    async def get_all_users(
        self,
        offset: int = 0,
        limit: int = 20,
        role: str | None = None,
    ) -> tuple[list[User], int]:
        from app.core.constants import UserRole
        filters = [User.is_deleted.is_(False), User.role != UserRole.SUPER_ADMIN]
        if role:
            filters.append(User.role == role)
        return await self.get_all(offset=offset, limit=limit, filters=filters)

    async def soft_delete(self, user: User) -> User:
        user.is_deleted = True
        user.deleted_at = datetime.now(timezone.utc)
        await self.session.flush()
        return user

    async def update_last_login(self, user_id: uuid.UUID) -> None:
        stmt = (
            update(User)
            .where(User.id == user_id)
            .values(last_login_at=datetime.now(timezone.utc))
        )
        await self.session.execute(stmt)

    async def email_exists(
        self,
        email: str,
        exclude_id: uuid.UUID | None = None,
        tenant_id: uuid.UUID | None = None,
    ) -> bool:
        """
        Pass tenant_id to check staff-style per-tenant uniqueness (matches the
        uq_users_email_per_tenant_staff index); omit it for the global check
        (matches uq_users_email_global_non_staff, used for owner/reseller/admin).
        """
        stmt = select(User.id).where(User.email == email, User.is_deleted.is_(False))
        if tenant_id is not None:
            stmt = stmt.where(User.tenant_id == tenant_id)
        if exclude_id:
            stmt = stmt.where(User.id != exclude_id)
        stmt = stmt.limit(1)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none() is not None

    async def assign_branch(
        self,
        user_id: uuid.UUID,
        branch_id: uuid.UUID,
        tenant_id: uuid.UUID,
        is_primary: bool = False,
    ) -> UserBranchAssignment:
        assignment = UserBranchAssignment(
            user_id=user_id,
            branch_id=branch_id,
            tenant_id=tenant_id,
            is_primary=is_primary,
        )
        self.session.add(assignment)
        await self.session.flush()
        await self.session.refresh(assignment)
        return assignment

    async def remove_branch_assignment(
        self, user_id: uuid.UUID, branch_id: uuid.UUID
    ) -> bool:
        stmt = select(UserBranchAssignment).where(
            UserBranchAssignment.user_id == user_id,
            UserBranchAssignment.branch_id == branch_id,
        )
        result = await self.session.execute(stmt)
        assignment = result.scalar_one_or_none()
        if assignment:
            await self.session.delete(assignment)
            await self.session.flush()
            return True
        return False
