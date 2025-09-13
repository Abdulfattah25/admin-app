import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router/index.js' // Pastikan path ini benar
import './style.css'
import { useAuthStore } from '@/stores/auth'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)

// Ensure auth session is restored before mount to avoid initial redirect
const auth = useAuthStore()
auth.init().finally(() => {
  router.isReady().then(() => app.mount('#app'))
})
