// Written in the D programming language.

/**
Functions for starting and interacting with other processes, and for
working with the current _process' execution environment.

Process_handling:
$(UL $(LI
    $(LREF spawnProcess) spawns a new _process, optionally assigning it an
    arbitrary set of standard input, output, and error streams.
    The function returns immediately, leaving the child _process to execute
    in parallel with its parent.  All other functions in this module that
    spawn processes are built around $(D spawnProcess).)
$(LI
    $(LREF wait) makes the parent _process wait for a child _process to
    terminate.  In general one should always do this, to avoid
    child processes becoming "zombies" when the parent _process exits.
    Scope guards are perfect for this – see the $(LREF spawnProcess)
    documentation for examples.  $(LREF tryWait) is similar to $(D wait),
    but does not block if the _process has not yet terminated.)
$(LI
    $(LREF pipeProcess) also spawns a child _process which runs
    in parallel with its parent.  However, instead of taking
    arbitrary streams, it automatically creates a set of
    pipes that allow the parent to communicate with the child
    through the child's standard input, output, and/or error streams.
    This function corresponds roughly to C's $(D popen) function.)
$(LI
    $(LREF execute) starts a new _process and waits for it
    to complete before returning.  Additionally, it captures
    the _process' standard output and error streams and returns
    the output of these as a string.)
$(LI
    $(LREF spawnShell), $(LREF pipeShell) and $(LREF executeShell) work like
    $(D spawnProcess), $(D pipeProcess) and $(D execute), respectively,
    except that they take a single command string and run it through
    the current user's default command interpreter.
    $(D executeShell) corresponds roughly to C's $(D system) function.)
$(LI
    $(LREF kill) attempts to terminate a running _process.)
)

The following table compactly summarises the different _process creation
functions and how they relate to each other:
$(BOOKTABLE,
    $(TR $(TH )
         $(TH Runs program directly)
         $(TH Runs shell command))
    $(TR $(TD Low-level _process creation)
         $(TD $(LREF spawnProcess))
         $(TD $(LREF spawnShell)))
    $(TR $(TD Automatic input/output redirection using pipes)
         $(TD $(LREF pipeProcess))
         $(TD $(LREF pipeShell)))
    $(TR $(TD Execute and wait for completion, collect output)
         $(TD $(LREF execute))
         $(TD $(LREF executeShell)))
)

Other_functionality:
$(UL
$(LI
    $(LREF pipe) is used to create unidirectional pipes.)
$(LI
    $(LREF environment) is an interface through which the current _process'
    environment variables can be read and manipulated.)
$(LI
    $(LREF escapeShellCommand) and $(LREF escapeShellFileName) are useful
    for constructing shell command lines in a portable way.)
)

Authors:
    $(LINK2 https://github.com/kyllingstad, Lars Tandle Kyllingstad),
    $(LINK2 https://github.com/schveiguy, Steven Schveighoffer),
    $(WEB thecybershadow.net, Vladimir Panteleev)
Copyright:
    Copyright (c) 2013, the authors. All rights reserved.
Source:
    $(PHOBOSSRC std/_process.d)
Macros:
    WIKI=Phobos/StdProcess
    OBJECTREF=$(D $(LINK2 object.html#$0,$0))
    LREF=$(D $(LINK2 #.$0,$0))
*/
module std.process;

version (Posix)
{
    import core.stdc.errno;
    import core.stdc.string;
    import core.sys.posix.stdio;
    import core.sys.posix.unistd;
    import core.sys.posix.sys.wait;
}
version (Windows)
{
    import core.stdc.stdio;
    import core.sys.windows.windows;
    import std.utf;
    import std.windows.syserror;
}
import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.path;
import std.stdio;
import std.string;
import std.internal.processinit;


// When the DMC runtime is used, we have to use some custom functions
// to convert between Windows file handles and FILE*s.
version (Win32) version (DigitalMars) version = DMC_RUNTIME;


// Some of the following should be moved to druntime.
private
{

// Windows API declarations.
version (Windows)
{
    extern(Windows) BOOL GetHandleInformation(HANDLE hObject,
                                              LPDWORD lpdwFlags);
    extern(Windows) BOOL SetHandleInformation(HANDLE hObject,
                                              DWORD dwMask,
                                              DWORD dwFlags);
    extern(Windows) BOOL TerminateProcess(HANDLE hProcess,
                                          UINT uExitCode);
    extern(Windows) LPWSTR* CommandLineToArgvW(LPCWSTR lpCmdLine,
                                               int* pNumArgs);
    enum
    {
        HANDLE_FLAG_INHERIT = 0x1,
        HANDLE_FLAG_PROTECT_FROM_CLOSE = 0x2,
    }
    enum CREATE_UNICODE_ENVIRONMENT = 0x400;
}

// Microsoft Visual C Runtime (MSVCRT) declarations.
version (Windows)
{
    version (DMC_RUNTIME) { } else
    {
        import core.stdc.stdint;
        extern(C)
        {
            int _fileno(FILE* stream);
            HANDLE _get_osfhandle(int fd);
            int _open_osfhandle(HANDLE osfhandle, int flags);
            FILE* _fdopen(int fd, const (char)* mode);
            int _close(int fd);
        }
        enum
        {
            STDIN_FILENO  = 0,
            STDOUT_FILENO = 1,
            STDERR_FILENO = 2,
        }
        enum
        {
            _O_RDONLY = 0x0000,
            _O_APPEND = 0x0004,
            _O_TEXT   = 0x4000,
        }
    }
}

// POSIX API declarations.
version (Posix)
{
    version (OSX)
    {
        extern(C) char*** _NSGetEnviron() nothrow;
        private const(char**)* environPtr;
        extern(C) void std_process_static_this() { environPtr = _NSGetEnviron(); }
        const(char**) environ() @property @trusted nothrow { return *environPtr; }
    }
    else
    {
        // Made available by the C runtime:
        extern(C) extern __gshared const char** environ;
    }
}


} // private


// =============================================================================
// Functions and classes for process management.
// =============================================================================


/**
Spawns a new _process, optionally assigning it an arbitrary set of standard
input, output, and error streams.

The function returns immediately, leaving the child _process to execute
in parallel with its parent.  It is recommended to always call $(LREF wait)
on the returned $(LREF Pid), as detailed in the documentation for $(D wait).

Command_line:
There are four overloads of this function.  The first two take an array
of strings, $(D args), which should contain the program name as the
zeroth element and any command-line arguments in subsequent elements.
The third and fourth versions are included for convenience, and may be
used when there are no command-line arguments.  They take a single string,
$(D program), which specifies the program name.

Unless a directory is specified in $(D args[0]) or $(D program),
$(D spawnProcess) will search for the program in a platform-dependent
manner.  On POSIX systems, it will look for the executable in the
directories listed in the PATH environment variable, in the order
they are listed.  On Windows, it will search for the executable in
the following sequence:
$(OL
    $(LI The directory from which the application loaded.)
    $(LI The current directory for the parent process.)
    $(LI The 32-bit Windows system directory.)
    $(LI The 16-bit Windows system directory.)
    $(LI The Windows directory.)
    $(LI The directories listed in the PATH environment variable.)
)
---
// Run an executable called "prog" located in the current working
// directory:
auto pid = spawnProcess("./prog");
scope(exit) wait(pid);
// We can do something else while the program runs.  The scope guard
// ensures that the process is waited for at the end of the scope.
...

// Run DMD on the file "myprog.d", specifying a few compiler switches:
auto dmdPid = spawnProcess(["dmd", "-O", "-release", "-inline", "myprog.d" ]);
if (wait(dmdPid) != 0)
    writeln("Compilation failed!");
---

Environment_variables:
By default, the child process inherits the environment of the parent
process, along with any additional variables specified in the $(D env)
parameter.  If the same variable exists in both the parent's environment
and in $(D env), the latter takes precedence.

If the $(LREF Config.newEnv) flag is set in $(D config), the child
process will $(I not) inherit the parent's environment.  Its entire
environment will then be determined by $(D env).
---
wait(spawnProcess("myapp", ["foo" : "bar"], Config.newEnv));
---

Standard_streams:
The optional arguments $(D stdin), $(D stdout) and $(D stderr) may
be used to assign arbitrary $(XREF stdio,File) objects as the standard
input, output and error streams, respectively, of the child process.  The
former must be opened for reading, while the latter two must be opened for
writing.  The default is for the child process to inherit the standard
streams of its parent.
---
// Run DMD on the file myprog.d, logging any error messages to a
// file named errors.log.
auto logFile = File("errors.log", "w");
auto pid = spawnProcess(["dmd", "myprog.d"],
                        std.stdio.stdin,
                        std.stdio.stdout,
                        logFile);
if (wait(pid) != 0)
    writeln("Compilation failed. See errors.log for details.");
---

Note that if you pass a $(D File) object that is $(I not)
one of the standard input/output/error streams of the parent process,
that stream will by default be $(I closed) in the parent process when
this function returns.  See the $(LREF Config) documentation below for
information about how to disable this behaviour.

Beware of buffering issues when passing $(D File) objects to
$(D spawnProcess).  The child process will inherit the low-level raw
read/write offset associated with the underlying file descriptor, but
it will not be aware of any buffered data.  In cases where this matters
(e.g. when a file should be aligned before being passed on to the
child process), it may be a good idea to use unbuffered streams, or at
least ensure all relevant buffers are flushed.

Params:
args    = An array which contains the program name as the zeroth element
          and any command-line arguments in the following elements.
program = The program name, $(I without) command-line arguments.
stdin   = The standard input stream of the child process.
          This can be any $(XREF stdio,File) that is opened for reading.
          By default the child process inherits the parent's input
          stream.
stdout  = The standard output stream of the child process.
          This can be any $(XREF stdio,File) that is opened for writing.
          By default the child process inherits the parent's output stream.
stderr  = The standard error stream of the child process.
          This can be any $(XREF stdio,File) that is opened for writing.
          By default the child process inherits the parent's error stream.
env     = Additional environment variables for the child process.
config  = Flags that control process creation. See $(LREF Config)
          for an overview of available flags.

Returns:
A $(LREF Pid) object that corresponds to the spawned process.

Throws:
$(LREF ProcessException) on failure to start the process.$(BR)
$(XREF stdio,StdioException) on failure to pass one of the streams
    to the child process (Windows only).$(BR)
$(CXREF exception,RangeError) if $(D args) is empty.
*/
Pid spawnProcess(in char[][] args,
                 File stdin = std.stdio.stdin,
                 File stdout = std.stdio.stdout,
                 File stderr = std.stdio.stderr,
                 const string[string] env = null,
                 Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    version (Windows)    auto  args2 = escapeShellArguments(args);
    else version (Posix) alias args2 = args;
    return spawnProcessImpl(args2, stdin, stdout, stderr, env, config);
}

