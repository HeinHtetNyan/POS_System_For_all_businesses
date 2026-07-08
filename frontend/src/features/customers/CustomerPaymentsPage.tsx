import { useState } from 'react'
import { useParams } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { fmt, fmtDateTime } from '@/lib/utils'
import { Btn, Modal, Spinner, Empty, Table, Th, Td, StatCard } from '@/components/ui'
import { IconPlus, IconCash } from '@/components/icons'
import { customersService } from '@/services/customers/customers.service'
import { useAuthStore } from '@/store/auth.store'
import { useLocaleStore } from '@/i18n/localeStore'
import type { LedgerEntry } from '@/shared/types'

const PAGE_SIZE = 30

export default function CustomerPaymentsPage() {
  const { id } = useParams<{ id: string }>()
  const qc = useQueryClient()
  const user = useAuthStore(s => s.user)
  const t = useLocaleStore(s => s.t)
  // Cashiers get read-only lookup — see CustomersScreen.tsx for the same rule.
  const canManageCustomers = user?.role !== 'CASHIER'

  const [showModal, setShowModal]   = useState(false)
  const [amount, setAmount]         = useState('')
  const [note, setNote]             = useState('')
  const [reference, setReference]   = useState('')
  const [page, setPage]             = useState(1)

  const { data: ledgerData, isLoading } = useQuery({
    queryKey: ['customer-ledger', id, 1],
    queryFn: () => customersService.getLedger(id!, { page: 1 }),
    enabled: !!id,
  })

  const { data: statement } = useQuery({
    queryKey: ['customer-statement', id],
    queryFn: () => customersService.getStatement(id!),
    enabled: !!id,
  })

  const paymentMutation = useMutation({
    mutationFn: () => customersService.recordPayment(id!, {
      amount,
      note:           note || undefined,
      reference_type: reference ? 'MANUAL' : undefined,
      reference_id:   reference || undefined,
    }),
    onSuccess: () => {
      toast.success(t('customers.payment_recorded'))
      setShowModal(false)
      setAmount('')
      setNote('')
      setReference('')
      qc.invalidateQueries({ queryKey: ['customer', id] })
      qc.invalidateQueries({ queryKey: ['customer-ledger', id] })
      qc.invalidateQueries({ queryKey: ['customer-statement', id] })
      qc.invalidateQueries({ queryKey: ['customers'] })
    },
    onError: () => toast.error(t('customers.payment_failed')),
  })

  const allEntries: LedgerEntry[] = ledgerData?.items ?? []

  // Sale reference IDs — payments matching these were made during checkout (not standalone debt payments)
  const saleRefs = new Set(
    allEntries.filter(e => e.type === 'SALE' && e.reference).map(e => e.reference as string)
  )

  // Only show payments NOT matched to a same-order sale (standalone debt repayments)
  const debtPayments = allEntries.filter(
    e => e.type === 'PAYMENT' && (!e.reference || !saleRefs.has(e.reference))
  )

  const totalPaid = debtPayments.reduce((sum, e) => sum + parseFloat(e.credit ?? '0'), 0)

  const totalPages = Math.max(1, Math.ceil(debtPayments.length / PAGE_SIZE))
  const paginatedPayments = debtPayments.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  function closeModal() {
    setShowModal(false)
    setAmount('')
    setNote('')
    setReference('')
  }

  return (
    <div className="p-4 sm:p-6 space-y-4">
      {/* Summary + action */}
      <div className="flex items-center justify-between gap-3">
        <div className="flex gap-3">
          <StatCard label={t('customers.debt_payments')} value={fmt(totalPaid)} />
          {statement?.closing_balance != null && (
            <StatCard
              label={t('customers.remaining_debt')}
              value={fmt(statement.closing_balance)}
              accent={parseFloat(statement.closing_balance) > 0}
            />
          )}
        </div>
        {canManageCustomers && (
          <Btn onClick={() => setShowModal(true)}>
            <IconPlus width="14" height="14" /> {t('customers.record_payment')}
          </Btn>
        )}
      </div>

      {/* Debt payment history */}
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden">
        <div className="px-4 py-3 border-b border-zinc-800">
          <h3 className="text-sm font-semibold text-zinc-200">{t('customers.debt_payment_history')}</h3>
          <p className="text-xs text-zinc-600 mt-0.5">{t('customers.debt_payment_history_sub')}</p>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center h-40">
            <Spinner size={28} />
          </div>
        ) : debtPayments.length === 0 ? (
          <Empty
            icon={<IconCash width="40" height="40" />}
            title={t('customers.no_debt_payments')}
            subtitle={canManageCustomers ? t('customers.no_debt_payments_sub') : undefined}
            action={
              canManageCustomers ? (
                <Btn size="sm" onClick={() => setShowModal(true)}>
                  <IconPlus width="14" height="14" /> {t('customers.record_payment')}
                </Btn>
              ) : undefined
            }
          />
        ) : (
          <>
          <Table>
            <thead>
              <tr>
                <Th>{t('customers.date')}</Th>
                <Th>{t('customers.note')}</Th>
                <Th>{t('customers.reference')}</Th>
                <Th right>{t('customers.amount_paid')}</Th>
                <Th right>{t('customers.balance_after')}</Th>
              </tr>
            </thead>
            <tbody>
              {paginatedPayments.map((entry, i) => (
                <tr key={entry.id ?? i} className="hover:bg-zinc-800/40 transition-colors">
                  <Td muted>{entry.date ? fmtDateTime(entry.date) : '—'}</Td>
                  <Td>{entry.description || '—'}</Td>
                  <Td muted mono>{entry.reference ?? '—'}</Td>
                  <Td right>
                    <span className="font-mono font-semibold text-green-400">{fmt(entry.credit ?? 0)}</span>
                  </Td>
                  <Td right>
                    <span className="font-mono text-zinc-400">{fmt(entry.balance)}</span>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
          <div className="px-4 py-2.5 border-t border-zinc-800 flex items-center justify-between gap-3">
            <p className="text-xs text-zinc-500">
              {debtPayments.length === 0 ? `0 ${t('customers.payments_word')}` : `${(page - 1) * PAGE_SIZE + 1}–${Math.min(page * PAGE_SIZE, debtPayments.length)} ${t('customers.of')} ${debtPayments.length}`}
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
          </>
        )}
      </div>

      {/* Record Payment Modal */}
      <Modal open={showModal} onClose={closeModal} title={t('customers.record_debt_payment')}>
        <div className="space-y-4">
          <p className="text-xs text-zinc-500">{t('customers.record_payment_desc')}</p>

          <ModalField label={t('customers.amount')} required>
            <input
              type="number"
              step="0.01"
              min="0.01"
              value={amount}
              onChange={e => setAmount(e.target.value)}
              placeholder="0.00"
              autoFocus
              className="w-full bg-zinc-800 border border-zinc-700 rounded-xl text-zinc-100 placeholder-zinc-600 text-sm focus:outline-none focus:border-amber-500 focus:ring-1 focus:ring-amber-500/20 py-2.5 px-3"
            />
          </ModalField>

          <ModalField label={t('customers.reference')}>
            <input
              type="text"
              value={reference}
              onChange={e => setReference(e.target.value)}
              placeholder={t('customers.reference_placeholder')}
              className="w-full bg-zinc-800 border border-zinc-700 rounded-xl text-zinc-100 placeholder-zinc-600 text-sm focus:outline-none focus:border-amber-500 focus:ring-1 focus:ring-amber-500/20 py-2.5 px-3"
            />
          </ModalField>

          <ModalField label={t('customers.note')}>
            <textarea
              value={note}
              onChange={e => setNote(e.target.value)}
              rows={2}
              placeholder={t('customers.optional_note_placeholder')}
              className="w-full bg-zinc-800 border border-zinc-700 rounded-xl text-zinc-100 placeholder-zinc-600 text-sm focus:outline-none focus:border-amber-500 focus:ring-1 focus:ring-amber-500/20 py-2.5 px-3 resize-none"
            />
          </ModalField>

          <div className="flex gap-3">
            <Btn variant="secondary" fullWidth onClick={closeModal}>{t('common.cancel')}</Btn>
            <Btn
              fullWidth
              disabled={!amount || parseFloat(amount) <= 0 || paymentMutation.isPending}
              onClick={() => paymentMutation.mutate()}
            >
              {paymentMutation.isPending ? <Spinner size={16} /> : t('customers.record_payment')}
            </Btn>
          </div>
        </div>
      </Modal>
    </div>
  )
}

function ModalField({ label, required, children }: {
  label: string; required?: boolean; children: React.ReactNode
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">
        {label}{required && <span className="text-red-400 ml-0.5">*</span>}
      </label>
      {children}
    </div>
  )
}
