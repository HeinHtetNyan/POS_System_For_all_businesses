import { useState, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { Btn, Spinner } from '@/components/ui'
import { subscriptionsService } from '@/services/subscriptions/subscriptions.service'
import { extractApiMsg } from '@/lib/utils'
import { IconSmartphone, IconMonitor } from '@/components/icons'
import type { AppDownloadLinks } from '@/shared/types'

const EMPTY: AppDownloadLinks = { android: '', ios: '', windows: '' }

const FIELDS: { key: keyof AppDownloadLinks; icon: typeof IconSmartphone; label: string; placeholder: string; hint?: string }[] = [
  {
    key: 'android', icon: IconSmartphone, label: 'Android (Google Play)',
    placeholder: 'https://play.google.com/store/apps/details?id=...',
    hint: 'If this isn\'t a Play Store link (e.g. a direct .apk or Google Drive link), the device will show an "Install unknown apps" warning that users have to approve manually.',
  },
  {
    key: 'ios', icon: IconSmartphone, label: 'iOS (App Store)',
    placeholder: 'https://apps.apple.com/app/id...',
    hint: 'iOS only allows installs via the App Store or TestFlight. A direct file link (e.g. Google Drive) lets users download the file but they can\'t actually install it — use a TestFlight link here if the app isn\'t on the App Store yet.',
  },
  { key: 'windows', icon: IconMonitor, label: 'Windows', placeholder: 'https://.../SawYunPos-Setup.exe' },
]

function isValidUrl(value: string) {
  if (!value) return true
  try {
    const u = new URL(value)
    return u.protocol === 'http:' || u.protocol === 'https:'
  } catch {
    return false
  }
}

export default function AppDownloadLinksPage() {
  const qc = useQueryClient()
  const [links, setLinks] = useState<AppDownloadLinks>(EMPTY)
  const [dirty, setDirty] = useState(false)

  const { data: savedLinks, isLoading } = useQuery({
    queryKey: ['platform', 'app-download-links'],
    queryFn: subscriptionsService.adminGetPlatformAppDownloadLinks,
    staleTime: 30_000,
  })

  useEffect(() => {
    if (savedLinks) {
      setLinks(savedLinks)
      setDirty(false)
    }
  }, [savedLinks])

  const saveMutation = useMutation({
    mutationFn: (l: AppDownloadLinks) => subscriptionsService.adminSetPlatformAppDownloadLinks(l),
    onSuccess: saved => {
      qc.invalidateQueries({ queryKey: ['platform', 'app-download-links'] })
      // Login page reads this same data pre-auth — keep it in sync immediately.
      qc.invalidateQueries({ queryKey: ['public', 'app-download-links'] })
      setLinks(saved)
      setDirty(false)
      toast.success('App download links saved')
    },
    onError: err => toast.error(extractApiMsg(err) ?? 'Failed to save'),
  })

  function update(key: keyof AppDownloadLinks, value: string) {
    setLinks(prev => ({ ...prev, [key]: value.trim() }))
    setDirty(true)
  }

  const allValid = FIELDS.every(f => isValidUrl(links[f.key]))
  const inp = 'w-full bg-zinc-800 border border-zinc-700 rounded-lg px-2.5 py-1.5 text-sm text-zinc-100 focus:outline-none focus:border-amber-500 transition-colors font-mono'

  if (isLoading) {
    return <div className="flex items-center justify-center h-full"><Spinner size={28} /></div>
  }

  return (
    <div className="flex flex-col h-full overflow-hidden">
      {/* Header */}
      <div className="flex-shrink-0 flex items-center justify-between px-5 py-3.5 border-b border-zinc-800">
        <div>
          <h2 className="text-base font-semibold text-zinc-100">App Download Links</h2>
          <p className="text-xs text-zinc-500 mt-0.5">
            Shown as download buttons on the public login screen. Leave a field empty to show "Coming Soon" for that platform.
          </p>
        </div>
        <div className="flex items-center gap-2">
          {dirty && <span className="text-xs text-amber-400">Unsaved changes</span>}
          <Btn
            size="sm"
            disabled={!dirty || !allValid || saveMutation.isPending}
            onClick={() => saveMutation.mutate(links)}
          >
            {saveMutation.isPending ? 'Saving…' : 'Save Changes'}
          </Btn>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-5">
        <div className="max-w-xl space-y-4">

          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl overflow-hidden divide-y divide-zinc-800">
            {FIELDS.map(({ key, icon: Icon, label, placeholder, hint }) => {
              const value = links[key]
              const valid = isValidUrl(value)
              return (
                <div key={key} className="p-4 flex items-start gap-3">
                  <div className="w-9 h-9 rounded-lg bg-zinc-800 border border-zinc-700 flex items-center justify-center text-zinc-400 flex-shrink-0 mt-4">
                    <Icon width="16" height="16" />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-1">
                      <label className="block text-xs text-zinc-400">{label}</label>
                      {!value && (
                        <span className="text-[9px] font-semibold uppercase tracking-wide text-amber-400 bg-amber-500/15 rounded-full px-1.5 py-0.5">
                          Coming Soon
                        </span>
                      )}
                    </div>
                    <input
                      value={value}
                      onChange={e => update(key, e.target.value)}
                      placeholder={placeholder}
                      className={`${inp} ${!valid ? 'border-red-700 focus:border-red-500' : ''}`}
                    />
                    {!valid && <p className="text-[11px] text-red-400 mt-1">Enter a valid http(s) URL, or leave empty.</p>}
                    {valid && hint && <p className="text-[11px] text-zinc-600 mt-1 leading-relaxed">{hint}</p>}
                  </div>
                </div>
              )
            })}
          </div>

          <div className="flex items-start gap-2.5 px-4 py-3 bg-blue-950/30 border border-blue-800/30 rounded-xl">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="text-blue-400 flex-shrink-0 mt-0.5">
              <circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>
            </svg>
            <p className="text-xs text-blue-300/80 leading-relaxed">
              The login screen's "Mobile App" button uses the Android link for Android visitors and the iOS link for
              everyone else, falling back to whichever one is set if only one is filled in.
            </p>
          </div>

          {dirty && (
            <div className="flex justify-end pb-4">
              <Btn
                disabled={!allValid || saveMutation.isPending}
                onClick={() => saveMutation.mutate(links)}
              >
                {saveMutation.isPending ? 'Saving…' : 'Save Changes'}
              </Btn>
            </div>
          )}

        </div>
      </div>
    </div>
  )
}
