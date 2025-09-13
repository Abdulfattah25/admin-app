-- ============================================================
-- CASHFLOW APP - IMPROVED SCHEMA WITH ADMIN COMPATIBILITY
-- Compatible with multi-app admin system
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- CASHFLOW-SPECIFIC TABLES (with proper prefixes)
-- ============================================================

-- Cashflow user profiles (app-specific user data)
CREATE TABLE IF NOT EXISTS public.cashflow_profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    default_currency VARCHAR(3) DEFAULT 'USD',
    timezone TEXT DEFAULT 'UTC',
    settings JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cashflow categories for income/expense classification
CREATE TABLE IF NOT EXISTS public.cashflow_categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    color TEXT DEFAULT '#6c757d',
    icon TEXT DEFAULT 'bi-circle',
    description TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, name, type)
);

-- Cashflow transactions (main financial records)
CREATE TABLE IF NOT EXISTS public.cashflow_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    category_id UUID REFERENCES public.cashflow_categories(id) ON DELETE SET NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    description TEXT NOT NULL,
    notes TEXT,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
    recurring_type TEXT CHECK (recurring_type IN ('none', 'daily', 'weekly', 'monthly', 'yearly')) DEFAULT 'none',
    recurring_end_date DATE,
    attachment_url TEXT,
    tags TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cashflow budgets for expense planning
