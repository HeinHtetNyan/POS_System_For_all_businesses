import type { QueryClient } from '@tanstack/react-query'

/**
 * Shared invalidation list for anything that changes order/inventory state
 * (checkout, refund, void). Centralized here because these three call sites
 * previously drifted independently — some invalidated keys nobody queries
 * with (['dashboard'], ['sales-analytics']), while dashboard/analytics
 * widgets using the real keys were never invalidated by any of them.
 */
export function invalidateSalesMutationQueries(qc: QueryClient) {
  return Promise.all([
    qc.invalidateQueries({ queryKey: ['orders'] }),
    qc.invalidateQueries({ queryKey: ['sales', 'orders'] }),
    qc.invalidateQueries({ queryKey: ['session-orders'] }),
    qc.invalidateQueries({ queryKey: ['inventory'] }),
    qc.invalidateQueries({ queryKey: ['products'] }),
    qc.invalidateQueries({ queryKey: ['analytics'] }), // dashboard + low-stock widgets
    qc.invalidateQueries({ queryKey: ['sales-summary'] }),
    qc.invalidateQueries({ queryKey: ['sales-top-products'] }),
    qc.invalidateQueries({ queryKey: ['sales-by-cashier'] }),
    qc.invalidateQueries({ queryKey: ['sales-payment-methods'] }),
    qc.invalidateQueries({ queryKey: ['financial-summary'] }),
    qc.invalidateQueries({ queryKey: ['financial-profit'] }),
  ])
}
