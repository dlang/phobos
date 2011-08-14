// Written in the D programming language.

/**
Macros:

WIKI=Phobos/StdProcess

Copyright: Copyright Digital Mars 2007 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu)
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
import core.stdc.errno;
import std.c.process;
import std.c.string;

import std.conv;
import std.exception;
import std.stdio;
import std.string;
import std.typecons;

version (Windows)
{
    import std.array, std.format, std.random, std.file;
    import core.sys.windows.windows;
    import std.utf;
    import std.windows.syserror;
}
version (Posix)
{
    import core.sys.posix.stdlib;
}


// The following is needed for reading/writing environment variables.
version(Posix)
{
    version(OSX)
    {
        // https://www.gnu.org/software/gnulib/manual/html_node/environ.html
        private extern(C) extern __gshared char*** _NSGetEnviron();
        // need to declare environ = *_NSGetEnviron() in static this()
    }
    else
    {
        // Made available by the C runtime:
        private extern(C) extern __gshared const char** environ;
    }
}
version(Windows)
{
    // TODO: This should be in core.sys.windows.windows.
    alias WCHAR* LPWCH;
    extern(Windows)
    {
        LPWCH GetEnvironmentStringsW();
        BOOL FreeEnvironmentStringsW(LPWCH lpszEnvironmentBlock);
        DWORD GetEnvironmentVariableW(LPCWSTR lpName, LPWSTR lpBuffer,
            DWORD nSize);
        BOOL SetEnvironmentVariableW(LPCWSTR lpName, LPCWSTR lpValue);
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
        return (status & 0x0000ff00) >>> 8;
    else
        return status;
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
    else
    {
        return std.c.process.spawnvp(mode, toStringz(pathname), argv_);
    }
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
bool stopped(int status)    { return cast(bool)((status & 0xff) == 0x7f); }
bool signaled(int status)   { return cast(bool)((cast(char)((status & 0x7f) + 1) >> 1) > 0); }
int  termsig(int status)    { return status & 0x7f; }
bool exited(int status)     { return cast(bool)((status & 0x7f) == 0); }
int  exitstatus(int status) { return (status & 0xff00) >> 8; }
}   // private
}   // version (Posix)

/* ========================================================== */

/**
 * Execute program specified by pathname, passing it the arguments (argv)
 * and the environment (envp), returning the exit status.
 * The 'p' versions of exec search the PATH environment variable
 * setting for the program.
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
        string[]    envPaths    =   std.string.split(
            to!string(std.c.stdlib.getenv("PATH")), ":");
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
version(Posix)
{
    alias core.sys.posix.unistd.getpid getpid;
}
else version (Windows)
{
    alias std.c.windows.windows.GetCurrentProcessId getpid;
}

/**
   Runs $(D_PARAM cmd) in a shell and returns its standard output. If
   the process could not be started or exits with an error code,
   throws an exception.

   Example:

   ----
   auto tempFilename = chomp(shell("mcookie"));
   auto f = enforce(fopen(tempFilename), "w");
   scope(exit)
   {
       fclose(f) == 0 || assert(false);
       system("rm " ~ tempFilename);
   }
   ... use f ...
   ----
*/
version (Windows) string shell(string cmd)
{
    // Generate a random filename
    auto a = appender!string();
    foreach (ref e; 0 .. 8)
    {
        formattedWrite(a, "%x", rndGen.front);
        rndGen.popFront;
    }
    auto filename = a.data;
    scope(exit) if (exists(filename)) remove(filename);
    errnoEnforce(system(cmd ~ "> " ~ filename) == 0);
    return readText(filename);
}

version (Posix) string shell(string cmd)
{
    File f;
    f.popen(cmd, "r");
    char[] line;
    string result;
    while (f.readln(line))
    {
        result ~= line;
    }
    f.close;
    return result;
}

unittest
{
    auto x = shell("echo wyda");
    // @@@ This fails on wine
    //assert(x == "wyda" ~ newline, text(x.length));
}

/**
Gets the value of environment variable $(D name) as a string. Calls
$(LINK2 std_c_stdlib.html#_getenv, std.c.stdlib._getenv)
internally. */

string getenv(in char[] name)
{
    // Cache the last call's result
    static string lastResult;
    auto p = std.c.stdlib.getenv(toStringz(name));
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

version(Posix) void setenv(in char[] name, in char[] value, bool overwrite)
{
    errnoEnforce(
        std.c.stdlib.setenv(toStringz(name), toStringz(value), overwrite) == 0);
}

/**
Removes variable $(D name) from the environment. Calls $(LINK2
std_c_stdlib.html#_unsetenv, std.c.stdlib._unsetenv) internally. */

version(Posix) void unsetenv(in char[] name)
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
    // initiaizes the value of environ for OSX
    version(OSX)
    {
        static private char** environ;
        static this()
        {
            environ = * _NSGetEnviron();
        }
    }
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

        assert (v == environment[n]);
    }
}


version (Windows)
{
    import core.sys.windows.windows;

    extern (Windows)
    HINSTANCE ShellExecuteA(HWND hwnd, LPCSTR lpOperation, LPCSTR lpFile, LPCSTR lpParameters, LPCSTR lpDirectory, INT nShowCmd);


    pragma(lib,"shell32.lib");

    /****************************************
     * Start up the browser and set it to viewing the page at url.
     */
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
            //browser = "/Applications/Safari.app/Contents/MacOS/Safari";
            args[0] = "open".ptr;
            args[1] = "-a".ptr;
            args[2] = "/Applications/Safari.app".ptr;
            args[3] = toStringz(url);
            args[4] = null;
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
            args[0] = "x-www-browser".ptr;

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


