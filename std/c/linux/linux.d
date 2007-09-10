
module std.c.linux.linux;

import std.c.linux.linuxextern;

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

struct stat
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
    assert(stat.size == 88);
}


extern (C)
{
    int open(char*, int, ...);
    int read(int, void*, int);
    int write(int, void*, int);
    int close(int);
    int lseek(int, int, int);
    int fstat(int, stat*);
    int getErrno();
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
