/*
	Copyright (C) 2004 Christopher E. Miller
	
	This software is provided 'as-is', without any express or implied
	warranty.  In no event will the authors be held liable for any damages
	arising from the use of this software.
	
	Permission is granted to anyone to use this software for any purpose,
	including commercial applications, and to alter it and redistribute it
	freely, subject to the following restrictions:
	
	1. The origin of this software must not be misrepresented; you must not
	   claim that you wrote the original software. If you use this software
	   in a product, an acknowledgment in the product documentation would be
	   appreciated but is not required.
	2. Altered source versions must be plainly marked as such, and must not
	   be misrepresented as being the original software.
	3. This notice may not be removed or altered from any source
	   distribution.
*/

// socket.d 1.2
// Apr 2004

module std.socket;


version(linux)
{
	version = BsdSockets;
}

version(Win32)
{
	typedef uint socket_t = ~0;
}
else version(BsdSockets)
{
	typedef int socket_t = -1;
}
else
{
	static assert(0); // No socket support yet
}
const socket_t INVALID_SOCKET = socket_t.init;
const int SOCKET_ERROR = -1;


private:

import std.string, std.stdint, std.c.stdlib;


version(Win32)
{
	import std.c.windows.windows;
	
	
	extern(Windows)
	{
		const int WSADESCRIPTION_LEN = 256;
		const int WSASYS_STATUS_LEN = 128;
		
		struct WSADATA
		{
			WORD wVersion;
			WORD wHighVersion;
			char szDescription[WSADESCRIPTION_LEN+1];
			char szSystemStatus[WSASYS_STATUS_LEN+1];
			ushort iMaxSockets;
			ushort iMaxUdpDg;
			char* lpVendorInfo;
		}
		alias WSADATA* LPWSADATA;
		
		
		const int IOCPARM_MASK =  0x7f;
		const int IOC_IN =        cast(int)0x80000000;
		const int FIONBIO =       IOC_IN | ((uint.sizeof & IOCPARM_MASK) << 16) | (102 << 8) | 126;
		const int SOL_SOCKET =    0xFFFF;
		const int SO_TYPE =       0x1008;
		
		
		int WSAStartup(WORD wVersionRequested, LPWSADATA lpWSAData);
		int WSACleanup();
		socket_t socket(int af, int type, int protocol);
		int ioctlsocket(socket_t s, int cmd, uint* argp);
		int getsockopt(socket_t s, int level, int optname, char* optval, int* optlen);
		uint inet_addr(char* cp);
		int bind(socket_t s, sockaddr* name, int namelen);
		int connect(socket_t s, sockaddr* name, int namelen);
		int listen(socket_t s, int backlog);
		socket_t accept(socket_t s, sockaddr* addr, int* addrlen);
		int closesocket(socket_t s);
		int shutdown(socket_t s, int how);
		int getpeername(socket_t s, sockaddr* name, int* namelen);
		int getsockname(socket_t s, sockaddr* name, int* namelen);
		int send(socket_t s, void* buf, int len, int flags);
		int sendto(socket_t s, void* buf, int len, int flags, sockaddr* to, int tolen);
		int recv(socket_t s, void* buf, int len, int flags);
		int recvfrom(socket_t s, void* buf, int len, int flags, sockaddr* from, int* fromlen);
		int select(int nfds, fd_set* readfds, fd_set* writefds, fd_set* errorfds, timeval* timeout);
		//int __WSAFDIsSet(socket_t s, fd_set* fds);
		int getsockopt(socket_t s, int level, int optname, void* optval, int* optlen);
		int setsockopt(socket_t s, int level, int optname, void* optval, int optlen);
		char* inet_ntoa(uint ina);
		hostent* gethostbyname(char* name);
		hostent* gethostbyaddr(void* addr, int len, int type);
		
		
		const int WSAEWOULDBLOCK =  10035;
		const int WSAEINTR =        10004;
		
		int WSAGetLastError();
	}
}
else version(BsdSockets)
{
	extern(C)
	{
		const int F_GETFL =       3;
		const int F_SETFL =       4;
		const int O_NONBLOCK =    0x4000;
		const int SOL_SOCKET =    0xFFFF;
		const int SO_TYPE =       0x1008;
		
		
		socket_t socket(int af, int type, int protocol);
		int fcntl(socket_t s, int f, ...);
		int getsockopt(socket_t s, int level, int optname, char* optval, int* optlen);
		uint inet_addr(char* cp);
		int bind(socket_t s, sockaddr* name, int namelen);
		int connect(socket_t s, sockaddr* name, int namelen);
		int listen(socket_t s, int backlog);
		socket_t accept(socket_t s, sockaddr* addr, int* addrlen);
		int close(socket_t s);
		int shutdown(socket_t s, int how);
		int getpeername(socket_t s, sockaddr* name, int* namelen);
		int getsockname(socket_t s, sockaddr* name, int* namelen);
		int send(socket_t s, void* buf, int len, int flags);
		int sendto(socket_t s, void* buf, int len, int flags, sockaddr* to, int tolen);
		int recv(socket_t s, void* buf, int len, int flags);
		int recvfrom(socket_t s, void* buf, int len, int flags, sockaddr* from, int* fromlen);
		int select(int nfds, fd_set* readfds, fd_set* writefds, fd_set* errorfds, timeval* timeout);
		int getsockopt(socket_t s, int level, int optname, void* optval, int* optlen);
		int setsockopt(socket_t s, int level, int optname, void* optval, int optlen);
		char* inet_ntoa(uint ina);
		hostent* gethostbyname(char* name);
		hostent* gethostbyaddr(void* addr, int len, int type);
		
		
		const int EINTR =           4;
		version(linux)
		{
			const int EINPROGRESS =  115; //EWOULDBLOCK
			
			
			import std.c.linux.linux; //for getErrno
		}
		else
		{
			static assert(0);
		}
	}
}


