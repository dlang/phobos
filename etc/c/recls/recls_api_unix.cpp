/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_api_unix.cpp
 *
 * Purpose:     Win32 implementation file for the recls API.
 *
 * Created:     16th August 2003
 * Updated:     27th November 2003
 *
 * License:     (Licensed under the Synesis Software Standard Source License)
 *
 *              Copyright (C) 2002-2003, Synesis Software Pty Ltd.
 *
 *              All rights reserved.
 *
 *              www:        http://www.synesis.com.au/software
 *                          http://www.recls.org/
 *
 *              email:      submissions@recls.org  for submissions
 *                          admin@recls.org        for other enquiries
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


/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#include "recls.h"
#include "recls_internal.h"
#include "recls_assert.h"
#include "recls_util.h"

#include <stlsoft_nulldef.h>

#include <unixstl_filesystem_traits.h>
#include <unixstl_glob_sequence.h>

# include <sys/types.h>
# include <sys/stat.h>

#include "recls_debug.h"

#include <algorithm>

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

unixstl_ns_using(glob_sequence)

typedef unixstl_ns_qual(filesystem_traits)<recls_char_t>    traits_type; // We need to do this, because VC is a bit thick

/* /////////////////////////////////////////////////////////////////////////////
 * Utility functions
 */

#if defined(_DEBUG) && \
    defined(RECLS_PLATFORM_IS_WIN32)

/* static */ tls_index  function_scope::sm_index;

#endif /* _DEBUG */

/* ////////////////////////////////////////////////////////////////////////// */

static recls_info_t create_entryinfo_from_psrecord(recls_char_t const * /* rootDir */, recls_uint32_t flags, recls_char_t const *entry)
{
    typedef recls_char_t    char_type;

    recls_char_t    rootDir[PATH_MAX];
    recls_char_t    entryName[PATH_MAX];
    recls_char_t    *name_start;

    traits_type::str_copy(rootDir, entry);
    name_start = strrchr(rootDir, '/');
    traits_type::str_copy(entryName, ++name_start);
    *name_start = '\0';

    function_scope_trace("create_entryinfo_from_psrecord");

    // size of structure is:
    //
    //    offsetof(struct recls_fileinfo_t, data)
    //  + directory parts
    //  + full path (+ null)
    //  + short name (+ null)

    size_t  cchRootDir  =   traits_type::str_len(rootDir);

//    recls_assert(cchRootDir > 0);
//    recls_assert(rootDir[cchRootDir - 1] == traits_type::path_name_separator());

    size_t  cchFileName =   traits_type::str_len(entryName);
    size_t  cDirParts   =   ((flags & RECLS_F_DIRECTORY_PARTS) == RECLS_F_DIRECTORY_PARTS) ? count_dir_parts(rootDir, rootDir + cchRootDir) : 0;
    size_t  cbPath      =   align_up_size(sizeof(char_type) * (1 + cchRootDir + cchFileName));
    size_t  cb          =   offsetof(struct recls_fileinfo_t, data)
                        +   cDirParts * sizeof(recls_strptrs_t)
                        +   cbPath;

    struct recls_fileinfo_t *info   =   const_cast<struct recls_fileinfo_t*>(FileInfo_Allocate(cb));

    if(NULL != info)
    {
        char_type               *fullPath   =   (char_type*)&info->data[cDirParts * sizeof(recls_strptrs_t)];
//      char_type               *altName    =   (char_type*)&info->data[cDirParts * sizeof(recls_strptrs_t) + cbPath];

        // full path
        traits_type::str_copy(fullPath, rootDir);
        traits_type::str_cat(fullPath, entryName);
        info->path.begin                    =   fullPath;
        info->path.end                      =   fullPath + cchRootDir + cchFileName;

        // directory, file (name + ext)
        info->directory.begin               =   fullPath;
        info->directory.end                 =   fullPath + cchRootDir;
        info->fileName.begin                =   info->directory.end;
        info->fileName.end                  =   strrchr(info->directory.end, '.');
        if(NULL != info->fileName.end)
        {
            info->fileExt.begin             =   info->fileName.end + 1;
            info->fileExt.end               =   info->directory.end +  cchFileName;
        }
        else
        {
            info->fileName.end              =   info->directory.end +  cchFileName;
            info->fileExt.begin             =   info->directory.end +  cchFileName;
            info->fileExt.end               =   info->directory.end +  cchFileName;
        }

        // determine the directory parts
        char_type const         *p          =   info->directory.begin;
        char_type const         *l          =   info->directory.end;
        struct recls_strptrs_t  *begin      =   (struct recls_strptrs_t*)&info->data[0];

        info->directoryParts.begin          =   begin;
        info->directoryParts.end            =   begin + cDirParts;

        if(info->directoryParts.begin != info->directoryParts.end)
        {
            recls_assert((flags & RECLS_F_DIRECTORY_PARTS) == RECLS_F_DIRECTORY_PARTS);

            begin->begin = p;

            for(; p != l; ++p)
            {
                if(*p == traits_type::path_name_separator())
                {
                    begin->end = p + 1;

                    if(++begin != info->directoryParts.end)
                    {
                        begin->begin = p + 1;
                    }
                }
            }
        }

        struct stat st;

        stat(fullPath, &st);

        // attributes
        info->attributes            =   st.st_mode;

        // time, size
        info->lastStatusChangeTime  =   st.st_ctime;
        info->modificationTime      =   st.st_mtime;
        info->lastAccessTime        =   st.st_atime;
        info->size                  =   st.st_size;

        // Checks
        recls_assert(info->path.begin < info->path.end);

        recls_assert(info->directory.begin < info->directory.end);
        recls_assert(info->path.begin <= info->directory.begin);
        recls_assert(info->directory.end <= info->path.end);

        recls_assert(info->fileName.begin <= info->fileName.end);

        recls_assert(info->fileExt.begin <= info->fileExt.end);

        recls_assert(info->fileName.begin < info->fileExt.end);
        recls_assert(info->fileName.end <= info->fileExt.begin);
    }

    return info;
}

