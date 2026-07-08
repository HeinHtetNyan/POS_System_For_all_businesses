import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { toast } from 'sonner'
import { cn, extractApiMsg, fmtDateTime } from '@/lib/utils'
import { newPasswordZodSchema, PASSWORDS_DO_NOT_MATCH_MESSAGE } from '@/lib/validation/password'
import { Btn, Badge, Table, Th, Td, Spinner, Divider, PasswordInput } from '@/components/ui'
import { usersService } from '@/services/users/users.service'
import { tenantService } from '@/services/tenant/tenant.service'
import { useAuthStore } from '@/store/auth.store'
import { useLocaleStore } from '@/i18n/localeStore'
import type { User, UserRole } from '@/shared/types'

const STAFF_ROLES: UserRole[] = ['MANAGER', 'CASHIER', 'INVENTORY_STAFF']

function roleLabel(t: (k: string) => string, role: string) {
  if (role === 'MANAGER')         return t('settings.staff.role_manager')
  if (role === 'CASHIER')         return t('settings.staff.role_cashier')
  if (role === 'INVENTORY_STAFF') return t('settings.staff.role_inventory')
  return role
}

function statusLabel(t: (k: string) => string, status: string) {
  if (status === 'ACTIVE')    return t('status.active')
  if (status === 'SUSPENDED') return t('settings.staff.status_suspended')
  return status
}

function inputCls(err = false) {
  return cn(
    'w-full bg-zinc-950 border rounded-xl text-zinc-100 placeholder-zinc-600 text-sm',
    'focus:outline-none focus:ring-1 focus:ring-amber-500/20 transition-all py-2.5 px-3',
    err ? 'border-red-500' : 'border-zinc-700 focus:border-amber-500',
  )
}

function FormField({ label, error, required, children }: {
  label: string; error?: string; required?: boolean; children: React.ReactNode
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">
        {label}{required && <span className="text-red-400 ml-0.5">*</span>}
      </label>
      {children}
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  )
}

function statusVariant(status: string) {
  if (status === 'ACTIVE')    return 'success'
  if (status === 'SUSPENDED') return 'danger'
  return 'default'
}

// Create Staff Modal

function makeCreateSchema(t: (k: string) => string) {
  return z.object({
    first_name:        z.string().min(1, t('settings.staff.required')),
    last_name:         z.string().min(1, t('settings.staff.required')),
    email:             z.string().email(t('settings.staff.invalid_email')).or(z.literal('')).optional(),
    password:          newPasswordZodSchema,
    confirm_password:  z.string().min(1, t('settings.staff.required')),
    phone:             z.string().min(1, t('settings.staff.phone_required')),
    role:              z.enum(['MANAGER', 'CASHIER', 'INVENTORY_STAFF']),
    primary_branch_id: z.string().optional(),
  }).refine(d => d.password === d.confirm_password, {
    message: PASSWORDS_DO_NOT_MATCH_MESSAGE,
    path: ['confirm_password'],
  })
}
type CreateForm = z.infer<ReturnType<typeof makeCreateSchema>>

