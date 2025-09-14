<template>
  <teleport to="body">
    <transition
      enter-active-class="duration-300 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="duration-200 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="show"
        class="fixed inset-0 z-50 overflow-y-auto"
        aria-labelledby="modal-title"
        role="dialog"
        aria-modal="true"
      >
        <div
          class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0"
        >
          <div
            class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
            @click="$emit('cancel')"
          ></div>

          <!-- Modal panel -->
          <transition
            enter-active-class="duration-300 ease-out"
            enter-from-class="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
            enter-to-class="opacity-100 translate-y-0 sm:scale-100"
            leave-active-class="duration-200 ease-in"
            leave-from-class="opacity-100 translate-y-0 sm:scale-100"
            leave-to-class="opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"
          >
            <div
              v-if="show"
              class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full"
            >
              <form @submit.prevent="handleSubmit">
                <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
                  <div class="sm:flex sm:items-start">
                    <div
                      class="mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full bg-indigo-100 sm:mx-0 sm:h-10 sm:w-10"
                    >
                      <i class="fa-solid fa-key text-indigo-600 text-lg"></i>
                    </div>
                    <div class="mt-3 text-center sm:mt-0 sm:ml-4 sm:text-left w-full">
                      <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">
                        Generate Licenses
                      </h3>
                      <div class="mt-4">
                        <div class="mb-4">
                          <label class="block text-sm font-medium text-gray-700 mb-2">
                            Application: <span class="font-semibold">{{ appName }}</span>
                          </label>
                        </div>
                        <div class="mb-4">
                          <label
                            for="license-count"
                            class="block text-sm font-medium text-gray-700 mb-2"
                          >
                            Number of licenses to generate:
                          </label>
                          <input
                            id="license-count"
                            v-model.number="licenseCount"
                            type="number"
                            min="1"
                            max="100"
                            required
                            class="form-input"
                            placeholder="Enter number of licenses"
                          />
                          <p class="mt-1 text-xs text-gray-500">
                            You can generate between 1 and 100 licenses at once.
                          </p>
                        </div>
                        <div v-if="errors.licenseCount" class="text-red-600 text-sm">
                          {{ errors.licenseCount }}
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
                  <button
                    type="submit"
                    :disabled="!isFormValid || loading"
                    class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <LoadingComponent v-if="loading" />
                    <span v-else>Generate</span>
                  </button>
                  <button
                    type="button"
                    class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
                    @click="$emit('cancel')"
                  >
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </transition>
        </div>
      </div>
    </transition>
  </teleport>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import LoadingComponent from '@/components/LoadingComponent.vue'

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  appName: {
    type: String,
    required: true,
  },
})

const emit = defineEmits(['confirm', 'cancel'])

const licenseCount = ref(10)
const loading = ref(false)
const errors = ref({})

const isFormValid = computed(() => {
  return (
    licenseCount.value &&
    licenseCount.value >= 1 &&
    licenseCount.value <= 100 &&
    Object.keys(errors.value).length === 0
  )
})

const validateForm = () => {
  errors.value = {}

  if (!licenseCount.value) {
    errors.value.licenseCount = 'License count is required'
  } else if (licenseCount.value < 1) {
    errors.value.licenseCount = 'Minimum 1 license required'
  } else if (licenseCount.value > 100) {
    errors.value.licenseCount = 'Maximum 100 licenses allowed'
  }
}

const handleSubmit = () => {
  validateForm()

  if (isFormValid.value) {
    emit('confirm', licenseCount.value)
  }
}

// Reset form when modal is closed
watch(
  () => props.show,
  (newValue) => {
    if (!newValue) {
      licenseCount.value = 10
      errors.value = {}
      loading.value = false
    }
  },
)

// Validate on input change
watch(licenseCount, validateForm)
</script>