/// ditto
Pid spawnProcess(in char[][] args,
                 const string[string] env,
                 Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    return spawnProcess(args,
                        std.stdio.stdin,
                        std.stdio.stdout,
                        std.stdio.stderr,
                        env,
                        config);
}

/// ditto
Pid spawnProcess(in char[] program,
                 File stdin = std.stdio.stdin,
                 File stdout = std.stdio.stdout,
                 File stderr = std.stdio.stderr,
                 const string[string] env = null,
                 Config config = Config.none)
    @trusted
{
    return spawnProcess((&program)[0 .. 1],
                        stdin, stdout, stderr, env, config);
}

/// ditto
Pid spawnProcess(in char[] program,
                 const string[string] env,
                 Config config = Config.none)
    @trusted
{
    return spawnProcess((&program)[0 .. 1], env, config);
}

/*
Implementation of spawnProcess() for POSIX.

envz should be a zero-terminated array of zero-terminated strings
on the form "var=value".
*/
version (Posix)
private Pid spawnProcessImpl(in char[][] args,
                             File stdin,
                             File stdout,
                             File stderr,
                             const string[string] env,
                             Config config)
    @trusted // TODO: Should be @safe
{
    if (args.empty) throw new RangeError("Command line is empty");
    const(char)[] name = args[0];
    if (any!isDirSeparator(name))
    {
        if (!isExecutable(name))
            throw new ProcessException(text("Not an executable file: ", name));
    }
    else
    {
        name = searchPathFor(name);
        if (name is null)
            throw new ProcessException(text("Executable file not found: ", name));
    }

    // Convert program name and arguments to C-style strings.
    auto argz = new const(char)*[args.length+1];
    argz[0] = toStringz(name);
    foreach (i; 1 .. args.length) argz[i] = toStringz(args[i]);
    argz[$-1] = null;

    // Prepare environment.
    auto envz = createEnv(env, !(config & Config.newEnv));

    // Get the file descriptors of the streams.
    // These could potentially be invalid, but that is OK.  If so, later calls
    // to dup2() and close() will just silently fail without causing any harm.
    auto stdinFD  = core.stdc.stdio.fileno(stdin.getFP());
    auto stdoutFD = core.stdc.stdio.fileno(stdout.getFP());
    auto stderrFD = core.stdc.stdio.fileno(stderr.getFP());

    auto id = fork();
    if (id < 0)
        throw ProcessException.newFromErrno("Failed to spawn new process");
    if (id == 0)
    {
        // Child process

        // Redirect streams and close the old file descriptors.
        // In the case that stderr is redirected to stdout, we need
        // to backup the file descriptor since stdout may be redirected
        // as well.
        if (stderrFD == STDOUT_FILENO)  stderrFD = dup(stderrFD);
        dup2(stdinFD,  STDIN_FILENO);
        dup2(stdoutFD, STDOUT_FILENO);
        dup2(stderrFD, STDERR_FILENO);

        // Ensure that the standard streams aren't closed on execute, and
        // optionally close all other file descriptors.
        setCLOEXEC(STDIN_FILENO, false);
        setCLOEXEC(STDOUT_FILENO, false);
        setCLOEXEC(STDERR_FILENO, false);
        if (!(config & Config.inheritFDs))
        {
            import core.sys.posix.sys.resource;
            rlimit r;
            getrlimit(RLIMIT_NOFILE, &r);
            foreach (i; 3 .. cast(int) r.rlim_cur) close(i);
        }

        // Close the old file descriptors, unless they are
        // either of the standard streams.
        if (stdinFD  > STDERR_FILENO)  close(stdinFD);
        if (stdoutFD > STDERR_FILENO)  close(stdoutFD);
        if (stderrFD > STDERR_FILENO)  close(stderrFD);

        // Execute program.
        core.sys.posix.unistd.execve(argz[0], argz.ptr, envz);

        // If execution fails, exit as quickly as possible.
        core.sys.posix.stdio.perror("spawnProcess(): Failed to execute program");
        core.sys.posix.unistd._exit(1);
        assert (0);
    }
    else
    {
        // Parent process:  Close streams and return.
        if (stdinFD  > STDERR_FILENO && !(config & Config.retainStdin))
            stdin.close();
        if (stdoutFD > STDERR_FILENO && !(config & Config.retainStdout))
            stdout.close();
        if (stderrFD > STDERR_FILENO && !(config & Config.retainStderr))
            stderr.close();
        return new Pid(id);
    }
}

/*
Implementation of spawnProcess() for Windows.

commandLine must contain the entire command line, properly
quoted/escaped as required by CreateProcessW().

envz must be a pointer to a block of UTF-16 characters on the form
"var1=value1\0var2=value2\0...varN=valueN\0\0".
*/
version (Windows)
private Pid spawnProcessImpl(in char[] commandLine,
                             File stdin,
                             File stdout,
                             File stderr,
                             const string[string] env,
                             Config config)
    @trusted
{
    if (commandLine.empty) throw new RangeError("Command line is empty");
    auto commandz = toUTFz!(wchar*)(commandLine);

    // Prepare environment.
    auto envz = createEnv(env, !(config & Config.newEnv));

    // Startup info for CreateProcessW().
    STARTUPINFO_W startinfo;
    startinfo.cb = startinfo.sizeof;
    startinfo.dwFlags = STARTF_USESTDHANDLES;

    // Extract file descriptors and HANDLEs from the streams and make the
    // handles inheritable.
    static void prepareStream(ref File file, DWORD stdHandle, string which,
                              out int fileDescriptor, out HANDLE handle)
    {
        fileDescriptor = _fileno(file.getFP());
        if (fileDescriptor < 0)   handle = GetStdHandle(stdHandle);
        else
        {
            version (DMC_RUNTIME) handle = _fdToHandle(fileDescriptor);
            else    /* MSVCRT */  handle = _get_osfhandle(fileDescriptor);
        }
        DWORD dwFlags;
        GetHandleInformation(handle, &dwFlags);
        if (!(dwFlags & HANDLE_FLAG_INHERIT))
        {
            if (!SetHandleInformation(handle,
                                      HANDLE_FLAG_INHERIT,
                                      HANDLE_FLAG_INHERIT))
            {
                throw new StdioException(
                    "Failed to make "~which~" stream inheritable by child process ("
                    ~sysErrorString(GetLastError()) ~ ')',
                    0);
            }
        }
    }
    int stdinFD = -1, stdoutFD = -1, stderrFD = -1;
    prepareStream(stdin,  STD_INPUT_HANDLE,  "stdin" , stdinFD,  startinfo.hStdInput );
    prepareStream(stdout, STD_OUTPUT_HANDLE, "stdout", stdoutFD, startinfo.hStdOutput);
    prepareStream(stderr, STD_ERROR_HANDLE,  "stderr", stderrFD, startinfo.hStdError );

    // Create process.
    PROCESS_INFORMATION pi;
    DWORD dwCreationFlags =
        CREATE_UNICODE_ENVIRONMENT |
        ((config & Config.suppressConsole) ? CREATE_NO_WINDOW : 0);
    if (!CreateProcessW(null, commandz, null, null, true, dwCreationFlags,
                        envz, null, &startinfo, &pi))
        throw ProcessException.newFromLastError("Failed to spawn new process");

    // figure out if we should close any of the streams
    if (stdinFD  > STDERR_FILENO && !(config & Config.retainStdin))
        stdin.close();
    if (stdoutFD > STDERR_FILENO && !(config & Config.retainStdout))
        stdout.close();
    if (stderrFD > STDERR_FILENO && !(config & Config.retainStderr))
        stderr.close();

    // close the thread handle in the process info structure
    CloseHandle(pi.hThread);

    return new Pid(pi.dwProcessId, pi.hProcess);
}

// Converts childEnv to a zero-terminated array of zero-terminated strings
// on the form "name=value", optionally adding those of the current process'
// environment strings that are not present in childEnv.  If the parent's
// environment should be inherited without modification, this function
// returns environ directly.
version (Posix)
private const(char*)* createEnv(const string[string] childEnv,
                                bool mergeWithParentEnv)
{
    // Determine the number of strings in the parent's environment.
    int parentEnvLength = 0;
    if (mergeWithParentEnv)
    {
        if (childEnv.length == 0) return environ;
        while (environ[parentEnvLength] != null) ++parentEnvLength;
    }

    // Convert the "new" variables to C-style strings.
    auto envz = new const(char)*[parentEnvLength + childEnv.length + 1];
    int pos = 0;
    foreach (var, val; childEnv)
        envz[pos++] = (var~'='~val~'\0').ptr;

    // Add the parent's environment.
    foreach (environStr; environ[0 .. parentEnvLength])
    {
        int eqPos = 0;
        while (environStr[eqPos] != '=' && environStr[eqPos] != '\0') ++eqPos;
        if (environStr[eqPos] != '=') continue;
        auto var = environStr[0 .. eqPos];
        if (var in childEnv) continue;
        envz[pos++] = environStr;
    }
    envz[pos] = null;
    return envz.ptr;
}

