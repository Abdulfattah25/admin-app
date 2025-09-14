-- ============================================================
-- CLEANUP OLD SCHEMA: DROP UNUSED LEGACY TABLES SAFELY
-- Run this AFTER:
--   1) admin_core.sql
--   2) productivity_app.sql
--   3) cashflow_app.sql
--   4) migrate_old_to_new.sql
-- This script checks existence and counts to avoid accidental data loss.
-- ============================================================

DO $$
DECLARE
  -- Old table counts (if exist)
  old_users_count int := NULL;
  old_licenses_count int := NULL;
  old_profiles_count int := NULL;
  old_categories_count int := NULL;
  old_transactions_count int := NULL;
  old_templates_count int := NULL;
  old_instances_count int := NULL;
  old_scorelog_count int := NULL;
  old_budgets_count int := NULL;
  old_goals_count int := NULL;
  old_expense_types_count int := NULL;
  old_expense_items_count int := NULL;

  -- New table counts
  new_admin_profiles_count int := 0;
  new_admin_licenses_count int := 0;
  new_admin_app_users_count int := 0;
  new_cashflow_users_count int := 0;
  new_cashflow_categories_count int := 0;
  new_cashflow_transactions_count int := 0;
  new_prod_users_count int := 0;
  new_prod_templates_count int := 0;
  new_prod_instances_count int := 0;
  new_prod_logs_count int := 0;

  -- Toggle optional drops (budgets/goals/expense_types/items)
  drop_optional boolean := TRUE; -- set to FALSE to skip dropping optional legacy tables
