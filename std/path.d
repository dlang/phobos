// Written in the D programming language.

/** Proposal for a new $(D std._path).

    This module is used to parse path strings. All functions, with the
    exception of $(D absolutePath()) and $(D expandTilde()), are pure
    string manipulation functions; they don't depend on any state outside
    the program, nor do they perform any I/O.
    This has the consequence that the module does not make any distinction
    between a path that points to a directory and a path that points to a
    file.  To differentiate between these cases, use $(D  std.file.isDir()).

    Note that on Windows, both the backslash (\) and the slash (/) are
    in principle valid directory separators.  This module treats them
    both on equal footing, but in cases where a $(I new) separator is
    added, a backslash will be used.  Furthermore, the $(D normalize())
    function will replace all slashes with backslashes on this platform.

    Authors:
        Lars Tandle Kyllingstad,
        $(WEB digitalmars.com, Walter Bright),
        Grzegorz Adam Hankiewicz,
        Thomas K&uuml;hne,
        Bill Baxter,
        $(WEB erdani.org, Andrei Alexandrescu)
    Copyright:
        Copyright (c) 2000, the authors. All rights reserved.
    License:
        $(WEB boost.org/LICENSE_1_0.txt, Boost License 1.0)
    Source:
        $(PHOBOSSRC std/_path.d)
    Macros:
        WIKI = Phobos/StdPath
*/
module std.path;


import std.algorithm;
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




/** Determine whether the given character is a directory separator.

    On Windows, this includes both '\' and '/'.  On POSIX, it's just '/'.
*/
bool isDirSeparator(dchar c)  @safe pure nothrow
{
    if (c == '/') return true;
    version(Windows) if (c == '\\') return true;
    return false;
}


/*  Determine whether the given character is a drive separator.

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
private sizediff_t lastSeparator(C)(in C[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    auto i = (cast(sizediff_t) path.length) - 1;
    while (i >= 0 && !isSeparator(path[i])) --i;
    return i;
}


/*  Helper function that strips trailing slashes and backslashes
    from a path.
*/
private C[] chompDirSeparators(C)(C[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    auto i = (cast(sizediff_t) path.length) - 1;
    while (i >= 0 && isDirSeparator(path[i])) --i;
    return path[0 .. i+1];
}




/** Returns the name of a file, without any leading directory
    and with an optional suffix chopped off.

    Examples:
    ---
    assert (baseName("dir/file.ext")         == "file.ext");
    assert (baseName("dir/file.ext", ".ext") == "file");
    assert (baseName("dir/filename", "name") == "file");
    assert (baseName("dir/subdir/")          == "subdir");

    version (Windows)
    {
        assert (baseName(`d:file.ext`)      == "file.ext");
        assert (baseName(`d:\dir\file.ext`) == "file.ext");
    }
    ---

    Note:
    This function only strips away the specified suffix.  If you want
    to remove the extension from a path, regardless of what the extension
    is, use stripExtension().
    If you want the filename without leading directories and without
    an extension, combine the functions like this:
    ---
    assert (baseName(stripExtension("dir/file.ext")) == "file");
    ---
*/
// This function is written so it adheres to the POSIX requirements
// for the 'basename' shell utility:
// http://pubs.opengroup.org/onlinepubs/9699919799/utilities/basename.html
C[] baseName(C)(C[] path)  @safe pure nothrow  if (isSomeChar!C)
{
    auto p1 = stripDrive(path);
    if (p1.length == 0) return null;

    auto p2 = chompDirSeparators(p1);
    if (p2.length == 0) return p1[0 .. 1];

    return p2[lastSeparator(p2)+1 .. $];
}

/// ditto
C[] baseName(C, C1)(C[] path, C1[] suffix)  //TODO: @safe pure nothrow
    if (isSomeChar!C && isSomeChar!C1)
{
    auto p1 = baseName(path);
    auto p2 = std.string.chomp(p1, suffix);
    if (p2.length == 0) return p1;
    else return p2;
}


unittest
{
    assert (baseName("")                            == "");
    assert (baseName("file.ext"w)                   == "file.ext");
    assert (baseName("file.ext"d, ".ext")           == "file");
    assert (baseName("file", "file"w.dup)           == "file");
    assert (baseName("dir/file.ext"d.dup)           == "file.ext");
    assert (baseName("dir/file.ext", ".ext"d)       == "file");
    assert (baseName("dir/file"w, "file"d)          == "file");
    assert (baseName("dir///subdir////")            == "subdir");
    assert (baseName("dir/subdir.ext/", ".ext")     == "subdir");
    assert (baseName("dir/subdir/".dup, "subdir")   == "subdir");
    assert (baseName("/"w.dup)                      == "/");
    assert (baseName("//"d.dup)                     == "/");
    assert (baseName("///")                         == "/");

    version (Windows)
    {
    assert (baseName("dir\\file.ext")               == "file.ext");
    assert (baseName("dir\\file.ext", ".ext")       == "file");
    assert (baseName("dir\\file", "file")           == "file");
    assert (baseName("d:file.ext")                  == "file.ext");
    assert (baseName("d:file.ext", ".ext")          == "file");
    assert (baseName("d:file", "file")              == "file");
    assert (baseName("dir\\\\subdir\\\\\\")         == "subdir");
    assert (baseName("dir\\subdir.ext\\", ".ext")   == "subdir");
    assert (baseName("dir\\subdir\\", "subdir")     == "subdir");
    assert (baseName("\\")                          == "\\");
    assert (baseName("\\\\")                        == "\\");
    assert (baseName("\\\\\\")                      == "\\");
    assert (baseName("d:\\")                        == "\\");
    assert (baseName("d:")                          == "");
    }

    assert (baseName(stripExtension("dir/file.ext")) == "file");
}




/** Returns the directory part of a path.  On Windows, this
    includes the drive letter if present.

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
*/
C[] dirName(C)(C[] path)  @trusted //TODO: @safe pure nothrow
    if (isSomeChar!C)
{
    // This function is written so it adheres to the POSIX requirements
    // for the 'dirname' shell utility:
    // http://pubs.opengroup.org/onlinepubs/9699919799/utilities/dirname.html

    if (path.length == 0) return to!(typeof(return))(".");

    auto p = chompDirSeparators(path);
    if (p.length == 0) return path[0 .. 1];
    if (p.length == 2 && isDriveSeparator(p[1]) && path.length > 2)
        return path[0 .. 3];

    auto i = lastSeparator(p);
    if (i == -1) return to!(typeof(return))(".");
    if (i == 0) return p[0 .. 1];

    // If the directory part is either d: or d:\, don't
    // chop off the last symbol.
    if (isDriveSeparator(p[i]) || isDriveSeparator(p[i-1]))
        return p[0 .. i+1];

    // Remove any remaining trailing (back)slashes.
    return chompDirSeparators(p[0 .. i]);
}


unittest
{
    assert (dirName("")                 == ".");
    assert (dirName("file"w)            == ".");
    assert (dirName("dir/"d)            == ".");
    assert (dirName("dir///")           == ".");
    assert (dirName("dir/file"w.dup)    == "dir");
    assert (dirName("dir///file"d.dup)  == "dir");
    assert (dirName("dir/subdir/")      == "dir");
    assert (dirName("/dir/file"w)       == "/dir");
    assert (dirName("/file"d)           == "/");
    assert (dirName("/")                == "/");
    assert (dirName("///")              == "/");

    version (Windows)
    {
    assert (dirName("dir\\")            == ".");
    assert (dirName("dir\\\\\\")        == ".");
    assert (dirName("dir\\file")        == "dir");
    assert (dirName("dir\\\\\\file")    == "dir");
    assert (dirName("dir\\subdir\\")    == "dir");
    assert (dirName("\\dir\\file")      == "\\dir");
    assert (dirName("\\file")           == "\\");
    assert (dirName("\\")               == "\\");
    assert (dirName("\\\\\\")           == "\\");
    assert (dirName("d:")               == "d:");
    assert (dirName("d:file")           == "d:");
    assert (dirName("d:\\")             == "d:\\");
    assert (dirName("d:\\file")         == "d:\\");
    assert (dirName("d:\\dir\\file")    == "d:\\dir");
    }
}




/** Returns the drive letter (including the colon) of a path, or
    an empty string if there is no drive letter.

    Always returns an empty string on POSIX.

    Examples:
    ---
    version (Windows)
    {
        assert (driveName("d:file")   == "d:");
        assert (driveName(`d:\file`)  == "d:");
        assert (driveName(`dir\file`) == "");
    }
    ---
*/
C[] driveName(C)(C[] path)  @safe pure //TODO: nothrow
    if (isSomeChar!C)
{
    version (Windows)
    {
        path = stripLeft(path);
        if (path.length > 2  &&  path[1] == ':')  return path[0 .. 2];
    }
    return null;
}


unittest
{
    version (Posix)  assert (driveName("c:/foo") == null);
    version (Windows)
    {
    assert (driveName("dir\\file") == null);
    assert (driveName("d:file") == "d:");
    assert (driveName("d:\\file") == "d:");
    }
}




/** Strip the drive designation from a Windows path.
    On POSIX, this is a noop.

    Example:
    ---
    version (Windows)
    {
        assert (stripDrive(`d:\dir\file`) == `\dir\file`);
    }
    ---
*/
C[] stripDrive(C)(C[] path)  @safe pure nothrow  if (isSomeChar!C)
{
    version(Windows)
        if (path.length >= 2 && isDriveSeparator(path[1])) return path[2 .. $];
    return path;
}


unittest
{
    version(Windows) assert (stripDrive(`d:\dir\file`) == `\dir\file`);
    version(Posix)   assert (stripDrive(`d:\dir\file`) == `d:\dir\file`);
}




/*  Helper function that returns the position of the filename/extension
    separator dot in path.  If not found, returns -1.
*/
private sizediff_t extSeparatorPos(C)(in C[] path)  @safe pure nothrow
    if (isSomeChar!C)
{
    auto i = (cast(sizediff_t) path.length) - 1;
    while (i >= 0 && !isSeparator(path[i]))
    {
        if (path[i] == '.' && i > 0 && !isSeparator(path[i-1])) return i;
        --i;
    }
    return -1;
}




/** Get the extension part of a file name.

    Examples:
    ---
    assert (extension("file")           == "");
    assert (extension("file.ext")       == "ext");
    assert (extension("file.ext1.ext2") == "ext2");
    assert (extension(".file")          == "");
    assert (extension(".file.ext")      == "ext");
    ---
*/
C[] extension(C)(C[] path)  @safe pure nothrow  if (isSomeChar!C)
{
    auto i = extSeparatorPos(path);
    if (i == -1) return null;
    else return path[i+1 .. $];
}


unittest
{
    assert (extension("file") == "");
    assert (extension("file.ext"w) == "ext");
    assert (extension("file.ext1.ext2"d) == "ext2");
    assert (extension(".foo".dup) == "");
    assert (extension(".foo.ext"w.dup) == "ext");

    assert (extension("dir/file"d.dup) == "");
    assert (extension("dir/file.ext") == "ext");
    assert (extension("dir/file.ext1.ext2"w) == "ext2");
    assert (extension("dir/.foo"d) == "");
    assert (extension("dir/.foo.ext".dup) == "ext");

    version(Windows)
    {
    assert (extension("dir\\file") == "");
    assert (extension("dir\\file.ext") == "ext");
    assert (extension("dir\\file.ext1.ext2") == "ext2");
    assert (extension("dir\\.foo") == "");
    assert (extension("dir\\.foo.ext") == "ext");

    assert (extension("d:file") == "");
    assert (extension("d:file.ext") == "ext");
    assert (extension("d:file.ext1.ext2") == "ext2");
    assert (extension("d:.foo") == "");
    assert (extension("d:.foo.ext") == "ext");
    }
}




/** Return the path with the extension stripped off.

    Examples:
    ---
    assert (stripExtension("file")           == "file");
    assert (stripExtension("file.ext")       == "file");
    assert (stripExtension("file.ext1.ext2") == "file.ext1");
    assert (stripExtension(".file")          == ".file");
    assert (stripExtension(".file.ext")      == ".file");
    assert (stripExtension("dir/file.ext")   == "dir/file");
    ---
*/
C[] stripExtension(C)(C[] path)  @safe pure nothrow  if (isSomeChar!C)
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
}




/** Set the extension of a filename.

    If the filename already has an extension, it is replaced.   If not, the
    extension is simply appended to the filename.

    This function normally allocates a new string (the possible exception
    being case when path is immutable and doesn't already have an extension).

    Examples:
    ---
    assert (setExtension("file", "ext")     == "file.ext");
    assert (setExtension("file.old", "new") == "file.new");
    ---
*/
immutable(Unqual!C1)[] setExtension(C1, C2)(in C1[] path, in C2[] ext)
    @trusted pure nothrow
    if (isSomeChar!C1 && !is(C1 == immutable) && is(Unqual!C1 == Unqual!C2))
{
    return cast(typeof(return))(stripExtension(path)~'.'~ext);
}

///ditto
immutable(C1)[] setExtension(C1, C2)(immutable(C1)[] path, in C2[] ext)
    @trusted pure nothrow
    if (isSomeChar!C1 && is(Unqual!C1 == Unqual!C2))
{
    // Optimised for the case where path is immutable and has no extension
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
    assert (setExtension("file.", "ext") == "file.ext");
    assert (setExtension("file.old", "new") == "file.new");

    assert (setExtension("file"w.dup, "ext"w) == "file.ext");
    assert (setExtension("file."w, "ext"w.dup) == "file.ext");
    assert (setExtension("file.old"d.dup, "new"d) == "file.new");
}




/** Set the extension of a filename, but only if it doesn't
    already have one.

    This function always allocates a new string, except in the case when
    path is immutable and already has an extension.

    Examples:
    ---
    assert (defaultExtension("file", "ext")     == "file.ext");
    assert (defaultExtension("file.old", "new") == "file.old");
    ---
*/
immutable(Unqual!C1)[] defaultExtension(C1, C2)(in C1[] path, in C2[] ext)
    @trusted pure // (BUG 5700) nothrow
    if (isSomeChar!C1 && is(Unqual!C1 == Unqual!C2))
{
    auto i = extSeparatorPos(path);
    if (i == -1) return cast(typeof(return))(path~'.'~ext);
    else return path.idup;
}


unittest
{
    auto p1 = defaultExtension("file"w, "ext"w);
    assert (p1 == "file.ext");
    static assert (is(typeof(p1) == wstring));

    auto p2 = defaultExtension("file.old"d, "new"d.dup);
    assert (p2 == "file.old");
    static assert (is(typeof(p2) == dstring));
}




// Detects whether the given types are all string types of the same width
private template compatibleStrings(Strings...)  if (Strings.length > 0)
{
    static if (Strings.length == 1)
    {
        enum compatibleStrings = isSomeChar!(typeof(Strings[0].init[0]));
    }
    else
    {
        enum compatibleStrings =
            is(Unqual!(typeof(Strings[0].init[0])) == Unqual!(typeof(Strings[1].init[0])))
            && compatibleStrings!(Strings[1 .. $]);
    }
}

version (unittest)
{
    static assert (compatibleStrings!(char[], const(char)[], string));
    static assert (compatibleStrings!(wchar[], const(wchar)[], wstring));
    static assert (compatibleStrings!(dchar[], const(dchar)[], dstring));
    static assert (!compatibleStrings!(int[], const(int)[], immutable(int)[]));
    static assert (!compatibleStrings!(char[], wchar[]));
    static assert (!compatibleStrings!(char[], dstring));
}




/** Joins one or more path components.

    The given path components are concatenated with each other,
    and if necessary, directory separators are inserted between
    them. If any of the path components are rooted (see
    $(LINK2 #isRooted,isRooted)) the preceding path components
    will be dropped.

    Examples:
    ---
    version (Posix)
    {
        assert (joinPath("foo", "bar", "baz") == "foo/bar/baz");
        assert (joinPath("/foo/", "bar")      == "/foo/bar");
        assert (joinPath("/foo", "/bar")      == "/bar");
    }

    version (Windows)
    {
        assert (joinPath("foo", "bar", "baz") == `foo\bar\baz`);
        assert (joinPath(`c:\foo`, "bar")    == `c:\foo\bar`);
        assert (joinPath("foo", `d:\bar`)    == `d:\bar`);
        assert (joinPath("foo", `\bar`)      == `\bar`);
    }
    ---
*/
immutable(Unqual!C)[] joinPath(C, Strings...)(in C[] path, in Strings morePaths)
    @trusted // (BUG 5304) pure  (BUG 5700) nothrow
    if (compatibleStrings!(C[], Strings))
{
    // Exactly one path component
    static if (Strings.length == 0)
    {
        return path.idup;
    }

    // Exactly two path components
    else static if (Strings.length == 1)
    {
        alias path path1;
        alias morePaths[0] path2;
        if (path2.length == 0) return path1.idup;
        if (path1.length == 0) return path2.idup;
        if (isRooted(path2)) return path2.idup;

        if (isDirSeparator(path1[$-1]) || isDirSeparator(path2[0]))
            return cast(typeof(return))(path1 ~ path2);
        else
            return cast(typeof(return))(path1 ~ dirSeparator ~ path2);
    }

    // More than two path components
    else
    {
        return joinPath(joinPath(path, morePaths[0]), morePaths[1 .. $]);
    }
}


unittest
{
    version (Posix)
    {
        assert (joinPath("foo") == "foo");
        assert (joinPath("/foo/") == "/foo/");
        assert (joinPath("foo", "bar") == "foo/bar");
        assert (joinPath("foo", "bar", "baz") == "foo/bar/baz");
        assert (joinPath("foo/".dup, "bar") == "foo/bar");
        assert (joinPath("foo///", "bar".dup) == "foo///bar");
        assert (joinPath("/foo"w, "bar"w) == "/foo/bar");
        assert (joinPath("foo"w.dup, "/bar"w) == "/bar");
        assert (joinPath("foo"w, "bar/"w.dup) == "foo/bar/");
        assert (joinPath("/"d, "foo"d) == "/foo");
        assert (joinPath(""d.dup, "foo"d) == "foo");
        assert (joinPath("foo"d, ""d.dup) == "foo");
        assert (joinPath("foo", "bar".dup, "baz") == "foo/bar/baz");
        assert (joinPath("foo"w, "/bar"w, "baz"w.dup) == "/bar/baz");
    }
    version (Windows)
    {
        assert (joinPath("foo") == "foo");
        assert (joinPath(`\foo/`) == `\foo/`);
        assert (joinPath("foo", "bar", "baz") == `foo\bar\baz`);
        assert (joinPath("foo", `\bar`) == `\bar`);
        assert (joinPath(`c:\foo`, "bar") == `c:\foo\bar`);
        assert (joinPath("foo"w, `d:\bar`w.dup) ==  `d:\bar`);
    }
}




/** Returns a forward range that iterates over the elements of a path.

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
auto pathSplitter(C)(const(C)[] path)  //TODO: @safe pure nothrow
    if (isSomeChar!C)
{
    struct PathSplitter
    {
    // TODO: @safe pure nothrow:
    //DMD BUG 5798
        @property empty() { return _empty; }

        @property front()
        {
            assert (!empty, "PathSplitter: called front() on empty range");
            return _front;
        }

        void popFront()
        {
            assert (!empty, "PathSplitter: called popFront() on empty range");
            if (_path.length == 0)
            {
                _empty = true;
            }
            else
            {
                int i = 0;
                while (i < _path.length && !isDirSeparator(_path[i])) ++i;
                _front = _path[0 .. i];
                while (i < _path.length && isDirSeparator(_path[i])) ++i;
                _path = _path[i .. $];
            }
        }

        auto save() { return this; }


    private:
        typeof(path) _path;
        typeof(path) _front;
        bool _empty;

        this(typeof(path) p)
        {
            if (p.length == 0)
            {
                _empty = true;
                return;
            }
            _path = p;

            // If path is rooted, first element is special
            if (isDirSeparator(_path[0]))
            {
                if (_path.length > 2 && isDirSeparator(_path[1])
                    && !isDirSeparator(_path[2]))
                {
                    // Network mount
                    int i = 3;
                    while (i < _path.length && !isDirSeparator(_path[i])) ++i;
                    _front = _path[0 .. i];
                    while (i < _path.length && isDirSeparator(_path[i])) ++i;
                    _path = _path[i .. $];
                }
                else
                {
                    _front = _path[0 .. 1];
                    int i = 1;
                    while (i < _path.length && isDirSeparator(_path[i])) ++i;
                    _path = _path[i .. $];
                }
            }
            else
            {
                version (Posix)
                {
                    popFront();
                }
                else version (Windows)
                {
                    if (_path.length > 2 && isDriveSeparator(_path[1])
                        && isDirSeparator(_path[2]))
                    {
                        _front = _path[0 .. 3];
                        int i = 3;
                        while (i < _path.length && isDirSeparator(_path[i])) ++i;
                        _path = _path[i .. $];
                    }
                    else popFront();
                }
                else static assert (false);
            }
        }
    }

    return PathSplitter(path);
}


unittest
{
    assert (pathSplitter("").empty);

    // Root directories
    assert (equal(pathSplitter("/"), ["/"]));
    assert (equal(pathSplitter("///"), ["/"]));
    assert (equal(pathSplitter("//foo"), ["//foo"]));

    // Absolute paths
    assert (equal(pathSplitter("/foo/bar"), ["/", "foo", "bar"]));
    assert (equal(pathSplitter("//foo/bar"), ["//foo", "bar"]));

    // General
    assert (equal(pathSplitter("foo/bar"), ["foo", "bar"]));
    assert (equal(pathSplitter("foo//bar"), ["foo", "bar"]));
    assert (equal(pathSplitter("foo/bar//"), ["foo", "bar"]));
    assert (equal(pathSplitter("foo/../bar//./"), ["foo", "..", "bar", "."]));

    // save()
    auto ps1 = pathSplitter("foo/bar/baz");
    auto ps2 = ps1.save();
    ps1.popFront;
    assert (equal(ps1, ["bar", "baz"]));
    assert (equal(ps2, ["foo", "bar", "baz"]));

    // Windows-specific
    version (Windows)
    {
        assert (equal(pathSplitter(`\`), [`\`]));
        assert (equal(pathSplitter(`foo\..\bar\/.\`), ["foo", "..", "bar", "."]));
        assert (equal(pathSplitter("c:"), ["c:"]));
        assert (equal(pathSplitter(`c:\foo\bar`), [`c:\`, "foo", "bar"]));
        assert (equal(pathSplitter(`c:foo\bar`), ["c:foo", "bar"]));
    }
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
}




/** Determines whether a path is absolute or not.

    Examples:
    On POSIX, an absolute path starts at the root directory.
    (In fact, $(D _isAbsolute) is just an alias for $(D isRooted).)
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
    a specific drive.  Hence, it must start with "d:\" or "d:/",
    where d is the drive letter.  Alternatively, it may be a
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
    return path.length >= 3 && (
        (isDriveSeparator(path[1]) && isDirSeparator(path[2])) ||
        (isDirSeparator(path[0]) && isDirSeparator(path[1]) && !isDirSeparator(path[2]))
        );
}

else version (Posix) alias isRooted isAbsolute;


unittest
{
    assert (!isAbsolute("foo"));
    assert (!isAbsolute("../foo"w));

    version (Posix)
    {
    assert (isAbsolute("/"d));
    assert (isAbsolute("/foo".dup));
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
    }
}




/** Translate path into an absolute _path.

    This means:
    $(UL
        $(LI If path is empty, return an empty string.)
        $(LI If path is already absolute, return it.)
        $(LI Otherwise, append path to the current working
            directory and return the result.)
    )

    Examples:
    ---
    version (Posix)
    {
        // Assuming the current working directory is /foo/bar
        assert (absolutePath("some/file")  == "/foo/bar/some/file");
        assert (absolutePath("../file")    == "/foo/bar/../file");
        assert (absolutePath("/some/file") == "/some/file");
    }

    version (Windows)
    {
        // Assuming the current working directory is c:\foo\bar
        assert (absolutePath(`some\file`)    == `c:\foo\bar\some\file`);
        assert (absolutePath(`..\file`)      == `c:\foo\bar\..\file`);
        assert (absolutePath(`c:\some\file`) == `c:\some\file`);
    }
    ---
*/
string absolutePath(string path)  // TODO: @safe nothrow
{
    if (path.length == 0)  return null;
    if (isAbsolute(path))  return path;
    return joinPath(getcwd(), path);
}


unittest
{
    version (Posix)
    {
        assert (absolutePath("/foo/bar") == "/foo/bar");
        assert (absolutePath("/foo/.././/bar//") == "/foo/.././/bar//");
    }

    version (Windows)
    {
        assert (absolutePath(`c:\foo\bar`) == `c:\foo\bar`);
        assert (absolutePath(`c:\foo\..\.\\bar\\`) == `c:\foo\..\.\\bar\\`);
    }
}




