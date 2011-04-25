// Written in the D programming language.

/*
  TODO:
  DONE Pull request for c declarations only

  DONE const(void[]) for output
  DONE ubyte[] for input
  DONE Zero copy of data (where possible)

  DONE lowercase headers

  DONE move header parsing into HTTP class

  DONE postData textPostData etc. for all cases

  DONE Threads: shutdowns from other threads/callbacks, or shutdown the entire library
           curl is thread safe by not letting curl handles be shared between threads.
	   shutdowns of the library happens at app exit
	   shutdown of curl handles happens in Curl destructors an cannot be done from 

  DONE Grand dispatch from URL only (looking at protocol) e.g. one function to handle ftp/http/... urls.
       Doesn't make sense I think. Ftp/Http/Smtp... has different semantics and too little in common.

  Is inheritance necessary (for streaming Transport... for grand url dispatch result?)

  Suggestion (foreach):
    The data transfer should happen concurrently with the foreach code. 
    The type of line is char[] or const(char)[]. 
    Similarly, there would be a byChunk interface that transfers in ubyte[] chunks.
    Also we need a head() method for the corresponding command. 

  Future improvements:

  Progress may be deprecated in the future
  Typed http headers - Johannes Pfau (waiting for std.protocol.http to be accepted)
*/

/**
Curl client functionality as provided by libcurl.

Example:

---
// Simple GET with default timeout etc.
writeln( Http.get("http://www.google.com").text ); // .headers for headers etc.

//
// GET with custom data receivers 
//
Http http = new Http("http://www.google.com");
http.onReceiveHeader = (const(char)[] key, const(char)[] value) { writeln(key ~ ": " ~ value); };
http.onReceive = (void[] data) { /+ drop +/ };
http.perform;

//
// POST with timouts
//
http.url("http://www.testing.com/test.cgi");
http.onReceive = (void[] data) { writeln(data); };
http.connectTimeout(1000);
http.dataTimeout(1000);  
http.dnsTimeout(1000);
http.postData = "The quick....";
http.perform;

//
// PUT with data senders 
//
string msg = "Hello world";
http.onSend = delegate size_t(void[] data) { 
  if (msg.empty) return 0; 
  auto m = cast(void[])msg;
  auto l = m.length;
  data[0..l] = m[0..$];  
  msg.length = 0;
  return l;
};
http.method = HttpMethod.put; // defaults to POST
http.contentLength = 11; // defaults to chunked transfer if not specified
http.perform;

// HTTPS
writeln(Http.get("https://mail.google.com").content);

// FTP
writeln(Ftp.get("ftp://ftp.digitalmars.com/sieve.ds", "./downloaded-file"));

http.method = HttpMethod.get;
http.url = "http://upload.wikimedia.org/wikipedia/commons/5/53/Wikipedia-logo-en-big.png";
http.onReceive = delegate(void[]) { };
http.onProgress = (double dltotal, double dlnow, double ultotal, double ulnow) {
  writeln("Progress ", dltotal, ", ", dlnow, ", ", ultotal, ", ", ulnow);
  return 0;
};
http.perform;
---

Source: $(PHOBOSSRC etc/_curl.d)

Copyright: Copyright Jonas Drewsen 2011-2012
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB steamwinter.com, Jonas Drewsen)
Credits:   The functionally is based on $(WEB _curl.haxx.se, libcurl)
*/
/*
         Copyright Jonas Drewsen 2011 - 2012.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module etc.curl;

import etc.c.curl;
import std.conv;  
import std.string; 
import std.regex; 
import std.stream;
import std.algorithm; 
import std.encoding;
import std.concurrency; 
import std.typecons;

version(unittest) import std.stdio;

pragma(lib, "curl");

/// An exception class for curl
class CurlException: Exception {
  /// Construct a CurlException with given error message.
  this(string msg) { super(msg); }
}

/**
    Wrapper class to provide a better interface to libcurl than using the plain C API.
    It is recommended to use the Http/Ftp... classes instead unless you need the basic 
    access to libcurl.

    Do not use an instance of Curl in two threads simultanously.
*/
private class Curl {

  static this() {
    // initialize early to prevent thread races
    if (curl_global_init(CurlGlobal.all))
      throw new Exception("Couldn't initialize libcurl");
  }
  
  static ~this() {
    curl_global_cleanup();
  }

  alias void[] outdata;
  alias ubyte[] indata;
  bool stopped;

  // A handle should not be used bu two thread simultanously
  private CURL* handle;
  private size_t delegate(outdata) _onSend; // May also return CURL_READFUNC_ABORT or CURL_READFUNC_PAUSE
  private void delegate(indata) _onReceive;
  private void delegate(const(char)[]) _onReceiveHeader;
  private CurlSeek delegate(long,CurlSeekPos) _onSeek;
  private int delegate(curl_socket_t,CurlSockType) _onSocketOption;
  private int delegate(double dltotal, double dlnow, double ultotal, double ulnow) _onProgress;

  /**
     Default constructor. Remember to set at least the $(D url)
     property before calling $(D perform())
   */
  this() {
    handle = curl_easy_init();
    stopped = false;
    CURL* curl = curl_easy_init();
    set(CurlOption.verbose, 1L); 
  }

  ~this() {
    if (!stopped)
      curl_easy_cleanup(this.handle);
  }

  private void _check(CURLcode code) {
    if (code != CurlError.ok) {
      throw new Exception(to!string(curl_easy_strerror(code)));
    }
  }

  private void throwOnStopped() {
    if (stopped) 
      throw new CurlException("Curl instance called after being cleaned up");
  }

  /** 
      Stop and invalidate this curl instance.
  */
  void cleanup() {
    throwOnStopped();
    stopped = true;
    curl_easy_cleanup(this.handle);
  }

  /**
     Pausing and continuing transfers
   */
  void pause(bool sendingPaused, bool receivingPaused) {
    throwOnStopped();
    _check(curl_easy_pause(this.handle, 
			   (sendingPaused ? CurlPause.send_cont : CurlPause.send) |
			   (receivingPaused ? CurlPause.recv_cont : CurlPause.recv)));
  }

