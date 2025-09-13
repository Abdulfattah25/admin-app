-- ============================================================
-- QUICK FIX SCRIPT: Populate admin_app_users from admin_profiles
-- Run this if you have users in admin_profiles but none in admin_app_users
-- ============================================================

-- Ensure applications table has admin app
INSERT INTO public.applications (name, description) 
VALUES ('admin', 'Administrative dashboard application')
ON CONFLICT (name) DO UPDATE SET
  description = EXCLUDED.description,
  updated_at = NOW();

-- Insert all admin_profiles into admin_app_users for admin app
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
ON CONFLICT (user_id, app_name) DO UPDATE SET
  email = EXCLUDED.email,
  name = EXCLUDED.name,
  role = EXCLUDED.role,
  status = EXCLUDED.status,
  updated_at = NOW();

-- Also create entries for productivity app if user profiles exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'productivity_users' AND table_schema = 'public') THEN
    INSERT INTO public.applications (name, description) 
    VALUES ('productivity', 'Productivity management application')
    ON CONFLICT (name) DO UPDATE SET
      description = EXCLUDED.description,
      updated_at = NOW();

    INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status, created_at, updated_at)
    SELECT 
      pu.id as user_id,
      'productivity' as app_name,
      pu.email,
      pu.name,
      'user' as role,
      CASE 
        WHEN pu.is_active THEN 'active'
        ELSE 'inactive'
      END as status,
      pu.created_at,
      pu.updated_at
    FROM public.productivity_users pu
    ON CONFLICT (user_id, app_name) DO UPDATE SET
      email = EXCLUDED.email,
      name = EXCLUDED.name,
      status = EXCLUDED.status,
      updated_at = NOW();

    RAISE NOTICE 'Added productivity users to admin_app_users';
  END IF;
END $$;

-- Also create entries for cashflow app if user profiles exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'cashflow_profiles' AND table_schema = 'public') THEN
    INSERT INTO public.applications (name, description) 
    VALUES ('cashflow', 'Cashflow management application')
    ON CONFLICT (name) DO UPDATE SET
      description = EXCLUDED.description,
      updated_at = NOW();

    INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status, created_at, updated_at)
    SELECT 
      cp.id as user_id,
      'cashflow' as app_name,
      cp.email,
      cp.full_name as name,
      'user' as role,
      CASE 
        WHEN cp.is_active THEN 'active'
        ELSE 'inactive'
      END as status,
      cp.created_at,
      cp.updated_at
    FROM public.cashflow_profiles cp
    ON CONFLICT (user_id, app_name) DO UPDATE SET
      email = EXCLUDED.email,
      name = EXCLUDED.name,
      status = EXCLUDED.status,
      updated_at = NOW();

    RAISE NOTICE 'Added cashflow users to admin_app_users';
  END IF;
END $$;

-- Display summary
DO $$
DECLARE
  admin_count INTEGER;
  productivity_count INTEGER;
  cashflow_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO admin_count FROM public.admin_app_users WHERE app_name = 'admin';
  SELECT COUNT(*) INTO productivity_count FROM public.admin_app_users WHERE app_name = 'productivity';
  SELECT COUNT(*) INTO cashflow_count FROM public.admin_app_users WHERE app_name = 'cashflow';
  
  RAISE NOTICE 'Quick Fix Summary:';
  RAISE NOTICE 'Admin app users: %', admin_count;
  RAISE NOTICE 'Productivity app users: %', productivity_count;
  RAISE NOTICE 'Cashflow app users: %', cashflow_count;
END $$;
