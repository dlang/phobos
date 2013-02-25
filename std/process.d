// Written in the D programming language.

/**
Macros:

WIKI=Phobos/StdProcess

Copyright: Copyright Digital Mars 2007 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu),
           $(WEB thecybershadow.net, Vladimir Panteleev)
Source:    $(PHOBOSSRC std/_process.d)
*/
/*
         Copyright Digital Mars 2007 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.process;


import core.stdc.stdlib;
import std.c.stdlib;
import core.stdc.errno;
import core.thread;
import std.c.process;
import std.c.string;

import std.array;
import std.conv;
import std.exception;
import std.internal.processinit;
import std.stdio;
import std.string;
import std.typecons;

version (Windows)
{
    import std.format, std.random, std.file;
    import core.sys.windows.windows;
    import std.utf;
    import std.windows.syserror;
}
version (Posix)
{
    import core.sys.posix.stdlib;
}
version (unittest)
{
    import std.file, std.conv, std.array, std.random;
    import std.path : absolutePath;
}


// The following is needed for reading/writing environment variables.
version(Posix)
{
    version(OSX)
    {
        // https://www.gnu.org/software/gnulib/manual/html_node/environ.html
        private extern(C) extern __gshared char*** _NSGetEnviron();
        __gshared char** environ;

        // Run in std.__processinit to avoid cyclic construction errors.
        extern(C) void std_process_static_this()
        {
            environ = *_NSGetEnviron();
        }
    }
    else
    {
        // Made available by the C runtime:
        private extern(C) extern __gshared const char** environ;
    }
}


/**
   Execute $(D command) in a _command shell.

   Returns: If $(D command) is null, returns nonzero if the _command
   interpreter is found, and zero otherwise. If $(D command) is not
   null, returns -1 on error, or the exit status of command (which may
   in turn signal an error in command's execution).

   Note: On Unix systems, the homonym C function (which is accessible
   to D programs as $(LINK2 std_c_process.html, std.c._system))
   returns a code in the same format as $(LUCKY waitpid, waitpid),
   meaning that C programs must use the $(D WEXITSTATUS) macro to
   extract the actual exit code from the $(D system) call. D's $(D
   system) automatically extracts the exit status.

*/

int system(string command)
{
    if (!command) return std.c.process.system(null);
    const commandz = toStringz(command);
    immutable status = std.c.process.system(commandz);
    if (status == -1) return status;
    version (Posix)
    {
        if (exited(status))
            return exitstatus(status);

        // Abnormal termination, return -1.
        return -1;
    }
    else version (Windows)
        return status;
    else
        static assert(0, "system not implemented for this OS.");
}

private void toAStringz(in string[] a, const(char)**az)
{
    foreach(string s; a)
    {
        *az++ = toStringz(s);
    }
    *az = null;
}


/* ========================================================== */

//version (Windows)
//{
//    int spawnvp(int mode, string pathname, string[] argv)
//    {
//      char** argv_ = cast(char**)alloca((char*).sizeof * (1 + argv.length));
//
//      toAStringz(argv, argv_);
//
//      return std.c.process.spawnvp(mode, toStringz(pathname), argv_);
//    }
//}

// Incorporating idea (for spawnvp() on Posix) from Dave Fladebo

alias std.c.process._P_WAIT P_WAIT;
alias std.c.process._P_NOWAIT P_NOWAIT;

int spawnvp(int mode, string pathname, string[] argv)
{
    auto argv_ = cast(const(char)**)alloca((char*).sizeof * (1 + argv.length));

    toAStringz(argv, argv_);

    version (Posix)
    {
        return _spawnvp(mode, toStringz(pathname), argv_);
    }
    else version (Windows)
    {
        return std.c.process.spawnvp(mode, toStringz(pathname), argv_);
    }
    else
        static assert(0, "spawnvp not implemented for this OS.");
}

version (Posix)
{
private import core.sys.posix.unistd;
private import core.sys.posix.sys.wait;
int _spawnvp(int mode, in char *pathname, in char **argv)
{
    int retval = 0;
    pid_t pid = fork();

    if(!pid)
    {   // child
        std.c.process.execvp(pathname, argv);
        goto Lerror;
    }
    else if(pid > 0)
    {   // parent
        if(mode == _P_NOWAIT)
        {
            retval = pid; // caller waits
        }
        else
        {
            while(1)
            {
                int status;
                pid_t wpid = waitpid(pid, &status, 0);
                if(exited(status))
                {
                    retval = exitstatus(status);
                    break;
                }
                else if(signaled(status))
                {
                    retval = -termsig(status);
                    break;
                }
                else if(stopped(status)) // ptrace support
                    continue;
                else
                    goto Lerror;
            }
        }

        return retval;
    }

Lerror:
    retval = errno;
    char[80] buf = void;
    throw new Exception(
        "Cannot spawn " ~ to!string(pathname) ~ "; "
        ~ to!string(strerror_r(retval, buf.ptr, buf.length))
        ~ " [errno " ~ to!string(retval) ~ "]");
}   // _spawnvp
private
{
    alias WIFSTOPPED stopped;
    alias WIFSIGNALED signaled;
    alias WTERMSIG termsig;
    alias WIFEXITED exited;
    alias WEXITSTATUS exitstatus;
}   // private
}   // version (Posix)

/* ========================================================== */

/**
 * Replace the current process by executing a command, $(D pathname), with
 * the arguments in $(D argv). Typically, the first element of $(D argv) is
 * the command being executed, i.e. $(D argv[0] == pathname). The 'p'
 * versions of $(D exec) search the PATH environment variable for $(D
 * pathname). The 'e' versions additionally take the new process'
 * environment variables as an array of strings of the form key=value.
 *
 * Does not return on success (the current process will have been
 * replaced). Returns -1 on failure with no indication of the
 * underlying error.
 */

int execv(in string pathname, in string[] argv)
{
    auto argv_ = cast(const(char)**)alloca((char*).sizeof * (1 + argv.length));

    toAStringz(argv, argv_);

    return std.c.process.execv(toStringz(pathname), argv_);
}

/** ditto */
int execve(in string pathname, in string[] argv, in string[] envp)
{
    auto argv_ = cast(const(char)**)alloca((char*).sizeof * (1 + argv.length));
    auto envp_ = cast(const(char)**)alloca((char*).sizeof * (1 + envp.length));

    toAStringz(argv, argv_);
    toAStringz(envp, envp_);

    return std.c.process.execve(toStringz(pathname), argv_, envp_);
}

/** ditto */
int execvp(in string pathname, in string[] argv)
{
    auto argv_ = cast(const(char)**)alloca((char*).sizeof * (1 + argv.length));

    toAStringz(argv, argv_);

    return std.c.process.execvp(toStringz(pathname), argv_);
}

/** ditto */
int execvpe(in string pathname, in string[] argv, in string[] envp)
{
version(Posix)
{
    // Is pathname rooted?
    if(pathname[0] == '/')
    {
        // Yes, so just call execve()
        return execve(pathname, argv, envp);
    }
    else
    {
        // No, so must traverse PATHs, looking for first match
        string[]    envPaths    =   std.array.split(
            to!string(core.stdc.stdlib.getenv("PATH")), ":");
        int         iRet        =   0;

        // Note: if any call to execve() succeeds, this process will cease
        // execution, so there's no need to check the execve() result through
        // the loop.

        foreach(string pathDir; envPaths)
        {
            string  composite   =  cast(string) (pathDir ~ "/" ~ pathname);

            iRet = execve(composite, argv, envp);
        }
        if(0 != iRet)
        {
            iRet = execve(pathname, argv, envp);
        }

        return iRet;
    }
}
else version(Windows)
{
    auto argv_ = cast(const(char)**)alloca((char*).sizeof * (1 + argv.length));
    auto envp_ = cast(const(char)**)alloca((char*).sizeof * (1 + envp.length));

    toAStringz(argv, argv_);
    toAStringz(envp, envp_);

    return std.c.process.execvpe(toStringz(pathname), argv_, envp_);
}
else
{
    static assert(0);
} // version
}

/**
 * Returns the process ID of the calling process, which is guaranteed to be
 * unique on the system. This call is always successful.
 *
 * Example:
 * ---
 * writefln("Current process id: %s", getpid());
 * ---
 */
