/*
	Copyright (C) 2004-2005 Christopher E. Miller
	
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
	
	socket.d 1.3
	Jan 2005
	
	Thanks to Benjamin Herr for his assistance.
*/

module std.socket;

private import std.string, std.stdint, std.c.string, std.c.stdlib;


version(linux)
{
	version = BsdSockets;
}

version(Win32)
{
	private import std.c.windows.windows, std.c.windows.winsock;
	private alias std.c.windows.winsock.timeval _ctimeval;
	
	typedef SOCKET socket_t = INVALID_SOCKET;
	private const int _SOCKET_ERROR = SOCKET_ERROR;
	
	
	private int _lasterr()
	{
		return WSAGetLastError();
	}
}
else version(BsdSockets)
{
	version(linux)
	{
		private import std.c.linux.linux, std.c.linux.socket;
		private alias std.c.linux.linux.timeval _ctimeval;
	}
	
	typedef int32_t socket_t = -1;
	private const int _SOCKET_ERROR = -1;
	
	
	private int _lasterr()
	{
		return getErrno();
	}
}
else
{
	static assert(0); // No socket support yet.
}


class SocketException: Exception
{
	int errorCode; // Platform-specific error code.
	
	
	this(char[] msg, int err = 0)
	{
		errorCode = err;
		
		version(linux)
		{
			if(errorCode > 0)
			{
				char* cs;
				size_t len;
				
				cs = strerror(errorCode);
				len = strlen(cs);
				
				if(cs[len - 1] == '\n')
					len--;
				if(cs[len - 1] == '\r')
					len--;
				msg = msg ~ ": " ~ cs[0 .. len];
			}
		}
		
		super(msg);
	}
}


static this()
{
	version(Win32)
	{
		WSADATA wd;
		
		// Winsock will still load if an older version is present.
		// The version is just a request.
		int val;
		val = WSAStartup(0x2020, &wd);
		if(val) // Request Winsock 2.2 for IPv6.
			throw new SocketException("Unable to initialize socket library", val);
	}
}


static ~this()
{
	version(Win32)
	{
		WSACleanup();
	}
}


enum AddressFamily: int
{
	UNSPEC =     AF_UNSPEC,
	UNIX =       AF_UNIX,
	INET =       AF_INET,
	IPX =        AF_IPX,
	APPLETALK =  AF_APPLETALK,
	INET6 =      AF_INET6,
}


enum SocketType: int
{
	STREAM =     SOCK_STREAM,
	DGRAM =      SOCK_DGRAM,
	RAW =        SOCK_RAW,
	RDM =        SOCK_RDM,
	SEQPACKET =  SOCK_SEQPACKET,
}


enum ProtocolType: int
{
	IP =    IPPROTO_IP,
	ICMP =  IPPROTO_ICMP,
	IGMP =  IPPROTO_IGMP,
	GGP =   IPPROTO_GGP,
	TCP =   IPPROTO_TCP,
	PUP =   IPPROTO_PUP,
	UDP =   IPPROTO_UDP,
	IDP =   IPPROTO_IDP,
	IPV6 =  IPPROTO_IPV6,
}


class Protocol
{
	ProtocolType type;
	char[] name;
	char[][] aliases;
	
	
	void populate(protoent* proto)
	{
		type = cast(ProtocolType)proto.p_proto;
		name = std.string.toString(proto.p_name).dup;
		
		int i;
		for(i = 0;; i++)
		{
			if(!proto.p_aliases[i])
				break;
		}
		
		if(i)
		{
			aliases = new char[][i];
			for(i = 0; i != aliases.length; i++)
			{
				aliases[i] = std.string.toString(proto.p_aliases[i]).dup;
			}
		}
		else
		{
			aliases = null;
		}
	}
	
	
	bool getProtocolByName(char[] name)
	{
		protoent* proto;
		proto = getprotobyname(toStringz(name));
		if(!proto)
			return false;
		populate(proto);
		return true;
	}
	
	
	// Same as getprotobynumber().
	bool getProtocolByType(ProtocolType type)
	{
		protoent* proto;
		proto = getprotobynumber(type);
		if(!proto)
			return false;
		populate(proto);
		return true;
	}
}


unittest
{
	Protocol proto = new Protocol;
	assert(proto.getProtocolByType(ProtocolType.TCP));
	printf("About protocol TCP:\n\tName: %.*s\n", proto.name);
	foreach(char[] s; proto.aliases)
	{
		printf("\tAlias: %.*s\n", s);
	}
}


class Service
{
	char[] name;
	char[][] aliases;
	ushort port;
	char[] protocolName;
	
	
	void populate(servent* serv)
	{
		name = std.string.toString(serv.s_name).dup;
		port = ntohs(serv.s_port);
		protocolName = std.string.toString(serv.s_proto).dup;
		
		int i;
		for(i = 0;; i++)
		{
			if(!serv.s_aliases[i])
				break;
		}
		
		if(i)
		{
			aliases = new char[][i];
			for(i = 0; i != aliases.length; i++)
			{
				aliases[i] = std.string.toString(serv.s_aliases[i]).dup;
			}
		}
		else
		{
			aliases = null;
		}
	}
	
	
	bool getServiceByName(char[] name, char[] protocolName)
	{
		servent* serv;
		serv = getservbyname(toStringz(name), toStringz(protocolName));
		if(!serv)
			return false;
		populate(serv);
		return true;
	}
	
	
	// Any protocol name will be matched.
	bool getServiceByName(char[] name)
	{
		servent* serv;
		serv = getservbyname(toStringz(name), null);
		if(!serv)
			return false;
		populate(serv);
		return true;
	}
	
	
	bool getServiceByPort(ushort port, char[] protocolName)
	{
		servent* serv;
		serv = getservbyport(port, toStringz(protocolName));
		if(!serv)
			return false;
		populate(serv);
		return true;
	}
	
	
	// Any protocol name will be matched.
	bool getServiceByPort(ushort port)
	{
		servent* serv;
		serv = getservbyport(port, null);
		if(!serv)
			return false;
		populate(serv);
		return true;
	}
}


unittest
{
	Service serv = new Service;
	if(serv.getServiceByName("epmap", "tcp"))
	{
		printf("About service epmap:\n\tService: %.*s\n\tPort: %d\n\tProtocol: %.*s\n",
			serv.name, serv.port, serv.protocolName);
		foreach(char[] s; serv.aliases)
		{
			printf("\tAlias: %.*s\n", s);
		}
	}
	else
	{
		printf("No service for epmap.\n");
	}
}


class HostException: Exception
{
	int errorCode;
	
	
	this(char[] msg, int err = 0)
	{
		errorCode = err;
		super(msg);
	}
}


class InternetHost
{
	char[] name;
	char[][] aliases;
	uint32_t[] addrList;
	
	
	void validHostent(hostent* he)
	{
		if(he.h_addrtype != cast(int)AddressFamily.INET || he.h_length != 4)
			throw new HostException("Address family mismatch", _lasterr());
	}
	
	
	void populate(hostent* he)
	{
		int i;
		char* p;
		
		name = std.string.toString(he.h_name).dup;
		
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
				aliases[i] = std.string.toString(he.h_aliases[i]).dup;
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
			addrList = new uint32_t[i];
			for(i = 0; i != addrList.length; i++)
			{
				addrList[i] = ntohl(*(cast(uint32_t*)he.h_addr_list[i]));
			}
		}
		else
		{
			addrList = null;
		}
	}
	
	
	bool getHostByName(char[] name)
	{
		hostent* he = gethostbyname(toStringz(name));
		if(!he)
			return false;
		validHostent(he);
		populate(he);
		return true;
	}
	
	
	bool getHostByAddr(uint addr)
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
	bool getHostByAddr(char[] addr)
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


