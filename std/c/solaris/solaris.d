
/* Written by Walter Bright, Christopher E. Miller, and many others.
 * http://www.digitalmars.com/d/
 * Placed into public domain.
 * Solaris(R) is the registered trademark of Sun Microsystems, Inc. in the U.S. and other
 * countries.
 */

module std.c.solaris.solaris;

version (Solaris) { } else { static assert(0); }

public import std.c.solaris.pthread;

private import std.c.stdio;

// Many of these are different sizes on 64-bit.
alias int __time_t;
alias int pid_t;
alias int off_t;
alias uint mode_t;
alias int clockid_t;

alias uint uid_t;
alias uint gid_t;

struct timespec
{
   __time_t tv_sec;    /* seconds   */
   int tv_nsec;        /* nanosecs. */
}

static if (size_t.sizeof == 4)
    alias int ssize_t;
else
    alias long ssize_t;

enum : int
{
    SIGHUP = 1,
    SIGINT = 2,
    SIGQUIT = 3,
    SIGILL = 4,
    SIGTRAP = 5,
    SIGABRT = 6,
    SIGIOT = 6,
    SIGEMT = 7,
    SIGFPE = 8,
    SIGKILL = 9,
    SIGBUS = 10,
    SIGSEGV = 11,
    SIGSYS = 12,
    SIGPIPE = 13,
    SIGALRM = 14,
    SIGTERM = 15,
    SIGUSR1 = 16,
    SIGUSR2 = 17,
    SIGCLD = 18,
    SIGCHLD = 18,
    SIGPWR = 19,
    SIGWINCH = 20,
    SIGURG = 21,
    SIGPOLL = 22,
    SIGIO = 22,
    SIGSTOP = 23,
    SIGTSTP = 24,
    SIGCONT = 25,
    SIGTTIN = 26,
    SIGTTOU = 27,
    SIGVTALRM = 28,
    SIGPROF = 29,
    SIGXCPU = 30,
    SIGXFSZ = 31,
    SIGWAITING = 32,
    SIGLWP = 33,
    SIGFREEZE = 34,
    SIGTHAW = 35,
    SIGCANCEL = 36,
    SIGLOST = 37,
    SIGXRES = 38,
    SIGJVM1 = 39,
    SIGJVM2 = 40,
}

enum
{
    O_RDONLY = 0,
    O_WRONLY = 1,
    O_RDWR = 2,
    O_CREAT = 0x100,
    O_EXCL = 0x400,
    O_TRUNC = 0x200,
    O_APPEND = 0x08,
    O_NONBLOCK = 0x80,
    O_NDELAY = 0x04,
    O_SYNC = 0x10,
    O_DSYNC = 0x40,
    O_RSYNC = 0x8000,
    O_NOCTTY = 0x800,
    O_XATTR = 0x4000,
    O_NOFOLLOW = 0x20000,
    O_NOLINKS = 0x40000,
}

struct struct_stat	// distinguish it from the stat() function
{
    ulong st_dev;	/// device
    ulong st_ino;	/// file serial number
    uint st_mode;	/// file mode
    uint st_nlink;	/// link count
    uint st_uid;	/// user ID of file's owner
    uint st_gid;	/// user ID of group's owner
    ulong st_rdev;	/// if device then device number
    int st_size;	/// file size in bytes
    int st_atime;
    int st_atimensec;
    int st_mtime;
    int st_mtimensec;
    int st_ctime;
    int st_ctimensec;
    int st_blksize;	/// optimal I/O block size
    long st_blocks;	/// number of allocated 512 byte blocks

    char[16] st_fstype;
}

unittest
{
    version (Solaris) assert(struct_stat.sizeof == 136);
}

enum : int
{
    S_IFMT   = 0xF000,
    S_IAMB   = 0x1FF,

    S_IFIFO  = 0x1000,
    S_IFCHR  = 0x2000,
    S_IFDIR  = 0x4000,
    S_IFBLK  = 0x6000,
    S_IFREG  = 0x8000,
    S_IFLNK  = 0xA000,
    S_IFSOCK = 0xC000,

