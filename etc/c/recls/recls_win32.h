/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_win32.h
 *
 * Purpose:     Win32-specific header file for the recls API.
 *
 * Created:     18th August 2003
 * Updated:     21st November 2003
 *
 * Author:      Matthew Wilson, Synesis Software Pty Ltd.
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


#ifndef RECLS_INCL_H_RECLS_WIN32
#define RECLS_INCL_H_RECLS_WIN32

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_WIN32_MAJOR      1
# define RECLS_VER_H_RECLS_WIN32_MINOR      1
# define RECLS_VER_H_RECLS_WIN32_REVISION   2
# define RECLS_VER_H_RECLS_WIN32_EDIT       6
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/** \file recls_win32.h Win32-specific parts of the \ref group_recls  API */

/* /////////////////////////////////////////////////////////////////////////////
 * Strictness
 */

#ifndef RECLS_NO_STRICT
# define RECLS_STRICT
#endif /* !RECLS_NO_STRICT */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#include "recls.h"

#ifndef RECLS_PLATFORM_IS_WIN32
# error recls_win32.h is to be included in Win32 compilations only
#endif /* RECLS_PLATFORM_IS_WIN32 */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Functions
 */

/** Gets the drive associated with the given file entry info structure
 *
 * \param hEntry The info entry structure.
 * \param pchDrive Pointer to a character to receive the drive character. Cannot be NULL. The character will be in uppercase.
 */
RECLS_FNDECL(void) Recls_GetDriveProperty(  recls_info_t    hEntry
                                        ,   recls_char_t    *pchDrive);

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !RECLS_INCL_H_RECLS_WIN32 */

/* ////////////////////////////////////////////////////////////////////////// */