class InternetAddress: Address
{
	protected:
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
	const uint ADDR_ANY = INADDR_ANY;
	const uint ADDR_NONE = INADDR_NONE;
	const ushort PORT_ANY = 0;
	
	
	AddressFamily addressFamily()
	{
		return cast(AddressFamily)AddressFamily.INET;
	}
	
	
	ushort port()
	{
		return ntohs(sin.sin_port);
	}
	
	
	uint addr()
	{
		return ntohl(sin.sin_addr.s_addr);
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
				//throw new AddressException("Invalid internet address");
				throw new AddressException("Unable to resolve host '" ~ addr ~ "'");
			uiaddr = ih.addrList[0];
		}
		sin.sin_addr.s_addr = htonl(uiaddr);
		sin.sin_port = htons(port);
	}
	
	
	this(uint addr, ushort port)
	{
		sin.sin_addr.s_addr = htonl(addr);
		sin.sin_port = htons(port);
	}
	
	
	this(ushort port)
	{
		sin.sin_addr.s_addr = 0; //any, "0.0.0.0"
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
	this(char[] msg, int err = 0)
	{
		super(msg, err);
	}
}


enum SocketShutdown: int
{
	RECEIVE =  SD_RECEIVE,
	SEND =     SD_SEND,
	BOTH =     SD_RECEIVE,
}


enum SocketFlags: int
{
	NONE =       0,
	
	OOB =        MSG_OOB, //out of band
	PEEK =       MSG_PEEK, //only for receiving
	DONTROUTE =  MSG_DONTROUTE, //only for sending
}


extern(C) struct timeval
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
	uint nbytes; // Win32: excludes uint.sizeof "count".
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
	else version(BsdSockets)
	{
		int maxfd = -1;
		
		
		socket_t* first()
		{
			return cast(socket_t*)buf;
		}
	}
	
	
	fd_set* _fd_set()
	{
		return cast(fd_set*)buf;
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
		else version(BsdSockets)
		{
			nbytes = max / NFDBITS * socket_t.sizeof;
			if(max % NFDBITS)
				nbytes += socket_t.sizeof;
			buf = new byte[nbytes]; // new initializes to 0.
		}
	}
	
	
	this()
	{
		this(FD_SETSIZE);
	}
	
	
	void reset()
	{
		version(Win32)
		{
			count = 0;
		}
		else version(BsdSockets)
		{
			maxfd = -1;
			buf[0 .. nbytes] = 0;
		}
	}
	
	
	void add(socket_t s)
	in
	{
		// Make sure too many sockets don't get added.
		version(Win32)
		{
			assert(count < max);
		}
		else version(BsdSockets)
		{
			assert(FDELT(s) < nbytes / socket_t.sizeof);
		}
	}
	body
	{
		FD_SET(s, _fd_set);
		
		version(BsdSockets)
		{
			if(s > maxfd)
				maxfd = s;
		}
	}
	
	
	void add(Socket s)
	{
		add(s.sock);
	}
	
	
	void remove(socket_t s)
	{
		FD_CLR(s, _fd_set);
	}
	
	
	void remove(Socket s)
	{
		remove(s.sock);
	}
	
	
	int isSet(socket_t s)
	{
		return FD_ISSET(s, _fd_set);
	}
	
	
	int isSet(Socket s)
	{
		return isSet(s.sock);
	}
	
	
	// Max sockets that can be added, like FD_SETSIZE.
	uint max()
	{
		version(Win32)
		{
			return nbytes / socket_t.sizeof;
		}
		else version(BsdSockets)
		{
			return nbytes / socket_t.sizeof * NFDBITS;
		}
		else
		{
			static assert(0);
		}
	}
	
	
	fd_set* toFd_set()
	{
		return _fd_set;
	}
	
	
	int selectn()
	{
		version(Win32)
		{
			return 0;
		}
		else version(BsdSockets)
		{
			return maxfd + 1;
		}
	}
}


