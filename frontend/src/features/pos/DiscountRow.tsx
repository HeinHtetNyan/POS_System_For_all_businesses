import { useState } from 'react'
import { useCartStore, useCartTotals } from '@/store/cartStore'
import { IconDiscount, IconX, IconCheck } from '@/components/icons'
import { cn } from '@/lib/utils'

export default function DiscountRow() {
  const discount     = useCartStore(s => s.discount)
  const discountType = useCartStore(s => s.discountType)
  const setDiscount     = useCartStore(s => s.setDiscount)
  const setDiscountType = useCartStore(s => s.setDiscountType)
  const totals = useCartTotals()

  const [expanded, setExpanded] = useState(false)
  const [inputVal, setInputVal] = useState(discount > 0 ? String(discount) : '')
  const [localType, setLocalType] = useState<'percent' | 'amount'>(discountType)

  function handleApply() {
    const parsed = parseFloat(inputVal)
    let clamped: number
    if (isNaN(parsed) || parsed < 0) {
      clamped = 0
    } else if (localType === 'percent') {
      clamped = Math.min(100, parsed)
    } else {
      clamped = Math.min(totals.itemSubtotal + totals.orderDiscAmt, parsed)
    }
    setDiscount(clamped)
    setDiscountType(localType)
    setExpanded(false)
  }

  function handleOpen() {
    setInputVal(discount > 0 ? String(discount) : '')
    setLocalType(discountType)
    setExpanded(true)
  }

  function handleClose() {
    setExpanded(false)
  }

  function discountLabel(): string {
    if (discount <= 0) return ''
    if (discountType === 'percent') return `${discount}%`
    return `${discount.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Kyats`
  }

  if (!expanded) {
    return (
      <button
        onClick={handleOpen}
        className="flex items-center gap-1.5 text-xs text-zinc-500 hover:text-amber-400 transition-colors py-1"
      >
        <IconDiscount width="13" height="13" />
        {discount > 0 ? (
          <span className="text-amber-400 font-semibold">Discount: {discountLabel()}</span>
        ) : (
          <span>Add discount</span>
        )}
      </button>
    )
  }

  return (
    <div className="flex items-center gap-1.5">
      <IconDiscount width="13" height="13" className="text-zinc-500 flex-shrink-0" />
      <div className="flex items-center gap-1 flex-1">
        {/* Type toggle */}
        <div className="flex rounded-lg border border-zinc-700 overflow-hidden flex-shrink-0">
          <button
            onClick={() => setLocalType('percent')}
            className={cn(
              'px-2 py-1 text-xs font-semibold transition-colors',
              localType === 'percent' ? 'bg-amber-500 text-black' : 'bg-zinc-800 text-zinc-400 hover:text-zinc-100',
            )}
          >
            %
          </button>
          <button
            onClick={() => setLocalType('amount')}
            className={cn(
              'px-2 py-1 text-xs font-semibold transition-colors',
              localType === 'amount' ? 'bg-amber-500 text-black' : 'bg-zinc-800 text-zinc-400 hover:text-zinc-100',
            )}
          >
            Ks
          </button>
        </div>

        <div className="relative flex items-center flex-1">
          <input
            type="number"
            min={0}
            max={localType === 'percent' ? 100 : undefined}
            value={inputVal}
            onChange={e => setInputVal(e.target.value)}
            onKeyDown={e => {
              if (e.key === 'Enter') handleApply()
              if (e.key === 'Escape') handleClose()
            }}
            placeholder="0"
            autoFocus
            className={cn(
              'w-full bg-zinc-800 border border-zinc-700 rounded-lg text-zinc-100 text-xs font-mono',
              'focus:outline-none focus:border-amber-500 focus:ring-1 focus:ring-amber-500/20',
              'py-1.5 pl-2 pr-6 transition-all duration-150',
            )}
          />
          <span className="absolute right-2 text-zinc-500 text-xs pointer-events-none">
            {localType === 'percent' ? '%' : 'Ks'}
          </span>
        </div>
        <button
          onClick={handleApply}
          className="w-7 h-7 rounded-lg bg-amber-500 hover:bg-amber-400 flex items-center justify-center transition-colors text-black flex-shrink-0"
          aria-label="Apply discount"
        >
          <IconCheck width="12" height="12" />
        </button>
        <button
          onClick={handleClose}
          className="w-7 h-7 rounded-lg bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 flex items-center justify-center transition-colors text-zinc-400 hover:text-zinc-100 flex-shrink-0"
          aria-label="Cancel"
        >
          <IconX width="12" height="12" />
        </button>
      </div>
    </div>
  )
}
