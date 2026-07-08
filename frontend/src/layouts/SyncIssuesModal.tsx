import { useQuery, useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { getFailedSyncOps, retrySyncOp, removeSyncOp } from '@/offline/db'
import { processSyncQueue } from '@/services/sync/syncService'
import { useUIStore } from '@/store/ui.store'
import { Btn, Spinner, Empty } from '@/components/ui'
import { IconAlert, IconX } from '@/components/icons'
import { useLocaleStore } from '@/i18n/localeStore'

interface Props {
  onClose: () => void
}

function typeLabel(type: string, t: (k: string) => string) {
  const map: Record<string, string> = {
    SALE_CREATE: t('sync.type_sale'),
    INVENTORY_UPDATE: t('sync.type_inventory_update'),
    PRODUCT_UPDATE: t('sync.type_product_update'),
    PAYMENT_PROCESS: t('sync.type_payment'),
  }
  return map[type] ?? type
}

export default function SyncIssuesModal({ onClose }: Props) {
  const qc = useQueryClient()
  const t = useLocaleStore(s => s.t)

  const { data: ops = [], isLoading } = useQuery({
    queryKey: ['sync-queue', 'failed'],
    queryFn: getFailedSyncOps,
    refetchInterval: 5000,
  })

  async function refreshCount() {
    const remaining = await getFailedSyncOps()
    useUIStore.getState().setFailedSyncCount(remaining.length)
  }

  async function handleRetry(id: string) {
    await retrySyncOp(id)
    await qc.invalidateQueries({ queryKey: ['sync-queue'] })
    await refreshCount()
    toast.info(t('sync.retrying'))
    await processSyncQueue()
    await qc.invalidateQueries({ queryKey: ['sync-queue'] })
    await refreshCount()
  }

  async function handleDiscard(id: string) {
    await removeSyncOp(id)
    await qc.invalidateQueries({ queryKey: ['sync-queue'] })
    await refreshCount()
    toast.success(t('sync.discarded'))
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
      <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-lg shadow-2xl flex flex-col max-h-[85vh]">
        <div className="flex items-center justify-between px-5 py-4 border-b border-zinc-800 flex-shrink-0">
          <div className="flex items-center gap-2">
            <IconAlert width="16" height="16" className="text-red-400" />
            <h2 className="text-sm font-semibold text-zinc-100">{t('sync.issues_title')}</h2>
          </div>
          <button onClick={onClose} className="text-zinc-500 hover:text-zinc-300">
            <IconX width="16" height="16" />
          </button>
        </div>

        <div className="px-5 py-3 border-b border-zinc-800 flex-shrink-0">
          <p className="text-xs text-zinc-400">
            {t('sync.issues_description')}
          </p>
        </div>

        <div className="flex-1 overflow-y-auto px-5 py-3">
          {isLoading ? (
            <div className="flex justify-center py-6"><Spinner size={24} /></div>
          ) : ops.length === 0 ? (
            <Empty icon={<IconAlert width="32" height="32" />} title={t('sync.no_issues')} subtitle={t('sync.everything_synced')} />
          ) : (
            <div className="flex flex-col gap-3">
              {ops.map(op => (
                <div key={op.id} className="rounded-xl bg-zinc-800/60 border border-zinc-700 p-3 flex flex-col gap-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-semibold text-zinc-200">
                      {typeLabel(op.type, t)}
                    </span>
                    <span className="text-[10px] text-zinc-500">
                      {new Date(op.createdAt).toLocaleString()}
                    </span>
                  </div>
                  {op.lastError && (
                    <p className="text-[11px] text-red-400 font-mono break-words">{op.lastError}</p>
                  )}
                  <p className="text-[10px] text-zinc-600">{t('sync.retried_prefix')} {op.retries} {op.retries === 1 ? t('sync.time_singular') : t('sync.time_plural')}</p>
                  <div className="flex gap-2">
                    <Btn size="sm" variant="secondary" fullWidth onClick={() => handleRetry(op.id)}>
                      {t('sync.retry')}
                    </Btn>
                    <Btn size="sm" variant="danger" fullWidth onClick={() => handleDiscard(op.id)}>
                      {t('sync.discard')}
                    </Btn>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
