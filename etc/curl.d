// Written in the D programming language.

/*
  Known issues:
  *
 
  Possible improvements:

  * Progress may be deprecated in the future. Maybe implement a replacement.
  * Support typed http headers - (Johannes Pfau)
*/

/**
<script type="text/javascript">inhibitQuickIndex = 1</script>

$(BOOKTABLE ,
$(TR $(TH Category) $(TH Functions)
)
$(TR $(TDNW High level) $(TD $(MYREF download) $(MYREF upload) $(MYREF get) 
$(MYREF post) $(MYREF put) $(MYREF del) $(MYREF options) $(MYREF trace) 
$(MYREF connect) $(MYREF byLine) $(MYREF byChunk)
$(MYREF byLineAsync) $(MYREF byChunkAsync) )
)
$(TR $(TDNW Low level) $(TD $(MYREF Http) $(MYREF Ftp) $(MYREF
Smtp) )
)
)

Networking client functionality as provided by $(WEB _curl.haxx.se/libcurl,
libcurl). The libcurl library must be installed on the system in order to use
this module.

Compared to using libcurl directly this module provides a simpler API for
performing common tasks. Futhermore it provides <a href="std_range.html">$(D
range)</a> access to protocols supported by libcurl both synchronously and
asynchronously.

A high level and a low level API are available. The high level API is build
entirely on top of the low level one. 

The high level API is for commonly used functionality such as HTTP/FTP get. The
$(LREF byLineAsync) and $(LREF byChunkAsync) provides asynchronous <a
href="std_range.html">$(D ranges)</a> that performs the request in another
thread while handling a line/chunk in the current thread.

The low level API allows for streaming and other advanced features.

$(BOOKTABLE Cheat Sheet,
$(TR $(TH Function Name) $(TH Description)
)
$(LEADINGROW High level)
$(TR $(TDNW $(LREF download)) $(TD $(D
download("ftp.digitalmars.com/sieve.ds", "/tmp/downloaded-ftp-file")) 
downloads file from url to file system.)
)
$(TR $(TDNW $(LREF upload)) $(TD $(D
upload("/tmp/downloaded-ftp-file", "ftp.digitalmars.com/sieve.ds");) 
uploads file from file system to url.)
)
$(TR $(TDNW $(LREF get)) $(TD $(D
get("d-p-l.org")) returns a string containing the d-p-l.org web page.)
)
$(TR $(TDNW $(LREF put)) $(TD $(D
put("d-p-l.org", "Hi")) returns a string containing 
the d-p-l.org web page. after a HTTP PUT of "hi")
)
$(TR $(TDNW $(LREF post)) $(TD $(D
post("d-p-l.org", "Hi")) returns a string containing 
the d-p-l.org web page. after a HTTP POST of "hi")
)
$(TR $(TDNW $(LREF byLine)) $(TD $(D
byLine("d-p-l.org")) returns a range of strings containing the 
d-p-l.org web page.)
)
$(TR $(TDNW $(LREF byChunk)) $(TD $(D
byChunk("d-p-l.org", 10)) returns a range of ubyte[10] containing the 
d-p-l.org web page.)
)
$(TR $(TDNW $(LREF byLineAsync)) $(TD $(D
byLineAsync("d-p-l.org")) returns a range of strings containing the d-p-l.org web
 page asynchronously.)
)
$(TR $(TDNW $(LREF byChunkAsync)) $(TD $(D
byChunkAsync("d-p-l.org", 10)) returns a range of ubyte[10] containing the 
d-p-l.org web page asynchronously.)
)
$(LEADINGROW Low level
)
$(TR $(TDNW $(LREF Http)) $(TD $(D Http) class for advanced usage))
$(TR $(TDNW $(LREF Ftp)) $(TD $(D Ftp) class for advanced usage))
$(TR $(TDNW $(LREF Smtp)) $(TD $(D Smtp) class for advanced usage))
)


Examples:
---
import etc.curl, std.stdio;

// Return a string containing the content specified by an URL
string content = get("d-p-l.org");

// Post data and return a string containing the content specified by an URL
string content = post("mydomain.com/here.cgi", "post data");

// Get content of file from ftp server
string content = get("ftp.digitalmars.com/sieve.ds");

// Post and print out content line by line. The request is done in another thread.
foreach (line; byLineAsync("d-p-l.org", "Post data"))
    writeln(line);

// Get using a line range and proxy settings
auto client = Http();
client.proxy = "1.2.3.4";
foreach (line; byLine("d-p-l.org", client))
    writeln(line);
---

For more control than the high level functions provide, use the low level API:

Example:
---
import etc.curl, std.stdio;

// GET with custom data receivers
Http http = Http("www.d-p-l.org");
http.onReceiveHeader =
    (const(char)[] key, const(char)[] value) { writeln(key ~ ": " ~ value); };
http.onReceive = (ubyte[] data) { /+ drop +/ return data.length; };
http.perform();
---

First, an instance of the reference-counted Http struct is created. Then the
custom delegates are set. These will be called whenever the Http instance
receives a header or a data buffer. In this simple example, the headers are
writting to stdout and the data is ignored. See $(LREF onReceiveHeader)/$(LREF
onReceive) for more information. Finally the HTTP request is started by calling
perform().

Macros:
MYREF = <font face='Consolas, "Bitstream Vera Sans Mono", "Andale Mono", Monaco, "DejaVu Sans Mono", "Lucida Console", monospace'><a href="#$1">$1</a>&nbsp;</font>

Source: $(PHOBOSSRC etc/_curl.d)

Copyright: Copyright Jonas Drewsen 2011-2012
License:  <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:  Jonas Drewsen
Credits:  The functionally is based on $(WEB _curl.haxx.se/libcurl, libcurl). 
          LibCurl is licensed under a MIT/X derivate license.
*/
/*
         Copyright Jonas Drewsen 2011 - 2012.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module etc.curl;

import core.thread;
import etc.c.curl;
import std.algorithm; 
import std.array;
import std.concurrency; 
import std.conv;  
import std.datetime;
import std.encoding;
import std.exception;
import std.regex; 
import std.socket : InternetAddress; 
import std.stream;
import std.string; 
import std.traits;
import std.typecons;

version(unittest) 
{
    // Run unit test with the PHOBOS_TEST_ALLOW_NET=1 set in order to 
    // allow net traffic
    import std.stdio;
    import std.c.stdlib;
    import std.range;
    enum testUrl1 = "http://d-programming-language.appspot.com/testUrl1";
    enum testUrl2 = "http://d-programming-language.appspot.com/testUrl2";
    enum testUrl3 = "ftp://ftp.digitalmars.com/sieve.ds";
    enum testUrl4 = "d-programming-language.appspot.com/testUrl1";
}
version(StdDdoc) import std.stdio;

pragma(lib, "curl");
extern (C) void exit(int);

/** Connection type used when the url should be used to auto detect protocol.
  *  
  * This struct is used as placeholder for the connection parameter when calling
  * the high level API and the connection type (Http/Ftp) should be guessed by
  * inspecting the url parameter.
  *
  * The rules for guessing the protocol are:
  * 1, if url starts with ftp://, ftps:// or ftp. then Ftp connection is assumed.
  * 2, Http connection otherwise.
  *
  * Example:
  * ---
  * import etc.curl;
  * // Two requests below will do the same.
  * string content;
  *
  * // Explicit connection provided
  * content = get!Http("d-p-l.org");
  *
  * // Guess connection type by looking at the url
  * content = get!AutoConnection("d-p-l.org");
  * // and since AutoConnection is default this is the same as
  * connect = get("d-p-l.org");
  * ---
  *
  */
struct AutoConnection { }

/** HTTP/FTP download to local file system.
 *    
 * Example:
 * ----
 * import etc.curl;
 * download("ftp.digitalmars.com/sieve.ds", "/tmp/downloaded-ftp-file");
 * download("d-programming-language.appspot.com/testUrl2", "/tmp/downloaded-http-file");
 * ----
 */
void download(Conn = AutoConnection, T = char)(const(char)[] url, string saveToPath, Conn conn = Conn())
if ( (is(Conn : Http) || is(Conn : Ftp) || is(Conn : AutoConnection)) &&
     (is(T == char) || is(T == ubyte)) )
{
    static if (is(Conn : Http))
    {
        auto client = Ftp(url);
    }
    else static if (is(Conn : Ftp))
    {
        auto client = Ftp(url);
    }
    else
    {
        if (url.startsWith("ftp://") || url.startsWith("ftps://") || url.startsWith("ftp."))
            return download!(Ftp,T)(url, saveToPath, Ftp());
        else 
            return download!(Http,T)(url, saveToPath, Http());
    }

    static if (is(Conn : Http) || is(Conn : Ftp)) 
    {
        auto f = new std.stream.BufferedFile(saveToPath, FileMode.OutNew);
        scope (exit) f.close;
        client.onReceive = (ubyte[] data) { return f.write(data); };
        client.perform;
    }
}

unittest {
    if (!netAllowed) return;
    download("ftp.digitalmars.com/sieve.ds", "/tmp/downloaded-ftp-file");
    download("d-programming-language.appspot.com/testUrl1", "/tmp/downloaded-http-file");
}

/** Upload file from local files system using the HTTP or FTP protocol.
 *    
 * Example:
 * ----
 * import etc.curl;
 * upload("/tmp/downloaded-ftp-file", "ftp.digitalmars.com/sieve.ds");
 * upload("/tmp/downloaded-http-file", "d-programming-language.appspot.com/testUrl2");
 * ----
 */
void upload(Conn = AutoConnection, T = char)(string loadFromPath, const(char)[] url, Conn conn = Conn())
if ( (is(Conn : Http) || is(Conn : Ftp) || is(Conn : AutoConnection)) &&
     (is(T == char) || is(T == ubyte)) )
{
    static if (is(Conn : Http))
    {
        auto client = Http(url);
        client.method = Http.Method.put;
    }
    else static if (is(Conn : Ftp))
    {
        auto client = Ftp(url);
    }
    else
    {
        if (url.startsWith("ftp://") || url.startsWith("ftps://") || url.startsWith("ftp."))
            return upload!(Ftp,T)(loadFromPath, url, Ftp());
        else 
            return upload!(Http,T)(loadFromPath, url, Http());
    }

    static if (is(Conn : Http) || is(Conn : Ftp)) 
    {
        auto f = new std.stream.BufferedFile(loadFromPath, FileMode.In);
        scope (exit) f.close;
        client.onSend = (void[] data) { 
            return f.read(cast(ubyte[])data);
        };
        client.contentLength = cast(size_t)f.size;
        client.perform;
    }
}

unittest {
    if (!netAllowed) return;
    //    upload("/tmp/downloaded-ftp-file", "ftp.digitalmars.com/sieve.ds");
    upload("/tmp/downloaded-http-file", "d-programming-language.appspot.com/testUrl2");
}

/** HTTP/FTP get content.
 *    
 * Example:
 * ----
 * import etc.curl;
 * string content = get("d-programming-language.appspot.com/testUrl2");
 * ----
 *
 * Returns:
 * A string containing the content of the resource pointed to by the url.
 *
 * See_Also: $(LREF Http.Method)
 */
T[] get(Conn = AutoConnection, T = char)(const(char)[] url, Conn conn = Conn())
if ( (is(Conn : Http) || is(Conn : Ftp) || is(Conn : AutoConnection)) &&
     (is(T == char) || is(T == ubyte)) )
{
    static if (is(Conn : Http))
    {
        conn.method = Http.Method.get;
        return _basicHttp!(T)(url, "", conn);
        
    }
    else static if (is(Conn : Ftp))
    {
        return _basicFtp!(T)(url, "", conn);
    }
    else
    {
        if (url.startsWith("ftp://") || url.startsWith("ftps://") || url.startsWith("ftp."))
            return get!(Ftp,T)(url, Ftp());
        else 
            return get!(Http,T)(url, Http());
    }
}

