
module std.c.openbsd.openbsd;

version (OpenBSD) { } else { static assert(0); }

public import std.c.openbsd.pthread;

private import std.c.stdio;


//alias uint fflags_t;
alias int clockid_t;
alias int time_t;
alias int __time_t;
alias int pid_t;
alias long off_t;
//alias long blkcnt_t;
//alias uint blksize_t;
alias int dev_t;
alias uint gid_t;
alias uint id_t;
//alias ulong ino64_t;
alias uint ino_t;
alias uint mode_t;
alias uint nlink_t;
alias uint uid_t;
alias ulong fsblkcnt_t;
alias ulong fsfilcnt_t;

struct timeval
{
    int tv_sec;
    int tv_usec;
}

struct timespec
{
    time_t tv_sec;
    int tv_nsec;
}


