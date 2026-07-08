import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { fmt, fmtDate, fmtDateTime, extractApiMsg } from '@/lib/utils'
import { Btn, Table, Th, Td, Spinner, SectionHeader, Badge } from '@/components/ui'
import { procurementService } from '@/services/procurement/procurement.service'
import { POStatusBadge, PayableStatusBadge, inputCls } from './procurementHelpers'
import { useAuthStore } from '@/store/auth.store'
import { useLocaleStore } from '@/i18n/localeStore'
import type { PurchaseOrderItem } from '@/shared/types'

const MANAGER_ROLES = ['MANAGER', 'BUSINESS_OWNER', 'RESELLER', 'SUPER_ADMIN']


function ReceiveGoodsModal({
  poId, branchId, items, onClose,
}: {
  poId: string
  branchId: string
  items: PurchaseOrderItem[]
  onClose: () => void
}) {
  const qc = useQueryClient()
  const t = useLocaleStore(s => s.t)
  const [receiveDate, setReceiveDate] = useState(new Date().toISOString().split('T')[0])
  const [notes, setNotes] = useState('')
  // Default to what's still outstanding, not the full ordered quantity — a
  // partially-received PO would otherwise pre-fill (and allow submitting)
  // more than what's actually left to receive.
  const remaining = (item: PurchaseOrderItem) =>
    Math.max(0, parseFloat(item.ordered_quantity) - parseFloat(item.received_quantity)).toString()
  const [quantities, setQuantities] = useState<Record<string, string>>(
    Object.fromEntries(items.map(i => [i.id, remaining(i)]))
  )
  const [unitCosts, setUnitCosts] = useState<Record<string, string>>(
    Object.fromEntries(items.map(i => [i.id, i.unit_cost]))
  )

  const mutation = useMutation({
    mutationFn: () => procurementService.createReceipt({
      purchase_order_id: poId,
      branch_id:         branchId,
      receipt_date:      new Date(receiveDate).toISOString(),
      notes:             notes || undefined,
      items:             items
        .filter(i => parseFloat(quantities[i.id] ?? '0') > 0)
        .map(i => ({
          purchase_order_item_id: i.id,
          received_quantity:      quantities[i.id],
          unit_cost:              unitCosts[i.id] ?? i.unit_cost,
        })),
    }),
    onSuccess: (receipt) => {
      toast.success(`${t('procurement.receipt_created_prefix')} ${receipt.receipt_number} ${t('procurement.receipt_created_suffix')}`)
      qc.invalidateQueries({ queryKey: ['purchase-order', poId] })
      qc.invalidateQueries({ queryKey: ['purchase-orders'] })
      qc.invalidateQueries({ queryKey: ['goods-receipts'] })
      // PurchaseOrdersPage joins receipt numbers/dates onto the PO table
      // via a separately-keyed query — a plain 'goods-receipts' invalidation
      // doesn't match it.
      qc.invalidateQueries({ queryKey: ['goods-receipts-all'] })
      qc.invalidateQueries({ queryKey: ['inventory'] })
      qc.invalidateQueries({ queryKey: ['products'] })
      // Receiving can adjust the supplier payable via cost variance.
      qc.invalidateQueries({ queryKey: ['supplier-payables'] })
      qc.invalidateQueries({ queryKey: ['supplier-balance'] })
      onClose()
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('procurement.failed_create_receipt')),
  })

  const hasItems = items.some(i => parseFloat(quantities[i.id] ?? '0') > 0)
  // The HTML max attribute alone doesn't stop submission — this button isn't
  // a native form-submit, so enforce the same limit in JS.
  const overReceiving = items.some(i => parseFloat(quantities[i.id] ?? '0') > parseFloat(remaining(i)))

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="bg-zinc-900 border border-zinc-700 rounded-2xl w-full max-w-lg shadow-2xl">
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800">
          <h2 className="text-base font-semibold text-zinc-100">{t('procurement.receive_goods')}</h2>
          <button onClick={onClose} className="text-zinc-500 hover:text-zinc-200 w-8 h-8 flex items-center justify-center rounded-lg hover:bg-zinc-800 transition-colors">
            ✕
          </button>
        </div>

        <div className="p-5 space-y-4 max-h-[60vh] overflow-y-auto">
          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-zinc-500 uppercase tracking-wider">{t('procurement.receipt_date')}</label>
              <input
                type="date"
                value={receiveDate}
                onChange={e => setReceiveDate(e.target.value)}
                className={inputCls(false)}
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label className="text-xs text-zinc-500 uppercase tracking-wider">{t('procurement.notes')}</label>
              <input
                value={notes}
                onChange={e => setNotes(e.target.value)}
                placeholder={t('procurement.optional_notes_placeholder')}
                className={inputCls(false)}
              />
            </div>
          </div>

          <div className="space-y-2">
            <div className="grid grid-cols-[1fr_80px_110px_90px] gap-2 px-1">
              <span className="text-xs text-zinc-500 uppercase">{t('procurement.item')}</span>
              <span className="text-xs text-zinc-500 uppercase text-right">{t('procurement.po_status_ordered')}</span>
              <span className="text-xs text-zinc-500 uppercase text-right">{t('procurement.unit_cost')}</span>
              <span className="text-xs text-zinc-500 uppercase text-right">{t('procurement.receiving')}</span>
            </div>
            {items.map(item => (
              <div key={item.id} className="grid grid-cols-[1fr_80px_110px_90px] gap-2 items-center bg-zinc-800/40 rounded-xl p-2">
                <div className="min-w-0">
                  {item.product_name
                    ? <p className="text-xs text-zinc-200 truncate">{item.product_name}</p>
                    : <p className="text-xs text-zinc-400 font-mono truncate">{item.product_id.slice(0, 8)}…</p>
                  }
                </div>
                <div className="text-right">
                  <span className="text-sm font-mono text-zinc-400">{item.ordered_quantity}</span>
                  {parseFloat(item.received_quantity) > 0 && (
                    <p className="text-[10px] text-zinc-600">{item.received_quantity} {t('procurement.received_lower')}</p>
                  )}
                </div>
                <input
                  type="number"
                  min="0"
                  step="any"
                  value={unitCosts[item.id] ?? ''}
                  onChange={e => setUnitCosts(prev => ({ ...prev, [item.id]: e.target.value }))}
                  className={`${inputCls(false)} text-right`}
                />
                <input
                  type="number"
                  min="0"
                  max={remaining(item)}
                  step="any"
                  value={quantities[item.id] ?? ''}
                  onChange={e => setQuantities(prev => ({ ...prev, [item.id]: e.target.value }))}
                  className={`${inputCls(false)} text-right`}
                />
              </div>
            ))}
          </div>
        </div>

        <div className="flex gap-3 px-5 pb-5 pt-3 border-t border-zinc-800">
          <Btn variant="secondary" onClick={onClose}>{t('common.cancel')}</Btn>
          <Btn
            onClick={() => mutation.mutate()}
            disabled={mutation.isPending || !hasItems || overReceiving}
            fullWidth
          >
            {mutation.isPending ? <Spinner size={16} /> : t('procurement.confirm_receipt')}
          </Btn>
        </div>
      </div>
    </div>
  )
}