  /**
     Set a string curl option.
     Params:
     option = A $(XREF etc.c.curl, CurlOption) as found in the curl documentation
     value = The string
   */
  void set(CURLoption option, const(char)[] value) {
    throwOnStopped();
    _check(curl_easy_setopt(this.handle, option, toStringz(value)));
  }

  /**
     Set a long curl option.
     Params:
     option = A $(XREF etc.c.curl, CurlOption) as found in the curl documentation
     value = The long
   */
  void set(CURLoption option, long value) {
    throwOnStopped();
    _check(curl_easy_setopt(this.handle, option, value));
  }

  /**
     Set a void* curl option.
     Params:
     option = A $(XREF etc.c.curl, CurlOption) as found in the curl documentation
     value = The pointer
   */
  void set(CURLoption option, void* value) {
    throwOnStopped();
    _check(curl_easy_setopt(this.handle, option, value));
  }

  /**
     Clear a pointer option
     Params:
     option = A $(XREF etc.c.curl, CurlOption) as found in the curl documentation
   */
  void clear(CURLoption option) {
    throwOnStopped();
    _check(curl_easy_setopt(this.handle, option, cast(void*)0));
  }

  /**
     perform the curl request by doing the HTTP,FTP etc. as it has
     been setup beforehand.
  */
  void perform() {
    throwOnStopped();
    _check(curl_easy_perform(this.handle));
  }

  /**
     The event handler that receives incoming data.

     Params:
     callback = the callback that recieves the ubyte[] data.
                Be sure to copy the incoming data and not store
		a slice.
     Example:
     ----
     http.onReceive = (ubyte[] data) { writeln("Got data", cast(char[])data); };
     ----
  */
  @property ref Curl onReceive(void delegate(indata) callback) {
    _onReceive = (indata id) { 
      if (stopped)
	throw new CurlException("Receive callback called on cleaned up Curl instance");
      callback(id);
    };
    set(CurlOption.file, cast(void*) this);
    set(CurlOption.writefunction, cast(void*) &Curl._receiveCallback);
    return this;
  }

  /**
     The event handler that receives incoming headers for protocols
     that uses headers

     Params:
     callback = the callback that recieves the key/value head strings.
                Make sure the callback copies the incoming params if
		it needs to store it because they are references into
		the backend and may very likely change.
     Example:
     ----
     http.onReceiveHeader = (const(char)[] key, const(char[]) value) { writeln(key, " = ", value); };
     ----
  */
  @property ref Curl onReceiveHeader(void delegate(const(char)[]) callback) {
    _onReceiveHeader = (const(char)[] od) {
      if (stopped)
	throw new CurlException("Receive header callback called on cleaned up Curl instance");
      callback(od);
    };
    set(CurlOption.writeheader, cast(void*) this);
    set(CurlOption.headerfunction, cast(void*) &Curl._receiveHeaderCallback);
    return this;
  }

  /**
     The event handler that gets called when data is needed for sending.

     Params:
     callback = the callback that has a void[] buffer to be filled
     
     Returns:
     The callback returns the number of elements in the buffer that has been filled and is ready to send.

     Example:
     ----
     string msg = "Hello world";
     http.onSend = delegate size_t(void[] data) { 
         if (msg.empty) return 0; 
         auto m = cast(void[])msg;
         auto l = m.length;
         data[0..l] = m[0..$];  
         msg.length = 0;
         return l;
     };
     ----
  */
  @property ref Curl onSend(size_t delegate(outdata) callback) {
    _onSend = (outdata od) {
      if (stopped)
	throw new CurlException("Send callback called on cleaned up Curl instance");
      return callback(od);
    };
    set(CurlOption.infile, cast(void*) this);
    set(CurlOption.readfunction, cast(void*) &Curl._sendCallback);
    return this;
  }

  /**
     The event handler that gets called when the curl backend needs to seek the 
     data to be sent.

     Params:
     callback = the callback that receives a seek offset and a seek position $(XREF etc.c.curl, CurlSeekPos)
     
     Returns:
     The callback returns the success state of the seeking $(XREF etc.c.curl, CurlSeek)

     Example:
     ----
     http.onSeek = (long p, CurlSeekPos sp) { 
        return CurlSeek.cantseek;
     };
     ----
  */
  @property ref Curl onSeek(CurlSeek delegate(long, CurlSeekPos) callback) {
    _onSeek = (long ofs, CurlSeekPos sp) { 
      if (stopped)
	throw new CurlException("Seek callback called on cleaned up Curl instance");
      return callback(ofs, sp);
    };
    set(CurlOption.seekdata, cast(void*) this);
    set(CurlOption.seekfunction, cast(void*) &Curl._seekCallback);
    return this;
  }

  /**
     The event handler that gets called when the net socket has been created but a 
     connect() call has not yet been done. This makes it possible to set misc. socket
     options.
     
     Params:
     callback = the callback that receives the socket and socket type $(XREF etc.c.curl, CurlSockType)
     
     Returns:
     Return 0 from the callback to signal success, return 1 to signal error and make curl close the socket

     Example:
     ----
     http.onSocketOption = delegate int(curl_socket_t s, CurlSockType t) { /+ do stuff +/ };
     ----
  */
  @property ref Curl onSocketOption(int delegate(curl_socket_t, CurlSockType) callback) {
    _onSocketOption = (curl_socket_t sock, CurlSockType st) {
      if (stopped)
	throw new CurlException("Socket option callback called on cleaned up Curl instance");
      return callback(sock, st);
    };
    set(CurlOption.sockoptdata, cast(void*) this);
    set(CurlOption.sockoptfunction, cast(void*) &Curl._socketOptionCallback);
    return this;
  }

