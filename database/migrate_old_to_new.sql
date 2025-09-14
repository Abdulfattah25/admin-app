-- ============================================================
-- MIGRATE OLD DATA TO NEW SPLIT SCHEMA
-- This script is idempotent and safe to re-run.
-- It assumes you have already executed:
--   - database/admin_core.sql
--   - database/productivity_app.sql
--   - database/cashflow_app.sql
-- ============================================================

-- Ensure default applications exist
INSERT INTO public.applications (name, display_name, description, is_active)
VALUES
  ('admin', 'Admin Dashboard', 'Administrative dashboard application', TRUE),
  ('productivity', 'Productivity App', 'Productivity management application', TRUE),
  ('cashflow', 'Cashflow App', 'Cashflow management application', TRUE)
ON CONFLICT (name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();

-- ============================================================
-- 1) ADMIN CORE MIGRATIONS
--    Move from old public.users and public.licenses (if present)
-- ============================================================

DO $$
BEGIN
  -- Migrate old users to admin_profiles and admin_app_users
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'users'
  ) THEN
    -- admin_profiles
    INSERT INTO public.admin_profiles (id, email, name, role, is_active, created_at)
    SELECT 
      id,
      email,
      COALESCE(name, NULL),
      CASE WHEN role IN ('admin','super_admin') THEN role ELSE 'user' END,
      CASE WHEN status = 'active' THEN TRUE ELSE FALSE END,
      COALESCE(created_at, NOW())
    FROM public.users u
    ON CONFLICT (id) DO UPDATE SET
      email = EXCLUDED.email,
      name = EXCLUDED.name,
      role = EXCLUDED.role,
      is_active = EXCLUDED.is_active;

    -- admin_app_users based on app_name column if exists
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='users' AND column_name='app_name'
    ) THEN
      INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status, created_at)
      SELECT 
        id AS user_id,
        COALESCE(app_name, 'productivity') AS app_name,
        email,
        name,
        COALESCE(role, 'user') AS role,
        COALESCE(status, 'active') AS status,
        COALESCE(created_at, NOW())
      FROM public.users
      WHERE app_name IS NOT NULL
      ON CONFLICT (user_id, app_name) DO UPDATE SET
        email = EXCLUDED.email,
        name = EXCLUDED.name,
        role = EXCLUDED.role,
        status = EXCLUDED.status,
        updated_at = NOW();
    END IF;
  END IF;
END $$;

-- Migrate licenses
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'licenses'
  ) THEN
    -- Ensure admin_profiles exist for used_by if any
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='licenses' AND column_name='used_by'
    ) THEN
      INSERT INTO public.admin_profiles (id, email)
      SELECT DISTINCT l.used_by, ''::text
      FROM public.licenses l
      WHERE l.used_by IS NOT NULL
      ON CONFLICT (id) DO NOTHING;
    END IF;

    INSERT INTO public.admin_licenses (license_code, app_name, is_used, used_by, created_at, used_at, expires_at)
    SELECT DISTINCT
      l.license_code,
      COALESCE(l.app_name, 'productivity') AS app_name,
      COALESCE(l.is_used, false) AS is_used,
      l.used_by,
      COALESCE(l.created_at, NOW()),
      l.used_at,
      NULL::timestamptz
    FROM public.licenses l
    ON CONFLICT (license_code) DO UPDATE SET
      app_name = EXCLUDED.app_name,
      is_used = EXCLUDED.is_used,
      used_by = EXCLUDED.used_by,
      used_at = EXCLUDED.used_at,
      expires_at = COALESCE(EXCLUDED.expires_at, public.admin_licenses.expires_at);
  END IF;
END $$;

-- Create 'admin' app enrollments for admins
INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status, created_at, updated_at)
SELECT 
  ap.id AS user_id,
  'admin' AS app_name,
  ap.email,
  ap.name,
  ap.role,
  CASE WHEN ap.is_active THEN 'active' ELSE 'inactive' END,
  ap.created_at,
  ap.updated_at
FROM public.admin_profiles ap
WHERE ap.role IN ('admin','super_admin')
ON CONFLICT (user_id, app_name) DO UPDATE SET
  email = EXCLUDED.email,
  name = EXCLUDED.name,
  role = EXCLUDED.role,
  status = EXCLUDED.status,
  updated_at = NOW();

-- ============================================================
-- 2) PRODUCTIVITY APP MIGRATIONS
--    Move from old tables: users, daily_tasks_template, daily_tasks_instance, score_log
-- ============================================================

