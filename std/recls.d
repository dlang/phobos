/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls.d
 *
 * Purpose:     D mapping for the recls library. recls is a platform-independent
 *              recursive search library. It is mapped to several languages, 
 *              including D. recls was written by Matthew Wilson, as the first
 *              exemplar for his "Positive Integration" column in C/C++ User's
 *              Journal.
 *
 * Created      10th Octover 2003
 * Updated:     27th November 2003
 *
 * Author:      Matthew Wilson
 *
 * License:     (Licensed under the Synesis Software Standard Source License)
 *
 *              Copyright (C) 2002-2003, Synesis Software Pty Ltd.
 *
 *              All rights reserved.
 *
 *              www:        http://www.recls.org/
 *                          http://www.synesis.com.au/software
 *                          http://www.synsoft.org/
 *
 *              email:      admin@recls.org
 *
 *              Redistribution and use in source and binary forms, with or
 *              without modification, are permitted provided that the following
 *              conditions are met:
 *
 *              (i) Redistributions of source code must retain the above
 *              copyright notice and contact information, this list of
 *              conditions and the following disclaimer.
 *
 *              (ii) Any derived versions of this software (howsoever modified)
 *              remain the sole property of Synesis Software.
 *
 *              (iii) Any derived versions of this software (howsoever modified)
 *              remain subject to all these conditions.
 *
 *              (iv) Neither the name of Synesis Software nor the names of any
 *              subdivisions, employees or agents of Synesis Software, nor the
 *              names of any other contributors to this software may be used to
 *              endorse or promote products derived from this software without
 *              specific prior written permission.
 *
 *              This source code is provided by Synesis Software "as is" and any
 *              warranties, whether expressed or implied, including, but not
 *              limited to, the implied warranties of merchantability and
 *              fitness for a particular purpose are disclaimed. In no event
 *              shall the Synesis Software be liable for any direct, indirect,
 *              incidental, special, exemplary, or consequential damages
 *              (including, but not limited to, procurement of substitute goods
 *              or services; loss of use, data, or profits; or business
 *              interruption) however caused and on any theory of liability,
 *              whether in contract, strict liability, or tort (including
 *              negligence or otherwise) arising in any way out of the use of
 *              this software, even if advised of the possibility of such
 *              damage.
 *
 * ////////////////////////////////////////////////////////////////////////// */



////////////////////////////////////////////////////////////////////////////////
// Module

module std.recls;

////////////////////////////////////////////////////////////////////////////////
// Imports

import std.string;

version (linux)
{
    private import std.c.linux.linux;
}

////////////////////////////////////////////////////////////////////////////////
// Public types

private alias int                recls_sint32_t;
/// Unsigned 32-bit integer, used for flags
public alias uint               recls_uint32_t;
/// boolean type, used in the recls API functions
public typedef int              recls_bool_t;
/// boolean type, used in the recls class mappings
public alias recls_bool_t       boolean;

version(Windows)
{
    /// Win32 time type
    public struct               recls_time_t
    {
        uint    dwLowDateTime;
        uint    dwHighDateTime; 
    };

    /// Win32 file size type
    alias ulong                 recls_filesize_t;
}
else version(linux)
{
    /// UNIX time type
    typedef time_t              recls_time_t;

    /// UNIX file size type
    typedef off_t               recls_filesize_t;
}

/// The recls search handle type.
public typedef void             *hrecls_t;
/// The recls entry handle type.
public typedef void             *recls_info_t;
/// The recls entry process callback function parameter type. */    
public typedef void             *recls_process_fn_param_t;

/// The return code of the recls API
public typedef recls_sint32_t   recls_rc_t;

/// Returns non-zero if the given return code represents a failure condition.
public recls_bool_t RECLS_FAILED(recls_rc_t rc)
{
    return cast(recls_bool_t)(rc < 0);
}

/// Returns non-zero if the given return code represents a success condition.
public recls_bool_t RECLS_SUCCEEDED(recls_rc_t rc)
{
    return cast(recls_bool_t)!RECLS_FAILED(rc);
}

////////////////////////////////////////////////////////////////////////////////
// Values

/** General success code */
public const recls_rc_t         RECLS_RC_OK             =   cast(recls_rc_t)(0);