  /**
     The event handler that gets called to inform of upload/download progress.
     
     Params:
     callback = the callback that receives the (total bytes to download, currently downloaded bytes,
                total bytes to upload, currently uploaded bytes).
     
     Returns:
     Return 0 from the callback to signal success, return non-zero to abort transfer

     Example:
     ----
     http.onProgress = delegate int(double dl, double dln, double ul, double ult) { 
       writeln("Progress: downloaded ", dln, " of ", dl);
       writeln("Progress: uploaded ", uln, " of ", ul);  
     };
     ----
  */
  @property ref Curl onProgress(int delegate(double dltotal, double dlnow, double ultotal, double ulnow) callback) {
    _onProgress = (double dlt, double dln, double ult, double uln) {
      if (stopped)
	throw new CurlException("Progress callback called on cleaned up Curl instance");
      return callback(dlt, dln, ult, uln);
    };
    set(CurlOption.noprogress, 0);
    set(CurlOption.progressdata, cast(void*) this);
    set(CurlOption.progressfunction, cast(void*) &Curl._progressCallback);
    return this;
  }
  
  //
  // Internal C callbacks to register with libcurl
  //
  extern (C) private static size_t _receiveCallback(const char* str, size_t size, size_t nmemb, void* ptr) {
    Curl b = cast(Curl) ptr;
    if (b._onReceive != null)
      b._onReceive(cast(indata)(str[0..size*nmemb]));
    return size*nmemb;
  }

  extern (C) private static size_t _receiveHeaderCallback(const char* str, size_t size, size_t nmemb, void* ptr) {
    Curl b = cast(Curl) ptr;
    auto s = str[0..size*nmemb].chomp;
    if (b._onReceiveHeader != null) 
      b._onReceiveHeader(s); 

    return size*nmemb;
  }
 
  extern (C) private static size_t _sendCallback(char *str, size_t size, size_t nmemb, void *ptr)           
  {                                                                                         
    Curl b = cast(Curl) ptr;
    void[] a = cast(void[]) str[0..size*nmemb];
    if (b._onSend == null)
      return 0;
    return b._onSend(a);
  }

  extern (C) private static int _seekCallback(void *ptr, curl_off_t offset, int origin)           
  {                                                                                         
    Curl b = cast(Curl) ptr;
    if (b._onSeek == null)
      return CurlSeek.cantseek;

    // origin: CurlSeekPos.set/current/end
    // return: CurlSeek.ok/fail/cantseek
    return b._onSeek(cast(long) offset, cast(CurlSeekPos) origin);
  }

  extern (C) private static int _socketOptionCallback(void *ptr, curl_socket_t curlfd, curlsocktype purpose)          
  {                                                                                         
    Curl b = cast(Curl) ptr;
    if (b._onSocketOption == null)
      return 0;

    // return: 0 ok, 1 fail
    return b._onSocketOption(curlfd, cast(CurlSockType) purpose);
  }

  extern (C) private static int _progressCallback(void *ptr, double dltotal, double dlnow, double ultotal, double ulnow)
  {                                                                                         
    Curl b = cast(Curl) ptr;
    if (b._onProgress == null)
      return 0;

    // return: 0 ok, 1 fail
    return b._onProgress(dltotal, dlnow, ultotal, ulnow);
  }

}


/**
   Abstact Base class for all supported curl protocols. 
*/
abstract class Protocol {

  Curl curl = null;

  private this() {
    curl = new Curl;
  }

  private this(in const(char)[] url) {
    this();
    curl.set(CurlOption.url, url);
  }

  /// Connection settings

  /// Set timeout for activity on connection in milliseconds
  @property ref Protocol dataTimeout(int ms) {
    curl.set(CurlOption.timeout_ms, ms);
    return this;
  }

  /// Set timeout for connecting in milliseconds
  @property ref Protocol connectTimeout(int ms) {
    curl.set(CurlOption.connecttimeout_ms, ms);
    return this;
  }
  
  /// Network settings

  /// The URL to specify the location of the resource
  @property ref Protocol url(in const(char)[] url) {
    curl.set(CurlOption.url, url);
    return this;
  }

  /// DNS lookup timeout in milliseconds
  @property ref Protocol dnsTimeout(int ms) {
    curl.set(CurlOption.dns_cache_timeout, ms);
    return this;
  }

  /**
     The network interface to use in form of the the IP of the interface.
     Example:
     ----
     theprotocol.netInterface = "192.168.1.32";
     ----
  */
  @property ref Protocol netInterface(const(char)[] i) {
    curl.set(CurlOption.intrface, cast(char*)i);
    return this;  
  }

  /**
     Set the local outgoing port to use.
     Params:
     port = the first outgoing port number to try and use
     range = if the first port is occupied then try this many 
             port number forwards
  */
  ref Protocol setLocalPortRange(int port, int range) {
    curl.set(CurlOption.localport, cast(long)port);
    curl.set(CurlOption.localportrange, cast(long)range);
    return this;  
  }

  /// Set the tcp nodelay socket option on or off
  @property ref Protocol tcpNoDelay(bool on) {
    curl.set(CurlOption.tcp_nodelay, cast(long) (on ? 1 : 0) );
    return this;
  }

  /// Authentication settings

  /**
     Set the usename, pasword and optionally domain for authentication purposes.
     
     Some protocols may need authentication in some cases. Use this
     function to provide credentials.

     Params:
     username = the username
     password = the password
     domain = used for NTLM authentication only and is set to the NTLM domain name
  */
  ref Protocol setUsernameAndPassword(const(char)[] username, const(char)[] password, const(char)[] domain = "") {
    if (domain != "")
      username = domain ~ "/" ~ username;
    curl.set(CurlOption.userpwd, cast(char*)(username ~ ":" ~ password));
    return this;
  }


  /**
     See $(XREF curl, Curl.onReceive)
   */
  @property ref Protocol onReceive(void delegate(ubyte[]) callback) {
    curl.onReceive(callback);
    return this;
  }

  /**
     See $(XREF curl, Curl.onProgress)
   */
  @property ref Protocol onProgress(int delegate(double dltotal, double dlnow, double ultotal, double ulnow) callback) {
    curl.onProgress(callback);
    return this;
  }
}

/// The standard HTTP methods
enum HttpMethod {
  head,
  get,
  post,
  put,
  del,
  options,
  trace,
  connect
}


/**
  HTTP status line ie. the first line returned in a HTTP response.
  
  If authentication or redirections are done then the status will be
  for the last response received.
*/
struct HttpStatusLine {
  ushort majorVersion;
  ushort minorVersion;
  ushort code;
  string reason;

