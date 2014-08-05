/*
Windows implementation of std.process.spawnProcess().

This module is only meant to be used internally in Phobos. Its API is
subject to change without notice.  Please see std/process.d for author,
copyright and licence information.
*/
module std.internal.process.spawnprocess_windows;

import std.process: Config, Pid;
import std.stdio: File;

version (Windows):


version (Win32) version (DigitalMars) version = DMC_RUNTIME;
version (DMC_RUNTIME) { } else
{
    enum
    {
        STDIN_FILENO  = 0,
        STDOUT_FILENO = 1,
        STDERR_FILENO = 2,
    }
}


/*
commandLine must contain the entire command line, properly
quoted/escaped as required by CreateProcessW().
*/
version (Windows)
private Pid spawnProcessImpl(in char[] commandLine,
                             File stdin,
                             File stdout,
                             File stderr,
                             const string[string] env,
                             Config config,
                             in char[] workDir)
    @trusted
{
    import core.exception, core.sys.windows.windows;
    import std.stdio, std.utf;
    import std.windows.syserror;

    if (commandLine.length == 0) throw new RangeError("Command line is empty");
    auto commandz = toUTFz!(wchar*)(commandLine);
    auto workDirz = workDir is null ? null : toUTFz!(wchar*)(workDir);

    // Prepare environment.
    auto envz = createEnv(env, !(config & Config.newEnv));

    // Startup info for CreateProcessW().
    STARTUPINFO_W startinfo;
    startinfo.cb = startinfo.sizeof;
    startinfo.dwFlags = STARTF_USESTDHANDLES;

    static int getFD(ref File f) { return f.isOpen ? f.fileno() : -1; }

    // Extract file descriptors and HANDLEs from the streams and make the
    // handles inheritable.
    static void prepareStream(ref File file, DWORD stdHandle, string which,
                              out int fileDescriptor, out HANDLE handle)
    {
        fileDescriptor = getFD(file);
        if (fileDescriptor < 0)   handle = GetStdHandle(stdHandle);
        else                      handle = file.windowsHandle;

        DWORD dwFlags;
        if (GetHandleInformation(handle, &dwFlags))
        {
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
                        envz, workDirz, &startinfo, &pi))
        throw ProcessException.newFromLastError("Failed to spawn new process");

    // figure out if we should close any of the streams
    if (!(config & Config.retainStdin ) && stdinFD  > STDERR_FILENO
                                        && stdinFD  != getFD(std.stdio.stdin ))
        stdin.close();
    if (!(config & Config.retainStdout) && stdoutFD > STDERR_FILENO
                                        && stdoutFD != getFD(std.stdio.stdout))
        stdout.close();
    if (!(config & Config.retainStderr) && stderrFD > STDERR_FILENO
                                        && stderrFD != getFD(std.stdio.stderr))
        stderr.close();

    // close the thread handle in the process info structure
    CloseHandle(pi.hThread);

    return new Pid(pi.dwProcessId, pi.hProcess);
}


private:

import core.sys.windows.windows: LPVOID;

// Converts childEnv to a Windows environment block, which is on the form
// "name1=value1\0name2=value2\0...nameN=valueN\0\0", optionally adding
// those of the current process' environment strings that are not present
// in childEnv.  Returns null if the parent's environment should be
// inherited without modification, as this is what is expected by
// CreateProcess().
LPVOID createEnv(const string[string] childEnv,
                 bool mergeWithParentEnv)
{
    import std.array: appender;
    import std.string: toUpper;
    import std.process: environment;

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

unittest
{
    assert (createEnv(null, true) == null);
    assert ((cast(wchar*) createEnv(null, false))[0 .. 2] == "\0\0"w);
    auto e1 = (cast(wchar*) createEnv(["foo":"bar", "ab":"c"], false))[0 .. 14];
    assert (e1 == "FOO=bar\0AB=c\0\0"w || e1 == "AB=c\0FOO=bar\0\0"w);
}
