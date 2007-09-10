
module std.c.windows.windows;

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

    alias WCHAR* LPWSTR, LPCWSTR, PCWSTR;

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

    alias HANDLE HGDIOBJ;
    alias HANDLE HACCEL;
    alias HANDLE HBITMAP;
    alias HANDLE HBRUSH;
    alias HANDLE HCOLORSPACE;
    alias HANDLE HDC;
    alias HANDLE HGLRC;
    alias HANDLE HDESK;
    alias HANDLE HENHMETAFILE;
    alias HANDLE HFONT;
    alias HANDLE HICON;
    alias HANDLE HMENU;
    alias HANDLE HMETAFILE;
    alias HANDLE HPALETTE;
    alias HANDLE HPEN;
    alias HANDLE HRGN;
    alias HANDLE HRSRC;
    alias HANDLE HSTR;
    alias HANDLE HTASK;
    alias HANDLE HWINSTA;
    alias HANDLE HKL;
    alias HICON HCURSOR;

    alias HANDLE HKEY;
    alias HKEY *PHKEY;
    alias DWORD ACCESS_MASK;
    alias ACCESS_MASK *PACCESS_MASK;
    alias ACCESS_MASK REGSAM;

    alias int (*FARPROC)();

    alias UINT WPARAM;
    alias LONG LPARAM;
    alias LONG LRESULT;

    alias DWORD   COLORREF;
    alias DWORD   *LPCOLORREF;
    alias WORD    ATOM;


WORD HIWORD(int l) { return (WORD)((l >> 16) & 0xFFFF); }
WORD LOWORD(int l) { return (WORD)l; }
int FAILED(int status) { return status < 0; }
int SUCCEEDED(int Status) { return Status >= 0; }

enum : int
{
    FALSE = 0,
    TRUE = 1,
}

enum : uint
{
    MAX_PATH = 260,
    HINSTANCE_ERROR = 32,
}

enum
{
	ERROR_SUCCESS =                    0,
	ERROR_INVALID_FUNCTION =           1,
	ERROR_FILE_NOT_FOUND =             2,
	ERROR_PATH_NOT_FOUND =             3,
	ERROR_TOO_MANY_OPEN_FILES =        4,
	ERROR_ACCESS_DENIED =              5,
	ERROR_INVALID_HANDLE =             6,
	ERROR_NO_MORE_FILES =              18,
	ERROR_MORE_DATA =		   234,
	ERROR_NO_MORE_ITEMS =		   259,
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

enum : uint
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

enum : uint
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

alias SECURITY_ATTRIBUTES* PSECURITY_ATTRIBUTES, LPSECURITY_ATTRIBUTES;

struct FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
}
alias FILETIME* PFILETIME;

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

struct WIN32_FIND_DATAW {
    DWORD dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD nFileSizeHigh;
    DWORD nFileSizeLow;
    DWORD dwReserved0;
    DWORD dwReserved1;
    WCHAR  cFileName[ 260  ];
    WCHAR  cAlternateFileName[ 14 ];
}

