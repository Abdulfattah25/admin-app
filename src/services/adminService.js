import { supabase } from '@/supabase'
import { cache, TTL, appCacheKey } from '@/services/cache'
import { paginate, runRpc } from '@/services/supaUtils'

export class AdminService {
  // Applications Management
  static async getApplications() {
    const cacheKey = 'applications:active'
    const cached = cache.get(cacheKey)
    if (cached) return cached

    const { data, error } = await supabase
      .from('applications')
      .select('*')
      .eq('is_active', true)
      .order('name')

    if (error) throw error
    const result = data || []
    cache.set(cacheKey, result, TTL.APPLICATIONS)
    return result
  }

  // Users Management - using new table structure
  static async getUsersByApp(appName = null, { limit = 20, offset = 0 } = {}) {
    const appKey = appCacheKey(appName)
    const cacheKey = `users:${appKey}:l${limit}:o${offset}`
    const cached = cache.get(cacheKey)
    if (cached) return cached

    try {
      let query = supabase
        .from('admin_app_users')
        .select(
          'id, user_id, app_name, email, name, role, status, license_id, created_at, updated_at',
        )

      if (appName) {
        query = query.eq('app_name', appName)
      }

      const { data, error } = await paginate(query.order('created_at', { ascending: false }), {
        limit,
        offset,
      })

      if (error) throw error

      const rows = data || []

      // Isi nama/email dari profile jika kosong agar UI tetap konsisten
      const userIds = Array.from(new Set(rows.map((r) => r.user_id).filter(Boolean)))
      if (userIds.length > 0) {
        try {
          const { data: profiles, error: profErr } = await supabase
            .from('admin_profiles')
            .select('id, name, email')
            .in('id', userIds)

          if (!profErr && profiles) {
            const nameById = new Map(profiles.map((p) => [p.id, p.name]))
            const emailById = new Map(profiles.map((p) => [p.id, p.email]))

            const enriched = rows.map((r) => ({
              ...r,
              name: r.name && r.name.trim() !== '' ? r.name : (nameById.get(r.user_id) ?? null),
              email:
                r.email && r.email.trim() !== '' ? r.email : (emailById.get(r.user_id) ?? null),
            }))
            cache.set(cacheKey, enriched, TTL.LIST)
            return enriched
          }
        } catch (e) {
          console.warn('admin_profiles enrichment failed:', e)
        }
      }

      cache.set(cacheKey, rows, TTL.LIST)
      return rows
    } catch (error) {
      console.error('Error fetching users by app:', error)

      // Fallback ke admin_profiles saat admin_app_users bermasalah
      try {
        const { data: profileData, error: profileError } = await supabase
          .from('admin_profiles')
          .select('id, email, name, role, is_active, created_at, updated_at')
          .order('created_at', { ascending: false })

        if (profileError) throw profileError

        const transformedData = (profileData || []).map((profile) => ({
          id: profile.id,
          user_id: profile.id,
          app_name: appName || 'admin',
          email: profile.email,
          name: profile.name,
          role: profile.role,
          status: profile.is_active ? 'active' : 'inactive',
          created_at: profile.created_at,
          updated_at: profile.updated_at,
        }))

        cache.set(cacheKey, transformedData, TTL.LIST)
        return transformedData
      } catch (fallbackError) {
        console.error('Fallback query also failed:', fallbackError)
        return []
      }
    }
  }

  static async getUserStats(appName = null) {
    const appKey = appCacheKey(appName)
    const cacheKey = `stats:users:${appKey}`
    const cached = cache.get(cacheKey)
    if (cached) return cached

    let query = supabase.from('admin_app_users').select('*', { count: 'exact', head: true })

    if (appName) {
      query = query.eq('app_name', appName)
    }

    const { count, error } = await query

    if (error) throw error

    // Get active users count
    let activeQuery = supabase
      .from('admin_app_users')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'active')

    if (appName) {
      activeQuery = activeQuery.eq('app_name', appName)
    }

    const { count: activeCount } = await activeQuery

