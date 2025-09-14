-- ============================================================
-- PRODUCTIVITY APP SCHEMA (SPLIT)
-- Depends on: admin_core.sql for core tables and auth
-- ============================================================

-- Users
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

-- Task templates
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

-- Task instances
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

-- Score logs
CREATE TABLE IF NOT EXISTS public.productivity_score_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.productivity_users(id) ON DELETE CASCADE,
  task_instance_id UUID REFERENCES public.productivity_task_instances(id) ON DELETE SET NULL,
  score_delta INTEGER NOT NULL,
  reason TEXT NOT NULL,
  log_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_productivity_task_templates_user_id ON public.productivity_task_templates(user_id);
CREATE INDEX IF NOT EXISTS idx_productivity_task_instances_user_date ON public.productivity_task_instances(user_id, task_date);
CREATE INDEX IF NOT EXISTS idx_productivity_task_instances_completed ON public.productivity_task_instances(is_completed);
CREATE INDEX IF NOT EXISTS idx_productivity_score_logs_user_date ON public.productivity_score_logs(user_id, log_date);

-- Triggers
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_productivity_users_updated_at ON public.productivity_users;
CREATE TRIGGER trg_productivity_users_updated_at BEFORE UPDATE ON public.productivity_users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
DROP TRIGGER IF EXISTS trg_productivity_task_templates_updated_at ON public.productivity_task_templates;
CREATE TRIGGER trg_productivity_task_templates_updated_at BEFORE UPDATE ON public.productivity_task_templates FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
DROP TRIGGER IF EXISTS trg_productivity_task_instances_updated_at ON public.productivity_task_instances;
CREATE TRIGGER trg_productivity_task_instances_updated_at BEFORE UPDATE ON public.productivity_task_instances FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- RLS
ALTER TABLE public.productivity_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productivity_task_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productivity_task_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.productivity_score_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Productivity users self access" ON public.productivity_users;
CREATE POLICY "Productivity users self access" ON public.productivity_users
  FOR ALL USING (id = auth.uid()) WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Productivity users admin access" ON public.productivity_users;
CREATE POLICY "Productivity users admin access" ON public.productivity_users
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Productivity task templates self access" ON public.productivity_task_templates;
CREATE POLICY "Productivity task templates self access" ON public.productivity_task_templates
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Productivity task instances self access" ON public.productivity_task_instances;
CREATE POLICY "Productivity task instances self access" ON public.productivity_task_instances
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Productivity score logs self access" ON public.productivity_score_logs;
CREATE POLICY "Productivity score logs self access" ON public.productivity_score_logs
  FOR ALL USING (user_id = auth.uid());