alias core.thread.getpid getpid;

/**
   Runs $(D_PARAM cmd) in a shell and returns its standard output. If
   the process could not be started or exits with an error code,
   throws ErrnoException.

   Example:

   ----
   auto tempFilename = chomp(shell("mcookie"));
   auto f = enforce(fopen(tempFilename), "w");
   scope(exit)
   {
       fclose(f) == 0 || assert(false);
       system(escapeShellCommand("rm", tempFilename));
   }
   ... use f ...
   ----
*/
string shell(string cmd)
{
    version(Windows)
    {
        // Generate a random filename
        auto a = appender!string();
        foreach (ref e; 0 .. 8)
        {
            formattedWrite(a, "%x", rndGen.front);
            rndGen.popFront();
        }
        auto filename = a.data;
        scope(exit) if (exists(filename)) remove(filename);
        // We can't use escapeShellCommands here because we don't know
        // if cmd is escaped (wrapped in quotes) or not, without relying
        // on shady heuristics. The current code shouldn't cause much
        // trouble unless filename contained spaces (it won't).
        errnoEnforce(system(cmd ~ "> " ~ filename) == 0);
        return readText(filename);
    }
    else version(Posix)
    {
        File f;
        f.popen(cmd, "r");
        char[] line;
        string result;
        while (f.readln(line))
        {
            result ~= line;
        }
        f.close();
        return result;
    }
    else
        static assert(0, "shell not implemented for this OS.");
}

unittest
{
    auto x = shell("echo wyda");
    // @@@ This fails on wine
    //assert(x == "wyda" ~ newline, text(x.length));

    import std.exception;  // Issue 9444
    assertThrown!ErrnoException(shell("qwertyuiop09813478"));
}

/**
Gets the value of environment variable $(D name) as a string. Calls
$(LINK2 std_c_stdlib.html#_getenv, std.c.stdlib._getenv)
internally. */

string getenv(in char[] name)
{
    // Cache the last call's result
    static string lastResult;
    auto p = core.stdc.stdlib.getenv(toStringz(name));
    if (!p) return null;
    auto value = p[0 .. strlen(p)];
    if (value == lastResult) return lastResult;
    return lastResult = value.idup;
}

/**
Sets the value of environment variable $(D name) to $(D value). If the
value was written, or the variable was already present and $(D
overwrite) is false, returns normally. Otherwise, it throws an
exception. Calls $(LINK2 std_c_stdlib.html#_setenv,
std.c.stdlib._setenv) internally. */
version(StdDdoc) void setenv(in char[] name, in char[] value, bool overwrite);
else version(Posix) void setenv(in char[] name, in char[] value, bool overwrite)
{
    errnoEnforce(
        std.c.stdlib.setenv(toStringz(name), toStringz(value), overwrite) == 0);
}

/**
Removes variable $(D name) from the environment. Calls $(LINK2
std_c_stdlib.html#_unsetenv, std.c.stdlib._unsetenv) internally. */
version(StdDdoc) void unsetenv(in char[] name);
else version(Posix) void unsetenv(in char[] name)
{
    errnoEnforce(std.c.stdlib.unsetenv(toStringz(name)) == 0);
}

version (Posix) unittest
{
    setenv("wyda", "geeba", true);
    assert(getenv("wyda") == "geeba");
    // Get again to make sure caching works
    assert(getenv("wyda") == "geeba");
    unsetenv("wyda");
    assert(getenv("wyda") is null);
}

/* ////////////////////////////////////////////////////////////////////////// */

version(MainTest)
{
    int main(string[] args)
    {
        if(args.length < 2)
        {
            printf("Must supply executable (and optional arguments)\n");

            return 1;
        }
        else
        {
            string[]    dummy_env;

            dummy_env ~= "VAL0=value";
            dummy_env ~= "VAL1=value";

/+
            foreach(string arg; args)
            {
                printf("%.*s\n", arg);
            }
+/

//          int i = execv(args[1], args[1 .. args.length]);
//          int i = execvp(args[1], args[1 .. args.length]);
            int i = execvpe(args[1], args[1 .. args.length], dummy_env);

            printf("exec??() has returned! Error code: %d; errno: %d\n", i, /* errno */-1);

            return 0;
        }
    }
}

