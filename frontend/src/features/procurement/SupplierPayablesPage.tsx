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
import { useLocaleStore } from '@/i18n/localeStore'
import type { SupplierPayableDetail } from '@/shared/types'

const PAGE_SIZE = 30


const makePaymentSchema = (maxAmount: number, t: (key: string) => string) => z.object({
  payment_method:   z.string().min(1, t('procurement.validation_payment_method_required')),
  amount:           z.string().min(1)
    .refine(v => parseFloat(v) > 0, t('procurement.validation_must_be_positive'))
    .refine(v => parseFloat(v) <= maxAmount, `${t('procurement.validation_cannot_exceed_remaining')} (${maxAmount.toFixed(2)})`),
  payment_date:     z.string().min(1, t('procurement.validation_date_required')),
  reference_number: z.string(),
  notes:            z.string(),
})

type PaymentFormValues = z.infer<ReturnType<typeof makePaymentSchema>>

const PAYMENT_METHODS = ['CASH', 'BANK_TRANSFER', 'CHEQUE', 'CARD', 'MOBILE_PAYMENT']

function RecordPaymentModal({ payable, onClose }: { payable: SupplierPayableDetail; onClose: () => void }) {
  const qc = useQueryClient()
  const t = useLocaleStore(s => s.t)

  const remainingAmount = parseFloat(payable.remaining_amount)
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm<PaymentFormValues>({
    resolver: zodResolver(makePaymentSchema(remainingAmount, t)),
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
      toast.success(`${t('procurement.payment_of_prefix')} ${fmt(payment.amount)} ${t('procurement.payment_recorded_suffix')}`)
      qc.invalidateQueries({ queryKey: ['supplier-payables'] })
      qc.invalidateQueries({ queryKey: ['supplier-balance'] })
      qc.invalidateQueries({ queryKey: ['payable-detail', payable.id] })
      qc.invalidateQueries({ queryKey: ['purchase-order', payable.purchase_order_id] })
      onClose()
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('procurement.failed_record_payment')),
  })

  const pending = isSubmitting || mutation.isPending

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="bg-zinc-900 border border-zinc-700 rounded-2xl w-full max-w-sm shadow-2xl">
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800">
          <h2 className="text-base font-semibold text-zinc-100">{t('procurement.record_payment')}</h2>
          <button onClick={onClose} className="text-zinc-500 hover:text-zinc-200 w-8 h-8 flex items-center justify-center rounded-lg hover:bg-zinc-800 transition-colors">
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit(d => mutation.mutate(d))} className="p-5 space-y-4">
          <div className="bg-zinc-800/50 rounded-xl p-3 text-sm">
            <div className="flex justify-between">
              <span className="text-zinc-500">{t('procurement.outstanding')}</span>
              <span className="font-mono font-semibold text-amber-400">{fmt(payable.remaining_amount)}</span>
            </div>
            <div className="flex justify-between mt-1">
              <span className="text-zinc-500">{t('procurement.col_total')}</span>
              <span className="font-mono text-zinc-400">{fmt(payable.total_amount)}</span>
            </div>
          </div>

          <FormField label={t('procurement.payment_method')} error={errors.payment_method?.message} required>
            <select {...register('payment_method')} className={inputCls(!!errors.payment_method)}>
              {PAYMENT_METHODS.map(m => (
                <option key={m} value={m}>{m.replace('_', ' ')}</option>
              ))}
            </select>
          </FormField>

          <FormField label={t('procurement.amount')} error={errors.amount?.message} required>
            <input {...register('amount')} type="number" min="0.01" max={remainingAmount} step="0.01" className={inputCls(!!errors.amount)} />
          </FormField>

          <FormField label={t('procurement.payment_date')} error={errors.payment_date?.message} required>
            <input {...register('payment_date')} type="date" className={inputCls(!!errors.payment_date)} />
          </FormField>

          <FormField label={t('procurement.reference_number')}>
            <input {...register('reference_number')} placeholder="TXN-12345" className={inputCls(false)} />
          </FormField>

          <FormField label={t('procurement.notes')}>
            <textarea {...register('notes')} placeholder={t('procurement.optional_notes_ellipsis_placeholder')} rows={2} className={`${inputCls(false)} resize-none`} />
          </FormField>

          <div className="flex gap-3 pt-1">
            <Btn type="button" variant="secondary" onClick={onClose}>{t('common.cancel')}</Btn>
            <Btn type="submit" disabled={pending} fullWidth>
              {pending ? <Spinner size={16} /> : t('procurement.record_payment')}
            </Btn>
          </div>
        </form>
      </div>
    </div>
  )
}


