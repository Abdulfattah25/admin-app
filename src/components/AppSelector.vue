<template>
  <div class="mb-6">
    <label class="block text-sm font-medium text-gray-700 mb-2">
      Select Application
    </label>
    <select 
      v-model="selectedApp" 
      @change="handleAppChange"
      :disabled="adminStore.loading"
      class="form-input max-w-xs"
    >
      <option value="">All Applications</option>
      <option 
        v-for="app in adminStore.applications" 
        :key="app.name" 
        :value="app.name"
      >
        {{ app.name }}
      </option>
    </select>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAdminStore } from '@/stores/admin'

const emit = defineEmits(['app-changed'])

const adminStore = useAdminStore()
const selectedApp = ref('')

const handleAppChange = async () => {
  try {
    await adminStore.selectApp(selectedApp.value || null)
    emit('app-changed')
  } catch (error) {
    console.error('Failed to select app:', error)
  }
}

onMounted(async () => {
  if (adminStore.applications.length === 0) {
    await adminStore.fetchApplications()
  }
})
</script>