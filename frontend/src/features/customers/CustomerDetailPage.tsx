import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { fmt, fmtDateTime, timeAgo } from '@/lib/utils'
import { Btn, StatCard, Spinner, Empty } from '@/components/ui'
import { IconEdit, IconPlus, IconTrash, IconUser } from '@/components/icons'
import { customersService } from '@/services/customers/customers.service'
import { useAuthStore } from '@/store/auth.store'
import { useLocaleStore } from '@/i18n/localeStore'
import type { LedgerEntry } from '@/shared/types'

export default function CustomerDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const user = useAuthStore(s => s.user)
  const t = useLocaleStore(s => s.t)
  // Cashiers get read-only lookup — see CustomersScreen.tsx for the same rule.
  const canManageCustomers = user?.role !== 'CASHIER'
  const [note, setNote]         = useState('')
  const [isEditing, setIsEditing] = useState(false)

  const { data: customer, isLoading } = useQuery({
    queryKey: ['customer', id],
    queryFn: () => customersService.get(id!),
    enabled: !!id,
  })

  const { data: ledgerData } = useQuery({
    queryKey: ['customer-ledger', id, 1],
    queryFn: () => customersService.getLedger(id!, { page: 1 }),
    enabled: !!id,
  })

  const { data: statement } = useQuery({
    queryKey: ['customer-statement', id],
    queryFn: () => customersService.getStatement(id!),
    enabled: !!id,
  })

  const updateNoteMutation = useMutation({
    mutationFn: (text: string | null) => customersService.update(id!, { notes: text }),
    onSuccess: (_data, text) => {
      toast.success(text ? t('customers.note_saved') : t('customers.note_deleted'))
      setNote('')
      setIsEditing(false)
      qc.invalidateQueries({ queryKey: ['customer', id] })
    },
    onError: () => toast.error(t('customers.note_save_failed')),
  })

  if (isLoading || !customer) {
    return (
      <div className="flex items-center justify-center h-40">
        <Spinner size={28} />
      </div>
    )
  }

  const remainingDebt = statement?.closing_balance != null ? parseFloat(statement.closing_balance) : 0
  const recentEntries: LedgerEntry[] = ledgerData?.items?.slice(0, 5) ?? []

  const now = new Date()
  const currentMonth = now.getMonth()
  const currentYear  = now.getFullYear()

  const allEntries: LedgerEntry[] = ledgerData?.items ?? []
  const monthlyOrderAmt = allEntries
    .filter(e => {
      if (e.type !== 'SALE' || !e.debit || !e.date) return false
      const d = new Date(e.date)
      return d.getMonth() === currentMonth && d.getFullYear() === currentYear
    })
    .reduce((sum, e) => sum + parseFloat(e.debit ?? '0'), 0)

  const yearlyOrderAmt = allEntries
    .filter(e => {
      if (e.type !== 'SALE' || !e.debit || !e.date) return false
      return new Date(e.date).getFullYear() === currentYear
    })
    .reduce((sum, e) => sum + parseFloat(e.debit ?? '0'), 0)

  return (
    <div className="p-4 sm:p-6 space-y-5">
      {/* Stats */}
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
        <StatCard
          label={t('customers.remaining_debt')}
          value={fmt(remainingDebt)}
          accent={remainingDebt > 0}
        />
        <StatCard label={t('customers.member_since')}  value={new Date(customer.created_at).getFullYear().toString()} />
        <StatCard label={t('customers.last_updated')}  value={timeAgo(customer.updated_at)} />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <StatCard label={t('customers.orders_this_month')} value={fmt(monthlyOrderAmt)} accent={monthlyOrderAmt > 0} />
        <StatCard label={t('customers.orders_this_year')}  value={fmt(yearlyOrderAmt)}  accent={yearlyOrderAmt > 0} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Customer info */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-zinc-200">{t('customers.customer_info')}</h3>
            {canManageCustomers && (
              <Btn variant="ghost" size="xs" onClick={() => navigate(`/app/customers/${id}/edit`)}>
                <IconEdit width="12" height="12" /> {t('common.edit')}
              </Btn>
            )}
          </div>
          <div className="space-y-2.5">
            <InfoRow label={t('customers.name')}    value={customer.name}            />
            <InfoRow label={t('settings.phone')}   value={customer.phone}           />
            <InfoRow label={t('settings.email')}   value={customer.email ?? '—'}    />
            <InfoRow label={t('settings.address')} value={customer.address ?? '—'}  />
            {customer.notes && <InfoRow label={t('customers.notes')} value={customer.notes} />}
          </div>
        </div>

        {/* Note panel */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          {!canManageCustomers ? (
            /*  Read-only lookup: show the note if one exists, no edit UI  */
            <>
              <h3 className="text-sm font-semibold text-zinc-200 mb-3">{t('customers.note')}</h3>
              {customer.notes ? (
                <p className="text-sm text-zinc-300 whitespace-pre-wrap break-words leading-relaxed">
                  {customer.notes}
                </p>
              ) : (
                <p className="text-sm text-zinc-600">{t('customers.no_note')}</p>
              )}
            </>
          ) : customer.notes && !isEditing ? (
            /*  Has a note, view mode  */
            <>
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-sm font-semibold text-zinc-200">{t('customers.note')}</h3>
                <div className="flex items-center gap-1.5">
                  <Btn
                    variant="ghost"
                    size="xs"
                    onClick={() => { setNote(customer.notes ?? ''); setIsEditing(true) }}
                  >
                    <IconEdit width="12" height="12" /> {t('common.edit')}
                  </Btn>
                  <Btn
                    variant="ghost"
                    size="xs"
                    disabled={updateNoteMutation.isPending}
                    onClick={() => updateNoteMutation.mutate(null)}
                    className="text-red-400 hover:text-red-300"
                  >
                    <IconTrash width="12" height="12" /> {t('common.delete')}
                  </Btn>
                </div>
              </div>
              <p className="text-sm text-zinc-300 whitespace-pre-wrap break-words leading-relaxed">
                {customer.notes}
              </p>
            </>
          ) : (
            /*  No note, or editing  */
            <>
              <h3 className="text-sm font-semibold text-zinc-200 mb-3">
                {isEditing ? t('customers.edit_note') : t('customers.add_note')}
              </h3>
              <div className="space-y-2">
                <textarea
                  value={note}
                  onChange={e => setNote(e.target.value)}
                  rows={3}
                  placeholder={t('customers.note_placeholder')}
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-xl text-zinc-100 placeholder-zinc-600 text-sm focus:outline-none focus:border-amber-500 focus:ring-1 focus:ring-amber-500/20 transition-all py-2.5 px-3 resize-none"
                />
                <div className="flex gap-2">
                  <Btn
                    size="sm"
                    disabled={!note.trim() || updateNoteMutation.isPending}
                    onClick={() => updateNoteMutation.mutate(note.trim())}
                  >
                    <IconPlus width="12" height="12" />
                    {updateNoteMutation.isPending ? t('common.saving') : isEditing ? t('customers.save_note') : t('customers.add_note')}
                  </Btn>
                  {isEditing && (
                    <Btn
                      size="sm"
                      variant="ghost"
                      onClick={() => { setNote(''); setIsEditing(false) }}
                    >
                      {t('common.cancel')}
                    </Btn>
                  )}
                </div>
              </div>
            </>
          )}
        </div>
      </div>

      {/* Recent activity */}
      {recentEntries.length === 0 ? (
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <Empty
            icon={<IconUser width="32" height="32" />}
            title={t('customers.no_activity')}
            subtitle={t('customers.no_activity_sub')}
          />
        </div>
      ) : (
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-zinc-200">{t('customers.recent_activity')}</h3>
            <Btn variant="ghost" size="xs" onClick={() => navigate(`/app/customers/${id}/ledger`)}>
              {t('dash.view_all')}
            </Btn>
          </div>
          <div className="divide-y divide-zinc-800">
            {recentEntries.map((entry, i) => (
              <div key={entry.id ?? i} className="py-2.5 flex items-center justify-between gap-3">
                <div className="min-w-0">
                  <p className="text-sm text-zinc-300 truncate">{entry.description || entry.type}</p>
                  <p className="text-xs text-zinc-600">
                    {entry.date ? fmtDateTime(entry.date) : ''}
                  </p>
                </div>
                <div className="flex-shrink-0 text-right">
                  {entry.debit && parseFloat(entry.debit) > 0 && (
                    <p className="font-mono text-xs text-amber-400">{fmt(entry.debit)}</p>
                  )}
                  {entry.credit && parseFloat(entry.credit) > 0 && (
                    <p className="font-mono text-xs text-green-400">-{fmt(entry.credit)}</p>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start gap-3">
      <span className="text-xs text-zinc-600 uppercase tracking-wider flex-shrink-0 w-16 pt-0.5">{label}</span>
      <span className="text-sm text-zinc-300 min-w-0 break-words">{value}</span>
    </div>
  )
}
