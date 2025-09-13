// ============================================================
// CASHFLOW ADMIN SERVICE
// Enhanced admin management service for Cashflow app integration
// Compatible with multi-app admin system
// ============================================================

import { supabase } from '@/supabase'

export class CashflowAdminService {
  constructor() {
    this.tablePrefixes = {
      profiles: 'cashflow_profiles',
      categories: 'cashflow_categories',
      transactions: 'cashflow_transactions',
      budgets: 'cashflow_budgets',
      goals: 'cashflow_goals',
      expenseTypes: 'cashflow_expense_types',
      expenseItems: 'cashflow_expense_items',
    }
  }

  // ============================================================
  // USER MANAGEMENT
  // ============================================================

  static async getAllUsers(page = 1, limit = 20, search = '') {
    try {
      let query = supabase
        .from('cashflow_profiles')
        .select(
          `
          id,
          email,
          full_name,
          avatar_url,
          default_currency,
          timezone,
          is_active,
          created_at,
          updated_at
        `,
        )
        .order('created_at', { ascending: false })

      if (search) {
        query = query.or(`email.ilike.%${search}%,full_name.ilike.%${search}%`)
      }

      const { data, error, count } = await query.range((page - 1) * limit, page * limit - 1)

      if (error) throw error

      return {
        users: data,
        totalCount: count,
        currentPage: page,
        totalPages: Math.ceil(count / limit),
      }
    } catch (error) {
      console.error('Error fetching cashflow users:', error)
      throw error
    }
  }

  static async getUserDetails(userId) {
    try {
      const { data: user, error: userError } = await supabase
        .from('cashflow_profiles')
        .select('*')
        .eq('id', userId)
        .single()

      if (userError) throw userError

      // Get user statistics
      const stats = await CashflowAdminService.getUserStatistics(userId)

      return { ...user, statistics: stats }
    } catch (error) {
      console.error('Error fetching user details:', error)
      throw error
    }
  }

  static async getUserStatistics(userId) {
    try {
      const [transactionStats, categoryStats, budgetStats, goalStats] = await Promise.all([
        CashflowAdminService.getTransactionStatistics(userId),
        CashflowAdminService.getCategoryStatistics(userId),
        CashflowAdminService.getBudgetStatistics(userId),
        CashflowAdminService.getGoalStatistics(userId),
      ])

      return {
        transactions: transactionStats,
        categories: categoryStats,
        budgets: budgetStats,
        goals: goalStats,
      }
    } catch (error) {
      console.error('Error fetching user statistics:', error)
      throw error
    }
  }

  static async updateUserStatus(userId, isActive) {
    try {
      const { data, error } = await supabase
        .from('cashflow_profiles')
        .update({
          is_active: isActive,
          updated_at: new Date().toISOString(),
        })
        .eq('id', userId)
        .select()

      if (error) throw error
      return data[0]
    } catch (error) {
      console.error('Error updating user status:', error)
      throw error
    }
  }

  // ============================================================
  // TRANSACTION ANALYTICS
  // ============================================================

  static async getTransactionStatistics(userId) {
    try {
      const { data, error } = await supabase.rpc('get_cashflow_financial_summary', {
        user_uuid: userId,
        start_date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        end_date: new Date().toISOString().split('T')[0],
      })

      if (error) throw error

      const { data: totalTransactions, error: countError } = await supabase
        .from('cashflow_transactions')
        .select('id', { count: 'exact' })
        .eq('user_id', userId)

      if (countError) throw countError

      return {
        ...data,
        total_transactions: totalTransactions?.length || 0,
      }
    } catch (error) {
      console.error('Error fetching transaction statistics:', error)
      return {
        total_income: 0,
        total_expenses: 0,
        net_amount: 0,
        transaction_count: 0,
        total_transactions: 0,
      }
    }
  }

  static async getCategoryStatistics(userId) {
    try {
      const { data, error } = await supabase
        .from('cashflow_categories')
        .select('type', { count: 'exact' })
        .eq('user_id', userId)
        .eq('is_active', true)

      if (error) throw error

      const incomeCategories = data?.filter((c) => c.type === 'income').length || 0
      const expenseCategories = data?.filter((c) => c.type === 'expense').length || 0

      return {
        total_categories: data?.length || 0,
        income_categories: incomeCategories,
        expense_categories: expenseCategories,
      }
    } catch (error) {
      console.error('Error fetching category statistics:', error)
      return {
        total_categories: 0,
        income_categories: 0,
        expense_categories: 0,
      }
    }
  }

