/* ////////////////////////////////////////////////////////////////////////////
 * File:        stlsoft_iterator.h (originally MTIter.h, ::SynesisStl)
 *
 * Purpose:     iterator classes.
 *
 * Created:     2nd January 2000
 * Updated:     28th November 2003
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


#ifndef _STLSOFT_INCL_H_STLSOFT_ITERATOR
#define _STLSOFT_INCL_H_STLSOFT_ITERATOR

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define _STLSOFT_VER_H_STLSOFT_ITERATOR_MAJOR      1
# define _STLSOFT_VER_H_STLSOFT_ITERATOR_MINOR      14
# define _STLSOFT_VER_H_STLSOFT_ITERATOR_REVISION   1
# define _STLSOFT_VER_H_STLSOFT_ITERATOR_EDIT       43
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* ////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _STLSOFT_INCL_H_STLSOFT
# include "stlsoft.h"  // Include the STLSoft root header
#endif /* !_STLSOFT_INCL_H_STLSOFT */
#include <iterator>    // std::iterator, std::reverse_iterator, std::reverse_bidirectional_iterator

/* /////////////////////////////////////////////////////////////////////////////
 * Warnings
 */

/* This is here temporarily, until a better solution can be found. */
#ifdef __STLSOFT_COMPILER_IS_MSVC
# pragma warning(disable : 4097)    // suppresses: typedef-name 'identifier1' used as synonym for class-name 'identifier2'
#endif /* __STLSOFT_COMPILER_IS_MSVC */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#ifndef _STLSOFT_NO_NAMESPACE
namespace stlsoft
{
#endif /* _STLSOFT_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Library identification
 */

// This is all some hideous kludge caused by Dinkumware's standard library's
// failure to leave behind any definitive discriminatable vestige of its
// presence.

#ifdef __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES
# undef __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES
#endif /* !__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES */

#ifdef __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES_1300
# undef __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES_1300
#endif /* !__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES_1300 */

#ifdef __STLSOFT_CF_STL_IS_STLPORT
# undef __STLSOFT_CF_STL_IS_STLPORT
#endif /* !__STLSOFT_CF_STL_IS_STLPORT */

/* Detect whether Dinkumware "may" be present
 *
 * Discriminated symbol is __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES
 */
#if (   defined(__STLSOFT_COMPILER_IS_INTEL) || \
        (   defined(__STLSOFT_COMPILER_IS_MSVC) && \
            _MSC_VER >= 1200 && \
            _MSC_VER < 1310)) && \
    defined(_STD_BEGIN) && \
    defined(_STD_END) && \
    defined(_Mbstinit)
# define __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES
#endif /* _MSC_VER && _MSC_VER == 1300 */

#if defined(__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES) && \
    defined(_DEPRECATED) && \
    defined(_HAS_TEMPLATE_PARTIAL_ORDERING) && \
    defined(_CPPLIB_VER)
# define __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES_1300
#endif /*  */

/* Detect whether STLport is present
 *
 * Discriminated symbol is __STLSOFT_CF_STL_IS_STLPORT
 */
#ifdef _STLPORT_VERSION
# define __STLSOFT_CF_STL_IS_STLPORT
#endif /* _STLPORT_VERSION */

/* Must be either Dinkumware or STLport if compiling with Intel or Visual C++
 */
#if (   defined(__STLSOFT_COMPILER_IS_INTEL) || \
        (   defined(__STLSOFT_COMPILER_IS_MSVC) && \
            _MSC_VER >= 1200 && \
            _MSC_VER < 1310)) && \
    (   !defined(__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES) && \
        !defined(__STLSOFT_CF_STL_IS_STLPORT))
# error When compiling with Intel C/C++ or Microsoft Visual C++, only the Dinkumware or STLport STL implementations are currently supported.
# error  Please contact STLSoft (admin@stlsoft.org) if you need to support a different STL implementation with these compilers.
#endif /* (Intel || MSVC) && !DinkumWare && !STLport */

