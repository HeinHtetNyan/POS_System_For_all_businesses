import type { Product } from '@/shared/types'

export type ScanSource = 'cache' | 'api'

export type ScanResult =
  | { status: 'found'; product: Product; source: ScanSource }
  | { status: 'not_found' }
  | { status: 'error'; message: string }
