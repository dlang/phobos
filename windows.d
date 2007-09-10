
extern (Windows)
{
    alias uint ULONG;
    alias ULONG *PULONG;
    alias ushort USHORT;
    alias USHORT *PUSHORT;
    alias ubyte UCHAR;
    alias UCHAR *PUCHAR;
    alias char *PSZ;
    alias wchar WCHAR;

    alias void VOID;
    alias char CHAR;
    alias short SHORT;
    alias int LONG;
    alias CHAR *LPSTR;
    alias CHAR *PSTR;
    alias CHAR *LPCSTR;
    alias CHAR *PCSTR;
    alias LPSTR LPTCH, PTCH;
    alias LPSTR PTSTR, LPTSTR;
    alias LPCSTR LPCTSTR;

    alias uint DWORD;
    alias int BOOL;
    alias ubyte BYTE;
    alias ushort WORD;
    alias float FLOAT;
    alias FLOAT *PFLOAT;
    alias BOOL *PBOOL;
    alias BOOL *LPBOOL;
    alias BYTE *PBYTE;
    alias BYTE *LPBYTE;
    alias int *PINT;
    alias int *LPINT;
    alias WORD *PWORD;
    alias WORD *LPWORD;
    alias int *LPLONG;
    alias DWORD *PDWORD;
    alias DWORD *LPDWORD;
    alias void *LPVOID;
    alias void *LPCVOID;

    alias int INT;
    alias uint UINT;
    alias uint *PUINT;

    typedef void *HANDLE;
    alias void *PVOID;
    alias HANDLE HGLOBAL;
    alias LONG HRESULT;
    alias LONG SCODE;
    alias HANDLE HINSTANCE;
    alias HINSTANCE HMODULE;
    alias HANDLE HWND;
    alias HANDLE HKEY;
    alias HKEY *PHKEY;
    alias DWORD ACCESS_MASK;
    alias ACCESS_MASK *PACCESS_MASK;
    alias ACCESS_MASK REGSAM;

    alias int (*FARPROC)();

    DWORD GetTickCount();

WORD HIWORD(int l) { return (WORD)((l >> 16) & 0xFFFF); }
WORD LOWORD(int l) { return (WORD)l; }
int FAILED(int status) { return status < 0; }
int SUCCEEDED(int Status) { return Status >= 0; }

enum : uint
{
    MAX_PATH = 260,
    HINSTANCE_ERROR = 32,
}

enum
{
	ERROR_SUCCESS =                    0,
}

enum
{
	DLL_PROCESS_ATTACH = 1,
	DLL_THREAD_ATTACH =  2,
	DLL_THREAD_DETACH =  3,
	DLL_PROCESS_DETACH = 0,
}

enum
{
    FILE_BEGIN           = 0,
    FILE_CURRENT         = 1,
    FILE_END             = 2,
}

enum
{
    DELETE =                           0x00010000,
    READ_CONTROL =                     0x00020000,
    WRITE_DAC =                        0x00040000,
    WRITE_OWNER =                      0x00080000,
    SYNCHRONIZE =                      0x00100000,

    STANDARD_RIGHTS_REQUIRED =         0x000F0000,
    STANDARD_RIGHTS_READ =             READ_CONTROL,
    STANDARD_RIGHTS_WRITE =            READ_CONTROL,
    STANDARD_RIGHTS_EXECUTE =          READ_CONTROL,
    STANDARD_RIGHTS_ALL =              0x001F0000,
    SPECIFIC_RIGHTS_ALL =              0x0000FFFF,
    ACCESS_SYSTEM_SECURITY =           0x01000000,
    MAXIMUM_ALLOWED =                  0x02000000,

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
    char   cFileName[MAX_PATH];
    char   cAlternateFileName[ 14 ];
}

export:


BOOL   CloseHandle(HANDLE hObject);
HANDLE CreateFileA(char *lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode,
	SECURITY_ATTRIBUTES *lpSecurityAttributes, DWORD dwCreationDisposition,
	DWORD dwFlagsAndAttributes, HANDLE hTemplateFile);
BOOL   DeleteFileA(char *lpFileName);
BOOL   FindClose(HANDLE hFindFile);
HANDLE FindFirstFileA(char *lpFileName, WIN32_FIND_DATA *lpFindFileData);
BOOL   FindNextFileA(HANDLE hFindFile, WIN32_FIND_DATA *lpFindFileData);
BOOL   GetExitCodeThread(HANDLE hThread, DWORD *lpExitCode);
DWORD  GetLastError();
DWORD  GetFileAttributesA(char *lpFileName);
DWORD  GetFileSize(HANDLE hFile, DWORD *lpFileSizeHigh);
BOOL   MoveFileA(char *from, char *to);
BOOL   ReadFile(HANDLE hFile, void *lpBuffer, DWORD nNumberOfBytesToRead,
	DWORD *lpNumberOfBytesRead, OVERLAPPED *lpOverlapped);
DWORD  SetFilePointer(HANDLE hFile, LONG lDistanceToMove,
	LONG *lpDistanceToMoveHigh, DWORD dwMoveMethod);
BOOL   WriteFile(HANDLE hFile, void *lpBuffer, DWORD nNumberOfBytesToWrite,
	DWORD *lpNumberOfBytesWritten, OVERLAPPED *lpOverlapped);
DWORD  GetModuleFileNameA(HMODULE hModule, LPSTR lpFilename, DWORD nSize);


export
{
 LONG  InterlockedIncrement(LPLONG lpAddend);
 LONG  InterlockedDecrement(LPLONG lpAddend);
 LONG  InterlockedExchange(LPLONG Target, LONG Value);
 LONG  InterlockedExchangeAdd(LPLONG Addend, LONG Value);
 PVOID InterlockedCompareExchange(PVOID *Destination, PVOID Exchange, PVOID Comperand);
 BOOL  FreeResource(HGLOBAL hResData);
 LPVOID LockResource(HGLOBAL hResData);
}

HMODULE LoadLibraryA(LPCSTR lpLibFileName);
FARPROC GetProcAddress(HMODULE hModule, LPCSTR lpProcName);

/*
 * MessageBox() Flags
 */
enum
{
	MB_OK =                       0x00000000,
	MB_OKCANCEL =                 0x00000001,
	MB_ABORTRETRYIGNORE =         0x00000002,
	MB_YESNOCANCEL =              0x00000003,
	MB_YESNO =                    0x00000004,
	MB_RETRYCANCEL =              0x00000005,


	MB_ICONHAND =                 0x00000010,
	MB_ICONQUESTION =             0x00000020,
	MB_ICONEXCLAMATION =          0x00000030,
	MB_ICONASTERISK =             0x00000040,


	MB_USERICON =                 0x00000080,
	MB_ICONWARNING =              MB_ICONEXCLAMATION,
	MB_ICONERROR =                MB_ICONHAND,


	MB_ICONINFORMATION =          MB_ICONASTERISK,
	MB_ICONSTOP =                 MB_ICONHAND,

	MB_DEFBUTTON1 =               0x00000000,
	MB_DEFBUTTON2 =               0x00000100,
	MB_DEFBUTTON3 =               0x00000200,

	MB_DEFBUTTON4 =               0x00000300,


	MB_APPLMODAL =                0x00000000,
	MB_SYSTEMMODAL =              0x00001000,
	MB_TASKMODAL =                0x00002000,

	MB_HELP =                     0x00004000, // Help Button


	MB_NOFOCUS =                  0x00008000,
	MB_SETFOREGROUND =            0x00010000,
	MB_DEFAULT_DESKTOP_ONLY =     0x00020000,


	MB_TOPMOST =                  0x00040000,
	MB_RIGHT =                    0x00080000,
	MB_RTLREADING =               0x00100000,


	MB_TYPEMASK =                 0x0000000F,
	MB_ICONMASK =                 0x000000F0,
	MB_DEFMASK =                  0x00000F00,
	MB_MODEMASK =                 0x00003000,
	MB_MISCMASK =                 0x0000C000,
}


int MessageBoxA(HWND hWnd, LPCSTR lpText, LPCSTR lpCaption, UINT uType);
int MessageBoxExA(HWND hWnd, LPCSTR lpText, LPCSTR lpCaption, UINT uType, WORD wLanguageId);

enum : HKEY
{
	HKEY_CLASSES_ROOT =           ((HKEY) 0x80000000),
	HKEY_CURRENT_USER =           ((HKEY) 0x80000001),
	HKEY_LOCAL_MACHINE =          ((HKEY) 0x80000002),
	HKEY_USERS =                  ((HKEY) 0x80000003),
	HKEY_PERFORMANCE_DATA =       ((HKEY) 0x80000004),

	HKEY_CURRENT_CONFIG =         ((HKEY) 0x80000005),
	HKEY_DYN_DATA =               ((HKEY) 0x80000006),
}

enum
{
	KEY_QUERY_VALUE =         (0x0001),
	KEY_SET_VALUE =           (0x0002),
	KEY_CREATE_SUB_KEY =      (0x0004),
	KEY_ENUMERATE_SUB_KEYS =  (0x0008),
	KEY_NOTIFY =              (0x0010),
	KEY_CREATE_LINK =         (0x0020),

	KEY_READ =                ((STANDARD_RIGHTS_READ | KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY) & (~SYNCHRONIZE)),
	KEY_WRITE =               ((STANDARD_RIGHTS_WRITE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY) & (~SYNCHRONIZE)),
	KEY_EXECUTE =             (KEY_READ & ~SYNCHRONIZE),
	KEY_ALL_ACCESS =          ((STANDARD_RIGHTS_ALL | KEY_QUERY_VALUE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY | KEY_CREATE_LINK) & (~SYNCHRONIZE)),
}

enum
{
	REG_OPTION_RESERVED =         (0x00000000),   // Parameter is reserved

	REG_OPTION_NON_VOLATILE =     (0x00000000),   // Key is preserved
                                                    // when system is rebooted

	REG_OPTION_VOLATILE =         (0x00000001),   // Key is not preserved
                                                    // when system is rebooted

	REG_OPTION_CREATE_LINK =      (0x00000002),   // Created key is a
                                                    // symbolic link

	REG_OPTION_BACKUP_RESTORE =   (0x00000004),   // open for backup or restore
                                                    // special access rules
                                                    // privilege required

	REG_OPTION_OPEN_LINK =        (0x00000008),   // Open symbolic link

	REG_LEGAL_OPTION = (REG_OPTION_RESERVED | REG_OPTION_NON_VOLATILE | REG_OPTION_VOLATILE | REG_OPTION_CREATE_LINK | REG_OPTION_BACKUP_RESTORE | REG_OPTION_OPEN_LINK),
}

enum
{
	REG_NONE =                    ( 0 ),   // No value type
	REG_SZ =                      ( 1 ),   // Unicode nul terminated string
	REG_EXPAND_SZ =               ( 2 ),   // Unicode nul terminated string
                                            // (with environment variable references)
	REG_BINARY =                  ( 3 ),   // Free form binary
	REG_DWORD =                   ( 4 ),   // 32-bit number
	REG_DWORD_LITTLE_ENDIAN =     ( 4 ),   // 32-bit number (same as REG_DWORD)
	REG_DWORD_BIG_ENDIAN =        ( 5 ),   // 32-bit number
	REG_LINK =                    ( 6 ),   // Symbolic Link (unicode)
	REG_MULTI_SZ =                ( 7 ),   // Multiple Unicode strings
	REG_RESOURCE_LIST =           ( 8 ),   // Resource list in the resource map
	REG_FULL_RESOURCE_DESCRIPTOR = ( 9 ),  // Resource list in the hardware description
	REG_RESOURCE_REQUIREMENTS_LIST = ( 10 ),
}

export LONG  RegDeleteKeyA(HKEY hKey, LPCSTR lpSubKey);
export LONG  RegCloseKey(HKEY hKey);

export LONG RegCreateKeyExA(HKEY hKey, LPCSTR lpSubKey, DWORD Reserved, LPSTR lpClass,
    DWORD dwOptions, REGSAM samDesired, SECURITY_ATTRIBUTES* lpSecurityAttributes,
    PHKEY phkResult, LPDWORD lpdwDisposition);

export LONG RegSetValueExA(HKEY hKey, LPCSTR lpValueName, DWORD Reserved, DWORD dwType, BYTE* lpData, DWORD cbData);

}