  void reset() { 
    majorVersion = 0;
    minorVersion = 0;
    code = 0;
    reason = "";
  }
}

private Tuple!(size_t,string) decodeString(const(ubyte)[] data, EncodingScheme scheme, size_t maxChars = size_t.max) {
  string res;
  size_t startLen = data.length;
  size_t charsDecoded = 0;
  while (data.length && charsDecoded < maxChars) {
    auto dc = scheme.safeDecode(data);
    if (dc == INVALID_SEQUENCE) {
      writeln("invalid seq", data);
      return typeof(return)(size_t.max, cast(string)null);
    }
    charsDecoded++;
    res ~= dc;
  }
  return typeof(return)(startLen-data.length, res);
}

/// Result struct used when not using callbacks for results
struct HttpResult {

  short code;                 /// The http status code
  private ubyte[] _bytes;     /// The received http content as raw ubyte[]
  string[string] headers;     /// The received http headers


  private void reset() {
    code = 0;
    _bytes.length = 0;
    foreach(k; headers.keys) headers.remove(k);
  }

  /**
     Return the received content. This will actually perform the
     syncronous http request the first time it is called.
  */
  @property ubyte[] content() {
    return _bytes;
  }

  /**
     The received http content decoded from content-type charset into text.
     
     This value is parsed from the HttpResult.content property of this struct.
  */
  @property string text() {
    auto scheme = encodingScheme;
    if (!scheme) {
      return null;
    }
    auto r = decodeString(_bytes, scheme);
    _bytes = _bytes[r[0]..$];
    return r[1];
  }

  @property const(char)[] encodingSchemeName() {
    string * v = ("content-type" in headers);
    char[] charset = "ISO-8859-1".dup; // Default charset defined in HTTP RFC
    if (v) {
      writeln("ESN is ", *v);
      auto m = match(cast(char[]) (*v), regex(".*charset=([^;]*)"));
      if (!m.empty && m.captures.length > 1) {
	charset = m.captures[1];
      }
    }
    writeln("charset is", charset);
    return charset;
  }

  @property EncodingScheme encodingScheme() {
    return EncodingScheme.create(to!string(encodingSchemeName));
  }

  void addHeader(const(char)[] key, const(char)[] value) {
    string * v = (key in headers);
    if (v) {
      (*v) ~= value;
    } else {
      headers[key] = to!string(value);
    }
  }

}

mixin template AsyncUnitRead(alias parseUnit, UnitType) {

      enum State {
	needUnit,
	needData,
	errorDecode,
	gotUnit,
	lastUnit,
	done
      };
      State state;
      private EncodingScheme encodingScheme;

      @property auto empty() 
      {
	tryEnsureUnit();
	return state == State.done;
      }

      @property UnitType front()
      {
	tryEnsureUnit();
	assert(state == State.gotUnit, "Expected " ~ State.gotUnit ~ " but got " ~ to!string(state));
	return unit;
      }

      void popFront()
      {
	tryEnsureUnit();
	assert(state == State.gotUnit, "Expected " ~ State.gotUnit ~ " but got " ~ to!string(state));
	state = State.needUnit;
      }

      private void tryEnsureUnit() 
      {
	scope (exit) {
	  if (state == State.errorDecode) 
	    throw new CurlException("Decoding error");
	}

	while (true) {
	  switch (state) {
	  case State.needUnit:
	    parseUnit(); break;
	  case State.needData:
	    if (!running) {
	      state = State.done;
	      break;
	    }
	    writeln("trying to recive");
	    receive(
		    (immutable(ubyte)[] _data) { 
		      if (encodingScheme is null) {
			encodingScheme = EncodingScheme.create("ISO-8859-1"); // default per HTTP RFC doc
		      }
		      bytes ~= _data;
		      parseUnit();
		    },
		    (string _data) {
		      encodingScheme = EncodingScheme.create(_data);
		    },
		    (bool f) { state = state.lastUnit; running = false; }
		    );
	    break;
	  case State.gotUnit: return;
	  case State.errorDecode: return;
	  case State.lastUnit:
	    // The last ubytes in the buffer is the final unit.
	    decodeUnit(bytes, size_t.max);
	    bytes = [];
	    return;
	  case State.done:
	    return;
	  }
	}
      }

      static if ( is(UnitType == string) ) {

      private size_t decodeUnit(immutable(ubyte)[] _data, size_t maxUnitLength) {
	auto ds = decodeString(_data, encodingScheme, maxUnitLength);
	if (ds[0] == size_t.max) { // error null string decoded
	  state = State.errorDecode;
	  return size_t.max;
	}
	unit = ds[1];
	state = State.gotUnit;
	return ds[0];
      }

      } else static if ( is(UnitType == immutable(ubyte)[]) ) {
	  
      private size_t decodeUnit(immutable(ubyte)[] _data, size_t maxUnitLength) {
	size_t eat = maxUnitLength > _data.length ? _data.length : maxUnitLength;
	unit = _data[0..eat];
	state = State.gotUnit;
	return eat;
      }

      } else {
	  static assert(0, "Cannot instantiate AsyncHttpResult.byLine() with LineType " ~ LineType.toString);
      }
}

struct AsyncHttpResult {

  private Tid workerTid;
  
  enum KeepTerminator : bool { no, yes }

  auto byLine(LineType = string)(KeepTerminator kt = KeepTerminator.no, char terminator = '\n') {
    /*
      The basic idea is:
      4. Control congestion (too many buffers in flight) with setMaxMailboxSize.
      5. Make sure you have a little protocol that stops the secondary thread when the range is destroyed.
    */
    static struct AsyncHttpLineInputRange {

      private Tid workerTid;
      private bool running;
      private bool keepTerminator;
      private char terminator;
      private immutable(ubyte)[] bytes;
      private LineType unit;

      this(Tid tid, KeepTerminator kt, char terminator) 
      {
	workerTid = tid;
	running = true;
	keepTerminator = kt;
	this.terminator = terminator;
	state = State.needUnit;
      }

      private void parseUnit() 
      {
	auto r = bytes.findSplit([cast(ubyte)terminator]);
	if (r[1].length == 0) {
	  state = State.needData;
	  return;
	}
	decodeUnit(keepTerminator ? r[0] ~ r[1] : r[0], size_t.max);
	if (state != State.gotUnit) return;
	bytes = r[2]; // bytes left after terminator
      }

      mixin AsyncUnitRead!(parseUnit, LineType);

    }
    return AsyncHttpLineInputRange(workerTid, kt, terminator);
  }

