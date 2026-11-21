\getenv auth_db_password AUTH_DB_PASSWORD
\getenv reviews_db_password REVIEWS_DB_PASSWORD

-- Hold the lock for the session because CREATE DATABASE runs outside a transaction.
SELECT pg_advisory_lock(80410364);

SELECT format('CREATE ROLE reeltone_auth LOGIN PASSWORD %L', :'auth_db_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'reeltone_auth')
\gexec

SELECT 'CREATE DATABASE reeltone_auth OWNER reeltone_auth'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'reeltone_auth')
\gexec

REVOKE CONNECT, TEMPORARY ON DATABASE reeltone_auth FROM PUBLIC;

SELECT format('CREATE ROLE reeltone_reviews LOGIN PASSWORD %L', :'reviews_db_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'reeltone_reviews')
\gexec

SELECT 'CREATE DATABASE reeltone_reviews OWNER reeltone_reviews'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'reeltone_reviews')
\gexec

REVOKE CONNECT, TEMPORARY ON DATABASE reeltone_reviews FROM PUBLIC;

SELECT pg_advisory_unlock(80410364);
