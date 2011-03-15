// Written in the D programming language.

/*
  TODO:
  Pull request for c declarations only

  const(void[]) for output
  ubyte[] for input
  postData testPostData etc. for all cases
  Zero copy of data (where possible)

  Progress is deprecated

  Is inheritance necessary (for streaming Transport... for grand url dispatch result?)

  Threads: shutdowns from other threads/callbacks, or shutdown the entire library

  Grand dispatch from URL only (looking at protocol)

  Suggestion (foreach):
    The data transfer should happen concurrently with the foreach code. The type of line is char[] or const(char)[]. Similarly, there would be a byChunk interface that transfers in ubyte[] chunks.
    Also we need a head() method for the corresponding command. 

  Typed http headers - Johannes Pfau
 */

/**
Curl client functionality as provided by libcurl.

Example:

---
// Simple GET with default timeout etc.
writeln( Http.get("http://www.google.com").content ); // .headers for headers etc.

//
// GET with custom data receivers 
//
Http http = new Http("http://www.google.com");
http.onReceiveHeader = (string key, string value) { writeln(key ~ ": " ~ value); };
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
http.postData("The quick....");
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
*/
private class Curl {
  
  alias void[] rawdata;
  private CURL* handle;
  private size_t delegate(rawdata) _onSend; // May also return CURL_READFUNC_ABORT or CURL_READFUNC_PAUSE
  private void delegate(rawdata) _onReceive;
  private void delegate(string,string) _onReceiveHeader;
  private CurlSeek delegate(long,CurlSeekPos) _onSeek;
  private int delegate(curl_socket_t,CurlSockType) _onSocketOption;
  private int delegate(double dltotal, double dlnow, double ultotal, double ulnow) _onProgress;

  /**
     Default constructor. Remember to set at least the $(D url)
     property before calling $(D perform())
   */
  this() {
    handle = curl_easy_init();
    CURL* curl = curl_easy_init();
    set(CurlOption.verbose, 1L); 
  }

  ~this() {
    curl_easy_cleanup(this.handle);
  }

  private void _check(CURLcode code) {
    if (code != CurlError.ok) {
      throw new Exception(to!string(curl_easy_strerror(code)));
    }
  }

  /**
     Set a string curl option.
     Params:
     option = A $(XREF etc.c.curl, CurlOption) as found in the curl documentation
     value = The string
   */
  void set(CURLoption option, string value) {
    _check(curl_easy_setopt(this.handle, option, toStringz(value)));
  }

  /**
     Set a long curl option.
     Params:
     option = A $(XREF etc.c.curl, CurlOption) as found in the curl documentation
     value = The long
   */
  void set(CURLoption option, long value) {
    _check(curl_easy_setopt(this.handle, option, value));
  }

  /**
     Set a void* curl option.
     Params:
     option = A $(XREF etc.c.curl, CurlOption) as found in the curl documentation
     value = The pointer
   */
  void set(CURLoption option, void* value) {
    _check(curl_easy_setopt(this.handle, option, value));
  }

  /**
     Clear a pointer option
     Params:
     option = A $(XREF etc.c.curl, CurlOption) as found in the curl documentation
   */
  void clear(CURLoption option) {
    _check(curl_easy_setopt(this.handle, option, cast(void*)0));
  }

  /**
     perform the curl request by doing the HTTP,FTP etc. as it has
     been setup beforehand.
  */
  void perform() {
    firstLine = null;
    _check(curl_easy_perform(this.handle));
  }

  /**
     The event handler that receives incoming data.

     Params:
     callback = the callback that recieves the void[] data.

     Example:
     ----
     http.onReceive = (void[] data) { writeln("Got data", cast(char[])data); };
     ----
  */
  @property ref Curl onReceive(void delegate(rawdata) callback) {
    _onReceive = callback;
    set(CurlOption.file, cast(void*) this);
    set(CurlOption.writefunction, cast(void*) &Curl._receiveCallback);
    return this;
  }