function CreateStaffModal({ onClose, tenantId }: { onClose: () => void; tenantId: string }) {
  const t = useLocaleStore(s => s.t)
  const qc = useQueryClient()
  const { register, handleSubmit, formState: { errors } } = useForm<CreateForm>({
    resolver: zodResolver(makeCreateSchema(t)),
    defaultValues: { role: 'CASHIER' },
  })

  const { data: branchesData } = useQuery({
    queryKey: ['tenant', tenantId, 'branches'],
    queryFn: () => tenantService.getBranches(tenantId, { page_size: 100 }),
    enabled: !!tenantId,
    staleTime: 60_000,
  })
  const branches = (branchesData?.items ?? []).filter(b => b.status === 'ACTIVE')

  const mutation = useMutation({
    mutationFn: (data: CreateForm) => {
      const email = data.email?.trim()
        || `${data.first_name.toLowerCase()}.${data.last_name.toLowerCase()}.${Date.now()}@staff.internal`
      return usersService.create({
        email,
        password:          data.password,
        first_name:        data.first_name,
        last_name:         data.last_name,
        phone:             data.phone.trim(),
        role:              data.role,
        primary_branch_id: data.primary_branch_id || undefined,
      })
    },
    onSuccess: (created) => {
      toast.success(
        `${t('settings.staff.create_success_prefix')} ${created.phone ?? created.email}`,
        { duration: 10000 },
      )
      qc.invalidateQueries({ queryKey: ['staff-users'] })
      onClose()
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('settings.staff.create_error')),
  })

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="bg-zinc-900 border border-zinc-700 rounded-2xl w-full max-w-md shadow-2xl">
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800">
          <h2 className="text-base font-semibold text-zinc-100">{t('settings.staff.add_title')}</h2>
          <button onClick={onClose} className="text-zinc-500 hover:text-zinc-200 w-8 h-8 flex items-center justify-center rounded-lg hover:bg-zinc-800 transition-colors">✕</button>
        </div>
        <form onSubmit={handleSubmit(d => mutation.mutate(d))} className="p-5 space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <FormField label={t('settings.staff.first_name')} error={errors.first_name?.message} required>
              <input {...register('first_name')} placeholder={t('settings.staff.first_name_placeholder')} className={inputCls(!!errors.first_name)} />
            </FormField>
            <FormField label={t('settings.staff.last_name')} error={errors.last_name?.message} required>
              <input {...register('last_name')} placeholder={t('settings.staff.last_name_placeholder')} className={inputCls(!!errors.last_name)} />
            </FormField>
          </div>
          <FormField label={t('settings.email')} error={errors.email?.message}>
            <input {...register('email')} type="email" placeholder={t('settings.staff.email_placeholder')} className={inputCls(!!errors.email)} />
          </FormField>
          <FormField label={t('settings.staff.password')} error={errors.password?.message} required>
            <PasswordInput {...register('password')} placeholder={t('settings.staff.password_placeholder')} inputClassName={inputCls(!!errors.password)} />
          </FormField>
          <FormField label={t('settings.staff.confirm_password')} error={errors.confirm_password?.message} required>
            <PasswordInput {...register('confirm_password')} placeholder={t('settings.staff.confirm_password_placeholder')} inputClassName={inputCls(!!errors.confirm_password)} />
          </FormField>
          <div className="grid grid-cols-2 gap-3">
            <FormField label={t('settings.phone')} error={errors.phone?.message} required>
              <input {...register('phone')} type="tel" inputMode="tel" autoComplete="tel" placeholder={t('settings.staff.phone_placeholder')} className={inputCls(!!errors.phone)} />
            </FormField>
            <FormField label={t('settings.staff.role')} required>
              <select {...register('role')} className={inputCls()}>
                {STAFF_ROLES.map(r => (
                  <option key={r} value={r}>{roleLabel(t, r)}</option>
                ))}
              </select>
            </FormField>
          </div>
          <FormField label={t('settings.staff.assigned_branch')}>
            <select {...register('primary_branch_id')} className={inputCls()}>
              <option value="">{t('settings.staff.no_branch_option')}</option>
              {branches.map(b => (
                <option key={b.id} value={b.id}>{b.name}</option>
              ))}
            </select>
          </FormField>
          <div className="flex gap-3 pt-1">
            <Btn type="button" variant="secondary" onClick={onClose}>{t('common.cancel')}</Btn>
            <Btn type="submit" disabled={mutation.isPending} fullWidth>
              {mutation.isPending ? <Spinner size={16} /> : t('settings.staff.create_account_btn')}
            </Btn>
          </div>
        </form>
      </div>
    </div>
  )
}

// Edit Staff Modal

function makeEditSchema(t: (k: string) => string) {
  return z.object({
    first_name:        z.string().min(1, t('settings.staff.required')),
    last_name:         z.string().min(1, t('settings.staff.required')),
    phone:             z.string().optional(),
    role:              z.enum(['MANAGER', 'CASHIER', 'INVENTORY_STAFF']),
    primary_branch_id: z.string().optional(),
  })
}
type EditForm = z.infer<ReturnType<typeof makeEditSchema>>

