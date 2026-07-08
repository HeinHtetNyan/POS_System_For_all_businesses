import { useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { extractApiMsg } from '@/lib/utils'
import { Badge, Btn } from '@/components/ui'
import {
  resellerFinanceService,
  type PayoutRequestResponse,
} from '@/services/reseller_finance/reseller_finance.service'
import { useLocaleStore } from '@/i18n/localeStore'

const PAYOUT_STATUS_VARIANT: Record<string, 'default' | 'warning' | 'success' | 'danger' | 'info'> = {
  PENDING: 'warning',
  UNDER_REVIEW: 'info',
  APPROVED: 'success',
  PAID: 'success',
  REJECTED: 'danger',
  CANCELLED: 'default',
}

const TX_TYPE_LABEL_KEY: Record<string, string> = {
  COMMISSION_EARNED: 'reseller.tx_commission',
  COMMISSION_REVERSAL: 'reseller.tx_commission_reversal',
  PAYOUT_LOCKED: 'reseller.tx_payout_reserved',
  PAYOUT_REJECTED: 'reseller.tx_payout_released',
  PAYOUT_COMPLETED: 'reseller.tx_payout_paid',
  MANUAL_ADJUSTMENT: 'reseller.tx_adjustment',
  BONUS: 'reseller.tx_bonus',
  PENALTY: 'reseller.tx_penalty',
}

function fmt(amount: string): string {
  return Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function RequestPayoutModal({ wallet, onClose }: { wallet: { available_balance: string; min_payout_amount: string; currency_code: string }; onClose: () => void }) {
  const t = useLocaleStore(s => s.t)
  const qc = useQueryClient()
  const [amount, setAmount] = useState('')
  const [reason, setReason] = useState('')

  const mutation = useMutation({
    mutationFn: () => resellerFinanceService.requestPayout({ amount, reason: reason || undefined }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['reseller', 'wallet'] })
      qc.invalidateQueries({ queryKey: ['reseller', 'payouts'] })
      toast.success(t('reseller.payout_requested'))
      onClose()
    },
    onError: err => toast.error(extractApiMsg(err) ?? t('reseller.failed_request_payout')),
  })

  const available = Number(wallet.available_balance)
  const min = Number(wallet.min_payout_amount)
  const requested = Number(amount)
  const isValid = requested > 0 && requested <= available && requested >= min

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
      <div className="bg-zinc-950 border border-zinc-800 rounded-2xl w-full max-w-md p-6 space-y-4">
        <h2 className="text-lg font-bold text-zinc-100">{t('reseller.request_payout_title')}</h2>
        <div className="bg-zinc-900 rounded-xl p-3 text-sm space-y-1">
          <div className="flex justify-between">
            <span className="text-zinc-500">{t('reseller.available_label')}</span>
            <span className="text-zinc-200 font-mono">{fmt(wallet.available_balance)} {wallet.currency_code}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-zinc-500">{t('reseller.minimum_label')}</span>
            <span className="text-zinc-400 font-mono">{fmt(wallet.min_payout_amount)} {wallet.currency_code}</span>
          </div>
        </div>
        <div>
          <label className="text-xs text-zinc-400 mb-1 block">{t('reseller.amount_label')}</label>
          <input
            type="number"
            value={amount}
            onChange={e => setAmount(e.target.value)}
            placeholder={`${t('reseller.min_prefix')} ${fmt(wallet.min_payout_amount)}`}
            className="w-full bg-zinc-900 border border-zinc-700 rounded-xl px-3 py-2 text-sm text-zinc-100 focus:outline-none focus:border-orange-500"
          />
        </div>
        <div>
          <label className="text-xs text-zinc-400 mb-1 block">{t('reseller.reason_optional_label')}</label>
          <textarea
            value={reason}
            onChange={e => setReason(e.target.value)}
            rows={2}
            className="w-full bg-zinc-900 border border-zinc-700 rounded-xl px-3 py-2 text-sm text-zinc-100 focus:outline-none focus:border-orange-500 resize-none"
          />
        </div>
        <div className="flex gap-3 justify-end">
          <Btn variant="ghost" size="sm" onClick={onClose}>{t('common.cancel')}</Btn>
          <Btn size="sm" onClick={() => mutation.mutate()} loading={mutation.isPending} disabled={!isValid}>
            {t('reseller.request_btn')}
          </Btn>
        </div>
      </div>
    </div>
  )
}