/** Resolve current/parent directory symbols (. and ..) and remove
    superfluous directory separators.  Replace slashes with
    backslashes on Windows.

    Note that this function does not resolve symbolic links.

    Examples:
    ---
    version (Posix)
    {
        assert (normalize("/foo/./bar/..//baz/") == "/foo/baz");
        assert (normalize("../foo/.") == "../foo");
    }
    version (Windows)
    {
        assert (normalize(`c:\foo\.\bar/..\\baz\`) == `c:\foo\baz`);
        assert (normalize(`..\foo\.`) == `..\foo`);
    }
    ---
*/
immutable(Unqual!C)[] normalize(C)(in C[] path)  //TODO: @safe pure nothrow
    if (isSomeChar!C)
{
    version (Windows)    enum Unqual!C dirSep = '\\';
    else version (Posix) enum Unqual!C dirSep = '/';

    auto segments = pathSplitter(path);
    if (segments.empty) return null;

    auto first = segments.front;
    immutable hasRoot = isRooted(first);
    version (Windows)
    {
        immutable firstSpecial = hasRoot
            || (first.length >= 2 && isDriveSeparator(first[1]));
    }
    else alias hasRoot firstSpecial;
    if (firstSpecial) segments.popFront();

    auto stack = new typeof(first)[(path.length+1)/2];
    size_t stackIndex = 0;

    bool hasParents = false;
    foreach (s; segments)
    {
        if (s == "..")
        {
            if (hasParents)
            {
                assert (stackIndex > 0 && stack[stackIndex-1] != "..");
                --stackIndex;
                hasParents = (stackIndex > 0);
            }
            else if (!hasRoot)
            {
                stack[stackIndex] = s;
                ++stackIndex;
            }
        }
        else if (s != ".")
        {
            stack[stackIndex] = s;
            ++stackIndex;
            hasParents = true;
        }
    }

    // 'normalized' holds the normalized path. 'buffer' is taken
    // as an output range over normalized.
    auto normalized = new Unqual!(C)[path.length];
    auto buffer = normalized;

    // std.range.put doesn't work with narrow strings
    void putc(Unqual!C c) { buffer[0] = c; buffer = buffer[1 .. $]; }
    void puts(const Unqual!(C)[] s) { buffer[0 .. s.length] = s[]; buffer = buffer[s.length .. $]; }

    if (firstSpecial)
    {
        version (Windows)
        {
            foreach (c; first)
            {
                if (c == '/') putc(dirSep);
                else putc(c);
            }
        }
        else
        {
            puts(first);
        }
        if (!isDirSeparator(first[$-1]) && stackIndex > 0) putc(dirSep);
    }
    if (stackIndex > 0)
    {
        foreach (s; stack[0 .. stackIndex-1])
        {
            puts(s);
            putc(dirSep);
        }
        puts(stack[stackIndex-1]);
    }

    return cast(typeof(return)) normalized[0 .. $-buffer.length];
}


