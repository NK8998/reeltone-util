# ReelTone deployment

Run Compose from this directory. The application repositories are `../reeltone-auth` and `../reeltone-reviews`. Stream and Studio have reserved directories and can be added as their services are built. Local and production Compose projects use separate networks and volumes.

## Local development

On a fresh checkout, copy `.env.local.example` to `.env.local`. Create the local Auth env and signing key using the [Auth setup](../reeltone-auth/README.md#run-locally). Create the Reviews API env and register its `reviews-local` client using the [Reviews auth setup](../reeltone-reviews/README.md#reeltone-auth). Those same env files are read by Compose. Set `LOCAL_UID` and `LOCAL_GID` in `.env.local` if your host user differs from `1000:1000`.

```sh
docker compose --env-file .env.local -f compose.yaml -f compose.local.yaml up --build -d --wait
```

| Service | Local address |
| --- | --- |
| Auth | `http://localhost:3000` |
| Reviews | `http://localhost:3101` |
| PostgreSQL | `127.0.0.1:5433` with user `postgres` and password `root` |

The local stack runs Next.js with Fast Refresh, Flask with its reloader, and Auth in Node watch mode. Edit the source in your checkout and the running containers pick it up. Next.js assets in `public/` are mounted too. The development images contain their own dependencies and build caches.

For a normal restart, use the same command without `--build`. Rebuild after dependency or Dockerfile changes. Recreate the affected service after changing its env file. To apply new SQL migrations without rebuilding, use the same Compose files followed by `run --rm migrate-auth` or `run --rm migrate-reviews`.

Reviews talks to Flask inside Docker. Auth and Reviews use separate databases and login roles on the shared PostgreSQL volume. Compose runs provisioning and both migration jobs before starting the apps. The first local deployment imports any existing Reviews SQLite files under `../reeltone-reviews/server/db` through a read-only mount on the migration job.

Use the same env and Compose files with `logs -f` to view the app logs or `down` to stop the stack.

## Production

1. Copy `.env.prod.example` to `.env.prod` and fill in separate PostgreSQL passwords for the administrator, Auth, and Reviews, along with the release image tags and TLS directories. The release images come from the Auth, Reviews API, and Reviews web Dockerfiles. Build the web image with `NEXT_PUBLIC_SITE_URL=https://reviews.reeltone.site`.
2. Copy `reeltone-auth.env.example` and `reeltone-reviews.env.example` to their matching `.env` files. Configure the Auth signing keys and SMTP. Register the production Reviews client in Auth with the callback `https://reviews.reeltone.site/api/reeltone/auth/callback`. Put the matching client secret and a separate session secret in the Reviews env file. Set `TMDB_API_KEY` for Reviews.
3. Point `auth.reeltone.site` and `reviews.reeltone.site` at the host. Each TLS directory must provide a container-readable `fullchain.pem` and `privkey.pem`. Provision and renew certificates outside Compose, then reload Nginx after renewal.

```sh
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml up -d --wait
```

Nginx routes both domains and publishes ports 80 and 443. The API and PostgreSQL ports stay private. The Reviews API reaches Auth through Nginx over HTTPS on the Docker network.

Auth and Reviews data live in the PostgreSQL volume. Back it up and retain it across deployments.

### Import an existing production Reviews database

Stop the old Reviews API so it stops writing, then take a consistent backup of its SQLite files. Before starting the new API, mount the backup on the migration job:

```sh
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml \
  run --rm -v /absolute/path/to/backup:/legacy:ro migrate-reviews \
  python migrate.py --sqlite /legacy/reeltone.db --sqlite-sessions /legacy/reviews-sessions.sqlite3
```

Omit `--sqlite-sessions` if there is no sessions file. The importer keeps record IDs and records a successful import in PostgreSQL. It rejects a populated target to protect existing data. Keep the source files as backups.

See the [Auth schema](auth-schema.md) for Auth tables and [the Reviews migration](../reeltone-reviews/server/db/migrations/001_reviews.sql) for Reviews tables. Provisioning creates missing databases and roles. Existing roles keep their passwords across runs.
