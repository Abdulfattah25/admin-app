<template>
  <div class="card">
    <div class="px-4 py-5 sm:px-6 flex justify-between items-center">
      <div>
        <h3 class="text-lg leading-6 font-medium text-gray-900">Users Management</h3>
        <p class="mt-1 max-w-2xl text-sm text-gray-500">
          Manage users for {{ adminStore.currentAppName || 'all applications' }}
        </p>
      </div>
      <button @click="refreshUsers" :disabled="loading" class="btn-secondary">
        <i class="fa-solid fa-rotate mr-2 text-sm"></i>
        Refresh
      </button>
    </div>

    <div v-if="loading" class="p-6">
      <LoadingComponent text="Loading users..." />
    </div>

    <ul v-else-if="adminStore.users.length > 0" class="divide-y divide-gray-200">
      <li v-for="user in adminStore.users" :key="user.id" class="px-4 py-4 sm:px-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <div class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
                <span class="text-sm font-medium text-gray-700">
                  {{
                    user.name
                      ? user.name.charAt(0).toUpperCase()
                      : user.email.charAt(0).toUpperCase()
                  }}
                </span>
              </div>
            </div>
            <div class="ml-4">
              <div class="text-sm font-medium text-gray-900">{{ user.name || 'No Name' }}</div>
              <div class="text-sm text-gray-500">{{ user.email }}</div>
              <div class="text-xs text-gray-400 mt-1">
                <span class="inline-flex items-center"> App: {{ user.app_name || 'None' }} </span>
                <span class="mx-2">•</span>
                <span class="inline-flex items-center">
                  Status:
                  <span
                    :class="user.status === 'active' ? 'text-green-600' : 'text-red-600'"
                    class="ml-1"
                  >
                    {{ user.status }}
                  </span>
                </span>
                <span class="mx-2">•</span>
                <span class="inline-flex items-center"> Role: {{ user.role }} </span>
              </div>
            </div>
          </div>
          <div class="flex items-center space-x-2">
            <button
              @click="toggleUserStatus(user)"
              :disabled="actionLoading"
              :class="[
                user.status === 'active'
                  ? 'bg-red-100 text-red-800 hover:bg-red-200'
                  : 'bg-green-100 text-green-800 hover:bg-green-200',
                'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium transition-colors disabled:opacity-50',
              ]"
            >
              {{ user.status === 'active' ? 'Deactivate' : 'Activate' }}
            </button>
            <button
              @click="confirmDeleteUser(user)"
              :disabled="actionLoading"
              class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800 hover:bg-red-200 transition-colors disabled:opacity-50"
            >
              Delete
            </button>
          </div>
        </div>
      </li>
    </ul>

    <!-- Empty state -->
    <div v-else class="text-center py-12">
      <i class="fa-solid fa-users mx-auto text-4xl text-gray-400"></i>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No users</h3>
      <p class="mt-1 text-sm text-gray-500">No users found for this application.</p>
      <button
        @click="checkAndCreateAdminUsers"
        class="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
      >
        Create Admin Users from Profiles
      </button>
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
import { ref, onMounted } from 'vue'
import { useAdminStore } from '@/stores/admin'
import { AdminService } from '@/services/adminService'
import LoadingComponent from '@/components/LoadingComponent.vue'
import ConfirmationModal from '@/components/ConfirmationModal.vue'

const emit = defineEmits(['show-notification'])

const adminStore = useAdminStore()
const loading = ref(false)
const actionLoading = ref(false)
const showConfirmModal = ref(false)
const confirmModal = ref({
  title: '',
  message: '',
  confirmText: 'Confirm',
  type: 'primary',
})
const pendingAction = ref(null)

const refreshUsers = async () => {
  loading.value = true
  try {
    await adminStore.fetchUsers()
  } catch (error) {
    emit('show-notification', {
      type: 'error',
      title: 'Failed to Load Users',
      message: error.message,
    })
  } finally {
    loading.value = false
  }
}

// Load users when component mounts
onMounted(async () => {
  await refreshUsers()
})

const toggleUserStatus = (user) => {
  const newStatus = user.status === 'active' ? 'inactive' : 'active'
  const action = newStatus === 'active' ? 'activate' : 'deactivate'

  confirmModal.value = {
    title: `${action.charAt(0).toUpperCase() + action.slice(1)} User`,
    message: `Are you sure you want to ${action} user "${user.name || user.email}"?`,
    confirmText: action.charAt(0).toUpperCase() + action.slice(1),
    type: newStatus === 'active' ? 'success' : 'warning',
  }

  pendingAction.value = { type: 'toggle-status', user, newStatus }
  showConfirmModal.value = true
}

const confirmDeleteUser = (user) => {
  confirmModal.value = {
    title: 'Delete User',
    message: `Are you sure you want to delete user "${user.name || user.email}"? This action cannot be undone.`,
    confirmText: 'Delete',
    type: 'danger',
  }

  pendingAction.value = { type: 'delete', user }
  showConfirmModal.value = true
}

const handleConfirmAction = async () => {
  if (!pendingAction.value) return

  actionLoading.value = true
  showConfirmModal.value = false

  try {
    const { type, user, newStatus } = pendingAction.value

    if (type === 'toggle-status') {
      await AdminService.updateUserStatus(user.id, newStatus)
      emit('show-notification', {
        type: 'success',
        title: 'User Updated',
        message: `User ${newStatus === 'active' ? 'activated' : 'deactivated'} successfully`,
      })
    } else if (type === 'delete') {
      await AdminService.deleteUser(user.id)
      emit('show-notification', {
        type: 'success',
        title: 'User Deleted',
        message: 'User deleted successfully',
      })
    }

    await adminStore.fetchUsers()
    await adminStore.fetchStats()
  } catch (error) {
    emit('show-notification', {
      type: 'error',
      title: 'Action Failed',
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

const checkAndCreateAdminUsers = async () => {
  loading.value = true
  try {
    const appName = adminStore.currentApp || 'admin'
    const result = await AdminService.createAdminUsersFromProfiles(appName)

    emit('show-notification', {
      type: 'success',
      title: 'Users Created',
      message: `Created or updated ${result.inserted} admin users for ${appName} app`,
    })

    await refreshUsers()
  } catch (error) {
    console.error('Error creating admin users:', error)
    emit('show-notification', {
      type: 'error',
      title: 'Creation Failed',
      message: 'Failed to create admin users: ' + error.message,
    })
  } finally {
    loading.value = false
  }
}
</script>
