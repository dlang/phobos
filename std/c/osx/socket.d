/*
    Written by Christopher E. Miller
    Placed into public domain.
*/


/// Please import the core.sys.posix.* modules you need instead. This module will be deprecated in DMD 2.068.
module std.c.osx.socket;

version (OSX):
private import core.stdc.stdint;
public import core.sys.posix.arpa.inet;
public import core.sys.posix.netdb;
public import core.sys.posix.netinet.tcp;
public import core.sys.posix.netinet.in_;
public import core.sys.posix.sys.select;
public import core.sys.posix.sys.socket;

extern(C):

// Not defined in OSX, so these will be removed at the end of deprecation
enum: int
{
    SD_RECEIVE =  0,
    SD_SEND =     1,
    SD_BOTH =     2,
}

enum: int
{
    IP_MULTICAST_LOOP =  11,
    IP_ADD_MEMBERSHIP =  12,
    IP_DROP_MEMBERSHIP = 13,

    // ...

    //IPV6_ADDRFORM =        1,
    IPV6_PKTINFO =         19,
    IPV6_HOPOPTS =         22,
    IPV6_DSTOPTS =         23,
    IPV6_RTHDR =           24,
    IPV6_PKTOPTIONS =      25,
    IPV6_CHECKSUM =        26,
    IPV6_HOPLIMIT =        20,
    IPV6_NEXTHOP =         21,
    //IPV6_AUTHHDR =         10,
    IPV6_MULTICAST_HOPS =  10,
    //IPV6_ROUTER_ALERT =    22,
    //IPV6_MTU_DISCOVER =    23,
    //IPV6_MTU =             24,
    //IPV6_RECVERR =         25,
    IPV6_V6ONLY =          27,
    //IPV6_JOIN_ANYCAST =    27,
    //IPV6_LEAVE_ANYCAST =   28,
    IPV6_IPSEC_POLICY =    28,
    //IPV6_XFRM_POLICY =     35,
}