/* ////////////////////////////////////////////////////////////////////////// */




/** Manipulates environment variables using an associative-array-like
    interface.

    Examples:
    ---
    // Return variable, or throw an exception if it doesn't exist.
    auto path = environment["PATH"];

    // Add/replace variable.
    environment["foo"] = "bar";

    // Remove variable.
    environment.remove("foo");

    // Return variable, or null if it doesn't exist.
    auto foo = environment.get("foo");

    // Return variable, or a default value if it doesn't exist.
    auto foo = environment.get("foo", "default foo value");

    // Return an associative array of type string[string] containing
    // all the environment variables.
    auto aa = environment.toAA();
    ---
*/
alias Environment environment;

abstract final class Environment
{
static:
private:
    // Return the length of an environment variable (in number of
    // wchars, including the null terminator), 0 if it doesn't exist.
    version(Windows)
    int varLength(LPCWSTR namez)
    {
        return GetEnvironmentVariableW(namez, null, 0);
    }


    // Retrieve the environment variable, or return false on failure.
    bool getImpl(string name, out string value)
    {
        version(Posix)
        {
            const vz = core.sys.posix.stdlib.getenv(toStringz(name));
            if (vz == null) return false;
            auto v = vz[0 .. strlen(vz)];

            // Cache the last call's result.
            static string lastResult;
            if (v != lastResult) lastResult = v.idup;
            value = lastResult;
            return true;
        }

        else version(Windows)
        {
            const namez = toUTF16z(name);
            immutable len = varLength(namez);
            if (len == 0) return false;
            if (len == 1) return true;

            auto buf = new WCHAR[len];
            GetEnvironmentVariableW(namez, buf.ptr, to!DWORD(buf.length));
            value = toUTF8(buf[0 .. $-1]);
            return true;
        }

        else static assert(0);
    }



public:
    // Retrieve an environment variable, throw on failure.
    string opIndex(string name)
    {
        string value;
        enforce(getImpl(name, value), "Environment variable not found: "~name);
        return value;
    }



    // Assign a value to an environment variable.  If the variable
    // exists, it is overwritten.
    string opIndexAssign(string value, string name)
    {
        version(Posix)
        {
            if (core.sys.posix.stdlib.setenv(toStringz(name),
                toStringz(value), 1) != -1)
            {
                return value;
            }

            // The default errno error message is very uninformative
            // in the most common case, so we handle it manually.
            enforce(errno != EINVAL,
                "Invalid environment variable name: '"~name~"'");
            errnoEnforce(false,
                "Failed to add environment variable");
            assert(0);
        }

        else version(Windows)
        {
            enforce(
                SetEnvironmentVariableW(toUTF16z(name), toUTF16z(value)),
                sysErrorString(GetLastError())
            );
            return value;
        }

        else static assert(0);
    }



    // Remove an environment variable.  The function succeeds even
    // if the variable isn't in the environment.
    void remove(string name)
    {
        version(Posix)
        {
            core.sys.posix.stdlib.unsetenv(toStringz(name));
        }

        else version(Windows)
        {
            SetEnvironmentVariableW(toUTF16z(name), null);
        }

        else static assert(0);
    }



    // Same as opIndex, except return a default value if
    // the variable doesn't exist.
    string get(string name, string defaultValue = null)
    {
        string value;
        auto found = getImpl(name, value);
        return found ? value : defaultValue;
    }



    // Return all environment variables in an associative array.
    string[string] toAA()
    {
        string[string] aa;

        version(Posix)
        {
            for (int i=0; environ[i] != null; ++i)
            {
                immutable varDef = to!string(environ[i]);
                immutable eq = varDef.indexOf('=');
                assert (eq >= 0);

                immutable name = varDef[0 .. eq];
                immutable value = varDef[eq+1 .. $];

                // In POSIX, environment variables may be defined more
                // than once.  This is a security issue, which we avoid
                // by checking whether the key already exists in the array.
                // For more info:
                // http://www.dwheeler.com/secure-programs/Secure-Programs-HOWTO/environment-variables.html
                if (name !in aa)  aa[name] = value;
            }
        }

        else version(Windows)
        {
            auto envBlock = GetEnvironmentStringsW();
            enforce (envBlock, "Failed to retrieve environment variables.");
            scope(exit) FreeEnvironmentStringsW(envBlock);

            for (int i=0; envBlock[i] != '\0'; ++i)
            {
                auto start = i;
                while (envBlock[i] != '=')
                {
                    assert (envBlock[i] != '\0');
                    ++i;
                }
                immutable name = toUTF8(envBlock[start .. i]);

                start = i+1;
                while (envBlock[i] != '\0') ++i;
                aa[name] = toUTF8(envBlock[start .. i]);
            }
        }

        else static assert(0);

        return aa;
    }

}


