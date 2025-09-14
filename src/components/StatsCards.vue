<template>
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
    <!-- Total Users -->
    <div class="card">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-indigo-500 rounded-md flex items-center justify-center">
              <i class="fa-solid fa-user-group text-white text-base"></i>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
              <dd class="text-lg font-medium text-gray-900">{{ adminStore.stats.users.total }}</dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <!-- Active Users -->
    <div class="card">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
              <i class="fa-solid fa-user-check text-white text-base"></i>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Active Users</dt>
              <dd class="text-lg font-medium text-gray-900">{{ adminStore.stats.users.active }}</dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <!-- Total Licenses -->
    <div class="card">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
              <i class="fa-solid fa-id-badge text-white text-base"></i>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Total Licenses</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ adminStore.stats.licenses.total }}
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div>

    <!-- Available Licenses -->
    <div class="card">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="w-8 h-8 bg-yellow-500 rounded-md flex items-center justify-center">
              <i class="fa-solid fa-lock-open text-white text-base"></i>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">Available Licenses</dt>
              <dd class="text-lg font-medium text-gray-900">
                {{ adminStore.stats.licenses.available }}
              </dd>
            </dl>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { useAdminStore } from '@/stores/admin'

const adminStore = useAdminStore()
</script>
