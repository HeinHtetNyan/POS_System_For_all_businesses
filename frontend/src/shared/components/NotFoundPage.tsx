import { useNavigate } from 'react-router-dom'
import { useLocaleStore } from '@/i18n/localeStore'

export default function NotFoundPage() {
  const navigate = useNavigate()
  const t = useLocaleStore(s => s.t)

  return (
    <div className="min-h-screen flex items-center justify-center bg-zinc-950 px-4">
      <div className="text-center max-w-sm">
        <p className="text-6xl font-black text-zinc-800 font-mono mb-4">404</p>
        <h1 className="text-xl font-bold text-zinc-100 mb-2">{t('errors.page_not_found')}</h1>
        <p className="text-zinc-500 text-sm mb-6">
          {t('errors.page_not_found_moved_desc')}
        </p>
        <button
          onClick={() => navigate(-1)}
          className="px-5 py-2.5 rounded-xl bg-amber-500 text-black text-sm font-semibold hover:bg-amber-400 transition-colors"
        >
          {t('notif.go_back')}
        </button>
      </div>
    </div>
  )
}
