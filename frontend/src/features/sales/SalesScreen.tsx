import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { checkoutService, refundService } from '@/services/sales/sales.service'
import { receiptsService } from '@/services/receipts/receipts.service'
import { useTenantStore } from '@/store/tenant.store'
import { useAuthStore } from '@/store/auth.store'
import { fmt, fmtDateTime, timeAgo } from '@/lib/utils'
import { getPaymentMethodLabel } from '@/lib/paymentMethod'
import { useLocaleStore } from '@/i18n/localeStore'
import { StatCard, Table, Th, Td, Badge, Empty, Divider, Spinner } from '@/components/ui'
import { IconSales, IconSearch, IconRefund, IconPrint, IconAlert } from '@/components/icons'
import { ReceiptPrintPreviewModal } from '@/components/hardware/PrintPreviewModal'
import VoidOrderModal from './VoidOrderModal'
import type { Order, OrderItem, RefundRecord, OrderPayment } from '@/shared/types'

const VOID_ALLOWED_ROLES = new Set(['SUPER_ADMIN', 'BUSINESS_OWNER', 'MANAGER'])

type TabFilter = 'all' | 'COMPLETED' | 'REFUNDED'

const STATUS_VARIANT: Record<string, 'success' | 'warning' | 'danger'> = {
  COMPLETED:          'success',
  REFUNDED:           'warning',
  PARTIALLY_REFUNDED: 'warning',
}

const PAYMENT_VARIANT: Record<string, 'success' | 'warning' | 'danger'> = {
  PAID:    'success',
  PARTIAL: 'warning',
  PENDING: 'danger',
}

function orderStatusLabel(status: string, t: (key: string) => string): string {
  const map: Record<string, string> = {
    COMPLETED:          t('status.completed'),
    PENDING:            t('status.pending'),
    CANCELLED:          t('status.cancelled'),
    REFUNDED:           t('status.refunded'),
    PARTIALLY_REFUNDED: t('sales.status_partially_refunded'),
    VOIDED:             t('sales.status_voided'),
    DRAFT:              t('sales.status_draft'),
  }
  return map[status] ?? (status.charAt(0) + status.slice(1).toLowerCase().replace('_', ' '))
}

