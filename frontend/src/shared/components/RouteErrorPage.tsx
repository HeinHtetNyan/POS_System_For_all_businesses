import { useRouteError, isRouteErrorResponse } from 'react-router-dom'

export default function RouteErrorPage() {
  const error = useRouteError()

  const isChunkError =
    error instanceof Error &&
    (error.message.includes('dynamically imported module') ||
      error.message.includes('Failed to fetch dynamically') ||
      error.name === 'ChunkLoadError')

  const is404 = isRouteErrorResponse(error) && error.status === 404

  return (
    <div className="min-h-screen bg-zinc-950 flex items-center justify-center p-6">
      <div className="max-w-md w-full text-center space-y-6">
        <div className="w-16 h-16 rounded-2xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center mx-auto">
          <span className="text-3xl font-black text-amber-400">N</span>
        </div>

        {isChunkError ? (
          <>
            <div>
              <h1 className="text-xl font-semibold text-zinc-100 mb-2">New version available</h1>
              <p className="text-sm text-zinc-400 leading-relaxed">
                A newer version of the app was deployed. Reload to get the latest version.
              </p>
            </div>
            <button
              onClick={() => window.location.reload()}
              className="px-5 py-2.5 bg-amber-500 hover:bg-amber-400 text-black text-sm font-semibold rounded-xl transition-colors"
            >
              Reload App
            </button>
          </>
        ) : is404 ? (
          <>
            <div>
              <h1 className="text-xl font-semibold text-zinc-100 mb-2">Page not found</h1>
              <p className="text-sm text-zinc-400">The page you're looking for doesn't exist.</p>
            </div>
            <a
              href="/"
              className="inline-block px-5 py-2.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-100 text-sm font-semibold rounded-xl transition-colors"
            >
              Go Home
            </a>
          </>
        ) : (
          <>
            <div>
              <h1 className="text-xl font-semibold text-zinc-100 mb-2">Something went wrong</h1>
              <p className="text-sm text-zinc-400 leading-relaxed">
                {error instanceof Error ? error.message : 'An unexpected error occurred.'}
              </p>
            </div>
            <button
              onClick={() => window.location.reload()}
              className="px-5 py-2.5 bg-zinc-800 hover:bg-zinc-700 text-zinc-100 text-sm font-semibold rounded-xl transition-colors"
            >
              Reload Page
            </button>
          </>
        )}
      </div>
    </div>
  )
}