  static async getBudgetStatistics(userId) {
    try {
      const { data, error } = await supabase
        .from('cashflow_budgets')
        .select('amount, spent_amount, is_active')
        .eq('user_id', userId)

      if (error) throw error

      const activeBudgets = data?.filter((b) => b.is_active) || []
      const totalBudgetAmount = activeBudgets.reduce((sum, b) => sum + (b.amount || 0), 0)
      const totalSpentAmount = activeBudgets.reduce((sum, b) => sum + (b.spent_amount || 0), 0)

      return {
        total_budgets: data?.length || 0,
        active_budgets: activeBudgets.length,
        total_budget_amount: totalBudgetAmount,
        total_spent_amount: totalSpentAmount,
        budget_utilization:
          totalBudgetAmount > 0 ? (totalSpentAmount / totalBudgetAmount) * 100 : 0,
      }
    } catch (error) {
      console.error('Error fetching budget statistics:', error)
      return {
        total_budgets: 0,
        active_budgets: 0,
        total_budget_amount: 0,
        total_spent_amount: 0,
        budget_utilization: 0,
      }
    }
  }

  static async getGoalStatistics(userId) {
    try {
      const { data, error } = await supabase
        .from('cashflow_goals')
        .select('target_amount, current_amount, is_completed, is_active')
        .eq('user_id', userId)

      if (error) throw error

      const activeGoals = data?.filter((g) => g.is_active) || []
      const completedGoals = activeGoals.filter((g) => g.is_completed)
      const totalTargetAmount = activeGoals.reduce((sum, g) => sum + (g.target_amount || 0), 0)
      const totalCurrentAmount = activeGoals.reduce((sum, g) => sum + (g.current_amount || 0), 0)

      return {
        total_goals: data?.length || 0,
        active_goals: activeGoals.length,
        completed_goals: completedGoals.length,
        completion_rate:
          activeGoals.length > 0 ? (completedGoals.length / activeGoals.length) * 100 : 0,
        total_target_amount: totalTargetAmount,
        total_current_amount: totalCurrentAmount,
        goal_progress: totalTargetAmount > 0 ? (totalCurrentAmount / totalTargetAmount) * 100 : 0,
      }
    } catch (error) {
      console.error('Error fetching goal statistics:', error)
      return {
        total_goals: 0,
        active_goals: 0,
        completed_goals: 0,
        completion_rate: 0,
        total_target_amount: 0,
        total_current_amount: 0,
        goal_progress: 0,
      }
    }
  }

  // ============================================================
  // GLOBAL ANALYTICS (for dashboard)
  // ============================================================

  static async getGlobalStatistics() {
    try {
      const [userStats, transactionStats, budgetStats, goalStats] = await Promise.all([
        CashflowAdminService.getGlobalUserStatistics(),
        CashflowAdminService.getGlobalTransactionStatistics(),
        CashflowAdminService.getGlobalBudgetStatistics(),
        CashflowAdminService.getGlobalGoalStatistics(),
      ])

      return {
        users: userStats,
        transactions: transactionStats,
        budgets: budgetStats,
        goals: goalStats,
      }
    } catch (error) {
      console.error('Error fetching global statistics:', error)
      throw error
    }
  }

  static async getGlobalUserStatistics() {
    try {
      const { data: totalUsers, error: userError } = await supabase
        .from('cashflow_profiles')
        .select('is_active', { count: 'exact' })

      if (userError) throw userError

      const activeUsers = totalUsers?.filter((u) => u.is_active).length || 0

      return {
        total_users: totalUsers?.length || 0,
        active_users: activeUsers,
        inactive_users: (totalUsers?.length || 0) - activeUsers,
      }
    } catch (error) {
      console.error('Error fetching global user statistics:', error)
      return { total_users: 0, active_users: 0, inactive_users: 0 }
    }
  }