//transparent
struct fd_set
{
}


struct sockaddr
{
	ushort sa_family;               
	char[14] sa_data = [0];             
}


struct hostent
{
	char* h_name;
	char** h_aliases;
	version(Win32)
	{
		short h_addrtype;
		short h_length;
	}
	else version(BsdSockets)
	{
		int h_addrtype;
		int h_length;
	}
	char** h_addr_list;
	
	
	char* h_addr()
	{
		return h_addr_list[0];
	}
}


version(BigEndian)
{
	uint16_t htons(uint16_t x)
	{
		return x;
	}
	
	
	uint32_t htonl(uint32_t x)
	{
		return x;
	}
}
else version(LittleEndian)
{
	import std.intrinsic;
	
	
	uint16_t htons(uint16_t x)
	{
		return (x >> 8) | (x << 8);
	}


	uint32_t htonl(uint32_t x)
	{
		return bswap(x);
	}
}
else
{
	static assert(0);
}


uint16_t ntohs(uint16_t x)
{
	return htons(x);
}


uint32_t ntohl(uint32_t x)
{
	return htonl(x);
}


public:
class SocketException: Exception
{
	this(char[] msg)
	{
		super(msg);
	}
}


static this()
{
	version(Win32)
	{
		WSADATA wd;
		if(WSAStartup(0x0101, &wd))
			throw new SocketException("Unable to initialize socket library.");
	}
}


static ~this()
{
	version(Win32)
	{
		WSACleanup();
	}
}


version(Win32)
{
	enum AddressFamily: int
	{
		UNSPEC =     0,
		UNIX =       1,
		INET =       2,
		IPX =        6,
		APPLETALK =  16,
		//INET6 =      ? // Need Windows XP ?
	}
}
else version(BsdSockets)
{
	enum AddressFamily: int
	{
		UNSPEC =     0,
		UNIX =       1,
		INET =       2,
		IPX =        4,
		APPLETALK =  5,
		//INET6 =      10,
	}
}


