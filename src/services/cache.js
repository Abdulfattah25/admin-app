// Simple in-memory cache with TTL per key
// Note: Resets on page reload. Suitable for SPA runtime caching.

class MemoryCache {
  constructor() {
    this.store = new Map()
  }

  // key: string, value: any, ttlMs: number
  set(key, value, ttlMs = 30000) {
    const expiresAt = Date.now() + ttlMs
    this.store.set(key, { value, expiresAt })
  }

  get(key) {
    const entry = this.store.get(key)
    if (!entry) return null
    if (Date.now() > entry.expiresAt) {
      this.store.delete(key)
      return null
    }
    return entry.value
  }

  del(key) {
    this.store.delete(key)
  }

  // Invalidate all keys that start with the given prefix
  invalidatePrefix(prefix) {
    for (const k of this.store.keys()) {
      if (k.startsWith(prefix)) this.store.delete(k)
    }
  }
}

export const cache = new MemoryCache()

// TTL presets (ms)
export const TTL = {
  APPLICATIONS: 5 * 60 * 1000, // 5 minutes
  LIST: 30 * 1000, // 30 seconds
  STATS: 20 * 1000, // 20 seconds
}

// Helper to normalize app key
export function appCacheKey(appName) {
  return appName && appName.trim() !== '' ? appName : 'all'
}