unittest
{
    // New variable
    environment["std_process"] = "foo";
    assert (environment["std_process"] == "foo");

    // Set variable again
    environment["std_process"] = "bar";
    assert (environment["std_process"] == "bar");

    // Remove variable
    environment.remove("std_process");

    // Remove again, should succeed
    environment.remove("std_process");

    // Throw on not found.
    try { environment["std_process"]; assert(0); } catch(Exception e) { }

    // get() without default value
    assert (environment.get("std.process") == null);

    // get() with default value
    assert (environment.get("std_process", "baz") == "baz");

    // Convert to associative array
    auto aa = environment.toAA();
    assert (aa.length > 0);
    foreach (n, v; aa)
    {
        // Wine has some bugs related to environment variables:
        //  - Wine allows the existence of an env. variable with the name
        //    "\0", but GetEnvironmentVariable refuses to retrieve it.
        //  - If an env. variable has zero length, i.e. is "\0",
        //    GetEnvironmentVariable should return 1.  Instead it returns
        //    0, indicating the variable doesn't exist.
        version(Windows)  if (n.length == 0 || v.length == 0) continue;

        // why does this happen?
        //   n = "temp" || "tmp"
        //   v = "C:\Users\ADMINI~1\AppData\Local\Temp\2"
        //   e[n] = "C:\cygwin\tmp"
        // for n = "TEMP" or "TMP", v and en[v] are both "C:\cygwin\tmp"
        version(Windows)  if (n == "temp" || n == "tmp") continue;

        //printf("%.*s, %.*s, %.*s\n", n.length, n.ptr, v.length, v.ptr, environment[n].length, environment[n].ptr);
        assert (v == environment[n]);
    }
}


version(StdDdoc)
{
    /****************************************
     * Start up the browser and set it to viewing the page at url.
     */
    void browse(string url);
}
else
version (Windows)
{
    import core.sys.windows.windows;

    extern (Windows)
    HINSTANCE ShellExecuteA(HWND hwnd, LPCSTR lpOperation, LPCSTR lpFile, LPCSTR lpParameters, LPCSTR lpDirectory, INT nShowCmd);


    pragma(lib,"shell32.lib");

    void browse(string url)
    {
        ShellExecuteA(null, "open", toStringz(url), null, null, SW_SHOWNORMAL);
    }
}
else version (OSX)
{
    import core.stdc.stdio;
    import core.stdc.string;
    import core.sys.posix.unistd;

    void browse(string url)
    {
        const(char)*[5] args;

        const(char)* browser = core.stdc.stdlib.getenv("BROWSER");
        if (browser)
        {   browser = strdup(browser);
            args[0] = browser;
            args[1] = toStringz(url);
            args[2] = null;
        }
        else
        {
            args[0] = "open".ptr;
            args[1] = toStringz(url);
            args[2] = null;
        }

        auto childpid = fork();
        if (childpid == 0)
        {
            core.sys.posix.unistd.execvp(args[0], cast(char**)args.ptr);
            perror(args[0]);                // failed to execute
            return;
        }
        if (browser)
            free(cast(void*)browser);
    }
}
else version (Posix)
{
    import core.stdc.stdio;
    import core.stdc.string;
    import core.sys.posix.unistd;

    void browse(string url)
    {
        const(char)*[3] args;

        const(char)* browser = core.stdc.stdlib.getenv("BROWSER");
        if (browser)
        {   browser = strdup(browser);
            args[0] = browser;
        }
        else
            //args[0] = "x-www-browser".ptr;  // doesn't work on some systems
            args[0] = "xdg-open".ptr;

        args[1] = toStringz(url);
        args[2] = null;

        auto childpid = fork();
        if (childpid == 0)
        {
            core.sys.posix.unistd.execvp(args[0], cast(char**)args.ptr);
            perror(args[0]);                // failed to execute
            return;
        }
        if (browser)
            free(cast(void*)browser);
    }
}
else
    static assert(0, "os not supported");


