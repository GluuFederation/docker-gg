#!/bin/sh

set -e

# ==========
# GG entrypoint
# ==========

RUN python3 /app/scripts/gluu-gateway.py &

# ==========
# kongs entrypoint
# ==========
/docker-entrypoint.sh kong docker-start