/** Return code that indicates that there is no more data available from an otherwise valid search. */
public const recls_rc_t         RECLS_RC_NO_MORE_DATA   =   cast(recls_rc_t)(-1004);

/// The flags used to moderate the recls search behaviour
public enum RECLS_FLAG
{
        RECLS_F_FILES               =   0x00000001 /*!< Include files in search. Included by default if none specified */
    ,   RECLS_F_DIRECTORIES         =   0x00000002 /*!< Include directories in search. Not currently supported. */
    ,   RECLS_F_LINKS               =   0x00000004 /*!< Include links in search. Ignored in Win32. */
    ,   RECLS_F_DEVICES             =   0x00000008 /*!< Include devices in search. Not currently supported. */
    ,   RECLS_F_TYPEMASK            =   0x00000FFF
    ,   RECLS_F_RECURSIVE           =   0x00010000 /*!< Searches given directory and all sub-directories */
    ,   RECLS_F_NO_FOLLOW_LINKS     =   0x00020000 /*!< Does not expand links */
    ,   RECLS_F_DIRECTORY_PARTS     =   0x00040000 /*!< Fills out the directory parts. Supported from version 1.1.1 onwards. */
    ,   RECLS_F_DETAILS_LATER       =   0x00080000 /*!< Does not fill out anything other than the path. Not currently supported. */
};

////////////////////////////////////////////////////////////////////////////////
// Private recls API declarations

extern (Windows)
{
    private recls_rc_t Recls_Search(    char            *searchRoot
                                    ,   char            *pattern
                                    ,   recls_uint32_t  flags
                                    ,   hrecls_t        *phSrch);

    typedef int (*hrecls_process_fn_t)(recls_info_t info, recls_process_fn_param_t param);

    private recls_rc_t Recls_SearchProcess( char                        *searchRoot
                                        ,   char                        *pattern
                                        ,   recls_uint32_t  flags
                                        ,   hrecls_process_fn_t         pfn
                                        ,   recls_process_fn_param_t    param);

    private void Recls_SearchClose(in hrecls_t hSrch);

    private recls_rc_t Recls_GetNext(in hrecls_t hSrch);

    private recls_rc_t Recls_GetDetails(in hrecls_t hSrch, out recls_info_t pinfo);

    private recls_rc_t Recls_GetNextDetails(in hrecls_t hSrch, out recls_info_t pinfo);

    private void Recls_CloseDetails(in recls_info_t fileInfo);

    private recls_rc_t Recls_CopyDetails(in recls_info_t fileInfo, in recls_info_t *pinfo);

    private recls_rc_t Recls_OutstandingDetails(in hrecls_t hSrch, out recls_uint32_t count);

    private recls_rc_t Recls_GetLastError(in hrecls_t hSrch);

    private int Recls_GetErrorString(in recls_rc_t rc, in char *buffer, in uint cchBuffer);

    private int Recls_GetLastErrorString(in hrecls_t hSrch, in char *buffer, in uint cchBuffer);

    private uint Recls_GetPathProperty(in recls_info_t  fileInfo, in char *buffer, in uint cchBuffer);

version(Windows)
{
    private void Recls_GetDriveProperty(in recls_info_t fileInfo, out char chDrive);
}

    private uint Recls_GetDirectoryProperty(in recls_info_t fileInfo, in char *buffer, in uint cchBuffer);

    private uint Recls_GetDirectoryPathProperty(in recls_info_t fileInfo, in char *buffer, in uint cchBuffer);

    private uint Recls_GetFileProperty(in recls_info_t fileInfo, in char *buffer, in uint cchBuffer);

    private uint Recls_GetShortFileProperty(in recls_info_t fileInfo, in char *buffer, in uint cchBuffer);

    private uint Recls_GetFileNameProperty(in recls_info_t fileInfo, in char *buffer, in uint cchBuffer);

    private uint Recls_GetFileExtProperty(in recls_info_t fileInfo, in char *buffer, in uint cchBuffer);

    private uint Recls_GetDirectoryPartProperty(in recls_info_t fileInfo, in int part, in char *buffer, in uint cchBuffer);

    private recls_bool_t Recls_IsFileReadOnly(in recls_info_t fileInfo);

    private recls_bool_t Recls_IsFileDirectory(in recls_info_t fileInfo);

    private recls_bool_t Recls_IsFileLink(in recls_info_t fileInfo);

    private void         Recls_GetSizeProperty(in recls_info_t fileInfo, recls_filesize_t *size);

    private recls_time_t Recls_GetCreationTime(in recls_info_t fileInfo);

    private recls_time_t Recls_GetModificationTime(in recls_info_t fileInfo);

    private recls_time_t Recls_GetLastAccessTime(in recls_info_t fileInfo);

    private recls_time_t Recls_GetLastStatusChangeTime(in recls_info_t fileInfo);

}

////////////////////////////////////////////////////////////////////////////////
// Public functions

/// Creates a search
///
/// \param searchRoot
/// \param pattern
/// \param flags
/// \param hSrch
/// \return 
/// \retval

public recls_rc_t Search_Create(in char[] searchRoot, in char[] pattern, in int flags, out hrecls_t hSrch)
{
    return Recls_Search(toStringz(searchRoot), toStringz(pattern), flags, &hSrch);
}

/+
private extern(Windows) int process_fn(recls_info_t entry, recls_process_fn_param_t p)
{
    return dg(Entry._make_Entry(entry), p);
}

public recls_rc_t Search_Process(   in char[]                                                       searchRoot
                                ,   in char[]                                                       pattern
                                ,   in int                                                          flags
                                ,   int delegate(in Entry entry, recls_process_fn_param_t param)    dg
                                ,   recls_process_fn_param_t                                        param)
{
/*     extern(Windows) int process_fn(recls_info_t entry, recls_process_fn_param_t p)
    {
        return dg(Entry._make_Entry(entry), p);
    }
 */
    return Recls_SearchProcess(searchRoot, pattern, flags, process_fn, param);
}
+/

/// Advances the given search to the next position
///
/// \param hSrch handle identifying the search
/// \return return code indicating status of the operation
/// \return RECLS_
public recls_rc_t Search_GetNext(in hrecls_t hSrch)
{
    return Recls_GetNext(hSrch);
}

/// Closes the given search
///
/// \param hSrch handle identifying the search
public void Search_Close(inout hrecls_t hSrch)
{
    Recls_SearchClose(hSrch);

    hSrch = null;
}

public recls_rc_t Search_GetEntry(in hrecls_t hSrch, out recls_info_t entry)
{
    return Recls_GetDetails(hSrch, entry);
}

public recls_rc_t Search_GetNextEntry(in hrecls_t hSrch, out recls_info_t entry)
{
    return Recls_GetNextDetails(hSrch, entry);
}

public void Search_CloseEntry(inout recls_info_t entry)
{
    Recls_CloseDetails(entry);

    entry = null;
}

public recls_info_t Search_CopyEntry(in recls_info_t entry)
{
    recls_info_t    copy;

    if(RECLS_FAILED(Recls_CopyDetails(entry, &copy)))
    {
        copy = null;
    }

    return copy;
}

public recls_rc_t Search_OutstandingDetails(in hrecls_t hSrch, out recls_uint32_t count)
{
    return Recls_OutstandingDetails(hSrch, count);
}

public recls_rc_t Search_GetLastError(in hrecls_t hSrch)
{
    return Recls_GetLastError(hSrch);
}

public char[] Search_GetErrorString(in recls_rc_t rc)
{
    uint    cch =   Recls_GetErrorString(rc, null, 0);
    char[]  err =   new char[cch];

    cch = Recls_GetErrorString(rc, err, err.length);

    assert(cch <= err.length);

    return err;
}

public char[] Search_GetEntryPath(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    uint    cch     =   Recls_GetPathProperty(entry, null, 0);
    char[]  path    =   new char[cch];

    cch = Recls_GetPathProperty(entry, path, path.length);

    assert(cch <= path.length);

    return path;
}

version(Windows)
{
public char Search_GetEntryDrive(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    char    chDrive;

    return (Recls_GetDriveProperty(entry, chDrive), chDrive);
}
}

public char[] Search_GetEntryDirectory(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    uint    cch =   Recls_GetDirectoryProperty(entry, null, 0);
    char[]  str =   new char[cch];

    cch = Recls_GetDirectoryProperty(entry, str, str.length);

    assert(cch <= str.length);

    return str;
}

public char[] Search_GetEntryDirectoryPath(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    uint    cch =   Recls_GetDirectoryPathProperty(entry, null, 0);
    char[]  str =   new char[cch];

    cch = Recls_GetDirectoryPathProperty(entry, str, str.length);

    assert(cch <= str.length);

    return str;
}

public char[] Search_GetEntryFile(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    uint    cch =   Recls_GetFileProperty(entry, null, 0);
    char[]  str =   new char[cch];

    cch = Recls_GetFileProperty(entry, str, str.length);

    assert(cch <= str.length);

    return str;
}

public char[] Search_GetEntryShortFile(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    uint    cch =   Recls_GetShortFileProperty(entry, null, 0);
    char[]  str =   new char[cch];

    cch = Recls_GetShortFileProperty(entry, str, str.length);

    assert(cch <= str.length);

    return str;
}

public char[] Search_GetEntryFileName(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    uint    cch =   Recls_GetFileNameProperty(entry, null, 0);
    char[]  str =   new char[cch];

    cch = Recls_GetFileNameProperty(entry, str, str.length);

    assert(cch <= str.length);

    return str;
}

public char[] Search_GetEntryFileExt(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    uint    cch =   Recls_GetFileExtProperty(entry, null, 0);
    char[]  str =   new char[cch];

    cch = Recls_GetFileExtProperty(entry, str, str.length);

    assert(cch <= str.length);

    return str;
}

public char[][] Search_GetEntryDirectoryParts(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    uint        cParts  =   Recls_GetDirectoryPartProperty(entry, -1, null, 0);
    char[][]    parts   =   new char[][cParts];

    for(int i = 0; i < cParts; ++i)
    {
        uint    cch =   Recls_GetDirectoryPartProperty(entry, i, null, 0);
        char[]  str =   new char[cch];

        cch = Recls_GetDirectoryPartProperty(entry, i, str, str.length);

        assert(cch <= str.length);

        parts[i] = str;
    }

    return parts;
}

public boolean Search_IsEntryReadOnly(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    return Recls_IsFileReadOnly(entry);
}

public boolean Search_IsEntryDirectory(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    return Recls_IsFileDirectory(entry);
}

public boolean Search_IsEntryLink(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    return Recls_IsFileLink(entry);
}

public recls_filesize_t Search_GetEntrySize(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    recls_filesize_t    size;

    return (Recls_GetSizeProperty(entry, &size), size);
}

public recls_time_t Search_GetEntryCreationTime(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    return Recls_GetCreationTime(entry);
}

public recls_time_t Search_GetEntryModificationTime(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    return Recls_GetModificationTime(entry);
}

public recls_time_t Search_GetEntryLastAccessTime(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    return Recls_GetLastAccessTime(entry);
}

public recls_time_t Search_GetEntryLastStatusChangeTime(in recls_info_t entry)
in
{
    assert(null !== entry);
}
body
{
    return Recls_GetLastStatusChangeTime(entry);
}

////////////////////////////////////////////////////////////////////////////////
// Classes

/// Represents a search
public class Search
{
/// \name Construction
public:
    /// Create a search object with the given searchRoot, pattern and flags
    ///
    /// \param searchRoot The root directory of the search. If null, or the empty string, the current directory is assumed
    /// \param pattern The search pattern. If null, or the empty string, all entries are returned
    /// \param flags The flags with moderate the search
    this(in char[] searchRoot, in char[] pattern, in uint flags)
    {
        m_searchRoot    =   searchRoot;
        m_pattern       =   pattern;
        m_flags         =   flags;
    }

/// \name Types
public:
    class Enumerator
    {
    private:
        this(hrecls_t hSrch, recls_rc_t lastError)
        {
            m_hSrch     =   hSrch;
            m_lastError =   lastError;
        }
    public:
        ~this()
        {
            if(null != m_hSrch)
            {
                Search_Close(m_hSrch);
            }
        }

    public:
        boolean HasEntry()
        {
            return RECLS_SUCCEEDED(m_lastError);
        }

        Entry   CurrentEntry()
        in
        {
            assert(null !== m_hSrch);
        }
        body
        {
            recls_info_t    entry;
            recls_rc_t      rc  =   Search_GetEntry(m_hSrch, entry);

            m_lastError = rc;

            try
            {
                return Entry._make_Entry(entry);
            }
            finally
            {
                Search_CloseEntry(entry);
            }
        }

        recls_rc_t LastError()
        {
            return m_lastError;
        }

    public:
        boolean GetNextEntry()
        in
        {
            assert(null != m_hSrch);
        }
        body
        {
            recls_rc_t  rc  =   Search_GetNext(m_hSrch);

            m_lastError = rc;

            if(RECLS_FAILED(rc))
            {
                Search_Close(m_hSrch);

                if(RECLS_RC_NO_MORE_DATA != rc)
                {
                    // throw new ReclsException("Search continuation failed", rc);
                }
            }

            return RECLS_SUCCEEDED(rc);
        }

    /// Members
    private:
        hrecls_t    m_hSrch;    // NOTE THAT D DOES STRONG TYPEDEFS (see true-typedefs)
        recls_rc_t  m_lastError;
    }

/// Operations
public:
    Enumerator Enumerate()
    {
        hrecls_t    hSrch;
        recls_rc_t  rc  =   Search_Create(m_searchRoot, m_pattern, m_flags, hSrch);

        try
        {
            return new Enumerator(hSrch, rc);
        }
        catch(Exception x)
        {
            Search_Close(hSrch);

            throw x;
        }
    }

public:
    int opApply(int delegate(inout Entry entry) dg)
    {
        int             result  =   0;
        hrecls_t        hSrch;
        recls_rc_t      rc      =   Search_Create(m_searchRoot, m_pattern, m_flags, hSrch);
        recls_info_t    entry;

        do
        {
            if(RECLS_FAILED(rc))
            {
                if(RECLS_RC_NO_MORE_DATA != rc)
                {
                    // throw new ReclsException("Search continuation failed", rc);
                }

                result = 1;
            }
            else
            {
                rc = Search_GetEntry(hSrch, entry);

                if(RECLS_FAILED(rc))
                {
                    if(RECLS_RC_NO_MORE_DATA != rc)
                    {
                        // throw new ReclsException("Search continuation failed", rc);
                    }

                    result = 1;
                }
                else
                {
                    try
                    {
                        Entry   e = Entry._make_Entry(entry);

                        result = dg(e);
                    }
                    finally
                    {
                        Search_CloseEntry(entry);
                    }
                }

                rc = Search_GetNextEntry(hSrch, entry);
            }

        } while(result == 0);

        return result;
    }

/// Members
private:
    char[]  m_searchRoot;
    char[]  m_pattern;
    uint    m_flags;
}

/* public class Boolean
{
public:
    this(boolean value)
    {
        m_value = value;
    }

    op()
    {
        return m_value != 0;
    }

private:
    boolean m_value;
}
 */

/// Represents a search entry
public class Entry
{
    invariant
    {
        if(null != m_entry)
        {
            // Now do all the checks to verify that the various components of the path are valid

            // Since we cannot call member functions (as that would end up in recursion)
            // the only thing we can do is to "test" the validity of the entry handle, so
            // we just add a reference, and then release it
            recls_info_t    entry   =   Search_CopyEntry(m_entry);

            assert(null !== entry);

            Recls_CloseDetails(entry);
        }
    }

private:
    /// This is necessary, because DMD 0.73 generates code
    /// that goes into an infinite loop when creating an
    /// Entry instance with a non-null entry
    static Entry _make_Entry(recls_info_t entry)
    {
        recls_info_t    copy    =   Search_CopyEntry(entry);
        Entry           e       =   null;

        try
        {
            e = new Entry(null);

            e.m_entry = entry;
        }
        catch(Exception x)
        {
            Search_CloseEntry(copy);

            throw x;
        }

        return e;
    }

