import { useQuery } from '@tanstack/react-query'
import { fmt } from '@/lib/utils'
import { StatCard, Table, Th, Td } from '@/components/ui'
import { analyticsService } from '@/services/analytics/analytics.service'
import { useAnalyticsFilters, AnalyticsFilters, ChartCard } from './analyticsHelpers'
import { useLocaleStore } from '@/i18n/localeStore'

export default function StaffAnalyticsPage() {
  const t = useLocaleStore(s => s.t)
  const filters = useAnalyticsFilters()
  const { from, to, branch, apiParams } = filters

  const cashierQ = useQuery({
    queryKey: ['sales-by-cashier', from, to, branch],
    queryFn:  () => analyticsService.getSalesByCashier(apiParams),
  })

  const cashiers = cashierQ.data ?? []

  const totalOrders = cashiers.reduce((s, c) => s + c.orders, 0)
  const totalSales  = cashiers.reduce((s, c) => s + parseFloat(String(c.sales)), 0)

  return (
    <div className="p-4 sm:p-6 space-y-5">
      <div className="flex flex-col gap-3">
        <h2 className="text-base font-semibold text-zinc-100">{t('analytics.staff_performance_title')}</h2>
        <AnalyticsFilters {...filters} />
      </div>

      {/* Summary row */}
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
        <StatCard label={t('analytics.active_cashiers')} value={cashiers.length.toString()} />
        <StatCard label={t('analytics.field_total_orders')}    value={totalOrders.toLocaleString()} />
        <StatCard label={t('analytics.total_sales')}     value={fmt(totalSales)} accent />
      </div>

      {/* Cashier breakdown table */}
      <ChartCard
        title={t('analytics.cashier_sales_breakdown')}
        isLoading={cashierQ.isLoading}
        isEmpty={cashiers.length === 0}
      >
        <Table>
          <thead>
            <tr>
              <Th>#</Th>
              <Th>{t('analytics.field_cashier')}</Th>
              <Th right>{t('analytics.field_orders')}</Th>
              <Th right>{t('nav.sales')}</Th>
              <Th right>{t('analytics.refunds')}</Th>
              <Th right>{t('analytics.avg_ticket')}</Th>
            </tr>
          </thead>
          <tbody>
            {cashiers.map((c, i) => (
              <tr key={c.cashier_id} className="hover:bg-zinc-800/40 transition-colors">
                <Td muted>{i + 1}</Td>
                <Td>
                  <span className="text-sm font-medium text-zinc-100">{c.cashier_name}</span>
                </Td>
                <Td right>
                  <span className="font-mono text-zinc-200">{c.orders}</span>
                </Td>
                <Td right>
                  <span className="font-mono text-amber-400">{fmt(c.sales)}</span>
                </Td>
                <Td right>
                  <span className={`font-mono ${parseFloat(String(c.refunds)) > 0 ? 'text-red-400' : 'text-zinc-500'}`}>
                    {fmt(c.refunds)}
                  </span>
                </Td>
                <Td right>
                  <span className="font-mono text-zinc-400">{fmt(c.average_ticket)}</span>
                </Td>
              </tr>
            ))}
          </tbody>
        </Table>
      </ChartCard>
    </div>
  )
}
