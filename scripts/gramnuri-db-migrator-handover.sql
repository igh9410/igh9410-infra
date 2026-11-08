-- One-time ownership handover of gramnuri_db from cluster_admin to the
-- migration-only role gramnuri_migrator (CNPG managed role, see
-- argocd/values/<env>-gramnuri-db.yaml). Run once per environment as the
-- postgres superuser, after the role exists and before the first migration Job:
--
--   K="kubectl --context tailscale-operator-1.taild7ce30.ts.net"
--   NS=cnpg-database   # prod: prod-cnpg-database
--   POD=$($K -n $NS get pods -l cnpg.io/instanceRole=primary -o name | head -1)
--   $K -n $NS exec -i $POD -c postgres -- psql -d gramnuri_db -v ON_ERROR_STOP=1 \
--     < scripts/gramnuri-db-migrator-handover.sql
--
-- Safe to re-run. Only touches gramnuri_db. REASSIGN OWNED is deliberately not
-- used: it would also reassign other databases owned by cluster_admin
-- (artskorner_db shares the prod cluster).
--
-- Why superuser: changing ownership away from another role cannot be done by
-- the migration role itself, so this cannot live in a goose migration.

BEGIN;

ALTER DATABASE gramnuri_db OWNER TO gramnuri_migrator;
ALTER SCHEMA public OWNER TO gramnuri_migrator;

DO $$
DECLARE
    obj record;
BEGIN
    -- Tables, views and standalone sequences in public. Indexes and sequences
    -- owned by a serial/identity column follow their table automatically.
    FOR obj IN
        SELECT c.oid::regclass AS name,
               CASE c.relkind
                   WHEN 'S' THEN 'SEQUENCE'
                   WHEN 'v' THEN 'VIEW'
                   WHEN 'm' THEN 'MATERIALIZED VIEW'
                   ELSE 'TABLE'
               END AS kind
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relkind IN ('r', 'p', 'v', 'm', 'S')
          AND c.relowner <> 'gramnuri_migrator'::regrole
          AND NOT EXISTS (
              SELECT 1 FROM pg_depend d
              WHERE d.classid = 'pg_class'::regclass
                AND d.objid = c.oid
                AND d.refclassid = 'pg_class'::regclass
                AND d.deptype IN ('a', 'i')
          )
    LOOP
        RAISE NOTICE 'ALTER % % OWNER TO gramnuri_migrator', obj.kind, obj.name;
        EXECUTE format('ALTER %s %s OWNER TO gramnuri_migrator', obj.kind, obj.name);
    END LOOP;
END
$$;

-- DML-only access for the API role on objects created by future migrations
-- (mirrors the existing cluster_admin default ACL). No DDL is granted.
ALTER DEFAULT PRIVILEGES FOR ROLE gramnuri_migrator IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO gramnuri_db_user;
ALTER DEFAULT PRIVILEGES FOR ROLE gramnuri_migrator IN SCHEMA public
    GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO gramnuri_db_user;

COMMIT;

-- Verification: everything in public should now be owned by gramnuri_migrator.
SELECT c.relkind, pg_get_userbyid(c.relowner) AS owner, count(*)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
GROUP BY 1, 2
ORDER BY 1, 2;
