import { memo } from 'react'
import { cn, fmt } from '@/lib/utils'
import { useLocaleStore } from '@/i18n/localeStore'
import type { Product } from '@/types'

interface ProductCardProps {
  product: Product
  cartQty: number
  onAdd: (product: Product) => void
}

const LOW_STOCK_THRESHOLD = 10

// Stable product objects + numeric cartQty = pure value comparison → safe to memo
function ProductCard({ product, cartQty, onAdd }: ProductCardProps) {
  const t = useLocaleStore(s => s.t)
  const isOutOfStock = product.stock === 0
  const isLowStock = product.stock > 0 && product.stock <= LOW_STOCK_THRESHOLD
  const inCart = cartQty > 0

  return (
    <button
      onClick={() => !isOutOfStock && onAdd(product)}
      className={cn(
        'relative flex flex-col rounded-xl border overflow-hidden text-left transition-all duration-150 select-none w-full',
        isOutOfStock
          ? 'opacity-50 cursor-not-allowed bg-zinc-900 border-zinc-800'
          : inCart
            ? 'bg-zinc-800 border-amber-500/40 hover:border-amber-500/60'
            : 'bg-zinc-900 border-zinc-800 hover:bg-zinc-800/80 active:scale-95 cursor-pointer',
      )}
    >
      {/* Color stripe */}
      <div className="h-1 w-full flex-shrink-0" style={{ backgroundColor: product.color }} />

      {/* Cart qty badge */}
      {inCart && (
        <span className="absolute top-2 right-2 w-5 h-5 rounded-full bg-amber-500 text-black text-[10px] font-bold flex items-center justify-center z-10 shadow-md">
          {cartQty}
        </span>
      )}

      {/* Promo badge */}
      {!inCart && product.promoLabel && (
        <span className="absolute top-2 right-2 px-1.5 py-0.5 rounded-md bg-green-500/90 text-black text-[9px] font-bold z-10 leading-tight">
          {product.promoLabel}
        </span>
      )}

      <div className="p-2.5 flex flex-col gap-1 flex-1">
        {/* Product name */}
        <p
          className="text-xs font-semibold text-zinc-100 line-clamp-2 leading-snug"
          style={{ minHeight: '2.5rem' }}
        >
          {product.name}
        </p>

        {/* SKU */}
        <p className="font-mono text-zinc-600" style={{ fontSize: '10px' }}>
          {product.sku}
        </p>

        {/* Price row */}
        <div className="flex items-center justify-between mt-auto pt-1">
          <div className="flex flex-col">
            <span className={`font-mono text-xs font-bold ${product.promoLabel ? 'text-green-400' : 'text-amber-400'}`}>
              {fmt(product.price)}
            </span>
            {product.promoLabel && (
              <span className="font-mono text-[9px] text-zinc-500 line-through leading-tight">
                {t('pos.orig')}
              </span>
            )}
          </div>
          {isOutOfStock ? (
            <span className="text-[10px] font-semibold text-red-500">{t('pos.out')}</span>
          ) : isLowStock ? (
            <span className="text-[10px] font-semibold text-amber-500">
              {product.stock} {t('pos.left')}
            </span>
          ) : null}
        </div>
      </div>
    </button>
  )
}

export default memo(ProductCard)
