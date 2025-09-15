# License System Integration Guide

## Overview

Sistem lisensi terpusat untuk mengelola akses multi-aplikasi dalam satu project Supabase. Admin app dapat membuat lisensi, aplikasi lain dapat verify & redeem untuk mengaktifkan akses user.

## ⚠️ File Structure Updates (Terbaru)

**File yang DIHAPUS (sudah digabung):**

- ~~`src/services/improvedAdminService.js`~~ → Digabung ke `src/services/adminService.js`
- ~~`database/license_rpc.sql`~~ → Digabung ke `database/admin_core.sql`

**File UTAMA:**

- `src/services/adminService.js` - Service tunggal untuk semua fungsi admin
- `database/admin_core.sql` - Schema lengkap dengan license RPC functions
- `src/services/supaUtils.js` - Helper utilities (runRpc, paginate)

## Database Setup

1. **Jalankan SQL untuk setup lengkap:**

   ```bash
   # Di Supabase SQL Editor, jalankan:
   database/admin_core.sql
   ```

2. **Tabel yang diperlukan:**
   - `admin_licenses` - menyimpan kode lisensi per aplikasi
   - `admin_app_users` - menyimpan user access per aplikasi
   - `admin_profiles` - profil user dasar
   - `applications` - daftar aplikasi aktif

## Admin App Usage

### Generate Lisensi

```javascript
// Generate 10 lisensi untuk productivity app
await AdminService.generateLicenses('productivity', 10)
```

### Monitor Lisensi

```javascript
// Daftar lisensi dengan pagination
const licenses = await AdminService.getLicensesByApp('productivity', {
  limit: 20,
  offset: 0,
})

// Statistik lisensi
const stats = await AdminService.getLicenseStats('productivity')
// { total: 10, used: 3, available: 7 }
```

## Client App Integration

### 1. Setup Service

Buat `src/services/licenseService.js` di aplikasi client (contoh: productivity app):

```javascript
import { supabase } from '@/supabase'

export class LicenseService {
  static async checkUserAccess(appName = 'productivity') {
    const { data } = await supabase
      .from('admin_app_users')
      .select('status')
      .eq('app_name', appName)
      .eq('user_id', (await supabase.auth.getUser()).data.user?.id)
      .eq('status', 'active')
      .single()

    return !!data
  }

  static async verifyLicense(licenseCode, appName = 'productivity') {
    const { data, error } = await supabase.rpc('verify_license', {
      p_app_name: appName,
      p_license_code: licenseCode,
    })

    if (error) throw error
    return !!data
  }

  static async redeemLicense(licenseCode, appName = 'productivity') {
    const { data, error } = await supabase.rpc('redeem_license', {
      p_app_name: appName,
      p_license_code: licenseCode,
    })

    if (error) throw error
    return data?.[0]
  }
}
```

### 2. Flow Aktivasi

1. User login ke aplikasi
2. Cek akses: `LicenseService.checkUserAccess()`
3. Jika belum ada akses, minta input kode lisensi
4. Verify: `LicenseService.verifyLicense(code)`
5. Redeem: `LicenseService.redeemLicense(code)`
6. Akses aktif, redirect ke aplikasi

### 3. Gating Fitur

```javascript
// Di route guard atau middleware
const hasAccess = await LicenseService.checkUserAccess('productivity')
if (!hasAccess) {
  // Redirect ke halaman aktivasi lisensi
}
```

## Import Consistency (Setelah Update)

**✅ Import yang BENAR setelah consolidation:**

```javascript
import { AdminService } from '@/services/adminService'
```

**❌ Import LAMA (sudah dihapus):**

```javascript
import { AdminService } from '@/services/improvedAdminService' // File sudah tidak ada
```

## Error Handling

RPC functions akan throw error dengan kode spesifik:

- `LICENSE_NOT_FOUND` - Kode tidak ditemukan
- `LICENSE_ALREADY_USED` - Sudah dipakai user lain
- `LICENSE_EXPIRED` - Sudah kadaluarsa

## Performance Optimizations

1. **Caching:** Cache results di localStorage/sessionStorage
2. **Pagination:** Gunakan limit/offset untuk daftar besar
3. **Select minimal:** Hanya kolom yang dibutuhkan UI
4. **Error boundaries:** Graceful fallback saat RPC gagal

## Security Features

1. **RLS Policy:** User hanya bisa baca `admin_app_users` miliknya
2. **SECURITY DEFINER:** RPC bypass RLS dengan aman
3. **Row locking:** Prevent race condition saat redeem
4. **Input validation:** Parameter RPC divalidasi

## Multi-App Architecture

```
Admin App (admin)
├── Generate licenses untuk apps lain
├── Monitor usage per app
└── Manage users per app

Productivity App (productivity)
├── Verify & redeem licenses
├── Check user access
└── Gate features based on license

Cashflow App (cashflow)
├── Verify & redeem licenses
├── Check user access
└── Gate features based on license

Future Apps (any-name)
├── Same pattern...
```

## Example Implementation

Lihat `docs/license-integration-example.js` untuk contoh lengkap komponen Vue yang menggunakan sistem ini.

## File Structure Final

```
src/services/
├── adminService.js     ← Main service (consolidated)
├── authService.js      ← Auth logic
├── cache.js            ← Caching utilities
├── supaUtils.js        ← Supabase utilities (runRpc, paginate)
└── cashflowAdminService.js ← Cashflow specific

database/
└── admin_core.sql      ← Complete schema + license RPCs
```

## Troubleshooting

1. **RPC tidak ditemukan:** Pastikan `database/admin_core.sql` sudah dijalankan di Supabase
2. **Permission denied:** Cek RLS policy dan grant EXECUTE
3. **Import error:** Pastikan import dari `@/services/adminService` (bukan improvedAdminService)
4. **Cache stale:** Invalidation otomatis setelah redeem/generate
5. **Race condition:** Row locking di RPC mencegah double redeem
