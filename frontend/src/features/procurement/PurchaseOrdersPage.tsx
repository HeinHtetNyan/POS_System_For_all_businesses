import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { cn, fmt, fmtDate } from '@/lib/utils'
import { Btn, Table, Th, Td, Empty, Spinner, SectionHeader } from '@/components/ui'
import { IconPlus, IconChevRight } from '@/components/icons'
import { procurementService } from '@/services/procurement/procurement.service'
import { POStatusBadge } from './procurementHelpers'
import { useLocaleStore } from '@/i18n/localeStore'

const PAGE_SIZE = 30

export default function PurchaseOrdersPage() {
  const navigate = useNavigate()
  const t = useLocaleStore(s => s.t)
  const STATUS_FILTERS = [
    { label: t('procurement.filter_all'),                        value: undefined            },
    { label: t('procurement.po_status_draft'),                   value: 'DRAFT'              },
    { label: t('procurement.po_status_pending_approval'),        value: 'SUBMITTED'          },
    { label: t('procurement.po_status_ordered'),                 value: 'APPROVED'           },
    { label: t('procurement.po_status_partial_receipt'),         value: 'PARTIALLY_RECEIVED' },
    { label: t('procurement.po_status_received'),                value: 'RECEIVED'           },
    { label: t('status.cancelled'),                               value: 'CANCELLED'          },
  ]
  const [status, setStatus] = useState<string | undefined>(undefined)
  const [selMonth, setSelMonth] = useState(() => new Date().getMonth() + 1)
  const [selYear,  setSelYear]  = useState(() => new Date().getFullYear())
  const [page, setPage] = useState(1)

  const { data, isLoading } = useQuery({
    queryKey: ['purchase-orders', { status }],
    queryFn: () => procurementService.listOrders({ status, page: 1, page_size: 500 }),
    placeholderData: prev => prev,
  })

  // Fetch all receipts for client-side join (stale 30s since it's background data)
  const { data: allReceiptsData } = useQuery({
    queryKey: ['goods-receipts-all'],
    queryFn: () => procurementService.listReceipts({ page: 1, page_size: 500 }),
    staleTime: 30_000,
  })

  const orders      = data?.items ?? []
  const allReceipts = allReceiptsData?.items ?? []

  // Map poId → receipt[]
  const receiptsByPoId = new Map<string, typeof allReceipts>()
  allReceipts.forEach(r => {
    const arr = receiptsByPoId.get(r.purchase_order_id) ?? []
    arr.push(r)
    receiptsByPoId.set(r.purchase_order_id, arr)
  })

  const monthStr = `${selYear}-${String(selMonth).padStart(2, '0')}`
  const filteredOrders = orders.filter(po => (po.created_at ?? '').slice(0, 7) === monthStr)

  // One row per receipt; POs with no receipts get one row with receipt = null
  const allRows = filteredOrders.flatMap(po => {
    const poReceipts = receiptsByPoId.get(po.id) ?? []
    if (poReceipts.length === 0) return [{ po, receipt: null as typeof allReceipts[number] | null }]
    return poReceipts.map(r => ({ po, receipt: r as typeof allReceipts[number] | null }))
  })

  const totalPages = Math.max(1, Math.ceil(allRows.length / PAGE_SIZE))
  const rows = allRows.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <SectionHeader
        title={t('procurement.purchase_orders_title')}
        subtitle={`${allRows.length} ${t('procurement.order')}${allRows.length !== 1 ? 's' : ''}`}
        action={
          <Btn size="sm" onClick={() => navigate('/app/procurement/purchase-orders/new')}>
            <IconPlus width="14" height="14" /> {t('procurement.new_po')}
          </Btn>
        }
      />

      <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-4">
        {/* Month / Year selectors */}
        <div className="flex flex-wrap items-center gap-2">
          <select
            value={selMonth}
            onChange={e => { setSelMonth(Number(e.target.value)); setPage(1) }}
            className="bg-zinc-900 border border-zinc-700 rounded-xl text-zinc-200 text-sm px-3 py-1.5 focus:outline-none focus:border-amber-500"
          >
            {[
              t('procurement.month_january'), t('procurement.month_february'), t('procurement.month_march'),
              t('procurement.month_april'), t('procurement.month_may'), t('procurement.month_june'),
              t('procurement.month_july'), t('procurement.month_august'), t('procurement.month_september'),
              t('procurement.month_october'), t('procurement.month_november'), t('procurement.month_december'),
            ].map((m, i) => (
              <option key={i + 1} value={i + 1}>{m}</option>
            ))}
          </select>
          <select
            value={selYear}
            onChange={e => { setSelYear(Number(e.target.value)); setPage(1) }}
            className="bg-zinc-900 border border-zinc-700 rounded-xl text-zinc-200 text-sm px-3 py-1.5 focus:outline-none focus:border-amber-500"
          >
            {Array.from({ length: 80 }, (_, i) => 2020 + i).map(y => (
              <option key={y} value={y}>{y}</option>
            ))}
          </select>
        </div>
        <div className="flex gap-1 flex-wrap">
          {STATUS_FILTERS.map(f => (
            <button
              key={f.label}
              onClick={() => { setStatus(f.value); setPage(1) }}
              className={cn(
                'px-3 py-2 rounded-xl text-xs font-medium transition-colors border',
                status === f.value
                  ? 'bg-amber-500/15 border-amber-500/30 text-amber-400'
                  : 'bg-zinc-900 border-zinc-700 text-zinc-400 hover:text-zinc-200',
              )}
            >
              {f.label}
            </button>
          ))}
        </div>

        <div className="bg-zinc-900 rounded-2xl border border-zinc-800 overflow-hidden">
          {isLoading ? (
            <div className="flex items-center justify-center h-40"><Spinner size={28} /></div>
          ) : rows.length === 0 ? (
            <Empty
              icon={<span className="text-4xl">📋</span>}
              title={t('procurement.no_purchase_orders_found')}
              subtitle={t('procurement.create_first_po')}
              action={
                <Btn size="sm" onClick={() => navigate('/app/procurement/purchase-orders/new')}>
                  <IconPlus width="14" height="14" /> {t('procurement.new_po')}
                </Btn>
              }
            />
          ) : (
            <Table>
              <thead>
                <tr>
                  <Th>{t('procurement.col_po_number')}</Th>
                  <Th>{t('procurement.supplier')}</Th>
                  <Th>{t('procurement.col_receipt_number')}</Th>
                  <Th>{t('settings.status')}</Th>
                  <Th right>{t('procurement.col_total')}</Th>
                  <Th>{t('procurement.order_date')}</Th>
                  <Th>{t('procurement.expected')}</Th>
                  <Th>{t('procurement.receive_date')}</Th>
                  <Th />
                </tr>
              </thead>
              <tbody>
                {rows.map((row, i) => (
                  <tr
                    key={`${row.po.id}-${row.receipt?.id ?? 'none'}-${i}`}
                    onClick={() => navigate(`/app/procurement/purchase-orders/${row.po.id}`)}
                    className="cursor-pointer hover:bg-zinc-800/60 transition-colors"
                  >
                    <Td>
                      <span className="font-mono font-semibold text-amber-400">{row.po.po_number}</span>
                    </Td>
                    <Td>
                      <span className="text-sm text-zinc-200">{row.po.supplier_name ?? '—'}</span>
                    </Td>
                    <Td>
                      {row.receipt ? (
                        <button
                          className="font-mono font-semibold text-blue-400 hover:text-blue-300 transition-colors"
                          onClick={e => {
                            e.stopPropagation()
                            navigate(`/app/procurement/receipts/${row.receipt!.id}`)
                          }}
                        >
                          {row.receipt.receipt_number}
                        </button>
                      ) : (
                        <span className="text-zinc-600">—</span>
                      )}
                    </Td>
                    <Td><POStatusBadge status={row.po.status} /></Td>
                    <Td right><span className="font-mono">{fmt(row.po.total_amount)}</span></Td>
                    <Td muted>{fmtDate(row.po.order_date)}</Td>
                    <Td muted>{row.po.expected_date ? fmtDate(row.po.expected_date) : '—'}</Td>
                    <Td muted>{row.receipt?.receipt_date ? fmtDate(row.receipt.receipt_date) : '—'}</Td>
                    <Td>
                      <IconChevRight width="14" height="14" className="text-zinc-600" />
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </div>

        <div className="flex items-center justify-between gap-3">
          <p className="text-xs text-zinc-500">
            {allRows.length === 0 ? t('procurement.zero_orders') : `${(page - 1) * PAGE_SIZE + 1}–${Math.min(page * PAGE_SIZE, allRows.length)} ${t('procurement.of_word')} ${allRows.length}`}
          </p>
          <div className="flex items-center gap-1">
            <button
              onClick={() => setPage(p => Math.max(1, p - 1))}
              disabled={page === 1}
              className="px-2 py-1 rounded-lg text-xs text-zinc-400 border border-zinc-700 hover:border-zinc-500 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >{t('common.prev')}</button>
            <span className="text-xs text-zinc-500 px-2">{page} / {totalPages}</span>
            <button
              onClick={() => setPage(p => Math.min(totalPages, p + 1))}
              disabled={page >= totalPages}
              className="px-2 py-1 rounded-lg text-xs text-zinc-400 border border-zinc-700 hover:border-zinc-500 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
            >{t('common.next')}</button>
          </div>
        </div>
      </div>
    </div>
  )
}