enum SocketOptionLevel: int
{
	SOCKET =  SOL_SOCKET,
	IP =      ProtocolType.IP,
	ICMP =    ProtocolType.ICMP,
	IGMP =    ProtocolType.IGMP,
	GGP =     ProtocolType.GGP,
	TCP =     ProtocolType.TCP,
	PUP =     ProtocolType.PUP,
	UDP =     ProtocolType.UDP,
	IDP =     ProtocolType.IDP,
	IPV6 =    ProtocolType.IPV6,
}


extern(C) struct linger
{
	// D interface
	version(Win32)
	{
		uint16_t on;
		uint16_t time;
	}
	else version(BsdSockets)
	{
		int32_t on;
		int32_t time;
	}
	
	// C interface
	deprecated
	{
		alias on l_onoff;
		alias time l_linger;
	}
}


enum SocketOption: int
{
	DEBUG =                SO_DEBUG,
	BROADCAST =            SO_BROADCAST,
	REUSEADDR =            SO_REUSEADDR,
	LINGER =               SO_LINGER,
	OOBINLINE =            SO_OOBINLINE,
	SNDBUF =               SO_SNDBUF,
	RCVBUF =               SO_RCVBUF,
	DONTROUTE =            SO_DONTROUTE,
	
	// SocketOptionLevel.TCP:
	TCP_NODELAY =          .TCP_NODELAY,
	
	// SocketOptionLevel.IPV6:
	IPV6_UNICAST_HOPS =    .IPV6_UNICAST_HOPS,
	IPV6_MULTICAST_IF =    .IPV6_MULTICAST_IF,
	IPV6_MULTICAST_LOOP =  .IPV6_MULTICAST_LOOP,
	IPV6_JOIN_GROUP =      .IPV6_JOIN_GROUP,
	IPV6_LEAVE_GROUP =     .IPV6_LEAVE_GROUP,
}


class Socket
{
	private:
	socket_t sock;
	AddressFamily _family;
	
