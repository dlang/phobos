
/* Written by Walter Bright, Sean Kelly, and many others.
 * http://www.digitalmars.com
 * Placed into public domain.
 */

module std.c.osx.osx;

public import std.c.linux.linuxextern;
public import std.c.linux.pthread;

private import std.c.stdio;

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


static if (size_t.sizeof == 4)
    alias int ssize_t;
else
    alias long ssize_t;


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
static assert(struct_stat.sizeof == 96);

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
    ssize_t read(int, void*, size_t);
    ssize_t write(int, in void*, size_t);
    int close(int);
    int lseek(int, off_t, int);
    int fstat(int, struct_stat*);
    int lstat(in char*, struct_stat*);
    int stat(in char*, struct_stat*);
    int chdir(in char*);
    int mkdir(in char*, int);
    int rmdir(in char*);
    char* getcwd(char*, size_t);
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
        PROT_NONE       = 0,
        PROT_READ       = 1,
        PROT_WRITE      = 2,
        PROT_EXEC       = 4,
}

// Memory mapping sharing types


enum
{   MAP_SHARED  = 1,
    MAP_PRIVATE = 2,
    MAP_FIXED   = 0x10,
    MAP_FILE    = 0,
    MAP_ANON    = 0x1000,
    MAP_NORESERVE       = 0x40,

    MAP_RENAME  = 0x20,
    MAP_RESERVED0080 = 0x80,
    MAP_NOEXTEND        = 0x100,
    MAP_HASSEMAPHORE = 0x200,
    MAP_NOCACHE = 0x400,
}

// Values for msync()

enum
{   MS_ASYNC    = 1,
    MS_INVALIDATE       = 2,
    MS_SYNC             = 0x10,
}

// Values for mlockall()

enum
{
        MCL_CURRENT     = 1,
        MCL_FUTURE      = 2,
}

// Values for mremap()

enum
{
        MREMAP_MAYMOVE  = 1,
}

// Values for madvise

enum
{       MADV_NORMAL     = 0,
        MADV_RANDOM     = 1,
        MADV_SEQUENTIAL = 2,
        MADV_WILLNEED   = 3,
        MADV_DONTNEED   = 4,
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
        uint d_ino;
        ushort d_reclen;
        ubyte d_type;
        ubyte d_namlen;
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
                btr(cast(size_t*)&set.fds_bits.ptr[FDELT(fd)], cast(size_t)(fd % NFDBITS));
        }


        // Tests.
        int FD_ISSET(int fd, fd_set* set)
        {
                return bt(cast(size_t*)&set.fds_bits.ptr[FDELT(fd)], cast(size_t)(fd % NFDBITS));
        }


        // Adds.
        void FD_SET(int fd, fd_set* set)
        {
                bts(cast(size_t*)&set.fds_bits.ptr[FDELT(fd)], cast(size_t)(fd % NFDBITS));
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
     * To use these functions, you'll need to link in /usr/lib/libdl.a
     * (compile/link with -L-ldl)
     */

    const int RTLD_NOW = 0x00002;       // Correct for Red Hat 8

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
}

extern (C)
{
    /* from semaphore.h
     */

    alias int sem_t;

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

    int utime(char* filename, utimbuf* buf);
}

extern (C):

alias int kern_return_t;

enum : kern_return_t
{
    KERN_SUCCESS                = 0,
    KERN_INVALID_ADDRESS        = 1,
    KERN_PROTECTION_FAILURE     = 2,
    KERN_NO_SPACE               = 3,
    KERN_INVALID_ARGUMENT       = 4,
    KERN_FAILURE                = 5,
    KERN_RESOURCE_SHORTAGE      = 6,
    KERN_NOT_RECEIVER           = 7,
    KERN_NO_ACCESS              = 8,
    KERN_MEMORY_FAILURE         = 9,
    KERN_MEMORY_ERROR           = 10,
    KERN_ALREADY_IN_SET         = 11,
    KERN_NOT_IN_SET             = 12,
    KERN_NAME_EXISTS            = 13,
    KERN_ABORTED                = 14,
    KERN_INVALID_NAME           = 15,
    KERN_INVALID_TASK           = 16,
    KERN_INVALID_RIGHT          = 17,
    KERN_INVALID_VALUE          = 18,
    KERN_UREFS_OVERFLOW         = 19,
    KERN_INVALID_CAPABILITY     = 20,
    KERN_RIGHT_EXISTS           = 21,
    KERN_INVALID_HOST           = 22,
    KERN_MEMORY_PRESENT         = 23,
    KERN_MEMORY_DATA_MOVED      = 24,
    KERN_MEMORY_RESTART_COPY    = 25,
    KERN_INVALID_PROCESSOR_SET  = 26,
    KERN_POLICY_LIMIT           = 27,
    KERN_INVALID_POLICY         = 28,
    KERN_INVALID_OBJECT         = 29,
    KERN_ALREADY_WAITING        = 30,
    KERN_DEFAULT_SET            = 31,
    KERN_EXCEPTION_PROTECTED    = 32,
    KERN_INVALID_LEDGER         = 33,
    KERN_INVALID_MEMORY_CONTROL = 34,
    KERN_INVALID_SECURITY       = 35,
    KERN_NOT_DEPRESSED          = 36,
    KERN_TERMINATED             = 37,
    KERN_LOCK_SET_DESTROYED     = 38,
    KERN_LOCK_UNSTABLE          = 39,
    KERN_LOCK_OWNED             = 40,
    KERN_LOCK_OWNED_SELF        = 41,
    KERN_SEMAPHORE_DESTROYED    = 42,
    KERN_RPC_SERVER_TERMINATED  = 43,
    KERN_RPC_TERMINATE_ORPHAN   = 44,
    KERN_RPC_CONTINUE_ORPHAN    = 45,
    KERN_NOT_SUPPORTED          = 46,
    KERN_NODE_DOWN              = 47,
    KERN_OPERATION_TIMED_OUT    = 49,
    KERN_RETURN_MAX             = 0x100,
}