/* ////////////////////////////////////////////////////////////////////////// */

/*
    Command line arguments exist in three forms:
    1) string or char* array, as received by main.
       Also used internally on POSIX systems.
    2) Command line string, as used in Windows'
       CreateProcess and CommandLineToArgvW functions.
       A specific quoting and escaping algorithm is used
       to distinguish individual arguments.
    3) Shell command string, as written at a shell prompt
       or passed to cmd /C - this one may contain shell
       control characters, e.g. > or | for redirection /
       piping - thus, yet another layer of escaping is
       used to distinguish them from program arguments.

    Except for escapeWindowsArgument, the intermediary
    format (2) is hidden away from the user in this module.
*/

pure @safe nothrow
private char[] charAllocator(size_t size) { return new char[size]; }

/**
    Quote an argument in a manner conforming to the behavior of
    $(LINK2 http://msdn.microsoft.com/en-us/library/windows/desktop/bb776391(v=vs.85).aspx,
    CommandLineToArgvW).
*/

pure nothrow
string escapeWindowsArgument(in char[] arg)
{
    // Rationale for leaving this function as public:
    // this algorithm of escaping paths is also used in other software,
    // e.g. DMD's response files.

    auto buf = escapeWindowsArgumentImpl!charAllocator(arg);
    return assumeUnique(buf);
}

@safe nothrow
private char[] escapeWindowsArgumentImpl(alias allocator)(in char[] arg)
    if (is(typeof(allocator(size_t.init)[0] = char.init)))
{
    // References:
    // * http://msdn.microsoft.com/en-us/library/windows/desktop/bb776391(v=vs.85).aspx
    // * http://blogs.msdn.com/b/oldnewthing/archive/2010/09/17/10063629.aspx

    // Calculate the total string size.

    // Trailing backslashes must be escaped
    bool escaping = true;
    // Result size = input size + 2 for surrounding quotes + 1 for the
    // backslash for each escaped character.
    size_t size = 1 + arg.length + 1;

    foreach_reverse (c; arg)
    {
        if (c == '"')
        {
            escaping = true;
            size++;
        }
        else
        if (c == '\\')
        {
            if (escaping)
                size++;
        }
        else
            escaping = false;
    }

    // Construct result string.

    auto buf = allocator(size);
    size_t p = size;
    buf[--p] = '"';
    escaping = true;
    foreach_reverse (c; arg)
    {
        if (c == '"')
            escaping = true;
        else
        if (c != '\\')
            escaping = false;

        buf[--p] = c;
        if (escaping)
            buf[--p] = '\\';
    }
    buf[--p] = '"';
    assert(p == 0);

    return buf;
}