/* /////////////////////////////////////////////////////////////////////////////
 * PlatformDirectoryNode
 */

class PlatformDirectoryNode
    : public ReclsDNode
{
public:
    typedef recls_char_t            char_type;
    typedef PlatformDirectoryNode   class_type;
private:
    typedef glob_sequence           directory_sequence_t;
    typedef glob_sequence           entry_sequence_t;

// Construction
private:
    PlatformDirectoryNode(recls_uint32_t flags, char_type const *rootDir, char_type const *pattern);
public:
    virtual ~PlatformDirectoryNode();

    static PlatformDirectoryNode *FindAndCreate(recls_uint32_t flags, char_type const *rootDir, char_type const *pattern);
    static PlatformDirectoryNode *FindAndCreate(recls_uint32_t flags, char_type const *rootDir, char_type const *subDir, char_type const *pattern);

// ReclsDNode methods
private:
    virtual recls_rc_t GetNext();
    virtual recls_rc_t GetDetails(recls_info_t *pinfo);
    virtual recls_rc_t GetNextDetails(recls_info_t *pinfo);

// Implementation
private:
    recls_rc_t      Initialise();

    recls_bool_t    _is_valid() const;

#if defined(RECLS_COMPILER_IS_BORLAND)
    static directory_sequence_t::const_iterator _select_iter(int b, directory_sequence_t::const_iterator trueVal, directory_sequence_t::const_iterator falseVal)
    {
        // I can't explain it, but Borland does not like the tertiary operator and the copy-ctors of the iterators
        if(b)
        {
            return trueVal;
        }
        else
        {
            return falseVal;
        }
    }
#endif /* !RECLS_COMPILER_IS_BORLAND */
    static int _ssFlags_from_reclsFlags(recls_uint32_t flags)
    {
        recls_assert(0 == (flags & RECLS_F_LINKS));     // Doesn't work with links
        recls_assert(0 == (flags & RECLS_F_DEVICES));   // Doesn't work with devices

        int ssFlags = 0;

        if(0 != (flags & RECLS_F_FILES))
        {
            ssFlags |= entry_sequence_t::files;
        }
        if(0 != (flags & RECLS_F_DIRECTORIES))
        {
            ssFlags |= entry_sequence_t::directories;
        }

        return ssFlags;
    }

// Members
private:
    recls_info_t                            m_current;
    ReclsDNode                              *m_dnode;
    recls_uint32_t const                    m_flags;
    entry_sequence_t                        m_entries;
    entry_sequence_t::const_iterator        m_entriesBegin;
    directory_sequence_t                    m_directories;
    directory_sequence_t::const_iterator    m_directoriesBegin;
    char_type                               m_rootDir[RECLS_PATH_MAX];
    char_type                               m_pattern[RECLS_PATH_MAX];
};

PlatformDirectoryNode::PlatformDirectoryNode(recls_uint32_t flags, PlatformDirectoryNode::char_type const *rootDir, PlatformDirectoryNode::char_type const *pattern)
    : m_current(NULL)
    , m_dnode(NULL)
    , m_flags(flags)
    , m_entries(rootDir, pattern, _ssFlags_from_reclsFlags(flags))
    , m_entriesBegin(m_entries.begin())
#ifdef _MSC_VER // For testing
    , m_directories(rootDir, "*.*", directory_sequence_t::directories)
#else /* ? _MSC_VER */
    , m_directories(rootDir, traits_type::pattern_all(), directory_sequence_t::directories)
#endif /* _MSC_VER */
#if !defined(RECLS_COMPILER_IS_BORLAND)
    , m_directoriesBegin((flags & RECLS_F_RECURSIVE) ? m_directories.begin() : m_directories.end())
#else
    , m_directoriesBegin(_select_iter((flags & RECLS_F_RECURSIVE), m_directories.begin(), m_directories.end()))
#endif /* !RECLS_COMPILER_IS_BORLAND */
{
    function_scope_trace("PlatformDirectoryNode::PlatformDirectoryNode");

#if defined(RECLS_COMPILER_IS_BORLAND)
//    m_directoriesBegin = ((flags & RECLS_F_RECURSIVE) ? m_directories.begin() : m_directories.end());
#endif /* !RECLS_COMPILER_IS_BORLAND */

    traits_type::str_copy(m_rootDir, rootDir);
    traits_type::ensure_dir_end(m_rootDir);
    traits_type::str_copy(m_pattern, pattern);

    recls_assert(stlsoft_raw_offsetof(PlatformDirectoryNode, m_entries) < stlsoft_raw_offsetof(PlatformDirectoryNode, m_entriesBegin));
    recls_assert(stlsoft_raw_offsetof(PlatformDirectoryNode, m_directories) < stlsoft_raw_offsetof(PlatformDirectoryNode, m_directoriesBegin));
}

inline /* static */ PlatformDirectoryNode *PlatformDirectoryNode::FindAndCreate(recls_uint32_t flags, PlatformDirectoryNode::char_type const *rootDir, PlatformDirectoryNode::char_type const *pattern)
{
    PlatformDirectoryNode  *node;

    function_scope_trace("PlatformDirectoryNode::FindAndCreate");

#ifdef RECLS_COMPILER_THROWS_ON_NEW_FAIL
    try
    {
#endif /* RECLS_COMPILER_THROWS_ON_NEW_FAIL */
        node = new PlatformDirectoryNode(flags, rootDir, pattern);
#ifdef RECLS_COMPILER_THROWS_ON_NEW_FAIL
    }
    catch(std::bad_alloc &)
    {
        node = NULL;
    }
#endif /* RECLS_COMPILER_THROWS_ON_NEW_FAIL */

    if(NULL != node)
    {
        // Ensure that it, or one of its sub-nodes, has matching entries.
        recls_rc_t  rc = node->Initialise();

        if(RECLS_FAILED(rc))
        {
            delete node;

            node = NULL;
        }
    }

    recls_assert(NULL == node || node->_is_valid());

    return node;
}

