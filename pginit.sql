CREATE ROLE tx_admin LOGIN PASSWORD 'test' NOSUPERUSER INHERIT NOCREATEDB CREATEROLE NOREPLICATION;
CREATE ROLE tx_app   LOGIN PASSWORD 'test' NOSUPERUSER INHERIT NOCREATEDB CREATEROLE NOREPLICATION;
CREATE ROLE tx_viewer NOLOGIN NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;
CREATE DATABASE termx WITH OWNER = tx_admin ENCODING = 'UTF8' TABLESPACE = pg_default CONNECTION LIMIT = -1;
grant temp on database termx to tx_app;
grant connect on database termx to tx_app;

set core.env  = 'dev';
ALTER SYSTEM SET core.env = 'dev';
select pg_reload_conf();

-- hstore is required by termx migrations (matches scripts/recreate-db.sh). It
-- must live in the `termx` database, so connect there before creating it.
\connect termx
CREATE EXTENSION IF NOT EXISTS hstore SCHEMA public;

