from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from app.schemas.common import BaseSchema



class DashboardResponse(BaseSchema):
    sales_today: Decimal
    sales_yesterday: Decimal
    sales_this_week: Decimal
    sales_this_month: Decimal
    orders_today: int
    orders_this_month: int
    revenue_today: Decimal
    revenue_month: Decimal
    refund_count_month: int
    refund_amount_month: Decimal
    total_customers: int
    new_customers_month: int
    low_stock_products: int
    inventory_value: Decimal
    total_customer_outstanding: Decimal
    generated_at: datetime



class SalesSummaryResponse(BaseSchema):
    order_count: int
    gross_sales: Decimal
    refund_amount: Decimal
    net_sales: Decimal
    average_order_value: Decimal
    unique_customers: int


class SalesTrendItem(BaseSchema):
    period: str
    sales: Decimal
    orders: int
    revenue: Decimal


class SalesTrendResponse(BaseSchema):
    granularity: str
    items: list[SalesTrendItem]


class TopProductResponse(BaseSchema):
    product_id: uuid.UUID
    product_name: str
    sku: str | None
    quantity_sold: Decimal
    revenue: Decimal
    profit_estimate: Decimal


class CategorySalesResponse(BaseSchema):
    category_id: uuid.UUID | None
    category_name: str
    quantity_sold: Decimal
    sales: Decimal
    profit: Decimal


class BranchSalesResponse(BaseSchema):
    branch_id: uuid.UUID
    branch_name: str
    orders: int
    sales: Decimal
    refunds: Decimal
    revenue: Decimal


class CashierSalesResponse(BaseSchema):
    cashier_id: uuid.UUID
    cashier_name: str
    orders: int
    sales: Decimal
    refunds: Decimal
    average_ticket: Decimal


class PaymentMethodResponse(BaseSchema):
    payment_method: str
    transaction_count: int
    amount: Decimal
    percentage: Decimal



class InventoryValuationItem(BaseSchema):
    product_id: uuid.UUID
    product_name: str
    sku: str | None
    quantity_on_hand: Decimal
    cost_price: Decimal
    valuation: Decimal


class InventoryValuationResponse(BaseSchema):
    items: list[InventoryValuationItem]
    total_valuation: Decimal


class LowStockResponse(BaseSchema):
    product_id: uuid.UUID
    product_name: str
    sku: str | None
    branch_id: uuid.UUID
    branch_name: str
    quantity_on_hand: Decimal
    reorder_point: Decimal


class MovementReportResponse(BaseSchema):
    movement_type: str
    count: int
    total_quantity: Decimal


class FastMovingResponse(BaseSchema):
    product_id: uuid.UUID
    product_name: str
    sku: str | None
    quantity_sold: Decimal
    order_count: int
    rank: int


class DeadStockResponse(BaseSchema):
    product_id: uuid.UUID
    product_name: str
    sku: str | None
    quantity_on_hand: Decimal
    last_sold_at: datetime | None
    days_without_sale: int



class FinancialSummaryResponse(BaseSchema):
    gross_revenue: Decimal
    refund_amount: Decimal
    net_revenue: Decimal
    cost_of_goods_sold: Decimal
    gross_profit: Decimal
    gross_margin_pct: Decimal


class ProfitReportItem(BaseSchema):
    dimension_id: uuid.UUID | None
    dimension_name: str
    revenue: Decimal
    cogs: Decimal
    profit: Decimal
    margin_pct: Decimal


class ProfitReportResponse(BaseSchema):
    by: str  # "product" | "category" | "branch"
    items: list[ProfitReportItem]



class ExportDataset(BaseSchema):
    report_type: str
    generated_at: datetime
    filters: dict
    columns: list[str]
    rows: list[dict]
