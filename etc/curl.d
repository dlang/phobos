// Written in the D programming language.

/*
  Known issues:
  
  * DDoc is not generated where the mixins 
    ByLineAsync, ByLineSync, ByChunkAsync and ByLineSync are
    used. This seems to be a limitation of ddoc - suggestions
    on how to circumvent this appreciated.
  
  Possible improvements:

  * Progress may be deprecated in the future. Maybe implement a replacement.
  * Support typed http headers - (Johannes Pfau)
  
*/

/**
Curl client functionality as provided by libcurl. 

Most of the methods are available both as a synchronous and
asynchronous versions. Http.get() is the synchronous version of a
standard HTTP GET request that will return a Http.Result. The request
is perform when first accessing a method or property on that
Http.Result instance. Http.getAsync() is the asynchronous version that
will spawn a thread in the background and return a Http.AsyncResult
immediately. You can read data from the result at later point in
time. This allows you to start processing data before all data has
been received by using byChunk() or byLine() on the Http.AsyncResult
instance.

Example:
---
// Simple GET with connect timeout of 10 seconds 
Http.get("http://www.google.com").connectTimeout(dur!"seconds"(10)).toString(); 

// GET with custom data receivers 
Http http = Http("http://www.google.com");
http.onReceiveHeader = 
    (const(char)[] key, const(char)[] value) { writeln(key ~ ": " ~ value); };
http.onReceive = (ubyte[] data) { /+ drop +/ return data.length; };
http.perform();

// GET using an asynchronous range
foreach (line; Http.getAsync("http://www.google.com").byLine()) {
    // Do some expensive processing on the line while more lines are
    // received asynchronously in the background.
    writeln("asyncLine: ", line);
}

// PUT with data senders 
string msg = "Hello world";
http.onSend = (void[] data) { 
    if (msg.empty) return 0; 
    auto m = cast(void[])msg;
    size_t length = m.length;
    data[0..length] = m[0..$];  
    msg.length = 0;
    return length;
};
http.method = Http.Method.put; // defaults to POST
http.contentLength = 11; // defaults to chunked transfer if not specified
http.perform();

// Track progress
http.method = Http.Method.get;
http.url = "http://upload.wikimedia.org/wikipedia/commons/" 
           "5/53/Wikipedia-logo-en-big.png";
http.onReceive = (ubyte[] data) { return data.length; };
http.onProgress = (double dltotal, double dlnow, 
                   double ultotal, double ulnow) {
    writeln("Progress ", dltotal, ", ", dlnow, ", ", ultotal, ", ", ulnow);
    return 0;
};
http.perform();

// Send an email with SMTPS
SMTP smtp = SMTP("smtps://smtp.gmail.com");
smtp.setAuthentication("from.addr@gmail.com", "password");
smtp.mailTo = ["<to.addr@gmail.com"];
smtp.mailFrom = "<from.addr@gmail.com>";
smtp.message = "Example Message";
smtp.perform;
---

Source: $(PHOBOSSRC etc/_curl.d)

Copyright: Copyright Jonas Drewsen 2011-2012
License:  <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:  Jonas Drewsen
Credits:  The functionally is based on $(WEB _curl.haxx.se, libcurl). 
          LibCurl is licensed under a MIT/X derivate license.
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
import std.array;
import std.regex; 
import std.stream;
import std.algorithm; 
import std.encoding;
import std.concurrency; 
import std.typecons;
import std.exception;
import std.datetime;
import std.traits;
import core.thread;
import core.stdc.string; // strlen

version(unittest) {
    // Run unit test with the PHOBOS_TEST_ALLOW_NET=1 set in order to 
    // allow net traffic
    import std.stdio;
    import std.c.stdlib;
    import std.range;
    const string testUrl1 = "http://d-programming-language.appspot.com/testUrl1";
    const string testUrl2 = "http://d-programming-language.appspot.com/testUrl2";
}
version(StdDdoc) import std.stdio;

pragma(lib, "curl");

/*
  Wrapper class to provide a better interface to libcurl than using
  the plain C API.  It is recommended to use the Http/Ftp
  etc. classes instead unless you need the basic access to libcurl.
*/
private struct Curl {

    shared static this() {
        // initialize early to prevent thread races
        if (curl_global_init(CurlGlobal.all))
            throw new CurlException("Couldn't initialize libcurl");
    }
 
    shared static ~this() {
        curl_global_cleanup();
    }

    alias void[] outdata;
    alias ubyte[] indata;
    bool stopped;

    // A handle should not be used bu two thread simultanously
    private CURL* handle;
    private size_t delegate(outdata) _onSend; // May also return CURL_READFUNC_ABORT or CURL_READFUNC_PAUSE
    private size_t delegate(indata) _onReceive;
    private void delegate(const(char)[]) _onReceiveHeader;
    private CurlSeek delegate(long,CurlSeekPos) _onSeek;
    private int delegate(curl_socket_t,CurlSockType) _onSocketOption;
    private int delegate(double dltotal, double dlnow, double ultotal, double ulnow) _onProgress;
    

    /**
       Initialize the instance by creating a working curl handle.
    */
    void initialize() {
        enforce(!handle, "Curl instance already initialized");
        handle = curl_easy_init();
        enforce(handle, "Curl instance couldn't be initialized");
        stopped = false;
    }

    ~this() {
        // Cannot enforce this since emplace constructs a temporary of
        // this struct when doing its stuff. Emplace is used by
        // RefCounted.
        // enforce(handle, "No valid curl handle in Curl instance");
        if (!handle) return;
        curl_easy_cleanup(handle);
    }

    private void _check(CURLcode code) {
        if (code != CurlError.ok) {
            throw new CurlException(errorString(code));
        }
    }

    private string errorString(CURLcode code) {
        return to!string(curl_easy_strerror(code)) ~ " on handle " ~ to!string(handle);
    }

    private void throwOnStopped() {
        if (stopped) 
            throw new CurlException("Curl instance called after being cleaned up");
    }
    
    /** 
        Stop and invalidate this curl instance.
        Do not call this from inside a callback handler e.g. onReceive.
    */
    void cleanup() {
        throwOnStopped();
        stopped = true;
        curl_easy_cleanup(this.handle);
    }

    /**
       Pausing and continuing transfers.
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
       Clear a pointer option.
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
    CURLcode perform(bool throwOnError = true) {
        throwOnStopped();
        CURLcode code = curl_easy_perform(this.handle);
        if (throwOnError)
            _check(code);
        return code;
    }

    /**
       The event handler that receives incoming data.

       Params:
       callback = the callback that receives the ubyte[] data.
       Be sure to copy the incoming data and not store
       a slice.
       Example:
       ----
curl.onReceive = (ubyte[] data) { writeln("Got data", cast(char[]) data); return data.length;};
       ----
    */
    @property void onReceive(size_t delegate(indata) callback) {
        _onReceive = (indata id) { 
            if (stopped)
                throw new CurlException("Receive callback called on cleaned up Curl instance");
            return callback(id);
        };
        set(CurlOption.file, cast(void*) &this);
        set(CurlOption.writefunction, cast(void*) &Curl._receiveCallback);
    }

