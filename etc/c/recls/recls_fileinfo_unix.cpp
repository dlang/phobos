/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_fileinfo_unix.cpp
 *
 * Purpose:     UNIX implementation for the file information blocks of the recls API.
 *
 * Created:     2nd November 2003
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
#include <stlsoft_lock_scope.h>

// For ease of debugging for those of you (us?) that prefer working on Win32, 
// the definition of EMULATE_UNIX_ON_WIN32 will allow you to do so.
#if defined(EMULATE_UNIX_ON_WIN32)
# include <windows.h>
# if defined(_MT) || \
	 defined(__MT__)
#  ifndef _REENTRANT
#   define _REENTRANT
#  endif /* !_REENTRANT */
#  define RECLS_FILEINFO_MULTITHREADED
# endif /* _MT || __MT__ */
#else /* ? EMULATE_UNIX_ON_WIN32 */
# if defined(_REENTRANT)
#  define RECLS_FILEINFO_MULTITHREADED
# endif /* _REENTRANT */
#endif /* EMULATE_UNIX_ON_WIN32 */


//#define	RECLS_UNIX_USE_ATOMIC_OPERATIONS // Define this if you're on Linux (and you know what you're doing!)

#if defined(RECLS_FILEINFO_MULTITHREADED)
 // If we're multi-threading, then we have two options:
# if defined(RECLS_UNIX_USE_ATOMIC_OPERATIONS)
  // 1. On Linux we can use the kernel's atomic operations, since all we need 
  //    is atomic integer operations. Since these kernel operations are not
  //    standard, you must explicitly select them in your build by defining
  //    the symbol RECLS_UNIX_USE_ATOMIC_OPERATIONS
#  include <asm/atomic.h>
# else /* ? RECLS_UNIX_USE_ATOMIC_OPERATIONS */
  // 2. On other UNIX systems we use the UNIXSTL thread_mutex class
#  include <unixstl_thread_mutex.h>
# endif /* !RECLS_UNIX_USE_ATOMIC_OPERATIONS */
#else /* ? RECLS_FILEINFO_MULTITHREADED */
 // When not multi-threaded, we just use the STLSoft null_mutex class, which
 // is just a stub
# include <stlsoft_null_mutex.h>
#endif /* RECLS_FILEINFO_MULTITHREADED */

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

#if defined(RECLS_FILEINFO_MULTITHREADED) && \
    defined(RECLS_UNIX_USE_ATOMIC_OPERATIONS)
typedef	atomic_t				rc_atomic_t;
# define rc_atomic_init(x)		ATOMIC_INIT(x)
#else /* ? RECLS_FILEINFO_MULTITHREADED && RECLS_UNIX_USE_ATOMIC_OPERATIONS */
typedef	recls_sint32_t			rc_atomic_t;
# define rc_atomic_init(x)		x
#endif /* RECLS_FILEINFO_MULTITHREADED && RECLS_UNIX_USE_ATOMIC_OPERATIONS */

struct counted_recls_info_t
{
    volatile rc_atomic_t	rc;
    recls_uint32_t          _;
    struct recls_fileinfo_t info;
};

/* /////////////////////////////////////////////////////////////////////////////
 * Constants and definitions
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace
{
#else
static
#endif /* !RECLS_NO_NAMESPACE */

volatile rc_atomic_t s_createdInfoBlocks =   rc_atomic_init(0);
volatile rc_atomic_t s_sharedInfoBlocks  =   rc_atomic_init(0);

#if !defined(RECLS_NO_NAMESPACE)
} // namespace recls
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Helpers
 */

#if !defined(RECLS_UNIX_USE_ATOMIC_OPERATIONS)
namespace
{
#if defined(RECLS_FILEINFO_MULTITHREADED)
//	unixstl::process_mutex	s_mx(true);
	unixstl::thread_mutex	s_mx(true);
	typedef unixstl::thread_mutex	mutex_t;
#else /* ? RECLS_FILEINFO_MULTITHREADED */
	stlsoft::null_mutex		s_mx;

	typedef stlsoft::null_mutex		mutex_t;
#endif /* RECLS_FILEINFO_MULTITHREADED */
}
#endif /* !RECLS_UNIX_USE_ATOMIC_OPERATIONS */

inline void RC_PreIncrement(rc_atomic_t volatile *p)
{
#if defined(RECLS_UNIX_USE_ATOMIC_OPERATIONS)

	atomic_inc(p);

#else /* ? RECLS_UNIX_USE_ATOMIC_OPERATIONS */
	stlsoft::lock_scope<mutex_t>		lock(s_mx);

	return ++(*p);
#endif /* !RECLS_UNIX_USE_ATOMIC_OPERATIONS */
}

inline recls_sint32_t RC_PreDecrement(rc_atomic_t volatile *p)
{
#if defined(RECLS_UNIX_USE_ATOMIC_OPERATIONS)

	return 1 + atomic_dec_and_test(p);

#else /* ? RECLS_UNIX_USE_ATOMIC_OPERATIONS */
	stlsoft::lock_scope<mutex_t>		lock(s_mx);

	return --(*p);
#endif /* !RECLS_UNIX_USE_ATOMIC_OPERATIONS */
}

inline recls_sint32_t RC_ReadValue(rc_atomic_t volatile *p)
{
#if defined(RECLS_UNIX_USE_ATOMIC_OPERATIONS)

	return atomic_read(p);

#else /* ? RECLS_UNIX_USE_ATOMIC_OPERATIONS */
	stlsoft::lock_scope<mutex_t>		lock(s_mx);

	return (*p);
#endif /* !RECLS_UNIX_USE_ATOMIC_OPERATIONS */
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
		rc_atomic_t	initial = rc_atomic_init(1);

        ci->rc  =   initial; // One initial reference
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

    *pcCreated	=	RC_ReadValue(&s_createdInfoBlocks);
    *pcShared   =   RC_ReadValue(&s_sharedInfoBlocks);
}

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */
