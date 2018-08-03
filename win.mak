######################################################

zip:
	del phobos.zip
	zip32 -r phobos.zip . -x .git\* -x \*.lib -x \*.obj

phobos.zip : zip

clean:
	cd etc\c\zlib
	$(MAKE) -f win$(MODEL).mak clean
	cd ..\..\..
	del $(DOCS)
	del $(UNITTEST_OBJS) unittest.obj unittest.exe
	del $(LIB)
	del phobos.json

install: phobos.zip
	$(CP) phobos.lib phobos64.lib $(DIR)\windows\lib
	+rd/s/q $(DIR)\src\phobos
	unzip -o phobos.zip -d $(DIR)\src\phobos

auto-tester-build: targets

JOBS=$(NUMBER_OF_PROCESSORS)
GMAKE=gmake

auto-tester-test:
	$(GMAKE) -j$(JOBS) -f posix.mak unittest BUILD=release DMD="$(DMD)" OS=win$(MODEL) \
	CUSTOM_DRUNTIME=1 PIC=0 MODEL=$(MODEL) DRUNTIME=$(DRUNTIMELIB) CC=$(CC)
