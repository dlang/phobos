// Written in the D programming language.

/** This module is used to manipulate _path strings.

    All functions, with the exception of $(LREF expandTilde) (and in some
    cases $(LREF absolutePath) and $(LREF relativePath)), are pure
    string manipulation functions; they don't depend on any state outside
    the program, nor do they perform any actual file system actions.
    This has the consequence that the module does not make any distinction
    between a _path that points to a directory and a _path that points to a
    file, and it does not know whether or not the object pointed to by the
    _path actually exists in the file system.
    To differentiate between these cases, use $(XREF file,isDir) and
    $(XREF file,exists).

    Note that on Windows, both the backslash ($(D `\`)) and the slash ($(D `/`))
    are in principle valid directory separators.  This module treats them
    both on equal footing, but in cases where a $(I new) separator is
    added, a backslash will be used.  Furthermore, the $(LREF buildNormalizedPath)
    function will replace all slashes with backslashes on that platform.

    In general, the functions in this module assume that the input paths
    are well-formed.  (That is, they should not contain invalid characters,
    they should follow the file system's _path format, etc.)  The result
    of calling a function on an ill-formed _path is undefined.  When there
    is a chance that a _path or a file name is invalid (for instance, when it
    has been input by the user), it may sometimes be desirable to use the
    $(LREF isValidFilename) and $(LREF isValidPath) functions to check
    this.

    Most functions do not perform any memory allocations, and if a string is
    returned, it is usually a slice of an input string.  If a function
    allocates, this is explicitly mentioned in the documentation.

    Authors:
        Lars Tandle Kyllingstad,
        $(WEB digitalmars.com, Walter Bright),
        Grzegorz Adam Hankiewicz,
        Thomas Kühne,
        $(WEB erdani.org, Andrei Alexandrescu)
    Copyright:
        Copyright (c) 2000–2011, the authors. All rights reserved.
    License:
        $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:
        $(PHOBOSSRC std/_path.d)
    Macros:
        WIKI = Phobos/StdPath
*/
module std.path;


import std.algorithm;
import std.array;
import std.conv;
import std.file: getcwd;
import std.string;
import std.traits;

version(Posix)
{
    import core.exception;
    import core.stdc.errno;
    import core.sys.posix.pwd;
    import core.sys.posix.stdlib;
    private import core.exception : onOutOfMemoryError;
}




/** String used to separate directory names in a path.  Under
    POSIX this is a slash, under Windows a backslash.
*/
version(Posix)          enum string dirSeparator = "/";
else version(Windows)   enum string dirSeparator = "\\";
else static assert (0, "unsupported platform");




/** Path separator string.  A colon under POSIX, a semicolon
    under Windows.
*/
version(Posix)          enum string pathSeparator = ":";
else version(Windows)   enum string pathSeparator = ";";
else static assert (0, "unsupported platform");




/** Determines whether the given character is a directory separator.

    On Windows, this includes both $(D `\`) and $(D `/`).
    On POSIX, it's just $(D `/`).
*/
bool isDirSeparator(dchar c)  @safe pure nothrow
{
    if (c == '/') return true;
    version(Windows) if (c == '\\') return true;
    return false;
}


/*  Determines whether the given character is a drive separator.

    On Windows, this is true if c is the ':' character that separates
    the drive letter from the rest of the path.  On POSIX, this always
    returns false.
*/
private bool isDriveSeparator(dchar c)  @safe pure nothrow
{
    version(Windows) return c == ':';
    else return false;
}


/*  Combines the isDirSeparator and isDriveSeparator tests. */
version(Windows) private bool isSeparator(dchar c)  @safe pure nothrow
{
    return isDirSeparator(c) || isDriveSeparator(c);
}
version(Posix) private alias isDirSeparator isSeparator;


