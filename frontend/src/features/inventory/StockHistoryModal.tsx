import { useQuery } from '@tanstack/react-query'
import { useLocaleStore } from '@/i18n/localeStore'
import { inventoryService } from '@/services/inventory/inventory.service'
import { Modal, Spinner, Empty } from '@/components/ui'
import { fmtDateTime } from '@/lib/utils'
import type { InventoryItem, StockMovement, PaginatedResponse } from '@/shared/types'

interface Props {
  item: InventoryItem
  branchId: string
  productName: string
  productSku: string
  onClose: () => void
}

const TYPE_INFO: Record<string, { key: string; color: string }> = {
  SALE:                { key: 'inventory.type.sale',                color: 'text-red-400'    },
  REFUND:              { key: 'inventory.type.cash_refund',         color: 'text-blue-400'   },
  REPLACEMENT:         { key: 'inventory.type.replacement',         color: 'text-violet-400' },
  PURCHASE:            { key: 'inventory.type.purchase',            color: 'text-green-400'  },
  PURCHASE_RECEIPT:    { key: 'inventory.type.purchase',            color: 'text-green-400'  },
  MANUAL_CORRECTION:   { key: 'inventory.type.manual_adjust',       color: 'text-amber-400'  },
  OPENING_STOCK:       { key: 'inventory.type.opening_stock',       color: 'text-purple-400' },
  TRANSFER_IN:         { key: 'inventory.type.transfer_in',         color: 'text-cyan-400'   },
  TRANSFER_OUT:        { key: 'inventory.type.transfer_out',        color: 'text-orange-400' },
  ADJUSTMENT_INCREASE: { key: 'inventory.type.adjustment_increase', color: 'text-amber-400'  },
  ADJUSTMENT_DECREASE: { key: 'inventory.type.adjustment_decrease', color: 'text-amber-400'  },
  DAMAGE:              { key: 'inventory.type.damage',              color: 'text-red-400'    },
  RETURN_TO_SUPPLIER:  { key: 'inventory.type.return',              color: 'text-orange-400' },
  LOSS:                { key: 'inventory.type.loss',                color: 'text-red-400'    },
}

const OUTBOUND_TYPES = new Set([
  'SALE', 'REPLACEMENT', 'TRANSFER_OUT', 'DAMAGE',
  'ADJUSTMENT_DECREASE', 'RETURN_TO_SUPPLIER', 'LOSS',
])

function typeInfo(t: (key: string) => string, type: string) {
  const info = TYPE_INFO[type]
  return info ? { label: t(info.key), color: info.color } : { label: type.replace(/_/g, ' '), color: 'text-zinc-400' }
}

export default function StockHistoryModal({ item, branchId, productName, productSku, onClose }: Props) {
  const t = useLocaleStore(s => s.t)
  const { data, isLoading } = useQuery({
    queryKey: ['stock-movements', branchId, item.product_id],
    queryFn: () =>
      inventoryService.getBranchMovements(branchId, {
        product_id: item.product_id,
        page_size: 200,
      }) as Promise<PaginatedResponse<StockMovement>>,
    staleTime: 0,
  })

  const movements: StockMovement[] = data?.items ?? []

  return (
    <Modal open onClose={onClose} title={t('inventory.stock_history')} size="lg">
      {/* Product header */}
      <div className="flex items-center justify-between bg-zinc-900 border border-zinc-800 rounded-xl px-4 py-3 mb-4">
        <div>
          <p className="text-sm font-semibold text-zinc-100">{productName}</p>
          <p className="text-xs font-mono text-zinc-500">{productSku}</p>
        </div>
        <div className="text-right">
          <p className="text-xs text-zinc-500">{t('inventory.available_now')}</p>
          <p className="text-sm font-mono font-bold text-amber-400">
            {Math.round(parseFloat(item.quantity_available))}
          </p>
        </div>
      </div>

      {/* Movements list */}
      {isLoading ? (
        <div className="flex justify-center py-10"><Spinner size={28} /></div>
      ) : movements.length === 0 ? (
        <Empty title={t('inventory.no_history_found')} subtitle={t('inventory.no_history_subtitle')} />
      ) : (
        <div className="flex flex-col divide-y divide-zinc-800 max-h-[420px] overflow-y-auto -mx-6 px-6">
          {movements.map(mv => {
            const qty        = parseFloat(mv.quantity)
            const prevQty    = parseFloat(mv.previous_quantity)
            const newQty     = parseFloat(mv.new_quantity)
            const isOutbound = OUTBOUND_TYPES.has(mv.movement_type)
            const info       = typeInfo(t, mv.movement_type)
            return (
              <div key={mv.id} className="py-3 flex gap-3">
                {/* Delta badge */}
                <div className={`flex-shrink-0 w-14 text-center rounded-lg px-1 py-1 text-xs font-mono font-bold border ${
                  isOutbound
                    ? 'bg-red-950 border-red-800 text-red-400'
                    : 'bg-green-950 border-green-800 text-green-400'
                }`}>
                  {isOutbound ? '−' : '+'}{Math.round(qty)}
                </div>

                {/* Detail */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className={`text-xs font-semibold ${info.color}`}>{info.label}</span>
                    {mv.reference_type && (
                      <span className="text-[10px] text-zinc-600 font-mono">{mv.reference_type}</span>
                    )}
                  </div>
                  {/* Stock level change */}
                  <p className="text-xs text-zinc-500 mt-0.5">
                    <span className="font-mono">{Math.round(prevQty)}</span>
                    <span className="mx-1 text-zinc-700">→</span>
                    <span className="font-mono font-semibold text-zinc-300">{Math.round(newQty)}</span>
                  </p>
                  {mv.reason && (
                    <p className="text-xs text-zinc-400 mt-0.5">{mv.reason}</p>
                  )}
                  {mv.notes && (
                    <p className="text-xs text-zinc-500 mt-0.5 italic">"{mv.notes}"</p>
                  )}
                </div>

                {/* Date + Actor */}
                <div className="flex-shrink-0 text-right">
                  <p className="text-[10px] text-zinc-600 whitespace-nowrap">{fmtDateTime(mv.created_at)}</p>
                  {mv.actor_name && (
                    <p className="text-[10px] text-zinc-500 whitespace-nowrap mt-0.5">{t('inventory.by')} {mv.actor_name}</p>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}

      {!isLoading && movements.length > 0 && (
        <p className="text-xs text-zinc-600 mt-3 text-right">{movements.length} {t('inventory.records')}</p>
      )}
    </Modal>
  )
}
