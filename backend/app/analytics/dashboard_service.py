from __future__ import annotations

import asyncio
import uuid
from collections.abc import Awaitable, Callable
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import TypeVar

from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.repositories import AnalyticsRepository
from app.analytics.schemas import DashboardResponse
from app.core.constants import AuditAction, EntityType
from app.core.timezone import resolve_zone
from app.db.session import AsyncSessionLocal
from app.services.audit_service import AuditService

T = TypeVar("T")


async def _run_with_own_session(
    query: Callable[[AnalyticsRepository], Awaitable[T]],
) -> T:
    """Run one read against its own short-lived session.

    An AsyncSession can't run more than one query at a time, so the 9
    independent dashboard aggregates below can't be gathered concurrently
    on the shared request-scoped session — each needs its own connection
    to actually overlap instead of queueing behind one another.
    """
    async with AsyncSessionLocal() as session:
        return await query(AnalyticsRepository(session))


class DashboardService:
    def __init__(self, session: AsyncSession) -> None:
        self.repo = AnalyticsRepository(session)
        self.audit = AuditService(session)

    async def get_dashboard(
        self,
        tenant_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        cashier_user_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> DashboardResponse:
        now = datetime.now(timezone.utc)

        # "Today"/"this week"/"this month" must reflect the tenant's own calendar,
        # not UTC's — otherwise orders near local midnight land in the wrong bucket.
        tz_name = await self.repo.get_tenant_timezone(tenant_id)
        zone = resolve_zone(tz_name)
        now_local = now.astimezone(zone)
        today_start_local = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
        tomorrow_local = today_start_local + timedelta(days=1)
        yesterday_start_local = today_start_local - timedelta(days=1)
        week_start_local = today_start_local - timedelta(days=today_start_local.weekday())
        month_start_local = today_start_local.replace(day=1)

        today_start = today_start_local.astimezone(timezone.utc)
        tomorrow = tomorrow_local.astimezone(timezone.utc)
        yesterday_start = yesterday_start_local.astimezone(timezone.utc)
        week_start = week_start_local.astimezone(timezone.utc)
        month_start = month_start_local.astimezone(timezone.utc)

        (
            today_stats,
            yesterday_stats,
            week_stats,
            month_stats,
            refund_stats,
            customer_stats,
            low_stock_count,
            inventory_value,
            total_customer_outstanding,
        ) = await asyncio.gather(
            _run_with_own_session(
                lambda r: r.get_order_stats_in_range(
                    tenant_id, today_start, tomorrow, branch_id, cashier_user_id
                )
            ),
            _run_with_own_session(
                lambda r: r.get_order_stats_in_range(
                    tenant_id, yesterday_start, today_start, branch_id, cashier_user_id
                )
            ),
            _run_with_own_session(
                lambda r: r.get_order_stats_in_range(
                    tenant_id, week_start, tomorrow, branch_id, cashier_user_id
                )
            ),
            _run_with_own_session(
                lambda r: r.get_order_stats_in_range(
                    tenant_id, month_start, tomorrow, branch_id, cashier_user_id
                )
            ),
            _run_with_own_session(
                lambda r: r.get_refund_stats_in_range(tenant_id, month_start, tomorrow)
            ),
            _run_with_own_session(lambda r: r.get_customer_stats(tenant_id, month_start)),
            _run_with_own_session(lambda r: r.get_low_stock_count(tenant_id, branch_id)),
            _run_with_own_session(lambda r: r.get_total_inventory_value(tenant_id, branch_id)),
            _run_with_own_session(lambda r: r.get_total_customer_outstanding(tenant_id)),
        )

        await self.audit.log(
            action=AuditAction.DASHBOARD_VIEWED,
            actor_user_id=actor_id,
            tenant_id=tenant_id,
            entity_type=EntityType.ANALYTICS_REPORT,
            after_state={"branch_id": str(branch_id) if branch_id else None},
            request_id=request_id,
        )

        return DashboardResponse(
            sales_today=Decimal(str(today_stats.get("gross_sales", 0))),
            sales_yesterday=Decimal(str(yesterday_stats.get("gross_sales", 0))),
            sales_this_week=Decimal(str(week_stats.get("gross_sales", 0))),
            sales_this_month=Decimal(str(month_stats.get("gross_sales", 0))),
            orders_today=int(today_stats.get("order_count", 0)),
            orders_this_month=int(month_stats.get("order_count", 0)),
            revenue_today=Decimal(str(today_stats.get("net_revenue", 0))),
            revenue_month=Decimal(str(month_stats.get("net_revenue", 0))),
            refund_count_month=int(refund_stats.get("refund_count", 0)),
            refund_amount_month=Decimal(str(refund_stats.get("refund_amount", 0))),
            total_customers=int(customer_stats.get("total_customers", 0)),
            new_customers_month=int(customer_stats.get("new_customers_month", 0)),
            low_stock_products=low_stock_count,
            inventory_value=Decimal(str(inventory_value)),
            total_customer_outstanding=Decimal(str(total_customer_outstanding)),
            generated_at=now,
        )
