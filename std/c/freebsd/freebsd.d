
/* Written by Walter Bright, Christopher E. Miller, and many others.
 * http://www.digitalmars.com/d/
 * Placed into public domain.
 */

module std.c.freebsd.freebsd;

version (FreeBSD) { } else { static assert(0); }

public import std.c.freebsd.pthread;

private import std.c.stdio;

alias uint fflags_t;
alias int clockid_t;
alias int time_t;
alias int __time_t;
alias int pid_t;
alias long off_t;
alias long blkcnt_t;
alias uint blksize_t;
alias uint dev_t;
alias uint gid_t;
alias long id_t;
//alias ulong ino64_t;
alias uint ino_t;
alias ushort mode_t;
alias ushort nlink_t;
alias uint uid_t;
alias ulong fsblkcnt_t;
alias ulong fsfilcnt_t;

struct timespec
{
    time_t tv_sec;
    int tv_nsec;
}

static if (size_t.sizeof == 4)
    alias int ssize_t;
else
    alias long ssize_t;
alias ssize_t intptr_t;

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
    SIGURG = 16,
    SIGSTOP = 17,
    SIGTSTP = 18,
    SIGCONT = 19,
    SIGCHLD = 20,
    SIGTTIN = 21,
    SIGTTOU = 22,
    SIGIO = 23,
    SIGXCPU = 24,
    SIGXFSZ = 25,
    SIGVTALRM = 26,
    SIGPROF = 27,
    SIGWINCH = 28,
    SIGINFO = 29,
    SIGUSR1 = 30,
    SIGUSR2 = 31,
    SIGTHR = 32,
    SIGLWP = SIGTHR,
    SIGRTMIN = 65,
    SIGRTMAX = 126,
}

// fcntl.h
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
    O_NOCTTY = 0x8000,
    O_DIRECT = 0x1000,
}

// sys/stat.h
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
    fflags_t st_flags;
    uint st_gen;
    int st_lspare;
    timespec st_birthtimesspec;
    ubyte[16 - timespec.sizeof] st_qspare;
}

unittest
{
    version (FreeBSD)   assert(struct_stat.sizeof == 96);
}

// sys/stat.h
enum : int
{
    S_IFIFO  = 0010000,
    S_IFCHR  = 0020000,
    S_IFDIR  = 0040000,
    S_IFBLK  = 0060000,
    S_IFREG  = 0100000,
    S_IFLNK  = 0120000,
    S_IFSOCK = 0140000,
    S_ISVTX  = 0001000,
    S_IFWHT  = 0160000,

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

    extern char** environ;
}

alias int suseconds_t;

struct timeval
{
    time_t tv_sec;
    suseconds_t tv_usec;
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
    char* tm_zone;
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
    MAP_COPY	= MAP_PRIVATE,
    MAP_FIXED	= 0x10,
    MAP_FILE	= 0,
    MAP_ANON	= 0x1000,
    MAP_NORESERVE	= 0x40,

    MAP_RENAME	 = 0x20,
    MAP_RESERVED0080 = 0x80,
    MAP_NOEXTEND	 = 0x100,
    MAP_HASSEMAPHORE = 0x200,
    MAP_STACK        = 0x400,
    MAP_NOSYNC       = 0x800,
    MAP_NOCORE       = 0x20000,
}

// Values for msync()

enum
{   MS_ASYNC	= 1,
    MS_INVALIDATE	= 2,
    MS_SYNC		= 0,
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
	MADV_NOSYNC	= 6,
	MADV_AUTOSYNC	= 7,
	MADV_NOCORE	= 8,
	MADV_CORE	= 9,
	MADV_PROTECT	= 10,
}

enum
{
	MINCORE_INCORE = 1,
	MINCORE_REFERENCED = 2,
	MINCORE_MODIFIED = 4,
	MINCORE_REFERENCED_OTHER = 8,
	MINCORE_MODIFIED_OTHER = 0x10,
}

extern (C)
{
void* mmap(void*, size_t, int, int, int, off_t);
const void* MAP_FAILED = cast(void*)-1;

int madvise(void*, size_t, int);
int minherit(void*, size_t, int);
int munmap(void*, size_t);
int mprotect(void*, size_t, int);
int msync(void*, size_t, int);
int madvise(void*, size_t, int);
int mlock(void*, size_t);
int munlock(void*, size_t);
int mlockall(int);
int munlockall();
void* mremap(void*, size_t, size_t, int);
int mincore(/*const*/ void*, size_t, ubyte*);
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
	uint d_fileno;		// this is int on some linuxes
	ushort d_reclen;
	ubyte d_type;		// this field isn't there on some linuxes
	ubyte d_namlen;
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
		EINPROGRESS = 36,
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

    const int RTLD_NOW = 2;

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
	time_t pw_change;
	char* pw_class;
	char* pw_gecos;
	char* pw_dir;
	char* pw_shell;
	time_t pw_expire;
	int pw_fields;
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

    const SA_RESTART = 2;

    const size_t _SIGSET_WORDS = 4;

    struct sigset_t
    {
	uint[_SIGSET_WORDS] __bits;
    }
    alias sigset_t __sigset;
    alias sigset_t __sigset_t;

    struct sigaction_t
    {
	union
	{   __sighandler_t sa_handler;
	    __sigaction_t sa_sigaction;
	}
	int sa_flags;
	sigset_t sa_mask;
    }

    int sigfillset(sigset_t*);
    int sigdelset(sigset_t*, int);
    int sigismember(sigset_t*, int);
    int sigaction(int, sigaction_t*, sigaction_t*);
    int sigsuspend(sigset_t*);
}

extern (C)
{
    /* from semaphore.h
     */
    alias intptr_t semid_t;

    struct sem_t
    {
	uint magic;
	pthread_mutex_t lock;
	pthread_cond_t gtzero;
	uint count;
	uint nwaiters;
	semid_t semid;
	int syssem;
	struct LIST_ENTRY
	{ sem_t *le_next;
	  sem_t **le_prev;
	}
	LIST_ENTRY entry;
	sem_t **backpointer;
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
    SCHED_OTHER = 2,
    SCHED_RR = 3
}

struct sched_param
{
    int sched_priority;
}