    const result = {
      total: count || 0,
      active: activeCount || 0,
      inactive: (count || 0) - (activeCount || 0),
    }
    cache.set(cacheKey, result, TTL.STATS)
    return result
  }

  static async updateUserStatus(userId, status) {
    // 1) Lookup the app user to know user_id and app_name for cascading updates
    const { data: appUser, error: fetchErr } = await supabase
      .from('admin_app_users')
      .select('id, user_id, app_name')
      .eq('id', userId)
      .single()

    if (fetchErr) throw fetchErr

    // 2) Update status on admin_app_users
    const { data, error } = await supabase
      .from('admin_app_users')
      .update({
        status,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId)
      .select()

    if (error) throw error

    // 3) If toggling status for the 'admin' app, reflect to admin_profiles.is_active
    if (appUser?.app_name === 'admin') {
      const isActive = status === 'active'
      const { error: profErr } = await supabase
        .from('admin_profiles')
        .update({ is_active: isActive, updated_at: new Date().toISOString() })
        .eq('id', appUser.user_id)

      if (profErr) {
        console.warn('Failed to sync admin_profiles.is_active:', profErr)
      }
    }

    // Invalidate caches related to this specific app
    const appKey = appCacheKey(appUser?.app_name)
    cache.invalidatePrefix(`users:${appKey}`)
    cache.invalidatePrefix(`stats:users:${appKey}`)
    return data[0]
  }

  static async deleteUser(userId) {
    // 1) Find the app user and its license to free up
    const { data: appUser, error: fetchErr } = await supabase
      .from('admin_app_users')
      .select('id, license_id, app_name')
      .eq('id', userId)
      .single()

    if (fetchErr) throw fetchErr

    // 2) If there is a license, mark it available again
    if (appUser?.license_id) {
      const { error: licErr } = await supabase
        .from('admin_licenses')
        .update({ is_used: false, used_by: null, used_at: null })
        .eq('id', appUser.license_id)
      if (licErr) {
        console.warn('Failed to free license on user delete:', licErr)
      }
    }

    // 3) Delete the app user record
    const { error } = await supabase.from('admin_app_users').delete().eq('id', userId)
    if (error) throw error

    // Invalidate caches for this specific app
    const appKey = appCacheKey(appUser?.app_name)
    cache.invalidatePrefix(`users:${appKey}`)
    cache.invalidatePrefix(`stats:users:${appKey}`)
  }

  // License Management - using new table structure
  static async getLicensesByApp(appName = null, { limit = 20, offset = 0 } = {}) {
    const appKey = appCacheKey(appName)
    const cacheKey = `licenses:${appKey}:l${limit}:o${offset}`
    const cached = cache.get(cacheKey)
    if (cached) return cached

    try {
      let query = supabase
        .from('admin_licenses')
        .select('id, license_code, app_name, is_used, used_at, used_by, created_at')

      if (appName) {
        query = query.eq('app_name', appName)
      }

      const { data: licenses, error } = await paginate(
        query.order('created_at', { ascending: false }),
        { limit, offset },
      )
      if (error) throw error

      const rows = licenses || []

      // Ambil email/nama pemakai lisensi berdasarkan app ketika ada used_by
      const userIds = Array.from(new Set(rows.map((r) => r.used_by).filter(Boolean)))

      let emailByUserId = {}
      let nameByUserId = {}
      if (userIds.length > 0) {
        let userQuery = supabase
          .from('admin_app_users')
          .select('user_id, email, name')
          .in('user_id', userIds)
        if (appName) {
          userQuery = userQuery.eq('app_name', appName)
        }

        const { data: appUsers, error: usersErr } = await userQuery
        if (!usersErr && appUsers) {
          for (const u of appUsers) {
            emailByUserId[u.user_id] = u.email
            nameByUserId[u.user_id] = u.name
          }
        } else if (usersErr) {
          console.warn('admin_app_users lookup failed:', usersErr)
        }
      }

      const result = rows.map((r) => ({
        ...r,
        used_by_email: r.used_by ? (emailByUserId[r.used_by] ?? null) : null,
        used_by_name: r.used_by ? (nameByUserId[r.used_by] ?? null) : null,
      }))
      cache.set(cacheKey, result, TTL.LIST)
      return result
    } catch (e) {
      console.error('Error fetching licenses by app:', e)
      return []
    }
  }

  static async getLicenseStats(appName = null) {
    const appKey = appCacheKey(appName)
    const cacheKey = `stats:licenses:${appKey}`
    const cached = cache.get(cacheKey)
    if (cached) return cached

    let query = supabase.from('admin_licenses').select('*', { count: 'exact', head: true })

    if (appName) {
      query = query.eq('app_name', appName)
    }

    const { count: total } = await query

    let usedQuery = supabase
      .from('admin_licenses')
      .select('*', { count: 'exact', head: true })
      .eq('is_used', true)

    if (appName) {
      usedQuery = usedQuery.eq('app_name', appName)
    }

    const { count: used } = await usedQuery

    const result = {
      total: total || 0,
      used: used || 0,
      available: (total || 0) - (used || 0),
    }
    cache.set(cacheKey, result, TTL.STATS)
    return result
  }

  static async generateLicenses(appName, count) {
    const licenses = []

    for (let i = 0; i < count; i++) {
      const licenseCode = this.generateLicenseCode()
      licenses.push({
        license_code: licenseCode,
        app_name: appName,
      })
    }

    const { error } = await supabase
      .from('admin_licenses')
      .insert(licenses, { returning: 'minimal' })

    if (error) throw error
    const appKey = appCacheKey(appName)
    cache.invalidatePrefix(`licenses:${appKey}`)
    cache.invalidatePrefix(`stats:licenses:${appKey}`)
    return { success: true, inserted: licenses.length }
  }

  static generateLicenseCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    let result = ''
    for (let i = 0; i < 16; i++) {
      if (i > 0 && i % 4 === 0) result += '-'
      result += chars.charAt(Math.floor(Math.random() * chars.length))
    }
    return result
  }

  static async deleteLicense(licenseId) {
    const { data: lic, error: fetchErr } = await supabase
      .from('admin_licenses')
      .select('id, app_name')
      .eq('id', licenseId)
      .single()

    if (fetchErr) throw fetchErr

    const { error } = await supabase.from('admin_licenses').delete().eq('id', licenseId)

    if (error) throw error
    const appKey = appCacheKey(lic?.app_name)
    cache.invalidatePrefix(`licenses:${appKey}`)
    cache.invalidatePrefix(`stats:licenses:${appKey}`)
  }

  // License RPCs for cross-app integration
  static async verifyLicense(appName, licenseCode) {
    try {
      const data = await runRpc('verify_license', {
        p_app_name: appName,
        p_license_code: licenseCode,
      })
      return !!data
    } catch (e) {
      throw e
    }
  }

  static async redeemLicense(appName, licenseCode) {
    try {
      const data = await runRpc('redeem_license', {
        p_app_name: appName,
        p_license_code: licenseCode,
      })

      const appKey = appCacheKey(appName)
      cache.invalidatePrefix(`licenses:${appKey}`)
      cache.invalidatePrefix(`stats:licenses:${appKey}`)
      cache.invalidatePrefix(`users:${appKey}`)
      cache.invalidatePrefix(`stats:users:${appKey}`)

      return Array.isArray(data) ? (data?.[0] ?? null) : (data ?? null)
    } catch (e) {
      throw e
    }
  }

  // Productivity App Specific Methods
  static async getProductivityUsers(limit = 50) {
    const { data, error } = await supabase
      .from('productivity_users')
      .select(
        `
        *,
        productivity_task_instances!inner(
          is_completed,
          task_date
        )
      `,
      )
      .order('total_score', { ascending: false })
      .limit(limit)

    if (error) throw error
    return data || []
  }

  static async getProductivityUserTasks(userId, date = null) {
    let query = supabase
      .from('productivity_task_instances')
      .select(
        `
        *,
        productivity_task_templates(
          id,
          task_name,
          description,
          category
        )
      `,
      )
      .eq('user_id', userId)

    if (date) {
      query = query.eq('task_date', date)
    }

    const { data, error } = await query.order('created_at', { ascending: false })

    if (error) throw error
    return data || []
  }

  // Cashflow App Specific Methods
  static async getCashflowUsers(limit = 50) {
    const { data, error } = await supabase
      .from('cashflow_users')
      .select(
        `
        *,
        cashflow_transactions(
          amount,
          type,
          transaction_date
        )
      `,
      )
      .order('created_at', { ascending: false })
      .limit(limit)

    if (error) throw error
    return data || []
  }

  static async getCashflowUserTransactions(userId, startDate = null, endDate = null) {
    let query = supabase
      .from('cashflow_transactions')
      .select(
        `
        *,
        cashflow_categories(
          name,
          type,
          color
        )
      `,
      )
      .eq('user_id', userId)

    if (startDate) {
      query = query.gte('transaction_date', startDate)
    }
    if (endDate) {
      query = query.lte('transaction_date', endDate)
    }

    const { data, error } = await query.order('transaction_date', { ascending: false })

    if (error) throw error
    return data || []
  }

  // Cross-app analytics
  static async getAppUsageStats() {
    const apps = await this.getApplications()
    const stats = []

    for (const app of apps) {
      const userStats = await this.getUserStats(app.name)
      const licenseStats = await this.getLicenseStats(app.name)

      stats.push({
        app_name: app.name,
        display_name: app.display_name,
        users: userStats,
        licenses: licenseStats,
      })
    }

    return stats
  }

  // Migration helper (run once to migrate old data)
  static async migrateOldData() {
    const { data, error } = await supabase.rpc('migrate_existing_data')

    if (error) throw error
    return data
  }

  // Admin helper: create admin_app_users from active admin_profiles for a given app
  static async createAdminUsersFromProfiles(appName = 'admin') {
    // 1) Fetch active profiles
    const { data: profiles, error: profErr } = await supabase
      .from('admin_profiles')
      .select('id, email, name, role, is_active')
      .eq('is_active', true)

    if (profErr) throw profErr

    const rows = profiles || []
    if (rows.length === 0) return { inserted: 0 }

    // 2) Prepare upsert payload for the target app
    const payload = rows.map((p) => ({
      user_id: p.id,
      app_name: appName || 'admin',
      email: p.email,
      name: p.name,
      role: p.role,
      status: p.is_active ? 'active' : 'inactive',
    }))

    // 3) Upsert with onConflict on (user_id, app_name)
    const { error: upsertErr } = await supabase
      .from('admin_app_users')
      .upsert(payload, { onConflict: 'user_id,app_name' })

    if (upsertErr) throw upsertErr

    // 4) Invalidate caches for this app
    const appKey = appCacheKey(appName)
    cache.invalidatePrefix(`users:${appKey}`)
    cache.invalidatePrefix(`stats:users:${appKey}`)

    return { inserted: payload.length }
  }
}
