import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { fmt, fmtDateTime, timeAgo } from '@/lib/utils'
import { Btn, StatCard, Spinner, Empty } from '@/components/ui'
import { IconEdit, IconPlus, IconTrash, IconUser } from '@/components/icons'
import { customersService } from '@/services/customers/customers.service'
import type { LedgerEntry } from '@/shared/types'

export default function CustomerDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const qc = useQueryClient()
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
      toast.success(text ? 'Note saved' : 'Note deleted')
      setNote('')
      setIsEditing(false)
      qc.invalidateQueries({ queryKey: ['customer', id] })
    },
    onError: () => toast.error('Failed to save note'),
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
          label="Remaining Debt"
          value={fmt(remainingDebt)}
          accent={remainingDebt > 0}
        />
        <StatCard label="Member Since"  value={new Date(customer.created_at).getFullYear().toString()} />
        <StatCard label="Last Updated"  value={timeAgo(customer.updated_at)} />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <StatCard label="Orders This Month" value={fmt(monthlyOrderAmt)} accent={monthlyOrderAmt > 0} />
        <StatCard label="Orders This Year"  value={fmt(yearlyOrderAmt)}  accent={yearlyOrderAmt > 0} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Customer info */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-zinc-200">Customer Info</h3>
            <Btn variant="ghost" size="xs" onClick={() => navigate(`/app/customers/${id}/edit`)}>
              <IconEdit width="12" height="12" /> Edit
            </Btn>
          </div>
          <div className="space-y-2.5">
            <InfoRow label="Name"    value={customer.name}            />
            <InfoRow label="Phone"   value={customer.phone}           />
            <InfoRow label="Email"   value={customer.email ?? '—'}    />
            <InfoRow label="Address" value={customer.address ?? '—'}  />
            {customer.notes && <InfoRow label="Notes" value={customer.notes} />}
          </div>
        </div>

        {/* Note panel */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          {customer.notes && !isEditing ? (
            /*  Has a note, view mode  */
            <>
              <div className="flex items-center justify-between mb-3">
                <h3 className="text-sm font-semibold text-zinc-200">Note</h3>
                <div className="flex items-center gap-1.5">
                  <Btn
                    variant="ghost"
                    size="xs"
                    onClick={() => { setNote(customer.notes ?? ''); setIsEditing(true) }}
                  >
                    <IconEdit width="12" height="12" /> Edit
                  </Btn>
                  <Btn
                    variant="ghost"
                    size="xs"
                    disabled={updateNoteMutation.isPending}
                    onClick={() => updateNoteMutation.mutate(null)}
                    className="text-red-400 hover:text-red-300"
                  >
                    <IconTrash width="12" height="12" /> Delete
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
                {isEditing ? 'Edit Note' : 'Add Note'}
              </h3>
              <div className="space-y-2">
                <textarea
                  value={note}
                  onChange={e => setNote(e.target.value)}
                  rows={3}
                  placeholder="Add a note about this customer…"
                  className="w-full bg-zinc-800 border border-zinc-700 rounded-xl text-zinc-100 placeholder-zinc-600 text-sm focus:outline-none focus:border-amber-500 focus:ring-1 focus:ring-amber-500/20 transition-all py-2.5 px-3 resize-none"
                />
                <div className="flex gap-2">
                  <Btn
                    size="sm"
                    disabled={!note.trim() || updateNoteMutation.isPending}
                    onClick={() => updateNoteMutation.mutate(note.trim())}
                  >
                    <IconPlus width="12" height="12" />
                    {updateNoteMutation.isPending ? 'Saving…' : isEditing ? 'Save Note' : 'Add Note'}
                  </Btn>
                  {isEditing && (
                    <Btn
                      size="sm"
                      variant="ghost"
                      onClick={() => { setNote(''); setIsEditing(false) }}
                    >
                      Cancel
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
            title="No activity yet"
            subtitle="Transactions and notes will appear here"
          />
        </div>
      ) : (
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <div className="flex items-center justify-between mb-3">
            <h3 className="text-sm font-semibold text-zinc-200">Recent Activity</h3>
            <Btn variant="ghost" size="xs" onClick={() => navigate(`/app/customers/${id}/ledger`)}>
              View all
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