/* /////////////////////////////////////////////////////////////////////////////
 * Iterator macros
 */

/* reverse_iterator */

#if defined(__STLSOFT_COMPILER_IS_BORLAND)
# define stlsoft_reverse_iterator(I, T, R, P, D)        stlsoft_ns_qual_std(reverse_iterator)<I>
#elif defined(__STLSOFT_COMPILER_IS_CUSTOM) || \
      defined(__STLSOFT_COMPILER_IS_UNKNOWN)
# define stlsoft_reverse_iterator(I, T, R, P, D)        stlsoft_ns_qual_std(reverse_iterator)<I, T, R, D>
#elif defined(__STLSOFT_COMPILER_IS_DMC)
# if defined(__STLSOFT_CF_STL_IS_STLPORT)
#  define stlsoft_reverse_iterator(I, T, R, P, D)       stlsoft_ns_qual_std(reverse_iterator)<I>
# else /* ? __STLSOFT_CF_STL_IS_STLPORT */
#  define stlsoft_reverse_iterator(I, T, R, P, D)       stlsoft_ns_qual_std(reverse_iterator)<I, T, R, D>
# endif /* __STLSOFT_CF_STL_IS_STLPORT */
#elif defined(__STLSOFT_COMPILER_IS_COMO)
# define stlsoft_reverse_iterator(I, T, R, P, D)        stlsoft_ns_qual_std(reverse_iterator)<I>
#elif defined(__STLSOFT_COMPILER_IS_GCC)
# if __GNUC__ < 3
#  define stlsoft_reverse_iterator(I, T, R, P, D)       ::reverse_iterator<I>
# else
#  define stlsoft_reverse_iterator(I, T, R, P, D)       stlsoft_ns_qual_std(reverse_iterator)<I>
# endif /* __GNUC__ < 3 */
#elif defined(__STLSOFT_COMPILER_IS_INTEL)
# if defined(__STLSOFT_CF_STL_IS_STLPORT) || \
     defined(__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES_1300)
#  define stlsoft_reverse_iterator(I, T, R, P, D)       stlsoft_ns_qual_std(reverse_iterator)<I>
# else
#  define stlsoft_reverse_iterator(I, T, R, P, D)       stlsoft_ns_qual_std(reverse_iterator)<I, T, R, P, D>
# endif /* __STLSOFT_CF_STL_IS_STLPORT || __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES_1300 */
#elif defined(__STLSOFT_COMPILER_IS_MWERKS)
# define stlsoft_reverse_iterator(I, T, R, P, D)        stlsoft_ns_qual_std(reverse_iterator)<I>
#elif defined(__STLSOFT_COMPILER_IS_MSVC)
# if _MSC_VER >= 1310
#  define stlsoft_reverse_iterator(I, T, R, P, D)       stlsoft_ns_qual_std(reverse_iterator)<I>
# elif defined(__STLSOFT_CF_STL_IS_STLPORT)
#  define stlsoft_reverse_iterator(I, T, R, P, D)       stlsoft_ns_qual_std(reverse_iterator)<I, T, R, D>
# elif defined(__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES_1300)
#  define stlsoft_reverse_iterator(I, T, R, P, D)       stlsoft_ns_qual_std(reverse_iterator)<I>
# else
#  define stlsoft_reverse_iterator(I, T, R, P, D)       stlsoft_ns_qual_std(reverse_iterator)<I, T, R, P, D>
# endif /* __STLSOFT_CF_STL_IS_STLPORT || __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES_1300 */
#elif defined(__STLSOFT_COMPILER_IS_WATCOM)
# if defined(__STLSOFT_CF_STL_IS_STLPORT)
#  define stlsoft_reverse_iterator(I, T, R, P, D)       stlsoft_ns_qual_std(reverse_iterator)<I>
# else
#  error Watcom is not supported independently of STLport
# endif /* __STLSOFT_CF_STL_IS_STLPORT */
#else
# error Compiler not recognised
#endif /* compiler */

/* reverse_bidirectional_iterator */

