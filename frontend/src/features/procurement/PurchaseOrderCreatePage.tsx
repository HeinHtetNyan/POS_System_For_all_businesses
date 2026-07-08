import { useState, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { useForm, useFieldArray, Controller } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { fmt, extractApiMsg } from '@/lib/utils'
import { Btn, Spinner, SectionHeader } from '@/components/ui'
import { procurementService } from '@/services/procurement/procurement.service'
import { productsService } from '@/services/products/products.service'
import { useTenantStore } from '@/store/tenant.store'
import { ScannerInputCapture, ProductScannerModal, lookupProductByBarcode } from '@/scanner'
import { ProductFormModal } from '@/features/products/ProductFormModal'
import { inputCls, FormField } from './procurementHelpers'
import { useLocaleStore } from '@/i18n/localeStore'
import type { Product } from '@/shared/types'

const makeItemSchema = (t: (key: string) => string) => z.object({
  product_id:        z.string().min(1, t('procurement.validation_product_required')),
  product_name:      z.string(),
  ordered_quantity:  z.string().min(1).refine(v => parseFloat(v) > 0, t('procurement.validation_must_be_positive')),
  unit_cost:         z.string().min(1).refine(v => parseFloat(v) >= 0, t('procurement.validation_must_be_non_negative')),
})

const makeSchema = (t: (key: string) => string) => z.object({
  supplier_id:   z.string().min(1, t('procurement.validation_supplier_required')),
  branch_id:     z.string().min(1, t('procurement.validation_branch_required')),
  order_date:    z.string().min(1, t('procurement.validation_order_date_required')),
  expected_date: z.string(),
  notes:         z.string(),
  items:         z.array(makeItemSchema(t)).min(1, t('procurement.validation_add_at_least_one_item')),
})

type FormValues = z.infer<ReturnType<typeof makeSchema>>

// Modal shown when a scan returns no matching product
function ProductNotFoundModal({
  code,
  onAddNew,
  onCancel,
}: {
  code: string
  onAddNew: () => void
  onCancel: () => void
}) {
  const t = useLocaleStore(s => s.t)
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-sm shadow-2xl p-6 space-y-5">
        <div className="flex flex-col items-center gap-3 text-center">
          <span className="text-4xl">🔍</span>
          <div>
            <h2 className="text-base font-semibold text-zinc-100">{t('procurement.product_not_found')}</h2>
            <p className="text-sm text-zinc-400 mt-1">
              {t('procurement.no_product_matches_barcode')} <span className="font-mono text-amber-400">{code}</span>.
            </p>
            <p className="text-xs text-zinc-500 mt-1">{t('procurement.add_product_hint')}</p>
          </div>
        </div>
        <div className="flex gap-3">
          <Btn variant="secondary" fullWidth onClick={onCancel}>{t('common.cancel')}</Btn>
          <Btn fullWidth onClick={onAddNew}>{t('procurement.add_new_product')}</Btn>
        </div>
      </div>
    </div>
  )
}