CREATE TABLE IF NOT EXISTS public.cashflow_budgets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    category_id UUID REFERENCES public.cashflow_categories(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    spent_amount DECIMAL(15,2) DEFAULT 0 CHECK (spent_amount >= 0),
    period TEXT NOT NULL CHECK (period IN ('weekly', 'monthly', 'yearly')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    alert_percentage INTEGER DEFAULT 80 CHECK (alert_percentage BETWEEN 1 AND 100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cashflow savings goals
CREATE TABLE IF NOT EXISTS public.cashflow_goals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    target_amount DECIMAL(15,2) NOT NULL CHECK (target_amount > 0),
    current_amount DECIMAL(15,2) DEFAULT 0 CHECK (current_amount >= 0),
    target_date DATE,
    priority INTEGER DEFAULT 1 CHECK (priority BETWEEN 1 AND 5),
    is_completed BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cashflow accounts (bank accounts, wallets, etc.)
CREATE TABLE IF NOT EXISTS public.cashflow_accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('bank', 'cash', 'credit_card', 'investment', 'other')),
    balance DECIMAL(15,2) DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    account_number TEXT,
    bank_name TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- Cashflow expense types for detailed categorization
CREATE TABLE IF NOT EXISTS public.cashflow_expense_types (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    icon TEXT DEFAULT 'bi-circle',
    color TEXT DEFAULT '#6c757d',
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, name)
);

-- Cashflow expense items (sub-categories)
CREATE TABLE IF NOT EXISTS public.cashflow_expense_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    expense_type_id UUID REFERENCES public.cashflow_expense_types(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    estimated_cost DECIMAL(15,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(expense_type_id, name)
);

-- Cashflow recurring transactions
CREATE TABLE IF NOT EXISTS public.cashflow_recurring_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    category_id UUID REFERENCES public.cashflow_categories(id) ON DELETE SET NULL,
    account_id UUID REFERENCES public.cashflow_accounts(id) ON DELETE SET NULL,
    amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
    description TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
    next_date DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    last_executed_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cashflow financial reports/snapshots
CREATE TABLE IF NOT EXISTS public.cashflow_reports (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    report_type TEXT NOT NULL CHECK (report_type IN ('monthly', 'yearly', 'custom')),
    report_date DATE NOT NULL,
    total_income DECIMAL(15,2) DEFAULT 0,
    total_expense DECIMAL(15,2) DEFAULT 0,
    net_income DECIMAL(15,2) DEFAULT 0,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================

-- Cashflow profiles indexes
CREATE INDEX IF NOT EXISTS idx_cashflow_profiles_email ON public.cashflow_profiles(email);
CREATE INDEX IF NOT EXISTS idx_cashflow_profiles_active ON public.cashflow_profiles(is_active);

-- Cashflow categories indexes
CREATE INDEX IF NOT EXISTS idx_cashflow_categories_user_type ON public.cashflow_categories(user_id, type);
CREATE INDEX IF NOT EXISTS idx_cashflow_categories_active ON public.cashflow_categories(is_active);

-- Cashflow transactions indexes
CREATE INDEX IF NOT EXISTS idx_cashflow_transactions_user_date ON public.cashflow_transactions(user_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_cashflow_transactions_category ON public.cashflow_transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_cashflow_transactions_type ON public.cashflow_transactions(type);
CREATE INDEX IF NOT EXISTS idx_cashflow_transactions_date_range ON public.cashflow_transactions(transaction_date);

-- Cashflow budgets indexes
CREATE INDEX IF NOT EXISTS idx_cashflow_budgets_user_active ON public.cashflow_budgets(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_cashflow_budgets_period ON public.cashflow_budgets(start_date, end_date);

-- Cashflow goals indexes
CREATE INDEX IF NOT EXISTS idx_cashflow_goals_user_active ON public.cashflow_goals(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_cashflow_goals_completed ON public.cashflow_goals(is_completed);

-- Cashflow accounts indexes
CREATE INDEX IF NOT EXISTS idx_cashflow_accounts_user_active ON public.cashflow_accounts(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_cashflow_accounts_type ON public.cashflow_accounts(type);

-- ============================================================
-- TRIGGERS & FUNCTIONS
-- ============================================================

-- Update timestamp function (reuse if exists)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers to all cashflow tables
CREATE TRIGGER trg_cashflow_profiles_updated_at 
    BEFORE UPDATE ON public.cashflow_profiles 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_cashflow_categories_updated_at 
    BEFORE UPDATE ON public.cashflow_categories 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_cashflow_transactions_updated_at 
    BEFORE UPDATE ON public.cashflow_transactions 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_cashflow_budgets_updated_at 
    BEFORE UPDATE ON public.cashflow_budgets 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_cashflow_goals_updated_at 
    BEFORE UPDATE ON public.cashflow_goals 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_cashflow_accounts_updated_at 
    BEFORE UPDATE ON public.cashflow_accounts 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_cashflow_expense_types_updated_at 
    BEFORE UPDATE ON public.cashflow_expense_types 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_cashflow_expense_items_updated_at 
    BEFORE UPDATE ON public.cashflow_expense_items 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_cashflow_recurring_transactions_updated_at 
    BEFORE UPDATE ON public.cashflow_recurring_transactions 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Auto-create cashflow profile and default categories for new users
CREATE OR REPLACE FUNCTION public.handle_new_cashflow_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Insert cashflow profile
    INSERT INTO public.cashflow_profiles (id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name')
    ON CONFLICT (id) DO NOTHING;
    
    -- Insert into admin_app_users for admin tracking (if table exists)
    BEGIN
        INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status)
        VALUES (NEW.id, 'cashflow', NEW.email, NEW.raw_user_meta_data->>'full_name', 'user', 'active')
        ON CONFLICT (user_id, app_name) DO NOTHING;
    EXCEPTION
        WHEN undefined_table THEN
            -- admin_app_users table doesn't exist yet, skip
            NULL;
    END;
    
    -- Insert default income categories
    INSERT INTO public.cashflow_categories (user_id, name, type, color, icon, is_default) VALUES
    (NEW.id, 'Salary', 'income', '#28a745', 'bi-cash-coin', true),
    (NEW.id, 'Freelance', 'income', '#17a2b8', 'bi-laptop', true),
    (NEW.id, 'Business', 'income', '#6f42c1', 'bi-briefcase', true),
    (NEW.id, 'Investment', 'income', '#fd7e14', 'bi-graph-up', true),
    (NEW.id, 'Other Income', 'income', '#6c757d', 'bi-plus-circle', true);
    
    -- Insert default expense categories
    INSERT INTO public.cashflow_categories (user_id, name, type, color, icon, is_default) VALUES
    (NEW.id, 'Food & Dining', 'expense', '#dc3545', 'bi-cart3', true),
    (NEW.id, 'Transportation', 'expense', '#ffc107', 'bi-fuel-pump', true),
    (NEW.id, 'Shopping', 'expense', '#e83e8c', 'bi-bag', true),
    (NEW.id, 'Entertainment', 'expense', '#6f42c1', 'bi-film', true),
    (NEW.id, 'Bills & Utilities', 'expense', '#fd7e14', 'bi-receipt', true),
    (NEW.id, 'Healthcare', 'expense', '#20c997', 'bi-heart-pulse', true),
    (NEW.id, 'Education', 'expense', '#0dcaf0', 'bi-book', true),
    (NEW.id, 'Other Expense', 'expense', '#6c757d', 'bi-circle', true);
    
    -- Insert default account
    INSERT INTO public.cashflow_accounts (user_id, name, type, balance)
    VALUES (NEW.id, 'Main Account', 'bank', 0.00);
    
    RETURN NEW;
END;
$$;

-- Drop old trigger if exists and create new one
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER trg_on_auth_user_created_cashflow
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_cashflow_user();

-- Function to update budget spent amount automatically
CREATE OR REPLACE FUNCTION public.update_budget_spent_amount()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    budget_record RECORD;
BEGIN
    -- Update spent amount for all relevant budgets when transaction changes
    FOR budget_record IN 
        SELECT DISTINCT b.id
        FROM public.cashflow_budgets b
        WHERE b.user_id = COALESCE(NEW.user_id, OLD.user_id)
        AND b.is_active = true
        AND COALESCE(NEW.transaction_date, OLD.transaction_date) BETWEEN b.start_date AND b.end_date
    LOOP
        UPDATE public.cashflow_budgets 
        SET spent_amount = (
            SELECT COALESCE(SUM(t.amount), 0)
            FROM public.cashflow_transactions t
            WHERE t.user_id = budget_record.id
            AND t.type = 'expense'
            AND t.category_id = (SELECT category_id FROM public.cashflow_budgets WHERE id = budget_record.id)
            AND t.transaction_date BETWEEN 
                (SELECT start_date FROM public.cashflow_budgets WHERE id = budget_record.id) AND
                (SELECT end_date FROM public.cashflow_budgets WHERE id = budget_record.id)
        )
        WHERE id = budget_record.id;
    END LOOP;
    
    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Trigger to auto-update budget spent amounts
CREATE TRIGGER trg_update_budget_spent
    AFTER INSERT OR UPDATE OR DELETE ON public.cashflow_transactions
    FOR EACH ROW EXECUTE FUNCTION public.update_budget_spent_amount();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on all cashflow tables
ALTER TABLE public.cashflow_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_expense_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_expense_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_recurring_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_reports ENABLE ROW LEVEL SECURITY;

-- Helper function to check if user is admin (compatible with admin system)
CREATE OR REPLACE FUNCTION public.is_admin_cashflow()
RETURNS BOOLEAN
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE 
    WHEN EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_profiles') THEN
      EXISTS(
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid()
          AND role IN ('admin', 'super_admin')
          AND is_active = TRUE
      )
    ELSE FALSE
  END;
$$;

GRANT EXECUTE ON FUNCTION public.is_admin_cashflow() TO PUBLIC;

-- Cashflow profiles policies
CREATE POLICY "cashflow_profiles_self_access" ON public.cashflow_profiles
    FOR ALL USING (auth.uid() = id);

CREATE POLICY "cashflow_profiles_admin_access" ON public.cashflow_profiles
    FOR ALL USING (public.is_admin_cashflow());

-- Cashflow categories policies
CREATE POLICY "cashflow_categories_self_access" ON public.cashflow_categories
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "cashflow_categories_admin_read" ON public.cashflow_categories
    FOR SELECT USING (public.is_admin_cashflow());

-- Cashflow transactions policies
CREATE POLICY "cashflow_transactions_self_access" ON public.cashflow_transactions
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "cashflow_transactions_admin_read" ON public.cashflow_transactions
    FOR SELECT USING (public.is_admin_cashflow());

-- Cashflow budgets policies
CREATE POLICY "cashflow_budgets_self_access" ON public.cashflow_budgets
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "cashflow_budgets_admin_read" ON public.cashflow_budgets
    FOR SELECT USING (public.is_admin_cashflow());

-- Cashflow goals policies
CREATE POLICY "cashflow_goals_self_access" ON public.cashflow_goals
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "cashflow_goals_admin_read" ON public.cashflow_goals
    FOR SELECT USING (public.is_admin_cashflow());

-- Cashflow accounts policies
CREATE POLICY "cashflow_accounts_self_access" ON public.cashflow_accounts
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "cashflow_accounts_admin_read" ON public.cashflow_accounts
    FOR SELECT USING (public.is_admin_cashflow());

-- Cashflow expense types policies
CREATE POLICY "cashflow_expense_types_self_access" ON public.cashflow_expense_types
    FOR ALL USING (auth.uid() = user_id);

-- Cashflow expense items policies
CREATE POLICY "cashflow_expense_items_self_access" ON public.cashflow_expense_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.cashflow_expense_types 
            WHERE cashflow_expense_types.id = cashflow_expense_items.expense_type_id 
            AND cashflow_expense_types.user_id = auth.uid()
        )
    );

-- Cashflow recurring transactions policies
CREATE POLICY "cashflow_recurring_transactions_self_access" ON public.cashflow_recurring_transactions
    FOR ALL USING (auth.uid() = user_id);

-- Cashflow reports policies
CREATE POLICY "cashflow_reports_self_access" ON public.cashflow_reports
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "cashflow_reports_admin_read" ON public.cashflow_reports
    FOR SELECT USING (public.is_admin_cashflow());

-- ============================================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================================

COMMENT ON TABLE public.cashflow_profiles IS 'Cashflow app user profiles with app-specific settings';
COMMENT ON TABLE public.cashflow_categories IS 'Income and expense categories for cashflow app';
COMMENT ON TABLE public.cashflow_transactions IS 'Financial transactions for cashflow app';
COMMENT ON TABLE public.cashflow_budgets IS 'Budget planning and tracking for cashflow app';
COMMENT ON TABLE public.cashflow_goals IS 'Savings and financial goals for cashflow app';
COMMENT ON TABLE public.cashflow_accounts IS 'Financial accounts (bank, cash, etc.) for cashflow app';
COMMENT ON TABLE public.cashflow_expense_types IS 'Expense type categorization for cashflow app';
COMMENT ON TABLE public.cashflow_expense_items IS 'Detailed expense items under each type';
COMMENT ON TABLE public.cashflow_recurring_transactions IS 'Automated recurring transactions';
COMMENT ON TABLE public.cashflow_reports IS 'Generated financial reports and snapshots';