    /**
       The event handler that receives incoming headers for protocols
       that uses headers.

       Params:
       callback = the callback that receives the header string.
       Make sure the callback copies the incoming params if
       it needs to store it because they are references into
       the backend and may very likely change.
       Example:
       ----
curl.onReceiveHeader = (const(char)[] header) { writeln(header); };
       ----
    */
    @property void onReceiveHeader(void delegate(const(char)[]) callback) {
        _onReceiveHeader = (const(char)[] od) {
            if (stopped)
                throw new CurlException("Receive header callback called on cleaned up Curl instance");
            callback(od);
        };
        set(CurlOption.writeheader, cast(void*) &this);
        set(CurlOption.headerfunction, cast(void*) &Curl._receiveHeaderCallback);
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
    @property void onSend(size_t delegate(outdata) callback) {
        _onSend = (outdata od) {
            if (stopped)
                throw new CurlException("Send callback called on cleaned up Curl instance");
            return callback(od);
        };
        set(CurlOption.infile, cast(void*) &this);
        set(CurlOption.readfunction, cast(void*) &Curl._sendCallback);
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
    @property void onSeek(CurlSeek delegate(long, CurlSeekPos) callback) {
        _onSeek = (long ofs, CurlSeekPos sp) { 
            if (stopped)
                throw new CurlException("Seek callback called on cleaned up Curl instance");
            return callback(ofs, sp);
        };
        set(CurlOption.seekdata, cast(void*) &this);
        set(CurlOption.seekfunction, cast(void*) &Curl._seekCallback);
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
    @property void onSocketOption(int delegate(curl_socket_t, CurlSockType) callback) {
        _onSocketOption = (curl_socket_t sock, CurlSockType st) {
            if (stopped)
                throw new CurlException("Socket option callback called on cleaned up Curl instance");
            return callback(sock, st);
        };
        set(CurlOption.sockoptdata, cast(void*) &this);
        set(CurlOption.sockoptfunction, cast(void*) &Curl._socketOptionCallback);
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
    @property void onProgress(int delegate(double dltotal, double dlnow, double ultotal, double ulnow) callback) {
        _onProgress = (double dlt, double dln, double ult, double uln) {
            if (stopped)
                throw new CurlException("Progress callback called on cleaned up Curl instance");
            return callback(dlt, dln, ult, uln);
        };
        set(CurlOption.noprogress, 0);
        set(CurlOption.progressdata, cast(void*) &this);
        set(CurlOption.progressfunction, cast(void*) &Curl._progressCallback);
    }
 
    // Internal C callbacks to register with libcurl
    extern (C) private static size_t _receiveCallback(const char* str, size_t size, size_t nmemb, void* ptr) {
        Curl* b = cast(Curl*) ptr;
        if (b._onReceive != null)
            return b._onReceive(cast(indata)(str[0..size*nmemb]));
        return size*nmemb;
    }

    extern (C) private static size_t _receiveHeaderCallback(const char* str, size_t size, size_t nmemb, void* ptr) {
        Curl* b = cast(Curl*) ptr;
        auto s = str[0..size*nmemb].chomp;
        if (b._onReceiveHeader != null) 
            b._onReceiveHeader(s); 

        return size*nmemb;
    }

    extern (C) private static size_t _sendCallback(char *str, size_t size, size_t nmemb, void *ptr)           
    {                                                                                         
        Curl* b = cast(Curl*) ptr;
        void[] a = cast(void[]) str[0..size*nmemb];
        if (b._onSend == null)
            return 0;
        return b._onSend(a);
    }

    extern (C) private static int _seekCallback(void *ptr, curl_off_t offset, int origin)           
    {                                                                                         
        Curl* b = cast(Curl*) ptr;
        if (b._onSeek == null)
            return CurlSeek.cantseek;

        // origin: CurlSeekPos.set/current/end
        // return: CurlSeek.ok/fail/cantseek
        return b._onSeek(cast(long) offset, cast(CurlSeekPos) origin);
    }

    extern (C) private static int _socketOptionCallback(void *ptr, curl_socket_t curlfd, curlsocktype purpose)          
    {                                                                                         
        Curl* b = cast(Curl*) ptr;
        if (b._onSocketOption == null)
            return 0;

        // return: 0 ok, 1 fail
        return b._onSocketOption(curlfd, cast(CurlSockType) purpose);
    }

    extern (C) private static int _progressCallback(void *ptr, double dltotal, double dlnow, double ultotal, double ulnow)
    {                                                                                         
        Curl* b = cast(Curl*) ptr;
        if (b._onProgress == null)
            return 0;

        // return: 0 ok, 1 fail
        return b._onProgress(dltotal, dlnow, ultotal, ulnow);
    }

}

/**
  Mixin template for all supported curl protocols. 
  This documentation should really be in the Http struct but
  the documentation tool does not support a mixin to put its
  doc strings where a mixin is done.
*/
private mixin template Protocol() {

    /// Escape a string.
    string escape(in const(char)[] str) {
        char * ptr = curl_easy_escape(p.curl.handle, cast(char*)str.ptr, str.length);
        enforce(ptr, new CurlException("Error escaping string"));
        string res = ptr[0..strlen(ptr)].idup;
        curl_free(ptr);
        return res;
    }

    /// Unescape a string.
    string unescape(in const(char)[] str) {
        int outlen;
        char * ptr = curl_easy_unescape(p.curl.handle, cast(char*)str.ptr, str.length, &outlen);
        enforce(ptr, new CurlException("Error escaping string"));
        string res = ptr[0..outlen].idup;
        curl_free(ptr);
        return res;
    }

    unittest {
        string t = "Testing 123 \u00FE \u00B6 \u03A0"; 
        auto http = Http("");
        string t1 = http.escape(t);
        string t2 = http.unescape(t1);
        assert(t == t2, "Escape and unescape on a string did not give the same string");
    }

    /**
       True if the instance is stopped and invalid.
    */
    @property bool isStopped() {
        return p.curl.stopped;
    }

    /// Stop and invalidate this instance.
    void cleanup() {
        p.curl.cleanup();
    }

    /** Set verbose.
        This will print request information to stderr.
     */
    @property void verbose(bool on) {
        p.curl.set(CurlOption.verbose, on ? 1L : 0L);
    }

    // Connection settings

    /// Set timeout for activity on connection.
    @property void dataTimeout(Duration d) {
        p.curl.set(CurlOption.timeout_ms, d.total!"msecs"());
    }

    /// Set timeout for connecting.
    @property void connectTimeout(Duration d) {
        p.curl.set(CurlOption.connecttimeout_ms, d.total!"msecs"());
    }
 
    // Network settings

    /// The URL to specify the location of the resource.
    @property void url(in const(char)[] url) {
        p.curl.set(CurlOption.url, url);
    }

    /// DNS lookup timeout.
    @property void dnsTimeout(Duration d) {
        p.curl.set(CurlOption.dns_cache_timeout, d.total!"msecs"());
    }

    /**
       The network interface to use in form of the the IP of the interface.
       Example:
       ----
theprotocol.netInterface = "192.168.1.32";
       ----
    */
    @property void netInterface(const(char)[] i) {
        p.curl.set(CurlOption.intrface, cast(char*)i);
    }

    /**
       Set the local outgoing port to use.
       Params:
       port = the first outgoing port number to try and use
    */
    @property void localPort(int port) {
        p.curl.set(CurlOption.localport, cast(long)port);
    }

    /**
       Set the local outgoing port range to use.
       This can be used together with the localPort property.
       Params:
       range = if the first port is occupied then try this many 
       port number forwards
    */
    @property void localPortRange(int range) {
        p.curl.set(CurlOption.localportrange, cast(long)range);
    }

    /// Set the tcp nodelay socket option on or off.
    @property void tcpNoDelay(bool on) {
        p.curl.set(CurlOption.tcp_nodelay, cast(long) (on ? 1 : 0) );
    }

    // Authentication settings

    /**
       Set the user name, password and optionally domain for authentication purposes.
    
       Some protocols may need authentication in some cases. Use this
       function to provide credentials.

       Params:
       username = the username
       password = the password
       domain = used for NTLM authentication only and is set to the NTLM domain name
    */
    void setAuthentication(const(char)[] username, const(char)[] password, const(char)[] domain = "") {
        if (domain != "")
            username = domain ~ "/" ~ username;
        p.curl.set(CurlOption.userpwd, cast(char*)(username ~ ":" ~ password));
    }

    unittest {
        if (!netAllowed) return;
        Http http = Http("http://www.protected.com");
        http.onReceiveHeader = 
            (const(char)[] key, const(char)[] value) { /* writeln(key ~ ": " ~ value); */ };
        http.onReceive = (ubyte[] data) { return data.length; };
        http.setAuthentication("myuser", "mypassword");
        http.perform();
    }

    /**
       The event handler that gets called when data is needed for
       sending. The length of the void[] specifies the max number of
       bytes that can be send. 

       Returns:
       The callback returns the number of elements in the buffer that has been filled and is ready to send.

       Example:
       ----
string msg = "Hello world";
client.onSend = delegate size_t(void[] data) { 
if (msg.empty) return 0; 
auto m = cast(void[])msg;
auto l = m.length;
data[0..l] = m[0..$];  
msg.length = 0;
return l;
};
        ----
    */
    @property void onSend(size_t delegate(void[]) callback) {
        p.curl.clear(CurlOption.postfields); // cannot specify data when using callback
        p.curl.onSend(callback);
    }

    /**
       The event handler that receives incoming data. Be sure to copy
       the incoming ubyte[] since it is not guaranteed to be valid
       aften the callback returns.

       Example:
       ----
client.onReceive = (ubyte[] data) { writeln("Got data", cast(char[]) data); return data.length;};
       ----
    */
    @property void onReceive(size_t delegate(ubyte[]) callback) {
        p.curl.onReceive(callback);
    }

    /**
       The event handler that gets called to inform of upload/download progress.
    
       Params:
       dltotal = total bytes to download
       dlnow = currently downloaded bytes
       ultotal = total bytes to upload
       ulnow = currently uploaded bytes
    
       Returns:
       Return 0 from the callback to signal success, return non-zero to abort transfer

       Example:
       ----
client.onProgress = delegate int(double dl, double dln, double ul, double ult) { 
writeln("Progress: downloaded ", dln, " of ", dl);
writeln("Progress: uploaded ", uln, " of ", ul);  
       };
       ----
    */
    @property void onProgress(int delegate(double dltotal, double dlnow, double ultotal, double ulnow) callback) {
        p.curl.onProgress(callback);
    }

    private void _assignProtocolParams(RParams)(ref const(RParams) requestParams) {

        if (requestParams.url) {
            url = requestParams.url;
        }
        Duration nodur = dur!"nsecs"(0);
        if (requestParams.dataTimeout != nodur) {
            dataTimeout = requestParams.dataTimeout;
        }
        if (requestParams.connectTimeout != nodur) {
            connectTimeout = requestParams.connectTimeout;
        }
        if (requestParams.dnsTimeout != nodur) {
            dnsTimeout = requestParams.dnsTimeout;
        }
        if (requestParams.netInterface) {
            netInterface = requestParams.netInterface;
        }
        if (requestParams.port) {
            localPort = requestParams.port;
        }
        if (requestParams.range) {
            localPort = requestParams.range;
        }
        if (requestParams.tcpNoDelay) {
            tcpNoDelay = requestParams.tcpNoDelay;
        }
        if (requestParams.username) {
            setAuthentication(requestParams.username,
                              requestParams.password,
                              requestParams.domain);
        }
    }
}

// Mixin properties to set parameters. 
// This is done using functions and not by allowing access to 
// the parameters member variables themselves since it allows for
// a nicer calling format: Http.get("...").dataTimeout(100).byLine()
// Only parameters that makes sense to expose is exposed here.
private mixin template ProtocolRequestParamsSetters(OWNER, T) {

    @property ref OWNER url(T.STR v) { 
        rp._requestParams.url = v; 
        return this;
    }
    @property ref OWNER dataTimeout(Duration v) { 
        rp._requestParams.dataTimeout = v; 
        return this;
    }
    @property ref OWNER connectTimeout(Duration v) { 
        rp._requestParams.connectTimeout = v; 
        return this;
    }
    @property ref OWNER dnsTimeout(Duration v) { 
        rp._requestParams.dnsTimeout = v; 
        return this;
    }
    @property ref OWNER netInterface(T.STR v) { 
        rp._requestParams.netInterface = v; 
        return this;
    }
    @property ref OWNER localPort(int v) { 
        rp._requestParams.port= v; 
        return this;
    }
    @property ref OWNER localPortRange(int v) { 
        rp._requestParams.range = v;
        return this;
    }
    @property ref OWNER tcpNoDelay(bool v) { 
        rp._requestParams.tcpNoDelay = v; 
        return this;
    }
    ref OWNER authentication(T.STR u, T.STR p, T.STR d = "") { 
        rp._requestParams.username = u; 
        rp._requestParams.password = p; 
        rp._requestParams.domain = d; 
        return this;
    }
}

private mixin template ByChunkSync(alias impl) {

    auto byChunk(size_t chunkSize) {

        static struct SyncChunkInputRange {

            alias ubyte[] ChunkType;
            private size_t chunkSize;
            private ChunkType _bytes;
            private size_t len;
            private size_t offset;

            this(ubyte[] bytes, size_t chunkSize) {
                this._bytes = bytes;
                this.len = _bytes.length;
                this.chunkSize = chunkSize;
            }

            @property auto empty() {
                return offset == len;
            }
                
            @property ChunkType front() {
                size_t nextOffset = offset + chunkSize;
                if (nextOffset > len) nextOffset = len;
                return _bytes[offset..nextOffset];
            }
                
            void popFront() {
                offset = offset + chunkSize;
                if (offset > len) offset = len;
            }
        }
        execute();
        return SyncChunkInputRange(impl._bytes, chunkSize);
    }
}

private mixin template ByLineSync() {

    auto byLine(Terminator = char, Char = char)(bool keepTerminator = false, 
                                                Terminator terminator = '\x0a') {
            
        // This range is using algorithm splitter and could be
        // optimized by not using that. 
        static struct SyncLineInputRange {

            private Char[] lines;
            private Char[] current;
            private bool currentValid;
            private bool keepTerminator;
            private Terminator terminator;
                
            this(Char[] lines, bool kt, Terminator terminator) {
                this.lines = lines;
                this.keepTerminator = kt;
                this.terminator = terminator;
                currentValid = true;
                popFront();
            }

            @property bool empty() {
                return !currentValid;
            }
                
            @property Char[] front() {
                enforce(currentValid, "Cannot call front() on empty range");
                return current;
            }
                
            void popFront() {
                enforce(currentValid, "Cannot call popFront() on empty range");
                if (lines.empty) {
                    currentValid = false;
                    return;
                }

                if (keepTerminator) {
                    auto r = findSplitAfter(lines, [ terminator ]);
                    if (r[0].empty) {
                        current = r[1];
                        lines = r[0];
                    } else {
                        current = r[0];
                        lines = r[1];
                    }
                } else {
                    auto r = findSplit(lines, [ terminator ]);
                    current = r[0];
                    lines = r[2];
                }
            }
        }
        execute();
        return SyncLineInputRange(toString!Char()[0..$], keepTerminator, terminator);
    }

}

private mixin template TryEnsureUnit(Proto) if ( is(Proto == Http) ) {

    void tryEnsureUnits() {
        while (true) {
            final switch (state) {
            case State.needUnits:
                if (asyncResult._running == RunState.done) {
                    state = State.done;
                    break;
                }
                receive(
                        (Tid origin, Message!(immutable(Unit)[]) _data) { 
                            if (origin != workerTid)
                                return false;
                            units = cast(Unit[]) _data.data;
                            state = State.gotUnits;
                            return true;
                        },
                        (Tid origin, Message!(Tuple!(string,string)) header) {
                            if (origin != workerTid)
                                return false;
                            asyncResult._headers[header.data[0]] = header.data[1];
                            return true;
                        },
                        (Tid origin, Message!(Http.StatusLine) l) {
                            if (origin != workerTid)
                                return false;
                            asyncResult._running = RunState.statusReady;
                            asyncResult._statusLine = l.data;
                            return true;
                        },
                        (Tid origin, Message!bool f) { 
                            if (origin != workerTid)
                                return false;
                            state = state.done; 
                            asyncResult._running = RunState.done; 
                            return true;
                        }
                        );
                break;
            case State.gotUnits: return;
            case State.done:
                return;
            }
        }
    }
}

private mixin template TryEnsureUnit(Proto) if ( is(Proto == Ftp) ) {

    void tryEnsureUnits() {
        while (true) {
            final switch (state) {
            case State.needUnits:
                if (asyncResult._running == RunState.done) {
                    state = State.done;
                    break;
                }
                receive(
                        (Tid origin, Message!(immutable(Unit)[]) _data) { 
                            if (origin != workerTid)
                                return false;
                            units = cast(Unit[]) _data.data;
                            state = State.gotUnits;
                            return true;
                        },
                        (Tid origin, Message!bool f) { 
                            if (origin != workerTid)
                                return false;
                            state = state.done; 
                            asyncResult._running = RunState.done; 
                            return true;
                        }
                        );
                break;
            case State.gotUnits: return;
            case State.done:
                return;
            }
        }
    }
}

/*
  Main thread part of the message passing protocol used for all async
  curl protocols.
 */
private mixin template WorkerThreadProtocol(Unit, alias units, Proto) {

    ~this() {
        workerTid.send(true);
    }

    @property bool empty() {
        tryEnsureUnits();
        return state == State.done;
    }

    @property Unit[] front() {
        tryEnsureUnits();
        assert(state == State.gotUnits, "Expected " ~ to!string(State.gotUnits) ~ " but got " ~ to!string(state));
        return units;
    }
                
    void popFront() {
        tryEnsureUnits();
        assert(state == State.gotUnits, "Expected " ~ to!string(State.gotUnits) ~ " but got " ~ to!string(state));
        state = State.needUnits;
        // Send to worker thread for buffer reuse
        workerTid.send(cast(immutable(Unit)[]) units);
        units = null;
    }

    enum State {
        needUnits,
            gotUnits,
            done
            }
    State state;

    mixin TryEnsureUnit!Proto;
}


private mixin template ByChunkAsync(Proto, alias impl) {

    // Workaround bug #2458
    // It should really be defined inside th byChunk method.
    static struct AsyncChunkInputRange {
        
        private ubyte[] chunk;
        private RefCounted!RImpl asyncResult;
        private Tid workerTid;
        
        this(RefCounted!RImpl parent, Tid tid, size_t chunkSize, size_t transmitBuffers) {
            asyncResult = parent;
            asyncResult._running = RunState.running;
            workerTid = tid;
            state = State.needUnits;
            
            // Send buffers to other thread for it to use.
            // Since no mechanism is in place for moving ownership
            // we simply cast to immutable here and cast it back
            // to mutable in the receiving end.
            foreach (i ; 0..transmitBuffers) {
                ubyte[] arr;
                arr.length = chunkSize;
                workerTid.send(cast(immutable(ubyte)[])arr);
            }
        }
        
        mixin WorkerThreadProtocol!(ubyte, chunk, Proto);
    }

    auto byChunk(size_t chunkSize, size_t transmitBuffers = 5) {
        // 50 is just an arbitrary number for now
        setMaxMailboxSize(thisTid, 50, OnCrowding.block);
        Tid tid = spawn(&(_spawnAsyncRequest!(Proto, ubyte)));
        tid.send(thisTid);
        tid.send(impl._requestParams);
        return AsyncChunkInputRange(this.rp, tid, chunkSize, transmitBuffers);
    }
}

private mixin template ByLineAsync(Proto, alias impl) {

    // Workaround bug #2458
    // It should really be defined inside th byLine method.
    static struct AsyncLineInputRange(Char) {
        
        private RefCounted!RImpl asyncResult;
        private Tid workerTid;
        private Char[] line;
        
        this(RefCounted!RImpl parent, Tid tid, size_t transmitBuffers) {
            asyncResult = parent;
            asyncResult._running = RunState.running;
            workerTid = tid;
            state = State.needUnits;
            
            // Send buffers to other thread for it to use.
            // Since no mechanism is in place for moving ownership
            // we simply cast to immutable here and cast it back
            // to mutable in the receiving end.
            foreach (i ; 0..transmitBuffers) {
                Char[] arr;
                arr.length = asyncResult._defaultStringBufferSize;
                workerTid.send(cast(immutable(Char)[])arr);
            }
        }
        
        mixin WorkerThreadProtocol!(Char, line, Proto);
    }

    auto byLine(Terminator = char, Char = char)(bool keepTerminator = false, 
                                                Terminator terminator = '\x0a',
                                                size_t transmitBuffers = 5) {            

        // 50 is just an arbitrary number for now
        setMaxMailboxSize(thisTid, 50, OnCrowding.block);
        Tid tid = spawn(&(_spawnAsyncRequest!(Proto, Char, Terminator)));
        tid.send(thisTid);
        tid.send(impl._requestParams);
        tid.send(terminator);
        tid.send(keepTerminator);
        static if ( is(Proto == Ftp) ) {
            tid.send(encodingName().idup);
        }
        return AsyncLineInputRange!Char(this.rp, tid, transmitBuffers);
    }
}

/*
  Decode ubyte[] array using the provided EncodingScheme up to maxChars
  Returns: Tuple of ubytes read and the Char[] characters decoded.
           Not all ubytes are guaranteed to be read in case of decoding error.
*/
private Tuple!(size_t,Char[]) decodeString(Char = char)(const(ubyte)[] data, 
                                                        EncodingScheme scheme,
                                                        size_t maxChars = size_t.max) {
    Char[] res;
    size_t startLen = data.length;
    size_t charsDecoded = 0;
    while (data.length && charsDecoded < maxChars) {
        dchar dc = scheme.safeDecode(data);
        if (dc == INVALID_SEQUENCE) {
            return typeof(return)(size_t.max, cast(Char[])null);
        }
        charsDecoded++;
        res ~= dc;
    }
    return typeof(return)(startLen-data.length, res);
}

/*
  Decode ubyte[] array using the provided EncodingScheme until a the
  line terminator specified is found. The basesrc parameter is
  effectively prepended to src as the first thing.

  This function is used for decoding as much of the src buffer as
  possible until either the terminator is found or decoding fails. If
  it fails as the last data in the src it may mean that the src buffer
  were missing some bytes in order to represent a correct code
  point. Upon the next call to this function more bytes have been
  received from net and the failing bytes should be given as the
  basesrc parameter. It is done this way to minimize data copying.

  Returns: true if a terminator was found 
           Not all ubytes are guaranteed to be read in case of decoding error.
	   any decoded chars will be inserted into dst.
*/
private bool decodeLineInto(Terminator, Char = char)(ref ubyte[] basesrc, 
                                                     ref ubyte[] src, ref Char[] dst,
						     EncodingScheme scheme,
						     Terminator terminator) {
    Char[] res;
    size_t startLen = src.length;
    size_t charsDecoded = 0;
    // if there is anything in the basesrc then try to decode that
    // first.
    if (basesrc.length != 0) {
        // Try to ensure 4 entries in the basesrc by copying from src.
        size_t blen = basesrc.length;
        size_t len = (basesrc.length + src.length) >= 4 ? 4 : basesrc.length + src.length;
        basesrc.length = len;
        dchar dc = scheme.safeDecode(basesrc);
        if (dc == INVALID_SEQUENCE) {
            if (len == 4)
                throw new CurlException("Invalid code sequence");
            return false;
        }
        dst ~= dc;
        src = src[len-basesrc.length-blen .. $]; // remove used ubytes from src
	basesrc.length = 0;
    }

    while (src.length) {
        typeof(src) lsrc = src[];
        dchar dc = scheme.safeDecode(src);
        if (dc == INVALID_SEQUENCE) {
            if (src.empty) {
                // The invalid sequence was in the end of the src.
                // Maybe there just need to be more bytes available so
                // we put these last bytes back to src for later use.
                src = lsrc;
                return false;
            }
            dc = '?';
        }
        dst ~= dc;
        
        if (dst.endsWith(terminator)) 
            return true;
    }
    return false; // no terminator found
}

/**
   Http client functionality.
*/
struct Http {

    mixin Protocol;
    static private uint defaultMaxRedirects = 10;

    private struct Impl {
        Curl curl;
        string[string] _headers;
        
        /// The status line of the final subrequest in a request.
        StatusLine status;
        private void delegate(StatusLine) _onReceiveStatusLine;
        
        /// The HTTP method to use.
        Method method = Method.get;
    }

    private RefCounted!Impl p;

    /** Time condition enumeration (an alias of CurlTimeCond):
        TimeCond.{none,ifmodsince,ifunmodsince,lastmod,last}
    */
    alias CurlTimeCond TimeCond;

    /**
       Constructor taking the url as parameter.
    */
    this(in const(char)[] url) {
        p.RefCounted.initialize();
        p.curl.initialize();
        p.curl.set(CurlOption.url, url);
        version (unittest) verbose(true);
    }

    /// Add a header string e.g. "X-CustomField: Something is fishy".
    void addHeader(in const(char)[] key, in const(char)[] value) {
        string * h = (key in p._headers);
        if (h is null)
            return setHeader(key,value);
        // http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.2
        // states that multiple headers with same field name must be
        // representable as a single header with comma separated values.
        (*h) ~= "," ~ value.idup;
    }

    /// Add a header string e.g. "X-CustomField: Something is fishy".
    void setHeader(in const(char)[] key, in const(char)[] value) {
        p._headers[key.idup] = value.idup;
    }

    /// Http method used.
    @property void method(Method m) {
        p.method = m;
    }
    /// ditto
    @property Method method() {
        return p.method;
    }

    /**
       Http status line of last response. One call to perform may
       result in several requests because of redirection.
    */
    @property StatusLine statusLine() {
        return p.status;
    }

    // Set the active cookie string e.g. "name1=value1;name2=value2"
    void setCookie(in const(char)[] cookie) {
        p.curl.set(CurlOption.cookie, cookie);
    }

    /// Set a file path to where a cookie jar should be read/stored.
    void setCookieJar(in const(char)[] path) {
        p.curl.set(CurlOption.cookiefile, path);
        p.curl.set(CurlOption.cookiejar, path);
    }

    /// Flush cookie jar to disk.
    void flushCookieJar() {
        p.curl.set(CurlOption.cookielist, "FLUSH");
    }

    /// Clear session cookies.
    void clearSessionCookies() {
        p.curl.set(CurlOption.cookielist, "SESS");
    }

    /// Clear all cookies.
    void clearAllCookies() {
        p.curl.set(CurlOption.cookielist, "ALL");
    }

    /**
       Set time condition on the request.

       Parameters:
       cond:  CurlTimeCond.{none,ifmodsince,ifunmodsince,lastmod}
       secsSinceEpoch: The time value
    */
    void setTimeCondition(Http.TimeCond cond, DateTime timestamp) {
        p.curl.set(CurlOption.timecondition, cond);
        long secsSinceEpoch = (timestamp - DateTime(1970, 1, 1)).total!"seconds";
        p.curl.set(CurlOption.timevalue, secsSinceEpoch);
    }

    /** Convenience function that simply does a HTTP HEAD on the
        specified URL. 

        Example:
        ----
auto res = Http.head("http://www.digitalmars.com")
writeln(res.headers["Content-Length"]);
        ----
     
        Returns:
        A $(XREF _curl, Http.Result) object.
    */
    static Result head(in const(char)[] url) {
        return Result(url, Method.head);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.head(testUrl1);
        auto sl = res.statusLine;
        assert(sl.majorVersion == 1, "head() statusLine majorVersion is not 1 ");
        assert(sl.code == 200, "head() statusLine code is not 200");
        assert(res.headers["content-type"] == "text/plain;charset=utf-8", "head() content-type is incorrect");
    }

    /** Asynchronous HTTP HEAD to the specified URL. 
        Callbacks are not supported when using this method (e.g. onReceive).

        Example:
        ----
auto res = Http.headAsync("http://www.digitalmars.com");
writeln(res.byChunk(100).front);
        ----

        Returns:
        A $(XREF _curl, Http.AsyncResult) object.
    */
    static AsyncResult headAsync(string url) {
        return AsyncResult(url, "", "", Method.head);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.headAsync(testUrl1);
        res.byChunk(1).empty;
        auto sl = res.statusLine;
        assert(sl.majorVersion == 1, "headAsync() statusLine majorVersion is not 1");
        assert(sl.code == 200, "headAsync() statusLine code is not 200");
        assert(res.headers["content-type"] == "text/plain;charset=utf-8", "headAsync() content-type is incorrect");
    }

    /** Convenience function that simply does a HTTP GET on the
        specified URL. 
     
        Example:
        ----
auto res = Http.get("http://www.digitalmars.com");
writeln(res.toString());
        ----

        Returns:
        A $(XREF _curl, Http.Result) object.
    */
    static Result get(in const(char)[] url) {
        return Result(url, Method.get);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.get(testUrl1);
        assert(res.bytes[0..11] == [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100], "get() returns unexpected content " ~ to!string(res.bytes[0..11]));
        assert(res.toString()[0..11] == "Hello world", "get() returns unexpected text "); 
    }

    /** Asynchronous HTTP GET to the specified URL. 
        Callbacks are not supported when using this method (e.g. onReceive).

        Example:
        ----
auto res = Http.getAsync("http://www.digitalmars.com");
writeln(res.byChunk(100).front);
        ----

        Returns:
        A $(XREF _curl, Http.AsyncResult) object.
    */
    static AsyncResult getAsync(string url) {
        return AsyncResult(url, "", "", Method.get);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.getAsync(testUrl1);
        auto byline = res.byLine(true);
        assert(byline.front[0..11] == "Hello world", "getAsync() returns unexpected text");
        auto wlen = walkLength(byline);
        assert(wlen == 1, "Did not read 1 lines getAsync().byLine() but " ~ to!string(wlen));
        
        res = Http.getAsync(testUrl1);
        auto bychunk = res.byChunk(100);
        assert(bychunk.front[0..11] == [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100], 
               "getAsync().byChunk() returns unexpected content");
        wlen = walkLength(bychunk);
    }

    /** Convenience function that simply does a HTTP POST on the
        specified URL. 

        Example:
        ----
auto res = Http.post("http://d-programming-language.appspot.com/testUrl2", [1,2,3,4]);
writeln(res.toString());
        ----

        Returns:
        A $(XREF _curl, Http.Result) object.
    */
    static Result post(in const(char)[] url, const(void)[] postData, const(char)[] contentType = "application/octet-stream") {
        Result res = Result(url, Method.post);
        const(char)[] k = "Content-Type";
        res.header(k, contentType);
        res.postData(postData);
        return res;
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.post(testUrl2, [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]);
        assert(res.bytes[0..11] == [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100], 
               "post() returns unexpected content " ~ to!string(res.bytes[0..11]));
    }

    /// ditto
    static Result post(in const(char)[] url, const(char)[] postData, const(char)[] contentType = "text/plain; charset=utf-8") {
        return post(url, cast(const(void)[]) postData, contentType);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.post(testUrl2, "Hello world");
        assert(res.toString()[0..11] == "Hello world", "post() returns unexpected text "); 
    }

    /** Convenience POST function as the one above but for associative arrays that
        will get application/form-url-encoded.
        You must escape the params yourself.
    */
    static Result post(in const(char)[] url, string[string] params) {
        string delim = "";
        string data = "";
        foreach (key; params.byKey()) {
            data ~= delim ~ key ~ "=" ~ params[key];
        }
        // string data = joiner(map!(delegate (string a) { return a ~ '=' ~ params[a]; })(params.keys), '&');
        return post(url, cast(immutable(void)[]) data, "application/form-url-encoded");
    }

    unittest {
        if (!netAllowed) return;
        string[string] fields;
        fields["Hello"] = "World";
        auto res = Http.post(testUrl2, fields);
        assert(res.toString()[0..11] == "Hello=World", "post() returns unexpected text"); 
    }
     
    /** Async HTTP POST to the specified URL. 
        Callbacks are not supported when using this method (e.g. onReceive).

        Example:
        ----
auto res = Http.postAsync("http://d-programming-language.appspot.com/testUrl2", 
                          "Posting this data");
writeln(res.byChunk(100).front);
        ----

        Returns:
        A $(XREF _curl, Http.AsyncResult) object.
    */
    static AsyncResult postAsync(string url, immutable(void)[] postData, string contentType = "application/octet-stream") {
        return AsyncResult(url, postData, contentType, Method.post);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.postAsync(testUrl2, [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]);
        auto byline = res.byLine();
	auto line = byline.front;
        assert(line[0..11] == "Hello world", "postAsync() returns unexpected text " ~ line);
        auto wlen = walkLength(byline);
        assert(wlen == 1, "Did not read 1 lines postAsync().byLine() but " ~ to!string(wlen));

        res = Http.postAsync(testUrl2, [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]);
        auto bychunk = res.byChunk(100);
        assert(bychunk.front[0..11] == [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100], 
               "postAsync().byChunk() returns unexpected content");
        wlen = walkLength(bychunk);
    }

    /// ditto
    static AsyncResult postAsync(string url, string data, string contentType = "text/plain; charset=utf-8") {
        return postAsync(url, cast(immutable(void)[]) data, contentType);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.postAsync(testUrl2, "Hello world");
        auto byline = res.byLine();
        assert(byline.front[0..11] == "Hello world", "postAsync() returns unexpected text");
        auto wlen = walkLength(byline);
        assert(wlen == 1, "Did not read 1 lines postAsync().byLine() but " ~ to!string(wlen));
    }

    /** Convenience asynchronous POST function as the one above but for
        associative arrays that will get application/form-url-encoded.
        You must escape the params yourself.
    */
    static AsyncResult postAsync(string url, string[string] params) {
        string delim = "";
        string data = "";
        foreach (key; params.byKey()) {
            data ~= delim ~ key ~ "=" ~ params[key];
            delim = "&";
        }
        // string data = joiner(map!(delegate (string a) { return a ~ '=' ~ params[a]; })(params.keys), '&');
        return postAsync(url, cast(immutable(void)[]) data, "application/form-url-encoded");
    }

    unittest {
        if (!netAllowed) return;
        string[string] fields;
        fields["Hello"] = "World";
        auto res = Http.postAsync(testUrl2, fields);
        auto byline = res.byLine();
        assert(byline.front[0..11] == "Hello=World", "postAsync() returns unexpected text");
        auto wlen = walkLength(byline);
        assert(wlen == 1, "Did not read 1 lines postAsync().byLine() but " ~ to!string(wlen));
    }

    /** Convenience function that simply does a HTTP PUT on the
        specified URL. 

        Example:
        ----
auto res = Http.put("http://d-programming-language.appspot.com/testUrl2", 
                    "Putting this data");
writeln(res.code);
        ----

        Returns:
        A $(XREF _curl, Http.Result) object.
    */
    static Result put(in const(char)[] url, const(void)[] putData, const(char)[] contentType = "application/octet-stream") {
        Result res = Result(url, Method.put);
        const(char)[] k = "Content-Type";
        res.header(k, contentType);
        res.postData(putData);
        return res;
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.put(testUrl2, [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]);
        assert(res.bytes[0..11] == [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100], 
               "put() returns unexpected content " ~ to!string(res.bytes[0..11]));
    }

    /// ditto
    static Result put(in const(char)[] url, const(char)[] putData, const(char)[] contentType = "text/plain; charset=utf-8") {
        return put(url, cast(const(void)[]) putData, contentType);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.put(testUrl2, "Hello world");
        assert(res.toString()[0..11] == "Hello world", "put() returns unexpected text "); 
    }

    /** Asynchronous HTTP PUT to the specified URL. 
        Callbacks are not supported when using this method (e.g. onReceive).

        Example:
        ----
auto res = Http.putAsync("http://d-programming-language.appspot.com/testUrl2", 
                         "Posting this data");
writeln(res.byChunk(100).front);
        ----

        Returns:
        A $(XREF _curl, Http.AsyncResult) object.
    */
    static AsyncResult putAsync(string url, immutable(void)[] putData, string contentType = "application/octet-stream") {
        return AsyncResult(url, putData, contentType, Method.put);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.putAsync(testUrl2, [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]);
        auto byline = res.byLine();
        assert(byline.front[0..11] == "Hello world", "putAsync() returns unexpected text");
        auto wlen = walkLength(byline);
        assert(wlen == 1, "Did not read 1 lines putAsync().byLine() but " ~ to!string(wlen));

        res = Http.putAsync(testUrl2, [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]);
        auto bychunk = res.byChunk(100);
        assert(bychunk.front[0..11] == [72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100], 
               "putAsync().byChunk() returns unexpected content");
        wlen = walkLength(bychunk);
    }

    /// ditto
    static AsyncResult putAsync(string url, string putData, string contentType = "text/plain; charset=utf-8") {
        return putAsync(url, cast(immutable(void)[]) putData, contentType);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.putAsync(testUrl2, "Hello world");
        auto byline = res.byLine();
        assert(byline.front[0..11] == "Hello world", "putAsync() returns unexpected text");
        auto wlen = walkLength(byline);
        assert(wlen == 1, "Did not read 1 lines putAsync().byLine() but " ~ to!string(wlen));
    }

    /** Convenience function that simply does a HTTP DELETE on the
        specified URL. 

        Example:
        ----
auto res = Http.del("http://d-programming-language.appspot.com/testUrl2");
writeln(res.toString());
        ----
     
        Returns:
        A $(XREF _curl, Http.Result) object.
    */
    static Result del(in const(char)[] url) {
        return Result(url, Method.del);
    }

    unittest {
        if (!netAllowed) return;
        assert(Http.del(testUrl2).toString()[0..11] == "Hello world", "del() received incorrect data");
    }

    /** Asynchronous version of del().  
        See_Also: $(XREF _curl, Http.getAsync).

    */
    static AsyncResult delAsync(string url) {
        return AsyncResult(url, "", "", Method.del);
    }

    unittest {
        if (!netAllowed) return;
        assert(Http.delAsync(testUrl2).byLine().front[0..11] == "Hello world", "delAsync() received unexpected data");
    }

    /** Convenience function that simply does a HTTP OPTIONS on the
        specified URL.

        Example:
        ----
auto res = Http.options("http://www.digitalmars.com");
writeln(res.toString());
        ----
     
        Returns:
        A $(XREF _curl, Http.Result) object.
    */
    static Result options(in const(char)[] url) {
        return Result(url, Method.options);
    }

    unittest {
        if (true ||!netAllowed) return;
        assert(Http.options(testUrl2).toString()[0..11] == "Hello world", "options() received incorrect data");
    }

    /** Asynchronous version of options(). 
        See_Also: $(XREF _curl, Http.getAsync)
    */
    static AsyncResult optionsAsync(string url) {
        return AsyncResult(url, "", "", Method.options);
    }

    unittest {
        if (!netAllowed) return;
        assert(Http.optionsAsync(testUrl2).byLine().front[0..11] == "Hello world", "optionsAsync() received unexpected data");
    }

    /** Convenience function that simply does a HTTP TRACE on the
        specified URL. 

        Example:
        ----
auto res = Http.trace("http://www.digitalmars.com");
writeln(res.toString());
        ----
     
        Returns:
        A $(XREF _curl, Http.Result) object.
    */
    static Result trace(in const(char)[] url) {
        return Result(url, Method.trace);
    }

    unittest {
        if (!netAllowed) return;
        assert(Http.trace(testUrl2).toString()[0..11] == "Hello world", "trace() received incorrect data");
    }

    /** Asynchronous version of trace(). 
        See_Also: $(XREF _curl, Http.getAsync)
    */
    static AsyncResult traceAsync(string url) {
        return AsyncResult(url, "", "", Method.get);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Http.getAsync(testUrl1);
        auto byline = res.byLine();
        assert(byline.front[0..11] == "Hello world", "getAsync() returns unexpected text");
	//        assert(Http.traceAsync(testUrl1).byLine().front[0..11] == "Hello world", "traceAsync() received unexpected data");
    }

    /** Convenience function that simply does a HTTP CONNECT on the
        specified URL. 

        Example:
        ----
auto res = Http.connect("http://www.digitalmars.com");
writeln(res.toString());
        ----

        Returns:
        A $(XREF _curl, Http.Result) object.
    */
    static Result connect(in const(char)[] url) {
        return Result(url, Method.connect);
    }

    unittest {
        // Disabled since google appengine does not support this method
        if (true ||!netAllowed) return;
        assert(Http.connect(testUrl2).toString()[0..11] == "Hello world", "connect() received incorrect data");
    }

    /** Specifying data to post when not using the onSend callback.

        The data is NOT copied by the library.  Content-Type will
        default to application/octet-stream.  Data is not converted or
        encoded for you.

        Example:
        ----
Http http = Http("http://www.mydomain.com");
http.onReceive = (ubyte[] data) { writeln(data); return data.length; };
http.postData = [1,2,3,4,5];
http.perform();
        ----
    */
    @property void postData(in const(void)[] data) {
        // cannot use callback when specifying data directly so we disable it here.
        p.curl.clear(CurlOption.readfunction); 
        setHeader("Content-Type", "application/octet-stream");
        p.curl.set(CurlOption.postfields, cast(void*)data.ptr);
    }
 
    /** Specifying data to post when not using the onSend callback.

        The data is NOT copied by the library.  Content-Type will
        default to text/plain.  Data is not converted or
        encoded for you.

        Example:
        ----
Http http = Http("http://www.mydomain.com");
http.onReceive = (ubyte[] data) { writeln(data); return data.length; };
http.postData = "The quick....";
http.perform();
        ----
    */
    @property void postData(in const(char)[] data) {
        // cannot use callback when specifying data directly so we disable it here.
        p.curl.clear(CurlOption.readfunction); 
        setHeader("Content-Type", "text/plain");
        p.curl.set(CurlOption.postfields, cast(void*)data.ptr);
    }

    /**
       Set the event handler that receives incoming headers. 
       
       The callback will receive a header field key, value as
       parameter. The char[] arrays are not valid after the delegate
       has returned.

       Example:
       ----
Http http = Http("http://www.google.com");
http.onReceive = (ubyte[] data) { writeln(data); return data.length; };
http.onReceiveHeader = (const(char)[] key, const(char[]) value) { writeln(key, " = ", value); };
http.perform();
       ----
    */
    @property void onReceiveHeader(void delegate(const(char)[],const(char)[]) callback) {
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
                    p.status.majorVersion = to!ushort(m.captures[1]);
                    p.status.minorVersion = to!ushort(m.captures[2]);
                    p.status.code = to!ushort(m.captures[3]);
                    p.status.reason = m.captures[4].idup;
                    if (p._onReceiveStatusLine != null) {
                        p._onReceiveStatusLine(p.status);
                    }
                }
                return;
            }

            // Normal http header
            auto m = match(cast(char[]) header, regex("(.*?): (.*)$"));

            if (!m.empty) {
                callback(m.captures[1].toLower, m.captures[2]); 
            }
     
        };
        p.curl.onReceiveHeader(callback is null ? null : dg);
    }

    /**
       Callback for each received StatusLine.

       Notice that several callbacks can be done for on call to
       perform() because if redirections.

       See_Also: $(XREF _curl, StatusLine)
     */
    @property void onReceiveStatusLine(void delegate(StatusLine) callback) {
        p._onReceiveStatusLine = callback;
    }

    /**
       The content length in bytes when using request that has content e.g. POST/PUT
       and not using chunked transfer. Is set as the "Content-Length" header.
       Set to size_t.max to reset to chunked transfer.
    */
    @property void contentLength(size_t len) {

        CurlOption lenOpt;

        // Force post if necessary
        if (p.method != Method.put && p.method != Method.post)
            p.method = Method.post;

        if (p.method == Method.put)  {
            lenOpt = CurlOption.infilesize_large;
        } else { 
            // post
            lenOpt = CurlOption.postfieldsize_large;
        }

        if (len == size_t.max) {
            // HTTP 1.1 supports requests with no length header set.
            setHeader("Transfer-Encoding", "chunked");
            setHeader("Expect", "100-continue");
        } else {
            p.curl.set(lenOpt, len);
        }
    }

    /**
       Perform a http request.

       After you have setup a Http request and possibly assigned
       callbacks you can call perform() to actually perform the
       request.
    */
    void perform() {
        _perform();
    }

    private CURLcode _perform(bool throwOnError = true) {
        p.status.reset;

        curl_slist * headerChunk;
        foreach (k ; p._headers.byKey())
            headerChunk = curl_slist_append(headerChunk, cast(char*) toStringz(k ~ ": " ~ p._headers[k])); 

        if (headerChunk !is null)
            p.curl.set(CurlOption.httpheader, headerChunk);

        final switch (p.method) {
        case Method.head:
            p.curl.set(CurlOption.nobody, 1L);
            break;
        case Method.get:
            p.curl.set(CurlOption.httpget, 1L);
            break;
        case Method.post:
            p.curl.set(CurlOption.post, 1L);
            break;
        case Method.put:
            p.curl.set(CurlOption.upload, 1L);
            break;
        case Method.del:
            p.curl.set(CurlOption.customrequest, "DELETE");
            break;
        case Method.options:
            p.curl.set(CurlOption.customrequest, "OPTIONS");
            break;
        case Method.trace:
            p.curl.set(CurlOption.customrequest, "TRACE");
            break;
        case Method.connect:
            p.curl.set(CurlOption.customrequest, "CONNECT");
            break;
        }

        scope(exit) curl_slist_free_all(headerChunk);
        return p.curl.perform(throwOnError);
    }

    /**
       Authentication method as specified in $(XREF etc.c.curl, AuthMethod).
    */
    @property void authenticationMethod(CurlAuth authMethod) {
        p.curl.set(CurlOption.httpauth, cast(long) authMethod);
    }

    /**
       Set max allowed redirections using the location header. 
       uint.max for infinite.
    */
    @property void maxRedirects(uint maxRedirs) {
        if (maxRedirs == uint.max) {
            // Disable
            p.curl.set(CurlOption.followlocation, 0);
        } else {
            p.curl.set(CurlOption.followlocation, 1);
            p.curl.set(CurlOption.maxredirs, maxRedirs);
        }
    }

    /** The standard HTTP methods :
     *  $(WEB www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.1.1, _RFC2616 Section 5.1.1)
     */
    enum Method {
        head, /// 
        get,  /// 
        post, /// 
        put,  /// 
        del,  /// 
        options, /// 
        trace,   /// 
        connect  /// 
    }

    /**
       HTTP status line ie. the first line returned in a HTTP response.
    
       If authentication or redirections are done then the status will be
       for the last response received.
    */
    struct StatusLine {
        ushort majorVersion; /// Major HTTP version ie. 1 in HTTP/1.0.
        ushort minorVersion; /// Minor HTTP version ie. 0 in HTTP/1.0.
        ushort code;         /// HTTP status line code e.g. 200.
        string reason;       /// HTTP status line reason string.
        
        /// Reset this status line
        void reset() { 
            majorVersion = 0;
            minorVersion = 0;
            code = 0;
            reason = "";
        }
    }

    // This structure is used to keep parameters when using static
    // request methods on the Http class.
    // It enables the e.g. Http.get("...").dataTimeout(100).byLine()
    struct RequestParams(T) {
        alias T[] STR;
        static if ( is(T == const(char))) {
            alias const(void)[] POSTDATA;
            alias Tuple!(STR,STR)[] HEADERS;
        } else {
            alias immutable(void)[] POSTDATA;
            alias immutable(Tuple!(STR,STR))[] HEADERS;
        }
        // This protocol params
        Method method;
        POSTDATA postData;
        HEADERS headers;
        STR cookieJar;
        Http.TimeCond timeCond;
        DateTime timeCondTimestamp;
        
        // Base Protocol params
        STR url;
        Duration dataTimeout;
        Duration connectTimeout;
        Duration dnsTimeout;
        STR netInterface;
        int port;
        int range;
        bool tcpNoDelay;
        STR username;
        STR password;
        STR domain; // NTLM authentication only
    };

        
    private mixin template RequestParamsSetters(OWNER, T) {
        @property ref OWNER method(Method m) { 
            rp._requestParams.method = m;
            return this;
        }
        @property ref OWNER postData(T.POSTDATA d) { 
            rp._requestParams.postData = d;
            return this;
        }
        @property ref OWNER headers(T.HEADERS v) { 
            foreach(k; v)
                rp._requestParams.headers ~= k;
            return this;
        }
        ref OWNER header(T.STR k, T.STR v = null) { 
            // remove any existing existing keys matching k
            T.HEADERS next;
            foreach (h; rp._requestParams.headers) {
                if (h[0] != k)
                    next ~= h;
            }
            if (v !is null)
                next ~= tuple(k,v);
            rp._requestParams.headers = next;
            return this;
        }
        @property ref OWNER cookieJar(T.STR j) { 
            rp._requestParams.cookieJar = j;
            return this;
        }
        ref OWNER timeCondition(Http.TimeCond c, DateTime t) { 
            rp._requestParams.timeCond = c;
            rp._requestParams.timeCondTimestamp = t;
            return this;
        }
    }


    // Used by spawnAsyncRequest
    static void _preAsyncOnReceive(Result)(ref Result res, ref EncodingScheme scheme, Tid fromTid) {
        // Make sure the last received statusLine is sent to main
        // thread before receiving. 
        if (res._statusLine.majorVersion != 0) {
            fromTid.send(thisTid(), message(res._statusLine));
            foreach (key; res._headers.byKey()) {
                fromTid.send(thisTid(), message(Tuple!(string,string)(key,res._headers[key])));
            }
            res._statusLine.majorVersion = 0;
        }
        
        string * v = ("content-type" in res._headers);
        string charset = "ISO-8859-1"; // Default charset defined in HTTP RFC
        if (v) {
            auto m = match(cast(char[]) (*v), regex("charset=([^;]*)"));
            if (!m.empty && m.captures.length > 1) {
            charset = m.captures[1].idup;
            }
            /*
            auto a = *v;
            if (a.findSkip("charset")) 
                if (a.findSkip("=")) {
                        while (a.skipOver(" \t")) {};
                        charset = a.findSplitBefore(";")[0].stripRight();
                }
            */
        }
        scheme = EncodingScheme.create(charset);
    }

    private void _preAsyncPerform(Res, RParams)(ref Res res, ref RParams requestParams) {

        this.onReceiveHeader = (const(char)[] key,const(char)[] value) { 
            receiveTimeout(0, (bool x) { this.cleanup(); });
            if (this.isStopped) return;
            res._headers[key] = value.idup;
        };
        
        this.onReceiveStatusLine = (StatusLine l) { 
            receiveTimeout(0, (bool x) { this.cleanup(); });
            if (this.isStopped) return;
            foreach(k; res._headers.keys) res._headers.remove(k);
            res._statusLine = l;
        };
        
        if (requestParams.method == Method.post || requestParams.method == Method.put) {
            this.onSend = delegate size_t(void[] buf) {
                receiveTimeout(0, (bool x) { this.cleanup(); });
                if (this.isStopped) return CurlReadFunc.abort;
                size_t minlen = min(buf.length, requestParams.postData.length);
                buf[0..minlen] = requestParams.postData[0..minlen];
                requestParams.postData = requestParams.postData[minlen..$];
                return minlen;
            };
            this.contentLength = requestParams.postData.length;
        }

        this.maxRedirects = Http.defaultMaxRedirects;
    }

    // Used by spawnAsyncRequest to finalize a Http request
    private void _finalizeProtocol(Res)(ref Res res, Tid fromTid) {
        // Send the status line and headers if they haven't been so
        if (res._statusLine.majorVersion != 0) {
            fromTid.send(thisTid(), message(res._statusLine));
            foreach (key; res._headers.byKey()) {
                fromTid.send(thisTid(), message(Tuple!(string,string)(key,res._headers[key])));
            }
            res._statusLine.majorVersion = 0;
        }
    }

    private void _assignParams(RParams)(ref const(RParams) requestParams) {
        
        this.p.method = requestParams.method;

        foreach (k ; requestParams.headers)
            this.addHeader(k[0], k[1]);

        if (requestParams.cookieJar) {
            this.setCookieJar(requestParams.cookieJar);
        }
        if (requestParams.timeCond != Http.TimeCond.none) {
            this.setTimeCondition(requestParams.timeCond, 
                                  requestParams.timeCondTimestamp); 
        }
    }

    /**
       The http result of a synchronous request.
    */
    struct Result {
            
        private enum State {
            uninitialized,
            ready,
            done
        };
        alias RequestParams!(const(char)) RParams;

        private struct RImpl {
            State _state;
            StatusLine _statusLine;  // Http status line
            string[string] _headers; // Received http headers
            ubyte[] _bytes;          // Received http content as raw ubyte[]
            RParams _requestParams;  // Parameters set for http request
        }

        private RefCounted!RImpl rp;

        // Need to keep a client object to support keep-alive
        // This must be a pointer since making it a direct value
        // creates linker errors. Probably a bug.
        // Furthermore this should be in the RImpl struct but cannot
        // because of bug 2926
        private Http * _client;
        ~this() {
            clear(_client);
        }

        mixin ProtocolRequestParamsSetters!(Result, RParams);
        mixin RequestParamsSetters!(Result, RParams);

        this(in const(char)[] url, Http.Method method) {
            rp.RefCounted.initialize();
            rp._requestParams.url = url;
            rp._requestParams.method = method;
        }

        void reset() {
            rp._statusLine.reset();
            rp._bytes.length = 0;
            rp._state = State.ready;
            foreach(k; rp._headers.keys) rp._headers.remove(k);
        }

        //
        private void execute() {
            final switch (rp._state) {
            case State.uninitialized:
                _client = new Http(rp._requestParams.url);
                rp._state = State.ready;
                goto case;
            case State.ready:
                break;
            case State.done:
                return;
            }
            _client._assignProtocolParams(rp._requestParams);
            _client._assignParams(rp._requestParams);
            
            if (rp._requestParams.method != Method.head)
                _client.onReceive = (ubyte[] data) { rp._bytes ~= data; return data.length; };
            
            if (rp._requestParams.method == Method.post || rp._requestParams.method == Method.put) {
                _client.onSend = delegate size_t(void[] buf) {
                    size_t minlen = min(buf.length, rp._requestParams.postData.length);
                    buf[0..minlen] = rp._requestParams.postData[0..minlen];
                    rp._requestParams.postData = rp._requestParams.postData[minlen..$];
                    return minlen;
                };
                _client.contentLength = rp._requestParams.postData.length;
            }
            _client.onReceiveHeader = (const(char)[] key,const(char)[] value) { addHeader(key, value); };
            _client.onReceiveStatusLine = (StatusLine l) { reset(); rp._statusLine = l; };
            _client.maxRedirects = Http.defaultMaxRedirects;
            _client.perform;
            rp._state = State.done;
        }

        /**
           The status line.
        */
        @property StatusLine statusLine() {
            execute();
            return rp._statusLine;
        }
        /**
           The received headers. 
        */
        @property string[string] headers() {
            execute();
            return rp._headers;
        }

        /**
	   Received content.
        */
        @property ubyte[] bytes() {
            execute();
            return rp._bytes;
        }
        
        /**
           The received http content decoded from content-type charset into text.
        */
        @property Char[] toString(Char = char)() {
            auto scheme = encodingScheme;
            if (!scheme) {
                return null;
            }

            static if (is (Char == char))
                // Special case where encoding is utf8 since that is what
                // this method returns
                if (scheme.toString() == "UTF-8")
                    return cast(char[])(rp._bytes);

            auto r = decodeString!Char(rp._bytes, scheme);
            return r[1];
        }

        /**
           The encoding scheme name.
        */
        @property const(char)[] encodingName() {
            execute();
            string * v = ("content-type" in headers);
            string charset = "ISO-8859-1"; // Default charset defined in HTTP RFC
            if (v) {
                auto m = match(cast(char[]) (*v), regex("charset=([^;]*)"));
                if (!m.empty && m.captures.length > 1) {
                    charset = m.captures[1].idup;
                }
            }
            return charset;
        }

        /**
           The encoding scheme.
        */
        @property EncodingScheme encodingScheme() {
            return EncodingScheme.create(to!string(encodingName));
        }
      
        private void addHeader(const(char)[] key, const(char)[] value) {
            string * v = (key in rp._headers);
            if (v) {
                (*v) ~= value;
            } else {
                rp._headers[key] = to!string(value);
            }
        }

        /**
           Returns a range that will synchronously read the incoming
           http data by chunks of a given size.
           
           Example:
           ---
foreach (chunk; Http.get("http://www.google.com").byChunk(100)) 
    writeln("syncChunk: ", chunk);
           ---

           Params:
           chunkSize = The size of each chunk to be read. The last one is allowed to be smaller.
           
           Returns:
           A SyncChunkInputRange
        */
        mixin ByChunkSync!rp;

        /**
           Returns a range that will synchronously read the incoming http data by line.
           
           Example:
           ---
// Read string
foreach (l; Http.get("http://www.google.com").byLine()) 
    writeln("syncLine: ", l);
           ---

           Params:
           keepTerminator = If the terminator for the lines should be included in the line returned
           terminator     = The terminating char for a line
           
           Returns:
           A HttpLineInputRange
        */
        mixin ByLineSync!();
    }

    /// Result struct used for asynchronous results.
    struct AsyncResult {

        private enum RunState {
            init,
            running,
            statusReady,
            done
        }

        alias RequestParams!(immutable(char)) RParams;
        private struct RImpl {
            RunState _running; 
            Http.StatusLine _statusLine; 
            string[string] _headers;     // The received http headers
            size_t _defaultStringBufferSize; 
            RParams _requestParams;
            immutable(void)[] _postData;
            string _contentType;
            Method _httpMethod;
        }
        private RefCounted!RImpl rp;

        mixin ProtocolRequestParamsSetters!(AsyncResult, RParams);
        mixin RequestParamsSetters!(AsyncResult, RParams);

        this(string url, immutable(void)[] postData, 
             string contentType, Method httpMethod) {
            rp.RefCounted.initialize();
            rp._requestParams.url = url;
            rp._requestParams.postData = postData;
            rp._requestParams.headers ~= tuple("Content-Type", contentType);
            rp._requestParams.method = httpMethod;
            rp._running = RunState.init;
	    // A guess on how long a normal line is
	    rp._defaultStringBufferSize = 100;
        }
        
        /** The running state. */
        @property bool isRunning() {
            return rp._running == RunState.running || rp._running == RunState.statusReady;
        }
        
        /** The http status code.  
            This property is only valid after calling either byChunk or byLine 
        */
        @property Http.StatusLine statusLine() {
            enforce(rp._running == RunState.statusReady || rp._running == RunState.done,
                    "Cannot get statusLine before a call to either byChunk or byLine on a Http.AsyncResult");
            return rp._statusLine;
        }

        /** The http headers. 
            This property is only valid after calling either byChunk or byLine
         */
        @property string[string] headers() {
            enforce(rp._running == RunState.statusReady || rp._running == RunState.done, 
                    "Cannot get headers before a call to either byChunk or byLine on a Http.AsyncResult");
            return rp._headers;
        }

        /**
           The encoding scheme name.
           This property is only valid after calling either byChunk or byLine           
        */
        @property const(char)[] encodingName() {
            enforce(rp._running == RunState.statusReady || rp._running == RunState.done, 
                    "Cannot get encoding before a call to either byChunk or byLine on a Http.AsyncResult");
            string * v = ("content-type" in headers);
            string charset = "ISO-8859-1"; // Default charset defined in HTTP RFC
            if (v) {
                auto m = match(cast(char[]) (*v), regex(".*charset=([^;]*)"));
                if (!m.empty && m.captures.length > 1) {
                    charset = m.captures[1].idup;
                }
            }
            return charset;
        }

        /**
           The encoding scheme.
           This property is only valid after calling either byChunk or byLine           
        */
        @property EncodingScheme encodingScheme() {
            return EncodingScheme.create(to!string(encodingName));
        }
        
        /**
           Returns a range that will asynchronously read the incoming http data by chunks of a given size.
           
           Example:
           ---
// Read ubyte[] in chunks of 1000
foreach (l; Http.getAsync("http://www.google.com").byChunk(1000)) 
writeln("asyncChunk: ", l);
           ---

           Params:
           chunkSize = The size of each chunk to be read. The last one is allowed to be smaller.
           transmitBuffers = number of buffers filled asynchronously 
           
           Returns:
           An AsyncChunkInputRange
        */
        mixin ByChunkAsync!(Http, rp);

        /**
           Returns a range that will asynchronously read the incoming http data by line.
           
           Example:
           ---
// Read char[] lines
foreach (l; Http.getAsync("http://www.google.com").byLine()) 
writeln("asyncLine: ", l);
           ---
       
           Params:
           keepTerminator = If the terminator for the lines should be included in the line returned
           terminator = The terminating char for a line
           transmitBuffers = number of buffers filled asynchronously 
           
           Returns:
           An AsyncLineInputRange
        */
        mixin ByLineAsync!(Http, rp);
        
    } // AsyncResult

} // Http

 
/**
   Ftp client functionality.
*/
struct Ftp {
    
    mixin Protocol;

    private struct Impl {
        Curl curl;
    }

    private RefCounted!Impl p;

    /**
       Ftp access to the specified url.
    */
    this(in const(char)[] url) {
        p.RefCounted.initialize();
        p.curl.initialize();
        p.curl.set(CurlOption.url, url);
        version (unittest) verbose(true);
    }

    /** Convenience function that simply does a FTP GET on specified
        URL. 

        Example:
        ----
Ftp.get("ftp://ftp.digitalmars.com/sieve.ds", "/tmp/downloaded-file");
        ----
    */
    static void get(in const(char)[] url, in string saveToPath) {
        auto client = new Ftp(url);
        auto f = new std.stream.File(saveToPath, FileMode.OutNew);
        client.onReceive = (ubyte[] data) { f.write(data); return data.length; };
        client.perform;
        f.close;
    }

    /** Convenience function that simply does a FTP GET on the
        specified URL.
     
        Example:
        ----
auto res = Ftp.get("ftp://ftp.digitalmars.com/sieve.ds");
writeln(res.toString());
        ----

        Returns:
        A $(XREF _curl, Ftp.Result) object.
    */
    static Result get(in const(char)[] url) {
        return Result(url);
    }

    unittest {
        if (!netAllowed) return;
        auto res = Ftp.get("ftp://ftp.digitalmars.com/sieve.ds").byLine();
        res.popFront();
        assert(res.front == "/* Eratosthenes Sieve prime number calculation. */\r", 
               "get() returns unexpected content " ~ res.front);
    }

    /** Asynchronous FTP GET to the specified URL. 
        Callbacks are not supported when using this method (e.g. onReceive).

        Example:
        ----
auto res = Ftp.getAsync("ftp://ftp.digitalmars.com/sieve.ds");
writeln(res.byChunk(100).front);
        ----

        Returns:
        A $(XREF _curl, Ftp.AsyncResult) object.
    */
    static AsyncResult getAsync(string url) {
        return AsyncResult(url, "");
    }

    unittest {
        if (!netAllowed) return;
        auto res = Ftp.getAsync("ftp://ftp.digitalmars.com/sieve.ds").byLine();
        res.popFront();
        assert(res.front == "/* Eratosthenes Sieve prime number calculation. */\r", 
               "get() returns unexpected content " ~ res.front);
    }

    /**
       Performs the ftp request as it has been configured.

       After you have setup a Ftp request and possibly assigned
       callbacks you can call perform() to actually perform the
       request.
    */
    void perform() {
        _perform();
    }

    private CURLcode _perform(bool throwOnError = true) {
        return p.curl.perform(throwOnError);
    }

    /**
       The content length in bytes of the ftp data.
    */
    @property void contentLength(size_t len) {
        p.curl.set(CurlOption.infilesize_large, len);      
    }

    // This structure is used to keep parameters when using static
    // request methods on the Ftp class.
    // It enables the e.g. Ftp.get("...").dataTimeout(100).byLine()
    struct RequestParams(T) {
        alias T[] STR;
        static if ( is(T == const(char))) {
            alias const(void)[] POSTDATA;
            alias const(STR)[] HEADERS;
        } else {
            alias immutable(void)[] POSTDATA;
            alias immutable(STR)[] HEADERS;
        }
        // This protocol params
        POSTDATA postData;
        
        // Base Protocol params
        STR url;
        Duration dataTimeout;
        Duration connectTimeout;
        Duration dnsTimeout;
        STR netInterface;
        int port;
        int range;
        bool tcpNoDelay;
        STR username;
        STR password;
        STR domain; // NTLM authentication only
    };
        
    private mixin template RequestParamsSetters(OWNER, T) {
        @property ref OWNER postData(T.POSTDATA d) { 
            rp._requestParams.postData = d;
            return this;
        }
    }

    // Used by spawnAsyncRequest
    private void _preAsyncPerform(RParams)(ref RParams requestParams) {
        if (requestParams.postData.length != 0) {
            this.onSend = delegate size_t(void[] buf) {
                receiveTimeout(0, (bool x) { this.cleanup(); });
                if (this.isStopped) return CurlReadFunc.abort;
                size_t minlen = min(buf.length, requestParams.postData.length);
                buf[0..minlen] = requestParams.postData[0..minlen];
                requestParams.postData = requestParams.postData[minlen..$];
                return minlen;
            };
            this.contentLength = requestParams.postData.length;
        }
    }

    private void _assignParams(RParams)(ref const(RParams) requestParams) {
        // void
    }

    /**
       The ftp result of a synchronous request.
    */
    struct Result {
            
        private enum State {
            uninitialized,
            ready,
            done
        };

        alias RequestParams!(const(char)) RParams;
        private struct RImpl {
            private State _state;
            private ubyte[] _bytes; /// The received ftp content as raw ubyte[].
            RParams _requestParams;
            const(char)[] _encodingSchemeName;
        }
        mixin ProtocolRequestParamsSetters!(Result, RParams);
        mixin RequestParamsSetters!(Result, RParams);

        private RefCounted!RImpl rp;        

        // Need to keep a client object to support keep-alive
        // This must be a pointer since making it a direct value
        // creates linker errors. Probably a bug.
        // Furthermore this should be in the RImpl struct but cannot
        // because of bug 2926
        private Ftp * _client;

        this(in const(char)[] url) {
            rp.RefCounted.initialize();
            rp._requestParams.url = url;
        }

        ~this() {
            clear(_client);
        }

        private void reset() {
            rp._bytes.length = 0;
            rp._state = State.ready;
        }
        
        //
        void execute() {
            final switch (rp._state) {
            case State.uninitialized:
                _client = new Ftp(rp._requestParams.url);
                rp._state = State.ready;
                goto case;
            case State.ready:
                break;
            case State.done:
                return;
            }
            _client._assignProtocolParams(rp._requestParams);
            _client._assignParams(rp._requestParams);

            _client.onReceive = (ubyte[] data) { rp._bytes ~= data; return data.length; };

            if (rp._requestParams.postData.length != 0) {
                _client.onSend = delegate size_t(void[] buf) {
                    size_t minlen = min(buf.length, rp._requestParams.postData.length);
                    buf[0..minlen] = rp._requestParams.postData[0..minlen];
                    rp._requestParams.postData = rp._requestParams.postData[minlen..$];
                    return minlen;
                };
                _client.contentLength = rp._requestParams.postData.length;
            }
            _client.perform;
            rp._state = State.done;
        }