  /**
     The event handler that receives incoming headers for protocols
     that uses headers

     Params:
     callback = the callback that recieves the key/value head strings.

     Example:
     ----
     http.onReceiveHeader = (string key, string value) { writeln(key, " = ", value); };
     ----
  */
  @property ref Curl onReceiveHeader(void delegate(string,string) callback) {
    _onReceiveHeader = callback;
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
  @property ref Curl onSend(size_t delegate(rawdata) callback) {
    _onSend = callback;
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
    _onSeek = callback;
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
    _onSocketOption = callback;
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
    _onProgress = callback;
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
      b._onReceive(cast(rawdata)(str[0..size*nmemb]));
    return size*nmemb;
  }

  char[] firstLine = null;

  extern (C) private static size_t _receiveHeaderCallback(const char* str, size_t size, size_t nmemb, void* ptr) {
    Curl b = cast(Curl) ptr;
    auto s = str[0..size*nmemb].chomp;

    if (b.firstLine == null) {
      b.firstLine = cast(char[]) s;
    } else {
      auto m = match(cast(char[]) s, regex("(.*?): (.*)$"));

      if (!m.empty && b._onReceiveHeader != null) {
	b._onReceiveHeader(to!string(m.captures[1]), to!string(m.captures[2])); 
      }

    }

    return size*nmemb;
  }
 
  extern (C) private static size_t _sendCallback(char *str, size_t size, size_t nmemb, void *ptr)           
  {                                                                                         
    Curl b = cast(Curl) ptr;
    char[] a = str[0..size*nmemb];
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

  private this(in string url) {
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
  @property ref Protocol url(in string url) {
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
  @property ref Protocol netInterface(string i) {
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
  ref Protocol setUsernameAndPassword(string username, string password, string domain = "") {
    if (domain != "")
      username = domain ~ "/" ~ username;
    curl.set(CurlOption.userpwd, cast(char*)(username ~ ":" ~ password));
    return this;
  }


  /**
     See $(XREF curl, Curl.onReceive)
   */
  @property ref Protocol onReceive(void delegate(void[] ) callback) {
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

/// Result struct used when not using callbacks for results
struct HttpResult {
  short code;                /// The http status code
  void[] content;            /// The received http content
  string[][string] headers;  /// The received http headers
}

/**
   Http client functionality.
*/
class Http : Protocol {

  private curl_slist * headerChunk = null; // outgoing http headers

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
  this(in string url) {
    curl = new Curl;
    curl_slist_free_all(headerChunk);
    super(url);
  }

  /// Add a header string e.g. "X-CustomField: Something is fishy"
  void addHeader(in string header) {
    headerChunk = curl_slist_append(headerChunk, cast(char*) toStringz(header)); 
  }

  // Set the active cookie string e.g. "name1=value1;name2=value2"
  void setCookie(in string cookie) {
    curl.set(CurlOption.cookie, cookie);
  }

  /// Set a filepath to where a cookie jar should be read/stored
  void setCookieJar(in string path) {
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
  static HttpResult head(in string url) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.head;
    client.onReceiveHeader = (string key,string value) { res.headers[key] ~= value; };
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) get on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Example:
      ----
      auto res = Http.get("http://www.digitalmars.com");
      writeln(cast(char[])res.content);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult get(in string url) {
    auto client = new Http(url);
    HttpResult res;
    client.onReceive = (void[] data) { res.content ~= data; };
    client.onReceiveHeader = (string key,string value) { res.headers[key] ~= value; };
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) post on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Example:
      ----
      auto res = Http.post("http://www.digitalmars.com", 
                           cast(void[]) "Posting this data");
      writeln(cast(char[])res.content);
      ----

      Params:
      url = The URL including protocol http or https
      data = The data to post to server

      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult post(in string url, void[] data) {
    auto client = new Http(url);
    HttpResult res;
    client.onSend = delegate size_t(void[] buf) {
      size_t minlen = min(buf.length, data.length);
      buf[0..minlen] = data[0..minlen];
      data = data[minlen..$];
      return minlen;
    };
    client.contentLength = data.length;
    client.onReceive = (void[] data) { res.content ~= data; };
    client.onReceiveHeader = (string key,string value) { res.headers[key] ~= value; };
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) put on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Example:
      ----
      auto res = Http.put("http://www.digitalmars.com", 
                           cast(void[]) "Putting this data");
      writeln(cast(char[])res.content);
      ----

      Params:
      url = The URL including protocol http or https
      data = The data to put to server

      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult put(in string url, void[] data) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.put;
    client.onSend = delegate size_t(void[] buf) {
      size_t minlen = min(buf.length, data.length);
      buf[0..minlen] = data[0..minlen];
      data = data[minlen..$];
      return minlen;
    };
    client.contentLength = data.length;
    client.onReceive = (void[] data) { res.content ~= data; };
    client.onReceiveHeader = (string key,string value) { res.headers[key] ~= value; };
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) delete on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Example:
      ----
      auto res = Http.del("http://www.digitalmars.com/die.txt");
      writeln(cast(char[])res.content);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult del(in string url) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.del;
    client.onReceive = (void[] data) { res.content ~= data; };
    client.onReceiveHeader = (string key,string value) { res.headers[key] ~= value; };
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) options on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Example:
      ----
      auto res = Http.options("http://www.digitalmars.com/die.txt");
      writeln(cast(char[])res.content);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult options(in string url) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.options;
    client.onReceive = (void[] data) { res.content ~= data; };
    client.onReceiveHeader = (string key,string value) { res.headers[key] ~= value; };
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) trace on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Example:
      ----
      auto res = Http.trace("http://www.digitalmars.com/die.txt");
      writeln(cast(char[])res.content);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult trace(in string url) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.trace;
    client.onReceive = (void[] data) { res.content ~= data; };
    client.onReceiveHeader = (string key,string value) { res.headers[key] ~= value; };
    client.perform;
    return res;
  }

  /** Convenience function that simply does a HTTP(s) connect on the
      specified URL. Internally this is implemented using an 
      instance of the Http class.

      Example:
      ----
      auto res = Http.connect("http://www.digitalmars.com/die.txt");
      writeln(cast(char[])res.content);
      ----

      Params:
      url = The URL including protocol http or https
      
      Returns:
      A $(XREF _curl, HttpResult) object.
  */
  static HttpResult connect(in string url) {
    auto client = new Http(url);
    HttpResult res;
    client.method = HttpMethod.connect;
    client.onReceive = (void[] data) { res.content ~= data; };
    client.onReceiveHeader = (string key,string value) { res.headers[key] ~= value; };
    client.perform;
    return res;
  }

  /** Specifying post data for postingwithout using the onSend callback */
  ref Http postData(in void[] data) {
    curl.clear(CurlOption.readfunction); // cannot use callback when specifying data directly
    curl.set(CurlOption.postfields, cast(void*)data.ptr);
    return this;
  }
  
  /**
     See $(XREF curl, Curl.onReceiveHeader)
   */
  @property ref Http onReceiveHeader(void delegate(string,string) callback) {
    curl.onReceiveHeader(callback);
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
  ref Http setFollowLocation(int maxRedirs) {
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
  this(in string url) {
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
  static void get(in string url, in string saveToPath) {
    auto client = new Ftp(url);
    auto f = new std.stream.File(saveToPath, FileMode.OutNew);
    client.onReceive = (void[] data) { f.write(cast(ubyte[])data); };
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
    // Simple GET with default timeout etc.
    writeln( Http.get("http://www.google.com").content ); // .headers for headers etc.

    //
    // GET with custom data receivers 
    //
    Http http = new Http("http://www.google.com");
    http.onReceiveHeader = (string key, string value) { writeln(key ~ ": " ~ value); };
    http.onReceive = (void[] data) { /* drop */ };
    http.perform;

    //
    // POST with timouts
    //
    http.url("http://www.testing.com/test.cgi");
    http.onReceive = (void[] data) { writeln(data); };
    http.connectTimeout(1000);
    http.dataTimeout(1000);  
    http.dnsTimeout(1000);
    http.postData("The quick....");
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
    Ftp.get("ftp://ftp.digitalmars.com/sieve.ds", "./downloaded-file");
    
    http.method = HttpMethod.get;
    http.url = "http://upload.wikimedia.org/wikipedia/commons/5/53/Wikipedia-logo-en-big.png";
    http.onReceive = delegate(void[]) { };
    http.onProgress = (double dltotal, double dlnow, double ultotal, double ulnow) {
      writeln("Progress ", dltotal, ", ", dlnow, ", ", ultotal, ", ", ulnow);
      return 0;
    };
    http.perform;
}

