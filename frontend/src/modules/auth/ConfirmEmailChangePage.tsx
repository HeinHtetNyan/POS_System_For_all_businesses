import { useEffect, useState } from 'react'
import { Link, useSearchParams, useNavigate } from 'react-router-dom'
import { Btn, Spinner } from '@/components/ui/index'
import { IconAlert } from '@/components/icons'
import { authService } from '@/services/auth/auth.service'
import { useAuthStore } from '@/store/auth.store'

export default function ConfirmEmailChangePage() {
  const [searchParams] = useSearchParams()
  const navigate        = useNavigate()
  const token            = searchParams.get('token') ?? ''

  const [status, setStatus] = useState<'loading' | 'success' | 'error'>(token ? 'loading' : 'error')
  const [message, setMessage] = useState<string | null>(
    token ? null : 'This confirmation link is missing or invalid. Please request the change again.',
  )

  useEffect(() => {
    if (!token) return
    let cancelled = false
    authService.confirmEmailChange(token)
      .then(() => {
        if (cancelled) return
        setStatus('success')
        // Refresh the cached user so the profile page shows the new email
        // immediately if they're still logged in on this device.
        if (useAuthStore.getState().isAuthenticated) {
          useAuthStore.getState().fetchMe().catch(() => {})
        }
      })
      .catch((err: unknown) => {
        if (cancelled) return
        const msg =
          (err as { response?: { data?: { error?: { message?: string } } } })
            ?.response?.data?.error?.message ??
          (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail ??
          'This confirmation link is invalid or has expired. Please request the change again.'
        setMessage(msg)
        setStatus('error')
      })
    return () => { cancelled = true }
  }, [token])

  return (
    <div className="relative w-full max-w-md">
      {/* Logo */}
      <div className="text-center mb-8">
        <img src="/logo-icon.png" alt="SawYunPos" className="inline-block w-16 h-16 rounded-2xl shadow-2xl shadow-blue-900/50 mb-4" />
        <h1 className="text-2xl font-bold text-zinc-100">SawYunPos</h1>
        <p className="text-zinc-500 text-sm mt-1">Enterprise Point of Sale</p>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-2xl text-center space-y-4">
        {status === 'loading' && (
          <>
            <Spinner size={28} />
            <h2 className="text-lg font-semibold text-zinc-100">Confirming your new email…</h2>
          </>
        )}

        {status === 'success' && (
          <>
            <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-amber-500/10 border border-amber-500/30 mb-2">
              <svg className="w-6 h-6 text-amber-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h2 className="text-lg font-semibold text-zinc-100">Email updated!</h2>
            <p className="text-zinc-400 text-sm">
              Your account's email address has been changed. Use your new email to sign in from now on.
            </p>
            <Btn variant="primary" size="md" fullWidth onClick={() => navigate('/login')}>
              Continue to sign in
            </Btn>
          </>
        )}

        {status === 'error' && (
          <>
            <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-red-950 border border-red-800 mb-2">
              <IconAlert width="24" height="24" className="text-red-400" />
            </div>
            <h2 className="text-lg font-semibold text-zinc-100">Confirmation failed</h2>
            <p className="text-zinc-400 text-sm">{message}</p>
            <Btn variant="primary" size="md" fullWidth onClick={() => navigate('/login')}>
              Back to sign in
            </Btn>
          </>
        )}
      </div>

      {status === 'error' && (
        <p className="text-center text-zinc-600 text-xs mt-4">
          You can request the change again from your profile settings after signing in.{' '}
          <Link to="/login" className="text-amber-500 hover:text-amber-400">
            Sign in
          </Link>
        </p>
      )}
    </div>
  )
}
