import { useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { cn } from '@/lib/utils'
import { Btn, Spinner, SectionHeader } from '@/components/ui'
import { customersService } from '@/services/customers/customers.service'
import { useLocaleStore } from '@/i18n/localeStore'
import type { ReactNode } from 'react'

export default function CustomerFormPage() {
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const qc = useQueryClient()
  const isEdit = !!id
  const t = useLocaleStore(s => s.t)

  const schema = z.object({
    name:      z.string().min(1, t('customers.name_required')),
    phone:     z.string().min(6, t('customers.phone_min_length')),
    email:     z.string().email(t('customers.invalid_email')).or(z.literal('')).optional(),
    address:   z.string(),
    notes:     z.string(),
    is_active: z.boolean(),
  })

  type FormValues = z.infer<typeof schema>

  const { data: existing, isLoading: loadingExisting } = useQuery({
    queryKey: ['customer', id],
    queryFn: () => customersService.get(id!),
    enabled: isEdit,
  })

  const { register, handleSubmit, reset, formState: { errors, isSubmitting } } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: '', phone: '', email: '', address: '', notes: '', is_active: true,
    },
  })

  useEffect(() => {
    if (existing) {
      reset({
        name:      existing.name,
        phone:     existing.phone,
        email:     existing.email ?? '',
        address:   existing.address ?? '',
        notes:     existing.notes ?? '',
        is_active: existing.is_active,
      })
    }
  }, [existing, reset])

  const createMutation = useMutation({
    mutationFn: (data: FormValues) => customersService.create({
      name:    data.name,
      phone:   data.phone,
      email:   data.email || undefined,
      address: data.address || undefined,
      notes:   data.notes || undefined,
    }),
    onSuccess: (customer) => {
      toast.success(t('customers.created'))
      qc.invalidateQueries({ queryKey: ['customers'] })
      navigate(`/app/customers/${customer.id}`)
    },
    onError: () => toast.error(t('customers.create_failed')),
  })

  const updateMutation = useMutation({
    mutationFn: (data: FormValues) => customersService.update(id!, {
      name:      data.name,
      phone:     data.phone,
      email:     data.email || undefined,
      address:   data.address || undefined,
      notes:     data.notes || undefined,
      is_active: data.is_active,
    }),
    onSuccess: () => {
      toast.success(t('customers.updated'))
      qc.invalidateQueries({ queryKey: ['customer', id] })
      qc.invalidateQueries({ queryKey: ['customers'] })
      navigate(`/app/customers/${id}`)
    },
    onError: () => toast.error(t('customers.update_failed')),
  })

  function onSubmit(data: FormValues) {
    if (isEdit) updateMutation.mutate(data)
    else createMutation.mutate(data)
  }

  const pending = isSubmitting || createMutation.isPending || updateMutation.isPending

  if (isEdit && loadingExisting) {
    return (
      <div className="flex items-center justify-center h-40">
        <Spinner size={32} />
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full overflow-hidden">
      <SectionHeader
        title={isEdit ? t('customers.edit_customer') : t('customers.new_customer')}
        subtitle={isEdit ? existing?.name : t('customers.new_customer_subtitle')}
      />

      <div className="flex-1 overflow-y-auto">
        <form onSubmit={handleSubmit(onSubmit)} className="max-w-lg mx-auto p-4 sm:p-6 space-y-4">
          <FormField label={t('customers.full_name')} error={errors.name?.message} required>
            <input
              {...register('name')}
              placeholder={t('customers.full_name_placeholder')}
              className={inputCls(!!errors.name)}
            />
          </FormField>

          <FormField label={t('settings.phone')} error={errors.phone?.message} required>
            <input
              {...register('phone')}
              type="tel"
              inputMode="tel"
              autoComplete="tel"
              placeholder={t('customers.phone_placeholder')}
              className={inputCls(!!errors.phone)}
            />
          </FormField>

          <FormField label={t('settings.email')} error={errors.email?.message}>
            <input
              {...register('email')}
              type="email"
              placeholder={t('customers.email_placeholder')}
              className={inputCls(!!errors.email)}
            />
          </FormField>

          <FormField label={t('settings.address')}>
            <textarea
              {...register('address')}
              placeholder={t('customers.address_placeholder')}
              rows={2}
              className={cn(inputCls(false), 'resize-none')}
            />
          </FormField>

          <FormField label={t('customers.internal_notes')}>
            <textarea
              {...register('notes')}
              placeholder={t('customers.notes_placeholder')}
              rows={3}
              className={cn(inputCls(false), 'resize-none')}
            />
          </FormField>

          {isEdit && (
            <div className="flex items-center gap-3 py-1">
              <input
                type="checkbox"
                id="is_active"
                {...register('is_active')}
                className="w-4 h-4 rounded accent-amber-500"
              />
              <label htmlFor="is_active" className="text-sm text-zinc-300 cursor-pointer">
                {t('customers.active_customer')}
              </label>
            </div>
          )}

          <div className="flex gap-3 pt-2">
            <Btn
              type="button"
              variant="secondary"
              onClick={() => navigate(isEdit ? `/app/customers/${id}` : '/app/customers')}
            >
              {t('common.cancel')}
            </Btn>
            <Btn type="submit" disabled={pending} fullWidth>
              {pending ? <Spinner size={16} /> : isEdit ? t('common.save_changes') : t('customers.create_customer')}
            </Btn>
          </div>
        </form>
      </div>
    </div>
  )
}

function inputCls(err: boolean) {
  return cn(
    'w-full bg-zinc-900 border rounded-xl text-zinc-100 placeholder-zinc-600 text-sm',
    'focus:outline-none focus:ring-1 focus:ring-amber-500/20 transition-all duration-150 py-2.5 px-3',
    err ? 'border-red-500 focus:border-red-500' : 'border-zinc-700 focus:border-amber-500',
  )
}

function FormField({ label, error, required, children }: {
  label: string; error?: string; required?: boolean; children: ReactNode
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">
        {label}
        {required && <span className="text-red-400 ml-0.5">*</span>}
      </label>
      {children}
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  )
}
