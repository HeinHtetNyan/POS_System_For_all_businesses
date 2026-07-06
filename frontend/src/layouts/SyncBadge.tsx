import { lazy, Suspense, useState } from 'react'
import { useUIStore } from '@/store/ui.store'
import { IconWifi, IconWifiOff, IconAlert } from '@/components/icons'

const SyncIssuesModal = lazy(() => import('./SyncIssuesModal'))

export default function SyncBadge() {
  const isOnline = useUIStore(s => s.isOnline)
  const pendingSyncCount = useUIStore(s => s.pendingSyncCount)
  const failedSyncCount = useUIStore(s => s.failedSyncCount)
  const [showIssues, setShowIssues] = useState(false)

  return (
    <div className="inline-flex items-center gap-2">
      {isOnline ? (
        <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-green-950 border border-green-800 text-green-400 text-xs font-medium">
          <IconWifi width="13" height="13" />
          <span>Online</span>
        </span>
      ) : (
        <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-red-950 border border-red-800 text-red-400 text-xs font-medium">
          <IconWifiOff width="13" height="13" />
          <span>Offline</span>
        </span>
      )}

      {pendingSyncCount > 0 && (
        <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-amber-950 border border-amber-800 text-amber-400 text-xs font-medium">
          <span>Syncing {pendingSyncCount}…</span>
        </span>
      )}

      {failedSyncCount > 0 && (
        <button
          onClick={() => setShowIssues(true)}
          className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-red-950 border border-red-800 text-red-400 text-xs font-medium hover:bg-red-900 transition-colors"
        >
          <IconAlert width="13" height="13" />
          <span>{failedSyncCount} sync issue{failedSyncCount > 1 ? 's' : ''}</span>
        </button>
      )}

      {showIssues && (
        <Suspense fallback={null}>
          <SyncIssuesModal onClose={() => setShowIssues(false)} />
        </Suspense>
      )}
    </div>
  )
}
