module etc.curl;

import etc.c.curl;
import std.conv; // wrapper
import std.string; // wrapper
import std.stdio; // wrapper
import std.regex; // wrapper

pragma(lib, "curl");

/// An exception class for curl
class CurlException: Exception {
  /// Construct a CurlException with given error message.
  this(string msg) { super(msg); }
}

/++
    Wrapper class to provide a better interface to libcurl than using the plain C API

    Copyright: Copyright 2010 - 2011
    License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
    Authors:   Jonas Drewsen and Graham Fawcett
    Source:    $(PHOBOSSRC etc/_curl.d)
+/
class Curl {
  
  CURL* handle;

  this() {
    handle = curl_easy_init();
    CURL* curl = curl_easy_init();
    set(CURLOPT_FILE, cast(void*) this);
    set(CURLOPT_WRITEHEADER, cast(void*) this);
    set(CURLOPT_WRITEFUNCTION, cast(void*) &Curl.writeCallback);
    set(CURLOPT_HEADERFUNCTION, cast(void*) &Curl.headerCallback);
  }

  this(string url) {
    this();
    set(CURLOPT_URL, url);
  }

  ~this() {
    curl_easy_cleanup(this.handle);
  }

  void _check(CURLcode code) {
    if (code != CURLE_OK) {
      throw new Exception(to!string(code));
    }
  }

  void set(CURLoption option, string value) {
    _check(curl_easy_setopt(this.handle, option, toStringz(value)));
  }

  void set(CURLoption option, long value) {
    _check(curl_easy_setopt(this.handle, option, value));
  }

  void set(CURLoption option, void* value) {
    _check(curl_easy_setopt(this.handle, option, value));
  }


  void perform() {
    _check(curl_easy_perform(this.handle));
  }

  void dataReceived(const char[] s) {
    write(s);
  }

  char[] firstLine = null;
  string[string] headers;

  void headerReceived(const char[] s) {
    if (firstLine == null) {
      firstLine = cast(char[]) s;
    } else {
      auto m = match(cast(char[]) s, regex("(.*?): (.*)$"));
      if (!m.empty) {
	headers[to!string(m.captures[1])] = to!string(m.captures[2]);
      }

    }
  }

  extern (C) static size_t writeCallback(const char* str, size_t c, size_t l, void* ptr) {
    Curl b = cast(Curl) ptr;
    b.dataReceived(str[0..c*l]);
    return c*l;
  }

  extern (C) static size_t headerCallback(const char* str, size_t c, size_t l, void* ptr) {
    Curl b = cast(Curl) ptr;
    auto s = str[0..c*l].chomp;
    b.headerReceived(s);
    return c*l;
  }
}



//version(unittest) {

  pragma(msg, "Including main");

  void main(string[] args) {

    auto curl = new Curl("http://www.digitalmars.com");
    curl.perform;
    writefln("\nheaders: %s", curl.headers);
    
  }


  //}
