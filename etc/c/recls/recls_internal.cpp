/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_internal.cpp
 *
 * Purpose:     Implementation file for the recls API internal helpers.
 *
 * Created:     16th August 2003
 * Updated:     27th November 2003
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


/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#include "recls.h"
#include "recls_internal.h"
#include "recls_assert.h"

#include <stlsoft_nulldef.h>

#include <string.h>

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

static size_t recls_strncpy(recls_char_t *dest, size_t cchDest, recls_char_t const *src, size_t cchSrc)
{
    size_t  cchWritten;

    if(cchDest < cchSrc)
    {
        /* Just to straight strncpy. */
        strncpy(dest, src, cchDest);

        cchWritten = cchDest;
    }
    else
    {
        strncpy(dest, src, cchSrc);

        if(cchSrc < cchDest)
        {
            /* Fill the rest up with blanks. */

            memset(&dest[cchSrc], 0, sizeof(recls_char_t) * (cchDest - cchSrc));
        }

        cchWritten = cchSrc;
    }

    return cchWritten;
}

/* ////////////////////////////////////////////////////////////////////////// */

#if defined(RECLS_COMPILER_IS_DMC) || \
    defined(RECLS_COMPILER_IS_WATCOM)
RECLS_FNDECL(size_t) Recls_GetStringProperty_(  struct recls_strptrs_t const *      ptrs
                                            ,   recls_char_t *                      buffer
                                            ,   size_t                              cchBuffer)
#else
RECLS_FNDECL(size_t) Recls_GetStringProperty_(  struct recls_strptrs_t const *const ptrs
                                            ,   recls_char_t *const                 buffer
                                            ,   size_t const                        cchBuffer)
#endif /* RECLS_COMPILER_IS_DMC || RECLS_COMPILER_IS_WATCOM */
{
    recls_assert(NULL != ptrs);

    size_t  cch =   ptrs->end - ptrs->begin;

    if(NULL != buffer)
    {
        cch = recls_strncpy(buffer, cchBuffer, ptrs->begin, cch);
    }

    return cch;
}

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */
