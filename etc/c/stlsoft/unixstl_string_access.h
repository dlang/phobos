/* /////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_string_access.h
 *
 * Purpose:     Contains classes and functions for dealing with OLE/COM strings.
 *
 * Created:     11th January 2003
 * Updated:     13th August 2003
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


#ifndef _UNIXSTL_INCL_H_UNIXSTL_STRING_ACCESS
#define _UNIXSTL_INCL_H_UNIXSTL_STRING_ACCESS

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _UNIXSTL_VER_H_UNIXSTL_STRING_ACCESS_MAJOR      1
#define _UNIXSTL_VER_H_UNIXSTL_STRING_ACCESS_MINOR      1
#define _UNIXSTL_VER_H_UNIXSTL_STRING_ACCESS_REVISION   2
#define _UNIXSTL_VER_H_UNIXSTL_STRING_ACCESS_EDIT       10
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _UNIXSTL_INCL_H_UNIXSTL
 #include "unixstl.h"   // Include the UNIXSTL root header
#endif /* !_UNIXSTL_INCL_H_UNIXSTL */
#include <dirent.h>

/* /////////////////////////////////////////////////////////////////////////////
 * Forward declarations
 */

struct dirent;

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 *
 * The UNIXSTL components are contained within the unixstl namespace. This is
 * actually an alias for stlsoft::unixstl_project,
 *
 * The definition matrix is as follows:
 *
 * _STLSOFT_NO_NAMESPACE    _UNIXSTL_NO_NAMESPACE   unixstl definition
 * ---------------------    --------------------    -----------------
 *  not defined             not defined             = stlsoft::unixstl_project
 *  not defined             defined                 not defined
 *  defined                 not defined             unixstl
 *  defined                 defined                 not defined
 *
 */

#ifndef _UNIXSTL_NO_NAMESPACE
 #ifdef _STLSOFT_NO_NAMESPACE
/* There is no stlsoft namespace, so must define ::unixstl */
namespace unixstl
{
 #else
/* Define stlsoft::unixstl_project */

namespace stlsoft
{

namespace unixstl_project
{

 #endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_UNIXSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

/// \weakgroup concepts STLSoft Concepts

/// \weakgroup concepts_shims Shims
/// \ingroup concepts 

/// \weakgroup concepts_shims_string_access String Access Shims
/// \ingroup concepts_shims
/// \brief These \ref concepts_shims "shims" retrieve the C-string for arbitrary types

/// \defgroup unixstl_string_access_shims String Access Shims (UNIXSTL)
/// \ingroup UNIXSTL concepts_shims_string_access
/// \brief These \ref concepts_shims "shims" retrieve the C-string for arbitrary types
/// @{

/* /////////////////////////////////////////////////////////////////////////////
 * c_str_ptr_null
 *
 * This can be applied to an expression, and the return value is either a
 * pointer to the character string or NULL.
 */

/// \brief Returns the corresponding C-string pointer of the dirent structure \c d, or NULL if \c d is empty
inline us_char_a_t const *c_str_ptr_null(struct dirent const *d)
{
    return (d == 0 || d->d_name[0] == 0) ? 0 : d->d_name;
}

/// \brief Returns the corresponding C-string pointer of the dirent structure \c d, or NULL if \c d is empty
inline us_char_a_t const *c_str_ptr_null(struct dirent const &d)
{
    return d.d_name[0] == 0 ? 0 : d.d_name;
}

/* /////////////////////////////////////////////////////////////////////////////
 * c_str_ptr
 *
 * This can be applied to an expression, and the return value is either a
 * pointer to the character string or to an empty string.
 */

/// \brief Returns the corresponding C-string pointer of the dirent structure \c d
inline us_char_a_t const *c_str_ptr(struct dirent const *d)
{
    return (d == 0) ? "" : d->d_name;
}

/// \brief Returns the corresponding C-string pointer of the dirent structure \c d
inline us_char_a_t const *c_str_ptr(struct dirent const &d)
{
    return d.d_name;
}

/* /////////////////////////////////////////////////////////////////////////////
 * c_str_len
 *
 * This can be applied to an expression, and the return value is the number of
 * characters in the character string in the expression.
 */


/* /////////////////////////////////////////////////////////////////////////////
 * c_str_size
 *
 * This can be applied to an expression, and the return value is the number of
 * bytes required to store the character string in the expression, NOT including
 * the null-terminating character.
 */


/* ////////////////////////////////////////////////////////////////////////// */

/// @} // end of group unixstl_string_access_shims

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _UNIXSTL_NO_NAMESPACE
 #ifdef _STLSOFT_NO_NAMESPACE
} // namespace unixstl
 #else
} // namespace unixstl_project
} // namespace stlsoft
 #endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_UNIXSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !_UNIXSTL_INCL_H_UNIXSTL_STRING_ACCESS */

/* ////////////////////////////////////////////////////////////////////////// */
