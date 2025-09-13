-- ============================================================
-- MIGRATION SCRIPT: From Old Schema to New Improved Schema
-- Run this AFTER running improved_schema.sql
-- ============================================================

-- Step 1: Migrate existing users to admin_profiles
DO $$
BEGIN
  -- Check if old users table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users' AND table_schema = 'public') THEN
    
    -- Migrate users to admin_profiles
    INSERT INTO public.admin_profiles (id, email, name, role, is_active, created_at)
    SELECT 
      id, 
      email, 
      name,
      CASE 
        WHEN role = 'admin' THEN 'admin'
        ELSE 'user'
      END as role,
      CASE 
        WHEN status = 'active' THEN true
        ELSE false
      END as is_active,
      created_at
    FROM public.users
    ON CONFLICT (id) DO UPDATE SET
      email = EXCLUDED.email,
      name = EXCLUDED.name,
      role = EXCLUDED.role,
      is_active = EXCLUDED.is_active;

    -- Migrate users with app_name to admin_app_users
    INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status, created_at)
    SELECT 
      id as user_id,
      COALESCE(app_name, 'productivity') as app_name,
      email,
      name,
      COALESCE(role, 'user') as role,
      COALESCE(status, 'active') as status,
      created_at
    FROM public.users
    WHERE app_name IS NOT NULL
    ON CONFLICT (user_id, app_name) DO UPDATE SET
      email = EXCLUDED.email,
      name = EXCLUDED.name,
      role = EXCLUDED.role,
      status = EXCLUDED.status;

    RAISE NOTICE 'Users migrated to admin_profiles and admin_app_users';
  END IF;
END $$;

-- Step 2: Migrate existing licenses to admin_licenses
DO $$
BEGIN
  -- Check if old licenses table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'licenses' AND table_schema = 'public') THEN
    
    -- Migrate licenses (handle different possible column structures)
    INSERT INTO public.admin_licenses (license_code, app_name, is_used, used_by, created_at, used_at)
    SELECT DISTINCT
      license_code,
      COALESCE(app_name, 'productivity') as app_name,
      COALESCE(is_used, false) as is_used,
      used_by,
      created_at,
      used_at
    FROM public.licenses
    ON CONFLICT (license_code) DO UPDATE SET
      app_name = EXCLUDED.app_name,
      is_used = EXCLUDED.is_used,
      used_by = EXCLUDED.used_by,
      used_at = EXCLUDED.used_at;

    RAISE NOTICE 'Licenses migrated to admin_licenses';
  END IF;
END $$;

-- Step 3: Migrate productivity-specific data
DO $$
BEGIN
  -- Migrate users to productivity_users
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users' AND table_schema = 'public') THEN
    INSERT INTO public.productivity_users (id, email, name, created_at)
    SELECT 
      id,
      email,
      name,
      created_at
    FROM public.users
    ON CONFLICT (id) DO UPDATE SET
      email = EXCLUDED.email,
      name = EXCLUDED.name;

    RAISE NOTICE 'Users migrated to productivity_users';
  END IF;

  -- Migrate daily_tasks_template to productivity_task_templates
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'daily_tasks_template' AND table_schema = 'public') THEN
    INSERT INTO public.productivity_task_templates 
    (id, user_id, task_name, description, priority, category, task_type, score_value, created_at)
    SELECT 
      id,
      user_id,
      task_name,
      NULL as description, -- old table doesn't have description
      CASE 
        WHEN priority = 'tinggi' THEN 'high'
        WHEN priority = 'sedang' THEN 'medium'
        WHEN priority = 'rendah' THEN 'low'
        ELSE 'medium'
      END as priority,
      category,
      CASE 
        WHEN jenis_task = 'harian' THEN 'daily'
        WHEN jenis_task = 'deadline' THEN 'deadline'
        ELSE 'daily'
      END as task_type,
      10 as score_value, -- default score
      created_at
    FROM public.daily_tasks_template
    WHERE EXISTS (SELECT 1 FROM public.productivity_users WHERE id = daily_tasks_template.user_id)
    ON CONFLICT (id) DO UPDATE SET
      task_name = EXCLUDED.task_name,
      priority = EXCLUDED.priority,
      category = EXCLUDED.category,
      task_type = EXCLUDED.task_type;

    RAISE NOTICE 'Task templates migrated to productivity_task_templates';
  END IF;

  -- Migrate daily_tasks_instance to productivity_task_instances
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'daily_tasks_instance' AND table_schema = 'public') THEN
    INSERT INTO public.productivity_task_instances 
    (id, user_id, template_id, task_name, priority, category, task_type, task_date, deadline_date, is_completed, completed_at, created_at)
    SELECT 
      id,
      user_id,
      task_id as template_id,
      task_name,
      CASE 
        WHEN priority = 'tinggi' THEN 'high'
        WHEN priority = 'sedang' THEN 'medium'
        WHEN priority = 'rendah' THEN 'low'
        ELSE 'medium'
      END as priority,
      category,
      CASE 
        WHEN jenis_task = 'harian' THEN 'daily'
        WHEN jenis_task = 'deadline' THEN 'deadline'
        ELSE 'daily'
      END as task_type,
      date as task_date,
      deadline_date,
      is_completed,
      checked_at as completed_at,
      created_at
    FROM public.daily_tasks_instance
    WHERE EXISTS (SELECT 1 FROM public.productivity_users WHERE id = daily_tasks_instance.user_id)
    ON CONFLICT (id) DO UPDATE SET
      task_name = EXCLUDED.task_name,
      priority = EXCLUDED.priority,
      category = EXCLUDED.category,
      task_type = EXCLUDED.task_type,
      is_completed = EXCLUDED.is_completed;

    RAISE NOTICE 'Task instances migrated to productivity_task_instances';
  END IF;

  -- Migrate score_log to productivity_score_logs
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'score_log' AND table_schema = 'public') THEN
    INSERT INTO public.productivity_score_logs 
    (id, user_id, score_delta, reason, log_date, created_at)
    SELECT 
      id,
      user_id,
      score_delta,
      reason,
      date as log_date,
      created_at
    FROM public.score_log
    WHERE EXISTS (SELECT 1 FROM public.productivity_users WHERE id = score_log.user_id)
    ON CONFLICT (id) DO UPDATE SET
      score_delta = EXCLUDED.score_delta,
      reason = EXCLUDED.reason;

    RAISE NOTICE 'Score logs migrated to productivity_score_logs';
  END IF;
