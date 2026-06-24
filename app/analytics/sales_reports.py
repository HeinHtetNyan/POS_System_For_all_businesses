from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.repositories import AnalyticsRepository
from app.analytics.schemas import (
    BranchSalesResponse,
    CashierSalesResponse,
    CategorySalesResponse,
    ExportDataset,
    PaymentMethodResponse,
    SalesSummaryResponse,
    SalesTrendItem,
    SalesTrendResponse,
    TopProductResponse,
)
from app.core.constants import AuditAction, EntityType
from app.services.audit_service import AuditService


def _date_to_utc_start(d: date) -> datetime:
    return datetime(d.year, d.month, d.day, tzinfo=timezone.utc)


def _date_to_utc_end(d: date) -> datetime:
    return _date_to_utc_start(d) + timedelta(days=1)


class SalesReportsService:
    def __init__(self, session: AsyncSession) -> None:
        self.repo = AnalyticsRepository(session)
        self.audit = AuditService(session)

    async def get_summary(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> SalesSummaryResponse:
        start_dt = _date_to_utc_start(start_date) if start_date else None
        end_dt = _date_to_utc_end(end_date) if end_date else None

        row = await self.repo.get_sales_summary(tenant_id, start_dt, end_dt, branch_id)

        await self.audit.log(
            action=AuditAction.SALES_REPORT_VIEWED,
            actor_user_id=actor_id,
            tenant_id=tenant_id,
            entity_type=EntityType.ANALYTICS_REPORT,
            after_state={"report": "sales_summary"},
            request_id=request_id,
        )
        return SalesSummaryResponse(
            order_count=int(row.get("order_count", 0)),
            gross_sales=Decimal(str(row.get("gross_sales", 0))),
            refund_amount=Decimal(str(row.get("refund_amount", 0))),
            net_sales=Decimal(str(row.get("net_sales", 0))),
            average_order_value=Decimal(str(row.get("average_order_value", 0))),
            unique_customers=int(row.get("unique_customers", 0)),
        )

    async def get_trend(
        self,
        tenant_id: uuid.UUID,
        granularity: str = "daily",
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> SalesTrendResponse:
        if granularity not in ("daily", "weekly", "monthly"):
            granularity = "daily"
        start_dt = _date_to_utc_start(start_date) if start_date else None
        end_dt = _date_to_utc_end(end_date) if end_date else None

        rows = await self.repo.get_sales_trend(
            tenant_id, granularity, start_dt, end_dt, branch_id
        )
        items = [
            SalesTrendItem(
                period=str(r["period"])[:10],
                sales=Decimal(str(r.get("sales", 0))),
                orders=int(r.get("orders", 0)),
                revenue=Decimal(str(r.get("revenue", 0))),
            )
            for r in rows
        ]
        return SalesTrendResponse(granularity=granularity, items=items)

    async def get_top_products(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
        limit: int = 10,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> list[TopProductResponse]:
        start_dt = _date_to_utc_start(start_date) if start_date else None
        end_dt = _date_to_utc_end(end_date) if end_date else None

        rows = await self.repo.get_top_products(
            tenant_id, start_dt, end_dt, branch_id, limit
        )
        return [
            TopProductResponse(
                product_id=r["product_id"],
                product_name=r["product_name"],
                sku=r.get("sku"),
                quantity_sold=Decimal(str(r.get("quantity_sold", 0))),
                revenue=Decimal(str(r.get("revenue", 0))),
                profit_estimate=Decimal(str(r.get("profit_estimate", 0))),
            )
            for r in rows
        ]

    async def get_by_category(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> list[CategorySalesResponse]:
        start_dt = _date_to_utc_start(start_date) if start_date else None
        end_dt = _date_to_utc_end(end_date) if end_date else None

        rows = await self.repo.get_sales_by_category(tenant_id, start_dt, end_dt, branch_id)
        return [
            CategorySalesResponse(
                category_id=r.get("category_id"),
                category_name=r.get("category_name", "Uncategorized"),
                quantity_sold=Decimal(str(r.get("quantity_sold", 0))),
                sales=Decimal(str(r.get("sales", 0))),
                profit=Decimal(str(r.get("profit", 0))),
            )
            for r in rows
        ]

    async def get_by_branch(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> list[BranchSalesResponse]:
        start_dt = _date_to_utc_start(start_date) if start_date else None
        end_dt = _date_to_utc_end(end_date) if end_date else None

        rows = await self.repo.get_sales_by_branch(tenant_id, start_dt, end_dt)
        return [
            BranchSalesResponse(
                branch_id=r["branch_id"],
                branch_name=r["branch_name"],
                orders=int(r.get("orders", 0)),
                sales=Decimal(str(r.get("sales", 0))),
                refunds=Decimal(str(r.get("refunds", 0))),
                revenue=Decimal(str(r.get("revenue", 0))),
            )
            for r in rows
        ]

    async def get_by_cashier(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> list[CashierSalesResponse]:
        start_dt = _date_to_utc_start(start_date) if start_date else None
        end_dt = _date_to_utc_end(end_date) if end_date else None

        rows = await self.repo.get_sales_by_cashier(tenant_id, start_dt, end_dt, branch_id)
        return [
            CashierSalesResponse(
                cashier_id=r["cashier_id"],
                cashier_name=r["cashier_name"],
                orders=int(r.get("orders", 0)),
                sales=Decimal(str(r.get("sales", 0))),
                refunds=Decimal(str(r.get("refunds", 0))),
                average_ticket=Decimal(str(r.get("average_ticket", 0))),
            )
            for r in rows
        ]

    async def get_payment_methods(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> list[PaymentMethodResponse]:
        start_dt = _date_to_utc_start(start_date) if start_date else None
        end_dt = _date_to_utc_end(end_date) if end_date else None

        rows = await self.repo.get_payment_methods_stats(
            tenant_id, start_dt, end_dt, branch_id
        )
        return [
            PaymentMethodResponse(
                payment_method=r["payment_method"],
                transaction_count=int(r.get("transaction_count", 0)),
                amount=Decimal(str(r.get("amount", 0))),
                percentage=Decimal(str(r.get("percentage", 0))),
            )
            for r in rows
        ]


    async def export_sales_report(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
    ) -> ExportDataset:
        summary = await self.get_summary(tenant_id, start_date, end_date, branch_id)
        top_products = await self.get_top_products(
            tenant_id, start_date, end_date, branch_id, limit=100
        )
        return ExportDataset(
            report_type="sales",
            generated_at=datetime.now(timezone.utc),
            filters={
                "start_date": str(start_date) if start_date else None,
                "end_date": str(end_date) if end_date else None,
                "branch_id": str(branch_id) if branch_id else None,
            },
            columns=[
                "order_count", "gross_sales", "refund_amount",
                "net_sales", "average_order_value", "unique_customers",
            ],
            rows=[summary.model_dump()]
            + [p.model_dump() for p in top_products],
        )
