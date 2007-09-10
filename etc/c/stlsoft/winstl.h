/* /////////////////////////////////////////////////////////////////////////////
 * File:        winstl.h
 *
 * Purpose:     Root header for the WinSTL libraries. Performs various compiler
 *              and platform discriminations, and definitions of types.
 *
 * Created:     15th January 2002
 * Updated:     17th November 2003
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


#ifndef _WINSTL_INCL_H_WINSTL
#define _WINSTL_INCL_H_WINSTL

/* File version */
#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _WINSTL_VER_H_WINSTL_MAJOR      1
#define _WINSTL_VER_H_WINSTL_MINOR      26
#define _WINSTL_VER_H_WINSTL_REVISION   1
#define _WINSTL_VER_H_WINSTL_EDIT       100
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/** \file winstl.h The root header for the \ref WinSTL project */

/** \weakgroup projects STLSoft Projects
 *
 * \brief The Projects that comprise the STLSoft libraries
 */

/** \defgroup WinSTL WinSTL
 * \ingroup projects
 *
 * \brief <img src = "winstl32x32.jpg">&nbsp;&nbsp;&nbsp;&nbsp;<i>Where the Standard Template Library meets the Win32 API</i>
 *
 * The philosophy of WinSTL (http://winstl.org/) is essentially the same as that
 * of the STLSoft (http://stlsoft.org/) organisation: providing robust and
 * lightweight software to the Win32 API development
 * community. WinSTL provides template-based software that builds on that
 * provided by Win and STLSoft in order to reduce programmer effort and increase
 * robustness in the use of the Win. 
 *
 * <b>Namespaces</b>
 *
 * The WinSTL namespace <code><b>winstl</b></code> is actually an alias for the
 * namespace <code><b>stlsoft::winstl_project</b></code>, and as such all the
 * WinSTL project components actually reside within the
 * <code><b>stlsoft</b></code> namespace. However, there is never any need to 
 * use the <code><b>stlsoft::winstl_project</b></code> namespace in your code,
 * and you should always use the alias <code><b>winstl</b></code>.
 *
 * <b>Dependencies</b>
 *
 * As with <b><i>all</i></b> parts of the STLSoft libraries, there are no
 * dependencies on WinSTL binary components and no need to compile WinSTL
 * implementation files; WinSTL is <b>100%</b> header-only!
 *
 * As with most of the STLSoft sub-projects, WinSTL depends only on:
 *
 * - Selected headers from the C standard library, such as  <code><b>wchar.h</b></code>
 * - Selected headers from the C++ standard library, such as <code><b>new</b></code>, <code><b>functional</b></code>
 * - Selected header files of the STLSoft main project
 * - The header files particular to the technology area, in this case the Win32 API library headers, such as <code><b>objbase.h</b></code>
 * - The binary (static and dynamic libraries) components particular to the technology area, in this case the Win32 API libraries that ship with the operating system and your compiler(s)
 *
 * In addition, some parts of the libraries exhibit different behaviour when
 * translated in different contexts, such as the value of <code><b>_WIN32_WINNT</b></code>,
 * or with <code><b>ntsecapi.h</b></code> include. In <b><i>all</i></b>
 * cases the libraries function correctly in whatever context they are compiled.
 */

/* /////////////////////////////////////////////////////////////////////////////
 * WinSTL version
 *
 * The libraries version information is comprised of major, minor and revision
 * components.
 *
 * The major version is denoted by the _WINSTL_VER_MAJOR preprocessor symbol.
 * A changes to the major version component implies that a dramatic change has
 * occurred in the libraries, such that considerable changes to source dependent
 * on previous versions would need to be effected.
 *
 * The minor version is denoted by the _WINSTL_VER_MINOR preprocessor symbol.
 * Changes to the minor version component imply that a significant change has
 * occurred to the libraries, either in the addition of new functionality or in
 * the destructive change to one or more components such that recomplilation and
 * code change may be necessitated.
 *
 * The revision version is denoted by the _WINSTL_VER_REVISIO preprocessor
 * symbol. Changes to the revision version component imply that a bug has been
 * fixed. Dependent code should be recompiled in order to pick up the changes.
 *
 * In addition to the individual version symbols - _WINSTL_VER_MAJOR,
 * _WINSTL_VER_MINOR and _WINSTL_VER_REVISION - a composite symbol _WINSTL_VER
 * is defined, where the upper 8 bits are 0, bits 16-23 represent the major
 * component,  bits 8-15 represent the minor component, and bits 0-7 represent
 * the revision component.
 *
 * Each release of the libraries will bear a different version, and that version
 * will also have its own symbol: Version 1.0.1 specifies _WINSTL_VER_1_0_1.
 *
 * Thus the symbol _WINSTL_VER may be compared meaningfully with a specific
 * version symbol, e.g. #if _WINSTL_VER >= _WINSTL_VER_1_0_1
 */

/// \def _WINSTL_VER_MAJOR
/// The major version number of WinSTL

/// \def _WINSTL_VER_MINOR
/// The minor version number of WinSTL

/// \def _WINSTL_VER_REVISION
/// The revision version number of WinSTL

/// \def _WINSTL_VER
/// The current composite version number of WinSTL

#define _WINSTL_VER_MAJOR       1
#define _WINSTL_VER_MINOR       4
#define _WINSTL_VER_REVISION    1
#define _WINSTL_VER_1_0_1       0x00010001  /*!< Version 1.0.1 */
#define _WINSTL_VER_1_0_2       0x00010002  /*!< Version 1.0.2 */
#define _WINSTL_VER_1_1_1       0x00010101  /*!< Version 1.1.1 */
#define _WINSTL_VER_1_2_1       0x00010201  /*!< Version 1.2.1 */
#define _WINSTL_VER_1_3_1       0x00010301  /*!< Version 1.3.1 */
#define _WINSTL_VER_1_3_2       0x00010302  /*!< Version 1.3.2 */
#define _WINSTL_VER_1_3_3       0x00010303  /*!< Version 1.3.3 */
#define _WINSTL_VER_1_3_4       0x00010304  /*!< Version 1.3.4 */
#define _WINSTL_VER_1_3_5       0x00010305  /*!< Version 1.3.5 */
#define _WINSTL_VER_1_3_6       0x00010306  /*!< Version 1.3.6 */
#define _WINSTL_VER_1_3_7       0x00010307  /*!< Version 1.3.7 */
#define _WINSTL_VER_1_4_1       0x00010401  /*!< Version 1.4.1 */

#define _WINSTL_VER             _WINSTL_VER_1_4_1

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

/* Strict */
#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# ifndef STRICT
#  if defined(_WINSTL_STRICT) || \
      (   !defined(_WINSTL_NO_STRICT) && \
          !defined(NO_STRICT))
#   define STRICT 1
#  endif /* !NO_STRICT && !_WINSTL_NO_STRICT */
# endif /* STRICT */
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

#ifndef _STLSOFT_INCL_H_STLSOFT
# include "stlsoft.h"   // STLSoft root header
#endif /* !_STLSOFT_INCL_H_STLSOFT */
#include <windows.h>    // Windows base header

/* /////////////////////////////////////////////////////////////////////////////
 * STLSoft version compatibility
 */

#if !defined(_STLSOFT_VER_1_5_1) || \
    _STLSOFT_VER < _STLSOFT_VER_1_5_1
# error This version of the WinSTL libraries requires STLSoft version 1.5.1 or later
#endif /* _STLSOFT_VER < _STLSOFT_VER_1_5_1 */

/* /////////////////////////////////////////////////////////////////////////////
 * Sanity checks
 *
 * Win32    -   must be compiled in context of Win32 API
 * MBCS     -   none of the libraries' code is written to support MBCS
 */

/* Must be Win32 api. */
#if !defined(WIN32) && \
    !defined(_WIN32)
# error The WinSTL libraries is currently only compatible with the Win32 API
#endif /* !WIN32 && !_WIN32 */

/* Should not be MBCS. */
#ifdef _MBCS
# ifdef _WINSTL_STRICT
#  error The WinSTL libraries are not compatible with variable length character representation schemes such as MBCS
# else
#  ifdef _STLSOFT_COMPILE_VERBOSE
#   pragma message("The WinSTL libraries are not compatible with variable length character representation schemes such as MBCS")
#  endif /* _STLSOFT_COMPILE_VERBOSE */
# endif /* _WINSTL_STRICT */
#endif /* _MBCS */

/* /////////////////////////////////////////////////////////////////////////////
 * Compiler compatibility
 *
 * Currently the only compilers supported by the WinSTL libraries are
 *
 * Borland C++ 5.5, 5.51, 5.6
 * Digital Mars C/C++ 8.26 - 8.32
 * Metrowerks 2.4 & 3.0 (CodeWarrior 7.0 & 8.0)
 * Intel C/C++ 6.0 & 7.0
 * Visual C++ 4.2, 5.0, 6.0, 7.0
 * Watcom C/C++ 11.0
 */

