/* Converted to D from curl headers by htod and 
   cleaned up by Jonas Drewsen (jdrewsen) 
*/
module etc.c.curl;

pragma(lib, "curl");

import core.stdc.time;
import std.socket;

// linux
import core.sys.posix.sys.socket;

//
// LICENSE FROM CURL HEADERS
//

/***************************************************************************
 *                                  _   _ ____  _
 *  Project                     ___| | | |  _ \| |
 *                             / __| | | | |_) | |
 *                            | (__| |_| |  _ <| |___
 *                             \___|\___/|_| \_\_____|
 *
 * Copyright (C) 1998 - 2010, Daniel Stenberg, <daniel@haxx.se>, et al.
 *
 * This software is licensed as described in the file COPYING, which
 * you should have received as part of this distribution. The terms
 * are also available at http://curl.haxx.se/docs/copyright.html.
 *
 * You may opt to use, copy, modify, merge, publish, distribute and/or sell
 * copies of the Software, and permit persons to whom the Software is
 * furnished to do so, under the terms of the COPYING file.
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied.
 *
 ***************************************************************************/

/* This is the version number of the libcurl package from which this header
   file origins: */

/* The numeric version number is also available "in parts" by using these
   defines: */
const LIBCURL_VERSION_MAJOR = 7;
const LIBCURL_VERSION_MINOR = 21;

const LIBCURL_VERSION_PATCH = 4;
/* This is the numeric version of the libcurl version number, meant for easier
   parsing and comparions by programs. The LIBCURL_VERSION_NUM define will
   always follow this syntax:

         0xXXYYZZ

   Where XX, YY and ZZ are the main version, release and patch numbers in
   hexadecimal (using 8 bits each). All three numbers are always represented
   using two digits.  1.2 would appear as "0x010200" while version 9.11.7
   appears as "0x090b07".

   This 6-digit (24 bits) hexadecimal number does not show pre-release number,
   and it is always a greater number in a more recent release. It makes
   comparisons with greater than and less than work.
*/

const LIBCURL_VERSION_NUM = 0x071504;

/*
 * This is the date and time when the full source package was created. The
 * timestamp is not stored in git, as the timestamp is properly set in the
 * tarballs by the maketgz script.
 *
 * The format of the date should follow this template:
 *
 * "Mon Feb 12 11:35:33 UTC 2007"
 */

/* Data type definition of curl_off_t. */

// jdrewsen: Always 64bit and that is what long is in D
alias long curl_off_t; 

alias void CURL;

// jdrewsen: Get socket alias from std.socket
alias socket_t curl_socket_t;

// jdrewsen: Would like to get socket error constant from std.socket by it is private atm.
version(Win32) {
  private import std.c.windows.windows, std.c.windows.winsock;
  const int CURL_SOCKET_BAD = SOCKET_ERROR;
}
version(Posix) const int CURL_SOCKET_BAD = -1;

/* if one field name has more than one
   file, this link should link to following
   files */

/* name is only stored pointer do not free in formfree */
/* contents is only stored pointer do not free in formfree */
/* upload file contents by using the regular read callback to get the
   data and pass the given pointer as custom pointer */

/* The file name to show. If not set, the actual file name will be
   used (if this is a file part) */
/* custom pointer used for HTTPPOST_CALLBACK posts */
struct curl_httppost
{
    curl_httppost *next;
    char *name;
    int namelength;
    char *contents;
    int contentslength;
    char *buffer;
    int bufferlength;
    char *contenttype;
    curl_slist *contentheader;
    curl_httppost *more;
    int flags;
    char *showfilename;
    void *userp;
}

const HTTPPOST_FILENAME    = 1;  /* specified content is a file name */
const HTTPPOST_READFILE    = 2;  /* specified content is a file name */
const HTTPPOST_PTRNAME     = 4;  /* name is only stored pointer
				    do not free in formfree */
const HTTPPOST_PTRCONTENTS = 8;  /* contents is only stored pointer
				    do not free in formfree */
const HTTPPOST_BUFFER      = 16; /* upload file from buffer */
const HTTPPOST_PTRBUFFER   = 32; /* upload file from pointer contents */
const HTTPPOST_CALLBACK    = 64; /* upload file contents by using the
				    regular read callback to get the data
				    and pass the given pointer as custom
				    pointer */


alias int function(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow) curl_progress_callback;

/* Tests have proven that 20K is a very bad buffer size for uploads on
   Windows, while 16K for some odd reason performed a lot better.
   We do the ifndef check to allow this value to easier be changed at build
   time for those who feel adventurous. The practical minimum is about
   400 bytes since libcurl uses a buffer of this size as a scratch area
   (unrelated to network send operations). */
const CURL_MAX_WRITE_SIZE = 16384;

/* The only reason to have a max limit for this is to avoid the risk of a bad
   server feeding libcurl with a never-ending header that will cause reallocs
   infinitely */
const CURL_MAX_HTTP_HEADER = (100*1024);


/* This is a magic return code for the write callback that, when returned,
   will signal libcurl to pause receiving on the current transfer. */
const CURL_WRITEFUNC_PAUSE = 0x10000001;
alias size_t  function(char *buffer, size_t size, size_t nitems, void *outstream)curl_write_callback;

/* enumeration of file types */
enum CurlFileType {
    file,
    directory,
    symlink,
    device_block,
    device_char,
    namedpipe,
    socket,
    door,
    unknown
}
alias int curlfiletype;

const CURLFINFOFLAG_KNOWN_FILENAME    = 1;
const CURLFINFOFLAG_KNOWN_FILETYPE    = 2;
const CURLFINFOFLAG_KNOWN_TIME        = 4;
const CURLFINFOFLAG_KNOWN_PERM        = 8;
const CURLFINFOFLAG_KNOWN_UID         = 16;
const CURLFINFOFLAG_KNOWN_GID         = 32;
const CURLFINFOFLAG_KNOWN_SIZE        = 64;
const CURLFINFOFLAG_KNOWN_HLINKCOUNT  = 128;


/* Content of this structure depends on information which is known and is
   achievable (e.g. by FTP LIST parsing). Please see the url_easy_setopt(3) man
   page for callbacks returning this structure -- some fields are mandatory,
   some others are optional. The FLAG field has special meaning. */

/* If some of these fields is not NULL, it is a pointer to b_data. */
struct _N2
{
    char *time;
    char *perm;
    char *user;
    char *group;
    char *target;
}

/* used internally */
struct curl_fileinfo
{
    char *filename;
    curlfiletype filetype;
    time_t time;
    uint perm;
    int uid;
    int gid;
    curl_off_t size;
    int hardlinks;
    _N2 strings;
    uint flags;
    char *b_data;
    size_t b_size;
    size_t b_used;
}

/* return codes for CURLOPT_CHUNK_BGN_FUNCTION */
const CURL_CHUNK_BGN_FUNC_OK = 0;
const CURL_CHUNK_BGN_FUNC_FAIL = 1;

const CURL_CHUNK_BGN_FUNC_SKIP = 2;
/* if splitting of data transfer is enabled, this callback is called before
   download of an individual chunk started. Note that parameter "remains" works
   only for FTP wildcard downloading (for now), otherwise is not used */
alias int  function(void *transfer_info, void *ptr, int remains)curl_chunk_bgn_callback;

/* return codes for CURLOPT_CHUNK_END_FUNCTION */
const CURL_CHUNK_END_FUNC_OK = 0;

const CURL_CHUNK_END_FUNC_FAIL = 1;
/* If splitting of data transfer is enabled this callback is called after
   download of an individual chunk finished.
   Note! After this callback was set then it have to be called FOR ALL chunks.
   Even if downloading of this chunk was skipped in CHUNK_BGN_FUNC.
   This is the reason why we don't need "transfer_info" parameter in this
   callback and we are not interested in "remains" parameter too. */
alias int  function(void *ptr)curl_chunk_end_callback;

/* return codes for FNMATCHFUNCTION */
const CURL_FNMATCHFUNC_MATCH = 0;
const CURL_FNMATCHFUNC_NOMATCH = 1;
const CURL_FNMATCHFUNC_FAIL = 2;

/* callback type for wildcard downloading pattern matching. If the
   string matches the pattern, return CURL_FNMATCHFUNC_MATCH value, etc. */
alias int  function(void *ptr, char *pattern, char *string)curl_fnmatch_callback;

// seek whence...
enum CurlSeekPos {
  set,
  current,
  end
}

/* These are the return codes for the seek callbacks */
enum CurlSeek {
  ok,
  fail,     /* fail the entire transfer */
  cantseek  /* tell libcurl seeking can't be done, so
	       libcurl might try other means instead */
}
alias int  function(void *instream, curl_off_t offset, int origin)curl_seek_callback;

/* This is a return code for the read callback that, when returned, will
   signal libcurl to immediately abort the current transfer. */
const CURL_READFUNC_ABORT = 0x10000000;

/* This is a return code for the read callback that, when returned,
   will const signal libcurl to pause sending data on the current
   transfer. */
const CURL_READFUNC_PAUSE = 0x10000001;
alias size_t  function(char *buffer, size_t size, size_t nitems, void *instream)curl_read_callback;

enum CurlSockType {
    ipcxn,
    last
}
alias int curlsocktype;

alias int  function(void *clientp, curl_socket_t curlfd, curlsocktype purpose)curl_sockopt_callback;

/* addrlen was a socklen_t type before 7.18.0 but it turned really
   ugly and painful on the systems that lack this type */
struct curl_sockaddr
{
    int family;
    int socktype;
    int protocol;
    uint addrlen;
    sockaddr addr;
}

