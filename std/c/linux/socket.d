/*
    Written by Christopher E. Miller
    Placed into public domain.
*/


module std.c.linux.socket;

private import core.stdc.stdint;
public import core.sys.posix.arpa.inet;
public import core.sys.posix.netinet.tcp;
public import core.sys.posix.netinet.in_;
public import core.sys.posix.sys.select;
public import core.sys.posix.sys.socket;

extern(C):

enum: int
{
    AF_IPX =        4,
    AF_APPLETALK =  5,
    PF_IPX =        AF_IPX,
    PF_APPLETALK =  AF_APPLETALK,
}

enum: int
{
    SOCK_RDM =      4,
}

enum: int
{
    IPPROTO_IGMP =  2,
    IPPROTO_GGP =   3,
    IPPROTO_PUP =   12,
    IPPROTO_IDP =   22,
    IPPROTO_ND =    77,
    IPPROTO_RAW =   255,

    IPPROTO_MAX =   256,
}

struct protoent
{
    char* p_name;
    char** p_aliases;
    int32_t p_proto;
}

protoent* getprotobyname(in char* name);
protoent* getprotobynumber(int number);

struct servent
{
    char* s_name;
    char** s_aliases;
    int32_t s_port;
    char* s_proto;
}

servent* getservbyname(in char* name, in char* proto);
servent* getservbyport(int port, in char* proto);

struct hostent
{
    char* h_name;
    char** h_aliases;
    int32_t h_addrtype;
    int32_t h_length;
    char** h_addr_list;


    char* h_addr()
    {
        return h_addr_list[0];
    }
}

hostent* gethostbyname(in char* name);
int gethostbyname_r(in char* name, hostent* ret, void* buf, size_t buflen, hostent** result, int* h_errnop);
int gethostbyname2_r(in char* name, int af, hostent* ret, void* buf, size_t buflen, hostent** result, int* h_errnop);
hostent* gethostbyaddr(void* addr, int len, int type);

enum: int
{
    SD_RECEIVE =  0,
    SD_SEND =     1,
    SD_BOTH =     2,
}

enum: int
{
    MSG_NOSIGNAL =   0x4000,
}

enum: int
{
    IP_MULTICAST_LOOP =  34,
    IP_ADD_MEMBERSHIP =  35,
    IP_DROP_MEMBERSHIP = 36,

    // ...

    IPV6_ADDRFORM =        1,
    IPV6_PKTINFO =         2,
    IPV6_HOPOPTS =         3,
    IPV6_DSTOPTS =         4,
    IPV6_RTHDR =           5,
    IPV6_PKTOPTIONS =      6,
    IPV6_CHECKSUM =        7,
    IPV6_HOPLIMIT =        8,
    IPV6_NEXTHOP =         9,
    IPV6_AUTHHDR =         10,
    IPV6_MULTICAST_HOPS =  18,
    IPV6_ROUTER_ALERT =    22,
    IPV6_MTU_DISCOVER =    23,
    IPV6_MTU =             24,
    IPV6_RECVERR =         25,
    IPV6_V6ONLY =          26,
    IPV6_JOIN_ANYCAST =    27,
    IPV6_LEAVE_ANYCAST =   28,
    IPV6_IPSEC_POLICY =    34,
    IPV6_XFRM_POLICY =     35,
}

enum: uint
{
    INADDR_LOOPBACK =   0x7F000001,
    INADDR_BROADCAST =  0xFFFFFFFF,
    INADDR_NONE =       0xFFFFFFFF,
}
