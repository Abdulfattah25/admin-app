import { defineStore } from 'pinia'
import { AdminService } from '@/services/adminService'

export const useAdminStore = defineStore('admin', {
  state: () => ({
    currentApp: null,
    applications: [],
    users: [],
    licenses: [],
    stats: {
      users: { total: 0, active: 0, inactive: 0 },
      licenses: { total: 0, used: 0, available: 0 }
    },
    loading: false,
    error: null
  }),

  getters: {
    currentAppName: (state) => state.currentApp
  },

  actions: {
    async fetchApplications() {
      try {
        this.loading = true
        const apps = await AdminService.getApplications()
        this.applications = apps
      } catch (error) {
        this.error = error.message
        throw error
      } finally {
        this.loading = false
      }
    },

    async selectApp(appName) {
      this.currentApp = appName
      await Promise.all([
        this.fetchUsers(),
        this.fetchLicenses(),
        this.fetchStats()
      ])
    },

    async fetchUsers() {
      try {
        const users = await AdminService.getUsersByApp(this.currentApp)
        this.users = users
      } catch (error) {
        this.error = error.message
        throw error
      }
    },

    async fetchLicenses() {
      try {
        const licenses = await AdminService.getLicensesByApp(this.currentApp)
        this.licenses = licenses
      } catch (error) {
        this.error = error.message
        throw error
      }
    },

    async fetchStats() {
      try {
        const [userStats, licenseStats] = await Promise.all([
          AdminService.getUserStats(this.currentApp),
          AdminService.getLicenseStats(this.currentApp)
        ])
        
        this.stats = {
          users: userStats,
          licenses: licenseStats
        }
      } catch (error) {
        this.error = error.message
        throw error
      }
    },

    clearError() {
      this.error = null
    }
  }
})