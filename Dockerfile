FROM alpine:3.10 AS build

RUN apk update \
    && apk add -Uuv --no-cache git

ENV GLUU_GG_VERSION=version_4.2

RUN git clone --recursive --depth 1 --branch ${GLUU_GG_VERSION} https://github.com/GluuFederation/gluu-gateway.git /tmp/
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

FROM kong:2.0.1-alpine

ENV LUA_DIST=/usr/local/share/lua/5.1
ENV DISABLED_PLUGINS="ldap-auth key-auth basic-auth hmac-auth jwt oauth2"

# ============
# Gluu Gateway
# ============

# require root rights to replace/remove some existing Kong files
USER root

COPY --from=build  /tmp/lib/ ${LUA_DIST}/

RUN for plugin in ${DISABLED_PLUGINS}; do \
  cp ${LUA_DIST}/gluu/disable-plugin-handler.lua ${LUA_DIST}/kong/plugins/${plugin}/handler.lua; \
  rm -f ${LUA_DIST}/kong/plugins/${plugin}/migrations/*; \
  rm -f ${LUA_DIST}/kong/plugins/${plugin}/daos.lua; \
  done && \
  rm ${LUA_DIST}/gluu/disable-plugin-handler.lua

# restore
USER kong

#===========
# Metadata
# ===========

LABEL name="gluu-gateway" \
    maintainer="Gluu Inc. <support@gluu.org>" \
    vendor="Gluu Federation" \
    version="4.2.0" \
    release="dev" \
    summary="Gluu gateway " \
    description="Gluu Gateway (GG) is an API gateway that leverages the Gluu Server for central OAuth client management and access control"


# ===
# ENV
# ===

# by default enable all bundled and gluu plugins
ENV KONG_PLUGINS="bundled,gluu-oauth-auth,gluu-uma-auth,gluu-uma-pep,gluu-oauth-pep,gluu-metrics,gluu-openid-connect,gluu-opa-pep" \
    # required in kong.conf
    KONG_NGINX_HTTP_LUA_SHARED_DICT="gluu_metrics 1M"

#redirect all logs to Docker
ENV KONG_PROXY_ACCESS_LOG=/dev/stdout \
    KONG_ADMIN_ACCESS_LOG=/dev/stdout \
    KONG_PROXY_ERROR_LOG=/dev/stderr \
    KONG_ADMIN_ERROR_LOG=/dev/stderr \
    KONG_NGINX_HTTP_LARGE_CLIENT_HEADER_BUFFERS="8 16k"
