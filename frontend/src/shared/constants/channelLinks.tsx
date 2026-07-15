import { IconYoutube, IconTelegram, IconViber, IconPhoneCall, IconMail, IconFacebook, IconTiktok, IconSmartphone } from '@/components/icons'
import type { AppDownloadLinks } from '@/shared/types'

export type ChannelLinkChip = { icon: typeof IconSmartphone; label: string; href: string }

// The 7 Channel Links fields, superadmin-editable at Super Admin > All Links
// (same resource as the Android/iOS/Windows download links). Used anywhere
// a "contact us" chip row is shown — the login page and custom/Enterprise
// plan cards (Pricing page + in-app Subscription page) — so there's one
// single source of truth instead of a separate per-plan value.
export function buildChannelLinkChips(links: AppDownloadLinks | undefined): ChannelLinkChip[] {
  const chips: ChannelLinkChip[] = [
    { icon: IconYoutube,   label: 'YouTube',  href: links?.youtube ?? '' },
    { icon: IconTelegram,  label: 'Telegram', href: links?.telegram ?? '' },
    { icon: IconViber,     label: 'Viber',    href: links?.viber ?? '' },
    { icon: IconPhoneCall, label: 'Phone',    href: links?.phone ? `tel:${links.phone}` : '' },
    { icon: IconMail,      label: 'Email',    href: links?.email ? `mailto:${links.email}` : '' },
    { icon: IconFacebook,  label: 'Facebook', href: links?.facebook ?? '' },
    { icon: IconTiktok,    label: 'TikTok',   href: links?.tiktok ?? '' },
  ]
  return chips.filter(c => !!c.href)
}
