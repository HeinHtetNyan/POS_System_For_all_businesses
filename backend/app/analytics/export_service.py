"""
Analytics CSV export service — read-only, tenant-scoped.
Generates raw bytes (UTF-8 with BOM) for browser download.
"""
from __future__ import annotations

import csv
import io
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy import and_, func, literal, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.cashiers.models import CashierSession
from app.core.constants import OrderStatus, PaymentStatus
from app.customers.models import Customer
from app.models.branch import Branch
from app.models.user import User
from app.payments.models import Payment, Refund, RefundItem
from app.sales.models import Order, OrderItem


def _utc_start(d: date) -> datetime:
    return datetime(d.year, d.month, d.day, tzinfo=timezone.utc)


def _fmt_dt(dt: datetime | None) -> str:
    if dt is None:
        return ""
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def _fmt_dec(v: Decimal | None) -> str:
    if v is None:
        return ""
    return str(v.quantize(Decimal("0.00")))


_MONEY_COLS: frozenset[str] = frozenset({
    "Subtotal", "Discount", "Tax", "Total", "Refunded Amount", "Net Amount",
    "Unit Price", "Line Refund Amount", "Total Refund Amount",
    "Unit Cost", "Line Subtotal", "Line Total", "Order Total",
})


def _totals_row(headers: list[str], rows: list[dict]) -> dict:
    """Build a TOTAL row that sums every money column; non-money cols are blank."""
    totals: dict = {h: "" for h in headers}
    totals[headers[0]] = "TOTAL"
    for h in headers:
        if h in _MONEY_COLS:
            total = Decimal("0")
            for row in rows:
                val = row.get(h, "")
                if val:
                    try:
                        total += Decimal(val)
                    except Exception:
                        pass
            totals[h] = str(total.quantize(Decimal("0.00")))
    return totals


