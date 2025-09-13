import { createRouter, createWebHistory } from 'vue-router'
import LoginPage from '@/pages/LoginPage.vue'
import DashboardPage from '@/pages/DashboardPage.vue'
import { useAuthStore } from '@/stores/auth'

const routes = [
  {
    path: '/',
    name: 'login',
    component: LoginPage,
  },
  {
    path: '/dashboard',
    name: 'dashboard',
    component: DashboardPage,
    meta: { requiresAuth: true },
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to, _from, next) => {
  const auth = useAuthStore()
  // Ensure auth is initialized before routing decisions
  if (!auth.initialized) {
    try {
      await auth.init()
    } catch (e) {
      // swallow init errors; fallback to default logic
      // console.warn('Auth init failed', e)
    }
  }

  const requiresAuth = to.matched.some((r) => r.meta?.requiresAuth)
  if (requiresAuth && !auth.isAuthenticated) {
    return next({ name: 'login', query: { redirect: to.fullPath } })
  }

  if (to.name === 'login' && auth.isAuthenticated) {
    return next({ name: 'dashboard' })
  }

  return next()
})

export default router
