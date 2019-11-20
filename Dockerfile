FROM kong:1.3.0-alpine

RUN apk update \
    && apk add --no-cache --virtual build-deps unzip

# ============
# Gluu Gateway
# ============

ENV GLUU_VERSION=v4.0.0 \
    GG_DEPS=gluu-gateway-node-deps

RUN wget -q https://github.com/GluuFederation/gluu-gateway/raw/${GLUU_VERSION}/${GG_DEPS}.zip -O /tmp/${GG_DEPS}.zip \
    && unzip -q /tmp/${GG_DEPS}.zip -d /tmp \
    && rm -f /tmp/${GG_DEPS}.zip

COPY install-plugins.sh /tmp/
RUN sh /tmp/install-plugins.sh \
    && rm -rf /tmp/install-plugins.sh /tmp/${GG_DEPS}

# ===========
# Metadata
# ===========

LABEL name="gluu-gateway" \
    maintainer="Gluu Inc. <support@gluu.org>" \
    vendor="Gluu Federation" \
    version="4.0.0" \
    release="01" \
    summary="Gluu gateway " \
    description="Gluu Gateway (GG) is an API gateway that leverages the Gluu Server for central OAuth client management and access control"



# ===
# ENV
# ===

# required in kong.conf
ENV KONG_PLUGINS="bundled,gluu-oauth-auth,gluu-uma-auth,gluu-uma-pep,gluu-oauth-pep,gluu-metrics,gluu-openid-connect,gluu-opa-pep" \
    KONG_NGINX_HTTP_LUA_SHARED_DICT="gluu_metrics 1M"

# =======
# Cleanup
# =======

RUN apk del build-deps
