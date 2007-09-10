/* ////////////////////////////////////////////////////////////////////////////
 * File:        stlsoft_lock_scope.h (originally MLLock.h, ::SynesisStd)
 *
 * Purpose:     Synchronisation object lock scoping class.
 *
 * Created:     1st October 1994
 * Updated:     22nd November 2003
 *
 * Author:      Matthew Wilson, Synesis Software Pty Ltd.
 *
 * License:     (Licensed under the Synesis Software Standard Source License)
 *
 *              Copyright (C) 2002-2003, Synesis Software Pty Ltd.
 *
 *              All rights reserved.
 *
 *              www:        http://www.synesis.com.au/stlsoft
 *                          http://www.stlsoft.org/
 *
 *              email:      submissions@stlsoft.org  for submissions
 *                          admin@stlsoft.org        for other enquiries
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


#ifndef _STLSOFT_INCL_H_STLSOFT_LOCK_SCOPE
#define _STLSOFT_INCL_H_STLSOFT_LOCK_SCOPE

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _STLSOFT_VER_H_STLSOFT_LOCK_SCOPE_MAJOR     3
#define _STLSOFT_VER_H_STLSOFT_LOCK_SCOPE_MINOR     0
#define _STLSOFT_VER_H_STLSOFT_LOCK_SCOPE_REVISION  2
#define _STLSOFT_VER_H_STLSOFT_LOCK_SCOPE_EDIT      89
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _STLSOFT_INCL_H_STLSOFT
# include "stlsoft.h"   // Include the STLSoft root header
#endif /* !_STLSOFT_INCL_H_STLSOFT */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#ifndef _STLSOFT_NO_NAMESPACE
namespace stlsoft
{
#endif /* _STLSOFT_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

// class lock_traits

/// Traits class for lockable objects
///
/// \param L The lockable class
template<ss_typename_param_k L>
struct lock_traits
{
public:
    /// The lockable type
    typedef L               lock_type;
    /// The current parameterisation of this type
    typedef lock_traits<L>  class_type;

// Operations
public:
    /// Locks the given lockable instance
    static void lock(lock_type &c)
    {
        lock_instance(c);
    }

    /// Unlocks the given lockable instance
    static void unlock(lock_type &c)
    {
        unlock_instance(c);
    }
};

// class lock_invert_traits

/// Traits class for inverting the lock status of lockable objects
///
/// \param L The lockable class
template<ss_typename_param_k L>
struct lock_invert_traits
{
public:
    /// The lockable type
    typedef L                       lock_type;
    /// The current parameterisation of this type
    typedef lock_invert_traits<L>   class_type;

// Operations
public:
    /// Unlocks the given lockable instance
    static void lock(lock_type &c)
    {
        unlock_instance(c);
    }

    /// Locks the given lockable instance
    static void unlock(lock_type &c)
    {
        lock_instance(c);
    }
};

// class lock_traits_inverter

/// Traits inverter class for inverting the lock behaviour of lockable traits types
///
/// \param L The traits class
template<ss_typename_param_k T>
struct lock_traits_inverter
{
public:
    /// The traits type
    typedef T                                           traits_type;
    /// The lockable type
    typedef ss_typename_type_k traits_type::lock_type   lock_type;
    /// The current parameterisation of this type
    typedef lock_traits_inverter<T>                     class_type;

// Operations
public:
    /// Unlocks the given lockable instance
    static void lock(lock_type &c)
    {
        traits_type::unlock(c);
    }

    /// Locks the given lockable instance
    static void unlock(lock_type &c)
    {
        traits_type::lock(c);
    }
};

// class lock_scope

/// This class scopes the lock status of a lockable type
///
/// \param L The lockable type, e.g. stlsoft::null_mutex
/// \param T The lock traits. On translators that support default template arguments this defaults to lock_traits<L>
template<   ss_typename_param_k L
#ifdef __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT
        ,   ss_typename_param_k T = lock_traits<L>
#else
        ,   ss_typename_param_k T
#endif /* __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT */
        >
class lock_scope
{
public:
    /// The lockable type
    typedef L                       lock_type;
    /// The traits type
    typedef T                       traits_type;
    /// The current parameterisation of this type
    typedef lock_scope<L, T>        class_type;

// Construction
public:
    /// Locks the lockable instance
    lock_scope(lock_type &l)
        : m_l(l)
    {
        traits_type::lock(m_l);
    }
    /// Unlocks the lockable instance
    ~lock_scope()
    {
        traits_type::unlock(m_l);
    }

// Members
private:
    lock_type   &m_l;

// Not to be implemented
private:
    lock_scope(class_type const &rhs);
    lock_scope &operator =(class_type const &rhs);
};

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _STLSOFT_NO_NAMESPACE
} // namespace stlsoft
#endif /* _STLSOFT_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !_STLSOFT_INCL_H_STLSOFT_LOCK_SCOPE */

/* ////////////////////////////////////////////////////////////////////////// */
