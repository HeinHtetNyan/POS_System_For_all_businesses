import { type ReactNode } from 'react'
import { cn } from '@/lib/utils'
import { Badge } from '@/components/ui'
import { useLocaleStore } from '@/i18n/localeStore'


type BadgeVariant = 'default' | 'success' | 'danger' | 'warning' | 'info' | 'purple' | 'orange'

function poStatusMap(t: (key: string) => string): Record<string, { variant: BadgeVariant; label: string }> {
  return {
    DRAFT:              { variant: 'default', label: t('procurement.po_status_draft')            },
    SUBMITTED:          { variant: 'purple',  label: t('procurement.po_status_pending_approval') },
    APPROVED:           { variant: 'info',    label: t('procurement.po_status_ordered')          },
    PARTIALLY_RECEIVED: { variant: 'warning', label: t('procurement.po_status_partial_receipt')  },
    RECEIVED:           { variant: 'success', label: t('procurement.po_status_received')         },
    CANCELLED:          { variant: 'danger',  label: t('status.cancelled')                       },
  }
}

function payableStatusMap(t: (key: string) => string): Record<string, { variant: BadgeVariant; label: string }> {
  return {
    OPEN:    { variant: 'warning', label: t('procurement.payable_status_open') },
    PARTIAL: { variant: 'info',    label: t('status.partial')                 },
    PAID:    { variant: 'success', label: t('status.paid')                    },
  }
}

function supplierStatusMap(t: (key: string) => string): Record<string, { variant: BadgeVariant; label: string }> {
  return {
    ACTIVE:   { variant: 'success', label: t('status.active')                    },
    INACTIVE: { variant: 'default', label: t('status.inactive')                  },
    BLOCKED:  { variant: 'danger',  label: t('procurement.supplier_status_blocked') },
  }
}

export function POStatusBadge({ status }: { status: string }) {
  const t = useLocaleStore(s => s.t)
  const m = poStatusMap(t)[status] ?? { variant: 'default' as BadgeVariant, label: status }
  return <Badge variant={m.variant} size="xs" dot>{m.label}</Badge>
}

export function PayableStatusBadge({ status }: { status: string }) {
  const t = useLocaleStore(s => s.t)
  const m = payableStatusMap(t)[status] ?? { variant: 'default' as BadgeVariant, label: status }
  return <Badge variant={m.variant} size="xs" dot>{m.label}</Badge>
}

export function SupplierStatusBadge({ status }: { status: string }) {
  const t = useLocaleStore(s => s.t)
  const m = supplierStatusMap(t)[status] ?? { variant: 'default' as BadgeVariant, label: status }
  return <Badge variant={m.variant} size="xs" dot>{m.label}</Badge>
}


export function inputCls(err = false) {
  return cn(
    'w-full bg-zinc-900 border rounded-xl text-zinc-100 placeholder-zinc-600 text-sm',
    'focus:outline-none focus:ring-1 focus:ring-amber-500/20 transition-all duration-150 py-2.5 px-3',
    err ? 'border-red-500 focus:border-red-500' : 'border-zinc-700 focus:border-amber-500',
  )
}

export function FormField({ label, error, required, children }: {
  label: string; error?: string; required?: boolean; children: ReactNode
}) {
  return (
    <div className="flex flex-col gap-1.5">
      <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider">
        {label}
        {required && <span className="text-red-400 ml-0.5">*</span>}
      </label>
      {children}
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  )
}
