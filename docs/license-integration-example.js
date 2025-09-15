// Example integration untuk aplikasi Productivity
// File: src/services/licenseService.js (di aplikasi productivity)

import { supabase } from '@/supabase'

export class LicenseService {
  // Cek apakah user sudah punya akses aktif untuk app ini
  static async checkUserAccess(appName = 'productivity') {
    try {
      const { data, error } = await supabase
        .from('admin_app_users')
        .select('status')
        .eq('app_name', appName)
        .eq('user_id', (await supabase.auth.getUser()).data.user?.id)
        .eq('status', 'active')
        .single()

      return !error && !!data
    } catch {
      return false
    }
  }

  // Verifikasi kode lisensi sebelum redeem
  static async verifyLicense(licenseCode, appName = 'productivity') {
    try {
      const { data, error } = await supabase.rpc('verify_license', {
        p_app_name: appName,
        p_license_code: licenseCode,
      })

      if (error) throw new Error(error.message)
      return !!data
    } catch (e) {
      throw new Error(`Verifikasi gagal: ${e.message}`)
    }
  }

  // Redeem kode lisensi (aktivasi akses)
  static async redeemLicense(licenseCode, appName = 'productivity') {
    try {
      const { data, error } = await supabase.rpc('redeem_license', {
        p_app_name: appName,
        p_license_code: licenseCode,
      })

      if (error) {
        if (error.message.includes('LICENSE_NOT_FOUND')) {
          throw new Error('Kode lisensi tidak ditemukan')
        }
        if (error.message.includes('LICENSE_ALREADY_USED')) {
          throw new Error('Kode lisensi sudah digunakan')
        }
        if (error.message.includes('LICENSE_EXPIRED')) {
          throw new Error('Kode lisensi sudah kadaluarsa')
        }
        throw new Error(error.message)
      }

      return data?.[0] || null
    } catch (e) {
      throw new Error(`Aktivasi gagal: ${e.message}`)
    }
  }
}

// Contoh penggunaan di komponen Vue:
/*
<template>
  <div v-if="!hasAccess" class="license-form">
    <h2>Aktivasi Lisensi Productivity App</h2>
    <form @submit.prevent="activateLicense">
      <input 
        v-model="licenseCode" 
        placeholder="Masukkan kode lisensi"
        required
      />
      <button type="submit" :disabled="loading">
        {{ loading ? 'Memproses...' : 'Aktivasi' }}
      </button>
    </form>
    <p v-if="error" class="error">{{ error }}</p>
  </div>
  
  <div v-else>
    <!-- Aplikasi productivity normal -->
    <h1>Selamat datang di Productivity App!</h1>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { LicenseService } from '@/services/licenseService'

const hasAccess = ref(false)
const licenseCode = ref('')
const loading = ref(false)
const error = ref('')

onMounted(async () => {
  hasAccess.value = await LicenseService.checkUserAccess()
})

async function activateLicense() {
  loading.value = true
  error.value = ''
  
  try {
    // Verifikasi dulu
    const isValid = await LicenseService.verifyLicense(licenseCode.value)
    if (!isValid) {
      throw new Error('Kode lisensi tidak valid')
    }
    
    // Redeem
    await LicenseService.redeemLicense(licenseCode.value)
    hasAccess.value = true
    licenseCode.value = ''
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
</script>
*/
