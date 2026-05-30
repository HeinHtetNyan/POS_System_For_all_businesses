import { useRef, useState, useMemo, useEffect } from 'react'
import { useVirtualizer } from '@tanstack/react-virtual'
import type { Product, CartItem } from '@/types'
import { Empty } from '@/components/ui'
import { IconProducts } from '@/components/icons'
import ProductCard from '@/features/pos/ProductCard'

const CARD_MIN_W = 120
const GAP = 8
const ESTIMATED_ROW_H = 120 // px — generous estimate, measureElement corrects it

interface ProductGridProps {
  products: Product[]
  cartItems: CartItem[]
  onAdd: (p: Product) => void
}

export default function ProductGrid({ products, cartItems, onAdd }: ProductGridProps) {
  const cartQtyMap = useMemo(() => {
    const m = new Map<string, number>()
    for (const item of cartItems) m.set(item.id, item.qty)
    return m
  }, [cartItems])

  const parentRef = useRef<HTMLDivElement>(null)
  const [cols, setCols] = useState(3)

  // Recalculate column count whenever the container resizes
  useEffect(() => {
    const el = parentRef.current
    if (!el) return
    const obs = new ResizeObserver(() => {
      const w = el.clientWidth - GAP * 2
      setCols(Math.max(1, Math.floor((w + GAP) / (CARD_MIN_W + GAP))))
    })
    obs.observe(el)
    return () => obs.disconnect()
  }, [])

  // Split flat product list into rows of `cols` items
  const rows = useMemo(() => {
    const r: Product[][] = []
    for (let i = 0; i < products.length; i += cols) {
      r.push(products.slice(i, i + cols))
    }
    return r
  }, [products, cols])

  const rowVirtualizer = useVirtualizer({
    count: rows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => ESTIMATED_ROW_H,
    overscan: 4,
    measureElement: el => el.getBoundingClientRect().height,
  })

  if (products.length === 0) {
    return (
      <div ref={parentRef} className="h-full flex items-center justify-center">
        <Empty
          icon={<IconProducts width="48" height="48" />}
          title="No products found"
          subtitle="Try a different search or category"
        />
      </div>
    )
  }

  return (
    <div ref={parentRef} className="h-full overflow-y-auto">
      <div style={{ height: rowVirtualizer.getTotalSize(), position: 'relative', padding: GAP }}>
        {rowVirtualizer.getVirtualItems().map(vRow => (
          <div
            key={vRow.index}
            data-index={vRow.index}
            ref={rowVirtualizer.measureElement}
            style={{
              position: 'absolute',
              top: 0,
              left: GAP,
              right: GAP,
              transform: `translateY(${vRow.start}px)`,
              display: 'grid',
              gridTemplateColumns: `repeat(${cols}, 1fr)`,
              gap: GAP,
              paddingBottom: GAP,
            }}
          >
            {rows[vRow.index].map(product => (
              <ProductCard
                key={product.id}
                product={product}
                cartQty={cartQtyMap.get(product.id) ?? 0}
                onAdd={onAdd}
              />
            ))}
          </div>
        ))}
      </div>
    </div>
  )
}
