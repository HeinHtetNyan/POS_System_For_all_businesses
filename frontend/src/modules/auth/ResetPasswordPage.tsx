import { useState, type FormEvent } from 'react'
import { Link, useSearchParams, useNavigate } from 'react-router-dom'
import { Btn, PasswordInput, Spinner } from '@/components/ui/index'
import { IconAlert } from '@/components/icons'
import { authService } from '@/services/auth/auth.service'
import { validateNewPassword, PASSWORDS_DO_NOT_MATCH_MESSAGE } from '@/lib/validation/password'
import { useLocaleStore } from '@/i18n/localeStore'

export default function ResetPasswordPage() {
  const t = useLocaleStore(s => s.t)
  const [searchParams]              = useSearchParams()
  const navigate                    = useNavigate()
  const token                       = searchParams.get('token') ?? ''

  const [password, setPassword]     = useState('')
  const [confirm, setConfirm]       = useState('')
  const [isLoading, setLoading]     = useState(false)
  const [error, setError]           = useState<string | null>(null)
  const [success, setSuccess]       = useState(false)

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)

    const pwError = validateNewPassword(password)
    if (pwError) { setError(pwError); return }
    if (password !== confirm) { setError(PASSWORDS_DO_NOT_MATCH_MESSAGE); return }

    setLoading(true)
    try {
      await authService.resetPassword(token, password)
      setSuccess(true)
      // Redirect to login after 2.5 s so the user sees the success message
      setTimeout(() => navigate('/login', { replace: true }), 2500)
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { error?: { message?: string } } } })
          ?.response?.data?.error?.message ??
        (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail ??
        t('auth.generic_error')
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  /* No token in URL */
  if (!token) {
    return (
      <div className="relative w-full max-w-md">
        <div className="text-center mb-8">
          <img src="/logo-icon.png" alt="SawYunPos" className="inline-block w-16 h-16 rounded-2xl shadow-2xl shadow-blue-900/50 mb-4" />
          <h1 className="text-2xl font-bold text-zinc-100">SawYunPos</h1>
          <p className="text-zinc-500 text-sm mt-1">{t('auth.tagline')}</p>
        </div>
        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-2xl text-center space-y-4">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-red-950 border border-red-800 mb-2">
            <IconAlert width="24" height="24" className="text-red-400" />
          </div>
          <h2 className="text-lg font-semibold text-zinc-100">{t('auth.invalid_reset_link')}</h2>
          <p className="text-zinc-400 text-sm">
            {t('auth.invalid_reset_link_desc')}
          </p>
          <Btn variant="primary" size="md" fullWidth onClick={() => navigate('/forgot-password')}>
            {t('auth.request_new_link')}
          </Btn>
        </div>
      </div>
    )
  }

  return (
    <div className="relative w-full max-w-md">
      {/* Logo */}
      <div className="text-center mb-8">
        <img src="/logo-icon.png" alt="SawYunPos" className="inline-block w-16 h-16 rounded-2xl shadow-2xl shadow-blue-900/50 mb-4" />
        <h1 className="text-2xl font-bold text-zinc-100">SawYunPos</h1>
        <p className="text-zinc-500 text-sm mt-1">{t('auth.tagline')}</p>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-2xl">
        {success ? (
          /* Success state */
          <div className="text-center space-y-4">
            <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-amber-500/10 border border-amber-500/30 mb-2">
              <svg className="w-6 h-6 text-amber-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h2 className="text-lg font-semibold text-zinc-100">{t('auth.password_reset_success')}</h2>
            <p className="text-zinc-400 text-sm">
              {t('auth.password_reset_redirect')}
            </p>
            <Spinner size={20} />
          </div>
        ) : (
          /* Form state */
          <>
            <div className="mb-5">
              <h2 className="text-lg font-semibold text-zinc-100">{t('auth.set_new_password')}</h2>
              <p className="text-zinc-500 text-xs mt-1">
                {t('auth.password_strength_hint')}
              </p>
            </div>

            <form onSubmit={handleSubmit} noValidate>
              <div className="space-y-3">
                <PasswordInput
                  label={t('auth.new_password')}
                  value={password}
                  onChange={e => { setPassword(e.target.value); setError(null) }}
                  placeholder={t('auth.new_password_placeholder')}
                  autoComplete="new-password"
                  required
                />
                <PasswordInput
                  label={t('auth.confirm_new_password')}
                  value={confirm}
                  onChange={e => { setConfirm(e.target.value); setError(null) }}
                  placeholder={t('auth.repeat_new_password_placeholder')}
                  autoComplete="new-password"
                  required
                />

                {error && (
                  <div className="flex gap-2.5 px-3 py-2.5 rounded-xl bg-red-950 border border-red-800 text-red-400 text-xs">
                    <IconAlert width="14" height="14" className="flex-shrink-0 mt-0.5" />
                    <span>{error}</span>
                  </div>
                )}

                <Btn
                  type="submit"
                  variant="primary"
                  size="xl"
                  fullWidth
                  disabled={!password || !confirm || isLoading}
                  className="mt-1"
                >
                  {isLoading ? (
                    <><Spinner size={18} /> {t('common.saving')}</>
                  ) : (
                    t('auth.reset_password_btn')
                  )}
                </Btn>
              </div>
            </form>
          </>
        )}

        {token && !success && (
          <div className="mt-4 pt-4 border-t border-zinc-800 text-center">
            <p className="text-zinc-600 text-xs mb-2">{t('auth.android_reset_hint')}</p>
            <a
              href={`pos://reset-password?token=${token}`}
              className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg bg-zinc-800 border border-zinc-700 text-zinc-400 text-xs hover:text-zinc-200 hover:border-zinc-600 transition-colors"
            >
              <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" />
              </svg>
              {t('auth.open_in_app')}
            </a>
          </div>
        )}
      </div>

      {!success && (
        <p className="text-center text-zinc-600 text-xs mt-4">
          {t('auth.remember_password')}{' '}
          <Link to="/login" className="text-amber-500 hover:text-amber-400">
            {t('auth.back_to_sign_in')}
          </Link>
        </p>
      )}
    </div>
  )
}
