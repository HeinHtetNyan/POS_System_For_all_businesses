import { useState, Fragment } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { toast } from 'sonner'
import { cn, fmt, fmtDate, fmtDateTime, timeAgo, extractApiMsg } from '@/lib/utils'
import { Btn, Table, Th, Td, Empty, Spinner, SectionHeader, StatCard, Badge } from '@/components/ui'
import { procurementService } from '@/services/procurement/procurement.service'
import { PayableStatusBadge, inputCls, FormField } from './procurementHelpers'
import type { SupplierPayableDetail } from '@/shared/types'

const PAGE_SIZE = 30


const makePaymentSchema = (maxAmount: number) => z.object({
  payment_method:   z.string().min(1, 'Payment method required'),
  amount:           z.string().min(1)
    .refine(v => parseFloat(v) > 0, 'Must be > 0')
    .refine(v => parseFloat(v) <= maxAmount, `Cannot exceed the remaining balance (${maxAmount.toFixed(2)})`),
  payment_date:     z.string().min(1, 'Date required'),
  reference_number: z.string(),
  notes:            z.string(),
})

type PaymentFormValues = z.infer<ReturnType<typeof makePaymentSchema>>

const PAYMENT_METHODS = ['CASH', 'BANK_TRANSFER', 'CHEQUE', 'CARD', 'MOBILE_PAYMENT']

function RecordPaymentModal({ payable, onClose }: { payable: SupplierPayableDetail; onClose: () => void }) {
  const qc = useQueryClient()

  const remainingAmount = parseFloat(payable.remaining_amount)
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<PaymentFormValues>({
    resolver: zodResolver(makePaymentSchema(remainingAmount)),
    defaultValues: {
      payment_method:   'BANK_TRANSFER',
      amount:           remainingAmount.toFixed(2),
      payment_date:     new Date().toISOString().split('T')[0],
      reference_number: '',
      notes:            '',
    },
  })

  const mutation = useMutation({
    mutationFn: (data: PaymentFormValues) => procurementService.recordPayment(payable.id, {
      payment_method:   data.payment_method,
      amount:           data.amount,
      payment_date:     new Date(data.payment_date).toISOString(),
      reference_number: data.reference_number || undefined,
      notes:            data.notes || undefined,
    }),
    onSuccess: (payment) => {
      toast.success(`Payment of ${fmt(payment.amount)} recorded`)
      qc.invalidateQueries({ queryKey: ['supplier-payables'] })
      qc.invalidateQueries({ queryKey: ['supplier-balance'] })
      qc.invalidateQueries({ queryKey: ['payable-detail', payable.id] })
      qc.invalidateQueries({ queryKey: ['purchase-order', payable.purchase_order_id] })
      onClose()
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? 'Failed to record payment'),
  })

  const pending = isSubmitting || mutation.isPending

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="bg-zinc-900 border border-zinc-700 rounded-2xl w-full max-w-sm shadow-2xl">
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800">
          <h2 className="text-base font-semibold text-zinc-100">Record Payment</h2>
          <button onClick={onClose} className="text-zinc-500 hover:text-zinc-200 w-8 h-8 flex items-center justify-center rounded-lg hover:bg-zinc-800 transition-colors">
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit(d => mutation.mutate(d))} className="p-5 space-y-4">
          <div className="bg-zinc-800/50 rounded-xl p-3 text-sm">
            <div className="flex justify-between">
              <span className="text-zinc-500">Outstanding</span>
              <span className="font-mono font-semibold text-amber-400">{fmt(payable.remaining_amount)}</span>
            </div>
            <div className="flex justify-between mt-1">
              <span className="text-zinc-500">Total</span>
              <span className="font-mono text-zinc-400">{fmt(payable.total_amount)}</span>
            </div>
          </div>

          <FormField label="Payment Method" error={errors.payment_method?.message} required>
            <select {...register('payment_method')} className={inputCls(!!errors.payment_method)}>
              {PAYMENT_METHODS.map(m => (
                <option key={m} value={m}>{m.replace('_', ' ')}</option>
              ))}
            </select>
          </FormField>

          <FormField label="Amount" error={errors.amount?.message} required>
            <input {...register('amount')} type="number" min="0.01" max={remainingAmount} step="0.01" className={inputCls(!!errors.amount)} />
          </FormField>

          <FormField label="Payment Date" error={errors.payment_date?.message} required>
            <input {...register('payment_date')} type="date" className={inputCls(!!errors.payment_date)} />
          </FormField>

          <FormField label="Reference Number">
            <input {...register('reference_number')} placeholder="TXN-12345" className={inputCls(false)} />
          </FormField>

          <FormField label="Notes">
            <textarea {...register('notes')} placeholder="Optional notes…" rows={2} className={`${inputCls(false)} resize-none`} />
          </FormField>

          <div className="flex gap-3 pt-1">
            <Btn type="button" variant="secondary" onClick={onClose}>Cancel</Btn>
            <Btn type="submit" disabled={pending} fullWidth>
              {pending ? <Spinner size={16} /> : 'Record Payment'}
            </Btn>
          </div>
        </form>
      </div>
    </div>
  )
}


