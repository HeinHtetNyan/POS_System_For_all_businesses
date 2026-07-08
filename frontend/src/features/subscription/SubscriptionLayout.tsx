import { NavLink, Outlet } from 'react-router-dom'
import { cn } from '@/shared/utils'
import { useLocaleStore } from '@/i18n/localeStore'

export default function SubscriptionLayout() {
  const t = useLocaleStore(s => s.t)
  const TABS = [
    { to: '/app/subscription/current', label: t('subscription.tab_current_plan') },
    { to: '/app/subscription/plans',   label: t('subscription.tab_plans')        },
    { to: '/app/subscription/billing', label: t('subscription.tab_billing_history') },
  ]
  return (
    <div className="flex flex-col h-full overflow-hidden">
      <div className="flex-shrink-0 px-4 pt-4 pb-0 border-b border-zinc-800">
        <h1 className="text-lg font-semibold text-zinc-100 mb-3">{t('nav.subscription')}</h1>
        <nav className="flex gap-1 overflow-x-auto">
          {TABS.map(tab => (
            <NavLink
              key={tab.to}
              to={tab.to}
              className={({ isActive }) => cn(
                'px-3 py-2 text-sm font-medium border-b-2 whitespace-nowrap transition-colors',
                isActive
                  ? 'border-amber-500 text-amber-400'
                  : 'border-transparent text-zinc-500 hover:text-zinc-200',
              )}
            >
              {tab.label}
            </NavLink>
          ))}
        </nav>
      </div>
      <div className="flex-1 min-h-0 overflow-y-auto">
        <Outlet />
      </div>
    </div>
  )
}