enum SocketType: int
{
	STREAM =     1,
	DGRAM =      2,
	RAW =        3,
	RDM =        4,
	SEQPACKET =  5,
}


enum ProtocolType: int
{
	IP =    0,
	ICMP =  1,
	IGMP =  2,
	GGP =   3,
	TCP =   6,
	PUP =   12,
	UDP =   17,
	IDP =   22,
}


class AddressException: Exception
{
	this(char[] msg)
	{
		super(msg);
	}
}


abstract class Address
{
	protected sockaddr* name();
	protected int nameLen();
	AddressFamily addressFamily();
	char[] toString();
}


class UnknownAddress: Address
{
	protected:
	sockaddr sa;
	
	
	sockaddr* name()
	{
		return &sa;
	}
	
	
	int nameLen()
	{
		return sa.sizeof;
	}
	
	
	public:
	AddressFamily addressFamily()
	{
		return cast(AddressFamily)sa.sa_family;
	}
	
	
	char[] toString()
	{
		return "Unknown";
	}
}


class HostException: Exception
{
	this(char[] msg)
	{
		super(msg);
	}
}


class InternetHost
{
	char[] name;
	char[][] aliases;
	uint[] addrList;
	
	
	protected void validHostent(hostent* he)
	{
		if(he.h_addrtype != cast(int)AddressFamily.INET || he.h_length != 4)
			throw new HostException("Address family mismatch.");
	}
	
	
	void populate(hostent* he)
	{
		int i;
		char* p;
		
		name = std.string.toString(he.h_name);
		
		for(i = 0;; i++)
		{
			p = he.h_aliases[i];
			if(!p)
				break;
		}
		
		if(i)
		{
			aliases = new char[][i];
			for(i = 0; i != aliases.length; i++)
			{
				aliases[i] = std.string.toString(he.h_aliases[i]);
			}
		}
		else
		{
			aliases = null;
		}
		
		for(i = 0;; i++)
		{
			p = he.h_addr_list[i];
			if(!p)
				break;
		}
		
		if(i)
		{
			addrList = new uint[i];
			for(i = 0; i != addrList.length; i++)
			{
				addrList[i] = ntohl(*(cast(uint*)he.h_addr_list[i]));
			}
		}
		else
		{
			addrList = null;
		}
	}
	
	
	bit getHostByName(char[] name)
	{
		hostent* he = gethostbyname(toStringz(name));
		if(!he)
			return false;
		validHostent(he);
		populate(he);
		return true;
	}
	
	
	bit getHostByAddr(uint addr)
	{
		uint x = htonl(addr);
		hostent* he = gethostbyaddr(&x, 4, cast(int)AddressFamily.INET);
		if(!he)
			return false;
		validHostent(he);
		populate(he);
		return true;
	}
	
	
	//shortcut
	bit getHostByAddr(char[] addr)
	{
		uint x = inet_addr(std.string.toStringz(addr));
		hostent* he = gethostbyaddr(&x, 4, cast(int)AddressFamily.INET);
		if(!he)
			return false;
		validHostent(he);
		populate(he);
		return true;
	}
}


unittest
{
	InternetHost ih = new InternetHost;
	assert(ih.getHostByName("www.digitalmars.com"));
	printf("addrList.length = %d\n", ih.addrList.length);
	assert(ih.addrList.length);
	InternetAddress ia = new InternetAddress(ih.addrList[0], InternetAddress.PORT_ANY);
	printf("IP address = %.*s\nname = %.*s\n", ia.toAddrString(), ih.name);
	foreach(int i, char[] s; ih.aliases)
	{
		printf("aliases[%d] = %.*s\n", i, s);
	}
	
	printf("---\n");
	
	assert(ih.getHostByAddr(ih.addrList[0]));
	printf("name = %.*s\n", ih.name);
	foreach(int i, char[] s; ih.aliases)
	{
		printf("aliases[%d] = %.*s\n", i, s);
	}
}


