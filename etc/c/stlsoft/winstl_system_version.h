/* /////////////////////////////////////////////////////////////////////////////
 * File:        winstl_system_version.h
 *
 * Purpose:     Contains the basic_system_version class, which provides
 *              information about the host system version.
 *
 * Created:     10th February 2002
 * Updated:     24th November 2003
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


#ifndef _WINSTL_INCL_H_WINSTL_SYSTEM_VERSION
#define _WINSTL_INCL_H_WINSTL_SYSTEM_VERSION

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define _WINSTL_VER_H_WINSTL_SYSTEM_VERSION_MAJOR      1
# define _WINSTL_VER_H_WINSTL_SYSTEM_VERSION_MINOR      5
# define _WINSTL_VER_H_WINSTL_SYSTEM_VERSION_REVISION   2
# define _WINSTL_VER_H_WINSTL_SYSTEM_VERSION_EDIT       22
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _WINSTL_INCL_H_WINSTL
 #include "winstl.h"                // Include the WinSTL root header
#endif /* !_WINSTL_INCL_H_WINSTL */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#ifndef _WINSTL_NO_NAMESPACE
 #ifdef _STLSOFT_NO_NAMESPACE
/* There is no stlsoft namespace, so must define ::winstl */
namespace winstl
{
 #else
/* Define stlsoft::winstl_project */

namespace stlsoft
{

namespace winstl_project
{

 #endif /* _STLSOFT_NO_NAMESPACE */
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

/// Provides system version information
///
/// This class wraps the GetSystemInfo() API function. Since the information that
/// this function provides is constant for any particular active system for its
/// lifetime, the function is called only once, as implemented via the
/// _get_versioninfo() method.
class system_version
{
public:
    typedef system_version class_type;

// Operations
public:

    // Operating system type

    /// Returns \c true if the operating system is one of the NT family (NT, 2000, XP, .NET)
    static ws_bool_t winnt()
    {
        return _get_versioninfo().dwPlatformId == VER_PLATFORM_WIN32_NT;
    }

    /// Returns \c true if the operating system is one of the 95 family (95, 98, ME)
    static ws_bool_t win9x()
    {
        return _get_versioninfo().dwPlatformId == VER_PLATFORM_WIN32_WINDOWS;
    }

    /// Returns \c true if the operating system is Win32s
    static ws_bool_t win32s()
    {
        return _get_versioninfo().dwPlatformId == VER_PLATFORM_WIN32s;
    }

    // Operating system version

    /// Returns the operating system major version
    static ws_uint_t major()
    {
        return _get_versioninfo().dwMajorVersion;
    }

    /// Returns the operating system minor version
    static ws_uint_t minor()
    {
        return _get_versioninfo().dwMinorVersion;
    }

    //  Build number

    /// Returns the operating system build number
    static ws_uint32_t build_number()
    {
        return winnt() ? _get_versioninfo().dwBuildNumber : LOWORD(_get_versioninfo().dwBuildNumber);
    }

    // Structure access

    /// Provides a non-mutable (const) reference to the \c OSVERSIONINFO instance
    static const OSVERSIONINFO &get_versioninfo()
    {
        return _get_versioninfo();
    }

// Implementation
private:
    /// Unfortunately, something in this technique scares the Borland compilers (5.5
    /// and 5.51) into Internal compiler errors so the s_init variable in
    /// _get_versioninfo() is int rather than bool when compiling for borland.
    static OSVERSIONINFO &_get_versioninfo()
    {
        static OSVERSIONINFO    s_versioninfo;
#ifdef __STLSOFT_COMPILER_IS_BORLAND
        /* WSCB: Borland has an internal compiler error if use ws_bool_t */
        static ws_int_t         s_init = (s_versioninfo.dwOSVersionInfoSize = sizeof(s_versioninfo), ::GetVersionEx(&s_versioninfo), ws_true_v);
#else
        static ws_bool_t        s_init = (s_versioninfo.dwOSVersionInfoSize = sizeof(s_versioninfo), ::GetVersionEx(&s_versioninfo), ws_true_v);
#endif /* __STLSOFT_COMPILER_IS_BORLAND */

		STLSOFT_SUPPRESS_UNUSED(s_init); // Placate GCC

        return s_versioninfo;
    }
};

/* ////////////////////////////////////////////////////////////////////////// */

/// @} // end of group winstl_system_library

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _WINSTL_NO_NAMESPACE
 #ifdef _STLSOFT_NO_NAMESPACE
} // namespace winstl
 #else
} // namespace winstl_project
} // namespace stlsoft
 #endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_WINSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* _WINSTL_INCL_H_WINSTL_SYSTEM_VERSION */

/* ////////////////////////////////////////////////////////////////////////// */