alias curl_socket_t  function(void *clientp, curlsocktype purpose, curl_sockaddr *address)curl_opensocket_callback;

enum CurlIoError
{
    ok,            /* I/O operation successful */
    unknowncmd,    /* command was unknown to callback */	
    failrestart,   /* failed to restart the read */	
    last	   /* never use */                        
}
alias int curlioerr;

enum CurlIoCmd {
    nop,         /* command was unknown to callback */	
    restartread, /* failed to restart the read */	
    last,	 /* never use */                        
}
alias int curliocmd;

alias curlioerr  function(CURL *handle, int cmd, void *clientp)curl_ioctl_callback;

/*
 * The following typedef's are signatures of malloc, free, realloc, strdup and
 * calloc respectively.  Function pointers of these types can be passed to the
 * curl_global_init_mem() function to set user defined memory management
 * callback routines.
 */
alias void * function(size_t size)curl_malloc_callback;
alias void  function(void *ptr)curl_free_callback;
alias void * function(void *ptr, size_t size)curl_realloc_callback;
alias char * function(char *str)curl_strdup_callback;
alias void * function(size_t nmemb, size_t size)curl_calloc_callback;

/* the kind of data that is passed to information_callback*/
enum CurlCallbackInfo {
    text,
    header_in,
    header_out,
    data_in,
    data_out,
    ssl_data_in,
    ssl_data_out,
    end
}
alias int curl_infotype;

alias int  function(CURL *handle, curl_infotype type, char *data, size_t size, void *userptr)curl_debug_callback;

/* All possible error codes from all sorts of curl functions. Future versions
   may return other values, stay prepared.

   Always add new return codes last. Never *EVER* remove any. The return
   codes must remain the same!
 */
enum CurlError
{
    ok,                           
    unsupported_protocol,        /* 1 */				
    failed_init,		 /* 2 */				
    url_malformat,		 /* 3 */				
    obsolete4,			 /* 4 - NOT USED */			
    couldnt_resolve_proxy,	 /* 5 */				
    couldnt_resolve_host,	 /* 6 */				
    couldnt_connect,		 /* 7 */				
    ftp_weird_server_reply,	 /* 8 */				
    remote_access_denied,	 /* 9 a service was denied by the server
    				    due to lack of access - when login fails
    				    this is not returned. */
    obsolete10,                  /* 10 - NOT USED */			
    ftp_weird_pass_reply,	 /* 11 */				
    obsolete12,			 /* 12 - NOT USED */			
    ftp_weird_pasv_reply,	 /* 13 */				
    ftp_weird_227_format,	 /* 14 */				
    ftp_cant_get_host,		 /* 15 */				
    obsolete16,			 /* 16 - NOT USED */			
    ftp_couldnt_set_type,	 /* 17 */				
    partial_file,		 /* 18 */				
    ftp_couldnt_retr_file,	 /* 19 */				
    obsolete20,			 /* 20 - NOT USED */			
    quote_error,		 /* 21 - quote command failure */	
    http_returned_error,	 /* 22 */				
    write_error,		 /* 23 */				
    obsolete24,			 /* 24 - NOT USED */			
    upload_failed,		 /* 25 - failed upload "command" */	
    read_error,			 /* 26 - couldn't open/read from file */
    out_of_memory,		 /* 27 */                               
    /* Note: CURLE_OUT_OF_MEMORY may sometimes indicate a conversion error
             instead of a memory allocation error if CURL_DOES_CONVERSIONS
             is defined
    */
    operation_timedout,          /* 28 - the timeout time was reached */     
    obsolete29,			 /* 29 - NOT USED */			     
    ftp_port_failed,		 /* 30 - FTP PORT operation failed */	     
    ftp_couldnt_use_rest,	 /* 31 - the REST command failed */	     
    obsolete32,			 /* 32 - NOT USED */			     
    range_error,		 /* 33 - RANGE "command" didn't work */	     
    http_post_error,		 /* 34 */				     
    ssl_connect_error,		 /* 35 - wrong when connecting with SSL */   
    bad_download_resume,	 /* 36 - couldn't resume download */	     
    file_couldnt_read_file,	 /* 37 */				     
    ldap_cannot_bind,		 /* 38 */				     
    ldap_search_failed,		 /* 39 */				     
    obsolete40,			 /* 40 - NOT USED */			     
    function_not_found,		 /* 41 */				     
    aborted_by_callback,	 /* 42 */				     
    bad_function_argument,	 /* 43 */				     
    obsolete44,			 /* 44 - NOT USED */			     
    interface_failed,		 /* 45 - CURLOPT_INTERFACE failed */	     
    obsolete46,			 /* 46 - NOT USED */			     
    too_many_redirects,		 /* 47 - catch endless re-direct loops */    
    unknown_telnet_option,	 /* 48 - User specified an unknown option */ 
    telnet_option_syntax,	 /* 49 - Malformed telnet option */	     
    obsolete50,			 /* 50 - NOT USED */			     
    peer_failed_verification,	 /* 51 - peer's certificate or fingerprint  
				         wasn't verified fine */
    got_nothing,                 /* 52 - when this is a specific error */					
    ssl_engine_notfound,	 /* 53 - SSL crypto engine not found */						
    ssl_engine_setfailed,	 /* 54 - can not set SSL crypto engine as default */				
    send_error,			 /* 55 - failed sending network data */						
    recv_error,			 /* 56 - failure in receiving network data */					
    obsolete57,			 /* 57 - NOT IN USE */								
    ssl_certproblem,		 /* 58 - problem with the local certificate */					
    ssl_cipher,			 /* 59 - couldn't use specified cipher */					
    ssl_cacert,			 /* 60 - problem with the CA cert (path?) */					
    bad_content_encoding,	 /* 61 - Unrecognized transfer encoding */					
    ldap_invalid_url,		 /* 62 - Invalid LDAP URL */							
    filesize_exceeded,		 /* 63 - Maximum file size exceeded */						
    use_ssl_failed,		 /* 64 - Requested FTP SSL level failed */					
    send_fail_rewind,		 /* 65 - Sending the data requires a rewind that failed */			
    ssl_engine_initfailed,	 /* 66 - failed to initialise ENGINE */						
    login_denied,		 /* 67 - user, password or similar was not accepted and we failed to login */	
    tftp_notfound,		 /* 68 - file not found on server */						
    tftp_perm,			 /* 69 - permission problem on server */					
    remote_disk_full,		 /* 70 - out of disk space on server */						
    tftp_illegal,		 /* 71 - Illegal TFTP operation */						
    tftp_unknownid,		 /* 72 - Unknown transfer ID */							
    remote_file_exists,		 /* 73 - File already exists */							
    tftp_nosuchuser,		 /* 74 - No such user */							
    conv_failed,		 /* 75 - conversion failed */							
    conv_reqd,			 /* 76 - caller must register conversion                                        
    				    callbacks using curl_easy_setopt options
    				    CURLOPT_CONV_FROM_NETWORK_FUNCTION,
    				    CURLOPT_CONV_TO_NETWORK_FUNCTION, and
    				    CURLOPT_CONV_FROM_UTF8_FUNCTION */
    ssl_cacert_badfile,          /* 77 - could not load CACERT file, missing  or wrong format */ 
    remote_file_not_found,	 /* 78 - remote file not found */				 
    ssh,			 /* 79 - error from the SSH layer, somewhat                      
    				    generic so the error message will be of
    				    interest when this has happened */
    ssl_shutdown_failed,         /* 80 - Failed to shut down the SSL connection */ 
    again,			 /* 81 - socket is not ready for send/recv,        
    				    wait till it's ready and try again (Added
    				    in 7.18.2) */
    ssl_crl_badfile,             /* 82 - could not load CRL file, missing or wrong format (Added in 7.19.0) */	
    ssl_issuer_error,		 /* 83 - Issuer check failed.  (Added in 7.19.0) */				
    ftp_pret_failed,		 /* 84 - a PRET command failed */						
    rtsp_cseq_error,		 /* 85 - mismatch of RTSP CSeq numbers */					
    rtsp_session_error,		 /* 86 - mismatch of RTSP Session Identifiers */				
    ftp_bad_file_list,		 /* 87 - unable to parse FTP file list */					
    chunk_failed,		 /* 88 - chunk callback reported error */                                       
    curl_last                    /* never use! */
}
alias int CURLcode;

/* This prototype applies to all conversion callbacks */
alias CURLcode  function(char *buffer, size_t length)curl_conv_callback;

/* actually an OpenSSL SSL_CTX */
alias CURLcode  function(CURL *curl, void *ssl_ctx, void *userptr)curl_ssl_ctx_callback;

enum CurlProxy {
    http,       /* added in 7.10, new in 7.19.4 default is to use CONNECT HTTP/1.1 */ 
    http_1_0,	/* added in 7.19.4, force to use CONNECT HTTP/1.0  */		      
    socks4 = 4,	/* support added in 7.15.2, enum existed already in 7.10 */           
    socks5,
    socks4a,
    socks5_hostname   /* Use the SOCKS5 protocol but pass along the
			 host name rather than the IP address. added
			 in 7.18.0 */                                   
}
alias int curl_proxytype;

enum CurlAuth : long {
  none =         0,
  basic =        1,  /* Basic (default) */
  digest =       2,  /* Digest */
  gssnegotiate = 4,  /* GSS-Negotiate */
  ntlm =         8,  /* NTLM */
  digest_ie =    16, /* Digest with IE flavour */
  only =         2147483648, /* used together with a single other
				type to force no auth or just that
				single type */
  any = -17,     // (~CURLAUTH_DIGEST_IE)  /* all fine types set */
  anysafe = -18 // (~(CURLAUTH_BASIC|CURLAUTH_DIGEST_IE))
}


const CURLSSH_AUTH_ANY       = -1;     /* all types supported by the server */
const CURLSSH_AUTH_NONE      = 0;      /* none allowed, silly but complete */
const CURLSSH_AUTH_PUBLICKEY = 1; /* public/private key files */
const CURLSSH_AUTH_PASSWORD  = 2; /* password */
const CURLSSH_AUTH_HOST      = 4; /* host key files */
const CURLSSH_AUTH_KEYBOARD  = 8; /* keyboard interactive */
alias CURLSSH_AUTH_ANY CURLSSH_AUTH_DEFAULT;

const CURL_ERROR_SIZE = 256;
/* points to a zero-terminated string encoded with base64
                      if len is zero, otherwise to the "raw" data */
enum CurlKHType
{
    unknown,
    rsa1,
    rsa,
    dss
}
struct curl_khkey
{
    char *key;
    size_t len;
    CurlKHType keytype;
}

/* this is the set of return values expected from the curl_sshkeycallback
   callback */
/* do not accept it, but we can't answer right now so
   this causes a CURLE_DEFER error but otherwise the
   connection will be left intact etc */
enum CurlKHStat {
    fine_add_to_file,
    fine,
    reject,
    defer,
    last
}

/* this is the set of status codes pass in to the callback */
enum CurlKHMatch {
    ok,
    mismatch,
    missing,
    last
}

alias int  function(CURL *easy, curl_khkey *knownkey, curl_khkey *foundkey, CurlKHMatch m, void *clientp)curl_sshkeycallback;

/* parameter for the CURLOPT_USE_SSL option */
enum CurlUseSSL {
    none,
    tryssl,
    control,
    all,
    last
}
alias int curl_usessl;

/* parameter for the CURLOPT_FTP_SSL_CCC option */
enum CurlFtpSSL {
    ccc_none,
    ccc_passive,
    ccc_active,
    ccc_last
}
alias int curl_ftpccc;

/* parameter for the CURLOPT_FTPSSLAUTH option */
enum CurlFtpAuth {
    defaultauth,
    ssl,
    tls,
    last
}
alias int curl_ftpauth;

/* parameter for the CURLOPT_FTP_CREATE_MISSING_DIRS option */
enum CurlFtp {
    create_dir_none,   /* do NOT create missing dirs! */
    create_dir,        /* (FTP/SFTP) if CWD fails, try MKD and then CWD again if MKD 
    			  succeeded, for SFTP this does similar magic */             
    create_dir_retry,  /* (FTP only) if CWD fails, try MKD and then CWD again even if MKD    
    			  failed! */
    create_dir_last    /* not an option, never use */                                                         
}
alias int curl_ftpcreatedir;

/* parameter for the CURLOPT_FTP_FILEMETHOD option */
enum CurlFtpMethod {
    defaultmethod,    /* let libcurl pick */			  
    multicwd,   /* single CWD operation for each path part */  
    nocwd,      /* no CWD at all */				  
    singlecwd,  /* one CWD to full dir, then work on file */	  
    last	      /* not an option, never use */                 
}
alias int curl_ftpmethod;

/* CURLPROTO_ defines are for the CURLOPT_*PROTOCOLS options */
const CURLPROTO_HTTP   = 1;
const CURLPROTO_HTTPS  = 2;
const CURLPROTO_FTP    = 4;
const CURLPROTO_FTPS   = 8;
const CURLPROTO_SCP    = 16;
const CURLPROTO_SFTP   = 32;
const CURLPROTO_TELNET = 64;
const CURLPROTO_LDAP   = 128;
const CURLPROTO_LDAPS  = 256;
const CURLPROTO_DICT   = 512;
const CURLPROTO_FILE   = 1024;
const CURLPROTO_TFTP   = 2048;
const CURLPROTO_IMAP   = 4096;
const CURLPROTO_IMAPS  = 8192;
const CURLPROTO_POP3   = 16384;
const CURLPROTO_POP3S  = 32768;
const CURLPROTO_SMTP   = 65536;
const CURLPROTO_SMTPS  = 131072;
const CURLPROTO_RTSP   = 262144;
const CURLPROTO_RTMP   = 524288;
const CURLPROTO_RTMPT  = 1048576;
const CURLPROTO_RTMPE  = 2097152;
const CURLPROTO_RTMPTE = 4194304;
const CURLPROTO_RTMPS  = 8388608;
const CURLPROTO_RTMPTS = 16777216;
const CURLPROTO_GOPHER = 33554432;
const CURLPROTO_ALL    = -1; /* enable everything */

/* long may be 32 or 64 bits, but we should never depend on anything else
   but 32 */
const CURLOPTTYPE_LONG = 0;
const CURLOPTTYPE_OBJECTPOINT = 10000;
const CURLOPTTYPE_FUNCTIONPOINT = 20000;

const CURLOPTTYPE_OFF_T = 30000;
/* name is uppercase CURLOPT_<name>,
   type is one of the defined CURLOPTTYPE_<type>
   number is unique identifier */

/* The macro "##" is ISO C, we assume pre-ISO C doesn't support it. */
alias CURLOPTTYPE_LONG LONG;
alias CURLOPTTYPE_OBJECTPOINT OBJECTPOINT;
alias CURLOPTTYPE_FUNCTIONPOINT FUNCTIONPOINT;

alias CURLOPTTYPE_OFF_T OFF_T;

  /* This is the FILE * or void * the regular output should be written to. */

  /* The full URL to get/put */

  /* Port number to connect to, if other than default. */

  /* Name of proxy to use. */

  /* "name:password" to use when fetching. */

  /* "name:password" to use with proxy. */

  /* Range to get, specified as an ASCII string. */

  /* not used */

  /* Specified file stream to upload from (use as input): */

  /* Buffer to receive error messages in, must be at least CURL_ERROR_SIZE
   * bytes big. If this is not used, error messages go to stderr instead: */

  /* Function that will be called to store the output (instead of fwrite). The
   * parameters will use fwrite() syntax, make sure to follow them. */

  /* Function that will be called to read the input (instead of fread). The
   * parameters will use fread() syntax, make sure to follow them. */

  /* Time-out the read operation after this amount of seconds */

  /* If the CURLOPT_INFILE is used, this can be used to inform libcurl about
   * how large the file being sent really is. That allows better error
   * checking and better verifies that the upload was successful. -1 means
   * unknown size.
   *
   * For large file support, there is also a _LARGE version of the key
   * which takes an off_t type, allowing platforms with larger off_t
   * sizes to handle larger files.  See below for INFILESIZE_LARGE.
   */

  /* POST static input fields. */

  /* Set the referrer page (needed by some CGIs) */

  /* Set the FTP PORT string (interface name, named or numerical IP address)
     Use i.e '-' to use default address. */

  /* Set the User-Agent string (examined by some CGIs) */

  /* If the download receives less than "low speed limit" bytes/second
   * during "low speed time" seconds, the operations is aborted.
   * You could i.e if you have a pretty high speed connection, abort if
   * it is less than 2000 bytes/sec during 20 seconds.
   */

  /* Set the "low speed limit" */

  /* Set the "low speed time" */

  /* Set the continuation offset.
   *
   * Note there is also a _LARGE version of this key which uses
   * off_t types, allowing for large file offsets on platforms which
   * use larger-than-32-bit off_t's.  Look below for RESUME_FROM_LARGE.
   */

  /* Set cookie in request: */

  /* This points to a linked list of headers, struct curl_slist kind */

  /* This points to a linked list of post entries, struct curl_httppost */

  /* name of the file keeping your private SSL-certificate */

  /* password for the SSL or SSH private key */

  /* send TYPE parameter? */

  /* send linked-list of QUOTE commands */

  /* send FILE * or void * to store headers to, if you use a callback it
     is simply passed to the callback unmodified */

  /* point to a file to read the initial cookies from, also enables
     "cookie awareness" */

  /* What version to specifically try to use.
     See CURL_SSLVERSION defines below. */

  /* What kind of HTTP time condition to use, see defines */

  /* Time to use with the above condition. Specified in number of seconds
     since 1 Jan 1970 */

  /* 35 = OBSOLETE */

  /* Custom request, for customizing the get command like
     HTTP: DELETE, TRACE and others
     FTP: to use a different list command
     */

  /* HTTP request, for odd commands like DELETE, TRACE and others */

  /* 38 is not used */

  /* send linked-list of post-transfer QUOTE commands */

  /* Pass a pointer to string of the output using full variable-replacement
     as described elsewhere. */



  /* Specify whether to read the user+password from the .netrc or the URL.
   * This must be one of the CURL_NETRC_* enums below. */



  /* 55 = OBSOLETE */

  /* Function that will be called instead of the internal progress display
   * function. This function should be defined as the curl_progress_callback
   * prototype defines. */

  /* Data passed to the progress callback */

  /* We want the referrer field set automatically when following locations */

  /* Port of the proxy, can be set in the proxy string as well with:
     "[host]:[port]" */

  /* size of the POST input data, if strlen() is not good to use */

  /* tunnel non-http operations through a HTTP proxy */

  /* Set the interface string to use as outgoing network interface */

  /* Set the krb4/5 security level, this also enables krb4/5 awareness.  This
   * is a string, 'clear', 'safe', 'confidential' or 'private'.  If the string
   * is set but doesn't match one of these, 'private' will be used.  */

  /* Set if we should verify the peer in ssl handshake, set 1 to verify. */

  /* The CApath or CAfile used to validate the peer certificate
     this option is used only if SSL_VERIFYPEER is true */

  /* 66 = OBSOLETE */
  /* 67 = OBSOLETE */

  /* Maximum number of http redirects to follow */

  /* Pass a long set to 1 to get the date of the requested document (if
     possible)! Pass a zero to shut it off. */

  /* This points to a linked list of telnet options */

  /* Max amount of cached alive connections */

  /* What policy to use when closing connections when the cache is filled
     up */

  /* 73 = OBSOLETE */

  /* Set to explicitly use a new connection for the upcoming transfer.
     Do not use this unless you're absolutely sure of this, as it makes the
     operation slower and is less friendly for the network. */

  /* Set to explicitly forbid the upcoming transfer's connection to be re-used
     when done. Do not use this unless you're absolutely sure of this, as it
     makes the operation slower and is less friendly for the network. */

  /* Set to a file name that contains random data for libcurl to use to
     seed the random engine when doing SSL connects. */

  /* Set to the Entropy Gathering Daemon socket pathname */

  /* Time-out connect operations after this amount of seconds, if connects
     are OK within this time, then fine... This only aborts the connect
     phase. [Only works on unix-style/SIGALRM operating systems] */

  /* Function that will be called to store headers (instead of fwrite). The
   * parameters will use fwrite() syntax, make sure to follow them. */

  /* Set this to force the HTTP request to get back to GET. Only really usable
     if POST, PUT or a custom request have been used first.
   */

  /* Set if we should verify the Common name from the peer certificate in ssl
   * handshake, set 1 to check existence, 2 to ensure that it matches the
   * provided hostname. */

  /* Specify which file name to write all known cookies in after completed
     operation. Set file name to "-" (dash) to make it go to stdout. */

  /* Specify which SSL ciphers to use */

  /* Specify which HTTP version to use! This must be set to one of the
     CURL_HTTP_VERSION* enums set below. */

  /* Specifically switch on or off the FTP engine's use of the EPSV command. By
     default, that one will always be attempted before the more traditional
     PASV command. */

  /* type of the file keeping your SSL-certificate ("DER", "PEM", "ENG") */

  /* name of the file keeping your private SSL-key */

  /* type of the file keeping your private SSL-key ("DER", "PEM", "ENG") */

  /* crypto engine for the SSL-sub system */

  /* set the crypto engine for the SSL-sub system as default
     the param has no meaning...
   */

  /* Non-zero value means to use the global dns cache */

  /* DNS cache timeout */

  /* send linked-list of pre-transfer QUOTE commands */

  /* set the debug function */

  /* set the data for the debug function */

  /* mark this as start of a cookie session */

  /* The CApath directory used to validate the peer certificate
     this option is used only if SSL_VERIFYPEER is true */

  /* Instruct libcurl to use a smaller receive buffer */

  /* Instruct libcurl to not use any signal/alarm handlers, even when using
     timeouts. This option is useful for multi-threaded applications.
     See libcurl-the-guide for more background information. */

  /* Provide a CURLShare for mutexing non-ts data */

  /* indicates type of proxy. accepted values are CURLPROXY_HTTP (default),
     CURLPROXY_SOCKS4, CURLPROXY_SOCKS4A and CURLPROXY_SOCKS5. */

  /* Set the Accept-Encoding string. Use this to tell a server you would like
     the response to be compressed. */

  /* Set pointer to private data */

  /* Set aliases for HTTP 200 in the HTTP Response header */

  /* Continue to send authentication (user+password) when following locations,
     even when hostname changed. This can potentially send off the name
     and password to whatever host the server decides. */

  /* Specifically switch on or off the FTP engine's use of the EPRT command ( it
     also disables the LPRT attempt). By default, those ones will always be
     attempted before the good old traditional PORT command. */

  /* Set this to a bitmask value to enable the particular authentications
     methods you like. Use this in combination with CURLOPT_USERPWD.
     Note that setting multiple bits may cause extra network round-trips. */

  /* Set the ssl context callback function, currently only for OpenSSL ssl_ctx
     in second argument. The function must be matching the
     curl_ssl_ctx_callback proto. */

  /* Set the userdata for the ssl context callback function's third
     argument */

  /* FTP Option that causes missing dirs to be created on the remote server.
     In 7.19.4 we introduced the convenience enums for this option using the
     CURLFTP_CREATE_DIR prefix.
  */

  /* Set this to a bitmask value to enable the particular authentications
     methods you like. Use this in combination with CURLOPT_PROXYUSERPWD.
     Note that setting multiple bits may cause extra network round-trips. */

  /* FTP option that changes the timeout, in seconds, associated with
     getting a response.  This is different from transfer timeout time and
     essentially places a demand on the FTP server to acknowledge commands
     in a timely manner. */

// alias CURLOPT_FTP_RESPONSE_TIMEOUT CURLOPT_SERVER_RESPONSE_TIMEOUT;
  /* Set this option to one of the CURL_IPRESOLVE_* defines (see below) to
     tell libcurl to resolve names to those IP versions only. This only has
     affect on systems with support for more than one, i.e IPv4 _and_ IPv6. */

  /* Set this option to limit the size of a file that will be downloaded from
     an HTTP or FTP server.

     Note there is also _LARGE version which adds large file support for
     platforms which have larger off_t sizes.  See MAXFILESIZE_LARGE below. */

  /* See the comment for INFILESIZE above, but in short, specifies
   * the size of the file being uploaded.  -1 means unknown.
   */

  /* Sets the continuation offset.  There is also a LONG version of this;
   * look above for RESUME_FROM.
   */

  /* Sets the maximum size of data that will be downloaded from
   * an HTTP or FTP server.  See MAXFILESIZE above for the LONG version.
   */

  /* Set this option to the file name of your .netrc file you want libcurl
     to parse (using the CURLOPT_NETRC option). If not set, libcurl will do
     a poor attempt to find the user's home directory and check for a .netrc
     file in there. */

  /* Enable SSL/TLS for FTP, pick one of:
     CURLFTPSSL_TRY     - try using SSL, proceed anyway otherwise
     CURLFTPSSL_CONTROL - SSL for the control connection or fail
     CURLFTPSSL_ALL     - SSL for all communication or fail
  */

  /* The _LARGE version of the standard POSTFIELDSIZE option */

  /* Enable/disable the TCP Nagle algorithm */

  /* 122 OBSOLETE, used in 7.12.3. Gone in 7.13.0 */
  /* 123 OBSOLETE. Gone in 7.16.0 */
  /* 124 OBSOLETE, used in 7.12.3. Gone in 7.13.0 */
  /* 125 OBSOLETE, used in 7.12.3. Gone in 7.13.0 */
  /* 126 OBSOLETE, used in 7.12.3. Gone in 7.13.0 */
  /* 127 OBSOLETE. Gone in 7.16.0 */
  /* 128 OBSOLETE. Gone in 7.16.0 */

  /* When FTP over SSL/TLS is selected (with CURLOPT_USE_SSL), this option
     can be used to change libcurl's default action which is to first try
     "AUTH SSL" and then "AUTH TLS" in this order, and proceed when a OK
     response has been received.

     Available parameters are:
     CURLFTPAUTH_DEFAULT - let libcurl decide
     CURLFTPAUTH_SSL     - try "AUTH SSL" first, then TLS
     CURLFTPAUTH_TLS     - try "AUTH TLS" first, then SSL
  */


  /* 132 OBSOLETE. Gone in 7.16.0 */
  /* 133 OBSOLETE. Gone in 7.16.0 */

  /* zero terminated string for pass on to the FTP server when asked for
     "account" info */

  /* feed cookies into cookie engine */

  /* ignore Content-Length */

  /* Set to non-zero to skip the IP address received in a 227 PASV FTP server
     response. Typically used for FTP-SSL purposes but is not restricted to
     that. libcurl will then instead use the same IP address it used for the
     control connection. */

  /* Select "file method" to use when doing FTP, see the curl_ftpmethod
     above. */

  /* Local port number to bind the socket to */

  /* Number of ports to try, including the first one set with LOCALPORT.
     Thus, setting it to 1 will make no additional attempts but the first.
  */

  /* no transfer, set up connection and let application use the socket by
     extracting it with CURLINFO_LASTSOCKET */

  /* Function that will be called to convert from the
     network encoding (instead of using the iconv calls in libcurl) */

  /* Function that will be called to convert to the
     network encoding (instead of using the iconv calls in libcurl) */

  /* Function that will be called to convert from UTF8
     (instead of using the iconv calls in libcurl)
     Note that this is used only for SSL certificate processing */

  /* if the connection proceeds too quickly then need to slow it down */
  /* limit-rate: maximum number of bytes per second to send or receive */

  /* Pointer to command string to send if USER/PASS fails. */

  /* callback function for setting socket options */

  /* set to 0 to disable session ID re-use for this transfer, default is
     enabled (== 1) */

  /* allowed SSH authentication methods */

  /* Used by scp/sftp to do public/private key authentication */

  /* Send CCC (Clear Command Channel) after authentication */

  /* Same as TIMEOUT and CONNECTTIMEOUT, but with ms resolution */

  /* set to zero to disable the libcurl's decoding and thus pass the raw body
     data to the application even when it is encoded/compressed */

  /* Permission used when creating new files and directories on the remote
     server for protocols that support it, SFTP/SCP/FILE */

  /* Set the behaviour of POST when redirecting. Values must be set to one
     of CURL_REDIR* defines below. This used to be called CURLOPT_POST301 */

  /* used by scp/sftp to verify the host's public key */

  /* Callback function for opening socket (instead of socket(2)). Optionally,
     callback is able change the address or refuse to connect returning
     CURL_SOCKET_BAD.  The callback should have type
     curl_opensocket_callback */

  /* POST volatile input fields. */

  /* set transfer mode (;type=<a|i>) when doing FTP via an HTTP proxy */

  /* Callback function for seeking in the input stream */

  /* CRL file */

  /* Issuer certificate */

  /* (IPv6) Address scope */

  /* Collect certificate chain info and allow it to get retrievable with
     CURLINFO_CERTINFO after the transfer is complete. (Unfortunately) only
     working with OpenSSL-powered builds. */

  /* "name" and "pwd" to use when fetching. */

    /* "name" and "pwd" to use with Proxy when fetching. */

  /* Comma separated list of hostnames defining no-proxy zones. These should
     match both hostnames directly, and hostnames within a domain. For
     example, local.com will match local.com and www.local.com, but NOT
     notlocal.com or www.notlocal.com. For compatibility with other
     implementations of this, .local.com will be considered to be the same as
     local.com. A single * is the only valid wildcard, and effectively
     disables the use of proxy. */

  /* block size for TFTP transfers */

  /* Socks Service */

  /* Socks Service */

  /* set the bitmask for the protocols that are allowed to be used for the
     transfer, which thus helps the app which takes URLs from users or other
     external inputs and want to restrict what protocol(s) to deal
     with. Defaults to CURLPROTO_ALL. */

  /* set the bitmask for the protocols that libcurl is allowed to follow to,
     as a subset of the CURLOPT_PROTOCOLS ones. That means the protocol needs
     to be set in both bitmasks to be allowed to get redirected to. Defaults
     to all protocols except FILE and SCP. */

  /* set the SSH knownhost file name to use */

  /* set the SSH host key callback, must point to a curl_sshkeycallback
     function */

  /* set the SSH host key callback custom pointer */

  /* set the SMTP mail originator */

  /* set the SMTP mail receiver(s) */

  /* FTP: send PRET before PASV */

  /* RTSP request method (OPTIONS, SETUP, PLAY, etc...) */

  /* The RTSP session identifier */

  /* The RTSP stream URI */

  /* The Transport: header to use in RTSP requests */

  /* Manually initialize the client RTSP CSeq for this handle */

  /* Manually initialize the server RTSP CSeq for this handle */

  /* The stream to pass to INTERLEAVEFUNCTION. */

  /* Let the application define a custom write method for RTP data */

  /* Turn on wildcard matching */

  /* Directory matching callback called before downloading of an
     individual file (chunk) started */

  /* Directory matching callback called after the file (chunk)
     was downloaded, or skipped */

  /* Change match (fnmatch-like) callback for wildcard matching */

  /* Let the application define custom chunk data pointer */

  /* FNMATCH_FUNCTION user pointer */

  /* send linked-list of name:port:address sets */

  /* Set a username for authenticated TLS */

  /* Set a password for authenticated TLS */

  /* Set authentication type for authenticated TLS */