class InternetAddress: Address
{
	protected:
	struct sockaddr_in
	{
		ushort sin_family = cast(ushort)AddressFamily.INET;
		ushort sin_port;
		uint sin_addr; //in_addr
		char[8] sin_zero = [0];
	}
	sockaddr_in sin;


	sockaddr* name()
	{
		return cast(sockaddr*)&sin;
	}
	
	
	int nameLen()
	{
		return sin.sizeof;
	}
	
	
	this()
	{
	}
	
	
	public:
	const uint ADDR_ANY = 0;
	const uint ADDR_NONE = cast(int)-1;
	const ushort PORT_ANY = 0;
	
	
	AddressFamily addressFamily()
	{
		return AddressFamily.INET;
	}
	
	
	ushort port()
	{
		return ntohs(sin.sin_port);
	}
	
	
	uint addr()
	{
		return ntohl(sin.sin_addr);
	}
	
	
	//-port- can be PORT_ANY
	//-addr- is an IP address or host name
	this(char[] addr, ushort port)
	{
		uint uiaddr = parse(addr);
		if(ADDR_NONE == uiaddr)
		{
			InternetHost ih = new InternetHost;
			if(!ih.getHostByName(addr))
				throw new AddressException("Invalid internet address.");
			uiaddr = ih.addrList[0];
		}
		sin.sin_addr = htonl(uiaddr);
		sin.sin_port = htons(port);
	}
	
	
	this(uint addr, ushort port)
	{
		sin.sin_addr = htonl(addr);
		sin.sin_port = htons(port);
	}
	
	
	this(ushort port)
	{
		sin.sin_addr = 0; //any, "0.0.0.0"
		sin.sin_port = htons(port);
	}
	
	
	char[] toAddrString()
	{
		return std.string.toString(inet_ntoa(sin.sin_addr)).dup;
	}
	
	
	char[] toPortString()
	{
		return std.string.toString(port());
	}
	
	
	char[] toString()
	{
		return toAddrString() ~ ":" ~ toPortString();
	}
	
	
	//-addr- is an IP address in the format "a.b.c.d"
	//returns ADDR_NONE on failure
	static uint parse(char[] addr)
	{
		return ntohl(inet_addr(std.string.toStringz(addr)));
	}
}


unittest
{
	InternetAddress ia = new InternetAddress("63.105.9.61", 80);
	assert(ia.toString() == "63.105.9.61:80");
}


class SocketAcceptException: SocketException
{
	this(char[] msg)
	{
		super(msg);
	}
}


enum SocketShutdown: int
{
	RECEIVE =  0,
	SEND =     1,
	BOTH =     2,
}


enum SocketFlags: int
{
	NONE =           0,
	OOB =            0x1, //out of band
	PEEK =           0x02, //only for receiving
	DONTROUTE =      0x04, //only for sending
}


struct timeval
{
	// D interface
	int seconds;
	int microseconds;
	
	// C interface
	deprecated
	{
		alias seconds tv_sec;
		alias microseconds tv_usec;
	}
}


