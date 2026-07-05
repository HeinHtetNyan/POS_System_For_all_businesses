import { useState, type FormEvent } from 'react'
import { Link } from 'react-router-dom'
import { Btn, Input, Spinner } from '@/components/ui/index'
import { IconAlert } from '@/components/icons'
import { authService } from '@/services/auth/auth.service'

export default function ForgotPasswordPage() {
  const [email, setEmail]       = useState('')
  const [isLoading, setLoading] = useState(false)
  const [error, setError]       = useState<string | null>(null)
  const [sent, setSent]         = useState(false)

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setLoading(true)
    try {
      await authService.forgotPassword(email.trim().toLowerCase())
      setSent(true)
    } catch (err: unknown) {
      const msg =
        (err as { response?: { data?: { detail?: string; error?: { message?: string } } } })
          ?.response?.data?.error?.message ??
        (err as { response?: { data?: { detail?: string } } })?.response?.data?.detail ??
        'Something went wrong. Please try again.'
      setError(msg)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="relative w-full max-w-md">
      {/* Logo */}
      <div className="text-center mb-8">
        <img src="/logo-icon.png" alt="SawYunPos" className="inline-block w-16 h-16 rounded-2xl shadow-2xl shadow-blue-900/50 mb-4" />
        <h1 className="text-2xl font-bold text-zinc-100">SawYunPos</h1>
        <p className="text-zinc-500 text-sm mt-1">Enterprise Point of Sale</p>
      </div>

      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-2xl">
        {sent ? (
          /* Success state */
          <div className="text-center space-y-4">
            <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-amber-500/10 border border-amber-500/30 mb-2">
              <svg className="w-6 h-6 text-amber-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
            </div>
            <h2 className="text-lg font-semibold text-zinc-100">Check your email</h2>
            <p className="text-zinc-400 text-sm leading-relaxed">
              If an account with <span className="text-zinc-200 font-medium">{email}</span> exists,
              a password reset link has been sent. Check your inbox and spam folder.
            </p>
            <p className="text-zinc-600 text-xs">The link expires in 15 minutes.</p>
            <Btn variant="secondary" size="md" fullWidth onClick={() => { setSent(false); setEmail('') }}>
              Try a different email
            </Btn>
          </div>
        ) : (
          /* Form state */
          <>
            <div className="mb-5">
              <h2 className="text-lg font-semibold text-zinc-100">Forgot your password?</h2>
              <p className="text-zinc-500 text-xs mt-1">
                Enter your email address and we'll send you a reset link.
                Available for business owners and resellers only.
              </p>
            </div>

            <form onSubmit={handleSubmit} noValidate>
              <div className="space-y-3">
                <Input
                  label="Email address"
                  type="email"
                  value={email}
                  onChange={e => { setEmail(e.target.value); setError(null) }}
                  placeholder="you@company.com"
                  autoComplete="email"
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
                  disabled={!email.trim() || isLoading}
                  className="mt-1"
                >
                  {isLoading ? (
                    <><Spinner size={18} /> Sending…</>
                  ) : (
                    'Send reset link'
                  )}
                </Btn>
              </div>
            </form>
          </>
        )}
      </div>

      <p className="text-center text-zinc-600 text-xs mt-4">
        Remember your password?{' '}
        <Link to="/login" className="text-amber-500 hover:text-amber-400">
          Back to sign in
        </Link>
      </p>
    </div>
  )
}
