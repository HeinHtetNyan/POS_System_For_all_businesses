from __future__ import annotations

from fastapi import APIRouter

from app.api.deps import DbSession
from app.core.exceptions import NotFoundError
from app.subscriptions.schemas import AppDownloadLinksResponse, PublicPlanResponse, PublicTrialPlanResponse
from app.subscriptions.services import PlanService, PlatformSettingsService

router = APIRouter()


@router.get(
    "/plans",
    response_model=list[PublicPlanResponse],
    summary="List publicly visible subscription plans (no auth required)",
)
async def list_public_plans(db: DbSession) -> list[PublicPlanResponse]:
    svc = PlanService(db)
    plans = await svc.list_public_plans()
    return [PublicPlanResponse.model_validate(p) for p in plans]


@router.get(
    "/trial-plan",
    response_model=PublicTrialPlanResponse,
    summary="Get the default free trial's length and limits (no auth required)",
)
async def get_public_trial_plan(db: DbSession) -> PublicTrialPlanResponse:
    svc = PlanService(db)
    plan = await svc.get_trial_plan()
    if not plan:
        raise NotFoundError("SubscriptionPlan", "trial")

    limits = {e.feature_code: e.limit_value for e in plan.entitlements}
    return PublicTrialPlanResponse(
        trial_days=plan.trial_days,
        products=limits.get("products"),
        branches=limits.get("branches"),
        users=limits.get("users"),
        customers=limits.get("customers"),
    )


@router.get(
    "/app-download-links",
    response_model=AppDownloadLinksResponse,
    summary="Get the mobile/desktop app download links shown on the login screen (no auth required)",
)
async def get_public_app_download_links(db: DbSession) -> AppDownloadLinksResponse:
    svc = PlatformSettingsService(db)
    links = await svc.get_app_download_links()
    return AppDownloadLinksResponse(**links)
