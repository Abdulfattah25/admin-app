-- ============================================================
-- CASHFLOW MIGRATION SCRIPT: From Old Schema to New Improved Schema
-- Run this AFTER running improved_cashflow_schema.sql
-- ============================================================

-- Step 1: Backup message
DO $$
BEGIN
  RAISE NOTICE 'Starting Cashflow Database Migration...';
  RAISE NOTICE 'Make sure you have backed up your database before proceeding!';
END $$;

-- Step 2: Migrate profiles to cashflow_profiles
DO $$
BEGIN
  -- Check if old profiles table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles' AND table_schema = 'public') THEN
    
    -- Migrate profiles to cashflow_profiles
    INSERT INTO public.cashflow_profiles (id, email, full_name, avatar_url, created_at, updated_at)
    SELECT 
      id, 
      email, 
      full_name,
      avatar_url,
      created_at,
      updated_at
    FROM public.profiles
    ON CONFLICT (id) DO UPDATE SET
      email = EXCLUDED.email,
      full_name = EXCLUDED.full_name,
      avatar_url = EXCLUDED.avatar_url,
      updated_at = EXCLUDED.updated_at;

    RAISE NOTICE 'Profiles migrated to cashflow_profiles';
  END IF;
END $$;

-- Step 3: Migrate categories to cashflow_categories
DO $$
BEGIN
  -- Check if old categories table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'categories' AND table_schema = 'public') THEN
    
    -- Migrate categories to cashflow_categories
    INSERT INTO public.cashflow_categories 
    (id, user_id, name, type, color, icon, is_default, created_at, updated_at)
    SELECT 
      id,
      user_id,
      name,
      type,
      color,
      icon,
      is_default,
      created_at,
      updated_at
    FROM public.categories
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      type = EXCLUDED.type,
      color = EXCLUDED.color,
      icon = EXCLUDED.icon,
      is_default = EXCLUDED.is_default,
      updated_at = EXCLUDED.updated_at;

    RAISE NOTICE 'Categories migrated to cashflow_categories';
  END IF;
END $$;

-- Step 4: Migrate transactions to cashflow_transactions
DO $$
BEGIN
  -- Check if old transactions table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'transactions' AND table_schema = 'public') THEN
    
    -- Migrate transactions to cashflow_transactions
    INSERT INTO public.cashflow_transactions 
    (id, user_id, category_id, amount, description, notes, type, transaction_date, created_at, updated_at)
    SELECT 
      id,
      user_id,
      category_id,
      amount,
      description,
      notes,
      type,
      COALESCE(date, CURRENT_DATE) as transaction_date,
      created_at,
      updated_at
    FROM public.transactions
    ON CONFLICT (id) DO UPDATE SET
      category_id = EXCLUDED.category_id,
      amount = EXCLUDED.amount,
      description = EXCLUDED.description,
      notes = EXCLUDED.notes,
      type = EXCLUDED.type,
      transaction_date = EXCLUDED.transaction_date,
      updated_at = EXCLUDED.updated_at;

    RAISE NOTICE 'Transactions migrated to cashflow_transactions';
  END IF;
END $$;

-- Step 5: Migrate budgets to cashflow_budgets
DO $$
BEGIN
  -- Check if old budgets table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'budgets' AND table_schema = 'public') THEN
    
    -- Migrate budgets to cashflow_budgets
    INSERT INTO public.cashflow_budgets 
    (id, user_id, category_id, name, amount, period, start_date, end_date, is_active, created_at, updated_at)
    SELECT 
      id,
      user_id,
      category_id,
      name,
      amount,
      period,
      start_date,
      end_date,
      is_active,
      created_at,
      updated_at
    FROM public.budgets
    ON CONFLICT (id) DO UPDATE SET
      category_id = EXCLUDED.category_id,
      name = EXCLUDED.name,
      amount = EXCLUDED.amount,
      period = EXCLUDED.period,
      start_date = EXCLUDED.start_date,
      end_date = EXCLUDED.end_date,
      is_active = EXCLUDED.is_active,
      updated_at = EXCLUDED.updated_at;

    RAISE NOTICE 'Budgets migrated to cashflow_budgets';
  END IF;
