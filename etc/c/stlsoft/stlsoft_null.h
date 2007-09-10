/* /////////////////////////////////////////////////////////////////////////////
 * File:        stlsoft_null.h
 *
 * Purpose:     NULL_v template class.
 *
 * Created:     8th September 2002
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


#ifndef _STLSOFT_INCL_H_STLSOFT_NULL
#define _STLSOFT_INCL_H_STLSOFT_NULL

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _STLSOFT_VER_H_STLSOFT_NULL_MAJOR       1
#define _STLSOFT_VER_H_STLSOFT_NULL_MINOR       6
#define _STLSOFT_VER_H_STLSOFT_NULL_REVISION    1
#define _STLSOFT_VER_H_STLSOFT_NULL_EDIT        19
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _STLSOFT_INCL_H_STLSOFT
# include "stlsoft.h"   // Include the STLSoft root header
#endif /* !_STLSOFT_INCL_H_STLSOFT */

/* _STLSOFT_NULL_v_DEFINED */

#ifdef _STLSOFT_NULL_v_DEFINED
# undef _STLSOFT_NULL_v_DEFINED
#endif /* _STLSOFT_NULL_v_DEFINED */

#define _STLSOFT_NULL_v_DEFINED

#if defined(__STLSOFT_COMPILER_IS_DMC)
//# if __DMC__ < 0x0832
#  undef _STLSOFT_NULL_v_DEFINED
//# endif /* __DMC__ < 0x0832 */
#elif defined(__STLSOFT_COMPILER_IS_MSVC) && \
      _MSC_VER < 1310
# undef _STLSOFT_NULL_v_DEFINED
#elif defined(__STLSOFT_COMPILER_IS_WATCOM)
# undef _STLSOFT_NULL_v_DEFINED
#endif /* compiler */

/* _STLSOFT_NULL_v_DEFINED_PTR_TO_MEMBER_SUPPORT */

#ifdef _STLSOFT_NULL_v_DEFINED_PTR_TO_MEMBER_SUPPORT
# undef _STLSOFT_NULL_v_DEFINED_PTR_TO_MEMBER_SUPPORT
#endif /* _STLSOFT_NULL_v_DEFINED_PTR_TO_MEMBER_SUPPORT */

#define _STLSOFT_NULL_v_DEFINED_PTR_TO_MEMBER_SUPPORT

#if defined(__STLSOFT_COMPILER_IS_GCC)
# undef _STLSOFT_NULL_v_DEFINED_PTR_TO_MEMBER_SUPPORT
#elif defined(__STLSOFT_COMPILER_IS_MWERKS)
# undef _STLSOFT_NULL_v_DEFINED_PTR_TO_MEMBER_SUPPORT
#endif /* compiler */

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

#ifdef _STLSOFT_NULL_v_DEFINED

/// \brief Represents a type that can be an active replacement for NULL
///
/// This class can act as a replacement for the NULL macro, by being validly
/// assigned to or equated with pointer types only, as in
///
///   int   i = NULL; // error
///   int   *p = NULL; // OK
///
///   if(i == NULL) {} // error
///   if(NULL == i) {} // error
///
///   if(p == NULL) {} // OK
///   if(NULL == p) {} // OK
///
///
/// When used via inclusion of the file stlsoft_nulldef.h, the macro NULL is
/// redefined as NULL_v(), such that expressions containing NULL will be valid
/// against pointers only.
struct NULL_v
{
// Construction
public:
    /// Default constructor
    NULL_v()
    {}

/// Static creation
public:
    static NULL_v create()
    {
        return NULL_v();
    }

// Conversion
public:
    /// Implicit conversion operator (convertible to any pointer type)
    ///
    /// \param T The type of the pointer to which an instance will be convertible
    template <ss_typename_param_k T>
    operator T *() const
    {
        return 0;
    }

#ifdef _STLSOFT_NULL_v_DEFINED_PTR_TO_MEMBER_SUPPORT
    /// Implicit conversion operator (convertible to any pointer type)
    ///
    /// \param T The type of the pointer to which an instance will be convertible
    template <ss_typename_param_k T2, ss_typename_param_k C>
    operator T2 C::*() const
    {
        return 0;
    }
#endif /* _STLSOFT_NULL_v_DEFINED_PTR_TO_MEMBER_SUPPORT */

    /// Evaluates whether an instance of a type is null
    ///
    /// \param rhs A reference arbitrary type which will be compared to null
    template <ss_typename_param_k T>
    ss_bool_t equals(T const &rhs) const
    {
        return rhs == 0;
    }

// Not to be implemented
private:
    void operator &() const;

    NULL_v(NULL_v const &);
    NULL_v const &operator =(NULL_v const &);
};

#if 1
/// operator == for NULL_v and an arbitrary type
template <ss_typename_param_k T>
inline ss_bool_t operator ==(NULL_v const &lhs, T const &rhs)
{
    return lhs.equals(rhs);
}

/// operator == for an arbitrary type and NULL_v
template <ss_typename_param_k T>
inline ss_bool_t operator ==(T const &lhs, NULL_v const &rhs)
{
    return rhs.equals(lhs);
}

/// operator != for NULL_v and an arbitrary type
template <ss_typename_param_k T>
inline ss_bool_t operator !=(NULL_v const &lhs, T const &rhs)
{
    return !lhs.equals(rhs);
}

/// operator != for an arbitrary type and NULL_v
template <ss_typename_param_k T>
inline ss_bool_t operator !=(T const &lhs, NULL_v const &rhs)
{
    return !rhs.equals(lhs);
}
#endif /* 0 */

#endif /* _STLSOFT_NULL_v_DEFINED */

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _STLSOFT_NO_NAMESPACE
} // namespace stlsoft
#endif /* _STLSOFT_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !_STLSOFT_INCL_H_STLSOFT_NULL */

/* ////////////////////////////////////////////////////////////////////////// */
