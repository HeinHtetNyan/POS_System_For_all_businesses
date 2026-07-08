import { useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { Btn, Spinner, SectionHeader } from '@/components/ui'
import { procurementService } from '@/services/procurement/procurement.service'
import { extractApiMsg } from '@/lib/utils'
import { inputCls, FormField } from './procurementHelpers'
import { useLocaleStore } from '@/i18n/localeStore'

const makeSchema = (t: (key: string) => string) => z.object({
  name:    z.string().min(1, t('procurement.validation_name_required')),
  email:   z.string().email(t('procurement.validation_invalid_email')).or(z.literal('')),
  phone:   z.string(),
  address: z.string(),
  city:    z.string(),
  country: z.string(),
  website: z.string(),
  notes:   z.string(),
})

type FormValues = z.infer<ReturnType<typeof makeSchema>>

export default function SupplierFormPage() {
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const t = useLocaleStore(s => s.t)
  const isEdit = !!id

  const { data: existing, isLoading: loadingExisting } = useQuery({
    queryKey: ['supplier', id],
    queryFn: () => procurementService.getSupplier(id!),
    enabled: isEdit,
  })

  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<FormValues>({
    resolver: zodResolver(makeSchema(t)),
    defaultValues: { name: '', email: '', phone: '', address: '', city: '', country: '', website: '', notes: '' },
  })

  useEffect(() => {
    if (existing) {
      reset({
        name:    existing.name,
        email:   existing.email ?? '',
        phone:   existing.phone ?? '',
        address: existing.address ?? '',
        city:    existing.city ?? '',
        country: existing.country ?? '',
        website: existing.website ?? '',
        notes:   existing.notes ?? '',
      })
    }
  }, [existing, reset])

  const createMutation = useMutation({
    mutationFn: (data: FormValues) => procurementService.createSupplier({
      name:    data.name,
      email:   data.email || undefined,
      phone:   data.phone || undefined,
      address: data.address || undefined,
      city:    data.city || undefined,
      country: data.country || undefined,
      website: data.website || undefined,
      notes:   data.notes || undefined,
    }),
    onSuccess: (supplier) => {
      toast.success(t('procurement.supplier_created'))
      qc.invalidateQueries({ queryKey: ['suppliers'] })
      navigate(`/app/procurement/suppliers/${supplier.id}`)
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('procurement.failed_create_supplier')),
  })

  const updateMutation = useMutation({
    mutationFn: (data: FormValues) => procurementService.updateSupplier(id!, {
      name:    data.name,
      email:   data.email || null,
      phone:   data.phone || null,
      address: data.address || null,
      city:    data.city || null,
      country: data.country || null,
      website: data.website || null,
      notes:   data.notes || null,
    }),
    onSuccess: () => {
      toast.success(t('procurement.supplier_updated'))
      qc.invalidateQueries({ queryKey: ['supplier', id] })
      qc.invalidateQueries({ queryKey: ['suppliers'] })
      navigate(`/app/procurement/suppliers/${id}`)
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('procurement.failed_update_supplier')),
  })

  function onSubmit(data: FormValues) {
    if (isEdit) updateMutation.mutate(data)
    else createMutation.mutate(data)
  }

  const pending = isSubmitting || createMutation.isPending || updateMutation.isPending

  if (isEdit && loadingExisting) {
    return <div className="flex items-center justify-center h-40"><Spinner size={32} /></div>
  }

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <SectionHeader
        title={isEdit ? t('procurement.edit_supplier') : t('procurement.new_supplier')}
        subtitle={isEdit ? existing?.name : t('procurement.new_supplier_subtitle')}
      />

      <div className="flex-1 overflow-y-auto">
        <form onSubmit={handleSubmit(onSubmit)} className="max-w-lg mx-auto p-4 sm:p-6 space-y-4">
          <FormField label={t('procurement.supplier_name')} error={errors.name?.message} required>
            <input {...register('name')} placeholder="Acme Corp" className={inputCls(!!errors.name)} />
          </FormField>

          <div className="grid grid-cols-2 gap-4">
            <FormField label={t('settings.phone')} error={errors.phone?.message}>
              <input {...register('phone')} type="tel" inputMode="tel" autoComplete="tel" placeholder="+1 555 000 0000" className={inputCls(!!errors.phone)} />
            </FormField>
            <FormField label={t('settings.email')} error={errors.email?.message}>
              <input {...register('email')} type="email" placeholder="contact@supplier.com" className={inputCls(!!errors.email)} />
            </FormField>
          </div>

          <FormField label={t('settings.address')}>
            <textarea {...register('address')} placeholder={t('procurement.street_address_placeholder')} rows={2} className={`${inputCls(false)} resize-none`} />
          </FormField>

          <div className="grid grid-cols-2 gap-4">
            <FormField label={t('settings.city')}>
              <input {...register('city')} placeholder={t('settings.city')} className={inputCls(false)} />
            </FormField>
            <FormField label={t('settings.country')}>
              <input {...register('country')} placeholder={t('settings.country')} className={inputCls(false)} />
            </FormField>
          </div>

          <FormField label={t('procurement.website')}>
            <input {...register('website')} placeholder="https://supplier.com" className={inputCls(false)} />
          </FormField>

          <FormField label={t('procurement.notes')}>
            <textarea {...register('notes')} placeholder={t('procurement.internal_notes_placeholder')} rows={3} className={`${inputCls(false)} resize-none`} />
          </FormField>

          <div className="flex gap-3 pt-2">
            <Btn
              type="button"
              variant="secondary"
              onClick={() => navigate(isEdit ? `/app/procurement/suppliers/${id}` : '/app/procurement/suppliers')}
            >
              {t('common.cancel')}
            </Btn>
            <Btn type="submit" disabled={pending} fullWidth>
              {pending ? <Spinner size={16} /> : isEdit ? t('common.save_changes') : t('procurement.create_supplier')}
            </Btn>
          </div>
        </form>
      </div>
    </div>
  )
}