#if defined(__STLSOFT_COMPILER_IS_BORLAND)
# define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)      stlsoft_ns_qual_std(reverse_iterator)<I>
#elif defined(__STLSOFT_COMPILER_IS_CUSTOM) || \
      defined(__STLSOFT_COMPILER_IS_UNKNOWN)
# define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)      stlsoft_ns_qual_std(reverse_bidirectional_iterator)<I, T, R, D>
#elif defined(__STLSOFT_COMPILER_IS_DMC)
# if defined(__STLSOFT_CF_STL_IS_STLPORT)
# define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)      stlsoft_ns_qual_std(reverse_iterator)<I>
# else /* ? __STLSOFT_CF_STL_IS_STLPORT */
# define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)      stlsoft_ns_qual_std(reverse_bidirectional_iterator)<I, T, R, D>
# endif /* __STLSOFT_CF_STL_IS_STLPORT */
#elif defined(__STLSOFT_COMPILER_IS_COMO)
# define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)      stlsoft_ns_qual_std(reverse_iterator)<I>
#elif defined(__STLSOFT_COMPILER_IS_GCC)
# if __GNUC__ < 3
#  define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)     ::reverse_iterator<I>
# else
#  define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)     stlsoft_ns_qual_std(reverse_iterator)<I>
# endif /* __GNUC__ < 3 */
#elif defined(__STLSOFT_COMPILER_IS_MWERKS)
# define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)      stlsoft_ns_qual_std(reverse_iterator)<I>
#elif defined(__STLSOFT_COMPILER_IS_INTEL)
# ifdef __STLSOFT_CF_STL_IS_STLPORT
#  define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)     stlsoft_ns_qual_std(reverse_iterator)<I>
# else
#  define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)     stlsoft_ns_qual_std(reverse_bidirectional_iterator)<I, T, R, P, D>
# endif /* __STLSOFT_CF_STL_IS_STLPORT */
#elif defined(__STLSOFT_COMPILER_IS_MSVC)
# ifdef __STLSOFT_CF_STL_IS_STLPORT
#  ifdef _STLP_CLASS_PARTIAL_SPECIALIZATION
#   define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)    stlsoft_ns_qual_std(reverse_iterator)<I>
#  else
#   define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)    stlsoft_ns_qual_std(reverse_bidirectional_iterator)<I, T, R, P, D>
#  endif /* _STLP_CLASS_PARTIAL_SPECIALIZATION */
# else
#  define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)     stlsoft_ns_qual_std(reverse_bidirectional_iterator)<I, T, R, P, D>
# endif /* __STLSOFT_CF_STL_IS_STLPORT */
#elif defined(__STLSOFT_COMPILER_IS_WATCOM)
# if defined(__STLSOFT_CF_STL_IS_STLPORT)
#  define stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)     stlsoft_ns_qual_std(reverse_iterator)<I>
# else
#  error Watcom is not supported independently of STLport
# endif /* __STLSOFT_CF_STL_IS_STLPORT */
#else
# error Compiler not recognised
#endif /* compiler */

/* /////////////////////////////////////////////////////////////////////////////
 * Iterators
 */

// class iterator_base
/// Base type for <b><code>iterator</code></b> types
//
/// This class abstract std::iterator functionality for deriving classes, hiding
/// the inconsistencies and incompatibilities of the various compilers and/or
/// libraries supported by the STLSoft libraries.
///
/// \param C The iterator category
/// \param T The value type
/// \param D The distance type
/// \param P The pointer type
/// \param R The reference type
template<   ss_typename_param_k C   /* category */
        ,   ss_typename_param_k T   /* type */
        ,   ss_typename_param_k D   /* distance */
        ,   ss_typename_param_k P   /* pointer */
        ,   ss_typename_param_k R   /* reference */
        >
struct iterator_base
#if defined(__STLSOFT_COMPILER_IS_INTEL) || \
    defined(__STLSOFT_COMPILER_IS_MSVC)
    : public stlsoft_ns_qual_std(iterator)<stlsoft_ns_qual_std(input_iterator_tag), T, D>