function PaymentHistoryRow({ payableId }: { payableId: string }) {
  const t = useLocaleStore(s => s.t)
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
          <p className="text-xs text-zinc-600">{t('procurement.no_payments_recorded_yet')}</p>
        ) : (
          <div className="space-y-1">
            <p className="text-xs font-semibold text-zinc-400 uppercase tracking-wider mb-2">{t('procurement.payment_history')}</p>
            {detail.payments.map(p => (
              <div key={p.id} className="flex items-center gap-3 text-xs bg-zinc-800 rounded-lg px-3 py-2 flex-wrap">
                <span className="text-zinc-500">{fmtDate(p.payment_date)}</span>
                <Badge size="xs" variant={p.status === 'CONFIRMED' ? 'success' : p.status === 'VOIDED' ? 'danger' : 'default'}>
                  {p.payment_method.replace('_', ' ')}
                </Badge>
                {p.reference_number && <span className="font-mono text-zinc-500">{p.reference_number}</span>}
                {p.recorded_by_name && <span className="text-zinc-600">{t('procurement.by_prefix')} {p.recorded_by_name}</span>}
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
  const t = useLocaleStore(s => s.t)
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
          title={t('procurement.payments_title')}
          subtitle={`${total} ${t('procurement.payable_word')}${total !== 1 ? 's' : ''}`}
        />

        <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-4">
          {/* Stats */}
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            <StatCard label={t('procurement.stat_open_payables')}    value={(openData?.total ?? 0).toLocaleString()} />
            <StatCard label={t('procurement.stat_partially_paid')}   value={(partialData?.total ?? 0).toLocaleString()} />
            <StatCard label={t('procurement.stat_total_outstanding')} value={fmt(outstanding)} accent={outstanding > 0} />
          </div>

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

          {/* Status filters */}
          <div className="flex gap-1 flex-wrap">
            {([
              { label: t('procurement.filter_all'),        value: undefined  },
              { label: t('procurement.payable_status_open'), value: 'OPEN'     },
              { label: t('status.partial'),                  value: 'PARTIAL'  },
              { label: t('status.paid'),                     value: 'PAID'     },
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
                title={t('procurement.no_payables_found')}
                subtitle={t('procurement.no_payables_found_subtitle')}
              />
            ) : (
              <Table>
                <thead>
                  <tr>
                    <Th>{t('procurement.col_payable_id')}</Th>
                    <Th>{t('procurement.supplier')}</Th>
                    <Th>{t('settings.status')}</Th>
                    <Th right>{t('procurement.col_total')}</Th>
                    <Th right>{t('status.paid')}</Th>
                    <Th right>{t('procurement.col_remaining')}</Th>
                    <Th>{t('procurement.col_created')}</Th>
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
                            <Btn size="xs" onClick={e => { e.stopPropagation(); openPayModal(p.id) }}>{t('procurement.pay')}</Btn>
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
              {total === 0 ? t('procurement.zero_payables') : `${(page - 1) * PAGE_SIZE + 1}–${Math.min(page * PAGE_SIZE, total)} ${t('procurement.of_word')} ${total}`}
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

      {activePayable && (
        <RecordPaymentModal payable={activePayable} onClose={() => setActivePayable(null)} />
      )}
    </>
  )
}
