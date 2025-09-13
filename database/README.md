# Database Schema Improvement Guide

## Overview

This guide explains how to migrate from the current mixed schema to an improved multi-application database structure with proper naming conventions.

## Current Problems

1. **Mixed table purposes**: Task management and admin management in same schema
2. **No application prefixes**: Generic table names causing confusion
3. **Duplicate table definitions**: Multiple `licenses` tables with different structures
4. **Poor scalability**: Hard to add new applications

## New Schema Structure

### Core Admin Tables (Shared)

- `applications` - Registry of all applications
- `admin_profiles` - Admin system user profiles
- `admin_licenses` - Application licenses
- `admin_app_users` - Users registered for specific apps

### Application-Specific Tables

- `productivity_*` - Tables for productivity app
- `cashflow_*` - Tables for cashflow app
- `[app_name]_*` - Pattern for future apps

## Migration Steps

### 1. Backup Current Database

```sql
-- Create backup
pg_dump your_database > backup_before_migration.sql
```

### 2. Run New Schema

```bash
# Execute the improved schema
psql -d your_database -f database/improved_schema.sql
```

### 3. Run Migration Script

```bash
# Migrate existing data
psql -d your_database -f database/migration_script.sql
```

### 4. Update Application Code

#### Replace AdminService

Replace `src/services/adminService.js` with `src/services/improvedAdminService.js`:

```javascript
// Old import
import { AdminService } from '@/services/adminService'

// New import
import { AdminService } from '@/services/improvedAdminService'
```

#### Update Auth Service

The AuthService has been updated to use `admin_profiles` table instead of `users` table.

### 5. Verify Migration

1. Check admin login still works
2. Verify user and license data is present
3. Test all admin functions
4. Check application switching works

### 6. Clean Up (Optional)

After verifying everything works, you can drop old tables:

```sql
-- Uncomment the drop table section in migration_script.sql
-- and run it again
```

## New Table Structure Benefits

### 1. Clear Separation

- **Admin tables**: For cross-app administration
- **App tables**: For application-specific data

### 2. Scalable Naming

- Easy to add new applications
- Clear ownership of data
- No naming conflicts

### 3. Better Performance

- Proper indexes for each use case
- Smaller tables for faster queries
- Clear foreign key relationships

### 4. Easier Maintenance

- Clear purpose for each table
- Consistent naming patterns
- Better documentation

## Example Queries

### Get all users for productivity app

```sql
SELECT * FROM admin_app_users
WHERE app_name = 'productivity';
```

### Get productivity user tasks

```sql
SELECT t.*, tt.description
FROM productivity_task_instances t
LEFT JOIN productivity_task_templates tt ON t.template_id = tt.id
WHERE t.user_id = 'user-uuid';
```

### Get cross-app statistics

```sql
SELECT
  app_name,
  COUNT(*) as user_count,
  COUNT(CASE WHEN status = 'active' THEN 1 END) as active_users
FROM admin_app_users
GROUP BY app_name;
```

## Configuration Updates

### Environment Variables

No changes needed to existing environment variables.

### Supabase RLS Policies

New RLS policies are automatically created with the schema. They provide:

- Admin-only access to admin tables
- User-only access to their own app data
- Proper security for cross-app data

## Rollback Plan

If migration fails:

1. Restore from backup: `psql -d your_database < backup_before_migration.sql`
2. Revert code changes
3. Fix issues and retry

## Testing Checklist

- [ ] Admin login works
- [ ] User management works
- [ ] License management works
- [ ] Application switching works
- [ ] Data integrity maintained
- [ ] Performance is acceptable
- [ ] No error logs

## Future Applications

To add a new application (e.g., "inventory"):

1. **Add to applications table**:

```sql
INSERT INTO applications (name, display_name, description)
VALUES ('inventory', 'Inventory Manager', 'Stock and inventory management');
```

2. **Create app-specific tables**:

```sql
CREATE TABLE inventory_users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  -- app-specific fields
);

CREATE TABLE inventory_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES inventory_users(id),
  -- app-specific fields
);
```

3. **Add RLS policies**:

```sql
ALTER TABLE inventory_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "inventory_users_self_access" ON inventory_users
  FOR ALL USING (id = auth.uid());
```

4. **Update AdminService** to include new app methods.

This structure makes adding new applications straightforward and maintains consistency across the platform.
