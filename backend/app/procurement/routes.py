from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select

from app.api.deps import (
    CurrentUser,
    DbSession,
    EffectiveTenantId,
    RequestId,
    check_reseller_access,
    require_inventory_access,
    require_manager_or_above,
)
from app.procurement.schemas import (
    GoodsReceiptCreate,
    GoodsReceiptDetail,
    GoodsReceiptItemResponse,
    GoodsReceiptSummary,
    PaginatedGoodsReceipts,
    PaginatedPurchaseOrders,
    PaginatedSupplierPayables,
    PurchaseOrderCreate,
    PurchaseOrderDetail,
    PurchaseOrderItemResponse,
    PurchaseOrderSummary,
    PurchaseOrderUpdate,
    SupplierBalance,
    SupplierPayableDetail,
    SupplierPayableSummary,
    SupplierPaymentCreate,
    SupplierPaymentResponse,
)
from app.procurement.services import (
    PurchaseOrderService,
    ReceivingService,
    SupplierPayableService,
)
from app.models.user import User
from app.models.supplier import Supplier
from app.schemas.common import PaginatedResponse

router = APIRouter()


async def _user_names(db: DbSession, ids: set[uuid.UUID]) -> dict[uuid.UUID, str]:
    if not ids:
        return {}
    stmt = select(User.id, User.first_name, User.last_name).where(User.id.in_(ids))
    rows = await db.execute(stmt)
    return {r.id: f"{r.first_name} {r.last_name}".strip() for r in rows}


async def _supplier_names(db: DbSession, ids: set[uuid.UUID]) -> dict[uuid.UUID, str]:
    if not ids:
        return {}
    stmt = select(Supplier.id, Supplier.name).where(Supplier.id.in_(ids))
    rows = await db.execute(stmt)
    return {r.id: r.name for r in rows}



@router.post(
    "/purchase-orders",
    response_model=PurchaseOrderDetail,
    status_code=201,
    dependencies=[check_reseller_access("procurement:create", check_branch=False)],
)
async def create_purchase_order(
    db: DbSession,
    current_user: Annotated[User, Depends(require_inventory_access)],
    tenant_id: EffectiveTenantId,
    request_id: RequestId,
    data: PurchaseOrderCreate,
) -> PurchaseOrderDetail:
    svc = PurchaseOrderService(db)
    po = await svc.create_po(
        tenant_id=tenant_id,
        data=data,
        actor_id=current_user.id,
        request_id=request_id,
    )
    return PurchaseOrderDetail.model_validate(po)


