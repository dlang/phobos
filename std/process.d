// Written in the D programming language.

/**
Authors:

$(WEB digitalmars.com, Walter Bright), $(WEB erdani.org, Andrei
Alexandrescu)

Macros:

WIKI=Phobos/StdProcess

Copyright: Copyright Digital Mars 2007 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB digitalmars.com, Walter Bright),
           $(WEB erdani.org, Andrei Alexandrescu)

         Copyright Digital Mars 2007 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.process;

private import std.c.stdlib;
private import std.c.string;
private import std.conv;
private import std.string;
private import std.c.process;
private import core.stdc.errno;
private import std.exception;
version (Windows)
{
    import std.array, std.format, std.random, std.file;
    private import std.stdio : readln, fclose;
    private import std.c.windows.windows:GetCurrentProcessId;
}
version (Posix)
{
    private import std.stdio;
}

/**
   Execute $(D command) in a _command shell.

   Returns: If $(D command) is null, returns nonzero if the _command
   interpreter is found, and zero otherwise. If $(D command) is not
   null, returns -1 on error, or the exit status of command (which may
   in turn signal an error in command's execution).

   Note: On Unix systems, the homonym C function (which is accessible
   to D programs as $(LINK2 std_c_process.html, std.c._system))
   returns a code in the same format as
   $(WEB www.scit.wlv.ac.uk/cgi-bin/mansec?2+waitpid, waitpid),
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

version(Posix)
{
    //alias std.c.process.getpid getpid;
    import core.sys.posix.unistd : getpid;
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
