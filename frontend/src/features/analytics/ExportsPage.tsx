import { useState } from 'react'
import { format, startOfMonth } from 'date-fns'
import { toast } from 'sonner'
import { analyticsService } from '@/services/analytics/analytics.service'
import { useAnalyticsFilters, AnalyticsFilters } from './analyticsHelpers'
import { Btn, Spinner } from '@/components/ui'
import { useTenantStore } from '@/store/tenant.store'
import { useLocaleStore } from '@/i18n/localeStore'

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
  exports: { label: string; loading: boolean; onClick: () => void; variant?: 'csv' | 'xlsx' }[]
}) {
  const t = useLocaleStore(s => s.t)
  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden">
      <div className="px-5 py-4 border-b border-zinc-800">
        <h3 className="text-sm font-semibold text-zinc-100">{title}</h3>
        <p className="text-xs text-zinc-500 mt-1">{description}</p>
      </div>
      <div className="px-5 py-4 space-y-4">
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
        <div className="flex flex-wrap gap-2 pt-1">
          {exports.map(exp => (
            <Btn
              key={exp.label}
              variant={exp.variant === 'xlsx' ? 'primary' : 'secondary'}
              size="sm"
              onClick={exp.onClick}
              disabled={exp.loading}
            >
              {exp.loading
                ? <><Spinner size={14} /> {t('analytics.generating')}</>
                : exp.variant === 'xlsx'
                  ? <>⬇ {exp.label}</>
                  : <>↓ {exp.label}</>
              }
            </Btn>
          ))}
        </div>
      </div>
    </div>
  )
}

function SectionHeader({ label }: { label: string }) {
  return (
    <div className="flex items-center gap-3 pt-2">
      <span className="text-xs font-bold text-zinc-400 uppercase tracking-widest">{label}</span>
      <div className="flex-1 h-px bg-zinc-800" />
    </div>
  )
}

type LoadingKey =
  | 'salesCsv' | 'salesXlsx'
  | 'ordersCsv' | 'ordersXlsx'
  | 'topProdCsv' | 'topProdXlsx'
  | 'cashierCsv' | 'cashierXlsx'
  | 'catCsv' | 'catXlsx'
  | 'pmCsv' | 'pmXlsx'
  | 'trendCsv' | 'trendXlsx'
  | 'profitCsv' | 'profitXlsx'
  | 'invCsv' | 'invXlsx'
  | 'lowCsv' | 'lowXlsx'
  | 'fastCsv' | 'fastXlsx'
  | 'deadCsv' | 'deadXlsx'
  | 'moveCsv' | 'moveXlsx'
  | 'custCsv' | 'custXlsx'
  | 'poCsv' | 'poXlsx'
  | 'grCsv' | 'grXlsx'
  | 'spCsv' | 'spXlsx'

