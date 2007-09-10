/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_fileinfo_win32.cpp
 *
 * Purpose:     Win32 implementation for the file information blocks of the recls API.
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

#include <winstl_atomic_functions.h>

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

#if !defined(RECLS_NO_NAMESPACE)
namespace
{
#else
static
#endif /* !RECLS_NO_NAMESPACE */

volatile recls_sint32_t s_createdInfoBlocks =   0;
volatile recls_sint32_t s_sharedInfoBlocks  =   0;

#if !defined(RECLS_NO_NAMESPACE)
} // namespace recls
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs
 */

struct counted_recls_info_t
{
    volatile recls_sint32_t rc;
    recls_uint32_t          _;
    struct recls_fileinfo_t info;
};

/* /////////////////////////////////////////////////////////////////////////////
 * Helpers
 */

inline recls_sint32_t RC_PreIncrement(recls_sint32_t volatile *p)
{
    return winstl::atomic_preincrement(p);
}

inline recls_sint32_t RC_PreDecrement(recls_sint32_t volatile *p)
{
    return winstl::atomic_predecrement(p);
}

inline struct counted_recls_info_t *counted_info_from_info(recls_info_t i)
{
    recls_assert(i != NULL);

    // can't be bothered with all the C++ casts here!
    return (struct counted_recls_info_t *)((recls_byte_t*)i - offsetof(counted_recls_info_t, info));
}

inline recls_info_t info_from_counted_info(struct counted_recls_info_t * ci)
{
    recls_assert(ci != NULL);

    return &ci->info;
}

/* /////////////////////////////////////////////////////////////////////////////
 * File info functions
 */

RECLS_FNDECL(recls_info_t) FileInfo_Allocate(size_t cb)
{
    // Simply allocate a lock-count prior to the main memory (but do it on an 8-byte block)
    counted_recls_info_t    *ci     =   static_cast<counted_recls_info_t*>(malloc(cb - sizeof(struct recls_fileinfo_t) + sizeof(struct counted_recls_info_t)));
    recls_info_t            info;

    if(NULL == ci)
    {
        info = NULL;
    }
    else
    {
        ci->rc  =   1; // One initial reference
        info    =   info_from_counted_info(ci);

        RC_PreIncrement(&s_createdInfoBlocks);
    }

    return info;
}

RECLS_FNDECL(void) FileInfo_Release(recls_info_t fileInfo)
{
    if(NULL != fileInfo)
    {
        counted_recls_info_t    *pci    =   counted_info_from_info(fileInfo);

        if(0 == RC_PreDecrement(&pci->rc))
        {
            free(pci);

            RC_PreDecrement(&s_createdInfoBlocks);
        }
        else
        {
            RC_PreDecrement(&s_sharedInfoBlocks);
        }
    }
}

RECLS_FNDECL(recls_rc_t) FileInfo_Copy(recls_info_t fileInfo, recls_info_t *pinfo)
{
    recls_assert(NULL != pinfo);

    if(NULL != fileInfo)
    {
        counted_recls_info_t    *pci    =   counted_info_from_info(fileInfo);

        RC_PreIncrement(&pci->rc);
        RC_PreIncrement(&s_sharedInfoBlocks);
    }

    *pinfo = fileInfo;

    return RECLS_RC_OK;
}

RECLS_FNDECL(void) FileInfo_BlockCount(recls_sint32_t *pcCreated, recls_sint32_t *pcShared)
{
    recls_assert(NULL != pcCreated);
    recls_assert(NULL != pcShared);

    // Because on 3.51 and 95, the InterlockedInc/Decrement functions do not 
    // return the values, we're going to fudge it

    RC_PreIncrement(&s_createdInfoBlocks);
    recls_sint32_t createdInfoBlocks    =   s_createdInfoBlocks;
    RC_PreDecrement(&s_createdInfoBlocks);
    *pcCreated                          =   createdInfoBlocks - 1;

    RC_PreIncrement(&s_sharedInfoBlocks);
    recls_sint32_t sharedInfoBlocks     =   s_sharedInfoBlocks;
    RC_PreDecrement(&s_sharedInfoBlocks);
    *pcShared                           =   sharedInfoBlocks - 1;
}

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */
