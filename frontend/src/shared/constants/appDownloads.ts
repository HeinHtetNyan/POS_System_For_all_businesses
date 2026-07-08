import type { AppDownloadLinks } from '@/shared/types'

// Single "Mobile App" button needs one link — send Android users to the Play
// Store and everyone else (iOS, desktop browsers) to the App Store link,
// falling back to whichever of the two is actually set. Links themselves are
// no longer hardcoded here — they're editable in Super Admin > App Download
// Links and fetched from GET /public/app-download-links.
export function getMobileDownloadLink(links: AppDownloadLinks | undefined): string {
  if (!links) return ''
  const isAndroid = typeof navigator !== 'undefined' && /Android/i.test(navigator.userAgent)
  return isAndroid ? (links.android || links.ios) : (links.ios || links.android)
}
