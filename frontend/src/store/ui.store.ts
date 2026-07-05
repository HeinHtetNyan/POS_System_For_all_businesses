import { create } from 'zustand'

interface UIState {
  sidebarOpen: boolean
  isOnline: boolean
  posFocusMode: boolean
  pendingSyncCount: number
  failedSyncCount: number

  toggleSidebar: () => void
  closeSidebar: () => void
  setOnline: (online: boolean) => void
  toggleOnline: () => void
  togglePosFocusMode: () => void
  setPosFocusMode: (on: boolean) => void
  setPendingSyncCount: (count: number) => void
  setFailedSyncCount: (count: number) => void
}

export const useUIStore = create<UIState>()((set) => ({
  sidebarOpen: false,
  isOnline: navigator.onLine,
  posFocusMode: false,
  pendingSyncCount: 0,
  failedSyncCount: 0,

  toggleSidebar:       () => set(s => ({ sidebarOpen: !s.sidebarOpen })),
  closeSidebar:        () => set({ sidebarOpen: false }),
  setOnline:           (isOnline) => set({ isOnline }),
  toggleOnline:        () => set(s => ({ isOnline: !s.isOnline })),
  togglePosFocusMode:  () => set(s => ({ posFocusMode: !s.posFocusMode })),
  setPosFocusMode:     (on) => set({ posFocusMode: on }),
  setPendingSyncCount: (pendingSyncCount) => set({ pendingSyncCount }),
  setFailedSyncCount:  (failedSyncCount) => set({ failedSyncCount }),
}))
