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
