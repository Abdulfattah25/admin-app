<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
    <div class="max-w-md w-full space-y-8">
      <div>
        <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">Admin Dashboard</h2>
        <p class="mt-2 text-center text-sm text-gray-600">Sign in to manage your applications</p>
      </div>

      <form class="mt-8 space-y-6" @submit.prevent="handleLogin">
        <div class="rounded-md shadow-sm -space-y-px">
          <div>
            <label for="email" class="sr-only">Email address</label>
            <input
              id="email"
              v-model="formData.email"
              name="email"
              type="email"
              required
              autocomplete="email"
              :disabled="authStore.loading"
              class="form-input rounded-t-md rounded-b-none"
              placeholder="Email address"
            />
          </div>
          <div>
            <label for="password" class="sr-only">Password</label>
            <input
              id="password"
              v-model="formData.password"
              name="password"
              type="password"
              required
              autocomplete="current-password"
              :disabled="authStore.loading"
              class="form-input rounded-t-none rounded-b-md"
              placeholder="Password"
            />
          </div>
        </div>

        <div v-if="authStore.error" class="rounded-md bg-red-50 p-4">
          <div class="text-sm text-red-700">
            {{ authStore.error }}
          </div>
        </div>

        <div>
          <button
            type="submit"
            :disabled="authStore.loading || !isFormValid"
            class="btn-primary w-full justify-center py-2 px-4 text-sm disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <LoadingComponent v-if="authStore.loading" text="Signing in..." />
            <span v-else>Sign in</span>
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import LoadingComponent from '@/components/LoadingComponent.vue'

const router = useRouter()
const authStore = useAuthStore()

const formData = reactive({
  email: '',
  password: '',
})

const isFormValid = computed(() => {
  return formData.email && formData.password
})

const handleLogin = async () => {
  authStore.clearError()

  try {
    await authStore.login(formData)
    router.push('/dashboard')
  } catch (error) {
    // Error akan ditampilkan melalui authStore.error
    console.error('Login failed:', error)

    // Additional error handling untuk UI feedback
    if (
      error.message.includes('Database policy error') ||
      error.message.includes('infinite recursion') ||
      error.message.includes('42P17')
    ) {
      // Show more specific error for database issues
      console.error('Database configuration issue detected')
    }
  }
}
</script>
