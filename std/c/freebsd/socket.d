/*
	Written by Christopher E. Miller
	Placed into public domain.
*/


module std.c.freebsd.socket;

private import std.stdint;
private import std.c.freebsd.freebsd;

version (FreeBSD) { } else { static assert(0); }

extern(C):

alias uint socklen_t;

enum: int
{
    AF_UNSPEC =     0,
    AF_UNIX =       1,
    AF_INET =       2,
    AF_IPX =        23,
    AF_APPLETALK =  16,
    AF_INET6 =      28,
    // ...
    
    PF_UNSPEC =     AF_UNSPEC,
    PF_UNIX =       AF_UNIX,
    PF_INET =       AF_INET,
    PF_IPX =        AF_IPX,
    PF_APPLETALK =  AF_APPLETALK,
    PF_INET6 =      AF_INET6,
}

enum: int
{
    SOL_SOCKET =  0xFFFF,
}

enum: int
{
    SO_DEBUG =       1,
    SO_BROADCAST =   0x20,
    SO_REUSEADDR =   4,
    SO_LINGER =      0x80,
    //SO_DONTLINGER =  ~SO_LINGER,
    SO_OOBINLINE =   0x100,
    SO_SNDBUF =      0x1001,
    SO_RCVBUF =      0x1002,
    SO_ACCEPTCONN =  2,
    SO_DONTROUTE =   0x10,
    SO_TYPE =        0x1008,

    // netinet/tcp.h
    TCP_NODELAY =    1,

    // netinet/in.h
    IP_MULTICAST_LOOP =  11,
    IP_ADD_MEMBERSHIP =  12,
    IP_DROP_MEMBERSHIP = 13,
    
    // netinet6/in6.h
    //IPV6_ADDRFORM =        1,
    IPV6_PKTINFO =         46,
    IPV6_HOPOPTS =         49,
    IPV6_DSTOPTS =         50,
    IPV6_RTHDR =           51,
    IPV6_PKTOPTIONS =      52,
    IPV6_CHECKSUM =        26,
    IPV6_HOPLIMIT =        47,
    IPV6_NEXTHOP =         48,
    //IPV6_AUTHHDR =         10,
    IPV6_UNICAST_HOPS =    4,
    IPV6_MULTICAST_IF =    9,
    IPV6_MULTICAST_HOPS =  10,
    IPV6_MULTICAST_LOOP =  11,
    IPV6_JOIN_GROUP =      12,
    IPV6_LEAVE_GROUP =     13,
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

// sys/socket.h
enum: int
{
    MSG_OOB =        0x1,
    MSG_PEEK =       0x2,
    MSG_DONTROUTE =  0x4,
    MSG_NOSIGNAL =   0x20000,
}

enum: int
{
    SHUT_RD   =  0,
    SHUT_WR   =  1,
    SHUT_RDWR =  2,
}

enum: int	// not defined in FreeBSD, but we'll do it
{
    SD_RECEIVE =  SHUT_RD,
    SD_SEND =     SHUT_WR,
    SD_BOTH =     SHUT_RDWR,
}

alias ubyte sa_family_t;
struct sockaddr
{
    ubyte sa_len;
    sa_family_t sa_family;               
    ubyte[14] sa_data;             
}

alias uint in_addr_t;
alias ushort in_port_t;

// netinet/in.h
struct sockaddr_in
{
    ubyte sin_len;
    sa_family_t sin_family;
    in_port_t sin_port;
    in_addr sin_addr;
    ubyte[8] sin_zero;
}

// netinet6/in6.h
struct sockaddr_in6
{
    ubyte sin6_len;
    sa_family_t sin6_family;
    in_port_t sin6_port;
    uint sin6_flowinfo;
    in6_addr sin6_addr;
    uint sin6_scope_id;
}

// netdb.h
struct addrinfo
{
    int ai_flags; 
    int ai_family;
    int ai_socktype;
    int ai_protocol;
    socklen_t ai_addrlen;
    char* ai_canonname;
    sockaddr* ai_addr;
    addrinfo* ai_next;
}

// fcntl.h
const int F_GETFL =       3;
const int F_SETFL =       4;

int socket(int af, int type, int protocol);
int bind(int s, /*const*/ sockaddr* name, int namelen);
int connect(int s, /*const*/ sockaddr* name, int namelen);
int listen(int s, int backlog);
int accept(int s, sockaddr* addr, int* addrlen);
int shutdown(int s, int how);
int getpeername(int s, sockaddr* name, int* namelen);
int getsockname(int s, sockaddr* name, int* namelen);
int send(int s, void* buf, int len, int flags);
int sendto(int s, void* buf, int len, int flags, sockaddr* to, int tolen);
int recv(int s, void* buf, int len, int flags);
int recvfrom(int s, void* buf, int len, int flags, sockaddr* from, int* fromlen);
int getsockopt(int s, int level, int optname, void* optval, int* optlen);
int setsockopt(int s, int level, int optname, void* optval, int optlen);
uint inet_addr(char* cp);
char* inet_ntoa(in_addr ina);
hostent* gethostbyname(char* name);
int gethostbyname_r(char* name, hostent* ret, void* buf, size_t buflen, hostent** result, int* h_errnop);
int gethostbyname2_r(char* name, int af, hostent* ret, void* buf, size_t buflen, hostent** result, int* h_errnop);
hostent* gethostbyaddr(void* addr, int len, int type);
protoent* getprotobyname(char* name);
protoent* getprotobynumber(int number);
servent* getservbyname(char* name, char* proto);
servent* getservbyport(int port, char* proto);
int gethostname(char* name, int namelen);
int getaddrinfo(char* nodename, char* servname, addrinfo* hints, addrinfo** res);
void freeaddrinfo(addrinfo* ai);
int getnameinfo(sockaddr* sa, socklen_t salen, char* node, socklen_t nodelen, char* service, socklen_t servicelen, int flags);


struct linger
{
	int l_onoff;
	int l_linger;
}

// netdb.h
struct protoent
{
	char* p_name;
	char** p_aliases;
	int p_proto;
}

// netdb.h
struct servent
{
	char* s_name;
	char** s_aliases;
	int s_port;
	char* s_proto;
}


version(BigEndian)
{
	ushort htons(ushort x)
	{
		return x;
	}
	
	
	uint htonl(uint x)
	{
		return x;
	}
}
else version(LittleEndian)
{
	private import std.intrinsic;
	
	
	ushort htons(ushort x)
	{
		return cast(ushort)((x >> 8) | (x << 8));
	}


	uint htonl(uint x)
	{
		return bswap(x);
	}
}
else
{
	static assert(0);
}


ushort ntohs(ushort x)
{
	return htons(x);
}


uint ntohl(uint x)
{
	return htonl(x);
}


enum: int
{
	SOCK_STREAM =     1,
	SOCK_DGRAM =      2,
	SOCK_RAW =        3,
	SOCK_RDM =        4,
	SOCK_SEQPACKET =  5,
}


// netinet/in.h
enum: int
{
	IPPROTO_IP =    0,
	IPPROTO_ICMP =  1,
	IPPROTO_IGMP =  2,
	IPPROTO_GGP =   3,
	IPPROTO_TCP =   6,
	IPPROTO_PUP =   12,
	IPPROTO_UDP =   17,
	IPPROTO_IDP =   22,
	IPPROTO_IPV6 =  41,
	IPPROTO_ND =    77,
	IPPROTO_RAW =   255,
	
