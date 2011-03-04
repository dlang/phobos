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
enum
{
    CURLFILETYPE_FILE,
    CURLFILETYPE_DIRECTORY,
    CURLFILETYPE_SYMLINK,
    CURLFILETYPE_DEVICE_BLOCK,
    CURLFILETYPE_DEVICE_CHAR,
    CURLFILETYPE_NAMEDPIPE,
    CURLFILETYPE_SOCKET,
    CURLFILETYPE_DOOR,
    CURLFILETYPE_UNKNOWN
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

/* These are the return codes for the seek callbacks */
const CURL_SEEKFUNC_OK = 0;
const CURL_SEEKFUNC_FAIL = 1; /* fail the entire transfer */
const CURL_SEEKFUNC_CANTSEEK = 2; /* tell libcurl seeking can't be done, so
                                    libcurl might try other means instead */

alias int  function(void *instream, curl_off_t offset, int origin)curl_seek_callback;

/* This is a return code for the read callback that, when returned, will
   signal libcurl to immediately abort the current transfer. */
const CURL_READFUNC_ABORT = 0x10000000;

/* This is a return code for the read callback that, when returned,
   will const signal libcurl to pause sending data on the current
   transfer. */
const CURL_READFUNC_PAUSE = 0x10000001;
alias size_t  function(char *buffer, size_t size, size_t nitems, void *instream)curl_read_callback;

enum
{
    CURLSOCKTYPE_IPCXN,
    CURLSOCKTYPE_LAST
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

enum
{
    CURLIOE_OK,            /* I/O operation successful */
    CURLIOE_UNKNOWNCMD,    /* command was unknown to callback */	
    CURLIOE_FAILRESTART,   /* failed to restart the read */	
    CURLIOE_LAST	   /* never use */                        
}
alias int curlioerr;

enum
{
    CURLIOCMD_NOP,         /* command was unknown to callback */	
    CURLIOCMD_RESTARTREAD, /* failed to restart the read */	
    CURLIOCMD_LAST,	   /* never use */                        
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
enum
{
    CURLINFO_TEXT,
    CURLINFO_HEADER_IN,
    CURLINFO_HEADER_OUT,
    CURLINFO_DATA_IN,
    CURLINFO_DATA_OUT,
    CURLINFO_SSL_DATA_IN,
    CURLINFO_SSL_DATA_OUT,
    CURLINFO_END
}
alias int curl_infotype;

alias int  function(CURL *handle, curl_infotype type, char *data, size_t size, void *userptr)curl_debug_callback;

/* All possible error codes from all sorts of curl functions. Future versions
   may return other values, stay prepared.

   Always add new return codes last. Never *EVER* remove any. The return
   codes must remain the same!
 */

/* 9 a service was denied by the server
                                    due to lack of access - when login fails
                                    this is not returned. */
  /* Note: CURLE_OUT_OF_MEMORY may sometimes indicate a conversion error
           instead of a memory allocation error if CURL_DOES_CONVERSIONS
           is defined
  */
/* 51 - peer's certificate or fingerprint
                                     wasn't verified fine */
/* 54 - can not set SSL crypto engine as
                                    default */
/* 65 - Sending the data requires a rewind
                                    that failed */
/* 67 - user, password or similar was not
                                    accepted and we failed to login */
/* 76 - caller must register conversion
                                    callbacks using curl_easy_setopt options
                                    CURLOPT_CONV_FROM_NETWORK_FUNCTION,
                                    CURLOPT_CONV_TO_NETWORK_FUNCTION, and
                                    CURLOPT_CONV_FROM_UTF8_FUNCTION */
/* 77 - could not load CACERT file, missing
                                    or wrong format */
/* 79 - error from the SSH layer, somewhat
                                    generic so the error message will be of
                                    interest when this has happened */

/* 80 - Failed to shut down the SSL
                                    connection */
/* 81 - socket is not ready for send/recv,
                                    wait till it's ready and try again (Added
                                    in 7.18.2) */
/* 82 - could not load CRL file, missing or
                                    wrong format (Added in 7.19.0) */
/* 83 - Issuer check failed.  (Added in
                                    7.19.0) */

enum
{
    CURLE_OK,                           
    CURLE_UNSUPPORTED_PROTOCOL,          /* 1 */				
    CURLE_FAILED_INIT,			 /* 2 */				
    CURLE_URL_MALFORMAT,		 /* 3 */				
    CURLE_OBSOLETE4,			 /* 4 - NOT USED */			
    CURLE_COULDNT_RESOLVE_PROXY,	 /* 5 */				
    CURLE_COULDNT_RESOLVE_HOST,		 /* 6 */				
    CURLE_COULDNT_CONNECT,		 /* 7 */				
    CURLE_FTP_WEIRD_SERVER_REPLY,	 /* 8 */				
    CURLE_REMOTE_ACCESS_DENIED,		 /* 9 a service was denied by the server
					    due to lack of access - when login fails
					    this is not returned. */
    CURLE_OBSOLETE10,                    /* 10 - NOT USED */			
    CURLE_FTP_WEIRD_PASS_REPLY,		 /* 11 */				
    CURLE_OBSOLETE12,			 /* 12 - NOT USED */			
    CURLE_FTP_WEIRD_PASV_REPLY,		 /* 13 */				
    CURLE_FTP_WEIRD_227_FORMAT,		 /* 14 */				
    CURLE_FTP_CANT_GET_HOST,		 /* 15 */				
    CURLE_OBSOLETE16,			 /* 16 - NOT USED */			
    CURLE_FTP_COULDNT_SET_TYPE,		 /* 17 */				
    CURLE_PARTIAL_FILE,			 /* 18 */				
    CURLE_FTP_COULDNT_RETR_FILE,	 /* 19 */				
    CURLE_OBSOLETE20,			 /* 20 - NOT USED */			
    CURLE_QUOTE_ERROR,			 /* 21 - quote command failure */	
    CURLE_HTTP_RETURNED_ERROR,		 /* 22 */				
    CURLE_WRITE_ERROR,			 /* 23 */				
    CURLE_OBSOLETE24,			 /* 24 - NOT USED */			
    CURLE_UPLOAD_FAILED,		 /* 25 - failed upload "command" */	
    CURLE_READ_ERROR,			 /* 26 - couldn't open/read from file */
    CURLE_OUT_OF_MEMORY,		 /* 27 */                               
    /* Note: CURLE_OUT_OF_MEMORY may sometimes indicate a conversion error
             instead of a memory allocation error if CURL_DOES_CONVERSIONS
             is defined
    */
    CURLE_OPERATION_TIMEDOUT,            /* 28 - the timeout time was reached */     
    CURLE_OBSOLETE29,			 /* 29 - NOT USED */			     
    CURLE_FTP_PORT_FAILED,		 /* 30 - FTP PORT operation failed */	     
    CURLE_FTP_COULDNT_USE_REST,		 /* 31 - the REST command failed */	     
    CURLE_OBSOLETE32,			 /* 32 - NOT USED */			     
    CURLE_RANGE_ERROR,			 /* 33 - RANGE "command" didn't work */	     
    CURLE_HTTP_POST_ERROR,		 /* 34 */				     
    CURLE_SSL_CONNECT_ERROR,		 /* 35 - wrong when connecting with SSL */   
    CURLE_BAD_DOWNLOAD_RESUME,		 /* 36 - couldn't resume download */	     
    CURLE_FILE_COULDNT_READ_FILE,	 /* 37 */				     
    CURLE_LDAP_CANNOT_BIND,		 /* 38 */				     
    CURLE_LDAP_SEARCH_FAILED,		 /* 39 */				     
    CURLE_OBSOLETE40,			 /* 40 - NOT USED */			     
    CURLE_FUNCTION_NOT_FOUND,		 /* 41 */				     
    CURLE_ABORTED_BY_CALLBACK,		 /* 42 */				     
    CURLE_BAD_FUNCTION_ARGUMENT,	 /* 43 */				     
    CURLE_OBSOLETE44,			 /* 44 - NOT USED */			     
    CURLE_INTERFACE_FAILED,		 /* 45 - CURLOPT_INTERFACE failed */	     
    CURLE_OBSOLETE46,			 /* 46 - NOT USED */			     
    CURLE_TOO_MANY_REDIRECTS,		 /* 47 - catch endless re-direct loops */    
    CURLE_UNKNOWN_TELNET_OPTION,	 /* 48 - User specified an unknown option */ 
    CURLE_TELNET_OPTION_SYNTAX,		 /* 49 - Malformed telnet option */	     
    CURLE_OBSOLETE50,			 /* 50 - NOT USED */			     
    CURLE_PEER_FAILED_VERIFICATION,	 /* 51 - peer's certificate or fingerprint  
					     wasn't verified fine */
    CURLE_GOT_NOTHING,                   /* 52 - when this is a specific error */					
    CURLE_SSL_ENGINE_NOTFOUND,		 /* 53 - SSL crypto engine not found */						
    CURLE_SSL_ENGINE_SETFAILED,		 /* 54 - can not set SSL crypto engine as default */				
    CURLE_SEND_ERROR,			 /* 55 - failed sending network data */						
    CURLE_RECV_ERROR,			 /* 56 - failure in receiving network data */					
    CURLE_OBSOLETE57,			 /* 57 - NOT IN USE */								
    CURLE_SSL_CERTPROBLEM,		 /* 58 - problem with the local certificate */					
    CURLE_SSL_CIPHER,			 /* 59 - couldn't use specified cipher */					
    CURLE_SSL_CACERT,			 /* 60 - problem with the CA cert (path?) */					
    CURLE_BAD_CONTENT_ENCODING,		 /* 61 - Unrecognized transfer encoding */					
    CURLE_LDAP_INVALID_URL,		 /* 62 - Invalid LDAP URL */							
    CURLE_FILESIZE_EXCEEDED,		 /* 63 - Maximum file size exceeded */						
    CURLE_USE_SSL_FAILED,		 /* 64 - Requested FTP SSL level failed */					
    CURLE_SEND_FAIL_REWIND,		 /* 65 - Sending the data requires a rewind that failed */			
    CURLE_SSL_ENGINE_INITFAILED,	 /* 66 - failed to initialise ENGINE */						
    CURLE_LOGIN_DENIED,			 /* 67 - user, password or similar was not accepted and we failed to login */	
    CURLE_TFTP_NOTFOUND,		 /* 68 - file not found on server */						
    CURLE_TFTP_PERM,			 /* 69 - permission problem on server */					
    CURLE_REMOTE_DISK_FULL,		 /* 70 - out of disk space on server */						
    CURLE_TFTP_ILLEGAL,			 /* 71 - Illegal TFTP operation */						
    CURLE_TFTP_UNKNOWNID,		 /* 72 - Unknown transfer ID */							
    CURLE_REMOTE_FILE_EXISTS,		 /* 73 - File already exists */							
    CURLE_TFTP_NOSUCHUSER,		 /* 74 - No such user */							
    CURLE_CONV_FAILED,			 /* 75 - conversion failed */							
    CURLE_CONV_REQD,			 /* 76 - caller must register conversion                                        
					    callbacks using curl_easy_setopt options
					    CURLOPT_CONV_FROM_NETWORK_FUNCTION,
					    CURLOPT_CONV_TO_NETWORK_FUNCTION, and
					    CURLOPT_CONV_FROM_UTF8_FUNCTION */
    CURLE_SSL_CACERT_BADFILE,            /* 77 - could not load CACERT file, missing  or wrong format */ 
    CURLE_REMOTE_FILE_NOT_FOUND,	 /* 78 - remote file not found */				 
    CURLE_SSH,				 /* 79 - error from the SSH layer, somewhat                      
					    generic so the error message will be of
					    interest when this has happened */
    CURLE_SSL_SHUTDOWN_FAILED,           /* 80 - Failed to shut down the SSL connection */ 
    CURLE_AGAIN,			 /* 81 - socket is not ready for send/recv,        
					    wait till it's ready and try again (Added
					    in 7.18.2) */
    CURLE_SSL_CRL_BADFILE,               /* 82 - could not load CRL file, missing or wrong format (Added in 7.19.0) */	
    CURLE_SSL_ISSUER_ERROR,		 /* 83 - Issuer check failed.  (Added in 7.19.0) */				
    CURLE_FTP_PRET_FAILED,		 /* 84 - a PRET command failed */						
    CURLE_RTSP_CSEQ_ERROR,		 /* 85 - mismatch of RTSP CSeq numbers */					
    CURLE_RTSP_SESSION_ERROR,		 /* 86 - mismatch of RTSP Session Identifiers */				
    CURLE_FTP_BAD_FILE_LIST,		 /* 87 - unable to parse FTP file list */					
    CURLE_CHUNK_FAILED,			 /* 88 - chunk callback reported error */                                       
    CURL_LAST /* never use! */
}
alias int CURLcode;

/* This prototype applies to all conversion callbacks */
alias CURLcode  function(char *buffer, size_t length)curl_conv_callback;

/* actually an OpenSSL SSL_CTX */
alias CURLcode  function(CURL *curl, void *ssl_ctx, void *userptr)curl_ssl_ctx_callback;

enum
{
    CURLPROXY_HTTP,             /* added in 7.10, new in 7.19.4 default is to use CONNECT HTTP/1.1 */ 
    CURLPROXY_HTTP_1_0,		/* added in 7.19.4, force to use CONNECT HTTP/1.0  */		      
    CURLPROXY_SOCKS4 = 4,	/* support added in 7.15.2, enum existed already in 7.10 */           
    CURLPROXY_SOCKS5,
    CURLPROXY_SOCKS4A,
    CURLPROXY_SOCKS5_HOSTNAME   /* Use the SOCKS5 protocol but pass along the
                                   host name rather than the IP address. added
                                   in 7.18.0 */                                   
}
alias int curl_proxytype;

const CURLAUTH_NONE =         0;
const CURLAUTH_BASIC =        1;  /* Basic (default) */
const CURLAUTH_DIGEST =       2;  /* Digest */
const CURLAUTH_GSSNEGOTIATE = 4;  /* GSS-Negotiate */
const CURLAUTH_NTLM =         8;  /* NTLM */
const CURLAUTH_DIGEST_IE =    16;  /* Digest with IE flavour */
const CURLAUTH_ONLY =         2147483648; /* used together with a single other
                                          type to force no auth or just that
                                          single type */

const CURLAUTH_ANY = -17; // (~CURLAUTH_DIGEST_IE)  /* all fine types set */
const CURLAUTH_ANYSAFE = -18; // (~(CURLAUTH_BASIC|CURLAUTH_DIGEST_IE))

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
enum type
{
    CURLKHTYPE_UNKNOWN,
    CURLKHTYPE_RSA1,
    CURLKHTYPE_RSA,
    CURLKHTYPE_DSS
}
struct curl_khkey
{
    char *key;
    size_t len;
    type keytype;
}

/* this is the set of return values expected from the curl_sshkeycallback
   callback */
/* do not accept it, but we can't answer right now so
   this causes a CURLE_DEFER error but otherwise the
   connection will be left intact etc */
enum curl_khstat
{
    CURLKHSTAT_FINE_ADD_TO_FILE,
    CURLKHSTAT_FINE,
    CURLKHSTAT_REJECT,
    CURLKHSTAT_DEFER,
    CURLKHSTAT_LAST
}

/* this is the set of status codes pass in to the callback */
enum curl_khmatch
{
    CURLKHMATCH_OK,
    CURLKHMATCH_MISMATCH,
    CURLKHMATCH_MISSING,
    CURLKHMATCH_LAST
}

alias int  function(CURL *easy, curl_khkey *knownkey, curl_khkey *foundkey, curl_khmatch , void *clientp)curl_sshkeycallback;

/* parameter for the CURLOPT_USE_SSL option */
enum
{
    CURLUSESSL_NONE,
    CURLUSESSL_TRY,
    CURLUSESSL_CONTROL,
    CURLUSESSL_ALL,
    CURLUSESSL_LAST
}
alias int curl_usessl;

/* parameter for the CURLOPT_FTP_SSL_CCC option */
enum
{
    CURLFTPSSL_CCC_NONE,
    CURLFTPSSL_CCC_PASSIVE,
    CURLFTPSSL_CCC_ACTIVE,
    CURLFTPSSL_CCC_LAST
}
alias int curl_ftpccc;

/* parameter for the CURLOPT_FTPSSLAUTH option */
enum
{
    CURLFTPAUTH_DEFAULT,
    CURLFTPAUTH_SSL,
    CURLFTPAUTH_TLS,
    CURLFTPAUTH_LAST
}
alias int curl_ftpauth;

/* parameter for the CURLOPT_FTP_CREATE_MISSING_DIRS option */
enum
{
    CURLFTP_CREATE_DIR_NONE,   /* do NOT create missing dirs! */
    CURLFTP_CREATE_DIR,        /* (FTP/SFTP) if CWD fails, try MKD and then CWD again if MKD 
				  succeeded, for SFTP this does similar magic */             
    CURLFTP_CREATE_DIR_RETRY,  /* (FTP only) if CWD fails, try MKD and then CWD again even if MKD    
				  failed! */
    CURLFTP_CREATE_DIR_LAST    /* not an option, never use */                                                         
}
alias int curl_ftpcreatedir;

/* parameter for the CURLOPT_FTP_FILEMETHOD option */
enum
{
    CURLFTPMETHOD_DEFAULT,    /* let libcurl pick */			  
    CURLFTPMETHOD_MULTICWD,   /* single CWD operation for each path part */  
    CURLFTPMETHOD_NOCWD,      /* no CWD at all */				  
    CURLFTPMETHOD_SINGLECWD,  /* one CWD to full dir, then work on file */	  
    CURLFTPMETHOD_LAST	      /* not an option, never use */                 
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

enum
{
    CURLOPT_FILE = 10001,
    CURLOPT_URL,
    CURLOPT_PORT = 3,
    CURLOPT_PROXY = 10004,
    CURLOPT_USERPWD,
    CURLOPT_PROXYUSERPWD,
    CURLOPT_RANGE,
    CURLOPT_INFILE = 10009,
    CURLOPT_ERRORBUFFER,
    CURLOPT_WRITEFUNCTION = 20011,
    CURLOPT_READFUNCTION,
    CURLOPT_TIMEOUT = 13,
    CURLOPT_INFILESIZE,
    CURLOPT_POSTFIELDS = 10015,
    CURLOPT_REFERER,
    CURLOPT_FTPPORT,
    CURLOPT_USERAGENT,
    CURLOPT_LOW_SPEED_LIMIT = 19,
    CURLOPT_LOW_SPEED_TIME,
    CURLOPT_RESUME_FROM,
    CURLOPT_COOKIE = 10022,
    CURLOPT_HTTPHEADER,
    CURLOPT_HTTPPOST,
    CURLOPT_SSLCERT,
    CURLOPT_KEYPASSWD,
    CURLOPT_CRLF = 27,
    CURLOPT_QUOTE = 10028,
    CURLOPT_WRITEHEADER,
    CURLOPT_COOKIEFILE = 10031,
    CURLOPT_SSLVERSION = 32,
    CURLOPT_TIMECONDITION,
    CURLOPT_TIMEVALUE,
    CURLOPT_CUSTOMREQUEST = 10036,
    CURLOPT_STDERR,
    CURLOPT_POSTQUOTE = 10039,
    CURLOPT_WRITEINFO,
    CURLOPT_VERBOSE = 41,
    CURLOPT_HEADER,
    CURLOPT_NOPROGRESS,
    CURLOPT_NOBODY,
    CURLOPT_FAILONERROR,
    CURLOPT_UPLOAD,
    CURLOPT_POST,
    CURLOPT_DIRLISTONLY,
    CURLOPT_APPEND = 50,
    CURLOPT_NETRC,
    CURLOPT_FOLLOWLOCATION,
    CURLOPT_TRANSFERTEXT,
    CURLOPT_PUT,
    CURLOPT_PROGRESSFUNCTION = 20056,
    CURLOPT_PROGRESSDATA = 10057,
    CURLOPT_AUTOREFERER = 58,
    CURLOPT_PROXYPORT,
    CURLOPT_POSTFIELDSIZE,
    CURLOPT_HTTPPROXYTUNNEL,
    CURLOPT_INTERFACE = 10062,
    CURLOPT_KRBLEVEL,
    CURLOPT_SSL_VERIFYPEER = 64,
    CURLOPT_CAINFO = 10065,
    CURLOPT_MAXREDIRS = 68,
    CURLOPT_FILETIME,
    CURLOPT_TELNETOPTIONS = 10070,
    CURLOPT_MAXCONNECTS = 71,
    CURLOPT_CLOSEPOLICY,
    CURLOPT_FRESH_CONNECT = 74,
    CURLOPT_FORBID_REUSE,
    CURLOPT_RANDOM_FILE = 10076,
    CURLOPT_EGDSOCKET,
    CURLOPT_CONNECTTIMEOUT = 78,
    CURLOPT_HEADERFUNCTION = 20079,
    CURLOPT_HTTPGET = 80,
    CURLOPT_SSL_VERIFYHOST,
    CURLOPT_COOKIEJAR = 10082,
    CURLOPT_SSL_CIPHER_LIST,
    CURLOPT_HTTP_VERSION = 84,
    CURLOPT_FTP_USE_EPSV,
    CURLOPT_SSLCERTTYPE = 10086,
    CURLOPT_SSLKEY,
    CURLOPT_SSLKEYTYPE,
    CURLOPT_SSLENGINE,
    CURLOPT_SSLENGINE_DEFAULT = 90,
    CURLOPT_DNS_USE_GLOBAL_CACHE,
    CURLOPT_DNS_CACHE_TIMEOUT,
    CURLOPT_PREQUOTE = 10093,
    CURLOPT_DEBUGFUNCTION = 20094,
    CURLOPT_DEBUGDATA = 10095,
    CURLOPT_COOKIESESSION = 96,
    CURLOPT_CAPATH = 10097,
    CURLOPT_BUFFERSIZE = 98,
    CURLOPT_NOSIGNAL,
    CURLOPT_SHARE = 10100,
    CURLOPT_PROXYTYPE = 101,
    CURLOPT_ENCODING = 10102,
    CURLOPT_PRIVATE,
    CURLOPT_HTTP200ALIASES,
    CURLOPT_UNRESTRICTED_AUTH = 105,
    CURLOPT_FTP_USE_EPRT,
    CURLOPT_HTTPAUTH,
    CURLOPT_SSL_CTX_FUNCTION = 20108,
    CURLOPT_SSL_CTX_DATA = 10109,
    CURLOPT_FTP_CREATE_MISSING_DIRS = 110,
    CURLOPT_PROXYAUTH,
    CURLOPT_FTP_RESPONSE_TIMEOUT,
    CURLOPT_IPRESOLVE,
    CURLOPT_MAXFILESIZE,
    CURLOPT_INFILESIZE_LARGE = 30115,
    CURLOPT_RESUME_FROM_LARGE,
    CURLOPT_MAXFILESIZE_LARGE,
    CURLOPT_NETRC_FILE = 10118,
    CURLOPT_USE_SSL = 119,
    CURLOPT_POSTFIELDSIZE_LARGE = 30120,
    CURLOPT_TCP_NODELAY = 121,
    CURLOPT_FTPSSLAUTH = 129,
    CURLOPT_IOCTLFUNCTION = 20130,
    CURLOPT_IOCTLDATA = 10131,
    CURLOPT_FTP_ACCOUNT = 10134,
    CURLOPT_COOKIELIST,
    CURLOPT_IGNORE_CONTENT_LENGTH = 136,
    CURLOPT_FTP_SKIP_PASV_IP,
    CURLOPT_FTP_FILEMETHOD,
    CURLOPT_LOCALPORT,
    CURLOPT_LOCALPORTRANGE,
    CURLOPT_CONNECT_ONLY,
    CURLOPT_CONV_FROM_NETWORK_FUNCTION = 20142,
    CURLOPT_CONV_TO_NETWORK_FUNCTION,
    CURLOPT_CONV_FROM_UTF8_FUNCTION,
    CURLOPT_MAX_SEND_SPEED_LARGE = 30145,
    CURLOPT_MAX_RECV_SPEED_LARGE,
    CURLOPT_FTP_ALTERNATIVE_TO_USER = 10147,
    CURLOPT_SOCKOPTFUNCTION = 20148,
    CURLOPT_SOCKOPTDATA = 10149,
    CURLOPT_SSL_SESSIONID_CACHE = 150,
    CURLOPT_SSH_AUTH_TYPES,
    CURLOPT_SSH_PUBLIC_KEYFILE = 10152,
    CURLOPT_SSH_PRIVATE_KEYFILE,
    CURLOPT_FTP_SSL_CCC = 154,
    CURLOPT_TIMEOUT_MS,
    CURLOPT_CONNECTTIMEOUT_MS,
    CURLOPT_HTTP_TRANSFER_DECODING,
    CURLOPT_HTTP_CONTENT_DECODING,
    CURLOPT_NEW_FILE_PERMS,
    CURLOPT_NEW_DIRECTORY_PERMS,
    CURLOPT_POSTREDIR,
    CURLOPT_SSH_HOST_PUBLIC_KEY_MD5 = 10162,
    CURLOPT_OPENSOCKETFUNCTION = 20163,
    CURLOPT_OPENSOCKETDATA = 10164,
    CURLOPT_COPYPOSTFIELDS,
    CURLOPT_PROXY_TRANSFER_MODE = 166,
    CURLOPT_SEEKFUNCTION = 20167,
    CURLOPT_SEEKDATA = 10168,
    CURLOPT_CRLFILE,
    CURLOPT_ISSUERCERT,
    CURLOPT_ADDRESS_SCOPE = 171,
    CURLOPT_CERTINFO,
    CURLOPT_USERNAME = 10173,
    CURLOPT_PASSWORD,
    CURLOPT_PROXYUSERNAME,
    CURLOPT_PROXYPASSWORD,
    CURLOPT_NOPROXY,
    CURLOPT_TFTP_BLKSIZE = 178,
    CURLOPT_SOCKS5_GSSAPI_SERVICE = 10179,
    CURLOPT_SOCKS5_GSSAPI_NEC = 180,
    CURLOPT_PROTOCOLS,
    CURLOPT_REDIR_PROTOCOLS,
    CURLOPT_SSH_KNOWNHOSTS = 10183,
    CURLOPT_SSH_KEYFUNCTION = 20184,
    CURLOPT_SSH_KEYDATA = 10185,
    CURLOPT_MAIL_FROM,
    CURLOPT_MAIL_RCPT,
    CURLOPT_FTP_USE_PRET = 188,
    CURLOPT_RTSP_REQUEST,
    CURLOPT_RTSP_SESSION_ID = 10190,
    CURLOPT_RTSP_STREAM_URI,
    CURLOPT_RTSP_TRANSPORT,
    CURLOPT_RTSP_CLIENT_CSEQ = 193,
    CURLOPT_RTSP_SERVER_CSEQ,
    CURLOPT_INTERLEAVEDATA = 10195,
    CURLOPT_INTERLEAVEFUNCTION = 20196,
    CURLOPT_WILDCARDMATCH = 197,
    CURLOPT_CHUNK_BGN_FUNCTION = 20198,
    CURLOPT_CHUNK_END_FUNCTION,
    CURLOPT_FNMATCH_FUNCTION,
    CURLOPT_CHUNK_DATA = 10201,
    CURLOPT_FNMATCH_DATA,
    CURLOPT_RESOLVE,
    CURLOPT_TLSAUTH_USERNAME,
    CURLOPT_TLSAUTH_PASSWORD,
    CURLOPT_TLSAUTH_TYPE,
    CURLOPT_LASTENTRY
}
alias int CURLoption;
alias CURLOPT_FTP_RESPONSE_TIMEOUT CURLOPT_SERVER_RESPONSE_TIMEOUT;

/* Below here follows defines for the CURLOPT_IPRESOLVE option. If a host
   name resolves addresses using more than one IP protocol version, this
   option might be handy to force libcurl to use a specific IP version. */
const CURL_IPRESOLVE_WHATEVER = 0; /* default, resolves addresses to all IP versions that your system allows */
const CURL_IPRESOLVE_V4 = 1;
const CURL_IPRESOLVE_V6 = 2;

  /* three convenient "aliases" that follow the name scheme better */
alias CURLOPT_FILE CURLOPT_WRITEDATA;
alias CURLOPT_INFILE CURLOPT_READDATA;
alias CURLOPT_WRITEHEADER CURLOPT_HEADERDATA;
alias CURLOPT_HTTPHEADER CURLOPT_RTSPHEADER;

/* These enums are for use with the CURLOPT_HTTP_VERSION option. */
enum
{
    CURL_HTTP_VERSION_NONE, /* setting this means we don't care, and that we'd
			       like the library to choose the best possible
			       for us! */
    CURL_HTTP_VERSION_1_0,
    CURL_HTTP_VERSION_1_1,
    CURL_HTTP_VERSION_LAST /* *ILLEGAL* http version */
}

/*
 * Public API enums for RTSP requests
 */
enum
{
    CURL_RTSPREQ_NONE,
    CURL_RTSPREQ_OPTIONS,
    CURL_RTSPREQ_DESCRIBE,
    CURL_RTSPREQ_ANNOUNCE,
    CURL_RTSPREQ_SETUP,
    CURL_RTSPREQ_PLAY,
    CURL_RTSPREQ_PAUSE,
    CURL_RTSPREQ_TEARDOWN,
    CURL_RTSPREQ_GET_PARAMETER,
    CURL_RTSPREQ_SET_PARAMETER,
    CURL_RTSPREQ_RECORD,
    CURL_RTSPREQ_RECEIVE,
    CURL_RTSPREQ_LAST
}

