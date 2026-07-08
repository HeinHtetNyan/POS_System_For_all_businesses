import type { ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { useSessionStore } from '@/store/session.store'
import { useUIStore } from '@/store/ui.store'
import { IconWifi, IconWifiOff, IconLogout } from '@/components/icons'
import SyncBadge from '@/layouts/SyncBadge'
import { useLocaleStore } from '@/i18n/localeStore'

interface POSLayoutProps {
  children: ReactNode
}

export default function POSLayout({ children }: POSLayoutProps) {
  const navigate = useNavigate()
  const { activeSession } = useSessionStore()
  const { isOnline, toggleOnline } = useUIStore()
  const t = useLocaleStore(s => s.t)

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* POS-specific top bar */}
      <header className="flex items-center gap-3 px-4 py-2.5 border-b border-zinc-800 bg-zinc-950 flex-shrink-0">
        <div className="hidden sm:flex items-center gap-2">
          <img src="/logo-icon.png" alt="SawYunPos" className="w-6 h-6 rounded-md flex-shrink-0" />
          <span className="text-xs font-semibold text-zinc-400">{t('nav.checkout')}</span>
        </div>
        {activeSession && (
          <div className="hidden md:flex items-center gap-2 px-3 py-1 bg-zinc-900 rounded-lg border border-zinc-800">
            <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
            <span className="text-xs text-zinc-400 font-mono">{activeSession.id.slice(0, 8)}…</span>
          </div>
        )}
        <div className="flex-1" />
        <SyncBadge />
        <button
          onClick={toggleOnline}
          title={isOnline ? t('pos.layout_simulate_offline') : t('pos.layout_go_online')}
          aria-label={isOnline ? t('pos.layout_simulate_offline') : t('pos.layout_go_online')}
          className={`w-8 h-8 rounded-lg flex items-center justify-center transition-colors ${isOnline ? 'text-zinc-600 hover:bg-zinc-800' : 'text-red-500 bg-red-950/40'}`}
        >
          {isOnline ? <IconWifi width="14" height="14" /> : <IconWifiOff width="14" height="14" />}
        </button>
        <button
          onClick={() => navigate('/app/session-close')}
          title={t('auth.session_close.title')}
          aria-label={t('auth.session_close.title')}
          className="flex items-center gap-1.5 px-3 py-1.5 text-xs text-zinc-500 hover:text-red-400 rounded-lg hover:bg-red-950/30 transition-all border border-transparent hover:border-red-900/40"
        >
          <IconLogout width="13" height="13" />
          <span className="hidden sm:inline">{t('auth.session_close.title')}</span>
        </button>
      </header>
      <div className="flex-1 overflow-hidden">
        {children}
      </div>
    </div>
  )
}
