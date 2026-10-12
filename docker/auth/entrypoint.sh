#!/bin/sh
# Copyright 2026 Rajdeep Das, Institute of Engineering & Management (IEM), Kolkata, India
# SPDX-License-Identifier: Apache-2.0
# Part of ABHED-v1. See the LICENSE and NOTICE files for terms and attribution.
# PowerDNS Authoritative entrypoint: (re)load a PRE-SIGNED zone into gsqlite3 and serve it.
# PowerDNS cannot sign with ML-DSA / MTL, so the zone is signed offline by pqcdns.signer and
# PowerDNS runs in "presigned" mode: it serves RRSIG/NSEC/DNSKEY exactly as provided.
set -eu
: "${ZONE_NAME:?ZONE_NAME required}"          # e.g.  .   lab   iem.lab
: "${ZONE_FILE:?ZONE_FILE required}"          # e.g.  /zones/iem.lab.zone
CONF_DIR="${CONF_DIR:-/etc/powerdns}"
DB="${DB:-/var/lib/powerdns/pdns.sqlite3}"
LISTEN="${LISTEN:-0.0.0.0}"
WEBPORT="${WEBPORT:-8081}"

SCHEMA=$(find / -name 'schema.sqlite3.sql*' -not -path '/proc/*' 2>/dev/null | head -n1)
[ -n "$SCHEMA" ] || { echo "sqlite schema not found"; exit 1; }
mkdir -p "$(dirname "$DB")" "$CONF_DIR" "${SOCKET_DIR:-/var/run/pdns}"
rm -f "$DB"
case "$SCHEMA" in *.gz) zcat "$SCHEMA" ;; *) cat "$SCHEMA" ;; esac | sqlite3 "$DB"

cat > "$CONF_DIR/pdns.conf" <<CONF
launch=gsqlite3
gsqlite3-database=$DB
gsqlite3-dnssec=yes
local-address=$LISTEN
local-port=53
daemon=no
socket-dir=${SOCKET_DIR:-/var/run/pdns}
guardian=no
loglevel=${LOGLEVEL:-4}
# serve large PQC answers: truncate above 1232 over UDP (TC=1), full size over TCP
udp-truncation-threshold=1232
max-tcp-connections=200
webserver=yes
webserver-address=$LISTEN
webserver-port=$WEBPORT
webserver-allow-from=0.0.0.0/0
api=yes
api-key=${API_KEY:-labkey}
CONF

PDNSUTIL="pdnsutil --config-dir=$CONF_DIR"
echo ">> loading $ZONE_FILE as zone '$ZONE_NAME'"
$PDNSUTIL load-zone "$ZONE_NAME" "$ZONE_FILE"
$PDNSUTIL set-presigned "$ZONE_NAME"
$PDNSUTIL rectify-zone "$ZONE_NAME" >/dev/null 2>&1 || true
echo ">> record types loaded:"
$PDNSUTIL list-zone "$ZONE_NAME" 2>/dev/null | awk '{print $4}' | sort | uniq -c | sed 's/^/   /'
[ "${NO_EXEC:-0}" = 1 ] && exit 0
exec pdns_server --config-dir="$CONF_DIR"
