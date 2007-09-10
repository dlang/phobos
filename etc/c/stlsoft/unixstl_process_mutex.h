/* ////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_process_mutex.h
 *
 * Purpose:     Intra-process mutext, based on PTHREADS.
 *
 * Date:        15th May 2002
 * Updated:     23rd November 2003
 *
 * Author:      Matthew Wilson, Synesis Software Pty Ltd.
 *
 * License:     (Licensed under the Synesis Software Standard Source License)
 *
 *              Copyright (C) 2002-2003, Synesis Software Pty Ltd.
 *
 *              All rights reserved.
 *
 *              www:        http://www.synesis.com.au/unixstl
 *                          http://www.unixstl.org/
 *
 *              email:      submissions@unixstl.org  for submissions
 *                          admin@unixstl.org        for other enquiries
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


#ifndef _UNIXSTL_INCL_H_UNIXSTL_PROCESS_MUTEX
#define _UNIXSTL_INCL_H_UNIXSTL_PROCESS_MUTEX

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define _UNIXSTL_VER_H_UNIXSTL_PROCESS_MUTEX_MAJOR     1
# define _UNIXSTL_VER_H_UNIXSTL_PROCESS_MUTEX_MINOR     3
# define _UNIXSTL_VER_H_UNIXSTL_PROCESS_MUTEX_REVISION  4
# define _UNIXSTL_VER_H_UNIXSTL_PROCESS_MUTEX_EDIT      15
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _UNIXSTL_INCL_H_UNIXSTL
# include "unixstl.h"    // Include the UNIXSTL root header
#endif /* !_UNIXSTL_INCL_H_UNIXSTL */
#if !defined(_REENTRANT) && \
    !defined(_POSIX_THREADS)
# error unixstl_process_mutex.h must be compiled in the context of PTHREADS
#endif /* !_REENTRANT && !_POSIX_THREADS */
#include <pthread.h>

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#ifndef _UNIXSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
/* There is no stlsoft namespace, so must define ::unixstl */
namespace unixstl
{
# else
/* Define stlsoft::unixstl_project */

namespace stlsoft
{

namespace unixstl_project
{

# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_UNIXSTL_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

// class process_mutex
/// This class provides an implementation of the mutex model based on the Win32 CRITICAL_SECTION
class process_mutex
{
public:
    typedef process_mutex class_type;

// Construction
public:
    /// Creates an instance of the mutex
    ss_explicit_k process_mutex(us_bool_t bRecursive) unixstl_throw_0()
        : m_init(create_(&m_mx, 0, bRecursive))
    {}
#if defined(_POSIX_THREAD_PROCESS_SHARED)
    /// Creates an instance of the mutex
    process_mutex(int pshared, us_bool_t bRecursive) unixstl_throw_0()
        : m_init(create_(&m_mx, pshared, bRecursive))
    {}
#endif /* _POSIX_THREAD_PROCESS_SHARED */
    /// Destroys an instance of the mutex
    ~process_mutex() unixstl_throw_0()
    {
        if(m_init)
        {
            ::pthread_mutex_destroy(&m_mx);
        }
    }

// Operations
public:
    /// Acquires a lock on the mutex, pending the thread until the lock is aquired
    void lock() unixstl_throw_0()
    {
        pthread_mutex_lock(&m_mx);
    }
    /// Attempts to lock the mutex
    ///
    /// \return <b>true</b> if the mutex was aquired, or <b>false</b> if not
    /// \note Only available with Windows NT 4 and later
    bool try_lock()
    {
        return pthread_mutex_trylock(&m_mx) == 0;
    }
    /// Releases an aquired lock on the mutex
    void unlock() unixstl_throw_0()
    {
        pthread_mutex_unlock(&m_mx);
    }

// Implementation
private:
    static us_bool_t create_(pthread_mutex_t *mx, int pshared, us_bool_t bRecursive)
    {
        us_bool_t           bSuccess    =   false;
        pthread_mutexattr_t attr;

        if(0 == ::pthread_mutexattr_init(&attr))
        {
            if( !bRecursive ||
                0 == ::pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE))
            {
#if defined(_POSIX_THREAD_PROCESS_SHARED)
                if(0 == ::pthread_mutexattr_setpshared(&attr, pshared))
#else
                ((void)pshared);
#endif /* _POSIX_THREAD_PROCESS_SHARED */
                {
                    if(0 == ::pthread_mutex_init(mx, &attr))
                    {
                        bSuccess = true;
                    }
                }
            }

            ::pthread_mutexattr_destroy(&attr);
        }

        return bSuccess;
    }

// Members
private:
    pthread_mutex_t m_mx;   // mx
    us_bool_t       m_init;

// Not to be implemented
private:
    process_mutex(class_type const &rhs);
    process_mutex &operator =(class_type const &rhs);
};

/* /////////////////////////////////////////////////////////////////////////////
 * Control shims
 */

#ifndef _UNIXSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
} // namespace unixstl
# else
} // namespace unixstl_project
# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_UNIXSTL_NO_NAMESPACE */

/// \weakgroup concepts STLSoft Concepts

/// \weakgroup concepts_shims Shims
/// \ingroup concepts 

/// \weakgroup concepts_shims_sync_control Synchronisation Control Shims
/// \ingroup concepts_shims
/// \brief These \ref concepts_shims "shims" control the behaviour of synchronisation objects

/// \defgroup unixstl_sync_control_shims Synchronisation Control Shims (UNIXSTL)
/// \ingroup UNIXSTL concepts_shims_sync_control
/// \brief These \ref concepts_shims "shims" control the behaviour of Win32 synchronisation objects
/// @{

/// This control ref concepts_shims "shim" aquires a lock on the given mutex
///
/// \param mx The mutex on which to aquire the lock
inline void lock_instance(unixstl_ns_qual(process_mutex) &mx)
{
    mx.lock();
}

/// This control ref concepts_shims "shim" releases a lock on the given mutex
///
/// \param mx The mutex on which to release the lock
inline void unlock_instance(unixstl_ns_qual(process_mutex) &mx)
{
    mx.unlock();
}

/// @} // end of group unixstl_sync_control_shims

#ifndef _UNIXSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
namespace unixstl
{
# else
namespace unixstl_project
{
# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_UNIXSTL_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * lock_traits (for the compilers that do not support Koenig Lookup)
 */

// class lock_traits
/// Traits for the process_mutex class (for compilers that do not support Koenig Lookup)
struct thread_mutex_lock_traits
{
public:
    /// The lockable type
    typedef process_mutex                lock_type;
    typedef thread_mutex_lock_traits    class_type;

// Operations
public:
    /// Lock the given process_mutex instance
    static void lock(process_mutex &c)
    {
        lock_instance(c);
    }

    /// Unlock the given process_mutex instance
    static void unlock(process_mutex &c)
    {
        unlock_instance(c);
    }
};

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _UNIXSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
} // namespace unixstl
# else
} // namespace unixstl_project
} // namespace stlsoft
# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_UNIXSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !_UNIXSTL_INCL_H_UNIXSTL_PROCESS_MUTEX */

/* ////////////////////////////////////////////////////////////////////////// */