  static async getGlobalTransactionStatistics() {
    try {
      const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
        .toISOString()
        .split('T')[0]
      const today = new Date().toISOString().split('T')[0]

      const { data, error } = await supabase
        .from('cashflow_transactions')
        .select('amount, type, transaction_date')
        .gte('transaction_date', thirtyDaysAgo)
        .lte('transaction_date', today)

      if (error) throw error

      const totalIncome =
        data?.filter((t) => t.type === 'income').reduce((sum, t) => sum + (t.amount || 0), 0) || 0
      const totalExpenses =
        data?.filter((t) => t.type === 'expense').reduce((sum, t) => sum + (t.amount || 0), 0) || 0

      return {
        total_transactions: data?.length || 0,
        total_income: totalIncome,
        total_expenses: totalExpenses,
        net_amount: totalIncome - totalExpenses,
        date_range: {
          start_date: thirtyDaysAgo,
          end_date: today,
        },
      }
    } catch (error) {
      console.error('Error fetching global transaction statistics:', error)
      return {
        total_transactions: 0,
        total_income: 0,
        total_expenses: 0,
        net_amount: 0,
      }
    }
  }

  static async getGlobalBudgetStatistics() {
    try {
      const { data, error } = await supabase
        .from('cashflow_budgets')
        .select('amount, spent_amount, is_active')

      if (error) throw error

      const activeBudgets = data?.filter((b) => b.is_active) || []
      const totalBudgetAmount = data?.reduce((sum, b) => sum + (b.amount || 0), 0) || 0
      const totalSpentAmount = data?.reduce((sum, b) => sum + (b.spent_amount || 0), 0) || 0

      return {
        total_budgets: data?.length || 0,
        active_budgets: activeBudgets.length,
        total_budget_amount: totalBudgetAmount,
        total_spent_amount: totalSpentAmount,
        budget_utilization:
          totalBudgetAmount > 0 ? (totalSpentAmount / totalBudgetAmount) * 100 : 0,
      }
    } catch (error) {
      console.error('Error fetching global budget statistics:', error)
      return {
        total_budgets: 0,
        active_budgets: 0,
        total_budget_amount: 0,
        total_spent_amount: 0,
        budget_utilization: 0,
      }
    }
  }

  static async getGlobalGoalStatistics() {
    try {
      const { data, error } = await supabase
        .from('cashflow_goals')
        .select('target_amount, current_amount, is_completed, is_active')

      if (error) throw error

      const activeGoals = data?.filter((g) => g.is_active) || []
      const completedGoals = activeGoals.filter((g) => g.is_completed)
      const totalTargetAmount = data?.reduce((sum, g) => sum + (g.target_amount || 0), 0) || 0
      const totalCurrentAmount = data?.reduce((sum, g) => sum + (g.current_amount || 0), 0) || 0

      return {
        total_goals: data?.length || 0,
        active_goals: activeGoals.length,
        completed_goals: completedGoals.length,
        completion_rate:
          activeGoals.length > 0 ? (completedGoals.length / activeGoals.length) * 100 : 0,
        total_target_amount: totalTargetAmount,
        total_current_amount: totalCurrentAmount,
        goal_progress: totalTargetAmount > 0 ? (totalCurrentAmount / totalTargetAmount) * 100 : 0,
      }
    } catch (error) {
      console.error('Error fetching global goal statistics:', error)
      return {
        total_goals: 0,
        active_goals: 0,
        completed_goals: 0,
        completion_rate: 0,
        total_target_amount: 0,
        total_current_amount: 0,
        goal_progress: 0,
      }
    }
  }

  // ============================================================
  // DATA MANAGEMENT
  // ============================================================

  static async getUserTransactions(userId, page = 1, limit = 20, filters = {}) {
    try {
      let query = supabase
        .from('cashflow_transactions')
        .select(
          `
          id,
          amount,
          description,
          notes,
          type,
          transaction_date,
          created_at,
          cashflow_categories:category_id (
            id,
            name,
            color,
            icon
          )
        `,
        )
        .eq('user_id', userId)
        .order('transaction_date', { ascending: false })

      // Apply filters
      if (filters.type) {
        query = query.eq('type', filters.type)
      }
      if (filters.categoryId) {
        query = query.eq('category_id', filters.categoryId)
      }
      if (filters.startDate) {
        query = query.gte('transaction_date', filters.startDate)
      }
      if (filters.endDate) {
        query = query.lte('transaction_date', filters.endDate)
      }

      const { data, error, count } = await query.range((page - 1) * limit, page * limit - 1)

      if (error) throw error

      return {
        transactions: data,
        totalCount: count,
        currentPage: page,
        totalPages: Math.ceil(count / limit),
      }
    } catch (error) {
      console.error('Error fetching user transactions:', error)
      throw error
    }
  }