  /* These enums are for use with the CURLOPT_NETRC option. */


enum CURL_NETRC_OPTION
{
    CURL_NETRC_IGNORED,  /* The .netrc will never be read. This is the default. */		
    CURL_NETRC_OPTIONAL  /* A user:password in the URL will be preferred to one in the .netrc. */,
    CURL_NETRC_REQUIRED, /* A user:password in the URL will be ignored.
			  * Unless one is set programmatically, the .netrc
			  * will be queried. */
    CURL_NETRC_LAST
}


enum
{
    CURL_SSLVERSION_DEFAULT,
    CURL_SSLVERSION_TLSv1,
    CURL_SSLVERSION_SSLv2,
    CURL_SSLVERSION_SSLv3,
    CURL_SSLVERSION_LAST /* never use */
}

enum CURL_TLSAUTH
{
    CURL_TLSAUTH_NONE,
    CURL_TLSAUTH_SRP,
    CURL_TLSAUTH_LAST /* never use */
}

/* symbols to use with CURLOPT_POSTREDIR.
   CURL_REDIR_POST_301 and CURL_REDIR_POST_302 can be bitwise ORed so that
   CURL_REDIR_POST_301 | CURL_REDIR_POST_302 == CURL_REDIR_POST_ALL */

const CURL_REDIR_GET_ALL = 0;
const CURL_REDIR_POST_301 = 1;
const CURL_REDIR_POST_302 = 2;
const CURL_REDIR_POST_ALL = (CURL_REDIR_POST_301|CURL_REDIR_POST_302);

enum
{
    CURL_TIMECOND_NONE,
    CURL_TIMECOND_IFMODSINCE,
    CURL_TIMECOND_IFUNMODSINCE,
    CURL_TIMECOND_LASTMOD,
    CURL_TIMECOND_LAST
}
alias int curl_TimeCond;


/* curl_strequal() and curl_strnequal() are subject for removal in a future
   libcurl, see lib/README.curlx for details */
int  curl_strequal(char *s1, char *s2);
int  curl_strnequal(char *s1, char *s2, size_t n);

enum
{
    CURLFORM_NOTHING,
    CURLFORM_COPYNAME,
    CURLFORM_PTRNAME,
    CURLFORM_NAMELENGTH,
    CURLFORM_COPYCONTENTS,
    CURLFORM_PTRCONTENTS,
    CURLFORM_CONTENTSLENGTH,
    CURLFORM_FILECONTENT,
    CURLFORM_ARRAY,
    CURLFORM_OBSOLETE,
    CURLFORM_FILE,
    CURLFORM_BUFFER,
    CURLFORM_BUFFERPTR,
    CURLFORM_BUFFERLENGTH,
    CURLFORM_CONTENTTYPE,
    CURLFORM_CONTENTHEADER,
    CURLFORM_FILENAME,
    CURLFORM_END,
    CURLFORM_OBSOLETE2,
    CURLFORM_STREAM,
    CURLFORM_LASTENTRY,
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
enum
{
    CURL_FORMADD_OK,
    CURL_FORMADD_MEMORY,
    CURL_FORMADD_OPTION_TWICE,
    CURL_FORMADD_NULL,
    CURL_FORMADD_UNKNOWN_OPTION,
    CURL_FORMADD_INCOMPLETE,
    CURL_FORMADD_ILLEGAL_ARRAY,
    CURL_FORMADD_DISABLED,
    CURL_FORMADD_LAST
}
alias int CURLFORMcode;

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

/* linked-list structure for the CURLOPT_QUOTE option (and other) */
struct curl_slist
{
    char *data;
    curl_slist *next;
}

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

enum
{
    CURLINFO_NONE, 
    CURLINFO_EFFECTIVE_URL = 1048577,
    CURLINFO_RESPONSE_CODE = 2097154,
    CURLINFO_TOTAL_TIME = 3145731,
    CURLINFO_NAMELOOKUP_TIME,
    CURLINFO_CONNECT_TIME,
    CURLINFO_PRETRANSFER_TIME,
    CURLINFO_SIZE_UPLOAD,
    CURLINFO_SIZE_DOWNLOAD,
    CURLINFO_SPEED_DOWNLOAD,
    CURLINFO_SPEED_UPLOAD,
    CURLINFO_HEADER_SIZE = 2097163,
    CURLINFO_REQUEST_SIZE,
    CURLINFO_SSL_VERIFYRESULT,
    CURLINFO_FILETIME,
    CURLINFO_CONTENT_LENGTH_DOWNLOAD = 3145743,
    CURLINFO_CONTENT_LENGTH_UPLOAD,
    CURLINFO_STARTTRANSFER_TIME,
    CURLINFO_CONTENT_TYPE = 1048594,
    CURLINFO_REDIRECT_TIME = 3145747,
    CURLINFO_REDIRECT_COUNT = 2097172,
    CURLINFO_PRIVATE = 1048597,
    CURLINFO_HTTP_CONNECTCODE = 2097174,
    CURLINFO_HTTPAUTH_AVAIL,
    CURLINFO_PROXYAUTH_AVAIL,
    CURLINFO_OS_ERRNO,
    CURLINFO_NUM_CONNECTS,
    CURLINFO_SSL_ENGINES = 4194331,
    CURLINFO_COOKIELIST,
    CURLINFO_LASTSOCKET = 2097181,
    CURLINFO_FTP_ENTRY_PATH = 1048606,
    CURLINFO_REDIRECT_URL,
    CURLINFO_PRIMARY_IP,
    CURLINFO_APPCONNECT_TIME = 3145761,
    CURLINFO_CERTINFO = 4194338,
    CURLINFO_CONDITION_UNMET = 2097187,
    CURLINFO_RTSP_SESSION_ID = 1048612,
    CURLINFO_RTSP_CLIENT_CSEQ = 2097189,
    CURLINFO_RTSP_SERVER_CSEQ,
    CURLINFO_RTSP_CSEQ_RECV,
    CURLINFO_PRIMARY_PORT,
    CURLINFO_LOCAL_IP = 1048617,
    CURLINFO_LOCAL_PORT = 2097194,
    /* Fill in new entries below here! */
    CURLINFO_LASTONE = 42
}
alias int CURLINFO;

/* CURLINFO_RESPONSE_CODE is the new name for the option previously known as
   CURLINFO_HTTP_CODE */
alias CURLINFO_RESPONSE_CODE CURLINFO_HTTP_CODE;


enum
{
    CURLCLOSEPOLICY_NONE,
    CURLCLOSEPOLICY_OLDEST,
    CURLCLOSEPOLICY_LEAST_RECENTLY_USED,
    CURLCLOSEPOLICY_LEAST_TRAFFIC,
    CURLCLOSEPOLICY_SLOWEST,
    CURLCLOSEPOLICY_CALLBACK,
    CURLCLOSEPOLICY_LAST
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
enum
{
    CURL_LOCK_DATA_NONE,
    CURL_LOCK_DATA_SHARE,
    CURL_LOCK_DATA_COOKIE,
    CURL_LOCK_DATA_DNS,
    CURL_LOCK_DATA_SSL_SESSION,
    CURL_LOCK_DATA_CONNECT,
    CURL_LOCK_DATA_LAST
}
alias int curl_lock_data;

/* Different lock access types */
enum
{
    CURL_LOCK_ACCESS_NONE,
    CURL_LOCK_ACCESS_SHARED,
    CURL_LOCK_ACCESS_SINGLE,
    CURL_LOCK_ACCESS_LAST
}
alias int curl_lock_access;

alias void  function(CURL *handle, curl_lock_data data, curl_lock_access locktype, void *userptr)curl_lock_function;
alias void  function(CURL *handle, curl_lock_data data, void *userptr)curl_unlock_function;

alias void CURLSH;

enum
{
    CURLSHE_OK,
    CURLSHE_BAD_OPTION,
    CURLSHE_IN_USE,
    CURLSHE_INVALID,
    CURLSHE_NOMEM,
    CURLSHE_LAST
}
alias int CURLSHcode;

/* pass in a user data pointer used in the lock/unlock callback
   functions */
enum
{
    CURLSHOPT_NONE,
    CURLSHOPT_SHARE,
    CURLSHOPT_UNSHARE,
    CURLSHOPT_LOCKFUNC,
    CURLSHOPT_UNLOCKFUNC,
    CURLSHOPT_USERDATA,
    CURLSHOPT_LAST
}
alias int CURLSHoption;

CURLSH * curl_share_init();
CURLSHcode  curl_share_setopt(CURLSH *, CURLSHoption option,...);
CURLSHcode  curl_share_cleanup(CURLSH *);

/****************************************************************************
 * Structures for querying information about the curl library at runtime.
 */

enum
{
    CURLVERSION_FIRST,
    CURLVERSION_SECOND,
    CURLVERSION_THIRD,
    CURLVERSION_FOURTH,
    CURLVERSION_LAST
}
alias int CURLversion;

/* The 'CURLVERSION_NOW' is the symbolic name meant to be used by
   basically all programs ever that want to get version information. It is
   meant to be a built-in version number for what kind of struct the caller
   expects. If the struct ever changes, we redefine the NOW to another enum
   from above. */
alias CURLVERSION_FOURTH CURLVERSION_NOW;

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

enum
{
    CURLM_CALL_MULTI_PERFORM = -1, /* please call curl_multi_perform() or curl_multi_socket*() soon */
    CURLM_OK,     
    CURLM_BAD_HANDLE,              /* the passed-in handle is not a valid CURLM handle */	 
    CURLM_BAD_EASY_HANDLE,	   /* an easy handle was not good/valid */		 
    CURLM_OUT_OF_MEMORY,	   /* if you ever get this, you're in deep sh*t */	 
    CURLM_INTERNAL_ERROR,	   /* this is a libcurl bug */				 
    CURLM_BAD_SOCKET,		   /* the passed in socket argument did not match */	 
    CURLM_UNKNOWN_OPTION,	   /* curl_multi_setopt() with unsupported option */       
    CURLM_LAST,
}
alias int CURLMcode;

/* just to make code nicer when using curl_multi_socket() you can now check
   for CURLM_CALL_MULTI_SOCKET too in the same style it works for
   curl_multi_perform() and CURLM_CALL_MULTI_PERFORM */
alias CURLM_CALL_MULTI_PERFORM CURLM_CALL_MULTI_SOCKET;

enum
{
    CURLMSG_NONE,
    CURLMSG_DONE, /* This easy handle has completed. 'result' contains
		     the CURLcode of the transfer */
    CURLMSG_LAST, /* no used */
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

enum
{
    CURLMOPT_SOCKETFUNCTION = 20001,    /* This is the socket callback function pointer */	    
    CURLMOPT_SOCKETDATA = 10002,        /* This is the argument passed to the socket callback */  
    CURLMOPT_PIPELINING = 3,	        /* set to 1 to enable pipelining for this multi handle */ 
    CURLMOPT_TIMERFUNCTION = 20004,     /* This is the timer callback function pointer */	    
    CURLMOPT_TIMERDATA = 10005,	        /* This is the argument passed to the timer callback */   
    CURLMOPT_MAXCONNECTS = 6,	        /* maximum number of entries in the connection cache */   
    CURLMOPT_LASTENTRY,
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
