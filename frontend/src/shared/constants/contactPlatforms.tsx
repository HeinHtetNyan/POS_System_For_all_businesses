import type { ContactLinks } from '@/shared/types'

export const CONTACT_PLATFORMS = [
  {
    key: 'phone' as const,
    label: 'Call Us',
    color: 'hover:bg-green-500/20 hover:border-green-500/50 hover:text-green-300',
    icon: (
      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
        <path d="M6.62 10.79a15.05 15.05 0 0 0 6.59 6.59l2.2-2.2a1 1 0 0 1 1.01-.24 11.36 11.36 0 0 0 3.57.57 1 1 0 0 1 1 1V20a1 1 0 0 1-1 1A17 17 0 0 1 3 4a1 1 0 0 1 1-1h3.5a1 1 0 0 1 1 1 11.36 11.36 0 0 0 .57 3.57 1 1 0 0 1-.25 1.01l-2.2 2.21z"/>
      </svg>
    ),
  },
  {
    key: 'email' as const,
    label: 'Email',
    color: 'hover:bg-amber-500/20 hover:border-amber-500/50 hover:text-amber-300',
    icon: (
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <rect x="2" y="4" width="20" height="16" rx="2" /><path d="m22 6-10 7L2 6" />
      </svg>
    ),
  },
  {
    key: 'viber' as const,
    label: 'Viber',
    color: 'hover:bg-violet-500/20 hover:border-violet-500/50 hover:text-violet-300',
    icon: (
      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
        <path d="M11.4 0C5.5 0 .8 4.5.8 10.1c0 3 1.4 5.7 3.6 7.5v3.7l3.4-1.9c1 .3 2.1.4 3.2.4 5.9 0 10.6-4.5 10.6-10.1S17.3 0 11.4 0zm1 13.6l-2.5-2.7-4.9 2.7 5.4-5.8 2.6 2.7 4.8-2.7-5.4 5.8z"/>
      </svg>
    ),
  },
  {
    key: 'telegram' as const,
    label: 'Telegram',
    color: 'hover:bg-sky-500/20 hover:border-sky-500/50 hover:text-sky-300',
    icon: (
      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
        <path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.96 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.244-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/>
      </svg>
    ),
  },
  {
    key: 'facebook' as const,
    label: 'Facebook',
    color: 'hover:bg-blue-500/20 hover:border-blue-500/50 hover:text-blue-300',
    icon: (
      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
        <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
      </svg>
    ),
  },
  {
    key: 'tiktok' as const,
    label: 'TikTok',
    color: 'hover:bg-pink-500/20 hover:border-pink-500/50 hover:text-pink-300',
    icon: (
      <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
        <path d="M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-2.88 2.5 2.89 2.89 0 0 1-2.89-2.89 2.89 2.89 0 0 1 2.89-2.89c.28 0 .54.04.79.1V9.01a6.33 6.33 0 0 0-.79-.05 6.34 6.34 0 0 0-6.34 6.34 6.34 6.34 0 0 0 6.34 6.34 6.34 6.34 0 0 0 6.34-6.34V8.69a8.18 8.18 0 0 0 4.78 1.52V6.74a4.85 4.85 0 0 1-1.02-.05z"/>
      </svg>
    ),
  },
]

// phone/email are raw numbers/addresses, not clickable URLs by themselves —
// every other platform already stores a ready-to-use link.
export function contactHref(key: keyof ContactLinks, value: string): string {
  if (key === 'phone') return `tel:${value.replace(/[^\d+]/g, '')}`
  if (key === 'email') return `mailto:${value}`
  return value
}
