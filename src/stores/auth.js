import { defineStore } from 'pinia'
import { AuthService } from '@/services/authService'
import { supabase } from '@/supabase'

let __initPromise = null

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    loading: false,
    error: null,
    initialized: false,
  }),

  getters: {
    isAuthenticated: (state) => !!state.user,
    isAdmin: (state) => state.user?.userData?.role === 'admin',
  },

  actions: {
    async init() {
      if (this.initialized) return
      if (!__initPromise) {
        __initPromise = (async () => {
          // Hydrate session from Supabase
          const {
            data: { session },
          } = await supabase.auth.getSession()
          if (session?.user) {
            // getCurrentUser enriches with admin_profiles
            const current = await AuthService.getCurrentUser()
            if (current) this.user = current
          } else {
            this.user = null
          }

          // Subscribe to auth state changes once
          supabase.auth.onAuthStateChange(async (_event, session) => {
            if (session?.user) {
              const current = await AuthService.getCurrentUser()
              if (current) this.user = current
            } else {
              this.user = null
            }
          })

          this.initialized = true
        })()
      }
      await __initPromise
    },
    async login(credentials) {
      this.loading = true
      this.error = null

      try {
        const result = await AuthService.login(credentials.email, credentials.password)
        this.user = result
        return result
      } catch (error) {
        this.error = error.message
        throw error
      } finally {
        this.loading = false
      }
    },

    async logout() {
      try {
        await AuthService.logout()
        this.user = null
        this.error = null
      } catch (error) {
        this.error = error.message
        throw error
      }
    },

    async getCurrentUser() {
      try {
        const userData = await AuthService.getCurrentUser()
        if (userData) {
          this.user = userData
        }
        return userData
      } catch (error) {
        console.error('Auth check failed:', error)
        this.error = error.message
        return null
      }
    },

    clearError() {
      this.error = null
    },
  },
})
