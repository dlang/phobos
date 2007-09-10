
extern (Windows)
{
    alias uint DWORD;
    alias int BOOL;
    alias int LONG;
    typedef void *HANDLE;

    DWORD GetTickCount();

const int MAX_PATH = 260;

enum
{
    FILE_BEGIN           = 0,
    FILE_CURRENT         = 1,
    FILE_END             = 2,
}

enum
{
    GENERIC_READ                     = 0x80000000,
    GENERIC_WRITE                    = 0x40000000,
    GENERIC_EXECUTE                  = 0x20000000,
    GENERIC_ALL                      = 0x10000000,
}

enum
{
    FILE_SHARE_READ                 = 0x00000001,
    FILE_SHARE_WRITE                = 0x00000002,
    FILE_SHARE_DELETE               = 0x00000004,  
    FILE_ATTRIBUTE_READONLY         = 0x00000001,  
    FILE_ATTRIBUTE_HIDDEN           = 0x00000002,  
    FILE_ATTRIBUTE_SYSTEM           = 0x00000004,  
    FILE_ATTRIBUTE_DIRECTORY        = 0x00000010,  
    FILE_ATTRIBUTE_ARCHIVE          = 0x00000020,  
    FILE_ATTRIBUTE_NORMAL           = 0x00000080,  
    FILE_ATTRIBUTE_TEMPORARY        = 0x00000100,  
    FILE_ATTRIBUTE_COMPRESSED       = 0x00000800,  
    FILE_ATTRIBUTE_OFFLINE          = 0x00001000,  
    FILE_NOTIFY_CHANGE_FILE_NAME    = 0x00000001,   
    FILE_NOTIFY_CHANGE_DIR_NAME     = 0x00000002,   
    FILE_NOTIFY_CHANGE_ATTRIBUTES   = 0x00000004,   
    FILE_NOTIFY_CHANGE_SIZE         = 0x00000008,   
    FILE_NOTIFY_CHANGE_LAST_WRITE   = 0x00000010,   
    FILE_NOTIFY_CHANGE_LAST_ACCESS  = 0x00000020,   
    FILE_NOTIFY_CHANGE_CREATION     = 0x00000040,   
    FILE_NOTIFY_CHANGE_SECURITY     = 0x00000100,   
    FILE_ACTION_ADDED               = 0x00000001,   
    FILE_ACTION_REMOVED             = 0x00000002,   
    FILE_ACTION_MODIFIED            = 0x00000003,   
    FILE_ACTION_RENAMED_OLD_NAME    = 0x00000004,   
    FILE_ACTION_RENAMED_NEW_NAME    = 0x00000005,   
    FILE_CASE_SENSITIVE_SEARCH      = 0x00000001,  
    FILE_CASE_PRESERVED_NAMES       = 0x00000002,  
    FILE_UNICODE_ON_DISK            = 0x00000004,  
    FILE_PERSISTENT_ACLS            = 0x00000008,  
    FILE_FILE_COMPRESSION           = 0x00000010,  
    FILE_VOLUME_IS_COMPRESSED       = 0x00008000,  
}

const DWORD MAILSLOT_NO_MESSAGE = (DWORD)-1;
const DWORD MAILSLOT_WAIT_FOREVER = (DWORD)-1; 

enum
{
    FILE_FLAG_WRITE_THROUGH         = 0x80000000,
    FILE_FLAG_OVERLAPPED            = 0x40000000,
    FILE_FLAG_NO_BUFFERING          = 0x20000000,
    FILE_FLAG_RANDOM_ACCESS         = 0x10000000,
    FILE_FLAG_SEQUENTIAL_SCAN       = 0x08000000,
    FILE_FLAG_DELETE_ON_CLOSE       = 0x04000000,
    FILE_FLAG_BACKUP_SEMANTICS      = 0x02000000,
    FILE_FLAG_POSIX_SEMANTICS       = 0x01000000,
}

enum
{
    CREATE_NEW          = 1,
    CREATE_ALWAYS       = 2,
    OPEN_EXISTING       = 3,
    OPEN_ALWAYS         = 4,
    TRUNCATE_EXISTING   = 5,
}

const HANDLE INVALID_HANDLE_VALUE = (HANDLE)-1;

struct OVERLAPPED {
    DWORD   Internal;
    DWORD   InternalHigh;
    DWORD   Offset;
    DWORD   OffsetHigh;
    HANDLE  hEvent;
}

struct SECURITY_ATTRIBUTES {
    DWORD nLength;
    void *lpSecurityDescriptor;
    BOOL bInheritHandle;
}

struct FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
}

struct WIN32_FIND_DATA {
    DWORD dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD nFileSizeHigh;
    DWORD nFileSizeLow;
    DWORD dwReserved0;
    DWORD dwReserved1;
    char   cFileName[ MAX_PATH ];
    char   cAlternateFileName[ 14 ];
}

BOOL CloseHandle(HANDLE hObject);

HANDLE CreateFileA(
    char *lpFileName,
    DWORD dwDesiredAccess,
    DWORD dwShareMode,
    SECURITY_ATTRIBUTES *lpSecurityAttributes,
    DWORD dwCreationDisposition,
    DWORD dwFlagsAndAttributes,
    HANDLE hTemplateFile
    );

BOOL DeleteFileA(char *lpFileName);

BOOL FindClose(HANDLE hFindFile);

HANDLE FindFirstFileA(
    char *lpFileName,
    out WIN32_FIND_DATA lpFindFileData
    );

BOOL FindNextFileA(
    HANDLE hFindFile,
    out WIN32_FIND_DATA lpFindFileData
    );

BOOL GetExitCodeThread(
    HANDLE hThread,
    DWORD *lpExitCode
    );

DWORD GetLastError();

DWORD GetFileAttributesA(char *lpFileName);

DWORD GetFileSize(
    HANDLE hFile,
    DWORD *lpFileSizeHigh
    );

BOOL MoveFileA(char *from, char *to);

BOOL ReadFile(
    HANDLE hFile,
    void *lpBuffer,
    DWORD nNumberOfBytesToRead,
    DWORD *lpNumberOfBytesRead,
    OVERLAPPED *lpOverlapped
    );

DWORD SetFilePointer(
    HANDLE hFile,
    LONG lDistanceToMove,
    LONG *lpDistanceToMoveHigh,
    DWORD dwMoveMethod
    );

BOOL WriteFile(
    HANDLE hFile,
    void *lpBuffer,
    DWORD nNumberOfBytesToWrite,
    DWORD *lpNumberOfBytesWritten,
    OVERLAPPED *lpOverlapped
    );


}