def _write_section(buf: io.StringIO, title: str, headers: list[str], rows: list[dict]) -> None:
    """Write a titled section (with a TOTAL row) into an already-open StringIO buffer."""
    buf.write(f"{title}\n")
    writer = csv.DictWriter(buf, fieldnames=headers, extrasaction="ignore", lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    if rows:
        writer.writerow(_totals_row(headers, rows))
    # blank separator row between sections
    buf.write("\n")


def _build_csv(*sections: tuple[str, list[str], list[dict]]) -> bytes:
    """Combine multiple (title, headers, rows) sections into one CSV file."""
    buf = io.StringIO()
    for title, headers, rows in sections:
        _write_section(buf, title, headers, rows)
    # UTF-8 BOM → Excel / Google Sheets open without encoding dialog
    return "﻿".encode("utf-8") + buf.getvalue().encode("utf-8")


class ExportService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # shared helpers

    def _order_filters(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None,
        end_date: date | None,
        branch_id: uuid.UUID | None,
    ) -> list:
        f: list = [
            Order.tenant_id == tenant_id,
            Order.order_status.in_([
                OrderStatus.COMPLETED.value,
                OrderStatus.PARTIALLY_REFUNDED.value,
                OrderStatus.REFUNDED.value,
            ]),
        ]
        if start_date:
            f.append(Order.created_at >= _utc_start(start_date))
        if end_date:
            f.append(Order.created_at < _utc_start(end_date) + timedelta(days=1))
        if branch_id:
            f.append(Order.branch_id == branch_id)
        return f

    def _pay_methods_subq(self, tenant_id: uuid.UUID):
        """Subquery: order_id → comma-separated list of distinct payment methods."""
        return (
            select(
                Payment.order_id.label("order_id"),
                func.string_agg(Payment.payment_method, literal(", ")).label("methods"),
            )
            .where(
                and_(
                    Payment.tenant_id == tenant_id,
                    Payment.payment_status == PaymentStatus.PAID.value,
                )
            )
            .group_by(Payment.order_id)
            .subquery("pay_methods")
        )

    # export 1: sales + refunds combined

    async def export_sales_and_refunds(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
    ) -> bytes:
        """
        Single CSV with two sections:
          SECTION 1 — SALES: one row per order
          SECTION 2 — REFUNDS: one row per refund line item
        """
        sales_rows = await self._fetch_sales(tenant_id, start_date, end_date, branch_id)
        refund_rows = await self._fetch_refunds(tenant_id, start_date, end_date, branch_id)

        sales_headers = [
            "Order Number", "Date", "Branch", "Cashier", "Customer",
            "Subtotal", "Discount", "Tax", "Total",
            "Payment Methods", "Status",
            "Refunded Amount", "Net Amount",
            "Notes", "Completed At",
        ]
        refund_headers = [
            "Refund Number", "Refund Date",
            "Original Order", "Order Date",
            "Branch", "Customer",
            "Product", "Variant",
            "Qty", "Unit Price", "Line Refund Amount",
            "Total Refund Amount",
            "Reason", "Type", "Processed By", "Notes",
        ]

        return _build_csv(
            ("SALES", sales_headers, sales_rows),
            ("REFUNDS", refund_headers, refund_rows),
        )

    async def _fetch_sales(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None,
        end_date: date | None,
        branch_id: uuid.UUID | None,
    ) -> list[dict]:
        CashierUser = aliased(User)
        pay_subq = self._pay_methods_subq(tenant_id)

        stmt = (
            select(
                Order.order_number,
                Order.created_at,
                Branch.name.label("branch_name"),
                func.concat(CashierUser.first_name, literal(" "), CashierUser.last_name).label("cashier_name"),
                Customer.name.label("customer_name"),
                Order.subtotal,
                Order.discount_amount,
                Order.tax_amount,
                Order.total_amount,
                pay_subq.c.methods.label("payment_methods"),
                Order.order_status,
                Order.refunded_amount,
                (Order.total_amount - Order.refunded_amount).label("net_amount"),
                Order.notes,
                Order.completed_at,
            )
            .join(Branch, Branch.id == Order.branch_id)
            .join(CashierSession, CashierSession.id == Order.cashier_session_id)
            .join(CashierUser, CashierUser.id == CashierSession.cashier_user_id)
            .outerjoin(Customer, Customer.id == Order.customer_id)
            .outerjoin(pay_subq, pay_subq.c.order_id == Order.id)
            .where(and_(*self._order_filters(tenant_id, start_date, end_date, branch_id)))
            .order_by(Order.created_at.desc())
        )

        rows_raw = (await self.session.execute(stmt)).mappings().all()
        return [
            {
                "Order Number":    r.order_number,
                "Date":            _fmt_dt(r.created_at),
                "Branch":          r.branch_name or "",
                "Cashier":         r.cashier_name or "",
                "Customer":        r.customer_name or "",
                "Subtotal":        _fmt_dec(r.subtotal),
                "Discount":        _fmt_dec(r.discount_amount),
                "Tax":             _fmt_dec(r.tax_amount),
                "Total":           _fmt_dec(r.total_amount),
                "Payment Methods": r.payment_methods or "",
                "Status":          r.order_status,
                "Refunded Amount": _fmt_dec(r.refunded_amount),
                "Net Amount":      _fmt_dec(r.net_amount),
                "Notes":           r.notes or "",
                "Completed At":    _fmt_dt(r.completed_at),
            }
            for r in rows_raw
        ]

    async def _fetch_refunds(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None,
        end_date: date | None,
        branch_id: uuid.UUID | None,
    ) -> list[dict]:
        ProcessedByUser = aliased(User)

        refund_filters: list = [Refund.tenant_id == tenant_id]
        if start_date:
            refund_filters.append(Refund.processed_at >= _utc_start(start_date))
        if end_date:
            refund_filters.append(Refund.processed_at < _utc_start(end_date) + timedelta(days=1))
        if branch_id:
            refund_filters.append(Order.branch_id == branch_id)

        stmt = (
            select(
                Refund.refund_number,
                Refund.processed_at,
                Order.order_number,
                Order.created_at.label("order_date"),
                Branch.name.label("branch_name"),
                Customer.name.label("customer_name"),
                OrderItem.product_name,
                OrderItem.variant_name,
                RefundItem.quantity,
                OrderItem.unit_price,
                RefundItem.amount.label("line_refund_amount"),
                Refund.amount.label("total_refund_amount"),
                Refund.reason,
                Refund.refund_type,
                func.concat(ProcessedByUser.first_name, literal(" "), ProcessedByUser.last_name).label("processed_by"),
                Refund.notes,
            )
            .join(Order, Order.id == Refund.order_id)
            .join(Branch, Branch.id == Order.branch_id)
            .outerjoin(Customer, Customer.id == Order.customer_id)
            .join(ProcessedByUser, ProcessedByUser.id == Refund.processed_by)
            .outerjoin(RefundItem, RefundItem.refund_id == Refund.id)
            .outerjoin(OrderItem, OrderItem.id == RefundItem.order_item_id)
            .where(and_(*refund_filters))
            .order_by(Refund.processed_at.desc(), Refund.refund_number)
        )

        rows_raw = (await self.session.execute(stmt)).mappings().all()
        return [
            {
                "Refund Number":       r.refund_number,
                "Refund Date":         _fmt_dt(r.processed_at),
                "Original Order":      r.order_number,
                "Order Date":          _fmt_dt(r.order_date),
                "Branch":              r.branch_name or "",
                "Customer":            r.customer_name or "",
                "Product":             r.product_name or "",
                "Variant":             r.variant_name or "",
                "Qty":                 str(r.quantity) if r.quantity is not None else "",
                "Unit Price":          _fmt_dec(r.unit_price) if r.unit_price is not None else "",
                "Line Refund Amount":  _fmt_dec(r.line_refund_amount) if r.line_refund_amount is not None else "",
                "Total Refund Amount": _fmt_dec(r.total_refund_amount),
                "Reason":              r.reason,
                "Type":                r.refund_type,
                "Processed By":        r.processed_by or "",
                "Notes":               r.notes or "",
            }
            for r in rows_raw
        ]

    # export 2: order line items

    async def export_order_items(
        self,
        tenant_id: uuid.UUID,
        start_date: date | None = None,
        end_date: date | None = None,
        branch_id: uuid.UUID | None = None,
    ) -> bytes:
        """
        One row per order line item — ideal for COGS / margin analysis.
        """
        CashierUser = aliased(User)
        pay_subq = self._pay_methods_subq(tenant_id)

        stmt = (
            select(
                Order.order_number,
                Order.created_at,
                Branch.name.label("branch_name"),
                func.concat(CashierUser.first_name, literal(" "), CashierUser.last_name).label("cashier_name"),
                Customer.name.label("customer_name"),
                OrderItem.product_name,
                OrderItem.variant_name,
                OrderItem.sku,
                OrderItem.quantity,
                OrderItem.unit_price,
                OrderItem.unit_cost_snapshot,
                OrderItem.discount_amount,
                OrderItem.tax_rate,
                OrderItem.subtotal.label("line_subtotal"),
                OrderItem.total.label("line_total"),
                Order.total_amount.label("order_total"),
                pay_subq.c.methods.label("payment_methods"),
                Order.order_status,
            )
            .join(OrderItem, OrderItem.order_id == Order.id)
            .join(Branch, Branch.id == Order.branch_id)
            .join(CashierSession, CashierSession.id == Order.cashier_session_id)
            .join(CashierUser, CashierUser.id == CashierSession.cashier_user_id)
            .outerjoin(Customer, Customer.id == Order.customer_id)
            .outerjoin(pay_subq, pay_subq.c.order_id == Order.id)
            .where(and_(*self._order_filters(tenant_id, start_date, end_date, branch_id)))
            .order_by(Order.created_at.desc(), OrderItem.id)
        )

        rows_raw = (await self.session.execute(stmt)).mappings().all()

        headers = [
            "Order Number", "Order Date", "Branch", "Cashier", "Customer",
            "Product", "Variant", "SKU",
            "Qty", "Unit Price", "Unit Cost",
            "Discount", "Tax Rate",
            "Line Subtotal", "Line Total", "Order Total",
            "Payment Methods", "Order Status",
        ]

        rows = [
            {
                "Order Number":    r.order_number,
                "Order Date":      _fmt_dt(r.created_at),
                "Branch":          r.branch_name or "",
                "Cashier":         r.cashier_name or "",
                "Customer":        r.customer_name or "",
                "Product":         r.product_name,
                "Variant":         r.variant_name or "",
                "SKU":             r.sku or "",
                "Qty":             str(r.quantity),
                "Unit Price":      _fmt_dec(r.unit_price),
                "Unit Cost":       _fmt_dec(r.unit_cost_snapshot) if r.unit_cost_snapshot is not None else "",
                "Discount":        _fmt_dec(r.discount_amount),
                "Tax Rate":        str(r.tax_rate),
                "Line Subtotal":   _fmt_dec(r.line_subtotal),
                "Line Total":      _fmt_dec(r.line_total),
                "Order Total":     _fmt_dec(r.order_total),
                "Payment Methods": r.payment_methods or "",
                "Order Status":    r.order_status,
            }
            for r in rows_raw
        ]

        return _build_csv(("ORDERS", headers, rows))