enum CurlOption {
    file = 10001,
    url,
    port = 3,
    proxy = 10004,
    userpwd,
    proxyuserpwd,
    range,
    infile = 10009,
    errorbuffer,
    writefunction = 20011,
    readfunction,
    timeout = 13,
    infilesize,
    postfields = 10015,
    referer,
    ftpport,
    useragent,
    low_speed_limit = 19,
    low_speed_time,
    resume_from,
    cookie = 10022,
    httpheader,
    httppost,
    sslcert,
    keypasswd,
    crlf = 27,
    quote = 10028,
    writeheader,
    cookiefile = 10031,
    sslversion = 32,
    timecondition,
    timevalue,
    customrequest = 10036,
    stderr,
    postquote = 10039,
    writeinfo,
    verbose = 41,
    header,
    noprogress,
    nobody,
    failonerror,
    upload,
    post,
    dirlistonly,
    append = 50,
    netrc,
    followlocation,
    transfertext,
    put,
    progressfunction = 20056,
    progressdata = 10057,
    autoreferer = 58,
    proxyport,
    postfieldsize,
    httpproxytunnel,
    intrface = 10062,
    krblevel,
    ssl_verifypeer = 64,
    cainfo = 10065,
    maxredirs = 68,
    filetime,
    telnetoptions = 10070,
    maxconnects = 71,
    closepolicy,
    fresh_connect = 74,
    forbid_reuse,
    random_file = 10076,
    egdsocket,
    connecttimeout = 78,
    headerfunction = 20079,
    httpget = 80,
    ssl_verifyhost,
    cookiejar = 10082,
    ssl_cipher_list,
    http_version = 84,
    ftp_use_epsv,
    sslcerttype = 10086,
    sslkey,
    sslkeytype,
    sslengine,
    sslengine_default = 90,
    dns_use_global_cache,
    dns_cache_timeout,
    prequote = 10093,
    debugfunction = 20094,
    debugdata = 10095,
    cookiesession = 96,
    capath = 10097,
    buffersize = 98,
    nosignal,
    share = 10100,
    proxytype = 101,
    encoding = 10102,
    private_opt,
    http200aliases,
    unrestricted_auth = 105,
    ftp_use_eprt,
    httpauth,
    ssl_ctx_function = 20108,
    ssl_ctx_data = 10109,
    ftp_create_missing_dirs = 110,
    proxyauth,
    ftp_response_timeout,
    ipresolve,
    maxfilesize,
    infilesize_large = 30115,
    resume_from_large,
    maxfilesize_large,
    netrc_file = 10118,
    use_ssl = 119,
    postfieldsize_large = 30120,
    tcp_nodelay = 121,
    ftpsslauth = 129,
    ioctlfunction = 20130,
    ioctldata = 10131,
    ftp_account = 10134,
    cookielist,
    ignore_content_length = 136,
    ftp_skip_pasv_ip,
    ftp_filemethod,
    localport,
    localportrange,
    connect_only,
    conv_from_network_function = 20142,
    conv_to_network_function,
    conv_from_utf8_function,
    max_send_speed_large = 30145,
    max_recv_speed_large,
    ftp_alternative_to_user = 10147,
    sockoptfunction = 20148,
    sockoptdata = 10149,
    ssl_sessionid_cache = 150,
    ssh_auth_types,
    ssh_public_keyfile = 10152,
    ssh_private_keyfile,
    ftp_ssl_ccc = 154,
    timeout_ms,
    connecttimeout_ms,
    http_transfer_decoding,
    http_content_decoding,
    new_file_perms,
    new_directory_perms,
    postredir,
    ssh_host_public_key_md5 = 10162,
    opensocketfunction = 20163,
    opensocketdata = 10164,
    copypostfields,
    proxy_transfer_mode = 166,
    seekfunction = 20167,
    seekdata = 10168,
    crlfile,
    issuercert,
    address_scope = 171,
    certinfo,
    username = 10173,
    password,
    proxyusername,
    proxypassword,
    noproxy,
    tftp_blksize = 178,
    socks5_gssapi_service = 10179,
    socks5_gssapi_nec = 180,
    protocols,
    redir_protocols,
    ssh_knownhosts = 10183,
    ssh_keyfunction = 20184,
    ssh_keydata = 10185,
    mail_from,
    mail_rcpt,
    ftp_use_pret = 188,
    rtsp_request,
    rtsp_session_id = 10190,
    rtsp_stream_uri,
    rtsp_transport,
    rtsp_client_cseq = 193,
    rtsp_server_cseq,
    interleavedata = 10195,
    interleavefunction = 20196,
    wildcardmatch = 197,
    chunk_bgn_function = 20198,
    chunk_end_function,
    fnmatch_function,
    chunk_data = 10201,
    fnmatch_data,
    resolve,
    tlsauth_username,
    tlsauth_password,
    tlsauth_type,
    lastentry
}
alias int CURLoption;
const CURLOPT_SERVER_RESPONSE_TIMEOUT = CurlOption.ftp_response_timeout;

/* Below here follows defines for the CURLOPT_IPRESOLVE option. If a host
   name resolves addresses using more than one IP protocol version, this
   option might be handy to force libcurl to use a specific IP version. */
const CURL_IPRESOLVE_WHATEVER = 0; /* default, resolves addresses to all IP versions that your system allows */
const CURL_IPRESOLVE_V4 = 1;
const CURL_IPRESOLVE_V6 = 2;

  /* three convenient "aliases" that follow the name scheme better */
const CURLOPT_WRITEDATA = CurlOption.file;
const CURLOPT_READDATA = CurlOption.infile;
const CURLOPT_HEADERDATA = CurlOption.writeheader;
const CURLOPT_RTSPHEADER = CurlOption.httpheader;

/* These enums are for use with the CURLOPT_HTTP_VERSION option. */
enum CurlHttpVersion {
    none, /* setting this means we don't care, and that we'd
	     like the library to choose the best possible
	     for us! */
    v1_0,
    v1_1,
    last /* *ILLEGAL* http version */
}

/*
 * Public API enums for RTSP requests
 */
enum CurlRtspReq {
    none,
    options,
    describe,
    announce,
    setup,
    play,
    pause,
    teardown,
    get_parameter,
    set_parameter,
    record,
    receive,
    last
}

 /* These enums are for use with the CURLOPT_NETRC option. */
enum CurlNetRcOption {
    ignored,  /* The .netrc will never be read. This is the default. */		
    optional  /* A user:password in the URL will be preferred to one in the .netrc. */,
    required, /* A user:password in the URL will be ignored.
	       * Unless one is set programmatically, the .netrc
	       * will be queried. */
    last
}

enum CurlSslVersion {
    default_version,
    tlsv1,
    sslv2,
    sslv3,
    last /* never use */
}

enum CurlTlsAuth {
    none,
    srp,
    last /* never use */
}