  auto byChunk(ChunkType = string)(size_t chunkSize) {
    /*
      The basic idea is:
      4. Control congestion (too many buffers in flight) with setMaxMailboxSize.
      5. Make sure you have a little protocol that stops the secondary thread when the range is destroyed.
    */
    static struct AsyncHttpChunkInputRange {

      private Tid workerTid;
      private bool running;
      private size_t chunkSize;
      private immutable(ubyte)[] bytes;
      private ChunkType unit;
      
      this(Tid tid, size_t chunkSize)
      {
	workerTid = tid;
	running = true;
	this.chunkSize = chunkSize;
	state = State.needUnit;
      }

      private void parseUnit()
      {
	if (bytes.length < chunkSize) {
	  state = State.needData;
	  return;
	}
	auto bytesConsumed = decodeUnit(bytes, chunkSize);
	bytes = bytes[bytesConsumed..$]; 
      }

      mixin AsyncUnitRead!(parseUnit, ChunkType);
    }
    return AsyncHttpChunkInputRange(workerTid, chunkSize);
  }

};

/**
   Http client functionality.
   Do not use the same instance of this class in two threads simultanously.
*/
class Http : Protocol {

  private curl_slist * headerChunk = null; // outgoing http headers

  /// The status line of the final subrequest in a request
  HttpStatusLine status;
  private void delegate(HttpStatusLine) _onReceiveStatusLine;

  /// The HTTP method to use
  public HttpMethod method = HttpMethod.get;

  /**
     Default constructor. Remember to set at least the $(D url)
     property before calling $(D perform).
   */
  this() {
    curl = new Curl;
    curl_slist_free_all(headerChunk);
  }

  /**
     As the default constructor but setting the $(D url) property.
   */
  this(in const(char)[] url) {
    curl = new Curl;
    curl_slist_free_all(headerChunk);
    super(url);
  }

  /// Add a header string e.g. "X-CustomField: Something is fishy"
  void addHeader(in const(char)[] key, in const(char)[] value) {
    headerChunk = curl_slist_append(headerChunk, cast(char*) toStringz(key ~ ": " ~ value)); 
  }

  /// Add a header string e.g. "X-CustomField: Something is fishy"
  private void addHeader(in const(char)[] header) {
    headerChunk = curl_slist_append(headerChunk, cast(char*) toStringz(header)); 
  }

  // Set the active cookie string e.g. "name1=value1;name2=value2"
  void setCookie(in const(char)[] cookie) {
    curl.set(CurlOption.cookie, cookie);
  }

  /// Set a filepath to where a cookie jar should be read/stored
  void setCookieJar(in const(char)[] path) {
    curl.set(CurlOption.cookiefile, path);
    curl.set(CurlOption.cookiejar, path);
  }

  /// Flush cookie jar to disk
  void flushCookieJar() {
    curl.set(CurlOption.cookielist, "FLUSH");
  }

  /// Clear session cookies
  void clearSessionCookies() {
    curl.set(CurlOption.cookielist, "SESS");
  }

  /// Clear all cookies
  void clearAllCookies() {
    curl.set(CurlOption.cookielist, "ALL");
  }

  /**
     Set time condition on the request.

     Parameters:
     cond:  CurlTimeCond.{none,ifmodsince,ifunmodsince,lastmod}
     secsSinceEpoch: The time value
  */
  void setTimeCondition(CurlTimeCond cond, long secsSinceEpoch) {
    curl.set(CurlOption.timecondition, cond);
    curl.set(CurlOption.timevalue, secsSinceEpoch);
  }