#if defined(__STLSOFT_COMPILER_IS_BORLAND)
/* Borland C++ */
# if __BORLANDC__ < 0x0550
#  error Versions of Borland C++ prior to 5.5 are not supported by the WinSTL libraries
# endif /* __BORLANDC__ */

#elif defined(__STLSOFT_COMPILER_IS_COMO)
/* Comeau C++ */
# if __COMO_VERSION__ < 4300
#  error Versions of Comeau C++ prior to 4.3 are not supported by the WinSTL libraries
# endif /* __COMO_VERSION__ */

#elif defined(__STLSOFT_COMPILER_IS_DMC)
/* Digital Mars C/C++ */
# if __DMC__ < 0x0826
#  error Versions of Digital Mars C/C++ prior to 8.26 are not supported by the WinSTL libraries
# endif /* __DMC__ */

#elif defined(__STLSOFT_COMPILER_IS_GCC)
/* GNU C/C++ */
# if __GNUC__ < 2 || \
     (  __GNUC__ == 2 && \
        __GNUC_MINOR__ < 95)
#  error Versions of GNU C/C++ prior to 2.95 are not supported by the WinSTL libraries
# endif /* __GNUC__ */

#elif defined(__STLSOFT_COMPILER_IS_INTEL)
/* Intel C++ */
# if (__INTEL_COMPILER < 600)
#  error Versions of Intel C++ prior to 6.0 are not supported by the WinSTL libraries
# endif /* __INTEL_COMPILER */

#elif defined(__STLSOFT_COMPILER_IS_MWERKS)
/* Metrowerks C++ */
# if (__MWERKS__ & 0xFF00) < 0x2400
#  error Versions of Metrowerks CodeWarrior C++ prior to 7.0 are not supported by the WinSTL libraries
# endif /* __MWERKS__ */

#elif defined(__STLSOFT_COMPILER_IS_MSVC)
/* Visual C++ */
# if _MSC_VER < 1020
#  error Versions of Visual C++ prior to 4.2 are not supported by the WinSTL libraries
# endif /* _MSC_VER */

#elif defined(__STLSOFT_COMPILER_IS_VECTORC)
/* VectorC C/C++ */

#elif defined(__STLSOFT_COMPILER_IS_WATCOM)
/* Watcom C/C++ */
# if (__WATCOMC__ < 1200)
#  error Versions of Watcom C/C++ prior to 12.0 are not supported by the WinSTL libraries
# endif /* __WATCOMC__ */

#else
/* No recognised compiler */
# ifdef _STLSOFT_FORCE_ANY_COMPILER
#  define _WINSTL_COMPILER_IS_UNKNOWN
#  ifdef _STLSOFT_COMPILE_VERBOSE
#   pragma message("Compiler is unknown to WinSTL")
#  endif /* _STLSOFT_COMPILE_VERBOSE */
# else
#  error Currently only Borland C++, Digital Mars C/C++, Intel C/C++, Metrowerks CodeWarrior and Visual C++ compilers are supported by the WinSTL libraries
# endif /* _STLSOFT_FORCE_ANY_COMPILER */
#endif /* compiler */

/* /////////////////////////////////////////////////////////////////////////////
 * Debugging
 *
 * The macro winstl_assert provides standard debug-mode assert functionality.
 */

/// Defines a runtime assertion
///
/// \param _x Must be non-zero, or an assertion will be fired
#define winstl_assert(_x)               stlsoft_assert(_x)

/// Defines a runtime assertion, with message
///
/// \param _x Must be non-zero, or an assertion will be fired
/// \param _m The literal character string message to be included in the assertion
#define winstl_message_assert(_m, _x)   stlsoft_message_assert(_m, _x)

