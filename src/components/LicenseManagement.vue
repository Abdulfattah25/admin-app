<template>
  <div class="card">
    <div class="px-4 py-5 sm:px-6 flex justify-between items-center">
      <div>
        <h3 class="text-lg leading-6 font-medium text-gray-900">License Management</h3>
        <p class="mt-1 max-w-2xl text-sm text-gray-500">
          Manage licenses for {{ adminStore.currentAppName || 'all applications' }}
        </p>
      </div>
      <div class="flex space-x-3">
        <button
          @click="showGenerateModal = true"
          :disabled="!adminStore.currentAppName || loading"
          class="btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <i class="fa-solid fa-plus mr-2 text-sm"></i>
          Generate Licenses
        </button>
        <button @click="refreshLicenses" :disabled="loading" class="btn-secondary">
          <i class="fa-solid fa-rotate mr-2 text-sm"></i>
          Refresh
        </button>
      </div>
    </div>

    <!-- Generate License Modal -->
    <GenerateLicenseModal
      :show="showGenerateModal"
      :app-name="adminStore.currentAppName"
      @confirm="handleGenerateLicenses"
      @cancel="showGenerateModal = false"
    />

    <div v-if="loading" class="p-6">
      <LoadingComponent text="Loading licenses..." />
    </div>

    <!-- Licenses Table -->
    <div v-else-if="adminStore.licenses.length > 0" class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              License Code
            </th>
            <th
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              Application
            </th>
            <th
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              Status
            </th>
            <th
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              Used By
            </th>
            <th
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              Used At
            </th>
            <th
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
            >
              Actions
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <tr v-for="license in adminStore.licenses" :key="license.id">
            <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
              <button
                @click="copyToClipboard(license.license_code)"
                class="hover:text-indigo-600 transition-colors"
                title="Click to copy"
              >
                {{ license.license_code }}
              </button>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
              {{ license.app_name }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span
                :class="license.is_used ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'"
                class="inline-flex px-2 py-1 text-xs font-semibold rounded-full"
              >
                {{ license.is_used ? 'Used' : 'Available' }}
              </span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
              {{ license.used_by_email || '-' }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
              {{ license.used_at ? formatDate(license.used_at) : '-' }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
              <button
                @click="confirmDeleteLicense(license)"
                :disabled="actionLoading"
                class="text-red-600 hover:text-red-900 transition-colors disabled:opacity-50"
              >
                Delete
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Empty state -->
    <div v-else class="text-center py-12">
      <i class="fa-solid fa-key mx-auto text-4xl text-gray-400"></i>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No licenses</h3>
      <p class="mt-1 text-sm text-gray-500">
        {{
          adminStore.currentAppName
            ? 'No licenses found for this application.'
            : 'Select an application to view licenses.'
        }}
      </p>
    </div>

    <!-- Confirmation Modal -->
    <ConfirmationModal
      :show="showConfirmModal"
      :title="confirmModal.title"
      :message="confirmModal.message"
      :confirm-text="confirmModal.confirmText"
      :confirm-type="confirmModal.type"
      @confirm="handleConfirmAction"
      @cancel="cancelConfirmAction"
    />
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useAdminStore } from '@/stores/admin'
// Use the improved service that targets admin_core.sql tables
import { AdminService } from '@/services/improvedAdminService'
import LoadingComponent from '@/components/LoadingComponent.vue'
import ConfirmationModal from '@/components/ConfirmationModal.vue'
import GenerateLicenseModal from '@/components/GenerateLicenseModal.vue'

const emit = defineEmits(['show-notification'])

const adminStore = useAdminStore()
const loading = ref(false)
const actionLoading = ref(false)
const showGenerateModal = ref(false)
const showConfirmModal = ref(false)
const confirmModal = ref({})
const pendingAction = ref(null)

const refreshLicenses = async () => {
  loading.value = true
  try {
    await adminStore.fetchLicenses()
  } catch (error) {
    emit('show-notification', {
      type: 'error',
      title: 'Failed to Load Licenses',
      message: error.message,
    })
  } finally {
    loading.value = false
  }
}

const handleGenerateLicenses = async (count) => {
  actionLoading.value = true
  showGenerateModal.value = false

  try {
    await AdminService.generateLicenses(adminStore.currentAppName, count)
    await adminStore.fetchLicenses()
    await adminStore.fetchStats()

    emit('show-notification', {
      type: 'success',
      title: 'Licenses Generated',
      message: `${count} licenses generated successfully`,
    })
  } catch (error) {
    emit('show-notification', {
      type: 'error',
      title: 'Failed to Generate Licenses',
      message: error.message,
    })
  } finally {
    actionLoading.value = false
  }
}

const confirmDeleteLicense = (license) => {
  confirmModal.value = {
    title: 'Delete License',
    message: `Are you sure you want to delete license "${license.license_code}"? This action cannot be undone.`,
    confirmText: 'Delete',
    type: 'danger',
  }

  pendingAction.value = { type: 'delete', license }
  showConfirmModal.value = true
}

const handleConfirmAction = async () => {
  if (!pendingAction.value) return

  actionLoading.value = true
  showConfirmModal.value = false

  try {
    const { license } = pendingAction.value
    await AdminService.deleteLicense(license.id)
    await adminStore.fetchLicenses()
    await adminStore.fetchStats()

    emit('show-notification', {
      type: 'success',
      title: 'License Deleted',
      message: 'License deleted successfully',
    })
  } catch (error) {
    emit('show-notification', {
      type: 'error',
      title: 'Failed to Delete License',
      message: error.message,
    })
  } finally {
    actionLoading.value = false
    pendingAction.value = null
  }
}

const cancelConfirmAction = () => {
  showConfirmModal.value = false
  pendingAction.value = null
}

const copyToClipboard = async (text) => {
  try {
    await navigator.clipboard.writeText(text)
    emit('show-notification', {
      type: 'success',
      title: 'Copied',
      message: 'License code copied to clipboard',
    })
  } catch (error) {
    emit('show-notification', {
      type: 'error',
      title: 'Copy Failed',
      message: 'Failed to copy license code',
    })
  }
}

const formatDate = (dateString) => {
  return new Date(dateString).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}
</script>