    S_IFDOOR = 0xD000,
    S_IFPORT = 0xE000,
    S_ISUID  = 0x800,
    S_ISGID  = 0x400,
    S_ISVTX  = 0x200,

    S_IREAD  = 00400,
    S_IWRITE = 00200,
    S_IEXEC  = 00100,
}

extern (C)
{
    int access(in char*, int);
    int open(in char*, int, ...);
    int read(int, void*, int);
    int write(int, in void*, int);
    int close(int);
    int lseek(int, off_t, int);
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

enum
{   MAP_SHARED	= 1,
    MAP_PRIVATE	= 2,
    MAP_TYPE	= 0x0F,
    MAP_FIXED	= 0x10,
    // MAP_FILE is not in mmap.h on Solaris, but is supposed to work.
    MAP_FILE	= 0,
    MAP_ANONYMOUS	= 0x100,
    MAP_ANON	= 0x100,
    MAP_ALIGN	= 0x200,
    MAP_TEXT	= 0x400,
    MAP_INITDATA	= 0x800,
}

// Values for msync()

enum
{   MS_ASYNC	= 1,
    MS_INVALIDATE	= 2,
    MS_SYNC		= 4,
}

// Values for mlockall()

enum
{
	MCL_CURRENT	= 1,
	MCL_FUTURE	= 2,
}

// Values for madvise

enum
{	MADV_NORMAL	= 0,
	MADV_RANDOM	= 1,
	MADV_SEQUENTIAL	= 2,
	MADV_WILLNEED	= 3,
	MADV_DONTNEED	= 4,
	MADV_FREE	= 5,
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
int mincore(void*, size_t, ubyte*);
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
	uint d_ino;
	off_t d_off;
	ushort d_reclen;
	char[256] d_name;
    }

    struct dirent64
    {
	ulong d_ino;
	long d_off;
	ushort d_reclen;
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
		EINPROGRESS = 150,
	}
	
	// Use select_large_fdset for > 1024 on Solaris.  64bit uses 65536.
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

    const int RTLD_NOW = 0x00002;

    void* dlopen(in char* file, int mode);
    int   dlclose(void* handle);
    void* dlsym(void* handle, char* name);
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
	char *pw_age;
	char *pw_comment;
	char *pw_gecos;
	char *pw_dir;
	char *pw_shell;
    }

    int getpwnam_r(char*, passwd*, void*, size_t, passwd**);
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
    extern (C) alias void (*__sighandler_t)(int);
    extern (C) alias void (*__sigaction_t)(int, void*, void*);

    const SA_RESTART = 0x00000004u;

    const size_t _SIGSET_NWORDS = 4;

    struct sigset_t
    {
	uint[_SIGSET_NWORDS] __sigbits;
    }

    alias sigset_t __sigset;
    alias sigset_t __sigset_t;

    struct sigaction_t
    {
	int sa_flags;
	union
	{
	    __sighandler_t sa_handler;
	    __sigaction_t sa_sigaction;
	}
	sigset_t sa_mask;
	int sa_resv[2];
    }

    int sigfillset(sigset_t *);
    int sigdelset(sigset_t *, int);
    int sigismember(sigset_t *, int);
    int sigaction(int, sigaction_t*, sigaction_t*);
    int sigsuspend(sigset_t*);
}

extern (C)
{
    /* from semaphore.h
     */

    struct sem_t
    {
	uint sem_count;
	ushort sem_type;
	ushort sem_magic;
	ulong[3] sem_pad1;
	ulong[2] sem_pad2;
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

    int utime(in char* filename, in utimbuf* buf);
}

extern (C)
{
    extern
    {
	void* __libc_stack_end;
	int __data_start;
	int _end;
	int timezone;

	void *_deh_beg;
	void *_deh_end;
    }
}

// sched.h

enum
{
    SCHED_FIFO = 1,
    SCHED_OTHER = 0,
    SCHED_RR = 2,
}

struct sched_param
{
    int sched_priority;
    int[8] sched_pad;
}