function makeResetPwSchema(t: (k: string) => string) {
  return z.object({
    new_password: newPasswordZodSchema,
    confirm_password: z.string().min(1, t('settings.staff.required')),
  }).refine(d => d.new_password === d.confirm_password, {
    message: PASSWORDS_DO_NOT_MATCH_MESSAGE,
    path: ['confirm_password'],
  })
}
type ResetPwForm = z.infer<ReturnType<typeof makeResetPwSchema>>

function EditStaffModal({ staff, isOwner, tenantId, onClose }: {
  staff: User
  isOwner: boolean
  tenantId: string
  onClose: () => void
}) {
  const t = useLocaleStore(s => s.t)
  const qc = useQueryClient()
  const [tab, setTab] = useState<'profile' | 'password'>('profile')

  const { data: branchesData } = useQuery({
    queryKey: ['tenant', tenantId, 'branches'],
    queryFn: () => tenantService.getBranches(tenantId, { page_size: 100 }),
    enabled: !!tenantId,
    staleTime: 60_000,
  })
  const branches = (branchesData?.items ?? []).filter(b => b.status === 'ACTIVE')

  const editForm = useForm<EditForm>({
    resolver: zodResolver(makeEditSchema(t)),
    defaultValues: {
      first_name:        staff.first_name,
      last_name:         staff.last_name,
      phone:             staff.phone ?? '',
      role:              (STAFF_ROLES.includes(staff.role as UserRole) ? staff.role : 'CASHIER') as EditForm['role'],
      primary_branch_id: staff.primary_branch_id ?? '',
    },
  })

  const pwForm = useForm<ResetPwForm>({
    resolver: zodResolver(makeResetPwSchema(t)),
    defaultValues: { new_password: '', confirm_password: '' },
  })

  const updateMutation = useMutation({
    mutationFn: async (data: EditForm) => {
      await usersService.update(staff.id, {
        first_name:        data.first_name,
        last_name:         data.last_name,
        phone:             data.phone || undefined,
        primary_branch_id: data.primary_branch_id || undefined,
      })
      if (data.role !== staff.role) {
        await usersService.updateRole(staff.id, data.role)
      }
    },
    onSuccess: () => {
      toast.success(t('settings.staff.update_success'))
      qc.invalidateQueries({ queryKey: ['staff-users'] })
      onClose()
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('settings.staff.update_error')),
  })

  const resetPwMutation = useMutation({
    mutationFn: (data: ResetPwForm) => usersService.resetPassword(staff.id, data.new_password),
    onSuccess: () => {
      toast.success(`${t('settings.staff.reset_password_success_prefix')} ${staff.first_name} ${staff.last_name}`)
      pwForm.reset()
      onClose()
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('settings.staff.reset_password_error')),
  })

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="bg-zinc-900 border border-zinc-700 rounded-2xl w-full max-w-md shadow-2xl">
        {/* Header */}
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800">
          <div>
            <h2 className="text-base font-semibold text-zinc-100">{t('settings.staff.edit_title')}</h2>
            <p className="text-xs text-zinc-500">{staff.full_name} · {roleLabel(t, staff.role)}</p>
          </div>
          <button onClick={onClose} className="text-zinc-500 hover:text-zinc-200 w-8 h-8 flex items-center justify-center rounded-lg hover:bg-zinc-800 transition-colors">✕</button>
        </div>

        {/* Tabs */}
        {isOwner && (
          <div className="flex gap-1 px-5 pt-3">
            <button
              onClick={() => setTab('profile')}
              className={cn('px-3 py-1.5 rounded-lg text-xs font-medium transition-colors', tab === 'profile' ? 'bg-amber-500 text-black' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800')}
            >
              {t('settings.staff.profile_tab')}
            </button>
            <button
              onClick={() => setTab('password')}
              className={cn('px-3 py-1.5 rounded-lg text-xs font-medium transition-colors', tab === 'password' ? 'bg-amber-500 text-black' : 'text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800')}
            >
              {t('settings.staff.reset_password_tab')}
            </button>
          </div>
        )}

        {/* Profile tab */}
        {tab === 'profile' && (
          <form onSubmit={editForm.handleSubmit(d => updateMutation.mutate(d))} className="p-5 space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <FormField label={t('settings.staff.first_name')} error={editForm.formState.errors.first_name?.message} required>
                <input {...editForm.register('first_name')} className={inputCls(!!editForm.formState.errors.first_name)} />
              </FormField>
              <FormField label={t('settings.staff.last_name')} error={editForm.formState.errors.last_name?.message} required>
                <input {...editForm.register('last_name')} className={inputCls(!!editForm.formState.errors.last_name)} />
              </FormField>
            </div>
            <FormField label={t('settings.phone')} error={editForm.formState.errors.phone?.message}>
              <input {...editForm.register('phone')} type="tel" inputMode="tel" autoComplete="tel" placeholder={t('settings.staff.phone_placeholder')} className={inputCls(!!editForm.formState.errors.phone)} />
            </FormField>
            {isOwner && (
              <FormField label={t('settings.staff.role')} required>
                <select {...editForm.register('role')} className={inputCls()}>
                  {STAFF_ROLES.map(r => (
                    <option key={r} value={r}>{roleLabel(t, r)}</option>
                  ))}
                </select>
              </FormField>
            )}
            {isOwner && (
              <FormField label={t('settings.staff.assigned_branch')}>
                <select {...editForm.register('primary_branch_id')} className={inputCls()}>
                  <option value="">{t('settings.staff.no_branch_option')}</option>
                  {branches.map(b => (
                    <option key={b.id} value={b.id}>{b.name}</option>
                  ))}
                </select>
              </FormField>
            )}
            <div className="flex gap-3 pt-1">
              <Btn type="button" variant="secondary" onClick={onClose}>{t('common.cancel')}</Btn>
              <Btn type="submit" disabled={updateMutation.isPending} fullWidth>
                {updateMutation.isPending ? <Spinner size={16} /> : t('settings.save_changes')}
              </Btn>
            </div>
          </form>
        )}

        {/* Reset Password tab (owner only) */}
        {tab === 'password' && isOwner && (
          <form onSubmit={pwForm.handleSubmit(d => resetPwMutation.mutate(d))} className="p-5 space-y-4">
            <div className="bg-amber-950/50 border border-amber-800/50 rounded-xl px-4 py-3">
              <p className="text-xs text-amber-400">
                {t('settings.staff.reset_warning_prefix')} <span className="font-semibold">{staff.full_name}</span>.
                {' '}{t('settings.staff.reset_warning_suffix')}
              </p>
            </div>
            <Divider />
            <FormField label={t('settings.staff.new_password')} error={pwForm.formState.errors.new_password?.message} required>
              <PasswordInput
                {...pwForm.register('new_password')}
                placeholder={t('settings.staff.password_placeholder')}
                inputClassName={inputCls(!!pwForm.formState.errors.new_password)}
              />
            </FormField>
            <FormField label={t('settings.staff.confirm_password')} error={pwForm.formState.errors.confirm_password?.message} required>
              <PasswordInput
                {...pwForm.register('confirm_password')}
                placeholder={t('settings.staff.confirm_new_password_placeholder')}
                inputClassName={inputCls(!!pwForm.formState.errors.confirm_password)}
              />
            </FormField>
            <div className="flex gap-3 pt-1">
              <Btn type="button" variant="secondary" onClick={onClose}>{t('common.cancel')}</Btn>
              <Btn type="submit" variant="danger" disabled={resetPwMutation.isPending} fullWidth>
                {resetPwMutation.isPending ? <Spinner size={16} /> : t('settings.staff.reset_password_tab')}
              </Btn>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}

// Main Page

export default function StaffSettingsPage() {
  const user    = useAuthStore(s => s.user)
  const t       = useLocaleStore(s => s.t)
  const qc      = useQueryClient()
  const isOwner = user?.role === 'BUSINESS_OWNER' || user?.role === 'SUPER_ADMIN'
  const tenantId = user?.tenant_id ?? ''

  const [showCreate, setShowCreate] = useState(false)
  const [editingStaff, setEditingStaff] = useState<User | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['staff-users'],
    queryFn: () => usersService.list({ page_size: 100 }),
  })

  const { data: branchesData } = useQuery({
    queryKey: ['tenant', tenantId, 'branches'],
    queryFn: () => tenantService.getBranches(tenantId, { page_size: 100 }),
    enabled: !!tenantId,
    staleTime: 60_000,
  })
  const branchMap = new Map(
    (branchesData?.items ?? []).map(b => [b.id, b.name]),
  )

  const statusMutation = useMutation({
    mutationFn: ({ userId, status }: { userId: string; status: string }) =>
      usersService.updateStatus(userId, status),
    onSuccess: () => {
      toast.success(t('settings.staff.status_updated'))
      qc.invalidateQueries({ queryKey: ['staff-users'] })
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('settings.staff.update_error')),
  })

  const staff = (data?.items ?? []).filter(
    (u: User) => STAFF_ROLES.includes(u.role as UserRole) && u.id !== user?.id,
  )

  return (
    <>
      <div className="h-full overflow-y-auto p-4 sm:p-6 space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-sm font-semibold text-zinc-100">{t('settings.staff.title')}</h3>
            <p className="text-xs text-zinc-500 mt-0.5">{t('settings.staff.subtitle')}</p>
          </div>
          {isOwner && <Btn size="sm" onClick={() => setShowCreate(true)}>{t('settings.staff.add_btn')}</Btn>}
        </div>

        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden">
          {isLoading ? (
            <div className="flex items-center justify-center h-32"><Spinner size={24} /></div>
          ) : staff.length === 0 ? (
            <div className="text-center py-10 space-y-2">
              <span className="text-3xl">👥</span>
              <p className="text-zinc-400 text-sm">{t('settings.staff.empty')}</p>
              <p className="text-zinc-600 text-xs">{t('settings.staff.empty_sub')}</p>
            </div>
          ) : (
            <Table>
              <thead>
                <tr>
                  <Th>{t('settings.staff.col_name')}</Th>
                  <Th>{t('settings.staff.role')}</Th>
                  <Th>{t('settings.staff.col_branch')}</Th>
                  <Th>{t('settings.status')}</Th>
                  <Th>{t('settings.staff.col_last_login')}</Th>
                  <Th />
                </tr>
              </thead>
              <tbody>
                {staff.map((u: User) => (
                  <tr key={u.id} className="hover:bg-zinc-800/40 transition-colors">
                    <Td>
                      <div>
                        <p className="text-sm text-zinc-100">{u.full_name}</p>
                        <p className="text-xs text-zinc-500">{u.email}</p>
                      </div>
                    </Td>
                    <Td>
                      <Badge size="xs" variant="default">{roleLabel(t, u.role)}</Badge>
                    </Td>
                    <Td muted>
                      {u.primary_branch_id ? branchMap.get(u.primary_branch_id) ?? '—' : '—'}
                    </Td>
                    <Td>
                      <Badge size="xs" variant={statusVariant(u.status)}>{statusLabel(t, u.status)}</Badge>
                    </Td>
                    <Td muted>{u.last_login_at ? fmtDateTime(u.last_login_at) : t('settings.staff.never')}</Td>
                    <Td>
                      <div className="flex items-center gap-1.5">
                        <Btn
                          size="xs"
                          variant="ghost"
                          onClick={() => setEditingStaff(u)}
                        >
                          {t('common.edit')}
                        </Btn>
                        {isOwner && (
                          u.status === 'ACTIVE' ? (
                            <Btn
                              size="xs"
                              variant="danger"
                              onClick={() => statusMutation.mutate({ userId: u.id, status: 'SUSPENDED' })}
                              disabled={statusMutation.isPending}
                            >
                              {t('settings.staff.deactivate')}
                            </Btn>
                          ) : (
                            <Btn
                              size="xs"
                              variant="secondary"
                              onClick={() => statusMutation.mutate({ userId: u.id, status: 'ACTIVE' })}
                              disabled={statusMutation.isPending}
                            >
                              {t('settings.staff.activate')}
                            </Btn>
                          )
                        )}
                      </div>
                    </Td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </div>
      </div>

      {showCreate && <CreateStaffModal onClose={() => setShowCreate(false)} tenantId={tenantId} />}
      {editingStaff && (
        <EditStaffModal
          staff={editingStaff}
          isOwner={isOwner}
          tenantId={tenantId}
          onClose={() => setEditingStaff(null)}
        />
      )}
    </>
  )
}
