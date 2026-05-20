> **WARNING!**
> This guide is intended for local quickstart and is not suited for production environments.

# Step-by-step instructions

- Clone the repository.
- Ensure that you have the [Docker](https://docs.docker.com/get-docker/) environment installed locally.
- Go to shell, navigate to the cloned directory, and execute the script below:

```bash
docker-compose pull && docker-compose up -d
```

- The first startup may take up to 1 minute. Execute the script below to monitor the installation process.

```bash
docker logs termx-server
```

- Wait until the text `Startup completed in NNNNms. Server Running: http://XXXXX:8200` appears.
- Open [`http://localhost:4200`](http://localhost:4200) in your web browser.

# KeyCloak

Follow KeyCloak installation and configuration [instructions](keycloak/README.md) if you need authentication in your environment.

# Minio

TermX stores large terminology archives (SNOMED RF2 zips, LOINC release bundles, wiki attachments) in [Minio](https://min.io/), an S3-compatible object store. The `termx-minio` container holds the data; the `termx-minio-init` container provisions a per-application user (`bob`) on every `docker compose up`.

## How it's wired

```
┌──────────────┐   POST /bob/objects           ┌──────────────┐
│ termx-server │ ────────────────────────────▶ │ termx-minio  │
│              │   uses bob:bobobobo           │   /data      │
└──────────────┘                                └──────────────┘
                                                       ▲
                                                       │ provisions bob user + readwrite policy on startup
                                                       │ (idempotent)
                                                ┌──────┴───────────┐
                                                │ termx-minio-init │
                                                │ uses MINIO_ROOT  │
                                                └──────────────────┘
```

`termx-server` never uses the Minio root account — it talks to Minio as `bob`. The root account is only used by the init container to create `bob` and attach the `readwrite` policy.

## Credentials — `minio.env`

A single file holds both the root and the per-app credentials so the init container can't drift out of sync with the Minio container:

```env
# minio.env — committed with safe-for-localhost defaults; OVERRIDE per deployment.

# Root account (administrator). Used by the init container ONLY.
MINIO_ROOT_USER=minio
MINIO_ROOT_PASSWORD=miniominio

# Per-app account the server uses (also referenced in server.env as
# BOB_MINIO_ACCESS_KEY / BOB_MINIO_SECRET_KEY — keep them in sync).
BOB_MINIO_USER=bob
BOB_MINIO_PASSWORD=bobobobo
```

Both `termx-minio` and `termx-minio-init` load this file via `env_file:` — change the root password in one place and both pick it up.

`server.env` carries the per-app credentials separately (because the server container reads `server.env`, not `minio.env`). If you change `BOB_MINIO_USER` / `BOB_MINIO_PASSWORD` in `minio.env`, mirror the same values into `server.env`'s `BOB_MINIO_ACCESS_KEY` / `BOB_MINIO_SECRET_KEY`. The other Bob settings in `server.env`:

```env
BOB_MINIO_URL=http://termx-minio:9000
BOB_MINIO_ACCESS_KEY=bob          # = minio.env BOB_MINIO_USER
BOB_MINIO_SECRET_KEY=bobobobo     # = minio.env BOB_MINIO_PASSWORD
```

## Persistence

`docker-compose.yml` mounts `./miniodata:/data` so the user list and the bucket contents survive container restarts. Create the directory next to the compose file:

```bash
mkdir -p miniodata
```

(The `.gitignore` already excludes it.)

**Important — Minio honors persisted credentials.** Once a Minio container has seeded `/data` with a given `MINIO_ROOT_PASSWORD`, subsequent boots use the PERSISTED password and ignore later changes to the env var. So:

- If you change `MINIO_ROOT_PASSWORD` in `minio.env` after the first startup, either update `minio.env` to match what's already persisted, **or** wipe `./miniodata` and restart so Minio re-seeds.
- Same applies to `BOB_MINIO_PASSWORD` — the init container won't rotate an existing user's password; remove the user first with `mc admin user remove minio bob` if you need to rotate.

## Startup ordering

- `termx-minio` declares a healthcheck (`mc ready local`). It only goes `healthy` once the S3 API actually accepts connections.
- `termx-minio-init` waits via `depends_on.termx-minio.condition: service_healthy`.
- `termx-server` waits via `depends_on.termx-minio-init.condition: service_completed_successfully`.

So a cold `docker compose up -d` reliably orders: Minio → init (creates `bob`) → server starts.

## Quick verification

```bash
docker compose up -d
docker compose logs termx-minio-init
# expect: "bob (bob) + readwrite policy provisioned"

# Try a tiny upload from the server side
curl -F file=@README.md -F container=wiki \
     -H "Authorization: Bearer yupi" \
     http://localhost:8200/bob/objects
# 200 OK + JSON BobObject if Minio + bob are wired correctly
```

## Web console

Minio's web console is exposed on port `9101`. Browse to `http://localhost:9101` and sign in as the root user from `minio.env` (`minio` / `miniominio` by default) to inspect buckets and objects.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Access Key Id you provided does not exist in our records` on `POST /bob/objects` | The `bob` user isn't in Minio. Either init never ran, ran before Minio was ready, or `./miniodata` was wiped after init | `docker compose up -d termx-minio-init` to re-run init. If repeated, check `docker compose logs termx-minio-init` |
| Init reports "Access denied" against the root account | `MINIO_ROOT_PASSWORD` in `minio.env` doesn't match what `./miniodata` has persisted | Either align `minio.env` with the persisted password, or wipe `./miniodata` for a fresh seed |
| Server returns Minio errors only after a `docker compose down -v` | `-v` removes named volumes but NOT bind mounts — `./miniodata` should survive | If `./miniodata` was deleted manually, recreate empty and `docker compose up -d`; init will re-seed |
| `BOB_MINIO_PASSWORD` rotation in `minio.env` doesn't take effect | `mc admin user add` skips existing users (correctly — it's idempotent) | `docker exec termx-minio mc admin user remove minio bob`, then `docker compose up -d termx-minio-init` |

# Demo

You can use the [TermX development](https://dev.termx.org/) and [demo](https://demo.termx.org/) environments instead.

# Advanced setup and Troubleshooting

Read details about manual configuration in [Termx tutorial](https://tutorial.termx.org/en/about):

- [Developer Quickstart](https://tutorial.termx.org/en/developer-quickstart);
- [Installation Guide](https://tutorial.termx.org/en/installation-guide).
- Uncomment "./pgdata:/var/lib/postgresql/data" and map PG database to the local directory (change "./pgdata" if needed) to prevent the data loss on PG container updates.