#elif defined(__STLSOFT_COMPILER_IS_MWERKS)
    : public stlsoft_ns_qual_std(iterator)<stlsoft_ns_qual_std(input_iterator_tag), T, D, P, R>
#endif /* __STLSOFT_COMPILER_IS_MSVC */
{
#if defined(__STLSOFT_COMPILER_IS_INTEL) || \
    defined(__STLSOFT_COMPILER_IS_MSVC)
    typedef stlsoft_ns_qual_std(iterator)<stlsoft_ns_qual_std(input_iterator_tag), T, D>         parent_class_type;
#elif defined(__STLSOFT_COMPILER_IS_MWERKS)
    typedef stlsoft_ns_qual_std(iterator)<stlsoft_ns_qual_std(input_iterator_tag), T, D, P, R>   parent_class_type;
#endif /* __STLSOFT_COMPILER_IS_MSVC */

public:
#if defined(__STLSOFT_COMPILER_IS_INTEL) || \
    defined(__STLSOFT_COMPILER_IS_MSVC) || \
    defined(__STLSOFT_COMPILER_IS_MWERKS)
    typedef ss_typename_type_k parent_class_type::iterator_category iterator_category;
    typedef ss_typename_type_k parent_class_type::value_type        value_type;
# if (   defined(__STLSOFT_COMPILER_IS_INTEL) || \
         defined(__STLSOFT_COMPILER_IS_MSVC)) && \
    !defined(__STLSOFT_CF_STL_IS_STLPORT)
    typedef ss_typename_type_k parent_class_type::distance_type     difference_type;
    typedef P                                                       pointer;
    typedef R                                                       reference;
# else
    typedef ss_typename_type_k parent_class_type::difference_type   difference_type;
    typedef ss_typename_type_k parent_class_type::pointer           pointer;
    typedef ss_typename_type_k parent_class_type::reference         reference;
# endif /* __STLSOFT_COMPILER_IS_MSVC */

#elif defined(__STLSOFT_COMPILER_IS_GCC) || \
      defined(__STLSOFT_COMPILER_IS_BORLAND)
# if defined(__STLSOFT_COMPILER_IS_GCC)
#  if __GNUC__ < 3
    typedef __STD::input_iterator_tag                               iterator_category;
#  else
    typedef stlsoft_ns_qual_std(input_iterator_tag)                 iterator_category;
#  endif /* __GNUC__ < 3 */
# elif defined(__STLSOFT_COMPILER_IS_BORLAND)
    typedef stlsoft_ns_qual_std(input_iterator_tag)                 iterator_category;
# endif /* __STLSOFT_COMPILER_IS_GCC || __STLSOFT_COMPILER_IS_BORLAND */
    typedef T                                                       value_type;
    typedef D                                                       difference_type;
    typedef P                                                       pointer;
    typedef R                                                       reference;
#else
    /* All other compilers. */
# if defined(__STLSOFT_COMPILER_IS_CUSTOM) || \
     defined(__STLSOFT_COMPILER_IS_UNKNOWN) || \
     defined(__STLSOFT_COMPILER_IS_DMC)
    typedef C                                                       iterator_category;
    typedef T                                                       value_type;
    typedef D                                                       difference_type;
    typedef P                                                       pointer;
    typedef R                                                       reference;
# elif defined(__STLSOFT_COMPILER_IS_WATCOM)
#  if defined(__STLSOFT_CF_STL_IS_STLPORT)
    typedef ss_typename_type_k parent_class_type::distance_type     difference_type;
    typedef P                                                       pointer;
    typedef R                                                       reference;
#  else
#   error Watcom is not supported independently of STLport
#  endif /* __STLSOFT_CF_STL_IS_STLPORT */
# else
#  error Compiler not supported
# endif /* !__STLSOFT_COMPILER_IS_DMC */
#endif /* __STLSOFT_COMPILER_IS_GCC || __STLSOFT_COMPILER_IS_BORLAND */

    /* These two are for compatibility with older non-standard implementations, and
     * will be benignly ignored by anything not requiring them.
     */
    typedef pointer                                                 pointer_type;
    typedef reference                                               reference_type;
};


