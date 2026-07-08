import { useNavigate, useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { fmt, fmtDate, fmtDateTime } from '@/lib/utils'
import { Badge, Table, Th, Td, Spinner, SectionHeader, Btn } from '@/components/ui'
import { procurementService } from '@/services/procurement/procurement.service'
import { useLocaleStore } from '@/i18n/localeStore'

export default function GoodsReceiptDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const t = useLocaleStore(s => s.t)

  const { data: receipt, isLoading } = useQuery({
    queryKey: ['goods-receipt', id],
    queryFn: () => procurementService.getReceipt(id!),
    enabled: !!id,
  })

  if (isLoading) return <div className="flex items-center justify-center h-40"><Spinner size={32} /></div>

  if (!receipt) {
    return (
      <div className="p-6 text-center text-zinc-500">
        {t('procurement.receipt_not_found')}{' '}
        <button onClick={() => navigate('/app/procurement/receipts')} className="text-amber-400 hover:underline">
          {t('procurement.back_to_receipts')}
        </button>
      </div>
    )
  }

  const totalValue = receipt.items.reduce((sum, item) => sum + parseFloat(item.line_total), 0)

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <SectionHeader
        title={receipt.receipt_number}
        subtitle={`${t('procurement.goods_receipt')} · ${fmtDate(receipt.receipt_date)}`}
        action={
          <Btn
            variant="secondary"
            size="sm"
            onClick={() => navigate(`/app/procurement/purchase-orders/${receipt.purchase_order_id}`)}
          >
            {t('procurement.view_po')}
          </Btn>
        }
      />

      <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-5">
        {/* Summary */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div className="bg-zinc-900 rounded-2xl border border-zinc-800 p-4 space-y-3">
            <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.receipt_info')}</h3>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-zinc-500">{t('settings.status')}</dt>
                <dd>
                  <Badge variant={receipt.status === 'RECEIVED' ? 'success' : 'danger'} size="xs" dot>
                    {receipt.status}
                  </Badge>
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-zinc-500">{t('procurement.receipt_date')}</dt>
                <dd className="text-zinc-200">{fmtDate(receipt.receipt_date)}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-zinc-500">{t('procurement.received_by')}</dt>
                <dd className="text-zinc-200">{receipt.received_by_name ?? '—'}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-zinc-500">{t('procurement.col_created')}</dt>
                <dd className="text-zinc-400">{fmtDateTime(receipt.created_at)}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-zinc-500">{t('procurement.purchase_order')}</dt>
                <dd>
                  <button
                    onClick={() => navigate(`/app/procurement/purchase-orders/${receipt.purchase_order_id}`)}
                    className="text-amber-400 hover:underline font-mono text-xs"
                  >
                    {receipt.purchase_order_id.slice(0, 8)}…
                  </button>
                </dd>
              </div>
              {receipt.notes && (
                <div className="pt-2 border-t border-zinc-800">
                  <dt className="text-zinc-500 mb-1">{t('procurement.notes')}</dt>
                  <dd className="text-zinc-400 text-xs">{receipt.notes}</dd>
                </div>
              )}
            </dl>
          </div>

          <div className="bg-zinc-900 rounded-2xl border border-zinc-800 p-4 space-y-3">
            <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.inventory_impact')}</h3>
            <p className="text-xs text-zinc-500">
              {t('procurement.inventory_impact_desc')}
            </p>
            <dl className="space-y-2 text-sm">
              <div className="flex justify-between">
                <dt className="text-zinc-500">{t('procurement.items_received')}</dt>
                <dd className="text-zinc-200">{receipt.items.length}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-zinc-500">{t('procurement.total_quantity')}</dt>
                <dd className="font-mono text-zinc-200">
                  {receipt.items.reduce((s, i) => s + parseFloat(i.received_quantity), 0).toFixed(2)}
                </dd>
              </div>
              <div className="flex justify-between border-t border-zinc-700 pt-2">
                <dt className="text-zinc-400 font-medium">{t('procurement.total_value')}</dt>
                <dd className="font-mono font-bold text-amber-400">{fmt(totalValue)}</dd>
              </div>
            </dl>
          </div>
        </div>

        {/* Items */}
        <div className="bg-zinc-900 rounded-2xl border border-zinc-800 overflow-hidden">
          <div className="px-4 py-3 border-b border-zinc-800">
            <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.received_items')} ({receipt.items.length})</h3>
          </div>
          <Table>
            <thead>
              <tr>
                <Th>{t('procurement.product')}</Th>
                <Th right>{t('procurement.quantity')}</Th>
                <Th right>{t('procurement.unit_cost')}</Th>
                <Th right>{t('procurement.line_total')}</Th>
              </tr>
            </thead>
            <tbody>
              {receipt.items.map(item => (
                <tr key={item.id} className="hover:bg-zinc-800/40 transition-colors">
                  <Td>
                    {item.product_name
                      ? <span className="text-sm text-zinc-200">{item.product_name}</span>
                      : <span className="text-xs font-mono text-zinc-500">{item.purchase_order_item_id.slice(0, 8)}…</span>
                    }
                  </Td>
                  <Td right><span className="font-mono text-green-400">{item.received_quantity}</span></Td>
                  <Td right><span className="font-mono">{fmt(item.unit_cost)}</span></Td>
                  <Td right><span className="font-mono text-amber-400">{fmt(item.line_total)}</span></Td>
                </tr>
              ))}
            </tbody>
          </Table>
        </div>
      </div>
    </div>
  )
}