END $$;

-- Step 6: Migrate goals to cashflow_goals
DO $$
BEGIN
  -- Check if old goals table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'goals' AND table_schema = 'public') THEN
    
    -- Migrate goals to cashflow_goals
    INSERT INTO public.cashflow_goals 
    (id, user_id, name, description, target_amount, current_amount, target_date, is_completed, created_at, updated_at)
    SELECT 
      id,
      user_id,
      name,
      description,
      target_amount,
      current_amount,
      target_date,
      is_completed,
      created_at,
      updated_at
    FROM public.goals
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      description = EXCLUDED.description,
      target_amount = EXCLUDED.target_amount,
      current_amount = EXCLUDED.current_amount,
      target_date = EXCLUDED.target_date,
      is_completed = EXCLUDED.is_completed,
      updated_at = EXCLUDED.updated_at;

    RAISE NOTICE 'Goals migrated to cashflow_goals';
  END IF;
END $$;

-- Step 7: Migrate expense_types to cashflow_expense_types
DO $$
BEGIN
  -- Check if old expense_types table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'expense_types' AND table_schema = 'public') THEN
    
    -- Migrate expense_types to cashflow_expense_types
    INSERT INTO public.cashflow_expense_types 
    (id, user_id, name, icon, color, created_at, updated_at)
    SELECT 
      id,
      user_id,
      name,
      icon,
      color,
      created_at,
      updated_at
    FROM public.expense_types
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      icon = EXCLUDED.icon,
      color = EXCLUDED.color,
      updated_at = EXCLUDED.updated_at;

    RAISE NOTICE 'Expense types migrated to cashflow_expense_types';
  END IF;
END $$;

-- Step 8: Migrate expense_items to cashflow_expense_items
DO $$
BEGIN
  -- Check if old expense_items table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'expense_items' AND table_schema = 'public') THEN
    
    -- Migrate expense_items to cashflow_expense_items
    INSERT INTO public.cashflow_expense_items 
    (id, expense_type_id, name, created_at, updated_at)
    SELECT 
      id,
      expense_type_id,
      name,
      created_at,
      updated_at
    FROM public.expense_items
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name,
      updated_at = EXCLUDED.updated_at;

    RAISE NOTICE 'Expense items migrated to cashflow_expense_items';
  END IF;
END $$;

-- Step 9: Update budget spent amounts based on transactions
DO $$
BEGIN
  UPDATE public.cashflow_budgets b
  SET spent_amount = COALESCE((
    SELECT SUM(t.amount)
    FROM public.cashflow_transactions t
    WHERE t.user_id = b.user_id
    AND t.type = 'expense'
    AND t.category_id = b.category_id
    AND t.transaction_date BETWEEN b.start_date AND b.end_date
  ), 0);
  
  RAISE NOTICE 'Updated budget spent amounts based on transactions';
END $$;

-- Step 10: Create admin app users entries if admin system exists
DO $$
DECLARE
  user_record RECORD;
BEGIN
  -- Check if admin_app_users table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_app_users' AND table_schema = 'public') THEN
    
    -- Insert all cashflow users into admin_app_users
    FOR user_record IN 
      SELECT DISTINCT id, email, full_name 
      FROM public.cashflow_profiles
    LOOP
      INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status)
      VALUES (user_record.id, 'cashflow', user_record.email, user_record.full_name, 'user', 'active')
      ON CONFLICT (user_id, app_name) DO UPDATE SET
        email = EXCLUDED.email,
        name = EXCLUDED.name,
        updated_at = NOW();
    END LOOP;
    
    RAISE NOTICE 'Created admin_app_users entries for cashflow users';
  ELSE
    RAISE NOTICE 'admin_app_users table not found - skipping admin integration';
  END IF;
END $$;

-- Step 11: Ensure cashflow app is registered in applications table
DO $$
BEGIN
  -- Check if applications table exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'applications' AND table_schema = 'public') THEN
    
    INSERT INTO public.applications (name, display_name, description, is_active) 
    VALUES ('cashflow', 'Cashflow Manager', 'Personal finance and cashflow management application', true)
    ON CONFLICT (name) DO UPDATE SET
      display_name = EXCLUDED.display_name,
      description = EXCLUDED.description,
      is_active = EXCLUDED.is_active,
      updated_at = NOW();
    
    RAISE NOTICE 'Cashflow app registered in applications table';
  ELSE
    RAISE NOTICE 'applications table not found - skipping app registration';
  END IF;
END $$;

-- Step 12: Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_migration_cashflow_profiles_email ON public.cashflow_profiles(email);
CREATE INDEX IF NOT EXISTS idx_migration_cashflow_transactions_user_date ON public.cashflow_transactions(user_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_migration_cashflow_categories_user_type ON public.cashflow_categories(user_id, type);

-- Step 13: Verify migration counts
DO $$
DECLARE
  old_profiles_count INTEGER := 0;
  new_profiles_count INTEGER := 0;
  old_transactions_count INTEGER := 0;
  new_transactions_count INTEGER := 0;
  old_categories_count INTEGER := 0;
  new_categories_count INTEGER := 0;
BEGIN
  -- Count old vs new records
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles' AND table_schema = 'public') THEN
    SELECT COUNT(*) INTO old_profiles_count FROM public.profiles;
  END IF;
  
  SELECT COUNT(*) INTO new_profiles_count FROM public.cashflow_profiles;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'transactions' AND table_schema = 'public') THEN
    SELECT COUNT(*) INTO old_transactions_count FROM public.transactions;
  END IF;
  
  SELECT COUNT(*) INTO new_transactions_count FROM public.cashflow_transactions;
  
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'categories' AND table_schema = 'public') THEN
    SELECT COUNT(*) INTO old_categories_count FROM public.categories;
  END IF;
  
  SELECT COUNT(*) INTO new_categories_count FROM public.cashflow_categories;
  
  RAISE NOTICE 'Cashflow Migration Summary:';
  RAISE NOTICE 'Profiles: % old -> % new cashflow_profiles', old_profiles_count, new_profiles_count;
  RAISE NOTICE 'Transactions: % old -> % new cashflow_transactions', old_transactions_count, new_transactions_count;
  RAISE NOTICE 'Categories: % old -> % new cashflow_categories', old_categories_count, new_categories_count;
END $$;

-- Step 14: Optional - Drop old tables (UNCOMMENT ONLY AFTER VERIFYING MIGRATION)
-- WARNING: This will permanently delete the old tables. Make sure migration is successful first!

/*
DO $$
BEGIN
  -- Drop old tables only if new tables have data
  IF (SELECT COUNT(*) FROM public.cashflow_profiles) > 0 THEN
    DROP TABLE IF EXISTS public.expense_items CASCADE;
    DROP TABLE IF EXISTS public.expense_types CASCADE;
    DROP TABLE IF EXISTS public.goals CASCADE;
    DROP TABLE IF EXISTS public.budgets CASCADE;
    DROP TABLE IF EXISTS public.transactions CASCADE;
    DROP TABLE IF EXISTS public.categories CASCADE;
    DROP TABLE IF EXISTS public.profiles CASCADE;
    
    RAISE NOTICE 'Old cashflow tables dropped successfully';
  ELSE
    RAISE NOTICE 'Migration not complete - old tables preserved';
  END IF;
END $$;
*/

RAISE NOTICE 'Cashflow migration completed successfully!';
RAISE NOTICE 'Please verify your data and then uncomment the drop table section if needed.';
RAISE NOTICE 'Update your cashflow application to use the new table names.';