// reverse_iterator_base, const_reverse_iterator_base,
// reverse_bidirectional_iterator_base and const_reverse_bidirectional_iterator_base
//
// These classes act as the base for reverse iterators, insulating deriving
// classes from the inconsistencies and incompatibilities of the various
// compilers and/or libraries supported by the STLSoft libraries.

// class reverse_iterator_base
/// Base type for <b><code>reverse_iterator</code></b> types
//
/// This class acts as the base for reverse iterators, insulating deriving
/// classes from the inconsistencies and incompatibilities of the various
/// compilers and/or libraries supported by the STLSoft libraries.
///
/// \param I The iterator type
/// \param T The value type
/// \param R The reference type
/// \param P The pointer type
/// \param D The distance type
template<   ss_typename_param_k I
        ,   ss_typename_param_k T
        ,   ss_typename_param_k R
        ,   ss_typename_param_k P
        ,   ss_typename_param_k D
        >
struct reverse_iterator_base
    : public stlsoft_reverse_iterator(I, T, R, P, D)
{
public:
    typedef stlsoft_reverse_iterator(I, T, R, P, D)                 parent_class_type;

    typedef ss_typename_type_k parent_class_type::iterator_category iterator_category;
    typedef ss_typename_type_k parent_class_type::value_type        value_type;
# if (   defined(__STLSOFT_COMPILER_IS_INTEL) || \
         defined(__STLSOFT_COMPILER_IS_MSVC)) && \
      _MSC_VER < 1300 && /* This is truly hideous, but since PJP doesn't put version numbers in the VC++ stl swill, we have no choice */ \
     !defined(__STLSOFT_CF_STL_IS_STLPORT)
    typedef ss_typename_type_k parent_class_type::distance_type     difference_type;
    typedef ss_typename_type_k parent_class_type::pointer_type      pointer;
    typedef ss_typename_type_k parent_class_type::reference_type    reference;
#else
    typedef ss_typename_type_k parent_class_type::difference_type   difference_type;
    typedef ss_typename_type_k parent_class_type::pointer           pointer;
    typedef ss_typename_type_k parent_class_type::reference         reference;
#endif /* __STLSOFT_COMPILER_IS_MSVC */

    /* These two are for compatibility with older non-standard implementations, and
     * will be benignly ignored by anything not requiring them.
     */
    typedef pointer                                                 pointer_type;
    typedef reference                                               reference_type;

// Construction
public:
    /// Constructor
    ss_explicit_k reverse_iterator_base(I i)
        : parent_class_type(i)
    {}
};

// class const_reverse_iterator_base
/// Base type for <b><code>const_reverse_iterator</code></b> types
//
/// This class acts as the base for const reverse iterators, insulating deriving
/// classes from the inconsistencies and incompatibilities of the various
/// compilers and/or libraries supported by the STLSoft libraries.
///
/// \param I The iterator type
/// \param T The value type
/// \param R The reference type
/// \param P The pointer type
/// \param D The distance type
template<   ss_typename_param_k I
        ,   ss_typename_param_k T
        ,   ss_typename_param_k R
        ,   ss_typename_param_k P
        ,   ss_typename_param_k D
        >
struct const_reverse_iterator_base
    : public stlsoft_reverse_iterator(I, T, R, P, D)
{
public:
    typedef stlsoft_reverse_iterator(I, T, R, P, D)                 parent_class_type;

    typedef ss_typename_type_k parent_class_type::iterator_category iterator_category;
    typedef ss_typename_type_k parent_class_type::value_type        value_type;
# if (   defined(__STLSOFT_COMPILER_IS_INTEL) || \
         defined(__STLSOFT_COMPILER_IS_MSVC)) && \
      _MSC_VER < 1300 && /* This is truly hideous, but since PJP doesn't put version numbers in the VC++ stl swill, we have no choice */ \
     !defined(__STLSOFT_CF_STL_IS_STLPORT)
    typedef ss_typename_type_k parent_class_type::distance_type     difference_type;
    typedef ss_typename_type_k parent_class_type::pointer_type      pointer;
    typedef ss_typename_type_k parent_class_type::reference_type    reference;
