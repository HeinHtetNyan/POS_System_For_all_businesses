import { useLocaleStore } from '@/i18n/localeStore'

interface PlaceholderPageProps {
  title: string
  description?: string
}

export default function PlaceholderPage({ title, description }: PlaceholderPageProps) {
  const t = useLocaleStore(s => s.t)
  return (
    <div className="flex flex-col items-center justify-center h-full py-24 text-center">
      <div className="w-16 h-16 rounded-2xl bg-zinc-800 border border-zinc-700 flex items-center justify-center mb-4">
        <span className="text-2xl">🚧</span>
      </div>
      <h2 className="text-xl font-semibold text-zinc-200 mb-2">{title}</h2>
      <p className="text-zinc-500 text-sm max-w-sm">
        {description ?? t('errors.placeholder_module_desc')}
      </p>
    </div>
  )
}
