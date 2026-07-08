import { NavLink, Outlet } from 'react-router-dom'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/store/auth.store'
import { useLocaleStore } from '@/i18n/localeStore'

export default function ProcurementLayout() {
  const user = useAuthStore(s => s.user)
  const t = useLocaleStore(s => s.t)
  const isInventoryStaff = user?.role === 'INVENTORY_STAFF'
  const ALL_TABS = [
    { to: '/app/procurement/dashboard',       label: t('procurement.tab_overview'),        managerOnly: false },
    { to: '/app/procurement/suppliers',       label: t('procurement.tab_suppliers'),       managerOnly: false },
    { to: '/app/procurement/purchase-orders', label: t('procurement.tab_purchase_orders'), managerOnly: false },
    { to: '/app/procurement/payments',        label: t('procurement.tab_payments'),        managerOnly: true },
  ]
  const tabs = ALL_TABS.filter(tab => !(tab.managerOnly && isInventoryStaff))

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Tab bar */}
      <div className="flex-shrink-0 border-b border-zinc-800 bg-zinc-950 px-4 overflow-x-auto">
        <nav className="flex gap-1 min-w-max">
          {tabs.map(tab => (
            <NavLink
              key={tab.to}
              to={tab.to}
              end={false}
              className={({ isActive }) => cn(
                'px-3 py-3 text-sm font-medium border-b-2 transition-colors whitespace-nowrap',
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

      {/* Page content */}
      <div className="flex-1 min-h-0 overflow-y-auto">
        <Outlet />
      </div>
    </div>
  )
}
