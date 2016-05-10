include ../osmodel.mak

ifeq ($(OS),osx)
  BOOTSTRAP_DMD:=dmd2/$(OS)/bin/dmd
else
  BOOTSTRAP_DMD:=dmd2/$(OS)/bin$(MODEL)/dmd
endif

all: reggae

ZIPFILENAME:=dmd.2.070.2.$(OS)

ifeq ($(OS),freebsd)
   ZIPFILENAME:=dmd.2.070.2.$(OS)-$(MODEL)
endif

reggae: dmd2
	$(BOOTSTRAP_DMD) -version=minimal -ofbin/reggae -Isrc -Ipayload -Jpayload/reggae $(addprefix src/reggae/,reggae_main.d reggae.d) $(addprefix payload/reggae/,options.d types.d build.d config.d file.d ctaa.d range.d sorting.d dependencies.d) $(addprefix payload/reggae/rules/, package.d d.d common.d) payload/reggae/core/rules/package.d


dmd.zip:
	curl -fsSL --retry 3 http://downloads.dlang.org/releases/2.x/2.070.2/$(ZIPFILENAME).zip > dmd.zip

dmd2: dmd.zip
	unzip dmd.zip
