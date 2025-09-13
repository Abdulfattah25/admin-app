<template>
  <div class="mb-6">
    <label class="block text-sm font-medium text-gray-700 mb-2"> Select Application </label>
    <select
      v-model="selectedApp"
      @change="handleAppChange"
      :disabled="adminStore.loading"
      class="form-input max-w-xs"
    >
      <option value="">All Applications</option>
      <option v-for="app in adminStore.applications" :key="app.name" :value="app.name">
        {{ app.name }}
      </option>
    </select>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue'
import { useAdminStore } from '@/stores/admin'

const emit = defineEmits(['app-changed'])

const adminStore = useAdminStore()
// Initialize from store or saved selection
const selectedApp = ref('')

const handleAppChange = async () => {
  try {
    const next = selectedApp.value || null
    await adminStore.selectApp(next)
    // Persist only when a concrete app is selected
    if (next) {
      localStorage.setItem('selectedApp', next)
    } else {
      localStorage.removeItem('selectedApp')
    }
    emit('app-changed')
  } catch (error) {
    console.error('Failed to select app:', error)
  }
}

onMounted(async () => {
  if (adminStore.applications.length === 0) {
    await adminStore.fetchApplications()
  }

  // If nothing selected yet, try restore from localStorage (if valid) or pick first app
  if (!adminStore.currentAppName) {
    const saved = localStorage.getItem('selectedApp')
    const names = (adminStore.applications || []).map((a) => a.name)
    const validSaved = saved && names.includes(saved) ? saved : ''
    const first = names[0] || ''
    const pick = validSaved || first
    if (pick) {
      selectedApp.value = pick
      await handleAppChange()
    }
  } else {
    // Sync UI with store if already selected
    selectedApp.value = adminStore.currentAppName || ''
  }
})

// Keep UI selection in sync if currentApp changes elsewhere
watch(
  () => adminStore.currentAppName,
  (val) => {
    if (val !== (selectedApp.value || null)) {
      selectedApp.value = val || ''
    }
  },
)
</script>