inline /* static */ PlatformDirectoryNode *PlatformDirectoryNode::FindAndCreate(recls_uint32_t flags, PlatformDirectoryNode::char_type const *rootDir, PlatformDirectoryNode::char_type const *subDir, PlatformDirectoryNode::char_type const *pattern)
{
    char_type   compositeDir[RECLS_PATH_MAX];

    recls_assert(rootDir[traits_type::str_len(rootDir) - 1] == traits_type::path_name_separator());

    // Only need subdir, since globbing provides partial path
    traits_type::str_copy(compositeDir, subDir);

    return FindAndCreate(flags, compositeDir, pattern);
}

PlatformDirectoryNode::~PlatformDirectoryNode()
{
    function_scope_trace("PlatformDirectoryNode::~PlatformDirectoryNode");

    FileInfo_Release(m_current);

    delete m_dnode;
}

recls_rc_t PlatformDirectoryNode::Initialise()
{
    function_scope_trace("PlatformDirectoryNode::Initialise");

    recls_rc_t  rc;

    recls_assert(NULL == m_current);
    recls_assert(NULL == m_dnode);

    if(m_entriesBegin != m_entries.end())
    {
        // (i) Try getting a file first,
        m_current = create_entryinfo_from_psrecord(m_rootDir, m_flags, *m_entriesBegin);

        if(NULL == m_current)
        {
            rc = RECLS_RC_OUT_OF_MEMORY;
        }
        else
        {
            rc = RECLS_RC_OK;
        }
    }
    else
    {
        if(m_directoriesBegin == m_directories.end())
        {
            rc = RECLS_RC_NO_MORE_DATA;
        }
        else
        {
            do
            {
#if 1
                // The way glob_sequence works
                m_dnode = PlatformDirectoryNode::FindAndCreate(m_flags, m_rootDir, *m_directoriesBegin, m_pattern);
#else /* ? 0 */
//                m_dnode = PlatformDirectoryNode::FindAndCreate(m_flags, (*m_directoriesBegin).get_path(), m_pattern);
#endif /* 0 */

            } while(NULL == m_dnode && ++m_directoriesBegin != m_directories.end());

            rc = (NULL == m_dnode) ? RECLS_RC_NO_MORE_DATA : RECLS_RC_OK;
        }
    }

    if(RECLS_SUCCEEDED(rc))
    {
        recls_assert(_is_valid());
    }

    return rc;
}

recls_bool_t PlatformDirectoryNode::_is_valid() const
{
    function_scope_trace("PlatformDirectoryNode::_is_valid");

    recls_rc_t  rc  =   RECLS_RC_OK;

#ifdef STLSOFT_CF_PRAGMA_MESSAGE_SUPPORT
# pragma message("Flesh these out")
#endif /* STLSOFT_CF_PRAGMA_MESSAGE_SUPPORT */
    if(RECLS_SUCCEEDED(rc))
    {

    }

    if(RECLS_SUCCEEDED(rc))
    {
    }

    if(RECLS_SUCCEEDED(rc))
    {
    }

    if(RECLS_SUCCEEDED(rc))
    {
    }

    // (i) Either we are enumerating files (m_current != NULL) or directories (m_dnode != NULL), but not both
    recls_assert(NULL == m_current || NULL == m_dnode);
    // (ii) Either we are enumerating files (m_current != NULL) or there are no more files to enumerate
    recls_assert(NULL != m_current || m_entriesBegin == m_entries.end());

    return RECLS_SUCCEEDED(rc);
}