unittest
{
    version (Posix)
    {
        // Trivial
        assert (normalize("") == "");
        assert (normalize("foo/bar") == "foo/bar");

        // Correct handling of leading slashes
        assert (normalize("/") == "/");
        assert (normalize("///") == "/");
        assert (normalize("////") == "/");
        assert (normalize("/foo/bar") == "/foo/bar");
        assert (normalize("//foo/bar") == "//foo/bar");
        assert (normalize("//foo") == "//foo");
        assert (normalize("//foo///") == "//foo");
        assert (normalize("///foo/bar") == "/foo/bar");
        assert (normalize("////foo/bar") == "/foo/bar");

        // Correct handling of single-dot symbol (current directory)
        assert (normalize("/./foo") == "/foo");
        assert (normalize("/foo/./bar") == "/foo/bar");

        assert (normalize("./foo") == "foo");
        assert (normalize("././foo") == "foo");
        assert (normalize("foo/././bar") == "foo/bar");

        // Correct handling of double-dot symbol (previous directory)
        assert (normalize("/foo/../bar") == "/bar");
        assert (normalize("/foo/../../bar") == "/bar");
        assert (normalize("/../foo") == "/foo");
        assert (normalize("/../../foo") == "/foo");
        assert (normalize("/foo/..") == "/");
        assert (normalize("/foo/../..") == "/");

        assert (normalize("foo/../bar") == "bar");
        assert (normalize("foo/../../bar") == "../bar");
        assert (normalize("../foo") == "../foo");
        assert (normalize("../../foo") == "../../foo");
        assert (normalize("../foo/../bar") == "../bar");
        assert (normalize(".././../foo") == "../../foo");
        assert (normalize("foo/bar/..") == "foo");
        assert (normalize("/foo/../..") == "/");

        // The ultimate path
        assert (normalize("/foo/../bar//./../...///baz//") == "/.../baz");
    }
    else version (Windows)
    {
        // Trivial
        assert (normalize("") == "");
        assert (normalize(`foo\bar`) == `foo\bar`);
        assert (normalize("foo/bar") == `foo\bar`);

        // Correct handling of absolute paths
        assert (normalize("/") == `\`);
        assert (normalize(`\`) == `\`);
        assert (normalize(`\\\`) == `\`);
        assert (normalize(`\\\\`) == `\`);
        assert (normalize(`\foo\bar`) == `\foo\bar`);
        assert (normalize(`\\foo`) == `\\foo`);
        assert (normalize(`\\foo\\`) == `\\foo`);
        assert (normalize(`\\foo/bar`) == `\\foo\bar`);
        assert (normalize(`\\\foo\bar`) == `\foo\bar`);
        assert (normalize(`\\\\foo\bar`) == `\foo\bar`);
        assert (normalize(`c:\`) == `c:\`);
        assert (normalize(`c:\foo\bar`) == `c:\foo\bar`);
        assert (normalize(`c:\\foo\bar`) == `c:\foo\bar`);

        // Correct handling of single-dot symbol (current directory)
        assert (normalize(`\./foo`) == `\foo`);
        assert (normalize(`\foo/.\bar`) == `\foo\bar`);

        assert (normalize(`.\foo`) == `foo`);
        assert (normalize(`./.\foo`) == `foo`);
        assert (normalize(`foo\.\./bar`) == `foo\bar`);

        // Correct handling of double-dot symbol (previous directory)
        assert (normalize(`\foo\..\bar`) == `\bar`);
        assert (normalize(`\foo\../..\bar`) == `\bar`);
        assert (normalize(`\..\foo`) == `\foo`);
        assert (normalize(`\..\..\foo`) == `\foo`);
        assert (normalize(`\foo\..`) == `\`);
        assert (normalize(`\foo\../..`) == `\`);

        assert (normalize(`foo\..\bar`) == `bar`);
        assert (normalize(`foo\..\../bar`) == `..\bar`);
        assert (normalize(`..\foo`) == `..\foo`);
        assert (normalize(`..\..\foo`) == `..\..\foo`);
        assert (normalize(`..\foo\..\bar`) == `..\bar`);
        assert (normalize(`..\.\..\foo`) == `..\..\foo`);
        assert (normalize(`foo\bar\..`) == `foo`);
        assert (normalize(`\foo\..\..`) == `\`);
        assert (normalize(`c:\foo\..\..`) == `c:\`);

        // Correct handling of non-root path with drive specifier
        assert (normalize(`c:foo`) == `c:foo`);
        assert (normalize(`c:..\foo\.\..\bar`) == `c:..\bar`);

        // The ultimate path
        assert (normalize(`c:\foo\..\bar\\.\..\...\\\baz\\`) == `c:\...\baz`);
    }
    else static assert (false);
}




/** Compare file names.

    Returns (for $(D pred = "a < b")):
    $(BOOKTABLE,
    $(TR $(TD $(D < 0))  $(TD $(D filename1 < filename2) ))
    $(TR $(TD $(D = 0))  $(TD $(D filename1 == filename2)))
    $(TR $(TD $(D > 0))  $(TD $(D filename1 > filename2)))
    )

    On Windows, $(D fcmp) is an alias for $(D std.string.icmp),
    which yields a case insensitive comparison.
    On POSIX, it is an alias for $(D std.algorithm.cmp), i.e. a
    case sensitive comparison.
 */
// TODO: @safe pure nothrow
version (StdDdoc) int fcmp(alias pred = "a < b", S1, S2)(S1 filename1, S2 filename2);
else version (Windows) alias std.string.icmp fcmp;
else version (Posix) alias std.algorithm.cmp fcmp;




/** Matches path characters.

    Under Windows, the comparison is done ignoring case. Under Linux
    an exact match is performed.

    Returns: $(D true) if c1 matches c2, $(D false) otherwise.

    Examples:
    -----
    version(Windows)
    {
        assert (!pathCharMatch('a', 'b'));
        assert (pathCharMatch('A', 'a'));
    }
    version(Posix)
    {
        assert (!pathCharMatch('a', 'b'));
        assert (!pathCharMatch('A', 'a'));
    }
    -----
 */
bool pathCharMatch(dchar c1, dchar c2)  @safe pure nothrow
{
    version (Windows)
    {
        if (c1 != c2)
        {
            if ('A' <= c1 && c1 <= 'Z')
                c1 += cast(char)'a' - 'A';
            if ('A' <= c2 && c2 <= 'Z')
                c2 += cast(char)'a' - 'A';
            return c1 == c2;
        }
        return true;
    }
    else version (Posix)
    {
        return c1 == c2;
    }
    else
    {
        static assert(0);
    }
}




/** Matches a pattern against a path.

    Some characters of pattern have special a meaning (they are
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

    Internally individual character comparisons are done calling
    $(D pathCharMatch()), so its rules apply here too. Note that directory
    separators and dots don't stop a meta-character from matching
    further portions of the path.

    Returns:
    $(D true) if pattern matches path, $(D false) otherwise.

    See_also:
    $(LINK2 http://en.wikipedia.org/wiki/Glob_%28programming%29,Wikipedia: _glob (programming))

    Examples:
    -----
    assert (glob("foo.bar", "*"));
    assert (glob("foo.bar", "*.*"));
    assert (glob(`foo/foo\bar`, "f*b*r"));
    assert (glob("foo.bar", "f???bar"));
    assert (glob("foo.bar", "[fg]???bar"));
    assert (glob("foo.bar", "[!gh]*bar"));
    assert (glob("bar.fooz", "bar.{foo,bif}z"));
    assert (glob("bar.bifz", "bar.{foo,bif}z"));

    version (Windows)
    {
        assert (glob("foo", "Foo"));
        assert (glob("Goo.bar", "[fg]???bar"));
    }
    version (Posix)
    {
        assert (!glob("foo", "Foo"));
        assert (!glob("Goo.bar", "[fg]???bar"));
    }
    -----
 */
bool glob(const(char)[] path, const(char)[] pattern)  @safe nothrow //TODO: pure
in
{
    // Verify that pattern[] is valid
    assert(balancedParens(pattern, '[', ']', 0));
    assert(balancedParens(pattern, '{', '}', 0));
}
body
{
	size_t ni; // current character in path

    foreach (pi; 0 .. pattern.length)
    {
        char pc = pattern[pi];
        switch (pc)
        {
            case '*':
                if (pi + 1 == pattern.length)
                    return true;
                foreach (j; ni .. path.length)
                {
                    if (glob(path[j .. path.length],
                                    pattern[pi + 1 .. pattern.length]))
                        return true;
                }
                return false;

            case '?':
                if (ni == path.length)
                    return false;
                ni++;
                break;

            case '[': {
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
                    if (!anymatch && pathCharMatch(nc, pc))
                        anymatch = true;
                    pi++;
                }
                if (anymatch == not)
                    return false;
            }
                break;

            case '{': {
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
                        if (glob(path[ni..$], pattern[piRemain..$]))
                        {
                            return true;
                        }
                        pi++;
                    }
                    else
                    {
                        if (glob(path[ni..$],
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
            }
                return false;

            default:
                if (ni == path.length)
                    return false;
                if (!pathCharMatch(pc, path[ni]))
                    return false;
                ni++;
                break;
	    }
	}
    assert(ni >= path.length);
	return ni == path.length;
}

unittest
{
    version (Windows) assert(glob("foo", "Foo"));
    version (Posix) assert(!glob("foo", "Foo"));
    assert(glob("foo", "*"));
    assert(glob("foo.bar", "*"));
    assert(glob("foo.bar", "*.*"));
    assert(glob("foo.bar", "foo*"));
    assert(glob("foo.bar", "f*bar"));
    assert(glob("foo.bar", "f*b*r"));
    assert(glob("foo.bar", "f???bar"));
    assert(glob("foo.bar", "[fg]???bar"));
    assert(glob("foo.bar", "[!gh]*bar"));

    assert(!glob("foo", "bar"));
    assert(!glob("foo", "*.*"));
    assert(!glob("foo.bar", "f*baz"));
    assert(!glob("foo.bar", "f*b*x"));
    assert(!glob("foo.bar", "[gh]???bar"));
    assert(!glob("foo.bar", "[!fg]*bar"));
    assert(!glob("foo.bar", "[fg]???baz"));

    assert(glob("foo.bar", "{foo,bif}.bar"));
    assert(glob("bif.bar", "{foo,bif}.bar"));

    assert(glob("bar.foo", "bar.{foo,bif}"));
    assert(glob("bar.bif", "bar.{foo,bif}"));

    assert(glob("bar.fooz", "bar.{foo,bif}z"));
    assert(glob("bar.bifz", "bar.{foo,bif}z"));

    assert(glob("bar.foo", "bar.{biz,,baz}foo"));
    assert(glob("bar.foo", "bar.{biz,}foo"));
    assert(glob("bar.foo", "bar.{,biz}foo"));
    assert(glob("bar.foo", "bar.{}foo"));

    assert(glob("bar.foo", "bar.{ar,,fo}o"));
    assert(glob("bar.foo", "bar.{,ar,fo}o"));
    assert(glob("bar.o", "bar.{,ar,fo}o"));
}




/** Performs tilde expansion in paths.

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

    Returns:
    inputPath with the tilde expanded, or just inputPath
    if it could not be expanded.
    For Windows, expandTilde() merely returns its argument inputPath.

    Throws:
    OutOfMemoryException if there is not enough memory to perform
    the database lookup for the $(D ~user) syntax.

    Examples:
    -----
    import std.path;

    void process_file(string filename)
    {
        string path = expandTilde(filename);
        ...
    }
    -----

    -----
    import std.path;

    string RESOURCE_DIR_TEMPLATE = "~/.applicationrc";
    string RESOURCE_DIR;    // This gets expanded in main().

    int main(string[] args)
    {
        RESOURCE_DIR = expandTilde(RESOURCE_DIR_TEMPLATE);
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
            size_t end = std.c.string.strlen(c_path);

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
            auto last_char = std.algorithm.countUntil(path, dirSeparator[0]);

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
                extra_memory = std.c.stdlib.malloc(extra_memory_size);
                if (extra_memory == null)
                    goto Lerror;

                // Obtain info from database.
                passwd *verify;
                setErrno(0);
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
                std.c.stdlib.free(extra_memory);
                extra_memory_size *= 2;
            }

            path = combineCPathWithDPath(result.pw_dir, path, last_char);

        Lnotfound:
            std.c.stdlib.free(extra_memory);
            return path;

        Lerror:
            // Errors are going to be caused by running out of memory
            if (extra_memory)
                std.c.stdlib.free(extra_memory);
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




deprecated:
// Kept for backwards compatibility
alias dirSeparator sep;
enum string altsep = "/";
alias pathSeparator pathsep;
version(Windows) enum string linesep = "\r\n";
version(Posix) enum string linesep = "\n";
enum string curdir = ".";
enum string pardir = "..";
alias extension getExt;
string getName(string path) { return baseName(stripExtension(path)); }
alias baseName getBaseName;
alias baseName basename;
alias dirName dirname;
alias dirName getDirName;
alias driveName getDrive;
alias defaultExtension defaultExt;
alias setExtension addExt;
alias isAbsolute isabs;
alias absolutePath rel2abs;
alias joinPath join;
alias pathCharMatch fncharmatch;
alias glob fnmatch;