export
{
BOOL SetCurrentDirectoryA(LPCSTR lpPathName);
BOOL SetCurrentDirectoryW(LPCWSTR lpPathName);
DWORD GetCurrentDirectoryA(DWORD nBufferLength, LPSTR lpBuffer);
DWORD GetCurrentDirectoryW(DWORD nBufferLength, LPWSTR lpBuffer);
BOOL CreateDirectoryA(LPCSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
BOOL CreateDirectoryW(LPCWSTR lpPathName, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
BOOL CreateDirectoryExA(LPCSTR lpTemplateDirectory, LPCSTR lpNewDirectory, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
BOOL CreateDirectoryExW(LPCWSTR lpTemplateDirectory, LPCWSTR lpNewDirectory, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
BOOL RemoveDirectoryA(LPCSTR lpPathName);
BOOL RemoveDirectoryW(LPCWSTR lpPathName);

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
}


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

//
// Registry Specific Access Rights.
//

enum
{
	KEY_QUERY_VALUE =         0x0001,
	KEY_SET_VALUE =           0x0002,
	KEY_CREATE_SUB_KEY =      0x0004,
	KEY_ENUMERATE_SUB_KEYS =  0x0008,
	KEY_NOTIFY =              0x0010,
	KEY_CREATE_LINK =         0x0020,

	KEY_READ =       ((STANDARD_RIGHTS_READ | KEY_QUERY_VALUE | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY)   & ~SYNCHRONIZE),
	KEY_WRITE =      ((STANDARD_RIGHTS_WRITE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY) & ~SYNCHRONIZE),
	KEY_EXECUTE =    (KEY_READ & ~SYNCHRONIZE),
	KEY_ALL_ACCESS = ((STANDARD_RIGHTS_ALL | KEY_QUERY_VALUE | KEY_SET_VALUE | KEY_CREATE_SUB_KEY | KEY_ENUMERATE_SUB_KEYS | KEY_NOTIFY | KEY_CREATE_LINK) & ~SYNCHRONIZE),
}

//
// Key creation/open disposition
//

const int REG_CREATED_NEW_KEY =         0x00000001;   // New Registry Key created
const int REG_OPENED_EXISTING_KEY =     0x00000002;   // Existing Key opened


//
//
// Predefined Value Types.
//
enum
{
	REG_NONE =                    0,   // No value type
	REG_SZ =                      1,   // Unicode nul terminated string
	REG_EXPAND_SZ =               2,   // Unicode nul terminated string
                                            // (with environment variable references)
	REG_BINARY =                  3,   // Free form binary
	REG_DWORD =                   4,   // 32-bit number
	REG_DWORD_LITTLE_ENDIAN =     4,   // 32-bit number (same as REG_DWORD)
	REG_DWORD_BIG_ENDIAN =        5,   // 32-bit number
	REG_LINK =                    6,   // Symbolic Link (unicode)
	REG_MULTI_SZ =                7,   // Multiple Unicode strings
	REG_RESOURCE_LIST =           8,   // Resource list in the resource map
	REG_FULL_RESOURCE_DESCRIPTOR = 9,  // Resource list in the hardware description
	REG_RESOURCE_REQUIREMENTS_LIST = 10,
	REG_QWORD =			11,
	REG_QWORD_LITTLE_ENDIAN =	11,
}

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

export LONG RegDeleteKeyA(HKEY hKey, LPCSTR lpSubKey);
export LONG RegDeleteValueA(HKEY hKey, LPCSTR lpValueName);

export LONG  RegEnumKeyExA(HKEY hKey, DWORD dwIndex, LPSTR lpName, LPDWORD lpcbName, LPDWORD lpReserved, LPSTR lpClass, LPDWORD lpcbClass, FILETIME* lpftLastWriteTime);
export LONG RegEnumValueA(HKEY hKey, DWORD dwIndex, LPSTR lpValueName, LPDWORD lpcbValueName, LPDWORD lpReserved,
    LPDWORD lpType, LPBYTE lpData, LPDWORD lpcbData);

export LONG RegCloseKey(HKEY hKey);
export LONG RegFlushKey(HKEY hKey);

export LONG RegOpenKeyA(HKEY hKey, LPCSTR lpSubKey, PHKEY phkResult);
export LONG RegOpenKeyExA(HKEY hKey, LPCSTR lpSubKey, DWORD ulOptions, REGSAM samDesired, PHKEY phkResult);

export LONG RegQueryInfoKeyA(HKEY hKey, LPSTR lpClass, LPDWORD lpcbClass,
    LPDWORD lpReserved, LPDWORD lpcSubKeys, LPDWORD lpcbMaxSubKeyLen, LPDWORD lpcbMaxClassLen,
    LPDWORD lpcValues, LPDWORD lpcbMaxValueNameLen, LPDWORD lpcbMaxValueLen, LPDWORD lpcbSecurityDescriptor,
    PFILETIME lpftLastWriteTime);

export LONG RegQueryValueA(HKEY hKey, LPCSTR lpSubKey, LPSTR lpValue,
    LPLONG lpcbValue);

export LONG RegCreateKeyExA(HKEY hKey, LPCSTR lpSubKey, DWORD Reserved, LPSTR lpClass,
   DWORD dwOptions, REGSAM samDesired, SECURITY_ATTRIBUTES* lpSecurityAttributes,
    PHKEY phkResult, LPDWORD lpdwDisposition);

export LONG RegSetValueExA(HKEY hKey, LPCSTR lpValueName, DWORD Reserved, DWORD dwType, BYTE* lpData, DWORD cbData);

struct MEMORY_BASIC_INFORMATION {
    PVOID BaseAddress;
    PVOID AllocationBase;
    DWORD AllocationProtect;
    DWORD RegionSize;
    DWORD State;
    DWORD Protect;
    DWORD Type;
}
alias MEMORY_BASIC_INFORMATION* PMEMORY_BASIC_INFORMATION;

enum
{
	SECTION_QUERY       = 0x0001,
	SECTION_MAP_WRITE   = 0x0002,
	SECTION_MAP_READ    = 0x0004,
	SECTION_MAP_EXECUTE = 0x0008,
	SECTION_EXTEND_SIZE = 0x0010,

	SECTION_ALL_ACCESS = (STANDARD_RIGHTS_REQUIRED|SECTION_QUERY| SECTION_MAP_WRITE | SECTION_MAP_READ | SECTION_MAP_EXECUTE | SECTION_EXTEND_SIZE),
	PAGE_NOACCESS          = 0x01,
	PAGE_READONLY          = 0x02,
	PAGE_READWRITE         = 0x04,
	PAGE_WRITECOPY         = 0x08,
	PAGE_EXECUTE           = 0x10,
	PAGE_EXECUTE_READ      = 0x20,
	PAGE_EXECUTE_READWRITE = 0x40,
	PAGE_EXECUTE_WRITECOPY = 0x80,
	PAGE_GUARD            = 0x100,
	PAGE_NOCACHE          = 0x200,
	MEM_COMMIT           = 0x1000,
	MEM_RESERVE          = 0x2000,
	MEM_DECOMMIT         = 0x4000,
	MEM_RELEASE          = 0x8000,
	MEM_FREE            = 0x10000,
	MEM_PRIVATE         = 0x20000,
	MEM_MAPPED          = 0x40000,
	MEM_RESET           = 0x80000,
	MEM_TOP_DOWN       = 0x100000,
	SEC_FILE           = 0x800000,
	SEC_IMAGE         = 0x1000000,
	SEC_RESERVE       = 0x4000000,
	SEC_COMMIT        = 0x8000000,
	SEC_NOCACHE      = 0x10000000,
	MEM_IMAGE        = SEC_IMAGE,
}

//
// Define access rights to files and directories
//

//
// The FILE_READ_DATA and FILE_WRITE_DATA constants are also defined in
// devioctl.h as FILE_READ_ACCESS and FILE_WRITE_ACCESS. The values for these
// constants *MUST* always be in sync.
// The values are redefined in devioctl.h because they must be available to
// both DOS and NT.
//

enum
{
	FILE_READ_DATA =            ( 0x0001 ),   // file & pipe
	FILE_LIST_DIRECTORY =       ( 0x0001 ),    // directory

	FILE_WRITE_DATA =           ( 0x0002 ),    // file & pipe
	FILE_ADD_FILE =             ( 0x0002 ),    // directory

	FILE_APPEND_DATA =          ( 0x0004 ),    // file
	FILE_ADD_SUBDIRECTORY =     ( 0x0004 ),    // directory
	FILE_CREATE_PIPE_INSTANCE = ( 0x0004 ),    // named pipe

	FILE_READ_EA =              ( 0x0008 ),    // file & directory

	FILE_WRITE_EA =             ( 0x0010 ),    // file & directory

	FILE_EXECUTE =              ( 0x0020 ),    // file
	FILE_TRAVERSE =             ( 0x0020 ),    // directory

	FILE_DELETE_CHILD =         ( 0x0040 ),    // directory

	FILE_READ_ATTRIBUTES =      ( 0x0080 ),    // all

	FILE_WRITE_ATTRIBUTES =     ( 0x0100 ),    // all

	FILE_ALL_ACCESS = (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0x1FF),

	FILE_GENERIC_READ =         (STANDARD_RIGHTS_READ  | FILE_READ_DATA |  FILE_READ_ATTRIBUTES |                 FILE_READ_EA |  SYNCHRONIZE),


	FILE_GENERIC_WRITE =        (STANDARD_RIGHTS_WRITE | FILE_WRITE_DATA |  FILE_WRITE_ATTRIBUTES |                      FILE_WRITE_EA  |  FILE_APPEND_DATA |  SYNCHRONIZE),


	FILE_GENERIC_EXECUTE =      (STANDARD_RIGHTS_EXECUTE | FILE_READ_ATTRIBUTES |                 FILE_EXECUTE |  SYNCHRONIZE),
}

export
{
 LPVOID VirtualAlloc(LPVOID lpAddress, DWORD dwSize, DWORD flAllocationType, DWORD flProtect);
 BOOL VirtualFree(LPVOID lpAddress, DWORD dwSize, DWORD dwFreeType);
 BOOL VirtualProtect(LPVOID lpAddress, DWORD dwSize, DWORD flNewProtect, PDWORD lpflOldProtect);
 DWORD VirtualQuery(LPCVOID lpAddress, PMEMORY_BASIC_INFORMATION lpBuffer, DWORD dwLength);
 LPVOID VirtualAllocEx(HANDLE hProcess, LPVOID lpAddress, DWORD dwSize, DWORD flAllocationType, DWORD flProtect);
 BOOL VirtualFreeEx(HANDLE hProcess, LPVOID lpAddress, DWORD dwSize, DWORD dwFreeType);
 BOOL VirtualProtectEx(HANDLE hProcess, LPVOID lpAddress, DWORD dwSize, DWORD flNewProtect, PDWORD lpflOldProtect);
 DWORD VirtualQueryEx(HANDLE hProcess, LPCVOID lpAddress, PMEMORY_BASIC_INFORMATION lpBuffer, DWORD dwLength);
}

struct SYSTEMTIME
{
    WORD wYear;
    WORD wMonth;
    WORD wDayOfWeek;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wMilliseconds;
}

struct TIME_ZONE_INFORMATION {
    LONG Bias;
    WCHAR StandardName[ 32 ];
    SYSTEMTIME StandardDate;
    LONG StandardBias;
    WCHAR DaylightName[ 32 ];
    SYSTEMTIME DaylightDate;
    LONG DaylightBias;
}

enum
{
	TIME_ZONE_ID_UNKNOWN =  0,
	TIME_ZONE_ID_STANDARD = 1,
	TIME_ZONE_ID_DAYLIGHT = 2,
}

export void GetSystemTime(SYSTEMTIME* lpSystemTime);
export void GetSystemTimeAsFileTime(FILETIME* lpSystemTimeAsFileTime);
export BOOL SetSystemTime(SYSTEMTIME* lpSystemTime);
export void GetLocalTime(SYSTEMTIME* lpSystemTime);
export BOOL SetLocalTime(SYSTEMTIME* lpSystemTime);
export BOOL SystemTimeToTzSpecificLocalTime(TIME_ZONE_INFORMATION* lpTimeZoneInformation, SYSTEMTIME* lpUniversalTime, SYSTEMTIME* lpLocalTime);
export DWORD GetTimeZoneInformation(TIME_ZONE_INFORMATION* lpTimeZoneInformation);
export BOOL SetTimeZoneInformation(TIME_ZONE_INFORMATION* lpTimeZoneInformation);

export BOOL SystemTimeToFileTime(SYSTEMTIME *lpSystemTime, FILETIME* lpFileTime);
export BOOL FileTimeToLocalFileTime(FILETIME *lpFileTime, FILETIME* lpLocalFileTime);
export BOOL LocalFileTimeToFileTime(FILETIME *lpLocalFileTime, FILETIME* lpFileTime);
export BOOL FileTimeToSystemTime(FILETIME *lpFileTime, SYSTEMTIME* lpSystemTime);
export LONG CompareFileTime(FILETIME *lpFileTime1, FILETIME *lpFileTime2);
export BOOL FileTimeToDosDateTime(FILETIME *lpFileTime, WORD* lpFatDate, WORD* lpFatTime);
export BOOL DosDateTimeToFileTime(WORD wFatDate, WORD wFatTime, FILETIME* lpFileTime);
export DWORD GetTickCount();
export BOOL SetSystemTimeAdjustment(DWORD dwTimeAdjustment, BOOL bTimeAdjustmentDisabled);
export BOOL GetSystemTimeAdjustment(DWORD* lpTimeAdjustment, DWORD* lpTimeIncrement, BOOL* lpTimeAdjustmentDisabled);

struct FLOATING_SAVE_AREA {
    DWORD   ControlWord;
    DWORD   StatusWord;
    DWORD   TagWord;
    DWORD   ErrorOffset;
    DWORD   ErrorSelector;
    DWORD   DataOffset;
    DWORD   DataSelector;
    BYTE    RegisterArea[80 ];
    DWORD   Cr0NpxState;
}

enum
{
	SIZE_OF_80387_REGISTERS =      80,
//
// The following flags control the contents of the CONTEXT structure.
//
	CONTEXT_i386 =    0x00010000,    // this assumes that i386 and
	CONTEXT_i486 =    0x00010000,    // i486 have identical context records

	CONTEXT_CONTROL =         (CONTEXT_i386 | 0x00000001), // SS:SP, CS:IP, FLAGS, BP
	CONTEXT_INTEGER =         (CONTEXT_i386 | 0x00000002), // AX, BX, CX, DX, SI, DI
	CONTEXT_SEGMENTS =        (CONTEXT_i386 | 0x00000004), // DS, ES, FS, GS
	CONTEXT_FLOATING_POINT =  (CONTEXT_i386 | 0x00000008), // 387 state
	CONTEXT_DEBUG_REGISTERS = (CONTEXT_i386 | 0x00000010), // DB 0-3,6,7

	CONTEXT_FULL = (CONTEXT_CONTROL | CONTEXT_INTEGER | CONTEXT_SEGMENTS),
}

struct CONTEXT
{

    //
    // The flags values within this flag control the contents of
    // a CONTEXT record.
    //
    // If the context record is used as an input parameter, then
    // for each portion of the context record controlled by a flag
    // whose value is set, it is assumed that that portion of the
    // context record contains valid context. If the context record
    // is being used to modify a threads context, then only that
    // portion of the threads context will be modified.
    //
    // If the context record is used as an IN OUT parameter to capture
    // the context of a thread, then only those portions of the thread's
    // context corresponding to set flags will be returned.
    //
    // The context record is never used as an OUT only parameter.
    //

    DWORD ContextFlags;

    //
    // This section is specified/returned if CONTEXT_DEBUG_REGISTERS is
    // set in ContextFlags.  Note that CONTEXT_DEBUG_REGISTERS is NOT
    // included in CONTEXT_FULL.
    //

    DWORD   Dr0;
    DWORD   Dr1;
    DWORD   Dr2;
    DWORD   Dr3;
    DWORD   Dr6;
    DWORD   Dr7;

    //
    // This section is specified/returned if the
    // ContextFlags word contians the flag CONTEXT_FLOATING_POINT.
    //

    FLOATING_SAVE_AREA FloatSave;

    //
    // This section is specified/returned if the
    // ContextFlags word contians the flag CONTEXT_SEGMENTS.
    //

    DWORD   SegGs;
    DWORD   SegFs;
    DWORD   SegEs;
    DWORD   SegDs;

    //
    // This section is specified/returned if the
    // ContextFlags word contians the flag CONTEXT_INTEGER.
    //

    DWORD   Edi;
    DWORD   Esi;
    DWORD   Ebx;
    DWORD   Edx;
    DWORD   Ecx;
    DWORD   Eax;

    //
    // This section is specified/returned if the
    // ContextFlags word contians the flag CONTEXT_CONTROL.
    //

    DWORD   Ebp;
    DWORD   Eip;
    DWORD   SegCs;              // MUST BE SANITIZED
    DWORD   EFlags;             // MUST BE SANITIZED
    DWORD   Esp;
    DWORD   SegSs;
}

enum
{
	THREAD_BASE_PRIORITY_LOWRT =  15,  // value that gets a thread to LowRealtime-1
	THREAD_BASE_PRIORITY_MAX =    2,   // maximum thread base priority boost
	THREAD_BASE_PRIORITY_MIN =    -2,  // minimum thread base priority boost
	THREAD_BASE_PRIORITY_IDLE =   -15, // value that gets a thread to idle

	THREAD_PRIORITY_LOWEST =          THREAD_BASE_PRIORITY_MIN,
	THREAD_PRIORITY_BELOW_NORMAL =    (THREAD_PRIORITY_LOWEST+1),
	THREAD_PRIORITY_NORMAL =          0,
	THREAD_PRIORITY_HIGHEST =         THREAD_BASE_PRIORITY_MAX,
	THREAD_PRIORITY_ABOVE_NORMAL =    (THREAD_PRIORITY_HIGHEST-1),
	THREAD_PRIORITY_ERROR_RETURN =    int.max,

	THREAD_PRIORITY_TIME_CRITICAL =   THREAD_BASE_PRIORITY_LOWRT,
	THREAD_PRIORITY_IDLE =            THREAD_BASE_PRIORITY_IDLE,
}

export HANDLE GetCurrentThread();
export BOOL DuplicateHandle (HANDLE sourceProcess, HANDLE sourceThread,
        HANDLE targetProcessHandle, HANDLE *targetHandle, DWORD access, 
        BOOL inheritHandle, DWORD options);
export DWORD GetCurrentThreadId();
export BOOL SetThreadPriority(HANDLE hThread, int nPriority);
export BOOL SetThreadPriorityBoost(HANDLE hThread, BOOL bDisablePriorityBoost);
export BOOL GetThreadPriorityBoost(HANDLE hThread, PBOOL pDisablePriorityBoost);
export int GetThreadPriority(HANDLE hThread);
export BOOL GetThreadContext(HANDLE hThread, CONTEXT* lpContext);
export BOOL SetThreadContext(HANDLE hThread, CONTEXT* lpContext);
export DWORD SuspendThread(HANDLE hThread);
export DWORD ResumeThread(HANDLE hThread);
export DWORD WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds);
export DWORD WaitForMultipleObjects(DWORD nCount, HANDLE *lpHandles, BOOL bWaitAll, DWORD dwMilliseconds);
export void Sleep(DWORD dwMilliseconds);

enum
{
	WM_NOTIFY =                       0x004E,
	WM_INPUTLANGCHANGEREQUEST =       0x0050,
	WM_INPUTLANGCHANGE =              0x0051,
	WM_TCARD =                        0x0052,
	WM_HELP =                         0x0053,
	WM_USERCHANGED =                  0x0054,
	WM_NOTIFYFORMAT =                 0x0055,

	NFR_ANSI =                             1,
	NFR_UNICODE =                          2,
	NF_QUERY =                             3,
	NF_REQUERY =                           4,

	WM_CONTEXTMENU =                  0x007B,
	WM_STYLECHANGING =                0x007C,
	WM_STYLECHANGED =                 0x007D,
	WM_DISPLAYCHANGE =                0x007E,
	WM_GETICON =                      0x007F,
	WM_SETICON =                      0x0080,



	WM_NCCREATE =                     0x0081,
	WM_NCDESTROY =                    0x0082,
	WM_NCCALCSIZE =                   0x0083,
	WM_NCHITTEST =                    0x0084,
	WM_NCPAINT =                      0x0085,
	WM_NCACTIVATE =                   0x0086,
	WM_GETDLGCODE =                   0x0087,

	WM_NCMOUSEMOVE =                  0x00A0,
	WM_NCLBUTTONDOWN =                0x00A1,
	WM_NCLBUTTONUP =                  0x00A2,
	WM_NCLBUTTONDBLCLK =              0x00A3,
	WM_NCRBUTTONDOWN =                0x00A4,
	WM_NCRBUTTONUP =                  0x00A5,
	WM_NCRBUTTONDBLCLK =              0x00A6,
	WM_NCMBUTTONDOWN =                0x00A7,
	WM_NCMBUTTONUP =                  0x00A8,
	WM_NCMBUTTONDBLCLK =              0x00A9,

	WM_KEYFIRST =                     0x0100,
	WM_KEYDOWN =                      0x0100,
	WM_KEYUP =                        0x0101,
	WM_CHAR =                         0x0102,
	WM_DEADCHAR =                     0x0103,
	WM_SYSKEYDOWN =                   0x0104,
	WM_SYSKEYUP =                     0x0105,
	WM_SYSCHAR =                      0x0106,
	WM_SYSDEADCHAR =                  0x0107,
	WM_KEYLAST =                      0x0108,


	WM_IME_STARTCOMPOSITION =         0x010D,
	WM_IME_ENDCOMPOSITION =           0x010E,
	WM_IME_COMPOSITION =              0x010F,
	WM_IME_KEYLAST =                  0x010F,


	WM_INITDIALOG =                   0x0110,
	WM_COMMAND =                      0x0111,
	WM_SYSCOMMAND =                   0x0112,
	WM_TIMER =                        0x0113,
	WM_HSCROLL =                      0x0114,
	WM_VSCROLL =                      0x0115,
	WM_INITMENU =                     0x0116,
	WM_INITMENUPOPUP =                0x0117,
	WM_MENUSELECT =                   0x011F,
	WM_MENUCHAR =                     0x0120,
	WM_ENTERIDLE =                    0x0121,

	WM_CTLCOLORMSGBOX =               0x0132,
	WM_CTLCOLOREDIT =                 0x0133,
	WM_CTLCOLORLISTBOX =              0x0134,
	WM_CTLCOLORBTN =                  0x0135,
	WM_CTLCOLORDLG =                  0x0136,
	WM_CTLCOLORSCROLLBAR =            0x0137,
	WM_CTLCOLORSTATIC =               0x0138,



	WM_MOUSEFIRST =                   0x0200,
	WM_MOUSEMOVE =                    0x0200,
	WM_LBUTTONDOWN =                  0x0201,
	WM_LBUTTONUP =                    0x0202,
	WM_LBUTTONDBLCLK =                0x0203,
	WM_RBUTTONDOWN =                  0x0204,
	WM_RBUTTONUP =                    0x0205,
	WM_RBUTTONDBLCLK =                0x0206,
	WM_MBUTTONDOWN =                  0x0207,
	WM_MBUTTONUP =                    0x0208,
	WM_MBUTTONDBLCLK =                0x0209,



	WM_MOUSELAST =                    0x0209,








	WM_PARENTNOTIFY =                 0x0210,
	MENULOOP_WINDOW =                 0,
	MENULOOP_POPUP =                  1,
	WM_ENTERMENULOOP =                0x0211,
	WM_EXITMENULOOP =                 0x0212,


	WM_NEXTMENU =                     0x0213,
}

enum
{
/*
 * Dialog Box Command IDs
 */
	IDOK =                1,
	IDCANCEL =            2,
	IDABORT =             3,
	IDRETRY =             4,
	IDIGNORE =            5,
	IDYES =               6,
	IDNO =                7,

	IDCLOSE =         8,
	IDHELP =          9,


// end_r_winuser



/*
 * Control Manager Structures and Definitions
 */



// begin_r_winuser

/*
 * Edit Control Styles
 */
	ES_LEFT =             0x0000,
	ES_CENTER =           0x0001,
	ES_RIGHT =            0x0002,
	ES_MULTILINE =        0x0004,
	ES_UPPERCASE =        0x0008,
	ES_LOWERCASE =        0x0010,
	ES_PASSWORD =         0x0020,
	ES_AUTOVSCROLL =      0x0040,
	ES_AUTOHSCROLL =      0x0080,
	ES_NOHIDESEL =        0x0100,
	ES_OEMCONVERT =       0x0400,
	ES_READONLY =         0x0800,
	ES_WANTRETURN =       0x1000,

	ES_NUMBER =           0x2000,


// end_r_winuser



/*
 * Edit Control Notification Codes
 */
	EN_SETFOCUS =         0x0100,
	EN_KILLFOCUS =        0x0200,
	EN_CHANGE =           0x0300,
	EN_UPDATE =           0x0400,
	EN_ERRSPACE =         0x0500,
	EN_MAXTEXT =          0x0501,
	EN_HSCROLL =          0x0601,
	EN_VSCROLL =          0x0602,


/* Edit control EM_SETMARGIN parameters */
	EC_LEFTMARGIN =       0x0001,
	EC_RIGHTMARGIN =      0x0002,
	EC_USEFONTINFO =      0xffff,




// begin_r_winuser

/*
 * Edit Control Messages
 */
	EM_GETSEL =               0x00B0,
	EM_SETSEL =               0x00B1,
	EM_GETRECT =              0x00B2,
	EM_SETRECT =              0x00B3,
	EM_SETRECTNP =            0x00B4,
	EM_SCROLL =               0x00B5,
	EM_LINESCROLL =           0x00B6,
	EM_SCROLLCARET =          0x00B7,
	EM_GETMODIFY =            0x00B8,
	EM_SETMODIFY =            0x00B9,
	EM_GETLINECOUNT =         0x00BA,
	EM_LINEINDEX =            0x00BB,
	EM_SETHANDLE =            0x00BC,
	EM_GETHANDLE =            0x00BD,
	EM_GETTHUMB =             0x00BE,
	EM_LINELENGTH =           0x00C1,
	EM_REPLACESEL =           0x00C2,
	EM_GETLINE =              0x00C4,
	EM_LIMITTEXT =            0x00C5,
	EM_CANUNDO =              0x00C6,
	EM_UNDO =                 0x00C7,
	EM_FMTLINES =             0x00C8,
	EM_LINEFROMCHAR =         0x00C9,
	EM_SETTABSTOPS =          0x00CB,
	EM_SETPASSWORDCHAR =      0x00CC,
	EM_EMPTYUNDOBUFFER =      0x00CD,
	EM_GETFIRSTVISIBLELINE =  0x00CE,
	EM_SETREADONLY =          0x00CF,
	EM_SETWORDBREAKPROC =     0x00D0,
	EM_GETWORDBREAKPROC =     0x00D1,
	EM_GETPASSWORDCHAR =      0x00D2,

	EM_SETMARGINS =           0x00D3,
	EM_GETMARGINS =           0x00D4,
	EM_SETLIMITTEXT =         EM_LIMITTEXT, /* ;win40 Name change */
	EM_GETLIMITTEXT =         0x00D5,
	EM_POSFROMCHAR =          0x00D6,
	EM_CHARFROMPOS =          0x00D7,



// end_r_winuser


/*
 * EDITWORDBREAKPROC code values
 */
	WB_LEFT =            0,
	WB_RIGHT =           1,
	WB_ISDELIMITER =     2,

// begin_r_winuser

/*
 * Button Control Styles
 */
	BS_PUSHBUTTON =       0x00000000,
	BS_DEFPUSHBUTTON =    0x00000001,
	BS_CHECKBOX =         0x00000002,
	BS_AUTOCHECKBOX =     0x00000003,
	BS_RADIOBUTTON =      0x00000004,
	BS_3STATE =           0x00000005,
	BS_AUTO3STATE =       0x00000006,
	BS_GROUPBOX =         0x00000007,
	BS_USERBUTTON =       0x00000008,
	BS_AUTORADIOBUTTON =  0x00000009,
	BS_OWNERDRAW =        0x0000000B,
	BS_LEFTTEXT =         0x00000020,

	BS_TEXT =             0x00000000,
	BS_ICON =             0x00000040,
	BS_BITMAP =           0x00000080,
	BS_LEFT =             0x00000100,
	BS_RIGHT =            0x00000200,
	BS_CENTER =           0x00000300,
	BS_TOP =              0x00000400,
	BS_BOTTOM =           0x00000800,
	BS_VCENTER =          0x00000C00,
	BS_PUSHLIKE =         0x00001000,
	BS_MULTILINE =        0x00002000,
	BS_NOTIFY =           0x00004000,
	BS_FLAT =             0x00008000,
	BS_RIGHTBUTTON =      BS_LEFTTEXT,



/*
 * User Button Notification Codes
 */
	BN_CLICKED =          0,
	BN_PAINT =            1,
	BN_HILITE =           2,
	BN_UNHILITE =         3,
	BN_DISABLE =          4,
	BN_DOUBLECLICKED =    5,

	BN_PUSHED =           BN_HILITE,
	BN_UNPUSHED =         BN_UNHILITE,
	BN_DBLCLK =           BN_DOUBLECLICKED,
	BN_SETFOCUS =         6,
	BN_KILLFOCUS =        7,

/*
 * Button Control Messages
 */
	BM_GETCHECK =        0x00F0,
	BM_SETCHECK =        0x00F1,
	BM_GETSTATE =        0x00F2,
	BM_SETSTATE =        0x00F3,
	BM_SETSTYLE =        0x00F4,

	BM_CLICK =           0x00F5,
	BM_GETIMAGE =        0x00F6,
	BM_SETIMAGE =        0x00F7,

	BST_UNCHECKED =      0x0000,
	BST_CHECKED =        0x0001,
	BST_INDETERMINATE =  0x0002,
	BST_PUSHED =         0x0004,
	BST_FOCUS =          0x0008,


/*
 * Static Control Constants
 */
	SS_LEFT =             0x00000000,
	SS_CENTER =           0x00000001,
	SS_RIGHT =            0x00000002,
	SS_ICON =             0x00000003,
	SS_BLACKRECT =        0x00000004,
	SS_GRAYRECT =         0x00000005,
	SS_WHITERECT =        0x00000006,
	SS_BLACKFRAME =       0x00000007,
	SS_GRAYFRAME =        0x00000008,
	SS_WHITEFRAME =       0x00000009,
	SS_USERITEM =         0x0000000A,
	SS_SIMPLE =           0x0000000B,
	SS_LEFTNOWORDWRAP =   0x0000000C,

	SS_OWNERDRAW =        0x0000000D,
	SS_BITMAP =           0x0000000E,
	SS_ENHMETAFILE =      0x0000000F,
	SS_ETCHEDHORZ =       0x00000010,
	SS_ETCHEDVERT =       0x00000011,
	SS_ETCHEDFRAME =      0x00000012,
	SS_TYPEMASK =         0x0000001F,

	SS_NOPREFIX =         0x00000080, /* Don't do "&" character translation */

	SS_NOTIFY =           0x00000100,
	SS_CENTERIMAGE =      0x00000200,
	SS_RIGHTJUST =        0x00000400,
	SS_REALSIZEIMAGE =    0x00000800,
	SS_SUNKEN =           0x00001000,
	SS_ENDELLIPSIS =      0x00004000,
	SS_PATHELLIPSIS =     0x00008000,
	SS_WORDELLIPSIS =     0x0000C000,
	SS_ELLIPSISMASK =     0x0000C000,


// end_r_winuser


/*
 * Static Control Mesages
 */
	STM_SETICON =         0x0170,
	STM_GETICON =         0x0171,

	STM_SETIMAGE =        0x0172,
	STM_GETIMAGE =        0x0173,
	STN_CLICKED =         0,
	STN_DBLCLK =          1,
	STN_ENABLE =          2,
	STN_DISABLE =         3,

	STM_MSGMAX =          0x0174,
}


enum
{
/*
 * Window Messages
 */

	WM_NULL =                         0x0000,
	WM_CREATE =                       0x0001,
	WM_DESTROY =                      0x0002,
	WM_MOVE =                         0x0003,
	WM_SIZE =                         0x0005,

	WM_ACTIVATE =                     0x0006,
/*
 * WM_ACTIVATE state values
 */
	WA_INACTIVE =     0,
	WA_ACTIVE =       1,
	WA_CLICKACTIVE =  2,

	WM_SETFOCUS =                     0x0007,
	WM_KILLFOCUS =                    0x0008,
	WM_ENABLE =                       0x000A,
	WM_SETREDRAW =                    0x000B,
	WM_SETTEXT =                      0x000C,
	WM_GETTEXT =                      0x000D,
	WM_GETTEXTLENGTH =                0x000E,
	WM_PAINT =                        0x000F,
	WM_CLOSE =                        0x0010,
	WM_QUERYENDSESSION =              0x0011,
	WM_QUIT =                         0x0012,
	WM_QUERYOPEN =                    0x0013,
	WM_ERASEBKGND =                   0x0014,
	WM_SYSCOLORCHANGE =               0x0015,
	WM_ENDSESSION =                   0x0016,
	WM_SHOWWINDOW =                   0x0018,
	WM_WININICHANGE =                 0x001A,

	WM_SETTINGCHANGE =                WM_WININICHANGE,



	WM_DEVMODECHANGE =                0x001B,
	WM_ACTIVATEAPP =                  0x001C,
	WM_FONTCHANGE =                   0x001D,
	WM_TIMECHANGE =                   0x001E,
	WM_CANCELMODE =                   0x001F,
	WM_SETCURSOR =                    0x0020,
	WM_MOUSEACTIVATE =                0x0021,
	WM_CHILDACTIVATE =                0x0022,
	WM_QUEUESYNC =                    0x0023,

	WM_GETMINMAXINFO =                0x0024,
}

struct RECT
{
    LONG    left;
    LONG    top;
    LONG    right;
    LONG    bottom;
}
alias RECT* PRECT, NPRECT, LPRECT;

struct PAINTSTRUCT {
    HDC         hdc;
    BOOL        fErase;
    RECT        rcPaint;
    BOOL        fRestore;
    BOOL        fIncUpdate;
    BYTE        rgbReserved[32];
}
alias PAINTSTRUCT* PPAINTSTRUCT, NPPAINTSTRUCT, LPPAINTSTRUCT;

// flags for GetDCEx()

enum
{
	DCX_WINDOW =           0x00000001,
	DCX_CACHE =            0x00000002,
	DCX_NORESETATTRS =     0x00000004,
	DCX_CLIPCHILDREN =     0x00000008,
	DCX_CLIPSIBLINGS =     0x00000010,
	DCX_PARENTCLIP =       0x00000020,
	DCX_EXCLUDERGN =       0x00000040,
	DCX_INTERSECTRGN =     0x00000080,
	DCX_EXCLUDEUPDATE =    0x00000100,
	DCX_INTERSECTUPDATE =  0x00000200,
	DCX_LOCKWINDOWUPDATE = 0x00000400,
	DCX_VALIDATE =         0x00200000,
}

export
{
 BOOL UpdateWindow(HWND hWnd);
 HWND SetActiveWindow(HWND hWnd);
 HWND GetForegroundWindow();
 BOOL PaintDesktop(HDC hdc);
 BOOL SetForegroundWindow(HWND hWnd);
 HWND WindowFromDC(HDC hDC);
 HDC GetDC(HWND hWnd);
 HDC GetDCEx(HWND hWnd, HRGN hrgnClip, DWORD flags);
 HDC GetWindowDC(HWND hWnd);
 int ReleaseDC(HWND hWnd, HDC hDC);
 HDC BeginPaint(HWND hWnd, LPPAINTSTRUCT lpPaint);
 BOOL EndPaint(HWND hWnd, PAINTSTRUCT *lpPaint);
 BOOL GetUpdateRect(HWND hWnd, LPRECT lpRect, BOOL bErase);
 int GetUpdateRgn(HWND hWnd, HRGN hRgn, BOOL bErase);
 int SetWindowRgn(HWND hWnd, HRGN hRgn, BOOL bRedraw);
 int GetWindowRgn(HWND hWnd, HRGN hRgn);
 int ExcludeUpdateRgn(HDC hDC, HWND hWnd);
 BOOL InvalidateRect(HWND hWnd, RECT *lpRect, BOOL bErase);
 BOOL ValidateRect(HWND hWnd, RECT *lpRect);
 BOOL InvalidateRgn(HWND hWnd, HRGN hRgn, BOOL bErase);
 BOOL ValidateRgn(HWND hWnd, HRGN hRgn);
 BOOL RedrawWindow(HWND hWnd, RECT *lprcUpdate, HRGN hrgnUpdate, UINT flags);
}

// flags for RedrawWindow()
enum
{
	RDW_INVALIDATE =          0x0001,
	RDW_INTERNALPAINT =       0x0002,
	RDW_ERASE =               0x0004,
	RDW_VALIDATE =            0x0008,
	RDW_NOINTERNALPAINT =     0x0010,
	RDW_NOERASE =             0x0020,
	RDW_NOCHILDREN =          0x0040,
	RDW_ALLCHILDREN =         0x0080,
	RDW_UPDATENOW =           0x0100,
	RDW_ERASENOW =            0x0200,
	RDW_FRAME =               0x0400,
	RDW_NOFRAME =             0x0800,
}

export
{
 BOOL GetClientRect(HWND hWnd, LPRECT lpRect);
 BOOL GetWindowRect(HWND hWnd, LPRECT lpRect);
 BOOL AdjustWindowRect(LPRECT lpRect, DWORD dwStyle, BOOL bMenu);
 BOOL AdjustWindowRectEx(LPRECT lpRect, DWORD dwStyle, BOOL bMenu, DWORD dwExStyle);
 HFONT CreateFontA(int, int, int, int, int, DWORD,
                             DWORD, DWORD, DWORD, DWORD, DWORD,
                             DWORD, DWORD, LPCSTR);
 HFONT CreateFontW(int, int, int, int, int, DWORD,
                             DWORD, DWORD, DWORD, DWORD, DWORD,
                             DWORD, DWORD, LPCWSTR);
}

enum
{
	OUT_DEFAULT_PRECIS =          0,
	OUT_STRING_PRECIS =           1,
	OUT_CHARACTER_PRECIS =        2,
	OUT_STROKE_PRECIS =           3,
	OUT_TT_PRECIS =               4,
	OUT_DEVICE_PRECIS =           5,
	OUT_RASTER_PRECIS =           6,
	OUT_TT_ONLY_PRECIS =          7,
	OUT_OUTLINE_PRECIS =          8,
	OUT_SCREEN_OUTLINE_PRECIS =   9,

	CLIP_DEFAULT_PRECIS =     0,
	CLIP_CHARACTER_PRECIS =   1,
	CLIP_STROKE_PRECIS =      2,
	CLIP_MASK =               0xf,
	CLIP_LH_ANGLES =          (1<<4),
	CLIP_TT_ALWAYS =          (2<<4),
	CLIP_EMBEDDED =           (8<<4),

	DEFAULT_QUALITY =         0,
	DRAFT_QUALITY =           1,
	PROOF_QUALITY =           2,

	NONANTIALIASED_QUALITY =  3,
	ANTIALIASED_QUALITY =     4,


	DEFAULT_PITCH =           0,
	FIXED_PITCH =             1,
	VARIABLE_PITCH =          2,

	MONO_FONT =               8,


	ANSI_CHARSET =            0,
	DEFAULT_CHARSET =         1,
	SYMBOL_CHARSET =          2,
	SHIFTJIS_CHARSET =        128,
	HANGEUL_CHARSET =         129,
	GB2312_CHARSET =          134,
	CHINESEBIG5_CHARSET =     136,
	OEM_CHARSET =             255,

	JOHAB_CHARSET =           130,
	HEBREW_CHARSET =          177,
	ARABIC_CHARSET =          178,
	GREEK_CHARSET =           161,
	TURKISH_CHARSET =         162,
	VIETNAMESE_CHARSET =      163,
	THAI_CHARSET =            222,
	EASTEUROPE_CHARSET =      238,
	RUSSIAN_CHARSET =         204,

	MAC_CHARSET =             77,
	BALTIC_CHARSET =          186,

	FS_LATIN1 =               0x00000001L,
	FS_LATIN2 =               0x00000002L,
	FS_CYRILLIC =             0x00000004L,
	FS_GREEK =                0x00000008L,
	FS_TURKISH =              0x00000010L,
	FS_HEBREW =               0x00000020L,
	FS_ARABIC =               0x00000040L,
	FS_BALTIC =               0x00000080L,
	FS_VIETNAMESE =           0x00000100L,
	FS_THAI =                 0x00010000L,
	FS_JISJAPAN =             0x00020000L,
	FS_CHINESESIMP =          0x00040000L,
	FS_WANSUNG =              0x00080000L,
	FS_CHINESETRAD =          0x00100000L,
	FS_JOHAB =                0x00200000L,
	FS_SYMBOL =               (int)0x80000000L,


/* Font Families */
	FF_DONTCARE =         (0<<4), /* Don't care or don't know. */
	FF_ROMAN =            (1<<4), /* Variable stroke width, serifed. */
                                    /* Times Roman, Century Schoolbook, etc. */
	FF_SWISS =            (2<<4), /* Variable stroke width, sans-serifed. */
                                    /* Helvetica, Swiss, etc. */
	FF_MODERN =           (3<<4), /* Constant stroke width, serifed or sans-serifed. */
                                    /* Pica, Elite, Courier, etc. */
	FF_SCRIPT =           (4<<4), /* Cursive, etc. */
	FF_DECORATIVE =       (5<<4), /* Old English, etc. */

/* Font Weights */
	FW_DONTCARE =         0,
	FW_THIN =             100,
	FW_EXTRALIGHT =       200,
	FW_LIGHT =            300,
	FW_NORMAL =           400,
	FW_MEDIUM =           500,
	FW_SEMIBOLD =         600,
	FW_BOLD =             700,
	FW_EXTRABOLD =        800,
	FW_HEAVY =            900,

	FW_ULTRALIGHT =       FW_EXTRALIGHT,
	FW_REGULAR =          FW_NORMAL,
	FW_DEMIBOLD =         FW_SEMIBOLD,
	FW_ULTRABOLD =        FW_EXTRABOLD,
	FW_BLACK =            FW_HEAVY,

	PANOSE_COUNT =               10,
	PAN_FAMILYTYPE_INDEX =        0,
	PAN_SERIFSTYLE_INDEX =        1,
	PAN_WEIGHT_INDEX =            2,
	PAN_PROPORTION_INDEX =        3,
	PAN_CONTRAST_INDEX =          4,
	PAN_STROKEVARIATION_INDEX =   5,
	PAN_ARMSTYLE_INDEX =          6,
	PAN_LETTERFORM_INDEX =        7,
	PAN_MIDLINE_INDEX =           8,
	PAN_XHEIGHT_INDEX =           9,

	PAN_CULTURE_LATIN =           0,
}

struct RGBQUAD {
        BYTE    rgbBlue;
        BYTE    rgbGreen;
        BYTE    rgbRed;
        BYTE    rgbReserved;
}
alias RGBQUAD* LPRGBQUAD;

struct BITMAPINFOHEADER
{
        DWORD      biSize;
        LONG       biWidth;
        LONG       biHeight;
        WORD       biPlanes;
        WORD       biBitCount;
        DWORD      biCompression;
        DWORD      biSizeImage;
        LONG       biXPelsPerMeter;
        LONG       biYPelsPerMeter;
        DWORD      biClrUsed;
        DWORD      biClrImportant;
}
alias BITMAPINFOHEADER* LPBITMAPINFOHEADER, PBITMAPINFOHEADER;

struct BITMAPINFO {
    BITMAPINFOHEADER    bmiHeader;
    RGBQUAD             bmiColors[1];
}
alias BITMAPINFO* LPBITMAPINFO, PBITMAPINFO;

struct PALETTEENTRY {
    BYTE        peRed;
    BYTE        peGreen;
    BYTE        peBlue;
    BYTE        peFlags;
}
alias PALETTEENTRY* PPALETTEENTRY, LPPALETTEENTRY;

/* Pixel format descriptor */
struct PIXELFORMATDESCRIPTOR
{
    WORD  nSize;
    WORD  nVersion;
    DWORD dwFlags;
    BYTE  iPixelType;
    BYTE  cColorBits;
    BYTE  cRedBits;
    BYTE  cRedShift;
    BYTE  cGreenBits;
    BYTE  cGreenShift;
    BYTE  cBlueBits;
    BYTE  cBlueShift;
    BYTE  cAlphaBits;
    BYTE  cAlphaShift;
    BYTE  cAccumBits;
    BYTE  cAccumRedBits;
    BYTE  cAccumGreenBits;
    BYTE  cAccumBlueBits;
    BYTE  cAccumAlphaBits;
    BYTE  cDepthBits;
    BYTE  cStencilBits;
    BYTE  cAuxBuffers;
    BYTE  iLayerType;
    BYTE  bReserved;
    DWORD dwLayerMask;
    DWORD dwVisibleMask;
    DWORD dwDamageMask;
}
alias PIXELFORMATDESCRIPTOR* PPIXELFORMATDESCRIPTOR, LPPIXELFORMATDESCRIPTOR;


export
{
 BOOL   RoundRect(HDC, int, int, int, int, int, int);
 BOOL   ResizePalette(HPALETTE, UINT);
 int    SaveDC(HDC);
 int    SelectClipRgn(HDC, HRGN);
 int    ExtSelectClipRgn(HDC, HRGN, int);
 int    SetMetaRgn(HDC);
 HGDIOBJ   SelectObject(HDC, HGDIOBJ);
 HPALETTE   SelectPalette(HDC, HPALETTE, BOOL);
 COLORREF   SetBkColor(HDC, COLORREF);
 int     SetBkMode(HDC, int);
 LONG    SetBitmapBits(HBITMAP, DWORD, void *);
 UINT    SetBoundsRect(HDC,   RECT *, UINT);
 int     SetDIBits(HDC, HBITMAP, UINT, UINT, void *, BITMAPINFO *, UINT);
 int     SetDIBitsToDevice(HDC, int, int, DWORD, DWORD, int,
        int, UINT, UINT, void *, BITMAPINFO *, UINT);
 DWORD   SetMapperFlags(HDC, DWORD);
 int     SetGraphicsMode(HDC hdc, int iMode);
 int     SetMapMode(HDC, int);
 HMETAFILE     SetMetaFileBitsEx(UINT, BYTE *);
 UINT    SetPaletteEntries(HPALETTE, UINT, UINT, PALETTEENTRY *);
 COLORREF   SetPixel(HDC, int, int, COLORREF);
 BOOL     SetPixelV(HDC, int, int, COLORREF);
 BOOL    SetPixelFormat(HDC, int, PIXELFORMATDESCRIPTOR *);
 int     SetPolyFillMode(HDC, int);
 BOOL    StretchBlt(HDC, int, int, int, int, HDC, int, int, int, int, DWORD);
 BOOL    SetRectRgn(HRGN, int, int, int, int);
 int     StretchDIBits(HDC, int, int, int, int, int, int, int, int,
         void *, BITMAPINFO *, UINT, DWORD);
 int     SetROP2(HDC, int);
 int     SetStretchBltMode(HDC, int);
 UINT    SetSystemPaletteUse(HDC, UINT);
 int     SetTextCharacterExtra(HDC, int);
 COLORREF   SetTextColor(HDC, COLORREF);
 UINT    SetTextAlign(HDC, UINT);
 BOOL    SetTextJustification(HDC, int, int);
 BOOL    UpdateColors(HDC);
}

/* Text Alignment Options */
enum
{
	TA_NOUPDATECP =                0,
	TA_UPDATECP =                  1,

	TA_LEFT =                      0,
	TA_RIGHT =                     2,
	TA_CENTER =                    6,

	TA_TOP =                       0,
	TA_BOTTOM =                    8,
	TA_BASELINE =                  24,

	TA_RTLREADING =                256,
	TA_MASK =       (TA_BASELINE+TA_CENTER+TA_UPDATECP+TA_RTLREADING),
}

struct POINT
{
    LONG  x;
    LONG  y;
}
alias POINT* PPOINT, NPPOINT, LPPOINT;


export
{
 BOOL    MoveToEx(HDC, int, int, LPPOINT);
 BOOL    TextOutA(HDC, int, int, LPCSTR, int);
 BOOL    TextOutW(HDC, int, int, LPCWSTR, int);
}

export void PostQuitMessage(int nExitCode);
export LRESULT DefWindowProcA(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam);
export HMODULE GetModuleHandleA(LPCSTR lpModuleName);

alias LRESULT (* WNDPROC)(HWND, UINT, WPARAM, LPARAM);

struct WNDCLASSEXA {
    UINT        cbSize;
    /* Win 3.x */
    UINT        style;
    WNDPROC     lpfnWndProc;
    int         cbClsExtra;
    int         cbWndExtra;
    HINSTANCE   hInstance;
    HICON       hIcon;
    HCURSOR     hCursor;
    HBRUSH      hbrBackground;
    LPCSTR      lpszMenuName;
    LPCSTR      lpszClassName;
    /* Win 4.0 */
    HICON       hIconSm;
}
alias WNDCLASSEXA* PWNDCLASSEXA, NPWNDCLASSEXA, LPWNDCLASSEXA;


struct WNDCLASSA {
    UINT        style;
    WNDPROC     lpfnWndProc;
    int         cbClsExtra;
    int         cbWndExtra;
    HINSTANCE   hInstance;
    HICON       hIcon;
    HCURSOR     hCursor;
    HBRUSH      hbrBackground;
    LPCSTR      lpszMenuName;
    LPCSTR      lpszClassName;
}
alias WNDCLASSA* PWNDCLASSA, NPWNDCLASSA, LPWNDCLASSA;
alias WNDCLASSA WNDCLASS;

/*
 * Window Styles
 */
enum
{
	WS_OVERLAPPED =       0x00000000,
	WS_POPUP =            (int)0x80000000,
	WS_CHILD =            0x40000000,
	WS_MINIMIZE =         0x20000000,
	WS_VISIBLE =          0x10000000,
	WS_DISABLED =         0x08000000,
	WS_CLIPSIBLINGS =     0x04000000,
	WS_CLIPCHILDREN =     0x02000000,
	WS_MAXIMIZE =         0x01000000,
	WS_CAPTION =          0x00C00000,  /* WS_BORDER | WS_DLGFRAME  */
	WS_BORDER =           0x00800000,
	WS_DLGFRAME =         0x00400000,
	WS_VSCROLL =          0x00200000,
	WS_HSCROLL =          0x00100000,
	WS_SYSMENU =          0x00080000,
	WS_THICKFRAME =       0x00040000,
	WS_GROUP =            0x00020000,
	WS_TABSTOP =          0x00010000,

	WS_MINIMIZEBOX =      0x00020000,
	WS_MAXIMIZEBOX =      0x00010000,

	WS_TILED =            WS_OVERLAPPED,
	WS_ICONIC =           WS_MINIMIZE,
	WS_SIZEBOX =          WS_THICKFRAME,

/*
 * Common Window Styles
 */
	WS_OVERLAPPEDWINDOW = (WS_OVERLAPPED |            WS_CAPTION |  WS_SYSMENU |  WS_THICKFRAME |            WS_MINIMIZEBOX |                 WS_MAXIMIZEBOX),
	WS_TILEDWINDOW =      WS_OVERLAPPEDWINDOW,
	WS_POPUPWINDOW =      (WS_POPUP |  WS_BORDER |  WS_SYSMENU),
	WS_CHILDWINDOW =      (WS_CHILD),
}

/*
 * Class styles
 */
enum
{
	CS_VREDRAW =          0x0001,
	CS_HREDRAW =          0x0002,
	CS_KEYCVTWINDOW =     0x0004,
	CS_DBLCLKS =          0x0008,
	CS_OWNDC =            0x0020,
	CS_CLASSDC =          0x0040,
	CS_PARENTDC =         0x0080,
	CS_NOKEYCVT =         0x0100,
	CS_NOCLOSE =          0x0200,
	CS_SAVEBITS =         0x0800,
	CS_BYTEALIGNCLIENT =  0x1000,
	CS_BYTEALIGNWINDOW =  0x2000,
	CS_GLOBALCLASS =      0x4000,


	CS_IME =              0x00010000,
}

export
{
 HICON LoadIconA(HINSTANCE hInstance, LPCSTR lpIconName);
 HICON LoadIconW(HINSTANCE hInstance, LPCWSTR lpIconName);
 HCURSOR LoadCursorA(HINSTANCE hInstance, LPCSTR lpCursorName);
 HCURSOR LoadCursorW(HINSTANCE hInstance, LPCWSTR lpCursorName);
}

const LPSTR IDI_APPLICATION =     cast(LPSTR)(32512);
const LPSTR IDC_CROSS =           cast(LPSTR)(32515);

/*
 * Color Types
 */
enum
{
	CTLCOLOR_MSGBOX =         0,
	CTLCOLOR_EDIT =           1,
	CTLCOLOR_LISTBOX =        2,
	CTLCOLOR_BTN =            3,
	CTLCOLOR_DLG =            4,
	CTLCOLOR_SCROLLBAR =      5,
	CTLCOLOR_STATIC =         6,
	CTLCOLOR_MAX =            7,

	COLOR_SCROLLBAR =         0,
	COLOR_BACKGROUND =        1,
	COLOR_ACTIVECAPTION =     2,
	COLOR_INACTIVECAPTION =   3,
	COLOR_MENU =              4,
	COLOR_WINDOW =            5,
	COLOR_WINDOWFRAME =       6,
	COLOR_MENUTEXT =          7,
	COLOR_WINDOWTEXT =        8,
	COLOR_CAPTIONTEXT =       9,
	COLOR_ACTIVEBORDER =      10,
	COLOR_INACTIVEBORDER =    11,
	COLOR_APPWORKSPACE =      12,
	COLOR_HIGHLIGHT =         13,
	COLOR_HIGHLIGHTTEXT =     14,
	COLOR_BTNFACE =           15,
	COLOR_BTNSHADOW =         16,
	COLOR_GRAYTEXT =          17,
	COLOR_BTNTEXT =           18,
	COLOR_INACTIVECAPTIONTEXT = 19,
	COLOR_BTNHIGHLIGHT =      20,


	COLOR_3DDKSHADOW =        21,
	COLOR_3DLIGHT =           22,
	COLOR_INFOTEXT =          23,
	COLOR_INFOBK =            24,

	COLOR_DESKTOP =           COLOR_BACKGROUND,
	COLOR_3DFACE =            COLOR_BTNFACE,
	COLOR_3DSHADOW =          COLOR_BTNSHADOW,
	COLOR_3DHIGHLIGHT =       COLOR_BTNHIGHLIGHT,
	COLOR_3DHILIGHT =         COLOR_BTNHIGHLIGHT,
	COLOR_BTNHILIGHT =        COLOR_BTNHIGHLIGHT,
}

const int CW_USEDEFAULT = (int)0x80000000;
/*
 * Special value for CreateWindow, et al.
 */
const HWND HWND_DESKTOP = ((HWND)0);


export ATOM RegisterClassA(WNDCLASSA *lpWndClass);

export HWND CreateWindowExA(
    DWORD dwExStyle,
    LPCSTR lpClassName,
    LPCSTR lpWindowName,
    DWORD dwStyle,
    int X,
    int Y,
    int nWidth,
    int nHeight,
    HWND hWndParent ,
    HMENU hMenu,
    HINSTANCE hInstance,
    LPVOID lpParam);


HWND CreateWindowA(
    LPCSTR lpClassName,
    LPCSTR lpWindowName,
    DWORD dwStyle,
    int X,
    int Y,
    int nWidth,
    int nHeight,
    HWND hWndParent ,
    HMENU hMenu,
    HINSTANCE hInstance,
    LPVOID lpParam)
{
    return CreateWindowExA(0, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWndParent, hMenu, hInstance, lpParam);
}

/*
 * Message structure
 */
struct MSG {
    HWND        hwnd;
    UINT        message;
    WPARAM      wParam;
    LPARAM      lParam;
    DWORD       time;
    POINT       pt;
}
alias MSG* PMSG, NPMSG, LPMSG;

export
{
 BOOL GetMessageA(LPMSG lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax);
 BOOL TranslateMessage(MSG *lpMsg);
 LONG DispatchMessageA(MSG *lpMsg);
 BOOL PeekMessageA(MSG *lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg);
 HWND GetFocus();
}

export DWORD ExpandEnvironmentStringsA(LPCSTR lpSrc, LPSTR lpDst, DWORD nSize);

}
