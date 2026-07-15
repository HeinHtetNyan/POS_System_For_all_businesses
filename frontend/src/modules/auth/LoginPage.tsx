import { useState, type FormEvent } from 'react'
import { useNavigate, useLocation, Link } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '@/store/auth.store'
import { ROLE_HOME, canAccess } from '@/shared/constants/rbac'
import type { UserRole } from '@/shared/types'
import { Btn, Input, PasswordInput, Spinner } from '@/components/ui/index'
import { IconAlert, IconSmartphone, IconMonitor } from '@/components/icons'
import { getMobileDownloadLink } from '@/shared/constants/appDownloads'
import { buildChannelLinkChips } from '@/shared/constants/channelLinks'
import { fmtDate } from '@/lib/utils'
import { useLocaleStore } from '@/i18n/localeStore'
import { subscriptionsService } from '@/services/subscriptions/subscriptions.service'

type LoginMode = 'owner' | 'staff'

export default function LoginPage() {
  const navigate  = useNavigate()
  const location  = useLocation()
  const { login, isLoading, error, clearError } = useAuthStore()
  const t = useLocaleStore(s => s.t)

  // Public, unauthenticated — safe to fetch before sign-in. Super Admin edits
  // these under App Download Links; empty fields render as "Coming Soon".
  const { data: downloadLinks } = useQuery({
    queryKey: ['public', 'app-download-links'],
    queryFn: subscriptionsService.getPublicAppDownloadLinks,
    staleTime: 5 * 60 * 1000,
  })

  const [mode, setMode]               = useState<LoginMode>('owner')
  const [identifier, setIdentifier]   = useState('')  // email or phone for owner/reseller
  const [password, setPassword]       = useState('')
  const [businessCode, setBusinessCode] = useState('')
  const [staffIdentifier, setStaffIdentifier] = useState('')

  function switchMode(m: LoginMode) {
    setMode(m)
    clearError()
  }

  function buildOwnerPayload() {
    return { email: identifier.trim(), password }
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    clearError()
    try {
      if (mode === 'owner') {
        await login(buildOwnerPayload())
      } else {
        await login({
          business_code: businessCode.trim().toUpperCase(),
          identifier: staffIdentifier.trim(),
          password,
        })
      }
      const from = (location.state as { from?: { pathname: string } })?.from?.pathname
      const user = useAuthStore.getState().user
      const home = user ? (ROLE_HOME[user.role] ?? '/app/pos') : '/app/pos'
      const ROLE_PREFIXES: Record<string, string[]> = {
        SUPER_ADMIN:     ['/super-admin', '/app'],
        RESELLER:        ['/reseller'],
        BUSINESS_OWNER:  ['/app'],
        MANAGER:         ['/app'],
        CASHIER:         ['/app'],
        INVENTORY_STAFF: ['/app'],
      }
      const allowed = user ? (ROLE_PREFIXES[user.role] ?? []) : []

      // Also validate the specific section in the from path — prefix match alone isn't
      // enough because e.g. a CASHIER can reach /app/* but not /app/settings.
      function isSectionAllowed(path: string, role: UserRole): boolean {
        const match = path.match(/^\/app\/([^/]+)/)
        if (!match) return true
        return canAccess(role, match[1])
      }

      const safeFrom =
        from &&
        allowed.some(p => from.startsWith(p)) &&
        (!user || isSectionAllowed(from, user.role as UserRole))
          ? from
          : null
      navigate(safeFrom ?? home, { replace: true })
    } catch {
      // error is already set in store
    }
  }

  const ownerReady = !!identifier && !!password
  const staffReady = !!businessCode && !!staffIdentifier && !!password
  const canSubmit  = !isLoading && (mode === 'owner' ? ownerReady : staffReady)

  return (
    <div className="relative w-full max-w-md">
      {/* Logo */}
      <div className="text-center mb-8">
        <img src="/logo-icon.png" alt="SawYunPos" className="inline-block w-16 h-16 rounded-2xl shadow-2xl shadow-blue-900/50 mb-4" />
        <h1 className="text-2xl font-bold text-zinc-100">SawYunPos</h1>
        <p className="text-zinc-500 text-sm mt-1">{t('auth.tagline')}</p>
      </div>

      {/* Card */}
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-2xl">
        {/* Tab toggle */}
        <div className="flex bg-zinc-950 rounded-xl p-1 mb-5 gap-1">
          {(['owner', 'staff'] as const).map(m => (
            <button
              key={m}
              type="button"
              onClick={() => switchMode(m)}
              className={`flex-1 py-2 rounded-lg text-xs font-semibold transition-all ${
                mode === m
                  ? 'bg-amber-500 text-black shadow'
                  : 'text-zinc-400 hover:text-zinc-100'
              }`}
            >
              {m === 'owner' ? t('auth.tab_owner') : t('settings.tab.staff')}
            </button>
          ))}
        </div>

        <form onSubmit={handleSubmit} noValidate>
          <div className="space-y-3">
            {mode === 'owner' ? (
              <>
                <Input
                  label={t('settings.email')}
                  type="email"
                  value={identifier}
                  onChange={e => { setIdentifier(e.target.value); clearError() }}
                  placeholder={t('auth.email_placeholder')}
                  autoComplete="username"
                  required
                />
                <p className="text-[11px] text-zinc-600 -mt-1">
                  {t('auth.owner_login_hint')}
                </p>
                <div>
                  <PasswordInput
                    label={t('auth.password')}
                    value={password}
                    onChange={e => { setPassword(e.target.value); clearError() }}
                    placeholder={t('auth.password_placeholder')}
                    autoComplete="current-password"
                    required
                  />
                  <div className="text-right mt-1">
                    <Link to="/forgot-password" className="text-xs text-zinc-500 hover:text-amber-400 transition-colors">
                      {t('auth.forgot_password')}
                    </Link>
                  </div>
                </div>
              </>
            ) : (
              <>
                <Input
                  label={t('auth.business_code')}
                  type="text"
                  value={businessCode}
                  onChange={e => { setBusinessCode(e.target.value.toUpperCase()); clearError() }}
                  placeholder={t('auth.business_code_placeholder')}
                  autoComplete="off"
                  required
                />
                <p className="text-[11px] text-zinc-600 -mt-1">
                  {t('auth.business_code_hint')}
                </p>
                <Input
                  label={t('auth.phone_or_email')}
                  type="text"
                  value={staffIdentifier}
                  onChange={e => { setStaffIdentifier(e.target.value); clearError() }}
                  placeholder={t('auth.phone_or_email_placeholder')}
                  autoComplete="username"
                  required
                />
                <PasswordInput
                  label={t('auth.password')}
                  value={password}
                  onChange={e => { setPassword(e.target.value); clearError() }}
                  placeholder={t('auth.password_placeholder')}
                  autoComplete="current-password"
                  required
                />
              </>
            )}

            {error && (
              <div className="flex gap-2.5 px-3 py-2.5 rounded-xl bg-red-950 border border-red-800 text-red-400 text-xs">
                <IconAlert width="14" height="14" className="flex-shrink-0 mt-0.5" />
                <div className="flex flex-col gap-1">
                  <span>{error}</span>
                  {mode === 'owner' && error.includes('incorrect') && (
                    <span className="text-red-500/70">
                      {t('auth.no_account')}{' '}
                      <a href="/register" className="underline text-red-400 hover:text-red-300">
                        {t('auth.register_here')}
                      </a>
                    </span>
                  )}
                </div>
              </div>
            )}

            <Btn
              type="submit"
              variant="primary"
              size="xl"
              fullWidth
              disabled={!canSubmit}
              className="mt-1"
            >
              {isLoading ? (
                <><Spinner size={18} /> {t('auth.signing_in')}</>
              ) : (
                t('auth.sign_in')
              )}
            </Btn>
          </div>
        </form>
      </div>

      {mode === 'owner' && (
        <p className="text-center text-zinc-600 text-xs mt-4">
          {t('auth.no_account')}{' '}
          <Link to="/register" className="text-amber-500 hover:text-amber-400">
            {t('auth.start_free_trial')}
          </Link>
        </p>
      )}

      {/* Mobile / desktop app downloads — editable in Super Admin > App Download Links */}
      <LinkChipRow
        links={[
          { icon: IconSmartphone, label: t('auth.download_mobile_app'),  href: getMobileDownloadLink(downloadLinks) },
          { icon: IconMonitor,    label: t('auth.download_windows_app'), href: downloadLinks?.windows ?? '' },
        ]}
        comingSoonLabel={t('auth.coming_soon')}
      />

      {/* Channel links — same Super Admin > All Links page. Unlike the
          downloads row above, these are simply omitted when unset instead of
          showing a disabled "Coming Soon" placeholder. */}
      <LinkChipRow
        hideEmpty
        links={buildChannelLinkChips(downloadLinks)}
        comingSoonLabel={t('auth.coming_soon')}
      />

      <p className="text-center text-zinc-600 text-[11px] mt-3">
        SawYunPos v1.0 · {fmtDate(new Date())}
      </p>
    </div>
  )
}

