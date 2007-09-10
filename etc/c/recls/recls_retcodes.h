/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_retcodes.h
 *
 * Purpose:     Return codes for the  recls API.
 *
 * Created:     15th August 2003
 * Updated:     27th September 2003
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


#if !defined(RECLS_INCL_H_RECLS) && \
    !defined(RECLS_DOCUMENTATION_SKIP_SECTION)
# error recls_retcodes.h cannot be included directly. Include recls.h
#else

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_RETCODES_MAJOR       1
# define RECLS_VER_H_RECLS_RETCODES_MINOR       1
# define RECLS_VER_H_RECLS_RETCODES_REVISION    2
# define RECLS_VER_H_RECLS_RETCODES_EDIT        10
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/** \file recls_retcodes.h Return codes for the \ref group_recls  API */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Constants and definitions
 */

/** No search is currently active */
#define RECLS_RC_SEARCH_NO_CURRENT      ((RECLS_QUAL(recls_rc_t))(-1 - 1001))
/** The directory was invalid, or does not exist */
#define RECLS_RC_INVALID_DIRECTORY      ((RECLS_QUAL(recls_rc_t))(-1 - 1002))
/** No more data is available */
#define RECLS_RC_NO_MORE_DATA           ((RECLS_QUAL(recls_rc_t))(-1 - 1003))
/** Memory exhaustion */
#define RECLS_RC_OUT_OF_MEMORY          ((RECLS_QUAL(recls_rc_t))(-1 - 1004))
/** Function not implemented */
#define RECLS_RC_NOT_IMPLEMENTED        ((RECLS_QUAL(recls_rc_t))(-1 - 1005))
/** Invalid search type */
#define RECLS_RC_INVALID_SEARCH_TYPE    ((RECLS_QUAL(recls_rc_t))(-1 - 1006))

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !RECLS_INCL_H_RECLS */

/* ////////////////////////////////////////////////////////////////////////// */
