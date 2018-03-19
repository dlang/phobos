
/// Placed into public domain
/// Author: Walter Bright

// @@@DEPRECATED_2017-06@@@

/++
    $(RED Deprecated. Use $(D core.sys.windows.stat) instead. This module will be
          removed in June 2017.)
  +/
deprecated("Import core.sys.windows.stat instead")
module std.c.windows.stat;

version (Windows):
public import core.sys.windows.stat;
