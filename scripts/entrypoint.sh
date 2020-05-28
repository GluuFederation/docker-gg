#!/bin/sh

set -e

# ==========
# GG entrypoint
# ==========

python3 /app/scripts/gluu-gateway.py &

# ==========
# kongs entrypoint
# ==========
/docker-entrypoint.sh kong docker-start