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
    spawn processes are built around $(LREF spawnProcess).)
$(LI
    $(LREF wait) makes the parent _process wait for a child _process to
    terminate.  In general one should always do this, to avoid
    child _processes becoming "zombies" when the parent _process exits.
    Scope guards are perfect for this – see the $(LREF spawnProcess)
    documentation for examples.)
$(LI
    $(LREF pipeProcess) and $(LREF pipeShell) also spawn a child _process
    which runs in parallel with its parent.  However, instead of taking
    arbitrary streams, they automatically create a set of
    pipes that allow the parent to communicate with the child
    through the child's standard input, output, and/or error streams.
    These functions correspond roughly to C's $(D popen) function.)
$(LI
    $(LREF execute) and $(LREF shell) start a new _process and wait for it
    to complete before returning.  Additionally, they capture
    the _process' standard output and error streams and return
    the output of these as a string.
    These correspond roughly to C's $(D system) function.)
)
$(LREF shell) and $(LREF pipeShell) both run the given command
through the user's default command interpreter.  On Windows, this is
the $(I cmd.exe) program, on POSIX it is determined by the SHELL environment
variable (defaulting to $(I /bin/sh) if it cannot be determined).  The
command is specified as a single string which is sent directly to the
shell.

The other commands all have two forms, one where the program name
and its arguments are specified in a single string parameter, separated
by spaces, and one where the arguments are specified as an array of
strings.  Use the latter whenever the program name or any of the arguments
contain spaces.

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
    $(LINK2 https://github.com/schveiguy, Steven Schveighoffer)
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
    extern(Windows) BOOL SetHandleInformation(HANDLE hObject,
                                              DWORD dwMask,
                                              DWORD dwFlags);
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


/// A handle that corresponds to a spawned process.
final class Pid
{
    /**
    The ID number assigned to the process by the operating
    system.
    */
    @property int processID() const @safe pure
    {
        assert(_processID >= 0);
        return _processID;
    }

    // See module-level wait() for documentation.
    version (Posix)
    int wait() @trusted
    {
        if (_processID == terminated) return _exitCode;
        int exitCode;
        while(true)
        {
            int status;
            auto check = waitpid(processID, &status, 0);
            if (check == -1  &&  errno == ECHILD)
            {
                throw new ProcessException(
                    "Process does not exist or is not a child process.");
            }
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
            // Process has stopped, but not terminated, so we continue waiting.
        }
        // Mark Pid as terminated, and cache and return exit code.
        _processID = terminated;
        _exitCode = exitCode;
        return exitCode;
    }
    else version (Windows)
    {
        int wait() @trusted
        {
            if (_processID == terminated) return _exitCode;
            if(_handle != INVALID_HANDLE_VALUE)
            {
                auto result = WaitForSingleObject(_handle, INFINITE);
                if (result != WAIT_OBJECT_0)
                    throw ProcessException.newFromLastError("Wait failed.");
                // the process has exited, get the return code
                if (!GetExitCodeProcess(_handle, cast(LPDWORD)&_exitCode))
                    throw ProcessException.newFromLastError();
                CloseHandle(_handle);
                _handle = INVALID_HANDLE_VALUE;
                _processID = terminated;
            }
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

private:
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
Spawns a new _process, optionally assigning it an
arbitrary set of standard input, output, and error streams.
The function returns immediately, leaving the child _process to execute
in parallel with its parent.

Unless a directory is specified in the $(D _command) (or $(D name))
parameter, this function will search the directories in the
PATH environment variable for the program.  To run an executable in
the current directory, use $(D "./$(I executable_name)").

Note that if you pass an $(XREF stdio,File) object that is $(I not)
one of the standard input/output/error streams of the parent process,
that stream will by default be closed in the parent process when this
function returns.  See the $(LREF Config) documentation below for
information about how to disable this behaviour.

Beware of buffering issues when passing $(XREF stdio,File) objects to
$(D spawnProcess).  The child process will inherit the low-level raw
read/write offset associated with the underlying file descriptor, but
it will not be aware of any buffered data.  In cases where this matters
(e.g. when a file should be aligned before being passed on to the
child process), it may be a good idea to use unbuffered streams (or at
least ensure all relevant buffers are flushed).

Params:
command = A string that contains the program name and any _command-line
    arguments, separated by spaces.  If the program name or any
    of the arguments themselves contain spaces, use the third or
    fourth form of this function, where they are specified as
    separate elements in an array.
environmentVars = The environment variables for the child process may
    be specified using this parameter.  If it is omitted, the child
    process inherits the environment of the parent process.
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
name = The name or path of the executable file.
args = The _command-line arguments to give to the program.
    (There is no need to specify the program name as the
    zeroth argument; this is done automatically.)

Returns:
A $(LREF Pid) object that corresponds to the spawned process.

Throws:
$(LREF ProcessException) on failure to start the process.$(BR)
$(XREF stdio,StdioException) on failure to pass one of the streams
    to the child process (Windows only).

Examples:
Open Firefox on the D homepage and wait for it to complete:
---
auto pid = spawnProcess("firefox http://www.dlang.org");
wait(pid);
---
Use the $(I ls) _command to retrieve a list of files:
---
string[] files;
auto p = pipe();

auto pid = spawnProcess("ls", stdin, p.writeEnd);
scope(exit) wait(pid);

foreach (f; p.readEnd.byLine())  files ~= f.idup;
---
Use the $(I ls -l) _command to get a list of files, pipe the output
to $(I grep) and let it filter out all files except D source files,
and write the output to the file $(I dfiles.txt):
---
// Let's emulate the command "ls -l | grep '\.d$' > dfiles.txt"
auto p = pipe();
auto file = File("dfiles.txt", "w");

auto lsPid = spawnProcess("ls -l", stdin, p.writeEnd);
scope(exit) wait(lsPid);

auto grPid = spawnProcess(`grep '\.d$'`, p.readEnd, file);
scope(exit) wait(grPid);
---
Open a set of files in LibreOffice Writer, and make it print
any error messages to the standard output stream.  Note that since
the filenames contain spaces, we have to pass them in an array:
---
spawnProcess("lowriter", ["my document.odt", "your document.odt"],
             stdin, stdout, stdout);
---
*/
Pid spawnProcess(
    string command,
    File stdin_ = std.stdio.stdin,
    File stdout_ = std.stdio.stdout,
    File stderr_ = std.stdio.stderr,
    Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    auto splitCmd = split(command);
    return spawnProcess(splitCmd[0], splitCmd[1 .. $],
                        stdin_, stdout_, stderr_, config);
}

/// ditto
Pid spawnProcess(
    string command,
    const ref string[string] environmentVars,
    File stdin_ = std.stdio.stdin,
    File stdout_ = std.stdio.stdout,
    File stderr_ = std.stdio.stderr,
    Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    auto splitCmd = split(command);
    return spawnProcess(splitCmd[0], splitCmd[1 .. $], environmentVars,
                        stdin_, stdout_, stderr_, config);
}

/// ditto
Pid spawnProcess(
    string name,
    const string[] args,
    File stdin_ = std.stdio.stdin,
    File stdout_ = std.stdio.stdout,
    File stderr_ = std.stdio.stderr,
    Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    version (Windows)
        return spawnProcessWindows(name, args, null,
                                   stdin_, stdout_, stderr_, config);
    else version (Posix)
        return spawnProcessPosix(name, args, environ,
                                 stdin_, stdout_, stderr_, config);
}

/// ditto
Pid spawnProcess(
    string name,
    const string[] args,
    const ref string[string] environmentVars,
    File stdin_ = std.stdio.stdin,
    File stdout_ = std.stdio.stdout,
    File stderr_ = std.stdio.stderr,
    Config config = Config.none)
    @trusted // TODO: Should be @safe
{
    version (Windows)
        return spawnProcessWindows(name, args, toWindowsEnv(environmentVars),
                                   stdin_, stdout_, stderr_, config);
    else version (Posix)
        return spawnProcessPosix(name, args, toPosixEnv(environmentVars),
                                 stdin_, stdout_, stderr_, config);
}

// Implementation of spawnProcess for POSIX.
version (Posix)
private Pid spawnProcessPosix(string name,
                              const string[] args,
                              const char** envz,
                              File stdin_,
                              File stdout_,
                              File stderr_,
                              Config config)
    @trusted // TODO: Should be @safe
{
    if (any!isDirSeparator(name))
    {
        if (!isExecutable(name))
            throw new ProcessException("Not an executable file: "~name);
    }
    else
    {
        name = searchPathFor(name);
        if (name is null)
            throw new ProcessException("Executable file not found: "~name);
    }

    auto namez = toStringz(name);
    auto argz = toArgz(name, args);

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
        execve(namez, argz, envz);

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

version (Windows)
private Pid spawnProcessWindows(string name,
                                const string[] args,
                                LPVOID envz,
                                File stdin_,
                                File stdout_,
                                File stderr_,
                                Config config)
                                @trusted
{
    // Windows is a little strange when passing command line.  It requires the
    // command-line to be one single command line, and the quoting processing
    // is rather bizzare.  Through trial and error, here are the rules I've
    // discovered that Windows uses to parse the command line WRT quotes:
    //
    // inside or outside quote mode:
    // 1. if 2 or more backslashes are followed by a quote, the first
    //    2 backslashes are reduced to 1 backslash which does not
    //    affect anything after it.
    // 2. one backslash followed by a quote is interpreted as a
    //    literal quote, which cannot be used to close quote mode, and
    //    does not affect anything after it.
    //
    // outside quote mode:
    // 3. a quote enters quote mode
    // 4. whitespace delineates an argument
    //
    // inside quote mode:
    // 5. 2 quotes sequentially are interpreted as a literal quote and
    //    an exit from quote mode.
    // 6. a quote at the end of the string, or one that is followed by
    //    anything other than a quote exits quote mode, but does not
    //    affect the character after the quote.
    // 7. end of line exits quote mode
    //
    // In our 'reverse' routine, we will only utilize the first 2 rules
    // for escapes.
    //
    wchar[] cmdline;

    // reserve enough space to hold the program and all the arguments, plus 3
    // extra characters per arg for the quotes and the space, plus 5 extra
    // chars for good measure (in case we have to add escaped quotes).
    uint minsize = 0;
    foreach(s; args) minsize += s.length;
    cmdline.reserve(minsize + name.length + 3 * args.length + 5);

    // this could be written more optimized...
    void addArg(string a)
    {
        if(cmdline.length)
            cmdline ~= " ";
        // first, determine if we need a quote
        bool needquote = false;
        foreach(dchar d; a)
            if(d == ' ')
            {
                needquote = true;
                break;
            }
        if(needquote)
            cmdline ~= '"';
        foreach(dchar d; a)
        {
            if(d == '"')
                cmdline ~= '\\';
            cmdline ~= d;
        }
        if(needquote)
            cmdline ~= '"';
    }
    addArg(name);
    foreach(a; args)
        addArg(a);
    cmdline ~= '\0';

    // ok, the command line is ready.  Figure out the startup info
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
        if (!SetHandleInformation(handle, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT))
        {
            throw new StdioException(
                "Failed to pass "~which~" stream to child process", 0);
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
    if (!CreateProcessW(null, cmdline.ptr, null, null, true, dwCreationFlags,
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
private string searchPathFor(string executable)
    @trusted //TODO: @safe nothrow
{
    auto pathz = environment["PATH"];
    if (pathz == null)  return null;

    foreach (dir; splitter(to!string(pathz), ':'))
    {
        auto execPath = buildPath(dir, executable);
        if (isExecutable(execPath))  return execPath;
    }

    return null;
}

// Converts a string[] array to a C array of C strings,
// setting the program name as the zeroth element.
version (Posix)
private const(char)** toArgz(string prog, const string[] args)
    @trusted nothrow //TODO: @safe
{
    alias const(char)* stringz_t;
    auto argz = new stringz_t[](args.length+2);

    argz[0] = toStringz(prog);
    foreach (i; 0 .. args.length)
    {
        argz[i+1] = toStringz(args[i]);
    }
    argz[$-1] = null;
    return argz.ptr;
}

// Converts a string[string] array to a C array of C strings
// on the form "key=value".
version (Posix)
private const(char)** toPosixEnv(const ref string[string] env)
    @trusted //TODO: @safe pure nothrow
{
    alias const(char)* stringz_t;
    auto envz = new stringz_t[](env.length+1);
    int i = 0;
    foreach (k, v; env)
    {
        envz[i] = (k~'='~v~'\0').ptr;
        i++;
    }
    envz[$-1] = null;
    return envz.ptr;
}

// Converts a string[string] array to a block of 16-bit
// characters on the form "key=value\0key=value\0...\0\0"
version (Windows)
private LPVOID toWindowsEnv(const ref string[string] env)
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
private bool isExecutable(string path) @trusted //TODO: @safe nothrow
{
    return (access(toStringz(path), X_OK) == 0);
}

unittest
{
    TestScript prog1 = "exit 0";
    assert (wait(spawnProcess(prog1.path)) == 0);

    TestScript prog2 = "exit 123";
    auto pid2 = spawnProcess(prog2.path);
    assert (wait(pid2) == 123);
    assert (wait(pid2) == 123);

    version (Windows) TestScript prog3 =
       "if not -%1-==-foo- ( exit 1 )
        if not -%2-==-bar- ( exit 1 )
        exit 0";
    else version (Posix) TestScript prog3 =
       `if test "$1" != "foo"; then exit 1; fi
        if test "$2" != "bar"; then exit 1; fi
        exit 0`;
    assert (wait(spawnProcess(prog3.path, ["foo", "bar"])) == 0);
    assert (wait(spawnProcess(prog3.path~" foo bar")) == 0);
    assert (wait(spawnProcess(prog3.path)) == 1);

    version (Windows) TestScript prog4 =
       "if %hello%==world ( exit 0 )
        exit 1";
    version (Posix) TestScript prog4 =
       "if test $hello = world; then exit 0; fi
        exit 1";
    auto env = [ "hello" : "world" ];
    assert (wait(spawnProcess(prog4.path, null, env)) == 0);
    assert (wait(spawnProcess(prog4.path, env)) == 0);

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
    auto pid5 = spawnProcess(prog5.path, ["foo", "bar" ],
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
    auto pid6 = spawnProcess(prog5.path, ["bar", "baz" ], file6i, file6o, file6e);
    wait(pid6);
    assert (readText(path6o).chomp() == "INPUT output bar");
    assert (readText(path6e).chomp().stripRight() == "INPUT error baz");
    remove(path6i);
    remove(path6o);
    remove(path6e);
}

version (Posix) unittest
{
    // Termination by signal.
    import core.sys.posix.signal;
    TestScript prog = "while true; do; done"; // Infinite loop
    auto pid = spawnProcess(prog.path);
    kill(pid.processID, SIGTERM);
    assert (wait(pid) == -SIGTERM);
}


/**
Flags that control the behaviour of $(LREF spawnProcess).
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
    On Windows, this option causes the process to run in
    a console window.  On POSIX it has no effect.
    */
    gui = 8,
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
*/
int wait(Pid pid) @safe
{
    assert(pid !is null, "Called wait on a null Pid.");
    return pid.wait();
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
the child, while the parent uses the other end.  See the
$(LREF spawnProcess) documentation for examples.
See also $(LREF pipeProcess) and $(LREF pipeShell) for an easy
way of doing this.

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
$(LREF pipeShell) invokes the user's _command interpreter
to execute the given program or _command.

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
auto pipes = pipeProcess("my_application");

// Store lines of output.
string[] output;
foreach (line; pipes.stdout.byLine) output ~= line.idup;

// Store lines of errors.
string[] errors;
foreach (line; pipes.stderr.byLine) errors ~= line.idup;
---
*/
ProcessPipes pipeProcess(string command,
                         Redirect redirectFlags = Redirect.all)
    @safe
{
    auto splitCmd = split(command);
    return pipeProcess(splitCmd[0], splitCmd[1 .. $], redirectFlags);
}

/// ditto
ProcessPipes pipeProcess(string name,
                         string[] args,
                         Redirect redirectFlags = Redirect.all)
    @trusted //TODO: @safe
{
    File stdinFile, stdoutFile, stderrFile;

    ProcessPipes pipes;
    pipes._redirectFlags = redirectFlags;

    if (redirectFlags & Redirect.stdin)
    {
        auto p = pipe();
        stdinFile = p.readEnd;
        pipes._stdin = p.writeEnd;
    }
    else
    {
        stdinFile = std.stdio.stdin;
    }

    if (redirectFlags & Redirect.stdout)
    {
        if ((redirectFlags & Redirect.stdoutToStderr) != 0)
            throw new Error("Invalid combination of options: Redirect.stdout | "
                            ~"Redirect.stdoutToStderr");
        auto p = pipe();
        stdoutFile = p.writeEnd;
        pipes._stdout = p.readEnd;
    }
    else
    {
        stdoutFile = std.stdio.stdout;
    }

    if (redirectFlags & Redirect.stderr)
    {
        if ((redirectFlags & Redirect.stderrToStdout) != 0)
            throw new Error("Invalid combination of options: Redirect.stderr | "
                            ~"Redirect.stderrToStdout");
        auto p = pipe();
        stderrFile = p.writeEnd;
        pipes._stderr = p.readEnd;
    }
    else
    {
        stderrFile = std.stdio.stderr;
    }

    if (redirectFlags & Redirect.stdoutToStderr)
    {
        if (redirectFlags & Redirect.stderrToStdout)
        {
            // We know that neither of the other options have been
            // set, so we assign the std.stdio.std* streams directly.
            stdoutFile = std.stdio.stderr;
            stderrFile = std.stdio.stdout;
        }
        else
        {
            stdoutFile = stderrFile;
        }
    }
    else if (redirectFlags & Redirect.stderrToStdout)
    {
        stderrFile = stdoutFile;
    }

    pipes._pid = spawnProcess(name, args, stdinFile, stdoutFile, stderrFile);
    return pipes;
}

/// ditto
ProcessPipes pipeShell(string command, Redirect redirectFlags = Redirect.all)
    @safe
{
    return pipeProcess(getShell(), [shellSwitch, command], redirectFlags);
}


/**
Flags that can be passed to $(LREF pipeProcess) and $(LREF pipeShell)
to specify which of the child process' standard streams are redirected.
Use bitwise OR to combine flags.
*/
enum Redirect
{
    none = 0,

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
    auto pp = pipeProcess(prog.path, ["bar", "baz"]);
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

    pp = pipeProcess(prog.path, ["12345", "67890"],
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
Tuple!(int, "status", string, "output") execute(string command)
    @trusted //TODO: @safe
{
    auto p = pipeProcess(command,
                         Redirect.stdout | Redirect.stderrToStdout);

    Appender!(ubyte[]) a;
    foreach (ubyte[] chunk; p.stdout.byChunk(4096))  a.put(chunk);

    typeof(return) r;
    r.output = cast(string) a.data;
    r.status = wait(p.pid);
    return r;
}

/// ditto
Tuple!(int, "status", string, "output") execute(string name, string[] args...)
    @trusted //TODO: @safe
{
    auto p = pipeProcess(name, args,
                         Redirect.stdout | Redirect.stderrToStdout);

    Appender!(ubyte[]) a;
    foreach (ubyte[] chunk; p.stdout.byChunk(4096))  a.put(chunk);

    typeof(return) r;
    r.output = cast(string) a.data;
    r.status = wait(p.pid);
    return r;
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
    auto r = execute(prog.path~" foo bar");
    assert (r.status == 123);
    assert (r.output.stripRight() == "foobar");
    auto s = execute(prog.path, "Hello", "World");
    assert (s.status == 123);
    assert (s.output.stripRight() == "HelloWorld");
}


// A command-line switch that indicates to the shell that it should
// interpret the following argument as a command to be executed.
version (Posix)   private immutable string shellSwitch = "-c";
version (Windows) private immutable string shellSwitch = "/C";

// Gets the user's default shell.
private string getShell() @safe //TODO: nothrow
{
    version (Windows)    return "cmd.exe";
    else version (Posix) return environment.get("SHELL", "/bin/sh");
}


/**
Executes $(D _command) in the user's default _shell and returns its
exit code and output.

This function blocks until the command terminates.
The $(D output) string includes what the command writes to its
standard error stream as well as its standard output stream.
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
    version (Windows)
        return execute(getShell() ~ " " ~ shellSwitch ~ " " ~ command);
    else version (Posix)
        return execute(getShell(), shellSwitch, command);
    else assert(0);
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
    auto userShell = environment.get("SHELL", "/bin/sh");
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
        version (Windows) if (n.length == 0 || v.length == 0) continue;

        assert (v == environment[n]);
    }
}
