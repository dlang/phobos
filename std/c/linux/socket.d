/*
    Written by Christopher E. Miller
    Placed into public domain.
*/


/// Please import the core.sys.posix.* modules you need instead. This module will be deprecated in DMD 2.068.
module std.c.linux.socket;

version (linux):
private import core.stdc.stdint;
public import core.sys.posix.arpa.inet;
public import core.sys.posix.netdb;
public import core.sys.posix.netinet.tcp;
public import core.sys.posix.netinet.in_;
public import core.sys.posix.sys.select;
public import core.sys.posix.sys.socket;

extern(C):

int gethostbyname_r(in char* name, hostent* ret, void* buf, size_t buflen, hostent** result, int* h_errnop);
int gethostbyname2_r(in char* name, int af, hostent* ret, void* buf, size_t buflen, hostent** result, int* h_errnop);

enum: int
{
    SD_RECEIVE =  0,
    SD_SEND =     1,
    SD_BOTH =     2,
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

enum: int
{
    TCP_NODELAY =        1,     // Don't delay send to coalesce packets
    TCP_MAXSEG =         2,     // Set maximum segment size
    TCP_CORK =           3,     // Control sending of partial frames
    TCP_KEEPIDLE =       4,     // Start keeplives after this period
    TCP_KEEPINTVL =      5,     // Interval between keepalives
    TCP_KEEPCNT =        6,     // Number of keepalives before death
    TCP_SYNCNT =         7,     // Number of SYN retransmits
    TCP_LINGER2 =        8,     // Life time of orphaned FIN-WAIT-2 state
    TCP_DEFER_ACCEPT =   9,     // Wake up listener only when data arrive
    TCP_WINDOW_CLAMP =  10,     // Bound advertised window
    TCP_INFO =          11,     // Information about this connection.
    TCP_QUICKACK =      12,     // Bock/reenable quick ACKs.
    TCP_CONGESTION =    13,     // Congestion control algorithm.
    TCP_MD5SIG =        14,     // TCP MD5 Signature (RFC2385)
}