function PaymentHistoryRow({ payableId }: { payableId: string }) {
  const { data: detail, isLoading } = useQuery({
    queryKey: ['payable-detail', payableId],
    queryFn: () => procurementService.getPayable(payableId),
  })

  if (isLoading) {
    return (
      <tr className="bg-zinc-800/30">
        <td colSpan={8} className="px-4 py-3">
          <div className="flex items-center justify-center h-10"><Spinner size={16} /></div>
        </td>
      </tr>
    )
  }

  return (
    <tr className="bg-zinc-800/30">
      <td colSpan={8} className="px-4 py-3">
        {!detail || detail.payments.length === 0 ? (
          <p className="text-xs text-zinc-600">No payments recorded yet.</p>
        ) : (
          <div className="space-y-1">
            <p className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">Payment History</p>
            {detail.payments.map(p => (
              <div key={p.id} className="flex items-center gap-3 text-xs bg-zinc-800 rounded-lg px-3 py-2 flex-wrap">
                <span className="text-zinc-500">{fmtDate(p.payment_date)}</span>
                <Badge size="xs" variant={p.status === 'CONFIRMED' ? 'success' : p.status === 'VOIDED' ? 'danger' : 'default'}>
                  {p.payment_method.replace('_', ' ')}
                </Badge>
                {p.reference_number && <span className="font-mono text-zinc-500">{p.reference_number}</span>}
                {p.recorded_by_name && <span className="text-zinc-600">by {p.recorded_by_name}</span>}
                <span className="ml-auto font-mono font-semibold text-green-400">{fmt(p.amount)}</span>
              </div>
            ))}
          </div>
        )}
      </td>
    </tr>
  )
}


export default function SupplierPayablesPage() {
  const [status, setStatus]             = useState<string | undefined>(undefined)
  const [selMonth, setSelMonth] = useState(() => new Date().getMonth() + 1)
  const [selYear,  setSelYear]  = useState(() => new Date().getFullYear())
  const [page, setPage]                 = useState(1)
  const [expandedId, setExpandedId]   = useState<string | null>(null)
  const [activePayable, setActivePayable] = useState<SupplierPayableDetail | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['supplier-payables', { status }],
    queryFn: () => procurementService.listPayables({ status, page: 1, page_size: 500 }),
    placeholderData: prev => prev,
  })

  const { data: openData }    = useQuery({ queryKey: ['supplier-payables', { status: 'OPEN',    page_size: 100 }], queryFn: () => procurementService.listPayables({ status: 'OPEN',    page_size: 100 }) })
  const { data: partialData } = useQuery({ queryKey: ['supplier-payables', { status: 'PARTIAL', page_size: 100 }], queryFn: () => procurementService.listPayables({ status: 'PARTIAL', page_size: 100 }) })

  const allPayables = data?.items ?? []

  const monthStr = `${selYear}-${String(selMonth).padStart(2, '0')}`
  const payables = allPayables.filter(p => (p.created_at ?? '').slice(0, 7) === monthStr)

  const total      = payables.length
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE))
  const paginatedPayables = payables.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  const openTotal    = (openData?.items    ?? []).reduce((s, p) => s + parseFloat(p.remaining_amount), 0)
  const partialTotal = (partialData?.items ?? []).reduce((s, p) => s + parseFloat(p.remaining_amount), 0)
  const outstanding  = openTotal + partialTotal

  async function openPayModal(payableId: string) {
    const detail = await procurementService.getPayable(payableId)
    setActivePayable(detail)
  }

  return (
    <>
      <div className="flex flex-col h-full overflow-hidden">
        <SectionHeader
          title="Payments"
          subtitle={`${total} payable${total !== 1 ? 's' : ''}`}
        />

        <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-4">
          {/* Stats */}
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <StatCard label="Open Payables"    value={(openData?.total ?? 0).toLocaleString()} />
            <StatCard label="Partially Paid"   value={(partialData?.total ?? 0).toLocaleString()} />
            <StatCard label="Total Outstanding" value={fmt(outstanding)} accent={outstanding > 0} />
          </div>

          {/* Month / Year selectors */}
          <div className="flex flex-wrap items-center gap-2">
            <select
              value={selMonth}
              onChange={e => { setSelMonth(Number(e.target.value)); setPage(1) }}
              className="bg-zinc-900 border border-zinc-700 rounded-xl text-zinc-200 text-sm px-3 py-1.5 focus:outline-none focus:border-amber-500"
            >
              {['January','February','March','April','May','June','July','August','September','October','November','December'].map((m, i) => (
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

          {/* Status filters */}
          <div className="flex gap-1 flex-wrap">
            {([
              { label: 'All',     value: undefined  },
              { label: 'Open',    value: 'OPEN'     },
              { label: 'Partial', value: 'PARTIAL'  },
              { label: 'Paid',    value: 'PAID'     },
            ] as const).map(f => (
              <button
                key={f.label}
                onClick={() => { setStatus(f.value as string | undefined); setPage(1) }}
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

          {/* Table */}
          <div className="bg-zinc-900 rounded-2xl border border-zinc-800 overflow-hidden">
            {isLoading ? (
              <div className="flex items-center justify-center h-40"><Spinner size={28} /></div>
            ) : payables.length === 0 ? (
              <Empty
                icon={<span className="text-4xl">💳</span>}
                title="No payables found"
                subtitle="Payables are created automatically when purchase orders are approved and received"
              />
            ) : (
              <Table>
                <thead>
                  <tr>
                    <Th>Payable ID</Th>
                    <Th>Supplier</Th>
                    <Th>Status</Th>
                    <Th right>Total</Th>
                    <Th right>Paid</Th>
                    <Th right>Remaining</Th>
                    <Th>Created</Th>
                    <Th />
                  </tr>
                </thead>
                <tbody>
                  {paginatedPayables.map(p => (
                    <Fragment key={p.id}>
                      <tr
                        className="cursor-pointer hover:bg-zinc-800/60 transition-colors"
                        onClick={() => setExpandedId(prev => prev === p.id ? null : p.id)}
                      >
                        <Td muted mono>{p.id.slice(0, 8)}…</Td>
                        <Td>
                          <span className="text-sm text-zinc-200">{p.supplier_name ?? '—'}</span>
                        </Td>
                        <Td><PayableStatusBadge status={p.status} /></Td>
                        <Td right><span className="font-mono">{fmt(p.total_amount)}</span></Td>
                        <Td right><span className="font-mono text-green-400">{fmt(p.paid_amount)}</span></Td>
                        <Td right>
                          <span className={`font-mono font-semibold ${p.status === 'PAID' ? 'text-zinc-500' : 'text-amber-400'}`}>
                            {fmt(p.remaining_amount)}
                          </span>
                        </Td>
                        <Td muted>{timeAgo(p.created_at)}</Td>
                        <Td>
                          {p.status !== 'PAID' && (
                            <Btn size="xs" onClick={e => { e.stopPropagation(); openPayModal(p.id) }}>Pay</Btn>
                          )}
                        </Td>
                      </tr>
                      {expandedId === p.id && <PaymentHistoryRow payableId={p.id} />}
                    </Fragment>
                  ))}
                </tbody>
              </Table>
            )}
          </div>

          <div className="flex items-center justify-between gap-3">
            <p className="text-xs text-zinc-500">
              {total === 0 ? '0 payables' : `${(page - 1) * PAGE_SIZE + 1}–${Math.min(page * PAGE_SIZE, total)} of ${total}`}
            </p>
            <div className="flex items-center gap-1">
              <button
                onClick={() => setPage(p => Math.max(1, p - 1))}
                disabled={page === 1}
                className="px-2 py-1 rounded-lg text-xs text-zinc-400 border border-zinc-700 hover:border-zinc-500 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
              >‹ Prev</button>
              <span className="text-xs text-zinc-500 px-2">{page} / {totalPages}</span>
              <button
                onClick={() => setPage(p => Math.min(totalPages, p + 1))}
                disabled={page >= totalPages}
                className="px-2 py-1 rounded-lg text-xs text-zinc-400 border border-zinc-700 hover:border-zinc-500 hover:text-zinc-200 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
              >Next ›</button>
            </div>
          </div>
        </div>
      </div>

      {activePayable && (
        <RecordPaymentModal payable={activePayable} onClose={() => setActivePayable(null)} />
      )}
    </>
  )
}
