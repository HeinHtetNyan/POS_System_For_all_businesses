import { useQueries } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { fmt, timeAgo } from '@/lib/utils'
import { useAuthStore } from '@/store/auth.store'
import { useSessionStore } from '@/store/session.store'
import { useTenantStore } from '@/store/tenant.store'
import { useLocaleStore } from '@/i18n/localeStore'
import { analyticsService } from '@/services/analytics/analytics.service'
import { KpiCard } from './widgets/KpiCard'
import { DashboardSection } from './widgets/DashboardSection'
import { QuickActionGrid, type QuickAction } from './widgets/QuickActionGrid'
import { RecentlyViewed } from './widgets/RecentlyViewed'

const CASHIER_ACTIONS: QuickAction[] = [
  { labelKey: 'qa.open_pos',      descKey: 'qa.open_pos_desc',      icon: '💰', path: '/app/pos' },
  { labelKey: 'qa.customers',     descKey: 'qa.customers_desc',     icon: '👥', path: '/app/customers' },
  { labelKey: 'qa.sales_history', descKey: 'qa.sales_history_desc', icon: '🧾', path: '/app/sales' },
]

const INVENTORY_ACTIONS: QuickAction[] = [
  { labelKey: 'qa.inventory',     descKey: 'qa.inventory_desc', icon: '🏭', path: '/app/inventory' },
  { labelKey: 'qa.products',      descKey: 'qa.catalog_desc',   icon: '📦', path: '/app/products' },
]

export default function StaffDashboardPage() {
  const navigate = useNavigate()
  const user = useAuthStore(s => s.user)
  const { activeSession } = useSessionStore()
  const { availableBranches } = useTenantStore()
  const t = useLocaleStore(s => s.t)
  const role = user?.role ?? 'CASHIER'
  const isInventoryStaff = role === 'INVENTORY_STAFF'
  // This page has no branch switcher, so it must never depend on the shared
  // selectedBranch store (that's for switcher pages like BusinessDashboardPage
  // and can go stale — e.g. after a branch reassignment — causing a 403 here).
  // Omit branch_id entirely and let the backend resolve scope from the
  // authenticated user's own primary_branch_id, which is always correct.
  const myBranchName = availableBranches.find(b => b.id === user?.primary_branch_id)?.name

  const [kpiQuery, lowStockQuery] = useQueries({
    queries: [
      {
        queryKey: ['analytics', 'dashboard', 'own'],
        queryFn: () => analyticsService.getDashboard(),
      },
      {
        queryKey: ['analytics', 'low-stock', 'own'],
        queryFn: () => analyticsService.getLowStock(),
        enabled: isInventoryStaff,
      },
    ],
  })

  const kpi = kpiQuery.data
  const lowStock = lowStockQuery.data ?? []

  return (
    <div className="flex flex-col h-full overflow-y-auto">
      {/* Header */}
      <div className="flex-shrink-0 px-4 py-3.5 border-b border-zinc-800">
        <h2 className="text-base font-semibold text-zinc-100">
          {t(`dash.greeting_${getGreeting()}`)}, {user?.first_name ?? t('dash.there_fallback')}
        </h2>
        <p className="text-xs text-zinc-500 mt-0.5">
          {isInventoryStaff ? t('dash.inventory_staff_role') : t('dash.cashier_role')}{myBranchName ? ` · ${myBranchName}` : ''}
        </p>
      </div>

      <div className="p-4 sm:p-6 space-y-6 max-w-5xl w-full mx-auto">

        {/* Active Session Banner */}
        {activeSession && (
          <div className="bg-green-950/30 border border-green-800/40 rounded-2xl px-4 py-3.5 flex items-center justify-between gap-3 flex-wrap">
            <div>
              <p className="text-sm font-medium text-green-400">{t('dash.session_open_title')}</p>
              <p className="text-xs text-green-300/70 mt-0.5">
                {t('auth.session_close.started_prefix')} {timeAgo(activeSession.opened_at)} · {t('dash.opening_colon')} {fmt(activeSession.opening_balance)}
              </p>
            </div>
            <button
              onClick={() => navigate('/app/pos')}
              className="bg-green-600 hover:bg-green-500 text-white text-sm font-medium px-4 py-2 rounded-xl transition-colors flex-shrink-0"
            >
              {t('dash.continue_selling')}
            </button>
          </div>
        )}

        {/* KPI Row */}
        <DashboardSection title={t('dash.today_at_glance')}>
          {isInventoryStaff ? (
            <div className="grid grid-cols-2 gap-3">
              <KpiCard
                label={t('dash.orders_today')}
                value={kpi?.orders_today ?? '—'}
                sub={t('dash.transactions_word')}
                icon="🧾"
                isLoading={kpiQuery.isLoading}
                isError={kpiQuery.isError}
              />
              <KpiCard
                label={t('status.low_stock')}
                value={lowStock.length}
                sub={lowStock.length > 0 ? t('dash.need_restock') : t('dash.all_stocked')}
                icon="⚠️"
                isLoading={lowStockQuery.isLoading}
                isError={lowStockQuery.isError}
              />
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-3">
              <KpiCard
                label={t('analytics.sales_today')}
                value={fmt(kpi?.sales_today)}
                icon="💰"
                accent
                isLoading={kpiQuery.isLoading}
                isError={kpiQuery.isError}
              />
              <KpiCard
                label={t('dash.this_month')}
                value={fmt(kpi?.sales_this_month)}
                sub={`${kpi?.orders_this_month ?? 0} ${t('sales.orders_word')}`}
                icon="📅"
                isLoading={kpiQuery.isLoading}
                isError={kpiQuery.isError}
              />
            </div>
          )}
        </DashboardSection>

        {/* Quick Actions */}
        <DashboardSection title={t('dash.quick_actions')}>
          <QuickActionGrid actions={isInventoryStaff ? INVENTORY_ACTIONS : CASHIER_ACTIONS} />
        </DashboardSection>

        {/* Recently Viewed */}
        <RecentlyViewed />

        {/* Low Stock (Inventory Staff only) */}
        {isInventoryStaff && lowStock.length > 0 && (
          <DashboardSection
            title={`${t('dash.low_stock_alerts_prefix')} (${lowStock.length})`}
            action={{ label: t('dash.manage'), onClick: () => navigate('/app/inventory') }}
          >
            <div className="bg-zinc-900 border border-zinc-800 rounded-2xl divide-y divide-zinc-800">
              {lowStock.slice(0, 10).map(item => (
                <div key={item.product_id} className="flex items-center gap-3 px-4 py-3 flex-wrap">
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-zinc-200 truncate">{item.product_name}</p>
                    <p className="text-xs text-zinc-500 mt-0.5">
                      {item.sku ? `${t('dash.sku_prefix')} ${item.sku} · ` : ''}{item.branch_name}
                    </p>
                  </div>
                  <div className="flex items-center gap-3 flex-shrink-0">
                    <div className="text-right">
                      <p className="text-sm font-semibold text-red-400 tabular-nums">{item.quantity_on_hand}</p>
                      <p className="text-[10px] text-zinc-600">{t('dash.in_stock')}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-sm font-medium text-zinc-400 tabular-nums">{item.reorder_point}</p>
                      <p className="text-[10px] text-zinc-600">{t('dash.reorder_at')}</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </DashboardSection>
        )}

      </div>
    </div>
  )
}

function getGreeting(): string {
  const h = new Date().getHours()
  if (h < 12) return 'morning'
  if (h < 17) return 'afternoon'
  return 'evening'
}
