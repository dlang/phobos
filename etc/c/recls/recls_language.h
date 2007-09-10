/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_language.h
 *
 * Purpose:     Platform discrimination for the recls API.
 *
 * Created:     15th August 2003
 * Updated:     23rd September 2003
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


#ifndef RECLS_INCL_H_RECLS_LANGUAGE
#define RECLS_INCL_H_RECLS_LANGUAGE

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_LANGUAGE_MAJOR       1
# define RECLS_VER_H_RECLS_LANGUAGE_MINOR       0
# define RECLS_VER_H_RECLS_LANGUAGE_REVISION    8
# define RECLS_VER_H_RECLS_LANGUAGE_EDIT        8
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/** \file recls_language.h Language detection for the \ref group_recls  API */

/* /////////////////////////////////////////////////////////////////////////////
 * Linkage
 */

/** \def RECLS_LINKAGE_C The linkage for <b>recls</b> functions. Is \c extern \c "C" in C++ and \c extern in C. */

#ifdef __cplusplus
# define RECLS_LINKAGE_C            extern "C"
# define RECLS_LINKAGE_CPP          extern "C++"
#else
# define RECLS_LINKAGE_C            extern
#endif /* __cplusplus */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(__cplusplus)
# define RECLS_NO_NAMESPACE
#endif /* !__cplusplus */

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

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !RECLS_INCL_H_RECLS_LANGUAGE */

/* ////////////////////////////////////////////////////////////////////////// */
