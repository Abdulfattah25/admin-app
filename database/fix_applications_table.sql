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