recls_rc_t PlatformDirectoryNode::GetNext()
{
    function_scope_trace("PlatformDirectoryNode::GetNext");

    recls_assert(_is_valid());

    /* Searching operates as follows:
     *
     * 1. Return all the contents of the files
     * 2. Return the contents of the directories.
     *
     * Hence, if m_dnode is non-NULL, we've already searched
     */

    /* States:
     *
     * - Iterating files: m_entriesBegin != m_entries.end(), m_dnode is NULL, m_directoriesBegin != m_directories.end()
     * - Iterating directories: m_directoriesBegin != m_directories.end(), m_dnode is non-NULL, m_current is NULL
     *
     */

    // Invariants

    // (i) Either we are enumerating files (m_current != NULL) or directories (m_dnode != NULL), but not both
    recls_assert(NULL == m_current || NULL == m_dnode);
    // (ii) Either we are enumerating files (m_current != NULL) or there are no more files to enumerate
    recls_assert(NULL != m_current || m_entriesBegin == m_entries.end());

    recls_rc_t  rc = RECLS_RC_NO_MORE_DATA;

    if(NULL != m_current)
    {
        // Currently enumerating through the files

        recls_assert(m_entriesBegin != m_entries.end());
        recls_assert(NULL == m_dnode);

        // Advance, and check for end of sequence
        ++m_entriesBegin;

        FileInfo_Release(m_current);
        if(m_entriesBegin != m_entries.end())
        {
            // Still enumerating, so just update m_current
            m_current = create_entryinfo_from_psrecord(m_rootDir, m_flags, *m_entriesBegin);

            rc = RECLS_RC_OK;
        }
        else
        {
            // No more left in the files sequence, so delete m_current
            m_current = NULL;

            rc = RECLS_RC_NO_MORE_DATA;
        }
    }

    if(NULL == m_current)
    {
        // Now we are either enumerating the directories, or we've already done so

        if(NULL != m_dnode)
        {
            // Currently enumerating the directories
            rc = m_dnode->GetNext();

            if(RECLS_RC_NO_MORE_DATA == rc)
            {
                ++m_directoriesBegin;

                delete m_dnode;

                m_dnode = NULL;
            }
        }

        if(m_directoriesBegin == m_directories.end())
        {
            // Enumeration is complete.
            rc = RECLS_RC_NO_MORE_DATA;
        }
        else
        {
            if(NULL == m_dnode)
            {
                do
                {
                    // Creation of the node will cause it to enter the first enumeration
                    // state. However, if there are no matching

                    recls_assert(m_directoriesBegin != m_directories.end());

#if 1
                    // The way glob_sequence works
                    m_dnode = PlatformDirectoryNode::FindAndCreate(m_flags, m_rootDir, *m_directoriesBegin, m_pattern);
#else /* ? 0 */
//                    m_dnode = PlatformDirectoryNode::FindAndCreate(m_flags, (*m_directoriesBegin).get_path(), m_pattern);
#endif /* 0 */

                    if(NULL != m_dnode)
                    {
                        rc = RECLS_RC_OK;
                    }
                    else
                    {
                        ++m_directoriesBegin;
                    }

                } while(NULL == m_dnode && m_directoriesBegin != m_directories.end());
            }
        }
    }

    recls_assert(_is_valid());

    return rc;
}

recls_rc_t PlatformDirectoryNode::GetDetails(recls_info_t *pinfo)
{
    function_scope_trace("PlatformDirectoryNode::GetDetails");

    recls_assert(_is_valid());

    recls_rc_t  rc;

    recls_assert(NULL != pinfo);
    recls_assert(NULL == m_current || NULL == m_dnode);

    if(NULL != m_current)
    {
        // Currently searching for files from the current directory

        recls_assert(NULL == m_dnode);

        rc = FileInfo_Copy(m_current, pinfo);

#if defined(_DEBUG) && \
    defined(RECLS_PLATFORM_IS_WIN32)
        {
            recls_char_t    buffer[RECLS_PATH_MAX];

            Recls_GetPathProperty(m_current, buffer, stlsoft_num_elements(buffer));

            debug_printf("    [%s]\n", buffer);
        }
#endif /* _DEBUG */
    }
    else if(NULL != m_dnode)
    {
        recls_assert(NULL == m_current);

        // Sub-directory searching is active, so get from there.

        rc = m_dnode->GetDetails(pinfo);
    }
    else
    {
        // Enumeration has completed
        rc = RECLS_RC_NO_MORE_DATA;
    }

    recls_assert(_is_valid());

    return rc;
}

