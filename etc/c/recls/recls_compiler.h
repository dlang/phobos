/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_compiler.h
 *
 * Purpose:     Compiler discrimination for the recls API.
 *
 * Created:     15th August 2003
 * Updated:     23rd September 2003
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


#ifndef RECLS_INCL_H_RECLS_COMPILER
#define RECLS_INCL_H_RECLS_COMPILER

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_COMPILER_MAJOR       1
# define RECLS_VER_H_RECLS_COMPILER_MINOR       0
# define RECLS_VER_H_RECLS_COMPILER_REVISION    6
# define RECLS_VER_H_RECLS_COMPILER_EDIT        6
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/** \file recls_compiler.h Compiler detection for the \ref group_recls API */

/* /////////////////////////////////////////////////////////////////////////////
 * Compiler detection
 */

#if defined(__BORLANDC__)
# define RECLS_COMPILER_IS_BORLAND
#elif defined(__DMC__)
# define RECLS_COMPILER_IS_DMC
#elif defined(__GNUC__)
# define RECLS_COMPILER_IS_GCC
#elif defined(__INTEL_COMPILER)
# define RECLS_COMPILER_IS_INTEL
#elif defined(__MWERKS__)
# define RECLS_COMPILER_IS_MWERKS
#elif defined(__WATCOMC__)
# define RECLS_COMPILER_IS_WATCOM
#elif defined(_MSC_VER)
# define RECLS_COMPILER_IS_MSVC
#else
# error Compiler not recognised
#endif /* compiler */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#if defined(RECLS_COMPILER_IS_BORLAND)
# include "recls_compiler_borland.h"
#elif defined(RECLS_COMPILER_IS_DMC)
# include "recls_compiler_dmc.h"
#elif defined(RECLS_COMPILER_IS_GCC)
# include "recls_compiler_gcc.h"
#elif defined(RECLS_COMPILER_IS_INTEL)
# include "recls_compiler_intel.h"
#elif defined(RECLS_COMPILER_IS_MWERKS)
# include "recls_compiler_mwerks.h"
#elif defined(RECLS_COMPILER_IS_WATCOM)
# include "recls_compiler_watcom.h"
#elif defined(RECLS_COMPILER_IS_MSVC)
# include "recls_compiler_msvc.h"
#else
# error Compiler not recognised. recls recognises Borland, CodeWarrior, Digital Mars, GCC, Intel, Visual C++ and Watcom.
#endif /* compiler */

/* /////////////////////////////////////////////////////////////////////////////
 * Calling convention
 */

/** \def RECLS_CALLCONV_NULL Unspecified calling convention for the \c recls API */
/** \def RECLS_CALLCONV_CDECL \c cdecl calling convention for the \c recls API */
/** \def RECLS_CALLCONV_STDDECL \c stdcall calling convention for the \c recls API */
/** \def RECLS_CALLCONV_FASTDECL \c fastcall calling convention for the \c recls API */
/** \def RECLS_CALLCONV_DEFAULT Default calling convention for the \c recls API */

#define RECLS_CALLCONV_NULL
#ifdef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_CALLCONV_CDECL
# define RECLS_CALLCONV_STDDECL
# define RECLS_CALLCONV_FASTDECL
# define RECLS_CALLCONV_DEFAULT
#elif defined(RECLS_PLATFORM_IS_WIN32)
# define RECLS_CALLCONV_CDECL               __cdecl
# define RECLS_CALLCONV_STDDECL             __stdcall
# define RECLS_CALLCONV_FASTDECL            __fastcall
# define RECLS_CALLCONV_DEFAULT             __stdcall
#elif defined(RECLS_PLATFORM_IS_WIN16)
# define RECLS_CALLCONV_CDECL               _cdecl
# define RECLS_CALLCONV_STDDECL             _pascal
# define RECLS_CALLCONV_FASTDECL            _pascal
# define RECLS_CALLCONV_DEFAULT             _pascal
#elif defined(RECLS_PLATFORM_IS_UNIX)
# define RECLS_CALLCONV_CDECL
# define RECLS_CALLCONV_STDDECL
# define RECLS_CALLCONV_FASTDECL
# define RECLS_CALLCONV_DEFAULT
#else
# error Platform not recognised
#endif /* __SYNSOFT_VAL_OS_WIN16 */

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

/** \def recls_bool_t The boolean type of the \c recls API */
typedef unsigned int        recls_bool_t;

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace typedefs
 */

#if !defined(RECLS_NO_NAMESPACE)
typedef recls_sint8_t       sint8_t;
typedef recls_uint8_t       uint8_t;

typedef recls_sint16_t      sint16_t;
typedef recls_uint16_t      uint16_t;

typedef recls_sint32_t      sint32_t;
typedef recls_uint32_t      uint32_t;

typedef recls_sint64_t      sint64_t;
typedef recls_uint64_t      uint64_t;

typedef recls_bool_t        bool_t;
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Constants and definitions
 */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !RECLS_INCL_H_RECLS_COMPILER */

/* ////////////////////////////////////////////////////////////////////////// */
