-- ============================================================
-- COMPLETE DIAGNOSIS AND FIX SCRIPT
-- Run this to diagnose and fix all current issues
-- ============================================================

-- First, let's check what tables exist
SELECT 
  table_name,
  table_schema
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('applications', 'admin_profiles', 'admin_app_users')
ORDER BY table_name;

-- Check applications table structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'applications' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if applications table has data
SELECT COUNT(*) as applications_count FROM public.applications;

-- Check admin_profiles data
SELECT COUNT(*) as admin_profiles_count FROM public.admin_profiles;

-- Check admin_app_users data
SELECT COUNT(*) as admin_app_users_count FROM public.admin_app_users;

-- Show sample data from each table
DO $$
BEGIN
  RAISE NOTICE 'APPLICATIONS TABLE:';
END $$;

SELECT id, name, display_name, is_active FROM public.applications ORDER BY name;

DO $$
BEGIN
  RAISE NOTICE 'ADMIN_PROFILES TABLE:';
END $$;

SELECT id, email, name, role, is_active FROM public.admin_profiles ORDER BY created_at;

DO $$
BEGIN
  RAISE NOTICE 'ADMIN_APP_USERS TABLE:';
END $$;

SELECT user_id, app_name, email, name, role, status FROM public.admin_app_users ORDER BY created_at;

-- Now let's run the fixes

-- 1. Fix applications table structure
CREATE TABLE IF NOT EXISTS public.applications (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  display_name VARCHAR(200),
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add missing columns to applications table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'applications' 
    AND column_name = 'is_active' 
    AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.applications ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'applications' 
    AND column_name = 'display_name' 
    AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.applications ADD COLUMN display_name VARCHAR(200);
  END IF;
END $$;

-- 2. Insert default applications
INSERT INTO public.applications (name, display_name, description, is_active) 
VALUES 
  ('admin', 'Admin Dashboard', 'Administrative dashboard application', true),
  ('productivity', 'Productivity App', 'Productivity management application', true),
  ('cashflow', 'Cashflow App', 'Cashflow management application', true)
ON CONFLICT (name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- 3. Populate admin_app_users from admin_profiles if empty
DO $$
DECLARE
  admin_app_users_count INTEGER;
  admin_profiles_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO admin_app_users_count FROM public.admin_app_users;
  SELECT COUNT(*) INTO admin_profiles_count FROM public.admin_profiles;
  
  RAISE NOTICE 'Current admin_app_users count: %', admin_app_users_count;
  RAISE NOTICE 'Current admin_profiles count: %', admin_profiles_count;
  
  IF admin_app_users_count = 0 AND admin_profiles_count > 0 THEN
    INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status, created_at, updated_at)
    SELECT 
      ap.id as user_id,
      'admin' as app_name,
      ap.email,
      ap.name,
      ap.role,
      CASE 
        WHEN ap.is_active THEN 'active'
        ELSE 'inactive'
      END as status,
      ap.created_at,
      ap.updated_at
    FROM public.admin_profiles ap
    WHERE ap.role IN ('admin', 'super_admin')
    ON CONFLICT (user_id, app_name) DO NOTHING;
    
    RAISE NOTICE 'Populated admin_app_users from admin_profiles';
  ELSE
    RAISE NOTICE 'Admin_app_users already has data or no admin_profiles to migrate';
  END IF;
END $$;

-- Final verification
DO $$
BEGIN
  RAISE NOTICE '=== FINAL STATUS ===';
END $$;

-- Count records in each table
DO $$
DECLARE
  app_count INTEGER;
  profile_count INTEGER;
  app_user_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO app_count FROM public.applications;
  SELECT COUNT(*) INTO profile_count FROM public.admin_profiles;
  SELECT COUNT(*) INTO app_user_count FROM public.admin_app_users;
  
  RAISE NOTICE 'Applications: %', app_count;
  RAISE NOTICE 'Admin Profiles: %', profile_count;
  RAISE NOTICE 'Admin App Users: %', app_user_count;
END $$;

-- Show current applications
SELECT 'APPLICATIONS' as table_name, name, display_name, is_active::text as status FROM public.applications
UNION ALL
SELECT 'ADMIN_APP_USERS' as table_name, app_name, email, status FROM public.admin_app_users
ORDER BY table_name, name;
