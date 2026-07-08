import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { useAuthStore } from '@/store/auth.store'
import { useLocaleStore } from '@/i18n/localeStore'
import { tenantService } from '@/services/tenant/tenant.service'
import { Btn, Spinner } from '@/components/ui'
import { extractApiMsg } from '@/lib/utils'

function makeSchema(t: (k: string) => string) {
  return z.object({
    tax_enabled:    z.boolean(),
    tax_rate:       z.string().refine(v => !v || (parseFloat(v) >= 0 && parseFloat(v) <= 100), t('settings.tax.rate_range_error')),
    tax_inclusive:  z.boolean(),
    tax_name:       z.string().max(50),
  })
}
type FormValues = z.infer<ReturnType<typeof makeSchema>>

function inputCls(err = false) {
  return `w-full bg-zinc-950 border rounded-xl text-zinc-100 placeholder-zinc-600 text-sm focus:outline-none focus:ring-1 focus:ring-amber-500/20 transition-all py-2.5 px-3 ${err ? 'border-red-500' : 'border-zinc-700 focus:border-amber-500'}`
}

function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      type="button"
      onClick={() => onChange(!checked)}
      className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${checked ? 'bg-amber-500' : 'bg-zinc-700'}`}
    >
      <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${checked ? 'translate-x-6' : 'translate-x-1'}`} />
    </button>
  )
}

export default function TaxSettingsPage() {
  const user = useAuthStore(s => s.user)
  const t = useLocaleStore(s => s.t)
  const qc = useQueryClient()
  const tenantId = user?.tenant_id

  const { data: settings, isLoading } = useQuery({
    queryKey: ['tenant-settings', tenantId],
    queryFn: () => tenantService.getTenantSettings(tenantId!),
    enabled: !!tenantId,
  })

  const { register, handleSubmit, reset, watch, setValue, formState: { isDirty, isSubmitting, errors } } = useForm<FormValues>({
    resolver: zodResolver(makeSchema(t)),
    defaultValues: { tax_enabled: false, tax_rate: '', tax_inclusive: false, tax_name: 'Tax' },
  })

  useEffect(() => {
    if (settings) {
      const ex = settings.extra_settings as Record<string, unknown>
      reset({
        tax_enabled:   settings.tax_rate != null && settings.tax_rate > 0,
        tax_rate:      settings.tax_rate != null ? String(settings.tax_rate) : '',
        tax_inclusive: settings.tax_inclusive,
        tax_name:      (ex.tax_name as string) ?? 'Tax',
      })
    }
  }, [settings, reset])

  const mutation = useMutation({
    mutationFn: (values: FormValues) =>
      tenantService.updateTenantSettings(tenantId!, {
        tax_rate:      values.tax_enabled && values.tax_rate ? parseFloat(values.tax_rate) : 0,
        tax_inclusive: values.tax_inclusive,
        extra_settings: { tax_name: values.tax_name || 'Tax' },
      }),
    onSuccess: () => {
      toast.success(t('settings.tax.save_success'))
      qc.invalidateQueries({ queryKey: ['tenant-settings', tenantId] })
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('settings.tax.save_error')),
  })

  const taxEnabled  = watch('tax_enabled')
  const taxRate     = watch('tax_rate')
  const taxName     = watch('tax_name') || 'Tax'
  const taxInclusive = watch('tax_inclusive')

  if (!tenantId) return null
  if (isLoading) return <div className="flex items-center justify-center h-40"><Spinner size={28} /></div>

  return (
    <div className="h-full overflow-y-auto p-4 sm:p-6">
      <form onSubmit={handleSubmit(d => mutation.mutate(d))} className="max-w-lg space-y-5">

        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-zinc-100">{t('settings.tax.enable_tax')}</p>
              <p className="text-xs text-zinc-500 mt-0.5">{t('settings.tax.enable_tax_desc')}</p>
            </div>
            <Toggle checked={taxEnabled} onChange={v => setValue('tax_enabled', v, { shouldDirty: true })} />
          </div>

          {taxEnabled && (
            <>
              <div className="border-t border-zinc-800 pt-4 space-y-4">
                <div className="flex flex-col gap-1.5">
                  <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">{t('settings.tax.tax_name')}</label>
                  <input
                    {...register('tax_name')}
                    placeholder={t('settings.tax.tax_name_placeholder')}
                    className={inputCls()}
                  />
                  <p className="text-xs text-zinc-600">{t('settings.tax.tax_name_desc')}</p>
                </div>

                <div className="flex flex-col gap-1.5">
                  <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">{t('settings.tax.tax_rate')}</label>
                  <div className="relative">
                    <input
                      {...register('tax_rate')}
                      type="number"
                      min="0"
                      max="100"
                      step="0.01"
                      placeholder={t('settings.tax.tax_rate_placeholder')}
                      className={`${inputCls(!!errors.tax_rate)} pr-8`}
                    />
                    <span className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-500 text-sm">%</span>
                  </div>
                  {errors.tax_rate && <p className="text-xs text-red-400">{errors.tax_rate.message}</p>}
                </div>

                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-zinc-100">{t('settings.tax.inclusive_pricing')}</p>
                    <p className="text-xs text-zinc-500 mt-0.5">{t('settings.tax.inclusive_pricing_desc')}</p>
                  </div>
                  <Toggle checked={taxInclusive} onChange={v => setValue('tax_inclusive', v, { shouldDirty: true })} />
                </div>
              </div>

              {taxRate && (
                <div className="bg-zinc-800/50 rounded-xl p-3 text-xs space-y-1">
                  <p className="text-zinc-400 font-medium">{t('settings.tax.example_label')}</p>
                  <p className="text-zinc-300">
                    {t('settings.tax.item_price_label')}: 100.00 {t('currency.mmk')} →{' '}
                    {taxInclusive
                      ? `${taxName} ${t('settings.tax.included_label')}: ${(100 * parseFloat(taxRate) / (100 + parseFloat(taxRate))).toFixed(2)} ${t('currency.mmk')}`
                      : `+ ${taxName} ${taxRate}%: ${(100 * parseFloat(taxRate) / 100).toFixed(2)} ${t('currency.mmk')} = ${(100 + 100 * parseFloat(taxRate) / 100).toFixed(2)} ${t('currency.mmk')} ${t('settings.tax.total_label')}`
                    }
                  </p>
                </div>
              )}
            </>
          )}
        </div>

        <Btn type="submit" disabled={!isDirty || isSubmitting || mutation.isPending}>
          {mutation.isPending ? <Spinner size={16} /> : t('settings.tax.save_btn')}
        </Btn>
      </form>
    </div>
  )
}
