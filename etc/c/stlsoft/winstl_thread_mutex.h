/* ////////////////////////////////////////////////////////////////////////////
 * File:        winstl_thread_mutex.h (originally MWCrtSct.h, ::SynesisWin)
 *
 * Purpose:     Intra-process mutex, based on Windows CRITICAL_SECTION.
 *
 * Date:        17th December 1996
 * Updated:     24th November 2003
 *
 * Author:      Matthew Wilson, Synesis Software Pty Ltd.
 *
 * License:     (Licensed under the Synesis Software Standard Source License)
 *
 *              Copyright (C) 2002-2003, Synesis Software Pty Ltd.
 *
 *              All rights reserved.
 *
 *              www:        http://www.synesis.com.au/winstl
 *                          http://www.winstl.org/
 *
 *              email:      submissions@winstl.org  for submissions
 *                          admin@winstl.org        for other enquiries
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


#ifndef _WINSTL_INCL_H_WINSTL_THREAD_MUTEX
#define _WINSTL_INCL_H_WINSTL_THREAD_MUTEX

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _WINSTL_VER_H_WINSTL_THREAD_MUTEX_MAJOR     1
#define _WINSTL_VER_H_WINSTL_THREAD_MUTEX_MINOR     3
#define _WINSTL_VER_H_WINSTL_THREAD_MUTEX_REVISION  4
#define _WINSTL_VER_H_WINSTL_THREAD_MUTEX_EDIT      14
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _WINSTL_INCL_H_WINSTL
# include "winstl.h"    // Include the WinSTL root header
#endif /* !_WINSTL_INCL_H_WINSTL */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#ifndef _WINSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
/* There is no stlsoft namespace, so must define ::winstl */
namespace winstl
{
# else
/* Define stlsoft::winstl_project */

namespace stlsoft
{

namespace winstl_project
{

# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_WINSTL_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Spin-count support
 */

#ifdef __WINSTL_THREAD_MUTEX_SPIN_COUNT_SUPPORT
# undef __WINSTL_THREAD_MUTEX_SPIN_COUNT_SUPPORT
#endif /* __WINSTL_THREAD_MUTEX_SPIN_COUNT_SUPPORT */

#ifdef __WINSTL_THREAD_MUTEX_TRY_LOCK_SUPPORT
# undef __WINSTL_THREAD_MUTEX_TRY_LOCK_SUPPORT
#endif /* __WINSTL_THREAD_MUTEX_TRY_LOCK_SUPPORT */

#if defined(_WIN32_WINNT) && \
    _WIN32_WINNT >= 0x0403
# define __WINSTL_THREAD_MUTEX_SPIN_COUNT_SUPPORT
#endif /* _WIN32_WINNT >= 0x0403 */

#if defined(_WIN32_WINNT) && \
    _WIN32_WINNT >= 0x0400
# define __WINSTL_THREAD_MUTEX_TRY_LOCK_SUPPORT
#endif /* _WIN32_WINNT >= 0x0400 */

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

// class thread_mutex
/// This class provides an implementation of the mutex model based on the Win32 CRITICAL_SECTION
class thread_mutex
{
public:
    typedef thread_mutex class_type;

// Construction
public:
    /// Creates an instance of the mutex
    thread_mutex() winstl_throw_0()
    {
        ::InitializeCriticalSection(&m_cs);
    }
#if defined(__WINSTL_THREAD_MUTEX_SPIN_COUNT_SUPPORT)
    /// Creates an instance of the mutex and sets its spin count
    ///
    /// \param spinCount The new spin count for the mutex
    /// \note Only available with Windows NT 4 SP3 and later
    thread_mutex(ws_dword_t spinCount) winstl_throw_0()
    {
        ::InitializeCriticalSectionAndSpinCount(&m_cs, spinCount);
    }
#endif /* __WINSTL_THREAD_MUTEX_SPIN_COUNT_SUPPORT */
    /// Destroys an instance of the mutex
    ~thread_mutex() winstl_throw_0()
    {
        ::DeleteCriticalSection(&m_cs);
    }

// Operations
public:
    /// Acquires a lock on the mutex, pending the thread until the lock is aquired
    void lock() winstl_throw_0()
    {
        ::EnterCriticalSection(&m_cs);
    }
#if defined(__WINSTL_THREAD_MUTEX_TRY_LOCK_SUPPORT)
    /// Attempts to lock the mutex
    ///
    /// \return <b>true</b> if the mutex was aquired, or <b>false</b> if not
    /// \note Only available with Windows NT 4 and later
    bool try_lock()
    {
        return ::TryEnterCriticalSection(&m_cs) != FALSE;
    }
#endif /* __WINSTL_THREAD_MUTEX_TRY_LOCK_SUPPORT */
    /// Releases an aquired lock on the mutex
    void unlock() winstl_throw_0()
    {
        ::LeaveCriticalSection(&m_cs);
    }

#if defined(__WINSTL_THREAD_MUTEX_SPIN_COUNT_SUPPORT)
    /// Sets the spin count for the mutex
    ///
    /// \param spinCount The new spin count for the mutex
    /// \return The previous spin count associated with the mutex
    /// \note Only available with Windows NT 4 SP3 and later
    ws_dword_t set_spin_count(ws_dword_t spinCount) winstl_throw_0()
    {
        return ::SetCriticalSectionSpinCount(&m_cs, spinCount);
    }
#endif /* __WINSTL_THREAD_MUTEX_SPIN_COUNT_SUPPORT */

// Members
private:
    CRITICAL_SECTION    m_cs;   // critical section

// Not to be implemented
private:
    thread_mutex(class_type const &rhs);
    thread_mutex &operator =(class_type const &rhs);
};

/* /////////////////////////////////////////////////////////////////////////////
 * Control shims
 */

#ifndef _WINSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
} // namespace winstl
# else
} // namespace winstl_project
# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_WINSTL_NO_NAMESPACE */

/// \weakgroup concepts STLSoft Concepts

/// \weakgroup concepts_shims Shims
/// \ingroup concepts 

/// \weakgroup concepts_shims_sync_control Synchronisation Control Shims
/// \ingroup concepts_shims
/// \brief These \ref concepts_shims "shims" control the behaviour of synchronisation objects

/// \defgroup winstl_sync_control_shims Synchronisation Control Shims (WinSTL)
/// \ingroup WinSTL concepts_shims_sync_control
/// \brief These \ref concepts_shims "shims" control the behaviour of Win32 synchronisation objects
/// @{

/// This control ref concepts_shims "shim" aquires a lock on the given mutex
///
/// \param mx The mutex on which to aquire the lock
inline void lock_instance(winstl_ns_qual(thread_mutex) &mx)
{
    mx.lock();
}

/// This control ref concepts_shims "shim" releases a lock on the given mutex
///
/// \param mx The mutex on which to release the lock
inline void unlock_instance(winstl_ns_qual(thread_mutex) &mx)
{
    mx.unlock();
}

/// @} // end of group winstl_sync_control_shims

#ifndef _WINSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
namespace winstl {
# else
namespace winstl_project {
#  if defined(__STLSOFT_COMPILER_IS_BORLAND)
using ::stlsoft::lock_instance;
using ::stlsoft::unlock_instance;
#  endif /* __STLSOFT_COMPILER_IS_BORLAND */
# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_WINSTL_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * lock_traits (for the compilers that do not support Koenig Lookup)
 */

// class lock_traits
/// Traits for the thread_mutex class (for compilers that do not support Koenig Lookup)
struct thread_mutex_lock_traits
{
public:
    /// The lockable type
    typedef thread_mutex                lock_type;
    typedef thread_mutex_lock_traits    class_type;

// Operations
public:
    /// Lock the given thread_mutex instance
    static void lock(thread_mutex &c)
    {
        lock_instance(c);
    }

    /// Unlock the given thread_mutex instance
    static void unlock(thread_mutex &c)
    {
        unlock_instance(c);
    }
};

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _WINSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
} // namespace winstl
# else
} // namespace winstl_project
} // namespace stlsoft
# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_WINSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !_WINSTL_INCL_H_WINSTL_THREAD_MUTEX */

/* ////////////////////////////////////////////////////////////////////////// */
