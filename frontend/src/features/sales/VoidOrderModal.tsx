import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { checkoutService } from '@/services/sales/sales.service'
import { invalidateSalesMutationQueries } from '@/lib/salesQueryInvalidation'
import { Btn } from '@/components/ui'
import { IconAlert, IconX } from '@/components/icons'
import type { Order } from '@/shared/types'

interface Props {
  order: Order
  onClose: () => void
  onSuccess?: (order: Order) => void
}

export default function VoidOrderModal({ order, onClose, onSuccess }: Props) {
  const qc = useQueryClient()
  const [reason, setReason] = useState('')

  const mutation = useMutation({
    mutationFn: () => checkoutService.voidOrder(order.id, { reason: reason.trim() }),
    onSuccess: voided => {
      toast.success(`Order ${voided.order_number} voided`)
      invalidateSalesMutationQueries(qc)
      if (voided.customer_id) {
        qc.invalidateQueries({ queryKey: ['customer', voided.customer_id] })
        qc.invalidateQueries({ queryKey: ['customer-ledger', voided.customer_id] })
        qc.invalidateQueries({ queryKey: ['customer-statement', voided.customer_id] })
        qc.invalidateQueries({ queryKey: ['customers'] })
      }
      onSuccess?.(voided)
      onClose()
    },
    onError: (err: any) => {
      const msg = err?.response?.data?.error?.message ?? err?.response?.data?.detail ?? 'Failed to void order.'
      toast.error(msg)
    },
  })

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-md shadow-2xl flex flex-col">
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800">
          <div className="flex items-center gap-2">
            <IconAlert width="16" height="16" className="text-red-400" />
            <h2 className="text-sm font-semibold text-zinc-100">Void Order</h2>
          </div>
          <button onClick={onClose} className="text-zinc-500 hover:text-zinc-300">
            <IconX width="16" height="16" />
          </button>
        </div>

        <div className="px-5 py-4 flex flex-col gap-3">
          <p className="text-xs text-zinc-400">
            Voiding <span className="text-amber-400 font-medium">{order.order_number}</span> permanently
            cancels this sale, restores inventory, and marks any payments as refunded. This cannot be undone.
          </p>
          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-medium text-zinc-400">Reason (required)</label>
            <textarea
              value={reason}
              onChange={e => setReason(e.target.value)}
              placeholder="e.g. Duplicate sale entered by mistake"
              rows={3}
              className="w-full rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-2 text-sm text-zinc-100 placeholder-zinc-600 focus:outline-none focus:border-amber-500 resize-none"
            />
          </div>
        </div>

        <div className="flex gap-3 px-5 py-4 border-t border-zinc-800">
          <Btn variant="secondary" fullWidth onClick={onClose}>Cancel</Btn>
          <Btn
            variant="danger"
            fullWidth
            loading={mutation.isPending}
            disabled={reason.trim().length === 0}
            onClick={() => mutation.mutate()}
          >
            Void Order
          </Btn>
        </div>
      </div>
    </div>
  )
}
