-- ============================================================
-- CASHFLOW APP - MIGRATION TO ADMIN COMPATIBLE SCHEMA
-- This script migrates existing cashflow data to new prefixed tables
-- Compatible with multi-app admin system
-- ============================================================

-- Start transaction
BEGIN;

-- ============================================================
-- 1. CREATE BACKUP TABLES (Optional - for safety)
-- ============================================================
/*
CREATE TABLE IF NOT EXISTS backup_profiles AS SELECT * FROM profiles;
CREATE TABLE IF NOT EXISTS backup_categories AS SELECT * FROM categories;
CREATE TABLE IF NOT EXISTS backup_transactions AS SELECT * FROM transactions;
CREATE TABLE IF NOT EXISTS backup_budgets AS SELECT * FROM budgets;
CREATE TABLE IF NOT EXISTS backup_goals AS SELECT * FROM goals;
CREATE TABLE IF NOT EXISTS backup_expense_types AS SELECT * FROM expense_types;
CREATE TABLE IF NOT EXISTS backup_expense_items AS SELECT * FROM expense_items;
*/

-- ============================================================
-- 2. DISABLE RLS TEMPORARILY FOR MIGRATION
-- ============================================================
ALTER TABLE IF EXISTS profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS transactions DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS budgets DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS goals DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS expense_types DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS expense_items DISABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. MIGRATE DATA FROM OLD TABLES TO NEW TABLES
-- ============================================================

-- Migrate profiles to cashflow_profiles
INSERT INTO public.cashflow_profiles (
    id, email, full_name, avatar_url, 
    default_currency, timezone, settings, is_active,
    created_at, updated_at
)
SELECT 
    id, email, full_name, avatar_url,
    'USD' as default_currency,
    'UTC' as timezone,
    '{}' as settings,
    true as is_active,
    created_at, updated_at
FROM profiles
ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    avatar_url = EXCLUDED.avatar_url,
    updated_at = EXCLUDED.updated_at;

-- Migrate categories to cashflow_categories
INSERT INTO public.cashflow_categories (
    id, user_id, name, type, color, icon, 
    description, is_default, is_active, sort_order,
    created_at, updated_at
)
SELECT 
    id, user_id, name, type, 
    COALESCE(color, '#6c757d') as color,
    COALESCE(icon, 'bi-circle') as icon,
    null as description,
    COALESCE(is_default, false) as is_default,
    true as is_active,
    0 as sort_order,
    created_at, updated_at
FROM categories
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    type = EXCLUDED.type,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    updated_at = EXCLUDED.updated_at;

-- Migrate transactions to cashflow_transactions
INSERT INTO public.cashflow_transactions (
    id, user_id, category_id, amount, description, notes, type,
    transaction_date, recurring_type, recurring_end_date,
    attachment_url, tags, created_at, updated_at
)
SELECT 
    id, user_id, category_id, amount, description,
    COALESCE(notes, '') as notes,
    type,
    COALESCE(date, CURRENT_DATE) as transaction_date,
    'none' as recurring_type,
    null as recurring_end_date,
    null as attachment_url,
    '{}' as tags,
    created_at, updated_at
FROM transactions
ON CONFLICT (id) DO UPDATE SET
    amount = EXCLUDED.amount,
    description = EXCLUDED.description,
    notes = EXCLUDED.notes,
    transaction_date = EXCLUDED.transaction_date,
    updated_at = EXCLUDED.updated_at;

-- Migrate budgets to cashflow_budgets
INSERT INTO public.cashflow_budgets (
    id, user_id, category_id, name, amount, spent_amount, period,
    start_date, end_date, is_active, alert_percentage,
    created_at, updated_at
)
SELECT 
    id, user_id, category_id, name, amount,
    0 as spent_amount, -- Will be calculated
    period, start_date, end_date,
    COALESCE(is_active, true) as is_active,
    80 as alert_percentage,
    created_at, updated_at
FROM budgets
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    amount = EXCLUDED.amount,
    period = EXCLUDED.period,
    start_date = EXCLUDED.start_date,
    end_date = EXCLUDED.end_date,
    is_active = EXCLUDED.is_active,
    updated_at = EXCLUDED.updated_at;

-- Migrate goals to cashflow_goals
INSERT INTO public.cashflow_goals (
    id, user_id, name, description, target_amount, current_amount,
    target_date, priority, is_completed, is_active,
    created_at, updated_at
)
SELECT 
    id, user_id, name, description, target_amount, current_amount,
    target_date,
    1 as priority,
    COALESCE(is_completed, false) as is_completed,
    true as is_active,
    created_at, updated_at
FROM goals
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    target_amount = EXCLUDED.target_amount,
    current_amount = EXCLUDED.current_amount,
    target_date = EXCLUDED.target_date,
    is_completed = EXCLUDED.is_completed,
    updated_at = EXCLUDED.updated_at;