export default function PurchaseOrderCreatePage() {
  const navigate = useNavigate()
  const qc = useQueryClient()
  const t = useLocaleStore(s => s.t)
  const { availableBranches } = useTenantStore()
  const [productSearch, setProductSearch] = useState('')
  const [showCameraScanner, setShowCameraScanner] = useState(false)
  const [notFoundCode, setNotFoundCode] = useState<string | null>(null)
  const [showNewProductForm, setShowNewProductForm] = useState(false)

  const { data: suppliersData } = useQuery({
    queryKey: ['suppliers', undefined, 1],
    queryFn: () => procurementService.listSuppliers({ status: 'ACTIVE', page_size: 100 }),
  })

  const { data: productsData } = useQuery({
    queryKey: ['products', productSearch],
    queryFn: () => productsService.list({ search: productSearch || undefined, page_size: 50 }),
    placeholderData: prev => prev,
  })

  const suppliers = suppliersData?.items ?? []
  const products  = productsData?.items ?? []

  const { register, control, handleSubmit, watch, formState: { errors, isSubmitting } } = useForm<FormValues>({
    resolver: zodResolver(makeSchema(t)),
    defaultValues: {
      supplier_id:   '',
      branch_id:     availableBranches[0]?.id ?? '',
      order_date:    new Date().toISOString().split('T')[0],
      expected_date: '',
      notes:         '',
      items:         [],
    },
  })

  const { fields, append, remove } = useFieldArray({ control, name: 'items' })

  const watchedItems = watch('items')
  const subtotal = watchedItems.reduce((sum, item) => {
    const qty  = parseFloat(item.ordered_quantity) || 0
    const cost = parseFloat(item.unit_cost) || 0
    return sum + qty * cost
  }, 0)

  function addProduct(product: { id: string; name: string; cost_price: string }) {
    const existing = watchedItems.findIndex(i => i.product_id === product.id)
    if (existing >= 0) {
      toast.info(t('procurement.product_already_in_list'))
      return
    }
    append({ product_id: product.id, product_name: product.name, ordered_quantity: '1', unit_cost: product.cost_price })
    setProductSearch('')
  }

  // USB/HID scanner — fires when scanner sends rapid keystrokes outside an input
  const handleUsbScan = useCallback(async (code: string) => {
    const result = await lookupProductByBarcode(code)
    if (result.status === 'found') {
      addProduct(result.product)
      toast.success(`${t('procurement.added_prefix')} ${result.product.name}`)
    } else if (result.status === 'not_found') {
      setNotFoundCode(code)
    } else {
      toast.error(result.message ?? t('procurement.scanner_lookup_failed'))
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [watchedItems])

  // Camera scanner result — product found
  function handleCameraResult(product: Product) {
    addProduct(product)
    setShowCameraScanner(false)
    toast.success(`${t('procurement.added_prefix')} ${product.name}`)
  }

  // Camera scanner — product not found
  function handleCameraNotFound(code: string) {
    setShowCameraScanner(false)
    setNotFoundCode(code)
  }

  const createMutation = useMutation({
    mutationFn: (data: FormValues) => procurementService.createOrder({
      branch_id:     data.branch_id,
      supplier_id:   data.supplier_id,
      order_date:    new Date(data.order_date).toISOString(),
      expected_date: data.expected_date ? new Date(data.expected_date).toISOString() : undefined,
      notes:         data.notes || undefined,
      items:         data.items.map(item => ({
        product_id:       item.product_id,
        ordered_quantity: item.ordered_quantity,
        unit_cost:        item.unit_cost,
      })),
    }),
    onSuccess: (po) => {
      toast.success(`${t('procurement.po_created_prefix')} ${po.po_number} ${t('procurement.po_created_suffix')}`)
      qc.invalidateQueries({ queryKey: ['purchase-orders'] })
      qc.invalidateQueries({ queryKey: ['supplier-payables'] })
      navigate(`/app/procurement/purchase-orders/${po.id}`)
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('procurement.failed_create_po')),
  })

  const pending = isSubmitting || createMutation.isPending

  return (
    <>
      {/* USB/HID scanner: captures rapid keystrokes when no text input is focused */}
      <ScannerInputCapture onScan={handleUsbScan} />

      {/* Camera scanner modal */}
      {showCameraScanner && (
        <ProductScannerModal
          onResult={handleCameraResult}
          onNotFound={handleCameraNotFound}
          onClose={() => setShowCameraScanner(false)}
        />
      )}

      {/* Product not found — prompt to create */}
      {notFoundCode && !showNewProductForm && (
        <ProductNotFoundModal
          code={notFoundCode}
          onAddNew={() => setShowNewProductForm(true)}
          onCancel={() => setNotFoundCode(null)}
        />
      )}

      {/* New product form — same as Products → New Product flow */}
      {showNewProductForm && (
        <ProductFormModal
          initialBarcode={notFoundCode ?? undefined}
          onClose={() => { setShowNewProductForm(false); setNotFoundCode(null) }}
          onSaved={(created) => {
            qc.invalidateQueries({ queryKey: ['products'] })
            setShowNewProductForm(false)
            setNotFoundCode(null)
            if (created) {
              addProduct(created)
              toast.success(`"${created.name}" ${t('procurement.added_to_this_order')}`)
            }
          }}
        />
      )}

      <div className="flex flex-col h-full overflow-hidden">
        <SectionHeader
          title={t('procurement.new_purchase_order')}
          subtitle={t('procurement.new_po_subtitle')}
        />

        <div className="flex-1 overflow-y-auto">
          <form onSubmit={handleSubmit(d => createMutation.mutate(d))} className="max-w-3xl mx-auto p-4 sm:p-6 space-y-5">

            {/* Order details */}
            <div className="bg-zinc-900 rounded-2xl border border-zinc-800 p-4 space-y-4">
              <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.order_details')}</h3>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <FormField label={t('procurement.supplier')} error={errors.supplier_id?.message} required>
                  <select {...register('supplier_id')} className={inputCls(!!errors.supplier_id)}>
                    <option value="">{t('procurement.select_supplier')}</option>
                    {suppliers.map(s => (
                      <option key={s.id} value={s.id}>{s.name} ({s.code})</option>
                    ))}
                  </select>
                </FormField>

                <FormField label={t('procurement.branch')} error={errors.branch_id?.message} required>
                  <select {...register('branch_id')} className={inputCls(!!errors.branch_id)}>
                    <option value="">{t('procurement.select_branch')}</option>
                    {availableBranches.map(b => (
                      <option key={b.id} value={b.id}>{b.name}</option>
                    ))}
                  </select>
                </FormField>

                <FormField label={t('procurement.order_date')} error={errors.order_date?.message} required>
                  <input {...register('order_date')} type="date" className={inputCls(!!errors.order_date)} />
                </FormField>

                <FormField label={t('procurement.expected_delivery')}>
                  <input {...register('expected_date')} type="date" className={inputCls(false)} />
                </FormField>
              </div>

              <FormField label={t('procurement.notes')}>
                <textarea {...register('notes')} placeholder={t('procurement.internal_notes_placeholder')} rows={2} className={`${inputCls(false)} resize-none`} />
              </FormField>
            </div>

            {/* Product search + scan + item list */}
            <div className="bg-zinc-900 rounded-2xl border border-zinc-800 p-4 space-y-4">
              <h3 className="text-sm font-semibold text-zinc-100">{t('procurement.order_items')}</h3>

              {/* Search + camera scan button */}
              <div className="space-y-2">
                <div className="flex gap-2">
                  <input
                    type="text"
                    value={productSearch}
                    onChange={e => setProductSearch(e.target.value)}
                    placeholder={t('procurement.search_products_placeholder')}
                    className={`${inputCls(false)} flex-1`}
                  />
                  <button
                    type="button"
                    onClick={() => setShowCameraScanner(true)}
                    title={t('procurement.scan_barcode_title')}
                    className="flex-shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-xl border border-zinc-700 bg-zinc-800 text-zinc-300 hover:text-amber-400 hover:border-amber-500 transition-colors text-sm"
                  >
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/>
                      <rect x="7" y="7" width="3" height="10" rx="1"/><rect x="14" y="7" width="3" height="10" rx="1"/>
                    </svg>
                    {t('procurement.scan')}
                  </button>
                </div>
                {/* USB scanner hint */}
                <p className="text-[10px] text-zinc-600">{t('procurement.usb_scanner_hint')}</p>

                {productSearch && products.length > 0 && (
                  <div className="bg-zinc-800 border border-zinc-700 rounded-xl overflow-hidden max-h-48 overflow-y-auto">
                    {products.map(p => (
                      <button
                        key={p.id}
                        type="button"
                        onClick={() => addProduct(p)}
                        className="w-full text-left px-3 py-2.5 hover:bg-zinc-700 transition-colors flex items-center justify-between gap-2"
                      >
                        <div>
                          <span className="text-sm text-zinc-100">{p.name}</span>
                          <span className="text-xs text-zinc-500 ml-2">{p.sku}</span>
                        </div>
                        <span className="text-xs font-mono text-zinc-400 flex-shrink-0">{fmt(p.cost_price)}</span>
                      </button>
                    ))}
                  </div>
                )}
                {productSearch && products.length === 0 && (
                  <p className="text-xs text-zinc-500 px-1">{t('procurement.no_products_found_scan')}</p>
                )}
              </div>

              {/* Items */}
              {fields.length === 0 ? (
                <p className="text-zinc-600 text-sm text-center py-4">
                  {t('procurement.search_scan_hint')}
                </p>
              ) : (
                <div className="space-y-2">
                  <div className="hidden sm:grid grid-cols-[1fr_120px_120px_80px_36px] gap-2 px-1">
                    <span className="text-xs text-zinc-500 uppercase">{t('procurement.product')}</span>
                    <span className="text-xs text-zinc-500 uppercase text-right">{t('procurement.qty')}</span>
                    <span className="text-xs text-zinc-500 uppercase text-right">{t('procurement.unit_cost')}</span>
                    <span className="text-xs text-zinc-500 uppercase text-right">{t('procurement.col_total')}</span>
                    <span />
                  </div>

                  {fields.map((field, i) => {
                    const qty  = parseFloat(watchedItems[i]?.ordered_quantity) || 0
                    const cost = parseFloat(watchedItems[i]?.unit_cost) || 0
                    const lineTotal = qty * cost
                    return (
                      <div key={field.id} className="grid grid-cols-1 sm:grid-cols-[1fr_120px_120px_80px_36px] gap-2 items-center bg-zinc-800/40 rounded-xl p-3 sm:p-2">
                        <div className="min-w-0">
                          <p className="text-sm text-zinc-100 truncate">{field.product_name}</p>
                        </div>
                        <div>
                          <label className="text-xs text-zinc-500 sm:hidden">{t('procurement.qty')}</label>
                          <Controller
                            control={control}
                            name={`items.${i}.ordered_quantity`}
                            render={({ field: f }) => (
                              <input {...f} type="number" min="0.0001" step="any"
                                className={`${inputCls(!!errors.items?.[i]?.ordered_quantity)} text-right`} />
                            )}
                          />
                        </div>
                        <div>
                          <label className="text-xs text-zinc-500 sm:hidden">{t('procurement.unit_cost')}</label>
                          <Controller
                            control={control}
                            name={`items.${i}.unit_cost`}
                            render={({ field: f }) => (
                              <input {...f} type="number" min="0" step="any"
                                className={`${inputCls(!!errors.items?.[i]?.unit_cost)} text-right`} />
                            )}
                          />
                        </div>
                        <div className="text-right">
                          <span className="font-mono text-sm text-zinc-200">{fmt(lineTotal)}</span>
                        </div>
                        <button
                          type="button"
                          onClick={() => remove(i)}
                          className="w-8 h-8 flex items-center justify-center rounded-lg text-zinc-600 hover:text-red-400 hover:bg-red-950/30 transition-colors"
                        >
                          ✕
                        </button>
                      </div>
                    )
                  })}
                </div>
              )}

              {errors.items?.root && (
                <p className="text-xs text-red-400">{errors.items.root.message}</p>
              )}

              {fields.length > 0 && (
                <div className="border-t border-zinc-800 pt-3 flex justify-end">
                  <div className="space-y-1 text-sm text-right min-w-[200px]">
                    <div className="flex justify-between gap-8">
                      <span className="text-zinc-500">{t('procurement.subtotal')}</span>
                      <span className="font-mono text-zinc-200">{fmt(subtotal)}</span>
                    </div>
                    <div className="flex justify-between gap-8 font-semibold border-t border-zinc-700 pt-1 mt-1">
                      <span className="text-zinc-300">{t('procurement.col_total')}</span>
                      <span className="font-mono text-amber-400">{fmt(subtotal)}</span>
                    </div>
                  </div>
                </div>
              )}
            </div>

            <div className="flex gap-3">
              <Btn type="button" variant="secondary" onClick={() => navigate('/app/procurement/purchase-orders')}>
                {t('common.cancel')}
              </Btn>
              <Btn type="submit" disabled={pending || fields.length === 0} fullWidth>
                {pending ? <Spinner size={16} /> : t('procurement.create_purchase_order')}
              </Btn>
            </div>
          </form>
        </div>
      </div>
    </>
  )
}
