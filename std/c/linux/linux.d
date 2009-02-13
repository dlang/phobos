
/* Written by Walter Bright, Christopher E. Miller, and many others.
 * http://www.digitalmars.com/d/
 * Placed into public domain.
 * Linux(R) is the registered trademark of Linus Torvalds in the U.S. and other
 * countries.
 */

module std.c.linux.linux;

public import std.c.linux.linuxextern;
public import std.c.linux.pthread;

private import std.c.stdio;

version (OSX)
{
    alias int time_t;
    alias int __time_t;
    alias int pid_t;
    alias long off_t;
    alias long blkcnt_t;
    alias int blksize_t;
    alias int dev_t;
    alias uint gid_t;
    alias uint id_t;
    alias ulong ino64_t;
    alias uint ino_t;
    alias ushort mode_t;
    alias ushort nlink_t;
    alias uint uid_t;
    alias uint fsblkcnt_t;
    alias uint fsfilcnt_t;

    struct timespec
    {
	time_t tv_sec;
	int tv_nsec;
    }
}

version (linux)
{
    alias int __time_t;
    alias int pid_t;
    alias int off_t;
    alias uint mode_t;

    alias uint uid_t;
    alias uint gid_t;

    struct timespec
    {
        __time_t tv_sec;    /* seconds   */
        int tv_nsec;        /* nanosecs. */
    }
}

static if (size_t.sizeof == 4)
    alias int ssize_t;
else
    alias long ssize_t;

version(linux)
{
    enum : int
    {
    	SIGHUP = 1,
    	SIGINT = 2,
    	SIGQUIT = 3,
    	SIGILL = 4,
    	SIGTRAP = 5,
    	SIGABRT = 6,
    	SIGIOT = 6,
    	SIGBUS = 7,
    	SIGFPE = 8,
    	SIGKILL = 9,
    	SIGUSR1 = 10,
    	SIGSEGV = 11,
    	SIGUSR2 = 12,
    	SIGPIPE = 13,
    	SIGALRM = 14,
    	SIGTERM = 15,
    	SIGSTKFLT = 16,
    	SIGCHLD = 17,
    	SIGCONT = 18,
    	SIGSTOP = 19,
    	SIGTSTP = 20,
    	SIGTTIN = 21,
    	SIGTTOU = 22,
    	SIGURG = 23,
    	SIGXCPU = 24,
    	SIGXFSZ = 25,
    	SIGVTALRM = 26,
    	SIGPROF = 27,
    	SIGWINCH = 28,
    	SIGPOLL = 29,
    	SIGIO = 29,
    	SIGPWR = 30,
    	SIGSYS = 31,
    	SIGUNUSED = 31,
    }
}

version(OSX)
{
    enum : int
    {
        SIGABRT   = 6,
        SIGALRM   = 14,
        SIGBUS    = 10,
        SIGCHLD   = 20,
        SIGCONT   = 19,
        SIGFPE    = 8,
        SIGHUP    = 1,
        SIGILL    = 4,
        SIGINT    = 2,
        SIGKILL   = 9,
        SIGPIPE   = 13,
        SIGQUIT   = 3,
        SIGSEGV   = 11,
        SIGSTOP   = 17,
        SIGTERM   = 15,
        SIGTSTP   = 18,
        SIGTTIN   = 21,
        SIGTTOU   = 22,
        SIGUSR1   = 30,
        SIGUSR2   = 31,
        SIGURG    = 16,
    }
}


version (linux)
{
enum
{
    O_RDONLY = 0,
    O_WRONLY = 1,
    O_RDWR = 2,
    O_CREAT = 0100,
    O_EXCL = 0200,
    O_TRUNC = 01000,
    O_APPEND = 02000,
    O_NONBLOCK = 0x800,
}
}

version (OSX)
{
enum
{
    O_RDONLY = 0,
    O_WRONLY = 1,
    O_RDWR = 2,

    O_CREAT = 0x200,
    O_EXCL  = 0x800,
    O_TRUNC = 0x400,
    O_APPEND = 8,
    O_NONBLOCK = 4,
    O_SYNC = 0x80,
    O_SHLOCK = 0x10,
    O_EXLOCK = 0x20,
    O_ASYNC = 0x40,
    O_NOFOLLOW = 0x100,
    O_EVTONLY = 0x8000,
    O_NOCTTY = 0x20000,
    O_DIRECTORY = 0x100000,
    O_SYMLINK   = 0x200000,
}
}

version (linux)
{
    struct struct_stat	// distinguish it from the stat() function
    {
	ulong st_dev;	/// device
	ushort __pad1;
	uint st_ino;	/// file serial number
	uint st_mode;	/// file mode
	uint st_nlink;	/// link count
	uint st_uid;	/// user ID of file's owner
	uint st_gid;	/// user ID of group's owner
	ulong st_rdev;	/// if device then device number
	ushort __pad2;
	int st_size;	/// file size in bytes
	int st_blksize;	/// optimal I/O block size
	int st_blocks;	/// number of allocated 512 byte blocks
	int st_atime;
	uint st_atimensec;
	int st_mtime;
	uint st_mtimensec;
	int st_ctime;
	uint st_ctimensec;

	uint __unused4;
	uint __unused5;
    }
}
version (OSX)
{
    struct struct_stat
    {
	dev_t st_dev;
	ino_t st_ino;
	mode_t st_mode;
	nlink_t st_nlink;
	uid_t st_uid;
	gid_t st_gid;
	dev_t st_rdev;
	timespec st_atimespec;
	timespec st_mtimespec;
	timespec st_ctimespec;
	off_t st_size;
	blkcnt_t st_blocks;
	blksize_t st_blksize;
	uint st_flags;
	uint st_gen;
	int st_lspare;
	long st_qspare[2];
    }
}

unittest
{
    version (linux) assert(struct_stat.sizeof == 88);
    version (OSX)   assert(struct_stat.sizeof == 96);
}

enum : int
{
    S_IFIFO  = 0010000,
    S_IFCHR  = 0020000,
    S_IFDIR  = 0040000,
    S_IFBLK  = 0060000,
    S_IFREG  = 0100000,
    S_IFLNK  = 0120000,
    S_IFSOCK = 0140000,

    S_IFMT   = 0170000,

    S_IREAD  = 0000400,
    S_IWRITE = 0000200,
    S_IEXEC  = 0000100,
}

extern (C)
{
    int access(in char*, int);
    int open(in char*, int, ...);
    int read(int, void*, int);
    int write(int, in void*, int);
    int close(int);
    int lseek(int, int, int);
    int fstat(int, struct_stat*);
    int lstat(in char*, struct_stat*);
    int stat(in char*, struct_stat*);
    int chdir(in char*);
    int mkdir(in char*, int);
    int rmdir(in char*);
    char* getcwd(char*, int);
    int chmod(in char*, mode_t);
    int fork();
    int dup(int);
    int dup2(int, int);
    int pipe(int[2]);
    pid_t wait(int*);
    int waitpid(pid_t, int*, int);

    uint alarm(uint);
    char* basename(char*);
    //wint_t btowc(int);
    int chown(in char*, uid_t, gid_t);
    int chroot(in char*);
    size_t confstr(int, char*, size_t);
    int creat(in char*, mode_t);
    char* ctermid(char*);
    int dirfd(DIR*);
    char* dirname(char*);
    int fattach(int, char*);
    int fchmod(int, mode_t);
    int fdatasync(int);
    int ffs(int);
    int fmtmsg(int, char*, int, char*, char*, char*);
    int fpathconf(int, int);
    int fseeko(FILE*, off_t, int);
    off_t ftello(FILE*);

    extern char** environ;
}

struct timeval
{
    int tv_sec;
    int tv_usec;
}

struct struct_timezone
{
    int tz_minuteswest;
    int tz_dstime;
}

struct tm
{
    int tm_sec;
    int tm_min;
    int tm_hour;
    int tm_mday;
    int tm_mon;
    int tm_year;
    int tm_wday;
    int tm_yday;
    int tm_isdst;
    int tm_gmtoff;
    int tm_zone;
}

extern (C)
{
    int gettimeofday(timeval*, struct_timezone*);
    int settimeofday(in timeval*, in struct_timezone*);
    __time_t time(__time_t*);
    char* asctime(in tm*);
    char* ctime(in __time_t*);
    tm* gmtime(in __time_t*);
    tm* localtime(in __time_t*);
    __time_t mktime(tm*);
    char* asctime_r(in tm* t, char* buf);
    char* ctime_r(in __time_t* timep, char* buf);
    tm* gmtime_r(in __time_t* timep, tm* result);
    tm* localtime_r(in __time_t* timep, tm* result);
}

/**************************************************************/
// Memory mapping from <sys/mman.h> and <bits/mman.h>

enum
{
	PROT_NONE	= 0,
	PROT_READ	= 1,
	PROT_WRITE	= 2,
	PROT_EXEC	= 4,
}

// Memory mapping sharing types

version (linux)
{
    enum
    {	MAP_SHARED	= 1,
	MAP_PRIVATE	= 2,
	MAP_TYPE	= 0x0F,
	MAP_FIXED	= 0x10,
	MAP_FILE	= 0,
	MAP_ANONYMOUS	= 0x20,
	MAP_ANON	= 0x20,
	MAP_GROWSDOWN	= 0x100,
	MAP_DENYWRITE	= 0x800,
	MAP_EXECUTABLE	= 0x1000,
	MAP_LOCKED	= 0x2000,
	MAP_NORESERVE	= 0x4000,
	MAP_POPULATE	= 0x8000,
	MAP_NONBLOCK	= 0x10000,
    }

    // Values for msync()

    enum
    {	MS_ASYNC	= 1,
	MS_INVALIDATE	= 2,
	MS_SYNC		= 4,
    }
}

version (OSX)
{
    enum
    {	MAP_SHARED	= 1,
	MAP_PRIVATE	= 2,
	MAP_FIXED	= 0x10,
	MAP_FILE	= 0,
	MAP_ANON	= 0x1000,
	MAP_NORESERVE	= 0x40,

	MAP_RENAME	= 0x20,
	MAP_RESERVED0080 = 0x80,
	MAP_NOEXTEND	= 0x100,
	MAP_HASSEMAPHORE = 0x200,
	MAP_NOCACHE	= 0x400,
    }

    // Values for msync()

    enum
    {	MS_ASYNC	= 1,
	MS_INVALIDATE	= 2,
	MS_SYNC		= 0x10,
    }
}

// Values for mlockall()

enum
{
	MCL_CURRENT	= 1,
	MCL_FUTURE	= 2,
}

// Values for mremap()

enum
{
	MREMAP_MAYMOVE	= 1,
}

// Values for madvise

enum
{	MADV_NORMAL	= 0,
	MADV_RANDOM	= 1,
	MADV_SEQUENTIAL	= 2,
	MADV_WILLNEED	= 3,
	MADV_DONTNEED	= 4,
}

extern (C)
{
void* mmap(void*, size_t, int, int, int, off_t);
const void* MAP_FAILED = cast(void*)-1;

int munmap(void*, size_t);
int mprotect(void*, size_t, int);
int msync(void*, size_t, int);
int madvise(void*, size_t, int);
int mlock(void*, size_t);
int munlock(void*, size_t);
int mlockall(int);
int munlockall();
void* mremap(void*, size_t, size_t, int);
int mincore(void*, size_t, ubyte*);
int remap_file_pages(void*, size_t, int, size_t, int);
int shm_open(in char*, int, int);
int shm_unlink(in char*);
}

extern(C)
{

    enum
    {
	DT_UNKNOWN = 0,
	DT_FIFO = 1,
	DT_CHR = 2,
	DT_DIR = 4,
	DT_BLK = 6,
	DT_REG = 8,
	DT_LNK = 10,
	DT_SOCK = 12,
	DT_WHT = 14,
    }

    struct dirent
    {
	uint d_ino;		// this is int on some linuxes
	off_t d_off;
	ushort d_reclen;
	ubyte d_type;		// this field isn't there on some linuxes
	char[256] d_name;
    }

    struct dirent64
    {
	ulong d_ino;
	long d_off;
	ushort d_reclen;
	ubyte d_type;
	char[256] d_name;
    }

    struct DIR
    {
	// Managed by OS.
    }
    
    DIR* opendir(in char* name);
    int closedir(DIR* dir);
    dirent* readdir(DIR* dir);
    void rewinddir(DIR* dir);
    off_t telldir(DIR* dir);
    void seekdir(DIR* dir, off_t offset);
}


extern(C)
{
	private import std.intrinsic;
	
	
	int select(int nfds, fd_set* readfds, fd_set* writefds, fd_set* errorfds, timeval* timeout);
	int fcntl(int s, int f, ...);
	
	
	enum
	{
		EINTR = 4,
		EINPROGRESS = 115,
	}
	
	
	const uint FD_SETSIZE = 1024;
	//const uint NFDBITS = 8 * int.sizeof; // DMD 0.110: 8 * (int).sizeof is not an expression
	const int NFDBITS = 32;
	
	
	struct fd_set
	{
		int[FD_SETSIZE / NFDBITS] fds_bits;
		alias fds_bits __fds_bits;
	}
	
	
	int FDELT(int d)
	{
		return d / NFDBITS;
	}
	
	
	int FDMASK(int d)
	{
		return 1 << (d % NFDBITS);
	}
	
	
	// Removes.
	void FD_CLR(int fd, fd_set* set)
	{
		btr(cast(uint*)&set.fds_bits.ptr[FDELT(fd)], cast(uint)(fd % NFDBITS));
	}
	
	
	// Tests.
	int FD_ISSET(int fd, fd_set* set)
	{
		return bt(cast(uint*)&set.fds_bits.ptr[FDELT(fd)], cast(uint)(fd % NFDBITS));
	}
	
	
	// Adds.
	void FD_SET(int fd, fd_set* set)
	{
		bts(cast(uint*)&set.fds_bits.ptr[FDELT(fd)], cast(uint)(fd % NFDBITS));
	}
	
	
	// Resets to zero.
	void FD_ZERO(fd_set* set)
	{
		set.fds_bits[] = 0;
	}
}

extern (C)
{
    /* From <dlfcn.h>
     * See http://www.opengroup.org/onlinepubs/007908799/xsh/dlsym.html
     */

    const int RTLD_NOW = 0x00002;	// Correct for Red Hat 8

    void* dlopen(in char* file, int mode);
    int   dlclose(void* handle);
    void* dlsym(void* handle, const(char)* name);
    char* dlerror();
}

extern (C)
{
    /* from <pwd.h>
     */

    struct passwd
    {
	char *pw_name;
	char *pw_passwd;
	uid_t pw_uid;
	gid_t pw_gid;
	char *pw_gecos;
	char *pw_dir;
	char *pw_shell;
    }

    int getpwnam_r(const(char)*, passwd*, void*, size_t, passwd**);
    passwd* getpwnam(in char*);
    passwd* getpwuid(uid_t);
    int getpwuid_r(uid_t, passwd*, char*, size_t, passwd**);
    int kill(pid_t, int);
    int sem_close(sem_t*);
}

extern (C)
{
    /* from sched.h
     */
    int sched_yield();
}

extern (C)
{
    /* from signal.h
     */
    version (linux)
    {
	extern (C) alias void (*__sighandler_t)(int);

	const SA_RESTART = 0x10000000u;

	enum _SIGSET_NWORDS = 1024 / (8 * uint.sizeof);

	struct sigset_t
	{
	    uint[_SIGSET_NWORDS] __val;
	}

	struct sigaction_t
	{
	    __sighandler_t sa_handler;
	    sigset_t sa_mask;
	    int sa_flags;
	    void (*sa_restorer)();
	}

        int sigfillset(sigset_t*);
        int sigdelset(sigset_t*, int);
        int sigismember(sigset_t*, int);
        int sigaction(int, sigaction_t*, sigaction_t*);
        int sigsuspend(sigset_t*);
    }
}

extern (C)
{
    /* from semaphore.h
     */

  version (OSX)
  {
    alias int sem_t;
  }
  else version (linux)
  {
    struct sem_t
    {
        _pthread_fastlock __sem_lock;
        int __sem_value;
        void* __sem_waiting;
    }
  }
  else
  {
    static assert(0);
  }
    int sem_init(sem_t*, int, uint);
    int sem_wait(sem_t*);
    int sem_trywait(sem_t*);
    int sem_post(sem_t*);
    int sem_getvalue(sem_t*, int*);
    int sem_destroy(sem_t*);
}

extern (C)
{
    /* from utime.h
     */

    struct utimbuf
    {
	__time_t actime;
	__time_t modtime;
    }

    int utime(const char* filename, utimbuf* buf);
}
