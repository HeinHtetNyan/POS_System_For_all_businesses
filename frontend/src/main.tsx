import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { RouterProvider } from 'react-router-dom'
import './index.css'
import { Providers } from './app/providers'
import { router } from './app/router'

// When a new deploy invalidates a lazy chunk, Vite fires this event.
// Reloading fetches the fresh index.html + new chunk filenames automatically.
window.addEventListener('vite:preloadError', () => {
  window.location.reload()
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Providers>
      <RouterProvider router={router} />
    </Providers>
  </StrictMode>,
)
