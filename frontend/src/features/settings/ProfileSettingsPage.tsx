import { useState } from 'react'
import { useMutation } from '@tanstack/react-query'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { toast } from 'sonner'
import { cn, extractApiMsg } from '@/lib/utils'
import { newPasswordZodSchema, PASSWORDS_DO_NOT_MATCH_MESSAGE } from '@/lib/validation/password'
import { Btn, Divider, PasswordInput, Spinner } from '@/components/ui'
import { ROLE_LABELS, ROLE_BADGE_STYLES } from '@/shared/constants/rbac'
import { usersService } from '@/services/users/users.service'
import { authService } from '@/services/auth/auth.service'
import { useAuthStore } from '@/store/auth.store'
import { useLocaleStore } from '@/i18n/localeStore'

function inputCls(err = false, disabled = false) {
  return cn(
    'w-full bg-zinc-950 border rounded-xl text-zinc-100 placeholder-zinc-600 text-sm',
    'focus:outline-none focus:ring-1 focus:ring-amber-500/20 transition-all py-2.5 px-3',
    err ? 'border-red-500' : 'border-zinc-700 focus:border-amber-500',
    disabled && 'border-zinc-800 text-zinc-500 cursor-not-allowed opacity-70',
  )
}

function FormField({ label, error, children }: { label: string; error?: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">{label}</label>
      {children}
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  )
}

function makeProfileSchema(t: (k: string) => string) {
  return z.object({
    first_name: z.string().min(1, t('settings.profile.required')),
    last_name:  z.string().min(1, t('settings.profile.required')),
    phone:      z.string().optional(),
  })
}
type ProfileForm = z.infer<ReturnType<typeof makeProfileSchema>>

function makePasswordSchema(t: (k: string) => string) {
  return z.object({
    current_password: z.string().min(1, t('settings.profile.required')),
    new_password: newPasswordZodSchema,
    confirm_password: z.string().min(1, t('settings.profile.required')),
  }).refine(d => d.new_password === d.confirm_password, {
    message: PASSWORDS_DO_NOT_MATCH_MESSAGE,
    path: ['confirm_password'],
  })
}
type PasswordForm = z.infer<ReturnType<typeof makePasswordSchema>>

function makeEmailSchema(t: (k: string) => string) {
  return z.object({
    new_email: z.string().min(1, t('settings.profile.required')).email(t('settings.profile.invalid_email')),
    current_password: z.string().min(1, t('settings.profile.required')),
  })
}
type EmailForm = z.infer<ReturnType<typeof makeEmailSchema>>

export default function ProfileSettingsPage() {
  const user = useAuthStore(s => s.user)
  const t = useLocaleStore(s => s.t)
  const [showPassword, setShowPassword] = useState(false)
  const [showEmail, setShowEmail] = useState(false)
  const [isEditingProfile, setIsEditingProfile] = useState(false)

  const profileForm = useForm<ProfileForm>({
    resolver: zodResolver(makeProfileSchema(t)),
    defaultValues: {
      first_name: user?.first_name ?? '',
      last_name:  user?.last_name ?? '',
      phone:      user?.phone ?? '',
    },
  })

  const passwordForm = useForm<PasswordForm>({
    resolver: zodResolver(makePasswordSchema(t)),
    defaultValues: { current_password: '', new_password: '', confirm_password: '' },
  })

  const emailForm = useForm<EmailForm>({
    resolver: zodResolver(makeEmailSchema(t)),
    defaultValues: { new_email: '', current_password: '' },
  })

  const profileMutation = useMutation({
    mutationFn: (data: ProfileForm) => usersService.update(user!.id, data),
    onSuccess: (updatedUser) => {
      toast.success(t('settings.profile.save_success'))
      // The logged-in user lives in this Zustand store, not React Query —
      // invalidating a query key here was a no-op and left stale name/phone
      // showing elsewhere in the app until the next login.
      useAuthStore.getState().setUser(updatedUser)
      setIsEditingProfile(false)
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('settings.profile.save_error')),
  })

  const passwordMutation = useMutation({
    mutationFn: (data: PasswordForm) =>
      authService.changePassword({ current_password: data.current_password, new_password: data.new_password }),
    onSuccess: () => {
      toast.success(t('settings.profile.password_changed'))
      passwordForm.reset()
      setShowPassword(false)
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('settings.profile.password_change_error')),
  })

  const emailMutation = useMutation({
    mutationFn: (data: EmailForm) => authService.requestEmailChange(data.new_email, data.current_password),
    onSuccess: (res) => {
      toast.success(res.message ?? t('settings.profile.email_sent_default'))
      emailForm.reset()
      setShowEmail(false)
    },
    onError: (err) => toast.error(extractApiMsg(err) ?? t('settings.profile.email_change_error')),
  })

  if (!user) return null

  const roleStyle = ROLE_BADGE_STYLES[user.role]
  const initials  = `${user.first_name[0] ?? ''}${user.last_name[0] ?? ''}`

  return (
    <div className="h-full overflow-y-auto p-4 sm:p-6 max-w-2xl space-y-6">

      {/* Identity card */}
      <div className="flex items-center gap-4 bg-zinc-900 border border-zinc-800 rounded-2xl px-5 py-4">
        <div
          className="w-14 h-14 rounded-2xl flex items-center justify-center text-xl font-bold border flex-shrink-0"
          style={{ background: roleStyle.bg, color: roleStyle.text, borderColor: roleStyle.border }}
        >
          {initials}
        </div>
        <div>
          <p className="text-zinc-100 font-semibold text-base leading-tight">{user.full_name}</p>
          <div className="flex items-center gap-2 mt-0.5">
            <p className="text-zinc-500 text-xs">{user.email}</p>
            {user.role === 'BUSINESS_OWNER' && (
              user.email_verified_at ? (
                <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-green-400">
                  ✓ {t('settings.profile.verified')}
                </span>
              ) : (
                <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-red-400">
                  ✗ {t('settings.profile.email_unverified')}
                </span>
              )
            )}
          </div>
          <span
            className="inline-block mt-1.5 px-2 py-0.5 rounded-md text-[11px] font-medium border"
            style={{ background: roleStyle.bg, color: roleStyle.text, borderColor: roleStyle.border }}
          >
            {ROLE_LABELS[user.role]}
          </span>
        </div>
      </div>

      {/* Edit Profile */}
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden">
        <div className="px-5 py-3.5 border-b border-zinc-800">
          <h3 className="text-sm font-semibold text-zinc-100">{t('settings.profile.title_edit')}</h3>
          <p className="text-xs text-zinc-500 mt-0.5">{t('settings.profile.edit_desc')}</p>
        </div>
        <form
          onSubmit={profileForm.handleSubmit(d => profileMutation.mutate(d))}
          className="p-5 space-y-4"
        >
          <div className="grid grid-cols-2 gap-3">
            <FormField label={t('settings.profile.first_name')} error={profileForm.formState.errors.first_name?.message}>
              <input
                {...profileForm.register('first_name')}
                disabled={!isEditingProfile}
                className={inputCls(!!profileForm.formState.errors.first_name, !isEditingProfile)}
              />
            </FormField>
            <FormField label={t('settings.profile.last_name')} error={profileForm.formState.errors.last_name?.message}>
              <input
                {...profileForm.register('last_name')}
                disabled={!isEditingProfile}
                className={inputCls(!!profileForm.formState.errors.last_name, !isEditingProfile)}
              />
            </FormField>
          </div>
          <FormField label={t('settings.phone')} error={profileForm.formState.errors.phone?.message}>
            <input
              {...profileForm.register('phone')}
              type="tel"
              inputMode="tel"
              autoComplete="tel"
              placeholder={t('settings.profile.phone_placeholder')}
              disabled={!isEditingProfile}
              className={inputCls(!!profileForm.formState.errors.phone, !isEditingProfile)}
            />
          </FormField>
          <div className="flex justify-end gap-3 pt-1">
            {!isEditingProfile ? (
              <Btn type="button" onClick={() => setIsEditingProfile(true)}>{t('common.edit')}</Btn>
            ) : (
              <>
                <Btn
                  type="button"
                  variant="secondary"
                  onClick={() => { profileForm.reset(); setIsEditingProfile(false) }}
                >
                  {t('common.cancel')}
                </Btn>
                <Btn type="submit" disabled={profileMutation.isPending}>
                  {profileMutation.isPending ? <><Spinner size={14} /> {t('settings.saving')}</> : t('settings.save_changes')}
                </Btn>
              </>
            )}
          </div>
        </form>
      </div>

      {/* Change Password */}
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden">
        <button
          className="w-full flex items-center justify-between px-5 py-3.5 border-b border-zinc-800 text-left hover:bg-zinc-800/40 transition-colors"
          onClick={() => setShowPassword(p => !p)}
        >
          <div>
            <h3 className="text-sm font-semibold text-zinc-100">{t('settings.profile.change_password_title')}</h3>
            <p className="text-xs text-zinc-500 mt-0.5">{t('settings.profile.change_password_desc')}</p>
          </div>
          <span className="text-zinc-500 text-sm">{showPassword ? '▲' : '▼'}</span>
        </button>

        {showPassword && (
          <form
            onSubmit={passwordForm.handleSubmit(d => passwordMutation.mutate(d))}
            className="p-5 space-y-4"
          >
            <FormField label={t('settings.profile.current_password')} error={passwordForm.formState.errors.current_password?.message}>
              <PasswordInput
                {...passwordForm.register('current_password')}
                placeholder={t('settings.profile.current_password_placeholder')}
                inputClassName={inputCls(!!passwordForm.formState.errors.current_password)}
              />
            </FormField>
            <Divider />
            <FormField label={t('settings.profile.new_password')} error={passwordForm.formState.errors.new_password?.message}>
              <PasswordInput
                {...passwordForm.register('new_password')}
                placeholder={t('settings.profile.new_password_placeholder')}
                inputClassName={inputCls(!!passwordForm.formState.errors.new_password)}
              />
            </FormField>
            <FormField label={t('settings.profile.confirm_new_password')} error={passwordForm.formState.errors.confirm_password?.message}>
              <PasswordInput
                {...passwordForm.register('confirm_password')}
                placeholder={t('settings.profile.confirm_new_password_placeholder')}
                inputClassName={inputCls(!!passwordForm.formState.errors.confirm_password)}
              />
            </FormField>
            <div className="flex gap-3 justify-end pt-1">
              <Btn type="button" variant="secondary" onClick={() => { setShowPassword(false); passwordForm.reset() }}>
                {t('common.cancel')}
              </Btn>
              <Btn type="submit" disabled={passwordMutation.isPending}>
                {passwordMutation.isPending ? <><Spinner size={14} /> {t('settings.profile.changing')}</> : t('settings.profile.change_password_title')}
              </Btn>
            </div>
          </form>
        )}
      </div>

      {/* Change Email */}
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden">
        <button
          className="w-full flex items-center justify-between px-5 py-3.5 border-b border-zinc-800 text-left hover:bg-zinc-800/40 transition-colors"
          onClick={() => setShowEmail(p => !p)}
        >
          <div>
            <h3 className="text-sm font-semibold text-zinc-100">{t('settings.profile.change_email_title')}</h3>
            <p className="text-xs text-zinc-500 mt-0.5">{t('settings.profile.change_email_desc')}</p>
          </div>
          <span className="text-zinc-500 text-sm">{showEmail ? '▲' : '▼'}</span>
        </button>

        {showEmail && (
          <form
            onSubmit={emailForm.handleSubmit(d => emailMutation.mutate(d))}
            className="p-5 space-y-4"
          >
            <p className="text-xs text-zinc-500 -mt-1">
              {t('settings.profile.email_change_notice')} <span className="text-zinc-300">{user.email}</span>
            </p>
            <FormField label={t('settings.profile.new_email')} error={emailForm.formState.errors.new_email?.message}>
              <input
                {...emailForm.register('new_email')}
                type="email"
                autoComplete="email"
                placeholder={t('settings.profile.new_email_placeholder')}
                className={inputCls(!!emailForm.formState.errors.new_email)}
              />
            </FormField>
            <Divider />
            <FormField label={t('settings.profile.current_password')} error={emailForm.formState.errors.current_password?.message}>
              <PasswordInput
                {...emailForm.register('current_password')}
                placeholder={t('settings.profile.confirm_its_you')}
                inputClassName={inputCls(!!emailForm.formState.errors.current_password)}
              />
            </FormField>
            <div className="flex gap-3 justify-end pt-1">
              <Btn type="button" variant="secondary" onClick={() => { setShowEmail(false); emailForm.reset() }}>
                {t('common.cancel')}
              </Btn>
              <Btn type="submit" disabled={emailMutation.isPending}>
                {emailMutation.isPending ? <><Spinner size={14} /> {t('settings.profile.sending')}</> : t('settings.profile.send_confirmation')}
              </Btn>
            </div>
          </form>
        )}
      </div>

    </div>
  )
}