recls_rc_t PlatformDirectoryNode::GetNextDetails(recls_info_t *pinfo)
{
    function_scope_trace("PlatformDirectoryNode::GetNextDetails");

    recls_assert(_is_valid());
    recls_assert(NULL != pinfo);

    recls_rc_t  rc  =   GetNext();

    if(RECLS_SUCCEEDED(rc))
    {
        rc = GetDetails(pinfo);
    }

    recls_assert(_is_valid());

    return rc;
}

/* /////////////////////////////////////////////////////////////////////////////
 * ReclsSearchInfo
 */

void *ReclsSearchInfo::operator new(size_t cb, int cDirParts, size_t cbRootDir)
{
    function_scope_trace("ReclsSearchInfo::operator new");

    cbRootDir = align_up_size(cbRootDir);

    recls_assert(cb > stlsoft_raw_offsetof(ReclsSearchInfo, data));

    cb = stlsoft_raw_offsetof(ReclsSearchInfo, data)
       + (cDirParts) * sizeof(recls_strptrs_t)
       + cbRootDir;

    return malloc(cb);
}

#if !defined(RECLS_COMPILER_IS_BORLAND) && \
    !defined(RECLS_COMPILER_IS_DMC)
void ReclsSearchInfo::operator delete(void *pv, int /* cDirParts */, size_t /* cbRootDir */)
{
    function_scope_trace("ReclsSearchInfo::operator delete");

    free(pv);
}
#endif /* !RECLS_COMPILER_IS_BORLAND && !RECLS_COMPILER_IS_DMC */

void ReclsSearchInfo::operator delete(void *pv)
{
    function_scope_trace("ReclsSearchInfo::operator delete");

    free(pv);
}

inline /* static */ recls_rc_t ReclsSearchInfo::FindAndCreate(ReclsSearchInfo::char_type const *rootDir, ReclsSearchInfo::char_type const *pattern, recls_uint32_t flags, ReclsSearchInfo **ppsi)
{
    function_scope_trace("ReclsSearchInfo::FindAndCreate");

    recls_rc_t      rc;
    ReclsSearchInfo *si;
    char_type       fullPath[RECLS_PATH_MAX];
    size_t          cchFullPath;

    *ppsi = NULL;

    cchFullPath = traits_type::get_full_path_name(rootDir, RECLS_NUM_ELEMENTS(fullPath), fullPath);
    if( 0 == cchFullPath ||
        !file_exists(fullPath))
    {
        rc = RECLS_RC_INVALID_DIRECTORY;
    }
    else
    {
#if defined(EMULATE_UNIX_ON_WIN32)
        recls_char_t    *_fullPath =    fullPath;
        recls_char_t    *fullPath   =   _fullPath + 2;

        std::replace(fullPath, fullPath + cchFullPath, '\\', traits_type::path_name_separator());
#endif /* EMULATE_UNIX_ON_WIN32 */

        traits_type::ensure_dir_end(fullPath);

        size_t      lenSearchRoot   =   traits_type::str_len(fullPath);

        recls_assert(0 < lenSearchRoot);

        rootDir = fullPath;

        // Count the directory parts. This is always done for the ReclsSearchInfo class, since it
        // uses them to recurse.
        char_type const         *begin      =   rootDir;
        char_type const *const  end         =   rootDir + lenSearchRoot;
        int                     cDirParts   =   count_dir_parts(begin, end);

#ifdef RECLS_COMPILER_THROWS_ON_NEW_FAIL
        try
        {
#endif /* RECLS_COMPILER_THROWS_ON_NEW_FAIL */
            si = new(cDirParts, sizeof(char_type) * (1 + lenSearchRoot)) ReclsSearchInfo(cDirParts, rootDir, pattern, flags);
#ifdef RECLS_COMPILER_THROWS_ON_NEW_FAIL
        }
        catch(std::bad_alloc &)
        {
            si = NULL;
        }
#endif /* RECLS_COMPILER_THROWS_ON_NEW_FAIL */

        if(NULL == si)
        {
            rc = RECLS_RC_FAIL;
        }
        else
        {
            // This is a nasty hack. It's tantamount to ctor & create function, so
            // should be made more elegant soon.
            if(NULL == si->m_dnode)
            {
                delete si;

                si = NULL;

                rc = RECLS_RC_NO_MORE_DATA;
            }
            else
            {
                *ppsi = si;

                rc = RECLS_RC_OK;
            }
        }
    }

    return rc;
}

