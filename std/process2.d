// Written in the D programming language.

/**
Functions for starting and interacting with other processes, and for
working with the current process' execution environment.

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
    child _processes becoming "zombies" when the parent _process exits.
    Scope guards are perfect for this – see the $(LREF spawnProcess)
    documentation for examples.)
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
    $(LREF spawnShell), $(LREF pipeShell) and $(LREF shell) work like
    $(D spawnProcess), $(D pipeProcess) and $(D execute), respectively,
    except that they take a single command string and run it through
    the current user's default command interpreter.
    $(D shell) corresponds roughly to C's $(D system) function.)
$(LI
    $(LREF kill) attempts to terminate a running process.)
)
Unless the directory of the executable file is explicitly specified, all
functions will search for it in the directories specified in the PATH
environment variable.

Other_functionality:
$(UL
$(LI
    $(LREF pipe) is used to create unidirectional pipes.)
$(LI
    $(LREF environment) is an interface through which the current process'
    environment variables can be read and manipulated.)
)

Authors:
    $(LINK2 https://github.com/kyllingstad, Lars Tandle Kyllingstad),
    $(LINK2 https://github.com/schveiguy, Steven Schveighoffer),
    $(LINK2 https://github.com/cybershadow, Vladimir Panteleev)
Copyright:
    Copyright (c) 2013, the authors. All rights reserved.
Source:
    $(PHOBOSSRC std/_process.d)
Macros:
    WIKI=Phobos/StdProcess
    OBJECTREF=$(D $(LINK2 object.html#$0,$0))
*/
module std.process2;

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
import std.typecons;


// When the DMC runtime is used, we have to use some custom functions
// to convert between Windows file handles and FILE*s.
version (Win32) version (DigitalMars) version = DMC_RUNTIME;


// Some of the following should be moved to druntime.
private:

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
        // https://www.gnu.org/software/gnulib/manual/html_node/environ.html
        extern(C) char*** _NSGetEnviron();
        __gshared const char** environ;
        shared static this() { environ = *_NSGetEnviron(); }
    }
    else
    {
        // Made available by the C runtime:
        extern(C) extern __gshared const char** environ;
    }
}


// Actual module classes/functions start here.
public:


// =============================================================================
// Functions and classes for process management.
// =============================================================================


/**
Spawns a new _process, optionally assigning it an
arbitrary set of standard input, output, and error streams.
The function returns immediately, leaving the child _process to execute
in parallel with its parent.

Command_line:
There are four overloads of this function.  The first two take an array
of strings, $(D args), which should contain the program name as the
zeroth element and any command-line arguments in subsequent elements.
The third and fourth versions are included for convenience, and may be
used when there are no command-line arguments.  They take a single string,
$(D program), which specifies the program name.

Unless a directory is specified in $(D args[0]) or $(D program),
$(D spawnProcess) will search for the program in the directories listed
in the PATH environment variable.  To run an executable in the current
directory, use $(D "./$(I executable_name)").
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
With the first and third $(D spawnProcess) overloads, one can specify
the environment variables of the child process using the $(D environmentVars)
parameter.  With the second and fourth overload, the child process inherits
its parent's environment variables.

To make the child inherit the parent's environment $(I plus) one or more
additional variables, first use $(D $(LREF environment).$(LREF toAA)) to
obtain an associative array that contains the parent's environment
variables, and add the new variables to it before passing it to
$(D spawnProcess).
---
auto envVars = environment.toAA();
envVars["FOO"] = "bar";
wait(spawnProcess("prog", envVars));
---

Standard_streams:
The optional arguments $(D stdin_), $(D stdout_) and $(D stderr_) may
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
args = An array which contains the program name as the first element
    and any command-line arguments in the following elements.
program = The program name, $(I without) command-line arguments.
environmentVars = The environment variables for the child process may
    be specified using this parameter.  By default it is $(D null),
    which means that, the child process inherits the environment of
    the parent process.
stdin_ = The standard input stream of the child process.
    This can be any $(XREF stdio,File) that is opened for reading.
    By default the child process inherits the parent's input
    stream.
stdout_ = The standard output stream of the child process.
    This can be any $(XREF stdio,File) that is opened for writing.
    By default the child process inherits the parent's output
    stream.
stderr_ = The standard error stream of the child process.
    This can be any $(XREF stdio,File) that is opened for writing.
    By default the child process inherits the parent's error
    stream.
config = Options that control the behaviour of $(D spawnProcess).
    See the $(LREF Config) documentation for details.

Returns:
A $(LREF Pid) object that corresponds to the spawned process.

Throws:
$(LREF ProcessException) on failure to start the process.$(BR)
$(XREF stdio,StdioException) on failure to pass one of the streams
    to the child process (Windows only).$(BR)
$(CXREF exception,RangeError) if $(D args) is empty.
*/
Pid spawnProcess(in char[][] args,
                 const string[string] environmentVars,
                 File stdin_ = std.stdio.stdin,
                 File stdout_ = std.stdio.stdout,
                 File stderr_ = std.stdio.stderr,
                 Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    version (Windows)    auto  args2 = escapeShellArguments(args);
    else version (Posix) alias args2 = args;
    return spawnProcessImpl(args2, toEnvz(environmentVars),
                            stdin_, stdout_, stderr_, config);
}

/// ditto
Pid spawnProcess(in char[][] args,
                 File stdin_ = std.stdio.stdin,
                 File stdout_ = std.stdio.stdout,
                 File stderr_ = std.stdio.stderr,
                 Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    version (Windows)    auto  args2 = escapeShellArguments(args);
    else version (Posix) alias args2 = args;
    return spawnProcessImpl(args2, null, stdin_, stdout_, stderr_, config);
}

/// ditto
Pid spawnProcess(in char[] program,
                 const string[string] environmentVars,
                 File stdin_ = std.stdio.stdin,
                 File stdout_ = std.stdio.stdout,
                 File stderr_ = std.stdio.stderr,
                 Config config = Config.none)
    @trusted
{
    return spawnProcess((&program)[0 .. 1], environmentVars,
                        stdin_, stdout_, stderr_, config);
}

/// ditto
Pid spawnProcess(in char[] program,
                 File stdin_ = std.stdio.stdin,
                 File stdout_ = std.stdio.stdout,
                 File stderr_ = std.stdio.stderr,
                 Config config = Config.none)
    @trusted
{
    return spawnProcess((&program)[0 .. 1],
                        stdin_, stdout_, stderr_, config);
}

/*
Implementation of spawnProcess() for POSIX.

envz should be a zero-terminated array of zero-terminated strings
on the form "var=value".
*/
version (Posix)
private Pid spawnProcessImpl(in char[][] args,
                             const(char*)* envz,
                             File stdin_,
                             File stdout_,
                             File stderr_,
                             Config config)
    @trusted // TODO: Should be @safe
{
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

    // Use parent's environment variables?
    if (envz is null) envz = environ;

    // Get the file descriptors of the streams.
    // These could potentially be invalid, but that is OK.  If so, later calls
    // to dup2() and close() will just silently fail without causing any harm.
    auto stdinFD  = core.stdc.stdio.fileno(stdin_.getFP());
    auto stdoutFD = core.stdc.stdio.fileno(stdout_.getFP());
    auto stderrFD = core.stdc.stdio.fileno(stderr_.getFP());

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

        // Close the old file descriptors, unless they are
        // either of the standard streams.
        if (stdinFD  > STDERR_FILENO)  close(stdinFD);
        if (stdoutFD > STDERR_FILENO)  close(stdoutFD);
        if (stderrFD > STDERR_FILENO)  close(stderrFD);

        // Execute program.
        execve(argz[0], argz.ptr, envz);

        // If execution fails, exit as quickly as possible.
        perror("spawnProcess(): Failed to execute program");
        _exit(1);
        assert (0);
    }
    else
    {
        // Parent process:  Close streams and return.
        if (stdinFD  > STDERR_FILENO && !(config & Config.noCloseStdin))
            stdin_.close();
        if (stdoutFD > STDERR_FILENO && !(config & Config.noCloseStdout))
            stdout_.close();
        if (stderrFD > STDERR_FILENO && !(config & Config.noCloseStderr))
            stderr_.close();
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
                             LPVOID envz,
                             File stdin_,
                             File stdout_,
                             File stderr_,
                             Config config)
    @trusted
{
    auto commandz = toUTFz!(wchar*)(commandLine);

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
    prepareStream(stdin_,  STD_INPUT_HANDLE,  "stdin" , stdinFD,  startinfo.hStdInput );
    prepareStream(stdout_, STD_OUTPUT_HANDLE, "stdout", stdoutFD, startinfo.hStdOutput);
    prepareStream(stderr_, STD_ERROR_HANDLE,  "stderr", stderrFD, startinfo.hStdError );

    // Create process.
    PROCESS_INFORMATION pi;
    DWORD dwCreationFlags = CREATE_UNICODE_ENVIRONMENT |
                            ((config & Config.gui) ? CREATE_NO_WINDOW : 0);
    if (!CreateProcessW(null, commandz, null, null, true, dwCreationFlags,
                        envz, null, &startinfo, &pi))
        throw ProcessException.newFromLastError("Failed to spawn new process");

    // figure out if we should close any of the streams
    if (stdinFD  > STDERR_FILENO && !(config & Config.noCloseStdin))
        stdin_.close();
    if (stdoutFD > STDERR_FILENO && !(config & Config.noCloseStdout))
        stdout_.close();
    if (stderrFD > STDERR_FILENO && !(config & Config.noCloseStderr))
        stderr_.close();

    // close the thread handle in the process info structure
    CloseHandle(pi.hThread);

    return new Pid(pi.dwProcessId, pi.hProcess);
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

// Converts a string[string] array to a C array of C strings
// on the form "key=value".
version (Posix)
private const(char)** toEnvz(const string[string] env)
    @trusted //TODO: @safe pure nothrow
{
    alias const(char)* stringz_t;
    auto envz = new stringz_t[](env.length+1);
    int i = 0;
    foreach (k, v; env) envz[i++] = (k~'='~v~'\0').ptr;
    envz[i] = null;
    return envz.ptr;
}

// Converts a string[string] array to a block of 16-bit
// characters on the form "key=value\0key=value\0...\0\0"
version (Windows)
private LPVOID toEnvz(const string[string] env)
    @trusted //TODO: @safe pure nothrow
{
    auto envz = appender!(wchar[])();
    foreach(k, v; env)
    {
        envz.put(k);
        envz.put('=');
        envz.put(v);
        envz.put('\0');
    }
    envz.put('\0');
    return envz.data.ptr;
}

// Checks whether the file exists and can be executed by the
// current user.
version (Posix)
private bool isExecutable(in char[] path) @trusted //TODO: @safe nothrow
{
    return (access(toStringz(path), X_OK) == 0);
}

unittest
{
    TestScript prog1 = "exit 0";
    assert (wait(spawnProcess(prog1.path)) == 0);

    TestScript prog2 = "exit 123";
    auto pid2 = spawnProcess([prog2.path]);
    assert (wait(pid2) == 123);
    assert (wait(pid2) == 123); // Exit code is cached.

    version (Windows) TestScript prog3 =
       "if not -%1-==-foo- ( exit 1 )
        if not -%2-==-bar- ( exit 1 )
        exit 0";
    else version (Posix) TestScript prog3 =
       `if test "$1" != "foo"; then exit 1; fi
        if test "$2" != "bar"; then exit 1; fi
        exit 0`;
    assert (wait(spawnProcess([ prog3.path, "foo", "bar"])) == 0);
    assert (wait(spawnProcess(prog3.path)) == 1);

    version (Windows) TestScript prog4 =
       "if %hello%==world ( exit 0 )
        exit 1";
    version (Posix) TestScript prog4 =
       "if test $hello = world; then exit 0; fi
        exit 1";
    auto env = [ "hello" : "world" ];
    assert (wait(spawnProcess(prog4.path, env)) == 0);
    assert (wait(spawnProcess([prog4.path], env)) == 0);

    version (Windows) TestScript prog5 =
       "set /p INPUT=
        echo %INPUT% output %1
        echo %INPUT% error %2 1>&2";
    else version (Posix) TestScript prog5 =
       "read INPUT
        echo $INPUT output $1
        echo $INPUT error $2 >&2";
    auto pipe5i = pipe();
    auto pipe5o = pipe();
    auto pipe5e = pipe();
    auto pid5 = spawnProcess([ prog5.path, "foo", "bar" ],
                             pipe5i.readEnd, pipe5o.writeEnd, pipe5e.writeEnd);
    pipe5i.writeEnd.writeln("input");
    pipe5i.writeEnd.flush();
    assert (pipe5o.readEnd.readln().chomp() == "input output foo");
    assert (pipe5e.readEnd.readln().chomp().stripRight() == "input error bar");
    wait(pid5);

    import std.ascii, std.file, std.uuid;
    auto path6i = buildPath(tempDir(), randomUUID().toString());
    auto path6o = buildPath(tempDir(), randomUUID().toString());
    auto path6e = buildPath(tempDir(), randomUUID().toString());
    std.file.write(path6i, "INPUT"~std.ascii.newline);
    auto file6i = File(path6i, "r");
    auto file6o = File(path6o, "w");
    auto file6e = File(path6e, "w");
    auto pid6 = spawnProcess([prog5.path, "bar", "baz" ],
                             file6i, file6o, file6e);
    wait(pid6);
    assert (readText(path6o).chomp() == "INPUT output bar");
    assert (readText(path6e).chomp().stripRight() == "INPUT error baz");
    remove(path6i);
    remove(path6o);
    remove(path6e);
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
properly quoted and escaped shell command line for the current plattform,
from an array of separate arguments.
*/
Pid spawnShell(in char[] command,
               const string[string] environmentVars,
               File stdin_ = std.stdio.stdin,
               File stdout_ = std.stdio.stdout,
               File stderr_ = std.stdio.stderr,
               Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    return spawnShellImpl(command, toEnvz(environmentVars),
                          stdin_, stdout_, stderr_, config);
}

/// ditto
Pid spawnShell(in char[] command,
               File stdin_ = std.stdio.stdin,
               File stdout_ = std.stdio.stdout,
               File stderr_ = std.stdio.stderr,
               Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    return spawnShellImpl(command, null, stdin_, stdout_, stderr_, config);
}

// Implementation of spawnShell() for Windows.
version(Windows)
private Pid spawnShellImpl(in char[] command,
                           LPVOID envz,
                           File stdin_ = std.stdio.stdin,
                           File stdout_ = std.stdio.stdout,
                           File stderr_ = std.stdio.stderr,
                           Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    auto scmd = escapeShellArguments(userShell, shellSwitch) ~ " " ~ command;
    return spawnProcessImpl(scmd, envz, stdin_, stdout_, stderr_, config);
}

// Implementation of spawnShell() for POSIX.
version(Posix)
private Pid spawnShellImpl(in char[] command,
                           const char** envz,
                           File stdin_ = std.stdio.stdin,
                           File stdout_ = std.stdio.stdout,
                           File stderr_ = std.stdio.stderr,
                           Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    const(char)[][3] args;
    args[0] = userShell;
    args[1] = shellSwitch;
    args[2] = command;
    return spawnProcessImpl(args, envz, stdin_, stdout_, stderr_, config);
}



/**
Flags that control the behaviour of $(LREF spawnProcess) and
$(LREF spawnShell).

Use bitwise OR to combine flags.

Example:
---
auto logFile = File("myapp_error.log", "w");

// Start program in a console window (Windows only), redirect
// its error stream to logFile, and leave logFile open in the
// parent process as well.
auto pid = spawnProcess("myapp", stdin, stdout, logFile,
                        Config.noCloseStderr | Config.gui);
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
    Unless the child process inherits the standard
    input/output/error streams of its parent, one almost
    always wants the streams closed in the parent when
    $(LREF spawnProcess) returns.  Therefore, by default, this
    is done.  If this is not desirable, pass any of these
    options to spawnProcess.
    */
    noCloseStdin  = 1,
    noCloseStdout = 2,                                  /// ditto
    noCloseStderr = 4,                                  /// ditto

    /**
    On Windows, the child process will by default be run in
    a console window.  This option wil cause it to run in "GUI mode"
    instead, i.e., without a console. On POSIX, it has no effect.
    */
    gui = 8,
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
    with the same value as $(LREF processID), while on Windows it returns
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
        HANDLE _handle;
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


/**
A non-blocking version of $(LREF wait).

If the process associated with $(D pid) has already terminated,
$(D tryWait) has the exact same effect as $(D wait).
In this case, it returns a tuple where the $(D terminated) field
is set to $(D true) and the $(D status) field has the same
interpretation as the return value of $(D wait).

If the process has $(I not) yet terminated, this function differs
from $(D wait) in that does not wait for this to happen, but instead
returns immediately.  The $(D terminated) field of the returned
tuple will then be set to $(D false), while the $(D status) field
will always be 0 (zero).  $(D wait) or $(D tryWait) should then be
called again at some later time on the same $(D Pid); not only to
get the exit code, but also to avoid the process becoming a "zombie"
when it finally terminates.  (See $(LREF wait) for details).

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
Tuple!(bool, "terminated", int, "status") tryWait(Pid pid) @safe
{
    assert(pid !is null, "Called tryWait on a null Pid.");
    auto code = pid.performWait(false);
    return typeof(return)(pid._processID == Pid.terminated, code);
}


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
will be used as the exit code of the process.  If not, the process wil exit
with code 1.  Do not use $(D codeOrSignal = 259), as this is a special value
(aka. $(LINK2 http://msdn.microsoft.com/en-us/library/windows/desktop/ms683189.aspx,
STILL_ACTIVE)) used by Windows to signal that a process has in fact $(I not)
terminated yet.
---
auto pid = spawnProcess("some_app");
kill(pid, 10);
assert (wait(pid) == 10);
---

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
$(LREF ProcessException) if the operating system reports an error.
    (Note that this does not include failure to terminate the process,
    which is considered a "normal" outcome.)$(BR)
$(OBJECTREF Error) if $(D codeOrSignal) is negative.
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
    version (Windows)    enum errMsg = "Invalid exit code";
    else version (Posix) enum errMsg = "Invalid signal";
    if (codeOrSignal < 0) throw new Error(errMsg);

    version (Windows)
    {
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

unittest
{
    // The test script goes into an infinite loop.
    version (Windows)
    {
        TestScript prog = "loop:
                           goto loop";
    }
    else version (Posix)
    {
        import core.sys.posix.signal: SIGTERM, SIGKILL;
        TestScript prog = "while true; do; done";
    }
    auto pid = spawnProcess(prog.path);
    kill(pid);
    version (Windows)    assert (wait(pid) == 1);
    else version (Posix) assert (wait(pid) == -SIGTERM);

    pid = spawnProcess(prog.path);
    auto s = tryWait(pid);
    assert (!s.terminated && s.status == 0);
    version (Windows)    kill(pid, 123);
    else version (Posix) kill(pid, SIGKILL);
    do { s = tryWait(pid); } while (!s.terminated);
    version (Windows)    assert (s.status == 123);
    else version (Posix) assert (s.status == -SIGKILL);
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
    errnoEnforce(core.sys.posix.unistd.pipe(fds) == 0,
                 "Unable to create pipe");
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
}


/**
Starts a new process, creating pipes to redirect its standard
input, output and/or error streams.

These functions return immediately, leaving the child process to
execute in parallel with the parent.
$(LREF pipeShell) invokes the user's _command interpreter, as
determined by $(LREF userShell), to execute the given program or
_command.

Returns:
A $(LREF ProcessPipes) object which contains $(XREF stdio,File)
handles that communicate with the redirected streams of the child
process, along with the $(LREF Pid) of the process.

Throws:
$(LREF ProcessException) on failure to start the process.$(BR)
$(XREF stdio,StdioException) on failure to create pipes.$(BR)
$(OBJECTREF Error) if $(D redirectFlags) is an invalid combination of flags.

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
ProcessPipes pipeProcess(string program,
                         Redirect redirectFlags = Redirect.all)
    @trusted
{
    return pipeProcessImpl!spawnProcess(program, redirectFlags);
}

/// ditto
ProcessPipes pipeProcess(string[] args,
                         Redirect redirectFlags = Redirect.all)
    @trusted //TODO: @safe
{
    return pipeProcessImpl!spawnProcess(args, redirectFlags);
}

/// ditto
ProcessPipes pipeShell(string command, Redirect redirectFlags = Redirect.all)
    @safe
{
    return pipeProcessImpl!spawnShell(command, redirectFlags);
}

// Implementation of the pipeProcess() family of functions.
private ProcessPipes pipeProcessImpl(alias spawnFunc, Cmd)
                                    (Cmd command, Redirect redirectFlags)
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
            throw new Error("Invalid combination of options: Redirect.stdout | "
                            ~"Redirect.stdoutToStderr");
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
            throw new Error("Invalid combination of options: Redirect.stderr | "
                            ~"Redirect.stderrToStdout");
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

    pipes._pid = spawnFunc(command, null, childStdin, childStdout, childStderr);
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
       "call :sub %1 %2 0
        call :sub %1 %2 1
        call :sub %1 %2 2
        call :sub %1 %2 3
        exit 3

        :sub
        set /p INPUT=
        if -%INPUT%-==-stop- ( exit %3 )
        echo %INPUT% %1
        echo %INPUT% %2 1>&2";
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
Executes the given program and returns its exit code and output.

This function blocks until the program terminates.
The $(D output) string includes what the program writes to its
standard error stream as well as its standard output stream.
---
auto dmd = execute("dmd myapp.d");
if (dmd.status != 0) writeln("Compilation failed:\n", dmd.output);
---

POSIX_specific:
If the process is terminated by a signal, the $(D status) field of
the return value will contain a negative number whose absolute
value is the signal number.  (See $(LREF wait) for details.)

Throws:
$(LREF ProcessException) on failure to start the process.$(BR)
$(XREF stdio,StdioException) on failure to capture output.
*/
Tuple!(int, "status", string, "output") execute(string program)
    @trusted //TODO: @safe
{
    auto p = pipeProcess(program, Redirect.stdout | Redirect.stderrToStdout);
    return processOutput(p, size_t.max);
}

/// ditto
Tuple!(int, "status", string, "output") execute(string[] args...)
    @trusted //TODO: @safe
{
    auto p = pipeProcess(args, Redirect.stdout | Redirect.stderrToStdout);
    return processOutput(p, size_t.max);
}

unittest
{
    // To avoid printing the newline characters, we use the echo|set trick on
    // Windows, and printf on POSIX (neither echo -n nor echo \c are portable).
    version (Windows) TestScript prog =
       "echo|set /p=%1
        echo|set /p=%2 1>&2
        exit 123";
    else version (Posix) TestScript prog =
       `printf '%s' $1
        printf '%s' $2 >&2
        exit 123`;
    auto r = execute([prog.path, "foo", "bar"]);
    assert (r.status == 123);
    assert (r.output.stripRight() == "foobar");
    auto s = execute(prog.path, "Hello", "World");
    assert (s.status == 123);
    assert (s.output.stripRight() == "HelloWorld");
}


/**
Executes $(D _command) in the user's default _shell and returns its
exit code and output.

This function blocks until the command terminates.
The $(D output) string includes what the command writes to its
standard error stream as well as its standard output stream.
The path to the _command interpreter is given by $(LREF userShell).
---
auto ls = shell("ls -l");
writefln("ls exited with code %s and said: %s", ls.status, ls.output);
---

POSIX_specific:
If the process is terminated by a signal, the $(D status) field of
the return value will contain a negative number whose absolute
value is the signal number.  (See $(LREF wait) for details.)

Throws:
$(LREF ProcessException) on failure to start the process.$(BR)
$(XREF stdio,StdioException) on failure to capture output.
*/
Tuple!(int, "status", string, "output") shell(string command)
    @trusted //TODO: @safe
{
    auto p = pipeShell(command, Redirect.stdout | Redirect.stderrToStdout);
    return processOutput(p, size_t.max);
}

unittest
{
    auto r1 = shell("echo foo");
    assert (r1.status == 0);
    assert (r1.output.chomp() == "foo");
    auto r2 = shell("echo bar 1>&2");
    assert (r2.status == 0);
    assert (r2.output.chomp().stripRight() == "bar");
    auto r3 = shell("exit 123");
    assert (r3.status == 123);
    assert (r3.output.empty);
}

// Collects the output and exit code for execute() and shell().
private Tuple!(int, "status", string, "output") processOutput(
    ref ProcessPipes pp,
    size_t maxData)
{
    Appender!(ubyte[]) a;
    enum chunkSize = 4096;
    foreach (ubyte[] chunk; pp.stdout.byChunk(chunkSize))
    {
        a.put(chunk);
        if (a.data().length + chunkSize > maxData) break;
    }

    typeof(return) r;
    r.output = cast(string) a.data;
    r.status = wait(pp.pid);
    return r;
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
        import std.ascii, std.file, std.uuid;
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
        path = buildPath(tempDir(), randomUUID().toString()~ext);
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
        if (!path.empty && exists(path)) remove(path);
    }

    string path;
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
$(LREF pipeShell) or $(LREF shell).
---
string url = "http://dlang.org/";
shell(escapeShellCommand("wget", url, "-O", "dlang-index.html"));
---

Concatenate multiple $(D escapeShellCommand) and
$(LREF escapeShellFileName) results to use shell redirection or
piping operators.
---
shell(
    escapeShellCommand("curl", "http://dlang.org/download.html") ~
    "|" ~
    escapeShellCommand("grep", "-o", `http://\S*\.zip`) ~
    ">" ~
    escapeShellFileName("D download links.txt"));
---
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

string escapeWindowsShellCommand(in char[] command)
    //TODO: @safe pure nothrow (prevented by Appender)
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
$(LREF pipeShell) or $(LREF shell).
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

    If no such variable exists, this function throws an $(D Exception).
    See also $(LREF get), which doesn't throw on failure.
    ---
    auto path = environment["PATH"];
    ---
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

    Unlike $(LREF opIndex), this function never throws.
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