version( X86 )
    version = i386;
version( X86_64 )
    version = i386;
version( i386 )
{
    alias uint        natural_t;
    alias natural_t   mach_port_t;
    alias mach_port_t thread_act_t;
    alias void        thread_state_t;
    alias int         thread_state_flavor_t;
    alias natural_t   mach_msg_type_number_t;

    enum
    {
        x86_THREAD_STATE32      = 1,
        x86_FLOAT_STATE32       = 2,
        x86_EXCEPTION_STATE32   = 3,
        x86_THREAD_STATE64      = 4,
        x86_FLOAT_STATE64       = 5,
        x86_EXCEPTION_STATE64   = 6,
        x86_THREAD_STATE        = 7,
        x86_FLOAT_STATE         = 8,
        x86_EXCEPTION_STATE     = 9,
        x86_DEBUG_STATE32       = 10,
        x86_DEBUG_STATE64       = 11,
        x86_DEBUG_STATE         = 12,
        THREAD_STATE_NONE       = 13,
    }

    struct x86_thread_state32_t
    {
        uint    eax;
        uint    ebx;
        uint    ecx;
        uint    edx;
        uint    edi;
        uint    esi;
        uint    ebp;
        uint    esp;
        uint    ss;
        uint    eflags;
        uint    eip;
        uint    cs;
        uint    ds;
        uint    es;
        uint    fs;
        uint    gs;
    }

    struct x86_thread_state64_t
    {
        ulong   rax;
        ulong   rbx;
        ulong   rcx;
        ulong   rdx;
        ulong   rdi;
        ulong   rsi;
        ulong   rbp;
        ulong   rsp;
        ulong   r8;
        ulong   r9;
        ulong   r10;
        ulong   r11;
        ulong   r12;
        ulong   r13;
        ulong   r14;
        ulong   r15;
        ulong   rip;
        ulong   rflags;
        ulong   cs;
        ulong   fs;
        ulong   gs;
    }

    struct x86_state_hdr_t
    {
        int     flavor;
        int     count;
    }

    struct x86_thread_state_t
    {
        x86_state_hdr_t             tsh;
        union _uts
        {
            x86_thread_state32_t    ts32;
            x86_thread_state64_t    ts64;
        }
        _uts                        uts;
    }

    enum : mach_msg_type_number_t
    {
        x86_THREAD_STATE32_COUNT = cast(mach_msg_type_number_t)( x86_thread_state32_t.sizeof / int.sizeof ),
        x86_THREAD_STATE64_COUNT = cast(mach_msg_type_number_t)( x86_thread_state64_t.sizeof / int.sizeof ),
        x86_THREAD_STATE_COUNT   = cast(mach_msg_type_number_t)( x86_thread_state_t.sizeof / int.sizeof ),
    }

    alias x86_THREAD_STATE          MACHINE_THREAD_STATE;
    alias x86_THREAD_STATE_COUNT    MACHINE_THREAD_STATE_COUNT;

    mach_port_t   mach_thread_self();
    mach_port_t   pthread_mach_thread_np(pthread_t);
    kern_return_t thread_suspend(thread_act_t);
    kern_return_t thread_resume(thread_act_t);
    kern_return_t thread_get_state(thread_act_t, thread_state_flavor_t, thread_state_t*, mach_msg_type_number_t*);
}
