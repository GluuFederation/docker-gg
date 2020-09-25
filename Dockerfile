FROM alpine:3.10 AS build

RUN apk update \
    && apk add -Uuv --no-cache git

ENV GLUU_GATEWAY_VERSION=version_4.2.1
ENV GLUU_GATEWAY_COMMIT_ID=97ae430e3a1f32e9c50dcabe3223e32c748d9f01

RUN git clone --recursive --depth 1 --branch ${GLUU_GATEWAY_VERSION} https://github.com/GluuFederation/gluu-gateway.git /tmp/
# place all required Lua files in /tmp/lib
# it would allow to copy it with one COPY directive later
RUN cp -r /tmp/third-party/lua-resty-hmac/lib/. /tmp/lib/
RUN cp -r /tmp/third-party/lua-resty-jwt/lib/. /tmp/lib/
RUN cp -r /tmp/third-party/lua-resty-lrucache/lib/. /tmp/lib/
RUN cp -r /tmp/third-party/lua-resty-session/lib/. /tmp/lib/
RUN mkdir /tmp/lib/rucciva && cp /tmp/third-party/json-logic-lua/logic.lua /tmp/lib/rucciva/json_logic.lua
RUN cp /tmp/third-party/oxd-web-lua/oxdweb.lua /tmp/lib/gluu/
RUN cp /tmp/third-party/nginx-lua-prometheus/prometheus.lua /tmp/lib/

# ============
# Main image
# ============

FROM kong:2.1.1-alpine

ENV LUA_DIST=/usr/local/share/lua/5.1 \
    DISABLED_PLUGINS="ldap-auth key-auth basic-auth hmac-auth jwt oauth2"

# ============
# Gluu Gateway
# ============
# ===
# ENV
# ===
ENV GLUU_GATEWAY_NAMESPACE="kong" \
    GLUU_GATEWAY_KONG_CONF_SECRET_NAME="kong-config" \
    GLUU_GATEWAY_KONG_DBLESS_CONF_INTERVAL_CHECK=60 \
    GLUU_GATEWAY_KONG_DECLARATIVE_CONFIG="/gg/kong.yml" \
    GLUU_PLUGINS="gluu-oauth-auth,gluu-uma-auth,gluu-uma-pep,gluu-oauth-pep,gluu-metrics,gluu-openid-connect,gluu-opa-pep"
# by default enable all bundled and gluu plugins
ENV KONG_PLUGINS="bundled,"$GLUU_PLUGINS \
    KONG_DATABASE="off" \
    # required in kong.conf
    KONG_NGINX_HTTP_LUA_SHARED_DICT="gluu_metrics 1M"


#redirect all logs to Docker
ENV KONG_PROXY_ACCESS_LOG=/dev/stdout \
    KONG_ADMIN_ACCESS_LOG=/dev/stdout \
    KONG_PROXY_ERROR_LOG=/dev/stderr \
    KONG_ADMIN_ERROR_LOG=/dev/stderr \
    KONG_NGINX_HTTP_LARGE_CLIENT_HEADER_BUFFERS="8 16k"

# require root rights to replace/remove some existing Kong files
USER root

# ============
# Python3
# ============
RUN apk add --no-cache --virtual .build-deps g++ python3-dev libffi-dev openssl-dev && \
    apk add --no-cache --update python3 && \
    pip3 install --upgrade pip setuptools \
    && pip3 install requests kubernetes psutil

COPY --from=build  /tmp/lib/ ${LUA_DIST}/
RUN mkdir gg
COPY scripts /gg/scripts

RUN for plugin in ${DISABLED_PLUGINS}; do \
  cp ${LUA_DIST}/gluu/disable-plugin-handler.lua ${LUA_DIST}/kong/plugins/${plugin}/handler.lua; \
  rm -f ${LUA_DIST}/kong/plugins/${plugin}/migrations/*; \
  rm -f ${LUA_DIST}/kong/plugins/${plugin}/daos.lua; \
  done && \
  rm ${LUA_DIST}/gluu/disable-plugin-handler.lua
RUN chown -R 1000:1000 /gg \
    && chgrp -R 0 /gg  && chmod -R g=u /gg \
    && chmod +x /gg/scripts/entrypoint.sh \
    && chmod +x /gg/scripts/gluu-gateway.py

USER kong
#============
# Metadata
# ===========
LABEL name="gluu-gateway" \
    maintainer="Gluu Inc. <support@gluu.org>" \
    vendor="Gluu Federation" \
    version="4.2.1" \
    release="02" \
    summary="Gluu gateway " \
    description="Gluu Gateway (GG) is an API gateway that leverages the Gluu Server for central OAuth client management and access control"

ENTRYPOINT ["/gg/scripts/entrypoint.sh"]
