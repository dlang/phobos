
/**
 * C's &lt;stdio.h&gt; for the D programming language
 * Authors: Walter Bright, Digital Mars, http://www.digitalmars.com
 * License: Public Domain
 * Macros:
 *      WIKI=Phobos/StdCStdio
 */



module std.c.stdio;

public import core.stdc.stdio;

extern (C):

version (Win32)
{
    import core.sys.windows.windows;

    enum
    {
        FHND_APPEND     = 0x04,
        FHND_DEVICE     = 0x08,
        FHND_TEXT       = 0x10,
        FHND_BYTE       = 0x20,
        FHND_WCHAR      = 0x40,
    }

    private enum _MAX_SEMAPHORES = 10 + _NFILE;
    private enum _semIO = 3;
    private extern __gshared short _iSemLockCtrs[_MAX_SEMAPHORES];
    private extern __gshared int _iSemThreadIds[_MAX_SEMAPHORES];
    private extern __gshared int _iSemNestCount[_MAX_SEMAPHORES];
    private extern __gshared HANDLE[_NFILE] _osfhnd;
    private extern __gshared ubyte[_NFILE] __fhnd_info;

    void _WaitSemaphore(int iSemaphore);
    void _ReleaseSemaphore(int iSemaphore);

    // this is copied from semlock.h in DMC's runtime.
    void LockSemaphore(uint num)
    {
        asm {
            mov EDX, num;
            lock;
            inc _iSemLockCtrs[EDX * 2];
            jz lsDone;
            push EDX;
            call _WaitSemaphore;
            add ESP, 4;
        }
lsDone: ;
    }

    void UnlockSemaphore(uint num)
    {
        asm {
            mov EDX, num;
            lock;
            dec _iSemLockCtrs[EDX * 2];
            js usDone;
            push EDX;
            call _ReleaseSemaphore;
            add ESP, 4;
        }
usDone: ;
    }

    // This converts a HANDLE to a file descriptor in DMC's runtime (TODO:
    // move this to druntime)
    int _handleToFD(HANDLE h, int flags)
    {
        LockSemaphore(_semIO);
        scope(exit) UnlockSemaphore(_semIO);
        for(int fd = 0; fd < _NFILE; fd++)
        {
            if(!_osfhnd[fd])
            {
                _osfhnd[fd] = h;
                __fhnd_info[fd] = cast(ubyte)flags;
                return fd;
            }
        }
        return -1;
    }

    HANDLE _fdToHandle(int fd)
    {
        // no semaphore is required, once inserted, a file descriptor
        // doesn't change.
        if(fd < 0 || fd >= _NFILE)
        {
            return null;
        }
        return _osfhnd[fd];
    }

    enum
    {
        O_RDONLY = 0,
        O_WRONLY = 1,
        O_RDWR   = 2,
        O_APPEND = 8,
        O_CREAT  = 0x100,
        O_TRUNC  = 0x200,
        O_EXCL   = 0x400
    };

    enum
    {
        S_IREAD = 0x0100,
        S_IWRITE = 0x0080
    }

    enum
    {
        STDIN_FILENO  = 0,
        STDOUT_FILENO = 1,
        STDERR_FILENO = 2
    }

    // include definitions for common functions
    int open(const char * filename, int flags, ...);
    int close(int fd);
    FILE *fdopen(int fd, const char *flags);
}
