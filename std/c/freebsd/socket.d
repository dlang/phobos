// Written in the D programming language.

/*
 * This module is just for making std.socket work under FreeBSD, and these
 * definitions should actually be in druntime. (core.sys.posix.netdb or sth)
 */
/// Please import the core.sys.posix.* modules you need instead. This module will be deprecated in DMD 2.068.
module std.c.freebsd.socket;

version (FreeBSD):
public import core.sys.posix.netdb;
public import core.sys.posix.sys.socket : AF_APPLETALK, AF_IPX, SOCK_RDM, MSG_NOSIGNAL;
public import core.sys.posix.netinet.in_ : IPPROTO_IGMP, IPPROTO_GGP,
                                          IPPROTO_PUP, IPPROTO_IDP, IPPROTO_ND,
                                          IPPROTO_MAX, INADDR_LOOPBACK, INADDR_NONE;
