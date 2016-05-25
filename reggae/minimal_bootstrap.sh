#!/usr/bin/env bash
# could also use rdmd like this:
# rdmd --build-only -version=reggaelib -version=minimal -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae reggaefile.d -b binary .
# This script doesn't just so it doesn't have to depend on rdmd being available

echo "HOST_DC: $HOST_DC"
$HOST_DC -conf= -I../../druntime/import -version=minimal -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae src/reggae/{reggae_main,reggae}.d payload/reggae/{options,types,build,config,file,ctaa,range,sorting,dependencies}.d payload/reggae/rules/{package,d,common}.d payload/reggae/core/rules/package.d