ReclsSearchInfo::char_type const *ReclsSearchInfo::_calc_rootDir(int cDirParts, ReclsSearchInfo::char_type const *rootDir)
{
    function_scope_trace("ReclsSearchInfo::_calc_rootDir");

    // Root dir is located after file parts, and before pattern
    return traits_type::str_copy((char_type*)&data[cDirParts * sizeof(recls_strptrs_t)], rootDir);
}

ReclsSearchInfo::ReclsSearchInfo(   int                                 cDirParts
                                ,   ReclsSearchInfo::char_type const    *rootDir
                                ,   ReclsSearchInfo::char_type const    *pattern
                                ,   recls_uint32_t                      flags)
    : m_flags(flags)
    , m_lastError(RECLS_RC_OK)
    , m_rootDir(_calc_rootDir(cDirParts, rootDir))
{
    function_scope_trace("ReclsSearchInfo::ReclsSearchInfo");

    recls_assert(NULL != rootDir);
    recls_assert(NULL != pattern);
    recls_assert(traits_type::str_len(rootDir) < RECLS_PATH_MAX);
    recls_assert(traits_type::str_len(pattern) < RECLS_PATH_MAX);

    // Initialise the directory parts.

    recls_assert(rootDir[1] != ':');

//    char_type const         *p          =   rootDir;
//    struct recls_strptrs_t  *begin      =   (struct recls_strptrs_t*)&data[0];

    // Now start the search
    m_dnode = PlatformDirectoryNode::FindAndCreate(m_flags, rootDir, pattern);
}

// Operations
recls_rc_t ReclsSearchInfo::GetNext()
{
    function_scope_trace("ReclsSearchInfo::GetNext");

    recls_assert(NULL != m_dnode);

    m_lastError =   m_dnode->GetNext();

    if(RECLS_RC_NO_MORE_DATA == m_lastError)
    {
        delete m_dnode;

        m_dnode = NULL;
    }

    return m_lastError;
}

recls_rc_t ReclsSearchInfo::GetDetails(recls_info_t *pinfo)
{
    function_scope_trace("ReclsSearchInfo::GetDetails");

    recls_assert(NULL != m_dnode);

    return (m_lastError = m_dnode->GetDetails(pinfo));
}

recls_rc_t ReclsSearchInfo::GetNextDetails(recls_info_t *pinfo)
{
    function_scope_trace("ReclsSearchInfo::GetNextDetails");

    recls_assert(NULL != m_dnode);

    m_lastError =   m_dnode->GetNextDetails(pinfo);

    if(RECLS_RC_NO_MORE_DATA == m_lastError)
    {
        delete m_dnode;
    }

    return m_lastError;
}

// Accessors

recls_rc_t ReclsSearchInfo::GetLastError() const
{
    function_scope_trace("ReclsSearchInfo::GetLastError");

    return m_lastError;
}

/* /////////////////////////////////////////////////////////////////////////////
 * Search control
 */