/// Defines a compile-time assertion
///
/// \param _x Must be non-zero, or compilation will fail
#define winstl_static_assert(_x)        stlsoft_static_assert(_x)

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 *
 * The WinSTL components are contained within the winstl namespace. This is
 * usually an alias for stlsoft::winstl_project,
 *
 * When compilers support namespaces they are defined by default. They can be
 * undefined using a cascasing system, as follows:
 *
 * If _STLSOFT_NO_NAMESPACES is defined, then _WINSTL_NO_NAMESPACES is defined.
 *
 * If _WINSTL_NO_NAMESPACES is defined, then _WINSTL_NO_NAMESPACE is defined.
 *
 * If _WINSTL_NO_NAMESPACE is defined, then the WinSTL constructs are defined
 * in the global scope.
 *
 * If _STLSOFT_NO_NAMESPACES, _WINSTL_NO_NAMESPACES and _WINSTL_NO_NAMESPACE are
 * all undefined but the symbol _STLSOFT_NO_NAMESPACE is defined (whence the
 * namespace stlsoft does not exist), then the WinSTL constructs are defined
 * within the winstl namespace. The definition matrix is as follows:
 *
 * _STLSOFT_NO_NAMESPACE    _WINSTL_NO_NAMESPACE    winstl definition
 * ---------------------    --------------------    -----------------
 *  not defined              not defined             = stlsoft::winstl_project
 *  not defined              defined                 not defined
 *  defined                  not defined             winstl
 *  defined                  defined                 not defined
 *
 *
 *
 * The macro winstl_ns_qual() macro can be used to refer to elements in the
 * WinSTL libraries irrespective of whether they are in the
 * stlsoft::winstl_project (or winstl) namespace or in the global namespace.
 *
 * Furthermore, some compilers do not support the standard library in the std
 * namespace, so the winstl_ns_qual_std() macro can be used to refer to elements
 * in the WinSTL libraries irrespective of whether they are in the std namespace
 * or in the global namespace.
 */

/* No STLSoft namespaces means no WinSTL namespaces */
#ifdef _STLSOFT_NO_NAMESPACES
# define _WINSTL_NO_NAMESPACES
#endif /* _STLSOFT_NO_NAMESPACES */

/* No WinSTL namespaces means no winstl namespace */
#ifdef _WINSTL_NO_NAMESPACES
# define _WINSTL_NO_NAMESPACE
#endif /* _WINSTL_NO_NAMESPACES */

#ifndef _WINSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
/* There is no stlsoft namespace, so must define ::winstl */
namespace winstl
{
# else
/* Define stlsoft::winstl_project */

namespace stlsoft
{

/// The WinSTL namespace - \c winstl (aliased to \c stlsoft::winstl_project) - is
/// the namespace for the WinSTL project.
namespace winstl_project
{

# endif /* _STLSOFT_NO_NAMESPACE */
#else
stlsoft_ns_using(move_lhs_from_rhs)
#endif /* !_WINSTL_NO_NAMESPACE */

/// \def winstl_ns_qual(x)
/// Qualifies with <b>winstl::</b> if WinSTL is using namespaces or, if not, does not qualify

/// \def winstl_ns_using(x)
/// Declares a using directive (with respect to <b>winstl</b>) if WinSTL is using namespaces or, if not, does nothing

#ifndef _WINSTL_NO_NAMESPACE
# define winstl_ns_qual(x)          ::winstl::x
# define winstl_ns_using(x)         using ::winstl::x;
#else
# define winstl_ns_qual(x)          x
# define winstl_ns_using(x)
#endif /* !_WINSTL_NO_NAMESPACE */

/// \def winstl_ns_qual_std(x)
/// Qualifies with <b>std::</b> if WinSTL is being translated in the context of the standard library being within the <b>std</b> namespace or, if not, does not qualify

/// \def winstl_ns_using_std(x)
/// Declares a using directive (with respect to <b>std</b>) if WinSTL is being translated in the context of the standard library being within the <b>std</b> namespace or, if not, does nothing

#ifdef __STLSOFT_CF_std_NAMESPACE
# define winstl_ns_qual_std(x)      ::std::x
# define winstl_ns_using_std(x)     using ::std::x;
#else
# define winstl_ns_qual_std(x)      x
# define winstl_ns_using_std(x)
#endif /* !__STLSOFT_CF_std_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs
 *
 * The WinSTL uses a number of typedefs to aid in compiler-independence in the
 * libraries' main code.
 */

typedef stlsoft_ns_qual(ss_char_a_t)        ws_char_a_t;    //!< Ansi char type
typedef stlsoft_ns_qual(ss_char_w_t)        ws_char_w_t;    //!< Unicode char type
typedef stlsoft_ns_qual(ss_sint8_t)         ws_sint8_t;     //!< 8-bit signed integer
typedef stlsoft_ns_qual(ss_uint8_t)         ws_uint8_t;     //!< 8-bit unsigned integer
typedef stlsoft_ns_qual(ss_int16_t)         ws_int16_t;     //!< 16-bit integer
typedef stlsoft_ns_qual(ss_sint16_t)        ws_sint16_t;    //!< 16-bit signed integer
typedef stlsoft_ns_qual(ss_uint16_t)        ws_uint16_t;    //!< 16-bit unsigned integer
typedef stlsoft_ns_qual(ss_int32_t)         ws_int32_t;     //!< 32-bit integer
typedef stlsoft_ns_qual(ss_sint32_t)        ws_sint32_t;    //!< 32-bit signed integer
typedef stlsoft_ns_qual(ss_uint32_t)        ws_uint32_t;    //!< 32-bit unsigned integer
#ifdef __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT
 typedef stlsoft_ns_qual(ss_int64_t)        ws_int64_t;     //!< 64-bit integer
 typedef stlsoft_ns_qual(ss_sint64_t)       ws_sint64_t;    //!< 64-bit signed integer
 typedef stlsoft_ns_qual(ss_uint64_t)       ws_uint64_t;    //!< 64-bit unsigned integer
#endif /* __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT */
typedef stlsoft_ns_qual(ss_int_t)           ws_int_t;       //!< integer
typedef stlsoft_ns_qual(ss_sint_t)          ws_sint_t;      //!< signed integer
typedef stlsoft_ns_qual(ss_uint_t)          ws_uint_t;      //!< unsigned integer
typedef stlsoft_ns_qual(ss_long_t)          ws_long_t;      //!< long
typedef stlsoft_ns_qual(ss_byte_t)          ws_byte_t;      //!< Byte
typedef stlsoft_ns_qual(ss_bool_t)          ws_bool_t;      //!< bool
typedef DWORD                               ws_dword_t;     //!< dword
typedef stlsoft_ns_qual(ss_size_t)          ws_size_t;      //!< size
typedef stlsoft_ns_qual(ss_ptrdiff_t)       ws_ptrdiff_t;   //!< ptr diff
typedef stlsoft_ns_qual(ss_streampos_t)     ws_streampos_t; //!< streampos
typedef stlsoft_ns_qual(ss_streamoff_t)     ws_streamoff_t; //!< streamoff

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
/* /////////////////////////////////////////////////////////////////////////////
 * Values
 *
 * Since the boolean type may not be supported natively on all compilers, the
 * values of true and false may also not be provided. Hence the values of
 * ws_true_v and ws_false_v are defined, and are used in all code.
 */

#define ws_true_v       ss_true_v
#define ws_false_v      ss_false_v

#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */
/* /////////////////////////////////////////////////////////////////////////////
 * Code modification macros
 */

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
/* Exception signatures. */
# define winstl_throw_0()                               stlsoft_throw_0()
# define winstl_throw_1(x1)                             stlsoft_throw_1(x1)
# define winstl_throw_2(x1, x2)                         stlsoft_throw_2(x1, x2)
# define winstl_throw_3(x1, x2, x3)                     stlsoft_throw_3(x1, x2, x3)
# define winstl_throw_4(x1, x2, x3, x4)                 stlsoft_throw_4(x1, x2, x3, x4)
# define winstl_throw_5(x1, x2, x3, x4, x5)             stlsoft_throw_5(x1, x2, x3, x4, x5)
# define winstl_throw_6(x1, x2, x3, x4, x5, x6)         stlsoft_throw_6(x1, x2, x3, x4, x5, x6)
# define winstl_throw_7(x1, x2, x3, x4, x5, x6, x7)     stlsoft_throw_7(x1, x2, x3, x4, x5, x6, x7)
# define winstl_throw_8(x1, x2, x3, x4, x5, x6, x7, x8) stlsoft_throw_8(x1, x2, x3, x4, x5, x6, x7, x8)
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/// Evaluates, at compile time, to the number of elements within the given vector entity
#define winstl_num_elements(_x)                         stlsoft_num_elements(_x)

/// Destroys the given instance \c p of the given type (\c t and \c _type)
#define winstl_destroy_instance(t, _type, p)            stlsoft_destroy_instance(t, _type, p)

/// Generates an opaque type with the name \c _htype
#define winstl_gen_opaque(_htype)                       stlsoft_gen_opaque(_htype)

/// Define a 'final' class, ie. one that cannot be inherited from
#define winstl_sterile_class(_cls)                      stlsoft_sterile_class(_cls)

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _WINSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
} // namespace winstl
# else
} // namespace winstl_project
} // namespace stlsoft
namespace winstl = ::stlsoft::winstl_project;
# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_WINSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* _WINSTL_INCL_H_WINSTL */

/* ////////////////////////////////////////////////////////////////////////// */