type LinkChipDef = { icon: typeof IconSmartphone; label: string; href: string }

// Shared chip look for the app-download row and the channel-links row.
// Downloads show a disabled "Coming Soon" placeholder when unset (there's a
// fixed, known set of platforms worth advertising as upcoming); channel
// links (hideEmpty) are simply omitted when unset instead — there's no
// fixed "expected" set of social/contact links to advertise.
function LinkChipRow({ links, comingSoonLabel, hideEmpty = false, className }: { links: LinkChipDef[]; comingSoonLabel: string; hideEmpty?: boolean; className?: string }) {
  const visible = hideEmpty ? links.filter(l => !!l.href) : links
  if (visible.length === 0) return null

  return (
    <div className={
      className ??
      (hideEmpty
        ? 'flex flex-wrap justify-center gap-2 mt-4'
        : 'grid grid-cols-2 gap-3 mt-4')
    }>
      {visible.map(({ icon: Icon, label, href }) => {
        const isLive = !!href
        const chipClassName = hideEmpty
          ? 'flex items-center gap-1.5 px-3 py-2 rounded-lg bg-zinc-900 border border-zinc-700 text-zinc-300 text-xs font-medium hover:border-amber-500/50 hover:text-amber-400 transition-colors'
          : `relative flex flex-col items-center justify-center gap-1 rounded-xl py-3 transition-colors ${
              isLive
                ? 'bg-zinc-900 border border-zinc-700 text-zinc-200 hover:border-amber-500/50 hover:text-amber-400'
                : 'bg-zinc-900/60 border border-zinc-800 text-zinc-500 cursor-not-allowed'
            }`
        const content = hideEmpty ? (
          <>
            <Icon width="16" height="16" />
            {label}
          </>
        ) : (
          <>
            {!isLive && (
              <span className="absolute top-1.5 right-1.5 bg-amber-500/15 text-amber-400 text-[9px] font-semibold uppercase tracking-wide rounded-full px-1.5 py-0.5">
                {comingSoonLabel}
              </span>
            )}
            <Icon width="18" height="18" />
            <span className="text-[11px] font-medium">{label}</span>
          </>
        )
        return isLive ? (
          <a key={label} href={href} target="_blank" rel="noopener noreferrer" className={chipClassName}>
            {content}
          </a>
        ) : (
          <button key={label} type="button" disabled className={chipClassName}>
            {content}
          </button>
        )
      })}
    </div>
  )
}
