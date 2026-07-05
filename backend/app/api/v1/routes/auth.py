from __future__ import annotations

from fastapi import APIRouter, BackgroundTasks, Depends, Query, Request, Response

from app.api.deps import (
    ClientIp,
    CurrentUser,
    DbSession,
    RequestId,
    UserAgent,
)
from app.core.config import settings
from app.core.rate_limit import check_rate_limit, check_registration_rate_limit
from app.db.redis import get_redis_optional
from app.notifications.email import (
    send_email_change_confirmation,
    send_email_change_notice,
    send_password_reset_email,
    send_verification_email,
)
from app.schemas.auth import (
    ChangePasswordRequest,
    ConfirmEmailChangeRequest,
    ForgotPasswordRequest,
    LoginRequest,
    RequestEmailChangeRequest,
    ResendVerificationRequest,
    ResetPasswordRequest,
    TokenResponse,
    VerifyEmailRequest,
)
from app.schemas.common import SuccessResponse
from app.schemas.user import UserResponse
from app.services.auth_service import AuthService
from app.subscriptions.schemas import RegisterRequest, RegistrationResponse
from app.services.registration_service import RegistrationService

router = APIRouter()


@router.post("/login", response_model=TokenResponse, summary="User login")
async def login(
    payload: LoginRequest,
    response: Response,
    db: DbSession,
    ip: ClientIp,
    ua: UserAgent,
    request_id: RequestId,
    redis=Depends(get_redis_optional),
) -> TokenResponse:
    service = AuthService(db)
    token_response, refresh_token = await service.login(
        email=payload.email,
        business_code=payload.business_code,
        identifier=payload.identifier,
        password=payload.password,
        ip_address=ip,
        user_agent=ua,
        request_id=request_id,
        redis=redis,
    )
    response.set_cookie(
        key=settings.JWT_REFRESH_TOKEN_COOKIE_NAME,
        value=refresh_token,
        httponly=True,
        secure=settings.refresh_cookie_secure,
        samesite=settings.JWT_REFRESH_TOKEN_COOKIE_SAMESITE,
        max_age=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS * 86400,
    )
    return token_response


@router.post("/refresh", response_model=TokenResponse, summary="Refresh access token")
async def refresh_token(
    request: Request,
    response: Response,
    db: DbSession,
    ip: ClientIp,
    ua: UserAgent,
    request_id: RequestId,
) -> TokenResponse:
    from app.core.exceptions import AuthenticationError as _AuthErr
    # Read refresh token from httponly cookie (preferred) or fall back to JSON body
    token_str: str | None = request.cookies.get(settings.JWT_REFRESH_TOKEN_COOKIE_NAME)
    if not token_str:
        try:
            body = await request.json()
            token_str = body.get("refresh_token")
        except Exception:
            pass
    if not token_str:
        raise _AuthErr("No refresh token provided")
    service = AuthService(db)
    token_response, new_refresh_token = await service.refresh_tokens(
        refresh_token=token_str,
        ip_address=ip,
        user_agent=ua,
        request_id=request_id,
    )
    response.set_cookie(
        key=settings.JWT_REFRESH_TOKEN_COOKIE_NAME,
        value=new_refresh_token,
        httponly=True,
        secure=settings.refresh_cookie_secure,
        samesite=settings.JWT_REFRESH_TOKEN_COOKIE_SAMESITE,
        max_age=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS * 86400,
    )
    return token_response


@router.post("/logout", response_model=SuccessResponse, summary="Logout user")
async def logout(
    request: Request,
    response: Response,
    db: DbSession,
    current_user: CurrentUser,
    request_id: RequestId,
) -> SuccessResponse:
    # Prefer cookie; fall back to JSON body for backward compatibility
    token_str: str | None = request.cookies.get(settings.JWT_REFRESH_TOKEN_COOKIE_NAME)
    if not token_str:
        try:
            body = await request.json()
            token_str = body.get("refresh_token")
        except Exception:
            pass
    service = AuthService(db)
    await service.logout(
        user_id=current_user.id,
        refresh_token=token_str,
        tenant_id=current_user.tenant_id,
        request_id=request_id,
    )
    response.delete_cookie(key=settings.JWT_REFRESH_TOKEN_COOKIE_NAME)
    return SuccessResponse(message="Logged out successfully")


@router.post("/change-password", response_model=SuccessResponse, summary="Change password")
async def change_password(
    payload: ChangePasswordRequest,
    db: DbSession,
    current_user: CurrentUser,
    request_id: RequestId,
    redis=Depends(get_redis_optional),
) -> SuccessResponse:
    service = AuthService(db)
    await service.change_password(
        user_id=current_user.id,
        current_password=payload.current_password,
        new_password=payload.new_password,
        tenant_id=current_user.tenant_id,
        request_id=request_id,
        redis=redis,
    )
    return SuccessResponse(message="Password changed successfully")


@router.get("/me", response_model=UserResponse, summary="Get current user profile")
async def get_me(current_user: CurrentUser) -> UserResponse:
    return UserResponse.model_validate(current_user)


@router.post("/forgot-password", response_model=SuccessResponse, summary="Request a password reset link")
async def forgot_password(
    payload: ForgotPasswordRequest,
    background_tasks: BackgroundTasks,
    db: DbSession,
    request_id: RequestId,
    ip: ClientIp,
    redis=Depends(get_redis_optional),
) -> SuccessResponse:
    # Rate limit: 5 attempts per email per hour to prevent abuse
    await check_rate_limit(
        redis=redis,
        key=f"rate:forgot_password:{payload.email.lower()}",
        max_requests=5,
        window_seconds=3600,
        error_message="Too many password reset requests. Please try again in an hour.",
    )
    service = AuthService(db)
    result = await service.create_password_reset_token(
        email=payload.email.lower().strip(),
        request_id=request_id,
    )
    if result:
        email, raw_token = result
        # Email is sent AFTER the DB session commits (BackgroundTask runs post-response)
        background_tasks.add_task(send_password_reset_email, email, raw_token)
    # Always return the same message to prevent user enumeration
    return SuccessResponse(message="If an account with that email exists, a password reset link has been sent.")


@router.post("/reset-password", response_model=SuccessResponse, summary="Reset password using a reset token")
async def reset_password(
    payload: ResetPasswordRequest,
    db: DbSession,
    request_id: RequestId,
    ip: ClientIp,
    redis=Depends(get_redis_optional),
) -> SuccessResponse:
    # Rate limit: 10 attempts per IP per hour — token entropy is high but limit anyway
    await check_rate_limit(
        redis=redis,
        key=f"rate:reset_password:{ip or 'unknown'}",
        max_requests=10,
        window_seconds=3600,
        error_message="Too many password reset attempts. Please try again in an hour.",
    )
    service = AuthService(db)
    await service.reset_password(
        token=payload.token,
        new_password=payload.new_password,
        request_id=request_id,
    )
    return SuccessResponse(message="Password reset successfully. You can now log in with your new password.")


@router.post("/verify-email", response_model=SuccessResponse, summary="Verify email address using a verification token")
async def verify_email(
    payload: VerifyEmailRequest,
    db: DbSession,
    request_id: RequestId,
    ip: ClientIp,
    redis=Depends(get_redis_optional),
) -> SuccessResponse:
    # Rate limit: 10 attempts per IP per hour — token entropy is high but limit anyway
    await check_rate_limit(
        redis=redis,
        key=f"rate:verify_email:{ip or 'unknown'}",
        max_requests=10,
        window_seconds=3600,
        error_message="Too many verification attempts. Please try again in an hour.",
    )
    service = AuthService(db)
    await service.verify_email(token=payload.token, request_id=request_id)
    return SuccessResponse(message="Email verified successfully.")


@router.post("/resend-verification", response_model=SuccessResponse, summary="Resend the email verification link")
async def resend_verification(
    payload: ResendVerificationRequest,
    background_tasks: BackgroundTasks,
    db: DbSession,
    request_id: RequestId,
    ip: ClientIp,
    redis=Depends(get_redis_optional),
) -> SuccessResponse:
    # Rate limit: 5 requests per email per hour to prevent abuse
    await check_rate_limit(
        redis=redis,
        key=f"rate:resend_verification:{payload.email.lower()}",
        max_requests=5,
        window_seconds=3600,
        error_message="Too many verification requests. Please try again in an hour.",
    )
    service = AuthService(db)
    result = await service.request_email_verification(
        email=payload.email.lower().strip(),
        request_id=request_id,
    )
    if result:
        email, raw_token = result
        background_tasks.add_task(send_verification_email, email, raw_token)
    # Same generic message whether or not the account exists/is already verified —
    # prevents user enumeration via this endpoint.
    return SuccessResponse(message="If the account exists and isn't verified yet, a verification email has been sent.")


@router.post("/request-email-change", response_model=SuccessResponse, summary="Request a change of the account's email address")
async def request_email_change(
    payload: RequestEmailChangeRequest,
    background_tasks: BackgroundTasks,
    db: DbSession,
    current_user: CurrentUser,
    request_id: RequestId,
    redis=Depends(get_redis_optional),
) -> SuccessResponse:
    # Rate limit: 5 requests per account per hour — same ceiling as resend-verification
    await check_rate_limit(
        redis=redis,
        key=f"rate:request_email_change:{current_user.id}",
        max_requests=5,
        window_seconds=3600,
        error_message="Too many email change requests. Please try again in an hour.",
    )
    service = AuthService(db)
    old_email, raw_token = await service.request_email_change(
        user_id=current_user.id,
        new_email=payload.new_email,
        current_password=payload.current_password,
        tenant_id=current_user.tenant_id,
        request_id=request_id,
        redis=redis,
    )
    new_email = payload.new_email.lower().strip()
    background_tasks.add_task(send_email_change_confirmation, new_email, new_email, raw_token)
    background_tasks.add_task(send_email_change_notice, old_email, new_email)
    return SuccessResponse(message=f"Check {new_email} for a confirmation link to complete the change.")


@router.post("/confirm-email-change", response_model=SuccessResponse, summary="Confirm a pending email address change")
async def confirm_email_change(
    payload: ConfirmEmailChangeRequest,
    db: DbSession,
    request_id: RequestId,
    ip: ClientIp,
    redis=Depends(get_redis_optional),
) -> SuccessResponse:
    # Rate limit: 10 attempts per IP per hour — token entropy is high but limit anyway
    await check_rate_limit(
        redis=redis,
        key=f"rate:confirm_email_change:{ip or 'unknown'}",
        max_requests=10,
        window_seconds=3600,
        error_message="Too many attempts. Please try again in an hour.",
    )
    service = AuthService(db)
    await service.confirm_email_change(token=payload.token, request_id=request_id)
    return SuccessResponse(message="Email address updated successfully.")


@router.post("/register", response_model=RegistrationResponse, status_code=201, summary="Self-service business registration")
async def register(
    payload: RegisterRequest,
    response: Response,
    db: DbSession,
    ip: ClientIp,
    ua: UserAgent,
    request_id: RequestId,
    redis=Depends(get_redis_optional),
    ref: str | None = Query(default=None, description="Referral code from ?ref=CODE link"),
) -> RegistrationResponse:
    # Merge query-param referral code into payload (query param takes precedence)
    if ref and not payload.referral_code:
        payload.referral_code = ref.strip().upper()
    await check_registration_rate_limit(redis, ip or "unknown")
    svc = RegistrationService(db)
    result = await svc.register(
        data=payload,
        ip_address=ip,
        user_agent=ua,
        request_id=request_id,
        redis=redis,
    )
    response.set_cookie(
        key=settings.JWT_REFRESH_TOKEN_COOKIE_NAME,
        value=result.refresh_token,
        httponly=True,
        secure=settings.refresh_cookie_secure,
        samesite=settings.JWT_REFRESH_TOKEN_COOKIE_SAMESITE,
        max_age=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS * 86400,
    )
    return result