    this(recls_info_t entry)
    {
        m_entry = entry;
    }
    ~this()
    {
        if(null !== m_entry)
        {
            Search_CloseEntry(m_entry);
        }
    }

public:
    /// The full path of the entry
    ///
    /// \note For "/usr/include/recls/recls_assert.h" this would yield "/usr/include/recls/recls_assert.h"
    char[]              GetPath()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryPath(m_entry);
    }
    /// The full path of the entry
    ///
    /// \note For "/usr/include/recls/recls_assert.h" this would yield "/usr/include/recls/recls_assert.h"
    char[]              Path()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryPath(m_entry);
    }
version(Windows)
{
    /// The drive component of the entry's path
    ///
    /// \note For "H:\Dev\include\recls\recls_assert.h" this would yield 'H'
    char                Drive()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryDrive(m_entry);
    }
} // version(Windows)
    /// The directory component of the entry's path
    ///
    /// \note For "/usr/include/recls/recls_assert.h" this would yield "/usr/include/recls/"
    char[]              Directory()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryDirectory(m_entry);
    }
    /// The full location component of the entry's path.
    ///
    /// \note This is everything before the filename+fileext. On Win32 systems for "H:\Dev\include\recls\recls_assert.h" this would yield "H:\Dev\include\recls\"
    char[]              DirectoryPath()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryDirectoryPath(m_entry);
    }
    /// An array of strings representing the parts of the Directory property
    ///
    /// \note For "/usr/include/recls/recls_assert.h" this would yield [ "/", "usr/", "include/", "recls/"]
    char[][]            DirectoryParts()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryDirectoryParts(m_entry);
    }
    /// The file component of the entry's path
    ///
    /// \note For "/usr/include/recls/recls_assert.h" this would yield "recls_assert.h"
    char[]              File()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryFile(m_entry);
    }
    /// The short equivalent of the entry's File property
    ///
    /// \note On Win32 systems, this is the 8.3 form, e.g. "recls_~1.h". On other systems this is identical to the File property
    char[]              ShortFile()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryShortFile(m_entry);
    }
    /// The file name component of the entry's path
    ///
    /// \note For "/usr/include/recls/recls_assert.h" this would yield "recls_assert"
    char[]              FileName()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryFileName(m_entry);
    }
    /// The file extension component of the entry's path
    ///
    /// \note For "/usr/include/recls/recls_assert.h" this would yield "h"
    char[]              FileExt()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryFileExt(m_entry);
    }

    /// The time the entry was created
    recls_time_t        CreationTime()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryCreationTime(m_entry);
    }
    /// The time the entry was last modified
    recls_time_t        ModificationTime()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryModificationTime(m_entry);
    }
    /// The time the entry was last accessed
    recls_time_t        LastAccessTime()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryLastAccessTime(m_entry);
    }
    /// The time the entry's last status changed
    recls_time_t        LastStatusChangeTime()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntryLastStatusChangeTime(m_entry);
    }

    /// The size of the entry
    recls_filesize_t    Size()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_GetEntrySize(m_entry);
    }

    /// Indicates whether the entry is read-only
    boolean             IsReadOnly()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_IsEntryReadOnly(m_entry);
    }
    /// Indicates whether the entry is a directory
    boolean             IsDirectory()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_IsEntryDirectory(m_entry);
    }
    /// Indicates whether the entry is a link
    boolean             IsLink()
    in
    {
        assert(null !== m_entry);
    }
    body
    {
        return Search_IsEntryLink(m_entry);
    }

/// Members
private:
    recls_info_t    m_entry;
}

////////////////////////////////////////////////////////////////////////////////

unittest
{
    Search  search  =   new Search(".", "*.*", RECLS_FLAG.RECLS_F_RECURSIVE);

    foreach(Entry entry; search)
    {
        entry.Path();
version(Windows)
{
        entry.Drive();
} // version(Windows)
        entry.Directory();
        entry.DirectoryPath();
        entry.DirectoryParts();
        entry.File();
        entry.ShortFile();
        entry.FileName();
        entry.FileExt();
        entry.CreationTime();
        entry.ModificationTime();
        entry.LastAccessTime();
        entry.LastStatusChangeTime();
        entry.Size();
        entry.IsReadOnly();
        entry.IsDirectory();
        entry.IsLink();
    }
}

////////////////////////////////////////////////////////////////////////////////
