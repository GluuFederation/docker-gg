FROM kong:1.3.0-alpine

RUN apk update \
    && apk add -Uuv --no-cache --virtual build-deps git  

# ============
# Gluu Gateway
# ============

ENV GLUU_VERSION=version_4.1 \
    GG_DEPS=gluu-gateway-node-deps

RUN git clone --single-branch --branch ${GLUU_VERSION} https://github.com/GluuFederation/gluu-gateway.git /tmp/${GG_DEPS} 

COPY gitmodules /tmp/${GG_DEPS}

RUN cd /tmp/${GG_DEPS} \
    && cat gitmodules > .gitmodules \
    && git submodule update --init --recursive \
    && rm -rf Dockerfile .dockerignore .gitignore

COPY install-plugins.sh /tmp/
RUN sh /tmp/install-plugins.sh \
    && rm -rf /tmp/install-plugins.sh /tmp/${GG_DEPS}

# ===========
# Metadata
# ===========

LABEL name="gluu-gateway" \
    maintainer="Gluu Inc. <support@gluu.org>" \
    vendor="Gluu Federation" \
    version="4.1.0" \
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

# =======
# Cleanup
# =======

RUN apk del build-deps
