// Written in the D programming language.

/*
 * This module is just for making std.socket work under FreeBSD, and these
 * definitions should actually be in druntime. (core.sys.posix.netdb or sth)
 */
module std.c.freebsd.socket;

import core.sys.posix.sys.socket;

extern(C):

enum // <sys/socket.h> __BSD_VISIBLE
{
    AF_APPLETALK    = 16,
    AF_IPX          = 23,
}

enum // <sys/socket.h> __BSD_VISIBLE
{
    SOCK_RDM        = 4,
}

enum // <sys/socket.h> __BSD_VISIBLE
{
    MSG_NOSIGNAL    = 0x20000,
}

enum // <netinet/in.h> __BSD_VISIBLE
{
    IPPROTO_IGMP    = 2,
    IPPROTO_GGP     = 3,
    IPPROTO_PUP     = 12,
    IPPROTO_IDP     = 22,
    IPPROTO_ND      = 77,
    IPPROTO_MAX     = 256,
}

enum // <netinet/in.h>
{
    INADDR_LOOPBACK = 0x7f000001,
    INADDR_NONE     = 0xffffffff,
}


/*========== <netdb.h> ==========*/

struct hostent
{
    char*       h_name;
    char**      h_aliases;
    int         h_addrtype;
    int         h_length;
    char**      h_addr_list;
}

struct servent
{
    char*       s_name;
    char**      s_aliases;
    int         s_port;
    char*       s_proto;
}

struct protoent
{
    char*       p_name;
    char**      p_aliases;
    int         p_proto;
}

hostent*    gethostbyaddr(in void*, socklen_t, int);    // obsolete
hostent*    gethostbyname(in char*);                    // obsolete
protoent*   getprotobyname(in char *);
protoent*   getprotobynumber(int);
servent*    getservbyname(in char*, in char*);
servent*    getservbyport(int, in char*);

