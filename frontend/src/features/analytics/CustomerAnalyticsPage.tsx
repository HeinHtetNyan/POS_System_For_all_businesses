import { useState } from 'react'
import { useQueries } from '@tanstack/react-query'
import { fmt } from '@/lib/utils'
import { StatCard, Table, Th, Td, Badge } from '@/components/ui'
import { analyticsService } from '@/services/analytics/analytics.service'
import { customersService } from '@/services/customers/customers.service'
import { useLocaleStore } from '@/i18n/localeStore'
import { useAnalyticsFilters, AnalyticsFilters, ChartCard } from './analyticsHelpers'

const PAGE_SIZE = 30

export default function CustomerAnalyticsPage() {
  const t = useLocaleStore(s => s.t)
  const filters = useAnalyticsFilters()
  const [custPage, setCustPage] = useState(1)

  const [dashboardQ, totalQ, activeQ, topCustomersQ] = useQueries({
    queries: [
      {
        queryKey: ['analytics-dashboard', filters.branch],
        queryFn:  () => analyticsService.getDashboard(
          filters.branch ? { branch_id: filters.branch } : undefined,
        ),
      },
      {
        queryKey: ['customers-count-total'],
        queryFn:  () => customersService.list({ page_size: 1 }),
      },
      {
        queryKey: ['customers-count-active'],
        queryFn:  () => customersService.list({ is_active: true, page_size: 1 }),
      },
      {
        queryKey: ['customers-top-balance'],
        queryFn:  () => customersService.list({ page_size: 200 }),
      },
    ],
  })

  const dashboard   = dashboardQ.data
  const totalCount  = totalQ.data?.total ?? 0
  const activeCount = activeQ.data?.total ?? 0

  const topCustomers = (topCustomersQ.data?.items ?? [])
    .filter(c => parseFloat(c.balance) > 0)
    .sort((a, b) => parseFloat(b.balance) - parseFloat(a.balance))

  const custTotalPages = Math.max(1, Math.ceil(topCustomers.length / PAGE_SIZE))
  const paginatedCustomers = topCustomers.slice((custPage - 1) * PAGE_SIZE, custPage * PAGE_SIZE)

  const kpisLoading = dashboardQ.isLoading || totalQ.isLoading || activeQ.isLoading

  return (
    <div className="p-4 sm:p-6 space-y-5">
      {/* Header */}
      <div className="flex flex-col gap-3">
        <h2 className="text-base font-semibold text-zinc-100">{t('analytics.customer_analytics_title')}</h2>
        <AnalyticsFilters {...filters} showDateRange={false} />
      </div>

      {/* KPIs */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {kpisLoading ? (
          Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="h-24 rounded-2xl bg-zinc-900 border border-zinc-800 animate-pulse" />
          ))
        ) : (
          <>
            <StatCard label={t('analytics.total_customers')}  value={totalCount.toLocaleString()} />
            <StatCard label={t('analytics.active_customers')} value={activeCount.toLocaleString()} accent />
            <StatCard label={t('analytics.new_this_month')}   value={(dashboard?.new_customers_month ?? 0).toLocaleString()} accent />
            <StatCard label={t('status.inactive')}             value={(totalCount - activeCount).toLocaleString()} />
          </>
        )}
      </div>

      {/* Top Customers by Balance */}
      <ChartCard
        title={t('analytics.top_customers_outstanding')}
        isLoading={topCustomersQ.isLoading}
        isEmpty={topCustomers.length === 0}
        emptyMessage={t('analytics.no_customers_outstanding')}
      >
        <Table>
          <thead>
            <tr>
              <Th>#</Th>
              <Th>{t('analytics.customer')}</Th>
              <Th>{t('settings.phone')}</Th>
              <Th>{t('products.col.status')}</Th>
              <Th right>{t('analytics.outstanding')}</Th>
            </tr>
          </thead>
          <tbody>
            {paginatedCustomers.map((c, i) => (
              <tr key={c.id} className="hover:bg-zinc-800/40 transition-colors">
                <Td muted>{(custPage - 1) * PAGE_SIZE + i + 1}</Td>
                <Td>{c.name}</Td>
                <Td muted mono>{c.phone}</Td>
                <Td>
                  <Badge variant={c.is_active ? 'success' : 'default'} size="xs">
                    {c.is_active ? t('status.active') : t('status.inactive')}
                  </Badge>
                </Td>
                <Td right>
                  <span className="font-mono font-semibold text-amber-400">{fmt(c.balance)}</span>
                </Td>
              </tr>
            ))}
          </tbody>
        </Table>
        <div className="px-4 py-2.5 border-t border-zinc-800 flex items-center justify-between gap-3">
          <p className="text-xs text-zinc-500">
            {topCustomers.length === 0 ? `0 ${t('analytics.noun_customers')}` : `${(custPage - 1) * PAGE_SIZE + 1}–${Math.min(custPage * PAGE_SIZE, topCustomers.length)} ${t('analytics.of')} ${topCustomers.length}`}
          </p>
          <div className="flex items-center gap-1">
            <button onClick={() => setCustPage(p => Math.max(1, p - 1))} disabled={custPage === 1}
              className="px-2 py-1 rounded-lg text-xs text-zinc-400 border border-zinc-700 hover:border-zinc-500 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition-colors">{t('common.prev')}</button>
            <span className="text-xs text-zinc-500 px-2">{custPage} / {custTotalPages}</span>
            <button onClick={() => setCustPage(p => Math.min(custTotalPages, p + 1))} disabled={custPage >= custTotalPages}
              className="px-2 py-1 rounded-lg text-xs text-zinc-400 border border-zinc-700 hover:border-zinc-500 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition-colors">{t('common.next')}</button>
          </div>
        </div>
      </ChartCard>

      <div className="text-xs text-zinc-600 bg-zinc-900 border border-zinc-800 rounded-2xl px-4 py-3">
        {t('analytics.customer_trends_note')}
      </div>
    </div>
  )
}
