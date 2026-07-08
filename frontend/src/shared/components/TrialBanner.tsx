import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { useAuthStore } from '@/store/auth.store'
import { useLocaleStore } from '@/i18n/localeStore'
import { subscriptionsService } from '@/services/subscriptions/subscriptions.service'

export default function TrialBanner() {
  const user = useAuthStore(s => s.user)
  const t = useLocaleStore(s => s.t)
  const isEligible = !!user && user.role === 'BUSINESS_OWNER'

  const { data: status } = useQuery({
    queryKey: ['subscription-status'],
    queryFn: subscriptionsService.getTrialStatus,
    enabled: isEligible,
    staleTime: 5 * 60 * 1000,
    refetchInterval: 10 * 60 * 1000,
  })

  if (!status) return null

  const isTrial = status.status === 'TRIAL'
  const isExpired = status.status === 'EXPIRED' || status.status === 'SUSPENDED'
  const isActivePaidApproaching =
    status.status === 'ACTIVE' &&
    status.days_remaining >= 0 &&
    status.days_remaining <= 14

  if (!isTrial && !isExpired && !isActivePaidApproaching) return null

  if (isExpired) {
    return (
      <div className="px-4 py-2 flex items-center justify-between gap-4 text-xs font-medium bg-red-950 border-b border-red-900 text-red-300 flex-shrink-0">
        <span>{t('shared.trial_banner.plan_expired')}</span>
        <Link
          to="/app/subscription/current"
          className="flex-shrink-0 px-3 py-1 rounded-lg font-semibold transition-colors bg-red-600 hover:bg-red-500 text-white"
        >
          {t('shared.trial_banner.upgrade_now')}
        </Link>
      </div>
    )
  }

  const days = status.days_remaining
  const urgent = days <= 3

  if (isActivePaidApproaching) {
    return (
      <div className={`px-4 py-2 flex items-center justify-between gap-4 text-xs font-medium flex-shrink-0 ${
        urgent
          ? 'bg-red-950 border-b border-red-900 text-red-300'
          : 'bg-amber-950/60 border-b border-amber-900/40 text-amber-300'
      }`}>
        <span>
          {urgent
            ? `${status.plan_name} ${t('shared.trial_banner.expires_in')} ${days} ${t('shared.trial_banner.day')}${days !== 1 ? t('shared.trial_banner.day_plural_suffix') : ''} ${t('shared.trial_banner.renew_urgent_suffix')}`
            : `${status.plan_name} · ${days} ${t('shared.trial_banner.day')}${days !== 1 ? t('shared.trial_banner.day_plural_suffix') : ''} ${t('shared.trial_banner.days_remaining_suffix')}`
          }
        </span>
        <Link
          to="/app/subscription/current"
          className={`flex-shrink-0 px-3 py-1 rounded-lg font-semibold transition-colors ${
            urgent
              ? 'bg-red-600 hover:bg-red-500 text-white'
              : 'bg-amber-500 hover:bg-amber-400 text-black'
          }`}
        >
          {t('subscription.renew_now')}
        </Link>
      </div>
    )
  }

  return (
    <div className={`px-4 py-2 flex items-center justify-between gap-4 text-xs font-medium flex-shrink-0 ${
      urgent
        ? 'bg-red-950 border-b border-red-900 text-red-300'
        : 'bg-amber-950/60 border-b border-amber-900/40 text-amber-300'
    }`}>
      <span>
        {urgent
          ? `${t('reseller.trial_label')} ${t('shared.trial_banner.expires_in')} ${days} ${t('shared.trial_banner.day')}${days !== 1 ? t('shared.trial_banner.day_plural_suffix') : ''} ${t('shared.trial_banner.upgrade_urgent_suffix')}`
          : `${t('auth.free_trial')} · ${days} ${t('shared.trial_banner.day')}${days !== 1 ? t('shared.trial_banner.day_plural_suffix') : ''} ${t('shared.trial_banner.remaining_only')}`
        }
      </span>
      <Link
        to="/app/subscription/current"
        className={`flex-shrink-0 px-3 py-1 rounded-lg font-semibold transition-colors ${
          urgent
            ? 'bg-red-600 hover:bg-red-500 text-white'
            : 'bg-amber-500 hover:bg-amber-400 text-black'
        }`}
      >
        {t('subscription.upgrade_plan')}
      </Link>
    </div>
  )
}