#else
    typedef ss_typename_type_k parent_class_type::difference_type   difference_type;
    typedef ss_typename_type_k parent_class_type::pointer           pointer;
    typedef ss_typename_type_k parent_class_type::reference         reference;
#endif /* __STLSOFT_COMPILER_IS_MSVC && __STLSOFT_CF_STL_IS_STLPORT */

    /* These two are for compatibility with older non-standard implementations, and
     * will be benignly ignored by anything not requiring them.
     */
    typedef pointer                                                 pointer_type;
    typedef reference                                               reference_type;

// Construction
public:
    /// Constructor
    ss_explicit_k const_reverse_iterator_base(I i)
        : parent_class_type(i)
    {}
};

#ifdef __STLSOFT_CF_BIDIRECTIONAL_ITERATOR_SUPPORT

// class reverse_bidirectional_iterator_base
/// Base type for <b><code>reverse_bidirectional_iterator</code></b> types
//
/// This class acts as the base for reverse bidirectional iterators,
/// insulating deriving classes from the inconsistencies and incompatibilities
/// of the various compilers and/or libraries supported by the STLSoft libraries.
///
/// \param I The iterator type
/// \param T The value type
/// \param R The reference type
/// \param P The pointer type
/// \param D The distance type
template<   ss_typename_param_k I
        ,   ss_typename_param_k T
        ,   ss_typename_param_k R
        ,   ss_typename_param_k P
        ,   ss_typename_param_k D
        >
struct reverse_bidirectional_iterator_base
    : public stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)
{
public:
    typedef stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)               parent_class_type;

    typedef ss_typename_type_k parent_class_type::iterator_category             iterator_category;
    typedef ss_typename_type_k parent_class_type::value_type                    value_type;
# if (   defined(__STLSOFT_COMPILER_IS_INTEL) || \
         defined(__STLSOFT_COMPILER_IS_MSVC)) && \
      _MSC_VER < 1300 && /* This is truly hideous, but since PJP doesn't put version numbers in the VC++ stl swill, we have no choice */ \
     !defined(__STLSOFT_CF_STL_IS_STLPORT)
    typedef ss_typename_type_k parent_class_type::distance_type                 difference_type;
    typedef ss_typename_type_k parent_class_type::pointer_type                  pointer;
    typedef ss_typename_type_k parent_class_type::reference_type                reference;
#else
    typedef ss_typename_type_k parent_class_type::difference_type               difference_type;
    typedef ss_typename_type_k parent_class_type::pointer                       pointer;
    typedef ss_typename_type_k parent_class_type::reference                     reference;
#endif /* __STLSOFT_COMPILER_IS_MSVC */

    /* These two are for compatibility with older non-standard implementations, and
     * will be benignly ignored by anything not requiring them.
     */
    typedef pointer                                                             pointer_type;
    typedef reference                                                           reference_type;

// Construction
public:
    /// Constructor
    ss_explicit_k reverse_bidirectional_iterator_base(I i)
        : parent_class_type(i)
    {}
};

// class const_reverse_bidirectional_iterator_base
/// Base type for <b><code>const_reverse_bidirectional_iterator</code></b> types
//
/// This class acts as the base for const reverse bidirectional iterators,
/// insulating deriving classes from the inconsistencies and incompatibilities
/// of the various compilers and/or libraries supported by the STLSoft libraries.
///
/// \param I The iterator type
/// \param T The value type
/// \param R The reference type
/// \param P The pointer type
/// \param D The distance type
template<   ss_typename_param_k I
        ,   ss_typename_param_k T
        ,   ss_typename_param_k R
        ,   ss_typename_param_k P
        ,   ss_typename_param_k D
        >
struct const_reverse_bidirectional_iterator_base
    : public stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)
{
public:
    typedef stlsoft_reverse_bidirectional_iterator(I, T, R, P, D)               parent_class_type;

    typedef ss_typename_type_k parent_class_type::iterator_category             iterator_category;
    typedef ss_typename_type_k parent_class_type::value_type                    value_type;
# if (   defined(__STLSOFT_COMPILER_IS_INTEL) || \
         defined(__STLSOFT_COMPILER_IS_MSVC)) && \
      _MSC_VER < 1300 && /* This is truly hideous, but since PJP doesn't put version numbers in the VC++ stl swill, we have no choice */ \
     !defined(__STLSOFT_CF_STL_IS_STLPORT)
    typedef ss_typename_type_k parent_class_type::distance_type                 difference_type;
    typedef ss_typename_type_k parent_class_type::pointer_type                  pointer;
    typedef ss_typename_type_k parent_class_type::reference_type                reference;
#else
    typedef ss_typename_type_k parent_class_type::difference_type               difference_type;
    typedef ss_typename_type_k parent_class_type::pointer                       pointer;
    typedef ss_typename_type_k parent_class_type::reference                     reference;
#endif /* __STLSOFT_COMPILER_IS_MSVC && __STLSOFT_CF_STL_IS_STLPORT */

    /* These two are for compatibility with older non-standard implementations, and
     * will be benignly ignored by anything not requiring them.
     */
    typedef pointer                                                             pointer_type;
    typedef reference                                                           reference_type;

// Construction
public:
    /// Constructor
    ss_explicit_k const_reverse_bidirectional_iterator_base(I i)
        : parent_class_type(i)
    {}
};

#endif /* __STLSOFT_CF_BIDIRECTIONAL_ITERATOR_SUPPORT */

// Random access iterator support

#ifdef __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES

#ifndef _STLSOFT_NO_NAMESPACE
} // namespace stlsoft
#endif /* _STLSOFT_NO_NAMESPACE */

template<   ss_typename_param_k _Ty
        ,   ss_typename_param_k _Diff
        ,   ss_typename_param_k _Pointer
        ,   ss_typename_param_k _Reference
        ,   ss_typename_param_k _Pointer2
        ,   ss_typename_param_k _Reference2
        >
class _Ptrit
{
public:
    typedef _Pointer    iterator_type;

private:
    char    x[1024];
};

namespace std
{
    namespace test_dinkumware
    {
        template<   ss_typename_param_k T1
                ,   ss_typename_param_k T2
                ,   bool S
                >
        struct select_type
        {
            typedef T1  selected_type;
        };

#ifdef __STLSOFT_CF_TEMPLATE_PARTIAL_SPECIALISATION_SUPPORT
        template<   ss_typename_param_k T1
                ,   ss_typename_param_k T2
                >
        struct select_type<T1, T2, false>
        {
            typedef T2  selected_type;
        };
#endif //# ifdef __STLSOFT_CF_TEMPLATE_PARTIAL_SPECIALISATION_SUPPORT

        template<   class V
                ,   class P
                ,   class R
                >
        class _Ptrit_tdkw
        {
            typedef _Ptrit<V, ptrdiff_t, P, R, P, R>    _Ptrit_type;

        public:
            typedef select_type<_Ptrit_type, P, sizeof(_Ptrit_type) < 1024>::selected_type  iterator_type;
        };

    }
}

