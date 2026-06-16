import { db } from '@/offline/db'
import { productsService } from '@/services/products/products.service'
import type { Product } from '@/shared/types'
import type { ScanResult } from './types'

export type { ScanResult, ScanSource } from './types'

export async function lookupProductBySku(sku: string): Promise<ScanResult> {
  const trimmed = sku.trim()
  if (!trimmed) return { status: 'not_found' }

  try {
    const cached = await db.products.where('sku').equals(trimmed).first()
    if (cached) return { status: 'found', product: cached as unknown as Product, source: 'cache' }
  } catch { /* IndexedDB unavailable — fall through */ }

  try {
    const product = await productsService.getBySku(trimmed)
    return { status: 'found', product, source: 'api' }
  } catch (err: unknown) {
    const status = (err as { response?: { status?: number } })?.response?.status
    if (status === 404) return { status: 'not_found' }
    return { status: 'error', message: 'Network error — check connection' }
  }
}

export async function lookupProductByBarcode(barcode: string): Promise<ScanResult> {
  const trimmed = barcode.trim()
  if (!trimmed) return { status: 'not_found' }

  try {
    const cached = await db.products.where('barcode').equals(trimmed).first()
    if (cached) return { status: 'found', product: cached as unknown as Product, source: 'cache' }
  } catch { /* fall through */ }

  try {
    const product = await productsService.getByBarcode(trimmed)
    return { status: 'found', product, source: 'api' }
  } catch (err: unknown) {
    const status = (err as { response?: { status?: number } })?.response?.status
    if (status === 404) return { status: 'not_found' }
    return { status: 'error', message: 'Network error — check connection' }
  }
}
