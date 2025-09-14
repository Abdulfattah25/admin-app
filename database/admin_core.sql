-- ============================================================
-- ADMIN CORE SCHEMA (CLEAN & SPLIT)
-- Dependencies: Supabase (auth schema), Postgres 14+, Tailwind not relevant
-- This script is idempotent and safe to re-run
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- TABLES
-- ============================================================

-- Applications registry
CREATE TABLE IF NOT EXISTS public.applications (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  display_name VARCHAR(200),
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Admin system user profiles
CREATE TABLE IF NOT EXISTS public.admin_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'super_admin')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Licenses (per application)
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

-- Users per application (join between auth.users and applications)
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
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_admin_profiles_email ON public.admin_profiles(email);
CREATE INDEX IF NOT EXISTS idx_admin_profiles_role ON public.admin_profiles(role);
CREATE INDEX IF NOT EXISTS idx_admin_licenses_app_name ON public.admin_licenses(app_name);
CREATE INDEX IF NOT EXISTS idx_admin_licenses_is_used ON public.admin_licenses(is_used);
CREATE INDEX IF NOT EXISTS idx_admin_app_users_app_name ON public.admin_app_users(app_name);
CREATE INDEX IF NOT EXISTS idx_admin_app_users_status ON public.admin_app_users(status);

-- ============================================================
-- TRIGGERS & FUNCTIONS
-- ============================================================

-- Generic updated_at updater
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers
DROP TRIGGER IF EXISTS trg_admin_profiles_updated_at ON public.admin_profiles;
CREATE TRIGGER trg_admin_profiles_updated_at
  BEFORE UPDATE ON public.admin_profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trg_admin_app_users_updated_at ON public.admin_app_users;
CREATE TRIGGER trg_admin_app_users_updated_at
  BEFORE UPDATE ON public.admin_app_users
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Helper: check if current user is admin
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

-- Auto-create admin_profiles on auth.users insert (no side effects beyond admin_profiles)
CREATE OR REPLACE FUNCTION public.handle_admin_new_user()
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

-- Ensure only one trigger exists for this purpose
DROP TRIGGER IF EXISTS trg_admin_on_auth_user_created ON auth.users;
CREATE TRIGGER trg_admin_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_admin_new_user();

-- RPC: Consume license and enroll user into an app atomically
-- Usage: select public.consume_license('productivity', 'LICENSECODE123');
CREATE OR REPLACE FUNCTION public.consume_license(p_app_name text, p_license_code text)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_email text := COALESCE((auth.jwt() ->> 'email'), NULL);
  v_name text := COALESCE((auth.jwt() -> 'user_metadata' ->> 'full_name'), NULL);
  v_license_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED' USING ERRCODE = '28000';
  END IF;

  -- Validate license
  SELECT id INTO v_license_id
  FROM public.admin_licenses
  WHERE license_code = p_license_code
    AND app_name = p_app_name
    AND is_used = FALSE
    AND (expires_at IS NULL OR expires_at > NOW())
  FOR UPDATE;

  IF v_license_id IS NULL THEN
    RAISE EXCEPTION 'INVALID_OR_USED_LICENSE' USING ERRCODE = '22023';
  END IF;

  -- Mark license used
  UPDATE public.admin_licenses
  SET is_used = TRUE,
      used_by = v_uid,
      used_at = NOW()
  WHERE id = v_license_id;

  -- Ensure admin_profiles row exists
  INSERT INTO public.admin_profiles (id, email, name)
  VALUES (v_uid, COALESCE(v_email, ''), v_name)
  ON CONFLICT (id) DO UPDATE SET email = COALESCE(EXCLUDED.email, admin_profiles.email);

  -- Enroll into app
  INSERT INTO public.admin_app_users (user_id, app_name, email, name, role, status, license_id)
  VALUES (v_uid, p_app_name, COALESCE(v_email, ''), v_name, 'user', 'active', v_license_id)
  ON CONFLICT (user_id, app_name) DO UPDATE SET
    email = COALESCE(EXCLUDED.email, public.admin_app_users.email),
    name = COALESCE(EXCLUDED.name, public.admin_app_users.name),
    status = 'active',
    license_id = COALESCE(EXCLUDED.license_id, public.admin_app_users.license_id),
    updated_at = NOW();

  RETURN 'OK';
END;
$$;

GRANT EXECUTE ON FUNCTION public.consume_license(text, text) TO authenticated;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_app_users ENABLE ROW LEVEL SECURITY;

-- Applications: readable by authenticated users; admins can manage
DROP POLICY IF EXISTS "Applications readable by authenticated users" ON public.applications;
CREATE POLICY "Applications readable by authenticated users" ON public.applications
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Applications admin manage" ON public.applications;
CREATE POLICY "Applications admin manage" ON public.applications
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Admin profiles: self can read/update; admins can manage
DROP POLICY IF EXISTS "Admin profiles self access" ON public.admin_profiles;
CREATE POLICY "Admin profiles self access" ON public.admin_profiles
  FOR SELECT USING (id = auth.uid());

DROP POLICY IF EXISTS "Admin profiles self update" ON public.admin_profiles;
CREATE POLICY "Admin profiles self update" ON public.admin_profiles
  FOR UPDATE USING (id = auth.uid()) WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Admin profiles admin access" ON public.admin_profiles;
CREATE POLICY "Admin profiles admin access" ON public.admin_profiles
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Licenses: admin only
DROP POLICY IF EXISTS "Admin licenses admin access" ON public.admin_licenses;
CREATE POLICY "Admin licenses admin access" ON public.admin_licenses
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- App users: admin only (normal users enroll via RPC security definer)
DROP POLICY IF EXISTS "Admin app users admin access" ON public.admin_app_users;
CREATE POLICY "Admin app users admin access" ON public.admin_app_users
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- ============================================================
-- SEED DATA (idempotent)
-- ============================================================
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
