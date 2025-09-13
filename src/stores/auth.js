import { defineStore } from 'pinia'
import { AuthService } from '@/services/authService'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    loading: false,
    error: null
  }),

  getters: {
    isAuthenticated: (state) => !!state.user,
    isAdmin: (state) => state.user?.userData?.role === 'admin'
  },

  actions: {
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
    }
  }
})