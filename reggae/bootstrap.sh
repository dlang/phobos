#!/usr/bin/env bash
#1st parameter is the backend to use (e.g. make, ninja)

dmd -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae src/reggae/*.d src/reggae/dub/*.d payload/reggae/backend/*.d payload/reggae/{options,reflect,config,build,types,sorting,dependencies,range,buildgen,package,ctaa,file}.d payload/reggae/rules/*.d payload/reggae/core/*.d payload/reggae/core/rules/*.d payload/reggae/dub/info.d
