FROM kong:1.3.0-alpine

RUN apk update \
    && apk add --no-cache --virtual build-deps unzip

# ============
# Gluu Gateway
# ============

ENV GLUU_VERSION=version_4.0 \
    GG_DEPS=gluu-gateway-node-deps

RUN wget -q https://github.com/GluuFederation/gluu-gateway/raw/${GLUU_VERSION}/${GG_DEPS}.zip -O /tmp/${GG_DEPS}.zip \
    && unzip -q /tmp/${GG_DEPS}.zip -d /tmp \
    && rm -f /tmp/${GG_DEPS}.zip

COPY install-plugins.sh /tmp/
RUN sh /tmp/install-plugins.sh \
    && rm -rf /tmp/install-plugins.sh /tmp/${GG_DEPS}

# ===
# ENV
# ===

# required in kong.conf
ENV KONG_PLUGINS="bundled,gluu-oauth-auth,gluu-uma-auth,gluu-uma-pep,gluu-oauth-pep,gluu-metrics,gluu-openid-connect,gluu-opa-pep"

# =======
# Cleanup
# =======

RUN apk del build-deps
