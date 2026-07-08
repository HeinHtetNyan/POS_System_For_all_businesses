import { Badge } from '@/components/ui'
import { fmt, fmtDate, fmtDateTime } from '@/lib/utils'
import { useLocaleStore } from '@/i18n/localeStore'
import type { Notification } from '@/shared/types'

const TYPE_CONFIG: Record<string, {
  icon: string
  variant: 'default' | 'success' | 'danger' | 'warning' | 'info' | 'purple' | 'orange'
  labelKey: string
}> = {
  SYSTEM:       { icon: '⚙️',  variant: 'default',  labelKey: 'notif.type.system'       },
  INVENTORY:    { icon: '📦',  variant: 'warning',  labelKey: 'notif.type.inventory'    },
  PROCUREMENT:  { icon: '🛒',  variant: 'info',     labelKey: 'notif.type.procurement'  },
  CUSTOMER:     { icon: '👥',  variant: 'purple',   labelKey: 'notif.type.customer'     },
  SUBSCRIPTION: { icon: '💳',  variant: 'orange',   labelKey: 'notif.type.subscription' },
  SECURITY:     { icon: '🔐',  variant: 'danger',   labelKey: 'notif.type.security'     },
}

const PRIORITY_CONFIG: Record<string, {
  variant: 'default' | 'success' | 'danger' | 'warning' | 'info' | 'purple' | 'orange'
  labelKey: string
}> = {
  LOW:      { variant: 'default',  labelKey: 'notif.priority.low'      },
  MEDIUM:   { variant: 'info',     labelKey: 'notif.priority.medium'   },
  HIGH:     { variant: 'warning',  labelKey: 'notif.priority.high'     },
  CRITICAL: { variant: 'danger',   labelKey: 'notif.priority.critical' },
}

export function NotificationTypeBadge({ type }: { type: string }) {
  const t = useLocaleStore(s => s.t)
  const cfg = TYPE_CONFIG[type] ?? { icon: '🔔', variant: 'default' as const, labelKey: '' }
  return (
    <Badge variant={cfg.variant} size="xs">
      {cfg.icon} {cfg.labelKey ? t(cfg.labelKey) : type}
    </Badge>
  )
}

export function NotificationPriorityBadge({ priority }: { priority: string }) {
  const t = useLocaleStore(s => s.t)
  const cfg = PRIORITY_CONFIG[priority] ?? { variant: 'default' as const, labelKey: '' }
  return <Badge variant={cfg.variant} size="xs">{cfg.labelKey ? t(cfg.labelKey) : priority}</Badge>
}

/** Shows which branch a notification originated from, when the event carried one
 * (e.g. low stock, PO submitted/approved, goods receipt, overdue payable, sync failed).
 * Tenant/platform-level notifications (billing, subscription, business registration)
 * have no branch, so this renders nothing for them. */
export function NotificationBranchBadge({ metadata }: { metadata: Record<string, unknown> | null | undefined }) {
  const branchName = metadata?.branch_name
  if (typeof branchName !== 'string' || !branchName) return null
  return (
    <Badge variant="default" size="xs">
      🏢 {branchName}
    </Badge>
  )
}

export function notificationTypeIcon(type: string): string {
  return TYPE_CONFIG[type]?.icon ?? '🔔'
}

// Metadata keys that only exist to build a "View" link (or have no useful
// display value as a raw ID) — never shown in the Details list.
const ID_KEYS = new Set([
  'purchase_order_id', 'goods_receipt_id', 'customer_id', 'product_id',
  'payable_id', 'branch_id', 'supplier_id', 'device_id', 'tenant_id',
  'plan_id', 'new_plan_id',
])

// Amount fields that should render as "1,234.00 MMK" using the sibling `currency` key.
const MONEY_KEYS = new Set([
  'total_amount', 'remaining_amount', 'amount', 'current_balance', 'credit_limit',
])

const DATE_KEYS = new Set(['expires_at', 'order_date'])

