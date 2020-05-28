#!/bin/sh

set -e

# ==========
# GG entrypoint
# ==========

python3 /gg/scripts/gluu-gateway.py &

# ==========
# kongs entrypoint
# ==========
/docker-entrypoint.sh kong docker-start