unittest 
{
    if (!netAllowed) return;
    auto res = get(testUrl1);
    assert(res == "Hello world\x0a",
           "get!Http() returns unexpected content " ~ res);
    res = get(testUrl4);
    assert(res == "Hello world\x0a",
           "get!Http() returns unexpected content: " ~ res);
    res = get(testUrl3);
    assert(res.startsWith("\x0d\x0a/* Eratosthenes Sieve prime number calculation. */"),
           "get!Ftp() returns unexpected content");
}


/** HTTP post content.
 *    
 * Example:
 * ----
 * import etc.curl;
 * string content = post("d-programming-language.appspot.com/testUrl2", [1,2,3,4]);
 * ----
 *
 * Returns:
 * A string containing the content of the resource pointed to by the url.
 *
 * See_Also: $(LREF Http.Method)
 */
T[] post(T = char, PostUnit)(const(char)[] url, const(PostUnit)[] postData, Http conn = Http())
if (is(T == char) || is(T == ubyte))
{
    conn.method = Http.Method.post;
    return _basicHttp!(T)(url, postData, conn);
}

unittest 
{
    if (!netAllowed) return;
    auto res = post(testUrl2, "Hello world");
    assert(res == "Hello world",
           "put!Http() returns unexpected content " ~ res);
}


/** HTTP/FTP put content.
 *    
 * Example:
 * ----  
 * import etc.curl;
 * string content = put("d-programming-language.appspot.com/testUrl2", 
 *                      "Putting this data");
 * ----
 *
 * Returns:
 * A string containing the content of the resource pointed to by the url.
 *
 * See_Also: $(LREF Http.Method)
 */
T[] put(Conn = AutoConnection, T = char, PutUnit)(const(char)[] url, const(PutUnit)[] putData, 
                                                  Conn conn = Conn())
if ( (is(Conn : Http) || is(Conn : Ftp) || is(Conn : AutoConnection)) && 
     (is(T == char) || is(T == ubyte)) )
{
    static if (is(Conn : Http))
    {
        conn.method = Http.Method.put;
        return _basicHttp!(T)(url, putData, conn);
    }
    else static if (is(Conn : Ftp))
    {
        return _basicFtp!(T)(url, putData, conn);
    }
    else
    {
        if (url.startsWith("ftp://") || url.startsWith("ftps://") || url.startsWith("ftp."))
            return put!(Ftp,T)(url, putData, Ftp());
        else 
            return put!(Http,T)(url, putData, Http());
    }
}

unittest 
{
    if (!netAllowed) return;
    auto res = put(testUrl2, "Hello world");
    assert(res == "Hello world",
           "put!Http() returns unexpected content " ~ res);

    // TODO: need ftp server to test with
    //    res = get(testUrl3);
    //    assert(res.startsWith("\x0d\x0a/* Eratosthenes Sieve prime number calculation. */"),
    //       "get!Ftp() returns unexpected content");
}


/** HTTP/FTP delete content.
 *    
 * Example:
 * ----  
 * import etc.curl;
 * del("d-programming-language.appspot.com/testUrl2"); 
 * ----
 *
 * See_Also: $(LREF Http.Method)
 */
void del(Conn = AutoConnection, T = char)(const(char)[] url, Conn conn = Conn())
if (is(Conn : Http) || is(Conn : Ftp) || is(Conn : AutoConnection))
{
    static if (is(Conn : Http))
    {
        conn.method = Http.Method.del;
        _basicHttp!(T)(url, cast(void[]) null, conn);
    }
    else static if (is(Conn : Ftp))
    {
        auto trimmed = url.findSplitAfter("ftp://")[1].findSplitAfter("ftps://")[1];
        auto t = trimmed.findSplitAfter("/");
        enum minDomainNameLength = 3;
        enforce(t[0].length > minDomainNameLength, 
                new CurlException("Invalid ftp url for delete " ~ url));
        conn.url = t[0];

        enforce(t[1].length > 0, 
                new CurlException("No filename specified to delete for url " ~ url));
        conn.addCommand("DELE " ~ t[1]);
        conn.perform();
    }
    else
    {
        if (url.startsWith("ftp://") || 
            url.startsWith("ftps://") || 
            url.startsWith("ftp."))
            return del!(Ftp,T)(url, Ftp());
        else 
            return del!(Http,T)(url, Http());
    }
}

unittest 
{
    if (!netAllowed) return;
    del(testUrl1);
}


/** HTTP options request.
 *    
 * Example:
 * ----
 * import etc.curl;
 * string content = options("d-programming-language.appspot.com/testUrl2", "something");
 * ----
 *
 * Returns:
 * A string containing the options of the resource pointed to by the url.
 *
 * See_Also: $(LREF Http.Method)
 */
T[] options(T = char, OptionsUnit)(const(char)[] url, 
                                   const(OptionsUnit)[] optionsData, 
                                   Http conn = Http())
if (is(T == char) || is(T == ubyte))
{
    conn.method = Http.Method.options;
    return _basicHttp!(T)(url, optionsData, conn);
}

unittest 
{
    if (!netAllowed) return;
    auto res = options(testUrl2, "Hello world");
    assert(res == "Hello world",
           "options!Http() returns unexpected content " ~ res);
}

unittest 
{
    if (!netAllowed) return;
    auto res = options(testUrl1, []);
    assert(res == "Hello world\x0a",
           "options!Http() returns unexpected content " ~ res);
}


/** HTTP trace request.
 *    
 * Example:
 * ----  
 * import etc.curl;
 * trace("d-programming-language.appspot.com/testUrl1"); 
 * ----
 *
 * Returns:
 * A string containing the trace info of the resource pointed to by the url.
 *
 * See_Also: $(LREF Http.Method)
 */
T[] trace(T = char)(const(char)[] url, Http conn = Http())
   if (is(T == char) || is(T == ubyte))
{
    conn.method = Http.Method.trace;
    return _basicHttp!(T)(url, cast(void[]) null, conn);
}

unittest 
{
    if (!netAllowed) return;
    auto res = trace(testUrl1);
    assert(res == "Hello world\x0a",
           "trace!Http() returns unexpected content " ~ res);
}


/** HTTP connect request.
 *    
 * Example:
 * ----  
 * import etc.curl;
 * connect("d-programming-language.appspot.com/testUrl1"); 
 * ----
 *
 * Returns:
 * A string containing the connect info of the resource pointed to by the url.
 *
 * See_Also: $(LREF Http.Method)
 */
T[] connect(T = char)(const(char)[] url, Http conn = Http())
   if (is(T == char) || is(T == ubyte))
{
    conn.method = Http.Method.connect;
    return _basicHttp!(T)(url, cast(void[]) null, conn);
}

unittest 
{
    // google appspot does not allow connect method.
    //    if (!netAllowed) return;
    //    auto res = connect(testUrl1);
    //    assert(res == "Hello world\x0a",
    //           "connect!Http() returns unexpected content " ~ res);
}


private auto _basicHttp(T)(const(char)[] url, const(void)[] sendData, Http client)
{
    scope (exit) 
    {
        client.onReceiveHeader = null;
        client.onReceiveStatusLine = null;
        client.onReceive = null;
    }
    client.url = url;
    Http.StatusLine statusLine;
    ubyte[] content;
    string[string] headers;
    client.onReceive = (ubyte[] data) { 
        content ~= data;
        return data.length;
    };

    if (sendData !is null && 
        (client.method == Http.Method.post || client.method == Http.Method.put))
    {
        client.contentLength = sendData.length;
        client.onSend = delegate size_t(void[] buf) {
            size_t minLen = min(buf.length, sendData.length);
            if (minLen == 0) return 0;
            buf[0..minLen] = sendData[0..minLen];
            sendData = sendData[minLen..$];
            return minLen;
        };
    }

    client.onReceiveHeader = (const(char)[] key,
                              const(char)[] value) { 
        string * v = (key in headers);
        if (v) 
            (*v) ~= ", " ~ value;
        else 
            headers[key] = value.idup;
    };
    client.onReceiveStatusLine = (Http.StatusLine l) { statusLine = l; };
    client.perform;
    enforce(statusLine.code / 100 == 2,
            new CurlException("HTTP request returned status code " ~
                              to!string(statusLine.code)));

    string * v = ("content-type" in headers);
    // Default charset defined in HTTP RFC
    string charset = "ISO-8859-1";
    if (v) 
    {
        auto m = match(cast(char[]) (*v), regex("charset=([^;,]*)"));
        if (!m.empty && m.captures.length > 1) 
        {
            charset = m.captures[1].idup;
        }
    }

    static if (is(T == ubyte))
    {
        return content;
    } 
    else
    {
        // Optimally just return the utf8 encoded content
        if (charset == "UTF-8")
            return cast(char[])(content);
        
        // The content has to be re-encoded to utf8
        EncodingScheme scheme = EncodingScheme.create(charset);
        enforce(scheme !is null,
                new CurlException("Unknown charset '" ~ charset ~ "'"));
        
        auto strInfo = decodeString(content, scheme);
        enforce(strInfo[0] != size_t.max,
                new CurlException("Invalid encoding sequence for header charset '" ~ 
                                  charset ~ "'"));
        
        return strInfo[1];
    }
}

private auto _basicFtp(T)(const(char)[] url, const(void)[] sendData, Ftp client)
{
    scope (exit) client.onReceive = null;
    
    ubyte[] content;

    if (client.encoding == "")
        client.encoding = "ISO-8859-1";

    client.url = url;
    client.onReceive = (ubyte[] data) { 
        content ~= data;
        return data.length;
    };

    if (sendData !is null && sendData.length != 0) 
    {
        client.onSend = delegate size_t(void[] buf) {
            size_t minLen = min(buf.length, sendData.length);
            if (minLen == 0) return 0;
            buf[0..minLen] = sendData[0..minLen];
            sendData = sendData[minLen..$];
            return minLen;
        };
    }

    client.perform;

    static if (is(T == ubyte))
    {
        return content;
    } 
    else
    {
        // Optimally just return the utf8 encoded content
        if (client.encoding == "UTF-8")
            return cast(char[])(content);
        
        // The content has to be re-encoded to utf8
        EncodingScheme scheme = EncodingScheme.create(client.encoding);
        string encoding = client.encoding;
        enforce(scheme !is null,
                new CurlException("Unknown charset '" ~ encoding ~ "'"));
        
        auto strInfo = decodeString(content, scheme);
        enforce(strInfo[0] != size_t.max,
                new CurlException("Invalid encoding sequence for charset '" ~ 
                                   encoding ~ "'"));
        return strInfo[1];
    }
}

alias std.string.KeepTerminator KeepTerminator;

/** HTTP/FTP fetch content as a range of lines.
 *
 * A range of lines is returned when the request is complete. If the method or
 * other request properties is to be customized then set the $(D conn) parameter
 * with a Http/Ftp instance that has these properties set.
 * 
 * Example:
 * ----
 * import etc.curl, std.stdio;
 * foreach (line; byLine("d-p-l.org")) 
 *     writeln(line);
 * ----
 *
 * Returns:
 * A range of strings with the content of the resource pointer to by the url
 */
auto byLine(Conn = AutoConnection, Terminator = char, Char = char)
           (const(char)[] url, KeepTerminator keepTerminator = KeepTerminator.no, 
            Terminator terminator = '\x0a', Conn conn = Conn())