  static async getUserBudgets(userId) {
    try {
      const { data, error } = await supabase
        .from('cashflow_budgets')
        .select(
          `
          id,
          name,
          amount,
          spent_amount,
          period,
          start_date,
          end_date,
          is_active,
          alert_percentage,
          cashflow_categories:category_id (
            id,
            name,
            color,
            icon
          )
        `,
        )
        .eq('user_id', userId)
        .order('created_at', { ascending: false })

      if (error) throw error
      return data
    } catch (error) {
      console.error('Error fetching user budgets:', error)
      throw error
    }
  }

  static async getUserGoals(userId) {
    try {
      const { data, error } = await supabase
        .from('cashflow_goals')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })

      if (error) throw error
      return data
    } catch (error) {
      console.error('Error fetching user goals:', error)
      throw error
    }
  }

  // ============================================================
  // DATA EXPORT
  // ============================================================

  static async exportUserData(userId, format = 'json') {
    try {
      const [profile, transactions, categories, budgets, goals] = await Promise.all([
        CashflowAdminService.getUserDetails(userId),
        CashflowAdminService.getUserTransactions(userId, 1, 1000), // Get all transactions
        CashflowAdminService.getUserCategories(userId),
        CashflowAdminService.getUserBudgets(userId),
        CashflowAdminService.getUserGoals(userId),
      ])

      const exportData = {
        profile,
        transactions: transactions.transactions,
        categories,
        budgets,
        goals,
        exportDate: new Date().toISOString(),
        appName: 'Cashflow Manager',
      }

      if (format === 'csv') {
        return CashflowAdminService.convertToCSV(exportData)
      }

      return exportData
    } catch (error) {
      console.error('Error exporting user data:', error)
      throw error
    }
  }

  static async getUserCategories(userId) {
    try {
      const { data, error } = await supabase
        .from('cashflow_categories')
        .select('*')
        .eq('user_id', userId)
        .order('name')

      if (error) throw error
      return data
    } catch (error) {
      console.error('Error fetching user categories:', error)
      throw error
    }
  }

  static convertToCSV(data) {
    // Convert transactions to CSV format
    const transactions = data.transactions.map((t) => ({
      Date: t.transaction_date,
      Type: t.type,
      Amount: t.amount,
      Description: t.description,
      Category: t.cashflow_categories?.name || 'Unknown',
      Notes: t.notes || '',
    }))

    const csvHeaders = Object.keys(transactions[0] || {}).join(',')
    const csvRows = transactions.map((row) =>
      Object.values(row)
        .map((value) => (typeof value === 'string' ? `"${value.replace(/"/g, '""')}"` : value))
        .join(','),
    )

    return [csvHeaders, ...csvRows].join('\n')
  }

  // ============================================================
  // CLEANUP AND MAINTENANCE (LEGACY METHODS - UPDATED)
  // ============================================================

  static async getCashflowUsers(limit = 50) {
    // Legacy method for backward compatibility
    const result = await CashflowAdminService.getAllUsers(1, limit)
    return result.users
  }

  static async getCashflowUserStats() {
    // Legacy method for backward compatibility
    return await CashflowAdminService.getGlobalUserStatistics()
  }

  static async updateCashflowUserStatus(userId, isActive) {
    // Legacy method for backward compatibility
    return await CashflowAdminService.updateUserStatus(userId, isActive)
  }
}

// Export the main service class
export default CashflowAdminService

// Export individual functions for backward compatibility
export const getCashflowUsers = CashflowAdminService.getCashflowUsers
export const getCashflowUserStats = CashflowAdminService.getCashflowUserStats
export const getGlobalStatistics = CashflowAdminService.getGlobalStatistics
export const exportUserData = CashflowAdminService.exportUserData