RECLS_FNDECL(recls_rc_t) Recls_Search(  recls_char_t const  *searchRoot
                                    ,   recls_char_t const  *pattern
                                    ,   recls_uint32_t      flags
                                    ,   hrecls_t            *phSrch)
{
    function_scope_trace("Recls_Search");

    recls_assert(NULL != searchRoot);
    recls_assert(NULL != pattern);
    recls_assert(NULL != phSrch);

    *phSrch = ReclsSearchInfo::ToHandle(NULL);

    recls_rc_t  rc;

    // Validate the search root
    if( NULL == searchRoot ||
        0 == *searchRoot)
    {
        searchRoot = ".";
    }

    // Validate the flags
    if(0 == (flags & RECLS_F_TYPEMASK))
    {
        flags |= RECLS_F_FILES;
    }

    // Since Win32 does not support all search types, we need to inform
    // the caller if they ask to create a search that can never be
    // satisfied.
    if(0 == (flags & (RECLS_F_FILES | RECLS_F_DIRECTORIES)))
    {
        rc = RECLS_RC_INVALID_SEARCH_TYPE;
    }
    // Validate the pattern.
    else if('\0' == *pattern)
    {
        rc = RECLS_RC_NO_MORE_DATA;
    }
    else
    {
        ReclsSearchInfo *si;

        rc = ReclsSearchInfo::FindAndCreate(searchRoot, pattern, flags, &si);

        if(RECLS_SUCCEEDED(rc))
        {
            *phSrch = ReclsSearchInfo::ToHandle(si);

            rc = RECLS_RC_OK;
        }
    }

    return rc;
}

/* /////////////////////////////////////////////////////////////////////////////
 * Error handling
 */

RECLS_FNDECL(size_t) Recls_GetErrorString(  recls_rc_t      rc
                                        ,   recls_char_t    *buffer
                                        ,   size_t          cchBuffer)
{
    function_scope_trace("Recls_GetErrorString");

    recls_assert(NULL != buffer);

    if(rc == RECLS_RC_SEARCH_NO_CURRENT)
    {
        strncpy(buffer, "Search has no current node", cchBuffer);
    }
    else if(rc == RECLS_RC_INVALID_DIRECTORY)
    {
        strncpy(buffer, "Invalid directory", cchBuffer);
    }
    else if(rc == RECLS_RC_NO_MORE_DATA)
    {
        strncpy(buffer, "No more data", cchBuffer);
    }
    else if(rc == RECLS_RC_OUT_OF_MEMORY)
    {
        strncpy(buffer, "No more memory", cchBuffer);
    }

    return strlen(buffer);
}

/* /////////////////////////////////////////////////////////////////////////////
 * Property elicitation
 */

RECLS_FNDECL(size_t) Recls_GetDirectoryPathProperty(    recls_info_t    fileInfo
                                                    ,   recls_char_t    *buffer
                                                    ,   size_t          cchBuffer)
{
    function_scope_trace("Recls_GetDirectoryPathProperty");

    recls_assert(NULL != fileInfo);

    struct recls_strptrs_t directoryPath =
    {
            fileInfo->path.begin    /* Directory path is defined by start of path ... */
        ,   fileInfo->directory.end /* ... to end of directory. */
    };

    return Recls_GetStringProperty_(&directoryPath, buffer, cchBuffer);
}

RECLS_FNDECL(recls_bool_t) Recls_IsFileReadOnly(recls_info_t fileInfo)
{
    function_scope_trace("Recls_IsFileReadOnly");

    recls_assert(NULL != fileInfo);

    return (fileInfo->attributes & S_IWRITE) == 0;
}

RECLS_FNDECL(recls_bool_t) Recls_IsFileDirectory(recls_info_t fileInfo)
{
    function_scope_trace("Recls_IsFileDirectory");

    recls_assert(NULL != fileInfo);

    return (fileInfo->attributes & S_IFMT) == S_IFDIR;
}

RECLS_FNDECL(recls_bool_t) Recls_IsFileLink(recls_info_t fileInfo)
{
    function_scope_trace("Recls_IsFileLink");

    recls_assert(NULL != fileInfo);
    ((void)fileInfo);

    return false;
}

RECLS_FNDECL(recls_time_t) Recls_GetCreationTime(recls_info_t fileInfo)
{
    function_scope_trace("Recls_GetCreationTime");

    recls_assert(NULL != fileInfo);

    return fileInfo->modificationTime;
}

RECLS_FNDECL(recls_time_t) Recls_GetLastStatusChangeTime(recls_info_t fileInfo)
{
    function_scope_trace("Recls_GetLastStatusChangeTime");

    recls_assert(NULL != fileInfo);

    return fileInfo->lastStatusChangeTime;
}

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */
