from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal
from typing import Any

from pydantic import EmailStr, Field, field_validator

from app.core.constants import ProofActionType  # noqa: F401
from app.schemas.common import BaseSchema, PaginatedResponse, TimestampedSchema



class PlanEntitlementCreate(BaseSchema):
    feature_code: str
    enabled: bool = True
    limit_value: int | None = None


class PlanEntitlementResponse(TimestampedSchema):
    plan_id: uuid.UUID
    feature_code: str
    enabled: bool
    limit_value: int | None


class PlanCreateRequest(BaseSchema):
    name: str
    code: str
    description: str | None = None
    billing_cycle: str
    price: Decimal
    currency: str = "MMK"
    trial_days: int = Field(default=0, ge=0)
    is_active: bool = True
    is_trial: bool = False
    is_public: bool = True
    sort_order: int = 0
    is_referral_plan: bool = False
    entitlements: list[PlanEntitlementCreate] = Field(default_factory=list)

    @field_validator("price", mode="before")
    @classmethod
    def coerce_price(cls, v: Any) -> Decimal:
        return Decimal(str(v))


class PlanUpdateRequest(BaseSchema):
    name: str | None = None
    description: str | None = None
    billing_cycle: str | None = None
    price: Decimal | None = None
    currency: str | None = None
    trial_days: int | None = None
    is_active: bool | None = None
    is_trial: bool | None = None
    is_public: bool | None = None
    sort_order: int | None = None
    is_referral_plan: bool | None = None
    entitlements: list[PlanEntitlementCreate] | None = None

    @field_validator("price", mode="before")
    @classmethod
    def coerce_price(cls, v: Any) -> Decimal | None:
        if v is None:
            return None
        return Decimal(str(v))


class PlanResponse(TimestampedSchema):
    name: str
    code: str
    description: str | None
    billing_cycle: str
    price: Decimal
    currency: str
    trial_days: int
    is_active: bool
    is_trial: bool
    is_public: bool
    sort_order: int
    is_referral_plan: bool
    entitlements: list[PlanEntitlementResponse]


class TrialStatusResponse(BaseSchema):
    status: str
    plan_name: str
    plan_code: str
    started_at: str
    expires_at: str | None
    days_remaining: int
    is_expired: bool
    usage: dict[str, dict]


class PublicPlanResponse(BaseSchema):
    id: uuid.UUID
    name: str
    code: str
    description: str | None
    billing_cycle: str
    price: Decimal
    currency: str
    trial_days: int
    sort_order: int
    entitlements: list[PlanEntitlementResponse]


class RegisterRequest(BaseSchema):
    business_name: str = Field(min_length=2, max_length=255)
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    phone: str | None = None
    password: str = Field(min_length=8, max_length=128)
    referral_code: str | None = None

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not any(c.islower() for c in v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain at least one digit")
        return v


class RegistrationResponse(BaseSchema):
    access_token: str
    # Internal use only — set as httponly cookie, excluded from JSON response
    refresh_token: str = Field(exclude=True)
    token_type: str = "bearer"
    expires_in: int
    user_id: str
    tenant_id: str
    onboarding_required: bool = True


class SubscriptionHistoryResponse(TimestampedSchema):
    tenant_id: uuid.UUID
    subscription_id: uuid.UUID
    change_type: str
    old_plan_id: uuid.UUID | None
    new_plan_id: uuid.UUID | None
    old_status: str | None
    new_status: str | None
    note: str | None
    changed_by_user_id: uuid.UUID | None


class SubscriptionResponse(TimestampedSchema):
    tenant_id: uuid.UUID
    plan_id: uuid.UUID
    status: str
    started_at: datetime
    expires_at: datetime | None
    cancelled_at: datetime | None
    trial_ends_at: datetime | None
    auto_renew: bool
    plan: PlanResponse
    pending_downgrade_plan_id: uuid.UUID | None = None
    pending_downgrade_requested_at: datetime | None = None


class PaymentProofCreateRequest(BaseSchema):
    amount: Decimal
    currency: str = "MMK"
    reference_number: str | None = None
    proof_file_url: str
    action_type: ProofActionType = ProofActionType.INITIAL_ACTIVATION
    target_plan_id: uuid.UUID | None = None

    @field_validator("proof_file_url")
    @classmethod
    def must_be_internal_upload(cls, v: str) -> str:
        if not v.startswith("/uploads/proofs/"):
            raise ValueError("proof_file_url must be an internal upload path starting with /uploads/proofs/")
        return v

    @field_validator("amount", mode="before")
    @classmethod
    def coerce_amount(cls, v: Any) -> Decimal:
        return Decimal(str(v))


class PaymentProofResponse(TimestampedSchema):
    tenant_id: uuid.UUID
    subscription_id: uuid.UUID
    amount: Decimal
    currency: str
    reference_number: str | None
    proof_file_url: str | None
    status: str
    action_type: ProofActionType = ProofActionType.INITIAL_ACTIVATION
    target_plan_id: uuid.UUID | None = None
    target_plan_name: str | None = None
    tenant_name: str | None = None
    tenant_email: str | None = None
    reviewed_by: uuid.UUID | None
    reviewed_at: datetime | None
    review_notes: str | None


class DowngradeScheduledResponse(BaseSchema):
    message: str
    pending_downgrade_plan_id: uuid.UUID
    pending_downgrade_requested_at: datetime


class ActivateSubscriptionRequest(BaseSchema):
    plan_id: uuid.UUID
    extension_days: int = Field(default=30, ge=1)


class ChangePlanRequest(BaseSchema):
    plan_id: uuid.UUID


class ReviewProofRequest(BaseSchema):
    review_notes: str | None = None


# Paginated type aliases
PaginatedPlans = PaginatedResponse[PlanResponse]
PaginatedSubscriptionHistory = PaginatedResponse[SubscriptionHistoryResponse]
PaginatedPaymentProofs = PaginatedResponse[PaymentProofResponse]



class TenantEntitlementOverrideCreateRequest(BaseSchema):
    feature_code: str
    enabled: bool | None = None
    limit_value: int | None = None
    reason: str | None = None
    expires_at: datetime | None = None


class TenantEntitlementOverrideUpdateRequest(BaseSchema):
    enabled: bool | None = None
    limit_value: int | None = None
    reason: str | None = None
    expires_at: datetime | None = None


class TenantEntitlementOverrideResponse(TimestampedSchema):
    tenant_id: uuid.UUID
    feature_code: str
    enabled: bool | None
    limit_value: int | None
    reason: str | None
    expires_at: datetime | None
    created_by_user_id: uuid.UUID | None


class EffectiveEntitlementResponse(BaseSchema):
    feature_code: str
    enabled: bool
    limit_value: int | None
    source: str


class SubscriptionOverviewResponse(BaseSchema):
    total_tenants: int
    active_subscriptions: int
    trial_subscriptions: int
    expired_subscriptions: int
    suspended_subscriptions: int
    monthly_revenue: Decimal
    total_users: int = 0
    total_branches: int = 0
    total_orders: int = 0


class ExtendSubscriptionRequest(BaseSchema):
    days: int = Field(ge=1, le=3650)
    reason: str | None = None


class AdminChangePlanRequest(BaseSchema):
    plan_id: uuid.UUID
    reason: str | None = None


# Paginated admin type aliases
PaginatedAdminSubscriptions = PaginatedResponse[SubscriptionResponse]
PaginatedOverrides = PaginatedResponse[TenantEntitlementOverrideResponse]
