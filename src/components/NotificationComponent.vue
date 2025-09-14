<template>
  <transition
    enter-active-class="transform ease-out duration-300 transition"
    enter-from-class="translate-y-2 opacity-0 sm:translate-y-0 sm:translate-x-2"
    enter-to-class="translate-y-0 opacity-100 sm:translate-x-0"
    leave-active-class="transition ease-in duration-100"
    leave-from-class="opacity-100"
    leave-to-class="opacity-0"
  >
    <div
      v-if="visible"
      :class="[
        'max-w-2xl w-full sm:max-w-3xl md:max-w-4xl lg:max-w-5xl bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden',
        typeClasses,
      ]"
    >
      <div class="p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <component :is="iconComponent" :class="iconClasses" />
          </div>
          <div class="ml-3 flex-1 min-w-0 pt-0.5">
            <p class="text-sm font-medium text-gray-900 break-words">
              {{ title }}
            </p>
            <p class="mt-1 text-sm text-gray-500 whitespace-pre-wrap break-words">
              {{ message }}
            </p>
          </div>
          <div class="ml-4 flex-shrink-0 flex">
            <button
              @click="close"
              class="bg-white rounded-md inline-flex text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              aria-label="Close notification"
            >
              <i class="fa-solid fa-xmark text-lg"></i>
            </button>
          </div>
        </div>
      </div>
    </div>
  </transition>
</template>

<script setup>
import { computed, onMounted } from 'vue'
import CheckCircleIcon from '@/components/icons/CheckCircleIcon.vue'
import XCircleIcon from '@/components/icons/XCircleIcon.vue'
import ExclamationTriangleIcon from '@/components/icons/ExclamationTriangleIcon.vue'
import InformationCircleIcon from '@/components/icons/InformationCircleIcon.vue'

const props = defineProps({
  type: {
    type: String,
    default: 'info',
    validator: (value) => ['success', 'error', 'warning', 'info'].includes(value),
  },
  title: {
    type: String,
    required: true,
  },
  message: {
    type: String,
    required: true,
  },
  duration: {
    type: Number,
    default: 5000,
  },
  visible: {
    type: Boolean,
    default: true,
  },
})

const emit = defineEmits(['close'])

const typeClasses = computed(() => {
  const classes = {
    success: 'border-l-4 border-green-400',
    error: 'border-l-4 border-red-400',
    warning: 'border-l-4 border-yellow-400',
    info: 'border-l-4 border-blue-400',
  }
  return classes[props.type]
})

const iconComponent = computed(() => {
  const icons = {
    success: CheckCircleIcon,
    error: XCircleIcon,
    warning: ExclamationTriangleIcon,
    info: InformationCircleIcon,
  }
  return icons[props.type]
})

const iconClasses = computed(() => {
  const classes = {
    success: 'text-green-400 text-xl',
    error: 'text-red-400 text-xl',
    warning: 'text-yellow-400 text-xl',
    info: 'text-blue-400 text-xl',
  }
  return classes[props.type]
})

const close = () => {
  emit('close')
}

onMounted(() => {
  if (props.duration > 0) {
    setTimeout(() => {
      close()
    }, props.duration)
  }
})
</script>
