import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { cn } from '@/lib/utils'
import { useLocaleStore } from '@/i18n/localeStore'

const TABS = [
  { to: '/app/analytics/dashboard', labelKey: 'nav.dashboard' },
  { to: '/app/analytics/sales',     labelKey: 'nav.sales'     },
  { to: '/app/analytics/inventory', labelKey: 'nav.inventory' },
  { to: '/app/analytics/customers', labelKey: 'qa.customers'  },
  { to: '/app/analytics/financial', labelKey: 'analytics.tab_financial' },
  { to: '/app/analytics/staff',     labelKey: 'settings.tab.staff' },
  { to: '/app/analytics/exports',   labelKey: 'analytics.tab_exports'  },
]

export default function AnalyticsLayout() {
  const t = useLocaleStore(s => s.t)
  const location = useLocation()

  return (
    <div className="h-full flex flex-col overflow-hidden">
      {/* Tab bar */}
      <div className="flex-shrink-0 border-b border-zinc-800 bg-zinc-950">
        <nav className="flex overflow-x-auto px-4 lg:px-6 gap-0">
          {TABS.map(tab => (
            <NavLink
              key={tab.to}
              to={{ pathname: tab.to, search: location.search }}
              className={({ isActive }) => cn(
                'px-4 py-3 text-sm font-medium whitespace-nowrap border-b-2 transition-all duration-150',
                isActive
                  ? 'text-amber-400 border-amber-500'
                  : 'text-zinc-500 border-transparent hover:text-zinc-200',
              )}
            >
              {t(tab.labelKey)}
            </NavLink>
          ))}
        </nav>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto">
        <Outlet />
      </div>
    </div>
  )
}
