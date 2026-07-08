import { useRouteError, isRouteErrorResponse } from 'react-router-dom'
import { useLocaleStore } from '@/i18n/localeStore'

export default function RouteErrorPage() {
  const error = useRouteError()
  const t = useLocaleStore(s => s.t)

  const isChunkError =
    error instanceof Error &&
    (error.message.includes('dynamically imported module') ||
      error.message.includes('Failed to fetch dynamically') ||
      error.name === 'ChunkLoadError')

  const is404 = isRouteErrorResponse(error) && error.status === 404

  return (
    <div className="min-h-screen bg-zinc-950 flex items-center justify-center p-6">
      <div className="max-w-md w-full text-center space-y-6">
        <img src="/logo-icon.png" alt="SawYunPos" className="w-16 h-16 rounded-2xl mx-auto opacity-90" />

        {isChunkError ? (
          <>
            <div>
              <h1 className="text-xl font-semibold text-zinc-100 mb-2">{t('errors.new_version_available')}</h1>
              <p className="text-sm text-zinc-400 leading-relaxed">
                {t('errors.new_version_desc')}
              </p>
            </div>
            <button
              onClick={() => window.location.reload()}
              className="px-5 py-2.5 bg-amber-500 hover:bg-amber-400 text-black text-sm font-semibold rounded-xl transition-colors"
            >
              {t('errors.reload_app')}
            </button>
          </>
        ) : is404 ? (
          <>
            <div>
              <h1 className="text-xl font-semibold text-zinc-100 mb-2">{t('errors.page_not_found')}</h1>
              <p className="text-sm text-zinc-400">{t('errors.page_not_found_desc')}</p>
            </div>
            <a
              href="/"
              className="inline-block px-5 py-2.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-100 text-sm font-semibold rounded-xl transition-colors"
            >
              {t('errors.go_home')}
            </a>
          </>
        ) : (
          <>
            <div>
              <h1 className="text-xl font-semibold text-zinc-100 mb-2">{t('errors.something_went_wrong')}</h1>
              <p className="text-sm text-zinc-400 leading-relaxed">
                {import.meta.env.DEV && error instanceof Error
                  ? error.message
                  : t('errors.unexpected_error_reload')}
              </p>
            </div>
            <button
              onClick={() => window.location.reload()}
              className="px-5 py-2.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-100 text-sm font-semibold rounded-xl transition-colors"
            >
              {t('errors.reload_page')}
            </button>
          </>
        )}
      </div>
    </div>
  )
}
