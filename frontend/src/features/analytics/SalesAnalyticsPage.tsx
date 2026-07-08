import { useState } from 'react'
import { useQueries } from '@tanstack/react-query'
import { fmt } from '@/lib/utils'
import { StatCard, Table, Th, Td } from '@/components/ui'
import { analyticsService } from '@/services/analytics/analytics.service'
import { useAnalyticsFilters, AnalyticsFilters, ChartCard } from './analyticsHelpers'
import { getPaymentMethodLabel } from '@/lib/paymentMethod'
import type { PaymentMethodStat } from '@/shared/types'
import { useLocaleStore } from '@/i18n/localeStore'

const PAGE_SIZE = 30

function PaginationBar({ page, totalPages, total, setPage, noun }: {
  page: number; totalPages: number; total: number; setPage: React.Dispatch<React.SetStateAction<number>>; noun: string
}) {
  const t = useLocaleStore(s => s.t)
  return (
    <div className="flex items-center justify-between gap-3">
      <p className="text-xs text-zinc-500">
        {total === 0 ? `0 ${noun}` : `${(page - 1) * PAGE_SIZE + 1}–${Math.min(page * PAGE_SIZE, total)} ${t('analytics.of')} ${total}`}
      </p>
      <div className="flex items-center gap-1">
        <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
          className="px-2 py-1 rounded-lg text-xs text-zinc-400 border border-zinc-700 hover:border-zinc-500 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition-colors">{t('common.prev')}</button>
        <span className="text-xs text-zinc-500 px-2">{page} / {totalPages}</span>
        <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page >= totalPages}
          className="px-2 py-1 rounded-lg text-xs text-zinc-400 border border-zinc-700 hover:border-zinc-500 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition-colors">{t('common.next')}</button>
      </div>
    </div>
  )
}

