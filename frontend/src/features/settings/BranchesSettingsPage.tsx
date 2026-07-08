import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { extractApiMsg } from '@/lib/utils'
import { Badge, Spinner, Empty, Btn } from '@/components/ui'
import { useAuthStore } from '@/store/auth.store'
import { useLocaleStore } from '@/i18n/localeStore'
import { tenantService } from '@/services/tenant/tenant.service'
import type { BranchCreatePayload } from '@/services/tenant/tenant.service'
import { subscriptionsService } from '@/services/subscriptions/subscriptions.service'
import { TIMEZONES, CURRENCIES } from '@/shared/constants/localization'
import type { Branch } from '@/shared/types'

function autoCode(name: string): string {
  return name
    .trim()
    .split(/\s+/)
    .map(w => w.replace(/[^a-zA-Z0-9]/g, '').slice(0, 3).toUpperCase())
    .join('')
    .slice(0, 8) || 'BR'
}

const INPUT = 'w-full bg-zinc-800 border border-zinc-700 rounded-lg px-3 py-2 text-sm text-zinc-100 focus:outline-none focus:border-amber-500 transition-colors'
const LABEL = 'block text-xs text-zinc-400 mb-1'

const TIMEZONE_OPTIONS = TIMEZONES.map(tz => ({ value: tz, label: tz }))

function Field({
  label, value, onChange, required, readOnly, placeholder, type, inputMode, autoComplete,
}: {
  label: string; value: string; onChange?: (v: string) => void
  required?: boolean; readOnly?: boolean; placeholder?: string
  type?: string; inputMode?: React.HTMLAttributes<HTMLInputElement>['inputMode']; autoComplete?: string
}) {
  return (
    <div>
      <label className={LABEL}>
        {label}{required && <span className="text-red-400 ml-0.5">*</span>}
      </label>
      <input
        type={type}
        inputMode={inputMode}
        autoComplete={autoComplete}
        value={value}
        readOnly={readOnly}
        placeholder={placeholder}
        onChange={e => onChange?.(e.target.value)}
        className={`${INPUT} ${readOnly ? 'opacity-50 cursor-default' : ''}`}
      />
    </div>
  )
}

