import { Badge } from '@/components/ui'
import { fmt, fmtDate, fmtDateTime } from '@/lib/utils'
import type { Notification } from '@/shared/types'

const TYPE_CONFIG: Record<string, {
  icon: string
  variant: 'default' | 'success' | 'danger' | 'warning' | 'info' | 'purple' | 'orange'
  label: string
}> = {
  SYSTEM:       { icon: '⚙️',  variant: 'default',  label: 'System'       },
  INVENTORY:    { icon: '📦',  variant: 'warning',  label: 'Inventory'    },
  PROCUREMENT:  { icon: '🛒',  variant: 'info',     label: 'Procurement'  },
  CUSTOMER:     { icon: '👥',  variant: 'purple',   label: 'Customer'     },
  SUBSCRIPTION: { icon: '💳',  variant: 'orange',   label: 'Subscription' },
  SECURITY:     { icon: '🔐',  variant: 'danger',   label: 'Security'     },
}

const PRIORITY_CONFIG: Record<string, {
  variant: 'default' | 'success' | 'danger' | 'warning' | 'info' | 'purple' | 'orange'
}> = {
  LOW:      { variant: 'default'  },
  MEDIUM:   { variant: 'info'     },
  HIGH:     { variant: 'warning'  },
  CRITICAL: { variant: 'danger'   },
}

export function NotificationTypeBadge({ type }: { type: string }) {
  const cfg = TYPE_CONFIG[type] ?? { icon: '🔔', variant: 'default' as const, label: type }
  return (
    <Badge variant={cfg.variant} size="xs">
      {cfg.icon} {cfg.label}
    </Badge>
  )
}

export function NotificationPriorityBadge({ priority }: { priority: string }) {
  const cfg = PRIORITY_CONFIG[priority] ?? { variant: 'default' as const }
  return <Badge variant={cfg.variant} size="xs">{priority}</Badge>
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

const LABELS: Record<string, string> = {
  po_number:          'PO Number',
  receipt_number:     'Receipt Number',
  supplier_name:      'Supplier',
  submitted_by_name:  'Submitted By',
  product_name:       'Product',
  sku:                'SKU',
  current_stock:      'Current Stock',
  reorder_level:      'Reorder Level',
  customer_name:      'Customer',
  current_balance:    'Balance',
  credit_limit:       'Credit Limit',
  total_amount:       'Total Amount',
  remaining_amount:   'Remaining Amount',
  order_date:         'Order Date',
  tenant_name:        'Business',
  days_remaining:     'Days Remaining',
  expires_at:         'Expires At',
  plan_name:          'Plan',
  old_plan_name:      'Previous Plan',
  new_plan_name:      'New Plan',
  amount:             'Amount',
  device_name:        'Device',
  error:              'Error',
  business_name:      'Business',
  owner_name:         'Owner',
  owner_email:        'Owner Email',
  trial_days:         'Trial Days',
  branch_name:        'Branch',
}

function humanizeKey(key: string): string {
  return key.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
}

export interface MetadataEntry { key: string; label: string; value: string }

/** Turns a notification's raw metadata JSON into a clean, human-readable list —
 * skipping ID fields (used only for the "View" link) and the `currency` key
 * (merged into whichever *_amount/balance field it pairs with). */
export function formatMetadataEntries(metadata: Record<string, unknown> | null | undefined): MetadataEntry[] {
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

    entries.push({ key, label: LABELS[key] ?? humanizeKey(key), value })
  }
  return entries
}

export interface NotificationAction { label: string; path: string }

/** Resolves a "View X" call-to-action from a notification's type + metadata,
 * when the underlying entity can be linked to directly. */
export function getNotificationAction(notification: Notification): NotificationAction | null {
  const m = notification.metadata
  if (!m) return null

  // goods_receipt_id is checked before purchase_order_id — a goods-receipt
  // notification's metadata carries both, and the receipt is the more specific,
  // just-created entity the notification is actually about.
  if (typeof m.goods_receipt_id === 'string') {
    return { label: 'View Goods Receipt', path: `/app/procurement/receipts/${m.goods_receipt_id}` }
  }
  if (typeof m.purchase_order_id === 'string') {
    return { label: 'View Purchase Order', path: `/app/procurement/purchase-orders/${m.purchase_order_id}` }
  }
  if (typeof m.customer_id === 'string') {
    return { label: 'View Customer', path: `/app/customers/${m.customer_id}` }
  }
  if (typeof m.payable_id === 'string') {
    return { label: 'View Payables', path: '/app/procurement/payments' }
  }
  if (notification.type === 'INVENTORY') {
    return { label: 'View Inventory', path: '/app/inventory' }
  }
  if (notification.type === 'SUBSCRIPTION') {
    return { label: 'View Subscription', path: '/app/subscription' }
  }
  return null
}
