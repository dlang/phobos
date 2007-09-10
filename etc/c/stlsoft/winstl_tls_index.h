/* /////////////////////////////////////////////////////////////////////////////
 * File:        winstl_tls_index.h (formerly in MWTlsFns.h, ::SynesisWin)
 *
 * Purpose:     Win32 TLS slot index.
 *
 * Created:     20th January 1999
 * Updated:     24th September 2003
 *
 * Author:      Matthew Wilson, Synesis Software Pty Ltd.
 *
 * License:     (Licensed under the Synesis Software Standard Source License)
 *
 *              Copyright (C) 2002-2003, Synesis Software Pty Ltd.
 *
 *              All rights reserved.
 *
 *              www:        http://www.synesis.com.au/winstl
 *                          http://www.winstl.org/
 *
 *              email:      submissions@winstl.org  for submissions
 *                          admin@winstl.org        for other enquiries
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


#ifndef _WINSTL_INCL_H_WINSTL_TLS_INDEX
#define _WINSTL_INCL_H_WINSTL_TLS_INDEX

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define _WINSTL_VER_H_WINSTL_TLS_INDEX_MAJOR       1
# define _WINSTL_VER_H_WINSTL_TLS_INDEX_MINOR       0
# define _WINSTL_VER_H_WINSTL_TLS_INDEX_REVISION    1
# define _WINSTL_VER_H_WINSTL_TLS_INDEX_EDIT        2
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _WINSTL_INCL_H_WINSTL
# include "winstl.h"                // Include the WinSTL root header
#endif /* !_WINSTL_INCL_H_WINSTL */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#ifndef _WINSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
/* There is no stlsoft namespace, so must define ::winstl */
namespace winstl
{
 #else
/* Define stlsoft::winstl_project */

namespace stlsoft
{

namespace winstl_project
{

# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_WINSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

/// \weakgroup libraries STLSoft Libraries
/// \brief The individual libraries

/// \weakgroup libraries_system System Library
/// \ingroup libraries
/// \brief This library provides facilities for accessing system attributes

/// \defgroup winstl_system_library System Library (WinSTL)
/// \ingroup WinSTL libraries_system
/// \brief This library provides facilities for accessing Win32 system attributes
/// @{

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

/// A TLS index
///
/// 
class tls_index
{
public:
    typedef tls_index   class_type;

/// Operations
/// @{
public:
    ss_explicit_k tls_index() stlsoft_throw_0()
        : m_dwIndex(::TlsAlloc())
    {
        if(0xFFFFFFFF == m_dwIndex)
        {
            ::RaiseException(STATUS_NO_MEMORY, EXCEPTION_NONCONTINUABLE, 0, 0);
        }
    }
    ~tls_index() stlsoft_throw_0()
    {
        if(0xFFFFFFFF != m_dwIndex)
        {
            ::TlsFree(m_dwIndex);
        }
    }

/// @}

/// Operations
/// @{
public:
    operator ws_dword_t () const
    {
        return m_dwIndex;
    }

/// @}

// Members
private:
    ws_dword_t  m_dwIndex;

// Not to be implemented
private:
    tls_index(tls_index const &);
    tls_index &operator =(tls_index const &);
};

/* ////////////////////////////////////////////////////////////////////////// */

/// @} // end of group winstl_system_library

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _WINSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
} // namespace winstl
# else
} // namespace winstl_project
} // namespace stlsoft
# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_WINSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* _WINSTL_INCL_H_WINSTL_TLS_INDEX */

/* ////////////////////////////////////////////////////////////////////////// */