function SelectField({
  label, value, onChange, options,
}: {
  label: string; value: string; onChange: (v: string) => void
  options: { value: string; label: string }[]
}) {
  return (
    <div>
      <label className={LABEL}>{label}</label>
      <select value={value} onChange={e => onChange(e.target.value)} className={INPUT}>
        {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
      </select>
    </div>
  )
}

// Add Branch Modal

function AddBranchModal({ tenantId, onClose }: { tenantId: string; onClose: () => void }) {
  const t = useLocaleStore(s => s.t)
  const qc = useQueryClient()
  const [form, setForm] = useState<BranchCreatePayload>({
    name: '', code: '', address: '', city: '', phone: '',
    timezone: 'UTC', currency: 'MMK', is_main_branch: false,
  })

  const currencyOptions = CURRENCIES.map(c => ({ value: c, label: c === 'MMK' ? `${t('currency.mmk')} (MMK)` : c }))

  function setName(name: string) {
    setForm(p => ({ ...p, name, code: autoCode(name) }))
  }

  const mutation = useMutation({
    mutationFn: () => tenantService.createBranch(tenantId, {
      ...form,
      address: form.address || null,
      city:    form.city    || null,
      phone:   form.phone   || null,
    }),
    onSuccess: () => {
      toast.success(t('settings.branches.create_success'))
      qc.invalidateQueries({ queryKey: ['tenant', tenantId, 'branches'] })
      onClose()
    },
    onError: err => toast.error(extractApiMsg(err) ?? t('settings.branches.create_error')),
  })

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-md shadow-2xl">
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800">
          <h3 className="text-base font-semibold text-zinc-100">{t('settings.branches.add_title')}</h3>
          <button onClick={onClose} aria-label={t('common.close')} className="text-zinc-500 hover:text-zinc-200 w-7 h-7 flex items-center justify-center rounded-lg hover:bg-zinc-800">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 6 6 18M6 6l12 12"/></svg>
          </button>
        </div>

        <div className="p-5 space-y-3">
          <Field label={t('settings.branches.name')} value={form.name} onChange={setName} required />

          {/* Auto-generated code — read-only display */}
          <div>
            <label className={LABEL}>{t('settings.branches.code')} <span className="text-zinc-600">{t('settings.branches.auto_generated')}</span></label>
            <div className="flex items-center gap-2">
              <input
                value={form.code}
                readOnly
                className={`${INPUT} opacity-50 cursor-default font-mono tracking-widest`}
              />
            </div>
          </div>

          <Field label={t('settings.address')}  value={form.address ?? ''} onChange={v => setForm(p => ({ ...p, address: v }))} />
          <Field label={t('settings.city')}     value={form.city    ?? ''} onChange={v => setForm(p => ({ ...p, city: v }))} />
          <Field label={t('settings.phone')}    value={form.phone   ?? ''} onChange={v => setForm(p => ({ ...p, phone: v }))} placeholder={t('settings.branches.phone_placeholder')} type="tel" inputMode="tel" autoComplete="tel" />

          <div className="grid grid-cols-2 gap-3">
            <SelectField label={t('settings.timezone')} value={form.timezone ?? 'UTC'} onChange={v => setForm(p => ({ ...p, timezone: v }))} options={TIMEZONE_OPTIONS} />
            <SelectField label={t('settings.currency')} value={form.currency ?? 'MMK'} onChange={v => setForm(p => ({ ...p, currency: v }))} options={currencyOptions} />
          </div>
        </div>

        <div className="px-5 py-4 border-t border-zinc-800 flex gap-2 justify-end">
          <Btn variant="secondary" size="sm" onClick={onClose}>{t('common.cancel')}</Btn>
          <Btn
            size="sm"
            disabled={!form.name.trim() || mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            {mutation.isPending ? t('settings.branches.creating') : t('settings.branches.create_btn')}
          </Btn>
        </div>
      </div>
    </div>
  )
}

// Edit Branch Modal
type EditForm = {
  name: string; address: string; city: string; phone: string; timezone: string; currency: string
}

function EditBranchModal({
  tenantId, branch, onClose,
}: {
  tenantId: string; branch: Branch; onClose: () => void
}) {
  const t = useLocaleStore(s => s.t)
  const qc = useQueryClient()
  const [form, setForm] = useState<EditForm>({
    name:     branch.name,
    address:  branch.address  ?? '',
    city:     branch.city     ?? '',
    phone:    branch.phone    ?? '',
    timezone: branch.timezone ?? 'UTC',
    currency: branch.currency ?? 'MMK',
  })

  const currencyOptions = CURRENCIES.map(c => ({ value: c, label: c === 'MMK' ? `${t('currency.mmk')} (MMK)` : c }))

  const set = (key: keyof EditForm) => (v: string) => setForm(p => ({ ...p, [key]: v }))

  const mutation = useMutation({
    mutationFn: () => tenantService.updateBranch(tenantId, branch.id, {
      name:     form.name     || undefined,
      address:  form.address  || null,
      city:     form.city     || null,
      phone:    form.phone    || null,
      timezone: form.timezone || undefined,
      currency: form.currency || undefined,
    }),
    onSuccess: () => {
      toast.success(t('settings.branches.update_success'))
      qc.invalidateQueries({ queryKey: ['tenant', tenantId, 'branches'] })
      onClose()
    },
    onError: err => toast.error(extractApiMsg(err) ?? t('settings.branches.update_error')),
  })

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-md shadow-2xl">
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800">
          <div>
            <h3 className="text-base font-semibold text-zinc-100">{t('settings.branches.edit_title')}</h3>
            <p className="text-xs text-zinc-500 mt-0.5 font-mono tracking-widest">{branch.code}</p>
          </div>
          <button onClick={onClose} aria-label={t('common.close')} className="text-zinc-500 hover:text-zinc-200 w-7 h-7 flex items-center justify-center rounded-lg hover:bg-zinc-800">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M18 6 6 18M6 6l12 12"/></svg>
          </button>
        </div>

        <div className="p-5 space-y-3">
          <Field label={t('settings.branches.name')} value={form.name}     onChange={set('name')}     required />
          <Field label={t('settings.address')}        value={form.address}  onChange={set('address')}  />
          <Field label={t('settings.city')}            value={form.city}     onChange={set('city')}     />
          <Field label={t('settings.phone')}           value={form.phone}    onChange={set('phone')}    placeholder={t('settings.branches.phone_placeholder')} type="tel" inputMode="tel" autoComplete="tel" />
          <div className="grid grid-cols-2 gap-3">
            <SelectField label={t('settings.timezone')} value={form.timezone} onChange={set('timezone')} options={TIMEZONE_OPTIONS} />
            <SelectField label={t('settings.currency')} value={form.currency} onChange={set('currency')} options={currencyOptions} />
          </div>
        </div>

        <div className="px-5 py-4 border-t border-zinc-800 flex gap-2 justify-end">
          <Btn variant="secondary" size="sm" onClick={onClose}>{t('common.cancel')}</Btn>
          <Btn
            size="sm"
            disabled={!form.name.trim() || mutation.isPending}
            onClick={() => mutation.mutate()}
          >
            {mutation.isPending ? t('settings.saving') : t('settings.save_changes')}
          </Btn>
        </div>
      </div>
    </div>
  )
}

// Main Page