#ifndef _STLSOFT_NO_NAMESPACE
namespace stlsoft
{
#endif /* _STLSOFT_NO_NAMESPACE */

#endif /* !__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES */

/// Pointer iterator type
///
/// \param V The value type
/// \param P The pointer type
/// \param R The reference type
template<   ss_typename_param_k V
        ,   ss_typename_param_k P
        ,   ss_typename_param_k R
        >
struct pointer_iterator
{
#if defined(__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES) && \
    !defined(__STLSOFT_CF_STL_IS_STLPORT)
# if defined(__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES_1300)
    typedef std::test_dinkumware::_Ptrit_tdkw<V, P, R>::iterator_type   iterator_type;
# else
    typedef P                                                           iterator_type;
# endif /* __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES_1300 */
#elif defined(__STLSOFT_COMPILER_IS_MSVC) && \
      !defined(__STLSOFT_CF_STL_IS_STLPORT) && \
      defined(_XUTILITY_) && \
      _MSC_VER == 1300
    typedef std::_Ptrit<V, ptrdiff_t, P, R, P, R>                       iterator_type;
#else
    typedef P                                                           iterator_type;
#endif /* !__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES */
};

/* ////////////////////////////////////////////////////////////////////////// */

#if defined(__STLSOFT_COMPILER_IS_DMC) && \
	!defined(__STLSOFT_CF_STL_IS_STLPORT)
template<   ss_typename_param_k V
        ,   ss_typename_param_k P
        ,   ss_typename_param_k R
        >
inline random_access_iterator_tag iterator_category(pointer_iterator<V, P, R>::iterator_type const &)
{
    return random_access_iterator_tag();
}

template<   ss_typename_param_k V
        ,   ss_typename_param_k P
        ,   ss_typename_param_k R
        >
inline ptrdiff_t* distance_type(pointer_iterator<V, P, R>::iterator_type const &)
{
    return static_cast<ptrdiff_t*>(0);
}
#endif /* __STLSOFT_COMPILER_IS_DMC  && !__STLSOFT_CF_STL_IS_STLPORT */

/* ////////////////////////////////////////////////////////////////////////// */


/// Iterator category obtainer
///
/// \param I The iterator type
/// \param i The iterator instance

#if defined(__STLSOFT_COMPILER_IS_DMC)
# if defined(__STLSOFT_CF_STL_IS_STLPORT)
#  define stlsoft_iterator_query_category(I, i)     (stlsoft_ns_qual_std(iterator_traits)<I>::iterator_category())
//#  error Digital Mars with STLport not yet supported
# else
#  define stlsoft_iterator_query_category(I, i)     (stlsoft_ns_qual_std(iterator_category)(i))
# endif /*  */
#elif defined(__STLSOFT_COMPILER_IS_INTEL)
# if defined(__STLSOFT_CF_STL_IS_STLPORT)
#  define stlsoft_iterator_query_category(I, i)     (stlsoft_ns_qual_std(iterator_traits)<I>::iterator_category())
# elif defined(__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES)
#  define stlsoft_iterator_query_category(I, i)     (stlsoft_ns_qual_std(_Iter_cat)(i))
# else
#  error 
# endif /*  */
#elif defined(__STLSOFT_COMPILER_IS_MSVC)
# if defined(__STLSOFT_CF_STL_IS_STLPORT)
#  if _MSC_VER < 1300
#   define stlsoft_iterator_query_category(I, i)    (stlsoft_ns_qual_std(iterator_category)(i))
#  else
#   define stlsoft_iterator_query_category(I, i)    (stlsoft_ns_qual_std(iterator_category)(i))
#  endif /* _MSC_VER < 1300 */
# elif defined(__STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES)
#  define stlsoft_iterator_query_category(I, i)     (stlsoft_ns_qual_std(_Iter_cat)(i))
# elif(_MSC_VER >= 1310)
#  define stlsoft_iterator_query_category(I, i)     (stlsoft_ns_qual_std(iterator_traits)<I>::iterator_category())
# elif(_MSC_VER >= 1200)
#  error 
# endif /*  */
#else
# define stlsoft_iterator_query_category(I, i)      (stlsoft_ns_qual_std(iterator_traits)<I>::iterator_category())
#endif /* __STLSOFT_CF_MIGHT_BE_DINKUMWARE_MS_NAUGHTIES && !__STLSOFT_CF_STL_IS_STLPORT */

#if 0
template <typename T>
struct queried_iterator_category
{
};

template <typename T>
query_iterator_category
#endif /* 0 */

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _STLSOFT_NO_NAMESPACE
} // namespace stlsoft
#endif /* _STLSOFT_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* _STLSOFT_INCL_H_STLSOFT_ITERATOR */

/* ////////////////////////////////////////////////////////////////////////// */