/* symbols to use with CURLOPT_POSTREDIR.
   CURL_REDIR_POST_301 and CURL_REDIR_POST_302 can be bitwise ORed so that
   CURL_REDIR_POST_301 | CURL_REDIR_POST_302 == CURL_REDIR_POST_ALL */
const CURL_REDIR_GET_ALL = 0;
const CURL_REDIR_POST_301 = 1;
const CURL_REDIR_POST_302 = 2;
const CURL_REDIR_POST_ALL = (CURL_REDIR_POST_301|CURL_REDIR_POST_302);

enum CurlTimeCond {
    none,
    ifmodsince,
    ifunmodsince,
    lastmod,
    last
}
alias int curl_TimeCond;


/* curl_strequal() and curl_strnequal() are subject for removal in a future
   libcurl, see lib/README.curlx for details */
extern (C) { 
int  curl_strequal(char *s1, char *s2);
int  curl_strnequal(char *s1, char *s2, size_t n);
}
enum CurlForm {
    nothing,
    copyname,
    ptrname,
    namelength,
    copycontents,
    ptrcontents,
    contentslength,
    filecontent,
    array,
    obsolete,
    file,
    buffer,
    bufferptr,
    bufferlength,
    contenttype,
    contentheader,
    filename,
    end,
    obsolete2,
    stream,
    lastentry,
}
alias int CURLformoption;


/* structure to be used as parameter for CURLFORM_ARRAY */
struct curl_forms
{
    CURLformoption option;
    char *value;
}

/* use this for multipart formpost building */
/* Returns code for curl_formadd()
 *
 * Returns:
 * CURL_FORMADD_OK             on success
 * CURL_FORMADD_MEMORY         if the FormInfo allocation fails
 * CURL_FORMADD_OPTION_TWICE   if one option is given twice for one Form
 * CURL_FORMADD_NULL           if a null pointer was given for a char
 * CURL_FORMADD_MEMORY         if the allocation of a FormInfo struct failed
 * CURL_FORMADD_UNKNOWN_OPTION if an unknown option was used
 * CURL_FORMADD_INCOMPLETE     if the some FormInfo is not complete (or error)
 * CURL_FORMADD_MEMORY         if a curl_httppost struct cannot be allocated
 * CURL_FORMADD_MEMORY         if some allocation for string copying failed.
 * CURL_FORMADD_ILLEGAL_ARRAY  if an illegal option is used in an array
 *
 ***************************************************************************/
enum CurlFormAdd {
    ok,
    memory,
    option_twice,
    null_ptr,
    unknown_option,
    incomplete,
    illegal_array,
    disabled,
    last
}
alias int CURLFORMcode;

extern (C) { 

/*
 * NAME curl_formadd()
 *
 * DESCRIPTION
 *
 * Pretty advanced function for building multi-part formposts. Each invoke
 * adds one part that together construct a full post. Then use
 * CURLOPT_HTTPPOST to send it off to libcurl.
 */
CURLFORMcode  curl_formadd(curl_httppost **httppost, curl_httppost **last_post,...);

/*
 * callback function for curl_formget()
 * The void *arg pointer will be the one passed as second argument to
 *   curl_formget().
 * The character buffer passed to it must not be freed.
 * Should return the buffer length passed to it as the argument "len" on
 *   success.
 */
alias size_t  function(void *arg, char *buf, size_t len)curl_formget_callback;

/*
 * NAME curl_formget()
 *
 * DESCRIPTION
 *
 * Serialize a curl_httppost struct built with curl_formadd().
 * Accepts a void pointer as second argument which will be passed to
 * the curl_formget_callback function.
 * Returns 0 on success.
 */
int  curl_formget(curl_httppost *form, void *arg, curl_formget_callback append);
/*
 * NAME curl_formfree()
 *
 * DESCRIPTION
 *
 * Free a multipart formpost previously built with curl_formadd().
 */
void  curl_formfree(curl_httppost *form);

/*
 * NAME curl_getenv()
 *
 * DESCRIPTION
 *
 * Returns a malloc()'ed string that MUST be curl_free()ed after usage is
 * complete. DEPRECATED - see lib/README.curlx
 */
char * curl_getenv(char *variable);

/*
 * NAME curl_version()
 *
 * DESCRIPTION
 *
 * Returns a static ascii string of the libcurl version.
 */
char * curl_version();

/*
 * NAME curl_easy_escape()
 *
 * DESCRIPTION
 *
 * Escapes URL strings (converts all letters consider illegal in URLs to their
 * %XX versions). This function returns a new allocated string or NULL if an
 * error occurred.
 */
char * curl_easy_escape(CURL *handle, char *string, int length);

/* the previous version: */
char * curl_escape(char *string, int length);


/*
 * NAME curl_easy_unescape()
 *
 * DESCRIPTION
 *
 * Unescapes URL encoding in strings (converts all %XX codes to their 8bit
 * versions). This function returns a new allocated string or NULL if an error
 * occurred.
 * Conversion Note: On non-ASCII platforms the ASCII %XX codes are
 * converted into the host encoding.
 */
char * curl_easy_unescape(CURL *handle, char *string, int length, int *outlength);

/* the previous version */
char * curl_unescape(char *string, int length);

/*
 * NAME curl_free()
 *
 * DESCRIPTION
 *
 * Provided for de-allocation in the same translation unit that did the
 * allocation. Added in libcurl 7.10
 */
void  curl_free(void *p);

/*
 * NAME curl_global_init()
 *
 * DESCRIPTION
 *
 * curl_global_init() should be invoked exactly once for each application that
 * uses libcurl and before any call of other libcurl functions.
 *
 * This function is not thread-safe!
 */
CURLcode  curl_global_init(int flags);

/*
 * NAME curl_global_init_mem()
 *
 * DESCRIPTION
 *
 * curl_global_init() or curl_global_init_mem() should be invoked exactly once
 * for each application that uses libcurl.  This function can be used to
 * initialize libcurl and set user defined memory management callback
 * functions.  Users can implement memory management routines to check for
 * memory leaks, check for mis-use of the curl library etc.  User registered
 * callback routines with be invoked by this library instead of the system
 * memory management routines like malloc, free etc.
 */
CURLcode  curl_global_init_mem(int flags, curl_malloc_callback m, curl_free_callback f, curl_realloc_callback r, curl_strdup_callback s, curl_calloc_callback c);

/*
 * NAME curl_global_cleanup()
 *
 * DESCRIPTION
 *
 * curl_global_cleanup() should be invoked exactly once for each application
 * that uses libcurl
 */
void  curl_global_cleanup();
}

/* linked-list structure for the CURLOPT_QUOTE option (and other) */
struct curl_slist
{
    char *data;
    curl_slist *next;
}

extern (C) { 
/*
 * NAME curl_slist_append()
 *
 * DESCRIPTION
 *
 * Appends a string to a linked list. If no list exists, it will be created
 * first. Returns the new list, after appending.
 */
curl_slist * curl_slist_append(curl_slist *, char *);

/*
 * NAME curl_slist_free_all()
 *
 * DESCRIPTION
 *
 * free a previously built curl_slist.
 */
void  curl_slist_free_all(curl_slist *);

/*
 * NAME curl_getdate()
 *
 * DESCRIPTION
 *
 * Returns the time, in seconds since 1 Jan 1970 of the time string given in
 * the first argument. The time argument in the second parameter is unused
 * and should be set to NULL.
 */
time_t  curl_getdate(char *p, time_t *unused);
}

/* info about the certificate chain, only for OpenSSL builds. Asked
   for with CURLOPT_CERTINFO / CURLINFO_CERTINFO */
struct curl_certinfo
{
    int num_of_certs;      /* number of certificates with information */
    curl_slist **certinfo; /* for each index in this array, there's a
			      linked list with textual information in the
			      format "name: value" */
}

const CURLINFO_STRING = 0x100000;
const CURLINFO_LONG = 0x200000;
const CURLINFO_DOUBLE = 0x300000;
const CURLINFO_SLIST = 0x400000;
const CURLINFO_MASK = 0x0fffff;

const CURLINFO_TYPEMASK = 0xf00000;

enum CurlInfo {
    none, 
    effective_url = 1048577,
    response_code = 2097154,
    total_time = 3145731,
    namelookup_time,
    connect_time,
    pretransfer_time,
    size_upload,
    size_download,
    speed_download,
    speed_upload,
    header_size = 2097163,
    request_size,
    ssl_verifyresult,
    filetime,
    content_length_download = 3145743,
    content_length_upload,
    starttransfer_time,
    content_type = 1048594,
    redirect_time = 3145747,
    redirect_count = 2097172,
    private_info = 1048597,
    http_connectcode = 2097174,
    httpauth_avail,
    proxyauth_avail,
    os_errno,
    num_connects,
    ssl_engines = 4194331,
    cookielist,
    lastsocket = 2097181,
    ftp_entry_path = 1048606,
    redirect_url,
    primary_ip,
    appconnect_time = 3145761,
    certinfo = 4194338,
    condition_unmet = 2097187,
    rtsp_session_id = 1048612,
    rtsp_client_cseq = 2097189,
    rtsp_server_cseq,
    rtsp_cseq_recv,
    primary_port,
    local_ip = 1048617,
    local_port = 2097194,
    /* Fill in new entries below here! */
    lastone = 42
}
alias int CURLINFO;

/* CURLINFO_RESPONSE_CODE is the new name for the option previously known as
   CURLINFO_HTTP_CODE */
const CURLINFO_HTTP_CODE = CurlInfo.response_code; 


enum CurlClosePolicy {
    none,
    oldest,
    least_recently_used,
    least_traffic,
    slowest,
    callback,
    last
}
alias int curl_closepolicy;