  /** Convenience function that simply does a HTTP(s) head on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.head("http://www.digitalmars.com");
      writeln(res.headers["Content-Length"]);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult head(in const(char)[] url) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.head;
    client.onReceiveHeader = (const(char)[] key,const(char)[] value) { res.addHeader(key, value); };
    client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
    client.followLocation = 10;
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) get on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.
      
      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.get("http://www.digitalmars.com");
      writeln(res.text);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult get(in const(char)[] url) {
    auto client = new Http(url);
    HttpResult res;
    client.onReceive = (ubyte[] data) { res._bytes ~= data; };
    client.onReceiveHeader = (const(char)[] key,const(char)[] value) { res.addHeader(key, value); };
    client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
    client.followLocation = 10;
    client.perform;
    return res;
  }


  /** Convenience function that simply does a HTTP(s) post on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.post("http://www.digitalmars.com", 
                           "Posting this data");
      writeln(res.text);
      ----

      Params:
      url = The URL including protocol http or https
      data = The data to post to server

      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static AsyncHttpResult postAsync(string url, immutable(void)[] data, string contentType = "application/octet-stream") {

    // Spawn a thread for handling the reading of incoming data in the
    // background while the delegate is executing.  This will optimize
    // throughput by allowing simultanous input (this struct) and
    // output (AsyncHttpLineOutputRange).
    auto fun = function(string _url, immutable(void)[] _data, string _contentType) {
      auto client = new Http(_url);
      HttpResult res;
      Tid fromTid = receiveOnly!(Tid);

      client.onSend = delegate size_t(void[] buf) {
	size_t minlen = min(buf.length, _data.length);
	buf[0..minlen] = _data[0..minlen];
	_data = _data[minlen..$];
	return minlen;
      };
      client.addHeader("Content-Type: " ~ _contentType);
      client.contentLength = _data.length;
      client.onReceiveHeader = (const(char)[] key,const(char)[] value) { 
	res.addHeader(key, value); 
	if (key == "content-type")
	  fromTid.send(to!string(res.encodingSchemeName));
      };
      client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
      client.followLocation = 10;

      client.onReceive = (ubyte[] data) { 
	writeln("Send...");
	fromTid.send(data.idup);
      };

      // Start the request
      client.perform;

      fromTid.send(true); // signal done
    };

    // 50 is just an arbitrary number for now
    // TODO: fix setMaxMailboxSize(thisTid, 50, OnCrowding.block);
    Tid tid = spawnLinked(fun, url, data, contentType);
    tid.send(thisTid);

    auto r = AsyncHttpResult(tid);
    return r;
  }


  /** Convenience function that simply does a HTTP(s) post on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.post("http://www.digitalmars.com", 
                           "Posting this data");
      writeln(res.text);
      ----

      Params:
      url = The URL including protocol http or https
      data = The data to post to server

      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult post(in const(char)[] url, const(void)[] data, const(char)[] contentType = "application/octet-stream") {
    auto client = new Http(url);
    HttpResult res;
    client.onSend = delegate size_t(void[] buf) {
      size_t minlen = min(buf.length, data.length);
      buf[0..minlen] = data[0..minlen];
      data = data[minlen..$];
      return minlen;
    };
    client.addHeader("Content-Type: " ~ contentType);
    client.contentLength = data.length;
    client.onReceive = (ubyte[] idata) { res._bytes ~= idata; };
    client.onReceiveHeader = (const(char)[] key,const(char)[] value) { res.addHeader(key, value); };
    client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
    client.followLocation = 10;
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) post on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.post("http://www.digitalmars.com", 
                           "Posting this data");
      writeln(res.text);
      ----

      Params:
      url = The URL including protocol http or https
      data = The data to post to server

      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult post(in const(char)[] url, const(char)[] data, const(char)[] contentType = "text/plain; charset=utf-8") {
    auto client = new Http(url);
    HttpResult res;
    client.onSend = delegate size_t(void[] buf) {
      size_t minlen = min(buf.length, data.length);
      buf[0..minlen] = data[0..minlen];
      data = data[minlen..$];
      return minlen;
    };
    client.addHeader("Content-Type: " ~ contentType);
    client.contentLength = data.length;
    client.onReceive = (ubyte[] idata) { res._bytes ~= idata; };
    client.onReceiveHeader = (const(char)[] key,const(char)[] value) { res.addHeader(key, value); };
    client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
    client.followLocation = 10;
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) put on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.put("http://www.digitalmars.com", 
                           "Putting this data");
      writeln(res.code);
      ----

      Params:
      url = The URL including protocol http or https
      data = The data to put to server

      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult put(in const(char)[] url, const(void)[] data, const(char)[] contentType = "application/octet-stream") {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.put;
    client.onSend = delegate size_t(void[] buf) {
      size_t minlen = min(buf.length, data.length);
      buf[0..minlen] = data[0..minlen];
      data = data[minlen..$];
      return minlen;
    };
    client.addHeader("Content-Type: " ~ contentType);
    client.contentLength = data.length;
    client.onReceive = (ubyte[] idata) { res._bytes ~= idata; };
    client.onReceiveHeader = (const(char)[] key,const(char)[] value) { res.addHeader(key, value); };
    client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
    client.followLocation = 10;
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) put on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.put("http://www.digitalmars.com", 
                           "Putting this data");
      writeln(res.code);
      ----

      Params:
      url = The URL including protocol http or https
      data = The data to put to server

      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult put(in const(char)[] url, const(char)[] data, const(char)[] contentType = "text/plain; charset=utf-8") {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.put;
    client.onSend = delegate size_t(void[] buf) {
      size_t minlen = min(buf.length, data.length);
      buf[0..minlen] = data[0..minlen];
      data = data[minlen..$];
      return minlen;
    };
    client.addHeader("Content-Type: " ~ contentType);
    client.contentLength = data.length;
    client.onReceive = (ubyte[] idata) { res._bytes ~= idata; };
    client.onReceiveHeader = (const(char)[] key,const(char)[] value) { res.addHeader(key, value); };
    client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
    client.followLocation = 10;
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) delete on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.del("http://www.digitalmars.com/die.txt");
      writeln(res.text);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult del(in const(char)[] url) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.del;
    client.onReceive = (ubyte[] data) { res._bytes ~= data; };
    client.onReceiveHeader = (const(char)[] key,const(char)[] value) { res.addHeader(key, value); };
    client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
    client.followLocation = 10;
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) options on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.options("http://www.digitalmars.com/die.txt");
      writeln(res.text);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult options(in const(char)[] url) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.options;
    client.onReceive = (ubyte[] data) { res._bytes ~= data; };
    client.onReceiveHeader = (const(char)[] key,const(char)[] value) { res.addHeader(key, value); };
    client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
    client.followLocation = 10;
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) trace on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.trace("http://www.digitalmars.com/die.txt");
      writeln(res.text);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult trace(in const(char)[] url) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.trace;
    client.onReceive = (ubyte[] data) { res._bytes ~= data; };
    client.onReceiveHeader = (const(char)[] key,const(char)[] value) { res.addHeader(key, value); };
    client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
    client.followLocation = 10;
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) connect on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Redirecting 10 max times.

      Example:
      ----
      auto res = Http.connect("http://www.digitalmars.com/die.txt");
      writeln(res.text);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult connect(in const(char)[] url) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.connect;
    client.onReceive = (ubyte[] data) { res._bytes ~= data; };
    client.onReceiveHeader = (const(char)[] key,const(char)[] value) { res.addHeader(key, value); };
    client.onReceiveStatusLine = (HttpStatusLine l) { res.reset(); };
    client.followLocation = 10;
    client.perform;
    return res;
  }

  /** Specifying post data for posting without using the onSend callback 
      The pointed data are NOT copied by the library.
      Content-Type will default to application/octet-stream.
      Data is not converted or encoded for you.
   */
  @property ref Http postData(in const(void)[] data) {
    // cannot use callback when specifying data directly so we disable it here.
    curl.clear(CurlOption.readfunction); 
    addHeader("Content-Type: application/octet-stream");
    curl.set(CurlOption.postfields, cast(void*)data.ptr);
    return this;
  }
  
