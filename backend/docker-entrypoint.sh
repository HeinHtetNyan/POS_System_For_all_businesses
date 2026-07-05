#!/bin/sh
set -e

# ./uploads and ./logs are bind-mounted from the host. Docker creates missing
# bind-mount source dirs as root:root 755, which shadows the appuser ownership
# baked into the image — appuser then can't mkdir new subdirs (e.g. logos/,
# payment-icons/) under them. Fix ownership on every start, then drop to appuser.
mkdir -p /app/uploads/logos /app/uploads/payment-icons /app/uploads/proofs /app/logs
chown -R appuser:appgroup /app/uploads /app/logs

# Migrations run once, from the api container only (identified by its uvicorn
# command) — celery_worker/celery_beat share this same entrypoint/image but
# must not race the api container applying the same migration concurrently.
# set -e above means a failed migration stops the container instead of
# silently serving requests against a broken/partial schema.
if [ "$1" = "uvicorn" ]; then
    gosu appuser alembic upgrade head
fi

exec gosu appuser "$@"