const CURL_GLOBAL_SSL = 1;
const CURL_GLOBAL_WIN32 = 2;
const CURL_GLOBAL_ALL = (CURL_GLOBAL_SSL|CURL_GLOBAL_WIN32);
const CURL_GLOBAL_NOTHING = 0;
alias CURL_GLOBAL_ALL CURL_GLOBAL_DEFAULT;

/*****************************************************************************
 * Setup defines, protos etc for the sharing stuff.
 */

/* Different data locks for a single share */
  /*  CURL_LOCK_DATA_SHARE is used internally to say that
   *  the locking is just made to change the internal state of the share
   *  itself.
   */
enum CurlLockData {
    none,
    share,
    cookie,
    dns,
    ssl_session,
    connect,
    last
}
alias int curl_lock_data;

/* Different lock access types */
enum CurlLockAccess {
    none,
    shared_access,
    single,
    last
}
alias int curl_lock_access;

alias void  function(CURL *handle, curl_lock_data data, curl_lock_access locktype, void *userptr)curl_lock_function;
alias void  function(CURL *handle, curl_lock_data data, void *userptr)curl_unlock_function;

alias void CURLSH;

enum CurlShError {
    ok,
    bad_option,
    in_use,
    invalid,
    nomem,
    last
}
alias int CURLSHcode;

/* pass in a user data pointer used in the lock/unlock callback
   functions */
enum CurlShOption {
    none,
    share,
    unshare,
    lockfunc,
    unlockfunc,
    userdata,
    last
}
alias int CURLSHoption;

extern (C) { 
CURLSH * curl_share_init();
CURLSHcode  curl_share_setopt(CURLSH *, CURLSHoption option,...);
CURLSHcode  curl_share_cleanup(CURLSH *);
}

/****************************************************************************
 * Structures for querying information about the curl library at runtime.
 */

enum CurlVersion {
    first,
    second,
    third,
    fourth,
    last
}
alias int CURLversion;

/* The 'CURLVERSION_NOW' is the symbolic name meant to be used by
   basically all programs ever that want to get version information. It is
   meant to be a built-in version number for what kind of struct the caller
   expects. If the struct ever changes, we redefine the NOW to another enum
   from above. */
const CURLVERSION_NOW = CurlVersion.fourth; 

struct _N28
{
  CURLversion age;
  char *version_;
  uint version_num;
  char *host;
  int features;
  char *ssl_version;
  int ssl_version_num;
  char *libz_version;
  /* protocols is terminated by an entry with a NULL protoname */
  char **protocols;
  /* The fields below this were added in CURLVERSION_SECOND */
  char *ares;
  int ares_num;
  /* This field was added in CURLVERSION_THIRD */
  char *libidn;
  /* These field were added in CURLVERSION_FOURTH */
  /* Same as '_libiconv_version' if built with HAVE_ICONV */
  int iconv_ver_num;
  char *libssh_version;
}
alias _N28 curl_version_info_data;

const CURL_VERSION_IPV6         = 1;  /* IPv6-enabled */
const CURL_VERSION_KERBEROS4    = 2;  /* kerberos auth is supported */
const CURL_VERSION_SSL          = 4;  /* SSL options are present */
const CURL_VERSION_LIBZ         = 8;  /* libz features are present */
const CURL_VERSION_NTLM         = 16;  /* NTLM auth is supported */
const CURL_VERSION_GSSNEGOTIATE = 32; /* Negotiate auth support */
const CURL_VERSION_DEBUG        = 64;  /* built with debug capabilities */
const CURL_VERSION_ASYNCHDNS    = 128;  /* asynchronous dns resolves */
const CURL_VERSION_SPNEGO       = 256;  /* SPNEGO auth */
const CURL_VERSION_LARGEFILE    = 512;  /* supports files bigger than 2GB */
const CURL_VERSION_IDN          = 1024; /* International Domain Names support */
const CURL_VERSION_SSPI         = 2048; /* SSPI is supported */
const CURL_VERSION_CONV         = 4096; /* character conversions supported */
const CURL_VERSION_CURLDEBUG    = 8192; /* debug memory tracking supported */
const CURL_VERSION_TLSAUTH_SRP  = 16384; /* TLS-SRP auth is supported */

extern (C) { 
/*
 * NAME curl_version_info()
 *
 * DESCRIPTION
 *
 * This function returns a pointer to a static copy of the version info
 * struct. See above.
 */
curl_version_info_data * curl_version_info(CURLversion );

/*
 * NAME curl_easy_strerror()
 *
 * DESCRIPTION
 *
 * The curl_easy_strerror function may be used to turn a CURLcode value
 * into the equivalent human readable error string.  This is useful
 * for printing meaningful error messages.
 */
char * curl_easy_strerror(CURLcode );

/*
 * NAME curl_share_strerror()
 *
 * DESCRIPTION
 *
 * The curl_share_strerror function may be used to turn a CURLSHcode value
 * into the equivalent human readable error string.  This is useful
 * for printing meaningful error messages.
 */
char * curl_share_strerror(CURLSHcode );

/*
 * NAME curl_easy_pause()
 *
 * DESCRIPTION
 *
 * The curl_easy_pause function pauses or unpauses transfers. Select the new
 * state by setting the bitmask, use the convenience defines below.
 *
 */
CURLcode  curl_easy_pause(CURL *handle, int bitmask);
}

const CURLPAUSE_RECV      = 1;
const CURLPAUSE_RECV_CONT = 0;

const CURLPAUSE_SEND      = 4;
const CURLPAUSE_SEND_CONT = 0;

const CURLPAUSE_ALL       = (CURLPAUSE_RECV|CURLPAUSE_SEND);
const CURLPAUSE_CONT      = (CURLPAUSE_RECV_CONT|CURLPAUSE_SEND_CONT);

/* unfortunately, the easy.h and multi.h include files need options and info
  stuff before they can be included! */
/***************************************************************************
 *                                  _   _ ____  _
 *  Project                     ___| | | |  _ \| |
 *                             / __| | | | |_) | |
 *                            | (__| |_| |  _ <| |___
 *                             \___|\___/|_| \_\_____|
 *
 * Copyright (C) 1998 - 2008, Daniel Stenberg, <daniel@haxx.se>, et al.
 *
 * This software is licensed as described in the file COPYING, which
 * you should have received as part of this distribution. The terms
 * are also available at http://curl.haxx.se/docs/copyright.html.
 *
 * You may opt to use, copy, modify, merge, publish, distribute and/or sell
 * copies of the Software, and permit persons to whom the Software is
 * furnished to do so, under the terms of the COPYING file.
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied.
 *
 ***************************************************************************/

extern (C) { 
  CURL * curl_easy_init();
  CURLcode  curl_easy_setopt(CURL *curl, CURLoption option,...);
  CURLcode  curl_easy_perform(CURL *curl);
  void  curl_easy_cleanup(CURL *curl);
}

/*
 * NAME curl_easy_getinfo()
 *
 * DESCRIPTION
 *
 * Request internal information from the curl session with this function.  The
 * third argument MUST be a pointer to a long, a pointer to a char * or a
 * pointer to a double (as the documentation describes elsewhere).  The data
 * pointed to will be filled in accordingly and can be relied upon only if the
 * function returns CURLE_OK.  This function is intended to get used *AFTER* a
 * performed transfer, all results from this function are undefined until the
 * transfer is completed.
 */
extern (C) CURLcode  curl_easy_getinfo(CURL *curl, CURLINFO info,...);


/*
 * NAME curl_easy_duphandle()
 *
 * DESCRIPTION
 *
 * Creates a new curl session handle with the same options set for the handle
 * passed in. Duplicating a handle could only be a matter of cloning data and
 * options, internal state info and things like persistant connections cannot
 * be transfered. It is useful in multithreaded applications when you can run
 * curl_easy_duphandle() for each new thread to avoid a series of identical
 * curl_easy_setopt() invokes in every thread.
 */
extern (C) CURL * curl_easy_duphandle(CURL *curl);

/*
 * NAME curl_easy_reset()
 *
 * DESCRIPTION
 *
 * Re-initializes a CURL handle to the default values. This puts back the
 * handle to the same state as it was in when it was just created.
 *
 * It does keep: live connections, the Session ID cache, the DNS cache and the
 * cookies.
 */
extern (C) void  curl_easy_reset(CURL *curl);

/*
 * NAME curl_easy_recv()
 *
 * DESCRIPTION
 *
 * Receives data from the connected socket. Use after successful
 * curl_easy_perform() with CURLOPT_CONNECT_ONLY option.
 */
extern (C) CURLcode  curl_easy_recv(CURL *curl, void *buffer, size_t buflen, size_t *n);

/*
 * NAME curl_easy_send()
 *
 * DESCRIPTION
 *
 * Sends data over the connected socket. Use after successful
 * curl_easy_perform() with CURLOPT_CONNECT_ONLY option.
 */
extern (C) CURLcode  curl_easy_send(CURL *curl, void *buffer, size_t buflen, size_t *n);


/*
 * This header file should not really need to include "curl.h" since curl.h
 * itself includes this file and we expect user applications to do #include
 * <curl/curl.h> without the need for especially including multi.h.
 *
 * For some reason we added this include here at one point, and rather than to
 * break existing (wrongly written) libcurl applications, we leave it as-is
 * but with this warning attached.
 */