  /** Specifying post data for posting without using the onSend callback 
      The pointed data are NOT copied by the library.
      Content-Type will defaults to application/x-www-form-urlencoded.
      Data is not converted or encoded for you.
  */
  @property ref Http postData(in const(char)[] data) {
    // cannot use callback when specifying data directly so we disable it here.
    curl.clear(CurlOption.readfunction); 
    curl.set(CurlOption.postfields, cast(void*)data.ptr);
    return this;
  }

  /**
     See $(XREF curl, Curl.onReceiveHeader)
   */
  @property ref Http onReceiveHeader(void delegate(const(char)[],const(char)[]) callback) {
    // Wrap incoming callback in order to separate http status line from http headers.
    // On redirected requests there may be several such status lines. The last one is
    // the one recorded.
    auto dg = (const(char)[] header) { 
      if (header.length == 0) {
	// header delimiter
	return;
      }
      if (header[0..5] == "HTTP/") {
	auto m = match(header, regex(r"^HTTP/(\d+)\.(\d+) (\d+) (.*)$"));
	if (m.empty) {
	  // Invalid status line
	} else {
	  status.majorVersion = to!ushort(m.captures[1]);
	  status.minorVersion = to!ushort(m.captures[2]);
	  status.code = to!ushort(m.captures[3]);
	  status.reason = m.captures[4].idup;
	  if (_onReceiveStatusLine != null) {
	    _onReceiveStatusLine(status);
	  }
	}
	return;
      }

      // Normal http header
      auto m = match(cast(char[]) header, regex("(.*?): (.*)$"));

      if (!m.empty) {
	callback(m.captures[1].tolower, m.captures[2]); 
      }
      
    };
    curl.onReceiveHeader(callback is null ? null : dg);
    return this;
  }

  /**
     
   */
  @property ref Http onReceiveStatusLine(void delegate(HttpStatusLine) callback) {
    _onReceiveStatusLine = callback;
    return this;
  }

  /**
     See $(XREF curl, Curl.onSend)
   */
  @property ref Http onSend(size_t delegate(void[]) callback) {
    curl.clear(CurlOption.postfields); // cannot specify data when using callback
    curl.onSend(callback);
    return this;
  }

  /**
     The content length when using request that has content e.g. POST/PUT
     and not using chuncked transfer. Is set as the "Content-Length" header.

     Params:
     len: content length in bytes
   */
  @property void contentLength(size_t len) {

    CurlOption lenOpt;

    // Force post if necessary
    if (method != HttpMethod.put && method != HttpMethod.post)
      method = HttpMethod.post;

    if (method == HttpMethod.put)  {
      lenOpt = CurlOption.infilesize_large;
    } else { 
      // post
      lenOpt = CurlOption.postfieldsize_large;
    }

    if (len == 0) {
      // HTTP 1.1 supports requests with no length header set.
      addHeader("Transfer-Encoding: chunked");
      addHeader("Expect: 100-continue");
    } else {
	curl.set(lenOpt, len);      
    }
  }

  /**
     Perform http request
   */
  void perform() {

    status.reset;

    if (headerChunk != null)
      curl.set(CurlOption.httpheader, headerChunk);

    switch (method) {
    case HttpMethod.head:
      curl.set(CurlOption.nobody, 1L);
      break;
    case HttpMethod.get:
      curl.set(CurlOption.httpget, 1L);
      break;
    case HttpMethod.post:
      curl.set(CurlOption.post, 1L);
      break;
    case HttpMethod.put:
      curl.set(CurlOption.upload, 1L);
      break;
    case HttpMethod.del:
      curl.set(CurlOption.customrequest, "DELETE");
      break;
    case HttpMethod.options:
      curl.set(CurlOption.customrequest, "OPTIONS");
      break;
    case HttpMethod.trace:
      curl.set(CurlOption.customrequest, "TRACE");
      break;
    case HttpMethod.connect:
      curl.set(CurlOption.customrequest, "CONNECT");
      break;
    }

    curl.perform;
  }

  /**
     Set the http authentication method.

     Params:
     authMethod = method as specified in $(XREF etc.c.curl, AuthMethod).
   */
  ref Http setAuthenticationMethod(CurlAuth authMethod) {
    curl.set(CurlOption.httpauth, cast(long) authMethod);
    return this;
  }

  /**
     Set max allowed redirections using the location header.

     Params:
     maxRedirs = Max allowed redirs. -1 for infinite. 
   */
  @property ref Http followLocation(int maxRedirs) {
    if (maxRedirs == 0) {
      // Disable
      curl.set(CurlOption.followlocation, 0);
    } else {
      curl.set(CurlOption.followlocation, 1);
      curl.set(CurlOption.maxredirs, maxRedirs);
    }
    return this;
  }

}
 

/**
   Ftp client functionality
   Do not use the same instance of this class in two threads simultanously.
*/
class Ftp : Protocol {

  /**
     Default constructor. Remember to set at least the $(D url)
     property before calling $(D perform).
   */
  this() {
    curl = new Curl;
  }

  /**
     As the default constructor but setting the $(D url) property.
   */
  this(in const(char)[] url) {
    super(url);
  }

  /** Convenience function that simply does a FTP GET on specified
      URL. Internally this is implemented using an instance of the
      Ftp class.

      Example:
      ----
      Ftp.get("ftp://ftp.digitalmars.com/sieve.ds", "/tmp/downloaded-file");
      ----

      Params:
      url = The URL of the FTP
  */
  static void get(in const(char)[] url, in string saveToPath) {
    auto client = new Ftp(url);
    auto f = new std.stream.File(saveToPath, FileMode.OutNew);
    client.onReceive = (ubyte[] data) { f.write(data); };
    client.perform;
    f.close;
  }

  /**
     Performs the ftp request as it has been configured
  */
  void perform() {
    curl.perform;
  }

}


