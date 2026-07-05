import apiClient from '@/app/lib/axios'
import type {
  LoginRequest,
  TokenResponse,
  LogoutRequest,
  User,
  SuccessResponse,
  RegisterRequest,
  RegistrationResponse,
} from '@/shared/types'

export const authService = {
  login: (payload: LoginRequest) =>
    apiClient.post<TokenResponse>('/auth/login', payload).then(r => r.data),

  refresh: () =>
    apiClient.post<TokenResponse>('/auth/refresh', {}).then(r => r.data),

  logout: (payload?: LogoutRequest) =>
    apiClient.post<SuccessResponse>('/auth/logout', payload ?? {}).then(r => r.data),

  me: () =>
    apiClient.get<User>('/auth/me').then(r => r.data),

  changePassword: (payload: { current_password: string; new_password: string }) =>
    apiClient.post<SuccessResponse>('/auth/change-password', payload).then(r => r.data),

  register: (payload: RegisterRequest) =>
    apiClient.post<RegistrationResponse>('/auth/register', payload).then(r => r.data),

  forgotPassword: (email: string) =>
    apiClient.post<SuccessResponse>('/auth/forgot-password', { email }).then(r => r.data),

  resetPassword: (token: string, new_password: string) =>
    apiClient.post<SuccessResponse>('/auth/reset-password', { token, new_password }).then(r => r.data),

  verifyEmail: (token: string) =>
    apiClient.post<SuccessResponse>('/auth/verify-email', { token }).then(r => r.data),

  resendVerification: (email: string) =>
    apiClient.post<SuccessResponse>('/auth/resend-verification', { email }).then(r => r.data),

  requestEmailChange: (new_email: string, current_password: string) =>
    apiClient.post<SuccessResponse>('/auth/request-email-change', { new_email, current_password }).then(r => r.data),

  confirmEmailChange: (token: string) =>
    apiClient.post<SuccessResponse>('/auth/confirm-email-change', { token }).then(r => r.data),
}
