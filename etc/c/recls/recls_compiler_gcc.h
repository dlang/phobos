/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_compiler_gcc.h
 *
 * Purpose:     Digital Mars specific types and includes for the recls API.
 *
 * Created:     17th August 2003
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


#if !defined(RECLS_INCL_H_RECLS_COMPILER) && \
    !defined(RECLS_DOCUMENTATION_SKIP_SECTION)
# error recls_compiler_gcc.h cannot be included directly. Include recls.h
#else

#ifndef RECLS_COMPILER_IS_GCC
# error recls_compiler_gcc.h can only be used for GCC compiler builds
#endif /* !RECLS_COMPILER_IS_GCC */

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_COMPILER_GCC_MAJOR       1
# define RECLS_VER_H_RECLS_COMPILER_GCC_MINOR       1
# define RECLS_VER_H_RECLS_COMPILER_GCC_REVISION    1
# define RECLS_VER_H_RECLS_COMPILER_GCC_EDIT        4
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/** \file recls_compiler_gcc.h GCC-specific compiler definitions for the \ref group_recls  API */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#include <stddef.h>

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs
 */

/** \def recls_byte_t The byte type for the \ref group_recls  API */
/** \def recls_sint8_t The 8-bit signed integer type for the \ref group_recls  API */
/** \def recls_uint8_t The 8-bit unsigned integer type for the \ref group_recls  API */
/** \def recls_sint16_t The 16-bit signed integer type for the \ref group_recls  API */
/** \def recls_uint16_t The 16-bit unsigned integer type for the \ref group_recls  API */
/** \def recls_sint32_t The 32-bit signed integer type for the \ref group_recls  API */
/** \def recls_uint32_t The 32-bit unsigned integer type for the \ref group_recls  API */
/** \def recls_sint64_t The 64-bit signed integer type for the \ref group_recls  API */
/** \def recls_uint64_t The 64-bit unsigned integer type for the \ref group_recls  API */

typedef unsigned char       recls_byte_t;

typedef signed char         recls_sint8_t;
typedef unsigned char       recls_uint8_t;

typedef signed short        recls_sint16_t;
typedef unsigned short      recls_uint16_t;

typedef signed long         recls_sint32_t;
typedef unsigned long       recls_uint32_t;

typedef signed long long    recls_sint64_t;
typedef unsigned long long  recls_uint64_t;

/** \def recls_char_a_t The ANSI character type for the \ref group_recls  API */
/** \def recls_char_w_t The Unicode character type for the \ref group_recls  API */
typedef char                recls_char_a_t;
typedef wchar_t             recls_char_w_t;

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* RECLS_INCL_H_RECLS_COMPILER */

/* ////////////////////////////////////////////////////////////////////////// */