version (Posix) unittest
{
    auto e1 = createEnv(null, false);
    assert (e1 != null && *e1 == null);

    auto e2 = createEnv(null, true);
    assert (e2 != null);
    int i = 0;
    for (; environ[i] != null; ++i)
    {
        assert (e2[i] != null);
        import core.stdc.string;
        assert (strcmp(e2[i], environ[i]) == 0);
    }
    assert (e2[i] == null);

    auto e3 = createEnv(["foo" : "bar", "hello" : "world"], false);
    assert (e3 != null && e3[0] != null && e3[1] != null && e3[2] == null);
    assert ((e3[0][0 .. 8] == "foo=bar\0" && e3[1][0 .. 12] == "hello=world\0")
         || (e3[0][0 .. 12] == "hello=world\0" && e3[1][0 .. 8] == "foo=bar\0"));
}


// Converts childEnv to a Windows environment block, which is on the form
// "name1=value1\0name2=value2\0...nameN=valueN\0\0", optionally adding
// those of the current process' environment strings that are not present
// in childEnv.  Returns null if the parent's environment should be
// inherited without modification, as this is what is expected by
// CreateProcess().
version (Windows)
private LPVOID createEnv(const string[string] childEnv,
                         bool mergeWithParentEnv)
{
    if (mergeWithParentEnv && childEnv.length == 0) return null;

    auto envz = appender!(wchar[])();
    void put(string var, string val)
    {
        envz.put(var);
        envz.put('=');
        envz.put(val);
        envz.put(cast(wchar) '\0');
    }

    // Add the variables in childEnv, removing them from parentEnv
    // if they exist there too.
    auto parentEnv = mergeWithParentEnv ? environment.toAA() : null;
    foreach (k, v; childEnv)
    {
        auto uk = toUpper(k);
        put(uk, v);
        if (uk in parentEnv) parentEnv.remove(uk);
    }

    // Add remaining parent environment variables.
    foreach (k, v; parentEnv) put(k, v);

    // Two final zeros are needed in case there aren't any environment vars,
    // and the last one does no harm when there are.
    envz.put("\0\0"w);
    return envz.data.ptr;
}

version (Windows) unittest
{
    assert (createEnv(null, true) == null);
    assert ((cast(wchar*) createEnv(null, false))[0 .. 2] == "\0\0"w);
    auto e1 = (cast(wchar*) createEnv(["foo":"bar", "ab":"c"], false))[0 .. 14];
    assert (e1 == "FOO=bar\0AB=c\0\0"w || e1 == "AB=c\0FOO=bar\0\0"w);
}

// Searches the PATH variable for the given executable file,
// (checking that it is in fact executable).
version (Posix)
private string searchPathFor(in char[] executable)
    @trusted //TODO: @safe nothrow
{
    auto pathz = core.stdc.stdlib.getenv("PATH");
    if (pathz == null)  return null;

    foreach (dir; splitter(to!string(pathz), ':'))
    {
        auto execPath = buildPath(dir, executable);
        if (isExecutable(execPath))  return execPath;
    }

    return null;
}

// Checks whether the file exists and can be executed by the
// current user.
version (Posix)
private bool isExecutable(in char[] path) @trusted //TODO: @safe nothrow
{
    return (access(toStringz(path), X_OK) == 0);
}

version (Posix) unittest
{
    auto unamePath = searchPathFor("uname");
    assert (!unamePath.empty);
    assert (unamePath[0] == '/');
    assert (unamePath.endsWith("uname"));
    auto unlikely = searchPathFor("lkmqwpoialhggyaofijadsohufoiqezm");
    assert (unlikely is null, "Are you kidding me?");
}

// Sets or unsets the FD_CLOEXEC flag on the given file descriptor.
version (Posix)
private void setCLOEXEC(int fd, bool on)
{
    import core.sys.posix.fcntl;
    auto flags = fcntl(fd, F_GETFD);
    if (flags >= 0)
    {
        if (on) flags |= FD_CLOEXEC;
        else    flags &= ~(cast(typeof(flags)) FD_CLOEXEC);
        flags = fcntl(fd, F_SETFD, flags);
    }
    if (flags == -1)
    {
        throw new StdioException("Failed to "~(on ? "" : "un")
                                 ~"set close-on-exec flag on file descriptor");
    }
}

unittest // Command line arguments in spawnProcess().
{
    version (Windows) TestScript prog =
       "if not [%~1]==[foo] ( exit 1 )
        if not [%~2]==[bar] ( exit 2 )
        exit 0";
    else version (Posix) TestScript prog =
       `if test "$1" != "foo"; then exit 1; fi
        if test "$2" != "bar"; then exit 2; fi
        exit 0`;
    assert (wait(spawnProcess(prog.path)) == 1);
    assert (wait(spawnProcess([prog.path])) == 1);
    assert (wait(spawnProcess([prog.path, "foo"])) == 2);
    assert (wait(spawnProcess([prog.path, "foo", "baz"])) == 2);
    assert (wait(spawnProcess([prog.path, "foo", "bar"])) == 0);
}

unittest // Environment variables in spawnProcess().
{
    // We really should use set /a on Windows, but Wine doesn't support it.
    version (Windows) TestScript envProg =
       `if [%STD_PROCESS_UNITTEST1%] == [1] (
            if [%STD_PROCESS_UNITTEST2%] == [2] (exit 3)
            exit 1
        )
        if [%STD_PROCESS_UNITTEST1%] == [4] (
            if [%STD_PROCESS_UNITTEST2%] == [2] (exit 6)
            exit 4
        )
        if [%STD_PROCESS_UNITTEST2%] == [2] (exit 2)
        exit 0`;
    version (Posix) TestScript envProg =
       `if test "$std_process_unittest1" = ""; then
            std_process_unittest1=0
        fi
        if test "$std_process_unittest2" = ""; then
            std_process_unittest2=0
        fi
        exit $(($std_process_unittest1+$std_process_unittest2))`;

    environment.remove("std_process_unittest1"); // Just in case.
    environment.remove("std_process_unittest2");
    assert (wait(spawnProcess(envProg.path)) == 0);
    assert (wait(spawnProcess(envProg.path, null, Config.newEnv)) == 0);

    environment["std_process_unittest1"] = "1";
    assert (wait(spawnProcess(envProg.path)) == 1);
    assert (wait(spawnProcess(envProg.path, null, Config.newEnv)) == 0);

    auto env = ["std_process_unittest2" : "2"];
    assert (wait(spawnProcess(envProg.path, env)) == 3);
    assert (wait(spawnProcess(envProg.path, env, Config.newEnv)) == 2);

    env["std_process_unittest1"] = "4";
    assert (wait(spawnProcess(envProg.path, env)) == 6);
    assert (wait(spawnProcess(envProg.path, env, Config.newEnv)) == 6);

    environment.remove("std_process_unittest1");
    assert (wait(spawnProcess(envProg.path, env)) == 6);
    assert (wait(spawnProcess(envProg.path, env, Config.newEnv)) == 6);
}

unittest // Stream redirection in spawnProcess().
{
    version (Windows) TestScript prog =
       "set /p INPUT=
        echo %INPUT% output %~1
        echo %INPUT% error %~2 1>&2";
    else version (Posix) TestScript prog =
       "read INPUT
        echo $INPUT output $1
        echo $INPUT error $2 >&2";

    // Pipes
    auto pipei = pipe();
    auto pipeo = pipe();
    auto pipee = pipe();
    auto pid = spawnProcess([prog.path, "foo", "bar"],
                             pipei.readEnd, pipeo.writeEnd, pipee.writeEnd);
    pipei.writeEnd.writeln("input");
    pipei.writeEnd.flush();
    assert (pipeo.readEnd.readln().chomp() == "input output foo");
    assert (pipee.readEnd.readln().chomp().stripRight() == "input error bar");
    wait(pid);

    // Files
    import std.ascii, std.file, std.uuid;
    auto pathi = buildPath(tempDir(), randomUUID().toString());
    auto patho = buildPath(tempDir(), randomUUID().toString());
    auto pathe = buildPath(tempDir(), randomUUID().toString());
    std.file.write(pathi, "INPUT"~std.ascii.newline);
    auto filei = File(pathi, "r");
    auto fileo = File(patho, "w");
    auto filee = File(pathe, "w");
    pid = spawnProcess([prog.path, "bar", "baz" ], filei, fileo, filee);
    wait(pid);
    assert (readText(patho).chomp() == "INPUT output bar");
    assert (readText(pathe).chomp().stripRight() == "INPUT error baz");
    remove(pathi);
    remove(patho);
    remove(pathe);
}

unittest // Error handling in spawnProcess()
{
    assertThrown!ProcessException(spawnProcess("ewrgiuhrifuheiohnmnvqweoijwf"));
    assertThrown!ProcessException(spawnProcess("./rgiuhrifuheiohnmnvqweoijwf"));
}


/**
A variation on $(LREF spawnProcess) that runs the given _command through
the current user's preferred _command interpreter (aka. shell).

The string $(D command) is passed verbatim to the shell, and is therefore
subject to its rules about _command structure, argument/filename quoting
and escaping of special characters.
The path to the shell executable is determined by the $(LREF userShell)
function.

In all other respects this function works just like $(D spawnProcess).
Please refer to the $(LREF spawnProcess) documentation for descriptions
of the other function parameters, the return value and any exceptions
that may be thrown.
---
// Run the command/program "foo" on the file named "my file.txt", and
// redirect its output into foo.log.
auto pid = spawnShell(`foo "my file.txt" > foo.log`);
wait(pid);
---

See_also:
$(LREF escapeShellCommand), which may be helpful in constructing a
properly quoted and escaped shell _command line for the current platform.
*/
Pid spawnShell(in char[] command,
               File stdin = std.stdio.stdin,
               File stdout = std.stdio.stdout,
               File stderr = std.stdio.stderr,
               const string[string] env = null,
               Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    version (Windows)
    {
        auto args = escapeShellArguments(userShell, shellSwitch)
                    ~ " " ~ command;
    }
    else version (Posix)
    {
        const(char)[][3] args;
        args[0] = userShell;
        args[1] = shellSwitch;
        args[2] = command;
    }
    return spawnProcessImpl(args, stdin, stdout, stderr, env, config);
}

/// ditto
Pid spawnShell(in char[] command,
               const string[string] env,
               Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    return spawnShell(command,
                      std.stdio.stdin,
                      std.stdio.stdout,
                      std.stdio.stderr,
                      env,
                      config);
}

unittest
{
    version (Windows)
        auto cmd = "echo %FOO%";
    else version (Posix)
        auto cmd = "echo $foo";
    import std.file;
    auto tmpFile = uniqueTempPath();
    scope(exit) if (exists(tmpFile)) remove(tmpFile);
    auto redir = "> \""~tmpFile~'"';
    auto env = ["foo" : "bar"];
    assert (wait(spawnShell(cmd~redir, env)) == 0);
    auto f = File(tmpFile, "a");
    assert (wait(spawnShell(cmd, std.stdio.stdin, f, std.stdio.stderr, env)) == 0);
    f.close();
    auto output = std.file.readText(tmpFile);
    assert (output == "bar\nbar\n" || output == "bar\r\nbar\r\n");
}


/**
Flags that control the behaviour of $(LREF spawnProcess) and
$(LREF spawnShell).

Use bitwise OR to combine flags.

Example:
---
auto logFile = File("myapp_error.log", "w");

// Start program, suppressing the console window (Windows only),
// redirect its error stream to logFile, and leave logFile open
// in the parent process as well.
auto pid = spawnProcess("myapp", stdin, stdout, logFile,
                        Config.retainStderr | Config.suppressConsole);
scope(exit)
{
    auto exitCode = wait(pid);
    logFile.writeln("myapp exited with code ", exitCode);
    logFile.close();
}
---
*/
enum Config
{
    none = 0,

    /**
    By default, the child process inherits the parent's environment,
    and any environment variables passed to $(LREF spawnProcess) will
    be added to it.  If this flag is set, the only variables in the
    child process' environment will be those given to spawnProcess.
    */
    newEnv = 1,

    /**
    Unless the child process inherits the standard input/output/error
    streams of its parent, one almost always wants the streams closed
    in the parent when $(LREF spawnProcess) returns.  Therefore, by
    default, this is done.  If this is not desirable, pass any of these
    options to spawnProcess.
    */
    retainStdin  = 2,
    retainStdout = 4,                                  /// ditto
    retainStderr = 8,                                  /// ditto

    /**
    On Windows, if the child process is a console application, this
    flag will prevent the creation of a console window.  Otherwise,
    it will be ignored. On POSIX, $(D suppressConsole) has no effect.
    */
    suppressConsole = 16,

    /**
    On POSIX, open $(LINK2 http://en.wikipedia.org/wiki/File_descriptor,file descriptors)
    are by default inherited by the child process.  As this may lead
    to subtle bugs when pipes or multiple threads are involved,
    $(LREF spawnProcess) ensures that all file descriptors except the
    ones that correspond to standard input/output/error are closed
    in the child process when it starts.  Use $(D inheritFDs) to prevent
    this.

    On Windows, this option has no effect, and any handles which have been
    explicitly marked as inheritable will always be inherited by the child
    process.
    */
    inheritFDs = 32,
}


/// A handle that corresponds to a spawned process.
final class Pid
{
    /**
    The process ID number.

    This is a number that uniquely identifies the process on the operating
    system, for at least as long as the process is running.  Once $(LREF wait)
    has been called on the $(LREF Pid), this method will return an
    invalid process ID.
    */
    @property int processID() const @safe pure nothrow
    {
        return _processID;
    }

    /**
    An operating system handle to the process.

    This handle is used to specify the process in OS-specific APIs.
    On POSIX, this function returns a $(D core.sys.posix.sys.types.pid_t)
    with the same value as $(LREF Pid.processID), while on Windows it returns
    a $(D core.sys.windows.windows.HANDLE).

    Once $(LREF wait) has been called on the $(LREF Pid), this method
    will return an invalid handle.
    */
    // Note: Since HANDLE is a reference, this function cannot be const.
    version (Windows)
    @property HANDLE osHandle() @safe pure nothrow
    {
        return _handle;
    }
    else version (Posix)
    @property pid_t osHandle() @safe pure nothrow
    {
        return _processID;
    }

private:
    /*
    Pid.performWait() does the dirty work for wait() and nonBlockingWait().

    If block == true, this function blocks until the process terminates,
    sets _processID to terminated, and returns the exit code or terminating
    signal as described in the wait() documentation.

    If block == false, this function returns immediately, regardless
    of the status of the process.  If the process has terminated, the
    function has the exact same effect as the blocking version.  If not,
    it returns 0 and does not modify _processID.
    */
    version (Posix)
    int performWait(bool block) @trusted
    {
        if (_processID == terminated) return _exitCode;
        int exitCode;
        while(true)
        {
            int status;
            auto check = waitpid(_processID, &status, block ? 0 : WNOHANG);
            if (check == -1)
            {
                if (errno == ECHILD)
                {
                    throw new ProcessException(
                        "Process does not exist or is not a child process.");
                }
                else
                {
                    // waitpid() was interrupted by a signal.  We simply
                    // restart it.
                    assert (errno == EINTR);
                    continue;
                }
            }
            if (!block && check == 0) return 0;
            if (WIFEXITED(status))
            {
                exitCode = WEXITSTATUS(status);
                break;
            }
            else if (WIFSIGNALED(status))
            {
                exitCode = -WTERMSIG(status);
                break;
            }
            // We check again whether the call should be blocking,
            // since we don't care about other status changes besides
            // "exited" and "terminated by signal".
            if (!block) return 0;

            // Process has stopped, but not terminated, so we continue waiting.
        }
        // Mark Pid as terminated, and cache and return exit code.
        _processID = terminated;
        _exitCode = exitCode;
        return exitCode;
    }
    else version (Windows)
    {
        int performWait(bool block) @trusted
        {
            if (_processID == terminated) return _exitCode;
            assert (_handle != INVALID_HANDLE_VALUE);
            if (block)
            {
                auto result = WaitForSingleObject(_handle, INFINITE);
                if (result != WAIT_OBJECT_0)
                    throw ProcessException.newFromLastError("Wait failed.");
            }
            if (!GetExitCodeProcess(_handle, cast(LPDWORD)&_exitCode))
                throw ProcessException.newFromLastError();
            if (!block && _exitCode == STILL_ACTIVE) return 0;
            CloseHandle(_handle);
            _handle = INVALID_HANDLE_VALUE;
            _processID = terminated;
            return _exitCode;
        }

        ~this()
        {
            if(_handle != INVALID_HANDLE_VALUE)
            {
                CloseHandle(_handle);
                _handle = INVALID_HANDLE_VALUE;
            }
        }
    }

    // Special values for _processID.
    enum invalid = -1, terminated = -2;

    // OS process ID number.  Only nonnegative IDs correspond to
    // running processes.
    int _processID = invalid;

    // Exit code cached by wait().  This is only expected to hold a
    // sensible value if _processID == terminated.
    int _exitCode;

    // Pids are only meant to be constructed inside this module, so
    // we make the constructor private.
    version (Windows)
    {
        HANDLE _handle = INVALID_HANDLE_VALUE;
        this(int pid, HANDLE handle) @safe pure nothrow
        {
            _processID = pid;
            _handle = handle;
        }
    }
    else
    {
        this(int id) @safe pure nothrow
        {
            _processID = id;
        }
    }
}


/**
Waits for the process associated with $(D pid) to terminate, and returns
its exit status.

In general one should always _wait for child processes to terminate
before exiting the parent process.  Otherwise, they may become
"$(WEB en.wikipedia.org/wiki/Zombie_process,zombies)" – processes
that are defunct, yet still occupy a slot in the OS process table.

If the process has already terminated, this function returns directly.
The exit code is cached, so that if wait() is called multiple times on
the same $(LREF Pid) it will always return the same value.

POSIX_specific:
If the process is terminated by a signal, this function returns a
negative number whose absolute value is the signal number.
Since POSIX restricts normal exit codes to the range 0-255, a
negative return value will always indicate termination by signal.
Signal codes are defined in the $(D core.sys.posix.signal) module
(which corresponds to the $(D signal.h) POSIX header).

Throws:
$(LREF ProcessException) on failure.

Examples:
See the $(LREF spawnProcess) documentation.

See_also:
$(LREF tryWait), for a non-blocking function.
*/
int wait(Pid pid) @safe
{
    assert(pid !is null, "Called wait on a null Pid.");
    return pid.performWait(true);
}


unittest // Pid and wait()
{
    version (Windows)    TestScript prog = "exit %~1";
    else version (Posix) TestScript prog = "exit $1";
    assert (wait(spawnProcess([prog.path, "0"])) == 0);
    assert (wait(spawnProcess([prog.path, "123"])) == 123);
    auto pid = spawnProcess([prog.path, "10"]);
    assert (pid.processID > 0);
    version (Windows)    assert (pid.osHandle != INVALID_HANDLE_VALUE);
    else version (Posix) assert (pid.osHandle == pid.processID);
    assert (wait(pid) == 10);
    assert (wait(pid) == 10); // cached exit code
    assert (pid.processID < 0);
    version (Windows)    assert (pid.osHandle == INVALID_HANDLE_VALUE);
    else version (Posix) assert (pid.osHandle < 0);
}


/**
A non-blocking version of $(LREF wait).

If the process associated with $(D pid) has already terminated,
$(D tryWait) has the exact same effect as $(D wait).
In this case, it returns a struct where the $(D terminated) field
is set to $(D true) and the $(D status) field has the same
interpretation as the return value of $(D wait).

If the process has $(I not) yet terminated, this function differs
from $(D wait) in that does not wait for this to happen, but instead
returns immediately.  The $(D terminated) field of the returned
tuple will then be set to $(D false), while the $(D status) field
will always be 0 (zero).  $(D wait) or $(D tryWait) should then be
called again on the same $(D Pid) at some later time; not only to
get the exit code, but also to avoid the process becoming a "zombie"
when it finally terminates.  (See $(LREF wait) for details).

Returns:
A $(D struct) which contains the fields $(D bool terminated)
and $(D int status).  (This will most likely change to become a
$(D std.typecons.Tuple!(bool,"terminated",int,"status")) in the future,
but a compiler bug currently prevents this.)

Throws:
$(LREF ProcessException) on failure.

Example:
---
auto pid = spawnProcess("dmd myapp.d");
scope(exit) wait(pid);
...
auto dmd = tryWait(pid);
if (dmd.terminated)
{
    if (dmd.status == 0) writeln("Compilation succeeded!");
    else writeln("Compilation failed");
}
else writeln("Still compiling...");
...
---
Note that in this example, the first $(D wait) call will have no
effect if the process has already terminated by the time $(D tryWait)
is called.  In the opposite case, however, the $(D scope) statement
ensures that we always wait for the process if it hasn't terminated
by the time we reach the end of the scope.
*/
auto tryWait(Pid pid) @safe
{
    struct TryWaitResult
    {
        bool terminated;
        int status;
    }
    assert(pid !is null, "Called tryWait on a null Pid.");
    auto code = pid.performWait(false);
    return TryWaitResult(pid._processID == Pid.terminated, code);
}
// unittest: This function is tested together with kill() below.