const LABEL_KEYS: Record<string, string> = {
  po_number:          'notif.field.po_number',
  receipt_number:     'notif.field.receipt_number',
  supplier_name:      'notif.field.supplier_name',
  submitted_by_name:  'notif.field.submitted_by_name',
  product_name:       'notif.field.product_name',
  sku:                'products.col.sku',
  current_stock:      'notif.field.current_stock',
  reorder_level:      'notif.field.reorder_level',
  customer_name:      'notif.field.customer_name',
  current_balance:    'notif.field.current_balance',
  credit_limit:       'notif.field.credit_limit',
  total_amount:       'notif.field.total_amount',
  remaining_amount:   'notif.field.remaining_amount',
  order_date:         'notif.field.order_date',
  tenant_name:        'notif.field.tenant_name',
  days_remaining:     'notif.field.days_remaining',
  expires_at:         'notif.field.expires_at',
  plan_name:          'settings.plan',
  old_plan_name:      'notif.field.old_plan_name',
  new_plan_name:      'notif.field.new_plan_name',
  amount:             'notif.field.amount',
  device_name:        'notif.field.device_name',
  error:              'notif.field.error',
  business_name:      'notif.field.business_name',
  owner_name:         'notif.field.owner_name',
  owner_email:        'notif.field.owner_email',
  trial_days:         'notif.field.trial_days',
  branch_name:        'notif.field.branch_name',
}

function humanizeKey(key: string): string {
  return key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

export interface MetadataEntry { key: string; label: string; value: string }

/** Turns a notification's raw metadata JSON into a clean, human-readable list —
 * skipping ID fields (used only for the "View" link) and the `currency` key
 * (merged into whichever *_amount/balance field it pairs with). */
export function formatMetadataEntries(
  metadata: Record<string, unknown> | null | undefined,
  t: (key: string) => string,
): MetadataEntry[] {
  if (!metadata) return []
  const currency = typeof metadata.currency === 'string' ? metadata.currency : null
  const entries: MetadataEntry[] = []

  for (const [key, raw] of Object.entries(metadata)) {
    if (ID_KEYS.has(key) || key === 'currency' || raw == null || raw === '') continue

    let value: string
    if (MONEY_KEYS.has(key)) {
      value = fmt(raw as string | number, currency)
    } else if (DATE_KEYS.has(key)) {
      value = String(raw).length > 10 ? fmtDateTime(raw as string) : fmtDate(raw as string)
    } else {
      value = String(raw)
    }

    entries.push({ key, label: LABEL_KEYS[key] ? t(LABEL_KEYS[key]) : humanizeKey(key), value })
  }
  return entries
}

export interface NotificationAction { labelKey: string; path: string }

/** Resolves a "View X" call-to-action from a notification's type + metadata,
 * when the underlying entity can be linked to directly. */
export function getNotificationAction(notification: Notification): NotificationAction | null {
  const m = notification.metadata
  if (!m) return null

  // goods_receipt_id is checked before purchase_order_id — a goods-receipt
  // notification's metadata carries both, and the receipt is the more specific,
  // just-created entity the notification is actually about.
  if (typeof m.goods_receipt_id === 'string') {
    return { labelKey: 'notif.action.view_goods_receipt', path: `/app/procurement/receipts/${m.goods_receipt_id}` }
  }
  if (typeof m.purchase_order_id === 'string') {
    return { labelKey: 'notif.action.view_purchase_order', path: `/app/procurement/purchase-orders/${m.purchase_order_id}` }
  }
  if (typeof m.customer_id === 'string') {
    return { labelKey: 'notif.action.view_customer', path: `/app/customers/${m.customer_id}` }
  }
  if (typeof m.payable_id === 'string') {
    return { labelKey: 'notif.action.view_payables', path: '/app/procurement/payments' }
  }
  if (notification.type === 'INVENTORY') {
    return { labelKey: 'notif.action.view_inventory', path: '/app/inventory' }
  }
  if (notification.type === 'SUBSCRIPTION') {
    return { labelKey: 'notif.action.view_subscription', path: '/app/subscription' }
  }
  return null
}
