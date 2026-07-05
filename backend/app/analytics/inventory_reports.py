from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from decimal import Decimal

from sqlalchemy.ext.asyncio import AsyncSession

from app.analytics.repositories import AnalyticsRepository
from app.analytics.schemas import (
    DeadStockResponse,
    ExportDataset,
    FastMovingResponse,
    InventoryValuationItem,
    InventoryValuationResponse,
    LowStockResponse,
    MovementReportResponse,
)
from app.core.constants import AuditAction, EntityType
from app.core.timezone import local_day_end_utc, local_day_start_utc
from app.services.audit_service import AuditService


class InventoryReportsService:
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

    async def get_valuation(
        self,
        tenant_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> InventoryValuationResponse:
        rows = await self.repo.get_inventory_valuation(tenant_id, branch_id)
        items = [
            InventoryValuationItem(
                product_id=r["product_id"],
                product_name=r["product_name"],
                sku=r.get("sku"),
                quantity_on_hand=Decimal(str(r.get("quantity_on_hand", 0))),
                cost_price=Decimal(str(r.get("cost_price", 0))),
                valuation=Decimal(str(r.get("valuation", 0))),
            )
            for r in rows
        ]
        total = sum(item.valuation for item in items)

        await self.audit.log(
            action=AuditAction.INVENTORY_REPORT_VIEWED,
            actor_user_id=actor_id,
            tenant_id=tenant_id,
            entity_type=EntityType.ANALYTICS_REPORT,
            after_state={"report": "inventory_valuation"},
            request_id=request_id,
        )
        return InventoryValuationResponse(items=items, total_valuation=total)

    async def get_low_stock(
        self,
        tenant_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> list[LowStockResponse]:
        rows = await self.repo.get_low_stock_items(tenant_id, branch_id)
        return [
            LowStockResponse(
                product_id=r["product_id"],
                product_name=r["product_name"],
                sku=r.get("sku"),
                branch_id=r["branch_id"],
                branch_name=r["branch_name"],
                quantity_on_hand=Decimal(str(r.get("quantity_on_hand", 0))),
                reorder_point=Decimal(str(r.get("reorder_point", 0))),
            )
            for r in rows
        ]

    async def get_movements(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
        movement_type: str | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> list[MovementReportResponse]:
        start_dt, end_dt = await self._resolve_range(tenant_id, start_date, end_date)

        rows = await self.repo.get_movement_report(
            tenant_id, start_dt, end_dt, branch_id, movement_type
        )
        return [
            MovementReportResponse(
                movement_type=r["movement_type"],
                count=int(r.get("count", 0)),
                total_quantity=Decimal(str(r.get("total_quantity", 0))),
            )
            for r in rows
        ]

    async def get_fast_moving(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
        limit: int = 10,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> list[FastMovingResponse]:
        start_dt, end_dt = await self._resolve_range(tenant_id, start_date, end_date)

        rows = await self.repo.get_fast_moving_products(
            tenant_id, start_dt, end_dt, branch_id, limit
        )
        return [
            FastMovingResponse(
                product_id=r["product_id"],
                product_name=r["product_name"],
                sku=r.get("sku"),
                quantity_sold=Decimal(str(r.get("quantity_sold", 0))),
                order_count=int(r.get("order_count", 0)),
                rank=int(r.get("rank", 0)),
            )
            for r in rows
        ]

    async def get_dead_stock(
        self,
        tenant_id: uuid.UUID,
        days: int = 90,
        branch_id: uuid.UUID | None = None,
        actor_id: uuid.UUID | None = None,
        request_id: str | None = None,
    ) -> list[DeadStockResponse]:
        rows = await self.repo.get_dead_stock(tenant_id, days, branch_id)
        return [
            DeadStockResponse(
                product_id=r["product_id"],
                product_name=r["product_name"],
                sku=r.get("sku"),
                quantity_on_hand=Decimal(str(r.get("quantity_on_hand", 0))),
                last_sold_at=r.get("last_sold_at"),
                days_without_sale=int(r.get("days_without_sale", 0)),
            )
            for r in rows
        ]


    async def export_inventory_report(
        self,
        tenant_id: uuid.UUID,
        branch_id: uuid.UUID | None = None,
    ) -> ExportDataset:
        valuation = await self.get_valuation(tenant_id, branch_id)
        low_stock = await self.get_low_stock(tenant_id, branch_id)
        return ExportDataset(
            report_type="inventory",
            generated_at=datetime.now(timezone.utc),
            filters={"branch_id": str(branch_id) if branch_id else None},
            columns=["product_id", "product_name", "sku", "quantity_on_hand", "valuation"],
            rows=[i.model_dump() for i in valuation.items]
            + [ls.model_dump() for ls in low_stock],
        )