/**
Attempts to terminate the process associated with $(D pid).

The effect of this function, as well as the meaning of $(D codeOrSignal),
is highly platform dependent.  Details are given below.  Common to all
platforms is that this function only $(I initiates) termination of the process,
and returns immediately.  It does not wait for the process to end,
nor does it guarantee that the process does in fact get terminated.

Always call $(LREF wait) to wait for a process to complete, even if $(D kill)
has been called on it.

Windows_specific:
The process will be
$(LINK2 http://msdn.microsoft.com/en-us/library/windows/desktop/ms686714%28v=vs.100%29.aspx,
forcefully and abruptly terminated).  If $(D codeOrSignal) is specified, it
must be a nonnegative number which will be used as the exit code of the process.
If not, the process wil exit with code 1.  Do not use $(D codeOrSignal = 259),
as this is a special value (aka. $(LINK2 http://msdn.microsoft.com/en-us/library/windows/desktop/ms683189.aspx,STILL_ACTIVE))
used by Windows to signal that a process has in fact $(I not) terminated yet.
---
auto pid = spawnProcess("some_app");
kill(pid, 10);
assert (wait(pid) == 10);
---
$(RED Warning:) The mechanisms for process termination are
$(LINK2 http://blogs.msdn.com/b/oldnewthing/archive/2007/05/03/2383346.aspx,
incredibly badly specified) in the Windows API.  This function may therefore
produce unexpected results, and should be used with the utmost care.

POSIX_specific:
A $(LINK2 http://en.wikipedia.org/wiki/Unix_signal,signal) will be sent to
the process, whose value is given by $(D codeOrSignal).  Depending on the
signal sent, this may or may not terminate the process.  Symbolic constants
for various $(LINK2 http://en.wikipedia.org/wiki/Unix_signal#POSIX_signals,
POSIX signals) are defined in $(D core.sys.posix.signal), which corresponds to the
$(LINK2 http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/signal.h.html,
$(D signal.h) POSIX header).  If $(D codeOrSignal) is omitted, the
$(D SIGTERM) signal will be sent.  (This matches the behaviour of the
$(LINK2 http://pubs.opengroup.org/onlinepubs/9699919799/utilities/kill.html,
$(D _kill)) shell command.)
---
import core.sys.posix.signal: SIGKILL;
auto pid = spawnProcess("some_app");
kill(pid, SIGKILL);
assert (wait(pid) == -SIGKILL); // Negative return value on POSIX!
---

Throws:
$(LREF ProcessException) on error (e.g. if codeOrSignal is invalid).
    Note that failure to terminate the process is considered a "normal"
    outcome, not an error.$(BR)
*/
void kill(Pid pid)
{
    version (Windows) kill(pid, 1);
    else version (Posix)
    {
        import core.sys.posix.signal: SIGTERM;
        kill(pid, SIGTERM);
    }
}

/// ditto
void kill(Pid pid, int codeOrSignal)
{
    version (Windows)
    {
        if (codeOrSignal < 0) throw new ProcessException("Invalid exit code");
        version (Win32)
        {
            // On Windows XP, TerminateProcess() appears to terminate the
            // *current* process if it is passed an invalid handle...
            if (pid.osHandle == INVALID_HANDLE_VALUE)
                throw new ProcessException("Invalid process handle");
        }
        if (!TerminateProcess(pid.osHandle, codeOrSignal))
            throw ProcessException.newFromLastError();
    }
    else version (Posix)
    {
        import core.sys.posix.signal;
        if (kill(pid.osHandle, codeOrSignal) == -1)
            throw ProcessException.newFromErrno();
    }
}

unittest // tryWait() and kill()
{
    import core.thread;
    // The test script goes into an infinite loop.
    version (Windows)
    {
        TestScript prog = ":loop
                           goto loop";
    }
    else version (Posix)
    {
        import core.sys.posix.signal: SIGTERM, SIGKILL;
        TestScript prog = "while true; do sleep 1; done";
    }
    auto pid = spawnProcess(prog.path);
    Thread.sleep(dur!"seconds"(1));
    kill(pid);
    version (Windows)    assert (wait(pid) == 1);
    else version (Posix) assert (wait(pid) == -SIGTERM);

    pid = spawnProcess(prog.path);
    Thread.sleep(dur!"seconds"(1));
    auto s = tryWait(pid);
    assert (!s.terminated && s.status == 0);
    assertThrown!ProcessException(kill(pid, -123)); // Negative code not allowed.
    version (Windows)    kill(pid, 123);
    else version (Posix) kill(pid, SIGKILL);
    do { s = tryWait(pid); } while (!s.terminated);
    version (Windows)    assert (s.status == 123);
    else version (Posix) assert (s.status == -SIGKILL);
    assertThrown!ProcessException(kill(pid));
}


/**
Creates a unidirectional _pipe.

Data is written to one end of the _pipe and read from the other.
---
auto p = pipe();
p.writeEnd.writeln("Hello World");
assert (p.readEnd.readln().chomp() == "Hello World");
---
Pipes can, for example, be used for interprocess communication
by spawning a new process and passing one end of the _pipe to
the child, while the parent uses the other end.
(See also $(LREF pipeProcess) and $(LREF pipeShell) for an easier
way of doing this.)
---
// Use cURL to download the dlang.org front page, pipe its
// output to grep to extract a list of links to ZIP files,
// and write the list to the file "D downloads.txt":
auto p = pipe();
auto outFile = File("D downloads.txt", "w");
auto cpid = spawnProcess(["curl", "http://dlang.org/download.html"],
                         std.stdio.stdin, p.writeEnd);
scope(exit) wait(cpid);
auto gpid = spawnProcess(["grep", "-o", `http://\S*\.zip`],
                         p.readEnd, outFile);
scope(exit) wait(gpid);
---

Returns:
A $(LREF Pipe) object that corresponds to the created _pipe.

Throws:
$(XREF stdio,StdioException) on failure.
*/
version (Posix)
Pipe pipe() @trusted //TODO: @safe
{
    int[2] fds;
    if (core.sys.posix.unistd.pipe(fds) != 0)
        throw new StdioException("Unable to create pipe");
    Pipe p;
    auto readFP = fdopen(fds[0], "r");
    if (readFP == null)
        throw new StdioException("Cannot open read end of pipe");
    p._read = File(readFP, null);
    auto writeFP = fdopen(fds[1], "w");
    if (writeFP == null)
        throw new StdioException("Cannot open write end of pipe");
    p._write = File(writeFP, null);
    return p;
}
else version (Windows)
Pipe pipe() @trusted //TODO: @safe
{
    // use CreatePipe to create an anonymous pipe
    HANDLE readHandle;
    HANDLE writeHandle;
    if (!CreatePipe(&readHandle, &writeHandle, null, 0))
    {
        throw new StdioException(
            "Error creating pipe (" ~ sysErrorString(GetLastError()) ~ ')',
            0);
    }

    // Create file descriptors from the handles
    version (DMC_RUNTIME)
    {
        auto readFD  = _handleToFD(readHandle, FHND_DEVICE);
        auto writeFD = _handleToFD(writeHandle, FHND_DEVICE);
    }
    else // MSVCRT
    {
        auto readFD  = _open_osfhandle(readHandle, _O_RDONLY);
        auto writeFD = _open_osfhandle(writeHandle, _O_APPEND);
    }
    version (DMC_RUNTIME) alias .close _close;
    if (readFD == -1 || writeFD == -1)
    {
        // Close file descriptors, then throw.
        if (readFD >= 0) _close(readFD);
        else CloseHandle(readHandle);
        if (writeFD >= 0) _close(writeFD);
        else CloseHandle(writeHandle);
        throw new StdioException("Error creating pipe");
    }

    // Create FILE pointers from the file descriptors
    Pipe p;
    version (DMC_RUNTIME)
    {
        // This is a re-implementation of DMC's fdopen, but without the
        // mucking with the file descriptor.  POSIX standard requires the
        // new fdopen'd file to retain the given file descriptor's
        // position.
        FILE * local_fdopen(int fd, const(char)* mode)
        {
            auto fp = core.stdc.stdio.fopen("NUL", mode);
            if(!fp) return null;
            FLOCK(fp);
            auto iob = cast(_iobuf*)fp;
            .close(iob._file);
            iob._file = fd;
            iob._flag &= ~_IOTRAN;
            FUNLOCK(fp);
            return fp;
        }

        auto readFP  = local_fdopen(readFD, "r");
        auto writeFP = local_fdopen(writeFD, "a");
    }
    else // MSVCRT
    {
        auto readFP  = _fdopen(readFD, "r");
        auto writeFP = _fdopen(writeFD, "a");
    }
    if (readFP == null || writeFP == null)
    {
        // Close streams, then throw.
        if (readFP != null) fclose(readFP);
        else _close(readFD);
        if (writeFP != null) fclose(writeFP);
        else _close(writeFD);
        throw new StdioException("Cannot open pipe");
    }
    p._read = File(readFP, null);
    p._write = File(writeFP, null);
    return p;
}


/// An interface to a pipe created by the $(LREF pipe) function.
struct Pipe
{
    /// The read end of the pipe.
    @property File readEnd() @trusted /*TODO: @safe nothrow*/ { return _read; }