/*  Helper function that determines the position of the last
    drive/directory separator in a string.  Returns -1 if none
    is found.
*/
private ptrdiff_t lastSeparator(C)(in C[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    auto i = (cast(ptrdiff_t) path.length) - 1;
    while (i >= 0 && !isSeparator(path[i])) --i;
    return i;
}


version (Windows)
{
    private bool isUNC(C)(in C[] path) @safe pure nothrow  if (isSomeChar!C)
    {
        return path.length >= 3 && isDirSeparator(path[0]) && isDirSeparator(path[1])
            && !isDirSeparator(path[2]);
    }

    private ptrdiff_t uncRootLength(C)(in C[] path) @safe pure nothrow  if (isSomeChar!C)
        in { assert (isUNC(path)); }
        body
    {
        ptrdiff_t i = 3;
        while (i < path.length && !isDirSeparator(path[i])) ++i;
        if (i < path.length)
        {
            auto j = i;
            do { ++j; } while (j < path.length && isDirSeparator(path[j]));
            if (j < path.length)
            {
                do { ++j; } while (j < path.length && !isDirSeparator(path[j]));
                i = j;
            }
        }
        return i;
    }

    private bool hasDrive(C)(in C[] path)  @safe pure nothrow  if (isSomeChar!C)
    {
        return path.length >= 2 && isDriveSeparator(path[1]);
    }

    private bool isDriveRoot(C)(in C[] path)  @safe pure nothrow  if (isSomeChar!C)
    {
        return path.length >= 3 && isDriveSeparator(path[1])
            && isDirSeparator(path[2]);
    }
}


/*  Helper functions that strip leading/trailing slashes and backslashes
    from a path.
*/
private inout(C)[] ltrimDirSeparators(C)(inout(C)[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    int i = 0;
    while (i < path.length && isDirSeparator(path[i])) ++i;
    return path[i .. $];
}

private inout(C)[] rtrimDirSeparators(C)(inout(C)[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    auto i = (cast(ptrdiff_t) path.length) - 1;
    while (i >= 0 && isDirSeparator(path[i])) --i;
    return path[0 .. i+1];
}

private inout(C)[] trimDirSeparators(C)(inout(C)[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    return ltrimDirSeparators(rtrimDirSeparators(path));
}




/** This $(D enum) is used as a template argument to functions which
    compare file names, and determines whether the comparison is
    case sensitive or not.
*/
enum CaseSensitive : bool
{
    /// File names are case insensitive
    no = false,

    /// File names are case sensitive
    yes = true,

    /** The default (or most common) setting for the current platform.
        That is, $(D no) on Windows and Mac OS X, and $(D yes) on all
        POSIX systems except OS X (Linux, *BSD, etc.).
    */
    osDefault = osDefaultCaseSensitivity
}
version (Windows)    private enum osDefaultCaseSensitivity = false;
else version (OSX)   private enum osDefaultCaseSensitivity = false;
else version (Posix) private enum osDefaultCaseSensitivity = true;
else static assert (0);




/** Returns the name of a file, without any leading directory
    and with an optional suffix chopped off.

    If $(D suffix) is specified, it will be compared to $(D path)
    using $(D filenameCmp!cs),
    where $(D cs) is an optional template parameter determining whether
    the comparison is case sensitive or not.  See the
    $(LREF filenameCmp) documentation for details.

    Examples:
    ---
    assert (baseName("dir/file.ext")         == "file.ext");
    assert (baseName("dir/file.ext", ".ext") == "file");
    assert (baseName("dir/file.ext", ".xyz") == "file.ext");
    assert (baseName("dir/filename", "name") == "file");
    assert (baseName("dir/subdir/")          == "subdir");

    version (Windows)
    {
        assert (baseName(`d:file.ext`)      == "file.ext");
        assert (baseName(`d:\dir\file.ext`) == "file.ext");
    }
    ---

    Note:
    This function $(I only) strips away the specified suffix, which
    doesn't necessarily have to represent an extension.  If you want
    to remove the extension from a path, regardless of what the extension
    is, use $(LREF stripExtension).
    If you want the filename without leading directories and without
    an extension, combine the functions like this:
    ---
    assert (baseName(stripExtension("dir/file.ext")) == "file");
    ---

    Standards:
    This function complies with
    $(LINK2 http://pubs.opengroup.org/onlinepubs/9699919799/utilities/basename.html,
    the POSIX requirements for the 'basename' shell utility)
    (with suitable adaptations for Windows paths).
*/
inout(C)[] baseName(C)(inout(C)[] path)
    @trusted pure //TODO: nothrow (BUG 5700)
    if (isSomeChar!C)
{
    auto p1 = stripDrive(path);
    if (p1.empty)
    {
        version (Windows) if (isUNC(path))
        {
            return cast(typeof(return)) dirSeparator.dup;
        }
        return null;
    }

    auto p2 = rtrimDirSeparators(p1);
    if (p2.empty) return p1[0 .. 1];

    return p2[lastSeparator(p2)+1 .. $];
}

/// ditto
inout(C)[] baseName(CaseSensitive cs = CaseSensitive.osDefault, C, C1)
    (inout(C)[] path, in C1[] suffix)
    @safe pure //TODO: nothrow (because of filenameCmp())
    if (isSomeChar!C && isSomeChar!C1)
{
    auto p = baseName(path);
    if (p.length > suffix.length
        && filenameCmp!cs(p[$-suffix.length .. $], suffix) == 0)
    {
        return p[0 .. $-suffix.length];
    }
    else return p;
}


unittest
{
    assert (baseName("").empty);
    assert (baseName("file.ext"w) == "file.ext");
    assert (baseName("file.ext"d, ".ext") == "file");
    assert (baseName("file", "file"w.dup) == "file");
    assert (baseName("dir/file.ext"d.dup) == "file.ext");
    assert (baseName("dir/file.ext", ".ext"d) == "file");
    assert (baseName("dir/file"w, "file"d) == "file");
    assert (baseName("dir///subdir////") == "subdir");
    assert (baseName("dir/subdir.ext/", ".ext") == "subdir");
    assert (baseName("dir/subdir/".dup, "subdir") == "subdir");
    assert (baseName("/"w.dup) == "/");
    assert (baseName("//"d.dup) == "/");
    assert (baseName("///") == "/");

    assert (baseName!(CaseSensitive.yes)("file.ext", ".EXT") == "file.ext");
    assert (baseName!(CaseSensitive.no)("file.ext", ".EXT") == "file");

    version (Windows)
    {
        assert (baseName(`dir\file.ext`) == `file.ext`);
        assert (baseName(`dir\file.ext`, `.ext`) == `file`);
        assert (baseName(`dir\file`, `file`) == `file`);
        assert (baseName(`d:file.ext`) == `file.ext`);
        assert (baseName(`d:file.ext`, `.ext`) == `file`);
        assert (baseName(`d:file`, `file`) == `file`);
        assert (baseName(`dir\\subdir\\\`) == `subdir`);
        assert (baseName(`dir\subdir.ext\`, `.ext`) == `subdir`);
        assert (baseName(`dir\subdir\`, `subdir`) == `subdir`);
        assert (baseName(`\`) == `\`);
        assert (baseName(`\\`) == `\`);
        assert (baseName(`\\\`) == `\`);
        assert (baseName(`d:\`) == `\`);
        assert (baseName(`d:`).empty);
        assert (baseName(`\\server\share\file`) == `file`);
        assert (baseName(`\\server\share\`) == `\`);
        assert (baseName(`\\server\share`) == `\`);
    }

    assert (baseName(stripExtension("dir/file.ext")) == "file");

    static assert (baseName("dir/file.ext") == "file.ext");
    static assert (baseName("dir/file.ext", ".ext") == "file");
}




/** Returns the directory part of a path.  On Windows, this
    includes the drive letter if present.

    This function performs a memory allocation if and only if $(D path)
    is mutable and does not have a directory (in which case a new mutable
    string is needed to hold the returned current-directory symbol,
    $(D ".")).

    Examples:
    ---
    assert (dirName("file")        == ".");
    assert (dirName("dir/file")    == "dir");
    assert (dirName("/file")       == "/");
    assert (dirName("dir/subdir/") == "dir");

    version (Windows)
    {
        assert (dirName("d:file")      == "d:");
        assert (dirName(`d:\dir\file`) == `d:\dir`);
        assert (dirName(`d:\file`)     == `d:\`);
        assert (dirName(`dir\subdir\`) == `dir`);
    }
    ---

    Standards:
    This function complies with
    $(LINK2 http://pubs.opengroup.org/onlinepubs/9699919799/utilities/dirname.html,
    the POSIX requirements for the 'dirname' shell utility)
    (with suitable adaptations for Windows paths).
*/
C[] dirName(C)(C[] path)
    //TODO: @safe (BUG 6169) pure nothrow (because of to())
    if (isSomeChar!C)
{
    if (path.empty) return to!(typeof(return))(".");

    auto p = rtrimDirSeparators(path);
    if (p.empty) return path[0 .. 1];

    version (Windows)
    {
        if (isUNC(p) && uncRootLength(p) == p.length)
            return p;
        if (p.length == 2 && isDriveSeparator(p[1]) && path.length > 2)
            return path[0 .. 3];
    }

    auto i = lastSeparator(p);
    if (i == -1) return to!(typeof(return))(".");
    if (i == 0) return p[0 .. 1];

    version (Windows)
    {
        // If the directory part is either d: or d:\, don't
        // chop off the last symbol.
        if (isDriveSeparator(p[i]) || isDriveSeparator(p[i-1]))
            return p[0 .. i+1];
    }

    // Remove any remaining trailing (back)slashes.
    return rtrimDirSeparators(p[0 .. i]);
}


unittest
{
    assert (dirName("") == ".");
    assert (dirName("file"w) == ".");
    assert (dirName("dir/"d) == ".");
    assert (dirName("dir///") == ".");
    assert (dirName("dir/file"w.dup) == "dir");
    assert (dirName("dir///file"d.dup) == "dir");
    assert (dirName("dir/subdir/") == "dir");
    assert (dirName("/dir/file"w) == "/dir");
    assert (dirName("/file"d) == "/");
    assert (dirName("/") == "/");
    assert (dirName("///") == "/");

    version (Windows)
    {
        assert (dirName(`dir\`) == `.`);
        assert (dirName(`dir\\\`) == `.`);
        assert (dirName(`dir\file`) == `dir`);
        assert (dirName(`dir\\\file`) == `dir`);
        assert (dirName(`dir\subdir\`) == `dir`);
        assert (dirName(`\dir\file`) == `\dir`);
        assert (dirName(`\file`) == `\`);
        assert (dirName(`\`) == `\`);
        assert (dirName(`\\\`) == `\`);
        assert (dirName(`d:`) == `d:`);
        assert (dirName(`d:file`) == `d:`);
        assert (dirName(`d:\`) == `d:\`);
        assert (dirName(`d:\file`) == `d:\`);
        assert (dirName(`d:\dir\file`) == `d:\dir`);
        assert (dirName(`\\server\share\dir\file`) == `\\server\share\dir`);
        assert (dirName(`\\server\share\file`) == `\\server\share`);
        assert (dirName(`\\server\share\`) == `\\server\share`);
        assert (dirName(`\\server\share`) == `\\server\share`);
    }

    static assert (dirName("dir/file") == "dir");
}




/** Returns the root directory of the specified path, or $(D null) if the
    path is not rooted.

    Examples:
    ---
    assert (rootName("foo") is null);
    assert (rootName("/foo") == "/");

    version (Windows)
    {
        assert (rootName(`\foo`) == `\`);
        assert (rootName(`c:\foo`) == `c:\`);
        assert (rootName(`\\server\share\foo`) == `\\server\share`);
    }
    ---
*/
inout(C)[] rootName(C)(inout(C)[] path)  @safe pure nothrow  if (isSomeChar!C)
{
    if (path.empty) return null;

    version (Posix)
    {
        if (isDirSeparator(path[0])) return path[0 .. 1];
    }
    else version (Windows)
    {
        if (isDirSeparator(path[0]))
        {
            if (isUNC(path)) return path[0 .. uncRootLength(path)];
            else return path[0 .. 1];
        }
        else if (path.length >= 3 && isDriveSeparator(path[1]) &&
            isDirSeparator(path[2]))
        {
            return path[0 .. 3];
        }
    }
    else static assert (0, "unsupported platform");

    assert (!isRooted(path));
    return null;
}


unittest
{
    assert (rootName("") is null);
    assert (rootName("foo") is null);
    assert (rootName("/") == "/");
    assert (rootName("/foo/bar") == "/");

    version (Windows)
    {
        assert (rootName("d:foo") is null);
        assert (rootName(`d:\foo`) == `d:\`);
        assert (rootName(`\\server\share\foo`) == `\\server\share`);
        assert (rootName(`\\server\share`) == `\\server\share`);
    }
}




/** Returns the drive of a path, or $(D null) if the drive
    is not specified.  In the case of UNC paths, the network share
    is returned.

    Always returns $(D null) on POSIX.

    Examples:
    ---
    version (Windows)
    {
        assert (driveName(`d:\file`) == "d:");
        assert (driveName(`\\server\share\file`) == `\\server\share`);
        assert (driveName(`dir\file`).empty);
    }
    ---
*/
inout(C)[] driveName(C)(inout(C)[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    version (Windows)
    {
        if (hasDrive(path))
            return path[0 .. 2];
        else if (isUNC(path))
            return path[0 .. uncRootLength(path)];
    }
    return null;
}


unittest
{
    version (Posix)  assert (driveName("c:/foo").empty);
    version (Windows)
    {
        assert (driveName(`dir\file`).empty);
        assert (driveName(`d:file`) == "d:");
        assert (driveName(`d:\file`) == "d:");
        assert (driveName("d:") == "d:");
        assert (driveName(`\\server\share\file`) == `\\server\share`);
        assert (driveName(`\\server\share\`) == `\\server\share`);
        assert (driveName(`\\server\share`) == `\\server\share`);

        static assert (driveName(`d:\file`) == "d:");
    }
}




/** Strips the drive from a Windows path.  On POSIX, the path is returned
    unaltered.

    Example:
    ---
    version (Windows)
    {
        assert (stripDrive(`d:\dir\file`) == `\dir\file`);
        assert (stripDrive(`\\server\share\dir\file`) == `\dir\file`);
    }
    ---
*/
inout(C)[] stripDrive(C)(inout(C)[] path)  @safe pure nothrow  if (isSomeChar!C)
{
    version(Windows)
    {
        if (hasDrive(path))      return path[2 .. $];
        else if (isUNC(path))    return path[uncRootLength(path) .. $];
    }
    return path;
}


unittest
{
    version(Windows)
    {
        assert (stripDrive(`d:\dir\file`) == `\dir\file`);
        assert (stripDrive(`\\server\share\dir\file`) == `\dir\file`);
        static assert (stripDrive(`d:\dir\file`) == `\dir\file`);
    }
    version(Posix)
    {
        assert (stripDrive(`d:\dir\file`) == `d:\dir\file`);
    }
}




/*  Helper function that returns the position of the filename/extension
    separator dot in path.  If not found, returns -1.
*/
private ptrdiff_t extSeparatorPos(C)(in C[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    auto i = (cast(ptrdiff_t) path.length) - 1;
    while (i >= 0 && !isSeparator(path[i]))
    {
        if (path[i] == '.' && i > 0 && !isSeparator(path[i-1])) return i;
        --i;
    }
    return -1;
}




/** Returns the _extension part of a file name, including the dot.

    If there is no _extension, $(D null) is returned.

    Examples:
    ---
    assert (extension("file").empty);
    assert (extension("file.ext")       == ".ext");
    assert (extension("file.ext1.ext2") == ".ext2");
    assert (extension("file.")          == ".");
    assert (extension(".file").empty);
    assert (extension(".file.ext")      == ".ext");
    ---
*/
inout(C)[] extension(C)(inout(C)[] path)  @safe pure nothrow  if (isSomeChar!C)
{
    auto i = extSeparatorPos(path);
    if (i == -1) return null;
    else return path[i .. $];
}


unittest
{
    assert (extension("file").empty);
    assert (extension("file.") == ".");
    assert (extension("file.ext"w) == ".ext");
    assert (extension("file.ext1.ext2"d) == ".ext2");
    assert (extension(".foo".dup).empty);
    assert (extension(".foo.ext"w.dup) == ".ext");

    assert (extension("dir/file"d.dup).empty);
    assert (extension("dir/file.") == ".");
    assert (extension("dir/file.ext") == ".ext");
    assert (extension("dir/file.ext1.ext2"w) == ".ext2");
    assert (extension("dir/.foo"d).empty);
    assert (extension("dir/.foo.ext".dup) == ".ext");

    version(Windows)
    {
        assert (extension(`dir\file`).empty);
        assert (extension(`dir\file.`) == ".");
        assert (extension(`dir\file.ext`) == `.ext`);
        assert (extension(`dir\file.ext1.ext2`) == `.ext2`);
        assert (extension(`dir\.foo`).empty);
        assert (extension(`dir\.foo.ext`) == `.ext`);

        assert (extension(`d:file`).empty);
        assert (extension(`d:file.`) == ".");
        assert (extension(`d:file.ext`) == `.ext`);
        assert (extension(`d:file.ext1.ext2`) == `.ext2`);
        assert (extension(`d:.foo`).empty);
        assert (extension(`d:.foo.ext`) == `.ext`);
    }

    static assert (extension("file").empty);
    static assert (extension("file.ext") == ".ext");
}




/** Returns the path with the extension stripped off.

    Examples:
    ---
    assert (stripExtension("file")           == "file");
    assert (stripExtension("file.ext")       == "file");
    assert (stripExtension("file.ext1.ext2") == "file.ext1");
    assert (stripExtension("file.")          == "file");
    assert (stripExtension(".file")          == ".file");
    assert (stripExtension(".file.ext")      == ".file");
    assert (stripExtension("dir/file.ext")   == "dir/file");
    ---
*/
inout(C)[] stripExtension(C)(inout(C)[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    auto i = extSeparatorPos(path);
    if (i == -1) return path;
    else return path[0 .. i];
}


unittest
{
    assert (stripExtension("file") == "file");
    assert (stripExtension("file.ext"w) == "file");
    assert (stripExtension("file.ext1.ext2"d) == "file.ext1");
    assert (stripExtension(".foo".dup) == ".foo");
    assert (stripExtension(".foo.ext"w.dup) == ".foo");

    assert (stripExtension("dir/file"d.dup) == "dir/file");
    assert (stripExtension("dir/file.ext") == "dir/file");
    assert (stripExtension("dir/file.ext1.ext2"w) == "dir/file.ext1");
    assert (stripExtension("dir/.foo"d) == "dir/.foo");
    assert (stripExtension("dir/.foo.ext".dup) == "dir/.foo");

    version(Windows)
    {
    assert (stripExtension("dir\\file") == "dir\\file");
    assert (stripExtension("dir\\file.ext") == "dir\\file");
    assert (stripExtension("dir\\file.ext1.ext2") == "dir\\file.ext1");
    assert (stripExtension("dir\\.foo") == "dir\\.foo");
    assert (stripExtension("dir\\.foo.ext") == "dir\\.foo");

    assert (stripExtension("d:file") == "d:file");
    assert (stripExtension("d:file.ext") == "d:file");
    assert (stripExtension("d:file.ext1.ext2") == "d:file.ext1");
    assert (stripExtension("d:.foo") == "d:.foo");
    assert (stripExtension("d:.foo.ext") == "d:.foo");
    }

    static assert (stripExtension("file") == "file");
    static assert (stripExtension("file.ext"w) == "file");
}




/** Returns a string containing the _path given by $(D path), but where
    the extension has been set to $(D ext).

    If the filename already has an extension, it is replaced.   If not, the
    extension is simply appended to the filename.  Including a leading dot
    in $(D ext) is optional.

    This function normally allocates a new string (the possible exception
    being the case when path is immutable and doesn't already have an
    extension).

    Examples:
    ---
    assert (setExtension("file", "ext")      == "file.ext");
    assert (setExtension("file", ".ext")     == "file.ext");
    assert (setExtension("file.old", "new")  == "file.new");
    assert (setExtension("file.old", ".new") == "file.new");
    ---
*/
immutable(Unqual!C1)[] setExtension(C1, C2)(in C1[] path, in C2[] ext)
    @trusted pure nothrow
    if (isSomeChar!C1 && !is(C1 == immutable) && is(Unqual!C1 == Unqual!C2))
{
    if (ext.length > 0 && ext[0] == '.')
        return cast(typeof(return))(stripExtension(path)~ext);
    else
        return cast(typeof(return))(stripExtension(path)~'.'~ext);
}

///ditto
immutable(C1)[] setExtension(C1, C2)(immutable(C1)[] path, const(C2)[] ext)
    @trusted pure nothrow
    if (isSomeChar!C1 && is(Unqual!C1 == Unqual!C2))
{
    // Optimised for the case where path is immutable and has no extension
    if (ext.length > 0 && ext[0] == '.') ext = ext[1 .. $];
    auto i = extSeparatorPos(path);
    if (i == -1)
    {
        path ~= '.';
        path ~= ext;
        return path;
    }
    else if (i == path.length - 1)
    {
        path ~= ext;
        return path;
    }
    else
    {
        return cast(typeof(return))(path[0 .. i+1] ~ ext);
    }
}


unittest
{
    assert (setExtension("file", "ext") == "file.ext");
    assert (setExtension("file"w, ".ext"w) == "file.ext");
    assert (setExtension("file."d, "ext"d) == "file.ext");
    assert (setExtension("file.", ".ext") == "file.ext");
    assert (setExtension("file.old"w, "new"w) == "file.new");
    assert (setExtension("file.old"d, ".new"d) == "file.new");

    assert (setExtension("file"w.dup, "ext"w) == "file.ext");
    assert (setExtension("file"w.dup, ".ext"w) == "file.ext");
    assert (setExtension("file."w, "ext"w.dup) == "file.ext");
    assert (setExtension("file."w, ".ext"w.dup) == "file.ext");
    assert (setExtension("file.old"d.dup, "new"d) == "file.new");
    assert (setExtension("file.old"d.dup, ".new"d) == "file.new");

    static assert (setExtension("file", "ext") == "file.ext");
    static assert (setExtension("file.old", "new") == "file.new");

    static assert (setExtension("file"w.dup, "ext"w) == "file.ext");
    static assert (setExtension("file.old"d.dup, "new"d) == "file.new");
}




/** Returns the _path given by $(D path), with the extension given by
    $(D ext) appended if the path doesn't already have one.

    Including the dot in the extension is optional.

    This function always allocates a new string, except in the case when
    path is immutable and already has an extension.

    Examples:
    ---
    assert (defaultExtension("file", "ext")      == "file.ext");
    assert (defaultExtension("file", ".ext")     == "file.ext");
    assert (defaultExtension("file.", "ext")     == "file.");
    assert (defaultExtension("file.old", "new")  == "file.old");
    assert (defaultExtension("file.old", ".new") == "file.old");
    ---
*/
immutable(Unqual!C1)[] defaultExtension(C1, C2)(in C1[] path, in C2[] ext)
    @trusted pure // TODO: nothrow (because of to())
    if (isSomeChar!C1 && is(Unqual!C1 == Unqual!C2))
{
    auto i = extSeparatorPos(path);
    if (i == -1)
    {
        if (ext.length > 0 && ext[0] == '.')
            return cast(typeof(return))(path~ext);
        else
            return cast(typeof(return))(path~'.'~ext);
    }
    else return to!(typeof(return))(path);
}


unittest
{
    assert (defaultExtension("file", "ext") == "file.ext");
    assert (defaultExtension("file", ".ext") == "file.ext");
    assert (defaultExtension("file.", "ext")     == "file.");
    assert (defaultExtension("file.old", "new") == "file.old");
    assert (defaultExtension("file.old", ".new") == "file.old");

    assert (defaultExtension("file"w.dup, "ext"w) == "file.ext");
    assert (defaultExtension("file.old"d.dup, "new"d) == "file.old");

    static assert (defaultExtension("file", "ext") == "file.ext");
    static assert (defaultExtension("file.old", "new") == "file.old");

    static assert (defaultExtension("file"w.dup, "ext"w) == "file.ext");
    static assert (defaultExtension("file.old"d.dup, "new"d) == "file.old");
}




/** Combines one or more path components.

    The given path components are concatenated with each other,
    and if necessary, directory separators are inserted between
    them. If any of the path components are rooted (as defined by
    $(LREF isRooted)) the preceding path components will be dropped.

    This function always allocates memory to hold the resulting path.

    Examples:
    ---
    version (Posix)
    {
        assert (buildPath("foo", "bar", "baz") == "foo/bar/baz");
        assert (buildPath("/foo/", "bar")      == "/foo/bar");
        assert (buildPath("/foo", "/bar")      == "/bar");
    }

    version (Windows)
    {
        assert (buildPath("foo", "bar", "baz") == `foo\bar\baz`);
        assert (buildPath(`c:\foo`, "bar")    == `c:\foo\bar`);
        assert (buildPath("foo", `d:\bar`)    == `d:\bar`);
        assert (buildPath("foo", `\bar`)      == `\bar`);
    }
    ---
*/
immutable(C)[] buildPath(C)(const(C[])[] paths...)
    @safe pure //TODO: nothrow (because of reduce() and to())
    if (isSomeChar!C)
{
    static typeof(return) joinPaths(const(C)[] lhs, const(C)[] rhs)
        @trusted pure //TODO: nothrow (because of to())
    {
        if (rhs.empty) return to!(typeof(return))(lhs);
        if (lhs.empty || isRooted(rhs)) return to!(typeof(return))(rhs);
        if (isDirSeparator(lhs[$-1]) || isDirSeparator(rhs[0]))
            return cast(typeof(return))(lhs ~ rhs);
        else
            return cast(typeof(return))(lhs ~ dirSeparator ~ rhs);
    }

    return to!(typeof(return))(reduce!joinPaths(paths));
}


unittest
{
    version (Posix)
    {
        assert (buildPath("foo") == "foo");
        assert (buildPath("/foo/") == "/foo/");
        assert (buildPath("foo", "bar") == "foo/bar");
        assert (buildPath("foo", "bar", "baz") == "foo/bar/baz");
        assert (buildPath("foo/".dup, "bar") == "foo/bar");
        assert (buildPath("foo///", "bar".dup) == "foo///bar");
        assert (buildPath("/foo"w, "bar"w) == "/foo/bar");
        assert (buildPath("foo"w.dup, "/bar"w) == "/bar");
        assert (buildPath("foo"w, "bar/"w.dup) == "foo/bar/");
        assert (buildPath("/"d, "foo"d) == "/foo");
        assert (buildPath(""d.dup, "foo"d) == "foo");
        assert (buildPath("foo"d, ""d.dup) == "foo");
        assert (buildPath("foo", "bar".dup, "baz") == "foo/bar/baz");
        assert (buildPath("foo"w, "/bar"w, "baz"w.dup) == "/bar/baz");

        static assert (buildPath("foo", "bar", "baz") == "foo/bar/baz");
        static assert (buildPath("foo", "/bar", "baz") == "/bar/baz");
    }
    version (Windows)
    {
        assert (buildPath("foo") == "foo");
        assert (buildPath(`\foo/`) == `\foo/`);
        assert (buildPath("foo", "bar", "baz") == `foo\bar\baz`);
        assert (buildPath("foo", `\bar`) == `\bar`);
        assert (buildPath(`c:\foo`, "bar") == `c:\foo\bar`);
        assert (buildPath("foo"w, `d:\bar`w.dup) ==  `d:\bar`);

        static assert (buildPath("foo", "bar", "baz") == `foo\bar\baz`);
        static assert (buildPath("foo", `c:\bar`, "baz") == `c:\bar\baz`);
    }
}

unittest
{
    // Test for issue 7397
    string[] ary = ["a", "b"];
    version (Posix)
    {
        assert (buildPath(ary) == "a/b");
    }
    else version (Windows)
    {
        assert (buildPath(ary) == `a\b`);
    }
}



/** Performs the same task as $(LREF buildPath),
    while at the same time resolving current/parent directory
    symbols ($(D ".") and $(D "..")) and removing superfluous
    directory separators.
    On Windows, slashes are replaced with backslashes.

    Note that this function does not resolve symbolic links.

    This function always allocates memory to hold the resulting path.

    Examples:
    ---
    version (Posix)
    {
        assert (buildNormalizedPath("/foo/./bar/..//baz/") == "/foo/baz");
        assert (buildNormalizedPath("../foo/.") == "../foo");
        assert (buildNormalizedPath("/foo", "bar/baz/") == "/foo/bar/baz");
        assert (buildNormalizedPath("/foo", "/bar/..", "baz") == "/baz");
        assert (buildNormalizedPath("foo/./bar", "../../", "../baz") == "../baz");
        assert (buildNormalizedPath("/foo/./bar", "../../baz") == "/baz");
    }

    version (Windows)
    {
        assert (buildNormalizedPath(`c:\foo\.\bar/..\\baz\`) == `c:\foo\baz`);
        assert (buildNormalizedPath(`..\foo\.`) == `..\foo`);
        assert (buildNormalizedPath(`c:\foo`, `bar\baz\`) == `c:\foo\bar\baz`);
        assert (buildNormalizedPath(`c:\foo`, `bar/..`) == `c:\foo`);
        assert (buildNormalizedPath(`\\server\share\foo`, `..\bar`) == `\\server\share\bar`);
    }
    ---
*/
immutable(C)[] buildNormalizedPath(C)(const(C[])[] paths...)
    @trusted pure nothrow
    if (isSomeChar!C)
{
    import std.c.stdlib;
    auto paths2 = new const(C)[][](paths.length);
        //(cast(const(C)[]*)alloca((const(C)[]).sizeof * paths.length))[0 .. paths.length];

    // Check whether the resulting path will be absolute or rooted,
    // calculate its maximum length, and discard segments we won't use.
    typeof(paths[0][0])[] rootElement;
    int numPaths = 0;
    bool seenAbsolute;
    size_t segmentLengthSum = 0;
    foreach (i; 0 .. paths.length)
    {
        auto p = paths[i];
        if (p.empty) continue;
        else if (isRooted(p))
        {
            immutable thisIsAbsolute = isAbsolute(p);
            if (thisIsAbsolute || !seenAbsolute)
            {
                if (thisIsAbsolute) seenAbsolute = true;
                rootElement = rootName(p);
                paths2[0] = p[rootElement.length .. $];
                numPaths = 1;
                segmentLengthSum = paths2[0].length;
            }
            else
            {
                paths2[0] = p;
                numPaths = 1;
                segmentLengthSum = p.length;
            }
        }
        else
        {
            paths2[numPaths++] = p;
            segmentLengthSum += p.length;
        }
    }
    if (rootElement.length + segmentLengthSum == 0) return null;
    paths2 = paths2[0 .. numPaths];
    immutable rooted = !rootElement.empty;
    assert (rooted || !seenAbsolute); // absolute => rooted

    // Allocate memory for the resulting path, including room for
    // extra dir separators
    auto fullPath = new C[rootElement.length + segmentLengthSum + paths2.length];

    // Copy the root element into fullPath, and let relPart be
    // the remaining slice.
    typeof(fullPath) relPart;
    if (rooted)
    {
        // For Windows, we also need to perform normalization on
        // the root element.
        version (Posix)
        {
            fullPath[0 .. rootElement.length] = rootElement[];
        }
        else version (Windows)
        {
            foreach (i, c; rootElement)
            {
                if (isDirSeparator(c))
                {
                    static assert (dirSeparator.length == 1);
                    fullPath[i] = dirSeparator[0];
                }
                else fullPath[i] = c;
            }
        }
        else static assert (0);

        // If the root element doesn't end with a dir separator,
        // we add one.
        if (!isDirSeparator(rootElement[$-1]))
        {
            static assert (dirSeparator.length == 1);
            fullPath[rootElement.length] = dirSeparator[0];
            relPart = fullPath[rootElement.length + 1 .. $];
        }
        else
        {
            relPart = fullPath[rootElement.length .. $];
        }
    }
    else relPart = fullPath;

    // Now, we have ensured that all segments in path are relative to the
    // root we found earlier.
    bool hasParents = rooted;
    ptrdiff_t i;
    foreach (path; paths2)
    {
        path = trimDirSeparators(path);

        enum Prev { nonSpecial, dirSep, dot, doubleDot }
        Prev prev = Prev.dirSep;
        foreach (j; 0 .. path.length+1)
        {
            // Fake a dir separator between path segments
            immutable c = (j == path.length ? dirSeparator[0] : path[j]);

            if (isDirSeparator(c))
            {
                final switch (prev)
                {
                    case Prev.doubleDot:
                        if (hasParents)
                        {
                            while (i > 0 && !isDirSeparator(relPart[i-1])) --i;
                            if (i > 0) --i; // skip the dir separator
                            while (i > 0 && !isDirSeparator(relPart[i-1])) --i;
                            if (i == 0) hasParents = rooted;
                        }
                        else
                        {
                            relPart[i++] = '.';
                            relPart[i++] = '.';
                            static assert (dirSeparator.length == 1);
                            relPart[i++] = dirSeparator[0];
                        }
                        break;
                    case Prev.dot:
                        while (i > 0 && !isDirSeparator(relPart[i-1])) --i;
                        break;
                    case Prev.nonSpecial:
                        static assert (dirSeparator.length == 1);
                        relPart[i++] = dirSeparator[0];
                        hasParents = true;
                        break;
                    case Prev.dirSep:
                        break;
                }
                prev = Prev.dirSep;
            }
            else if (c == '.')
            {
                final switch (prev)
                {
                    case Prev.dirSep:
                        prev = Prev.dot;
                        break;
                    case Prev.dot:
                        prev = Prev.doubleDot;
                        break;
                    case Prev.doubleDot:
                        prev = Prev.nonSpecial;
                        relPart[i .. i+3] = "...";
                        i += 3;
                        break;
                    case Prev.nonSpecial:
                        relPart[i] = '.';
                        ++i;
                        break;
                }
            }
            else
            {
                final switch (prev)
                {
                    case Prev.doubleDot:
                        relPart[i] = '.';
                        ++i;
                        goto case;
                    case Prev.dot:
                        relPart[i] = '.';
                        ++i;
                        break;
                    case Prev.dirSep:       break;
                    case Prev.nonSpecial:   break;
                }
                relPart[i] = c;
                ++i;
                prev = Prev.nonSpecial;
            }
        }
    }

    // Return path, including root element and excluding the
    // final dir separator.
    immutable len = (relPart.ptr - fullPath.ptr) + (i > 0 ? i - 1 : 0);
    fullPath = fullPath[0 .. len];
    version (Windows)
    {
        // On Windows, if the path is on the form `\\server\share`,
        // with no further segments, normalization will have turned it
        // into `\\server\share\`.  If so, we need to remove the final
        // backslash.
        if (isUNC(fullPath) && uncRootLength(fullPath) == fullPath.length - 1)
            fullPath = fullPath[0 .. $-1];
    }
    return cast(typeof(return)) fullPath;
}

unittest
{
    assert (buildNormalizedPath("") is null);
    assert (buildNormalizedPath("foo") == "foo");

    version (Posix)
    {
        assert (buildNormalizedPath("/", "foo", "bar") == "/foo/bar");
        assert (buildNormalizedPath("foo", "bar", "baz") == "foo/bar/baz");
        assert (buildNormalizedPath("foo", "bar/baz") == "foo/bar/baz");
        assert (buildNormalizedPath("foo", "bar//baz///") == "foo/bar/baz");
        assert (buildNormalizedPath("/foo", "bar/baz") == "/foo/bar/baz");
        assert (buildNormalizedPath("/foo", "/bar/baz") == "/bar/baz");
        assert (buildNormalizedPath("/foo/..", "/bar/./baz") == "/bar/baz");
        assert (buildNormalizedPath("/foo/..", "bar/baz") == "/bar/baz");
        assert (buildNormalizedPath("/foo/../../", "bar/baz") == "/bar/baz");
        assert (buildNormalizedPath("/foo/bar", "../baz") == "/foo/baz");
        assert (buildNormalizedPath("/foo/bar", "../../baz") == "/baz");
        assert (buildNormalizedPath("/foo/bar", ".././/baz/..", "wee/") == "/foo/wee");
        assert (buildNormalizedPath("//foo/bar", "baz///wee") == "/foo/bar/baz/wee");
        static assert (buildNormalizedPath("/foo/..", "/bar/./baz") == "/bar/baz");
        // Examples in docs:
        assert (buildNormalizedPath("/foo", "bar/baz/") == "/foo/bar/baz");
        assert (buildNormalizedPath("/foo", "/bar/..", "baz") == "/baz");
        assert (buildNormalizedPath("foo/./bar", "../../", "../baz") == "../baz");
        assert (buildNormalizedPath("/foo/./bar", "../../baz") == "/baz");
    }
    else version (Windows)
    {
        assert (buildNormalizedPath(`\`, `foo`, `bar`) == `\foo\bar`);
        assert (buildNormalizedPath(`foo`, `bar`, `baz`) == `foo\bar\baz`);
        assert (buildNormalizedPath(`foo`, `bar\baz`) == `foo\bar\baz`);
        assert (buildNormalizedPath(`foo`, `bar\\baz\\\`) == `foo\bar\baz`);
        assert (buildNormalizedPath(`\foo`, `bar\baz`) == `\foo\bar\baz`);
        assert (buildNormalizedPath(`\foo`, `\bar\baz`) == `\bar\baz`);
        assert (buildNormalizedPath(`\foo\..`, `\bar\.\baz`) == `\bar\baz`);
        assert (buildNormalizedPath(`\foo\..`, `bar\baz`) == `\bar\baz`);
        assert (buildNormalizedPath(`\foo\..\..\`, `bar\baz`) == `\bar\baz`);
        assert (buildNormalizedPath(`\foo\bar`, `..\baz`) == `\foo\baz`);
        assert (buildNormalizedPath(`\foo\bar`, `../../baz`) == `\baz`);
        assert (buildNormalizedPath(`\foo\bar`, `..\.\/baz\..`, `wee\`) == `\foo\wee`);

        assert (buildNormalizedPath(`c:\`, `foo`, `bar`) == `c:\foo\bar`);
        assert (buildNormalizedPath(`c:foo`, `bar`, `baz`) == `c:foo\bar\baz`);
        assert (buildNormalizedPath(`c:foo`, `bar\baz`) == `c:foo\bar\baz`);
        assert (buildNormalizedPath(`c:foo`, `bar\\baz\\\`) == `c:foo\bar\baz`);
        assert (buildNormalizedPath(`c:\foo`, `bar\baz`) == `c:\foo\bar\baz`);
        assert (buildNormalizedPath(`c:\foo`, `\bar\baz`) == `c:\bar\baz`);
        assert (buildNormalizedPath(`c:\foo\..`, `\bar\.\baz`) == `c:\bar\baz`);
        assert (buildNormalizedPath(`c:\foo\..`, `bar\baz`) == `c:\bar\baz`);
        assert (buildNormalizedPath(`c:\foo\..\..\`, `bar\baz`) == `c:\bar\baz`);
        assert (buildNormalizedPath(`c:\foo\bar`, `..\baz`) == `c:\foo\baz`);
        assert (buildNormalizedPath(`c:\foo\bar`, `..\..\baz`) == `c:\baz`);
        assert (buildNormalizedPath(`c:\foo\bar`, `..\.\\baz\..`, `wee\`) == `c:\foo\wee`);

        assert (buildNormalizedPath(`\\server\share`, `foo`, `bar`) == `\\server\share\foo\bar`);
        assert (buildNormalizedPath(`\\server\share\`, `foo`, `bar`) == `\\server\share\foo\bar`);
        assert (buildNormalizedPath(`\\server\share\foo`, `bar\baz`) == `\\server\share\foo\bar\baz`);
        assert (buildNormalizedPath(`\\server\share\foo`, `\bar\baz`) == `\\server\share\bar\baz`);
        assert (buildNormalizedPath(`\\server\share\foo\..`, `\bar\.\baz`) == `\\server\share\bar\baz`);
        assert (buildNormalizedPath(`\\server\share\foo\..`, `bar\baz`) == `\\server\share\bar\baz`);
        assert (buildNormalizedPath(`\\server\share\foo\..\..\`, `bar\baz`) == `\\server\share\bar\baz`);
        assert (buildNormalizedPath(`\\server\share\foo\bar`, `..\baz`) == `\\server\share\foo\baz`);
        assert (buildNormalizedPath(`\\server\share\foo\bar`, `..\..\baz`) == `\\server\share\baz`);
        assert (buildNormalizedPath(`\\server\share\foo\bar`, `..\.\\baz\..`, `wee\`) == `\\server\share\foo\wee`);

        static assert (buildNormalizedPath(`\foo\..\..\`, `bar\baz`) == `\bar\baz`);

        // Examples in docs:
        assert (buildNormalizedPath(`c:\foo`, `bar\baz\`) == `c:\foo\bar\baz`);
        assert (buildNormalizedPath(`c:\foo`, `bar/..`) == `c:\foo`);
        assert (buildNormalizedPath(`\\server\share\foo`, `..\bar`) == `\\server\share\bar`);
    }
    else static assert (0);
}

unittest
{
    version (Posix)
    {
        // Trivial
        assert (buildNormalizedPath("").empty);
        assert (buildNormalizedPath("foo/bar") == "foo/bar");

        // Correct handling of leading slashes
        assert (buildNormalizedPath("/") == "/");
        assert (buildNormalizedPath("///") == "/");
        assert (buildNormalizedPath("////") == "/");
        assert (buildNormalizedPath("/foo/bar") == "/foo/bar");
        assert (buildNormalizedPath("//foo/bar") == "/foo/bar");
        assert (buildNormalizedPath("///foo/bar") == "/foo/bar");
        assert (buildNormalizedPath("////foo/bar") == "/foo/bar");

        // Correct handling of single-dot symbol (current directory)
        assert (buildNormalizedPath("/./foo") == "/foo");
        assert (buildNormalizedPath("/foo/./bar") == "/foo/bar");

        assert (buildNormalizedPath("./foo") == "foo");
        assert (buildNormalizedPath("././foo") == "foo");
        assert (buildNormalizedPath("foo/././bar") == "foo/bar");

        // Correct handling of double-dot symbol (previous directory)
        assert (buildNormalizedPath("/foo/../bar") == "/bar");
        assert (buildNormalizedPath("/foo/../../bar") == "/bar");
        assert (buildNormalizedPath("/../foo") == "/foo");
        assert (buildNormalizedPath("/../../foo") == "/foo");
        assert (buildNormalizedPath("/foo/..") == "/");
        assert (buildNormalizedPath("/foo/../..") == "/");

        assert (buildNormalizedPath("foo/../bar") == "bar");
        assert (buildNormalizedPath("foo/../../bar") == "../bar");
        assert (buildNormalizedPath("../foo") == "../foo");
        assert (buildNormalizedPath("../../foo") == "../../foo");
        assert (buildNormalizedPath("../foo/../bar") == "../bar");
        assert (buildNormalizedPath(".././../foo") == "../../foo");
        assert (buildNormalizedPath("foo/bar/..") == "foo");
        assert (buildNormalizedPath("/foo/../..") == "/");

        // The ultimate path
        assert (buildNormalizedPath("/foo/../bar//./../...///baz//") == "/.../baz");
        static assert (buildNormalizedPath("/foo/../bar//./../...///baz//") == "/.../baz");
    }
    else version (Windows)
    {
        // Trivial
        assert (buildNormalizedPath("").empty);
        assert (buildNormalizedPath(`foo\bar`) == `foo\bar`);
        assert (buildNormalizedPath("foo/bar") == `foo\bar`);

        // Correct handling of absolute paths
        assert (buildNormalizedPath("/") == `\`);
        assert (buildNormalizedPath(`\`) == `\`);
        assert (buildNormalizedPath(`\\\`) == `\`);
        assert (buildNormalizedPath(`\\\\`) == `\`);
        assert (buildNormalizedPath(`\foo\bar`) == `\foo\bar`);
        assert (buildNormalizedPath(`\\foo`) == `\\foo`);
        assert (buildNormalizedPath(`\\foo\\`) == `\\foo`);
        assert (buildNormalizedPath(`\\foo/bar`) == `\\foo\bar`);
        assert (buildNormalizedPath(`\\\foo\bar`) == `\foo\bar`);
        assert (buildNormalizedPath(`\\\\foo\bar`) == `\foo\bar`);
        assert (buildNormalizedPath(`c:\`) == `c:\`);
        assert (buildNormalizedPath(`c:\foo\bar`) == `c:\foo\bar`);
        assert (buildNormalizedPath(`c:\\foo\bar`) == `c:\foo\bar`);

        // Correct handling of single-dot symbol (current directory)
        assert (buildNormalizedPath(`\./foo`) == `\foo`);
        assert (buildNormalizedPath(`\foo/.\bar`) == `\foo\bar`);

        assert (buildNormalizedPath(`.\foo`) == `foo`);
        assert (buildNormalizedPath(`./.\foo`) == `foo`);
        assert (buildNormalizedPath(`foo\.\./bar`) == `foo\bar`);

        // Correct handling of double-dot symbol (previous directory)
        assert (buildNormalizedPath(`\foo\..\bar`) == `\bar`);
        assert (buildNormalizedPath(`\foo\../..\bar`) == `\bar`);
        assert (buildNormalizedPath(`\..\foo`) == `\foo`);
        assert (buildNormalizedPath(`\..\..\foo`) == `\foo`);
        assert (buildNormalizedPath(`\foo\..`) == `\`);
        assert (buildNormalizedPath(`\foo\../..`) == `\`);

        assert (buildNormalizedPath(`foo\..\bar`) == `bar`);
        assert (buildNormalizedPath(`foo\..\../bar`) == `..\bar`);
        assert (buildNormalizedPath(`..\foo`) == `..\foo`);
        assert (buildNormalizedPath(`..\..\foo`) == `..\..\foo`);
        assert (buildNormalizedPath(`..\foo\..\bar`) == `..\bar`);
        assert (buildNormalizedPath(`..\.\..\foo`) == `..\..\foo`);
        assert (buildNormalizedPath(`foo\bar\..`) == `foo`);
        assert (buildNormalizedPath(`\foo\..\..`) == `\`);
        assert (buildNormalizedPath(`c:\foo\..\..`) == `c:\`);

        // Correct handling of non-root path with drive specifier
        assert (buildNormalizedPath(`c:foo`) == `c:foo`);
        assert (buildNormalizedPath(`c:..\foo\.\..\bar`) == `c:..\bar`);

        // The ultimate path
        assert (buildNormalizedPath(`c:\foo\..\bar\\.\..\...\\\baz\\`) == `c:\...\baz`);
        static assert (buildNormalizedPath(`c:\foo\..\bar\\.\..\...\\\baz\\`) == `c:\...\baz`);
    }
    else static assert (false);
}

unittest
{
    // Test for issue 7397
    string[] ary = ["a", "b"];
    version (Posix)
    {
        assert (buildNormalizedPath(ary) == "a/b");
    }
    else version (Windows)
    {
        assert (buildNormalizedPath(ary) == `a\b`);
    }
}




/** Returns a bidirectional range that iterates over the elements of a path.

    Examples:
    ---
    assert (equal(pathSplitter("/"), ["/"]));
    assert (equal(pathSplitter("/foo/bar"), ["/", "foo", "bar"]));
    assert (equal(pathSplitter("//foo/bar"), ["//foo", "bar"]));
    assert (equal(pathSplitter("foo/../bar//./"), ["foo", "..", "bar", "."]));

    version (Windows)
    {
        assert (equal(pathSplitter(`foo\..\bar\/.\`), ["foo", "..", "bar", "."]));
        assert (equal(pathSplitter("c:"), ["c:"]));
        assert (equal(pathSplitter(`c:\foo\bar`), [`c:\`, "foo", "bar"]));
        assert (equal(pathSplitter(`c:foo\bar`), ["c:foo", "bar"]));
    }
    ---
*/
auto pathSplitter(C)(const(C)[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    static struct PathSplitter
    {
    @safe pure nothrow:
        @property empty() const { return _empty; }

        @property front() const
        {
            assert (!empty, "PathSplitter: called front() on empty range");
            return _front;
        }

        void popFront()
        {
            assert (!empty, "PathSplitter: called popFront() on empty range");
            if (_path.empty)
            {
                if (_front is _back)
                {
                    _empty = true;
                    _front = null;
                    _back = null;
                }
                else
                {
                    _front = _back;
                }
            }
            else
            {
                ptrdiff_t i = 0;
                while (i < _path.length && !isDirSeparator(_path[i])) ++i;
                _front = _path[0 .. i];
                _path = ltrimDirSeparators(_path[i .. $]);
            }
        }

        @property back() const
        {
            assert (!empty, "PathSplitter: called back() on empty range");
            return _back;
        }

        void popBack()
        {
            assert (!empty, "PathSplitter: called popBack() on empty range");
            if (_path.empty)
            {
                if (_front is _back)
                {
                    _empty = true;
                    _front = null;
                    _back = null;
                }
                else
                {
                    _back = _front;
                }
            }
            else
            {
                auto i = (cast(ptrdiff_t) _path.length) - 1;
                while (i >= 0 && !isDirSeparator(_path[i])) --i;
                _back = _path[i + 1 .. $];
                _path = rtrimDirSeparators(_path[0 .. i+1]);
            }
        }
        @property auto save() { return this; }


    private:
        typeof(path) _path, _front, _back;
        bool _empty;

        this(typeof(path) p)
        {
            if (p.empty)
            {
                _empty = true;
                return;
            }
            _path = p;

            // If path is rooted, first element is special
            version (Windows)
            {
                if (isUNC(_path))
                {
                    auto i = uncRootLength(_path);
                    _front = _path[0 .. i];
                    _path = ltrimDirSeparators(_path[i .. $]);
                }
                else if (isDriveRoot(_path))
                {
                    _front = _path[0 .. 3];
                    _path = ltrimDirSeparators(_path[3 .. $]);
                }
                else if (_path.length >= 1 && isDirSeparator(_path[0]))
                {
                    _front = _path[0 .. 1];
                    _path = ltrimDirSeparators(_path[1 .. $]);
                }
                else
                {
                    assert (!isRooted(_path));
                    popFront();
                }
            }
            else version (Posix)
            {
                if (_path.length >= 1 && isDirSeparator(_path[0]))
                {
                    _front = _path[0 .. 1];
                    _path = ltrimDirSeparators(_path[1 .. $]);
                }
                else
                {
                    popFront();
                }
            }
            else static assert (0);

            if (_path.empty) _back = _front;
            else
            {
                _path = rtrimDirSeparators(_path);
                popBack();
            }
        }
    }

    return PathSplitter(path);
}

unittest
{
    // equal2 verifies that the range is the same both ways, i.e.
    // through front/popFront and back/popBack.
    import std.range;
    bool equal2(R1, R2)(R1 r1, R2 r2)
    {
        static assert (isBidirectionalRange!R1);
        return equal(r1, r2) && equal(retro(r1), retro(r2));
    }

    assert (pathSplitter("").empty);

    // Root directories
    assert (equal2(pathSplitter("/"), ["/"]));
    assert (equal2(pathSplitter("//"), ["/"]));
    assert (equal2(pathSplitter("///"w), ["/"w]));

    // Absolute paths
    assert (equal2(pathSplitter("/foo/bar".dup), ["/", "foo", "bar"]));

    // General
    assert (equal2(pathSplitter("foo/bar"d.dup), ["foo"d, "bar"d]));
    assert (equal2(pathSplitter("foo//bar"), ["foo", "bar"]));
    assert (equal2(pathSplitter("foo/bar//"w), ["foo"w, "bar"w]));
    assert (equal2(pathSplitter("foo/../bar//./"d), ["foo"d, ".."d, "bar"d, "."d]));

    // save()
    auto ps1 = pathSplitter("foo/bar/baz");
    auto ps2 = ps1.save;
    ps1.popFront();
    assert (equal2(ps1, ["bar", "baz"]));
    assert (equal2(ps2, ["foo", "bar", "baz"]));

    // Platform specific
    version (Posix)
    {
        assert (equal2(pathSplitter("//foo/bar"w.dup), ["/"w, "foo"w, "bar"w]));
    }
    version (Windows)
    {
        assert (equal2(pathSplitter(`\`), [`\`]));
        assert (equal2(pathSplitter(`foo\..\bar\/.\`), ["foo", "..", "bar", "."]));
        assert (equal2(pathSplitter("c:"), ["c:"]));
        assert (equal2(pathSplitter(`c:\foo\bar`), [`c:\`, "foo", "bar"]));
        assert (equal2(pathSplitter(`c:foo\bar`), ["c:foo", "bar"]));
        assert (equal2(pathSplitter(`\\foo\bar`), [`\\foo\bar`]));
        assert (equal2(pathSplitter(`\\foo\bar\\`), [`\\foo\bar`]));
        assert (equal2(pathSplitter(`\\foo\bar\baz`), [`\\foo\bar`, "baz"]));
    }

    // CTFE
    static assert (equal(pathSplitter("/foo/bar".dup), ["/", "foo", "bar"]));
}




/** Determines whether a path starts at a root directory.

    On POSIX, this function returns true if and only if the path starts
    with a slash (/).
    ---
    version (Posix)
    {
        assert (isRooted("/"));
        assert (isRooted("/foo"));
        assert (!isRooted("foo"));
        assert (!isRooted("../foo"));
    }
    ---

    On Windows, this function returns true if the path starts at
    the root directory of the current drive, of some other drive,
    or of a network drive.
    ---
    version (Windows)
    {
        assert (isRooted(`\`));
        assert (isRooted(`\foo`));
        assert (isRooted(`d:\foo`));
        assert (isRooted(`\\foo\bar`));
        assert (!isRooted("foo"));
        assert (!isRooted("d:foo"));
    }
    ---
*/
bool isRooted(C)(in C[] path)  @safe pure nothrow  if (isSomeChar!C)
{
    if (path.length >= 1 && isDirSeparator(path[0])) return true;
    version (Posix)         return false;
    else version (Windows)  return isAbsolute(path);
}


unittest
{
    assert (isRooted("/"));
    assert (isRooted("/foo"));
    assert (!isRooted("foo"));
    assert (!isRooted("../foo"));

    version (Windows)
    {
    assert (isRooted(`\`));
    assert (isRooted(`\foo`));
    assert (isRooted(`d:\foo`));
    assert (isRooted(`\\foo\bar`));
    assert (!isRooted("foo"));
    assert (!isRooted("d:foo"));
    }

    static assert (isRooted("/foo"));
    static assert (!isRooted("foo"));
}




/** Determines whether a path is absolute or not.

    Examples:
    On POSIX, an absolute path starts at the root directory.
    (In fact, $(D _isAbsolute) is just an alias for $(LREF isRooted).)
    ---
    version (Posix)
    {
        assert (isAbsolute("/"));
        assert (isAbsolute("/foo"));
        assert (!isAbsolute("foo"));
        assert (!isAbsolute("../foo"));
    }
    ---

    On Windows, an absolute path starts at the root directory of
    a specific drive.  Hence, it must start with $(D `d:\`) or $(D `d:/`),
    where $(D d) is the drive letter.  Alternatively, it may be a
    network path, i.e. a path starting with a double (back)slash.
    ---
    version (Windows)
    {
        assert (isAbsolute(`d:\`));
        assert (isAbsolute(`d:\foo`));
        assert (isAbsolute(`\\foo\bar`));
        assert (!isAbsolute(`\`));
        assert (!isAbsolute(`\foo`));
        assert (!isAbsolute("d:foo"));
    }
    ---
*/
version (StdDdoc) bool isAbsolute(C)(in C[] path) @safe pure nothrow
    if (isSomeChar!C);

else version (Windows) bool isAbsolute(C)(in C[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    return isDriveRoot(path) || isUNC(path);
}

else version (Posix) alias isRooted isAbsolute;


unittest
{
    assert (!isAbsolute("foo"));
    assert (!isAbsolute("../foo"w));
    static assert (!isAbsolute("foo"));

    version (Posix)
    {
    assert (isAbsolute("/"d));
    assert (isAbsolute("/foo".dup));
    static assert (isAbsolute("/foo"));
    }

    version (Windows)
    {
    assert (isAbsolute("d:\\"w));
    assert (isAbsolute("d:\\foo"d));
    assert (isAbsolute("\\\\foo\\bar"));
    assert (!isAbsolute("\\"w.dup));
    assert (!isAbsolute("\\foo"d.dup));
    assert (!isAbsolute("d:"));
    assert (!isAbsolute("d:foo"));
    static assert (isAbsolute(`d:\foo`));
    }
}




/** Translates $(D path) into an absolute _path.

    The following algorithm is used:
    $(OL
        $(LI If $(D path) is empty, return $(D null).)
        $(LI If $(D path) is already absolute, return it.)
        $(LI Otherwise, append $(D path) to $(D base) and return
            the result. If $(D base) is not specified, the current
            working directory is used.)
    )
    The function allocates memory if and only if it gets to the third stage
    of this algorithm.

    Examples:
    ---
    version (Posix)
    {
        assert (absolutePath("some/file", "/foo/bar")  == "/foo/bar/some/file");
        assert (absolutePath("../file", "/foo/bar")    == "/foo/bar/../file");
        assert (absolutePath("/some/file", "/foo/bar") == "/some/file");
    }

    version (Windows)
    {
        assert (absolutePath(`some\file`, `c:\foo\bar`)    == `c:\foo\bar\some\file`);
        assert (absolutePath(`..\file`, `c:\foo\bar`)      == `c:\foo\bar\..\file`);
        assert (absolutePath(`c:\some\file`, `c:\foo\bar`) == `c:\some\file`);
    }
    ---

    Throws:
    $(D Exception) if the specified _base directory is not absolute.
*/
string absolutePath(string path, lazy string base = getcwd())
    @safe pure
{
    if (path.empty)  return null;
    if (isAbsolute(path))  return path;
    immutable baseVar = base;
    if (!isAbsolute(baseVar)) throw new Exception("Base directory must be absolute");
    return buildPath(baseVar, path);
}


unittest
{
    version (Posix)
    {
        assert (absolutePath("some/file", "/foo/bar")  == "/foo/bar/some/file");
        assert (absolutePath("../file", "/foo/bar")    == "/foo/bar/../file");
        assert (absolutePath("/some/file", "/foo/bar") == "/some/file");
        static assert (absolutePath("some/file", "/foo/bar") == "/foo/bar/some/file");
    }

    version (Windows)
    {
        assert (absolutePath(`some\file`, `c:\foo\bar`)    == `c:\foo\bar\some\file`);
        assert (absolutePath(`..\file`, `c:\foo\bar`)      == `c:\foo\bar\..\file`);
        assert (absolutePath(`c:\some\file`, `c:\foo\bar`) == `c:\some\file`);
        static assert (absolutePath(`some\file`, `c:\foo\bar`) == `c:\foo\bar\some\file`);
    }

    import std.exception;
    assertThrown(absolutePath("bar", "foo"));
}




/** Translates $(D path) into a relative _path.

    The returned _path is relative to $(D base), which is by default
    taken to be the current working directory.  If specified,
    $(D base) must be an absolute _path, and it is always assumed
    to refer to a directory.  If $(D path) and $(D base) refer to
    the same directory, the function returns $(D `.`).

    The following algorithm is used:
    $(OL
        $(LI If $(D path) is a relative directory, return it unaltered.)
        $(LI Find a common root between $(D path) and $(D base).
            If there is no common root, return $(D path) unaltered.)
        $(LI Prepare a string with as many $(D `../`) or $(D `..\`) as
            necessary to reach the common root from base path.)
        $(LI Append the remaining segments of $(D path) to the string
            and return.)
    )

    In the second step, path components are compared using $(D filenameCmp!cs),
    where $(D cs) is an optional template parameter determining whether
    the comparison is case sensitive or not.  See the
    $(LREF filenameCmp) documentation for details.

    The function allocates memory if and only if it reaches the third stage
    of the above algorithm.

    Examples:
    ---
    assert (relativePath("foo") == "foo");

    version (Posix)
    {
        assert (relativePath("foo", "/bar") == "foo");
        assert (relativePath("/foo/bar", "/foo/bar") == ".");
        assert (relativePath("/foo/bar", "/foo/baz") == "../bar");
        assert (relativePath("/foo/bar/baz", "/foo/woo/wee") == "../../bar/baz");
        assert (relativePath("/foo/bar/baz", "/foo/bar") == "baz");
    }
    version (Windows)
    {
        assert (relativePath("foo", `c:\bar`) == "foo");
        assert (relativePath(`c:\foo\bar`, `c:\foo\bar`) == ".");
        assert (relativePath(`c:\foo\bar`, `c:\foo\baz`) == `..\bar`);
        assert (relativePath(`c:\foo\bar\baz`, `c:\foo\woo\wee`) == `..\..\bar\baz`);
        assert (relativePath(`c:\foo\bar\baz`, `c:\foo\bar`) == "baz");
        assert (relativePath(`c:\foo\bar`, `d:\foo`) == `c:\foo\bar`);
    }
    ---

    Throws:
    $(D Exception) if the specified _base directory is not absolute.
*/
string relativePath(CaseSensitive cs = CaseSensitive.osDefault)
    (string path, lazy string base = getcwd())
    //TODO: @safe  (object.reserve(T[]) should be @trusted)
{
    if (!isAbsolute(path)) return path;
    immutable baseVar = base;
    if (!isAbsolute(baseVar)) throw new Exception("Base directory must be absolute");

    // Find common root with current working directory
    string result;
    if (!__ctfe) result.reserve(baseVar.length + path.length);

    auto basePS = pathSplitter(baseVar);
    auto pathPS = pathSplitter(path);
    if (filenameCmp!cs(basePS.front, pathPS.front) != 0) return path;

    basePS.popFront();
    pathPS.popFront();

    while (!basePS.empty && !pathPS.empty
        && filenameCmp!cs(basePS.front, pathPS.front) == 0)
    {
        basePS.popFront();
        pathPS.popFront();
    }

    // Append as many "../" as necessary to reach common base from path
    while (!basePS.empty)
    {
        result ~= "..";
        result ~= dirSeparator;
        basePS.popFront();
    }

    // Append the remainder of path
    while (!pathPS.empty)
    {
        result ~= pathPS.front;
        result ~= dirSeparator;
        pathPS.popFront();
    }

    // base == path
    if (result.empty) return ".";

    // Strip off last path separator
    return result[0 .. $-1];
}

unittest
{
    import std.exception;
    assert (relativePath("foo") == "foo");
    version (Posix)
    {
        assert (relativePath("foo", "/bar") == "foo");
        assert (relativePath("/foo/bar", "/foo/bar") == ".");
        assert (relativePath("/foo/bar", "/foo/baz") == "../bar");
        assert (relativePath("/foo/bar/baz", "/foo/woo/wee") == "../../bar/baz");
        assert (relativePath("/foo/bar/baz", "/foo/bar") == "baz");
        assertThrown(relativePath("/foo", "bar"));

        // CTFE
        static assert (relativePath("/foo/bar", "/foo/baz") == "../bar");
    }
    else version (Windows)
    {
        assert (relativePath("foo", `c:\bar`) == "foo");
        assert (relativePath(`c:\foo\bar`, `c:\foo\bar`) == ".");
        assert (relativePath(`c:\foo\bar`, `c:\foo\baz`) == `..\bar`);
        assert (relativePath(`c:\foo\bar\baz`, `c:\foo\woo\wee`) == `..\..\bar\baz`);
        assert (relativePath(`c:/foo/bar/baz`, `c:\foo\woo\wee`) == `..\..\bar\baz`);
        assert (relativePath(`c:\foo\bar\baz`, `c:\foo\bar`) == "baz");
        assert (relativePath(`c:\foo\bar`, `d:\foo`) == `c:\foo\bar`);
        assert (relativePath(`\\foo\bar`, `c:\foo`) == `\\foo\bar`);
        assertThrown(relativePath(`c:\foo`, "bar"));

        // CTFE
        static assert (relativePath(`c:\foo\bar`, `c:\foo\baz`) == `..\bar`);
    }
    else static assert (0);
}




/** Compares filename characters and return $(D < 0) if $(D a < b), $(D 0) if
    $(D a == b) and $(D > 0) if $(D a > b).

    This function can perform a case-sensitive or a case-insensitive
    comparison.  This is controlled through the $(D cs) template parameter
    which, if not specified, is given by
    $(LREF CaseSensitive)$(D .osDefault).

    On Windows, the backslash and slash characters ($(D `\`) and $(D `/`))
    are considered equal.

    Examples:
    ---
    assert (filenameCharCmp('a', 'a') == 0);
    assert (filenameCharCmp('a', 'b') < 0);
    assert (filenameCharCmp('b', 'a') > 0);

    version (linux)
    {
        // Same as calling filenameCharCmp!(CaseSensitive.yes)(a, b)
        assert (filenameCharCmp('A', 'a') < 0);
        assert (filenameCharCmp('a', 'A') > 0);
    }
    version (Windows)
    {
        // Same as calling filenameCharCmp!(CaseSensitive.no)(a, b)
        assert (filenameCharCmp('a', 'A') == 0);
        assert (filenameCharCmp('a', 'B') < 0);
        assert (filenameCharCmp('A', 'b') < 0);
    }
    ---
*/
int filenameCharCmp(CaseSensitive cs = CaseSensitive.osDefault)(dchar a, dchar b)
    @safe pure nothrow
{
    if (isDirSeparator(a) && isDirSeparator(b)) return 0;
    static if (!cs)
    {
        import std.uni;
        a = toLower(a);
        b = toLower(b);
    }
    return cast(int)(a - b);
}


unittest
{
    assert (filenameCharCmp!(CaseSensitive.yes)('a', 'a') == 0);
    assert (filenameCharCmp!(CaseSensitive.yes)('a', 'b') < 0);
    assert (filenameCharCmp!(CaseSensitive.yes)('b', 'a') > 0);
    assert (filenameCharCmp!(CaseSensitive.yes)('A', 'a') < 0);
    assert (filenameCharCmp!(CaseSensitive.yes)('a', 'A') > 0);

    assert (filenameCharCmp!(CaseSensitive.no)('a', 'a') == 0);
    assert (filenameCharCmp!(CaseSensitive.no)('a', 'b') < 0);
    assert (filenameCharCmp!(CaseSensitive.no)('b', 'a') > 0);
    assert (filenameCharCmp!(CaseSensitive.no)('A', 'a') == 0);
    assert (filenameCharCmp!(CaseSensitive.no)('a', 'A') == 0);
    assert (filenameCharCmp!(CaseSensitive.no)('a', 'B') < 0);
    assert (filenameCharCmp!(CaseSensitive.no)('B', 'a') > 0);
    assert (filenameCharCmp!(CaseSensitive.no)('A', 'b') < 0);
    assert (filenameCharCmp!(CaseSensitive.no)('b', 'A') > 0);

    version (Posix)   assert (filenameCharCmp('\\', '/') != 0);
    version (Windows) assert (filenameCharCmp('\\', '/') == 0);
}




/** Compares file names and returns
    $(D < 0) if $(D filename1 < filename2),
    $(D 0) if $(D filename1 == filename2) and
    $(D > 0) if $(D filename1 > filename2).

    Individual characters are compared using $(D filenameCharCmp!cs),
    where $(D cs) is an optional template parameter determining whether
    the comparison is case sensitive or not.  See the
    $(LREF filenameCharCmp) documentation for details.

    Examples:
    ---
    assert (filenameCmp("abc", "abc") == 0);
    assert (filenameCmp("abc", "abd") < 0);
    assert (filenameCmp("abc", "abb") > 0);
    assert (filenameCmp("abc", "abcd") < 0);
    assert (filenameCmp("abcd", "abc") > 0);

    version (linux)
    {
        // Same as calling filenameCmp!(CaseSensitive.yes)(filename1, filename2)
        assert (filenameCmp("Abc", "abc") < 0);
        assert (filenameCmp("abc", "Abc") > 0);
    }
    version (Windows)
    {
        // Same as calling filenameCmp!(CaseSensitive.no)(filename1, filename2)
        assert (filenameCmp("Abc", "abc") == 0);
        assert (filenameCmp("abc", "Abc") == 0);
        assert (filenameCmp("Abc", "abD") < 0);
        assert (filenameCmp("abc", "AbB") > 0);
    }
    ---
*/
int filenameCmp(CaseSensitive cs = CaseSensitive.osDefault, C1, C2)
    (const(C1)[] filename1, const(C2)[] filename2)
    @safe pure //TODO: nothrow (because of std.array.front())
    if (isSomeChar!C1 && isSomeChar!C2)
{
    for (;;)
    {
        if (filename1.empty) return -(cast(int) !filename2.empty);
        if (filename2.empty) return  (cast(int) !filename1.empty);
        auto c = filenameCharCmp!cs(filename1.front, filename2.front);
        if (c != 0) return c;
        filename1.popFront();
        filename2.popFront();
    }
    assert (0);
}


unittest
{
    assert (filenameCmp!(CaseSensitive.yes)("abc", "abc") == 0);
    assert (filenameCmp!(CaseSensitive.yes)("abc", "abd") < 0);
    assert (filenameCmp!(CaseSensitive.yes)("abc", "abb") > 0);
    assert (filenameCmp!(CaseSensitive.yes)("abc", "abcd") < 0);
    assert (filenameCmp!(CaseSensitive.yes)("abcd", "abc") > 0);
    assert (filenameCmp!(CaseSensitive.yes)("Abc", "abc") < 0);
    assert (filenameCmp!(CaseSensitive.yes)("abc", "Abc") > 0);

    assert (filenameCmp!(CaseSensitive.no)("abc", "abc") == 0);
    assert (filenameCmp!(CaseSensitive.no)("abc", "abd") < 0);
    assert (filenameCmp!(CaseSensitive.no)("abc", "abb") > 0);
    assert (filenameCmp!(CaseSensitive.no)("abc", "abcd") < 0);
    assert (filenameCmp!(CaseSensitive.no)("abcd", "abc") > 0);
    assert (filenameCmp!(CaseSensitive.no)("Abc", "abc") == 0);
    assert (filenameCmp!(CaseSensitive.no)("abc", "Abc") == 0);
    assert (filenameCmp!(CaseSensitive.no)("Abc", "abD") < 0);
    assert (filenameCmp!(CaseSensitive.no)("abc", "AbB") > 0);

    version (Posix)   assert (filenameCmp(`abc\def`, `abc/def`) != 0);
    version (Windows) assert (filenameCmp(`abc\def`, `abc/def`) == 0);
}




/** Matches a pattern against a path.

    Some characters of pattern have a special meaning (they are
    $(I meta-characters)) and can't be escaped. These are:

    $(BOOKTABLE,
    $(TR $(TD $(D *))
         $(TD Matches 0 or more instances of any character.))
    $(TR $(TD $(D ?))
         $(TD Matches exactly one instance of any character.))
    $(TR $(TD $(D [)$(I chars)$(D ]))
         $(TD Matches one instance of any character that appears
              between the brackets.))
    $(TR $(TD $(D [!)$(I chars)$(D ]))
         $(TD Matches one instance of any character that does not
              appear between the brackets after the exclamation mark.))
    $(TR $(TD $(D {)$(I string1)$(D ,)$(I string2)$(D ,)&hellip;$(D }))
         $(TD Matches either of the specified strings.))
    )

    Individual characters are compared using $(D filenameCharCmp!cs),
    where $(D cs) is an optional template parameter determining whether
    the comparison is case sensitive or not.  See the
    $(LREF filenameCharCmp) documentation for details.

    Note that directory
    separators and dots don't stop a meta-character from matching
    further portions of the path.

    Returns:
    $(D true) if pattern matches path, $(D false) otherwise.

    See_also:
    $(LINK2 http://en.wikipedia.org/wiki/Glob_%28programming%29,Wikipedia: _glob (programming))

    Examples:
    -----
    assert (globMatch("foo.bar", "*"));
    assert (globMatch("foo.bar", "*.*"));
    assert (globMatch(`foo/foo\bar`, "f*b*r"));
    assert (globMatch("foo.bar", "f???bar"));
    assert (globMatch("foo.bar", "[fg]???bar"));
    assert (globMatch("foo.bar", "[!gh]*bar"));
    assert (globMatch("bar.fooz", "bar.{foo,bif}z"));
    assert (globMatch("bar.bifz", "bar.{foo,bif}z"));

    version (Windows)
    {
        // Same as calling globMatch!(CaseSensitive.no)(path, pattern)
        assert (globMatch("foo", "Foo"));
        assert (globMatch("Goo.bar", "[fg]???bar"));
    }
    version (linux)
    {
        // Same as calling globMatch!(CaseSensitive.yes)(path, pattern)
        assert (!globMatch("foo", "Foo"));
        assert (!globMatch("Goo.bar", "[fg]???bar"));
    }
    -----
 */
bool globMatch(CaseSensitive cs = CaseSensitive.osDefault, C)
    (const(C)[] path, const(C)[] pattern)
    @safe pure nothrow
    if (isSomeChar!C)
in
{
    // Verify that pattern[] is valid
    assert(balancedParens(pattern, '[', ']', 0));
    assert(balancedParens(pattern, '{', '}', 0));
}
body
{
    size_t ni; // current character in path

    foreach (ref pi; 0 .. pattern.length)
    {
        C pc = pattern[pi];
        switch (pc)
        {
            case '*':
                if (pi + 1 == pattern.length)
                    return true;
                foreach (j; ni .. path.length)
                {
                    if (globMatch!(cs, C)(path[j .. path.length],
                                    pattern[pi + 1 .. pattern.length]))
                        return true;
                }
                return false;

            case '?':
                if (ni == path.length)
                    return false;
                ni++;
                break;

            case '[':
                if (ni == path.length)
                    return false;
                auto nc = path[ni];
                ni++;
                auto not = false;
                pi++;
                if (pattern[pi] == '!')
                {
                    not = true;
                    pi++;
                }
                auto anymatch = false;
                while (1)
                {
                    pc = pattern[pi];
                    if (pc == ']')
                        break;
                    if (!anymatch && (filenameCharCmp!cs(nc, pc) == 0))
                        anymatch = true;
                    pi++;
                }
                if (anymatch == not)
                    return false;
                break;

            case '{':
                // find end of {} section
                auto piRemain = pi;
                for (; piRemain < pattern.length
                         && pattern[piRemain] != '}'; piRemain++)
                {}

                if (piRemain < pattern.length) piRemain++;
                pi++;

                while (pi < pattern.length)
                {
                    auto pi0 = pi;
                    pc = pattern[pi];
                    // find end of current alternative
                    for (; pi<pattern.length && pc!='}' && pc!=','; pi++)
                    {
                        pc = pattern[pi];
                    }

                    if (pi0 == pi)
                    {
                        if (globMatch!(cs, C)(path[ni..$], pattern[piRemain..$]))
                        {
                            return true;
                        }
                        pi++;
                    }
                    else
                    {
                        if (globMatch!(cs, C)(path[ni..$],
                                        pattern[pi0..pi-1]
                                        ~ pattern[piRemain..$]))
                        {
                            return true;
                        }
                    }
                    if (pc == '}')
                    {
                        break;
                    }
                }
                return false;

            default:
                if (ni == path.length)
                    return false;
                if (filenameCharCmp!cs(pc, path[ni]) != 0)
                    return false;
                ni++;
                break;
        }
    }
    assert(ni <= path.length);
    return ni == path.length;
}

unittest
{
    assert (globMatch!(CaseSensitive.no)("foo", "Foo"));
    assert (!globMatch!(CaseSensitive.yes)("foo", "Foo"));

    assert(globMatch("foo", "*"));
    assert(globMatch("foo.bar"w, "*"w));
    assert(globMatch("foo.bar"d, "*.*"d));
    assert(globMatch("foo.bar", "foo*"));
    assert(globMatch("foo.bar"w, "f*bar"w));
    assert(globMatch("foo.bar"d, "f*b*r"d));
    assert(globMatch("foo.bar", "f???bar"));
    assert(globMatch("foo.bar"w, "[fg]???bar"w));
    assert(globMatch("foo.bar"d, "[!gh]*bar"d));

    assert(!globMatch("foo", "bar"));
    assert(!globMatch("foo"w, "*.*"w));
    assert(!globMatch("foo.bar"d, "f*baz"d));
    assert(!globMatch("foo.bar", "f*b*x"));
    assert(!globMatch("foo.bar", "[gh]???bar"));
    assert(!globMatch("foo.bar"w, "[!fg]*bar"w));
    assert(!globMatch("foo.bar"d, "[fg]???baz"d));
    assert(!globMatch("foo.di", "*.d")); // test issue 6634: triggered bad assertion

    assert(globMatch("foo.bar", "{foo,bif}.bar"));
    assert(globMatch("bif.bar"w, "{foo,bif}.bar"w));

    assert(globMatch("bar.foo"d, "bar.{foo,bif}"d));
    assert(globMatch("bar.bif", "bar.{foo,bif}"));

    assert(globMatch("bar.fooz"w, "bar.{foo,bif}z"w));
    assert(globMatch("bar.bifz"d, "bar.{foo,bif}z"d));

    assert(globMatch("bar.foo", "bar.{biz,,baz}foo"));
    assert(globMatch("bar.foo"w, "bar.{biz,}foo"w));
    assert(globMatch("bar.foo"d, "bar.{,biz}foo"d));
    assert(globMatch("bar.foo", "bar.{}foo"));

    assert(globMatch("bar.foo"w, "bar.{ar,,fo}o"w));
    assert(globMatch("bar.foo"d, "bar.{,ar,fo}o"d));
    assert(globMatch("bar.o", "bar.{,ar,fo}o"));

    static assert(globMatch("foo.bar", "[!gh]*bar"));
}




/** Checks that the given file or directory name is valid.

    This function returns $(D true) if and only if $(D filename) is not
    empty, not too long, and does not contain invalid characters.

    The maximum length of $(D filename) is given by the constant
    $(D core.stdc.stdio.FILENAME_MAX).  (On Windows, this number is
    defined as the maximum number of UTF-16 code points, and the
    test will therefore only yield strictly correct results when
    $(D filename) is a string of $(D wchar)s.)

    On Windows, the following criteria must be satisfied
    ($(LINK2 http://msdn.microsoft.com/en-us/library/aa365247(v=vs.85).aspx,source)):
    $(UL
        $(LI $(D filename) must not contain any characters whose integer
            representation is in the range 0-31.)
        $(LI $(D filename) must not contain any of the following $(I reserved
            characters): <>:"/\|?*)
        $(LI $(D filename) may not end with a space ($(D ' ')) or a period
            ($(D '.')).)
    )

    On POSIX, $(D filename) may not contain a forward slash ($(D '/')) or
    the null character ($(D '\0')).
*/
bool isValidFilename(C)(in C[] filename)  @safe pure nothrow  if (isSomeChar!C)
{
    import core.stdc.stdio;
    if (filename.length == 0 || filename.length >= FILENAME_MAX) return false;
    foreach (c; filename)
    {
        version (Windows)
        {
            switch (c)
            {
                case 0:
                ..
                case 31:
                case '<':
                case '>':
                case ':':
                case '"':
                case '/':
                case '\\':
                case '|':
                case '?':
                case '*':
                    return false;
                default:
            }
        }
        else version (Posix)
        {
            if (c == 0 || c == '/') return false;
        }
        else static assert (0);
    }
    version (Windows)
    {
        if (filename[$-1] == '.' || filename[$-1] == ' ') return false;
    }

    // All criteria passed
    return true;
}


unittest
{
    auto valid = ["foo"];
    auto invalid = ["", "foo\0bar", "foo/bar"];
    auto pfdep = [`foo\bar`, "*.txt"];
    version (Windows) invalid ~= pfdep;
    else version (Posix) valid ~= pfdep;
    else static assert (0);

    import std.typetuple;
    foreach (T; TypeTuple!(char[], const(char)[], string, wchar[],
        const(wchar)[], wstring, dchar[], const(dchar)[], dstring))
    {
        foreach (fn; valid)
            assert (isValidFilename(to!T(fn)));
        foreach (fn; invalid)
            assert (!isValidFilename(to!T(fn)));
    }
}




/** Checks whether $(D path) is a valid _path.

    Generally, this function checks that $(D path) is not empty, and that
    each component of the path either satisfies $(LREF isValidFilename)
    or is equal to $(D ".") or $(D "..").
    It does $(I not) check whether the _path points to an existing file
    or directory; use $(XREF file,exists) for this purpose.

    On Windows, some special rules apply:
    $(UL
        $(LI If the second character of $(D path) is a colon ($(D ':')),
            the first character is interpreted as a drive letter, and
            must be in the range A-Z (case insensitive).)
        $(LI If $(D path) is on the form $(D `\\$(I server)\$(I share)\...`)
            (UNC path), $(LREF isValidFilename) is applied to $(I server)
            and $(I share) as well.)
        $(LI If $(D path) starts with $(D `\\?\`) (long UNC path), the
            only requirement for the rest of the string is that it does
            not contain the null character.)
        $(LI If $(D path) starts with $(D `\\.\`) (Win32 device namespace)
            this function returns $(D false); such paths are beyond the scope
            of this module.)
    )
*/
bool isValidPath(C)(in C[] path)  @safe pure nothrow  if (isSomeChar!C)
{
    if (path.empty) return false;

    // Check whether component is "." or "..", or whether it satisfies
    // isValidFilename.
    bool isValidComponent(in C[] component)  @safe pure nothrow
    {
        assert (component.length > 0);
        if (component[0] == '.')
        {
            if (component.length == 1) return true;
            else if (component.length == 2 && component[1] == '.') return true;
        }
        return isValidFilename(component);
    }

    if (path.length == 1)
        return isDirSeparator(path[0]) || isValidComponent(path);

    const(C)[] remainder;
    version (Windows)
    {
        if (isDirSeparator(path[0]) && isDirSeparator(path[1]))
        {
            // Some kind of UNC path
            if (path.length < 5)
            {
                // All valid UNC paths must have at least 5 characters
                return false;
            }
            else if (path[2] == '?')
            {
                // Long UNC path
                if (!isDirSeparator(path[3])) return false;
                foreach (c; path[4 .. $])
                {
                    if (c == '\0') return false;
                }
                return true;
            }
            else if (path[2] == '.')
            {
                // Win32 device namespace not supported
                return false;
            }
            else
            {
                // Normal UNC path, i.e. \\server\share\...
                size_t i = 2;
                while (i < path.length && !isDirSeparator(path[i])) ++i;
                if (i == path.length || !isValidFilename(path[2 .. i]))
                    return false;
                ++i; // Skip a single dir separator
                size_t j = i;
                while (j < path.length && !isDirSeparator(path[j])) ++j;
                if (!isValidFilename(path[i .. j])) return false;
                remainder = path[j .. $];
            }
        }
        else if (isDriveSeparator(path[1]))
        {
            import std.ascii;
            if (!isAlpha(path[0])) return false;
            remainder = path[2 .. $];
        }
        else
        {
            remainder = path;
        }
    }
    else version (Posix)
    {
        remainder = path;
    }
    else static assert (0);
    assert (remainder !is null);
    remainder = ltrimDirSeparators(remainder);

    // Check that each component satisfies isValidComponent.
    while (!remainder.empty)
    {
        size_t i = 0;
        while (i < remainder.length && !isDirSeparator(remainder[i])) ++i;
        assert (i > 0);
        if (!isValidComponent(remainder[0 .. i])) return false;
        remainder = ltrimDirSeparators(remainder[i .. $]);
    }

    // All criteria passed
    return true;
}


unittest
{
    assert (isValidPath("/foo/bar"));
    assert (!isValidPath("/foo\0/bar"));

    version (Windows)
    {
        assert (isValidPath(`c:\`));
        assert (isValidPath(`c:\foo`));
        assert (isValidPath(`c:\foo\.\bar\\\..\`));
        assert (!isValidPath(`!:\foo`));
        assert (!isValidPath(`c::\foo`));
        assert (!isValidPath(`c:\foo?`));
        assert (!isValidPath(`c:\foo.`));

        assert (isValidPath(`\\server\share`));
        assert (isValidPath(`\\server\share\foo`));
        assert (isValidPath(`\\server\share\\foo`));
        assert (!isValidPath(`\\\server\share\foo`));
        assert (!isValidPath(`\\server\\share\foo`));
        assert (!isValidPath(`\\ser*er\share\foo`));
        assert (!isValidPath(`\\server\sha?e\foo`));
        assert (!isValidPath(`\\server\share\|oo`));

        assert (isValidPath(`\\?\<>:"?*|/\..\.`));
        assert (!isValidPath("\\\\?\\foo\0bar"));

        assert (!isValidPath(`\\.\PhysicalDisk1`));
    }
}




/** Performs tilde expansion in paths on POSIX systems.
    On Windows, this function does nothing.

    There are two ways of using tilde expansion in a path. One
    involves using the tilde alone or followed by a path separator. In
    this case, the tilde will be expanded with the value of the
    environment variable $(D HOME).  The second way is putting
    a username after the tilde (i.e. $(D ~john/Mail)). Here,
    the username will be searched for in the user database
    (i.e. $(D /etc/passwd) on Unix systems) and will expand to
    whatever path is stored there.  The username is considered the
    string after the tilde ending at the first instance of a path
    separator.

    Note that using the $(D ~user) syntax may give different
    values from just $(D ~) if the environment variable doesn't
    match the value stored in the user database.

    When the environment variable version is used, the path won't
    be modified if the environment variable doesn't exist or it
    is empty. When the database version is used, the path won't be
    modified if the user doesn't exist in the database or there is
    not enough memory to perform the query.

    This function performs several memory allocations.

    Returns:
    $(D inputPath) with the tilde expanded, or just $(D inputPath)
    if it could not be expanded.
    For Windows, $(D expandTilde) merely returns its argument $(D inputPath).

    Examples:
    -----
    void processFile(string path)
    {
        // Allow calling this function with paths such as ~/foo
        auto fullPath = expandTilde(path);
        ...
    }
    -----
*/
string expandTilde(string inputPath)
{
    version(Posix)
    {
        /*  Joins a path from a C string to the remainder of path.

            The last path separator from c_path is discarded. The result
            is joined to path[char_pos .. length] if char_pos is smaller
            than length, otherwise path is not appended to c_path.
        */
        static string combineCPathWithDPath(char* c_path, string path, size_t char_pos)
        {
            assert(c_path != null);
            assert(path.length > 0);
            assert(char_pos >= 0);

            // Search end of C string
            size_t end = core.stdc.string.strlen(c_path);

            // Remove trailing path separator, if any
            if (end && isDirSeparator(c_path[end - 1]))
                end--;

            // Create our own copy, as lifetime of c_path is undocumented
            string cp = c_path[0 .. end].idup;

            // Do we append something from path?
            if (char_pos < path.length)
                cp ~= path[char_pos .. $];

            return cp;
        }

        // Replaces the tilde from path with the environment variable HOME.
        static string expandFromEnvironment(string path)
        {
            assert(path.length >= 1);
            assert(path[0] == '~');

            // Get HOME and use that to replace the tilde.
            auto home = core.stdc.stdlib.getenv("HOME");
            if (home == null)
                return path;

            return combineCPathWithDPath(home, path, 1);
        }

        // Replaces the tilde from path with the path from the user database.
        static string expandFromDatabase(string path)
        {
            assert(path.length > 2 || (path.length == 2 && !isDirSeparator(path[1])));
            assert(path[0] == '~');

            // Extract username, searching for path separator.
            string username;
            auto last_char = std.string.indexOf(path, dirSeparator[0]);

            if (last_char == -1)
            {
                username = path[1 .. $] ~ '\0';
                last_char = username.length + 1;
            }
            else
            {
                username = path[1 .. last_char] ~ '\0';
            }
            assert(last_char > 1);

            // Reserve C memory for the getpwnam_r() function.
            passwd result;
            int extra_memory_size = 5 * 1024;
            void* extra_memory;

            while (1)
            {
                extra_memory = core.stdc.stdlib.malloc(extra_memory_size);
                if (extra_memory == null)
                    goto Lerror;

                // Obtain info from database.
                passwd *verify;
                errno = 0;
                if (getpwnam_r(cast(char*) username.ptr, &result, cast(char*) extra_memory, extra_memory_size,
                        &verify) == 0)
                {
                    // Failure if verify doesn't point at result.
                    if (verify != &result)
                        // username is not found, so return path[]
                        goto Lnotfound;
                    break;
                }

                if (errno != ERANGE)
                    goto Lerror;

                // extra_memory isn't large enough
                core.stdc.stdlib.free(extra_memory);
                extra_memory_size *= 2;
            }

            path = combineCPathWithDPath(result.pw_dir, path, last_char);

        Lnotfound:
            core.stdc.stdlib.free(extra_memory);
            return path;

        Lerror:
            // Errors are going to be caused by running out of memory
            if (extra_memory)
                core.stdc.stdlib.free(extra_memory);
            onOutOfMemoryError();
            return null;
        }

        // Return early if there is no tilde in path.
        if (inputPath.length < 1 || inputPath[0] != '~')
            return inputPath;

        if (inputPath.length == 1 || isDirSeparator(inputPath[1]))
            return expandFromEnvironment(inputPath);
        else
            return expandFromDatabase(inputPath);
    }
    else version(Windows)
    {
        // Put here real windows implementation.
        return inputPath;
    }
    else
    {
        static assert(0); // Guard. Implement on other platforms.
    }
}


version(unittest) import std.process: environment;
unittest
{
    version (Posix)
    {
        // Retrieve the current home variable.
        auto oldHome = environment.get("HOME");

        // Testing when there is no environment variable.
        environment.remove("HOME");
        assert(expandTilde("~/") == "~/");
        assert(expandTilde("~") == "~");

        // Testing when an environment variable is set.
        environment["HOME"] = "dmd/test";
        assert(expandTilde("~/") == "dmd/test/");
        assert(expandTilde("~") == "dmd/test");

        // The same, but with a variable ending in a slash.
        environment["HOME"] = "dmd/test/";
        assert(expandTilde("~/") == "dmd/test/");
        assert(expandTilde("~") == "dmd/test");

        // Recover original HOME variable before continuing.
        if (oldHome !is null) environment["HOME"] = oldHome;
        else environment.remove("HOME");

        // Test user expansion for root. Are there unices without /root?
        version (OSX)
            assert(expandTilde("~root") == "/var/root", expandTilde("~root"));
        else
            assert(expandTilde("~root") == "/root", expandTilde("~root"));
        version (OSX)
            assert(expandTilde("~root/") == "/var/root/", expandTilde("~root/"));
        else
            assert(expandTilde("~root/") == "/root/", expandTilde("~root/"));
        assert(expandTilde("~Idontexist/hey") == "~Idontexist/hey");
    }
}