-- Migrate expense_types to cashflow_expense_types
INSERT INTO public.cashflow_expense_types (
    id, user_id, name, icon, color, description, is_active,
    created_at, updated_at
)
SELECT 
    id, user_id, name,
    COALESCE(icon, 'bi-circle') as icon,
    COALESCE(color, '#6c757d') as color,
    null as description,
    true as is_active,
    created_at, updated_at
FROM expense_types
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    icon = EXCLUDED.icon,
    color = EXCLUDED.color,
    updated_at = EXCLUDED.updated_at;

-- Migrate expense_items to cashflow_expense_items
INSERT INTO public.cashflow_expense_items (
    id, expense_type_id, name, estimated_cost, is_active,
    created_at, updated_at
)
SELECT 
    id, expense_type_id, name,
    null as estimated_cost,
    true as is_active,
    created_at, updated_at
FROM expense_items
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    updated_at = EXCLUDED.updated_at;

-- ============================================================
-- 4. UPDATE BUDGET SPENT AMOUNTS (CALCULATE FROM TRANSACTIONS)
-- ============================================================
UPDATE public.cashflow_budgets 
SET spent_amount = (
    SELECT COALESCE(SUM(t.amount), 0)
    FROM public.cashflow_transactions t
    WHERE t.category_id = cashflow_budgets.category_id
      AND t.user_id = cashflow_budgets.user_id
      AND t.type = 'expense'
      AND t.transaction_date BETWEEN cashflow_budgets.start_date AND cashflow_budgets.end_date
);

-- ============================================================
-- 5. CREATE ADMIN APP ENTRIES (IF ADMIN SYSTEM EXISTS)
-- ============================================================

-- Add cashflow app to admin_apps table (if exists)
INSERT INTO public.admin_apps (name, description, database_prefix, is_active)
VALUES ('Cashflow Manager', 'Personal finance and expense tracking application', 'cashflow_', true)
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    database_prefix = EXCLUDED.database_prefix,
    is_active = EXCLUDED.is_active;

-- Register existing users with admin system (if admin tables exist)
DO $$
DECLARE
    app_id UUID;
BEGIN
    -- Get cashflow app ID
    SELECT id INTO app_id FROM public.admin_apps WHERE name = 'Cashflow Manager';
    
    IF app_id IS NOT NULL THEN
        -- Register all cashflow users
        INSERT INTO public.admin_app_users (user_id, app_id, role, is_active, permissions)
        SELECT 
            p.id as user_id,
            app_id,
            'user' as role,
            p.is_active,
            '["read", "write", "delete"]'::jsonb as permissions
        FROM public.cashflow_profiles p
        ON CONFLICT (user_id, app_id) DO UPDATE SET
            is_active = EXCLUDED.is_active,
            updated_at = NOW();
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'Admin tables not found, skipping admin registration';
END $$;

-- ============================================================
-- 6. VERIFY MIGRATION
-- ============================================================

-- Display migration summary
DO $$
DECLARE
    old_profiles_count INTEGER;
    new_profiles_count INTEGER;
    old_transactions_count INTEGER;
    new_transactions_count INTEGER;
BEGIN
    -- Count old and new records
    SELECT COUNT(*) INTO old_profiles_count FROM profiles;
    SELECT COUNT(*) INTO new_profiles_count FROM public.cashflow_profiles;
    SELECT COUNT(*) INTO old_transactions_count FROM transactions;
    SELECT COUNT(*) INTO new_transactions_count FROM public.cashflow_transactions;
    
    RAISE NOTICE 'MIGRATION SUMMARY:';
    RAISE NOTICE 'Profiles: % -> %', old_profiles_count, new_profiles_count;
    RAISE NOTICE 'Transactions: % -> %', old_transactions_count, new_transactions_count;
    
    IF old_profiles_count = new_profiles_count AND old_transactions_count = new_transactions_count THEN
        RAISE NOTICE 'Migration appears successful!';
    ELSE
        RAISE WARNING 'Migration may have issues - counts do not match!';
    END IF;
END $$;

-- Commit transaction
COMMIT;

-- ============================================================
-- POST-MIGRATION NOTES
-- ============================================================

/*
IMPORTANT NOTES AFTER RUNNING THIS MIGRATION:

1. Update your application code to use new table names:
   - profiles -> cashflow_profiles
   - categories -> cashflow_categories
   - transactions -> cashflow_transactions
   - budgets -> cashflow_budgets
   - goals -> cashflow_goals
   - expense_types -> cashflow_expense_types
   - expense_items -> cashflow_expense_items

2. Update your Supabase service functions to use new table names

3. Test all application functionality thoroughly

4. If using the admin system, verify users appear in admin dashboard

5. Consider creating new indexes if you have performance issues

6. Update any direct SQL queries in your application

7. Run ANALYZE on new tables for better query performance:
   ANALYZE public.cashflow_profiles;
   ANALYZE public.cashflow_categories;
   ANALYZE public.cashflow_transactions;
   ANALYZE public.cashflow_budgets;
   ANALYZE public.cashflow_goals;
   ANALYZE public.cashflow_expense_types;
   ANALYZE public.cashflow_expense_items;

8. Monitor for any RLS policy issues and adjust as needed
*/
