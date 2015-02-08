

/// Please import core.sys.posix.termios instead. This module will be deprecated in DMD 2.068.
module std.c.linux.termios;

version (linux):
public import core.sys.posix.termios;