        /**
	   Received content.
        */
        @property ubyte[] bytes() {
            execute();
            return rp._bytes;
        }
        
        /**
           The received ftp content decoded from content-type charset into text.
        */
        @property Char[] toString(Char = char)() {
            auto scheme = encodingScheme;
            if (!scheme) {
                return null;
            }

            static if (is (Char == char))
                // Special case where encoding is utf8 since that is what
                // this method returns
                if (scheme.toString() == "UTF-8")
                    return cast(char[])(rp._bytes);

            auto r = decodeString!Char(rp._bytes, scheme);
            return r[1];
        }

        /**
           The encoding scheme name. Defaults to UTF-8 if not set explicitly.
        */
        @property const(char)[] encodingName() {
            if (rp._encodingSchemeName is null)
                return "UTF-8";
            return rp._encodingSchemeName;
        }

        /**
           The encoding scheme name.
        */
        ref Result encoding(const(char)[] schemeName) {
            rp._encodingSchemeName = schemeName;
            return this;
        }

        /**
           The encoding scheme.
        */
        @property EncodingScheme encodingScheme() {
            return EncodingScheme.create(to!string(encodingName));
        }

        /**
           Returns a range that will synchronously read the incoming
           ftp data by chunks of a given size.
           
           Example:
           ---
foreach (chunk; Ftp.get("ftp://ftp.digitalmars.com/sieve.ds").byChunk(100)) 
    writeln("syncChunk: ", chunk);
           ---

           Params:
           chunkSize = The size of each chunk to be read. The last one is allowed to be smaller.
           
           Returns:
           A SyncChunkInputRange
        */
        mixin ByChunkSync!rp;

        /**
           Returns a range that will synchronously read the incoming ftp data by line.
           
           Example:
           ---
// Read string
foreach (l; Ftp.get("ftp://ftp.digitalmars.com/sieve.ds").byLine()) 
    writeln("syncLine: ", l);
           ---

           Params:
           keepTerminator  = If the terminator for the lines should be included in the line returned
           terminator      = The terminating char for a line

           Returns:
           A SyncLineInputRange
        */
        mixin ByLineSync!();
    }

    /// Result struct used for asynchronous results.
    struct AsyncResult {

        private enum RunState {
            init,
            running,
            statusReady,
            done
        }
     
        alias RequestParams!(immutable(char)) RParams;
        private struct RImpl { 
            RunState _running; 
            size_t _defaultStringBufferSize; 
            RParams _requestParams;
            immutable(void)[] _postData;
            const(char)[] _encodingSchemeName;
        }
        private RefCounted!RImpl rp;

        mixin ProtocolRequestParamsSetters!(AsyncResult, RParams);
        mixin RequestParamsSetters!(AsyncResult, RParams);


        this(string url, immutable(void)[] postData) {
            rp.RefCounted.initialize();
            rp._requestParams.url = url;
            rp._requestParams.postData = postData;
            rp._running = RunState.init;
	    // A guess on how long a normal line is
	    rp._defaultStringBufferSize = 100;
            rp._encodingSchemeName = "UTF-8";
        }
        
        /** The running state. */
        @property bool isRunning() {
            return rp._running == RunState.running || rp._running == RunState.statusReady;
        }
        
        /**
           The encoding scheme name. Defaults to UTF-8 if not set explictly.
           This property is only valid after calling either byChunk or byLine           
        */
        @property const(char)[] encodingName() {
            return rp._encodingSchemeName;
        }

        /**
           The encoding scheme name.
           This property is only valid after calling either byChunk or byLine           
        */
        ref AsyncResult encoding(const(char)[] schemeName) {
            enforce(rp._running != RunState.statusReady && rp._running != RunState.done, 
                    "Cannot set encodingSchemeName after a call to either byChunk or byLine on a Ftp.AsyncResult");
            rp._encodingSchemeName = schemeName;
            return this;
        }

        /**
           The encoding scheme.
           This property is only valid after calling either byChunk or byLine           
        */
        @property EncodingScheme encodingScheme() {
            return EncodingScheme.create(to!string(rp._encodingSchemeName));
        }


        /**
           Returns a range that will asynchronously read the incoming ftp data by chunks of a given size.
           
           Example:
           ---
// Read ubyte[] in chunks of 1000
foreach (l; Ftp.getAsync("ftp://ftp.digitalmars.com/sieve.ds").byChunk(1000)) 
writeln("asyncChunk: ", l);
           ---
           
           Params:
           chunkSize = The size of each chunk to be read. The last one is allowed to be smaller.
           transmitBuffers = number of buffers filled asynchronously 
           
           Returns:
           An AsyncChunkInputRange
        */
        mixin ByChunkAsync!(Ftp, rp);

        /**
           Returns a range that will asynchronously read the incoming ftp data by line.
           
           Example:
           ---
// Read string
foreach (l; Ftp.getAsync("ftp://ftp.digitalmars.com/sieve.ds").byLine()) 
    writeln("syncLine: ", l);
           ---

           Params:
           keepTerminator  = If the terminator for the lines should be included in the line returned
           terminator      = The terminating char for a line
           transmitBuffers = The number of buffer used for asynchronous data read 

           Returns:
           An AsyncLineInputRange
        */
        mixin ByLineAsync!(Ftp, rp);
    }
}

/**
    Basic SMTP protocol support.
*/
struct SMTP {

    mixin Protocol;
    
    private struct Impl {
        Curl curl;
    }

    private RefCounted!Impl p;

    /**
        Sets to the url of the SMTP server.
    */
    this(string url) {
        p.RefCounted.initialize();
        p.curl.initialize();
        
        if (url.startsWith("smtps://")) {
            p.curl.set(CurlOption.use_ssl, CurlUseSSL.all);
            p.curl.set(CurlOption.ssl_verifypeer, false);
            p.curl.set(CurlOption.ssl_verifyhost, 2);
        }
        else
            enforce(url.startsWith("smtp://"), "The url must be for the smtp protocol.");
        
        p.curl.set(CurlOption.url, url);
    }

    /**
        Setter for the sender's email address.
    */
    @property void mailFrom(string sender) {
        // The sender address should be encapsulated with < and >
        if (!(sender[0] == '<' && sender[$ - 1] == '>'))
            sender = '<' ~ sender ~ '>';
        p.curl.set(CurlOption.mail_from, sender);
    }
    
    /**
        Setter for the recipient email addresses.
    */
    @property void mailTo(string[] recipients) {
        curl_slist* recipients_list = null;
        foreach(recipient; recipients) {
            if (!(recipient[0] == '<' && recipient[$-1] == '>'))
                recipient = '<' ~ recipient ~ '>';
            recipients_list = curl_slist_append(recipients_list, cast(char*)toStringz(recipient));
        }
        p.curl.set(CurlOption.mail_rcpt, recipients_list);
    }
    
    /**
        Sets the message body text.
    */
    @property void message(string msg) {
        string _message = msg;
        /**
            This delegate reads the message text and copies it.
        */
        p.curl.onSend = delegate size_t(void[] data) {
            if (!msg.length) return 0;
            auto m = cast(void[])msg;
            size_t to_copy = min(data.length, _message.length);
            data[0..to_copy] = (cast(void[])_message)[0..to_copy];
            _message = _message[to_copy..$];
            return to_copy;
        };
    }
    
