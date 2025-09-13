<template>
  <div class="min-h-screen bg-gray-100">
    <!-- Navigation -->
    <nav class="bg-white shadow">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex items-center">
            <h1 class="text-xl font-semibold text-gray-900">Admin Dashboard</h1>
          </div>
          <div class="flex items-center space-x-4">
            <span class="text-sm text-gray-700">
              Welcome, {{ authStore.user?.user?.email }}
            </span>
            <button 
              @click="handleLogout"
              class="bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
            >
              Logout
            </button>
          </div>
        </div>
      </div>
    </nav>

    <!-- Main Content -->
    <div class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <!-- Notification Container -->
      <div 
        v-if="notification" 
        class="fixed top-4 right-4 z-50"
      >
        <NotificationComponent
          :type="notification.type"
          :title="notification.title"
          :message="notification.message"
          :visible="!!notification"
          @close="notification = null"
        />
      </div>

      <!-- App Selector -->
      <AppSelector @app-changed="handleAppChanged" />

      <!-- Stats Cards -->
      <StatsCards />

      <!-- Tabs -->
      <div class="bg-white shadow rounded-lg">
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex space-x-8 px-6" aria-label="Tabs">
            <button
              v-for="tab in tabs"
              :key="tab.name"
              @click="activeTab = tab.name"
              :class="[
                activeTab === tab.name 
                  ? 'border-indigo-500 text-indigo-600' 
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300',
                'whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm transition-colors'
              ]"
            >
              {{ tab.label }}
            </button>
          </nav>
        </div>

        <!-- Tab Content -->
        <div class="p-6">
          <UsersManagement 
            v-if="activeTab === 'users'" 
            @show-notification="showNotification"
          />
          <LicenseManagement 
            v-if="activeTab === 'licenses'" 
            @show-notification="showNotification"
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useAdminStore } from '@/stores/admin'
import NotificationComponent from '@/components/NotificationComponent.vue'
import AppSelector from '@/components/AppSelector.vue'
import StatsCards from '@/components/StatsCards.vue'
import UsersManagement from '@/components/UsersManagement.vue'
import LicenseManagement from '@/components/LicenseManagement.vue'

const router = useRouter()
const authStore = useAuthStore()
const adminStore = useAdminStore()

const activeTab = ref('users')
const notification = ref(null)

const tabs = [
  { name: 'users', label: 'Users Management' },
  { name: 'licenses', label: 'License Management' }
]

const handleLogout = async () => {
  try {
    await authStore.logout()
    router.push('/')
  } catch (error) {
    showNotification({
      type: 'error',
      title: 'Logout Failed',
      message: error.message
    })
  }
}

const handleAppChanged = async () => {
  // Data akan di-refresh otomatis oleh AppSelector
}

const showNotification = ({ type, title, message }) => {
  notification.value = { type, title, message }
}

onMounted(async () => {
  if (!authStore.isAuthenticated || !authStore.isAdmin) {
    router.push('/')
    return
  }

  try {
    await adminStore.fetchApplications()
  } catch (error) {
    showNotification({
      type: 'error',
      title: 'Failed to Load Data',
      message: error.message
    })
  }
})
</script>