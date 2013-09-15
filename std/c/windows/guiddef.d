/***********************************************************************\
*                               basetyps.d                              *
*                                                                       *
*                       Windows API header module                       *
*                                                                       *
*             Translated from MinGW API for MS-Windows 3.10             *
*                                                                       *
*                       Placed into public domain                       *
\***********************************************************************/

/* Windows is a registered trademark of Microsoft Corporation in the United
States and other countries. */

module std.c.windows.guiddef;
version (Windows):

private import std.stdint;
private import std.c.windows.windows;
	
align(1) struct GUID {  // size is 16
    DWORD   Data1;
    WORD    Data2;
    WORD    Data3;
    BYTE[8] Data4;
}
alias GUID UUID, IID, CLSID, FMTID, uuid_t;
alias GUID* LPGUID, LPCLSID, LPIID;
alias uint error_status_t, PROPID;