export default function BranchesSettingsPage() {
  const user = useAuthStore(s => s.user)
  const t = useLocaleStore(s => s.t)
  const qc = useQueryClient()
  const tenantId = user?.tenant_id
  const canEdit = user?.role === 'BUSINESS_OWNER' || user?.role === 'SUPER_ADMIN'
  const [showAdd, setShowAdd] = useState(false)
  const [editBranch, setEditBranch] = useState<Branch | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['tenant', tenantId, 'branches'],
    queryFn: () => tenantService.getBranches(tenantId!, { page_size: 50 }),
    enabled: !!tenantId,
  })

  const { data: entitlements } = useQuery({
    queryKey: ['subscription', 'entitlements'],
    queryFn: subscriptionsService.getMyEntitlements,
    enabled: !!tenantId,
  })

  const statusMutation = useMutation({
    mutationFn: ({ branchId, status }: { branchId: string; status: string }) =>
      tenantService.updateBranchStatus(tenantId!, branchId, status),
    onSuccess: (_, vars) => {
      toast.success(vars.status === 'ACTIVE' ? t('settings.branches.activated_msg') : t('settings.branches.deactivated_msg'))
      qc.invalidateQueries({ queryKey: ['tenant', tenantId, 'branches'] })
    },
    onError: err => toast.error(extractApiMsg(err) ?? t('settings.branches.update_error')),
  })

  if (!tenantId) return (
    <div className="flex items-center justify-center h-full">
      <p className="text-zinc-500 text-sm">{t('settings.no_tenant')}</p>
    </div>
  )

  if (isLoading) return (
    <div className="flex items-center justify-center h-full"><Spinner size={28} /></div>
  )

  const branches = data?.items ?? []
  const branchesEnt = entitlements?.find(e =>
    e.feature_code === 'branches'
  )
  const canAddBranch = entitlements
    ? (!!branchesEnt?.enabled && (
        branchesEnt.limit_value === null ||
        branchesEnt.limit_value === 0 ||
        branchesEnt.limit_value > 1
      ))
    : false

  return (
    <>
      {showAdd && tenantId && (
        <AddBranchModal tenantId={tenantId} onClose={() => setShowAdd(false)} />
      )}
      {editBranch && tenantId && (
        <EditBranchModal tenantId={tenantId} branch={editBranch} onClose={() => setEditBranch(null)} />
      )}

      <div className="h-full overflow-y-auto p-4 sm:p-6">
        <div className="max-w-2xl space-y-4">
          <div className="flex items-center justify-between gap-3">
            <p className="text-xs text-zinc-500">
              {t('settings.branches.desc')}
              {canEdit && !canAddBranch && t('settings.branches.limit_hint')}
            </p>
            {canEdit && canAddBranch && (
              <Btn size="sm" onClick={() => setShowAdd(true)} className="flex-shrink-0">
                {t('settings.branches.add_btn')}
              </Btn>
            )}
          </div>

          {branches.length === 0 ? (
            <Empty title={t('settings.branches.empty')} />
          ) : (
            <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden divide-y divide-zinc-800">
              {branches.map((branch: Branch) => {
                const isActive = branch.status === 'ACTIVE'
                const isClosed = branch.status === 'CLOSED'
                return (
                  <div key={branch.id} className="flex items-center gap-3 px-4 py-3.5">
                    {/* Avatar */}
                    <div className="w-9 h-9 rounded-lg bg-zinc-800 border border-zinc-700 flex items-center justify-center flex-shrink-0">
                      <span className="text-xs font-bold text-zinc-400 font-mono">
                        {branch.code.slice(0, 3).toUpperCase()}
                      </span>
                    </div>

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-medium text-zinc-100">{branch.name}</p>
                      <p className="text-xs text-zinc-500 truncate">
                        <span className="font-mono text-zinc-600">{branch.code}</span>
                        {branch.city && ` · ${branch.city}`}
                        {branch.address && ` · ${branch.address}`}
                      </p>
                    </div>

                    {/* Status badge */}
                    <Badge
                      variant={isActive ? 'success' : isClosed ? 'danger' : 'default'}
                      size="xs"
                    >
                      {isActive ? t('status.active') : isClosed ? t('settings.branches.status_closed') : t('status.inactive')}
                    </Badge>

                    {/* Edit button */}
                    {!isClosed && (
                      <button
                        onClick={() => canEdit && setEditBranch(branch)}
                        disabled={!canEdit}
                        className={`p-1.5 rounded-lg transition-colors flex-shrink-0 ${canEdit ? 'text-zinc-500 hover:text-zinc-200 hover:bg-zinc-800' : 'text-zinc-700 cursor-not-allowed opacity-50'}`}
                        title={canEdit ? t('settings.branches.edit_branch_tooltip') : t('settings.branches.owner_required')}
                      >
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                          <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                          <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
                        </svg>
                      </button>
                    )}

                    {/* Activate / Deactivate */}
                    {!isClosed && (
                      <Btn
                        size="xs"
                        variant={isActive ? 'danger' : 'secondary'}
                        disabled={!canEdit || statusMutation.isPending}
                        onClick={() => canEdit && statusMutation.mutate({
                          branchId: branch.id,
                          status:   isActive ? 'INACTIVE' : 'ACTIVE',
                        })}
                      >
                        {isActive ? t('settings.branches.deactivate') : t('settings.branches.activate')}
                      </Btn>
                    )}
                  </div>
                )
              })}
            </div>
          )}
        </div>

        {!canEdit && (
          <p className="text-xs text-zinc-600 text-center">
            {t('settings.branches.read_only')}
          </p>
        )}
      </div>
    </>
  )
}
