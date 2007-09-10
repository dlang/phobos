/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_util.h
 *
 * Purpose:     Utility functions for the recls API.
 *
 * Created:     17th August 2003
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


#ifndef RECLS_INCL_H_RECLS_UTIL
#define RECLS_INCL_H_RECLS_UTIL

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_UTIL_MAJOR       1
# define RECLS_VER_H_RECLS_UTIL_MINOR       4
# define RECLS_VER_H_RECLS_UTIL_REVISION    1
# define RECLS_VER_H_RECLS_UTIL_EDIT        9
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/** \file recls_util.h Utility functions for the \ref group_recls  API */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#include "recls.h"

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

RECLS_LINKAGE_C recls_bool_t is_dots(recls_char_t const *f);
RECLS_LINKAGE_C recls_bool_t file_exists(recls_char_t const *f);
RECLS_LINKAGE_C size_t      align_up_size(size_t i);
RECLS_LINKAGE_C size_t      count_char_instances_a(recls_char_a_t const *begin, recls_char_a_t const *end, recls_char_a_t const ch);
RECLS_LINKAGE_C size_t      count_char_instances_w(recls_char_w_t const *begin, recls_char_w_t const *end, recls_char_w_t const ch);
RECLS_LINKAGE_C size_t      count_dir_parts_a(recls_char_a_t const *begin, recls_char_a_t const *end);
RECLS_LINKAGE_C size_t      count_dir_parts_w(recls_char_w_t const *begin, recls_char_w_t const *end);

#ifdef __cplusplus
inline size_t count_dir_parts(recls_char_a_t const *begin, recls_char_a_t const *end)
{
    return count_dir_parts_a(begin, end);
}

inline size_t count_dir_parts(recls_char_w_t const *begin, recls_char_w_t const *end)
{
    return count_dir_parts_w(begin, end);
}
#endif /* __cplusplus */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !RECLS_INCL_H_RECLS_UTIL */

/* ////////////////////////////////////////////////////////////////////////// */
