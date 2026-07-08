import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { useAuthStore } from '@/store/auth.store'
import { ROLE_HOME } from '@/shared/constants/rbac'
import { Btn, Input, Spinner } from '@/components/ui/index'
import { tenantService } from '@/services/tenant/tenant.service'
import { subscriptionsService } from '@/services/subscriptions/subscriptions.service'
import { useLocaleStore } from '@/i18n/localeStore'

type Step = 1 | 2 | 3

function fmtLimit(limit: number | null | undefined, t: (key: string) => string): string {
  return limit === null || limit === undefined ? t('onboarding.unlimited') : String(limit)
}

function StepIndicator({ current, total }: { current: number; total: number }) {
  return (
    <div className="flex items-center gap-2 justify-center mb-8">
      {Array.from({ length: total }, (_, i) => (
        <div
          key={i}
          className={`h-1.5 rounded-full transition-all duration-300 ${
            i + 1 === current ? 'w-8 bg-amber-500' : i + 1 < current ? 'w-4 bg-amber-700' : 'w-4 bg-zinc-700'
          }`}
        />
      ))}
    </div>
  )
}

export default function OnboardingWizard() {
  const navigate = useNavigate()
  const { user, fetchMe } = useAuthStore()
  const t = useLocaleStore(s => s.t)

  const [step, setStep] = useState<Step>(1)
  const [isSaving, setIsSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [businessName, setBusinessName] = useState(user?.full_name ?? '')
  const [timezone, setTimezone] = useState('UTC')
  const [currency, setCurrency] = useState('MMK')

  const [branchName, setBranchName] = useState('Main Branch')
  const [branchPhone, setBranchPhone] = useState('')

  // Real trial length/limits for whatever plan this account actually got
  // (Free Trial vs a referral trial can differ) — was hardcoded and had
  // drifted out of sync with the real plan.
  const { data: trialStatus } = useQuery({
    queryKey: ['subscription', 'status'],
    queryFn: subscriptionsService.getTrialStatus,
    staleTime: 60_000,
  })

  function completeOnboarding() {
    localStorage.removeItem('sawyunpos_onboarding_pending')
    const home = user ? (ROLE_HOME[user.role] ?? '/app/dashboard') : '/app/dashboard'
    navigate(home, { replace: true })
  }

  async function handleStep1Next() {
    if (!businessName.trim()) {
      setError(t('onboarding.business_name_required'))
      return
    }
    if (!user?.tenant_id) {
      setStep(2)
      return
    }

    setIsSaving(true)
    setError(null)
    try {
      await tenantService.updateTenant(user.tenant_id, {
        name: businessName.trim(),
        timezone,
        currency,
      } as any)
      setStep(2)
    } catch (err: any) {
      setError(err?.response?.data?.error?.message ?? t('onboarding.save_business_failed'))
    } finally {
      setIsSaving(false)
    }
  }

  async function handleStep2Next() {
    if (!branchName.trim()) {
      setError(t('onboarding.branch_name_required'))
      return
    }
    if (!user?.tenant_id) {
      setStep(3)
      return
    }

    setIsSaving(true)
    setError(null)
    try {
      // Fetch branches to find the primary branch created at registration
      const branches = await tenantService.getBranches(user.tenant_id, { page: 1, page_size: 1 })
      const mainBranch = branches.items?.[0]
      if (mainBranch) {
        await tenantService.updateBranch(user.tenant_id, mainBranch.id, {
          name: branchName.trim(),
          phone: branchPhone.trim() || null,
        })
      }
      await fetchMe()
      setStep(3)
    } catch (err: any) {
      setError(err?.response?.data?.error?.message ?? t('onboarding.save_branch_failed'))
    } finally {
      setIsSaving(false)
    }
  }

  async function handleFinish() {
    completeOnboarding()
  }

  if (!user) return null

  return (
    <div className="h-full overflow-y-auto bg-zinc-950">
      <div className="min-h-full flex items-center justify-center p-4 py-8">
      <div className="w-full max-w-lg">
        <div className="text-center mb-6">
          <img src="/logo-icon.png" alt="SawYunPos" className="inline-block w-14 h-14 rounded-2xl shadow-2xl shadow-blue-900/50 mb-3" />
          <h1 className="text-xl font-bold text-zinc-100">{t('onboarding.welcome_title')}</h1>
          <p className="text-zinc-500 text-sm mt-1">{t('onboarding.welcome_subtitle')}</p>
        </div>

        <StepIndicator current={step} total={3} />

        <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 shadow-2xl">
          {error && (
            <div className="mb-4 px-3 py-2 rounded-lg bg-red-950/60 border border-red-900/40 text-red-300 text-sm">
              {error}
            </div>
          )}

          {step === 1 && (
            <div>
              <h2 className="text-base font-semibold text-zinc-100 mb-1">{t('settings.business_info')}</h2>
              <p className="text-zinc-500 text-sm mb-5">{t('onboarding.step1_desc')}</p>

              <div className="space-y-3">
                <Input
                  label={t('settings.business_name')}
                  value={businessName}
                  onChange={e => setBusinessName(e.target.value)}
                  placeholder={t('onboarding.business_name_placeholder')}
                />

                <div>
                  <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider block mb-1.5">
                    {t('settings.timezone')}
                  </label>
                  <select
                    value={timezone}
                    onChange={e => setTimezone(e.target.value)}
                    className="w-full bg-zinc-900 border border-zinc-700 rounded-xl text-zinc-100 px-3 py-2.5 text-sm focus:outline-none focus:border-amber-500"
                  >
                    <option value="UTC">UTC</option>
                    <option value="America/New_York">Eastern Time (ET)</option>
                    <option value="America/Chicago">Central Time (CT)</option>
                    <option value="America/Denver">Mountain Time (MT)</option>
                    <option value="America/Los_Angeles">Pacific Time (PT)</option>
                    <option value="Europe/London">London (GMT)</option>
                    <option value="Europe/Paris">Paris (CET)</option>
                    <option value="Asia/Tokyo">Tokyo (JST)</option>
                    <option value="Asia/Singapore">Singapore (SGT)</option>
                    <option value="Asia/Kolkata">India (IST)</option>
                    <option value="Asia/Bangkok">Bangkok (ICT)</option>
                    <option value="Asia/Yangon">Yangon (MMT)</option>
                    <option value="Australia/Sydney">Sydney (AEST)</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-medium text-zinc-500 uppercase tracking-wider block mb-1.5">
                    {t('settings.currency')}
                  </label>
                  <select
                    value={currency}
                    onChange={e => setCurrency(e.target.value)}
                    className="w-full bg-zinc-900 border border-zinc-700 rounded-xl text-zinc-100 px-3 py-2.5 text-sm focus:outline-none focus:border-amber-500"
                  >
                    <option value="MMK">{t('currency.mmk')} — Myanmar Kyat</option>
                    <option value="USD">USD — US Dollar</option>
                    <option value="EUR">EUR — Euro</option>
                    <option value="GBP">GBP — British Pound</option>
                    <option value="JPY">JPY — Japanese Yen</option>
                    <option value="SGD">SGD — Singapore Dollar</option>
                    <option value="THB">THB — Thai Baht</option>
                    <option value="MYR">MYR — Malaysian Ringgit</option>
                    <option value="IDR">IDR — Indonesian Rupiah</option>
                    <option value="PHP">PHP — Philippine Peso</option>
                    <option value="VND">VND — Vietnamese Dong</option>
                    <option value="KRW">KRW — South Korean Won</option>
                    <option value="CNY">CNY — Chinese Yuan</option>
                    <option value="INR">INR — Indian Rupee</option>
                    <option value="AUD">AUD — Australian Dollar</option>
                  </select>
                </div>
              </div>

              <Btn
                variant="primary"
                size="lg"
                fullWidth
                className="mt-5"
                onClick={handleStep1Next}
                disabled={isSaving}
              >
                {isSaving ? <Spinner size={16} /> : t('common.next')}
              </Btn>
            </div>
          )}

          {step === 2 && (
            <div>
              <h2 className="text-base font-semibold text-zinc-100 mb-1">{t('onboarding.step2_title')}</h2>
              <p className="text-zinc-500 text-sm mb-5">{t('onboarding.step2_desc')}</p>

              <div className="space-y-3">
                <Input
                  label={t('onboarding.branch_name_label')}
                  value={branchName}
                  onChange={e => setBranchName(e.target.value)}
                  placeholder={t('onboarding.branch_name_placeholder')}
                />
                <Input
                  label={t('onboarding.branch_phone_label')}
                  type="tel"
                  inputMode="tel"
                  autoComplete="tel"
                  value={branchPhone}
                  onChange={e => setBranchPhone(e.target.value)}
                  placeholder="+1 234 567 8900"
                />
              </div>

              <div className="flex gap-3 mt-5">
                <Btn variant="secondary" size="lg" fullWidth onClick={() => { setError(null); setStep(1) }} disabled={isSaving}>
                  {t('common.prev')}
                </Btn>
                <Btn variant="primary" size="lg" fullWidth onClick={handleStep2Next} disabled={isSaving}>
                  {isSaving ? <Spinner size={16} /> : t('common.next')}
                </Btn>
              </div>
            </div>
          )}

          {step === 3 && (
            <div>
              <div className="text-center py-4">
                <div className="text-5xl mb-4">🎉</div>
                <h2 className="text-lg font-semibold text-zinc-100 mb-2">{t('onboarding.all_set_title')}</h2>
                <p className="text-zinc-400 text-sm mb-6">
                  {t('onboarding.your_trial')} {trialStatus ? `${trialStatus.days_remaining}${t('onboarding.day_suffix')}` : ''} {t('onboarding.trial_active_desc')}
                </p>

                <div className="text-left bg-zinc-800/60 rounded-xl p-4 mb-6 space-y-2.5">
                  {[
                    { icon: '🏪', label: t('onboarding.feature_pos_title'), desc: t('onboarding.feature_pos_desc') },
                    { icon: '📦', label: t('onboarding.feature_inventory_title'), desc: t('onboarding.feature_inventory_desc') },
                    { icon: '👥', label: t('onboarding.feature_customers_title'), desc: t('onboarding.feature_customers_desc') },
                    { icon: '📊', label: t('onboarding.feature_analytics_title'), desc: t('onboarding.feature_analytics_desc') },
                    { icon: '🛒', label: t('qa.procurement'), desc: t('onboarding.feature_procurement_desc') },
                  ].map(item => (
                    <div key={item.label} className="flex items-start gap-3">
                      <span className="text-lg flex-shrink-0 mt-0.5">{item.icon}</span>
                      <div>
                        <p className="text-sm font-medium text-zinc-200">{item.label}</p>
                        <p className="text-xs text-zinc-500">{item.desc}</p>
                      </div>
                      <span className="ml-auto text-green-400 text-xs font-medium flex-shrink-0">✓ {t('onboarding.included')}</span>
                    </div>
                  ))}
                </div>

                <Btn variant="primary" size="lg" fullWidth onClick={handleFinish}>
                  {t('onboarding.go_to_dashboard')}
                </Btn>

                {trialStatus && (
                  <p className="text-xs text-zinc-600 mt-3">
                    {t('onboarding.trial_limits_prefix')} {fmtLimit(trialStatus.usage.products?.limit, t)} {t('onboarding.trial_limits_products')}
                    {' '}· {fmtLimit(trialStatus.usage.staff?.limit, t)} {t('onboarding.trial_limits_staff')}
                    {' '}· {fmtLimit(trialStatus.usage.branches?.limit, t)} {t('onboarding.trial_limits_branch')}
                    {' '}· {fmtLimit(trialStatus.usage.customers?.limit, t)} {t('onboarding.trial_limits_customers')}
                  </p>
                )}
              </div>
            </div>
          )}
        </div>

        <p className="text-center text-zinc-600 text-xs mt-4">
          <button
            onClick={completeOnboarding}
            className="text-zinc-600 hover:text-zinc-400 underline-offset-2 hover:underline"
          >
            {t('onboarding.skip_setup')}
          </button>
        </p>
      </div>
    </div>
    </div>
  )
}
