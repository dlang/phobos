// @@@DEPRECATED_2017-06@@@

/++
    $(RED Deprecated. Use $(D core.sys.windows.com) instead. This module will be
          removed in June 2017.)
  +/
deprecated("Import core.sys.windows.com instead")
module std.c.windows.com;

version (Windows):
public import core.sys.windows.com;
