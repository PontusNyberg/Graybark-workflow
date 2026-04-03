# Rules: Database Migration

Applies when database migration files are created or modified.

TODO: Adjust to match your database and migration tool.

## Migration safety

- Migrations must be **idempotent** where possible (IF NOT EXISTS, IF EXISTS)
- Never modify an already-applied migration — create a new one
- Test migrations on a fresh database before committing
- Include both up and down migrations if your tool supports it

## Schema design

- Use timestamps with timezone (TIMESTAMPTZ, not TIMESTAMP)
- Add `created_at` and `updated_at` to all tables
- Name indexes consistently (e.g., `idx_<table>_<column>`)
- Foreign keys should have `ON DELETE` behavior defined

## Security

- Enable Row Level Security (if using Supabase/PostgreSQL RLS)
- Never use SECURITY DEFINER without documented reason
- No plain text storage of sensitive data

## Naming conventions

- Table names: plural, snake_case (`users`, `order_items`)
- Column names: snake_case (`created_at`, `user_id`)
- Foreign keys: `<referenced_table_singular>_id` (`user_id`, `order_id`)

## Testing

- Test that migrations apply cleanly on empty database
- Test that migrations are reversible (if down migration exists)
- Test any Row Level Security policies
