
/* Written by Walter Bright and Christopher E. Miller
 * www.digitalmars.com
 * Placed into public domain.
 */

module std.c.linux.linux;

import std.c.linux.linuxextern;

alias int off_t;

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

enum
{
    O_RDONLY = 0,
    O_WRONLY = 1,
    O_RDWR = 2,
    O_CREAT = 0100,
    O_EXCL = 0200,
    O_TRUNC = 01000,
    O_APPEND = 02000,
}

struct struct_stat	// distinguish it from the stat() function
{
    ulong st_dev;
    ushort __pad1;
    uint st_ino;
    uint st_mode;
    uint st_nlink;
    uint st_uid;
    uint st_gid;
    ulong st_rdev;
    ushort __pad2;
    int st_size;
    int st_blksize;
    int st_blocks;
    int st_atime;
    uint __unused1;
    int st_mtime;
    uint __unused2;
    int st_ctime;
    uint __unused3;
    uint __unused4;
    uint __unused5;
}

unittest
{
    assert(struct_stat.sizeof == 88);
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

    S_IFMT   = 0170000
}

extern (C)
{
    int open(char*, int, ...);
    int read(int, void*, int);
    int write(int, void*, int);
    int close(int);
    int lseek(int, int, int);
    int fstat(int, struct_stat*);
    int stat(char*, struct_stat*);
    int chdir(char*);
    int mkdir(char*, int);
    int rmdir(char*);
    char* getcwd(char*, int);
}

struct timeval
{
    int tv_sec;
    int tv_usec;
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
    int gettimeofday(timeval*, void*);
    int time(int*);
    tm *localtime(int*);
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
int shm_open(char*, int, int);
int shm_unlink(char*);
}

extern(C)
{
    struct dirent
    {
	int d_ino;
	off_t d_off;
	ushort d_reclen;
	ubyte d_type;
	char[256] d_name;
    }
    
    struct DIR
    {
	// Managed by OS.
    }
    
    DIR* opendir(char* name);
    int closedir(DIR* dir);
    dirent* readdir(DIR* dir);
    void rewinddir(DIR* dir);
    off_t telldir(DIR* dir);
    void seekdir(DIR* dir, off_t offset);
}


extern(C)
{
	private import std.intrinsic;
	
	
	char* strerror(int errnum);
	
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

