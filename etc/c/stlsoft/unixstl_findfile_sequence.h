/* /////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_findfile_sequence.h
 *
 * Purpose:     findfile_sequence class. It is now implemented as a typedef to
 *              the glob_sequence class.
 *
 * Created:     15th January 2002
 * Updated:     3rd November 2003
 *
 * Author:      Matthew Wilson, Synesis Software Pty Ltd.
 *
 * License:     (Licensed under the Synesis Software Standard Source License)
 *
 *              Copyright (C) 2002-2003, Synesis Software Pty Ltd.
 *
 *              All rights reserved.
 *
 *              www:        http://www.synesis.com.au/unixstl
 *                          http://www.unixstl.org/
 *
 *              email:      submissions@unixstl.org  for submissions
 *                          admin@unixstl.org        for other enquiries
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


#ifndef _INCL_UNIXSTL_H_UNIXSTL_FINDFILE_SEQUENCE
#define _INCL_UNIXSTL_H_UNIXSTL_FINDFILE_SEQUENCE

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _UNIXSTL_VER_H_UNIXSTL_FINDFILE_SEQUENCE_MAJOR      2
#define _UNIXSTL_VER_H_UNIXSTL_FINDFILE_SEQUENCE_MINOR      1
#define _UNIXSTL_VER_H_UNIXSTL_FINDFILE_SEQUENCE_REVISION   1
#define _UNIXSTL_VER_H_UNIXSTL_FINDFILE_SEQUENCE_EDIT       43
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _INCL_UNIXSTL_H_UNIXSTL
# include "unixstl.h"                   // Include the UNIXSTL root header
#endif /* !_INCL_UNIXSTL_H_UNIXSTL */

#ifdef _UNIXSTL_FINDFILE_SEQUENCE_NO_BACK_SLASH_TERMINATOR
# define _UNIXSTL_GLOB_SEQUENCE_NO_BACK_SLASH_TERMINATOR
#endif /* _UNIXSTL_FINDFILE_SEQUENCE_NO_BACK_SLASH_TERMINATOR */

#ifndef _INCL_UNIXSTL_H_UNIXSTL_GLOB_SEQUENCE
# include "unixstl_glob_sequence.h" // glob_sequence
#endif /* !_INCL_UNIXSTL_H_UNIXSTL_GLOB_SEQUENCE */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 *
 * The UNIXSTL components are contained within the unixstl namespace. This is
 * actually an alias for stlsoft::unixstl_project,
 *
 * The definition matrix is as follows:
 *
 * _STLSOFT_NO_NAMESPACE    _UNIXSTL_NO_NAMESPACE   unixstl definition
 * ---------------------    ---------------------   -----------------
 *  not defined              not defined             = stlsoft::unixstl_project
 *  not defined              defined                 not defined
 *  defined                  not defined             unixstl
 *  defined                  defined                 not defined
 *
 */

/* No STLSoft namespaces means no UNIXSTL namespaces */
#ifdef _STLSOFT_NO_NAMESPACES
# define _UNIXSTL_NO_NAMESPACES
#endif /* _STLSOFT_NO_NAMESPACES */

/* No UNIXSTL namespaces means no unixstl namespace */
#ifdef _UNIXSTL_NO_NAMESPACES
# define _UNIXSTL_NO_NAMESPACE
#endif /* _UNIXSTL_NO_NAMESPACES */

#ifndef _UNIXSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
/* There is no stlsoft namespace, so must define ::unixstl */
namespace unixstl
{
# else
/* Define stlsoft::unixstl_project */

namespace stlsoft
{

namespace unixstl_project
{

# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_UNIXSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

/// \weakgroup libraries STLSoft Libraries
/// \brief The individual libraries

/// \weakgroup libraries_filesystem File-System Library
/// \ingroup libraries
/// \brief This library provides facilities for defining and manipulating file-system objects

/// \defgroup unixstl_filesystem_library File-System Library (UNIXSTL)
/// \ingroup UNIXSTL libraries_filesystem
/// \brief This library provides facilities for defining and manipulating UNIX file-system objects
/// @{

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs
 */

typedef glob_sequence   findfile_sequence;

/* ////////////////////////////////////////////////////////////////////////// */

/// @} // end of group unixstl_filesystem_library

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _UNIXSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
} // namespace unixstl
# else
} // namespace unixstl_project
} // namespace stlsoft
# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_UNIXSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !_INCL_UNIXSTL_H_UNIXSTL_FINDFILE_SEQUENCE */

/* ////////////////////////////////////////////////////////////////////////// */