export default function ExportsPage() {
  const t = useLocaleStore(s => s.t)
  const filters = useAnalyticsFilters()
  const { from, to, branch, apiParams } = filters
  const { availableBranches } = useTenantStore()

  const [loading, setLoading] = useState<Partial<Record<LoadingKey, boolean>>>({})
  const setL = (key: LoadingKey, val: boolean) =>
    setLoading(prev => ({ ...prev, [key]: val }))

  const effectiveFrom = from || format(startOfMonth(new Date()), 'yyyy-MM-dd')
  const effectiveTo   = to   || format(new Date(), 'yyyy-MM-dd')

  const effectiveParams = {
    ...apiParams,
    start_date: effectiveFrom,
    end_date:   effectiveTo,
  }

  function buildFilename(prefix: string, fmt: 'csv' | 'xlsx') {
    const branchName = branch
      ? (availableBranches.find(b => b.id === branch)?.name ?? branch)
      : 'all'
    return `${prefix}_${effectiveFrom}_${effectiveTo}_${branchName}.${fmt}`
  }

  async function handle(key: LoadingKey, fn: () => Promise<Blob>, filename: string) {
    setL(key, true)
    try {
      const blob = await fn()
      triggerDownload(blob, filename)
    } catch {
      toast.error(t('analytics.export_failed_toast'))
    } finally {
      setL(key, false)
    }
  }

  const branchParam = branch ? { branch_id: branch } : {}

  return (
    <div className="p-4 sm:p-6 space-y-5">
      {/* Header */}
      <div className="flex flex-col gap-3">
        <div>
          <h2 className="text-base font-semibold text-zinc-100">{t('analytics.data_exports_title')}</h2>
          <p className="text-xs text-zinc-500 mt-0.5">
            {t('analytics.export_desc_part1')}<span className="text-emerald-400 font-medium">{t('analytics.excel_xlsx_label')}</span>{t('analytics.export_desc_part2')}{' '}
            <span className="text-zinc-300 font-medium">{t('analytics.total_row_label')}</span>{t('analytics.export_desc_part3')}
          </p>
        </div>
        <AnalyticsFilters {...filters} />
        <div className="flex items-center gap-2 text-xs text-zinc-500">
          <span className="w-1.5 h-1.5 rounded-full bg-amber-500 flex-shrink-0" />
          {t('analytics.exporting_label')} <span className="text-zinc-300 font-mono">{effectiveFrom}</span>
          <span>→</span>
          <span className="text-zinc-300 font-mono">{effectiveTo}</span>
          {branch && availableBranches.length > 0 && (
            <>
              <span className="text-zinc-700">·</span>
              <span className="text-zinc-300">
                {availableBranches.find(b => b.id === branch)?.name ?? t('analytics.field_branch')}
              </span>
            </>
          )}
        </div>
      </div>

      {/* SALES DATA */}
      <SectionHeader label={t('analytics.section_sales_data')} />
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ExportCard
          title={t('analytics.export_sales_refunds_title')}
          description={t('analytics.export_sales_refunds_desc')}
          columns={[
            {
              label: t('analytics.col_group_sales'),
              cols: [t('analytics.field_order_number'), t('analytics.field_date'), t('analytics.field_branch'), t('analytics.field_cashier'), t('analytics.customer'),
                     t('analytics.field_subtotal'), t('analytics.field_discount'), t('analytics.field_tax'), t('analytics.field_total'), t('analytics.payment_methods'),
                     t('products.col.status'), t('analytics.field_refunded_amount'), t('analytics.field_net_amount')],
            },
            {
              label: t('analytics.col_group_refunds'),
              cols: [t('analytics.field_refund_number'), t('analytics.field_refund_date'), t('analytics.field_original_order'), t('analytics.field_branch'),
                     t('analytics.customer'), t('products.col.product'), t('analytics.field_qty'), t('analytics.field_line_refund_amount'),
                     t('analytics.field_total_refund_amount'), t('analytics.field_reason'), t('products.detail.type'), t('analytics.field_processed_by')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.salesCsv,
              onClick: () => handle('salesCsv',
                () => analyticsService.exportSalesRefunds({ ...effectiveParams, format: 'csv' }),
                buildFilename('sales_refunds', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.salesXlsx,
              onClick: () => handle('salesXlsx',
                () => analyticsService.exportSalesRefunds({ ...effectiveParams, format: 'xlsx' }),
                buildFilename('sales_refunds', 'xlsx')),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.export_order_line_items_title')}
          description={t('analytics.export_order_line_items_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_order_number'), t('analytics.field_order_date'), t('analytics.field_branch'), t('analytics.field_cashier'), t('analytics.customer'),
                     t('products.col.product'), t('analytics.field_variant'), t('products.col.sku'), t('analytics.field_qty'),
                     t('analytics.field_unit_price'), t('analytics.field_unit_cost'), t('analytics.field_discount'), t('analytics.field_tax_rate'),
                     t('analytics.field_line_subtotal'), t('analytics.field_line_total'), t('analytics.field_order_total'),
                     t('analytics.payment_methods'), t('analytics.field_order_status')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.ordersCsv,
              onClick: () => handle('ordersCsv',
                () => analyticsService.exportOrders({ ...effectiveParams, format: 'csv' }),
                buildFilename('orders', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.ordersXlsx,
              onClick: () => handle('ordersXlsx',
                () => analyticsService.exportOrders({ ...effectiveParams, format: 'xlsx' }),
                buildFilename('orders', 'xlsx')),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.top_products')}
          description={t('analytics.export_top_products_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_rank'), t('products.col.product'), t('products.col.sku'), t('analytics.field_units_sold'), t('analytics.field_revenue'),
                     t('analytics.field_avg_unit_price'), t('analytics.field_profit_estimate'), t('analytics.field_margin_pct')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.topProdCsv,
              onClick: () => handle('topProdCsv',
                () => analyticsService.exportTopProducts({ ...effectiveParams, format: 'csv' }),
                buildFilename('top_products', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.topProdXlsx,
              onClick: () => handle('topProdXlsx',
                () => analyticsService.exportTopProducts({ ...effectiveParams, format: 'xlsx' }),
                buildFilename('top_products', 'xlsx')),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.sales_by_cashier')}
          description={t('analytics.export_sales_by_cashier_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_cashier'), t('analytics.field_orders'), t('analytics.field_gross_sales'), t('analytics.refunds'), t('analytics.field_net_sales'), t('analytics.field_avg_order_value')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.cashierCsv,
              onClick: () => handle('cashierCsv',
                () => analyticsService.exportSalesByCashier({ ...effectiveParams, format: 'csv' }),
                buildFilename('sales_by_cashier', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.cashierXlsx,
              onClick: () => handle('cashierXlsx',
                () => analyticsService.exportSalesByCashier({ ...effectiveParams, format: 'xlsx' }),
                buildFilename('sales_by_cashier', 'xlsx')),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.sales_by_category')}
          description={t('analytics.export_sales_by_category_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('products.col.category'), t('analytics.field_units_sold'), t('analytics.field_revenue'), t('analytics.field_share_pct'), t('analytics.field_profit_estimate')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.catCsv,
              onClick: () => handle('catCsv',
                () => analyticsService.exportSalesByCategory({ ...effectiveParams, format: 'csv' }),
                buildFilename('sales_by_category', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.catXlsx,
              onClick: () => handle('catXlsx',
                () => analyticsService.exportSalesByCategory({ ...effectiveParams, format: 'xlsx' }),
                buildFilename('sales_by_category', 'xlsx')),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.payment_methods')}
          description={t('analytics.export_payment_methods_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_payment_method'), t('analytics.field_transactions'), t('analytics.field_total_amount'), t('analytics.field_share_pct')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.pmCsv,
              onClick: () => handle('pmCsv',
                () => analyticsService.exportPaymentMethods({ ...effectiveParams, format: 'csv' }),
                buildFilename('payment_methods', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.pmXlsx,
              onClick: () => handle('pmXlsx',
                () => analyticsService.exportPaymentMethods({ ...effectiveParams, format: 'xlsx' }),
                buildFilename('payment_methods', 'xlsx')),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.sales_trend_daily_title')}
          description={t('analytics.export_sales_trend_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_period'), t('analytics.field_orders'), t('analytics.field_gross_sales'), t('analytics.field_net_revenue')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.trendCsv,
              onClick: () => handle('trendCsv',
                () => analyticsService.exportSalesTrend({ ...effectiveParams, granularity: 'daily', format: 'csv' }),
                buildFilename('sales_trend_daily', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.trendXlsx,
              onClick: () => handle('trendXlsx',
                () => analyticsService.exportSalesTrend({ ...effectiveParams, granularity: 'daily', format: 'xlsx' }),
                buildFilename('sales_trend_daily', 'xlsx')),
            },
          ]}
        />
      </div>

      {/* FINANCIAL */}
      <SectionHeader label={t('analytics.tab_financial')} />
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ExportCard
          title={t('analytics.profit_report')}
          description={t('analytics.export_profit_report_desc')}
          columns={[
            {
              label: t('analytics.col_group_profit_sheets'),
              cols: [t('analytics.field_dimension'), t('analytics.field_revenue'), t('analytics.field_cogs'), t('analytics.field_gross_profit'), t('analytics.field_margin_pct')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.profitCsv,
              onClick: () => handle('profitCsv',
                () => analyticsService.exportProfitReport({ ...effectiveParams, format: 'csv' }),
                buildFilename('profit_report', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.profitXlsx,
              onClick: () => handle('profitXlsx',
                () => analyticsService.exportProfitReport({ ...effectiveParams, format: 'xlsx' }),
                buildFilename('profit_report', 'xlsx')),
            },
          ]}
        />
      </div>

      {/* INVENTORY */}
      <SectionHeader label={t('nav.inventory')} />
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ExportCard
          title={t('analytics.export_inventory_stocks_title')}
          description={t('analytics.export_inventory_stocks_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_branch'), t('products.col.category'), t('products.col.product'), t('analytics.field_variant'), t('products.col.sku'),
                     t('analytics.field_on_hand'), t('analytics.field_reserved'), t('analytics.field_available'),
                     t('analytics.field_reorder_point'), t('analytics.field_reorder_qty'),
                     t('analytics.field_unit_cost'), t('analytics.field_stock_value'), t('analytics.field_last_movement')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.invCsv,
              onClick: () => handle('invCsv',
                () => analyticsService.exportInventoryStocks({ ...branchParam, format: 'csv' }),
                `inventory_stocks_${branch ? (availableBranches.find(b => b.id === branch)?.name ?? branch) : 'all'}.csv`),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.invXlsx,
              onClick: () => handle('invXlsx',
                () => analyticsService.exportInventoryStocks({ ...branchParam, format: 'xlsx' }),
                `inventory_stocks_${branch ? (availableBranches.find(b => b.id === branch)?.name ?? branch) : 'all'}.xlsx`),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.low_stock_items')}
          description={t('analytics.export_low_stock_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_branch'), t('products.col.product'), t('products.col.sku'), t('analytics.field_on_hand'), t('analytics.field_reorder_point'), t('analytics.field_shortage')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.lowCsv,
              onClick: () => handle('lowCsv',
                () => analyticsService.exportLowStock({ ...branchParam, format: 'csv' }),
                `low_stock_${branch ? (availableBranches.find(b => b.id === branch)?.name ?? branch) : 'all'}.csv`),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.lowXlsx,
              onClick: () => handle('lowXlsx',
                () => analyticsService.exportLowStock({ ...branchParam, format: 'xlsx' }),
                `low_stock_${branch ? (availableBranches.find(b => b.id === branch)?.name ?? branch) : 'all'}.xlsx`),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.fast_moving_products')}
          description={t('analytics.export_fast_moving_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_rank'), t('products.col.product'), t('products.col.sku'), t('analytics.field_units_sold'), t('analytics.field_order_count')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.fastCsv,
              onClick: () => handle('fastCsv',
                () => analyticsService.exportFastMoving({ ...effectiveParams, format: 'csv' }),
                buildFilename('fast_moving', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.fastXlsx,
              onClick: () => handle('fastXlsx',
                () => analyticsService.exportFastMoving({ ...effectiveParams, format: 'xlsx' }),
                buildFilename('fast_moving', 'xlsx')),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.dead_stock')}
          description={t('analytics.export_dead_stock_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('products.col.product'), t('products.col.sku'), t('analytics.field_on_hand'), t('analytics.field_last_sold'), t('analytics.field_days_without_sale')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.deadCsv,
              onClick: () => handle('deadCsv',
                () => analyticsService.exportDeadStock({ ...branchParam, days: 90, format: 'csv' }),
                `dead_stock_90d_${branch ? (availableBranches.find(b => b.id === branch)?.name ?? branch) : 'all'}.csv`),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.deadXlsx,
              onClick: () => handle('deadXlsx',
                () => analyticsService.exportDeadStock({ ...branchParam, days: 90, format: 'xlsx' }),
                `dead_stock_90d_${branch ? (availableBranches.find(b => b.id === branch)?.name ?? branch) : 'all'}.xlsx`),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.stock_movements')}
          description={t('analytics.export_stock_movements_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_date'), t('analytics.field_branch'), t('products.col.product'), t('analytics.field_variant'), t('products.col.sku'),
                     t('analytics.field_movement_type'), t('analytics.field_qty_change'), t('analytics.field_unit_cost'), t('analytics.field_movement_value'),
                     t('analytics.field_reference_type'), t('analytics.field_reason'), t('analytics.field_notes')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.moveCsv,
              onClick: () => handle('moveCsv',
                () => analyticsService.exportStockMovements({ ...effectiveParams, format: 'csv' }),
                buildFilename('stock_movements', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.moveXlsx,
              onClick: () => handle('moveXlsx',
                () => analyticsService.exportStockMovements({ ...effectiveParams, format: 'xlsx' }),
                buildFilename('stock_movements', 'xlsx')),
            },
          ]}
        />
      </div>

      {/* CUSTOMERS */}
      <SectionHeader label={t('qa.customers')} />
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ExportCard
          title={t('analytics.customer_list_title')}
          description={t('analytics.export_customer_list_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_code'), t('analytics.field_name'), t('settings.phone'), t('settings.email'), t('analytics.field_gender'),
                     t('analytics.field_balance'), t('analytics.field_credit_limit'), t('analytics.field_total_orders'), t('analytics.field_total_spent'),
                     t('products.col.status'), t('analytics.field_member_since')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.custCsv,
              onClick: () => handle('custCsv',
                () => analyticsService.exportCustomers({ format: 'csv' }),
                'customers_all.csv'),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.custXlsx,
              onClick: () => handle('custXlsx',
                () => analyticsService.exportCustomers({ format: 'xlsx' }),
                'customers_all.xlsx'),
            },
          ]}
        />
      </div>

      {/* PROCUREMENT */}
      <SectionHeader label={t('qa.procurement')} />
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <ExportCard
          title={t('analytics.purchase_orders_title')}
          description={t('analytics.export_purchase_orders_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_po_number'), t('analytics.field_order_date'), t('analytics.field_supplier'), t('analytics.field_branch'), t('products.col.status'),
                     t('products.col.product'), t('analytics.field_variant'), t('products.col.sku'),
                     t('analytics.field_ordered_qty'), t('analytics.field_received_qty'), t('analytics.field_unit_cost'), t('analytics.field_line_total'),
                     t('analytics.field_expected_date'), t('analytics.field_notes')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.poCsv,
              onClick: () => handle('poCsv',
                () => analyticsService.exportPurchaseOrders({ start_date: effectiveFrom, end_date: effectiveTo, format: 'csv' }),
                buildFilename('purchase_orders', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.poXlsx,
              onClick: () => handle('poXlsx',
                () => analyticsService.exportPurchaseOrders({ start_date: effectiveFrom, end_date: effectiveTo, format: 'xlsx' }),
                buildFilename('purchase_orders', 'xlsx')),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.goods_receipts_title')}
          description={t('analytics.export_goods_receipts_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_receipt_number'), t('analytics.field_receipt_date'), t('analytics.field_po_reference'), t('analytics.field_supplier'), t('analytics.field_branch'), t('products.col.status'),
                     t('products.col.product'), t('analytics.field_variant'), t('products.col.sku'),
                     t('analytics.field_received_qty'), t('analytics.field_unit_cost'), t('analytics.field_line_total'), t('analytics.field_notes')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.grCsv,
              onClick: () => handle('grCsv',
                () => analyticsService.exportGoodsReceipts({ start_date: effectiveFrom, end_date: effectiveTo, format: 'csv' }),
                buildFilename('goods_receipts', 'csv')),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.grXlsx,
              onClick: () => handle('grXlsx',
                () => analyticsService.exportGoodsReceipts({ start_date: effectiveFrom, end_date: effectiveTo, format: 'xlsx' }),
                buildFilename('goods_receipts', 'xlsx')),
            },
          ]}
        />

        <ExportCard
          title={t('analytics.supplier_payables_title')}
          description={t('analytics.export_supplier_payables_desc')}
          columns={[
            {
              label: t('analytics.col_group_columns'),
              cols: [t('analytics.field_supplier'), t('analytics.field_po_number'), t('analytics.field_po_date'), t('analytics.field_branch'),
                     t('analytics.field_invoice_amount'), t('analytics.field_paid_amount'), t('analytics.field_remaining_amount'), t('products.col.status')],
            },
          ]}
          exports={[
            {
              label: t('analytics.csv_label'),
              variant: 'csv',
              loading: !!loading.spCsv,
              onClick: () => handle('spCsv',
                () => analyticsService.exportSupplierPayables({ format: 'csv' }),
                'supplier_payables_all.csv'),
            },
            {
              label: t('analytics.excel_xlsx_label'),
              variant: 'xlsx',
              loading: !!loading.spXlsx,
              onClick: () => handle('spXlsx',
                () => analyticsService.exportSupplierPayables({ format: 'xlsx' }),
                'supplier_payables_all.xlsx'),
            },
          ]}
        />
      </div>

      {/* Help note */}
      <div className="rounded-xl bg-zinc-900 border border-zinc-800 px-4 py-3 text-xs text-zinc-500 space-y-1">
        <p className="font-medium text-zinc-400">{t('analytics.help_google_sheets_title')}</p>
        <p>{t('analytics.help_google_sheets_body')}</p>
        <p className="font-medium text-zinc-400 pt-1">{t('analytics.help_xlsx_title')}</p>
        <p>{t('analytics.help_xlsx_body')}</p>
        <p className="font-medium text-zinc-400 pt-1">{t('analytics.help_csv_title')}</p>
        <p>{t('analytics.help_csv_body')}</p>
      </div>
    </div>
  )
}
