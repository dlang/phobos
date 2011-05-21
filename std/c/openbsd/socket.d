/*
*/


module std.c.openbsd.socket;

private import std.stdint;
private import std.c.openbsd.openbsd;

version (OpenBSD) { } else { static assert(0); }

extern(C):

struct	linger
{
    int	l_onoff;		
    int	l_linger;		
}

struct	splice
{
    int	sp_fd;			
    off_t sp_max;			
}

struct sockaddr
{
    u_int8_t    sa_len;		
    sa_family_t sa_family;		
    char sa_data[14];	
}


struct sockaddr_storage
{
    u_int8_t ss_len;		
    sa_family_t ss_family;	
    ubyte __ss_pad1[6];	
    u_int64_t __ss_pad2;	
    ubyte __ss_pad3[240];	
}

struct sockproto
{
    ushort sp_family;	
    ushort sp_protocol;	
}

struct sockcred
{
    uid_t sc_uid;			
    uid_t sc_euid;		
    gid_t sc_gid;			
    gid_t sc_egid;		
    int	sc_ngroups;		
    gid_t sc_groups[1];		
}

struct msghdr
{
    void* msg_name;	
    socklen_t msg_namelen;	
    iovec* msg_iov;	
    uint msg_iovlen;	
    void* msg_control;	
    socklen_t msg_controllen;	
    int msg_flags;	
}

struct cmsghdr
{
    socklen_t cmsg_len;	
    int cmsg_level;	
    int cmsg_type;	
}

struct osockaddr
{
    ushort sa_family;	
    char sa_data[14];	
}


struct omsghdr
{
    caddr_t msg_name;		
    int	msg_namelen;		
    iovec* msg_iov;		
    int msg_iovlen;		
    caddr_t msg_accrights;		
    int	msg_accrightslen;
}

int accept(int, sockaddr*, socklen_t*);
int bind(int, sockaddr*, socklen_t);
int connect(int, sockaddr*, socklen_t);
int getpeereid(int, uid_t*, gid_t*);
int getpeername(int, sockaddr*, socklen_t*);
int getsockname(int, sockaddr*, socklen_t*);
int getsockopt(int, int, int, void*, socklen_t*);
int listen(int, int);
ssize_t recv(int, void*, size_t, int);
ssize_t recvfrom(int, void*, size_t, int, sockaddr*, socklen_t*);
ssize_t recvmsg(int, msghdr*, int);
ssize_t send(int, void*, size_t, int);
ssize_t sendto(int, void*, size_t, int, sockaddr*, socklen_t);
ssize_t sendmsg(int, msghdr*, int);
int setsockopt(int, int, int, void*, socklen_t);
int shutdown(int, int);
int socket(int, int, int);
int socketpair(int, int, int, int*);
int getrtable();
int setrtable(int);