if (is(Conn : Http) || is(Conn : Ftp) || is(Conn : AutoConnection))
{
    // This range is using algorithm splitter and could be
    // optimized by not using that. 
    static struct SyncLineInputRange 
    {

        private Char[] lines;
        private Char[] current;
        private bool currentValid;
        private bool keepTerminator;
        private Terminator terminator;
            
        this(Char[] lines, bool kt, Terminator terminator) 
        {
            this.lines = lines;
            this.keepTerminator = kt;
            this.terminator = terminator;
            currentValid = true;
            popFront();
        }

        @property @safe bool empty() 
        {
            return !currentValid;
        }
            
        @property @safe Char[] front() 
        {
            enforce(currentValid, new CurlException("Cannot call front() on empty range"));
            return current;
        }
            
        void popFront() 
        {
            enforce(currentValid, new CurlException("Cannot call popFront() on empty range"));
            if (lines.empty) 
            {
                currentValid = false;
                return;
            }

            if (keepTerminator) 
            {
                auto r = findSplitAfter(lines, [ terminator ]);
                if (r[0].empty) 
                {
                    current = r[1];
                    lines = r[0];
                } 
                else 
                {
                    current = r[0];
                    lines = r[1];
                }
            } 
            else 
            {
                auto r = findSplit(lines, [ terminator ]);
                current = r[0];
                lines = r[2];
            }
        }
    }

    static if (is(Conn : Http))
    {
        conn.method = conn.method == Http.Method.undefined ? Http.Method.get : conn.method;
        auto result = _basicHttp!Char(url, null, conn);
    }
    else static if (is(Conn : Ftp))
    {
        auto result = _basicFtp!Char(url, null, conn);
    }
    else
    {
        Char[] result;
        if (url.startsWith("ftp://") || url.startsWith("ftps://"))
            result = get(url, Ftp());
        else 
            result = get(url, Http());
    }

    return SyncLineInputRange(result, keepTerminator == KeepTerminator.yes, terminator);
}


/** HTTP/FTP fetch content as a range of chunks.
 *
 * A range of chunks is returned when the request is complete. If the method or
 * other request properties is to be customized then set the $(D conn) parameter
 * with a Http/Ftp instance that has these properties set.
 * 
 * Example:
 * ----
 * import etc.curl, std.stdio;
 * foreach (chunk; byChunk("d-p-l.org", 100)) 
 *     writeln(chunk); // chunk is ubyte[100]
 * ----
 *
 * Returns:
 * A range of ubyte[chunkSize] with the content of the resource pointer to by the url
 */
auto byChunk(Conn = AutoConnection)
            (const(char)[] url, size_t chunkSize = 1024, Conn conn = Conn())
if (is(Conn : Http) || is(Conn : Ftp) || is(Conn : AutoConnection))
{
    static struct SyncChunkInputRange 
    {
        alias ubyte[] ChunkType;
        private size_t chunkSize;
        private ChunkType _bytes;
        private size_t len;
        private size_t offset;
        
        this(ubyte[] bytes, size_t chunkSize) 
        {
            this._bytes = bytes;
            this.len = _bytes.length;
            this.chunkSize = chunkSize;
        }
        
        @property @safe auto empty() 
        {
            return offset == len;
        }
        
        @property ChunkType front() 
        {
            size_t nextOffset = offset + chunkSize;
            if (nextOffset > len) nextOffset = len;
            return _bytes[offset..nextOffset];
        }
        
        @safe void popFront() 
        {
            offset = offset + chunkSize;
            if (offset > len) offset = len;
        }
    }

    static if (is(Conn : Http))
    {
        conn.method = conn.method == Method.undefined ? Http.Method.get : conn.method;
        auto result = _basicHttp!(ubyte)(url, null, conn);
    }
    else static if (is(Conn : Ftp))
    {
        auto result = _basicFtp!(ubyte)(url, null, conn);
    }
    else
    {
        ubyte[] result;
        if (url.startsWith("ftp://") || url.startsWith("ftps://"))
            result = get!(Ftp,ubyte)(url, Ftp());
        else 
            result = get!(Http,ubyte)(url, Http());
    }
    
    return SyncChunkInputRange(result, chunkSize);
}

/*
  Main thread part of the message passing protocol used for all async
  curl protocols.
 */