unittest {

    // Async POST GET with default timeout etc.
  //    foreach (l; Http.postAsync("http://freeze.steamwinter.com/posttest/test.cgi", "testing 123").byLine()) {
  //      writeln("async: ", l);
  //    }
  
//     foreach (l; Http.postAsync("http://www.fileformat.info/info/unicode/block/latin_supplement/utf8test.htm", "testing 123").byLine()) {
//       writeln("async: ", l);
//     }

    foreach (l; Http.postAsync("http://www.fileformat.info/info/unicode/block/latin_supplement/utf8test.htm", "testing 123").byChunk!(immutable(ubyte)[])(10)) {
      writeln("asyncChunk: ", l);
    }

    return;

    // Simple GET with default timeout etc.
    writeln( Http.get("http://www.google.com").text ); // .headers for headers etc.

    //
    // GET with custom data receivers 
    //
    Http http = new Http("http://www.google.com");
    http.onReceiveHeader = (const(char)[] key, const(char)[] value) { writeln(key ~ ": " ~ value); };
    http.onReceive = (ubyte[] data) { /* drop */ };
    http.perform;
    
    //
    // POST with timouts
    //
    http.url("http://www.testing.com/test.cgi");
    http.onReceive = (ubyte[] data) { writeln(data); };
    http.connectTimeout(1000);
    http.dataTimeout(1000);  
    http.dnsTimeout(1000);
    http.postData = "The quick....";
    http.perform;

    //
    // PUT with data senders 
    //
    string msg = "Hello world";
    http.onSend = delegate size_t(void[] data) { 
	if (!msg.length) return 0; 
	auto m = cast(void[])msg;
	auto l = m.length;
	data[0..l] = m[0..$];  
	msg.length = 0;
	return l;
    };
    http.method = HttpMethod.put; // defaults to POST
    // Defaults to chunked transfer if not specified. We don't want that now.
    http.contentLength = 11; 
    http.perform;

    // HTTPS
    writeln(Http.get("https://mail.google.com").text);


    /*
    // async foreach support
    foreach (auto line; Http.get("http://www.digitalmars.com").byLineAsync()) {

    }
    
    // async foreach support
    foreach (auto line; Http.post("http://www.digitalmars.com", "my data").byLineAsync()) {

    }

    // async foreach support
    HTTP hp = new Http("http://www.digitalmars.com");
    http.onSend = delegate size_t(void[] data) { 
	if (!msg.length) return 0; 
	auto m = cast(void[])msg;
	auto l = m.length;
	data[0..l] = m[0..$];  
	msg.length = 0;
	return l;
    };
    hp.method = HttpMethod.post;
    hp.contentLength = 11;

    foreach (auto line; Http.post("http://www.digitalmars.com", "my data").byLineAsync()) {
      
    }

    // sync foreach support
    foreach (auto line; Http.get("http://www.digitalmars.com").byLine()) {

    }

    // 1, Read all blocking (timeout optional) nothread
    Http.get("http://www.digitalmars.com", timeout).readAll();
    
    // 2, Read/write some blocking (timeout optional)  nothread
    auto hpost = Http.post("http://www.digitalmars.com", timeout);
    hpost.write(mydata);
    hpost.read(100);

    // 3, Select and read - nothread
    Http htp = Http.get("http://www.digitalmars.com");
    auto selres = selectThingy.select(htp, timeout);
    if (selres...) {
      auto bytes = htp.read(100);
    }

    // 4, Callbacks - no thread
    string msg = "Hello world";
    http.onSend = delegate size_t(void[] data) { 
	if (!msg.length) return 0; 
	auto m = cast(void[])msg;
	auto l = m.length;
	data[0..l] = m[0..$];  
	msg.length = 0;
	return l;
    };
    http.method = HttpMethod.put; // defaults to POST
    // Defaults to chunked transfer if not specified. We don't want that now.
    http.contentLength = 11; 
    http.perform;
    */

    /*
    // if several (needs select on sockets (Http instance) to do callbacks)
    Http.perform([http1,http2....]);

    // 4, Fibers - nohread
    // Http instance derived from FiberWaitSocket
    auto http = yieldUntilConnect( Http.get("http://www.digitalmars.com"), timeout );
    auto res = yieldUntilReadWrite( http );

    // 5, Foreach range sync (throws on optional timeout). Same for byChunk()
    foreach (auto line; Http.get("http://www.digitalmars.com", timeout).byLine()) {
    }

    // 6, Foreach range async (throws on timeout). Same for byChunk()
    foreach (auto line; Http.get("http://www.digitalmars.com", timeout).byLineAsync()) {
    }


    // 1 sync read (simple read on socket)
    sock.read()

    // 2 sync callback (sugar: simple read on socket followed by func call)
    sock.read((data) { print data });

    // async callback
    // 3     callback from other thread (let worker do it and proceed) = just spawn new thread and do sync xxx => nothing to do
    new thread(sock.read((data) { print data }));

    //      callback from mainloop     
    // 4                            on worker thread completion (let worker thread do it to a queue to mainloop and proceed but remember to yield at some point)
    async(sock.read,(data) { print data; });
    or
    sock.asyncReadThread((data) { print data; };

    // 5                            on select (let mainloop do it and proceed but remember to yield at some point)
    sock.asyncReadSelect((data) { print data; };
			 
    //
    // sync fiber
    //               from mainloop     
    // 6                            on worker thread completion (let worker thread do it to a queue to mainloop and yield fiber and resume when async op is done)
    async(sock.read);
    or
    yield sock.asyncReadThread();
			 
    // 7                            on select (let mainloop do it and yield fiber and resume when async op is done)
    yield sock.asyncReadSelect();

    //
    // 8 async future (let worker thread do it - proceed and get result in future)
    Future f = sock.readAsync();
    ....
    f.getResult(); or f.isReady()

    */

    // FTP
    Ftp.get("ftp://ftp.digitalmars.com/sieve.ds", "./downloaded-file");
    
    http.method = HttpMethod.get;
    http.url = "http://upload.wikimedia.org/wikipedia/commons/5/53/Wikipedia-logo-en-big.png";
    http.onReceive = delegate(ubyte[]) { };
    http.onProgress = (double dltotal, double dlnow, double ultotal, double ulnow) {
      writeln("Progress ", dltotal, ", ", dlnow, ", ", ultotal, ", ", ulnow);
      return 0;
    };
    http.perform;
}

