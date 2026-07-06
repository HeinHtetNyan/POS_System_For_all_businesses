import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { subscriptionsService } from '@/services/subscriptions/subscriptions.service'
import { Spinner } from '@/components/ui/index'
import type { PublicPlan } from '@/shared/types'
import { CONTACT_PLATFORMS, contactHref } from '@/shared/constants/contactPlatforms'

function ContactLinksRow({ plan }: { plan: PublicPlan }) {
  const active = CONTACT_PLATFORMS.filter(p => plan.contact_links?.[p.key])
  if (active.length === 0) {
    return <p className="text-xs text-zinc-600 text-center mt-6">Contact us to discuss your requirements.</p>
  }
  return (
    <div className="flex flex-wrap gap-2 justify-center mt-6">
      {active.map(p => (
        <a
          key={p.key}
          href={contactHref(p.key, plan.contact_links![p.key]!)}
          target={p.key === 'phone' || p.key === 'email' ? undefined : '_blank'}
          rel="noopener noreferrer"
          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-zinc-700 text-zinc-400 text-xs font-medium transition-colors ${p.color}`}
        >
          {p.icon}
          {p.label}
        </a>
      ))}
    </div>
  )
}

function PricingCard({ plan, highlighted = false }: { plan: PublicPlan; highlighted?: boolean }) {
  const price = parseFloat(plan.price as unknown as string)

  const getLimit = (code: string): string => {
    const ent = plan.entitlements.find(e => e.feature_code === code)
    if (!ent) return '—'
    if (ent.limit_value === null || ent.limit_value === undefined) return 'Unlimited'
    return String(ent.limit_value)
  }

  const hasFeature = (code: string): boolean => {
    const ent = plan.entitlements.find(e => e.feature_code === code)
    return ent ? ent.enabled : false
  }

  const features = [
    { label: 'Products', value: getLimit('products') },
    { label: 'Staff accounts', value: getLimit('users') },
    { label: 'Branches', value: getLimit('branches') },
    { label: 'Customers', value: getLimit('customers') },
    { label: 'Analytics & Reports', value: hasFeature('analytics') ? '✓' : '✗', yes: hasFeature('analytics') },
    { label: 'Procurement', value: hasFeature('procurement') ? '✓' : '✗', yes: hasFeature('procurement') },
    { label: 'POS Checkout', value: '✓', yes: true },
    { label: 'Inventory Management', value: '✓', yes: true },
    { label: 'Offline Support', value: '✓', yes: true },
  ]

  return (
    <div className={`rounded-2xl border p-6 flex flex-col ${
      highlighted
        ? 'bg-amber-500/10 border-amber-500/40 shadow-2xl shadow-amber-900/20'
        : 'bg-zinc-900 border-zinc-800'
    }`}>
      {highlighted && (
        <div className="mb-3">
          <span className="px-2.5 py-1 rounded-full bg-amber-500 text-black text-xs font-bold uppercase tracking-wide">
            Most Popular
          </span>
        </div>
      )}

      <h3 className="text-lg font-bold text-zinc-100">{plan.name}</h3>
      {plan.description && (
        <p className="text-zinc-500 text-sm mt-1">{plan.description}</p>
      )}

      <div className="mt-4 mb-6">
        {plan.is_custom ? (
          <span className="text-3xl font-bold text-zinc-100">Contact Us</span>
        ) : (
          <div className="flex items-baseline gap-1">
            <span className="text-3xl font-bold text-zinc-100">${price}</span>
            <span className="text-zinc-500 text-sm">
              /{plan.billing_cycle === 'YEARLY' ? 'yr' : 'mo'}
            </span>
          </div>
        )}
      </div>

      <div className="space-y-2.5 flex-1">
        {features.map(f => (
          <div key={f.label} className="flex items-center justify-between text-sm">
            <span className="text-zinc-400">{f.label}</span>
            <span className={
              f.yes === true ? 'text-green-400 font-medium' :
              f.yes === false ? 'text-zinc-600' :
              'text-zinc-200 font-medium'
            }>
              {f.value}
            </span>
          </div>
        ))}
      </div>

      {plan.is_custom ? (
        <ContactLinksRow plan={plan} />
      ) : (
        <Link
          to="/register"
          className={`mt-6 inline-flex items-center justify-center w-full px-4 py-3 rounded-xl font-semibold text-sm transition-colors ${
            highlighted
              ? 'bg-amber-500 hover:bg-amber-400 text-black'
              : 'bg-zinc-800 hover:bg-zinc-700 text-zinc-100 border border-zinc-700'
          }`}
        >
          Start Free Trial
        </Link>
      )}
    </div>
  )
}

export default function PricingPage() {
  const { data: plans = [], isLoading, isError } = useQuery({
    queryKey: ['public-plans'],
    queryFn: subscriptionsService.getPublicPlans,
    staleTime: 5 * 60 * 1000,
  })

  // Real trial length — was hardcoded and drifted out of sync with the
  // actual plan (Free Trial isn't in the plans list above since /public/plans
  // deliberately excludes trial-type plans).
  const { data: trialPlan } = useQuery({
    queryKey: ['public', 'trial-plan'],
    queryFn: subscriptionsService.getPublicTrialPlan,
    staleTime: 5 * 60 * 1000,
  })
  const trialDaysText = trialPlan ? `${trialPlan.trial_days}-day` : 'free'

  return (
    <div className="min-h-screen bg-zinc-950 text-zinc-100">
      <nav className="border-b border-zinc-900 px-6 py-4 flex items-center justify-between max-w-6xl mx-auto">
        <Link to="/" className="flex items-center gap-2">
          <img src="/logo-icon.png" alt="SawYunPos" className="w-8 h-8 rounded-xl" />
          <span className="font-bold text-zinc-100">SawYunPos</span>
        </Link>
        <div className="flex items-center gap-3">
          <Link to="/login" className="text-zinc-400 hover:text-zinc-100 text-sm transition-colors">
            Sign in
          </Link>
          <Link
            to="/register"
            className="px-4 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 text-black font-semibold text-sm transition-colors"
          >
            Start Free Trial
          </Link>
        </div>
      </nav>

      <main className="max-w-6xl mx-auto px-6 py-16">
        <div className="text-center mb-14">
          <h1 className="text-4xl font-bold text-zinc-100 mb-4">
            Simple, transparent pricing
          </h1>
          <p className="text-zinc-400 text-lg max-w-xl mx-auto">
            Start with a {trialDaysText} free trial. No credit card required.
            Upgrade when you're ready.
          </p>
        </div>

        {isLoading && (
          <div className="flex justify-center py-20">
            <Spinner size={40} />
          </div>
        )}

        {isError && (
          <div className="text-center py-20 text-zinc-500">
            <p>Failed to load plans. Please refresh the page.</p>
          </div>
        )}

        {!isLoading && !isError && plans.length === 0 && (
          <div className="text-center py-20 text-zinc-500">
            <p>No plans available at this time. Please contact us.</p>
          </div>
        )}

        {plans.length > 0 && (
          <div className={`grid gap-6 ${
            plans.length === 1 ? 'max-w-sm mx-auto' :
            plans.length === 2 ? 'md:grid-cols-2 max-w-2xl mx-auto' :
            'md:grid-cols-3'
          }`}>
            {plans.map((plan, index) => (
              <PricingCard
                key={plan.id}
                plan={plan}
                highlighted={plans.length >= 2 && index === Math.floor(plans.length / 2)}
              />
            ))}
          </div>
        )}

        <div className="mt-16 text-center">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-8 max-w-2xl mx-auto">
            <div className="text-4xl mb-3">🚀</div>
            <h2 className="text-xl font-bold text-zinc-100 mb-2">Start with a {trialDaysText} free trial</h2>
            <p className="text-zinc-500 text-sm mb-5">
              Full access to all features. No credit card needed.
              Cancel anytime during the trial period.
            </p>
            <Link
              to="/register"
              className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-amber-500 hover:bg-amber-400 text-black font-bold text-sm transition-colors"
            >
              Create Free Account →
            </Link>
          </div>
        </div>
      </main>

      <footer className="border-t border-zinc-900 px-6 py-8 text-center text-zinc-600 text-xs max-w-6xl mx-auto">
        <p>© 2026 SawYunPos. All rights reserved.</p>
        <div className="flex items-center justify-center gap-4 mt-2">
          <Link to="/login" className="hover:text-zinc-400">Sign In</Link>
          <Link to="/register" className="hover:text-zinc-400">Register</Link>
        </div>
      </footer>
    </div>
  )
}
