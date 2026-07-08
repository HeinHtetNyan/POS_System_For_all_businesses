import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuthStore } from '@/store/auth.store'
import { ROLE_HOME } from '@/shared/constants/rbac'
import { useLocaleStore } from '@/i18n/localeStore'
import { IconGlobe } from '@/components/icons'

interface AuthLayoutProps {
  children: ReactNode
  // Pages like /verify-email are meaningful to visit even while logged in
  // (e.g. a business owner clicking the emailed link without ever logging
  // out after registering) — set this to skip the normal "already signed
  // in, redirect to my dashboard" behavior used by login/register/etc.
  allowAuthenticated?: boolean
}

// Pre-auth pages have no tenant yet, so there's nothing to fetch a saved
// locale from — this toggle just flips the in-memory locale store directly.
// Once the user signs in, TenantFormatterSync takes over and re-syncs the
// locale from the tenant's saved setting, which is expected: this switch
// only controls what language the auth screens themselves are shown in.
function LanguageToggle() {
  const locale = useLocaleStore(s => s.locale)
  const setLocale = useLocaleStore(s => s.setLocale)
  const t = useLocaleStore(s => s.t)
  const isMyanmar = locale === 'my-MM'

  return (
    <button
      type="button"
      onClick={() => setLocale(isMyanmar ? 'en-US' : 'my-MM')}
      aria-label={t('auth.switch_language')}
      title={t('auth.switch_language')}
      className="fixed top-4 right-4 z-10 flex items-center gap-1.5 bg-zinc-900 border border-zinc-800 rounded-full pl-2.5 pr-3 py-1.5 text-xs font-medium text-zinc-300 hover:border-zinc-600 hover:text-zinc-100 transition-colors shadow-lg"
    >
      <IconGlobe width="14" height="14" />
      {isMyanmar ? 'English' : 'မြန်မာ'}
    </button>
  )
}

export default function AuthLayout({ children, allowAuthenticated = false }: AuthLayoutProps) {
  const { user, isAuthenticated } = useAuthStore()

  // Already authenticated — redirect to role home
  if (isAuthenticated && user && !allowAuthenticated) {
    const home = ROLE_HOME[user.role] ?? '/app/pos'
    return <Navigate to={home} replace />
  }

  return (
    <div className="h-full overflow-y-auto" style={{ backgroundColor: '#09090B' }}>
      {/* Grid pattern background */}
      <div
        className="fixed inset-0 pointer-events-none"
        style={{
          backgroundImage: `
            linear-gradient(rgba(217,119,6,0.03) 1px, transparent 1px),
            linear-gradient(90deg, rgba(217,119,6,0.03) 1px, transparent 1px)
          `,
          backgroundSize: '40px 40px',
        }}
      />
      <LanguageToggle />
      {/* Center content, but allow scroll when content is taller than viewport */}
      <div className="relative min-h-full flex items-center justify-center px-4 py-8">
        <div className="w-full max-w-md">
          {children}
        </div>
      </div>
    </div>
  )
}