/***************************************************************************
 *                                  _   _ ____  _
 *  Project                     ___| | | |  _ \| |
 *                             / __| | | | |_) | |
 *                            | (__| |_| |  _ <| |___
 *                             \___|\___/|_| \_\_____|
 *
 * Copyright (C) 1998 - 2010, Daniel Stenberg, <daniel@haxx.se>, et al.
 *
 * This software is licensed as described in the file COPYING, which
 * you should have received as part of this distribution. The terms
 * are also available at http://curl.haxx.se/docs/copyright.html.
 *
 * You may opt to use, copy, modify, merge, publish, distribute and/or sell
 * copies of the Software, and permit persons to whom the Software is
 * furnished to do so, under the terms of the COPYING file.
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied.
 *
 ***************************************************************************/

alias void CURLM;

enum CurlM {
    call_multi_perform = -1, /* please call curl_multi_perform() or curl_multi_socket*() soon */
    ok,     
    bad_handle,              /* the passed-in handle is not a valid CURLM handle */	 
    bad_easy_handle,	   /* an easy handle was not good/valid */		 
    out_of_memory,	   /* if you ever get this, you're in deep sh*t */	 
    internal_error,	   /* this is a libcurl bug */				 
    bad_socket,		   /* the passed in socket argument did not match */	 
    unknown_option,	   /* curl_multi_setopt() with unsupported option */       
    last,
}
alias int CURLMcode;

/* just to make code nicer when using curl_multi_socket() you can now check
   for CURLM_CALL_MULTI_SOCKET too in the same style it works for
   curl_multi_perform() and CURLM_CALL_MULTI_PERFORM */
const CURLM_CALL_MULTI_SOCKET = CurlM.call_multi_perform; 

enum CurlMsg
{
    none,
    done, /* This easy handle has completed. 'result' contains
    	     the CURLcode of the transfer */
    last, /* no used */
}
alias int CURLMSG;

union _N31
{
    void *whatever;  /* message-specific data */    
    CURLcode result; /* return code for transfer */ 
}
struct CURLMsg
{
    CURLMSG msg;        /* what this message means */ 
    CURL *easy_handle;	/* the handle it concerns */  
    _N31 data;
}

/*
 * Name:    curl_multi_init()
 *
 * Desc:    inititalize multi-style curl usage
 *
 * Returns: a new CURLM handle to use in all 'curl_multi' functions.
 */
extern (C) CURLM * curl_multi_init();

/*
 * Name:    curl_multi_add_handle()
 *
 * Desc:    add a standard curl handle to the multi stack
 *
 * Returns: CURLMcode type, general multi error code.
 */
extern (C) CURLMcode  curl_multi_add_handle(CURLM *multi_handle, CURL *curl_handle);

 /*
  * Name:    curl_multi_remove_handle()
  *
  * Desc:    removes a curl handle from the multi stack again
  *
  * Returns: CURLMcode type, general multi error code.
  */
extern (C) CURLMcode  curl_multi_remove_handle(CURLM *multi_handle, CURL *curl_handle);

 /*
  * Name:    curl_multi_fdset()
  *
  * Desc:    Ask curl for its fd_set sets. The app can use these to select() or
  *          poll() on. We want curl_multi_perform() called as soon as one of
  *          them are ready.
  *
  * Returns: CURLMcode type, general multi error code.
  */

/* tmp decl */
alias int fd_set;
extern (C) CURLMcode  curl_multi_fdset(CURLM *multi_handle, fd_set *read_fd_set, fd_set *write_fd_set, fd_set *exc_fd_set, int *max_fd);

 /*
  * Name:    curl_multi_perform()
  *
  * Desc:    When the app thinks there's data available for curl it calls this
  *          function to read/write whatever there is right now. This returns
  *          as soon as the reads and writes are done. This function does not
  *          require that there actually is data available for reading or that
  *          data can be written, it can be called just in case. It returns
  *          the number of handles that still transfer data in the second
  *          argument's integer-pointer.
  *
  * Returns: CURLMcode type, general multi error code. *NOTE* that this only
  *          returns errors etc regarding the whole multi stack. There might
  *          still have occurred problems on invidual transfers even when this
  *          returns OK.
  */
extern (C) CURLMcode  curl_multi_perform(CURLM *multi_handle, int *running_handles);

 /*
  * Name:    curl_multi_cleanup()
  *
  * Desc:    Cleans up and removes a whole multi stack. It does not free or
  *          touch any individual easy handles in any way. We need to define
  *          in what state those handles will be if this function is called
  *          in the middle of a transfer.
  *
  * Returns: CURLMcode type, general multi error code.
  */
extern (C) CURLMcode  curl_multi_cleanup(CURLM *multi_handle);

/*
 * Name:    curl_multi_info_read()
 *
 * Desc:    Ask the multi handle if there's any messages/informationals from
 *          the individual transfers. Messages include informationals such as
 *          error code from the transfer or just the fact that a transfer is
 *          completed. More details on these should be written down as well.
 *
 *          Repeated calls to this function will return a new struct each
 *          time, until a special "end of msgs" struct is returned as a signal
 *          that there is no more to get at this point.
 *
 *          The data the returned pointer points to will not survive calling
 *          curl_multi_cleanup().
 *
 *          The 'CURLMsg' struct is meant to be very simple and only contain
 *          very basic informations. If more involved information is wanted,
 *          we will provide the particular "transfer handle" in that struct
 *          and that should/could/would be used in subsequent
 *          curl_easy_getinfo() calls (or similar). The point being that we
 *          must never expose complex structs to applications, as then we'll
 *          undoubtably get backwards compatibility problems in the future.
 *
 * Returns: A pointer to a filled-in struct, or NULL if it failed or ran out
 *          of structs. It also writes the number of messages left in the
 *          queue (after this read) in the integer the second argument points
 *          to.
 */
extern (C) CURLMsg * curl_multi_info_read(CURLM *multi_handle, int *msgs_in_queue);

/*
 * Name:    curl_multi_strerror()
 *
 * Desc:    The curl_multi_strerror function may be used to turn a CURLMcode
 *          value into the equivalent human readable error string.  This is
 *          useful for printing meaningful error messages.
 *
 * Returns: A pointer to a zero-terminated error message.
 */
char * curl_multi_strerror(CURLMcode );

/*
 * Name:    curl_multi_socket() and
 *          curl_multi_socket_all()
 *
 * Desc:    An alternative version of curl_multi_perform() that allows the
 *          application to pass in one of the file descriptors that have been
 *          detected to have "action" on them and let libcurl perform.
 *          See man page for details.
 */
const CURL_POLL_NONE = 0;
const CURL_POLL_IN = 1;
const CURL_POLL_OUT = 2;
const CURL_POLL_INOUT = 3;

const CURL_POLL_REMOVE = 4;

alias CURL_SOCKET_BAD CURL_SOCKET_TIMEOUT;
const CURL_CSELECT_IN = 0x01;
const CURL_CSELECT_OUT = 0x02;

const CURL_CSELECT_ERR = 0x04;

extern (C) {
  alias int function(CURL *easy,                            /* easy handle */	 
		     curl_socket_t s, 			  /* socket */	 
		     int what, 				  /* see above */	 
		     void *userp, 			  /* private callback pointer */	 
		     void *socketp)curl_socket_callback;	  /* private socket pointer */ 
}

/*							     
 * Name:    curl_multi_timer_callback
 *
 * Desc:    Called by libcurl whenever the library detects a change in the
 *          maximum number of milliseconds the app is allowed to wait before
 *          curl_multi_socket() or curl_multi_perform() must be called
 *          (to allow libcurl's timed events to take place).
 *
 * Returns: The callback should return zero.
 */
/* private callback pointer */

extern (C) {
  alias int function(CURLM *multi,    /* multi handle */
		     int timeout_ms,  /* see above */
		     void *userp) curl_multi_timer_callback;  /* private callback pointer */
  
  CURLMcode  curl_multi_socket(CURLM *multi_handle, curl_socket_t s, int *running_handles);
  
  CURLMcode  curl_multi_socket_action(CURLM *multi_handle, curl_socket_t s, int ev_bitmask, int *running_handles);
  
  CURLMcode  curl_multi_socket_all(CURLM *multi_handle, int *running_handles);
}

/* This macro below was added in 7.16.3 to push users who recompile to use
   the new curl_multi_socket_action() instead of the old curl_multi_socket()
*/

/*
 * Name:    curl_multi_timeout()
 *
 * Desc:    Returns the maximum number of milliseconds the app is allowed to
 *          wait before curl_multi_socket() or curl_multi_perform() must be
 *          called (to allow libcurl's timed events to take place).
 *
 * Returns: CURLM error code.
 */
extern (C) CURLMcode  curl_multi_timeout(CURLM *multi_handle, int *milliseconds);

enum CurlMOption {
    socketfunction = 20001,    /* This is the socket callback function pointer */	    
    socketdata = 10002,        /* This is the argument passed to the socket callback */  
    pipelining = 3,	        /* set to 1 to enable pipelining for this multi handle */ 
    timerfunction = 20004,     /* This is the timer callback function pointer */	    
    timerdata = 10005,	        /* This is the argument passed to the timer callback */   
    maxconnects = 6,	        /* maximum number of entries in the connection cache */   
    lastentry,
}
alias int CURLMoption;


/*
 * Name:    curl_multi_setopt()
 *
 * Desc:    Sets options for the multi handle.
 *
 * Returns: CURLM error code.
 */
extern (C) CURLMcode  curl_multi_setopt(CURLM *multi_handle, CURLMoption option,...);


/*
 * Name:    curl_multi_assign()
 *
 * Desc:    This function sets an association in the multi handle between the
 *          given socket and a private pointer of the application. This is
 *          (only) useful for curl_multi_socket uses.
 *
 * Returns: CURLM error code.
 */
extern (C) CURLMcode  curl_multi_assign(CURLM *multi_handle, curl_socket_t sockfd, void *sockp);