private mixin template WorkerThreadProtocol(Unit, alias units) 
{

    // This wont work... fix it
    ~this() 
    {
        workerTid.send(true);
    }

    @property bool empty() 
    {
        tryEnsureUnits();
        return state == State.done;
    }

    @property Unit[] front() 
    {
        tryEnsureUnits();
        assert(state == State.gotUnits, 
               "Expected " ~ to!string(State.gotUnits) ~ 
               " but got " ~ to!string(state));
        return units;
    }
                
    void popFront() 
    {
        tryEnsureUnits();
        assert(state == State.gotUnits, 
               "Expected " ~ to!string(State.gotUnits) ~ 
               " but got " ~ to!string(state));
        state = State.needUnits;
        // Send to worker thread for buffer reuse
        workerTid.send(cast(immutable(Unit)[]) units);
        units = null;
    }
    
    enum State 
    {
        needUnits,
        gotUnits,
        done
    }
    State state;

    void tryEnsureUnits() 
    {
        while (true) 
        {
            final switch (state) 
            {
            case State.needUnits:
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

// Workaround bug #2458
// It should really be defined inside the byLineAsync method.
// Range that reads one line at a time asynchronously.
static struct AsyncLineInputRange(Char)
{
    private Char[] line;
    mixin WorkerThreadProtocol!(Char, line);
    
    private Tid workerTid;
    private State running;

    this(Tid tid, size_t transmitBuffers, size_t bufferSize) 
    {
        workerTid = tid;
        state = State.needUnits;
        
        // Send buffers to other thread for it to use.  Since no mechanism is in
        // place for moving ownership a cast to shared is done here and casted
        // back to non-shared in the receiving end.
        foreach (i ; 0..transmitBuffers)
        {
            Char[] arr;
            arr.length = bufferSize;
            workerTid.send(cast(immutable(Char[]))arr);
        }
    }    
}


/** HTTP/FTP fetch content as a range of lines asynchronously.
 *
 * A range of lines is returned immediately and the request that fetches the
 * lines is performed in another thread. If the method or other request
 * properties is to be customized then set the $(D conn) parameter with a
 * Http/Ftp instance that has these properties set. 
 *
 * If $(D postData) is non-null the method will be set to $(D post) for Http
 * requests.
 *
 * $(WEB curl.haxx.se/libcurl/c/curl_easy_setopt.html, _curl_easy_setopt)
 * 
 * Example:
 * ----
 * import etc.curl, std.stdio;
 * foreach (line; byLineAsync("d-p-l.org")) 
 *     writeln(line);
 * ----
 *
 * Returns:
 * A range of strings with the content of the resource pointer to by the url
 */
auto byLineAsync(Conn = AutoConnection, Terminator = char, Char = char, PostUnit)
            (const(char)[] url, const(PostUnit)[] postData, 
             KeepTerminator keepTerminator = KeepTerminator.no, 
             Terminator terminator = '\x0a',
             size_t transmitBuffers = 10, Conn conn = Conn())
if (is(Conn : Http) || is(Conn : Ftp) || is(Conn : AutoConnection))
{
    static if (is(Conn : AutoConnection))
    {
        if (url.startsWith("ftp://") || 
            url.startsWith("ftps://") || 
            url.startsWith("ftp."))
            return byLineAsync(url, postData, keepTerminator, 
                               terminator, transmitBuffers, Ftp());
        else
            return byLineAsync(url, postData, keepTerminator, 
                               terminator, transmitBuffers, Http());
    }
    else
    {
        // 50 is just an arbitrary number for now
        setMaxMailboxSize(thisTid, 50, OnCrowding.block);
        Tid tid = spawn(&(_spawnAsync!(Conn, Char, Terminator)));
        tid.send(thisTid);
        tid.send(terminator);
        tid.send(keepTerminator == KeepTerminator.yes);

        // no move semantic available in std.concurrency ie. must use casting.
        auto connDup = conn.dup();
        connDup.url = url;

        static if ( is(Conn : Http) )
        {
            connDup.p.headersOut = null;
            connDup.method = conn.method == Http.Method.undefined ? 
                Http.Method.get : conn.method; 
            if (postData !is null)
                {
                if (connDup.method == Http.Method.put)
                {
                    connDup.handle.set(CurlOption.infilesize_large, 
                                       postData.length);
                } else {
                    // post 
                    connDup.method = Http.Method.post;
                    connDup.handle.set(CurlOption.postfieldsize_large, 
                                       postData.length);
                }
                connDup.handle.set(CurlOption.copypostfields, 
                                   cast(void*) postData.ptr);
            }
            tid.send(cast(ulong)connDup.handle.handle);
            tid.send(connDup.method);
        } else {
            enforce(postData is null,
                    new CurlException("Cannot put ftp data using byLineAsync()"));
            tid.send(cast(ulong)connDup.handle.handle);
            tid.send(Http.Method.undefined);
        }
        connDup.p.curl.handle = null; // make sure handle is not freed
        return AsyncLineInputRange!Char(tid, transmitBuffers, 
                                        Conn.defaultAsyncStringBufferSize);
    }
}

/// ditto
auto byLineAsync(Conn = AutoConnection, Terminator = char, Char = char)
            (const(char)[] url, KeepTerminator keepTerminator = KeepTerminator.no, 
             Terminator terminator = '\x0a',
             size_t transmitBuffers = 10, Conn conn = Conn())
{
    static if (is(Conn : AutoConnection))
    {
        if (url.startsWith("ftp://") || 
            url.startsWith("ftps://") || 
            url.startsWith("ftp."))
            return byLineAsync(url, cast(void[])null, keepTerminator, 
                               terminator, transmitBuffers, Ftp());
        else
            return byLineAsync(url, cast(void[])null, keepTerminator, 
                               terminator, transmitBuffers, Http());
    } else {
        return byLineAsync(url, cast(void[])null, keepTerminator, 
                           terminator, transmitBuffers, conn);
    }
}

unittest 
{
    if (!netAllowed) return;
    auto res = byLineAsync(testUrl2, "Hello world");    
    auto line = res.front();
    assert(line == "Hello world",
           "byLineAsync!Http() returns unexpected content " ~ line);
    res = byLineAsync(testUrl1);    
    line = res.front();
    assert(line == "Hello world",
           "byLineAsync!Http() returns unexpected content: " ~ line);
}


// Workaround bug #2458
// It should really be defined inside the byLineAsync method.
// Range that reads one chunk at a time asynchronously.
static struct AsyncChunkInputRange
{
    private ubyte[] chunk;
    mixin WorkerThreadProtocol!(ubyte, chunk);
    
    private Tid workerTid;
    private State running;

    this(Tid tid, size_t transmitBuffers, size_t chunkSize) 
    {
        workerTid = tid;
        state = State.needUnits;
        
        // Send buffers to other thread for it to use.  Since no mechanism is in
        // place for moving ownership a cast to shared is done here and a cast
        // back to non-shared in the receiving end.
        foreach (i ; 0..transmitBuffers)
        {
            ubyte[] arr;
            arr.length = chunkSize;
            workerTid.send(cast(immutable(ubyte[]))arr);
        }
    }    
}

/** HTTP/FTP fetch content as a range of chunks asynchronously.
 *
 * A range of chunks is returned immediately and the request that fetches the
 * chunks is performed in another thread. If the method or other request
 * properties is to be customized then set the $(D conn) parameter with a
 * Http/Ftp instance that has these properties set.
 *
 * If $(D postData) is non-null the method will be set to $(D post) for Http
 * requests.
 *
 * $(WEB curl.haxx.se/libcurl/c/curl_easy_setopt.html, _curl_easy_setopt)
 * 
 * Example:
 * ----
 * import etc.curl, std.stdio;
 * foreach (chunk; byChunkAsync("d-p-l.org", 100)) 
 *     writeln(chunk); // chunk is ubyte[100]
 * ----
 *
 * Returns:
 * A range of ubyte[chunkSize] with the content of the resource pointer 
 * to by the url
 */
auto byChunkAsync(Conn = AutoConnection, PostUnit)
           (const(char)[] url, const(PostUnit)[] postData, 
            size_t chunkSize = 1024, size_t transmitBuffers = 10,
            Conn conn = Conn())
if (is(Conn : Http) || is(Conn : Ftp) || is(Conn : AutoConnection))
{
    static if (is(Conn : AutoConnection))
    {
        if (url.startsWith("ftp://") || 
            url.startsWith("ftps://") || 
            url.startsWith("ftp."))
            return byChunkAsync(url, postData, chunkSize, 
                                transmitBuffers, Ftp());
        else 
            return byChunkAsync(url, postData, chunkSize, 
                                transmitBuffers, Http());
    }
    else
    {
        // 50 is just an arbitrary number for now
        setMaxMailboxSize(thisTid, 50, OnCrowding.block);
        Tid tid = spawn(&(_spawnAsync!(Conn, ubyte)));
        tid.send(thisTid);

        // no move semantic available in std.concurrency ie. must use casting.
        auto connDup = conn.dup();
        connDup.url = url;

        static if ( is(Conn : Http) )
        {
            connDup.p.headersOut = null;
            connDup.method = conn.method == Http.Method.undefined ? 
                Http.Method.get : conn.method; 
            if (postData !is null)
            {
                if (connDup.method == Http.Method.put)
                {
                    connDup.handle.set(CurlOption.infilesize_large, 
                                       postData.length);
                } else {
                    // post 
                    connDup.method = Http.Method.post;
                    connDup.handle.set(CurlOption.postfieldsize_large, 
                                       postData.length);
                }
                connDup.handle.set(CurlOption.copypostfields, 
                                   cast(void*) postData.ptr);
            }
            tid.send(cast(ulong)connDup.handle.handle);
            tid.send(connDup.method);
        } else {
            enforce(postData is null,
                    new CurlException("Cannot put ftp data using byLineAsync()"));
            tid.send(cast(ulong)connDup.handle.handle);
            tid.send(Http.Method.undefined);
        }
        connDup.p.curl.handle = null; // make sure handle is not freed
        return AsyncChunkInputRange(tid, transmitBuffers, chunkSize);
    }
}

/// ditto
auto byChunkAsync(Conn = AutoConnection)
           (const(char)[] url, 
            size_t chunkSize = 1024, size_t transmitBuffers = 10, 
            Conn conn = Conn())
if (is(Conn : Http) || is(Conn : Ftp) || is(Conn : AutoConnection))
{
    static if (is(Conn : AutoConnection))
    {
        if (url.startsWith("ftp://") || 
            url.startsWith("ftps://") || 
            url.startsWith("ftp."))
            return byChunkAsync(url, cast(void[])null, chunkSize, 
                                transmitBuffers, Ftp());
        else
            return byChunkAsync(url, cast(void[])null, chunkSize, 
                                transmitBuffers, Http());
    } else {
        return byChunkAsync(url, cast(void[])null, chunkSize, 
                            transmitBuffers, conn);
    }
}

unittest 
{
    if (!netAllowed) return;
    auto res = byChunkAsync(testUrl2, "Hello world");    
    auto line = res.front();
    assert(line == cast(ubyte[])"Hello world",
           "byLineAsync!Http() returns unexpected content " ~ to!string(line));
    res = byChunkAsync(testUrl1);    
    line = res.front();
    assert(line == cast(ubyte[])"Hello world\x0a",
           "byLineAsync!Http() returns unexpected content: " ~ to!string(line));
}


/**
  Mixin template for all supported curl protocols. 
  This documentation should really be in the Http struct but
  the documentation tool does not support a mixin to put its
  doc strings where a mixin is done.
*/
private mixin template Protocol() 
{

    /// Value to return from $(D onSend)/$(D onReceive) delegates in order to
    /// pause a request
    alias CurlReadFunc.pause requestPause;

    /// Value to return from onSend delegate in order to abort a request
    alias CurlReadFunc.abort requestAbort;

    static uint defaultAsyncStringBufferSize = 100;

    /**
       The curl handle used by this connection.
    */
    @property ref Curl handle()
    {
        return p.curl;
    }

    /**
       True if the instance is stopped and invalid.
    */
    @property bool isValid() 
    {
        return !p.curl.stopped;
    }
    
    /// Stop and invalidate this instance.
    void shutdown() 
    {
        p.curl.shutdown();
    }

    /** Set verbose.
        This will print request information to stderr.
     */
    @property void verbose(bool on) 
    {
        
        p.curl.set(CurlOption.verbose, on ? 1L : 0L);
    }

    // Connection settings

    /// Set timeout for activity on connection.
    @property void dataTimeout(Duration d)
    {
        p.curl.set(CurlOption.timeout_ms, d.total!"msecs"());
    }

    /// Set timeout for connecting.
    @property void connectTimeout(Duration d) 
    {
        p.curl.set(CurlOption.connecttimeout_ms, d.total!"msecs"());
    }
 
    // Network settings

    /// The URL to specify the location of the resource.
    @property void url(const(char)[] url) 
    {
        p.curl.set(CurlOption.url, url);
    }

    /** Proxy
     *  See: $(WEB curl.haxx.se/libcurl/c/curl_easy_setopt.html#CURLOPTPROXY, _proxy)
     */
    @property void proxy(const(char)[] host) 
    {
        p.curl.set(CurlOption.proxy, host);
    }
    
    /** Proxy port
     *  See: $(WEB curl.haxx.se/libcurl/c/curl_easy_setopt.html#CURLOPTPROXYPORT, _proxy_port)
     */
    @property void proxyPort(ushort port) 
    {
        p.curl.set(CurlOption.proxyport, cast(long) port);
    }

    /// Type of proxy
    alias etc.c.curl.CurlProxy CurlProxy;

    /** Proxy type
     *  See: $(WEB curl.haxx.se/libcurl/c/curl_easy_setopt.html#CURLOPTPROXY, _proxy_type)
     */
    @property void proxyType(CurlProxy type) 
    {
        p.curl.set(CurlOption.proxytype, cast(long) type);
    }

    /// DNS lookup timeout.
    @property void dnsTimeout(Duration d) 
    {
        p.curl.set(CurlOption.dns_cache_timeout, d.total!"msecs"());
    }

    /**
     * The network interface to use in form of the the IP of the interface.
     *
     * Example:
     * ----
     * theprotocol.netInterface = "192.168.1.32";
     * theprotocol.netInterface = [ 192, 168, 1, 32 ];
     * ----
     *
     * See: $(XREF socket, InternetAddress)
     */
    @property void netInterface(const(char)[] i) 
    {
        p.curl.set(CurlOption.intrface, i);
    }

    /// ditto
    @property void netInterface(const(ubyte)[4] i) 
    {
        string _i = to!string([0]) ~ "." ~ to!string([1]) ~ "." ~ 
            to!string([2]) ~ "." ~ to!string([3]);
        netInterface(_i);
    }

    /// ditto
    @property void netInterface(InternetAddress i) 
    {
        string _i = to!string([0]) ~ "." ~ to!string([1]) ~ "." ~ 
            to!string([2]) ~ "." ~ to!string([3]);
        netInterface(_i);
    }

    /**
       Set the local outgoing port to use.
       Params:
       port = the first outgoing port number to try and use
    */
    @property void localPort(ushort port) 
    {
        p.curl.set(CurlOption.localport, cast(long)port);
    }

    /**
       Set the local outgoing port range to use.
       This can be used together with the localPort property.
       Params:
       range = if the first port is occupied then try this many 
       port number forwards
    */
    @property void localPortRange(ushort range) 
    {
        p.curl.set(CurlOption.localportrange, cast(long)range);
    }

    /** Set the tcp no-delay socket option on or off.
        See: $(WEB curl.haxx.se/libcurl/c/curl_easy_setopt.html#CURLOPTTCPNODELAY, nodelay)
    */
    @property void tcpNoDelay(bool on) 
    {
        p.curl.set(CurlOption.tcp_nodelay, cast(long) (on ? 1 : 0) );
    }

    // Authentication settings

    /**
       Set the user name, password and optionally domain for authentication
       purposes.
    
       Some protocols may need authentication in some cases. Use this
       function to provide credentials.

       Params:
       username = the username
       password = the password
       domain = used for NTLM authentication only and is set to the NTLM domain 
                name
    */
    void setAuthentication(const(char)[] username, const(char)[] password, 
                           const(char)[] domain = "") 
    {
        if (domain != "")
            username = domain ~ "/" ~ username;
        p.curl.set(CurlOption.userpwd, username ~ ":" ~ password);
    }

    unittest 
    {
        if (!netAllowed) return;
        auto http = Http("http://www.protected.com");
        http.onReceiveHeader = 
            (const(char)[] key, 
             const(char)[] value) { /* writeln(key ~ ": " ~ value); */ };
        http.onReceive = (ubyte[] data) { return data.length; };
        http.setAuthentication("myuser", "mypassword");
        http.perform();
    }

    /**
     * The event handler that gets called when data is needed for sending. The
     * length of the $(D void[]) specifies the maximum number of bytes that can
     * be send.
     *
     * Returns:
     * The callback returns the number of elements in the buffer that have been 
     * filled and are ready to send.
     * The special value $(D .abortRequest) can be returned in order to abort the 
     * current request.
     * The special value $(D .pauseRequest) can be returned in order to pause the 
     * current request.
     *
     * Example:
     * ----
     * import etc.curl;
     * string msg = "Hello world";
     * auto client = Http("d-p-l.org");
     * client.onSend = delegate size_t(void[] data) { 
     *     auto m = cast(void[])msg;
     *     size_t length = m.length > data.length ? data.length : m.length;
     *     if (length == 0) return 0; 
     *     data[0..length] = m[0..length];
     *     msg = msg[length..$];
     *     return length;
     * };
     * client.perform();
     * ----
     */
    @property void onSend(size_t delegate(void[]) callback) 
    {
        p.curl.clear(CurlOption.postfields); // cannot specify data when using callback
        p.curl.onSend(callback);
    }

    /**
      * The event handler that receives incoming data. Be sure to copy the
      * incoming ubyte[] since it is not guaranteed to be valid after the
      * callback returns.
      *
      * Returns:
      * The callback returns the incoming bytes read. If not the entire array is
      * the request will abort.
      * The special value .pauseRequest can be returned in order to pause the 
      * current request.
      *
      * Example:
      * ----
      * import etc.curl, std.stdio;
      * auto client = Http("d-p-l.org");
      * client.onReceive = (ubyte[] data) { 
      *     writeln("Got data", to!(const(char)[])(data)); 
      *     return data.length;
      * };
      * client.perform();
      * ----
      */
    @property void onReceive(size_t delegate(ubyte[]) callback) 
    {
        p.curl.onReceive(callback);
    }

    /**
      * The event handler that gets called to inform of upload/download progress.
      *
      * Params:
      * dlTotal = total bytes to download
      * dlNow = currently downloaded bytes
      * ulTotal = total bytes to upload
      * ulNow = currently uploaded bytes
      *
      * Returns:
      * Return 0 from the callback to signal success, return non-zero to abort 
      *          transfer
      *
      * Example:
      * ----
      * import etc.curl, std.stdio;
      * auto client = Http("d-p-l.org");
      * client.onProgress = delegate int(size_t dl, size_t dln, size_t ul, size_t ult) { 
      *     writeln("Progress: downloaded ", dln, " of ", dl);
      *     writeln("Progress: uploaded ", uln, " of ", ul);  
      * };
      * client.perform();
      * ----
      */
    @property void onProgress(int delegate(size_t dlTotal, size_t dlNow, 
                                           size_t ulTotal, size_t ulNow) callback) 
    {
        p.curl.onProgress(callback);
    }
}

/*
  Decode $(D ubyte[]) array using the provided EncodingScheme up to maxChars
  Returns: Tuple of ubytes read and the $(D Char[]) characters decoded.
           Not all ubytes are guaranteed to be read in case of decoding error.
*/
private Tuple!(size_t,Char[]) 
decodeString(Char = char)(const(ubyte)[] data, 
                          EncodingScheme scheme,
                          size_t maxChars = size_t.max)
{
    Char[] res;
    size_t startLen = data.length;
    size_t charsDecoded = 0;
    while (data.length && charsDecoded < maxChars) 
    {
        dchar dc = scheme.safeDecode(data);
        if (dc == INVALID_SEQUENCE) 
        {
            return typeof(return)(size_t.max, cast(Char[])null);
        }
        charsDecoded++;
        res ~= dc;
    }
    return typeof(return)(startLen-data.length, res);
}

/*
  Decode $(D ubyte[]) array using the provided $(D EncodingScheme) until a the
  line terminator specified is found. The basesrc parameter is effectively
  prepended to src as the first thing.

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
                                                     ref ubyte[] src, 
                                                     ref Char[] dst,
						     EncodingScheme scheme,
						     Terminator terminator) 
{
    Char[] res;
    size_t startLen = src.length;
    size_t charsDecoded = 0;
    // if there is anything in the basesrc then try to decode that
    // first.
    if (basesrc.length != 0) 
    {
        // Try to ensure 4 entries in the basesrc by copying from src.
        size_t blen = basesrc.length;
        size_t len = (basesrc.length + src.length) >= 4 ? 
                     4 : basesrc.length + src.length;
        basesrc.length = len;
        dchar dc = scheme.safeDecode(basesrc);
        if (dc == INVALID_SEQUENCE) 
        {
            enforce(len != 4, new CurlException("Invalid code sequence"));
            return false;
        }
        dst ~= dc;
        src = src[len-basesrc.length-blen .. $]; // remove used ubytes from src
	basesrc.length = 0;
    }

    while (src.length) 
    {
        typeof(src) lsrc = src[];
        dchar dc = scheme.safeDecode(src);
        if (dc == INVALID_SEQUENCE) 
        {
            if (src.empty) 
            {
                // The invalid sequence was in the end of the src.  Maybe there
                // just need to be more bytes available so these last bytes are
                // put back to src for later use.
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
  * Http client functionality.
  *
  * Examples:
  * ---
  * import etc.curl, std.stdio;
  *
  * // Get with custom data receivers 
  * auto http = Http("d-p-l.org");
  * http.onReceiveHeader = 
  *     (const(char)[] key, const(char)[] value) { writeln(key ~ ": " ~ value); };
  * http.onReceive = (ubyte[] data) { /+ drop +/ return data.length; };
  * http.perform();
  * 
  * // Put with data senders 
  * auto msg = "Hello world";
  * http.onSend = (void[] data) { 
  *     auto m = cast(void[])msg;
  *     size_t length = m.length > data.length ? data.length : m.length;
  *     if (length == 0) return 0; 
  *     data[0..length] = m[0..length];
  *     msg = msg[length..$];
  *     return length;
  * };
  * http.perform();
  *
  * // Track progress
  * http.method = Http.Method.get;
  * http.url = "http://upload.wikimedia.org/wikipedia/commons/" 
  *            "5/53/Wikipedia-logo-en-big.png";
  * http.onReceive = (ubyte[] data) { return data.length; };
  * http.onProgress = (double dltotal, double dlnow, 
  *                    double ultotal, double ulnow) {
  *     writeln("Progress ", dltotal, ", ", dlnow, ", ", ultotal, ", ", ulnow);
  *     return 0;
  * };
  * http.perform();
  * ---
  *
  * See_Also: $(WEB www.ietf.org/rfc/rfc2616.txt, RFC2616)
  *
  */
struct Http
{ 
    mixin Protocol;

    /// Authentication method equal to $(ECXREF curl, CurlAuth)
    alias CurlAuth AuthMethod;

    static private uint defaultMaxRedirects = 10;

    private struct Impl 
    {
        ~this()
        {
            if (headersOut !is null)
                curl_slist_free_all(headersOut);
            if (curl.handle !is null) // work around RefCounted/emplace bug
                curl.shutdown();
        }
        Curl curl;
        curl_slist * headersOut;
        string[string] headersIn;
        string charset;

        /// The status line of the final sub-request in a request.
        StatusLine status;
        private void delegate(StatusLine) onReceiveStatusLine;
        
        /// The HTTP method to use.
        Method method = Method.undefined;
    }

    private RefCounted!Impl p;

    /** Time condition enumeration as an alias of $(ECXREF curl, CurlTimeCond)

        $(WEB www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.25, _RFC2616 Section 14.25)
    */
    alias CurlTimeCond TimeCond;

    /**
       Constructor taking the url as parameter.
    */
    this(const(char)[] url) 
    {
        p.RefCounted.initialize();
        p.curl.initialize();
        p.curl.set(CurlOption.url, url);
        this.maxRedirects = Http.defaultMaxRedirects;
        p.charset = "ISO-8859-1"; // Default charset defined in HTTP RFC
        p.method = Method.undefined;
        dataTimeout = dur!"minutes"(2);
        version (unittest) verbose(true);
    }

    static Http opCall() 
    {
        Http http;
        http.p.RefCounted.initialize();
        http.p.curl.initialize();
        http.maxRedirects = Http.defaultMaxRedirects;
        http.p.charset = "ISO-8859-1"; // Default charset defined in HTTP RFC
        http.p.method = Method.undefined;
        http.dataTimeout = dur!"minutes"(2);
        version (unittest) http.verbose(true);
        return http;
    }

    Http dup()
    {
        Http copy = Http();
        copy.p.charset = "ISO-8859-1"; // Default charset defined in HTTP RFC
        copy.p.status = StatusLine.init;
        copy.p.method = p.method;
        copy.p.onReceiveStatusLine = null;
        curl_slist * cur = p.headersOut;
        curl_slist * newlist = null;
        while (cur)
        {
            newlist = curl_slist_append(newlist, cur.data);
            cur = cur.next;
        }
        copy.p.headersOut = newlist;
        copy.p.curl.set(CurlOption.httpheader, copy.p.headersOut);
        copy.p.curl = p.curl.dup();
        copy.dataTimeout = dur!"minutes"(2);
        return copy;
    }

    /**
       Perform a http request.

       After the Http client has been setup and possibly assigned callbacks the
       $(D perform()) method will start performing the request towards the
       specified server.
    */
    void perform() 
    {
        _perform();
    }

    private CURLcode _perform(bool throwOnError = true) 
    {
        p.status.reset;

        final switch (p.method) {
        case Method.head:
            p.curl.set(CurlOption.nobody, 1L);
            break;
        case Method.undefined:
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

        return p.curl.perform(throwOnError);
    }

    /** Clear all outgoing headers.
    */
    void clearHeaders()
    {
        if (p.headersOut !is null)
            curl_slist_free_all(p.headersOut);
        p.headersOut = null;
        p.curl.clear(CurlOption.httpheader);
    }

    /** Add a header e.g. "X-CustomField: Something is fishy".
     *
     * There is no remove header functionality. Do a $(LREF clearHeaders) and
     * set the needed headers instead.
     *
     * Example:
     * ---
     * import etc.curl;
     * auto client = Http();
     * client.addHeader("X-Custom-ABC", "This is the custom value");
     * string content = get("d-p-l.org", client);
     * ---
     */
    void addHeader(const(char)[] name, const(char)[] value) 
    {
        p.headersOut = curl_slist_append(p.headersOut, 
                                         cast(char*) toStringz(name ~ ": " ~ value));
        p.curl.set(CurlOption.httpheader, p.headersOut);
    }

    /// Http method used.
    @property void method(Method m) 
    {
        p.method = m;
    }

    /// ditto
    @property Method method() 
    {
        return p.method;
    }

    /**
       Http status line of last response. One call to perform may
       result in several requests because of redirection.
    */
    @property StatusLine statusLine()
    {
        return p.status;
    }

    // Set the active cookie string e.g. "name1=value1;name2=value2"
    void setCookie(const(char)[] cookie) 
    {
        p.curl.set(CurlOption.cookie, cookie);
    }

    /// Set a file path to where a cookie jar should be read/stored.
    void setCookieJar(const(char)[] path) 
    {
        p.curl.set(CurlOption.cookiefile, path);
        p.curl.set(CurlOption.cookiejar, path);
    }

    /// Flush cookie jar to disk.
    void flushCookieJar() 
    {
        p.curl.set(CurlOption.cookielist, "FLUSH");
    }

    /// Clear session cookies.
    void clearSessionCookies() 
    {
        p.curl.set(CurlOption.cookielist, "SESS");
    }

    /// Clear all cookies.
    void clearAllCookies() 
    {
        p.curl.set(CurlOption.cookielist, "ALL");
    }

    /**
       Set time condition on the request.

       Parameters:
       cond:  $(D CurlTimeCond.{none,ifmodsince,ifunmodsince,lastmod})
       timestamp: Timestamp for the condition

       $(WEB www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.25, _RFC2616 Section 14.25)
    */
    void setTimeCondition(Http.TimeCond cond, DateTime timestamp) 
    {
        p.curl.set(CurlOption.timecondition, cond);
        long secsSinceEpoch = (timestamp - DateTime(1970, 1, 1)).total!"seconds";
        p.curl.set(CurlOption.timevalue, secsSinceEpoch);
    }

    /** Specifying data to post when not using the onSend callback.
      *
      * The data is NOT copied by the library.  Content-Type will default to
      * application/octet-stream.  Data is not converted or encoded by this
      * method.
      *
      * Example:
      * ----
      * import etc.curl, std.stdio;
      * auto http = Http("http://www.mydomain.com");
      * http.onReceive = (ubyte[] data) { writeln(to!(const(char)[])(data)); return data.length; };
      * http.postData = [1,2,3,4,5];
      * http.perform();
      * ----
      */
    @property void postData(const(void)[] data) 
    {
        // cannot use callback when specifying data directly so is is disabled
        // here.
        p.curl.clear(CurlOption.readfunction); 
        addHeader("Content-Type", "application/octet-stream");
        p.curl.set(CurlOption.postfields, cast(void*)data.ptr);
        if (method == Method.undefined)
            method = Method.post;
    }
 
    /** Specifying data to post when not using the onSend callback.
      *
      * The data is NOT copied by the library.  Content-Type will default to
      * text/plain.  Data is not converted or encoded by this method.
      *
      * Example:
      * ----
      * import etc.curl, std.stdio;
      * auto http = Http("http://www.mydomain.com");
      * http.onReceive = (ubyte[] data) { writeln(to!(const(char)[])(data)); return data.length; };
      * http.postData = "The quick....";
      * http.perform();
      * ----
      */
    @property void postData(const(char)[] data) 
    {
        // cannot use callback when specifying data directly so it is disabled here.
        // here.
        p.curl.clear(CurlOption.readfunction); 
        addHeader("Content-Type", "text/plain");
        p.curl.set(CurlOption.postfields, cast(void*)data.ptr);
        if (method == Method.undefined)
            method = Method.post;
    }

    /**
      * Set the event handler that receives incoming headers. 
      * 
      * The callback will receive a header field key, value as parameter. The
      * $(D char[]) arrays are not valid after the delegate has returned.
      *
      * Example:
      * ----
      * import etc.curl, std.stdio;
      * auto http = Http("http://www.d-p-l.org");
      * http.onReceive = (ubyte[] data) { writeln(to!(const(char)[])(data)); return data.length; };
      * http.onReceiveHeader = (const(char)[] key, const(char[]) value) { writeln(key, " = ", value); };
      * http.perform();
      * ----
      */
    @property void onReceiveHeader(void delegate(const(char)[] key,
                                                 const(char)[] value) callback) 
    {
        // Wrap incoming callback in order to separate http status line from
        // http headers.  On redirected requests there may be several such
        // status lines. The last one is the one recorded.
        auto dg = (const(char)[] header) { 
            if (header.length == 0) 
            {
                // header delimiter
                return;
            }
            if (header.startsWith("HTTP/")) 
            {
                string[string] empty;
                p.headersIn = empty; // clear

                auto m = match(header, regex(r"^HTTP/(\d+)\.(\d+) (\d+) (.*)$"));
                if (m.empty) 
                {
                    // Invalid status line
                } 
                else 
                {
                    p.status.majorVersion = to!ushort(m.captures[1]);
                    p.status.minorVersion = to!ushort(m.captures[2]);
                    p.status.code = to!ushort(m.captures[3]);
                    p.status.reason = m.captures[4].idup;
                    if (p.onReceiveStatusLine != null) 
                        p.onReceiveStatusLine(p.status);
                }
                return;
            }
            
            // Normal http header
            auto m = match(cast(char[]) header, regex("(.*?): (.*)$"));

            string fieldName = m.captures[1].toLower.idup;
            if (fieldName == "content-type")
            {
                auto mct = match(cast(char[]) m.captures[2], 
                                 regex("charset=([^;]*)"));
                if (!mct.empty && mct.captures.length > 1)
                    p.charset = mct.captures[1].idup;
            }

            if (!m.empty) 
                callback(fieldName, m.captures[2]); 
            p.headersIn[fieldName] = m.captures[2].idup;
        };
        p.curl.onReceiveHeader(callback is null ? null : dg);
    }

    /**
       Callback for each received StatusLine.

       Notice that several callbacks can be done for each call to
       $(D perform()) due to redirections.

       See_Also: $(LREF StatusLine)
     */
    @property void onReceiveStatusLine(void delegate(StatusLine) callback) 
    {
        p.onReceiveStatusLine = callback;
    }

    /**
       The content length in bytes when using request that has content
       e.g. POST/PUT and not using chunked transfer. Is set as the
       "Content-Length" header.  Set to size_t.max to reset to chunked transfer.
    */
    @property void contentLength(size_t len) 
    {
        CurlOption lenOpt;

        // Force post if necessary
        if (p.method != Method.put && p.method != Method.post)
            p.method = Method.post;

        if (p.method == Method.put)
            lenOpt = CurlOption.infilesize_large;
        else 
            // post
            lenOpt = CurlOption.postfieldsize_large;

        if (len == size_t.max)
        {
            // HTTP 1.1 supports requests with no length header set.
            addHeader("Transfer-Encoding", "chunked");
            addHeader("Expect", "100-continue");
        } else {
            p.curl.set(lenOpt, len);
        }
    }

    /**
       Authentication method as specified in $(LREF AuthMethod).
    */
    @property void authenticationMethod(AuthMethod authMethod) {
        p.curl.set(CurlOption.httpauth, cast(long) authMethod);
    }

    /**
       Set max allowed redirections using the location header. 
       uint.max for infinite.
    */
    @property void maxRedirects(uint maxRedirs) 
    {
        if (maxRedirs == uint.max) 
        {
            // Disable
            p.curl.set(CurlOption.followlocation, 0);
        } 
        else
        {
            p.curl.set(CurlOption.followlocation, 1);
            p.curl.set(CurlOption.maxredirs, maxRedirs);
        }
    }

    /** <a name="Http.Method"/ >The standard HTTP methods :
     *  $(WEB www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.1.1, _RFC2616 Section 5.1.1)
     */
    enum Method 
    {
        undefined, 
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
       HTTP status line ie. the first line returned in an HTTP response.
    
       If authentication or redirections are done then the status will be for
       the last response received.
    */
    struct StatusLine 
    {
        ushort majorVersion; /// Major HTTP version ie. 1 in HTTP/1.0.
        ushort minorVersion; /// Minor HTTP version ie. 0 in HTTP/1.0.
        ushort code;         /// HTTP status line code e.g. 200.
        string reason;       /// HTTP status line reason string.
        
        /// Reset this status line
        @safe void reset() 
        { 
            majorVersion = 0;
            minorVersion = 0;
            code = 0;
            reason = "";
        }

        /// 
        string toString()
        {
            return format(code, reason, "(" ~ to!string(majorVersion) ~ 
                          "." ~ to!string(minorVersion));
        }
    }

} // Http

 
/**
   Ftp client functionality.

   See_Also: $(WEB tools.ietf.org/html/rfc959, RFC959)
*/
struct Ftp
{
    
    mixin Protocol;

    private struct Impl 
    {
        ~this()
        {
            if (commands !is null)
                curl_slist_free_all(commands);
            if (curl.handle !is null) // work around RefCounted/emplace bug
                curl.shutdown();
        }
        curl_slist * commands;
        Curl curl;
        string encoding;
    }

    private RefCounted!Impl p;

    /**
       Ftp access to the specified url.
    */
    this(const(char)[] url) 
    {
        p.RefCounted.initialize();
        p.curl.initialize();
        p.curl.set(CurlOption.url, url);
        p.encoding = "ISO-8859-1";
        dataTimeout(dur!"minutes"(2));
        version (unittest) verbose(true);
    }

    static Ftp opCall() 
    {
        Ftp ftp;
        ftp.p.RefCounted.initialize();
        ftp.p.curl.initialize();
        ftp.p.encoding = "ISO-8859-1";
        ftp.dataTimeout(dur!"minutes"(2));
        version (unittest) ftp.verbose(true);
        return ftp;
    }

    /**
       Performs the ftp request as it has been configured.

       After a Ftp client has been setup and possibly assigned callbacks the $(D
       perform()) method will start performing the actual communication with the
       server.
    */
    void perform() 
    {
        _perform();
    }

    private CURLcode _perform(bool throwOnError = true) 
    {
        return p.curl.perform(throwOnError);
    }


    Ftp dup()
    {
        Ftp copy = Ftp();
        copy.p.encoding = p.encoding;;
        copy.p.curl = p.curl.dup();
        curl_slist * cur = p.commands;
        curl_slist * newlist = null;
        while (cur)
        {
            newlist = curl_slist_append(newlist, cur.data);
            cur = cur.next;
        }
        copy.p.commands = newlist;
        copy.p.curl.set(CurlOption.postquote, copy.p.commands);
        copy.dataTimeout(dur!"minutes"(2));
        return copy;
    }

    /** Clear all commands send to ftp server.
    */
    void clearCommands()
    {
        if (p.commands !is null)
            curl_slist_free_all(p.commands);
        p.commands = null;
        p.curl.clear(CurlOption.postquote);
    }

    /** Add a command to send to ftp server.
     *
     * There is no remove command functionality. Do a $(LREF clearCommands) and
     * set the needed commands instead.
     *
     * Example:
     * ---
     * import etc.curl;
     * auto client = Ftp();
     * upload("my_file.txt", "ftp.digitalmars.com", client);
     * client.addCommand("RNFR my_file.txt");
     * client.addCommand("RNTO my_renamed_file.txt");
     * client.perform();
     * ---
     */
    void addCommand(const(char)[] command) 
    {
        p.commands = curl_slist_append(p.commands, 
                                       cast(char*) toStringz(command));
        p.curl.set(CurlOption.postquote, p.commands);
    }

    @property void encoding(const(char)[] name) 
    {
        p.encoding = name.idup;
    }

    @property string encoding()
    {
        return p.encoding;
    }

    /**
       The content length in bytes of the ftp data.
    */
    @property void contentLength(size_t len) 
    {
        p.curl.set(CurlOption.infilesize_large, len);      
    }
}

/**
  * Basic SMTP protocol support.
  * 
  * Example:
  * ---
  * import etc.curl;
  *
  * // Send an email with SMTPS
  * auto smtp = Smtp("smtps://smtp.gmail.com");
  * smtp.setAuthentication("from.addr@gmail.com", "password");
  * smtp.mailTo = ["<to.addr@gmail.com>"];
  * smtp.mailFrom = "<from.addr@gmail.com>";
  * smtp.message = "Example Message";
  * smtp.perform();
  * ---
  *
  * See_Also: $(WEB www.ietf.org/rfc/rfc2821.txt, RFC2821)
  */
struct Smtp 
{
    mixin Protocol;
    
    private struct Impl 
    {
        ~this()
        {
            if (curl.handle !is null) // work around RefCounted/emplace bug
                curl.shutdown();
        }
        Curl curl;
    }

    private RefCounted!Impl p;

    /**
        Sets to the url of the SMTP server.
    */
    this(string url) 
    {
        p.RefCounted.initialize();
        p.curl.initialize();
        
        if (url.startsWith("smtps://")) 
        {
            p.curl.set(CurlOption.use_ssl, CurlUseSSL.all);
            p.curl.set(CurlOption.ssl_verifypeer, false);
            p.curl.set(CurlOption.ssl_verifyhost, 2);
        }
        else
        {
            enforce(url.startsWith("smtp://"), 
                    new CurlException("The url must be for the smtp protocol."));
        }
 
        p.curl.set(CurlOption.url, url);
        dataTimeout(dur!"minutes"(2));
    }

    /**
        Performs the request as configured.
    */
    void perform() 
    {
        p.curl.perform;
    }

    /**
        Setter for the sender's email address.
    */
    @property void mailFrom(string sender) 
    {
        assert(sender.length > 0, "Sender must not be empty");
        p.curl.set(CurlOption.mail_from, sender);
    }
    
    /**
        Setter for the recipient email addresses.
    */
    @property void mailTo(string[] recipients) 
    {
        assert(recipients.length > 0, "Recipient must not be empty");
        curl_slist* recipients_list = null;
        foreach(recipient; recipients) 
        {
            recipients_list = 
                curl_slist_append(recipients_list, 
                                  cast(char*)toStringz(recipient));
        }
        p.curl.set(CurlOption.mail_rcpt, recipients_list);
    }
    
    /**
        Sets the message body text.
    */
    @property void message(string msg) 
    {
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
}

/// An exception class for curl.
class CurlException : Exception 
{
    /// Construct a CurlException with given error message.
    this(const(char)[] msg) { super(msg.idup); }
}

/// An timeout exception class for curl.
class CurlTimeoutException : CurlException 
{
    /// Construct a CurlTimeoutException with given error message.
    this(const(char)[] msg) { super(msg); }
}

/**
  Wrapper class to provide a better interface to libcurl than using the plain C
  API.  It is recommended to use the $(D Http)/$(D Ftp) etc. classes instead
  unless raw access to libcurl is needed.
*/
struct Curl 
{
    shared static this() 
    {
        // initialize early to prevent thread races
        enforce(!curl_global_init(CurlGlobal.all),
                new CurlException("Couldn't initialize libcurl"));
    }
 
    shared static ~this() 
    {
        curl_global_cleanup();
    }

    alias void[] OutData;
    alias ubyte[] InData;
    bool stopped;

    // A handle should not be used by two threads simultaneously
    private CURL* handle;

    // May also return $(D CURL_READFUNC_ABORT) or $(D CURL_READFUNC_PAUSE)
    private size_t delegate(OutData) _onSend; 
    private size_t delegate(InData) _onReceive;
    private void delegate(const(char)[]) _onReceiveHeader;
    private CurlSeek delegate(long,CurlSeekPos) _onSeek;
    private int delegate(curl_socket_t,CurlSockType) _onSocketOption;
    private int delegate(size_t dltotal, size_t dlnow, 
                         size_t ultotal, size_t ulnow) _onProgress;
    
    alias CurlReadFunc.pause requestPause;
    alias CurlReadFunc.abort requestAbort;

    /**
       Initialize the instance by creating a working curl handle.
    */
    void initialize() 
    {
        enforce(!handle, new CurlException("Curl instance already initialized"));
        handle = curl_easy_init();
        enforce(handle, new CurlException("Curl instance couldn't be initialized"));
        stopped = false;
        set(CurlOption.nosignal, 1);
    }

    /**
       Duplicate this handle.
       
       The new handle will have all options set as the one it was duplicated
       from. An exception to this is that all options that cannot be shared
       across threads are reset thereby making it safe to use the duplicate 
       in a new thread.
    */
    Curl dup()
    {
        Curl copy;
        copy.handle = curl_easy_duphandle(handle);
        copy.stopped = false;
        copy.clear(CurlOption.file);
        copy.clear(CurlOption.writefunction);
        copy.clear(CurlOption.writeheader);
        copy.clear(CurlOption.headerfunction);
        copy.clear(CurlOption.infile);
        copy.clear(CurlOption.readfunction);
        copy.clear(CurlOption.ioctldata);
        copy.clear(CurlOption.ioctlfunction);
        copy.clear(CurlOption.seekdata);
        copy.clear(CurlOption.seekfunction);
        copy.clear(CurlOption.sockoptdata);
        copy.clear(CurlOption.sockoptfunction);
        copy.clear(CurlOption.opensocketdata);
        copy.clear(CurlOption.opensocketfunction);

        // Enable for curl version > 7.21.7
        // copy.clear(CurlOption.closesocketdata);
        // copy.clear(CurlOption.closesocketfunction);

        copy.clear(CurlOption.noprogress);
        copy.clear(CurlOption.progressdata);
        copy.clear(CurlOption.progressfunction);
        copy.clear(CurlOption.debugdata);
        copy.clear(CurlOption.debugfunction);
        // copy.clear(CurlOption.ssl_ctx_data); Let ssl function be shared
        copy.clear(CurlOption.ssl_ctx_function);
        /*
        Allow sharing of conv functions
        copy.clear(CurlOption.conv_to_network_function);
        copy.clear(CurlOption.conv_from_network_function);
        copy.clear(CurlOption.conv_from_utf8_function);
        */
        copy.clear(CurlOption.interleavedata);
        copy.clear(CurlOption.interleavefunction);
        copy.clear(CurlOption.chunk_data);
        copy.clear(CurlOption.chunk_bgn_function);
        copy.clear(CurlOption.chunk_end_function);
        copy.clear(CurlOption.fnmatch_data);
        copy.clear(CurlOption.fnmatch_function);
        copy.clear(CurlOption.ssh_keydata);
        // copy.clear(CurlOption.ssh_keyfunction); Let key function be shared

        copy.clear(CurlOption.cookiejar); // disable writing cookies to file
        copy.clear(CurlOption.postfields);
        copy.set(CurlOption.nosignal, 1);
        return copy;
    }

    private void _check(CURLcode code) 
    {
        enforce(code != CurlError.operation_timedout,
                new CurlTimeoutException(errorString(code)));

        enforce(code == CurlError.ok,
                new CurlException(errorString(code)));
    }

    private string errorString(CURLcode code) 
    {
        return to!string(curl_easy_strerror(code)) ~ " on handle " ~ 
            to!string(handle);
    }

    private void throwOnStopped(const(char)[] message = null) 
    {
        const(char)[] def = "Curl instance called after being cleaned up";
        enforce(!stopped,
                new CurlException(message == null ? def : message));
    }
    
    /** 
        Stop and invalidate this curl instance.
        Warning: Do not call this from inside a callback handler e.g. $(D onReceive).
    */
    void shutdown() 
    {
        throwOnStopped();
        stopped = true;
        curl_easy_cleanup(this.handle);
        this.handle = null;
    }

    /**
       Pausing and continuing transfers.
    */
    void pause(bool sendingPaused, bool receivingPaused) 
    {
        throwOnStopped();
        _check(curl_easy_pause(this.handle, 
                               (sendingPaused ? CurlPause.send_cont : CurlPause.send) |
                               (receivingPaused ? CurlPause.recv_cont : CurlPause.recv)));
    }

    /**
       Set a string curl option.
       Params:
       option = A $(ECXREF curl, CurlOption) as found in the curl documentation
       value = The string
    */
    void set(CURLoption option, const(char)[] value) 
    {
        throwOnStopped();
        _check(curl_easy_setopt(this.handle, option, toStringz(value)));
    }

    // Make ddoc happy - it complaints about conflicting overloads
    void set(CURLoption option, char[] value) 
    {
        set(option, cast(const(char)[])value);
    }

    /**
       Set a long curl option.
       Params:
       option = A $(ECXREF curl, CurlOption) as found in the curl documentation
       value = The long
    */
    void set(CURLoption option, long value) 
    {
        throwOnStopped();
        _check(curl_easy_setopt(this.handle, option, value));
    }

    /**
       Set a void* curl option.
       Params:
       option = A $(ECXREF curl, CurlOption) as found in the curl documentation
       value = The pointer
    */
    void set(CURLoption option, void* value) 
    {
        throwOnStopped();
        _check(curl_easy_setopt(this.handle, option, value));
    }

    /**
       Clear a pointer option.
       Params:
       option = A $(ECXREF curl, CurlOption) as found in the curl documentation
    */
    void clear(CURLoption option) 
    {
        throwOnStopped();
        _check(curl_easy_setopt(this.handle, option, cast(void*)0));
    }

    /**
       perform the curl request by doing the HTTP,FTP etc. as it has
       been setup beforehand.
    */
    CURLcode perform(bool throwOnError = true) 
    {
        throwOnStopped();
        CURLcode code = curl_easy_perform(this.handle);
        if (throwOnError)
            _check(code);
        return code;
    }

    /**
      * The event handler that receives incoming data.
      *
      * Params:
      * callback = the callback that receives the $(D ubyte[]) data.
      * Be sure to copy the incoming data and not store
      * a slice.
      *
      * Returns:
      * The callback returns the incoming bytes read. If not the entire array is 
      * the request will abort.
      * The special value Http.pauseRequest can be returned in order to pause the 
      * current request.
      *
      * Example:
      * ----
      * import etc.curl, std.stdio;
      * Curl curl;
      * curl.initialize();
      * curl.set(CurlOption.url, "http://www.d-p-l.org");
      * curl.onReceive = (ubyte[] data) { writeln("Got data", to!(const(char)[])(data)); return data.length;};
      * curl.perform();
      * ----
      */
    @property void onReceive(size_t delegate(InData) callback) 
    { 
        _onReceive = (InData id) { 
            throwOnStopped("Receive callback called on cleaned up Curl instance");
            return callback(id);
        };
        set(CurlOption.file, cast(void*) &this);
        set(CurlOption.writefunction, cast(void*) &Curl._receiveCallback);
    }

    /**
      * The event handler that receives incoming headers for protocols
      * that uses headers.
      *
      * Params:
      * callback = the callback that receives the header string.
      * Make sure the callback copies the incoming params if
      * it needs to store it because they are references into
      * the backend and may very likely change.
      *
      * Example:
      * ----
      * import etc.curl, std.stdio;
      * Curl curl;
      * curl.initialize();
      * curl.set(CurlOption.url, "http://www.d-p-l.org");
      * curl.onReceiveHeader = (const(char)[] header) { writeln(header); };
      * curl.perform();
      * ----
      */
    @property void onReceiveHeader(void delegate(const(char)[]) callback) 
    {
        _onReceiveHeader = (const(char)[] od) {
            throwOnStopped("Receive header callback called on "
                           "cleaned up Curl instance");
            callback(od);
        };
        set(CurlOption.writeheader, cast(void*) &this);
        set(CurlOption.headerfunction, 
            cast(void*) &Curl._receiveHeaderCallback);
    }

    /**
      * The event handler that gets called when data is needed for sending.
      *
      * Params:
      * callback = the callback that has a $(D void[]) buffer to be filled
      *
      * Returns:
      * The callback returns the number of elements in the buffer that have been
      * filled and are ready to send.
      * The special value $(D Curl.abortRequest) can be returned in 
      * order to abort the current request.
      * The special value $(D Curl.pauseRequest) can be returned in order to 
      * pause the current request.
      *
      * Example:
      * ----
      * import etc.curl;
      * Curl curl;
      * curl.initialize();
      * curl.set(CurlOption.url, "http://www.d-p-l.org");
      *
      * string msg = "Hello world";
      * curl.onSend = (void[] data) { 
      *     auto m = cast(void[])msg;
      *     size_t length = m.length > data.length ? data.length : m.length;
      *     if (length == 0) return 0; 
      *     data[0..length] = m[0..length];
      *     msg = msg[length..$];
      *     return length;
      * };
      * curl.perform();
      * ----
      */
    @property void onSend(size_t delegate(OutData) callback) 
    {
        _onSend = (OutData od) {
            throwOnStopped("Send callback called on cleaned up Curl instance");
            return callback(od);
        };
        set(CurlOption.infile, cast(void*) &this);
        set(CurlOption.readfunction, cast(void*) &Curl._sendCallback);
    }

    /**
      * The event handler that gets called when the curl backend needs to seek
      * the data to be sent.
      *
      * Params:
      * callback = the callback that receives a seek offset and a seek position 
      *            $(ECXREF curl, CurlSeekPos)
      *
      * Returns:
      * The callback returns the success state of the seeking 
      * $(ECXREF curl, CurlSeek)
      *
      * Example:
      * ----
      * import etc.curl;
      * Curl curl;
      * curl.initialize();
      * curl.set(CurlOption.url, "http://www.d-p-l.org");
      * curl.onSeek = (long p, CurlSeekPos sp) { 
      *     return CurlSeek.cantseek;
      * };
      * curl.perform();
      * ----
      */
    @property void onSeek(CurlSeek delegate(long, CurlSeekPos) callback) 
    { 
        _onSeek = (long ofs, CurlSeekPos sp) { 
            throwOnStopped("Seek callback called on cleaned up Curl instance");
            return callback(ofs, sp);
        };
        set(CurlOption.seekdata, cast(void*) &this);
        set(CurlOption.seekfunction, cast(void*) &Curl._seekCallback);
    }

    /**
      * The event handler that gets called when the net socket has been created
      * but a $(D connect()) call has not yet been done. This makes it possible to set
      * misc. socket options.
      *
      * Params:
      * callback = the callback that receives the socket and socket type 
      * $(ECXREF curl, CurlSockType)
      *
      * Returns:
      * Return 0 from the callback to signal success, return 1 to signal error 
      * and make curl close the socket
      *
      * Example:
      * ----
      * import etc.curl;
      * Curl curl;
      * curl.initialize();
      * curl.set(CurlOption.url, "http://www.d-p-l.org");
      * curl.onSocketOption = delegate int(curl_socket_t s, CurlSockType t) { /+ do stuff +/ };
      * curl.perform();
      * ----
      */
    @property void onSocketOption(int delegate(curl_socket_t, 
                                               CurlSockType) callback) 
    {
        _onSocketOption = (curl_socket_t sock, CurlSockType st) {
            throwOnStopped("Socket option callback called on "
                           "cleaned up Curl instance");
            return callback(sock, st);
        };
        set(CurlOption.sockoptdata, cast(void*) &this);
        set(CurlOption.sockoptfunction, 
            cast(void*) &Curl._socketOptionCallback);
    }

    /**
      * The event handler that gets called to inform of upload/download progress.
      *
      * Params:
      * callback = the callback that receives the (total bytes to download, 
      * currently downloaded bytes, total bytes to upload, currently uploaded 
      * bytes).
      *
      * Returns:
      * Return 0 from the callback to signal success, return non-zero to abort 
      * transfer
      *
      * Example:
      * ----
      * import etc.curl;
      * Curl curl;
      * curl.initialize();
      * curl.set(CurlOption.url, "http://www.d-p-l.org");
      * curl.onProgress = delegate int(size_t dltotal, size_t dlnow, size_t ultotal, size_t uln) { 
      *     writeln("Progress: downloaded bytes ", dlnow, " of ", dltotal);
      *     writeln("Progress: uploaded bytes ", ulnow, " of ", ultotal);  
      * curl.perform();
      * };
      * ----
      */
    @property void onProgress(int delegate(size_t dlTotal, 
                                           size_t dlNow, 
                                           size_t ulTotal, 
                                           size_t ulNow) callback) 
    {
        _onProgress = (size_t dlt, size_t dln, size_t ult, size_t uln) {
            throwOnStopped("Progress callback called on cleaned "
                           "up Curl instance");
            return callback(dlt, dln, ult, uln);
        };
        set(CurlOption.noprogress, 0);
        set(CurlOption.progressdata, cast(void*) &this);
        set(CurlOption.progressfunction, cast(void*) &Curl._progressCallback);
    }
 
    // Internal C callbacks to register with libcurl
    extern (C) private static 
    size_t _receiveCallback(const char* str, 
                            size_t size, size_t nmemb, void* ptr) 
    {
        Curl* b = cast(Curl*) ptr;
        if (b._onReceive != null)
            return b._onReceive(cast(InData)(str[0..size*nmemb]));
        return size*nmemb;
    }

    extern (C) private static 
    size_t _receiveHeaderCallback(const char* str, 
                                  size_t size, size_t nmemb, void* ptr) 
    {
        Curl* b = cast(Curl*) ptr;
        auto s = str[0..size*nmemb].chomp;
        if (b._onReceiveHeader != null) 
            b._onReceiveHeader(s); 

        return size*nmemb;
    }

    extern (C) private static 
    size_t _sendCallback(char *str, size_t size, size_t nmemb, void *ptr)    
    {                                                                       
        Curl* b = cast(Curl*) ptr;
        void[] a = cast(void[]) str[0..size*nmemb];
        if (b._onSend == null)
            return 0;
        return b._onSend(a);
    }

    extern (C) private static 
    int _seekCallback(void *ptr, curl_off_t offset, int origin)           
    {                                                                   
        Curl* b = cast(Curl*) ptr;
        if (b._onSeek == null)
            return CurlSeek.cantseek;

        // origin: CurlSeekPos.set/current/end
        // return: CurlSeek.ok/fail/cantseek
        return b._onSeek(cast(long) offset, cast(CurlSeekPos) origin);
    }

    extern (C) private static 
    int _socketOptionCallback(void *ptr, 
                              curl_socket_t curlfd, curlsocktype purpose)  
    {                                                                        
        Curl* b = cast(Curl*) ptr;
        if (b._onSocketOption == null)
            return 0;

        // return: 0 ok, 1 fail
        return b._onSocketOption(curlfd, cast(CurlSockType) purpose);
    }

    extern (C) private static 
    int _progressCallback(void *ptr, 
                          double dltotal, double dlnow, 
                          double ultotal, double ulnow)
    {                                                                 
        Curl* b = cast(Curl*) ptr;
        if (b._onProgress == null)
            return 0;

        // return: 0 ok, 1 fail
        return b._onProgress(cast(size_t)dltotal, cast(size_t)dlnow, 
                             cast(size_t)ultotal, cast(size_t)ulnow);
    }

}

// Internal messages send between threads. 
// The data is wrapped in this struct in order to ensure that 
// other std.concurrency.receive calls does not pick up our messages
// by accident.
private struct Message(T) 
{
    public T data;
}

private static Message!T message(T)(T data) 
{
    return Message!T(data);
}

// Pool of to be used for reusing buffers
private struct Pool(DATA) 
{
    private struct Entry 
    {
        DATA data;
        Entry * next;
    };
    private Entry * root;
    private Entry * freeList;

    @safe bool empty() 
    {
        return root == null;
    }

    @safe nothrow void push(DATA d) 
    {
        if (freeList == null) 
        {
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

    @safe DATA pop() 
    {
        enforce(root != null, new Exception("pop() called on empty pool"));
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
                                          ref ubyte[] buffer, Tid fromTid, 
                                          ref bool aborted) 
{
    size_t datalen = data.length;

    // Copy data to fill active buffer
    while (data.length != 0) 
    {
                    
        // Make sure a buffer is present
        while ( outdata.length == 0 && freeBuffers.empty) 
        {
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
        if (outdata.length == 0) 
        {
            buffer = freeBuffers.pop();
            outdata = buffer[];
        }
                    
        // Copy data
        size_t copyBytes = outdata.length < data.length ? 
            outdata.length : data.length;

        outdata[0..copyBytes] = data[0..copyBytes];
        outdata = outdata[copyBytes..$];
        data = data[copyBytes..$];

        if (outdata.length == 0) 
            fromTid.send(thisTid(), message(cast(immutable(ubyte)[])buffer));
    }

    return datalen;
}

// ditto
private static void _finalizeAsyncChunks(ubyte[] outdata, ref ubyte[] buffer, 
                                         Tid fromTid) 
{
    if (outdata.length != 0) 
    {
        // Resize the last buffer
        buffer.length = buffer.length - outdata.length;
        fromTid.send(thisTid(), message(cast(immutable(ubyte)[])buffer));
    }
}


// Shared function for reading incoming lines of data and sending the to a
// parent thread
private static size_t _receiveAsyncLines(Terminator, Unit)
    (ubyte[] data, ref EncodingScheme encodingScheme,
     bool keepTerminator, Terminator terminator, 
     ref ubyte[] leftOverBytes, ref bool bufferValid,
     ref Pool!(Unit[]) freeBuffers, ref Unit[] buffer,
     Tid fromTid, ref bool aborted) 
{
    
    size_t datalen = data.length;

    // Terminator is specified and buffers should be resized as determined by
    // the terminator

    // Copy data to active buffer until terminator is found.

    // Decode as many lines as possible
    while (true) 
    {

        // Make sure a buffer is present
        while (!bufferValid && freeBuffers.empty) 
        {
            // Active buffer is invalid and there are no available buffers in
            // the pool. Wait for buffers to return from main thread in order to
            // reuse them.
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
        if (!bufferValid) 
        {
            buffer = freeBuffers.pop();
            bufferValid = true;
        }

        // Try to read a line from left over bytes from last onReceive plus the
        // newly received bytes.
        try 
        { 
            if (decodeLineInto(leftOverBytes, data, buffer,
                               encodingScheme, terminator)) 
            {
                if (keepTerminator) 
                {
                    fromTid.send(thisTid(), 
                                 message(cast(immutable(Unit)[])buffer));
                } 
                else 
                {
                    static if (isArray!Terminator)
                        fromTid.send(thisTid(), 
                                     message(cast(immutable(Unit)[])
                                             buffer[0..$-terminator.length]));
                    else
                        fromTid.send(thisTid(), 
                                     message(cast(immutable(Unit)[])
                                             buffer[0..$-1]));
                }
                bufferValid = false;
            } 
            else 
            {
                // Could not decode an entire line. Save
                // bytes left in data for next call to
                // onReceive. Can be up to a max of 4 bytes.
                enforce(data.length <= 4, 
                        new CurlException("Too many bytes left not decoded " ~ 
                                          to!string(data.length) ~ 
                                          " > 4. Maybe the charset specified in"
                                          " headers does not match "
                                          "the actual content downloaded?"));
                leftOverBytes ~= data;
                break;
            }
        } 
        catch (CurlException ex) 
        {
            prioritySend(fromTid, cast(immutable(CurlException))ex);
            return cast(size_t)0;
        }
    }
    return datalen;
}

// ditto
private static 
void _finalizeAsyncLines(Unit)(bool bufferValid, Unit[] buffer, Tid fromTid) 
{
    if (bufferValid && buffer.length != 0) 
        fromTid.send(thisTid(), message(cast(immutable(Unit)[])buffer[0..$]));
}

            
// Spawn a thread for handling the reading of incoming data in the
// background while the delegate is executing.  This will optimize
// throughput by allowing simultaneous input (this struct) and
// output (e.g. AsyncHttpLineOutputRange).
private static void _spawnAsync(Conn, Unit, Terminator = void)() 
{
    Tid fromTid = receiveOnly!(Tid);
    
    // Get buffer to read into
    Pool!(Unit[]) freeBuffers;  // Free list of buffer objects
	
    // Number of bytes filled into active buffer
    Unit[] buffer;
    bool aborted = false;

    EncodingScheme encodingScheme;
    static if ( !is(Terminator == void))
    {
        // Only lines reading will receive a terminator
        Terminator terminator = receiveOnly!Terminator;
        bool keepTerminator = receiveOnly!bool;

        // max number of bytes to carry over from an onReceive
        // callback. This is 4 because it is the max code units to
        // decode a code point in the supported encodings.
        ubyte[] leftOverBytes =  new ubyte[4];
        leftOverBytes.length = 0;
        bool bufferValid = false;
    } 
    else 
    {
        Unit[] outdata;
    }

    // no move semantic available in std.concurrency ie. must use casting.
    CURL* connDup = cast(CURL*)receiveOnly!(ulong);
    Conn client = Conn();
    client.p.curl.handle = connDup;

    // receive a method for both ftp and http but just use it for http
    Http.Method method = receiveOnly!(Http.Method);
    
    client.onReceive = (ubyte[] data) {

        // If no terminator is specified the chunk size is fixed.
        static if ( is(Terminator == void) )
            return _receiveAsyncChunks(data, outdata, freeBuffers, buffer, 
                                       fromTid, aborted);
        else 
            return _receiveAsyncLines(data, encodingScheme, 
                                      keepTerminator, terminator, leftOverBytes,
                                      bufferValid, freeBuffers, buffer, 
                                      fromTid, aborted);
    };

    static if ( is(Conn == Http) )
    {
        client.method = method;
        // register dummy header handler
        client.onReceiveHeader = (const(char)[] key,const(char)[] value) { 
            if (key == "content-type")
            {
                encodingScheme = EncodingScheme.create(client.p.charset);
            }
        };
    } else {
        encodingScheme = EncodingScheme.create(client.encoding);
    }

    // Start the request
    CURLcode code;
    try 
    {
        code = client._perform(false);
    } 
    catch (Exception ex)
    {
        prioritySend(fromTid, cast(immutable(Exception)) ex);
        fromTid.send(thisTid(), message(true)); // signal done
        return;
    }
    
    if (code != CurlError.ok) 
    {
        if (aborted && (code == CurlError.aborted_by_callback || 
                        code == CurlError.write_error))
        {
            fromTid.send(thisTid(), message(true)); // signal done
            return;
        }
        prioritySend(fromTid, cast(immutable(CurlException)) 
                     new CurlException(client.p.curl.errorString(code)));

        fromTid.send(thisTid(), message(true)); // signal done
        return;
    }

    // Send remaining data that is not a full chunk size
    static if ( is(Terminator == void) ) 
        _finalizeAsyncChunks(outdata, buffer, fromTid);
    else 
        _finalizeAsyncLines(bufferValid, buffer, fromTid);
    
    fromTid.send(thisTid(), message(true)); // signal done
}
            
version (unittest) 
{
  private auto netAllowed() 
  {
      return getenv("PHOBOS_TEST_ALLOW_NET") != null;
  }
}