    /// The write end of the pipe.
    @property File writeEnd() @trusted /*TODO: @safe nothrow*/ { return _write; }


    /**
    Closes both ends of the pipe.

    Normally it is not necessary to do this manually, as $(XREF stdio,File)
    objects are automatically closed when there are no more references
    to them.

    Note that if either end of the pipe has been passed to a child process,
    it will only be closed in the parent process.  (What happens in the
    child process is platform dependent.)
    */
    void close() @trusted //TODO: @safe nothrow
    {
        _read.close();
        _write.close();
    }

private:
    File _read, _write;
}

unittest
{
    auto p = pipe();
    p.writeEnd.writeln("Hello World");
    p.writeEnd.flush();
    assert (p.readEnd.readln().chomp() == "Hello World");
    p.close();
    assert (!p.readEnd.isOpen);
    assert (!p.writeEnd.isOpen);
}


/**
Starts a new process, creating pipes to redirect its standard
input, output and/or error streams.

$(D pipeProcess) and $(D pipeShell) are convenient wrappers around
$(LREF spawnProcess) and $(LREF spawnShell), respectively, and
automate the task of redirecting one or more of the child process'
standard streams through pipes.  Like the functions they wrap,
these functions return immediately, leaving the child process to
execute in parallel with the invoking process.  It is recommended
to always call $(LREF wait) on the returned $(LREF ProcessPipes.pid),
as detailed in the documentation for $(D wait).

The $(D args)/$(D program)/$(D command), $(D env) and $(D config)
parameters are forwarded straight to the underlying spawn functions,
and we refer to their documentation for details.

Params:
args     = An array which contains the program name as the zeroth element
           and any command-line arguments in the following elements.
           (See $(LREF spawnProcess) for details.)
program  = The program name, $(I without) command-line arguments.
           (See $(LREF spawnProcess) for details.)
command  = A shell command which is passed verbatim to the command
           interpreter.  (See $(LREF spawnShell) for details.)
redirect = Flags that determine which streams are redirected, and
           how.  See $(LREF Redirect) for an overview of available
           flags.
env      = Additional environment variables for the child process.
           (See $(LREF spawnProcess) for details.)
config   = Flags that control process creation. See $(LREF Config)
           for an overview of available flags, and note that the
           $(D retainStd...) flags have no effect in this function.

Returns:
A $(LREF ProcessPipes) object which contains $(XREF stdio,File)
handles that communicate with the redirected streams of the child
process, along with a $(LREF Pid) object that corresponds to the
spawned process.

Throws:
$(LREF ProcessException) on failure to start the process.$(BR)
$(XREF stdio,StdioException) on failure to redirect any of the streams.$(BR)

Example:
---
auto pipes = pipeProcess("my_application", Redirect.stdout | Redirect.stderr);
scope(exit) wait(pipes.pid);

// Store lines of output.
string[] output;
foreach (line; pipes.stdout.byLine) output ~= line.idup;

// Store lines of errors.
string[] errors;
foreach (line; pipes.stderr.byLine) errors ~= line.idup;
---
*/
ProcessPipes pipeProcess(string[] args,
                         Redirect redirectFlags = Redirect.all,
                         const string[string] env = null,
                         Config config = Config.none)
    @trusted //TODO: @safe
{
    return pipeProcessImpl!spawnProcess(args, redirectFlags, env, config);
}

/// ditto
ProcessPipes pipeProcess(string program,
                         Redirect redirectFlags = Redirect.all,
                         const string[string] env = null,
                         Config config = Config.none)
    @trusted
{
    return pipeProcessImpl!spawnProcess(program, redirectFlags, env, config);
}

/// ditto
ProcessPipes pipeShell(string command,
                       Redirect redirectFlags = Redirect.all,
                       const string[string] env = null,
                       Config config = Config.none)
    @safe
{
    return pipeProcessImpl!spawnShell(command, redirectFlags, env, config);
}

// Implementation of the pipeProcess() family of functions.
private ProcessPipes pipeProcessImpl(alias spawnFunc, Cmd)
                                    (Cmd command,
                                     Redirect redirectFlags,
                                     const string[string] env = null,
                                     Config config = Config.none)
    @trusted //TODO: @safe
{
    File childStdin, childStdout, childStderr;
    ProcessPipes pipes;
    pipes._redirectFlags = redirectFlags;

    if (redirectFlags & Redirect.stdin)
    {
        auto p = pipe();
        childStdin = p.readEnd;
        pipes._stdin = p.writeEnd;
    }
    else
    {
        childStdin = std.stdio.stdin;
    }

    if (redirectFlags & Redirect.stdout)
    {
        if ((redirectFlags & Redirect.stdoutToStderr) != 0)
            throw new StdioException("Cannot create pipe for stdout AND "
                                     ~"redirect it to stderr", 0);
        auto p = pipe();
        childStdout = p.writeEnd;
        pipes._stdout = p.readEnd;
    }
    else
    {
        childStdout = std.stdio.stdout;
    }

    if (redirectFlags & Redirect.stderr)
    {
        if ((redirectFlags & Redirect.stderrToStdout) != 0)
            throw new StdioException("Cannot create pipe for stderr AND "
                                     ~"redirect it to stdout", 0);
        auto p = pipe();
        childStderr = p.writeEnd;
        pipes._stderr = p.readEnd;
    }
    else
    {
        childStderr = std.stdio.stderr;
    }

    if (redirectFlags & Redirect.stdoutToStderr)
    {
        if (redirectFlags & Redirect.stderrToStdout)
        {
            // We know that neither of the other options have been
            // set, so we assign the std.stdio.std* streams directly.
            childStdout = std.stdio.stderr;
            childStderr = std.stdio.stdout;
        }
        else
        {
            childStdout = childStderr;
        }
    }
    else if (redirectFlags & Redirect.stderrToStdout)
    {
        childStderr = childStdout;
    }

    config &= ~(Config.retainStdin | Config.retainStdout | Config.retainStderr);
    pipes._pid = spawnFunc(command, childStdin, childStdout, childStderr,
                           env, config);
    return pipes;
}


/**
Flags that can be passed to $(LREF pipeProcess) and $(LREF pipeShell)
to specify which of the child process' standard streams are redirected.
Use bitwise OR to combine flags.
*/
enum Redirect
{
    /// Redirect the standard input, output or error streams, respectively.
    stdin = 1,
    stdout = 2,                             /// ditto
    stderr = 4,                             /// ditto

    /**
    Redirect _all three streams.  This is equivalent to
    $(D Redirect.stdin | Redirect.stdout | Redirect.stderr).
    */
    all = stdin | stdout | stderr,

    /**
    Redirect the standard error stream into the standard output stream.
    This can not be combined with $(D Redirect.stderr).
    */
    stderrToStdout = 8,

    /**
    Redirect the standard output stream into the standard error stream.
    This can not be combined with $(D Redirect.stdout).
    */
    stdoutToStderr = 16,
}

unittest
{
    version (Windows) TestScript prog =
       "call :sub %~1 %~2 0
        call :sub %~1 %~2 1
        call :sub %~1 %~2 2
        call :sub %~1 %~2 3
        exit 3

        :sub
        set /p INPUT=
        if -%INPUT%-==-stop- ( exit %~3 )
        echo %INPUT% %~1
        echo %INPUT% %~2 1>&2";
    else version (Posix) TestScript prog =
       `for EXITCODE in 0 1 2 3; do
            read INPUT
            if test "$INPUT" = stop; then break; fi
            echo "$INPUT $1"
            echo "$INPUT $2" >&2
        done
        exit $EXITCODE`;
    auto pp = pipeProcess([prog.path, "bar", "baz"]);
    pp.stdin.writeln("foo");
    pp.stdin.flush();
    assert (pp.stdout.readln().chomp() == "foo bar");
    assert (pp.stderr.readln().chomp().stripRight() == "foo baz");
    pp.stdin.writeln("1234567890");
    pp.stdin.flush();
    assert (pp.stdout.readln().chomp() == "1234567890 bar");
    assert (pp.stderr.readln().chomp().stripRight() == "1234567890 baz");
    pp.stdin.writeln("stop");
    pp.stdin.flush();
    assert (wait(pp.pid) == 2);

    pp = pipeProcess([prog.path, "12345", "67890"],
                     Redirect.stdin | Redirect.stdout | Redirect.stderrToStdout);
    pp.stdin.writeln("xyz");
    pp.stdin.flush();
    assert (pp.stdout.readln().chomp() == "xyz 12345");
    assert (pp.stdout.readln().chomp().stripRight() == "xyz 67890");
    pp.stdin.writeln("stop");
    pp.stdin.flush();
    assert (wait(pp.pid) == 1);

    pp = pipeShell(prog.path~" AAAAA BBB",
                   Redirect.stdin | Redirect.stdoutToStderr | Redirect.stderr);
    pp.stdin.writeln("ab");
    pp.stdin.flush();
    assert (pp.stderr.readln().chomp() == "ab AAAAA");
    assert (pp.stderr.readln().chomp().stripRight() == "ab BBB");
    pp.stdin.writeln("stop");
    pp.stdin.flush();
    assert (wait(pp.pid) == 1);
}

unittest
{
    TestScript prog = "exit 0";
    assertThrown!StdioException(pipeProcess(
        prog.path,
        Redirect.stdout | Redirect.stdoutToStderr));
    assertThrown!StdioException(pipeProcess(
        prog.path,
        Redirect.stderr | Redirect.stderrToStdout));
    auto p = pipeProcess(prog.path, Redirect.stdin);
    assertThrown!Error(p.stdout);
    assertThrown!Error(p.stderr);
    wait(p.pid);
    p = pipeProcess(prog.path, Redirect.stderr);
    assertThrown!Error(p.stdin);
    assertThrown!Error(p.stdout);
    wait(p.pid);
}

/**
Object which contains $(XREF stdio,File) handles that allow communication
with a child process through its standard streams.
*/
struct ProcessPipes
{
    /// The $(LREF Pid) of the child process.
    @property Pid pid() @safe nothrow
    {
        assert(_pid !is null);
        return _pid;
    }