@router.get(
    "/purchase-orders",
    response_model=PaginatedPurchaseOrders,
    dependencies=[check_reseller_access("procurement:view")],
)
async def list_purchase_orders(
    db: DbSession,
    current_user: Annotated[User, Depends(require_inventory_access)],
    tenant_id: EffectiveTenantId,
    branch_id: uuid.UUID | None = Query(default=None),
    supplier_id: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=500),
) -> PaginatedPurchaseOrders:
    svc = PurchaseOrderService(db)
    items, total = await svc.list_pos(
        tenant_id=tenant_id,
        page=page,
        page_size=page_size,
        branch_id=branch_id,
        supplier_id=supplier_id,
        status=status,
    )
    actor_ids = {p.created_by for p in items} | {p.approved_by for p in items if p.approved_by}
    names = await _user_names(db, actor_ids)
    sup_ids = {p.supplier_id for p in items}
    sup_names = await _supplier_names(db, sup_ids)
    return PaginatedResponse.create(
        items=[
            PurchaseOrderSummary.model_validate(p).model_copy(update={
                "created_by_name":  names.get(p.created_by),
                "approved_by_name": names.get(p.approved_by) if p.approved_by else None,
                "supplier_name":    sup_names.get(p.supplier_id),
            })
            for p in items
        ],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get(
    "/purchase-orders/{po_id}",
    response_model=PurchaseOrderDetail,
    dependencies=[check_reseller_access("procurement:view", check_branch=False)],
)
async def get_purchase_order(
    po_id: uuid.UUID,
    db: DbSession,
    current_user: Annotated[User, Depends(require_inventory_access)],
    tenant_id: EffectiveTenantId,
) -> PurchaseOrderDetail:
    svc = PurchaseOrderService(db)
    po = await svc.get_po(po_id, tenant_id)
    actor_ids = {po.created_by} | ({po.approved_by} if po.approved_by else set())
    names = await _user_names(db, actor_ids)

    return PurchaseOrderDetail.model_validate(po).model_copy(update={
        "created_by_name": names.get(po.created_by),
        "approved_by_name": names.get(po.approved_by) if po.approved_by else None,
        "items": [
            PurchaseOrderItemResponse.model_validate(item).model_copy(update={
                "product_name": item.product.name if item.product else None,
            })
            for item in po.items
        ],
    })


@router.patch("/purchase-orders/{po_id}", response_model=PurchaseOrderDetail)
async def update_purchase_order(
    po_id: uuid.UUID,
    db: DbSession,
    current_user: Annotated[User, Depends(require_manager_or_above)],
    tenant_id: EffectiveTenantId,
    data: PurchaseOrderUpdate,
) -> PurchaseOrderDetail:
    svc = PurchaseOrderService(db)
    po = await svc.update_po(po_id, tenant_id, data, current_user.id)
    return PurchaseOrderDetail.model_validate(po)


@router.post("/purchase-orders/{po_id}/submit", response_model=PurchaseOrderDetail)
async def submit_purchase_order(
    po_id: uuid.UUID,
    db: DbSession,
    current_user: Annotated[User, Depends(require_manager_or_above)],
    tenant_id: EffectiveTenantId,
    request_id: RequestId,
) -> PurchaseOrderDetail:
    svc = PurchaseOrderService(db)
    po = await svc.submit_po(po_id, tenant_id, current_user.id, request_id)
    return PurchaseOrderDetail.model_validate(po)


@router.post(
    "/purchase-orders/{po_id}/approve",
    response_model=PurchaseOrderDetail,
    dependencies=[check_reseller_access("procurement:approve", check_branch=False)],
)
async def approve_purchase_order(
    po_id: uuid.UUID,
    db: DbSession,
    current_user: Annotated[User, Depends(require_manager_or_above)],
    tenant_id: EffectiveTenantId,
    request_id: RequestId,
) -> PurchaseOrderDetail:
    svc = PurchaseOrderService(db)
    po = await svc.approve_po(po_id, tenant_id, current_user.id, request_id)
    return PurchaseOrderDetail.model_validate(po)


@router.post("/purchase-orders/{po_id}/cancel", response_model=PurchaseOrderDetail)
async def cancel_purchase_order(
    po_id: uuid.UUID,
    db: DbSession,
    current_user: Annotated[User, Depends(require_manager_or_above)],
    tenant_id: EffectiveTenantId,
    request_id: RequestId,
) -> PurchaseOrderDetail:
    svc = PurchaseOrderService(db)
    po = await svc.cancel_po(po_id, tenant_id, current_user.id, request_id)
    return PurchaseOrderDetail.model_validate(po)



@router.post("/receipts", response_model=GoodsReceiptDetail, status_code=201)
async def create_goods_receipt(
    db: DbSession,
    current_user: Annotated[User, Depends(require_inventory_access)],
    tenant_id: EffectiveTenantId,
    request_id: RequestId,
    data: GoodsReceiptCreate,
) -> GoodsReceiptDetail:
    svc = ReceivingService(db)
    receipt = await svc.create_goods_receipt(
        tenant_id=tenant_id,
        data=data,
        actor_id=current_user.id,
        request_id=request_id,
    )
    return GoodsReceiptDetail.model_validate(receipt)


@router.get(
    "/receipts",
    response_model=PaginatedGoodsReceipts,
    dependencies=[check_reseller_access("procurement:view")],
)
async def list_goods_receipts(
    db: DbSession,
    current_user: Annotated[User, Depends(require_inventory_access)],
    tenant_id: EffectiveTenantId,
    purchase_order_id: uuid.UUID | None = Query(default=None),
    branch_id: uuid.UUID | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=500),
) -> PaginatedGoodsReceipts:
    svc = ReceivingService(db)
    items, total = await svc.list_receipts(
        tenant_id=tenant_id,
        page=page,
        page_size=page_size,
        purchase_order_id=purchase_order_id,
        branch_id=branch_id,
    )
    names = await _user_names(db, {r.received_by for r in items if r.received_by})
    return PaginatedResponse.create(
        items=[
            GoodsReceiptSummary.model_validate(r).model_copy(update={
                "received_by_name": names.get(r.received_by),
            })
            for r in items
        ],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/receipts/{receipt_id}", response_model=GoodsReceiptDetail)
async def get_goods_receipt(
    receipt_id: uuid.UUID,
    db: DbSession,
    current_user: Annotated[User, Depends(require_inventory_access)],
    tenant_id: EffectiveTenantId,
) -> GoodsReceiptDetail:
    svc = ReceivingService(db)
    receipt = await svc.get_receipt(receipt_id, tenant_id)
    names = await _user_names(db, {receipt.received_by} if receipt.received_by else set())
    return GoodsReceiptDetail.model_validate(receipt).model_copy(update={
        "received_by_name": names.get(receipt.received_by),
        "items": [
            GoodsReceiptItemResponse.model_validate(item).model_copy(update={
                "product_name": (
                    item.purchase_order_item.product.name
                    if item.purchase_order_item and item.purchase_order_item.product
                    else None
                ),
            })
            for item in receipt.items
        ],
    })



@router.get("/payables", response_model=PaginatedSupplierPayables)
async def list_payables(
    db: DbSession,
    current_user: Annotated[User, Depends(require_inventory_access)],
    tenant_id: EffectiveTenantId,
    supplier_id: uuid.UUID | None = Query(default=None),
    status: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=500),
) -> PaginatedSupplierPayables:
    svc = SupplierPayableService(db)
    items, total = await svc.list_payables(
        tenant_id=tenant_id,
        page=page,
        page_size=page_size,
        supplier_id=supplier_id,
        status=status,
    )
    sup_ids = {p.supplier_id for p in items}
    sup_names = await _supplier_names(db, sup_ids)
    return PaginatedResponse.create(
        items=[
            SupplierPayableSummary.model_validate(p).model_copy(update={
                "supplier_name": sup_names.get(p.supplier_id),
            })
            for p in items
        ],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/payables/{payable_id}", response_model=SupplierPayableDetail)
async def get_payable(
    payable_id: uuid.UUID,
    db: DbSession,
    current_user: Annotated[User, Depends(require_inventory_access)],
    tenant_id: EffectiveTenantId,
) -> SupplierPayableDetail:
    svc = SupplierPayableService(db)
    payable = await svc.get_payable(payable_id, tenant_id)
    payment_actor_ids = {p.recorded_by for p in payable.payments if p.recorded_by}
    names = await _user_names(db, payment_actor_ids)
    detail = SupplierPayableDetail.model_validate(payable)
    detail = detail.model_copy(update={
        "payments": [
            SupplierPaymentResponse.model_validate(p).model_copy(update={
                "recorded_by_name": names.get(p.recorded_by),
            })
            for p in payable.payments
        ]
    })
    return detail


@router.get("/suppliers/{supplier_id}/balance", response_model=SupplierBalance)
async def get_supplier_balance(
    supplier_id: uuid.UUID,
    db: DbSession,
    current_user: Annotated[User, Depends(require_inventory_access)],
    tenant_id: EffectiveTenantId,
) -> SupplierBalance:
    svc = SupplierPayableService(db)
    balance = await svc.supplier_balance(supplier_id, tenant_id)
    return SupplierBalance.model_validate(balance)


@router.post("/payables/{payable_id}/payments", response_model=SupplierPaymentResponse, status_code=201)
async def record_supplier_payment(
    payable_id: uuid.UUID,
    db: DbSession,
    current_user: Annotated[User, Depends(require_manager_or_above)],
    tenant_id: EffectiveTenantId,
    request_id: RequestId,
    data: SupplierPaymentCreate,
) -> SupplierPaymentResponse:
    svc = SupplierPayableService(db)
    payment = await svc.record_payment(
        payable_id=payable_id,
        tenant_id=tenant_id,
        data=data,
        actor_id=current_user.id,
        request_id=request_id,
    )
    names = await _user_names(db, {payment.recorded_by} if payment.recorded_by else set())
    return SupplierPaymentResponse.model_validate(payment).model_copy(update={
        "recorded_by_name": names.get(payment.recorded_by),
    })
