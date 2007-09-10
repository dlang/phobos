/* /////////////////////////////////////////////////////////////////////////////
 * File:        stlsoft_nulldef.h
 *
 * Purpose:     Include for defining NULL to be the NULL_v template class.
 *
 * Created:     17th December 2002
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
 *              www:        http://www.synesis.com.au/stlsoft
 *                          http://www.stlsoft.org/
 *
 *              email:      submissions@stlsoft.org  for submissions
 *                          admin@stlsoft.org        for other enquiries
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


#ifndef _STLSOFT_INCL_H_STLSOFT_NULLDEF
#define _STLSOFT_INCL_H_STLSOFT_NULLDEF

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _STLSOFT_VER_H_STLSOFT_NULLDEF_MAJOR    1
#define _STLSOFT_VER_H_STLSOFT_NULLDEF_MINOR    0
#define _STLSOFT_VER_H_STLSOFT_NULLDEF_REVISION 5
#define _STLSOFT_VER_H_STLSOFT_NULLDEF_EDIT     8
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _STLSOFT_INCL_H_STLSOFT
# include "stlsoft.h"       // Include the STLSoft root header
#endif /* !_STLSOFT_INCL_H_STLSOFT */
#ifndef _STLSOFT_INCL_H_STLSOFT_NULL
# include "stlsoft_null.h"   // Include the STLSoft root header
#endif /* !_STLSOFT_INCL_H_STLSOFT_NULL */

#include <stddef.h> // Always make sure that this is included, irrespective of
                    // its potential inclusion within stlsoft.h

/* /////////////////////////////////////////////////////////////////////////////
 * Definitions
 */

#ifndef NULL
# ifdef _STLSOFT_COMPILE_VERBOSE
#  pragma message("NULL not defined. This is potentially dangerous. You are advised to include its defining header before stlsoft_nulldef.h")
# endif /* _STLSOFT_COMPILE_VERBOSE */
#endif /* !NULL */

#ifdef _STLSOFT_NULL_v_DEFINED
# ifdef __cplusplus
#  ifdef NULL
#   undef NULL
#  endif /* NULL */
  /// \def NULL
  ///
  /// By including this file, \c NULL is (re-)defined to be <code>stlsoft::NULL_v()</code>
  /// which means that any use of \c NULL must be with pointer types.
#  define NULL   stlsoft_ns_qual(NULL_v)::create()
# endif /* __cplusplus */
#endif /* _STLSOFT_NULL_v_DEFINED */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !_STLSOFT_INCL_H_STLSOFT_NULLDEF */

/* ////////////////////////////////////////////////////////////////////////// */