export default function ResellerWalletPage() {
  const t = useLocaleStore(s => s.t)
  const [showRequest, setShowRequest] = useState(false)
  const [txPage, setTxPage] = useState(1)
  const [payoutPage, setPayoutPage] = useState(1)

  const qc = useQueryClient()

  const { data: wallet, isLoading: walletLoading } = useQuery({
    queryKey: ['reseller', 'wallet'],
    queryFn: resellerFinanceService.getMyWallet,
    staleTime: 30_000,
  })

  const { data: transactions, isLoading: txLoading } = useQuery({
    queryKey: ['reseller', 'wallet-transactions', txPage],
    queryFn: () => resellerFinanceService.listMyTransactions({ page: txPage, page_size: 20 }),
    staleTime: 30_000,
  })

  const { data: payouts, isLoading: payoutsLoading } = useQuery({
    queryKey: ['reseller', 'payouts', payoutPage],
    queryFn: () => resellerFinanceService.listMyPayouts({ page: payoutPage, page_size: 10 }),
    staleTime: 30_000,
  })

  const cancelPayout = useMutation({
    mutationFn: (id: string) => resellerFinanceService.cancelPayout(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['reseller', 'payouts'] })
      qc.invalidateQueries({ queryKey: ['reseller', 'wallet'] })
      toast.success(t('reseller.payout_cancelled'))
    },
    onError: err => toast.error(extractApiMsg(err) ?? t('reseller.failed_cancel')),
  })

  const available = wallet ? Number(wallet.available_balance) : 0
  const canRequest = wallet && available >= Number(wallet.min_payout_amount)

  return (
    <div className="h-full overflow-y-auto p-6 space-y-8">
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-2xl font-bold text-zinc-100">{t('reseller.wallet_payouts_title')}</h1>
          <p className="text-zinc-500 text-sm mt-1">{t('reseller.wallet_payouts_subtitle')}</p>
        </div>
        <Btn size="sm" disabled={!canRequest} onClick={() => setShowRequest(true)}>
          {t('reseller.request_payout_title')}
        </Btn>
      </div>

      {/* Wallet cards */}
      {walletLoading ? (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {[1,2,3,4].map(i => (
            <div key={i} className="bg-zinc-900 border border-zinc-800 rounded-2xl p-5 animate-pulse h-24" />
          ))}
        </div>
      ) : wallet ? (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-5">
            <p className="text-xs text-zinc-500 mb-1">{t('reseller.available_label')}</p>
            <p className="text-2xl font-bold text-green-400 tabular-nums">{fmt(wallet.available_balance)}</p>
            <p className="text-xs text-zinc-600 mt-1">{wallet.currency_code}</p>
          </div>
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-5">
            <p className="text-xs text-zinc-500 mb-1">{t('reseller.locked_label')}</p>
            <p className="text-2xl font-bold text-amber-400 tabular-nums">{fmt(wallet.locked_balance)}</p>
            <p className="text-xs text-zinc-600 mt-1">{t('reseller.pending_payout_label')}</p>
          </div>
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-5">
            <p className="text-xs text-zinc-500 mb-1">{t('reseller.total_paid_out')}</p>
            <p className="text-2xl font-bold text-zinc-100 tabular-nums">{fmt(wallet.total_paid_out)}</p>
            <p className="text-xs text-zinc-600 mt-1">{t('reseller.all_time')}</p>
          </div>
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-5">
            <p className="text-xs text-zinc-500 mb-1">{t('reseller.commission_rate_label')}</p>
            <p className="text-2xl font-bold text-orange-400 tabular-nums">{Number(wallet.commission_rate_pct).toFixed(2)}%</p>
            <p className="text-xs text-zinc-600 mt-1">{t('reseller.per_paid_subscription')}</p>
          </div>
        </div>
      ) : (
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-8 text-center">
          <p className="text-zinc-500 text-sm">{t('reseller.no_wallet_yet')}</p>
        </div>
      )}

      {/* Payout requests */}
      <div>
        <h2 className="text-xs font-semibold text-zinc-500 uppercase tracking-wider mb-3">{t('reseller.payout_requests_heading')}</h2>
        {payoutsLoading ? (
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 animate-pulse h-24" />
        ) : !payouts || payouts.items.length === 0 ? (
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 text-center">
            <p className="text-zinc-600 text-sm">{t('reseller.no_payout_requests')}</p>
          </div>
        ) : (
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-zinc-800">
                  <th className="text-left px-4 py-3 text-xs text-zinc-500 font-medium">{t('reseller.amount_label')}</th>
                  <th className="text-left px-4 py-3 text-xs text-zinc-500 font-medium">{t('settings.status')}</th>
                  <th className="text-left px-4 py-3 text-xs text-zinc-500 font-medium">{t('reseller.reason_column')}</th>
                  <th className="text-left px-4 py-3 text-xs text-zinc-500 font-medium">{t('reseller.date_column')}</th>
                  <th className="text-left px-4 py-3 text-xs text-zinc-500 font-medium"></th>
                </tr>
              </thead>
              <tbody>
                {payouts.items.map((p: PayoutRequestResponse) => (
                  <tr key={p.id} className="border-b border-zinc-800/50 last:border-0">
                    <td className="px-4 py-3 font-mono font-bold text-zinc-100">{fmt(p.amount)} <span className="text-zinc-600 font-normal text-xs">{p.currency_code}</span></td>
                    <td className="px-4 py-3">
                      <Badge variant={PAYOUT_STATUS_VARIANT[p.status] ?? 'default'} size="xs">{p.status}</Badge>
                    </td>
                    <td className="px-4 py-3 text-zinc-500 text-xs max-w-[180px] truncate">{p.reason ?? '—'}</td>
                    <td className="px-4 py-3 text-zinc-600 text-xs">{new Date(p.created_at).toLocaleDateString()}</td>
                    <td className="px-4 py-3">
                      {p.status === 'PENDING' && (
                        <button
                          onClick={() => cancelPayout.mutate(p.id)}
                          disabled={cancelPayout.isPending}
                          className="text-xs text-red-400 hover:text-red-300 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
                        >
                          {cancelPayout.isPending ? t('reseller.cancelling') : t('common.cancel')}
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {(payouts.total ?? 0) > 10 && (
              <div className="flex items-center justify-between px-4 py-3 border-t border-zinc-800">
                <Btn variant="ghost" size="xs" disabled={payoutPage === 1} onClick={() => setPayoutPage(p => p - 1)}>{t('reseller.prev_arrow')}</Btn>
                <span className="text-xs text-zinc-600">{payoutPage}</span>
                <Btn variant="ghost" size="xs" disabled={payoutPage * 10 >= (payouts.total ?? 0)} onClick={() => setPayoutPage(p => p + 1)}>{t('reseller.next_arrow')}</Btn>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Transaction ledger */}
      <div>
        <h2 className="text-xs font-semibold text-zinc-500 uppercase tracking-wider mb-3">{t('reseller.transaction_ledger_heading')}</h2>
        {txLoading ? (
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 animate-pulse h-32" />
        ) : !transactions || transactions.items.length === 0 ? (
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 text-center">
            <p className="text-zinc-600 text-sm">{t('reseller.no_transactions')}</p>
          </div>
        ) : (
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-zinc-800">
                  <th className="text-left px-4 py-3 text-xs text-zinc-500 font-medium">{t('reseller.type_column')}</th>
                  <th className="text-right px-4 py-3 text-xs text-zinc-500 font-medium">{t('reseller.amount_label')}</th>
                  <th className="text-left px-4 py-3 text-xs text-zinc-500 font-medium">{t('reseller.note_column')}</th>
                  <th className="text-left px-4 py-3 text-xs text-zinc-500 font-medium">{t('reseller.date_column')}</th>
                </tr>
              </thead>
              <tbody>
                {transactions.items.map(tx => {
                  // `amount` is always stored as a positive magnitude regardless
                  // of direction — the only reliable signal for credit vs debit
                  // is whether the balance actually went up or down.
                  const isCredit = Number(tx.balance_after) >= Number(tx.balance_before)
                  return (
                    <tr key={tx.id} className="border-b border-zinc-800/50 last:border-0">
                      <td className="px-4 py-3 text-zinc-300 text-xs">{TX_TYPE_LABEL_KEY[tx.transaction_type] ? t(TX_TYPE_LABEL_KEY[tx.transaction_type]) : tx.transaction_type}</td>
                      <td className={`px-4 py-3 font-mono text-right font-bold ${isCredit ? 'text-green-400' : 'text-red-400'}`}>
                        {isCredit ? '+' : '-'}{fmt(tx.amount)}
                      </td>
                      <td className="px-4 py-3 text-zinc-600 text-xs max-w-[200px] truncate">{tx.notes ?? '—'}</td>
                      <td className="px-4 py-3 text-zinc-600 text-xs">{new Date(tx.created_at).toLocaleDateString()}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
            {(transactions.total ?? 0) > 20 && (
              <div className="flex items-center justify-between px-4 py-3 border-t border-zinc-800">
                <Btn variant="ghost" size="xs" disabled={txPage === 1} onClick={() => setTxPage(p => p - 1)}>{t('reseller.prev_arrow')}</Btn>
                <span className="text-xs text-zinc-600">{txPage}</span>
                <Btn variant="ghost" size="xs" disabled={txPage * 20 >= (transactions.total ?? 0)} onClick={() => setTxPage(p => p + 1)}>{t('reseller.next_arrow')}</Btn>
              </div>
            )}
          </div>
        )}
      </div>

      {showRequest && wallet && (
        <RequestPayoutModal wallet={wallet} onClose={() => setShowRequest(false)} />
      )}
    </div>
  )
}
