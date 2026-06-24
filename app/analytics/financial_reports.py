from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.repositories import AnalyticsRepository
from app.analytics.schemas import (
    ExportDataset,
    FinancialSummaryResponse,
    ProfitReportItem,
    ProfitReportResponse,
)
from app.core.constants import AuditAction, EntityType
from app.services.audit_service import AuditService


def _date_to_utc_start(d: date) -> datetime:
    return datetime(d.year, d.month, d.day, tzinfo=timezone.utc)


def _date_to_utc_end(d: date) -> datetime:
    return _date_to_utc_start(d) + timedelta(days=1)


class FinancialReportsService:
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
    ) -> FinancialSummaryResponse:
        start_dt = _date_to_utc_start(start_date) if start_date else None
        end_dt = _date_to_utc_end(end_date) if end_date else None

        row = await self.repo.get_financial_summary(tenant_id, start_dt, end_dt, branch_id)

        gross_revenue = Decimal(str(row.get("gross_revenue", 0)))
        refund_amount = Decimal(str(row.get("refund_amount", 0)))
        net_revenue = Decimal(str(row.get("net_revenue", 0)))
        cogs = Decimal(str(row.get("cogs", 0)))
        gross_profit = net_revenue - cogs
        gross_margin_pct = (
            (gross_profit / net_revenue * 100).quantize(Decimal("0.0001"))
            if net_revenue
            else Decimal("0")
        )

        await self.audit.log(
            action=AuditAction.FINANCIAL_REPORT_VIEWED,
            actor_user_id=actor_id,
            tenant_id=tenant_id,
            entity_type=EntityType.ANALYTICS_REPORT,
            after_state={"report": "financial_summary"},
            request_id=request_id,
        )
        return FinancialSummaryResponse(
            gross_revenue=gross_revenue,
            refund_amount=refund_amount,
            net_revenue=net_revenue,
            cost_of_goods_sold=cogs,
            gross_profit=gross_profit,
            gross_margin_pct=gross_margin_pct,
        )

    async def get_profit_report(
        self,
        tenant_id: uuid.UUID,
        by: str = "product",
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> ProfitReportResponse:
        if by not in ("product", "category", "branch"):
            by = "product"
        start_dt = _date_to_utc_start(start_date) if start_date else None
        end_dt = _date_to_utc_end(end_date) if end_date else None

        if by == "product":
            rows = await self.repo.get_profit_by_product(
                tenant_id, start_dt, end_dt, branch_id
            )
        elif by == "category":
            rows = await self.repo.get_profit_by_category(
                tenant_id, start_dt, end_dt, branch_id
            )
        else:
            rows = await self.repo.get_profit_by_branch(tenant_id, start_dt, end_dt)

        items = []
        for r in rows:
            revenue = Decimal(str(r.get("revenue", 0)))
            cogs = Decimal(str(r.get("cogs", 0)))
            profit = Decimal(str(r.get("profit", 0)))
            margin_pct = (
                (profit / revenue * 100).quantize(Decimal("0.0001")) if revenue else Decimal("0")
            )
            items.append(
                ProfitReportItem(
                    dimension_id=r.get("dimension_id"),
                    dimension_name=r.get("dimension_name", ""),
                    revenue=revenue,
                    cogs=cogs,
                    profit=profit,
                    margin_pct=margin_pct,
                )
            )

        await self.audit.log(
            action=AuditAction.FINANCIAL_REPORT_VIEWED,
            actor_user_id=actor_id,
            tenant_id=tenant_id,
            entity_type=EntityType.ANALYTICS_REPORT,
            after_state={"report": "profit", "by": by},
            request_id=request_id,
        )
        return ProfitReportResponse(by=by, items=items)


    async def export_financial_report(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
    ) -> ExportDataset:
        summary = await self.get_summary(tenant_id, start_date, end_date, branch_id)
        profit = await self.get_profit_report(
            tenant_id, "product", start_date, end_date, branch_id
        )
        return ExportDataset(
            report_type="financial",
            generated_at=datetime.now(timezone.utc),
            filters={
                "start_date": str(start_date) if start_date else None,
                "end_date": str(end_date) if end_date else None,
                "branch_id": str(branch_id) if branch_id else None,
            },
            columns=[
                "gross_revenue", "refund_amount", "net_revenue",
                "cost_of_goods_sold", "gross_profit", "gross_margin_pct",
            ],
            rows=[summary.model_dump()] + [i.model_dump() for i in profit.items],
        )