//a set of sockets for Socket.select()
class SocketSet
{
	private:
	uint nbytes; //Win32: excludes uint.sizeof "count"
	byte* buf;
	
	
	version(Win32)
	{
		uint count()
		{
			return *(cast(uint*)buf);
		}
		
		
		void count(int setter)
		{
			*(cast(uint*)buf) = setter;
		}
		
		
		socket_t* first()
		{
			return cast(socket_t*)(buf + uint.sizeof);
		}
	}
	else version(linux)
	{
		import std.intrinsic;
		
		
		uint nfdbits;
		
		
		uint fdelt(socket_t s)
		{
			return cast(uint)s / nfdbits;
		}
		
		
		uint fdmask(socket_t s)
		{
			return 1 << cast(uint)s % nfdbits;
		}
		
		
		uint* first()
		{
			return cast(uint*)buf;
		}
	}
	
	
	public:
	this(uint max)
	{
		version(Win32)
		{
			nbytes = max * socket_t.sizeof;
			buf = new byte[nbytes + uint.sizeof];
			count = 0;
		}
		else version(linux)
		{
			if(max <= 32)
				nbytes = 32 * uint.sizeof;
			else
				nbytes = max * uint.sizeof;
			buf = new byte[nbytes];
			nfdbits = nbytes * 8;
			//clear(); //new initializes to 0
		}
		else
		{
			static assert(0);
		}
	}
	
	
	this()
	{
		version(Win32)
		{
			this(64);
		}
		else version(linux)
		{
			this(32);
		}
		else
		{
			static assert(0);
		}
	}
	
	
	void reset()
	{
		version(Win32)
		{
			count = 0;
		}
		else version(linux)
		{
			buf[0 .. nbytes] = 0;
		}
		else
		{
			static assert(0);
		}
	}
	
	
	void add(socket_t s)
	in
	{
		version(Win32)
		{
			assert(count < max); //added too many sockets; specify a higher max in the constructor
		}
	}
	body
	{
		version(Win32)
		{
			uint c = count;
			first[c] = s;
			count = c + 1;
		}
		else version(linux)
		{
			bts(cast(uint*)&first[fdelt(s)], cast(uint)s % nfdbits);
		}
		else
		{
			static assert(0);
		}
	}
	
	
	void add(Socket s)
	{
		add(s.sock);
	}
	
	
	void remove(socket_t s)
	{
		version(Win32)
		{
			uint c = count;
			socket_t* start = first;
			socket_t* stop = start + c;
			
			for(; start != stop; start++)
			{
				if(*start == s)
					goto found;
			}
			return; //not found
			
			found:
			for(++start; start != stop; start++)
			{
				*(start - 1) = *start;
			}
			
			count = c - 1;
		}
		else version(linux)
		{
			btr(cast(uint*)&first[fdelt(s)], cast(uint)s % nfdbits);
		}
		else
		{
			static assert(0);
		}
	}
	
	
	void remove(Socket s)
	{
		remove(s.sock);
	}
	
	
	int isSet(socket_t s)
	{
		version(Win32)
		{
			socket_t* start = first;
			socket_t* stop = start + count;
			
			for(; start != stop; start++)
			{
				if(*start == s)
					return true;
			}
			return false;
		}
		else version(linux)
		{
			return bt(cast(uint*)&first[fdelt(s)], cast(uint)s % nfdbits);
		}
		else
		{
			static assert(0);
		}
	}
	
	
	int isSet(Socket s)
	{
		return isSet(s.sock);
	}
	
	
	uint max() //max sockets that can be added, like FD_SETSIZE
	{
		return nbytes / socket_t.sizeof;
	}
	
	
	fd_set* toFd_set()
	{
		return cast(fd_set*)buf;
	}
}


enum SocketOptionLevel: int
{
	SOCKET =  0xFFFF, //different source 1
	IP =      0,
	TCP =     6,
	UDP =     17,
}


struct linger
{
	// D interface
	ushort on;
	ushort time;
	
	// C interface
	deprecated
	{
		alias on l_onoff;
		alias time l_linger;
	}
}


version(Win32)
{
	enum SocketOption: int
	{
		DEBUG =      0x1,
		BROADCAST =  0x20,
		REUSEADDR =  0x4,
		LINGER =     0x80,
		OOBINLINE =  0x100,
		SNDBUF =     0x1001,
		RCVBUF =     0x1002,
		KEEPALIVE =  0x8,
		DONTROUTE =  0x10,
		
		// SocketOptionLevel.TCP:
		TCP_NODELAY = 1,
	}
}
else version(linux)
{
	enum SocketOption: int
	{
		DEBUG =      1,
		BROADCAST =  6,
		REUSEADDR =  2,
		LINGER =     13,
		OOBINLINE =  10,
		SNDBUF =     7,
		RCVBUF =     8,
		ACCEPTCONN = 30,
		DONTROUTE =  5,
		
		// SocketOptionLevel.TCP:
		TCP_NODELAY = 1,
	}
}
else
{
	static assert(0);
}


