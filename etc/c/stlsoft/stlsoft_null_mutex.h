/* ////////////////////////////////////////////////////////////////////////////
 * File:        stlsoft_null_mutex.h (originally MLMutex.h, ::SynesisStd)
 *
 * Purpose:     Mutual exclusion model class.
 *
 * Date:        19th December 1997
 * Updated:     2nd July 2003
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


#ifndef _STLSOFT_INCL_H_STLSOFT_NULL_MUTEX
#define _STLSOFT_INCL_H_STLSOFT_NULL_MUTEX

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _STLSOFT_VER_H_STLSOFT_NULL_MUTEX_MAJOR     1
#define _STLSOFT_VER_H_STLSOFT_NULL_MUTEX_MINOR     1
#define _STLSOFT_VER_H_STLSOFT_NULL_MUTEX_REVISION  1
#define _STLSOFT_VER_H_STLSOFT_NULL_MUTEX_EDIT      10
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _STLSOFT_INCL_H_STLSOFT
 #include "stlsoft.h"   // Include the STLSoft root header
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

// class null_mutex

/// This class provides a null implementation of the mutex model
class null_mutex
{
public:
    typedef null_mutex class_type;

// Construction
public:
    /// Creates an instance of the mutex
    null_mutex() stlsoft_throw_0()
    {}

// Operations
public:
    /// Acquires a lock on the mutex, pending the thread until the lock is aquired
    void lock() stlsoft_throw_0()
    {}
    /// Releases an aquired lock on the mutex
    void unlock() stlsoft_throw_0()
    {}

// Not to be implemented
private:
    null_mutex(class_type const &rhs);
    null_mutex &operator =(class_type const &rhs);
};

/* /////////////////////////////////////////////////////////////////////////////
 * Control shims
 */

/// \weakgroup concepts STLSoft Concepts

/// \weakgroup concepts_shims Shims
/// \ingroup concepts 

/// \weakgroup concepts_shims_sync_control Synchronisation Control Shims
/// \ingroup concepts_shims
/// \brief These \ref concepts_shims "shims" control the behaviour of synchronisation objects

/// \defgroup stlsoft_sync_control_shims Synchronisation Control Shims (STLSoft)
/// \ingroup STLSoft concepts_shims_sync_control
/// \brief These \ref concepts_shims "shims" control the behaviour of synchronisation objects
/// @{

/// This control \ref concepts_shims "shim" aquires a lock on the given mutex
///
/// \param mx The mutex on which to aquire the lock
inline void lock_instance(null_mutex &)
{}

/// This control ref concepts_shims "shim" releases a lock on the given mutex
///
/// \param mx The mutex on which to release the lock
inline void unlock_instance(null_mutex &)
{}

/// @} // end of group stlsoft_sync_control_shims

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _STLSOFT_NO_NAMESPACE
} // namespace stlsoft
#endif /* _STLSOFT_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !_STLSOFT_INCL_H_STLSOFT_NULL_MUTEX */

/* ////////////////////////////////////////////////////////////////////////// */