    /**
        Performs the request as configured.
    */
    void perform() {
        p.curl.perform;
    }
}

/// An exception class for curl.
class CurlException : Exception {
    /// Construct a CurlException with given error message.
    this(string msg) { super(msg); }
}

// Internal messages send between threads. 
// The data is wrapped in this struct in order to ensure that 
// other std.concurrency.receive calls does not pick up our messages
// by accident.
private struct Message(T) {
    public T data;
}

private static Message!T message(T)(T data) {
    return Message!T(data);
}

// Pool of to be used for reusing buffers
private struct Pool(DATA) {
private:
    struct Entry {
        DATA data;
        Entry * next;
    };
    Entry * root;
    Entry * freeList;
public:
    bool empty() {
        return root == null;
    }
    void push(DATA d) {
        if (freeList == null) {
            // Allocate new Entry since there is no one 
            // available in the freeList
            freeList = new Entry;
        }
        freeList.data = d;
        Entry * oldroot = root;
        root = freeList;
        freeList = freeList.next;
        root.next = oldroot;
    }
    DATA pop() {
        DATA d = root.data;
        Entry * n = root.next;
        root.next = freeList;
        freeList = root;
        root = n;
        return d;
    }
};

// Shared function for reading incoming chunks of data and 
// sending the to a parent thread
private static size_t _receiveAsyncChunks(ubyte[] data, ref ubyte[] outdata, 
                                          Pool!(ubyte[]) freeBuffers, 
                                          ref ubyte[] buffer, Tid fromTid, ref bool aborted) {
    size_t datalen = data.length;

    // Copy data to fill active buffer
    while (data.length != 0) {
                    
        // Make sure we have a buffer
        while ( outdata.length == 0 && freeBuffers.empty) {
            // Active buffer is invalid and there are no
            // available buffers in the pool. Wait for buffers
            // to return from main thread in order to reuse
            // them.
            receive((immutable(ubyte)[] buf) {
                    buffer = cast(ubyte[])buf;
                    outdata = buffer[];
                },
                (bool flag) { aborted = true; }
                );
            if (aborted) return cast(size_t)0;
        }
        if (outdata.length == 0) {
            buffer = freeBuffers.pop();
            outdata = buffer[];
        }
                    
        // Copy data
        size_t copyBytes = outdata.length < data.length ? outdata.length : data.length;

        outdata[0..copyBytes] = data[0..copyBytes];
        outdata = outdata[copyBytes..$];
        data = data[copyBytes..$];

        if (outdata.length == 0) {
            fromTid.send(thisTid(), message(cast(immutable(ubyte)[])buffer));
        }
    }

    return datalen;
}

// ditto
private static void _finalizeAsyncChunks(ubyte[] outdata, ref ubyte[] buffer, 
                                         Tid fromTid) {
    if (outdata.length != 0) {
        // Resize the last buffer
        buffer.length = buffer.length - outdata.length;
        fromTid.send(thisTid(), message(cast(immutable(ubyte)[])buffer));
    }
}


// Shared function for reading incoming lines of data and 
// sending the to a parent thread
private static size_t _receiveAsyncLines(Terminator, Unit)
    (ubyte[] data, ref EncodingScheme encodingScheme,
     bool keepTerminator, Terminator terminator, 
     ref ubyte[] leftOverBytes, ref bool bufferValid,
     ref Pool!(Unit[]) freeBuffers, ref Unit[] buffer,
     Tid fromTid, ref bool aborted) {
    
    size_t datalen = data.length;

    // Terminator is specified and buffers should be
    // resized as determined by the terminator

    // Copy data to active buffer until terminator is
    // found.

    // Decode as many lines as possible
    while (true) {

        // Make sure we have a buffer
        while (!bufferValid && freeBuffers.empty) {
            // Active buffer is invalid and there are no
            // available buffers in the pool. Wait for buffers
            // to return from main thread in order to reuse
            // them.
            receive((immutable(Unit)[] buf) {
                    buffer = cast(Unit[])buf;
                    buffer.length = 0;
                    buffer.assumeSafeAppend();
                    bufferValid = true;
                },
                (bool flag) { aborted = true; }
                );
            if (aborted) return cast(size_t)0;
        }
        if (!bufferValid) {
            buffer = freeBuffers.pop();
            bufferValid = true;
        }

        // Try to read a line from left over bytes from
        // last onReceive plus the newly received bytes. 
        try { 
            if (decodeLineInto(leftOverBytes, data, buffer,
                               encodingScheme, terminator)) {
                if (keepTerminator) {
                    fromTid.send(thisTid(), message(cast(immutable(Unit)[])buffer));
                } else {
                    static if (isArray!Terminator)
                        fromTid.send(thisTid(), message(cast(immutable(Unit)[])buffer[0..$-terminator.length]));
                    else
                        fromTid.send(thisTid(), message(cast(immutable(Unit)[])buffer[0..$-1]));
                }
                bufferValid = false;
            } else {
                // Could not decode an entire line. Save
                // bytes left in data for next call to
                // onReceive. Can be up to a max of 4 bytes.
                enforce(data.length <= 4, new CurlException("Too many bytes left not decoded " ~ to!string(data.length) ~ 
                                                            " > 4. Maybe the charset specified in headers does not match "
                                                            "the actual content downloaded?"));
                leftOverBytes ~= data;
                break;
            }
        } catch (CurlException ex) {
            prioritySend(fromTid, cast(immutable(CurlException))ex);
            return cast(size_t)0;
        }
    }
    return datalen;
}

// ditto
private static void _finalizeAsyncLines(Unit)(bool bufferValid, Unit[] buffer, Tid fromTid) {
    if (bufferValid && buffer.length != 0) {
        fromTid.send(thisTid(), message(cast(immutable(Unit)[])buffer[0..$]));
    }
}

            
// Spawn a thread for handling the reading of incoming data in the
// background while the delegate is executing.  This will optimize
// throughput by allowing simultaneous input (this struct) and
// output (e.g. AsyncHttpLineOutputRange).
private static void _spawnAsyncRequest(Proto,Unit,Terminator = void)() {

    Tid fromTid = receiveOnly!(Tid);
    Proto.AsyncResult.RParams requestParams = receiveOnly!(Proto.AsyncResult.RParams);
    
    auto client = Proto(requestParams.url);
    client._assignProtocolParams(requestParams);
    client._assignParams(requestParams);

    // Get buffer to read into
    Pool!(Unit[]) freeBuffers;  // Free list of buffer objects
	
    // Number of bytes filled into active buffer
    Unit[] buffer;
    bool aborted = false;

    EncodingScheme encodingScheme;
    static if ( !is(Terminator == void)) {
        // Only lines reading will receive a terminator
        Terminator terminator = receiveOnly!Terminator;
        bool keepTerminator = receiveOnly!bool;
        static if ( is(Proto == Ftp) ) {
            encodingScheme = EncodingScheme.create(receiveOnly!string);
        }
        // max number of bytes to carry over from an onReceive
        // callback. This is 4 because it is the max code units to
        // decode a code point in the supported encodings.
        ubyte[] leftOverBytes =  new ubyte[4];
        leftOverBytes.length = 0;
        bool bufferValid = false;
    } else {
        Unit[] outdata;
    }

    static if ( is(Proto == Http) ) {
        struct _Result {
            Http.StatusLine _statusLine;
            string[string] _headers; 
        };
        _Result res;
    }

    client.onReceive = (ubyte[] data) { 
        static if ( is(Proto == Http) ) 
            Proto._preAsyncOnReceive(res, encodingScheme, fromTid);
        // If no terminator is specified the chunk size is fixed.
        static if ( is(Terminator == void) ) {
            return _receiveAsyncChunks(data, outdata, freeBuffers, buffer, fromTid, aborted);
        } else {
            return _receiveAsyncLines(data, encodingScheme, 
                                      keepTerminator, terminator, leftOverBytes, 
                                      bufferValid, freeBuffers, buffer, fromTid, aborted);
        }
    };

    static if ( is(Proto == Http) ) 
        client._preAsyncPerform(res, requestParams);
    else
        client._preAsyncPerform(requestParams);

    // Start the request
    CURLcode code;
    try {
        code = client._perform(false);
    } catch (Exception ex) {
        prioritySend(fromTid, cast(immutable(Exception)) ex);
        fromTid.send(thisTid(), message(true)); // signal done
        return;
    }
    if (code != CurlError.ok) {
        if (aborted && (code == CurlError.aborted_by_callback || 
                        code == CurlError.write_error)) {
            return;
        }
        prioritySend(fromTid, cast(immutable(CurlException)) new CurlException(client.p.curl.errorString(code)));
    }

    static if ( is(Proto == Http) ) 
        client._finalizeProtocol(res, fromTid);

    // Send remaining data that is not a full chunk size
    static if ( is(Terminator == void) ) {
        _finalizeAsyncChunks(outdata, buffer, fromTid);
    } else {
        _finalizeAsyncLines(bufferValid, buffer, fromTid);
    }

    if (!client.isStopped) 
        client.cleanup();

    fromTid.send(thisTid(), message(true)); // signal done
}

unittest {
    // Verify that sync and async versions of a request gives the same results.
    auto syncline = Http.get(testUrl1).byLine();
    foreach (asyncline; Http.getAsync(testUrl1).byLine()) {
        assert(asyncline == syncline.front, "Get async by line does not give the same result as get sync by line");
        syncline.popFront();
    }

    auto syncchunk = Http.get(testUrl1).byChunk(100);
    foreach (asyncchunk; Http.getAsync(testUrl1).byChunk(100)) {
        assert(asyncchunk == syncchunk.front, "Get async by chunk does not give the same result as get sync by chunk");
        syncchunk.popFront();
    }
}

unittest {
    
    if (!netAllowed) return;    
    
    // GET with custom data receivers 
    Http http = Http("http://www.google.com");
    http.onReceiveHeader = (const(char)[] key, const(char)[] value) { writeln(key ~ ": " ~ value); };
    http.onReceive = (ubyte[] data) { /* drop */ return data.length; };
    http.perform();
    
    // POST with timeouts
    http.url("http://d-programming-language.appspot.com/testUrl2");
    http.onReceive = (ubyte[] data) { writeln(data); return data.length; };
    http.connectTimeout(dur!"seconds"(10));
    http.dataTimeout(dur!"seconds"(10));  
    http.dnsTimeout(dur!"seconds"(10));
    http.postData = "The quick....";
    http.perform();
    
    // PUT with data senders 
    string msg = "Hello world";
    http.onSend = delegate size_t(void[] data) { 
        if (!msg.length) return 0; 
        auto m = cast(void[])msg;
        auto l = m.length;
        data[0..l] = m[0..$];  
        msg.length = 0;
        return l;
    };
    http.method = Http.Method.put; // defaults to POST
    // Defaults to chunked transfer if not specified. We don't want that now.
    http.contentLength = 11; 
    http.perform();
    
    // FTP
    Ftp.get("ftp://ftp.digitalmars.com/sieve.ds", "./downloaded-file");
    
    http.method = Http.Method.get;
    http.url = "http://upload.wikimedia.org/wikipedia/commons/5/53/Wikipedia-logo-en-big.png";
    http.onReceive = delegate(ubyte[] data) { return data.length; };
    http.onProgress = (double dltotal, double dlnow, double ultotal, double ulnow) {
        writeln("Progress ", dltotal, ", ", dlnow, ", ", ultotal, ", ", ulnow);
        return 0;
    };
    http.perform();
    
    foreach (chunk; Http.getAsync("http://www.google.com").byChunk(100)) {
        stdout.rawWrite(chunk);
    }
}

version (unittest) {

  private auto netAllowed() {
      return getenv("PHOBOS_TEST_ALLOW_NET") != null;
  }
  
}