	IPPROTO_MAX =   256,
}


enum: uint
{
	INADDR_ANY =        0,
	INADDR_LOOPBACK =   0x7F000001,
	INADDR_BROADCAST =  0xFFFFFFFF,
	INADDR_NONE =       0xFFFFFFFF,
	ADDR_ANY =          INADDR_ANY,
}


// netdb.h
enum: int
{
	AI_PASSIVE = 0x1,
	AI_CANONNAME = 0x2,
	AI_NUMERICHOST = 0x4,
	AI_NUMERICSERV = 8,
}


union in_addr
{
	private union _S_un_t
	{
		private struct _S_un_b_t
		{
			uint8_t s_b1, s_b2, s_b3, s_b4;
		}
		_S_un_b_t S_un_b;
		
		private struct _S_un_w_t
		{
			ushort s_w1, s_w2;
		}
		_S_un_w_t S_un_w;
		
		uint S_addr;
	}
	_S_un_t S_un;
	
	uint s_addr;
	
	struct
	{
		uint8_t s_net, s_host;
		
		union
		{
			ushort s_imp;
			
			struct
			{
				uint8_t s_lh, s_impno;
			}
		}
	}
}


union in6_addr
{
	private union _in6_u_t
	{
		uint8_t[16] u6_addr8;
		ushort[8] u6_addr16;
		uint[4] u6_addr32;
	}
	_in6_u_t in6_u;
	
	uint8_t[16] s6_addr8;
	ushort[8] s6_addr16;
	uint[4] s6_addr32;
}


const in6_addr IN6ADDR_ANY = { s6_addr8: [0] };
const in6_addr IN6ADDR_LOOPBACK = { s6_addr8: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1] };
//alias IN6ADDR_ANY IN6ADDR_ANY_INIT;
//alias IN6ADDR_LOOPBACK IN6ADDR_LOOPBACK_INIT;
	
const uint INET_ADDRSTRLEN = 16;
const uint INET6_ADDRSTRLEN = 46;

// netdb.h
struct hostent
{
	char* h_name;
	char** h_aliases;
	int h_addrtype;
	int h_length;
	char** h_addr_list;

	char* h_addr()
	{
		return h_addr_list[0];
	}
}

