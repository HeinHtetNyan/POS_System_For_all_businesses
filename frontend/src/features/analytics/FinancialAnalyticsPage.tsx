import { useState } from 'react'
import { useQueries } from '@tanstack/react-query'
import { fmt } from '@/lib/utils'
import { StatCard, Table, Th, Td } from '@/components/ui'
import { analyticsService } from '@/services/analytics/analytics.service'
import { useLocaleStore } from '@/i18n/localeStore'
import { useAnalyticsFilters, AnalyticsFilters, ChartCard } from './analyticsHelpers'

type ProfitBy = 'product' | 'category' | 'branch'

const PAGE_SIZE = 30

const PROFIT_BY_KEYS: Record<ProfitBy, string> = {
  product:  'products.col.product',
  category: 'products.col.category',
  branch:   'analytics.field_branch',
}

export default function FinancialAnalyticsPage() {
  const t = useLocaleStore(s => s.t)
  const filters = useAnalyticsFilters()
  const { from, to, branch, apiParams } = filters
  const [profitBy, setProfitBy] = useState<ProfitBy>('product')
  const [profitPage, setProfitPage] = useState(1)

  const [summaryQ, profitQ] = useQueries({
    queries: [
      {
        queryKey: ['financial-summary', from, to, branch],
        queryFn:  () => analyticsService.getFinancialSummary(apiParams),
      },
      {
        queryKey: ['financial-profit', from, to, branch, profitBy],
        queryFn:  () => analyticsService.getProfitReport({ ...apiParams, by: profitBy }),
      },
    ],
  })

  const summary     = summaryQ.data
  const profitItems = profitQ.data?.items ?? []

  const profitTotalPages = Math.max(1, Math.ceil(profitItems.length / PAGE_SIZE))
  const paginatedProfit = profitItems.slice((profitPage - 1) * PAGE_SIZE, profitPage * PAGE_SIZE)

  return (
    <div className="p-4 sm:p-6 space-y-5">
      {/* Header + Filters */}
      <div className="flex flex-col gap-3">
        <h2 className="text-base font-semibold text-zinc-100">{t('analytics.financial_analytics_title')}</h2>
        <AnalyticsFilters {...filters} />
      </div>

      {/* Summary KPIs */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        {summaryQ.isLoading ? (
          Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="h-24 rounded-2xl bg-zinc-900 border border-zinc-800 animate-pulse" />
          ))
        ) : summary ? (
          <>
            <StatCard label={t('analytics.gross_revenue')} value={fmt(summary.gross_revenue)} accent />
            <StatCard label={t('analytics.field_net_revenue')}   value={fmt(summary.net_revenue)} />
            <StatCard label={t('analytics.cogs_full')} value={fmt(summary.cost_of_goods_sold)} />
            <StatCard label={t('analytics.field_gross_profit')}  value={fmt(summary.gross_profit)} accent />
            <StatCard
              label={t('analytics.field_margin_pct')}
              value={`${parseFloat(summary.gross_margin_pct).toFixed(1)}%`}
              accent={parseFloat(summary.gross_margin_pct) > 20}
            />
            <StatCard
              label={t('analytics.refunds')}
              value={fmt(summary.refund_amount)}
              accent={parseFloat(summary.refund_amount) > 0}
            />
          </>
        ) : null}
      </div>

      {/* Profit Report */}
      <ChartCard
        title={t('analytics.profit_report')}
        isLoading={profitQ.isLoading}
        isEmpty={profitItems.length === 0}
        action={
          <div className="flex gap-1">
            {(['product', 'category', 'branch'] as ProfitBy[]).map(b => (
              <button
                key={b}
                onClick={() => { setProfitBy(b); setProfitPage(1) }}
                className={`px-2.5 py-1 rounded-lg text-xs font-medium transition-all border ${
                  profitBy === b
                    ? 'bg-amber-500/15 border-amber-500/30 text-amber-400'
                    : 'bg-zinc-800 border-zinc-700 text-zinc-500 hover:text-zinc-200'
                }`}
              >
                {t(PROFIT_BY_KEYS[b])}
              </button>
            ))}
          </div>
        }
      >
        <Table>
          <thead>
            <tr>
              <Th>{t(PROFIT_BY_KEYS[profitBy])}</Th>
              <Th right>{t('analytics.field_revenue')}</Th>
              <Th right>{t('analytics.field_refunded')}</Th>
              <Th right>{t('analytics.cogs_full')}</Th>
              <Th right>{t('analytics.field_profit')}</Th>
              <Th right>{t('analytics.field_margin')}</Th>
            </tr>
          </thead>
          <tbody>
            {paginatedProfit.map((item, i) => {
              const margin = parseFloat(item.margin_pct)
              return (
                <tr key={item.dimension_id ?? i} className="hover:bg-zinc-800/40 transition-colors">
                  <Td>{item.dimension_name}</Td>
                  <Td right><span className="font-mono text-amber-400">{fmt(item.revenue)}</span></Td>
                  <Td right><span className="font-mono text-red-400">{fmt(item.refunded_amount)}</span></Td>
                  <Td right><span className="font-mono text-zinc-400">{fmt(item.cogs)}</span></Td>
                  <Td right><span className="font-mono text-green-400">{fmt(item.profit)}</span></Td>
                  <Td right>
                    <span className={`font-mono font-semibold ${
                      margin >= 20 ? 'text-green-400' : margin >= 10 ? 'text-amber-400' : 'text-red-400'
                    }`}>
                      {margin.toFixed(1)}%
                    </span>
                  </Td>
                </tr>
              )
            })}
          </tbody>
        </Table>
        <div className="px-4 py-2.5 border-t border-zinc-800 flex items-center justify-between gap-3">
          <p className="text-xs text-zinc-500">
            {profitItems.length === 0 ? `0 ${t('analytics.noun_items')}` : `${(profitPage - 1) * PAGE_SIZE + 1}–${Math.min(profitPage * PAGE_SIZE, profitItems.length)} ${t('analytics.of')} ${profitItems.length}`}
          </p>
          <div className="flex items-center gap-1">
            <button onClick={() => setProfitPage(p => Math.max(1, p - 1))} disabled={profitPage === 1}
              className="px-2 py-1 rounded-lg text-xs text-zinc-400 border border-zinc-700 hover:border-zinc-500 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition-colors">{t('common.prev')}</button>
            <span className="text-xs text-zinc-500 px-2">{profitPage} / {profitTotalPages}</span>
            <button onClick={() => setProfitPage(p => Math.min(profitTotalPages, p + 1))} disabled={profitPage >= profitTotalPages}
              className="px-2 py-1 rounded-lg text-xs text-zinc-400 border border-zinc-700 hover:border-zinc-500 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition-colors">{t('common.next')}</button>
          </div>
        </div>
      </ChartCard>

    </div>
  )
}