DO $$
BEGIN
  -- productivity_users from old public.users if exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='users') THEN
    INSERT INTO public.productivity_users (id, email, name, created_at)
    SELECT id, email, name, COALESCE(created_at, NOW())
    FROM public.users
    ON CONFLICT (id) DO UPDATE SET
      email = EXCLUDED.email,
      name = EXCLUDED.name;
  END IF;

  -- daily_tasks_template -> productivity_task_templates
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='daily_tasks_template') THEN
    INSERT INTO public.productivity_task_templates 
      (id, user_id, task_name, description, priority, category, task_type, score_value, created_at)
    SELECT 
      id,
      user_id,
      task_name,
      NULL::text AS description,
      CASE priority 
        WHEN 'tinggi' THEN 'high'
        WHEN 'sedang' THEN 'medium'
        WHEN 'rendah' THEN 'low'
        ELSE 'medium'
      END AS priority,
      category,
      CASE jenis_task 
        WHEN 'harian' THEN 'daily'
        WHEN 'deadline' THEN 'deadline'
        ELSE 'daily'
      END AS task_type,
      10 AS score_value,
      COALESCE(created_at, NOW())
    FROM public.daily_tasks_template t
    WHERE EXISTS (SELECT 1 FROM public.productivity_users pu WHERE pu.id = t.user_id)
    ON CONFLICT (id) DO UPDATE SET
      task_name = EXCLUDED.task_name,
      priority = EXCLUDED.priority,
      category = EXCLUDED.category,
      task_type = EXCLUDED.task_type;
  END IF;

  -- daily_tasks_instance -> productivity_task_instances
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='daily_tasks_instance') THEN
    INSERT INTO public.productivity_task_instances 
      (id, user_id, template_id, task_name, priority, category, task_type, task_date, deadline_date, is_completed, completed_at, created_at)
    SELECT 
      id,
      user_id,
      task_id AS template_id,
      task_name,
      CASE priority 
        WHEN 'tinggi' THEN 'high'
        WHEN 'sedang' THEN 'medium'
        WHEN 'rendah' THEN 'low'
        ELSE 'medium'
      END AS priority,
      category,
      CASE jenis_task 
        WHEN 'harian' THEN 'daily'
        WHEN 'deadline' THEN 'deadline'
        ELSE 'daily'
      END AS task_type,
      date AS task_date,
      deadline_date,
      is_completed,
      checked_at AS completed_at,
      COALESCE(created_at, NOW())
    FROM public.daily_tasks_instance i
    WHERE EXISTS (SELECT 1 FROM public.productivity_users pu WHERE pu.id = i.user_id)
    ON CONFLICT (id) DO UPDATE SET
      task_name = EXCLUDED.task_name,
      priority = EXCLUDED.priority,
      category = EXCLUDED.category,
      task_type = EXCLUDED.task_type,
      is_completed = EXCLUDED.is_completed;
  END IF;

  -- score_log -> productivity_score_logs
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='score_log') THEN
    INSERT INTO public.productivity_score_logs 
      (id, user_id, score_delta, reason, log_date, created_at)
    SELECT 
      id,
      user_id,
      score_delta,
      reason,
      date AS log_date,
      COALESCE(created_at, NOW())
    FROM public.score_log s
    WHERE EXISTS (SELECT 1 FROM public.productivity_users pu WHERE pu.id = s.user_id)
    ON CONFLICT (id) DO UPDATE SET
      score_delta = EXCLUDED.score_delta,
      reason = EXCLUDED.reason;
  END IF;

  -- Update total_score from logs
  UPDATE public.productivity_users pu
  SET total_score = COALESCE((
    SELECT SUM(score_delta) FROM public.productivity_score_logs WHERE user_id = pu.id
  ), 0);
END $$;

-- Enroll productivity users to admin_app_users
INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status, created_at, updated_at)
SELECT 
  pu.id AS user_id,
  'productivity' AS app_name,
  pu.email,
  pu.name,
  'user' AS role,
  CASE WHEN pu.is_active THEN 'active' ELSE 'inactive' END,
  pu.created_at,
  pu.updated_at
FROM public.productivity_users pu
ON CONFLICT (user_id, app_name) DO UPDATE SET
  email = EXCLUDED.email,
  name = EXCLUDED.name,
  status = EXCLUDED.status,
  updated_at = NOW();

-- ============================================================
-- 3) CASHFLOW APP MIGRATIONS
--    Move from old tables: profiles, categories, transactions
-- ============================================================