function CancelModal({ poId, onClose }: { poId: string; onClose: () => void }) {
  const qc = useQueryClient()
  const navigate = useNavigate()
  const t = useLocaleStore(s => s.t)
  const [reason, setReason] = useState('')

  const mutation = useMutation({
    mutationFn: () => procurementService.cancelOrder(poId, reason),
    onSuccess: () => {
      toast.success(t('procurement.po_cancelled'))
      qc.invalidateQueries({ queryKey: ['purchase-order', poId] })
      qc.invalidateQueries({ queryKey: ['purchase-orders'] })
      onClose()
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('procurement.failed_cancel')),
  })

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="bg-zinc-900 border border-zinc-700 rounded-2xl w-full max-w-sm shadow-2xl">
        <div className="p-5 space-y-4">
          <h2 className="text-base font-semibold text-zinc-100">{t('procurement.cancel_purchase_order')}</h2>
          <div className="flex flex-col gap-1.5">
            <label className="text-xs text-zinc-500 uppercase tracking-wider">{t('procurement.reason_required')}</label>
            <textarea
              value={reason}
              onChange={e => setReason(e.target.value)}
              placeholder={t('procurement.reason_for_cancellation_placeholder')}
              rows={3}
              className={`${inputCls(false)} resize-none`}
            />
          </div>
          <div className="flex gap-3">
            <Btn variant="secondary" onClick={onClose}>{t('procurement.back')}</Btn>
            <Btn
              variant="danger"
              onClick={() => mutation.mutate()}
              disabled={mutation.isPending || !reason.trim()}
              fullWidth
            >
              {mutation.isPending ? <Spinner size={16} /> : t('procurement.cancel_order')}
            </Btn>
          </div>
        </div>
      </div>
    </div>
  )
}


