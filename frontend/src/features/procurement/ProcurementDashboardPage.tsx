import { useNavigate } from 'react-router-dom'
import { useQueries } from '@tanstack/react-query'
import { fmt, fmtDate, timeAgo } from '@/lib/utils'
import { StatCard, Table, Th, Td, Spinner } from '@/components/ui'
import { procurementService } from '@/services/procurement/procurement.service'
import { POStatusBadge, PayableStatusBadge } from './procurementHelpers'
import { useLocaleStore } from '@/i18n/localeStore'

export default function ProcurementDashboardPage() {
  const navigate = useNavigate()
  const t = useLocaleStore(s => s.t)

  const [orderedQ, partialReceiptQ, openPayQ, partialPayQ, recentPOsQ, recentReceiptsQ, recentPayablesQ] = useQueries({
    queries: [
      { queryKey: ['purchase-orders', { status: 'APPROVED', page_size: 1 }],
        queryFn: () => procurementService.listOrders({ status: 'APPROVED', page_size: 1 }) },
      { queryKey: ['purchase-orders', { status: 'PARTIALLY_RECEIVED', page_size: 1 }],
        queryFn: () => procurementService.listOrders({ status: 'PARTIALLY_RECEIVED', page_size: 1 }) },
      { queryKey: ['supplier-payables', { status: 'OPEN', page_size: 1 }],
        queryFn: () => procurementService.listPayables({ status: 'OPEN', page_size: 1 }) },
      { queryKey: ['supplier-payables', { status: 'PARTIAL', page_size: 1 }],
        queryFn: () => procurementService.listPayables({ status: 'PARTIAL', page_size: 1 }) },
      { queryKey: ['purchase-orders', { page_size: 5 }],
        queryFn: () => procurementService.listOrders({ page_size: 5 }) },
      { queryKey: ['goods-receipts', { page_size: 5 }],
        queryFn: () => procurementService.listReceipts({ page_size: 5 }) },
      { queryKey: ['supplier-payables', { page_size: 5 }],
        queryFn: () => procurementService.listPayables({ page_size: 5 }) },
    ],
  })

  const kpisLoading = orderedQ.isLoading || partialReceiptQ.isLoading || openPayQ.isLoading || partialPayQ.isLoading

  const openPOs        = orderedQ.data?.total ?? 0
  const pendingReceipt = partialReceiptQ.data?.total ?? 0
  const openPayables   = openPayQ.data?.total ?? 0
  const partialPay     = partialPayQ.data?.total ?? 0
  const outstandingCount = openPayables + partialPay

  const recentPOs      = recentPOsQ.data?.items ?? []
  const recentReceipts = recentReceiptsQ.data?.items ?? []
  const recentPayables = recentPayablesQ.data?.items ?? []

  return (
    <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-5">
      <h2 className="text-base font-semibold text-zinc-100">{t('procurement.overview_title')}</h2>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3">
        {kpisLoading ? (
          Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="h-24 rounded-2xl bg-zinc-900 border border-zinc-800 animate-pulse" />
          ))
        ) : (
          <>
            <StatCard
              label={t('procurement.po_status_ordered')}
              value={openPOs.toLocaleString()}
              accent={openPOs > 0}
            />
            <StatCard
              label={t('procurement.po_status_partial_receipt')}
              value={pendingReceipt.toLocaleString()}
              accent={pendingReceipt > 0}
            />
            <StatCard
              label={t('procurement.stat_open_payables')}
              value={openPayables.toLocaleString()}
              accent={openPayables > 0}
            />
            <StatCard
              label={t('procurement.stat_awaiting_payment')}
              value={outstandingCount.toLocaleString()}
              accent={outstandingCount > 0}
            />
          </>
        )}
      </div>

      {/* Recent Purchase Orders */}
      <div className="bg-zinc-900 rounded-2xl border border-zinc-800 overflow-hidden">
        <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800">
          <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.recent_purchase_orders')}</h3>
          <button
            onClick={() => navigate('/app/procurement/purchase-orders')}
            className="text-xs text-amber-400 hover:text-amber-300 transition-colors"
          >
            {t('dash.view_all')}
          </button>
        </div>
        {recentPOsQ.isLoading ? (
          <div className="flex items-center justify-center h-24"><Spinner size={24} /></div>
        ) : recentPOs.length === 0 ? (
          <p className="text-zinc-600 text-sm text-center py-6">{t('procurement.no_purchase_orders_yet')}</p>
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>{t('procurement.col_po_number')}</Th>
                <Th>{t('settings.status')}</Th>
                <Th right>{t('procurement.col_total')}</Th>
                <Th>{t('procurement.col_date')}</Th>
              </tr>
            </thead>
            <tbody>
              {recentPOs.map(po => (
                <tr
                  key={po.id}
                  onClick={() => navigate(`/app/procurement/purchase-orders/${po.id}`)}
                  className="cursor-pointer hover:bg-zinc-800/60 transition-colors"
                >
                  <Td><span className="font-mono text-amber-400">{po.po_number}</span></Td>
                  <Td><POStatusBadge status={po.status} /></Td>
                  <Td right><span className="font-mono">{fmt(po.total_amount)}</span></Td>
                  <Td muted>{fmtDate(po.order_date)}</Td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </div>

      {/* Recent Receipts */}
      <div className="bg-zinc-900 rounded-2xl border border-zinc-800 overflow-hidden">
        <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800">
          <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.recent_goods_receipts')}</h3>
          <button
            onClick={() => navigate('/app/procurement/purchase-orders')}
            className="text-xs text-amber-400 hover:text-amber-300 transition-colors"
          >
            {t('dash.view_all')}
          </button>
        </div>
        {recentReceiptsQ.isLoading ? (
          <div className="flex items-center justify-center h-24"><Spinner size={24} /></div>
        ) : recentReceipts.length === 0 ? (
          <p className="text-zinc-600 text-sm text-center py-6">{t('procurement.no_receipts_yet')}</p>
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>{t('procurement.col_receipt_number')}</Th>
                <Th>{t('settings.status')}</Th>
                <Th>{t('procurement.col_date')}</Th>
                <Th>{t('procurement.col_created')}</Th>
              </tr>
            </thead>
            <tbody>
              {recentReceipts.map(r => (
                <tr
                  key={r.id}
                  onClick={() => navigate(`/app/procurement/receipts/${r.id}`)}
                  className="cursor-pointer hover:bg-zinc-800/60 transition-colors"
                >
                  <Td><span className="font-mono text-blue-400">{r.receipt_number}</span></Td>
                  <Td>
                    <span className={`inline-flex items-center text-xs px-2 py-0.5 rounded-full border font-medium ${
                      r.status === 'RECEIVED'
                        ? 'bg-green-950 text-green-400 border-green-800'
                        : 'bg-red-950 text-red-400 border-red-800'
                    }`}>
                      {r.status}
                    </span>
                  </Td>
                  <Td muted>{fmtDate(r.receipt_date)}</Td>
                  <Td muted>{timeAgo(r.created_at)}</Td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </div>

      {/* Outstanding Payables */}
      <div className="bg-zinc-900 rounded-2xl border border-zinc-800 overflow-hidden">
        <div className="flex items-center justify-between px-4 py-3 border-b border-zinc-800">
          <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.outstanding_payables')}</h3>
          <button
            onClick={() => navigate('/app/procurement/payments')}
            className="text-xs text-amber-400 hover:text-amber-300 transition-colors"
          >
            {t('dash.view_all')}
          </button>
        </div>
        {recentPayablesQ.isLoading ? (
          <div className="flex items-center justify-center h-24"><Spinner size={24} /></div>
        ) : recentPayables.length === 0 ? (
          <p className="text-zinc-600 text-sm text-center py-6">{t('procurement.no_payables_yet')}</p>
        ) : (
          <Table>
            <thead>
              <tr>
                <Th>{t('settings.status')}</Th>
                <Th right>{t('procurement.col_total')}</Th>
                <Th right>{t('status.paid')}</Th>
                <Th right>{t('procurement.col_remaining')}</Th>
              </tr>
            </thead>
            <tbody>
              {recentPayables.map(p => (
                <tr
                  key={p.id}
                  onClick={() => navigate('/app/procurement/payments')}
                  className="cursor-pointer hover:bg-zinc-800/60 transition-colors"
                >
                  <Td><PayableStatusBadge status={p.status} /></Td>
                  <Td right><span className="font-mono">{fmt(p.total_amount)}</span></Td>
                  <Td right><span className="font-mono text-green-400">{fmt(p.paid_amount)}</span></Td>
                  <Td right><span className="font-mono text-amber-400 font-semibold">{fmt(p.remaining_amount)}</span></Td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </div>
    </div>
  )
}
