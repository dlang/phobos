// Written in the D programming language

/*
 *  Copyright (C) 2010 by Digital Mars, http://www.digitalmars.com
 *  Written by Rainer Schuetze
 *
 *  This software is provided 'as-is', without any express or implied
 *  warranty. In no event will the authors be held liable for any damages
 *  arising from the use of this software.
 *
 *  Permission is granted to anyone to use this software for any purpose,
 *  including commercial applications, and to alter it and redistribute it
 *  freely, subject to the following restrictions:
 *
 *  o  The origin of this software must not be misrepresented; you must not
 *     claim that you wrote the original software. If you use this software
 *     in a product, an acknowledgment in the product documentation would be
 *     appreciated but is not required.
 *  o  Altered source versions must be plainly marked as such, and must not
 *     be misrepresented as being the original software.
 *  o  This notice may not be removed or altered from any source
 *     distribution.
 */

/**
 * This module provides OS specific helper function for threads support
 * Source: $(PHOBOSSRC std/_thread_helper.d)
 */

module std.thread_helper;

version( Windows )
{
    import std.c.windows.windows;
    import std.c.stdlib;

        public import std.thread;

    ///////////////////////////////////////////////////////////////////

    const SystemProcessInformation = 5;
    const STATUS_INFO_LENGTH_MISMATCH = 0xc0000004;

    // abbreviated versions of these structs
    struct _SYSTEM_PROCESS_INFORMATION
    {
        int NextEntryOffset; // When this entry is 0, there are no more processes to be read.
        int NumberOfThreads;
        int[15] fill1;
        int ProcessId;
        int[28] fill2;

        // SYSTEM_THREAD_INFORMATION or SYSTEM_EXTENDED_THREAD_INFORMATION structures follow.
    }

    struct _SYSTEM_THREAD_INFORMATION
    {
        int[8] fill1;
        int ProcessId;
        int ThreadId;
        int[6] fill2;
    }

    alias extern(Windows)
    HRESULT fnNtQuerySystemInformation( uint SystemInformationClass, void* info, uint infoLength, uint* ReturnLength );

    const ThreadBasicInformation = 0;

    struct THREAD_BASIC_INFORMATION
    {
        int    ExitStatus;
        void** TebBaseAddress;
        int    ProcessId;
        int    ThreadId;
        int    AffinityMask;
        int    Priority;
        int    BasePriority;
    }

    alias extern(Windows)
    int fnNtQueryInformationThread( HANDLE ThreadHandle, uint ThreadInformationClass, void* buf, uint size, uint* ReturnLength );

    ///////////////////////////////////////////////////////////////////
    // support attaching to thread other than just executing
    void** getTEB( HANDLE hnd )
    {
        HANDLE nthnd = GetModuleHandleA( "NTDLL" );
        assert( nthnd, "cannot get module handle for ntdll" );
        fnNtQueryInformationThread* fn = cast(fnNtQueryInformationThread*) GetProcAddress( nthnd, "NtQueryInformationThread" );
        assert( fn, "cannot find NtQueryInformationThread in ntdll" );

        THREAD_BASIC_INFORMATION tbi;
        int Status = (*fn)(hnd, ThreadBasicInformation, &tbi, tbi.sizeof, null);
        assert(Status == 0);

        return tbi.TebBaseAddress;
    }

    extern(Windows)
    HANDLE OpenThread(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwThreadId);

    const SYNCHRONIZE = 0x00100000;
    const THREAD_GET_CONTEXT = 8;
    const THREAD_QUERY_INFORMATION = 0x40;
    const THREAD_SUSPEND_RESUME = 2;

    void** getTEB( uint id )
    {
        HANDLE hnd = OpenThread( THREAD_QUERY_INFORMATION, FALSE, id );
        assert( hnd, "OpenThread failed" );

        void** teb = getTEB( hnd );
        CloseHandle( hnd );
        return teb;
    }

    void* getThreadStackBottom( HANDLE hnd )
    {
        void** teb = getTEB( hnd );
        return teb[1];
    }

    void* getThreadStackBottom( uint id )
    {
        void** teb = getTEB( id );
        return teb[1];
    }

    HANDLE OpenThreadHandle( uint id )
    {
        return OpenThread( SYNCHRONIZE|THREAD_GET_CONTEXT|THREAD_QUERY_INFORMATION|THREAD_SUSPEND_RESUME, FALSE, id );
    }

    ///////////////////////////////////////////////////////////////////
    // support attaching to all running threads
    // using function instead of delegate here to avoid allocating closure
    bool enumProcessThreads( uint procid, bool function( uint id, void* context ) dg, void* context )
    {
        HANDLE hnd = GetModuleHandleA( "NTDLL" );
        fnNtQuerySystemInformation* fn = cast(fnNtQuerySystemInformation*) GetProcAddress( hnd, "NtQuerySystemInformation" );
        if( !fn )
            return false;

        uint sz = 16384;
        uint retLength;
        HRESULT rc;
        char* buf;
        for( ; ; )
        {
            buf = cast(char*) std.c.stdlib.malloc(sz);
            if(!buf)
                return false;
            rc = (*fn)( SystemProcessInformation, buf, sz, &retLength );
            if( rc != STATUS_INFO_LENGTH_MISMATCH )
                break;
            std.c.stdlib.free( buf );
            sz *= 2;
        }
        scope(exit) std.c.stdlib.free( buf );

        if(rc != 0)
            return false;

        auto pinfo = cast(_SYSTEM_PROCESS_INFORMATION*) buf;
        auto pend  = cast(_SYSTEM_PROCESS_INFORMATION*) (buf + retLength);
        for( ; pinfo < pend; )
        {
            if( pinfo.ProcessId == procid )
            {
                auto tinfo = cast(_SYSTEM_THREAD_INFORMATION*)(pinfo + 1);
                for( int i = 0; i < pinfo.NumberOfThreads; i++, tinfo++ )
                    if( tinfo.ProcessId == procid )
                        if( !dg( tinfo.ThreadId, context ) )
                            return false;
            }
            if( pinfo.NextEntryOffset == 0 )
                break;
            pinfo = cast(_SYSTEM_PROCESS_INFORMATION*) (cast(char*) pinfo + pinfo.NextEntryOffset);
        }
        return true;
    }

    bool enumProcessThreads( bool function( uint id, void* context ) dg, void* context )
    {
        return enumProcessThreads( GetCurrentProcessId(), dg, context );
    }


}

