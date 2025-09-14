-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create categories table
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    color TEXT DEFAULT '#6c757d',
    icon TEXT DEFAULT 'bi-circle',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, name, type)
);

-- Create transactions table
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    description TEXT NOT NULL,
    notes TEXT,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create budgets table
CREATE TABLE IF NOT EXISTS public.budgets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    category_id UUID REFERENCES public.categories(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    period TEXT NOT NULL CHECK (period IN ('weekly', 'monthly', 'yearly')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create goals table
CREATE TABLE IF NOT EXISTS public.goals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    target_amount DECIMAL(15,2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(15,2) DEFAULT 0 CHECK (current_amount >= 0),
    target_date DATE,
    is_completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create expense_types table (NEW)
CREATE TABLE IF NOT EXISTS public.expense_types (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    icon TEXT DEFAULT 'bi-circle',
    color TEXT DEFAULT '#6c757d',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- Create expense_items table (NEW)
CREATE TABLE IF NOT EXISTS public.expense_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    expense_type_id UUID REFERENCES public.expense_types(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(expense_type_id, name)
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_items ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies
-- Profiles policies
CREATE POLICY "Users can view own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Categories policies
CREATE POLICY "Users can view own categories" ON public.categories
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own categories" ON public.categories
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own categories" ON public.categories
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own categories" ON public.categories
    FOR DELETE USING (auth.uid() = user_id);

-- Transactions policies
CREATE POLICY "Users can view own transactions" ON public.transactions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions" ON public.transactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transactions" ON public.transactions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own transactions" ON public.transactions
    FOR DELETE USING (auth.uid() = user_id);

-- Budgets policies
CREATE POLICY "Users can view own budgets" ON public.budgets
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own budgets" ON public.budgets
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own budgets" ON public.budgets
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own budgets" ON public.budgets
    FOR DELETE USING (auth.uid() = user_id);

-- Goals policies
CREATE POLICY "Users can view own goals" ON public.goals
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own goals" ON public.goals
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own goals" ON public.goals
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own goals" ON public.goals
    FOR DELETE USING (auth.uid() = user_id);

-- Expense Types policies (NEW)
CREATE POLICY "Users can view own expense types" ON public.expense_types
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own expense types" ON public.expense_types
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own expense types" ON public.expense_types
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own expense types" ON public.expense_types
    FOR DELETE USING (auth.uid() = user_id);

-- Expense Items policies (NEW)
CREATE POLICY "Users can view own expense items" ON public.expense_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.expense_types 
            WHERE expense_types.id = expense_items.expense_type_id 
            AND expense_types.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own expense items" ON public.expense_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.expense_types 
            WHERE expense_types.id = expense_items.expense_type_id 
            AND expense_types.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own expense items" ON public.expense_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.expense_types 
            WHERE expense_types.id = expense_items.expense_type_id 
            AND expense_types.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own expense items" ON public.expense_items
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.expense_types 
            WHERE expense_types.id = expense_items.expense_type_id 
            AND expense_types.user_id = auth.uid()
        )
    );

-- Create functions and triggers for updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.transactions
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.budgets
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.goals
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.expense_types
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.expense_items
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Function to create default categories for new users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert profile
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
    
    -- Insert default income categories
    INSERT INTO public.categories (user_id, name, type, color, icon, is_default) VALUES
    (NEW.id, 'Salary', 'income', '#28a745', 'bi-cash-coin', true),
    (NEW.id, 'Freelance', 'income', '#17a2b8', 'bi-laptop', true),
    (NEW.id, 'Business', 'income', '#6f42c1', 'bi-briefcase', true),
    (NEW.id, 'Investment', 'income', '#fd7e14', 'bi-graph-up', true),
    (NEW.id, 'Other Income', 'income', '#6c757d', 'bi-plus-circle', true);
    
    -- Insert default expense categories
    INSERT INTO public.categories (user_id, name, type, color, icon, is_default) VALUES
    (NEW.id, 'Food & Dining', 'expense', '#dc3545', 'bi-cart3', true),
    (NEW.id, 'Transportation', 'expense', '#ffc107', 'bi-fuel-pump', true),
    (NEW.id, 'Shopping', 'expense', '#e83e8c', 'bi-bag', true),
    (NEW.id, 'Entertainment', 'expense', '#6f42c1', 'bi-film', true),
    (NEW.id, 'Bills & Utilities', 'expense', '#fd7e14', 'bi-receipt', true),
    (NEW.id, 'Healthcare', 'expense', '#20c997', 'bi-heart-pulse', true),
    (NEW.id, 'Education', 'expense', '#0dcaf0', 'bi-book', true),
    (NEW.id, 'Other Expense', 'expense', '#6c757d', 'bi-circle', true);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user registration
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
SELECT user_id, name, type, color, icon, is_default
FROM public.categories
WHERE user_id = '201912e3-0cb0-425c-9982-97da15b18db0'
ORDER BY type, name;

-- Create expense_types table
CREATE TABLE public.expense_types (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    icon TEXT DEFAULT 'bi-circle',
    color TEXT DEFAULT '#6c757d',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- Create expense_items table
CREATE TABLE public.expense_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    expense_type_id UUID REFERENCES public.expense_types(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(expense_type_id, name)
);

-- Enable Row Level Security
ALTER TABLE public.expense_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_items ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies for expense_types
CREATE POLICY "Users can view own expense types" ON public.expense_types
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own expense types" ON public.expense_types
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own expense types" ON public.expense_types
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own expense types" ON public.expense_types
    FOR DELETE USING (auth.uid() = user_id);

-- Create RLS Policies for expense_items
CREATE POLICY "Users can view own expense items" ON public.expense_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.expense_types 
            WHERE expense_types.id = expense_items.expense_type_id 
            AND expense_types.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can insert own expense items" ON public.expense_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.expense_types 
            WHERE expense_types.id = expense_items.expense_type_id 
            AND expense_types.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own expense items" ON public.expense_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.expense_types 
            WHERE expense_types.id = expense_items.expense_type_id 
            AND expense_types.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own expense items" ON public.expense_items
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.expense_types 
            WHERE expense_types.id = expense_items.expense_type_id 
            AND expense_types.user_id = auth.uid()
        )
    );

-- Create function for updated_at trigger (if not exists)
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.expense_types
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.expense_items
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================
-- IMPROVED MULTI-APP DATABASE SCHEMA
-- Struktur yang dipisahkan per aplikasi dengan naming convention yang jelas
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- CORE TABLES (Shared across all applications)
-- ============================================================

-- Core applications registry
CREATE TABLE IF NOT EXISTS public.applications (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  display_name VARCHAR(200),
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add display_name column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'applications' 
    AND column_name = 'display_name' 
    AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.applications ADD COLUMN display_name VARCHAR(200);
  END IF;
END $$;

-- Core user profiles (admin system)
CREATE TABLE IF NOT EXISTS public.admin_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'super_admin')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Core licenses table (for all applications)
CREATE TABLE IF NOT EXISTS public.admin_licenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  license_code VARCHAR(255) NOT NULL UNIQUE,
  app_name VARCHAR(100) NOT NULL REFERENCES public.applications(name) ON DELETE CASCADE,
  is_used BOOLEAN NOT NULL DEFAULT FALSE,
  used_by UUID REFERENCES public.admin_profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  used_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
);

-- Core application users (users per application)
CREATE TABLE IF NOT EXISTS public.admin_app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  app_name VARCHAR(100) NOT NULL REFERENCES public.applications(name) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  role VARCHAR(50) NOT NULL DEFAULT 'user',
  status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'banned')),
  license_id UUID REFERENCES public.admin_licenses(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, app_name)
);

