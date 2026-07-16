# Database Migrations

`docker compose up -d --build` builds the server image and runs
`prisma migrate deploy` before the NestJS process starts. The application does
not use `prisma db push` at runtime.

The checked-in `20260714000000_initial_schema` migration is the v0.1 database
baseline. It is intended for a new database, including a self-hosted server
created with the supplied Compose file.

The baseline SQL must retain real line breaks. A migration file beginning with
`-- CreateSchemaCREATE ...` has been flattened and will comment out the entire
schema. The repository baseline is verified by resetting a disposable
PostgreSQL database, applying all migrations, and checking `prisma migrate
status`.

The project previously used `db push` during pre-release development. Do not
point this first migration at an old, unmanaged development database and
assume it is an in-place upgrade. Back up the database, provision a fresh
database, and import only data that has been reviewed for the current schema.

Before any future schema change:

1. Create a new Prisma migration and review its SQL.
2. Test `prisma migrate reset --force --skip-seed` against disposable data.
3. Test `prisma migrate deploy` against a copy of the deployment database.
4. Keep data transformations in the migration and document any operator step.
