import { supabase } from '@/supabase'

export class AuthService {
  static async login(email, password) {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      })

      if (error) throw error

      // Wait a moment to ensure auth state is established
      await new Promise((resolve) => setTimeout(resolve, 100))

      // Check admin privileges using new admin_profiles table
      let userData = null
      let attempts = 0
      const maxAttempts = 3

      while (attempts < maxAttempts && !userData) {
        try {
          const { data: fetchedUserData, error: userError } = await supabase
            .from('admin_profiles')
            .select('role, is_active, email, name')
            .eq('id', data.user.id)
            .single()

          if (userError) {
            // If user not found in admin_profiles, create one as admin
            if (userError.code === 'PGRST116') {
              const { data: newUser, error: createError } = await supabase
                .from('admin_profiles')
                .insert({
                  id: data.user.id,
                  email: data.user.email,
                  role: 'admin', // Default admin for first login
                  is_active: true,
                })
                .select()
                .single()

              if (createError) {
                console.error('Failed to create admin profile:', createError)
                throw new Error('Failed to create admin account. Please contact administrator.')
              }
              userData = newUser
              break
            } else if (userError.code === '42P17') {
              // Handle infinite recursion error
              attempts++
              if (attempts < maxAttempts) {
                await new Promise((resolve) => setTimeout(resolve, 500 * attempts))
                continue
              }
              throw new Error('Database policy error. Please contact administrator.')
            } else {
              throw userError
            }
          } else {
            userData = fetchedUserData
            break
          }
        } catch (retryError) {
          attempts++
          if (attempts >= maxAttempts) {
            throw retryError
          }
          await new Promise((resolve) => setTimeout(resolve, 500 * attempts))
        }
      }

      if (!userData) {
        throw new Error('Unable to fetch user data. Please try again.')
      }

      if (!['admin', 'super_admin'].includes(userData.role)) {
        // Logout the user since they don't have admin access
        await supabase.auth.signOut()
        throw new Error('Access denied. Admin privileges required.')
      }

      if (!userData.is_active) {
        await supabase.auth.signOut()
        throw new Error('Account is inactive. Please contact administrator.')
      }

      return { user: data.user, userData }
    } catch (error) {
      console.error('Login error:', error)
      // Provide more user-friendly error messages
      if (error.message.includes('invalid_credentials')) {
        throw new Error('Invalid email or password.')
      } else if (error.message.includes('too_many_requests')) {
        throw new Error('Too many login attempts. Please try again later.')
      } else if (error.message.includes('42P17') || error.message.includes('infinite recursion')) {
        throw new Error('Database configuration error. Please contact administrator.')
      }
      throw error
    }
  }

  static async logout() {
    const { error } = await supabase.auth.signOut()
    if (error) throw error
  }

  static async getCurrentUser() {
    const {
      data: { user },
    } = await supabase.auth.getUser()

    if (!user) return null

    const { data: userData } = await supabase
      .from('admin_profiles')
      .select('role, is_active, email, name')
      .eq('id', user.id)
      .single()

    return { user, userData }
  }
}