BEGIN
  -- Collect OLD counts if tables exist
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='users') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.users' INTO old_users_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='licenses') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.licenses' INTO old_licenses_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='profiles') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.profiles' INTO old_profiles_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='categories') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.categories' INTO old_categories_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='transactions') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.transactions' INTO old_transactions_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='daily_tasks_template') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.daily_tasks_template' INTO old_templates_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='daily_tasks_instance') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.daily_tasks_instance' INTO old_instances_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='score_log') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.score_log' INTO old_scorelog_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='budgets') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.budgets' INTO old_budgets_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='goals') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.goals' INTO old_goals_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='expense_types') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.expense_types' INTO old_expense_types_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='expense_items') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.expense_items' INTO old_expense_items_count;
  END IF;

  -- Collect NEW counts (tables should exist)
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='admin_profiles') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.admin_profiles' INTO new_admin_profiles_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='admin_licenses') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.admin_licenses' INTO new_admin_licenses_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='admin_app_users') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.admin_app_users' INTO new_admin_app_users_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='cashflow_users') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.cashflow_users' INTO new_cashflow_users_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='cashflow_categories') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.cashflow_categories' INTO new_cashflow_categories_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='cashflow_transactions') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.cashflow_transactions' INTO new_cashflow_transactions_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='productivity_users') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.productivity_users' INTO new_prod_users_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='productivity_task_templates') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.productivity_task_templates' INTO new_prod_templates_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='productivity_task_instances') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.productivity_task_instances' INTO new_prod_instances_count;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='productivity_score_logs') THEN
    EXECUTE 'SELECT COUNT(*) FROM public.productivity_score_logs' INTO new_prod_logs_count;
  END IF;

  RAISE NOTICE 'Cleanup summary BEFORE drops:';
  RAISE NOTICE 'old(users=% licenses=% profiles=% categories=% tx=% templates=% instances=% score_log=% budgets=% goals=% exp_types=% exp_items=%)',
    old_users_count, old_licenses_count, old_profiles_count, old_categories_count, old_transactions_count,
    old_templates_count, old_instances_count, old_scorelog_count, old_budgets_count, old_goals_count,
    old_expense_types_count, old_expense_items_count;
  RAISE NOTICE 'new(admin_profiles=% admin_licenses=% admin_app_users=% cashflow_users=% cashflow_categories=% cashflow_tx=% prod_users=% prod_templates=% prod_instances=% prod_logs=%)',
    new_admin_profiles_count, new_admin_licenses_count, new_admin_app_users_count,
    new_cashflow_users_count, new_cashflow_categories_count, new_cashflow_transactions_count,
    new_prod_users_count, new_prod_templates_count, new_prod_instances_count, new_prod_logs_count;

  -- =============================
  -- Drop clearly migrated tables
  -- =============================

  -- public.users -> admin_profiles/admin_app_users
  IF old_users_count IS NOT NULL AND new_admin_profiles_count >= COALESCE(old_users_count,0) THEN
    DROP TABLE IF EXISTS public.users CASCADE;
    RAISE NOTICE 'Dropped table public.users';
  END IF;

  -- public.licenses -> admin_licenses
  IF old_licenses_count IS NOT NULL AND new_admin_licenses_count >= COALESCE(old_licenses_count,0) THEN
    DROP TABLE IF EXISTS public.licenses CASCADE;
    RAISE NOTICE 'Dropped table public.licenses';
  END IF;

  -- Productivity legacy tables
  IF old_templates_count IS NOT NULL AND new_prod_templates_count >= COALESCE(old_templates_count,0) THEN
    DROP TABLE IF EXISTS public.daily_tasks_template CASCADE;
    RAISE NOTICE 'Dropped table public.daily_tasks_template';
  END IF;
  IF old_instances_count IS NOT NULL AND new_prod_instances_count >= COALESCE(old_instances_count,0) THEN
    DROP TABLE IF EXISTS public.daily_tasks_instance CASCADE;
    RAISE NOTICE 'Dropped table public.daily_tasks_instance';
  END IF;
  IF old_scorelog_count IS NOT NULL AND new_prod_logs_count >= COALESCE(old_scorelog_count,0) THEN
    DROP TABLE IF EXISTS public.score_log CASCADE;
    RAISE NOTICE 'Dropped table public.score_log';
  END IF;

  -- Cashflow legacy to new
  IF old_profiles_count IS NOT NULL AND new_cashflow_users_count >= COALESCE(old_profiles_count,0) THEN
    DROP TABLE IF EXISTS public.profiles CASCADE;
    RAISE NOTICE 'Dropped table public.profiles';
  END IF;
  IF old_categories_count IS NOT NULL AND new_cashflow_categories_count >= COALESCE(old_categories_count,0) THEN
    DROP TABLE IF EXISTS public.categories CASCADE;
    RAISE NOTICE 'Dropped table public.categories';
  END IF;
  IF old_transactions_count IS NOT NULL AND new_cashflow_transactions_count >= COALESCE(old_transactions_count,0) THEN
    DROP TABLE IF EXISTS public.transactions CASCADE;
    RAISE NOTICE 'Dropped table public.transactions';
  END IF;

  -- =============================
  -- Optional legacy tables (not used in new split): budgets, goals, expense_types/items
  -- =============================
  IF drop_optional THEN
    IF old_budgets_count IS NOT NULL THEN
      DROP TABLE IF EXISTS public.budgets CASCADE;
      RAISE NOTICE 'Dropped table public.budgets';
    END IF;
    IF old_goals_count IS NOT NULL THEN
      DROP TABLE IF EXISTS public.goals CASCADE;
      RAISE NOTICE 'Dropped table public.goals';
    END IF;
    IF old_expense_items_count IS NOT NULL THEN
      DROP TABLE IF EXISTS public.expense_items CASCADE;
      RAISE NOTICE 'Dropped table public.expense_items';
    END IF;
    IF old_expense_types_count IS NOT NULL THEN
      DROP TABLE IF EXISTS public.expense_types CASCADE;
      RAISE NOTICE 'Dropped table public.expense_types';
    END IF;
  ELSE
    RAISE NOTICE 'Optional drops disabled (budgets/goals/expense_types/expense_items kept)';
  END IF;

  RAISE NOTICE 'Cleanup completed.';
END $$;
