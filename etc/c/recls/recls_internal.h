/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_internal.h
 *
 * Purpose:     Main header file for the recls API.
 *
 * Created:     15th August 2003
 * Updated:     24th November 2003
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


#ifndef RECLS_INCL_H_RECLS_INTERNAL
#define RECLS_INCL_H_RECLS_INTERNAL

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_INTERNAL_MAJOR       1
# define RECLS_VER_H_RECLS_INTERNAL_MINOR       2
# define RECLS_VER_H_RECLS_INTERNAL_REVISION    3
# define RECLS_VER_H_RECLS_INTERNAL_EDIT        12
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef __cplusplus
# error This file can only be included in C++ compilation units
#endif /* __cplusplus */

#include "recls.h"

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Macros
 */

#ifndef RECLS_NUM_ELEMENTS
# if defined(stlsoft_num_elements)
#  define RECLS_NUM_ELEMENTS(x)             stlsoft_num_elements(x)
# else /* ? stlsoft_num_elements */
#  define RECLS_NUM_ELEMENTS(x)             (sizeof(x) / sizeof((x)[0]))
# endif /* stlsoft_num_elements */
#endif /* !RECLS_NUM_ELEMENTS */

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

// class ReclsDNode
/// Interface for directory nodes
///
/// \note It has an ugly name-prefix if need to compile with compiler that does not support namespaces
struct ReclsDNode
{
    /// Destructory
    ///
    /// ReclsDNode instances are <b>not</b> reference-counted, but are
    /// deleted by their owner. They are non-shareable.
    virtual ~ReclsDNode() = 0;

    virtual recls_rc_t GetNext() = 0;

    virtual recls_rc_t GetDetails(recls_info_t *pinfo) = 0;

    virtual recls_rc_t GetNextDetails(recls_info_t *pinfo) = 0;
};

inline ReclsDNode::~ReclsDNode()
{}

// class ReclsDNode
/// Search info structure
///
/// \note It has an ugly name-prefix if need to compile with compiler that does not support namespaces
class ReclsSearchInfo
{
public:
    typedef recls_char_t    char_type;
    typedef ReclsSearchInfo class_type;

// Allocation
private:
    void *operator new(size_t cb, int cDirParts, size_t cbRootDir);
#if !defined(RECLS_COMPILER_IS_BORLAND) && \
    !defined(RECLS_COMPILER_IS_DMC) && \
    !defined(RECLS_COMPILER_IS_INTEL) && \
    !defined(RECLS_COMPILER_IS_WATCOM)
    void operator delete(void *pv, int cDirParts, size_t cbRootDir);
#endif /* !RECLS_COMPILER_IS_BORLAND && !RECLS_COMPILER_IS_DMC */
public:
    void operator delete(void *pv);

// Construction
protected:
    ReclsSearchInfo(int             cDirParts
                ,   char_type const *rootDir
                ,   char_type const *pattern
                ,   recls_uint32_t  flags);
public:
    static recls_rc_t FindAndCreate(char_type const *rootDir
                                ,   char_type const *pattern
                                ,   recls_uint32_t  flags
                                ,   ReclsSearchInfo **ppsi);

// Operations
public:
    recls_rc_t GetNext();

    recls_rc_t GetDetails(recls_info_t *pinfo);

    recls_rc_t GetNextDetails(recls_info_t *pinfo);

// Accessors
public:
    recls_rc_t  GetLastError() const;

// Handle interconversion
public:
    static hrecls_t         ToHandle(ReclsSearchInfo *si);
    static ReclsSearchInfo  *FromHandle(hrecls_t h);

// Implementation
private:
    char_type const *_calc_rootDir(int cDirParts, char_type const *rootDir);

// Members
private:
    recls_uint32_t          m_flags;
    ReclsDNode              *m_dnode;
    recls_rc_t              m_lastError;
    char_type const * const m_rootDir;

    /** The opaque data of the search */
    recls_byte_t            data[1];
    /*
     * The data comprises:
     *
     *  - root dir
     *
     */

// Not to be implemented
private:
    ReclsSearchInfo(ReclsSearchInfo const &);
    ReclsSearchInfo &operator =(ReclsSearchInfo const &);
};

inline /* static */ hrecls_t ReclsSearchInfo::ToHandle(ReclsSearchInfo *si)
{
    return hrecls_t(si);
}

inline /* static */ ReclsSearchInfo *ReclsSearchInfo::FromHandle(hrecls_t h)
{
    return const_cast<ReclsSearchInfo *>(reinterpret_cast<ReclsSearchInfo const *>(h));
}

/* /////////////////////////////////////////////////////////////////////////////
 * File info functions
 */

RECLS_FNDECL(recls_info_t)  FileInfo_Allocate(  size_t          cb);
RECLS_FNDECL(void)          FileInfo_Release(   recls_info_t    fileInfo);
RECLS_FNDECL(recls_rc_t)    FileInfo_Copy(      recls_info_t    fileInfo
                                            ,   recls_info_t    *pinfo);

RECLS_FNDECL(void)          FileInfo_BlockCount(recls_sint32_t  *pcCreated
                                            ,   recls_sint32_t  *pcShared);

/* /////////////////////////////////////////////////////////////////////////////
 * Helper functions
 */

RECLS_FNDECL(size_t) Recls_GetStringProperty_(  struct recls_strptrs_t const    *ptrs
                                            ,   recls_char_t                    *buffer
                                            ,   size_t                          cchBuffer);

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !RECLS_INCL_H_RECLS_INTERNAL */

/* ////////////////////////////////////////////////////////////////////////// */
