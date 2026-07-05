from __future__ import annotations

import uuid
from typing import Any, Callable

import httpx

from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

_MAILTRAP_API_URL = "https://send.api.mailtrap.io/api/send"


async def _send_via_mailtrap(*, to: str, subject: str, html: str) -> None:
    """Send an email via Mailtrap Sending API using httpx."""
    if not settings.EMAIL_ENABLED:
        logger.info("email_disabled_skip", to=to, subject=subject)
        return

    token = settings.MAILTRAP_API_TOKEN.strip()
    if not token:
        logger.warning("mailtrap_token_not_set", to=to)
        return

    payload = {
        "from": {
            "email": settings.EMAIL_FROM,       # TODO: update EMAIL_FROM in .env
            "name": settings.EMAIL_FROM_NAME,   # TODO: update EMAIL_FROM_NAME in .env
        },
        "to": [{"email": to}],
        "subject": subject,
        "html": html,
        "category": "Transactional",
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                _MAILTRAP_API_URL,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            response.raise_for_status()
            logger.info("mailtrap_sent", to=to, subject=subject)
    except httpx.HTTPStatusError as exc:
        logger.error(
            "mailtrap_send_failed",
            to=to,
            subject=subject,
            status=exc.response.status_code,
            body=exc.response.text,
        )
        raise
    except Exception:
        logger.exception("mailtrap_send_error", to=to, subject=subject)
        raise


# Shared branded shell — every outgoing email (password reset, receipts,
# reminders, approvals) renders through this so they all look like one
# product: dark header with logo, white content card, optional Burmese
# translation block (dashed divider, matches how bilingual notices commonly
# look in Myanmar), light footer with a support contact.
def _render_email_shell(
    *,
    badge_label: str,
    heading: str,
    body_html: str,
    burmese_html: str | None = None,
) -> str:
    burmese_block = ""
    if burmese_html:
        burmese_block = f"""
          <tr>
            <td style="padding:4px 32px 24px;">
              <hr style="border:none;border-top:1px dashed #d1d5db;margin:0 0 20px;">
              <div style="font-size:13px;line-height:1.8;color:#4b5563;">{burmese_html}</div>
            </td>
          </tr>"""

    return f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>{heading}</title></head>
<body style="margin:0;padding:24px;background:#f4f7fb;font-family:Arial,sans-serif;color:#1f2937;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
    <tr>
      <td align="center">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0"
               style="background:#ffffff;border-radius:12px;overflow:hidden;">

          <tr>
            <td style="background:#111827;padding:28px 32px;">
              <table width="100%" cellspacing="0" cellpadding="0">
                <tr>
                  <td>
                    <img src="{settings.FRONTEND_BASE_URL.rstrip('/')}/logo-icon.png" alt="SawYunPos"
                         width="40" height="40" style="display:inline-block;width:40px;height:40px;border-radius:8px;vertical-align:middle;">
                    <span style="font-size:20px;font-weight:700;color:#f3f4f6;vertical-align:middle;margin-left:10px;">SawYunPos</span>
                  </td>
                  <td style="text-align:right;">
                    <span style="background:#f59e0b;color:#000;font-size:11px;font-weight:700;
                                 padding:4px 10px;border-radius:20px;text-transform:uppercase;">{badge_label}</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <tr>
            <td style="padding:28px 32px 8px;">
              <h1 style="margin:0 0 16px;font-size:22px;color:#111827;">{heading}</h1>
              <div style="font-size:14px;line-height:1.7;color:#374151;">{body_html}</div>
            </td>
          </tr>
          {burmese_block}

          <tr>
            <td style="padding:20px 32px;background:#f9fafb;border-top:1px solid #e5e7eb;">
              <p style="margin:0 0 4px;font-size:12px;color:#6b7280;">
                Need help? <a href="mailto:{settings.EMAIL_FROM}" style="color:#f59e0b;text-decoration:none;font-weight:600;">{settings.EMAIL_FROM}</a>
              </p>
              <p style="margin:0;font-size:11px;color:#9ca3af;">
                This is an automated message from SawYunPos — please don't reply directly to this email.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""


def _build_reset_password_html(reset_url: str) -> str:
    mins = settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES
    body_html = f"""
        <p style="margin:0 0 16px;">We received a request to reset the password for your account.
        Click the button below to choose a new password. This link expires in
        <strong>{mins} minutes</strong>.</p>
        <p style="margin:24px 0;">
          <a href="{reset_url}"
             style="background:#f97316;color:#ffffff;text-decoration:none;
                    padding:12px 24px;border-radius:8px;display:inline-block;font-weight:600;">
            Reset password
          </a>
        </p>
        <p style="margin:0 0 8px;font-size:13px;color:#6b7280;">
          If the button doesn't work, copy and paste this link into your browser:
        </p>
        <p style="word-break:break-all;font-size:13px;">
          <a href="{reset_url}" style="color:#f97316;">{reset_url}</a>
        </p>
        <p style="margin:16px 0 0;font-size:12px;color:#9ca3af;">
          If you didn't request a password reset, you can safely ignore this email —
          your password will not change.
        </p>"""
    burmese_html = f"""
        <p style="margin:0;">သင့်အကောင့်အတွက် စကားဝှက်အသစ်ပြောင်းလဲရန် တောင်းဆိုမှုကို
        လက်ခံရရှိပါသည်။ အထက်ပါခလုတ်ကို နှိပ်ပြီး စကားဝှက်အသစ်သတ်မှတ်ပါ။ ဤလင့်ခ်သည်
        {mins} မိနစ်အတွင်း သက်တမ်းကုန်ဆုံးပါမည်။ သင်ကိုယ်တိုင် တောင်းဆိုခြင်းမဟုတ်ပါက
        ဤအီးမေးလ်ကို လျစ်လျူရှုနိုင်ပါသည် — သင့်စကားဝှက်ကို ပြောင်းလဲမည်မဟုတ်ပါ။</p>"""
    return _render_email_shell(
        badge_label="Security",
        heading="Reset your password",
        body_html=body_html,
        burmese_html=burmese_html,
    )


def _build_subscription_receipt_html(
    *,
    tenant_name: str,
    plan_name: str,
    plan_price: str,
    currency: str,
    started_at: str,
    expires_at: str,
    paid_amount: str,
    reference_number: str | None,
    action_label: str,
) -> str:
    ref_row = ""
    if reference_number:
        ref_row = f"""
                <tr>
                  <td style="padding:8px 0;color:#6b7280;font-size:14px;">Reference / Invoice No.</td>
                  <td style="padding:8px 0;color:#111827;font-size:14px;font-weight:600;text-align:right;">{reference_number}</td>
                </tr>"""

    body_html = f"""
        <p style="margin:0 0 16px;color:#6b7280;">Your payment has been approved. Here&rsquo;s a summary.</p>
        <div style="background:#f9fafb;border-radius:8px;padding:14px 16px;margin:0 0 16px;">
          <p style="margin:0;font-size:12px;color:#9ca3af;text-transform:uppercase;letter-spacing:.5px;">Business</p>
          <p style="margin:4px 0 0;font-size:16px;font-weight:700;color:#111827;">{tenant_name}</p>
        </div>
        <table width="100%" cellspacing="0" cellpadding="0" style="border-top:1px solid #e5e7eb;">
          <tr>
            <td style="padding:14px 0 8px;color:#6b7280;font-size:13px;text-transform:uppercase;
                        letter-spacing:.5px;font-weight:600;" colspan="2">Plan Details</td>
          </tr>
          <tr>
            <td style="padding:8px 0;color:#6b7280;font-size:14px;">Plan</td>
            <td style="padding:8px 0;color:#111827;font-size:14px;font-weight:600;text-align:right;">{plan_name}</td>
          </tr>
          <tr>
            <td style="padding:8px 0;color:#6b7280;font-size:14px;">Plan Price</td>
            <td style="padding:8px 0;color:#111827;font-size:14px;font-weight:600;text-align:right;">{plan_price} {currency} / cycle</td>
          </tr>
          <tr>
            <td colspan="2" style="padding:6px 0;"><hr style="border:none;border-top:1px solid #e5e7eb;margin:0;"></td>
          </tr>
          <tr>
            <td style="padding:8px 0;color:#6b7280;font-size:14px;">Subscription Start</td>
            <td style="padding:8px 0;color:#111827;font-size:14px;font-weight:600;text-align:right;">{started_at}</td>
          </tr>
          <tr>
            <td style="padding:8px 0;color:#6b7280;font-size:14px;">Valid Until</td>
            <td style="padding:8px 0;color:#111827;font-size:14px;font-weight:600;text-align:right;">{expires_at}</td>
          </tr>
          <tr>
            <td colspan="2" style="padding:6px 0;"><hr style="border:none;border-top:1px solid #e5e7eb;margin:0;"></td>
          </tr>
          <tr>
            <td style="padding:8px 0;color:#6b7280;font-size:14px;">Amount Paid</td>
            <td style="padding:8px 0;color:#f59e0b;font-size:18px;font-weight:700;text-align:right;">{paid_amount} {currency}</td>
          </tr>
          {ref_row}
        </table>"""
    burmese_html = f"""
        <p style="margin:0;">{tenant_name} ၏ ငွေပေးချေမှုကို စိစစ်အတည်ပြုပြီးဖြစ်ပါသည်။
        {plan_name} အစီအစဉ်သည် {expires_at} အထိ အသက်ဝင်နေပါပြီ — ပေးချေငွေပမာဏ
        {paid_amount} {currency}။ ကျေးဇူးတင်ပါသည်။</p>"""
    return _render_email_shell(
        badge_label=action_label,
        heading="Subscription Receipt",
        body_html=body_html,
        burmese_html=burmese_html,
    )


def _build_verify_email_html(verify_url: str) -> str:
    mins = settings.EMAIL_VERIFICATION_TOKEN_EXPIRE_MINUTES
    hours = mins // 60
    body_html = f"""
        <p style="margin:0 0 16px;">Thanks for creating a SawYunPos account! Please confirm this is your
        email address by clicking the button below. This link expires in
        <strong>{hours} hour(s)</strong>.</p>
        <p style="margin:24px 0;">
          <a href="{verify_url}"
             style="background:#f97316;color:#ffffff;text-decoration:none;
                    padding:12px 24px;border-radius:8px;display:inline-block;font-weight:600;">
            Verify my email
          </a>
        </p>
        <p style="margin:0 0 8px;font-size:13px;color:#6b7280;">
          If the button doesn't work, copy and paste this link into your browser:
        </p>
        <p style="word-break:break-all;font-size:13px;">
          <a href="{verify_url}" style="color:#f97316;">{verify_url}</a>
        </p>
        <p style="margin:16px 0 0;font-size:12px;color:#9ca3af;">
          If you didn't create this account, you can safely ignore this email.
        </p>"""
    burmese_html = f"""
        <p style="margin:0;">SawYunPos အကောင့်ဖွင့်ပေးသည့်အတွက် ကျေးဇူးတင်ပါသည်။ ဤအီးမေးလ်
        လိပ်စာသည် သင့်ကိုယ်ပိုင်ဖြစ်ကြောင်း အတည်ပြုရန် အထက်ပါခလုတ်ကို နှိပ်ပါ။ ဤလင့်ခ်သည်
        {hours} နာရီအတွင်း သက်တမ်းကုန်ဆုံးပါမည်။ ဤအကောင့်ကို သင်ဖွင့်ခြင်းမဟုတ်ပါက
        ဤအီးမေးလ်ကို လျစ်လျူရှုနိုင်ပါသည်။</p>"""
    return _render_email_shell(
        badge_label="Verify Email",
        heading="Verify your email address",
        body_html=body_html,
        burmese_html=burmese_html,
    )


def _build_email_change_confirm_html(confirm_url: str, new_email: str) -> str:
    mins = settings.EMAIL_CHANGE_TOKEN_EXPIRE_MINUTES
    body_html = f"""
        <p style="margin:0 0 16px;">Someone requested to change the email address on a SawYunPos
        account to <strong>{new_email}</strong> (this address). Click the button below to confirm
        the change. This link expires in <strong>{mins} minutes</strong>.</p>
        <p style="margin:24px 0;">
          <a href="{confirm_url}"
             style="background:#f97316;color:#ffffff;text-decoration:none;
                    padding:12px 24px;border-radius:8px;display:inline-block;font-weight:600;">
            Confirm email change
          </a>
        </p>
        <p style="margin:0 0 8px;font-size:13px;color:#6b7280;">
          If the button doesn't work, copy and paste this link into your browser:
        </p>
        <p style="word-break:break-all;font-size:13px;">
          <a href="{confirm_url}" style="color:#f97316;">{confirm_url}</a>
        </p>
        <p style="margin:16px 0 0;font-size:12px;color:#9ca3af;">
          If you didn't request this, you can safely ignore this email — the account's email
          address will not change unless this link is clicked.
        </p>"""
    burmese_html = f"""
        <p style="margin:0;">SawYunPos အကောင့်တစ်ခု၏ အီးမေးလ်လိပ်စာကို ဤလိပ်စာ ({new_email})
        သို့ ပြောင်းလဲရန် တောင်းဆိုမှုတစ်ခု ရှိပါသည်။ ပြောင်းလဲမှုကို အတည်ပြုရန် အထက်ပါ
        ခလုတ်ကို နှိပ်ပါ။ ဤလင့်ခ်သည် {mins} မိနစ်အတွင်း သက်တမ်းကုန်ဆုံးပါမည်။ သင်ကိုယ်တိုင်
        တောင်းဆိုခြင်းမဟုတ်ပါက ဤအီးမေးလ်ကို လျစ်လျူရှုနိုင်ပါသည် — ဤလင့်ခ်ကို မနှိပ်မချင်း
        အကောင့်၏ အီးမေးလ်လိပ်စာ ပြောင်းလဲမည်မဟုတ်ပါ။</p>"""
    return _render_email_shell(
        badge_label="Confirm Change",
        heading="Confirm your new email address",
        body_html=body_html,
        burmese_html=burmese_html,
    )


def _build_email_change_notice_html(new_email: str) -> str:
    body_html = f"""
        <p style="margin:0 0 16px;">A request was made to change this account's email address to
        <strong>{new_email}</strong>. The change will only take effect once that new address is
        confirmed — this inbox will stop receiving account emails at that point.</p>
        <p style="margin:0;">If this wasn't you, your password may be compromised — sign in and
        change your password immediately, or contact support.</p>"""
    burmese_html = f"""
        <p style="margin:0;">ဤအကောင့်၏ အီးမေးလ်လိပ်စာကို {new_email} သို့ ပြောင်းလဲရန်
        တောင်းဆိုမှုတစ်ခု ရှိခဲ့ပါသည်။ ထိုလိပ်စာအား အတည်ပြုမှသာ ပြောင်းလဲမှု အသက်ဝင်ပါမည်။
        ဤသည်မှာ သင်ကိုယ်တိုင် တောင်းဆိုခြင်းမဟုတ်ပါက သင့်စကားဝှက်ကို ချက်ချင်းပြောင်းလဲပါ
        သို့မဟုတ် အကူအညီရယူပါ။</p>"""
    return _render_email_shell(
        badge_label="Security Notice",
        heading="Email change requested on your account",
        body_html=body_html,
        burmese_html=burmese_html,
    )


def _build_subscription_expiring_html(context: dict[str, Any]) -> str:
    days = context.get("days", 0)
    tenant_name = context.get("tenant_name", "")
    expires_at = context.get("expires_at", "")
    body_html = f"""
        <p style="margin:0 0 16px;">Your subscription for <strong>{tenant_name}</strong> will expire in
        <strong>{days} day(s)</strong>, on <strong>{expires_at}</strong>.</p>
        <p style="margin:0;">To continue using all features without interruption, please renew your
        subscription before the expiration date.</p>"""
    burmese_html = f"""
        <p style="margin:0;">{tenant_name} အတွက် သင့်လက်ရှိစာရင်းသွင်းမှုသည် ရက် {days}
        အတွင်း ({expires_at}) သက်တမ်းကုန်ဆုံးပါတော့မည်။ ဝန်ဆောင်မှု အနှောင့်အယှက်
        မရှိစေရန် သက်တမ်းကုန်ဆုံးမီ စာရင်းသွင်းမှုကို သက်တမ်းတိုးပါ။</p>"""
    return _render_email_shell(
        badge_label="Reminder",
        heading=f"Subscription Expires in {days} Day(s)",
        body_html=body_html,
        burmese_html=burmese_html,
    )


def _build_payment_proof_approved_html(context: dict[str, Any]) -> str:
    tenant_name = context.get("tenant_name", "")
    amount = context.get("amount", "")
    currency = context.get("currency", "MMK")
    expires_at = context.get("expires_at", "")
    body_html = f"""
        <p style="margin:0 0 16px;">Your payment proof of <strong>{amount} {currency}</strong> has been
        reviewed and approved.</p>
        <p style="margin:0;">Your subscription for <strong>{tenant_name}</strong> is now active until
        <strong>{expires_at}</strong>. Thank you for your payment.</p>"""
    burmese_html = f"""
        <p style="margin:0;">သင့်ငွေပေးချေမှု အထောက်အထား {amount} {currency} ကို
        စိစစ်အတည်ပြုပြီးဖြစ်ပါသည်။ {tenant_name} အတွက် စာရင်းသွင်းမှုသည် {expires_at}
        အထိ အသက်ဝင်နေပါပြီ။ ငွေပေးချေမှုအတွက် ကျေးဇူးတင်ပါသည်။</p>"""
    return _render_email_shell(
        badge_label="Approved",
        heading="Payment Proof Approved",
        body_html=body_html,
        burmese_html=burmese_html,
    )


# Subject line + HTML builder per generic template_name — kept separate from
# the specific `send_*_email` helpers above (password reset, receipt) since
# those are called directly with their own required arguments, while these
# route through the generic queue_email_notification(template_name, context)
# path used by the notification event handlers.
_TEMPLATE_SUBJECTS: dict[str, str] = {
    "subscription_expiring": "Your Subscription Expires in {days} Day(s)",
    "payment_proof_approved": "Payment Proof Approved — Subscription Renewed",
}

_TEMPLATE_HTML_BUILDERS: dict[str, Callable[[dict[str, Any]], str]] = {
    "subscription_expiring": _build_subscription_expiring_html,
    "payment_proof_approved": _build_payment_proof_approved_html,
}


async def send_subscription_receipt_email(
    *,
    to: str,
    tenant_name: str,
    plan_name: str,
    plan_price: str,
    currency: str,
    started_at: str,
    expires_at: str,
    paid_amount: str,
    reference_number: str | None,
    action_label: str,
) -> None:
    html = _build_subscription_receipt_html(
        tenant_name=tenant_name,
        plan_name=plan_name,
        plan_price=plan_price,
        currency=currency,
        started_at=started_at,
        expires_at=expires_at,
        paid_amount=paid_amount,
        reference_number=reference_number,
        action_label=action_label,
    )
    try:
        await _send_via_mailtrap(to=to, subject=f"Subscription Receipt — {plan_name}", html=html)
    except Exception:
        logger.exception("subscription_receipt_email_failed", to=to)


async def send_password_reset_email(to: str, token: str) -> None:
    """
    Send a password reset email via Mailtrap.
    Safe to use as a FastAPI BackgroundTask (async).
    """
    reset_url = f"{settings.FRONTEND_BASE_URL.rstrip('/')}/reset-password?token={token}"
    html = _build_reset_password_html(reset_url)
    try:
        await _send_via_mailtrap(to=to, subject="Reset your password", html=html)
    except Exception:
        logger.exception("password_reset_email_failed", to=to)


async def send_verification_email(to: str, token: str) -> None:
    """
    Send an email-address verification email via Mailtrap.
    Safe to use as a FastAPI BackgroundTask (async) or awaited directly.
    """
    verify_url = f"{settings.FRONTEND_BASE_URL.rstrip('/')}/verify-email?token={token}"
    html = _build_verify_email_html(verify_url)
    try:
        await _send_via_mailtrap(to=to, subject="Verify your email address", html=html)
    except Exception:
        logger.exception("verification_email_failed", to=to)


async def send_email_change_confirmation(to: str, new_email: str, token: str) -> None:
    """
    Send the confirmation link to the NEW address for a pending email change.
    Safe to use as a FastAPI BackgroundTask (async) or awaited directly.
    """
    confirm_url = f"{settings.FRONTEND_BASE_URL.rstrip('/')}/confirm-email-change?token={token}"
    html = _build_email_change_confirm_html(confirm_url, new_email)
    try:
        await _send_via_mailtrap(to=to, subject="Confirm your new email address", html=html)
    except Exception:
        logger.exception("email_change_confirmation_failed", to=to)


async def send_email_change_notice(to: str, new_email: str) -> None:
    """
    Send a heads-up (no action link) to the OLD address when an email change
    is requested, so the real owner finds out immediately if it wasn't them.
    """
    html = _build_email_change_notice_html(new_email)
    try:
        await _send_via_mailtrap(to=to, subject="Email change requested on your account", html=html)
    except Exception:
        logger.exception("email_change_notice_failed", to=to)


class EmailNotificationService:
    """
    Abstraction layer for email notifications.

    _deliver() sends via Mailtrap API. Templates registered in
    _TEMPLATE_SUBJECTS/_TEMPLATE_HTML_BUILDERS render as branded HTML through
    _render_email_shell(), matching send_subscription_receipt_email and
    send_password_reset_email above.
    """

    def __init__(self) -> None:
        pass

    def _render(self, template_name: str, context: dict[str, Any]) -> tuple[str, str]:
        subject_template = _TEMPLATE_SUBJECTS.get(template_name)
        if subject_template is None:
            logger.warning("email_template_not_found", template_name=template_name)
            fallback_html = f"<pre style='font-family:Arial,sans-serif;white-space:pre-wrap;'>{context}</pre>"
            return f"Notification: {template_name}", fallback_html
        subject = subject_template.format_map(context)
        builder = _TEMPLATE_HTML_BUILDERS[template_name]
        return subject, builder(context)

    async def _deliver(
        self,
        to: str,
        subject: str,
        html: str,
    ) -> None:
        await _send_via_mailtrap(to=to, subject=subject, html=html)

    async def send_email_notification(
        self,
        to: str,
        template_name: str,
        context: dict[str, Any],
    ) -> None:
        subject, html = self._render(template_name, context)
        await self._deliver(to=to, subject=subject, html=html)
        logger.info("email_notification_sent", to=to, template=template_name)

    async def queue_email_notification(
        self,
        to: str,
        template_name: str,
        context: dict[str, Any],
        user_id: uuid.UUID | None = None,
    ) -> None:
        from app.tasks.notification_tasks import send_email_task

        send_email_task.delay(
            to=to,
            template_name=template_name,
            context=context,
            user_id=str(user_id) if user_id else None,
        )
        logger.info(
            "email_notification_queued",
            to=to,
            template=template_name,
            user_id=str(user_id) if user_id else None,
        )


# Process-level singleton
email_service = EmailNotificationService()