END $$;

-- Step 4: Update user scores in productivity_users based on score_logs
DO $$
BEGIN
  UPDATE public.productivity_users 
  SET total_score = COALESCE((
    SELECT SUM(score_delta) 
    FROM public.productivity_score_logs 
    WHERE user_id = productivity_users.id
  ), 0);
  
  RAISE NOTICE 'Updated total scores for productivity users';
END $$;

-- Step 5: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_migration_admin_profiles_email ON public.admin_profiles(email);
CREATE INDEX IF NOT EXISTS idx_migration_admin_app_users_composite ON public.admin_app_users(user_id, app_name);
CREATE INDEX IF NOT EXISTS idx_migration_productivity_task_instances_user_date ON public.productivity_task_instances(user_id, task_date);

-- Step 6: Verify migration counts
DO $$
DECLARE
  old_users_count INTEGER := 0;
  new_admin_profiles_count INTEGER := 0;
  old_licenses_count INTEGER := 0;
  new_licenses_count INTEGER := 0;
  old_templates_count INTEGER := 0;
  new_templates_count INTEGER := 0;
BEGIN
  -- Count old vs new records
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users' AND table_schema = 'public') THEN
    SELECT COUNT(*) INTO old_users_count FROM public.users;
  END IF;
  
  SELECT COUNT(*) INTO new_admin_profiles_count FROM public.admin_profiles;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'licenses' AND table_schema = 'public') THEN
    SELECT COUNT(*) INTO old_licenses_count FROM public.licenses;
  END IF;
  
  SELECT COUNT(*) INTO new_licenses_count FROM public.admin_licenses;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'daily_tasks_template' AND table_schema = 'public') THEN
    SELECT COUNT(*) INTO old_templates_count FROM public.daily_tasks_template;
  END IF;
  
  SELECT COUNT(*) INTO new_templates_count FROM public.productivity_task_templates;
  
  RAISE NOTICE 'Migration Summary:';
  RAISE NOTICE 'Users: % old -> % new admin_profiles', old_users_count, new_admin_profiles_count;
  RAISE NOTICE 'Licenses: % old -> % new admin_licenses', old_licenses_count, new_licenses_count;
  RAISE NOTICE 'Task Templates: % old -> % new productivity_task_templates', old_templates_count, new_templates_count;
END $$;

-- Step 7: Optional - Drop old tables (UNCOMMENT ONLY AFTER VERIFYING MIGRATION)
-- WARNING: This will permanently delete the old tables. Make sure migration is successful first!

/*
DO $$
BEGIN
  -- Drop old tables only if new tables have data
  IF (SELECT COUNT(*) FROM public.admin_profiles) > 0 THEN
    DROP TABLE IF EXISTS public.daily_tasks_instance CASCADE;
    DROP TABLE IF EXISTS public.daily_tasks_template CASCADE;
    DROP TABLE IF EXISTS public.score_log CASCADE;
    DROP TABLE IF EXISTS public.profiles CASCADE;
    -- Keep old users and licenses tables for now as backup
    -- DROP TABLE IF EXISTS public.users CASCADE;
    -- DROP TABLE IF EXISTS public.licenses CASCADE;
    
    RAISE NOTICE 'Old productivity tables dropped';
  ELSE
    RAISE NOTICE 'Migration not complete - old tables preserved';
  END IF;
END $$;
*/

-- Final completion message
DO $$
BEGIN
  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE 'Please verify your data and then uncomment the drop table section if needed.';
  RAISE NOTICE 'Update your application to use the new table names.';
END $$;
