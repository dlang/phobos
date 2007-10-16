# Makefile to build linux D runtime library libphobos2.a and its unittest.
#
# Target:
#	<default> | release
#		-release -O
#	unittest
#		-unittest -release -O
#	debug
#		-g
#	unittest-debug
#		-unittest -g
#
#	release-ln | unittest-ln | debug-ln | unittest-debug
#		build the associated version of the library and create a
#		symlink to it in the phobos directory.
#
#	html
#		Build the documentation
#
#	all
#		equivalent to 'release unittest debug unittest-debug html'
#
#	clean
#		Delete all files produced by the build process

release unittest debug unittest-debug :
	@mkdir --parents objdir-$@
	@$(MAKE) --no-print-directory -C objdir-$@ -f ../linux-2.mak DMD=$(DMD) $@

all : release unittest debug unittest-debug html

%-ln : %
	ln -sf objdir-$*/libphobos2.a .
html :
	@$(MAKE) -f linux-2.mak DMD=$(DMD) html

clean :
	$(RM) -r objdir*