    /**
    An $(XREF stdio,File) that allows writing to the child process'
    standard input stream.

    Throws:
    $(OBJECTREF Error) if the child process' standard input stream hasn't
    been redirected.
    */
    @property File stdin() @trusted //TODO: @safe nothrow
    {
        if ((_redirectFlags & Redirect.stdin) == 0)
            throw new Error("Child process' standard input stream hasn't "
                            ~"been redirected.");
        return _stdin;
    }

    /**
    An $(XREF stdio,File) that allows reading from the child process'
    standard output stream.

    Throws:
    $(OBJECTREF Error) if the child process' standard output stream hasn't
    been redirected.
    */
    @property File stdout() @trusted //TODO: @safe nothrow
    {
        if ((_redirectFlags & Redirect.stdout) == 0)
            throw new Error("Child process' standard output stream hasn't "
                            ~"been redirected.");
        return _stdout;
    }

    /**
    An $(XREF stdio,File) that allows reading from the child process'
    standard error stream.

    Throws:
    $(OBJECTREF Error) if the child process' standard error stream hasn't
    been redirected.
    */
    @property File stderr() @trusted //TODO: @safe nothrow
    {
        if ((_redirectFlags & Redirect.stderr) == 0)
            throw new Error("Child process' standard error stream hasn't "
                            ~"been redirected.");
        return _stderr;
    }

private:
    Redirect _redirectFlags;
    Pid _pid;
    File _stdin, _stdout, _stderr;
}



/**
Executes the given program or shell command and returns its exit
code and output.

$(D execute) and $(D executeShell) start a new process using
$(LREF spawnProcess) and $(LREF spawnShell), respectively, and wait
for the process to complete before returning.  The functions capture
what the child process prints to both its standard output and
standard error streams, and return this together with its exit code.
---
auto dmd = execute("dmd", "myapp.d");
if (dmd.status != 0) writeln("Compilation failed:\n", dmd.output);

auto ls = executeShell("ls -l");
if (ls.status == 0) writeln("Failed to retrieve file listing");
else writeln(ls.output);
---

The $(D args)/$(D program)/$(D command), $(D env) and $(D config)
parameters are forwarded straight to the underlying spawn functions,
and we refer to their documentation for details.

Params:
args      = An array which contains the program name as the zeroth element
            and any command-line arguments in the following elements.
            (See $(LREF spawnProcess) for details.)
program   = The program name, $(I without) command-line arguments.
            (See $(LREF spawnProcess) for details.)
command   = A shell command which is passed verbatim to the command
            interpreter.  (See $(LREF spawnShell) for details.)
env       = Additional environment variables for the child process.
            (See $(LREF spawnProcess) for details.)
config    = Flags that control process creation. See $(LREF Config)
            for an overview of available flags, and note that the
            $(D retainStd...) flags have no effect in this function.
maxOutput = The maximum number of bytes of output that should be
            captured.

Returns:
A $(D struct) which contains the fields $(D int status) and
$(D string output).  (This will most likely change to become a
$(D std.typecons.Tuple!(int,"status",string,"output")) in the future,
but a compiler bug currently prevents this.)

POSIX_specific:
If the process is terminated by a signal, the $(D status) field of
the return value will contain a negative number whose absolute
value is the signal number.  (See $(LREF wait) for details.)

Throws:
$(LREF ProcessException) on failure to start the process.$(BR)
$(XREF stdio,StdioException) on failure to capture output.
*/
auto execute(string[] args,
             const string[string] env = null,
             Config config = Config.none,
             size_t maxOutput = size_t.max)
    @trusted //TODO: @safe
{
    return executeImpl!pipeProcess(args, env, config, maxOutput);
}

/// ditto
auto execute(string program,
             const string[string] env = null,
             Config config = Config.none,
             size_t maxOutput = size_t.max)
    @trusted //TODO: @safe
{
    return executeImpl!pipeProcess(program, env, config, maxOutput);
}

/// ditto
auto executeShell(string command,
                  const string[string] env = null,
                  Config config = Config.none,
                  size_t maxOutput = size_t.max)
    @trusted //TODO: @safe
{
    return executeImpl!pipeShell(command, env, config, maxOutput);
}

// Does the actual work for execute() and executeShell().
private auto executeImpl(alias pipeFunc, Cmd)(
    Cmd commandLine,
    const string[string] env = null,
    Config config = Config.none,
    size_t maxOutput = size_t.max)
{
    auto p = pipeFunc(commandLine, Redirect.stdout | Redirect.stderrToStdout,
                      env, config);

    auto a = appender!(ubyte[])();
    enum size_t defaultChunkSize = 4096;
    immutable chunkSize = min(maxOutput, defaultChunkSize);

    // Store up to maxOutput bytes in a.
    foreach (ubyte[] chunk; p.stdout.byChunk(chunkSize))
    {
        immutable size_t remain = maxOutput - a.data().length;

        if (chunk.length < remain) a.put(chunk);
        else
        {
            a.put(chunk[0 .. remain]);
            break;
        }
    }
    // Exhaust the stream, if necessary.
    foreach (ubyte[] chunk; p.stdout.byChunk(defaultChunkSize)) { }

    struct ProcessOutput { int status; string output; }
    return ProcessOutput(wait(p.pid), cast(string) a.data);
}

unittest
{
    // To avoid printing the newline characters, we use the echo|set trick on
    // Windows, and printf on POSIX (neither echo -n nor echo \c are portable).
    version (Windows) TestScript prog =
       "echo|set /p=%~1
        echo|set /p=%~2 1>&2
        exit 123";
    else version (Posix) TestScript prog =
       `printf '%s' $1
        printf '%s' $2 >&2
        exit 123`;
    auto r = execute([prog.path, "foo", "bar"]);
    assert (r.status == 123);
    assert (r.output.stripRight() == "foobar");
    auto s = execute([prog.path, "Hello", "World"]);
    assert (s.status == 123);
    assert (s.output.stripRight() == "HelloWorld");
}

unittest
{
    auto r1 = executeShell("echo foo");
    assert (r1.status == 0);
    assert (r1.output.chomp() == "foo");
    auto r2 = executeShell("echo bar 1>&2");
    assert (r2.status == 0);
    assert (r2.output.chomp().stripRight() == "bar");
    auto r3 = executeShell("exit 123");
    assert (r3.status == 123);
    assert (r3.output.empty);
}


/// An exception that signals a problem with starting or waiting for a process.
class ProcessException : Exception
{
    // Standard constructor.
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line);
    }

    // Creates a new ProcessException based on errno.
    static ProcessException newFromErrno(string customMsg = null,
                                         string file = __FILE__,
                                         size_t line = __LINE__)
    {
        import core.stdc.errno;
        import std.c.string;
        version (linux)
        {
            char[1024] buf;
            auto errnoMsg = to!string(
                std.c.string.strerror_r(errno, buf.ptr, buf.length));
        }
        else
        {
            auto errnoMsg = to!string(std.c.string.strerror(errno));
        }
        auto msg = customMsg.empty() ? errnoMsg
                                     : customMsg ~ " (" ~ errnoMsg ~ ')';
        return new ProcessException(msg, file, line);
    }

    // Creates a new ProcessException based on GetLastError() (Windows only).
    version (Windows)
    static ProcessException newFromLastError(string customMsg = null,
                                             string file = __FILE__,
                                             size_t line = __LINE__)
    {
        auto lastMsg = sysErrorString(GetLastError());
        auto msg = customMsg.empty() ? lastMsg
                                     : customMsg ~ " (" ~ lastMsg ~ ')';
        return new ProcessException(msg, file, line);
    }
}


/**
Determines the path to the current user's default command interpreter.

On Windows, this function returns the contents of the COMSPEC environment
variable, if it exists.  Otherwise, it returns the string $(D "cmd.exe").

On POSIX, $(D userShell) returns the contents of the SHELL environment
variable, if it exists and is non-empty.  Otherwise, it returns
$(D "/bin/sh").
*/
@property string userShell() @safe //TODO: nothrow
{
    version (Windows)    return environment.get("COMSPEC", "cmd.exe");
    else version (Posix) return environment.get("SHELL", "/bin/sh");
}


// A command-line switch that indicates to the shell that it should
// interpret the following argument as a command to be executed.
version (Posix)   private immutable string shellSwitch = "-c";
version (Windows) private immutable string shellSwitch = "/C";


/// Returns the process ID number of the current process.
@property int thisProcessID() @trusted //TODO: @safe nothrow
{
    version (Windows)    return GetCurrentProcessId();
    else version (Posix) return getpid();
}


// Unittest support code:  TestScript takes a string that contains a
// shell script for the current platform, and writes it to a temporary
// file. On Windows the file name gets a .cmd extension, while on
// POSIX its executable permission bit is set.  The file is
// automatically deleted when the object goes out of scope.
version (unittest)
private struct TestScript
{
    this(string code)
    {
        import std.ascii, std.file;
        version (Windows)
        {
            auto ext = ".cmd";
            auto firstLine = "@echo off";
        }
        else version (Posix)
        {
            auto ext = "";
            auto firstLine = "#!/bin/sh";
        }
        path = uniqueTempPath()~ext;
        std.file.write(path, firstLine~std.ascii.newline~code~std.ascii.newline);
        version (Posix)
        {
            import core.sys.posix.sys.stat;
            chmod(toStringz(path), octal!777);
        }
    }

    ~this()
    {
        import std.file;
        if (!path.empty && exists(path))
        {
            try { remove(path); }
            catch (Exception e)
            {
                debug std.stdio.stderr.writeln(e.msg);
            }
        }
    }

    string path;
}

version (unittest)
private string uniqueTempPath()
{
    import std.file, std.uuid;
    return buildPath(tempDir(), randomUUID().toString());
}


// =============================================================================
// Functions for shell command quoting/escaping.
// =============================================================================


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

