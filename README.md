# ReelTone deployment

Run Compose from this directory. The application repositories are `../reeltone-server`, `../reeltone-reviews`, and `../reeltone-stream`. Compose runs the unified server and both Next.js frontends. Local and production Compose projects use separate networks and volumes.

## Local development

On a fresh checkout, copy `.env.local.example` to `.env.local`. Create the local Auth env and signing key using the [Auth setup](../reeltone-server/README.md#run-locally). Create the Reviews API env and register its `reviews-local` client using the [Reviews auth setup](../reeltone-reviews/README.md#reeltone-auth). Those same env files are read by Compose. Set `LOCAL_UID` and `LOCAL_GID` in `.env.local` if your host user differs from `1000:1000`.

```sh
docker compose --env-file .env.local -f compose.yaml -f compose.local.yaml up --build -d --wait
```

| Service | Local address |
| --- | --- |
| Server | `http://localhost:3000` |
| Reviews | `http://localhost:3101` |
| Stream | `http://localhost:3102` |
| PostgreSQL | `127.0.0.1:5433` with user `postgres` and password `root` |

The local stack runs Next.js with Fast Refresh and the unified NestJS server in Node watch mode. NestJS serves Auth, Reviews and streaming directly. Edit the source in your checkout and the running containers pick it up. Next.js assets in `public/` are mounted too. The development images contain their own dependencies and build caches.

For a normal restart, use the same command without `--build`. Rebuild after dependency or Dockerfile changes. Recreate the affected service after changing its env file. To apply new SQL migrations without rebuilding, use the same Compose files followed by `run --rm migrate-auth` or `run --rm migrate-reviews`.

Reviews web talks to the server at `http://reeltone-server:3000/reviews`. Stream uses `http://reeltone-server:3000` to resolve playback manifests. The streaming manifest API is available at `http://localhost:3000/api/stream/videos`. Auth and Reviews use separate databases and login roles on the shared PostgreSQL volume. Compose provisions the databases and applies their schemas before starting the apps. To import a legacy Reviews SQLite backup, mount it read-only and pass `--sqlite` or `--sqlite-sessions` explicitly to `migrate-reviews`.

Use the same env and Compose files with `logs -f` to view the app logs or `down` to stop the stack.

### Reset all local database data

```sh
./reset-db.sh --yes
```

This permanently deletes the local PostgreSQL volume, including all Auth and Reviews data. The script starts the local stack with fresh databases and applies the schemas. Legacy SQLite imports require a separate command.

## Production

1. Copy `.env.prod.example` to `.env.prod` and fill in separate PostgreSQL passwords for the administrator, Auth, and Reviews, along with the release image tags and TLS directories. Set `SERVER_IMAGE`, `REVIEWS_WEB_IMAGE`, and `STREAM_WEB_IMAGE` to the release images built from the respective repository roots. Build Reviews with `NEXT_PUBLIC_SITE_URL=https://reviews.reeltone.site`.
2. Copy `reeltone-auth.env.example` and `reeltone-reviews.env.example` to their matching `.env` files. Configure the Auth signing keys and SMTP. Register the production Reviews client in Auth with the callback `https://reviews.reeltone.site/api/reeltone/auth/callback`. Put the matching client secret and a separate session secret in the Reviews env file. Set `TMDB_API_KEY` for Reviews.
3. Point `auth.reeltone.site`, `reviews.reeltone.site`, and `stream.reeltone.site` at the host. Each TLS directory must provide a container-readable `fullchain.pem` and `privkey.pem`. Provision and renew certificates outside Compose, then reload Nginx after renewal.

```sh
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml up -d --wait
```

Nginx routes all three domains and publishes ports 80 and 443. The migration jobs and the running backend all use the same server image. The API and PostgreSQL ports stay private. The Reviews API reaches Auth through Nginx over HTTPS on the Docker network.

Auth and Reviews data live in the PostgreSQL volume. Back it up and retain it across deployments.

### Import an existing production Reviews database

Stop the old Reviews API so it stops writing, then take a consistent backup of its SQLite files. Before starting the new API, mount the backup on the migration job:

```sh
docker compose --env-file .env.prod -f compose.yaml -f compose.prod.yaml \
  run --rm -v /absolute/path/to/backup:/legacy:ro migrate-reviews \
  npm run migration:reviews -- --sqlite /legacy/reeltone.db --sqlite-sessions /legacy/reviews-sessions.sqlite3
```

Omit `--sqlite-sessions` if there is no sessions file. The importer keeps record IDs and records a successful import in PostgreSQL. It rejects a populated target to protect existing data. Keep the source files as backups.

See the [Auth schema](auth-schema.md) for Auth tables and [the Reviews migration](../reeltone-server/reviews/db/migrations/001_reviews.sql) for Reviews tables. Provisioning creates missing databases and roles. Existing roles keep their passwords across runs.
