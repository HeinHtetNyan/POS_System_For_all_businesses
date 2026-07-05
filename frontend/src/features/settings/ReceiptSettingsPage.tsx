import { useEffect, useRef, useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { useAuthStore } from '@/store/auth.store'
import { tenantService } from '@/services/tenant/tenant.service'
import { Btn, Spinner } from '@/components/ui'
import { extractApiMsg, fmt } from '@/lib/utils'
import apiClient from '@/app/lib/axios'

const schema = z.object({
  receipt_header: z.string().max(200),
  receipt_footer: z.string().max(200),
  show_tax_on_receipt: z.boolean(),
})
type FormValues = z.infer<typeof schema>

function inputCls() {
  return 'w-full bg-zinc-950 border border-zinc-700 rounded-xl text-zinc-100 placeholder-zinc-600 text-sm focus:outline-none focus:ring-1 focus:ring-amber-500/20 focus:border-amber-500 transition-all py-2.5 px-3'
}

export default function ReceiptSettingsPage() {
  const user = useAuthStore(s => s.user)
  const qc = useQueryClient()
  const tenantId = user?.tenant_id
  const fileInputRef = useRef<HTMLInputElement>(null)

  // Logo state — fetched as base64 data URL for display and reliable printing
  const [logoDataUrl, setLogoDataUrl] = useState<string | null>(null)
  const [logoLoading, setLogoLoading] = useState(false)
  const [logoVersion, setLogoVersion] = useState(0)

  const { data: settings, isLoading } = useQuery({
    queryKey: ['tenant-settings', tenantId],
    queryFn: () => tenantService.getTenantSettings(tenantId!),
    enabled: !!tenantId,
  })

  const { register, handleSubmit, reset, watch, formState: { isDirty, isSubmitting } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: { receipt_header: '', receipt_footer: '', show_tax_on_receipt: true },
  })

  const hasLogo = !!(settings?.extra_settings as Record<string, unknown> | undefined)?.receipt_logo_url

  // Load the logo as a base64 data URL whenever settings indicate one exists,
  // or whenever logoVersion bumps (after a replace upload).
  useEffect(() => {
    if (!hasLogo || !tenantId) {
      setLogoDataUrl(null)
      return
    }
    let cancelled = false
    setLogoLoading(true)
    setLogoDataUrl(null)
    apiClient
      .get(`/tenants/${tenantId}/logo`, { responseType: 'blob' })
      .then(r => {
        if (cancelled) return
        const reader = new FileReader()
        reader.onload = () => {
          if (!cancelled) setLogoDataUrl(reader.result as string)
        }
        reader.readAsDataURL(r.data)
      })
      .catch(() => { if (!cancelled) setLogoDataUrl(null) })
      .finally(() => { if (!cancelled) setLogoLoading(false) })
    return () => { cancelled = true }
  }, [hasLogo, tenantId, logoVersion])

  useEffect(() => {
    if (settings) {
      const ex = settings.extra_settings as Record<string, unknown>
      reset({
        receipt_header:      (ex.receipt_header as string)  ?? '',
        receipt_footer:      (ex.receipt_footer as string)  ?? '',
        show_tax_on_receipt: (ex.show_tax_on_receipt as boolean) ?? true,
      })
    }
  }, [settings, reset])

  const mutation = useMutation({
    mutationFn: (values: FormValues) =>
      tenantService.updateTenantSettings(tenantId!, {
        extra_settings: {
          receipt_header:      values.receipt_header || null,
          receipt_footer:      values.receipt_footer || null,
          show_tax_on_receipt: values.show_tax_on_receipt,
        },
      }),
    onSuccess: () => {
      toast.success('Receipt settings saved')
      qc.invalidateQueries({ queryKey: ['tenant-settings', tenantId] })
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? 'Failed to save'),
  })

  const uploadMutation = useMutation({
    mutationFn: (file: File) => tenantService.uploadLogo(tenantId!, file),
    onSuccess: () => {
      toast.success('Logo uploaded')
      setLogoVersion(v => v + 1)
      qc.invalidateQueries({ queryKey: ['tenant-settings', tenantId] })
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? 'Failed to upload logo'),
  })

  const deleteMutation = useMutation({
    mutationFn: () => tenantService.deleteLogo(tenantId!),
    onSuccess: () => {
      toast.success('Logo removed')
      setLogoDataUrl(null)
      qc.invalidateQueries({ queryKey: ['tenant-settings', tenantId] })
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? 'Failed to remove logo'),
  })

  function handleFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    e.target.value = ''
    uploadMutation.mutate(file)
  }

  const showTax = watch('show_tax_on_receipt')

  // Live preview derived from saved tax settings
  const previewTaxRate      = settings?.tax_rate ?? 0
  const previewTaxName      = ((settings?.extra_settings as Record<string, unknown> | undefined)?.tax_name as string) || 'Tax'
  const previewTaxInclusive = settings?.tax_inclusive ?? false
  const previewTaxEnabled   = previewTaxRate > 0
  const previewSubtotal     = 15.00
  const previewTaxAmt       = previewTaxEnabled
    ? previewTaxInclusive
      ? previewSubtotal * previewTaxRate / (100 + previewTaxRate)
      : previewSubtotal * previewTaxRate / 100
    : 0
  const previewTotal = previewTaxInclusive ? previewSubtotal : previewSubtotal + previewTaxAmt

  if (!tenantId) return null
  if (isLoading) return <div className="flex items-center justify-center h-40"><Spinner size={28} /></div>

  const isLogoBusy = uploadMutation.isPending || deleteMutation.isPending || logoLoading

  return (
    <div className="h-full overflow-y-auto p-4 sm:p-6">
      <form onSubmit={handleSubmit(d => mutation.mutate(d))} className="max-w-lg space-y-5">

        {/* Logo upload */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 space-y-3">
          <div>
            <h3 className="text-sm font-semibold text-zinc-100">Receipt Logo</h3>
            <p className="text-xs text-zinc-500 mt-0.5">Appears at the top of every printed receipt. JPEG or PNG, max 2 MB.</p>
          </div>

          <input
            ref={fileInputRef}
            type="file"
            accept="image/jpeg,image/png"
            className="sr-only"
            onChange={handleFileChange}
          />

          {logoDataUrl ? (
            <div className="flex flex-col items-center gap-3">
              <div className="bg-white rounded-xl p-3 w-full flex justify-center">
                <img
                  src={logoDataUrl}
                  alt="Receipt logo"
                  className="max-h-24 max-w-full object-contain"
                />
              </div>
              <div className="flex gap-2 w-full">
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  disabled={isLogoBusy}
                  className="flex-1 py-2 rounded-xl bg-zinc-800 hover:bg-zinc-700 border border-zinc-700 text-zinc-300 text-xs font-medium transition-colors disabled:opacity-50"
                >
                  Replace
                </button>
                <button
                  type="button"
                  onClick={() => deleteMutation.mutate()}
                  disabled={isLogoBusy}
                  className="flex-1 py-2 rounded-xl bg-red-500/10 hover:bg-red-500/20 border border-red-500/30 text-red-400 text-xs font-medium transition-colors disabled:opacity-50"
                >
                  {deleteMutation.isPending ? <Spinner size={14} /> : 'Remove'}
                </button>
              </div>
            </div>
          ) : (
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              disabled={isLogoBusy}
              className="w-full border-2 border-dashed border-zinc-700 hover:border-amber-500/50 rounded-xl py-8 flex flex-col items-center gap-2 text-zinc-500 hover:text-zinc-300 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {uploadMutation.isPending || logoLoading ? (
                <Spinner size={20} />
              ) : (
                <>
                  <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
                      d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  <span className="text-xs font-medium">Click to upload logo</span>
                  <span className="text-[11px]">JPEG or PNG · max 2 MB</span>
                </>
              )}
            </button>
          )}
        </div>

        {/* Header & footer text */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 space-y-4">
          <h3 className="text-sm font-semibold text-zinc-100">Receipt Content</h3>

          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">Header Text</label>
            <input
              {...register('receipt_header')}
              placeholder="e.g. Welcome to SawYunPos!"
              className={inputCls()}
            />
            <p className="text-xs text-zinc-600">Shown at the top of every printed receipt.</p>
          </div>

          <div className="flex flex-col gap-1.5">
            <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">Footer Text</label>
            <textarea
              {...register('receipt_footer')}
              rows={2}
              placeholder="e.g. Thank you for shopping with us!"
              className={`${inputCls()} resize-none`}
            />
            <p className="text-xs text-zinc-600">Shown at the bottom of every printed receipt.</p>
          </div>
        </div>

        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-zinc-100">Show Tax on Receipt</p>
              <p className="text-xs text-zinc-500 mt-0.5">Print the tax line on customer receipts</p>
            </div>
            <button
              type="button"
              onClick={() => {
                const el = document.getElementById('show-tax-toggle') as HTMLInputElement
                el.click()
              }}
              className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${showTax ? 'bg-amber-500' : 'bg-zinc-700'}`}
            >
              <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${showTax ? 'translate-x-6' : 'translate-x-1'}`} />
            </button>
            <input id="show-tax-toggle" type="checkbox" {...register('show_tax_on_receipt')} className="sr-only" />
          </div>
        </div>

        {/* Preview */}
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 space-y-2">
          <h3 className="text-sm font-semibold text-zinc-100">Preview</h3>
          <div className="bg-white rounded-lg p-3 font-mono text-xs text-zinc-900 space-y-1 text-center">
            {logoDataUrl && (
              <div className="flex justify-center mb-2">
                <img src={logoDataUrl} alt="Logo" className="max-h-12 max-w-full object-contain" />
              </div>
            )}
            {watch('receipt_header') && <p className="font-bold">{watch('receipt_header')}</p>}
            <p className="text-zinc-400 text-[10px]">─────────────────</p>
            <p>Item 1 .............. {fmt(10)}</p>
            <p>Item 2 ............... {fmt(5)}</p>
            {showTax && previewTaxEnabled && previewTaxAmt > 0 && (
              <p>
                {previewTaxName} ({previewTaxRate}%){previewTaxInclusive ? ' incl.' : ''} .. {fmt(previewTaxAmt)}
              </p>
            )}
            <p className="font-bold">Total ............... {fmt(previewTotal)}</p>
            <p className="text-zinc-400 text-[10px]">─────────────────</p>
            {watch('receipt_footer') && <p className="text-zinc-600">{watch('receipt_footer')}</p>}
          </div>
        </div>

        <Btn type="submit" disabled={!isDirty || isSubmitting || mutation.isPending}>
          {mutation.isPending ? <Spinner size={16} /> : 'Save Receipt Settings'}
        </Btn>
      </form>
    </div>
  )
}