/**
Escapes an argv-style argument array to be used with $(LREF spawnShell),
$(LREF pipeShell) or $(LREF executeShell).
---
string url = "http://dlang.org/";
executeShell(escapeShellCommand("wget", url, "-O", "dlang-index.html"));
---

Concatenate multiple $(D escapeShellCommand) and
$(LREF escapeShellFileName) results to use shell redirection or
piping operators.
---
executeShell(
    escapeShellCommand("curl", "http://dlang.org/download.html") ~
    "|" ~
    escapeShellCommand("grep", "-o", `http://\S*\.zip`) ~
    ">" ~
    escapeShellFileName("D download links.txt"));
---

Throws:
$(OBJECTREF Exception) if any part of the command line contains unescapable
characters (NUL on all platforms, as well as CR and LF on Windows).
*/
string escapeShellCommand(in char[][] args...)
    //TODO: @safe pure nothrow
{
    return escapeShellCommandString(escapeShellArguments(args));
}


private string escapeShellCommandString(string command)
    //TODO: @safe pure nothrow
{
    version (Windows)
        return escapeWindowsShellCommand(command);
    else
        return command;
}

private string escapeWindowsShellCommand(in char[] command)
    //TODO: @safe pure nothrow (prevented by Appender)
{
    auto result = appender!string();
    result.reserve(command.length);

    foreach (c; command)
        switch (c)
        {
            case '\0':
                throw new Exception("Cannot put NUL in command line");
            case '\r':
            case '\n':
                throw new Exception("CR/LF are not escapable");
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

private string escapeShellArguments(in char[][] args...)
    @trusted pure nothrow
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

private auto escapeShellArgument(alias allocator)(in char[] arg) @safe nothrow
{
    // The unittest for this function requires special
    // preparation - see below.

    version (Windows)
        return escapeWindowsArgumentImpl!allocator(arg);
    else
        return escapePosixArgumentImpl!allocator(arg);
}

/**
Quotes a command-line argument in a manner conforming to the behavior of
$(LINK2 http://msdn.microsoft.com/en-us/library/windows/desktop/bb776391(v=vs.85).aspx,
CommandLineToArgvW).
*/
string escapeWindowsArgument(in char[] arg) @trusted pure nothrow
{
    // Rationale for leaving this function as public:
    // this algorithm of escaping paths is also used in other software,
    // e.g. DMD's response files.

    auto buf = escapeWindowsArgumentImpl!charAllocator(arg);
    return assumeUnique(buf);
}


private char[] charAllocator(size_t size) @safe pure nothrow
{
    return new char[size];
}


private char[] escapeWindowsArgumentImpl(alias allocator)(in char[] arg)
    @safe nothrow
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

private string escapePosixArgument(in char[] arg) @trusted pure nothrow
{
    auto buf = escapePosixArgumentImpl!charAllocator(arg);
    return assumeUnique(buf);
}

private char[] escapePosixArgumentImpl(alias allocator)(in char[] arg)
    @safe nothrow
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

/**
Escapes a filename to be used for shell redirection with $(LREF spawnShell),
$(LREF pipeShell) or $(LREF executeShell).
*/
string escapeShellFileName(in char[] fileName) @trusted pure nothrow
{
    // The unittest for this function requires special
    // preparation - see below.

    version (Windows)
        return cast(string)('"' ~ fileName ~ '"');
    else
        return escapePosixArgument(fileName);
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


// =============================================================================
// Environment variable manipulation.
// =============================================================================


/**
Manipulates _environment variables using an associative-array-like
interface.

This class contains only static methods, and cannot be instantiated.
See below for examples of use.
*/
abstract final class environment
{
static:
    /**
    Retrieves the value of the environment variable with the given $(D name).
    ---
    auto path = environment["PATH"];
    ---

    Throws:
    $(OBJECTREF Exception) if the environment variable does not exist.

    See_also:
    $(LREF environment.get), which doesn't throw on failure.
    */
    string opIndex(string name) @safe
    {
        string value;
        enforce(getImpl(name, value), "Environment variable not found: "~name);
        return value;
    }

    /**
    Retrieves the value of the environment variable with the given $(D name),
    or a default value if the variable doesn't exist.

    Unlike $(LREF environment.opIndex), this function never throws.
    ---
    auto sh = environment.get("SHELL", "/bin/sh");
    ---
    This function is also useful in checking for the existence of an
    environment variable.
    ---
    auto myVar = environment.get("MYVAR");
    if (myVar is null)
    {
        // Environment variable doesn't exist.
        // Note that we have to use 'is' for the comparison, since
        // myVar == null is also true if the variable exists but is
        // empty.
    }
    ---
    */
    string get(string name, string defaultValue = null) @safe //TODO: nothrow
    {
        string value;
        auto found = getImpl(name, value);
        return found ? value : defaultValue;
    }

    /**
    Assigns the given $(D value) to the environment variable with the given
    $(D name).

    If the variable does not exist, it will be created. If it already exists,
    it will be overwritten.
    ---
    environment["foo"] = "bar";
    ---

    Throws:
    $(OBJECTREF Exception) if the environment variable could not be added
        (e.g. if the name is invalid).
    */
    string opIndexAssign(string value, string name) @trusted
    {
        version (Posix)
        {
            if (core.sys.posix.stdlib.setenv(toStringz(name), toStringz(value), 1) != -1)
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
        else version (Windows)
        {
            enforce(
                SetEnvironmentVariableW(toUTF16z(name), toUTF16z(value)),
                sysErrorString(GetLastError())
            );
            return value;
        }
        else static assert(0);
    }

    /**
    Removes the environment variable with the given $(D name).

    If the variable isn't in the environment, this function returns
    successfully without doing anything.
    */
    void remove(string name) @trusted // TODO: @safe nothrow
    {
        version (Windows)    SetEnvironmentVariableW(toUTF16z(name), null);
        else version (Posix) core.sys.posix.stdlib.unsetenv(toStringz(name));
        else static assert(0);
    }

    /**
    Copies all environment variables into an associative array.

    Windows_specific:
    While Windows environment variable names are case insensitive, D's
    built-in associative arrays are not.  This function will store all
    variable names in uppercase (e.g. $(D PATH)).

    Throws:
    $(OBJECTREF Exception) if the environment variables could not
        be retrieved (Windows only).
    */
    string[string] toAA() @trusted
    {
        string[string] aa;
        version (Posix)
        {
            for (int i=0; environ[i] != null; ++i)
            {
                immutable varDef = to!string(environ[i]);
                immutable eq = std.string.indexOf(varDef, '=');
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
        else version (Windows)
        {
            auto envBlock = GetEnvironmentStringsW();
            enforce(envBlock, "Failed to retrieve environment variables.");
            scope(exit) FreeEnvironmentStringsW(envBlock);

            for (int i=0; envBlock[i] != '\0'; ++i)
            {
                auto start = i;
                while (envBlock[i] != '=') ++i;
                immutable name = toUTF8(toUpper(envBlock[start .. i]));

                start = i+1;
                while (envBlock[i] != '\0') ++i;
                // Just like in POSIX systems, environment variables may be
                // defined more than once in an environment block on Windows,
                // and it is just as much of a security issue there.  Moreso,
                // in fact, due to the case insensensitivity of variable names,
                // which is not handled correctly by all programs.
                if (name !in aa) aa[name] = toUTF8(envBlock[start .. i]);
            }
        }
        else static assert(0);
        return aa;
    }

private:
    // Returns the length of an environment variable (in number of
    // wchars, including the null terminator), or 0 if it doesn't exist.
    version (Windows)
    int varLength(LPCWSTR namez) @trusted nothrow
    {
        return GetEnvironmentVariableW(namez, null, 0);
    }

    // Retrieves the environment variable, returns false on failure.
    bool getImpl(string name, out string value) @trusted //TODO: nothrow
    {
        version (Windows)
        {
            const namez = toUTF16z(name);
            immutable len = varLength(namez);
            if (len == 0) return false;
            if (len == 1)
            {
                value = "";
                return true;
            }

            auto buf = new WCHAR[len];
            GetEnvironmentVariableW(namez, buf.ptr, to!DWORD(buf.length));
            value = toUTF8(buf[0 .. $-1]);
            return true;
        }
        else version (Posix)
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
        else static assert(0);
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
    assertThrown(environment["std_process"]);

    // get() without default value
    assert (environment.get("std_process") == null);

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
        version (Windows) if (n.length == 0 || v.length == 0) continue;

        assert (v == environment[n]);
    }
}




// =============================================================================
// Everything below this line was part of the old std.process, and most of
// it will be deprecated and removed.
// =============================================================================


/*
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


import core.stdc.stdlib;
import std.c.stdlib;
import core.stdc.errno;
import core.thread;
import std.c.process;
import std.c.string;

version (Windows)
{
    import std.format, std.random, std.file;
}
version (Posix)
{
    import core.sys.posix.stdlib;
}
version (unittest)
{
    import std.file, std.conv, std.random;
}



/**
   Execute $(D command) in a _command shell.

   $(RED This function is scheduled for deprecation.  Please use
   $(LREF spawnShell) or $(LREF executeShell) instead.)

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
 * the arguments in $(D argv).
 *
 * $(RED These functions are scheduled for deprecation.  Please use
 * $(LREF spawnShell) instead (or, alternatively, the homonymous C
 * functions declared in $(D std.c.process).))
 *
 * Typically, the first element of $(D argv) is
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
 * $(RED This function is scheduled for deprecation.  Please use
 * $(LREF thisProcessID) instead.)
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

   $(RED This function is scheduled for deprecation.  Please use
   $(LREF executeShell) instead.)

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
internally.

   $(RED This function is scheduled for deprecation.  Please use
   $(LREF environment.get) instead.)
*/

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
std.c.stdlib._setenv) internally.

   $(RED This function is scheduled for deprecation.  Please use
   $(LREF environment.opIndexAssign) instead.)
*/
version(StdDdoc) void setenv(in char[] name, in char[] value, bool overwrite);
else version(Posix) void setenv(in char[] name, in char[] value, bool overwrite)
{
    errnoEnforce(
        std.c.stdlib.setenv(toStringz(name), toStringz(value), overwrite) == 0);
}

/**
Removes variable $(D name) from the environment. Calls $(LINK2
std_c_stdlib.html#_unsetenv, std.c.stdlib._unsetenv) internally.

   $(RED This function is scheduled for deprecation.  Please use
   $(LREF environment.remove) instead.)
*/
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