DO $$
BEGIN
  -- profiles -> cashflow_users
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='profiles') THEN
    INSERT INTO public.cashflow_users (id, email, name, created_at, updated_at)
    SELECT 
      id,
      email,
      full_name,
      COALESCE(created_at, NOW()),
      COALESCE(updated_at, NOW())
    FROM public.profiles p
    ON CONFLICT (id) DO UPDATE SET
      email = EXCLUDED.email,
      name = EXCLUDED.name,
      updated_at = NOW();
  END IF;

  -- categories -> cashflow_categories (preserve original id to link transactions)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='categories') THEN
    INSERT INTO public.cashflow_categories (id, user_id, name, type, color, is_active, created_at)
    SELECT 
      c.id,
      c.user_id,
      c.name,
      c.type,
      COALESCE(c.color, '#000000'),
      TRUE,
      COALESCE(c.created_at, NOW())
    FROM public.categories c
    WHERE EXISTS (SELECT 1 FROM public.cashflow_users cu WHERE cu.id = c.user_id)
      AND NOT EXISTS (
        SELECT 1 FROM public.cashflow_categories cc WHERE cc.id = c.id
      );
  END IF;

  -- transactions -> cashflow_transactions
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='transactions') THEN
    INSERT INTO public.cashflow_transactions (id, user_id, category_id, amount, description, transaction_date, type, created_at, updated_at)
    SELECT 
      t.id,
      t.user_id,
      t.category_id, -- category ids preserved above
      t.amount,
      t.description,
      t.date AS transaction_date,
      t.type,
      COALESCE(t.created_at, NOW()),
      COALESCE(t.updated_at, NOW())
    FROM public.transactions t
    WHERE EXISTS (SELECT 1 FROM public.cashflow_users cu WHERE cu.id = t.user_id)
      AND NOT EXISTS (
        SELECT 1 FROM public.cashflow_transactions ct WHERE ct.id = t.id
      );
  END IF;
END $$;

-- Enroll cashflow users to admin_app_users
INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status, created_at, updated_at)
SELECT 
  cu.id AS user_id,
  'cashflow' AS app_name,
  cu.email,
  cu.name,
  'user' AS role,
  CASE WHEN cu.is_active THEN 'active' ELSE 'inactive' END,
  cu.created_at,
  cu.updated_at
FROM public.cashflow_users cu
ON CONFLICT (user_id, app_name) DO UPDATE SET
  email = EXCLUDED.email,
  name = EXCLUDED.name,
  status = EXCLUDED.status,
  updated_at = NOW();

-- ============================================================
-- 4) SUMMARY (optional RAISE NOTICE)
-- ============================================================

DO $$
DECLARE
  v_apps int; v_admin_profiles int; v_admin_app_users int; v_admin_licenses int;
  v_prod_users int; v_prod_templates int; v_prod_instances int; v_prod_logs int;
  v_cash_users int; v_cash_cats int; v_cash_tx int;
BEGIN
  SELECT COUNT(*) INTO v_apps FROM public.applications;
  SELECT COUNT(*) INTO v_admin_profiles FROM public.admin_profiles;
  SELECT COUNT(*) INTO v_admin_app_users FROM public.admin_app_users;
  SELECT COUNT(*) INTO v_admin_licenses FROM public.admin_licenses;

  SELECT COUNT(*) INTO v_prod_users FROM public.productivity_users;
  SELECT COUNT(*) INTO v_prod_templates FROM public.productivity_task_templates;
  SELECT COUNT(*) INTO v_prod_instances FROM public.productivity_task_instances;
  SELECT COUNT(*) INTO v_prod_logs FROM public.productivity_score_logs;

  SELECT COUNT(*) INTO v_cash_users FROM public.cashflow_users;
  SELECT COUNT(*) INTO v_cash_cats FROM public.cashflow_categories;
  SELECT COUNT(*) INTO v_cash_tx FROM public.cashflow_transactions;

  RAISE NOTICE 'Summary:';
  RAISE NOTICE 'applications=%', v_apps;
  RAISE NOTICE 'admin_profiles=% admin_app_users=% admin_licenses=%', v_admin_profiles, v_admin_app_users, v_admin_licenses;
  RAISE NOTICE 'productivity_users=% templates=% instances=% logs=%', v_prod_users, v_prod_templates, v_prod_instances, v_prod_logs;
  RAISE NOTICE 'cashflow_users=% categories=% transactions=%', v_cash_users, v_cash_cats, v_cash_tx;
END $$;
