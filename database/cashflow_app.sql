-- ============================================================
-- CASHFLOW APP SCHEMA (SPLIT)
-- Depends on: admin_core.sql for auth and applications
-- ============================================================

-- Users
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

-- Categories
CREATE TABLE IF NOT EXISTS public.cashflow_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.cashflow_users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('income', 'expense')),
  color VARCHAR(7) DEFAULT '#000000',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Transactions
CREATE TABLE IF NOT EXISTS public.cashflow_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.cashflow_users(id) ON DELETE CASCADE,
  category_id UUID REFERENCES public.cashflow_categories(id) ON DELETE SET NULL,
  amount DECIMAL(15,2) NOT NULL CHECK (amount > 0),
  description TEXT NOT NULL,
  transaction_date DATE NOT NULL,
  type VARCHAR(20) NOT NULL CHECK (type IN ('income', 'expense')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_cashflow_transactions_user_date ON public.cashflow_transactions(user_id, transaction_date);
CREATE INDEX IF NOT EXISTS idx_cashflow_transactions_category ON public.cashflow_transactions(category_id);

-- Triggers
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cashflow_users_updated_at ON public.cashflow_users;
CREATE TRIGGER trg_cashflow_users_updated_at BEFORE UPDATE ON public.cashflow_users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
DROP TRIGGER IF EXISTS trg_cashflow_transactions_updated_at ON public.cashflow_transactions;
CREATE TRIGGER trg_cashflow_transactions_updated_at BEFORE UPDATE ON public.cashflow_transactions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- RLS
ALTER TABLE public.cashflow_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Cashflow users self access" ON public.cashflow_users;
CREATE POLICY "Cashflow users self access" ON public.cashflow_users
  FOR ALL USING (id = auth.uid()) WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Cashflow categories self access" ON public.cashflow_categories;
CREATE POLICY "Cashflow categories self access" ON public.cashflow_categories
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Cashflow transactions self access" ON public.cashflow_transactions;
CREATE POLICY "Cashflow transactions self access" ON public.cashflow_transactions
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