	version(Win32)
		bool _blocking = false;
	
	
	// For use with accepting().
	protected this()
	{
	}
	
	
	public:
	this(AddressFamily af, SocketType type, ProtocolType protocol)
	{
		sock = cast(socket_t)socket(af, type, protocol);
		if(sock == socket_t.init)
			throw new SocketException("Unable to create socket", _lasterr());
		_family = af;
	}
	
	
	// A single protocol exists to support this socket type within the
	// protocol family, so the ProtocolType is assumed.
	this(AddressFamily af, SocketType type)
	{
		this(af, type, cast(ProtocolType)0); // Pseudo protocol number.
	}
	
	
	this(AddressFamily af, SocketType type, char[] protocolName)
	{
		protoent* proto;
		proto = getprotobyname(toStringz(protocolName));
		if(!proto)
			throw new SocketException("Unable to find the protocol", _lasterr());
		this(af, type, cast(ProtocolType)proto.p_proto);
	}
	
	
	~this()
	{
		close();
	}
	
	
	// Get underlying socket handle.
	socket_t handle() // getter
	{
		return sock;
	}
	
	
	bool blocking() // getter
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
	
	
	void blocking(bool byes) // setter
	{
		version(Win32)
		{
			uint num = !byes;
			if(_SOCKET_ERROR == ioctlsocket(sock, FIONBIO, &num))
				goto err;
			_blocking = byes;
		}
		else version(BsdSockets)
		{
			int x = fcntl(sock, F_GETFL, 0);
			if(-1 == x)
				goto err;
			if(byes)
				x &= ~O_NONBLOCK;
			else
				x |= O_NONBLOCK;
			if(-1 == fcntl(sock, F_SETFL, x))
				goto err;
		}
		return; // Success.
		
		err:
		throw new SocketException("Unable to set socket blocking", _lasterr());
	}
	
	
	AddressFamily addressFamily() // getter
	{
		return _family;
	}
	
	
	bool isAlive() // getter
	{
		int type, typesize = type.sizeof;
		return !getsockopt(sock, SOL_SOCKET, SO_TYPE, cast(char*)&type, &typesize);
	}
	
	
	void bind(Address addr)
	{
		if(_SOCKET_ERROR == .bind(sock, addr.name(), addr.nameLen()))
			throw new SocketException("Unable to bind socket", _lasterr());
	}
	
	
	void connect(Address to)
	{
		if(_SOCKET_ERROR == .connect(sock, to.name(), to.nameLen()))
		{
			int err;
			err = _lasterr();
			
			if(!blocking)
			{
				version(Win32)
				{
					if(WSAEWOULDBLOCK == err)
						return;
				}
				else version(linux)
				{
					if(EINPROGRESS == err)
						return;
				}
				else
				{
					static assert(0);
				}
			}
			throw new SocketException("Unable to connect socket", err);
		}
	}
	
	
	//need to bind() first
	void listen(int backlog)
	{
		if(_SOCKET_ERROR == .listen(sock, backlog))
			throw new SocketException("Unable to listen on socket", _lasterr());
	}
	
	
	// Override to use a derived class.
	// The returned socket's handle must not be set.
	protected Socket accepting()
	{
		return new Socket;
	}
	
	
	Socket accept()
	{
		socket_t newsock;
		//newsock = cast(socket_t).accept(sock, null, null); // DMD 0.101 error: found '(' when expecting ';' following 'statement
		alias .accept topaccept;
		newsock = cast(socket_t)topaccept(sock, null, null);
		if(socket_t.init == newsock)
			throw new SocketAcceptException("Unable to accept socket connection", _lasterr());
		
		Socket newSocket;
		try
		{
			newSocket = accepting();
			assert(newSocket.sock == socket_t.init);
			
			newSocket.sock = newsock;
			version(Win32)
				newSocket._blocking = _blocking; //inherits blocking mode
			newSocket._family = _family; //same family
		}
		catch(Object o)
		{
			_close(newsock);
			throw o;
		}
		
		return newSocket;
	}
	
	
	void shutdown(SocketShutdown how)
	{
		.shutdown(sock, cast(int)how);
	}
	
	
	private static void _close(socket_t sock)
	{
		version(Win32)
		{
			.closesocket(sock);
		}
		else version(BsdSockets)
		{
			.close(sock);
		}
	}
	
	
	//calling shutdown() before this is recommended
	//for connection-oriented sockets
	void close()
	{
		_close(sock);
		sock = socket_t.init;
	}
	
	
	private Address newFamilyObject()
	{
		Address result;
		switch(_family)
		{
			case cast(AddressFamily)AddressFamily.INET:
				result = new InternetAddress;
				break;
			
			default:
				result = new UnknownAddress;
		}
		return result;
	}
	
	
	// Returns the local machine's host name. Idea from mango.
	static char[] hostName() // getter
	{
		char[256] result; // Host names are limited to 255 chars.
		if(_SOCKET_ERROR == .gethostname(result, result.length))
			throw new SocketException("Unable to obtain host name", _lasterr());
		return std.string.toString(cast(char*)result).dup;
	}
	
	
	Address remoteAddress()
	{
		Address addr = newFamilyObject();
		int nameLen = addr.nameLen();
		if(_SOCKET_ERROR == .getpeername(sock, addr.name(), &nameLen))
			throw new SocketException("Unable to obtain remote socket address", _lasterr());
		assert(addr.addressFamily() == _family);
		return addr;
	}
	
	
	Address localAddress()
	{
		Address addr = newFamilyObject();
		int nameLen = addr.nameLen();
		if(_SOCKET_ERROR == .getsockname(sock, addr.name(), &nameLen))
			throw new SocketException("Unable to obtain local socket address", _lasterr());
		assert(addr.addressFamily() == _family);
		return addr;
	}
	
	
	const int ERROR = _SOCKET_ERROR;
	
	
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
		if(_SOCKET_ERROR == .getsockopt(sock, cast(int)level, cast(int)option, result, &len))
			throw new SocketException("Unable to get socket option", _lasterr());
		return len;
	}
	
	
	// Common case for integer and boolean options.
	int getOption(SocketOptionLevel level, SocketOption option, out int32_t result)
	{
		return getOption(level, option, (&result)[0 .. 1]);
	}
	
	
	int getOption(SocketOptionLevel level, SocketOption option, out linger result)
	{
		//return getOption(cast(SocketOptionLevel)SocketOptionLevel.SOCKET, SocketOption.LINGER, (&result)[0 .. 1]);
		return getOption(level, option, (&result)[0 .. 1]); 
	}
	
	
	void setOption(SocketOptionLevel level, SocketOption option, void[] value)
	{
		if(_SOCKET_ERROR == .setsockopt(sock, cast(int)level, cast(int)option, value, value.length))
			throw new SocketException("Unable to set socket option", _lasterr());
	}
	
	
	// Common case for integer and boolean options.
	void setOption(SocketOptionLevel level, SocketOption option, int32_t value)
	{
		setOption(level, option, (&value)[0 .. 1]);
	}
	
	
	void setOption(SocketOptionLevel level, SocketOption option, linger value)
	{
		//setOption(cast(SocketOptionLevel)SocketOptionLevel.SOCKET, SocketOption.LINGER, (&value)[0 .. 1]);
		setOption(level, option, (&value)[0 .. 1]);
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
			assert(checkRead !is checkWrite);
			assert(checkRead !is checkError);
		}
		if(checkWrite)
		{
			assert(checkWrite !is checkError);
		}
	}
	body
	{
		fd_set* fr, fw, fe;
		int n = 0;
		
		version(Win32)
		{
			// Windows has a problem with empty fd_set`s that aren't null.
			fr = (checkRead && checkRead.count()) ? checkRead.toFd_set() : null;
			fw = (checkWrite && checkWrite.count()) ? checkWrite.toFd_set() : null;
			fe = (checkError && checkError.count()) ? checkError.toFd_set() : null;
		}
		else
		{
			if(checkRead)
			{
				fr = checkRead.toFd_set();
				n = checkRead.selectn();
			}
			else
			{
				fr = null;
			}
			
			if(checkWrite)
			{
				fw = checkWrite.toFd_set();
				int _n;
				_n = checkWrite.selectn();
				if(_n > n)
					n = _n;
			}
			else
			{
				fw = null;
			}
			
			if(checkError)
			{
				fe = checkError.toFd_set();
				int _n;
				_n = checkError.selectn();
				if(_n > n)
					n = _n;
			}
			else
			{
				fe = null;
			}
		}
		
		int result = .select(n, fr, fw, fe, cast(_ctimeval*)tv);
		
		version(Win32)
		{
			if(_SOCKET_ERROR == result && WSAGetLastError() == WSAEINTR)
				return -1;
		}
		else version(linux)
		{
			if(_SOCKET_ERROR == result && getErrno() == EINTR)
				return -1;
		}
		else
		{
			static assert(0);
		}
		
		if(_SOCKET_ERROR == result)
			throw new SocketException("Socket select error", _lasterr());
		
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
	bool poll(events)
	{
		int WSAEventSelect(socket_t s, WSAEVENT hEventObject, int lNetworkEvents); // Winsock 2 ?
		int poll(pollfd* fds, int nfds, int timeout); // Unix ?
	}
	+/
}


class TcpSocket: Socket
{
	this(AddressFamily family)
	{
		super(family, SocketType.STREAM, ProtocolType.TCP);
	}
	
	
	this()
	{
		this(cast(AddressFamily)AddressFamily.INET);
	}
	
	
	//shortcut
	this(Address connectTo)
	{
		this(connectTo.addressFamily());
		connect(connectTo);
	}
}


class UdpSocket: Socket
{
	this(AddressFamily family)
	{
		super(family, SocketType.DGRAM, ProtocolType.UDP);
	}
	
	
	this()
	{
		this(cast(AddressFamily)AddressFamily.INET);
	}
}