export default function PurchaseOrderDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const user = useAuthStore(s => s.user)
  const t = useLocaleStore(s => s.t)
  const isManager = !!user && MANAGER_ROLES.includes(user.role)
  const [showReceive, setShowReceive] = useState(false)
  const [showCancel, setShowCancel] = useState(false)

  const { data: po, isLoading } = useQuery({
    queryKey: ['purchase-order', id],
    queryFn: () => procurementService.getOrder(id!),
    enabled: !!id,
  })

  const { data: receiptsData } = useQuery({
    queryKey: ['goods-receipts', { purchase_order_id: id }],
    queryFn: () => procurementService.listReceipts({ purchase_order_id: id!, page_size: 100 }),
    enabled: !!id,
  })
  const receipts = receiptsData?.items ?? []

  const invalidatePO = () => {
    qc.invalidateQueries({ queryKey: ['purchase-order', id] })
    qc.invalidateQueries({ queryKey: ['purchase-orders'] })
    qc.invalidateQueries({ queryKey: ['goods-receipts', { purchase_order_id: id }] })
  }

  const submitMutation = useMutation({
    mutationFn: () => procurementService.submitOrder(id!),
    onSuccess: () => { toast.success(t('procurement.submitted_for_approval')); invalidatePO() },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('procurement.failed_submit')),
  })

  const approveMutation = useMutation({
    mutationFn: () => procurementService.approveOrder(id!),
    onSuccess: () => { toast.success(t('procurement.po_approved')); invalidatePO() },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('procurement.failed_approve')),
  })

  if (isLoading) return <div className="flex items-center justify-center h-40"><Spinner size={32} /></div>
  if (!po) return (
    <div className="p-6 text-center text-zinc-500">
      {t('procurement.po_not_found')}{' '}
      <button onClick={() => navigate('/app/procurement/purchase-orders')} className="text-amber-400 hover:underline">{t('procurement.back')}</button>
    </div>
  )

  const canSubmit  = po.status === 'DRAFT'
  const canApprove = po.status === 'SUBMITTED' && isManager
  const canReceive = po.status === 'APPROVED' || po.status === 'PARTIALLY_RECEIVED'
  const canCancel  = ['DRAFT', 'SUBMITTED', 'APPROVED'].includes(po.status) && isManager

  return (
    <>
      <div className="flex flex-col h-full overflow-hidden">
        <SectionHeader
          title={po.po_number}
          subtitle={`${t('procurement.purchase_order')} · ${fmtDate(po.order_date)}`}
          action={
            <div className="flex gap-2 flex-wrap justify-end">
              {canSubmit && (
                <Btn size="sm" onClick={() => submitMutation.mutate()} disabled={submitMutation.isPending}>
                  {submitMutation.isPending ? <Spinner size={16} /> : t('procurement.submit_for_approval')}
                </Btn>
              )}
              {canApprove && (
                <Btn size="sm" onClick={() => approveMutation.mutate()} disabled={approveMutation.isPending}>
                  {approveMutation.isPending ? <Spinner size={16} /> : t('procurement.approve')}
                </Btn>
              )}
              {canReceive && (
                <Btn size="sm" onClick={() => setShowReceive(true)}>
                  {t('procurement.receive_goods')}
                </Btn>
              )}
              {canCancel && (
                <Btn size="sm" variant="danger" onClick={() => setShowCancel(true)}>
                  {t('procurement.cancel_order')}
                </Btn>
              )}
            </div>
          }
        />

        <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-5">
          {/* Summary */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
            <div className="bg-zinc-900 rounded-2xl border border-zinc-800 p-4 space-y-3">
              <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.order_info')}</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-zinc-500">{t('settings.status')}</dt>
                  <dd><POStatusBadge status={po.status} /></dd>
                </div>
                <div className="flex justify-between">
                  <dt className="text-zinc-500">{t('procurement.order_date')}</dt>
                  <dd className="text-zinc-200">{fmtDate(po.order_date)}</dd>
                </div>
                {po.expected_date && (
                  <div className="flex justify-between">
                    <dt className="text-zinc-500">{t('procurement.expected')}</dt>
                    <dd className="text-zinc-200">{fmtDate(po.expected_date)}</dd>
                  </div>
                )}
                {po.approved_at && (
                  <div className="flex justify-between">
                    <dt className="text-zinc-500">{t('procurement.po_status_ordered')}</dt>
                    <dd className="text-zinc-200">{fmtDateTime(po.approved_at)}</dd>
                  </div>
                )}
                <div className="flex justify-between">
                  <dt className="text-zinc-500">{t('procurement.created_by')}</dt>
                  <dd className="text-zinc-200">{po.created_by_name ?? '—'}</dd>
                </div>
                {po.approved_by_name && (
                  <div className="flex justify-between">
                    <dt className="text-zinc-500">{t('procurement.approved_by')}</dt>
                    <dd className="text-zinc-200">{po.approved_by_name}</dd>
                  </div>
                )}
                {po.notes && (
                  <div className="pt-2 border-t border-zinc-800">
                    <dt className="text-zinc-500 mb-1">{t('procurement.notes')}</dt>
                    <dd className="text-zinc-400 text-xs">{po.notes}</dd>
                  </div>
                )}
              </dl>
            </div>

            <div className="bg-zinc-900 rounded-2xl border border-zinc-800 p-4 space-y-3">
              <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.order_total')}</h3>
              <dl className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <dt className="text-zinc-500">{t('procurement.subtotal')}</dt>
                  <dd className="font-mono text-zinc-200">{fmt(po.subtotal)}</dd>
                </div>
                {parseFloat(po.discount_amount) > 0 && (
                  <div className="flex justify-between">
                    <dt className="text-zinc-500">{t('procurement.discount')}</dt>
                    <dd className="font-mono text-red-400">-{fmt(po.discount_amount)}</dd>
                  </div>
                )}
                {parseFloat(po.tax_amount) > 0 && (
                  <div className="flex justify-between">
                    <dt className="text-zinc-500">{t('procurement.tax')}</dt>
                    <dd className="font-mono text-zinc-200">{fmt(po.tax_amount)}</dd>
                  </div>
                )}
                <div className="flex justify-between border-t border-zinc-700 pt-2 font-semibold">
                  <dt className="text-zinc-300">{t('procurement.col_total')}</dt>
                  <dd className="font-mono text-amber-400">{fmt(po.total_amount)}</dd>
                </div>
              </dl>
            </div>

            <div className="bg-zinc-900 rounded-2xl border border-zinc-800 p-4 space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.payment')}</h3>
                {po.payable && <PayableStatusBadge status={po.payable.status} />}
              </div>
              {po.payable ? (() => {
                const remaining = parseFloat(po.payable.remaining_amount)
                const paid      = parseFloat(po.payable.paid_amount)
                const isFullyPaid = remaining === 0 && paid > 0
                return (
                  <>
                    {isFullyPaid ? (
                      <div className="flex flex-col items-center gap-1 py-3">
                        <span className="text-2xl">✅</span>
                        <p className="text-sm font-semibold text-green-400">{t('procurement.fully_paid')}</p>
                        <p className="text-xs text-zinc-500 font-mono">{fmt(po.payable.paid_amount)}</p>
                      </div>
                    ) : (
                      <>
                        <dl className="space-y-2 text-sm">
                          <div className="flex justify-between">
                            <dt className="text-zinc-500">{t('procurement.amount_due')}</dt>
                            <dd className="font-mono text-zinc-200">{fmt(po.payable.total_amount)}</dd>
                          </div>
                          {paid > 0 && (
                            <div className="flex justify-between">
                              <dt className="text-zinc-500">{t('status.paid')}</dt>
                              <dd className="font-mono text-green-400">{fmt(po.payable.paid_amount)}</dd>
                            </div>
                          )}
                          <div className="flex justify-between border-t border-zinc-700 pt-2 font-semibold">
                            <dt className="text-zinc-300">{t('procurement.col_remaining')}</dt>
                            <dd className="font-mono text-amber-400">{fmt(po.payable.remaining_amount)}</dd>
                          </div>
                        </dl>
                        <Btn size="sm" variant="outline" fullWidth onClick={() => navigate('/app/procurement/payments')}>
                          {paid > 0 ? t('procurement.pay_remaining') : t('procurement.make_payment')}
                        </Btn>
                      </>
                    )}
                  </>
                )
              })() : (
                <p className="text-sm text-zinc-600">{t('procurement.no_payable_yet')}</p>
              )}
            </div>
          </div>

          {/* Items */}
          <div className="bg-zinc-900 rounded-2xl border border-zinc-800 overflow-hidden">
            <div className="px-4 py-3 border-b border-zinc-800">
              <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.items')} ({po.items.length})</h3>
            </div>
            <Table>
              <thead>
                <tr>
                  <Th>{t('procurement.product')}</Th>
                  <Th right>{t('procurement.po_status_ordered')}</Th>
                  <Th right>{t('procurement.po_status_received')}</Th>
                  <Th right>{t('procurement.unit_cost')}</Th>
                  <Th right>{t('procurement.line_total')}</Th>
                  <Th>{t('procurement.progress')}</Th>
                </tr>
              </thead>
              <tbody>
                {po.items.map(item => {
                  const ordered  = parseFloat(item.ordered_quantity)
                  const received = parseFloat(item.received_quantity)
                  const pct      = ordered > 0 ? Math.min(100, Math.round((received / ordered) * 100)) : 0
                  return (
                    <tr key={item.id} className="hover:bg-zinc-800/40 transition-colors">
                      <Td>
                        {item.product_name
                          ? <span className="text-sm text-zinc-200">{item.product_name}</span>
                          : <span className="text-xs font-mono text-zinc-500">{item.product_id.slice(0, 8)}…</span>
                        }
                      </Td>
                      <Td right><span className="font-mono">{item.ordered_quantity}</span></Td>
                      <Td right>
                        <span className={`font-mono ${received >= ordered ? 'text-green-400' : received > 0 ? 'text-amber-400' : 'text-zinc-500'}`}>
                          {item.received_quantity}
                        </span>
                      </Td>
                      <Td right><span className="font-mono">{fmt(item.unit_cost)}</span></Td>
                      <Td right><span className="font-mono">{fmt(item.line_total)}</span></Td>
                      <Td>
                        <div className="flex items-center gap-2 min-w-[80px]">
                          <div className="flex-1 h-1.5 bg-zinc-700 rounded-full overflow-hidden">
                            <div
                              className={`h-full rounded-full ${pct >= 100 ? 'bg-green-500' : pct > 0 ? 'bg-amber-500' : 'bg-zinc-600'}`}
                              style={{ width: `${pct}%` }}
                            />
                          </div>
                          <span className="text-xs text-zinc-500">{pct}%</span>
                        </div>
                      </Td>
                    </tr>
                  )
                })}
              </tbody>
            </Table>
          </div>

          {/* Goods Receipts */}
          {receipts.length > 0 && (
            <div className="bg-zinc-900 rounded-2xl border border-zinc-800 overflow-hidden">
              <div className="px-4 py-3 border-b border-zinc-800">
                <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.goods_receipts')} ({receipts.length})</h3>
              </div>
              <Table>
                <thead>
                  <tr>
                    <Th>{t('procurement.col_receipt_number')}</Th>
                    <Th>{t('procurement.col_date')}</Th>
                    <Th>{t('procurement.received_by')}</Th>
                    <Th>{t('settings.status')}</Th>
                    <Th right>&nbsp;</Th>
                  </tr>
                </thead>
                <tbody>
                  {receipts.map(receipt => (
                    <tr
                      key={receipt.id}
                      onClick={() => navigate(`/app/procurement/receipts/${receipt.id}`)}
                      className="cursor-pointer hover:bg-zinc-800/40 transition-colors"
                    >
                      <Td><span className="font-mono text-sm text-zinc-200">{receipt.receipt_number}</span></Td>
                      <Td><span className="text-zinc-300">{fmtDateTime(receipt.receipt_date)}</span></Td>
                      <Td><span className="text-zinc-400">{receipt.received_by_name ?? '—'}</span></Td>
                      <Td>
                        <Badge variant={receipt.status === 'RECEIVED' ? 'success' : 'danger'} size="xs" dot>
                          {receipt.status}
                        </Badge>
                      </Td>
                      <Td right><span className="text-amber-400 text-xs">{t('procurement.view_arrow')}</span></Td>
                    </tr>
                  ))}
                </tbody>
              </Table>
            </div>
          )}
        </div>
      </div>

      {showReceive && (
        <ReceiveGoodsModal
          poId={po.id}
          branchId={po.branch_id}
          items={po.items}
          onClose={() => setShowReceive(false)}
        />
      )}
      {showCancel && (
        <CancelModal
          poId={po.id}
          onClose={() => setShowCancel(false)}
        />
      )}
    </>
  )
}
