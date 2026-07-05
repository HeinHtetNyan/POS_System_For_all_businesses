from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
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
from app.core.timezone import local_day_end_utc, local_day_start_utc
from app.services.audit_service import AuditService


class FinancialReportsService:
    def __init__(self, session: AsyncSession) -> None:
        self.repo = AnalyticsRepository(session)
        self.audit = AuditService(session)

    async def _resolve_range(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None,
        end_date: date | None,
    ) -> tuple[datetime | None, datetime | None]:
        tz_name = await self.repo.get_tenant_timezone(tenant_id) if (start_date or end_date) else "UTC"
        start_dt = local_day_start_utc(start_date, tz_name) if start_date else None
        end_dt = local_day_end_utc(end_date, tz_name) if end_date else None
        return start_dt, end_dt

    async def get_summary(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> FinancialSummaryResponse:
        start_dt, end_dt = await self._resolve_range(tenant_id, start_date, end_date)

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
        start_dt, end_dt = await self._resolve_range(tenant_id, start_date, end_date)

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
            refunded_amount = Decimal(str(r.get("refunded_amount", 0)))
            cogs = Decimal(str(r.get("cogs", 0)))
            profit = Decimal(str(r.get("profit", 0)))
            net_revenue = revenue - refunded_amount
            # Denominator matches gross_margin_pct above (net_revenue, not gross
            # revenue) so this report's margin reconciles with the summary's.
            margin_pct = (
                (profit / net_revenue * 100).quantize(Decimal("0.0001")) if net_revenue else Decimal("0")
            )
            items.append(
                ProfitReportItem(
                    dimension_id=r.get("dimension_id"),
                    dimension_name=r.get("dimension_name", ""),
                    revenue=revenue,
                    refunded_amount=refunded_amount,
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