export default function SalesAnalyticsPage() {
  const t = useLocaleStore(s => s.t)
  const filters = useAnalyticsFilters()
  const { from, to, branch, apiParams } = filters
  const [productsPage, setProductsPage] = useState(1)
  const [cashiersPage, setCashiersPage] = useState(1)

  const [summaryQ, topProductsQ, byCashierQ, paymentMethodsQ] = useQueries({
    queries: [
      {
        queryKey: ['sales-summary', from, to, branch],
        queryFn:  () => analyticsService.getSalesSummary(apiParams),
      },
      {
        queryKey: ['sales-top-products', from, to, branch],
        queryFn:  () => analyticsService.getTopProducts({ ...apiParams, limit: 100 }),
      },
      {
        queryKey: ['sales-by-cashier', from, to, branch],
        queryFn:  () => analyticsService.getSalesByCashier(apiParams),
      },
      {
        queryKey: ['sales-payment-methods', from, to, branch],
        queryFn:  () => analyticsService.getPaymentMethods(apiParams),
      },
    ],
  })

  const summary        = summaryQ.data
  const topProducts    = topProductsQ.data ?? []
  const cashiers       = byCashierQ.data ?? []
  const paymentMethods = paymentMethodsQ.data ?? []

  const productsTotalPages = Math.max(1, Math.ceil(topProducts.length / PAGE_SIZE))
  const cashiersTotalPages = Math.max(1, Math.ceil(cashiers.length / PAGE_SIZE))
  const paginatedProducts = topProducts.slice((productsPage - 1) * PAGE_SIZE, productsPage * PAGE_SIZE)
  const paginatedCashiers = cashiers.slice((cashiersPage - 1) * PAGE_SIZE, cashiersPage * PAGE_SIZE)

  return (
    <div className="p-4 sm:p-6 space-y-5">
      {/* Header + Filters */}
      <div className="flex flex-col gap-3">
        <h2 className="text-base font-semibold text-zinc-100">{t('analytics.sales_analytics_title')}</h2>
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
            <StatCard label={t('analytics.field_orders')}      value={summary.order_count.toLocaleString()} />
            <StatCard label={t('analytics.field_gross_sales')} value={fmt(summary.gross_sales)} accent />
            <StatCard label={t('analytics.field_net_sales')}   value={fmt(summary.net_sales)} />
            <StatCard label={t('analytics.avg_order')}   value={fmt(summary.average_order_value)} />
            <StatCard label={t('qa.customers')}   value={summary.unique_customers.toLocaleString()} />
            <StatCard
              label={t('analytics.refunds')}
              value={fmt(summary.refund_amount)}
              accent={parseFloat(summary.refund_amount) > 0}
            />
          </>
        ) : null}
      </div>

      {/* Payment Method Breakdown */}
      <div>
        <h3 className="text-sm font-semibold text-zinc-300 mb-3">{t('analytics.revenue_by_payment_method')}</h3>
        {paymentMethodsQ.isLoading ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="h-24 rounded-2xl bg-zinc-900 border border-zinc-800 animate-pulse" />
            ))}
          </div>
        ) : paymentMethods.length === 0 ? (
          <p className="text-sm text-zinc-600 py-2">{t('analytics.no_payment_data')}</p>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
            {(paymentMethods as PaymentMethodStat[]).map(pm => (
              <div
                key={pm.payment_method}
                className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 flex flex-col gap-1.5"
              >
                <p className="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider truncate">
                  {getPaymentMethodLabel(pm.payment_method)}
                </p>
                <p className="font-mono text-lg font-bold text-amber-400">{fmt(parseFloat(pm.amount))}</p>
                <div className="flex items-center justify-between text-[10px] text-zinc-500">
                  <span>{pm.transaction_count} {t('analytics.txn')}{pm.transaction_count !== 1 ? t('analytics.txn_plural_suffix') : ''}</span>
                  <span className="font-semibold text-zinc-400">{parseFloat(pm.percentage).toFixed(1)}%</span>
                </div>
                {/* Mini progress bar */}
                <div className="w-full h-1 bg-zinc-800 rounded-full overflow-hidden mt-0.5">
                  <div
                    className="h-full bg-amber-500 rounded-full"
                    style={{ width: `${Math.min(100, parseFloat(pm.percentage))}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Top Products */}
      <div className="space-y-2">
        <ChartCard
          title={t('analytics.top_products')}
          isLoading={topProductsQ.isLoading}
          isEmpty={topProducts.length === 0}
        >
          <Table>
            <thead>
              <tr>
                <Th>#</Th>
                <Th>{t('products.col.product')}</Th>
                <Th>{t('products.col.sku')}</Th>
                <Th right>{t('analytics.field_qty_sold')}</Th>
                <Th right>{t('analytics.field_revenue')}</Th>
                <Th right>{t('analytics.field_profit_est')}</Th>
              </tr>
            </thead>
            <tbody>
              {paginatedProducts.map((p, i) => (
                <tr key={p.product_id} className="hover:bg-zinc-800/40 transition-colors">
                  <Td muted>{(productsPage - 1) * PAGE_SIZE + i + 1}</Td>
                  <Td>{p.product_name}</Td>
                  <Td muted mono>{p.sku ?? '—'}</Td>
                  <Td right><span className="font-mono">{p.quantity_sold}</span></Td>
                  <Td right><span className="font-mono text-amber-400">{fmt(p.revenue)}</span></Td>
                  <Td right><span className="font-mono text-green-400">{fmt(p.profit_estimate)}</span></Td>
                </tr>
              ))}
            </tbody>
          </Table>
        </ChartCard>
        {!topProductsQ.isLoading && topProducts.length > 0 && (
          <PaginationBar page={productsPage} totalPages={productsTotalPages} total={topProducts.length} setPage={setProductsPage} noun={t('analytics.noun_products')} />
        )}
      </div>

      {/* By Cashier */}
      <div className="space-y-2">
        <ChartCard
          title={t('analytics.sales_by_cashier')}
          isLoading={byCashierQ.isLoading}
          isEmpty={cashiers.length === 0}
        >
          <Table>
            <thead>
              <tr>
                <Th>{t('analytics.field_cashier')}</Th>
                <Th right>{t('analytics.field_orders')}</Th>
                <Th right>{t('nav.sales')}</Th>
                <Th right>{t('analytics.refunds')}</Th>
                <Th right>{t('analytics.avg_ticket')}</Th>
              </tr>
            </thead>
            <tbody>
              {paginatedCashiers.map(c => (
                <tr key={c.cashier_id} className="hover:bg-zinc-800/40 transition-colors">
                  <Td>{c.cashier_name}</Td>
                  <Td right><span className="font-mono">{c.orders}</span></Td>
                  <Td right><span className="font-mono text-amber-400">{fmt(c.sales)}</span></Td>
                  <Td right><span className="font-mono text-red-400">{fmt(c.refunds)}</span></Td>
                  <Td right><span className="font-mono text-zinc-400">{fmt(c.average_ticket)}</span></Td>
                </tr>
              ))}
            </tbody>
          </Table>
        </ChartCard>
        {!byCashierQ.isLoading && cashiers.length > 0 && (
          <PaginationBar page={cashiersPage} totalPages={cashiersTotalPages} total={cashiers.length} setPage={setCashiersPage} noun={t('analytics.noun_cashiers')} />
        )}
      </div>
    </div>
  )
}
