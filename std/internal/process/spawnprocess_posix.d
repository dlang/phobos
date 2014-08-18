/*
POSIX implementation of std.process.spawnProcess().

This module is only meant to be used internally in Phobos. Its API is
subject to change without notice.  Please see std/process.d for author,
copyright and licence information.
*/
module std.internal.process.spawnprocess_posix;

import std.process: Config, Pid;
import std.stdio: File;

version (Posix):


Pid spawnProcessImpl(in char[][] args,
                     File stdin,
                     File stdout,
                     File stderr,
                     const string[string] env,
                     Config config,
                     in char[] workDir)
    @trusted // TODO: Should be @safe
{
    import core.exception, core.sys.posix.unistd,
           std.algorithm, std.conv, std.path, std.string;
    import core.stdc.stdio: fileno, perror;
    import std.process: ProcessException;

    if (args.length == 0) throw new RangeError();
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
            throw new ProcessException(text("Executable file not found: ", args[0]));
    }

    // Convert program name and arguments to C-style strings.
    auto argz = new const(char)*[args.length+1];
    argz[0] = toStringz(name);
    foreach (i; 1 .. args.length) argz[i] = toStringz(args[i]);
    argz[$-1] = null;

    // Prepare environment.
    auto envz = createEnv(env, !(config & Config.newEnv));

    // Open the working directory.
    // We use open in the parent and fchdir in the child
    // so that most errors (directory doesn't exist, not a directory)
    // can be propagated as exceptions before forking.
    int workDirFD = 0;
    scope(exit) if (workDirFD > 0) close(workDirFD);
    if (workDir)
    {
        import core.sys.posix.fcntl;
        workDirFD = open(toStringz(workDir), O_RDONLY);
        if (workDirFD < 0)
            throw ProcessException.newFromErrno("Failed to open working directory");
        stat_t s;
        if (fstat(workDirFD, &s) < 0)
            throw ProcessException.newFromErrno("Failed to stat working directory");
        if (!S_ISDIR(s.st_mode))
            throw new ProcessException("Not a directory: " ~ cast(string)workDir);
    }

    int getFD(ref File f) { return core.stdc.stdio.fileno(f.getFP()); }

    // Get the file descriptors of the streams.
    // These could potentially be invalid, but that is OK.  If so, later calls
    // to dup2() and close() will just silently fail without causing any harm.
    auto stdinFD  = getFD(stdin);
    auto stdoutFD = getFD(stdout);
    auto stderrFD = getFD(stderr);

    auto id = fork();
    if (id < 0)
        throw ProcessException.newFromErrno("Failed to spawn new process");
    if (id == 0)
    {
        // Child process

        // Set the working directory.
        if (workDirFD)
        {
            if (fchdir(workDirFD) < 0)
            {
                // Fail. It is dangerous to run a program
                // in an unexpected working directory.
                perror("spawnProcess(): Failed to set working directory");
                _exit(1);
                assert(0);
            }
            close(workDirFD);
        }

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
        if (!(config & Config.retainStdin ) && stdinFD  > STDERR_FILENO
                                            && stdinFD  != getFD(std.stdio.stdin ))
            stdin.close();
        if (!(config & Config.retainStdout) && stdoutFD > STDERR_FILENO
                                            && stdoutFD != getFD(std.stdio.stdout))
            stdout.close();
        if (!(config & Config.retainStderr) && stderrFD > STDERR_FILENO
                                            && stderrFD != getFD(std.stdio.stderr))
            stderr.close();
        return new Pid(id);
    }
}


private:

// Converts childEnv to a zero-terminated array of zero-terminated strings
// on the form "name=value", optionally adding those of the current process'
// environment strings that are not present in childEnv.  If the parent's
// environment should be inherited without modification, this function
// returns environ directly.
const(char*)* createEnv(const string[string] childEnv,
                        bool mergeWithParentEnv)
{
    import std.internal.process.environ;

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

unittest
{
    import std.internal.process.environ;
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


// Searches the PATH variable for the given executable file,
// (checking that it is in fact executable).
private string searchPathFor(in char[] executable)
    @trusted //TODO: @safe nothrow
{
    import core.stdc.stdlib, std.algorithm, std.conv, std.path;
    auto pathz = getenv("PATH");
    if (pathz == null)  return null;
    foreach (dir; splitter(to!string(pathz), ':'))
    {
        auto execPath = buildPath(dir, executable);
        if (isExecutable(execPath)) return execPath;
    }
    return null;
}

unittest
{
    import std.algorithm: endsWith;
    auto unamePath = searchPathFor("uname");
    assert (unamePath.length > 0);
    assert (unamePath[0] == '/');
    assert (unamePath.endsWith("uname"));
    auto unlikely = searchPathFor("lkmqwpoialhggyaofijadsohufoiqezm");
    assert (unlikely is null, "Are you kidding me?");
}


// Checks whether the file exists and can be executed by the
// current user.
private bool isExecutable(in char[] path) @trusted //TODO: @safe nothrow
{
    import core.sys.posix.unistd, std.string;
    return (access(toStringz(path), X_OK) == 0);
}


// Sets or unsets the FD_CLOEXEC flag on the given file descriptor.
private void setCLOEXEC(int fd, bool on)
{
    import core.stdc.errno, core.sys.posix.fcntl;
    auto flags = fcntl(fd, F_GETFD);
    if (flags >= 0)
    {
        if (on) flags |= FD_CLOEXEC;
        else    flags &= ~(cast(typeof(flags)) FD_CLOEXEC);
        flags = fcntl(fd, F_SETFD, flags);
    }
    assert (flags != -1 || errno == EBADF);
}
