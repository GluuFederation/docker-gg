#!/usr/bin/env sh

set -e

GG_DEPS=gluu-gateway-node-deps
GG_STUB_DIR=${GG_DEPS}/lib/kong/disable_plugin_stub
GG_THIRD_PARTY=${GG_DEPS}/third-party
LUA_DIST=/usr/local/share/lua/5.1
DISABLED_PLUGINS="ldap-auth key-auth basic-auth hmac-auth jwt oauth2"

mkdir -p ${LUA_DIST}/gluu \
    && cp -R /tmp/${GG_DEPS}/lib/* ${LUA_DIST}/

# third-party deps
cd /tmp/${GG_DEPS}/third-party \
    && cp oxd-web-lua/oxdweb.lua ${LUA_DIST}/gluu/ \
    && mkdir -p ${LUA_DIST}/rucciva \
    && cp json-logic-lua/logic.lua ${LUA_DIST}/rucciva/json_logic.lua \
    && cp -R lua-resty-lrucache/lib/resty/lrucache ${LUA_DIST}/resty/lrucache \
    && cp lua-resty-lrucache/lib/resty/lrucache.lua ${LUA_DIST}/resty/ \
    && cp -R lua-resty-session/lib/resty/session ${LUA_DIST}/resty/session \
    && cp lua-resty-session/lib/resty/session.lua ${LUA_DIST}/resty/ \
    && cp -a lua-resty-jwt/lib/resty/. ${LUA_DIST}/resty/ \
    && cp -a lua-resty-hmac/lib/resty/. ${LUA_DIST}/resty/ \
    && cp nginx-lua-prometheus/prometheus.lua ${LUA_DIST}/

# internal deps
cd /tmp/${GG_DEPS}/lib/kong \
    && cp -R plugins/* ${LUA_DIST}/kong/plugins/

ls ${LUA_DIST}/gluu
#disable builtin plugins
for plugin in ${DISABLED_PLUGINS}; do 
  cp ${LUA_DIST}/gluu/disable-plugin-handler.lua ${LUA_DIST}/kong/plugins/${plugin}/handler.lua; \
  rm -f ${LUA_DIST}/kong/plugins/${plugin}/migrations/*
  rm -f ${LUA_DIST}/kong/plugins/${plugin}/daos.lua
  done
rm ${LUA_DIST}/gluu/disable-plugin-handler.lua
