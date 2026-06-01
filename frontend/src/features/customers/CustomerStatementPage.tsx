import { useState } from 'react'
import { useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { fmt, fmtDate, fmtDateTime, cn } from '@/lib/utils'
import { Spinner, StatCard, Table, Th, Td, Badge, Empty, Btn, Modal } from '@/components/ui'
import { customersService } from '@/services/customers/customers.service'
import { checkoutService } from '@/services/sales/sales.service'
import type { LedgerEntry, Order } from '@/shared/types'

interface MergedRow {
  id: string
  date?: string
  orderId?: string
  description: string
  totalAmount: number
  paid: number
  remaining: number
  isSale: boolean
  type: string
}

function buildMergedRows(entries: LedgerEntry[]): MergedRow[] {
  const saleRefs = new Set(
    entries.filter(e => e.type === 'SALE' && e.reference).map(e => e.reference as string)
  )

  const paymentsByRef: Record<string, LedgerEntry[]> = {}
  for (const e of entries) {
    if (e.type === 'PAYMENT' && e.reference && saleRefs.has(e.reference)) {
      if (!paymentsByRef[e.reference]) paymentsByRef[e.reference] = []
      paymentsByRef[e.reference].push(e)
    }
  }

  const rows: MergedRow[] = []
  for (const entry of entries) {
    if (entry.type === 'SALE') {
      const matched = entry.reference ? (paymentsByRef[entry.reference] ?? []) : []
      const paid = matched.reduce((s, p) => s + parseFloat(p.credit ?? '0'), 0)
      const lastMatch = matched[matched.length - 1]
      rows.push({
        id: entry.id,
        date: entry.date,
        orderId: entry.reference ?? undefined,
        description: entry.description ?? 'Sale',
        totalAmount: parseFloat(entry.debit ?? '0'),
        paid,
        remaining: parseFloat(lastMatch?.balance ?? entry.balance ?? '0'),
        isSale: true,
        type: 'SALE',
      })
    } else if (entry.type === 'PAYMENT') {
      // skip checkout-time payments already merged into a SALE row
      if (entry.reference && saleRefs.has(entry.reference)) continue
      rows.push({
        id: entry.id,
        date: entry.date,
        orderId: undefined,
        description: entry.description ?? 'Debt Payment',
        totalAmount: 0,
        paid: parseFloat(entry.credit ?? '0'),
        remaining: parseFloat(entry.balance ?? '0'),
        isSale: false,
        type: 'PAYMENT',
      })
    } else if (entry.type === 'CREDIT_NOTE') {
      rows.push({
        id: entry.id,
        date: entry.date,
        orderId: entry.reference ?? undefined,
        description: entry.description ?? 'Credit Note',
        totalAmount: 0,
        paid: parseFloat(entry.credit ?? '0'),
        remaining: parseFloat(entry.balance ?? '0'),
        isSale: false,
        type: 'CREDIT_NOTE',
      })
    } else {
      rows.push({
        id: entry.id,
        date: entry.date,
        orderId: entry.reference ?? undefined,
        description: entry.description ?? entry.type,
        totalAmount: parseFloat(entry.debit ?? '0'),
        paid: parseFloat(entry.credit ?? '0'),
        remaining: parseFloat(entry.balance ?? '0'),
        isSale: false,
        type: entry.type,
      })
    }
  }
  // Newest first
  return rows.sort((a, b) => {
    const da = a.date ? new Date(a.date).getTime() : 0
    const db = b.date ? new Date(b.date).getTime() : 0
    return db - da
  })
}

const ROW_BADGE: Record<string, 'warning' | 'success' | 'purple' | 'info' | 'default'> = {
  SALE: 'warning',
  PAYMENT: 'success',
  CREDIT_NOTE: 'purple',
  ADJUSTMENT: 'info',
}

function OrderDetailModal({ orderId, onClose }: { orderId: string; onClose: () => void }) {
  const { data: order, isLoading } = useQuery<Order>({
    queryKey: ['order-detail', orderId],
    queryFn: () => checkoutService.getOrder(orderId),
    enabled: !!orderId,
  })

  return (
    <Modal open onClose={onClose} title="Order Details">
      {isLoading && (
        <div className="flex items-center justify-center h-32">
          <Spinner size={28} />
        </div>
      )}
      {!isLoading && !order && (
        <p className="text-sm text-zinc-500 text-center py-6">Order not found.</p>
      )}
      {order && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs text-zinc-500 uppercase tracking-wider">Order Number</p>
              <p className="font-mono font-semibold text-zinc-100">{order.order_number}</p>
              {order.branch_name && (
                <p className="text-xs text-blue-400 mt-0.5 font-medium">{order.branch_name}</p>
              )}
            </div>
            <div className="text-right">
              <p className="text-xs text-zinc-500">{order.created_at ? fmtDateTime(order.created_at) : '—'}</p>
              <div className="flex gap-1 justify-end mt-1">
                <Badge variant={order.order_status === 'COMPLETED' ? 'success' : 'warning'} size="xs">
                  {order.order_status}
                </Badge>
                <Badge variant={order.payment_status === 'PAID' ? 'success' : order.payment_status === 'PARTIAL' ? 'warning' : 'default'} size="xs">
                  {order.payment_status}
                </Badge>
              </div>
            </div>
          </div>

          {(order.items ?? []).length > 0 && (
            <div className="bg-zinc-800/50 rounded-xl overflow-hidden">
              <div className="px-3 py-2 border-b border-zinc-700/50">
                <p className="text-xs font-medium text-zinc-400 uppercase tracking-wider">Items</p>
              </div>
              <div className="divide-y divide-zinc-700/30">
                {(order.items ?? []).map(item => (
                  <div key={item.id} className="flex items-center justify-between px-3 py-2.5 gap-3">
                    <div className="min-w-0">
                      <p className="text-sm text-zinc-200 truncate">{item.product_name}</p>
                      {item.variant_name && (
                        <p className="text-xs text-zinc-500">{item.variant_name}</p>
                      )}
                    </div>
                    <div className="text-right flex-shrink-0">
                      <p className="text-xs text-zinc-500">{item.quantity} × {fmt(item.unit_price)}</p>
                      <p className="text-sm font-mono text-zinc-200">{fmt(item.total)}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          <div className="bg-zinc-800/50 rounded-xl px-3 py-3 space-y-1.5">
            <div className="flex justify-between text-sm">
              <span className="text-zinc-500">Subtotal</span>
              <span className="font-mono text-zinc-300">{fmt(order.subtotal)}</span>
            </div>
            {parseFloat(String(order.discount_amount)) > 0 && (
              <div className="flex justify-between text-sm">
                <span className="text-zinc-500">Discount</span>
                <span className="font-mono text-green-400">−{fmt(order.discount_amount)}</span>
              </div>
            )}
            {parseFloat(String(order.tax_amount)) > 0 && (
              <div className="flex justify-between text-sm">
                <span className="text-zinc-500">Tax</span>
                <span className="font-mono text-zinc-300">{fmt(order.tax_amount)}</span>
              </div>
            )}
            <div className="flex justify-between text-sm font-semibold border-t border-zinc-700 pt-1.5 mt-1.5">
              <span className="text-zinc-200">Total</span>
              <span className="font-mono text-amber-400">{fmt(order.total_amount)}</span>
            </div>
          </div>

          <Btn variant="secondary" fullWidth onClick={onClose}>Close</Btn>
        </div>
      )}
    </Modal>
  )
}

const PAGE_SIZE = 30

export default function CustomerStatementPage() {
  const { id } = useParams<{ id: string }>()
  const [selectedOrderId, setSelectedOrderId] = useState<string | null>(null)
  const [page, setPage] = useState(1)

  const { data: statement, isLoading: stmtLoading } = useQuery({
    queryKey: ['customer-statement', id],
    queryFn: () => customersService.getStatement(id!),
    enabled: !!id,
  })

  const { data: ledgerData, isLoading: ledgerLoading } = useQuery({
    queryKey: ['customer-ledger', id, 1],
    queryFn: () => customersService.getLedger(id!, { page: 1 }),
    enabled: !!id,
  })

  const isLoading = stmtLoading || ledgerLoading

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-40">
        <Spinner size={28} />
      </div>
    )
  }

  const allEntries: LedgerEntry[] = ledgerData?.items ?? []
  const rows = buildMergedRows(allEntries)
  const totalPages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE))
  const paginatedRows = rows.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  const now = new Date()
  const currentMonth = now.getMonth()
  const currentYear  = now.getFullYear()

  const monthlyCharges = allEntries
    .filter(e => {
      if (e.type !== 'SALE' || !e.debit || !e.date) return false
      const d = new Date(e.date)
      return d.getMonth() === currentMonth && d.getFullYear() === currentYear
    })
    .reduce((sum, e) => sum + parseFloat(e.debit ?? '0'), 0)

  const monthlyPayments = allEntries
    .filter(e => {
      if ((e.type !== 'PAYMENT' && e.type !== 'CREDIT_NOTE') || !e.credit || !e.date) return false
      const d = new Date(e.date)
      return d.getMonth() === currentMonth && d.getFullYear() === currentYear
    })
    .reduce((sum, e) => sum + parseFloat(e.credit ?? '0'), 0)

  return (
    <div className="p-4 sm:p-6 space-y-4">
      {selectedOrderId && (
        <OrderDetailModal orderId={selectedOrderId} onClose={() => setSelectedOrderId(null)} />
      )}

      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h3 className="text-sm font-semibold text-zinc-200">Customer Statement</h3>
          {statement?.generated_at && (
            <p className="text-xs text-zinc-500 mt-0.5">
              Generated {fmtDateTime(statement.generated_at)}
            </p>
          )}
        </div>
      </div>

      {/* Summary cards — charges & payments are this month; debt is all-time */}
      <div className="grid grid-cols-3 gap-3">
        <StatCard label="Charges (This Month)"  value={fmt(monthlyCharges)} />
        <StatCard label="Payments (This Month)" value={fmt(monthlyPayments)} />
        {statement?.closing_balance != null && (
          <StatCard
            label="Remaining Debt"
            value={fmt(statement.closing_balance)}
            accent={parseFloat(statement.closing_balance) > 0}
          />
        )}
      </div>

      {/* Transactions */}
      {rows.length === 0 ? (
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <Empty title="No transactions yet" subtitle="Transactions will appear here after orders are created" />
        </div>
      ) : (
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden">
          <div className="px-4 py-3 border-b border-zinc-800">
            <h3 className="text-sm font-semibold text-zinc-200">
              Transactions ({rows.length})
            </h3>
          </div>
          <Table>
            <thead>
              <tr>
                <Th>Date</Th>
                <Th>Type</Th>
                <Th>Description</Th>
                <Th right>Total Amount</Th>
                <Th right>Paid</Th>
                <Th right>Remaining</Th>
              </tr>
            </thead>
            <tbody>
              {paginatedRows.map(row => (
                <tr
                  key={row.id}
                  onClick={() => row.orderId ? setSelectedOrderId(row.orderId) : undefined}
                  className={cn(
                    'transition-colors',
                    row.orderId
                      ? 'cursor-pointer hover:bg-amber-500/5 hover:border-l-2 border-amber-500/0'
                      : 'hover:bg-zinc-800/40',
                  )}
                >
                  <Td muted>{row.date ? fmtDate(row.date) : '—'}</Td>
                  <Td>
                    <Badge variant={ROW_BADGE[row.type] ?? 'default'} size="xs">
                      {row.type === 'SALE' ? 'SALE' : row.type === 'PAYMENT' ? 'DEBT PMT' : row.type}
                    </Badge>
                  </Td>
                  <Td>
                    <span className={cn(row.orderId ? 'text-amber-400 hover:underline' : 'text-zinc-300')}>
                      {row.description}
                    </span>
                    {row.orderId && (
                      <span className="ml-1.5 text-zinc-600 text-xs">↗</span>
                    )}
                  </Td>
                  <Td right>
                    {row.totalAmount > 0
                      ? <span className="font-mono text-amber-400">{fmt(row.totalAmount)}</span>
                      : <span className="text-zinc-700">—</span>}
                  </Td>
                  <Td right>
                    {row.paid > 0
                      ? <span className="font-mono text-green-400">{fmt(row.paid)}</span>
                      : <span className="text-zinc-700">—</span>}
                  </Td>
                  <Td right>
                    <span className={cn(
                      'font-mono font-semibold',
                      row.remaining > 0 ? 'text-amber-400' : 'text-zinc-400',
                    )}>
                      {fmt(row.remaining)}
                    </span>
                  </Td>
                </tr>
              ))}
            </tbody>
          </Table>
          <div className="px-4 py-2.5 border-t border-zinc-800 flex items-center justify-between gap-3">
            <p className="text-xs text-zinc-500">
              {rows.length === 0 ? '0 transactions' : `${(page - 1) * PAGE_SIZE + 1}–${Math.min(page * PAGE_SIZE, rows.length)} of ${rows.length}`}
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
      )}
    </div>
  )
}
