
/* Windows is a registered trademark of Microsoft Corporation in the United
States and other countries. */

// @@@DEPRECATED_2017-06@@@

/++
    $(RED Deprecated. Use $(D core.sys.windows.windows) instead. This module will
          be removed in June 2017.)
  +/
deprecated("Import core.sys.windows.windows instead")
module std.c.windows.windows;

version (Windows):
public import core.sys.windows.windows;
