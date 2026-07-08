import { fmt } from '@/lib/utils'
import { useLocaleStore } from '@/i18n/localeStore'

const BILLS = [5, 10, 20, 50, 100, 200, 500]

interface QuickBillsProps {
  total: number
  onSelect: (v: string) => void
}

export default function QuickBills({ total, onSelect }: QuickBillsProps) {
  const t = useLocaleStore(s => s.t)
  const exactOption = { label: t('payment.exact'), value: total.toFixed(2), isExact: true }
  const billOptions = BILLS.filter(b => b >= total).map(b => ({
    label: fmt(b),
    value: b.toFixed(2),
    isExact: false,
  }))

  const options = [exactOption, ...billOptions].slice(0, 5)

  return (
    <div className="flex gap-2 flex-wrap">
      {options.map(opt => (
        <button
          key={opt.label}
          onClick={() => onSelect(opt.value)}
          className={`
            flex-1 min-w-[60px] h-9 rounded-xl text-xs font-semibold font-mono transition-all duration-100
            active:scale-95 border
            ${opt.isExact
              ? 'bg-zinc-700 hover:bg-zinc-600 border-zinc-600 text-zinc-100'
              : 'bg-zinc-900 hover:bg-zinc-800 border-zinc-800 text-zinc-300 hover:text-zinc-100'
            }
          `}
        >
          {opt.label}
        </button>
      ))}
    </div>
  )
}
