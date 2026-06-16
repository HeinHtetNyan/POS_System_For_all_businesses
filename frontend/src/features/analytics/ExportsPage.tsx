import { useState } from 'react'
import { format, startOfMonth, endOfMonth } from 'date-fns'
import { toast } from 'sonner'
import { analyticsService } from '@/services/analytics/analytics.service'
import { useAnalyticsFilters, AnalyticsFilters } from './analyticsHelpers'
import { Btn, Spinner } from '@/components/ui'
import { useTenantStore } from '@/store/tenant.store'

function triggerDownload(blob: Blob, filename: string) {
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

function ExportCard({
  title,
  description,
  columns,
  exports,
}: {
  title: string
  description: string
  columns: { label: string; cols: string[] }[]
  exports: { label: string; loading: boolean; onClick: () => void }[]
}) {
  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden">
      <div className="px-5 py-4 border-b border-zinc-800">
        <h3 className="text-sm font-semibold text-zinc-100">{title}</h3>
        <p className="text-xs text-zinc-500 mt-1">{description}</p>
      </div>

      <div className="px-5 py-4 space-y-4">
        {/* Column previews */}
        {columns.map(group => (
          <div key={group.label}>
            <p className="text-[10px] font-semibold text-zinc-600 uppercase tracking-wider mb-2">
              {group.label}
            </p>
            <div className="flex flex-wrap gap-1.5">
              {group.cols.map(col => (
                <span
                  key={col}
                  className="px-2 py-0.5 rounded-md bg-zinc-800 border border-zinc-700/60 text-zinc-400 text-[10px] font-mono"
                >
                  {col}
                </span>
              ))}
            </div>
          </div>
        ))}

        {/* Export buttons */}
        <div className="flex flex-wrap gap-2 pt-1">
          {exports.map(exp => (
            <Btn
              key={exp.label}
              variant="secondary"
              size="sm"
              onClick={exp.onClick}
              disabled={exp.loading}
            >
              {exp.loading
                ? <><Spinner size={14} /> Generating…</>
                : <>↓ {exp.label}</>
              }
            </Btn>
          ))}
        </div>
      </div>
    </div>
  )
}

export default function ExportsPage() {
  const filters = useAnalyticsFilters()
  const { from, to, branch, apiParams } = filters
  const { availableBranches } = useTenantStore()

  const [loadingSalesRefunds, setLoadingSalesRefunds] = useState(false)
  const [loadingOrders, setLoadingOrders]             = useState(false)

  // Default to current month if no date range selected
  const effectiveFrom = from || format(startOfMonth(new Date()), 'yyyy-MM-dd')
  const effectiveTo   = to   || format(endOfMonth(new Date()), 'yyyy-MM-dd')

  const effectiveParams = {
    ...apiParams,
    start_date: effectiveFrom,
    end_date:   effectiveTo,
  }

  function buildFilename(prefix: string) {
    const branchName = branch
      ? (availableBranches.find(b => b.id === branch)?.name ?? branch)
      : 'all'
    return `${prefix}_${effectiveFrom}_${effectiveTo}_${branchName}.csv`
  }

  async function handleSalesRefunds() {
    setLoadingSalesRefunds(true)
    try {
      const blob = await analyticsService.exportSalesRefunds(effectiveParams)
      triggerDownload(blob, buildFilename('sales_refunds'))
    } catch {
      toast.error('Export failed. Please try again.')
    } finally {
      setLoadingSalesRefunds(false)
    }
  }

  async function handleOrders() {
    setLoadingOrders(true)
    try {
      const blob = await analyticsService.exportOrders(effectiveParams)
      triggerDownload(blob, buildFilename('orders'))
    } catch {
      toast.error('Export failed. Please try again.')
    } finally {
      setLoadingOrders(false)
    }
  }

  return (
    <div className="p-4 sm:p-6 space-y-5">
      {/* Header */}
      <div className="flex flex-col gap-3">
        <div>
          <h2 className="text-base font-semibold text-zinc-100">Data Exports</h2>
          <p className="text-xs text-zinc-500 mt-0.5">
            Download CSV files for the selected period. Files open directly in Google Sheets or Excel.
            Each file includes a <span className="text-zinc-300 font-medium">TOTAL row</span> at the bottom.
          </p>
        </div>
        {/* Filters */}
        <AnalyticsFilters {...filters} />
        {/* Active period indicator */}
        <div className="flex items-center gap-2 text-xs text-zinc-500">
          <span className="w-1.5 h-1.5 rounded-full bg-amber-500 flex-shrink-0" />
          Exporting: <span className="text-zinc-300 font-mono">{effectiveFrom}</span>
          <span>→</span>
          <span className="text-zinc-300 font-mono">{effectiveTo}</span>
          {branch && availableBranches.length > 0 && (
            <>
              <span className="text-zinc-700">·</span>
              <span className="text-zinc-300">{availableBranches.find(b => b.id === branch)?.name ?? 'Branch'}</span>
            </>
          )}
        </div>
      </div>

      {/* Export cards */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ExportCard
          title="Sales & Refunds"
          description="Complete transaction record — sales orders followed by refund detail. One TOTAL row at the bottom of each section."
          columns={[
            {
              label: 'Sales columns',
              cols: ['Order Number', 'Date', 'Branch', 'Cashier', 'Customer',
                     'Subtotal', 'Discount', 'Tax', 'Total', 'Payment Methods',
                     'Status', 'Refunded Amount', 'Net Amount'],
            },
            {
              label: 'Refunds columns',
              cols: ['Refund Number', 'Refund Date', 'Original Order', 'Branch',
                     'Customer', 'Product', 'Qty', 'Line Refund Amount',
                     'Total Refund Amount', 'Reason', 'Type', 'Processed By'],
            },
          ]}
          exports={[
            {
              label: 'Export Sales & Refunds CSV',
              loading: loadingSalesRefunds,
              onClick: handleSalesRefunds,
            },
          ]}
        />

        <ExportCard
          title="Order Line Items"
          description="Every order expanded into per-product rows. Ideal for COGS, margin, and product-level analysis."
          columns={[
            {
              label: 'Columns',
              cols: ['Order Number', 'Order Date', 'Branch', 'Cashier', 'Customer',
                     'Product', 'Variant', 'SKU', 'Qty',
                     'Unit Price', 'Unit Cost', 'Discount', 'Tax Rate',
                     'Line Subtotal', 'Line Total', 'Order Total',
                     'Payment Methods', 'Order Status'],
            },
          ]}
          exports={[
            {
              label: 'Export Orders CSV',
              loading: loadingOrders,
              onClick: handleOrders,
            },
          ]}
        />
      </div>

      {/* Help note */}
      <div className="rounded-xl bg-zinc-900 border border-zinc-800 px-4 py-3 text-xs text-zinc-500 space-y-1">
        <p className="font-medium text-zinc-400">How to open in Google Sheets</p>
        <p>File → Import → Upload → select the .csv file → "Replace spreadsheet" → Import data.</p>
        <p className="font-medium text-zinc-400 pt-1">How to open in Excel</p>
        <p>Double-click the .csv file, or File → Open. Encoding is automatically detected (UTF-8).</p>
      </div>
    </div>
  )
}