class Socket
{
	private:
	socket_t sock;
	AddressFamily _family;
	
	version(Win32)
		bit _blocking = false;
	
	
	this(socket_t sock)
	{
		this.sock = sock;
	}
	
	
	public:
	this(AddressFamily af, SocketType type, ProtocolType protocol)
	{
		sock = socket(af, type, protocol);
		if(sock == sock.init)
			throw new SocketException("Unable to create socket.");
		_family = af;
	}
	
	
	// A single protocol exists to support this socket type within the
	// protocol family, so the ProtocolType is assumed.
	this(AddressFamily af, SocketType type)
	{
		this(af, type, cast(ProtocolType)0); // Pseudo protocol number.
	}
	
	
	~this()
	{
		close();
	}
	
	
	//get underlying socket handle
	socket_t handle()
	{
		return sock;
	}
	
	
	override char[] toString()
	{
		return "Socket";
	}
	
	
	//getter
	bit blocking()
	{
		version(Win32)
		{
			return _blocking;
		}
		else version(BsdSockets)
		{
			return !(fcntl(handle, F_GETFL, 0) & O_NONBLOCK);
		}
	}
	
	
	//setter
	void blocking(bit byes)
	{
		version(Win32)
		{
			uint num = !byes;
			if(SOCKET_ERROR == ioctlsocket(sock, FIONBIO, &num))
				goto err;
			_blocking = byes;
		}
		else version(BsdSockets)
		{
			int x = fcntl(handle, F_GETFL, 0);
			if(byes)
				x &= ~O_NONBLOCK;
			else
				x |= O_NONBLOCK;
			if(SOCKET_ERROR == fcntl(sock, F_SETFL, x))
				goto err;
		}
		return; //success
		
		err:
		throw new SocketException("Unable to set socket blocking.");
	}
	
	
	AddressFamily addressFamily()
	{
		return _family;
	}
	
	
	bit isAlive()
	{
		int type, typesize = type.sizeof;
		return !getsockopt(sock, SOL_SOCKET, SO_TYPE, cast(char*)type, &typesize);
	}
	
	
	void bind(Address addr)
	{
		if(SOCKET_ERROR == .bind(sock, addr.name(), addr.nameLen()))
			throw new SocketException("Unable to bind socket.");
	}
	
	
	void connect(Address to)
	{
		if(SOCKET_ERROR == .connect(sock, to.name(), to.nameLen()))
		{
			if(!blocking)
			{
				version(Win32)
				{
					if(WSAEWOULDBLOCK == WSAGetLastError())
						return;
				}
				else version(linux)
				{
					if(EINPROGRESS == getErrno())
						return;
				}
				else
				{
					static assert(0);
				}
			}
			throw new SocketException("Unable to connect socket.");
		}
	}
	
	
	//need to bind() first
	void listen(int backlog)
	{
		if(SOCKET_ERROR == .listen(sock, backlog))
			throw new SocketException("Unable to listen on socket.");
	}
	
	
	Socket accept()
	{
		socket_t newsock = .accept(sock, null, null);
		if(INVALID_SOCKET == newsock)
			throw new SocketAcceptException("Unable to accept socket connection.");
		Socket newSocket = new Socket(newsock);
		version(Win32)
			newSocket._blocking = _blocking; //inherits blocking mode
		newSocket._family = _family; //same family
		return newSocket;
	}
	
	
	void shutdown(SocketShutdown how)
	{
		.shutdown(sock, cast(int)how);
	}
	
	
	//calling shutdown() before this is recommended
	//for connection-oriented sockets
	void close()
	{
		version(Win32)
		{
			.closesocket(sock);
		}
		else version(BsdSockets)
		{
			.close(sock);
		}
		sock = sock.init;
	}
	
	
	private Address newFamilyObject()
	{
		Address result;
		switch(_family)
		{
			case AddressFamily.INET:
				result = new InternetAddress;
				break;
			
			default:
				result = new UnknownAddress;
		}
		return result;
	}
	
	
	Address remoteAddress()
	{
		Address addr = newFamilyObject();
		int nameLen = addr.nameLen();
		if(SOCKET_ERROR == .getpeername(sock, addr.name(), &nameLen))
			throw new SocketException("Unable to obtain remote socket address.");
		assert(addr.addressFamily() == _family);
		return addr;
	}
	
	
	Address localAddress()
	{
		Address addr = newFamilyObject();
		int nameLen = addr.nameLen();
		if(SOCKET_ERROR == .getsockname(sock, addr.name(), &nameLen))
			throw new SocketException("Unable to obtain local socket address.");
		assert(addr.addressFamily() == _family);
		return addr;
	}
	
	
	const int ERROR = SOCKET_ERROR;
	
	
	//returns number of bytes actually sent, or -1 on error
	int send(void[] buf, SocketFlags flags)
	{
		int sent = .send(sock, buf, buf.length, cast(int)flags);
		return sent;
	}
	
	
	int send(void[] buf)
	{
		return send(buf, SocketFlags.NONE);
	}
	
	
	int sendTo(void[] buf, SocketFlags flags, Address to)
	{
		int sent = .sendto(sock, buf, buf.length, cast(int)flags, to.name(), to.nameLen());
		return sent;
	}
	
	
	int sendTo(void[] buf, Address to)
	{
		return sendTo(buf, SocketFlags.NONE, to);
	}
	
	
	//assumes you connect()ed
	int sendTo(void[] buf, SocketFlags flags)
	{
		int sent = .sendto(sock, buf, buf.length, cast(int)flags, null, 0);
		return sent;
	}
	
	
	//assumes you connect()ed
	int sendTo(void[] buf)
	{
		return sendTo(buf, SocketFlags.NONE);
	}
	
	
	//returns number of bytes actually received, 0 on connection closure, or -1 on error
	int receive(void[] buf, SocketFlags flags)
	{
		if(!buf.length) //return 0 and don't think the connection closed
			return 0;
		int read = .recv(sock, buf, buf.length, cast(int)flags);
		// if(!read) //connection closed
		return read;
	}
	
	
	int receive(void[] buf)
	{
		return receive(buf, SocketFlags.NONE);
	}
	
	
	int receiveFrom(void[] buf, SocketFlags flags, out Address from)
	{
		if(!buf.length) //return 0 and don't think the connection closed
			return 0;
		from = newFamilyObject();
		int nameLen = from.nameLen();
		int read = .recvfrom(sock, buf, buf.length, cast(int)flags, from.name(), &nameLen);
		assert(from.addressFamily() == _family);
		// if(!read) //connection closed
		return read;
	}
	
	
	int receiveFrom(void[] buf, out Address from)
	{
		return receiveFrom(buf, SocketFlags.NONE, from);
	}
	
	
	//assumes you connect()ed
	int receiveFrom(void[] buf, SocketFlags flags)
	{
		if(!buf.length) //return 0 and don't think the connection closed
			return 0;
		int read = .recvfrom(sock, buf, buf.length, cast(int)flags, null, null);
		// if(!read) //connection closed
		return read;
	}
	
	
	//assumes you connect()ed
	int receiveFrom(void[] buf)
	{
		return receiveFrom(buf, SocketFlags.NONE);
	}
	
	
	//returns the length, in bytes, of the actual result - very different from getsockopt()
	int getOption(SocketOptionLevel level, SocketOption option, void[] result)
	{
		int len = result.length;
		if(SOCKET_ERROR == .getsockopt(sock, cast(int)level, cast(int)option, result, &len))
			throw new SocketException("Unable to get socket option.");
		return len;
	}
	
	
	// Common case for integer and boolean options.
	int getOption(SocketOptionLevel level, SocketOption option, out int result)
	{
		return getOption(level, option, (&result)[0 .. int.sizeof]);
	}
	
	
	void setOption(SocketOptionLevel level, SocketOption option, void[] value)
	{
		if(SOCKET_ERROR == .setsockopt(sock, cast(int)level, cast(int)option, value, value.length))
			throw new SocketException("Unable to set socket option.");
	}
	
	
	// Common case for integer and boolean options.
	void setOption(SocketOptionLevel level, SocketOption option, int value)
	{
		setOption(level, option, (&value)[0 .. int.sizeof]);
	}
	
	
	//SocketSet's updated to include only those sockets which an event occured
	//returns the number of events, 0 on timeout, or -1 on interruption
	//for a connect()ing socket, writeability means connected
	//for a listen()ing socket, readability means listening
	//Winsock: possibly internally limited to 64 sockets per set
	static int select(SocketSet checkRead, SocketSet checkWrite, SocketSet checkError, timeval* tv)
	in
	{
		//make sure none of the SocketSet's are the same object
		if(checkRead)
		{
			assert(checkRead !== checkWrite);
			assert(checkRead !== checkError);
		}
		if(checkWrite)
		{
			assert(checkWrite !== checkError);
		}
	}
	body
	{
		fd_set* fr, fw, fe;
		
		version(Win32)
		{
			//Windows has a problem with empty fd_set's that aren't null
			fr = (checkRead && checkRead.count()) ? checkRead.toFd_set() : null;
			fw = (checkWrite && checkWrite.count()) ? checkWrite.toFd_set() : null;
			fe = (checkError && checkError.count()) ? checkError.toFd_set() : null;
		}
		else
		{
			fr = checkRead ? checkRead.toFd_set() : null;
			fw = checkWrite ? checkWrite.toFd_set() : null;
			fe = checkError ? checkError.toFd_set() : null;
		}
		
		int result = .select(socket_t.max - 1, fr, fw, fe, tv);
		
		version(Win32)
		{
			if(SOCKET_ERROR == result && WSAGetLastError() == WSAEINTR)
				return -1;
		}
		else version(linux)
		{
			if(SOCKET_ERROR == result && getErrno() == EINTR)
				return -1;
		}
		else
		{
			static assert(0);
		}
		
		if(SOCKET_ERROR == result)
			throw new SocketException("Socket select error.");
		
		return result;
	}
	
	
	static int select(SocketSet checkRead, SocketSet checkWrite, SocketSet checkError, int microseconds)
	{
		timeval tv;
		tv.seconds = 0;
		tv.microseconds = microseconds;
		return select(checkRead, checkWrite, checkError, &tv);
	}
	
	
	//maximum timeout
	static int select(SocketSet checkRead, SocketSet checkWrite, SocketSet checkError)
	{
		return select(checkRead, checkWrite, checkError, null);
	}
	
	
	/+
	bit poll(events)
	{
		int WSAEventSelect(socket_t s, WSAEVENT hEventObject, int lNetworkEvents); // Winsock 2 ?
		int poll(pollfd* fds, int nfds, int timeout); // Unix ?
	}
	+/
}


class TcpSocket: Socket
{
	this()
	{
		super(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
	}
	
	
	//shortcut
	this(InternetAddress connectTo)
	{
		this();
		connect(connectTo);
	}
}


class UdpSocket: Socket
{
	this()
	{
		super(AddressFamily.INET, SocketType.DGRAM, ProtocolType.UDP);
	}
}

