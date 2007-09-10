/* ////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_spin_mutex.h (originally MWSpinMx.h, ::SynesisWin)
 *
 * Purpose:     Intra-process mutex, based on spin waits.
 *
 * Date:        27th August 1997
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


#ifndef _UNIXSTL_INCL_H_UNIXSTL_SPIN_MUTEX
#define _UNIXSTL_INCL_H_UNIXSTL_SPIN_MUTEX

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _UNIXSTL_VER_H_UNIXSTL_SPIN_MUTEX_MAJOR     1
#define _UNIXSTL_VER_H_UNIXSTL_SPIN_MUTEX_MINOR     2
#define _UNIXSTL_VER_H_UNIXSTL_SPIN_MUTEX_REVISION  2
#define _UNIXSTL_VER_H_UNIXSTL_SPIN_MUTEX_EDIT      8
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _UNIXSTL_INCL_H_UNIXSTL
# include "unixstl.h"   // Include the UNIXSTL root header
#endif /* !_UNIXSTL_INCL_H_UNIXSTL */
#include <asm/atomic.h> // Only works for Linux. For other OSs, use unixstl_process_mutex.h

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

// class spin_mutex
/// This class provides an implementation of the mutex model based on a spinning mechanism
class spin_mutex
{
public:
    typedef spin_mutex class_type;

// Construction
public:
    /// Creates an instance of the mutex
    ss_explicit_k spin_mutex(us_sint32_t *p) unixstl_throw_0()
        : m_spinCount((NULL != p) ? p : &m_internalCount)
        , m_internalCount(0)
#ifdef STLSOFT_SPINMUTEX_COUNT_LOCKS
        , m_cLocks(0)
#endif // STLSOFT_SPINMUTEX_COUNT_LOCKS
    {}
    /// Destroys an instance of the mutex
    ~spin_mutex() unixstl_throw_0()
    {
#ifdef STLSOFT_SPINMUTEX_COUNT_LOCKS
        stlsoft_assert(m_cLocks == 0);
#endif // STLSOFT_SPINMUTEX_COUNT_LOCKS
    }

// Operations
public:
    /// Acquires a lock on the mutex, pending the thread until the lock is aquired
    void lock() unixstl_throw_0()
    {
        for(; 0 != atomic_write((LPLONG)m_spinCount, 1); ::Sleep(1))
        {}
#ifdef STLSOFT_SPINMUTEX_COUNT_LOCKS
        stlsoft_assert(++m_cLocks != 0);
#endif // STLSOFT_SPINMUTEX_COUNT_LOCKS
    }
    /// Releases an aquired lock on the mutex
    void unlock() unixstl_throw_0()
    {
#ifdef STLSOFT_SPINMUTEX_COUNT_LOCKS
        stlsoft_assert(m_cLocks-- != 0);
#endif // STLSOFT_SPINMUTEX_COUNT_LOCKS
        atomic_write(m_spinCount, 0);
    }

// Members
private:
    us_sint32_t     *m_spinCount;
    us_sint32_t     m_internalCount;
#ifdef STLSOFT_SPINMUTEX_COUNT_LOCKS
    us_sint32_t     m_cLocks;       // Used as check on matched Lock/Unlock calls
#endif // STLSOFT_SPINMUTEX_COUNT_LOCKS

// Not to be implemented
private:
    spin_mutex(class_type const &rhs);
    spin_mutex &operator =(class_type const &rhs);
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
inline void lock_instance(unixstl_ns_qual(spin_mutex) &mx)
{
    mx.lock();
}

/// This control ref concepts_shims "shim" releases a lock on the given mutex
///
/// \param mx The mutex on which to release the lock
inline void unlock_instance(unixstl_ns_qual(spin_mutex) &mx)
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
/// Traits for the spin_mutex class (for compilers that do not support Koenig Lookup)
struct spin_mutex_lock_traits
{
public:
    /// The lockable type
    typedef spin_mutex                lock_type;
    typedef spin_mutex_lock_traits    class_type;

// Operations
public:
    /// Lock the given spin_mutex instance
    static void lock(spin_mutex &c)
    {
        lock_instance(c);
    }

    /// Unlock the given spin_mutex instance
    static void unlock(spin_mutex &c)
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

#endif /* !_WINSTL_INCL_H_UNIXSTL_SPIN_MUTEX */

/* ////////////////////////////////////////////////////////////////////////// */