-- ============================================================
-- PRODUCTIVITY APP SPECIFIC TABLES
-- ============================================================

-- Productivity users (extends admin_app_users)
CREATE TABLE IF NOT EXISTS public.productivity_users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  total_score INTEGER NOT NULL DEFAULT 0,
  current_streak INTEGER NOT NULL DEFAULT 0,
  longest_streak INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Daily task templates for productivity app
CREATE TABLE IF NOT EXISTS public.productivity_task_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.productivity_users(id) ON DELETE CASCADE,
  task_name TEXT NOT NULL,
  description TEXT,
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('high', 'medium', 'low')),
  category TEXT,
  task_type TEXT NOT NULL DEFAULT 'daily' CHECK (task_type IN ('daily', 'deadline')),
  default_deadline_days INTEGER,
  score_value INTEGER NOT NULL DEFAULT 10,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Daily task instances for productivity app
CREATE TABLE IF NOT EXISTS public.productivity_task_instances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.productivity_users(id) ON DELETE CASCADE,
  template_id UUID REFERENCES public.productivity_task_templates(id) ON DELETE SET NULL,
  task_name TEXT NOT NULL,
  description TEXT,
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('high', 'medium', 'low')),
  category TEXT,
  task_type TEXT NOT NULL DEFAULT 'daily' CHECK (task_type IN ('daily', 'deadline')),
  task_date DATE NOT NULL,
  deadline_date DATE,
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  completed_at TIMESTAMPTZ,
  score_earned INTEGER DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Score history for productivity app
CREATE TABLE IF NOT EXISTS public.productivity_score_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.productivity_users(id) ON DELETE CASCADE,
  task_instance_id UUID REFERENCES public.productivity_task_instances(id) ON DELETE SET NULL,
  score_delta INTEGER NOT NULL,
  reason TEXT NOT NULL,
  log_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- CASHFLOW APP SPECIFIC TABLES (Example for second app)
-- ============================================================

-- Cashflow users
CREATE TABLE IF NOT EXISTS public.cashflow_users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  default_currency VARCHAR(3) NOT NULL DEFAULT 'USD',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cashflow categories
CREATE TABLE IF NOT EXISTS public.cashflow_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.cashflow_users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('income', 'expense')),
  color VARCHAR(7) DEFAULT '#000000',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Cashflow transactions
CREATE TABLE IF NOT EXISTS public.cashflow_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.cashflow_users(id) ON DELETE CASCADE,
  category_id UUID REFERENCES public.cashflow_categories(id) ON DELETE SET NULL,
  amount DECIMAL(15,2) NOT NULL,
  description TEXT NOT NULL,
  transaction_date DATE NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('income', 'expense')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

-- Core indexes
CREATE INDEX IF NOT EXISTS idx_admin_profiles_email ON public.admin_profiles(email);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_role ON public.admin_profiles(role);
CREATE INDEX IF NOT EXISTS idx_admin_licenses_app_name ON public.admin_licenses(app_name);
CREATE INDEX IF NOT EXISTS idx_admin_licenses_is_used ON public.admin_licenses(is_used);
CREATE INDEX IF NOT EXISTS idx_admin_app_users_app_name ON public.admin_app_users(app_name);
CREATE INDEX IF NOT EXISTS idx_admin_app_users_status ON public.admin_app_users(status);

-- Productivity indexes
CREATE INDEX IF NOT EXISTS idx_productivity_task_templates_user_id ON public.productivity_task_templates(user_id);
CREATE INDEX IF NOT EXISTS idx_productivity_task_instances_user_date ON public.productivity_task_instances(user_id, task_date);
CREATE INDEX IF NOT EXISTS idx_productivity_task_instances_completed ON public.productivity_task_instances(is_completed);
CREATE INDEX IF NOT EXISTS idx_productivity_score_logs_user_date ON public.productivity_score_logs(user_id, log_date);

-- Cashflow indexes
CREATE INDEX IF NOT EXISTS idx_cashflow_transactions_user_date ON public.cashflow_transactions(user_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_cashflow_transactions_category ON public.cashflow_transactions(category_id);

-- ============================================================
-- TRIGGERS & FUNCTIONS
-- ============================================================

-- Update timestamp function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers
CREATE TRIGGER trg_admin_profiles_updated_at BEFORE UPDATE ON public.admin_profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_admin_app_users_updated_at BEFORE UPDATE ON public.admin_app_users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_productivity_users_updated_at BEFORE UPDATE ON public.productivity_users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_productivity_task_templates_updated_at BEFORE UPDATE ON public.productivity_task_templates FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_productivity_task_instances_updated_at BEFORE UPDATE ON public.productivity_task_instances FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_cashflow_users_updated_at BEFORE UPDATE ON public.cashflow_users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trg_cashflow_transactions_updated_at BEFORE UPDATE ON public.cashflow_transactions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Auto-create admin profile on auth user creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.admin_profiles (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Helper function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.admin_profiles
    WHERE id = auth.uid()
      AND role IN ('admin', 'super_admin')
      AND is_active = TRUE
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_admin() TO PUBLIC;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productivity_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productivity_task_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productivity_task_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productivity_score_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_transactions ENABLE ROW LEVEL SECURITY;

-- Applications policies (readable by authenticated users)
CREATE POLICY "Applications readable by authenticated users" ON public.applications
  FOR SELECT USING (auth.role() = 'authenticated');

-- Admin profiles policies
CREATE POLICY "Admin profiles self access" ON public.admin_profiles
  FOR ALL USING (id = auth.uid());

CREATE POLICY "Admin profiles admin access" ON public.admin_profiles
  FOR ALL USING (public.is_admin());

-- Admin licenses policies (admin only)
CREATE POLICY "Admin licenses admin access" ON public.admin_licenses
  FOR ALL USING (public.is_admin());

-- Admin app users policies (admin only)
CREATE POLICY "Admin app users admin access" ON public.admin_app_users
  FOR ALL USING (public.is_admin());

-- Productivity app policies
CREATE POLICY "Productivity users self access" ON public.productivity_users
  FOR ALL USING (id = auth.uid());

CREATE POLICY "Productivity users admin access" ON public.productivity_users
  FOR ALL USING (public.is_admin());

CREATE POLICY "Productivity task templates self access" ON public.productivity_task_templates
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Productivity task instances self access" ON public.productivity_task_instances
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Productivity score logs self access" ON public.productivity_score_logs
  FOR ALL USING (user_id = auth.uid());

-- Cashflow app policies
CREATE POLICY "Cashflow users self access" ON public.cashflow_users
  FOR ALL USING (id = auth.uid());

CREATE POLICY "Cashflow users admin access" ON public.cashflow_users
  FOR ALL USING (public.is_admin());

CREATE POLICY "Cashflow categories self access" ON public.cashflow_categories
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Cashflow transactions self access" ON public.cashflow_transactions
  FOR ALL USING (user_id = auth.uid());

-- ============================================================
-- INITIAL DATA
-- ============================================================

-- Insert default applications (simplified - only required columns)
INSERT INTO public.applications (name, description) VALUES 
('productivity', 'Task and productivity management application'),
('cashflow', 'Personal finance and cashflow management application')
ON CONFLICT (name) DO UPDATE SET
  description = COALESCE(EXCLUDED.description, public.applications.description),
  updated_at = NOW();

-- Add display_name values if column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'applications' 
    AND column_name = 'display_name' 
    AND table_schema = 'public'
  ) THEN
    UPDATE public.applications 
    SET display_name = CASE 
      WHEN name = 'productivity' THEN 'Productivity Manager'
      WHEN name = 'cashflow' THEN 'Cashflow Manager'
      ELSE INITCAP(name) || ' Manager'
    END
    WHERE display_name IS NULL;
  END IF;
END $$;

-- Set admin user (replace with your email)
UPDATE public.admin_profiles 
SET role = 'admin', is_active = TRUE 
WHERE email = 'fattahula98@gmail.com';

-- ============================================================
-- MIGRATION FUNCTIONS
-- ============================================================

-- Function to migrate existing data (run manually if needed)
CREATE OR REPLACE FUNCTION public.migrate_existing_data()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  migration_log TEXT := '';
BEGIN
  -- Migrate existing users table to productivity_users if exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users' AND table_schema = 'public') THEN
    INSERT INTO public.productivity_users (id, email, created_at)
    SELECT id, email, created_at 
    FROM public.users
    ON CONFLICT (id) DO NOTHING;
    migration_log := migration_log || 'Migrated users to productivity_users. ';
  END IF;

  -- Migrate existing daily_tasks_template to productivity_task_templates if exists
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'daily_tasks_template' AND table_schema = 'public') THEN
    INSERT INTO public.productivity_task_templates (id, user_id, task_name, priority, category, task_type, created_at)
    SELECT id, user_id, task_name, 
           CASE priority 
             WHEN 'tinggi' THEN 'high'
             WHEN 'sedang' THEN 'medium'
             WHEN 'rendah' THEN 'low'
             ELSE 'medium'
           END,
           category,
           CASE jenis_task 
             WHEN 'harian' THEN 'daily'
             WHEN 'deadline' THEN 'deadline'
             ELSE 'daily'
           END,
           created_at
    FROM public.daily_tasks_template
    ON CONFLICT (id) DO NOTHING;
    migration_log := migration_log || 'Migrated daily_tasks_template to productivity_task_templates. ';
  END IF;

  RETURN 'Migration completed: ' || migration_log;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.migrate_existing_data() TO authenticated;

