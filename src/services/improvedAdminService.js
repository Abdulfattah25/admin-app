import { supabase } from '@/supabase'

export class AdminService {
  // Applications Management
  static async getApplications() {
    const { data, error } = await supabase
      .from('applications')
      .select('*')
      .eq('is_active', true)
      .order('display_name')

    if (error) throw error
    return data || []
  }

  // Users Management - using new table structure
  static async getUsersByApp(appName = null) {
    let query = supabase.from('admin_app_users').select(`
        *,
        admin_licenses!admin_app_users_license_id_fkey(
          license_code,
          created_at
        )
      `)

    if (appName) {
      query = query.eq('app_name', appName)
    }

    const { data, error } = await query.order('created_at', { ascending: false })

    if (error) throw error
    return data || []
  }

  static async getUserStats(appName = null) {
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

    return {
      total: count || 0,
      active: activeCount || 0,
      inactive: (count || 0) - (activeCount || 0),
    }
  }

  static async updateUserStatus(userId, status) {
    const { data, error } = await supabase
      .from('admin_app_users')
      .update({
        status,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId)
      .select()

    if (error) throw error
    return data[0]
  }

  static async deleteUser(userId) {
    const { error } = await supabase.from('admin_app_users').delete().eq('id', userId)

    if (error) throw error
  }

  // License Management - using new table structure
  static async getLicensesByApp(appName = null) {
    let query = supabase.from('admin_licenses').select(`
        *,
        admin_app_users!admin_licenses_used_by_fkey(
          id,
          email,
          name
        )
      `)

    if (appName) {
      query = query.eq('app_name', appName)
    }

    const { data, error } = await query.order('created_at', { ascending: false })

    if (error) throw error
    return data || []
  }

  static async getLicenseStats(appName = null) {
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

    return {
      total: total || 0,
      used: used || 0,
      available: (total || 0) - (used || 0),
    }
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

    const { data, error } = await supabase.from('admin_licenses').insert(licenses).select()

    if (error) throw error
    return data
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
    const { error } = await supabase.from('admin_licenses').delete().eq('id', licenseId)

    if (error) throw error
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
}
