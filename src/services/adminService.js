import { supabase } from '@/supabase'

export class AdminService {
  // Applications Management
  static async getApplications() {
    const { data, error } = await supabase
      .from('applications')
      .select('*')
      .order('name')
    
    if (error) throw error
    return data || []
  }

  // Users Management
  static async getUsersByApp(appName = null) {
    let query = supabase
      .from('users')
      .select(`
        *,
        licenses!licenses_used_by_fkey(
          license_code,
          used_at
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
    let query = supabase
      .from('users')
      .select('*', { count: 'exact', head: true })

    if (appName) {
      query = query.eq('app_name', appName)
    }

    const { count, error } = await query
    
    if (error) throw error

    // Get active users count
    let activeQuery = supabase
      .from('users')
      .select('*', { count: 'exact', head: true })
      .eq('status', 'active')

    if (appName) {
      activeQuery = activeQuery.eq('app_name', appName)
    }

    const { count: activeCount } = await activeQuery

    return {
      total: count || 0,
      active: activeCount || 0,
      inactive: (count || 0) - (activeCount || 0)
    }
  }

  static async updateUserStatus(userId, status) {
    const { data, error } = await supabase
      .from('users')
      .update({ 
        status, 
        updated_at: new Date().toISOString() 
      })
      .eq('id', userId)
      .select()

    if (error) throw error
    return data[0]
  }

  static async deleteUser(userId) {
    const { error } = await supabase
      .from('users')
      .delete()
      .eq('id', userId)

    if (error) throw error
  }

  // License Management
  static async getLicensesByApp(appName = null) {
    let query = supabase
      .from('licenses')
      .select(`
        *,
        users!licenses_used_by_fkey(
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
    let query = supabase
      .from('licenses')
      .select('*', { count: 'exact', head: true })

    if (appName) {
      query = query.eq('app_name', appName)
    }

    const { count: total } = await query

    let usedQuery = supabase
      .from('licenses')
      .select('*', { count: 'exact', head: true })
      .eq('is_used', true)

    if (appName) {
      usedQuery = usedQuery.eq('app_name', appName)
    }

    const { count: used } = await usedQuery

    return {
      total: total || 0,
      used: used || 0,
      available: (total || 0) - (used || 0)
    }
  }

  static async generateLicenses(appName, count) {
    const licenses = []
    
    for (let i = 0; i < count; i++) {
      const licenseCode = this.generateLicenseCode()
      licenses.push({
        license_code: licenseCode,
        app_name: appName
      })
    }

    const { data, error } = await supabase
      .from('licenses')
      .insert(licenses)
      .select()

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
    const { error } = await supabase
      .from('licenses')
      .delete()
      .eq('id', licenseId)

    if (error) throw error
  }
}