export default function SalesScreen() {
  const t = useLocaleStore(s => s.t)
  const { selectedBranch, availableBranches } = useTenantStore()

  const [search, setSearch]               = useState('')
  const [tab, setTab]                     = useState<TabFilter>('all')
  const [selectedOrder, setSelectedOrder] = useState<Order | null>(null)
  const [selectedRefund, setSelectedRefund] = useState<RefundRecord | null>(null)

  const branchId   = selectedBranch?.id ?? ''
  const branchName = availableBranches.find(b => b.id === branchId)?.name ?? selectedBranch?.name ?? null

  // Orders query (used for All + Completed tabs)
  const ordersQuery = useQuery({
    queryKey: ['orders', branchId, tab],
    queryFn: () => checkoutService.listOrders({
      branch_id:    branchId || undefined,
      order_status: tab === 'COMPLETED' ? 'COMPLETED' : undefined,
      page_size:    200,
    }),
    enabled: !!branchId && tab !== 'REFUNDED',
  })

  // Refunds query (used for Refunded tab)
  const refundsQuery = useQuery({
    queryKey: ['refunds', branchId],
    queryFn: () => refundService.list({ branch_id: branchId || undefined, page_size: 200 }),
    enabled: tab === 'REFUNDED' && !!branchId,
  })

  const orders  = ordersQuery.data?.items ?? []
  const refunds = refundsQuery.data?.items ?? []

  const filteredOrders = orders.filter(o => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return o.id.toLowerCase().includes(q) || o.order_number.toLowerCase().includes(q)
  })

  const filteredRefunds = refunds.filter(r => {
    if (!search.trim()) return true
    const q = search.toLowerCase()
    return (
      r.refund_number.toLowerCase().includes(q) ||
      r.order_id.toLowerCase().includes(q) ||
      r.reason.toLowerCase().includes(q)
    )
  })

  // COMPLETED/PARTIALLY_REFUNDED/REFUNDED are the only statuses that represent
  // a real sale (mirrors the backend's _order_filters) — DRAFT/PENDING/CANCELLED/
  // VOIDED orders never generated revenue and must not appear in these sums.
  // A partially or fully refunded order still counts here — excluding it entirely
  // (as before) silently dropped its remaining net revenue to zero.
  const revenueOrders = orders.filter(o =>
    ['COMPLETED', 'PARTIALLY_REFUNDED', 'REFUNDED'].includes(o.order_status)
  )
  const totalRefunded = revenueOrders.reduce((s, o) => s + parseFloat(o.refunded_amount ?? '0'), 0)
  const totalRevenue = revenueOrders.reduce(
    (s, o) => s + parseFloat(o.total_amount) - parseFloat(o.refunded_amount ?? '0'), 0
  )
  const avgOrder = revenueOrders.length > 0 ? totalRevenue / revenueOrders.length : 0

  if (!branchId) {
    return (
      <div className="flex h-full items-center justify-center flex-col gap-3 p-6">
        <IconSales width="48" height="48" className="text-zinc-700" />
        <p className="text-zinc-400 font-medium">{t('sales.no_branch_selected')}</p>
        <p className="text-zinc-600 text-sm text-center max-w-xs">
          {t('sales.no_branch_selected_sub')}
        </p>
      </div>
    )
  }

  const isLoading = tab === 'REFUNDED' ? refundsQuery.isLoading : ordersQuery.isLoading

  return (
    <div className="flex flex-col lg:flex-row h-full overflow-y-auto lg:overflow-hidden">
      {/* Main */}
      <div className="flex-1 flex flex-col min-w-0 lg:overflow-hidden">
        {/* Page header */}
        <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-3 px-4 sm:px-6 py-3 sm:py-4 border-b border-zinc-800 flex-shrink-0">
          <div className="flex items-center gap-3 flex-1 min-w-0">
            <h2 className="text-base font-semibold text-zinc-100 flex-shrink-0">{t('qa.sales_history')}</h2>
            {branchName && (
              <span className="flex items-center gap-1.5 text-xs text-zinc-400 bg-zinc-800 border border-zinc-700 rounded-lg px-2.5 py-1 truncate">
                <span className="w-1.5 h-1.5 rounded-full bg-green-500 flex-shrink-0" />
                {branchName}
              </span>
            )}
          </div>
          <div className="relative">
            <IconSearch width="14" height="14" className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500 pointer-events-none" />
            <input
              type="text"
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder={tab === 'REFUNDED' ? t('sales.search_refunds_placeholder') : t('sales.search_orders_placeholder')}
              className="bg-zinc-900 border border-zinc-800 rounded-xl text-zinc-100 placeholder-zinc-600 text-sm
                focus:outline-none focus:border-amber-500 focus:ring-1 focus:ring-amber-500/20 transition-all
                py-2 pl-8 pr-4 w-full sm:w-56"
            />
          </div>
        </div>

        <div className="p-4 sm:p-6 flex flex-col gap-4 sm:gap-5 lg:overflow-auto lg:flex-1 lg:min-h-0">
          {/* Stats (orders only) */}
          {tab !== 'REFUNDED' && (
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 sm:gap-4">
              <StatCard label={t('sales.stat.total_orders')}    value={orders.length} />
              <StatCard label={t('sales.stat.revenue')}         value={fmt(totalRevenue)} accent />
              <StatCard label={t('status.refunded')}            value={fmt(totalRefunded)} />
              <StatCard label={t('sales.stat.avg_order_value')} value={fmt(avgOrder)} />
            </div>
          )}
          {tab === 'REFUNDED' && (
            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 sm:gap-4">
              <StatCard label={t('sales.stat.total_refunds')} value={refunds.length} />
              <StatCard label={t('sales.stat.refunded_total')} value={fmt(refunds.reduce((s, r) => s + parseFloat(r.amount), 0))} accent />
              <StatCard label={t('sales.stat.avg_refund')} value={fmt(refunds.length > 0 ? refunds.reduce((s, r) => s + parseFloat(r.amount), 0) / refunds.length : 0)} />
            </div>
          )}

          {/* Tab filter */}
          <div className="flex gap-1 bg-zinc-900 border border-zinc-800 rounded-xl p-1 w-fit">
            {(['all', 'COMPLETED', 'REFUNDED'] as const).map(tabValue => (
              <button
                key={tabValue}
                onClick={() => { setTab(tabValue); setSelectedOrder(null); setSelectedRefund(null) }}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${
                  tab === tabValue ? 'bg-amber-500 text-black' : 'text-zinc-400 hover:text-zinc-200'
                }`}
              >
                {tabValue === 'all' ? t('sales.tab_all') : tabValue === 'REFUNDED' ? t('status.refunded') : t('status.completed')}
              </button>
            ))}
          </div>

          {/* Orders table */}
          {tab !== 'REFUNDED' && (
            <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-x-auto flex flex-col flex-1 min-h-0">
              {isLoading ? (
                <div className="flex items-center justify-center h-40"><Spinner size={32} /></div>
              ) : (
                <Table>
                  <thead>
                    <tr>
                      <Th>{t('sales.col.order_number')}</Th>
                      <Th>{t('sales.col.date')}</Th>
                      <Th right>{t('sales.col.total')}</Th>
                      <Th>{t('products.col.status')}</Th>
                      <Th>{t('sales.col.payment')}</Th>
                      <Th>{t('sales.col.by')}</Th>
                      <Th>{t('sales.col.customer')}</Th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredOrders.length === 0 ? (
                      <tr>
                        <td colSpan={7}>
                          <Empty icon={<IconSales width="40" height="40" />} title={t('sales.no_orders_found')} subtitle={t('products.empty_sub')} />
                        </td>
                      </tr>
                    ) : filteredOrders.map(order => {
                      const isActive = selectedOrder?.id === order.id
                      const paymentLabel = order.payment_status
                        ? t(`status.${order.payment_status.toLowerCase()}`)
                        : null
                      return (
                        <tr
                          key={order.id}
                          onClick={() => { setSelectedOrder(isActive ? null : order); setSelectedRefund(null) }}
                          className={`cursor-pointer transition-colors ${isActive ? 'bg-zinc-800/80' : 'hover:bg-zinc-800/40'}`}
                        >
                          <Td mono>
                            <span className="text-amber-400 text-xs">{order.order_number}</span>
                          </Td>
                          <Td muted className="whitespace-nowrap text-xs">{fmtDateTime(order.created_at)}</Td>
                          <Td right mono>
                            <span className="text-amber-400">{fmt(parseFloat(order.total_amount), order.currency)}</span>
                          </Td>
                          <Td>
                            <Badge variant={STATUS_VARIANT[order.order_status] ?? 'warning'} dot>
                              {orderStatusLabel(order.order_status, t)}
                            </Badge>
                          </Td>
                          <Td>
                            <div className="flex flex-col gap-0.5">
                              {order.payments && order.payments.length > 0 ? (
                                <span className="text-xs font-medium text-green-400">
                                  {t('sales.paid_via')} {order.payments.map(p => {
                                    const label = getPaymentMethodLabel(p.payment_method)
                                    return p.notes ? `${label} (${p.notes})` : label
                                  }).join(' + ')}
                                </span>
                              ) : paymentLabel ? (
                                <Badge variant={PAYMENT_VARIANT[order.payment_status] ?? 'warning'} dot>
                                  {paymentLabel}
                                </Badge>
                              ) : null}
                            </div>
                          </Td>
                          <Td>
                            <span className="text-xs text-zinc-300">{order.cashier_name ?? '—'}</span>
                          </Td>
                          <Td>
                            {order.customer_name
                              ? <span className="text-xs text-amber-400 font-medium">{order.customer_name}</span>
                              : <span className="text-xs text-zinc-600">—</span>
                            }
                          </Td>
                        </tr>
                      )
                    })}
                  </tbody>
                </Table>
              )}
              <div className="px-4 py-2.5 border-t border-zinc-800 flex-shrink-0">
                <p className="text-xs text-zinc-500">{filteredOrders.length} {t('sales.of')} {orders.length} {t('sales.orders_word')}</p>
              </div>
            </div>
          )}

          {/* Refunds table */}
          {tab === 'REFUNDED' && (
            <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-x-auto flex flex-col flex-1 min-h-0">
              {isLoading ? (
                <div className="flex items-center justify-center h-40"><Spinner size={32} /></div>
              ) : (
                <Table>
                  <thead>
                    <tr>
                      <Th>{t('sales.col.refund_number')}</Th>
                      <Th>{t('sales.col.date')}</Th>
                      <Th>{t('sales.col.type')}</Th>
                      <Th right>{t('sales.col.amount')}</Th>
                      <Th>{t('sales.col.by')}</Th>
                      <Th>{t('sales.col.reason')}</Th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredRefunds.length === 0 ? (
                      <tr>
                        <td colSpan={6}>
                          <Empty icon={<IconRefund width="40" height="40" />} title={t('sales.no_refunds_found')} subtitle={t('sales.no_refunds_sub')} />
                        </td>
                      </tr>
                    ) : filteredRefunds.map(refund => {
                      const isActive = selectedRefund?.id === refund.id
                      // Split long refund number into 2 lines: REF-BRANCH / ORDER-TS
                      const refNumParts = refund.refund_number.split('-')
                      const refLine1 = refNumParts.length >= 2 ? `${refNumParts[0]}-${refNumParts[1]}` : refund.refund_number
                      const refLine2 = refNumParts.length >= 3 ? refNumParts.slice(2).join('-') : null
                      return (
                        <tr
                          key={refund.id}
                          onClick={() => { setSelectedRefund(isActive ? null : refund); setSelectedOrder(null) }}
                          className={`cursor-pointer transition-colors ${isActive ? 'bg-zinc-800/80' : 'hover:bg-zinc-800/40'}`}
                        >
                          <Td mono>
                            <span className="text-amber-400 text-xs block leading-tight">{refLine1}</span>
                            {refLine2 && <span className="text-zinc-500 text-[10px] block leading-tight font-mono">{refLine2}</span>}
                          </Td>
                          <Td muted className="whitespace-nowrap text-xs">{fmtDateTime(refund.processed_at)}</Td>
                          <Td>
                            {refund.refund_type === 'REPLACEMENT'
                              ? <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-violet-950 border border-violet-800 text-violet-400">{t('sales.replace_short')}</span>
                              : <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-blue-950 border border-blue-800 text-blue-400">{t('sales.cash_short')}</span>
                            }
                          </Td>
                          <Td right mono>
                            <span className={refund.refund_type === 'REPLACEMENT' ? 'text-violet-400' : 'text-red-400'}>
                              {refund.refund_type !== 'REPLACEMENT' && '−'}{fmt(parseFloat(refund.amount))}
                            </span>
                          </Td>
                          <Td>
                            <span className="text-xs text-zinc-300">{refund.processed_by_name ?? '—'}</span>
                          </Td>
                          <Td>
                            <span className="text-xs text-zinc-400 truncate max-w-[120px] block">{refund.reason}</span>
                          </Td>
                        </tr>
                      )
                    })}
                  </tbody>
                </Table>
              )}
              <div className="px-4 py-2.5 border-t border-zinc-800 flex-shrink-0">
                <p className="text-xs text-zinc-500">{filteredRefunds.length} {t('sales.of')} {refunds.length} {t('sales.refunds_word')}</p>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Order detail panel */}
      {selectedOrder && (
        <>
          <div className="fixed inset-0 bg-black/60 z-40 lg:hidden" onClick={() => setSelectedOrder(null)} />
          <OrderDetailPanel order={selectedOrder} onClose={() => setSelectedOrder(null)} />
        </>
      )}

      {/* Refund detail panel */}
      {selectedRefund && (
        <>
          <div className="fixed inset-0 bg-black/60 z-40 lg:hidden" onClick={() => setSelectedRefund(null)} />
          <RefundDetailPanel refund={selectedRefund} onClose={() => setSelectedRefund(null)} />
        </>
      )}
    </div>
  )
}

// Order Detail Panel

function OrderDetailPanel({ order, onClose }: { order: Order; onClose: () => void }) {
  const t = useLocaleStore(s => s.t)
  const [showReprint, setShowReprint] = useState(false)
  const [showVoid, setShowVoid] = useState(false)
  const role = useAuthStore(s => s.user?.role)

  const { data: detail, isLoading } = useQuery({
    queryKey: ['order-detail', order.id],
    queryFn: () => checkoutService.getOrder(order.id),
    staleTime: 30_000,
  })

  const { data: receipt } = useQuery({
    queryKey: ['receipt', 'order', order.id],
    queryFn: () => receiptsService.getByOrderId(order.id),
    staleTime: 60_000,
  })

  const items: OrderItem[] = (detail?.items ?? []) as OrderItem[]

  return (
    <div className="fixed inset-0 z-50 lg:relative lg:inset-auto lg:z-auto w-full lg:w-96 flex-shrink-0 lg:border-l border-zinc-800 bg-zinc-950 flex flex-col overflow-y-auto">
      <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800 flex-shrink-0">
        <span className="text-sm font-semibold text-zinc-100">{t('sales.order_receipt')}</span>
        <button onClick={onClose} className="flex items-center justify-center w-8 h-8 rounded-full bg-zinc-800 hover:bg-zinc-700 text-zinc-300 hover:text-zinc-100 transition-colors text-xl leading-none">
          ×
        </button>
      </div>

      <div className="px-4 py-4 border-b border-zinc-800 flex-shrink-0 space-y-1">
        <div className="flex items-center justify-between">
          <span className="font-mono text-sm font-bold text-amber-400">{order.order_number}</span>
          <Badge variant={STATUS_VARIANT[order.order_status] ?? 'warning'} dot>
            {orderStatusLabel(order.order_status, t)}
          </Badge>
        </div>
        <p className="text-xs text-zinc-400">{fmtDateTime(order.created_at)}</p>
        <p className="text-xs text-zinc-600">{timeAgo(order.created_at)}</p>
        {(order.branch_name || detail?.branch_name) && (
          <p className="text-xs text-zinc-500">{t('sales.branch')} <span className="text-blue-400 font-medium">{order.branch_name ?? detail?.branch_name}</span></p>
        )}
        {order.cashier_name && (
          <p className="text-xs text-zinc-500">{t('sales.col.by')} <span className="text-zinc-300">{order.cashier_name}</span></p>
        )}
        {order.customer_name && (
          <p className="text-xs text-zinc-500">{t('sales.col.customer')} <span className="text-amber-400 font-medium">{order.customer_name}</span></p>
        )}
      </div>

      <div className="px-4 py-3 border-b border-zinc-800 flex-shrink-0">
        <p className="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider mb-2">{t('sales.items')}</p>
        {isLoading ? (
          <div className="flex justify-center py-4"><Spinner size={20} /></div>
        ) : items.length === 0 ? (
          <p className="text-xs text-zinc-600 py-2">{t('sales.no_items')}</p>
        ) : (
          <div className="flex flex-col gap-2">
            {items.map((item, idx) => (
              <div key={item.id ?? idx} className="flex gap-2">
                <span className="flex-shrink-0 w-6 h-6 rounded-md bg-zinc-800 border border-zinc-700 text-zinc-300 text-xs font-bold flex items-center justify-center">
                  {parseFloat(item.quantity).toFixed(0)}
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-medium text-zinc-100 truncate">
                    {item.product_name}
                    {item.variant_name && <span className="ml-1 text-zinc-500">({item.variant_name})</span>}
                  </p>
                  {item.sku && <p className="text-[10px] text-zinc-600 font-mono">{item.sku}</p>}
                </div>
                <div className="flex-shrink-0 text-right">
                  <p className="text-xs font-mono text-zinc-200">{fmt(parseFloat(item.total), order.currency)}</p>
                  <p className="text-[10px] text-zinc-600 font-mono">
                    {fmt(parseFloat(item.unit_price), order.currency)} × {parseFloat(item.quantity).toFixed(0)}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="px-4 py-3 border-b border-zinc-800 flex-shrink-0">
        <div className="flex flex-col gap-1.5">
          <div className="flex justify-between text-xs text-zinc-500">
            <span>{t('sales.subtotal')}</span>
            <span className="font-mono">{fmt(parseFloat(order.subtotal), order.currency)}</span>
          </div>
          {parseFloat(order.discount_amount) > 0 && (
            <div className="flex justify-between text-xs text-amber-500">
              <span>{t('products.detail.discount')}</span>
              <span className="font-mono">−{fmt(parseFloat(order.discount_amount), order.currency)}</span>
            </div>
          )}
          <div className="flex justify-between text-xs text-zinc-500">
            <span>{t('sales.tax')}</span>
            <span className="font-mono">{fmt(parseFloat(order.tax_amount), order.currency)}</span>
          </div>
          {detail?.refunded_amount && parseFloat(detail.refunded_amount) > 0 && (
            <div className="flex justify-between text-xs text-red-400">
              <span>{t('status.refunded')}</span>
              <span className="font-mono">−{fmt(parseFloat(detail.refunded_amount), order.currency)}</span>
            </div>
          )}
          <Divider />
          <div className="flex justify-between text-sm font-bold text-zinc-100">
            <span>{t('sales.col.total')}</span>
            <span className="font-mono text-amber-400">{fmt(parseFloat(order.total_amount), order.currency)}</span>
          </div>
        </div>
      </div>

      {/* Payment methods breakdown */}
      <div className="px-4 py-3 border-b border-zinc-800 flex-shrink-0">
        <p className="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider mb-2">{t('sales.col.payment')}</p>
        {detail?.payments && detail.payments.length > 0 ? (
          <div className="flex flex-col gap-1.5">
            {(detail.payments as OrderPayment[]).map((p, i) => (
              <div key={p.id ?? i} className="flex items-center justify-between">
                <div className="flex items-center gap-1.5">
                  <span className="w-1.5 h-1.5 rounded-full bg-amber-400 flex-shrink-0" />
                  <span className="text-xs text-zinc-300">{getPaymentMethodLabel(p.payment_method)}</span>
                  {p.notes && (
                    <span className="text-[10px] text-zinc-500">· {p.notes}</span>
                  )}
                  {p.reference_number && (
                    <span className="text-[10px] text-zinc-600 font-mono">#{p.reference_number}</span>
                  )}
                </div>
                <span className="text-xs font-mono font-semibold text-amber-400">{fmt(parseFloat(p.amount), order.currency)}</span>
              </div>
            ))}
          </div>
        ) : (
          detail?.payment_status && (
            <div className="flex justify-between text-xs">
              <span className="text-zinc-500">{t('products.col.status')}</span>
              <span className="text-zinc-300 capitalize">{t(`status.${detail.payment_status.toLowerCase()}`)}</span>
            </div>
          )
        )}
      </div>

      {order.notes && (
        <div className="px-4 py-3 border-b border-zinc-800 flex-shrink-0">
          <p className="text-xs text-zinc-500 mb-1">{t('sales.notes')}</p>
          <p className="text-xs text-zinc-300">{order.notes}</p>
        </div>
      )}

      <div className="flex-1" />

      {/* Reprint / Void buttons */}
      <div className="px-4 py-3 border-t border-zinc-800 flex-shrink-0 flex flex-col gap-2">
        <button
          onClick={() => receipt && setShowReprint(true)}
          disabled={!receipt}
          className="w-full h-9 flex items-center justify-center gap-2 rounded-xl bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-zinc-200 text-sm font-semibold transition-all disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <IconPrint width="14" height="14" />
          {t('sales.reprint_receipt')}
        </button>
        {role && VOID_ALLOWED_ROLES.has(role) && (detail?.order_status ?? order.order_status) === 'COMPLETED' && (
          <button
            onClick={() => setShowVoid(true)}
            className="w-full h-9 flex items-center justify-center gap-2 rounded-xl bg-red-950 hover:bg-red-900 border border-red-800 text-red-400 text-sm font-semibold transition-all"
          >
            <IconAlert width="14" height="14" />
            {t('sales.void_order')}
          </button>
        )}
      </div>

      {receipt && showReprint && (
        <ReceiptPrintPreviewModal
          receipt={receipt}
          onClose={() => setShowReprint(false)}
          autoTrigger={false}
        />
      )}

      {showVoid && (
        <VoidOrderModal
          order={detail ?? order}
          onClose={() => setShowVoid(false)}
          onSuccess={() => { setShowVoid(false); onClose() }}
        />
      )}
    </div>
  )
}

// Refund Detail Panel

function RefundDetailPanel({ refund, onClose }: { refund: RefundRecord; onClose: () => void }) {
  const t = useLocaleStore(s => s.t)
  return (
    <div className="fixed inset-0 z-50 lg:relative lg:inset-auto lg:z-auto w-full lg:w-96 flex-shrink-0 lg:border-l border-zinc-800 bg-zinc-950 flex flex-col overflow-y-auto">
      <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800 flex-shrink-0">
        <span className="text-sm font-semibold text-zinc-100">{t('sales.refund_detail')}</span>
        <button onClick={onClose} className="flex items-center justify-center w-8 h-8 rounded-full bg-zinc-800 hover:bg-zinc-700 text-zinc-300 hover:text-zinc-100 transition-colors text-xl leading-none">
          ×
        </button>
      </div>

      {/* Meta */}
      <div className="px-4 py-4 border-b border-zinc-800 flex-shrink-0 space-y-1">
        <div className="flex items-center justify-between">
          <span className="font-mono text-sm font-bold text-amber-400">{refund.refund_number}</span>
          {refund.refund_type === 'REPLACEMENT'
            ? <span className="text-[10px] px-2 py-0.5 rounded-full bg-violet-950 border border-violet-800 text-violet-400 font-semibold">{t('sales.replacement')}</span>
            : <span className="text-[10px] px-2 py-0.5 rounded-full bg-blue-950 border border-blue-800 text-blue-400 font-semibold">{t('sales.cash_refund')}</span>
          }
        </div>
        <div className="flex justify-between text-xs text-zinc-500 mt-1">
          <span>{t('sales.order_id')}</span>
          <span className="font-mono text-zinc-400">{refund.order_id.slice(0, 8)}…</span>
        </div>
        <div className="flex justify-between text-xs text-zinc-500">
          <span>{t('sales.refund_date')}</span>
          <span className="text-zinc-300">{fmtDateTime(refund.processed_at)}</span>
        </div>
        {refund.processed_by_name && (
          <div className="flex justify-between text-xs text-zinc-500">
            <span>{t('sales.processed_by')}</span>
            <span className="text-zinc-300">{refund.processed_by_name}</span>
          </div>
        )}
        <div className="flex justify-between text-xs text-zinc-500">
          <span>{timeAgo(refund.processed_at)}</span>
        </div>
      </div>

      {/* Refunded items */}
      <div className="px-4 py-3 border-b border-zinc-800 flex-shrink-0">
        <p className="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider mb-2">{t('sales.refunded_items')}</p>
        {refund.items.length === 0 ? (
          <p className="text-xs text-zinc-600 py-1">{t('sales.no_item_details')}</p>
        ) : (
          <div className="flex flex-col gap-2">
            {refund.items.map((item, idx) => (
              <div key={item.id ?? idx} className="flex items-center gap-2">
                <span className="flex-shrink-0 w-6 h-6 rounded-md bg-zinc-800 border border-zinc-700 text-zinc-300 text-xs font-bold flex items-center justify-center">
                  {parseFloat(item.quantity).toFixed(0)}
                </span>
                <div className="flex-1 min-w-0">
                  <p className="text-xs font-medium text-zinc-200 truncate">
                    {item.product_name ?? '—'}
                    {item.variant_name && <span className="ml-1 text-zinc-500 text-[10px]">({item.variant_name})</span>}
                  </p>
                </div>
                <span className="text-xs font-mono text-red-400">−{fmt(parseFloat(item.amount))}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Total */}
      <div className="px-4 py-3 border-b border-zinc-800 flex-shrink-0">
        <div className="flex justify-between text-sm font-bold">
          <span className="text-zinc-400">
            {refund.refund_type === 'REPLACEMENT' ? t('sales.item_value') : t('sales.stat.refunded_total')}
          </span>
          <span className={`font-mono ${refund.refund_type === 'REPLACEMENT' ? 'text-violet-400' : 'text-red-400'}`}>
            {refund.refund_type === 'REPLACEMENT' ? '' : '−'}{fmt(parseFloat(refund.amount))}
          </span>
        </div>
      </div>

      {/* Reason + Notes */}
      <div className="px-4 py-3 flex-shrink-0">
        <p className="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider mb-1">{t('sales.col.reason')}</p>
        <p className="text-xs text-zinc-300">{refund.reason}</p>
        {refund.notes && (
          <>
            <p className="text-[10px] font-semibold text-zinc-500 uppercase tracking-wider mt-3 mb-1">{t('sales.notes')}</p>
            <p className="text-xs text-zinc-400">{refund.notes}</p>
          </>
        )}
      </div>

      <div className="flex-1" />
    </div>
  )
}
