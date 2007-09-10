/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_assert.h
 *
 * Purpose:     Compiler discrimination for the recls API.
 *
 * Created:     15th August 2003
 * Updated:     2nd November 2003
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


#ifndef RECLS_INCL_H_RECLS_ASSERT
#define RECLS_INCL_H_RECLS_ASSERT

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_ASSERT_MAJOR     1
# define RECLS_VER_H_RECLS_ASSERT_MINOR     0
# define RECLS_VER_H_RECLS_ASSERT_REVISION  6
# define RECLS_VER_H_RECLS_ASSERT_EDIT      6
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/** \file recls_assert.h Assertions for the \ref group_recls API */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#include "recls.h"

/** \def recls_assert Assert macro for the recls API
 *
 * \param x The expression that must evaluate to \c true
 */

#if defined(RECLS_PLATFORM_IS_WIN32) && \
    defined(_MSC_VER)
# include <crtdbg.h> // Prefer MSVCRT for VC++ and compatible compilers
# define recls_assert(x)    _ASSERTE(x)
#else
# include <assert.h>
# define recls_assert(x)    assert(x)
#endif /* compiler */

/* /////////////////////////////////////////////////////////////////////////////
 * Macros
 */

/** \def recls_message_assert Assert macro for the recls API
 *
 * \param m The literal string describing the failed condition
 * \param x The expression that must evaluate to \c true
 */

#if defined(__WATCOMC__)
 #define recls_message_assert(m, )      recls_assert(x)
#else
 #define recls_message_assert(m, x)     recls_assert((m, x))
#endif /* __WATCOMC__ */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !RECLS_INCL_H_RECLS_ASSERT */

/* ////////////////////////////////////////////////////////////////////////// */
