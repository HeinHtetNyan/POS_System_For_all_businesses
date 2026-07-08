import { useQuery } from '@tanstack/react-query'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '@/store/auth.store'
import { useLocaleStore } from '@/i18n/localeStore'
import { canAccess } from '@/shared/constants/rbac'
import { notificationsService } from '@/services/notifications/notifications.service'
import { analyticsService } from '@/services/analytics/analytics.service'
import { procurementService } from '@/services/procurement/procurement.service'
import { subscriptionsService } from '@/services/subscriptions/subscriptions.service'
import { AlertPanel, type AlertItem } from './AlertPanel'
import { DashboardSection } from './DashboardSection'

export function ActionCenter() {
  const user = useAuthStore(s => s.user)
  const navigate = useNavigate()
  const t = useLocaleStore(s => s.t)
  const role = user?.role ?? 'CASHIER'

  const notifQuery = useQuery({
    queryKey: ['notifications', 'unread-count'],
    queryFn: notificationsService.getUnreadCount,
    enabled: !!user,
  })

  const lowStockQuery = useQuery({
    queryKey: ['analytics', 'low-stock'],
    queryFn: () => analyticsService.getLowStock(),
    enabled: !!user && canAccess(role, 'inventory'),
  })

  const procurementQuery = useQuery({
    queryKey: ['procurement', 'orders-pending-count'],
    queryFn: () => procurementService.listOrders({ status: 'PENDING', page: 1, page_size: 1 }),
    enabled: !!user && canAccess(role, 'procurement'),
  })

  const subQuery = useQuery({
    queryKey: ['subscription', 'current'],
    queryFn: subscriptionsService.getMySubscription,
    enabled: !!user && canAccess(role, 'subscription'),
  })

  const alerts: AlertItem[] = []

  const unread = notifQuery.data?.unread_count ?? 0
  if (unread > 0) {
    alerts.push({
      id: 'notifications',
      label: `${unread} ${t('reseller.unread_notification')}${unread !== 1 ? 's' : ''}`,
      sub: t('dash.review_notification_inbox'),
      severity: unread > 5 ? 'warning' : 'info',
      action: { label: t('dash.view'), path: '/app/notifications' },
    })
  }

  const lowStockCount = lowStockQuery.data?.length ?? 0
  if (lowStockCount > 0) {
    alerts.push({
      id: 'low-stock',
      label: `${lowStockCount} ${t('products.col.product')}${lowStockCount !== 1 ? 's' : ''} ${t('dash.below_reorder_point')}`,
      sub: t('dash.inventory_needs_attention'),
      severity: lowStockCount > 10 ? 'critical' : 'warning',
      action: { label: t('qa.inventory'), path: '/app/inventory' },
    })
  }

  const pendingPOs = procurementQuery.data?.total ?? 0
  if (pendingPOs > 0) {
    alerts.push({
      id: 'pending-po',
      label: `${pendingPOs} ${t('status.pending')} ${t('procurement.purchase_order')}${pendingPOs !== 1 ? 's' : ''}`,
      sub: t('dash.awaiting_approval_fulfillment'),
      severity: 'info',
      action: { label: t('qa.procurement'), path: '/app/procurement/purchase-orders' },
    })
  }

  const sub = subQuery.data
  if (sub?.status === 'TRIAL') {
    alerts.push({
      id: 'trial',
      label: t('dash.trial_subscription_active'),
      sub: t('dash.upgrade_to_paid_plan'),
      severity: 'warning',
      action: { label: t('dash.upgrade'), path: '/app/subscription/current' },
    })
  } else if (sub?.status === 'EXPIRED') {
    alerts.push({
      id: 'sub-expired',
      label: t('dash.subscription_expired'),
      sub: t('dash.renew_plan_restore_access'),
      severity: 'critical',
      action: { label: t('dash.renew'), path: '/app/subscription/current' },
    })
  } else if (sub?.status === 'SUSPENDED') {
    alerts.push({
      id: 'sub-suspended',
      label: t('dash.subscription_suspended'),
      sub: t('dash.contact_support_renew'),
      severity: 'critical',
      action: { label: t('qa.subscription'), path: '/app/subscription/current' },
    })
  }

  const isLoading = notifQuery.isLoading && lowStockQuery.isLoading

  return (
    <DashboardSection
      title={t('dash.action_center')}
      action={
        alerts.length > 0
          ? { label: t('qa.notifications'), onClick: () => navigate('/app/notifications') }
          : undefined
      }
    >
      <AlertPanel items={alerts} isLoading={isLoading} />
    </DashboardSection>
  )
}