-- ============================================================
-- CLEANUP COMMENTS
-- ============================================================

COMMENT ON TABLE public.applications IS 'Registry of all applications in the system';
COMMENT ON TABLE public.admin_profiles IS 'Admin system user profiles';
COMMENT ON TABLE public.admin_licenses IS 'Application licenses managed by admin';
COMMENT ON TABLE public.admin_app_users IS 'Users registered for specific applications';
COMMENT ON TABLE public.productivity_users IS 'Productivity app specific user data';
COMMENT ON TABLE public.productivity_task_templates IS 'Template tasks for productivity app';
COMMENT ON TABLE public.productivity_task_instances IS 'Daily task instances for productivity app';
COMMENT ON TABLE public.productivity_score_logs IS 'Score tracking for productivity app';
COMMENT ON TABLE public.cashflow_users IS 'Cashflow app specific user data';
COMMENT ON TABLE public.cashflow_categories IS 'Income/expense categories for cashflow app';
COMMENT ON TABLE public.cashflow_transactions IS 'Financial transactions for cashflow app';

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

-- ============================================================
-- FIX APPLICATIONS TABLE: Ensure proper structure exists
-- Run this to fix the applications table structure issues
-- ============================================================

-- Create applications table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.applications (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  display_name VARCHAR(200),
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add missing columns if they don't exist
DO $$ 
BEGIN
  -- Add display_name column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'applications' 
    AND column_name = 'display_name' 
    AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.applications ADD COLUMN display_name VARCHAR(200);
  END IF;

  -- Add is_active column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'applications' 
    AND column_name = 'is_active' 
    AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.applications ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
  END IF;

  -- Add description column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'applications' 
    AND column_name = 'description' 
    AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.applications ADD COLUMN description TEXT;
  END IF;

  -- Add timestamps if they don't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'applications' 
    AND column_name = 'created_at' 
    AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.applications ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'applications' 
    AND column_name = 'updated_at' 
    AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.applications ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
  END IF;
END $$;

-- Insert default applications if they don't exist
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

-- Display current applications
SELECT 
  id,
  name,
  display_name,
  description,
  is_active,
  created_at
FROM public.applications
ORDER BY name;

-- Display success message
DO $$
BEGIN
  RAISE NOTICE 'Applications table structure fixed and default data inserted.';
END $$;


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