version(Windows) version(unittest)
{
    import core.sys.windows.windows;
    import core.stdc.stddef;

    extern (Windows) wchar_t**  CommandLineToArgvW(wchar_t*, int*);
    extern (C) size_t wcslen(in wchar *);

    unittest
    {
        string[] testStrings = [
            `Hello`,
            `Hello, world`,
            `Hello, "world"`,
            `C:\`,
            `C:\dmd`,
            `C:\Program Files\`,
        ];

        enum CHARS = `_x\" *&^`; // _ is placeholder for nothing
        foreach (c1; CHARS)
        foreach (c2; CHARS)
        foreach (c3; CHARS)
        foreach (c4; CHARS)
            testStrings ~= [c1, c2, c3, c4].replace("_", "");

        foreach (s; testStrings)
        {
            auto q = escapeWindowsArgument(s);
            LPWSTR lpCommandLine = (to!(wchar[])("Dummy.exe " ~ q) ~ "\0"w).ptr;
            int numArgs;
            LPWSTR* args = CommandLineToArgvW(lpCommandLine, &numArgs);
            scope(exit) LocalFree(args);
            assert(numArgs==2, s ~ " => " ~ q ~ " #" ~ text(numArgs-1));
            auto arg = to!string(args[1][0..wcslen(args[1])]);
            assert(arg == s, s ~ " => " ~ q ~ " => " ~ arg);
        }
    }
}

pure nothrow
private string escapePosixArgument(in char[] arg)
{
    auto buf = escapePosixArgumentImpl!charAllocator(arg);
    return assumeUnique(buf);
}

@safe nothrow
private char[] escapePosixArgumentImpl(alias allocator)(in char[] arg)
    if (is(typeof(allocator(size_t.init)[0] = char.init)))
{
    // '\'' means: close quoted part of argument, append an escaped
    // single quote, and reopen quotes

    // Below code is equivalent to:
    // return `'` ~ std.array.replace(arg, `'`, `'\''`) ~ `'`;

    size_t size = 1 + arg.length + 1;
    foreach (c; arg)
        if (c == '\'')
            size += 3;

    auto buf = allocator(size);
    size_t p = 0;
    buf[p++] = '\'';
    foreach (c; arg)
        if (c == '\'')
        {
            buf[p..p+4] = `'\''`;
            p += 4;
        }
        else
            buf[p++] = c;
    buf[p++] = '\'';
    assert(p == size);

    return buf;
}

@safe nothrow
private auto escapeShellArgument(alias allocator)(in char[] arg)
{
    // The unittest for this function requires special
    // preparation - see below.

    version (Windows)
        return escapeWindowsArgumentImpl!allocator(arg);
    else
        return escapePosixArgumentImpl!allocator(arg);
}

pure nothrow
private string escapeShellArguments(in char[][] args)
{
    char[] buf;

    @safe nothrow
    char[] allocator(size_t size)
    {
        if (buf.length == 0)
            return buf = new char[size];
        else
        {
            auto p = buf.length;
            buf.length = buf.length + 1 + size;
            buf[p++] = ' ';
            return buf[p..p+size];
        }
    }

    foreach (arg; args)
        escapeShellArgument!allocator(arg);
    return assumeUnique(buf);
}

string escapeWindowsShellCommand(in char[] command)
{
    auto result = appender!string();
    result.reserve(command.length);

    foreach (c; command)
        switch (c)
        {
            case '\0':
                assert(0, "Cannot put NUL in command line");
            case '\r':
            case '\n':
                assert(0, "CR/LF are not escapable");
            case '\x01': .. case '\x09':
            case '\x0B': .. case '\x0C':
            case '\x0E': .. case '\x1F':
            case '"':
            case '^':
            case '&':
            case '<':
            case '>':
            case '|':
                result.put('^');
                goto default;
            default:
                result.put(c);
        }
    return result.data;
}

private string escapeShellCommandString(string command)
{
    version (Windows)
        return escapeWindowsShellCommand(command);
    else
        return command;
}

/**
    Escape an argv-style argument array to be used with the
    $(D system) or $(D shell) functions.

    Example:
---
string url = "http://dlang.org/";
system(escapeShellCommand("wget", url, "-O", "dlang-index.html"));
---

    Concatenate multiple $(D escapeShellCommand) and
    $(D escapeShellFileName) results to use shell redirection or
    piping operators.

    Example:
---
system(
    escapeShellCommand("curl", "http://dlang.org/download.html") ~
    "|" ~
    escapeShellCommand("grep", "-o", `http://\S*\.zip`) ~
    ">" ~
    escapeShellFileName("D download links.txt"));
---
*/

string escapeShellCommand(in char[][] args...)
{
    return escapeShellCommandString(escapeShellArguments(args));
}

unittest
{
    // This is a simple unit test without any special requirements,
    // in addition to the unittest_burnin one below which requires
    // special preparation.

    struct TestVector { string[] args; string windows, posix; }
    TestVector[] tests =
    [
        {
            args    : ["foo"],
            windows : `^"foo^"`,
            posix   : `'foo'`
        },
        {
            args    : ["foo", "hello"],
            windows : `^"foo^" ^"hello^"`,
            posix   : `'foo' 'hello'`
        },
        {
            args    : ["foo", "hello world"],
            windows : `^"foo^" ^"hello world^"`,
            posix   : `'foo' 'hello world'`
        },
        {
            args    : ["foo", "hello", "world"],
            windows : `^"foo^" ^"hello^" ^"world^"`,
            posix   : `'foo' 'hello' 'world'`
        },
        {
            args    : ["foo", `'"^\`],
            windows : `^"foo^" ^"'\^"^^\\^"`,
            posix   : `'foo' ''\''"^\'`
        },
    ];

    foreach (test; tests)
        version (Windows)
            assert(escapeShellCommand(test.args) == test.windows);
        else
            assert(escapeShellCommand(test.args) == test.posix  );
}

/**
    Escape a filename to be used for shell redirection with
    the $(D system) or $(D shell) functions.
*/

pure nothrow
string escapeShellFileName(in char[] fn)
{
    // The unittest for this function requires special
    // preparation - see below.

    version (Windows)
        return cast(string)('"' ~ fn ~ '"');
    else
        return escapePosixArgument(fn);
}

// Loop generating strings with random characters
//version = unittest_burnin;

version(unittest_burnin)
unittest
{
    // There are no readily-available commands on all platforms suitable
    // for properly testing command escaping. The behavior of CMD's "echo"
    // built-in differs from the POSIX program, and Windows ports of POSIX
    // environments (Cygwin, msys, gnuwin32) may interfere with their own
    // "echo" ports.

    // To run this unit test, create std_process_unittest_helper.d with the
    // following content and compile it:
    // import std.stdio, std.array; void main(string[] args) { write(args.join("\0")); }
    // Then, test this module with:
    // rdmd --main -unittest -version=unittest_burnin process.d

    auto helper = absolutePath("std_process_unittest_helper");
    assert(shell(helper ~ " hello").split("\0")[1..$] == ["hello"], "Helper malfunction");

    void test(string[] s, string fn)
    {
        string e;
        string[] g;

        e = escapeShellCommand(helper ~ s);
        {
            scope(failure) writefln("shell() failed.\nExpected:\t%s\nEncoded:\t%s", s, [e]);
            g = shell(e).split("\0")[1..$];
        }
        assert(s == g, format("shell() test failed.\nExpected:\t%s\nGot:\t\t%s\nEncoded:\t%s", s, g, [e]));

        e = escapeShellCommand(helper ~ s) ~ ">" ~ escapeShellFileName(fn);
        {
            scope(failure) writefln("system() failed.\nExpected:\t%s\nFilename:\t%s\nEncoded:\t%s", s, [fn], [e]);
            system(e);
            g = readText(fn).split("\0")[1..$];
        }
        remove(fn);
        assert(s == g, format("system() test failed.\nExpected:\t%s\nGot:\t\t%s\nEncoded:\t%s", s, g, [e]));
    }

    while (true)
    {
        string[] args;
        foreach (n; 0..uniform(1, 4))
        {
            string arg;
            foreach (l; 0..uniform(0, 10))
            {
                dchar c;
                while (true)
                {
                    version (Windows)
                    {
                        // As long as DMD's system() uses CreateProcessA,
                        // we can't reliably pass Unicode
                        c = uniform(0, 128);
                    }
                    else
                        c = uniform!ubyte();

                    if (c == 0)
                        continue; // argv-strings are zero-terminated
                    version (Windows)
                        if (c == '\r' || c == '\n')
                            continue; // newlines are unescapable on Windows
                    break;
                }
                arg ~= c;
            }
            args ~= arg;
        }

        // generate filename
        string fn = "test_";
        foreach (l; 0..uniform(1, 10))
        {
            dchar c;
            while (true)
            {
                version (Windows)
                    c = uniform(0, 128); // as above
                else
                    c = uniform!ubyte();

                if (c == 0 || c == '/')
                    continue; // NUL and / are the only characters
                              // forbidden in POSIX filenames
                version (Windows)
                    if (c < '\x20' || c == '<' || c == '>' || c == ':' ||
                        c == '"' || c == '\\' || c == '|' || c == '?' || c == '*')
                        continue; // http://msdn.microsoft.com/en-us/library/aa365247(VS.85).aspx
                break;
            }

            fn ~= c;
        }

        test(args, fn);
    }
}
