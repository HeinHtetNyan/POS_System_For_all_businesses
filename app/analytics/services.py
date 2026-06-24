"""
Convenience coordinator — imports all sub-services in one place.
Routes can import directly from sub-service modules or use this as a facade.
"""
from __future__ import annotations

from app.analytics.dashboard_service import DashboardService
from app.analytics.financial_reports import FinancialReportsService
from app.analytics.inventory_reports import InventoryReportsService
from app.analytics.sales_reports import SalesReportsService

__all__ = [
    "DashboardService",
    "SalesReportsService",
    "InventoryReportsService",
    "FinancialReportsService",
]
