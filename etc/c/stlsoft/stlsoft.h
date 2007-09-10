/* /////////////////////////////////////////////////////////////////////////////
 * File:        stlsoft.h
 *
 * Purpose:     Root header for the STLSoft libraries. Performs various compiler
 *              and platform discriminations, and definitions of types.
 *
 * Created:     15th January 2002
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


#ifndef _STLSOFT_INCL_H_STLSOFT
#define _STLSOFT_INCL_H_STLSOFT

/* File version */
#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define _STLSOFT_VER_H_STLSOFT_MAJOR       1
# define _STLSOFT_VER_H_STLSOFT_MINOR       48
# define _STLSOFT_VER_H_STLSOFT_REVISION    2
# define _STLSOFT_VER_H_STLSOFT_EDIT        166
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/** \file stlsoft.h The root header for the \ref STLSoft project, and for all other \ref projects "projects" */

/** \weakgroup projects STLSoft Projects
 *
 * \brief The Projects that comprise the STLSoft libraries
 *
 * The STLSoft libraries are split up into sub-projects, where each sub-project only
 * depends on the STLSoft main project, which resides in the <code><b>stlsoft</b></code>
 * namespace.
 */

/** \defgroup STLSoft STLSoft
 * \ingroup projects
 *
 * \brief <img src = "stlsoft32x32.jpg">&nbsp;&nbsp;&nbsp;&nbsp;<i>... Robust, Lightweight, Cross-platform, Template Software ...</i>
 *
 * The philosophy of STLSoft is very simple: providing robust and lightweight software to the development community. The main STLSoft project, STLSoft itself (located at the site you are viewing now) provides cross-platform, technology/API-neutral classes and functions that stand on their own and are useful as independent libraries. They also support the other sub-projects (COMSTL, UNIXSTL, WinSTL, etc.) which are targeted at specific operating systems, technologies and APIs.

 * The philosophy of <a href = "http://comstl.org/">COMSTL</a> is essentially
 * the same as that of the <a href = "http://stlsoft.org/">STLSoft</a>
 * organisation: providing robust and lightweight software to the Component
 * Object Model (COM) development community.
 * <a href = "http://comstl.org/">COMSTL</a> provides template-based software
 * that builds on that provided by COM and
 * <a href = "http://stlsoft.org/">STLSoft</a> in order to reduce programmer
 * effort and increase robustness in the use of the COM. 
 *
 * <b>Namespaces</b>
 *
 * The <a href = "http://comstl.org/">COMSTL</a> namespace <code><b>comstl</b></code>
 * is actually an alias for the namespace <code><b>stlsoft::comstl_project</b></code>,
 * and as such all the COMSTL project components actually reside within the
 * <code><b>stlsoft</b></code> namespace
 *
 * <b>Dependencies</b>
 *
 * As with <b><i>all</i></b> parts of the STLSoft libraries, there are no
 * dependencies on <a href = "http://comstl.org/">COMSTL</a> binary components
 * and no need to compile <a href = "http://comstl.org/">COMSTL</a> implementation
 * files; <a href = "http://comstl.org/">COMSTL</a> is <b>100%</b> header-only!
 *
 * As with most of the <a href = "http://stlsoft.org/">STLSoft</a> sub-projects,
 * <a href = "http://comstl.org/">COMSTL</a> depends only on
 *
 * - Selected headers from the C standard library, such as  <code><b>wchar.h</b></code>
 * - Selected headers from the C++ standard library, such as <code><b>new</b></code>, <code><b>functional</b></code>
 * - Selected header files of the <a href = "http://stlsoft.org/">STLSoft</a> main project
 * - The header files particular to the technology area, in this case the COM library headers, such as <code><b>objbase.h</b></code>
 * - The binary (static and dynamic libraries) components particular to the technology area, in this case the COM libraries that ship with the operating system and your compiler(s)
 *
 * In addition, some parts of the libraries exhibit different behaviour when
 * translated in different contexts, such as with <code><b>_WIN32_DCOM</b></code>
 * defined, or with <code><b>iaccess.h</b></code> include. In <b><i>all</i></b>
 * cases the libraries function correctly in whatever context they are compiled.
 */

/* /////////////////////////////////////////////////////////////////////////////
 * STLSoft version
 *
 * The libraries version information is comprised of major, minor and revision
 * components.
 *
 * The major version is denoted by the _STLSOFT_VER_MAJOR preprocessor symbol.
 * A changes to the major version component implies that a dramatic change has
 * occured in the libraries, such that considerable changes to source dependent
 * on previous versions would need to be effected.
 *
 * The minor version is denoted by the _STLSOFT_VER_MINOR preprocessor symbol.
 * Changes to the minor version component imply that a significant change has
 * occured to the libraries, either in the addition of new functionality or in
 * the destructive change to one or more components such that recomplilation and
 * code change may be necessitated.
 *
 * The revision version is denoted by the _STLSOFT_VER_REVISIO preprocessor
 * symbol. Changes to the revision version component imply that a bug has been
 * fixed. Dependent code should be recompiled in order to pick up the changes.
 *
 * In addition to the individual version symbols - _STLSOFT_VER_MAJOR,
 * _STLSOFT_VER_MINOR and _STLSOFT_VER_REVISION - a composite symbol _STLSOFT_VER
 * is defined, where the upper 8 bits are 0, bits 16-23 represent the major
 * component,  bits 8-15 represent the minor component, and bits 0-7 represent
 * the revision component.
 *
 * Each release of the libraries will bear a different version, and that version
 * will also have its own symbol: Version 1.0.1 specifies _STLSOFT_VER_1_0_1.
 *
 * Thus the symbol _STLSOFT_VER may be compared meaningfully with a specific
 * version symbol, e.g.# if _STLSOFT_VER >= _STLSOFT_VER_1_0_1
 */

/// \def _STLSOFT_VER_MAJOR
/// The major version number of STLSoft

/// \def _STLSOFT_VER_MINOR
/// The minor version number of STLSoft

/// \def _STLSOFT_VER_REVISION
/// The revision version number of STLSoft

/// \def _STLSOFT_VER
/// The current composite version number of STLSoft

#define _STLSOFT_VER_MAJOR      1
#define _STLSOFT_VER_MINOR      6
#define _STLSOFT_VER_REVISION   6
#define _STLSOFT_VER_1_0_1      0x00010001  /*!< Version 1.0.1 */
#define _STLSOFT_VER_1_0_2      0x00010002  /*!< Version 1.0.2 */
#define _STLSOFT_VER_1_1_1      0x00010101  /*!< Version 1.1.1 */
#define _STLSOFT_VER_1_1_2      0x00010102  /*!< Version 1.1.2 */
#define _STLSOFT_VER_1_1_3      0x00010103  /*!< Version 1.1.3 */
#define _STLSOFT_VER_1_2_1      0x00010201  /*!< Version 1.2.1 */
#define _STLSOFT_VER_1_3_1      0x00010301  /*!< Version 1.3.1 */
#define _STLSOFT_VER_1_3_2      0x00010302  /*!< Version 1.3.2 */
#define _STLSOFT_VER_1_4_1      0x00010401  /*!< Version 1.4.1 */
#define _STLSOFT_VER_1_4_2      0x00010402  /*!< Version 1.4.2 */
#define _STLSOFT_VER_1_4_3      0x00010403  /*!< Version 1.4.3 */
#define _STLSOFT_VER_1_4_4      0x00010404  /*!< Version 1.4.4 */
#define _STLSOFT_VER_1_4_5      0x00010405  /*!< Version 1.4.5 */
#define _STLSOFT_VER_1_4_6      0x00010406  /*!< Version 1.4.6 */
#define _STLSOFT_VER_1_5_1      0x00010501  /*!< Version 1.5.1 */
#define _STLSOFT_VER_1_5_2      0x00010502  /*!< Version 1.5.2 */
#define _STLSOFT_VER_1_6_1      0x00010601  /*!< Version 1.6.1 */
#define _STLSOFT_VER_1_6_2      0x00010602  /*!< Version 1.6.2 */
#define _STLSOFT_VER_1_6_3      0x00010603  /*!< Version 1.6.3 */
#define _STLSOFT_VER_1_6_4      0x00010604  /*!< Version 1.6.4 */
#define _STLSOFT_VER_1_6_5      0x00010605  /*!< Version 1.6.5 */
#define _STLSOFT_VER_1_6_6      0x00010606  /*!< Version 1.6.6 */

#define _STLSOFT_VER            _STLSOFT_VER_1_6_6

/* /////////////////////////////////////////////////////////////////////////////
 * Basic macros
 */

/* Compilation messages
 *
 * To see certain informational messages during compilation define the
 * preprocessor symbol _STLSOFT_COMPILE_VERBOSE
 */

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define STLSOFT_STRINGIZE_(x)      #x
# define STLSOFT_STRINGIZE(x)       STLSOFT_STRINGIZE_(x)
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* Simple macro indirection
 */

#define STLSOFT_MACRO_INDIRECT(x)   x

/* /////////////////////////////////////////////////////////////////////////////
 * Sanity checks - 1
 *
 * C++      -   must be C++ compilation unit
 */

/* Must be C++. */
#ifndef __cplusplus
# error The STLSoft libraries are only compatible with C++ compilation units
#endif /* __cplusplus */

/* /////////////////////////////////////////////////////////////////////////////
 * Compiler compatibility
 *
 * Currently the only compilers supported by the STLSoft libraries are
 *
 * Borland C++ 5.5, 5.51 & 5.6
 * Comeau 4.3.1
 * Digital Mars C/C++ 8.26 and above
 * GCC 2.95, 2.96 & 3.2
 * Intel C/C++ 6.0 & 7.0
 * Metrowerks 2.4 & 3.0 (CodeWarrior 7.0 & 8.0)
 * Visual C++ 4.2, 5.0, 6.0 & .NET
 * Watcom C/C++ 11.0
 *
 * The following compilers are intended to be supported in a future release:
 *
 * Comeau C++
 */

#ifdef __STLSOFT_COMPILER_IS_UNKNOWN
# undef __STLSOFT_COMPILER_IS_UNKNOWN
#endif /* __STLSOFT_COMPILER_IS_UNKNOWN */

#ifdef __STLSOFT_COMPILER_IS_BORLAND
# undef __STLSOFT_COMPILER_IS_BORLAND
#endif /* __STLSOFT_COMPILER_IS_BORLAND */

#ifdef __STLSOFT_COMPILER_IS_COMO
# undef __STLSOFT_COMPILER_IS_COMO
#endif /* __STLSOFT_COMPILER_IS_COMO */

#ifdef __STLSOFT_COMPILER_IS_DMC
# undef __STLSOFT_COMPILER_IS_DMC
#endif /* __STLSOFT_COMPILER_IS_DMC */

#ifdef __STLSOFT_COMPILER_IS_GCC
# undef __STLSOFT_COMPILER_IS_GCC
#endif /* __STLSOFT_COMPILER_IS_GCC */

#ifdef __STLSOFT_COMPILER_IS_INTEL
# undef __STLSOFT_COMPILER_IS_INTEL
#endif /* __STLSOFT_COMPILER_IS_INTEL */

#ifdef __STLSOFT_COMPILER_IS_MSVC
# undef __STLSOFT_COMPILER_IS_MSVC
#endif /* __STLSOFT_COMPILER_IS_MSVC */

#ifdef __STLSOFT_COMPILER_IS_MWERKS
# undef __STLSOFT_COMPILER_IS_MWERKS
#endif /* __STLSOFT_COMPILER_IS_MWERKS */

#ifdef __STLSOFT_COMPILER_IS_VECTORC
# undef __STLSOFT_COMPILER_IS_VECTORC
#endif /* __STLSOFT_COMPILER_IS_VECTORC */

#ifdef __STLSOFT_COMPILER_IS_WATCOM
# undef __STLSOFT_COMPILER_IS_WATCOM
#endif /* __STLSOFT_COMPILER_IS_WATCOM */

/* First we do a check to see whether other compilers are providing
 * compatibility with Visual C++, and handle that.
 */

#ifdef _MSC_VER
# if defined(__BORLANDC__) ||      /* Borland C/C++ */ \
     defined(__COMO__) ||          /* Comeau C/C++ */ \
     defined(__DMC__) ||           /* Digital Mars C/C++ */ \
     defined(__GNUC__) ||          /* GNU C/C++ */ \
     defined(__INTEL_COMPILER) ||  /* Intel C/C++ */ \
     defined(__MWERKS__) ||        /* Metrowerks C/C++ */ \
     defined(__WATCOMC__)          /* Watcom C/C++ */
  /* Handle Microsoft Visual C++ support. */
#  if defined(_STLSOFT_NO_MSC_VER_SUPPORT) || \
     (   defined(_STLSOFT_STRICT) && \
         !defined(_STLSOFT_MSC_VER_SUPPORT))
#   undef _MSC_VER
#  endif /* _STLSOFT_NO_MSC_VER_SUPPORT || (_STLSOFT_STRICT && _STLSOFT_MSC_VER_SUPPORT) */
# endif /* compiler */
#endif /* _MSC_VER */

#if defined(_STLSOFT_FORCE_CUSTOM_COMPILER)
# define __STLSOFT_COMPILER_LABEL_STRING        "Custom (forced) compiler"
# define __STLSOFT_COMPILER_VERSION_STRING      "Custom (forced) compiler"
# define __STLSOFT_COMPILER_IS_CUSTOM
# ifndef __STLSOFT_CF_CUSTOM_COMPILER_INCLUDE_NAME
#  error When using the custom compiler option you must define the symbol __STLSOFT_CF_CUSTOM_COMPILER_INCLUDE_NAME, e.g. #define __STLSOFT_CF_CUSTOM_COMPILER_INCLUDE_NAME <stlsoft_cccap_my_compiler.h>
# endif /* !__STLSOFT_CF_CUSTOM_COMPILER_INCLUDE_NAME */

#elif defined(__COMO__) /* Do Comeau next, so that no Comeau back-end server compilers are preferentially discriminated */
/* Comeau C++ */
# define __STLSOFT_COMPILER_IS_COMO
# define __STLSOFT_COMPILER_LABEL_STRING        "Comeau C++"
# if __COMO_VERSION__ < 4300
#  error Only versions 4.3.0.1 and later of Comeau C++ compiler is supported by the STLSoft libraries
# elif (__COMO_VERSION__ == 4300)
#  define __STLSOFT_COMPILER_VERSION_STRING "Comeau C++ 4.3.0.1"
# else
#  define __STLSOFT_COMPILER_VERSION_STRING "Unknown version of Comeau C++"
# endif /* __COMO_VERSION__ */

#elif defined(__BORLANDC__)
/* Borland C++ */
# define __STLSOFT_COMPILER_IS_BORLAND
# define __STLSOFT_COMPILER_LABEL_STRING        "Borland C/C++"
# if 0 /* (__BORLANDC__ == 0x0460) */
#  define __STLSOFT_COMPILER_VERSION_STRING     "Borland C++ 4.52"
# elif (__BORLANDC__ == 0x0550)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Borland C++ 5.5"
# elif (__BORLANDC__ == 0x0551)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Borland C++ 5.51"
# elif (__BORLANDC__ == 0x0560)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Borland C++ 5.6"
# elif (__BORLANDC__ == 0x0564)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Borland C++ 5.64 (C++ BuilderX)"
# else
  /*# error Currently only versions 4.52, 5.5, 5.51 and 5.6 of the Borland C++ compiler are supported by the STLSoft libraries */
#  error Currently only versions 5.5, 5.51 and 5.6 of the Borland C++ compiler are supported by the STLSoft libraries
# endif /* __BORLANDC__ */

#elif defined(__DMC__)
/* Digital Mars C/C++ */
# define __STLSOFT_COMPILER_IS_DMC
# define __STLSOFT_COMPILER_LABEL_STRING        "Digital Mars C/C++"
# if (__DMC__ < 0x0826)
#  error Only versions 8.26 and later of the Digital Mars C/C++ compilers are supported by the STLSoft libraries
# else
#  if __DMC__ >= 0x0832
#   define __STLSOFT_COMPILER_VERSION_STRING    __DMC_VERSION_STRING__
#  elif (__DMC__ == 0x0826)
#   define __STLSOFT_COMPILER_VERSION_STRING    "Digital Mars C/C++ 8.26"
#  elif (__DMC__ == 0x0827)
#   define __STLSOFT_COMPILER_VERSION_STRING    "Digital Mars C/C++ 8.27"
#  elif (__DMC__ == 0x0828)
#   define __STLSOFT_COMPILER_VERSION_STRING    "Digital Mars C/C++ 8.28"
#  elif (__DMC__ == 0x0829)
#   define __STLSOFT_COMPILER_VERSION_STRING    "Digital Mars C/C++ 8.29"
#  elif (__DMC__ == 0x0830)
#   define __STLSOFT_COMPILER_VERSION_STRING    "Digital Mars C/C++ 8.30"
#  elif (__DMC__ == 0x0831)
#   define __STLSOFT_COMPILER_VERSION_STRING    "Digital Mars C/C++ 8.31"
#  endif /* __DMC__ */
# endif /* version */

#elif defined(__GNUC__)
/* GNU C/C++ */
# define __STLSOFT_COMPILER_IS_GCC
# define __STLSOFT_COMPILER_LABEL_STRING        "GNU C/C++"
# if __GNUC__ != 2 && \
     __GNUC__ != 3 && \
     __GNUC__ != 4
#  error GNU C/C++ compilers whose major version is not 2 or 3 are not currently supported by the STLSoft libraries
# elif __GNUC__ == 2
#  if __GNUC_MINOR__ < 95
#   error Currently only version 2.95 and above of the GNU C/C++ compiler is supported by the STLSoft libraries
#  elif __GNUC_MINOR__ == 95
#   define __STLSOFT_COMPILER_VERSION_STRING    "GNU C/C++ 2.95"
#  elif __GNUC_MINOR__ == 96
#   define __STLSOFT_COMPILER_VERSION_STRING    "GNU C/C++ 2.96"
#  else
#   define __STLSOFT_COMPILER_VERSION_STRING    "GNU C/C++ >2.96 - you should be aware that this version may not be supported correctly"
#  endif /* __GNUC__ != 2 */
# elif __GNUC__ == 3
#  if __GNUC_MINOR__ == 2
#   define __STLSOFT_COMPILER_VERSION_STRING    "GNU C/C++ 3.2"
#  else
#   define __STLSOFT_COMPILER_VERSION_STRING    "GNU C/C++ >3.2 - you should be aware that this version may not be supported correctly"
#  endif /* __GNUC__ != 2 */
# elif __GNUC__ == 4
#  define __STLSOFT_COMPILER_VERSION_STRING    "GNU C/C++ >= 4.0 - you should be aware that this version may not be supported correctly"
# endif /* __GNUC__ */

#elif defined(__INTEL_COMPILER)
/* Intel C++ */
# define __STLSOFT_COMPILER_IS_INTEL
# define __STLSOFT_COMPILER_LABEL_STRING        "Intel C/C++"
# if (__INTEL_COMPILER == 600)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Intel C/C++ 6.0"
# elif (__INTEL_COMPILER == 700)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Intel C/C++ 7.0"
# else
#  error Only Intel C++ Compiler versions 6.0 and 7.0 currently supported by the STLSoft libraries
# endif /* __INTEL_COMPILER */

#elif defined(__MWERKS__)
/* Metrowerks C++ */
# define __STLSOFT_COMPILER_IS_MWERKS
# define __STLSOFT_COMPILER_LABEL_STRING        "Metrowerks CodeWarrior C/C++"
# if ((__MWERKS__ & 0xFF00) == 0x2400)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Metrowerks CodeWarrior C++ 2.4"
# elif ((__MWERKS__ & 0xFF00) == 0x3000)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Metrowerks CodeWarrior C++ 3.0"
# else
#  error Only Metrowerks C++ Compiler 2.4 (CodeWarrior 7) and 3.0 (CodeWarrior 8) currently supported by the STLSoft libraries
# endif /* __MWERKS__ */

#elif defined(__VECTORC)
/* CodePlay Vector C/C++ */
# define __STLSOFT_COMPILER_IS_VECTORC
# define __STLSOFT_COMPILER_LABEL_STRING        "CodePlay VectorC C/C++"
# if (__VECTORC == 1)
#  define __STLSOFT_COMPILER_VERSION_STRING     "CodePlay VectorC C/C++"
# else
#  error Currently only versions of the CodePlay Vector C/C++ compiler defining __VECTORC == 1 are supported by the STLSoft libraries
# endif /* __VECTORC */

#elif defined(__WATCOMC__)
/* Watcom C/C++ */
# define __STLSOFT_COMPILER_IS_WATCOM
# define __STLSOFT_COMPILER_LABEL_STRING        "Watcom C/C++"

# if (__WATCOMC__ == 1100)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Watcom C/C++ 11.0"
# elif (__WATCOMC__ == 1200)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Open Watcom C/C++ 1.0 (Watcom 12.0)"
# else
#  error Currently only versions 11.0 and 12.0 of the Watcom C/C++ compiler is supported by the STLSoft libraries
# endif /* __WATCOMC__ */

#elif defined(_MSC_VER)
/* Visual C++ */
# define __STLSOFT_COMPILER_IS_MSVC
# define __STLSOFT_COMPILER_LABEL_STRING        "Visual C++"

# if (_MSC_VER == 1020)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Visual C++ 4.2"
# elif (_MSC_VER == 1100)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Visual C++ 5.0"
# elif (_MSC_VER == 1200)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Visual C++ 6.0"
# elif (_MSC_VER == 1300)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Visual C++ .NET (7.0)"
# elif (_MSC_VER == 1310)
#  define __STLSOFT_COMPILER_VERSION_STRING     "Visual C++ .NET (7.1)"
# else
#  error Currently only versions 4.2, 5.0, 6.0, 7.0 & 7.1 of the Visual C++ compiler are supported by the STLSoft libraries
# endif /* _MSC_VER */

#else
/* No recognised compiler */
# if defined(_STLSOFT_FORCE_UNKNOWN_COMPILER) || \
     defined(_STLSOFT_FORCE_ANY_COMPILER)
#  define __STLSOFT_COMPILER_LABEL_STRING       "Unknown (forced) compiler"
#  define __STLSOFT_COMPILER_VERSION_STRING     "Unknown (forced) compiler"
#  define __STLSOFT_COMPILER_IS_UNKNOWN
# else
#  error Compiler is not recognised.
#  error Currently only Borland C++, Comeau C++, Digital Mars C/C++, GNU C/C++,
#  error  Intel C/C++, Metrowerks CodeWarrior, Visual C++ and Watcom C/C++
#  error  compilers are supported by the STLSoft libraries
#  error If you want to use the libraries with your compiler, you may specify the
#  error  _STLSOFT_FORCE_CUSTOM_COMPILER or _STLSOFT_FORCE_ANY_COMPILER pre-processor
#  error  symbols.
#  error _STLSOFT_FORCE_ANY_COMPILER assumes that your compiler can support all
#  error  modern C++ compiler features, and causes the inclusion of the compiler
#  error  features file stlsoft_cccap_unknown.h, which is provided by STLSoft.
#  error _STLSOFT_FORCE_CUSTOM_COMPILER requires that you specify the name of the
#  error  compiler features file in __STLSOFT_CF_CUSTOM_COMPILER_INCLUDE_NAME.
#  error The idea is to use _STLSOFT_FORCE_ANY_COMPILER, to determine what language
#  error  features your compiler can support, and then copy, edit and use that file
#  error  via _STLSOFT_FORCE_CUSTOM_COMPILER and __STLSOFT_CF_CUSTOM_COMPILER_INCLUDE_NAME.
# endif /* _STLSOFT_FORCE_ANY_COMPILER */

#endif /* compiler tag */

/* /////////////////////////////////////////////////////////////////////////////
 * Compiler language feature support
 *
 * Various compilers support the language differently (or not at all), so these
 * features are discriminated here and utilised by various means within the code
 * in order to minimise the use of the preprocessor conditionals in the other
 * libraries' source code.
 */

/* Template support.
 *
 * Discriminated symbol is __STLSOFT_CF_TEMPLATE_SUPPORT
 */

#ifdef __STLSOFT_CF_TEMPLATE_SUPPORT
# undef __STLSOFT_CF_TEMPLATE_SUPPORT
#endif /* __STLSOFT_CF_TEMPLATE_SUPPORT */

/* Exception signature support.
 *
 * Discriminated symbol is __STLSOFT_CF_EXCEPTION_SIGNATURE_SUPPORT
 */
#ifdef __STLSOFT_CF_EXCEPTION_SIGNATURE_SUPPORT
# undef __STLSOFT_CF_EXCEPTION_SIGNATURE_SUPPORT
#endif /* __STLSOFT_CF_EXCEPTION_SIGNATURE_SUPPORT */

/* Native bool support.
 *
 * Discriminated symbol is __STLSOFT_CF_NATIVE_BOOL_SUPPORT
 */
#ifdef __STLSOFT_CF_NATIVE_BOOL_SUPPORT
# undef __STLSOFT_CF_NATIVE_BOOL_SUPPORT
#endif /* __STLSOFT_CF_NATIVE_BOOL_SUPPORT */

/* Native / typedef'd wchar_t support.
 *
 * Discriminated symbols are __STLSOFT_CF_NATIVE_WCHAR_T_SUPPORT
 *                           __STLSOFT_CF_TYPEDEF_WCHAR_T_SUPPORT
 *
 * Implementation symbol is __STLSOFT_NATIVE_WCHAR_T
 */
#ifdef __STLSOFT_CF_NATIVE_WCHAR_T_SUPPORT
# undef __STLSOFT_CF_NATIVE_WCHAR_T_SUPPORT
#endif /* __STLSOFT_CF_NATIVE_WCHAR_T_SUPPORT */

#ifdef __STLSOFT_CF_TYPEDEF_WCHAR_T_SUPPORT
# undef __STLSOFT_CF_TYPEDEF_WCHAR_T_SUPPORT
#endif /* __STLSOFT_CF_TYPEDEF_WCHAR_T_SUPPORT */

#ifdef __STLSOFT_NATIVE_WCHAR_T
# undef __STLSOFT_NATIVE_WCHAR_T
#endif /* __STLSOFT_NATIVE_WCHAR_T */

/* 8-bit, 16-bit, 32-bit type support
 *
 * Discriminated symbol is __STLSOFT_CF_NATIVE_8BIT_INT_SUPPORT,
 *                         __STLSOFT_CF_NATIVE_16BIT_INT_SUPPORT,
 *                         __STLSOFT_CF_NATIVE_32BIT_INT_SUPPORT
 *
 * Implementation symbol are __STLSOFT_NATIVE_INT8_T,
 *                           __STLSOFT_NATIVE_SINT8_T,
 *                           __STLSOFT_NATIVE_UINT8_T,
 *                           __STLSOFT_NATIVE_INT16_T,
 *                           __STLSOFT_NATIVE_SINT16_T,
 *                           __STLSOFT_NATIVE_UINT16_T,
 *                           __STLSOFT_NATIVE_INT32_T,
 *                           __STLSOFT_NATIVE_SINT32_T,
 *                           __STLSOFT_NATIVE_UINT32_T
 */

#ifdef __STLSOFT_CF_NATIVE_8BIT_INT_SUPPORT
# undef __STLSOFT_CF_NATIVE_8BIT_INT_SUPPORT
#endif /* __STLSOFT_CF_NATIVE_8BIT_INT_SUPPORT */

#ifdef __STLSOFT_CF_NATIVE_16BIT_INT_SUPPORT
# undef __STLSOFT_CF_NATIVE_16BIT_INT_SUPPORT
#endif /* __STLSOFT_CF_NATIVE_16BIT_INT_SUPPORT */

#ifdef __STLSOFT_CF_NATIVE_32BIT_INT_SUPPORT
# undef __STLSOFT_CF_NATIVE_32BIT_INT_SUPPORT
#endif /* __STLSOFT_CF_NATIVE_32BIT_INT_SUPPORT */

#ifdef __STLSOFT_NATIVE_INT8_T
# undef __STLSOFT_NATIVE_INT8_T
#endif /* __STLSOFT_NATIVE_INT8_T */
#ifdef __STLSOFT_NATIVE_SINT8_T
# undef __STLSOFT_NATIVE_SINT8_T
#endif /* __STLSOFT_NATIVE_SINT8_T */
#ifdef __STLSOFT_NATIVE_UINT8_T
# undef __STLSOFT_NATIVE_UINT8_T
#endif /* __STLSOFT_NATIVE_UINT8_T */

#ifdef __STLSOFT_NATIVE_INT16_T
# undef __STLSOFT_NATIVE_INT16_T
#endif /* __STLSOFT_NATIVE_INT16_T */
#ifdef __STLSOFT_NATIVE_SINT16_T
# undef __STLSOFT_NATIVE_SINT16_T
#endif /* __STLSOFT_NATIVE_SINT16_T */
#ifdef __STLSOFT_NATIVE_UINT16_T
# undef __STLSOFT_NATIVE_UINT16_T
#endif /* __STLSOFT_NATIVE_UINT16_T */

#ifdef __STLSOFT_NATIVE_INT32_T
# undef __STLSOFT_NATIVE_INT32_T
#endif /* __STLSOFT_NATIVE_INT32_T */
#ifdef __STLSOFT_NATIVE_SINT32_T
# undef __STLSOFT_NATIVE_SINT32_T
#endif /* __STLSOFT_NATIVE_SINT32_T */
#ifdef __STLSOFT_NATIVE_UINT32_T
# undef __STLSOFT_NATIVE_UINT32_T
#endif /* __STLSOFT_NATIVE_UINT32_T */

/* 64-bit support.
 *
 * Discriminated symbols are __STLSOFT_CF_NATIVE___int64_SUPPORT,
 * __STLSOFT_CF_NATIVE_LONG_LONG_SUPPORT and
 * __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT.
 *
 * 64-bit support is discriminated in the following two forms:
 *
 * (i) long long
 * (ii) __int64
 *
 * Form (i) support is selectively preferred. Form (ii) support
 * is only discriminated in the absence of form (i).
 */

#ifdef __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT
# undef __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT
#endif /* __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT */

#ifdef __STLSOFT_CF_NATIVE_LONG_LONG_SUPPORT
# undef __STLSOFT_CF_NATIVE_LONG_LONG_SUPPORT
#endif /* __STLSOFT_CF_NATIVE_LONG_LONG_SUPPORT */

#ifdef __STLSOFT_CF_NATIVE___int64_SUPPORT
# undef __STLSOFT_CF_NATIVE___int64_SUPPORT
#endif /* __STLSOFT_CF_NATIVE___int64_SUPPORT */

#ifdef __STLSOFT_CF_INT_DISTINCT_TYPE
# undef __STLSOFT_CF_INT_DISTINCT_TYPE
#endif /* __STLSOFT_CF_INT_DISTINCT_TYPE */

/* Compiler supports static assert.
 *
 * Discriminated symbol is __STLSOFT_CF_STATIC_ASSERT_SUPPORT
 */
#ifdef __STLSOFT_CF_STATIC_ASSERT_SUPPORT
# undef __STLSOFT_CF_STATIC_ASSERT_SUPPORT
#endif /* __STLSOFT_CF_STATIC_ASSERT_SUPPORT */

/* Function signature requires full-qualification.
 *
 * Discriminated symbol is __STLSOFT_CF_FUNCTION_SIGNATURE_FULL_ARG_QUALIFICATION_REQUIRED
 */
#ifdef __STLSOFT_CF_FUNCTION_SIGNATURE_FULL_ARG_QUALIFICATION_REQUIRED
# undef __STLSOFT_CF_FUNCTION_SIGNATURE_FULL_ARG_QUALIFICATION_REQUIRED
#endif /* __STLSOFT_CF_FUNCTION_SIGNATURE_FULL_ARG_QUALIFICATION_REQUIRED */

/* Exception support.
 *
 * Discriminated symbol is __STLSOFT_CF_EXCEPTION_SUPPORT
 */
#ifdef __STLSOFT_CF_EXCEPTION_SUPPORT
# undef __STLSOFT_CF_EXCEPTION_SUPPORT
#endif /* __STLSOFT_CF_EXCEPTION_SUPPORT */

/* Template class default fundamental type argument support
 *
 * Discriminated symbol is __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_FUNDAMENTAL_ARGUMENT_SUPPORT
 *
 * Microsoft Visual C++ 4.2 does not support template default fundamental type arguments.
 */
#ifdef __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_FUNDAMENTAL_ARGUMENT_SUPPORT
# undef __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_FUNDAMENTAL_ARGUMENT_SUPPORT
#endif /* __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_FUNDAMENTAL_ARGUMENT_SUPPORT */

/* Template class default class type argument support
 *
 * Discriminated symbol is __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT
 *
 * Microsoft Visual C++ 4.2 does not support template default class type arguments.
 */
#ifdef __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT
# undef __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT
#endif /* __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT */

/* Member functions can appear as template parameters
 *
 * Discriminated symbol is STLSOFT_CF_MEM_FUNC_AS_TEMPLATE_PARAM_SUPPORT
 */
#ifdef STLSOFT_CF_MEM_FUNC_AS_TEMPLATE_PARAM_SUPPORT
# undef STLSOFT_CF_MEM_FUNC_AS_TEMPLATE_PARAM_SUPPORT
#endif /* STLSOFT_CF_MEM_FUNC_AS_TEMPLATE_PARAM_SUPPORT */

/* Member template function support.
 *
 * Discriminated symbol is __STLSOFT_CF_MEMBER_TEMPLATE_FUNCTION_SUPPORT
 */
#ifdef __STLSOFT_CF_MEMBER_TEMPLATE_FUNCTION_SUPPORT
# undef __STLSOFT_CF_MEMBER_TEMPLATE_FUNCTION_SUPPORT
#endif // __STLSOFT_CF_MEMBER_TEMPLATE_FUNCTION_SUPPORT

/* Member template constructor support.
 *
 * Discriminated symbol is __STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT
 */
#ifdef __STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT
# undef __STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT
#endif // __STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT

/* Member template range method support.
 *
 * Discriminated symbol is __STLSOFT_CF_MEMBER_TEMPLATE_RANGE_METHOD_SUPPORT
 */
#ifdef __STLSOFT_CF_MEMBER_TEMPLATE_RANGE_METHOD_SUPPORT
# undef __STLSOFT_CF_MEMBER_TEMPLATE_RANGE_METHOD_SUPPORT
#endif // __STLSOFT_CF_MEMBER_TEMPLATE_RANGE_METHOD_SUPPORT

/* Member template class support.
 *
 * Discriminated symbol is __STLSOFT_CF_MEMBER_TEMPLATE_CLASS_SUPPORT
 */
#ifdef __STLSOFT_CF_MEMBER_TEMPLATE_CLASS_SUPPORT
# undef __STLSOFT_CF_MEMBER_TEMPLATE_CLASS_SUPPORT
#endif // __STLSOFT_CF_MEMBER_TEMPLATE_CLASS_SUPPORT

/* Template specialisation syntax support
 *
 * Discriminated symbol is __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX
 */
#ifdef __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX
# undef __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX
#endif /* __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX */

/* Template partial specialisation support.
 *
 * Discriminated symbol is __STLSOFT_CF_TEMPLATE_PARTIAL_SPECIALISATION_SUPPORT
 */
#ifdef __STLSOFT_CF_TEMPLATE_PARTIAL_SPECIALISATION_SUPPORT
# undef __STLSOFT_CF_TEMPLATE_PARTIAL_SPECIALISATION_SUPPORT
#endif // __STLSOFT_CF_TEMPLATE_PARTIAL_SPECIALISATION_SUPPORT

/* Template out-of-class function specialisation support.
 *
 * Discriminated symbol is __STLSOFT_CF_TEMPLATE_OUTOFCLASSFN_QUALIFIED_TYPE_SUPPORT
 */
#ifdef __STLSOFT_CF_TEMPLATE_OUTOFCLASSFN_QUALIFIED_TYPE_SUPPORT
# undef __STLSOFT_CF_TEMPLATE_OUTOFCLASSFN_QUALIFIED_TYPE_SUPPORT
#endif /* __STLSOFT_CF_TEMPLATE_OUTOFCLASSFN_QUALIFIED_TYPE_SUPPORT */

/* Standard library STL elements in std namespace.
 *
 * Discriminated symbol is __STLSOFT_CF_std_NAMESPACE
 */
#ifdef __STLSOFT_CF_std_NAMESPACE
# undef __STLSOFT_CF_std_NAMESPACE
#endif /* __STLSOFT_CF_std_NAMESPACE */

/* std::char_traits available.
 *
 * Discriminated symbol is __STLSOFT_CF_std_char_traits_AVAILABLE
 */
#ifdef __STLSOFT_CF_std_char_traits_AVAILABLE
# undef __STLSOFT_CF_std_char_traits_AVAILABLE
#endif /* __STLSOFT_CF_std_char_traits_AVAILABLE */

/* stl-like allocator classes provide allocate() hint argument
 *
 * Discriminated symbol is __STLSOFT_CF_ALLOCATOR_ALLOCATE_HAS_HINT
 *
 * Note: this should be resolving on the library, not the compiler
 */
#ifdef __STLSOFT_CF_ALLOCATOR_ALLOCATE_HAS_HINT
# undef __STLSOFT_CF_ALLOCATOR_ALLOCATE_HAS_HINT
#endif /* __STLSOFT_CF_ALLOCATOR_ALLOCATE_HAS_HINT */

/* stl-like allocator classes provide deallocate() object count argument
 *
 * Discriminated symbol is __STLSOFT_CF_ALLOCATOR_DEALLOCATE_HAS_OBJECTCOUNT
 *
 * Note: this should be resolving on the library, not the compiler
 */
#ifdef __STLSOFT_CF_ALLOCATOR_DEALLOCATE_HAS_OBJECTCOUNT
# undef __STLSOFT_CF_ALLOCATOR_DEALLOCATE_HAS_OBJECTCOUNT
#endif /* __STLSOFT_CF_ALLOCATOR_DEALLOCATE_HAS_OBJECTCOUNT */

/* Bidirectional iterator support
 */
#ifdef __STLSOFT_CF_BIDIRECTIONAL_ITERATOR_SUPPORT
# undef __STLSOFT_CF_BIDIRECTIONAL_ITERATOR_SUPPORT
#endif /* __STLSOFT_CF_BIDIRECTIONAL_ITERATOR_SUPPORT */

/* explicit keyword support
 *
 * Discriminated symbol is __STLSOFT_CF_EXPLICIT_KEYWORD_SUPPORT
 */
#ifdef __STLSOFT_CF_EXPLICIT_KEYWORD_SUPPORT
# undef __STLSOFT_CF_EXPLICIT_KEYWORD_SUPPORT
#endif /* __STLSOFT_CF_EXPLICIT_KEYWORD_SUPPORT */

/* mutable keyword support
 *
 * Discriminated symbol is __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT
 */
#ifdef __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT
# undef __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT
#endif /* __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT */

/* typename keyword support
 *
 * Discriminated symbols are __STLSOFT_CF_TYPENAME_PARAM_KEYWORD_SUPPORT,
 * __STLSOFT_CF_TYPENAME_TYPE_KEYWORD_SUPPORT, 
 * __STLSOFT_CF_TYPENAME_TYPE_DEF_KEYWORD_SUPPORT and
 * __STLSOFT_CF_TYPENAME_TYPE_MIL_KEYWORD_SUPPORT
 *
 * The typename keyword is actually used for two distinct purposes: the
 * generic type placeholder in template parameter specifications, and the
 * stipulation to compilers that a particular template derived construct
 * is a type, rather than a member or operation.
 *
 * These two uses have varying support on different compilers, hence the
 * STLSoft libraries utilise the ss_typename_param_k pseudo keyword for the
 * first purpose, and the ss_typename_type_k pseudo keyword for the second.
 *
 * In addition, some compilers cannot handle the use of typename as a type
 * qualifier in a template default parameter, so we further define the keyword
 * ss_typename_type_def_k. And some cannot handle it in a constructor 
 * initialiser list, for which ss_typename_type_mil_k is defined.
 */
#ifdef __STLSOFT_CF_TYPENAME_PARAM_KEYWORD_SUPPORT
# undef __STLSOFT_CF_TYPENAME_PARAM_KEYWORD_SUPPORT
#endif /* __STLSOFT_CF_TYPENAME_PARAM_KEYWORD_SUPPORT */

#ifdef __STLSOFT_CF_TYPENAME_TYPE_KEYWORD_SUPPORT
# undef __STLSOFT_CF_TYPENAME_TYPE_KEYWORD_SUPPORT
#endif /* __STLSOFT_CF_TYPENAME_TYPE_KEYWORD_SUPPORT */

#ifdef __STLSOFT_CF_TYPENAME_TYPE_DEF_KEYWORD_SUPPORT
# undef __STLSOFT_CF_TYPENAME_TYPE_DEF_KEYWORD_SUPPORT
#endif /* __STLSOFT_CF_TYPENAME_TYPE_DEF_KEYWORD_SUPPORT */

#ifdef __STLSOFT_CF_TYPENAME_TYPE_MIL_KEYWORD_SUPPORT
# undef __STLSOFT_CF_TYPENAME_TYPE_MIL_KEYWORD_SUPPORT
#endif /* __STLSOFT_CF_TYPENAME_TYPE_MIL_KEYWORD_SUPPORT */

/* Move constructor support
 *
 * Discriminated symbol is __STLSOFT_CF_MOVE_CONSTRUCTOR_SUPPORT
 */
#ifdef __STLSOFT_CF_MOVE_CONSTRUCTOR_SUPPORT
# undef __STLSOFT_CF_MOVE_CONSTRUCTOR_SUPPORT
#endif /* __STLSOFT_CF_MOVE_CONSTRUCTOR_SUPPORT */

/* Koening Lookup support
 *
 * Discriminated symbol is __STLSOFT_CF_KOENIG_LOOKUP_SUPPORT
 */
#ifdef __STLSOFT_CF_KOENIG_LOOKUP_SUPPORT
# undef __STLSOFT_CF_KOENIG_LOOKUP_SUPPORT
#endif /* __STLSOFT_CF_KOENIG_LOOKUP_SUPPORT */

/* Template template support
 *
 * Discriminated symbol is __STLSOFT_CF_TEMPLATE_TEMPLATE_SUPPORT
 */
#ifdef __STLSOFT_CF_TEMPLATE_TEMPLATE_SUPPORT
# undef __STLSOFT_CF_TEMPLATE_TEMPLATE_SUPPORT
#endif /* __STLSOFT_CF_TEMPLATE_TEMPLATE_SUPPORT */


#ifdef __STLSOFT_CF_STATIC_ARRAY_SIZE_DETERMINATION_SUPPORT
# undef __STLSOFT_CF_STATIC_ARRAY_SIZE_DETERMINATION_SUPPORT
#endif /* __STLSOFT_CF_STATIC_ARRAY_SIZE_DETERMINATION_SUPPORT */

#ifdef __STLSOFT_CF_VENEER_SUPPORT
# undef __STLSOFT_CF_VENEER_SUPPORT
#endif /* __STLSOFT_CF_VENEER_SUPPORT */

#ifdef __STLSOFT_CF_TEMPLATE_SHIMS_NOT_SUPPORTED
# undef __STLSOFT_CF_TEMPLATE_SHIMS_NOT_SUPPORTED
#endif /* __STLSOFT_CF_TEMPLATE_SHIMS_NOT_SUPPORTED */

#ifdef __STLSOFT_CF_NEGATIVE_MODULUS_POSITIVE_GIVES_NEGATIVE_RESULT
# undef __STLSOFT_CF_NEGATIVE_MODULUS_POSITIVE_GIVES_NEGATIVE_RESULT
#endif /* __STLSOFT_CF_NEGATIVE_MODULUS_POSITIVE_GIVES_NEGATIVE_RESULT */

#ifdef STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT
# undef STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT
#endif /* STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT */

#ifdef STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT
# undef STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT
#endif /* STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT */

#ifdef STLSOFT_CF_FASTCALL_SUPPORTED
# undef STLSOFT_CF_FASTCALL_SUPPORTED
#endif /* STLSOFT_CF_FASTCALL_SUPPORTED */

#ifdef STLSOFT_CF_STDCALL_SUPPORTED
# undef STLSOFT_CF_STDCALL_SUPPORTED
#endif /* STLSOFT_CF_STDCALL_SUPPORTED */

#ifdef STSLSOFT_INLINE_ASM_SUPPORTED
# undef STSLSOFT_INLINE_ASM_SUPPORTED
#endif /* STSLSOFT_INLINE_ASM_SUPPORTED */

#ifdef STSLSOFT_ASM_IN_INLINE_SUPPORTED
# undef STSLSOFT_ASM_IN_INLINE_SUPPORTED
#endif /* STSLSOFT_ASM_IN_INLINE_SUPPORTED */

/* Now we include the appropriate compiler-specific header */

#if defined(__STLSOFT_COMPILER_IS_CUSTOM)
# include __STLSOFT_CF_CUSTOM_COMPILER_INCLUDE_NAME
#elif defined(__STLSOFT_COMPILER_IS_UNKNOWN)
# include "stlsoft_cccap_unknown.h"
#elif defined(__STLSOFT_COMPILER_IS_BORLAND)
# include "stlsoft_cccap_borland.h"
#elif defined(__STLSOFT_COMPILER_IS_COMO)
# include "stlsoft_cccap_como.h"
#elif defined(__STLSOFT_COMPILER_IS_DMC)
# include "stlsoft_cccap_dmc.h"
#elif defined(__STLSOFT_COMPILER_IS_GCC)
# include "stlsoft_cccap_gcc.h"
#elif defined(__STLSOFT_COMPILER_IS_INTEL)
# include "stlsoft_cccap_intel.h"
#elif defined(__STLSOFT_COMPILER_IS_MSVC)
# include "stlsoft_cccap_msvc.h"
#elif defined(__STLSOFT_COMPILER_IS_MWERKS)
# include "stlsoft_cccap_mwerks.h"
#elif defined(__STLSOFT_COMPILER_IS_VECTORC)
# include "stlsoft_cccap_vectorc.h"
#elif defined(__STLSOFT_COMPILER_IS_WATCOM)
# include "stlsoft_cccap_watcom.h"
#else
# error Compiler not correctly discriminated
#endif /* compiler */

#if defined(_STLSOFT_COMPILE_VERBOSE) && \
    !defined(STLSOFT_CF_PRAGMA_MESSAGE_SUPPORT)
# undef _STLSOFT_COMPILE_VERBOSE
# endif /* !STLSOFT_CF_PRAGMA_MESSAGE_SUPPORT && _STLSOFT_COMPILE_VERBOSE */

# ifdef _STLSOFT_COMPILE_VERBOSE
#  pragma message(__STLSOFT_COMPILER_VERSION_STRING)
# endif /* STLSOFT_CF_PRAGMA_MESSAGE_SUPPORT && _STLSOFT_COMPILE_VERBOSE */

/* /////////////////////////////////////////////////////////////////////////////
 * Sanity checks - 2
 *
 * MBCS     -   none of the libraries code is written to support MBCS
 */

/* Should not be MBCS.
 *
 * Only ANSI and Unicode character encoding schemese are explicitly supported.
 */
#ifdef _MBCS
# ifdef _STLSOFT_STRICT
#  error The STLSoft libraries are not compatible with variable length character representation schemes such as MBCS
# else
#  ifdef _STLSOFT_COMPILE_VERBOSE
#   pragma message("The STLSoft libraries are not compatible with variable length character representation schemes such as MBCS")
#  endif /* _STLSOFT_COMPILE_VERBOSE */
# endif /* _STLSOFT_STRICT */
#endif /* _MBCS */





/* Template support */
#ifndef __STLSOFT_CF_TEMPLATE_SUPPORT
# error Template support not detected. STLSoft libraries are template-based and require this support.
#endif /* __STLSOFT_CF_TEMPLATE_SUPPORT */


/* Native 64-bit integer support */
#if defined(__STLSOFT_CF_NATIVE___int64_SUPPORT) || \
    defined(__STLSOFT_CF_NATIVE_LONG_LONG_SUPPORT)
# define __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT
#endif /* __STLSOFT_CF_NATIVE___int64_SUPPORT || __STLSOFT_CF_NATIVE_LONG_LONG_SUPPORT */

/* Out-of-class method definition argument full-qualification requirement */
#ifdef __STLSOFT_CF_FUNCTION_SIGNATURE_FULL_ARG_QUALIFICATION_REQUIRED
# define _stlsoft_qualify_fn_arg(Q, T)   Q::T
#else
# define _stlsoft_qualify_fn_arg(Q, T)   T
#endif /* __STLSOFT_CF_FUNCTION_SIGNATURE_FULL_ARG_QUALIFICATION_REQUIRED */

/* Out-of-memory throws bad_alloc.
 *
 * Discriminated symbol is __STLSOFT_CF_NOTHROW_BAD_ALLOC
 *
 * By default, compilations with the Borland, and Watcom compilers throw
 * bad_alloc in conditions of memory exhaustion, and those with Digital Mars
 * and Microsoft do not.
 *
 * The Microsoft compilers do not throw bad_alloc for long established reasons,
 * though they can be made to do so (see Matthew Wilson, "Generating
 * Out-Of-Memory Exceptions", Windows Developer's Journal, Vol 12 Number 5, May
 * 2001). This feature may be added in a forthcoming release of the libraries.
 *
 * The Digital Mars compiler appears to ship without any header files that
 * define bad_alloc (whether in std or not), so it is therefore assumed that
 * operator new will not throw exceptions in out of memory conditions.
 *
 * Define __STLSOFT_CF_THROW_BAD_ALLOC to force Microsoft to do so.
 * Define __STLSOFT_CF_NO_THROW_BAD_ALLOC to prevent Borland/Comeau/Digital Mars/
 * GCC/Metrowerks/Watcom from doing so.
 */

#ifndef __STLSOFT_CF_EXCEPTION_SUPPORT
# define __STLSOFT_CF_NOTHROW_BAD_ALLOC
#endif /* !__STLSOFT_CF_EXCEPTION_SUPPORT */

#ifdef __STLSOFT_CF_NOTHROW_BAD_ALLOC
# ifdef __STLSOFT_CF_THROW_BAD_ALLOC
#  undef __STLSOFT_CF_THROW_BAD_ALLOC
# endif /* __STLSOFT_CF_THROW_BAD_ALLOC */
#else
 /* Leave it to whatever the compiler's capability discrimination has determined */
#endif /* __STLSOFT_CF_NOTHROW_BAD_ALLOC */


/* Template specialisation syntax support
 */
#ifdef __STLSOFT_TEMPLATE_SPECIALISATION
# undef __STLSOFT_TEMPLATE_SPECIALISATION
#endif /* __STLSOFT_TEMPLATE_SPECIALISATION */

#ifdef __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX
# define STLSOFT_TEMPLATE_SPECIALISATION                template <>
#else
# define STLSOFT_TEMPLATE_SPECIALISATION
#endif /* __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX */


/* Keyword support.
 *
 * Define _STLSOFT_FORCE_ALL_KEYWORDS to force the assumption of compiler
 * support for all keywords.
 *
 * Define _STLSOFT_FORCE_KEYWORD_EXPLICIT to force the assumption of compiler
 * support for the explicit keyword
 *
 * Define _STLSOFT_FORCE_KEYWORD_MUTABLE to force the assumption of compiler
 * support for the mutable keyword
 *
 * Define _STLSOFT_FORCE_KEYWORD_TYPENAME to force the assumption of compiler
 * support for the typename keyword
 */

#ifdef _STLSOFT_FORCE_ALL_KEYWORDS
# define _STLSOFT_FORCE_KEYWORD_EXPLICIT
# define _STLSOFT_FORCE_KEYWORD_MUTABLE
# define _STLSOFT_FORCE_KEYWORD_TYPENAME
#endif /* _STLSOFT_FORCE_ALL_KEYWORDS */

#if !defined(__STLSOFT_CF_EXPLICIT_KEYWORD_SUPPORT) && \
    defined(_STLSOFT_FORCE_KEYWORD_EXPLICIT)
# define __STLSOFT_CF_EXPLICIT_KEYWORD_SUPPORT
#endif /* !__STLSOFT_CF_EXPLICIT_KEYWORD_SUPPORT && _STLSOFT_FORCE_KEYWORD_EXPLICIT */

#if !defined(__STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT) && \
    defined(_STLSOFT_FORCE_KEYWORD_MUTABLE)
# define __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT
#endif /* !__STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT && _STLSOFT_FORCE_KEYWORD_MUTABLE */

#if !defined(__STLSOFT_CF_TYPENAME_PARAM_KEYWORD_SUPPORT) && \
    defined(_STLSOFT_FORCE_KEYWORD_TYPENAME)
# define __STLSOFT_CF_TYPENAME_PARAM_KEYWORD_SUPPORT
#endif /* !__STLSOFT_CF_TYPENAME_PARAM_KEYWORD_SUPPORT && _STLSOFT_FORCE_KEYWORD_TYPENAME */

#if !defined(__STLSOFT_CF_TYPENAME_TYPE_KEYWORD_SUPPORT) && \
    defined(_STLSOFT_FORCE_KEYWORD_TYPENAME)
# define __STLSOFT_CF_TYPENAME_TYPE_KEYWORD_SUPPORT
#endif /* !__STLSOFT_CF_TYPENAME_TYPE_KEYWORD_SUPPORT && _STLSOFT_FORCE_KEYWORD_TYPENAME */

#if !defined(__STLSOFT_CF_TYPENAME_TYPE_DEF_KEYWORD_SUPPORT) && \
    defined(_STLSOFT_FORCE_KEYWORD_TYPENAME)
# define __STLSOFT_CF_TYPENAME_TYPE_DEF_KEYWORD_SUPPORT
#endif /* !__STLSOFT_CF_TYPENAME_TYPE_DEF_KEYWORD_SUPPORT && _STLSOFT_FORCE_KEYWORD_TYPENAME */

#if !defined(__STLSOFT_CF_TYPENAME_TYPE_MIL_KEYWORD_SUPPORT) && \
    defined(_STLSOFT_FORCE_KEYWORD_TYPENAME)
# define __STLSOFT_CF_TYPENAME_TYPE_MIL_KEYWORD_SUPPORT
#endif /* !__STLSOFT_CF_TYPENAME_TYPE_MIL_KEYWORD_SUPPORT && _STLSOFT_FORCE_KEYWORD_TYPENAME */

/* /////////////////////////////////////////////////////////////////////////////
 * operator bool()
 *
 * If the symbol STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT
 * is defined, operator bool should be defined as follows:
 *
 *  class X
 *  {
 *  private:
 *    struct boolean { int i; }
 *    typedef int boolean::*boolean_t;
 *  public:
 *    operator boolean_t () const;
 *  
 * otherwise it should be 
 *
 *  class X
 *  {
 *  private:
 *    typedef ss_bool_t boolean_t;
 *  public:
 *    operator boolean_t () const;
 * 
 *
 * If the symbol STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT
 * is defined, it means that (!x) can de deduced by the compiler, otherwise it
 * will need to be provided
 *
 * If STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT is not defined
 * then STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT should not be
 * defined, so we do a check here.
 *
 */

#if !defined(STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT) && \
    defined(STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT)
# error Cannot rely on use of boolean as pointer to member for operator !
# error Undefine STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT when 
# error STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT is not defined
#endif /* !STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT && STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT */

/* /////////////////////////////////////////////////////////////////////////////
 * Obsolete symbol definitions
 *
 * Define _STLSOFT_INCLUDE_OBSOLETE to include the definitions of symbols prior
 * to version 1.5.1
 */

/* Verify that the significant changes to STLSoft 1.5.1 are checked with respect
 * to other previously released projects
 */

#if (   defined(_ATLSTL_VER) && \
        _ATLSTL_VER <= 0x00010204) || \
    (   defined(_COMSTL_VER) && \
        _COMSTL_VER <= 0x00010201) || \
    (   defined(_MFCSTL_VER) && \
        _MFCSTL_VER <= 0x00010202) || \
    (   defined(_UNIXSTL_VER) && \
        _UNIXSTL_VER <= 0x00000901) || \
    (   defined(_WINSTL_VER) && \
        _WINSTL_VER <= 0x00010201)
# ifdef _STLSOFT_STRICT
#  error You are using an old version of one or more of ATLSTL, COMSTL, MFCSTL, UNIXSTL and WinSTL. Please upgrade all dependent projects in line with the STLSoft version you are using
# else
#  ifdef _STLSOFT_COMPILE_VERBOSE
#   pragma message("You are using an old version of one or more of ATLSTL, COMSTL, MFCSTL, UNIXSTL and WinSTL. _STLSOFT_INCLUDE_OBSOLETE will be defined (but is not guaranteed to work!)")
#  endif /* _STLSOFT_COMPILE_VERBOSE */
#  ifndef _STLSOFT_INCLUDE_OBSOLETE
#   define _STLSOFT_INCLUDE_OBSOLETE
#  endif /* !_STLSOFT_INCLUDE_OBSOLETE */
# endif /* _STLSOFT_STRICT */
#endif /* sub-project versions */

#ifdef _STLSOFT_INCLUDE_OBSOLETE
# include "stlsoft_cc_obsolete.h"
#endif /* _STLSOFT_INCLUDE_OBSOLETE */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _STLSOFT_NO_STD_INCLUDES
# include <stddef.h>    // standard types
# include <stdlib.h>    // standard constants
#endif /* !_STLSOFT_NO_STD_INCLUDES */

/* /////////////////////////////////////////////////////////////////////////////
 * Debugging
 *
 * The macro stlsoft_assert provides standard debug-mode assert functionality.
 */

#if defined(_STLSOFT_NO_ASSERT) && \
    defined(__STLSOFT_CF_ASSERT_SUPPORT)
# undef __STLSOFT_CF_ASSERT_SUPPORT
#endif /* _STLSOFT_NO_ASSERT && __STLSOFT_CF_ASSERT_SUPPORT */

/// \def stlsoft_assert Defines a runtime assertion
///
/// \param ex Must be non-zero, or an assertion will be fired
#ifdef __STLSOFT_CF_ASSERT_SUPPORT
# ifdef __STLSOFT_CF_USE_cassert
  /* Using the standard assertion mechanism, located in <cassert> */
#  include <cassert>
#  define stlsoft_assert(ex)                assert(ex)
# else
  /* Using either a custom or proprietary assertion mechanism, so must
   * provide the header include name
   */
#  ifndef __STLSOFT_CF_ASSERT_INCLUDE_NAME
#   error Must supply an assert include filename with custom or proprietary assertion mechanism
#  else
#   include __STLSOFT_CF_ASSERT_INCLUDE_NAME
#  endif /* !__STLSOFT_CF_ASSERT_INCLUDE_NAME */
# endif /* __STLSOFT_CF_USE_cassert */
# ifndef stlsoft_assert
#  error If your compiler discrimination file supports assertions, it must defined stlsoft_assert() (taking a single parameter)
# endif /* !stlsoft_assert */
#endif /* !__STLSOFT_CF_ASSERT_SUPPORT */

/// \def stlsoft_message_assert Defines a runtime assertion, with message
///
/// \param ex Must be non-zero, or an assertion will be fired
/// \param _m The literal character string message to be included in the assertion
#if defined(__STLSOFT_CF_ASSERT_SUPPORT)
# if defined(__WATCOMC__)
#  define stlsoft_message_assert(_m, ex)    stlsoft_assert(ex)
# else
#  define stlsoft_message_assert(_m, ex)    stlsoft_assert((_m, ex))
# endif /* __WATCOMC__ */
#else
# define stlsoft_message_assert(_m, ex)
#endif /* __STLSOFT_CF_ASSERT_SUPPORT */

/// \def stlsoft_static_assert Defines a compile-time assertion
///
/// \param ex Must be non-zero, or compilation will fail
#if defined(__STLSOFT_CF_STATIC_ASSERT_SUPPORT)
# if defined(__STLSOFT_COMPILER_IS_GCC)
#   define stlsoft_static_assert(ex)        do { typedef int ai[(ex) ? 1 : -1]; } while(0)
#  else
#   define stlsoft_static_assert(ex)        do { typedef int ai[(ex) ? 1 : 0]; } while(0)
# endif /* compiler */
#else
# define stlsoft_static_assert(ex)          stlsoft_message_assert("Static assertion failed: ", (ex))
#endif /* __STLSOFT_COMPILER_IS_DMC */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 *
 * The STLSoft uses namespaces by default, unless the _STLSOFT_NO_NAMESPACES
 * preprocessor symbol is defined, in which case all elements are placed within
 * the global namespace.
 *
 * The macro stlsoft_ns_qual() macro can be used to refer to elements in the
 * STLSoft libraries irrespective of whether they are in the stlsoft namespace
 * or in the global namespace.
 *
 * Some compilers do not support the standard library in the std namespace, so
 * the stlsoft_ns_qual_std() macro can be used to refer to elements in the
 * STLSoft libraries irrespective of whether they are in the std namespace or
 * in the global namespace.
 */

/* No STLSoft namespaces means no stlsoft namespace */
#ifdef _STLSOFT_NO_NAMESPACES
# define _STLSOFT_NO_NAMESPACE
#endif /* _STLSOFT_NO_NAMESPACES */

#ifndef _STLSOFT_NO_NAMESPACE
/// The STLSoft namespace - \c stlsoft - is the namespace for the STLSoft main
/// project, and the root namespace for all the other STLSoft projects, whose
/// individual namespaces reside within it.
namespace stlsoft
{
#endif /* !_STLSOFT_NO_NAMESPACE */

/// \def stlsoft_ns_qual(x)
/// Qualifies with <b>stlsoft::</b> if STLSoft is using namespaces or, if not, does not qualify

/// \def stlsoft_ns_using(x)
/// Declares a using directive (with respect to <b>stlsoft</b>) if STLSoft is using namespaces or, if not, does nothing

#ifndef _STLSOFT_NO_NAMESPACE
# define stlsoft_ns_qual(x)          ::stlsoft::x
# define stlsoft_ns_using(x)         using ::stlsoft::x;
#else
# define stlsoft_ns_qual(x)          x
# define stlsoft_ns_using(x)
#endif /* !_STLSOFT_NO_NAMESPACE */

/// \def stlsoft_ns_qual_std(x)
/// Qualifies with <b>std::</b> if STLSoft is being translated in the context of the standard library being within the <b>std</b> namespace or, if not, does not qualify

/// \def stlsoft_ns_using_std(x)
/// Declares a using directive (with respect to <b>std</b>) if STLSoft is being translated in the context of the standard library being within the <b>std</b> namespace or, if not, does nothing

#ifdef __STLSOFT_CF_std_NAMESPACE
# define stlsoft_ns_qual_std(x)      ::std::x
# define stlsoft_ns_using_std(x)     using ::std::x;
#else
# define stlsoft_ns_qual_std(x)      x
# define stlsoft_ns_using_std(x)
#endif /* !__STLSOFT_CF_std_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs
 *
 * The STLSoft uses a number of typedefs to aid in compiler-independence in the
 * libraries' main code.
 */

/* Type definitions - precursors */

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION

/* ptrdiff_t
 */
#ifndef _STLSOFT_NO_STD_INCLUDES
 typedef ptrdiff_t                  ss_ptrdiff_pr_t_;   // ptr diff
#else
 typedef int                        ss_ptrdiff_pr_t_;   // ptr diff
#endif /* !_STLSOFT_NO_STD_INCLUDES */

/* size_t
 */
#ifndef _STLSOFT_NO_STD_INCLUDES
 typedef size_t                     ss_size_pr_t_;      // size
#else
 typedef unsigned int               ss_size_pr_t_;      // size
#endif /* !_STLSOFT_NO_STD_INCLUDES */

/* wchar_t
 *
 * wchar_t is either a built-in type, or is defined to unsigned 16-bit value
 */

#ifdef __STLSOFT_CF_NATIVE_WCHAR_T_SUPPORT
 /* It's some kind of compiler native type. */
# ifndef __STLSOFT_NATIVE_WCHAR_T
  /* either wchar_t itself */
  typedef wchar_t                  ss_char_w_pr_t_;    // Unicode char type
# else
  /* or a compiler-specific type */
  typedef __STLSOFT_NATIVE_WCHAR_T ss_char_w_pr_t_;    // Unicode char type
# endif /* !__STLSOFT_NATIVE_WCHAR_T */
#elif defined(__STLSOFT_CF_TYPEDEF_WCHAR_T_SUPPORT)
  typedef wchar_t                  ss_char_w_pr_t_;    // Unicode char type
#else
 /* It's some kind of library-defined type. */
# ifndef _STLSOFT_NO_STD_INCLUDES
  typedef wchar_t                   ss_char_w_pr_t_;    // Unicode char type
# else
  typedef unsigned short            ss_char_w_pr_t_;    // Unicode char type
# endif /* __STLSOFT_CF_NATIVE_WCHAR_T_SUPPORT */
#endif /* !__STLSOFT_CF_NATIVE_WCHAR_T_SUPPORT */

/* 8-bit */
#ifdef __STLSOFT_CF_NATIVE_8BIT_INT_SUPPORT
 typedef __STLSOFT_NATIVE_INT8_T    ss_int8_pr_t_;
 typedef __STLSOFT_NATIVE_SINT8_T   ss_sint8_pr_t_;
 typedef __STLSOFT_NATIVE_UINT8_T   ss_uint8_pr_t_;
#else
 typedef signed char                ss_int8_pr_t_;
 typedef signed char                ss_sint8_pr_t_;
 typedef unsigned char              ss_uint8_pr_t_;
#endif /* __STLSOFT_CF_NATIVE_8BIT_INT_SUPPORT */

/* 16-bit */
#ifdef __STLSOFT_CF_NATIVE_16BIT_INT_SUPPORT
 typedef __STLSOFT_NATIVE_INT16_T   ss_int16_pr_t_;
 typedef __STLSOFT_NATIVE_SINT16_T  ss_sint16_pr_t_;
 typedef __STLSOFT_NATIVE_UINT16_T  ss_uint16_pr_t_;
#else
 typedef short                      ss_int16_pr_t_;
 typedef signed short               ss_sint16_pr_t_;
 typedef unsigned short             ss_uint16_pr_t_;
#endif /* __STLSOFT_CF_NATIVE_16BIT_INT_SUPPORT */

/* 32-bit */
#ifdef __STLSOFT_CF_NATIVE_32BIT_INT_SUPPORT
 typedef __STLSOFT_NATIVE_INT32_T   ss_int32_pr_t_;
 typedef __STLSOFT_NATIVE_SINT32_T  ss_sint32_pr_t_;
 typedef __STLSOFT_NATIVE_UINT32_T  ss_uint32_pr_t_;
#else
 typedef long                       ss_int32_pr_t_;
 typedef signed long                ss_sint32_pr_t_;
 typedef unsigned long              ss_uint32_pr_t_;
#endif /* __STLSOFT_CF_NATIVE_32BIT_INT_SUPPORT */

/* 64-bit */
#ifdef __STLSOFT_CF_NATIVE___int64_SUPPORT
 typedef __int64            ss_int64_pr_t_;
 typedef signed __int64     ss_sint64_pr_t_;
 typedef unsigned __int64   ss_uint64_pr_t_;
#elif defined(__STLSOFT_CF_NATIVE_LONG_LONG_SUPPORT)
 typedef long long          ss_int64_pr_t_;
 typedef signed long long   ss_sint64_pr_t_;
 typedef unsigned long long ss_uint64_pr_t_;
#endif /* __STLSOFT_CF_NATIVE_LONG_LONG_SUPPORT */

/* bool */
#ifdef __STLSOFT_CF_NATIVE_BOOL_SUPPORT
 typedef bool               ss_bool_pr_t_;
#else
 typedef unsigned int       ss_bool_pr_t_;
#endif /* __STLSOFT_CF_NATIVE_BOOL_SUPPORT */

#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* Type definitions - proper */

typedef char                ss_char_a_t;        //!< Ansi char type
typedef ss_char_w_pr_t_     ss_char_w_t;        //!< Unicode char type
typedef ss_int8_pr_t_       ss_int8_t;          //!< 8-bit integer
typedef ss_sint8_pr_t_      ss_sint8_t;         //!< 8-bit signed integer
typedef ss_uint8_pr_t_      ss_uint8_t;         //!< 8-bit unsigned integer
typedef ss_int16_pr_t_      ss_int16_t;         //!< 16-bit integer
typedef ss_sint16_pr_t_     ss_sint16_t;        //!< 16-bit signed integer
typedef ss_uint16_pr_t_     ss_uint16_t;        //!< 16-bit unsigned integer
typedef ss_int32_pr_t_      ss_int32_t;         //!< 32-bit integer
typedef ss_sint32_pr_t_     ss_sint32_t;        //!< 32-bit signed integer
typedef ss_uint32_pr_t_     ss_uint32_t;        //!< 32-bit unsigned integer
#ifdef __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT
 typedef ss_int64_pr_t_     ss_int64_t;         //!< 64-bit integer
 typedef ss_sint64_pr_t_    ss_sint64_t;        //!< 64-bit signed integer
 typedef ss_uint64_pr_t_    ss_uint64_t;        //!< 64-bit unsigned integer
#endif /* __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT */
typedef short               ss_short_t;         //!< short integer
typedef int                 ss_int_t;           //!< integer
typedef signed int          ss_sint_t;          //!< signed integer
typedef unsigned int        ss_uint_t;          //!< unsigned integer
typedef long                ss_long_t;          //!< long integer
typedef ss_uint8_t          ss_byte_t;          //!< Byte
typedef ss_bool_pr_t_       ss_bool_t;          //!< bool
typedef ss_size_pr_t_       ss_size_t;          //!< size
typedef ss_ptrdiff_pr_t_    ss_ptrdiff_t;       //!< ptr diff
typedef long                ss_streampos_t;     //!< streampos
typedef long                ss_streamoff_t;     //!< streamoff

#ifndef _STLSOFT_NO_NAMESPACE
typedef ss_char_a_t         char_a_t;           //!< Ansi char type
typedef ss_char_w_t         char_w_t;           //!< Unicode char type
typedef ss_int8_t           int8_t;             //!< 8-bit integer
typedef ss_sint8_t          sint8_t;            //!< 8-bit signed integer
typedef ss_uint8_t          uint8_t;            //!< 8-bit unsigned integer
typedef ss_int16_t          int16_t;            //!< 16-bit integer
typedef ss_sint16_t         sint16_t;           //!< 16-bit signed integer
typedef ss_uint16_t         uint16_t;           //!< 16-bit unsigned integer
typedef ss_int32_t          int32_t;            //!< 32-bit integer
typedef ss_sint32_t         sint32_t;           //!< 32-bit signed integer
typedef ss_uint32_t         uint32_t;           //!< 32-bit unsigned integer
# ifdef __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT
typedef ss_int64_t          int64_t;            //!< 64-bit integer
typedef ss_sint64_t         sint64_t;           //!< 64-bit signed integer
typedef ss_uint64_t         uint64_t;           //!< 64-bit unsigned integer
# endif /* __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT */
typedef ss_short_t          short_t;            //!< short integer
typedef ss_int_t            int_t;              //!< integer
typedef ss_sint_t           sint_t;             //!< signed integer
typedef ss_uint_t           uint_t;             //!< unsigned integer
typedef ss_long_t           long_t;             //!< long integer
typedef ss_byte_t           byte_t;             //!< Byte
typedef ss_bool_t           bool_t;             //!< bool
typedef ss_size_t           size_t;             //!< size
typedef ss_ptrdiff_t        ptrdiff_t;          //!< ptr diff
typedef ss_streampos_t      streampos_t;        //!< streampos
typedef ss_streamoff_t      streamoff_t;        //!< streamoff
#endif /* !_STLSOFT_NO_NAMESPACE */


#if 0
template <ss_size_t N>
struct uintp_traits;

STLSOFT_GEN_TRAIT_SPECIALISATION
struct uintp_traits<1>
{
    typedef uint8_t     unsigned_type;
}

typedef size_traits<sizeof(void*)>::signed_type     sintp_t;
typedef size_traits<sizeof(void*)>::unsigned_type   uintp_t;

#endif /* 0 */



#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#ifdef __cplusplus
struct stlsoft_size_checker
{
#ifdef __STLSOFT_COMPILER_IS_GCC
protected: // GCC is too "helpful" in this case, so must declare as protected
#else
private:
#endif /* __STLSOFT_COMPILER_IS_GCC */
    stlsoft_size_checker();
    ~stlsoft_size_checker()
    {
        // Char types
        stlsoft_static_assert(sizeof(ss_char_a_t) >= 1);
        stlsoft_static_assert(sizeof(ss_char_w_t) >= 2);
        // 8-bit types
        stlsoft_static_assert(sizeof(ss_int8_t)   == 1);
        stlsoft_static_assert(sizeof(ss_sint8_t)  == sizeof(ss_int8_t));
        stlsoft_static_assert(sizeof(ss_uint8_t)  == sizeof(ss_int8_t));
        // 16-bit types
        stlsoft_static_assert(sizeof(ss_int16_t)  == 2);
        stlsoft_static_assert(sizeof(ss_sint16_t) == sizeof(ss_int16_t));
        stlsoft_static_assert(sizeof(ss_uint16_t) == sizeof(ss_int16_t));
        // 32-bit types
        stlsoft_static_assert(sizeof(ss_int32_t)  == 4);
        stlsoft_static_assert(sizeof(ss_sint32_t) == sizeof(ss_int32_t));
        stlsoft_static_assert(sizeof(ss_uint32_t) == sizeof(ss_int32_t));
        // 64-bit types
#ifdef __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT
        stlsoft_static_assert(sizeof(ss_int64_t)  == 8);
        stlsoft_static_assert(sizeof(ss_sint64_t) == sizeof(ss_int64_t));
        stlsoft_static_assert(sizeof(ss_uint64_t) == sizeof(ss_int64_t));
#endif /* __STLSOFT_CF_NATIVE_64BIT_INTEGER_SUPPORT */
        // Integer types
        stlsoft_static_assert(sizeof(ss_int_t)    >= 1);
        stlsoft_static_assert(sizeof(ss_sint_t)   == sizeof(ss_int_t));
        stlsoft_static_assert(sizeof(ss_uint_t)   == sizeof(ss_int_t));
        stlsoft_static_assert(sizeof(ss_long_t)   >= sizeof(ss_int_t));
        // byte type
        stlsoft_static_assert(sizeof(ss_byte_t)   == 1);
        // Bool type
        stlsoft_static_assert(sizeof(ss_bool_t)   >= 1);
        // Other types
        stlsoft_static_assert(sizeof(ss_size_t)   >= 1);
        stlsoft_static_assert(sizeof(ss_ptrdiff_t) >= 1);
        stlsoft_static_assert(sizeof(ss_streampos_t) >= 1);
        stlsoft_static_assert(sizeof(ss_streamoff_t) >= 1);
    }
};
#endif /* __cplusplus */
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Keywords
 *
 * The STLSoft uses a number of preprocessor symbols to aid in compiler
 * compatibility in the libraries' code.
 *
 * ss_explicit_k            -   explicit, or nothing
 * ss_mutable_k             -   mutable, or nothing
 * ss_typename_type_k       -   typename, or nothing (used within template
 *                              definitions for declaring types derived from
 *                              externally derived types)
 * ss_typename_param_k      -   typename or class (used for template parameters)
 * ss_typename_type_def_k   -   typename qualifier in template default parameters
 * ss_typename_type_mil_k   -   typename qualifier in constructor initialiser lists
 */

/// \def ss_explicit_k
///
/// Evaluates to <b>explicit</b> on translators that support the keyword, otherwise to nothing
#ifdef __STLSOFT_CF_EXPLICIT_KEYWORD_SUPPORT
# define ss_explicit_k              explicit
#else
# define ss_explicit_k
#endif /* __STLSOFT_CF_EXPLICIT_KEYWORD_SUPPORT */

/// \def ss_mutable_k
///
/// Evaluates to <b>mutable</b> on translators that support the keyword, otherwise to nothing
#ifdef __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT
# define ss_mutable_k               mutable
#else
# define ss_mutable_k
#endif /* __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT */

/// \def ss_typename_param_k
///
/// Evaluates to <b>typename</b> on translators that support the keyword, otherwise to <b>class</b>
#ifdef __STLSOFT_CF_TYPENAME_PARAM_KEYWORD_SUPPORT
# define ss_typename_param_k        typename
#else
# define ss_typename_param_k        class
#endif /* __STLSOFT_CF_TYPENAME_PARAM_KEYWORD_SUPPORT */

/// \def ss_typename_type_k
///
/// Evaluates to <b>typename</b> on translators that support the keyword, otherwise to nothing
#ifdef __STLSOFT_CF_TYPENAME_TYPE_KEYWORD_SUPPORT
# define ss_typename_type_k         typename
#else
# define ss_typename_type_k
#endif /* __STLSOFT_CF_TYPENAME_TYPE_KEYWORD_SUPPORT */

/// \def ss_typename_type_def_k
///
/// Evaluates to <b>typename</b> on translators that support the keyword, otherwise to nothing
#ifdef __STLSOFT_CF_TYPENAME_TYPE_DEF_KEYWORD_SUPPORT
# define ss_typename_type_def_k     typename
#else
# define ss_typename_type_def_k
#endif /* __STLSOFT_CF_TYPENAME_TYPE_DEF_KEYWORD_SUPPORT */

/// \def ss_typename_type_mil_k
///
/// Evaluates to <b>typename</b> on translators that support the keyword, otherwise to nothing
#ifdef __STLSOFT_CF_TYPENAME_TYPE_MIL_KEYWORD_SUPPORT
# define ss_typename_type_mil_k     typename
#else
# define ss_typename_type_mil_k
#endif /* __STLSOFT_CF_TYPENAME_TYPE_MIL_KEYWORD_SUPPORT */



#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
/* /////////////////////////////////////////////////////////////////////////////
 * Values
 *
 * Since the boolean type may not be supported natively on all compilers, the
 * values of true and false may also not be provided. Hence the values of
 * ss_true_v and ss_false_v are defined, and are used in all code.
 */

#ifdef __STLSOFT_CF_NATIVE_BOOL_SUPPORT
# define ss_true_v       (true)
# define ss_false_v      (false)
#else
# define ss_true_v       (1)
# define ss_false_v      (0)
#endif /* __STLSOFT_CF_NATIVE_BOOL_SUPPORT */

#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */
/* /////////////////////////////////////////////////////////////////////////////
 * Code modification macros
 */

/// \defgroup code_modification_macros Code Modification Macros
/// \ingroup STLSoft
/// \brief These macros are used to help out where compiler differences are 
/// so great as to cause great disgusting messes in the class/function implementations
/// @{

/* Exception signatures. */
#if !defined(__STLSOFT_DOCUMENTATION_SKIP_SECTION) && \
    defined(__STLSOFT_CF_EXCEPTION_SIGNATURE_SUPPORT)
# define stlsoft_throw_0()                                  throw ()
# define stlsoft_throw_1(x1)                                throw (x1)
# define stlsoft_throw_2(x1, x2)                            throw (x1, x2)
# define stlsoft_throw_3(x1, x2, x3)                        throw (x1, x2, x3)
# define stlsoft_throw_4(x1, x2, x3, x4)                    throw (x1, x2, x3, x4)
# define stlsoft_throw_5(x1, x2, x3, x4, x5)                throw (x1, x2, x3, x4, x5)
# define stlsoft_throw_6(x1, x2, x3, x4, x5, x6)            throw (x1, x2, x3, x4, x5, x6)
# define stlsoft_throw_7(x1, x2, x3, x4, x5, x6, x7)        throw (x1, x2, x3, x4, x5, x6, x7)
# define stlsoft_throw_8(x1, x2, x3, x4, x5, x6, x7, x8)    throw (x1, x2, x3, x4, x5, x6, x7, x8)
#else
# define stlsoft_throw_0()
# define stlsoft_throw_1(x1)
# define stlsoft_throw_2(x1, x2)
# define stlsoft_throw_3(x1, x2, x3)
# define stlsoft_throw_4(x1, x2, x3, x4)
# define stlsoft_throw_5(x1, x2, x3, x4, x5)
# define stlsoft_throw_6(x1, x2, x3, x4, x5, x6)
# define stlsoft_throw_7(x1, x2, x3, x4, x5, x6, x7)
# define stlsoft_throw_8(x1, x2, x3, x4, x5, x6, x7, x8)
#endif /* __STLSOFT_CF_EXCEPTION_SIGNATURE_SUPPORT && !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/// \def stlsoft_num_elements
///
/// Evaluates, at compile time, to the number of elements within the given vector entity
///
/// Is it used as follows:
///
/// \htmlonly
/// <code>
/// int&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;ai[20];
/// <br>
/// int&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;i&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;=&nbsp;32;
/// <br>
/// int&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*pi&nbsp;&nbsp;&nbsp;=&nbsp;&i;
/// <br>
/// std::vector&lt;int&gt;&nbsp;&nbsp;vi;
/// <br>
/// <br>
/// size_t&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;s_ai&nbsp;&nbsp;=&nbsp;stlsoft_num_elements(ai);&nbsp;&nbsp;&nbsp;//&nbsp;Ok
/// <br>
/// size_t&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;s_i&nbsp;&nbsp;&nbsp;=&nbsp;stlsoft_num_elements(i);&nbsp;&nbsp;&nbsp;&nbsp;//&nbsp;Error
/// <br>
/// size_t&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;s_pi&nbsp;&nbsp;=&nbsp;stlsoft_num_elements(pi);&nbsp;&nbsp;&nbsp;//&nbsp;Error
/// <br>
/// size_t&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;s_vi&nbsp;&nbsp;=&nbsp;stlsoft_num_elements(vi);&nbsp;&nbsp;&nbsp;//&nbsp;Error
/// <br>
/// </code>
/// \endhtmlonly
///
/// \note For most of the supported compilers, this macro will reject application to pointer 
/// types, or to class types providing <code>operator []</code>. This helps to avoid the common
/// gotcha whereby <code>(sizeof(ar) / sizeof(ar[0]))</code> is applied to such types, without
/// causing a compiler error.

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define _stlsoft_num_elements(ar)                      (sizeof(ar) / sizeof(0[(ar)]))

# if defined(__cplusplus) && \
     defined(__STLSOFT_CF_STATIC_ARRAY_SIZE_DETERMINATION_SUPPORT)
#  if 0/* defined(__STLSOFT_COMPILER_IS_GCC) */
#   pragma pack(push, 1)
template <int N>
struct ss_array_size_struct
{
    ss_sint8_t  c[N];
};
#   pragma pack(pop)

template <class T, int N>
ss_array_size_struct<N> ss_static_array_size(T (&)[N]);

#   define stlsoft_num_elements(ar)                     sizeof(stlsoft_ns_qual(ss_static_array_size)(ar))
#  else /* ? 0 */
template <int N>
struct ss_array_size_struct
{
    ss_sint8_t  c[N];
};

template <class T, int N>
ss_array_size_struct<N> ss_static_array_size(T (&)[N]);

#   define stlsoft_num_elements(ar)                     sizeof(stlsoft_ns_qual(ss_static_array_size)(ar).c)
#  endif /* 0 */
# else
#  define stlsoft_num_elements(ar)                      _stlsoft_num_elements(ar)
# endif /* __cplusplus && __STLSOFT_CF_STATIC_ARRAY_SIZE_DETERMINATION_SUPPORT */
#else
# define stlsoft_num_elements(ar)
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/// \def stlsoft_raw_offsetof
///
/// Evaluates, at compile time, the offset of a structure/class member

#if defined(__STLSOFT_COMPILER_IS_GCC) && \
    __GNUC__ >= 3
# define stlsoft_raw_offsetof(s, m)                     (reinterpret_cast<size_t>(&reinterpret_cast<s *>(1)->m) - 1)
#else
# ifndef _STLSOFT_NO_STD_INCLUDES
#  define stlsoft_raw_offsetof(s, m)                    offsetof(s, m)
# else
#  define stlsoft_raw_offsetof(s, m)                    reinterpret_cast<size_t>(&static_cast<s *>(0)->m)
# endif /* !_STLSOFT_NO_STD_INCLUDES */
#endif /* __GNUC__ >= 3 */


/* destroy function */
#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
template <ss_typename_param_k T>
void stlsoft_destroy_instance_fn(T *p)
{
    p->~T();

    /* SSCB: Borland C++ and Visual C++ remove the dtor for basic
     * structs, and then warn that p is unused. This reference
     * suppresses that warning.
     */
    ((void)p);
}
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/// \def stlsoft_destroy_instance
///
/// Destroys the given instance \c p of the given type (\c t and \c _type)
#if defined(__STLSOFT_DOCUMENTATION_SKIP_SECTION) || \
    defined(__STLSOFT_COMPILER_IS_DMC)
# define stlsoft_destroy_instance(t, _type, p)          do { (p)->~t(); } while(0)
#else
# define stlsoft_destroy_instance(t, _type, p)          stlsoft_destroy_instance_fn((p))
#endif /* __STLSOFT_COMPILER_IS_DMC */

/// Generates an opaque type with the name \c type
///
/// For example, the following defines two distinct opaque types:
///
/// \htmlonly
/// <code>
/// stlsoft_gen_opaque(HThread)
/// <br>
/// stlsoft_gen_opaque(HProcess)
/// <br>
/// </code>
/// <br>
/// \endhtmlonly
///
/// The two types are incompatible with each other, and with any other types (except that
/// they are both convertible to <code>void const *</code>

#define stlsoft_gen_opaque(type)                        typedef struct __stlsoft_htype##type{ int i;} const *type;

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
/// Define a 'final' class, ie. one that cannot be inherited from
# define stlsoft_sterile_class(_cls)                    class __m__##_cls { private: __m__##_cls(){} ~__m__##_cls(){} friend class _cls; }; class _cls: public __m__##_cls
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/// \def STLSOFT_DECLARE_TEMPLATE_PARAM_AS_FRIEND
/// \ingroup code_modification_macros
///
/// \brief Declares a template (class) parameter to be a friend of the template.
///
/// Is it used as follows:
///
/// \htmlonly
/// <code>
/// template&lt;typename T&gt;
/// <br>
/// class Thing
/// <br>
/// {
/// <br>
/// &nbsp;&nbsp;STLSOFT_DECLARE_TEMPLATE_PARAM_AS_FRIEND(T);
/// <br>
/// <br>
/// private:
/// <br>
/// &nbsp;&nbsp;int m_member; // Thing&lt;T&gt;::m_member visible to T
/// <br>
/// };
/// <br>
/// </code>
/// \endhtmlonly
///
/// \note This is contrary to the C++-98 standard. Section 7.1.5.3(2) notes: <i>"...within a class 
/// template with a template type-parameter T, the declaration ["]friend class T;["] is ill-formed."</i> 
/// However, it gives the expected behaviour for all compilers currently supported by STLSoft

#if defined(__STLSOFT_DOCUMENTATION_SKIP_SECTION) || \
    defined(__STLSOFT_COMPILER_IS_BORLAND) || \
    defined(__STLSOFT_COMPILER_IS_COMO) || \
    defined(__STLSOFT_COMPILER_IS_DMC) || \
    (   defined(__STLSOFT_COMPILER_IS_GCC) && \
        __GNUC__ < 3) || \
    defined(__STLSOFT_COMPILER_IS_INTEL) || \
    defined(__STLSOFT_COMPILER_IS_MSVC) || \
    defined(__STLSOFT_COMPILER_IS_VECTORC) || \
    defined(__STLSOFT_COMPILER_IS_WATCOM)
# define    STLSOFT_DECLARE_TEMPLATE_PARAM_AS_FRIEND(T)     friend T
#elif defined(__STLSOFT_COMPILER_IS_MWERKS)
# define    STLSOFT_DECLARE_TEMPLATE_PARAM_AS_FRIEND(T)     friend class T
#elif defined(__STLSOFT_COMPILER_IS_GCC) && \
      __GNUC__ >= 3

# define    STLSOFT_DECLARE_TEMPLATE_PARAM_AS_FRIEND(T)     \
                                                            \
    struct friend_maker                                     \
    {                                                       \
        typedef T T2;                                       \
    };                                                      \
                                                            \
    typedef typename friend_maker::T2 friend_type;          \
                                                            \
    friend friend_type

#else
# error Compiler not discriminated
#endif /* compiler */


/// \def STLSOFT_GEN_TRAIT_SPECIALISATION
/// \ingroup code_modification_macros
///
/// \brief Used to define a specialisation of a traits type
///
#define STLSOFT_GEN_TRAIT_SPECIALISATION(TR, T, V)  \
                                                    \
    STLSOFT_TEMPLATE_SPECIALISATION                 \
    struct TR<T>                                    \
    {                                               \
        enum { value = V };                         \
    };


/// \def STLSOFT_SUPPRESS_UNUSED
/// \ingroup code_modification_macros
///
/// \brief Used to suppress unused variable warnings
///
#ifdef __STLSOFT_COMPILER_IS_INTEL
# define STLSOFT_SUPPRESS_UNUSED(x)		((void)((x) = (x)))
#else /* ? __STLSOFT_COMPILER_IS_INTEL */
# define STLSOFT_SUPPRESS_UNUSED(x)		((void)x)
#endif /* __STLSOFT_COMPILER_IS_INTEL */



/// @}

/// \defgroup pointer_manipulation_functions Pointer Manipulation Functions
/// \ingroup STLSoft
/// \brief These functions assist in calculations with, and the manipulation of pointers
/// @{

/// Offsets a pointer by a number of bytes
///
/// \param p The pointer to be offset
/// \param n The number of bytes to offset
/// \result \c p offset by \c bytes
template <ss_typename_param_k T>
inline void const *ptr_byte_offset(T const p, ss_ptrdiff_t n)
{
    return static_cast<void const *>(static_cast<ss_byte_t const *>(static_cast<void const *>(p)) + n);
}

/// Offsets a pointer by a number of elements
///
/// \param p The pointer to be offset
/// \param n The number of elements to offset
/// \result \c p offset by \c elements
template <ss_typename_param_k T>
inline T const *ptr_offset(T const *p, ss_ptrdiff_t n)
{
    return p + n;
}

/// Get the difference in bytes between two pointers
template <ss_typename_param_k T1, ss_typename_param_k T2>
inline ss_ptrdiff_t ptr_byte_diff(T1 const *p1, T2 const *p2)
{
    return static_cast<ss_byte_t const *>(static_cast<void const *>(p1)) - static_cast<ss_byte_t const *>(static_cast<void const *>(p2));
}

/// Get the difference in elements between two pointers
template <ss_typename_param_k T1, ss_typename_param_k T2>
inline ss_ptrdiff_t ptr_diff(T1 const *p1, T2 const *p2)
{
    return p1 - p2;
}

/// @} // end of group pointer_manipulation_functions

/* Mutable support */
#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
template <ss_typename_param_k T>
#ifdef __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT
inline T &mutable_access(T &t)
#else
inline T &mutable_access(T const &t)
#endif /* __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT */
{
#ifdef __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT
    return t;
#else
    return const_cast<T &>(t);
#endif /* __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT */
}
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* Move constructor support */
#ifdef __STLSOFT_CF_MOVE_CONSTRUCTOR_SUPPORT
# define stlsoft_define_move_rhs_type(t)            t &
#else
# define stlsoft_define_move_rhs_type(t)            t const &
#endif /* __STLSOFT_CF_MOVE_CONSTRUCTOR_SUPPORT */

template <ss_typename_param_k T>
inline T &move_lhs_from_rhs(stlsoft_define_move_rhs_type(T) t)
{
#ifdef __STLSOFT_CF_MOVE_CONSTRUCTOR_SUPPORT
    return t;
#else
    return const_cast<T &>(t);
#endif /* __STLSOFT_CF_MOVE_CONSTRUCTOR_SUPPORT */
}

/* /////////////////////////////////////////////////////////////////////////////
 * Memory
 */

// function operator new
//
// When namespaces are being used, stlsoft provides its own placement new,
// otherwise it includes <new> in order to access the global version.

#ifdef _STLSOFT_NO_NAMESPACE
# if defined(__STLSOFT_COMPILER_IS_BORLAND) && \
      __BORLANDC__ < 0x0550
#  include <new.h>
# else
#  include <new>
# endif /* __STLSOFT_COMPILER_IS_BORLAND && __BORLANDC__ < 0x0550 */
#else
# if ( defined(__STLSOFT_COMPILER_IS_DMC) && \
       __DMC__ < 0x0833) || \
     ( defined(__STLSOFT_COMPILER_IS_MSVC) && \
       _MSC_VER < 1300)
inline void *operator new(ss_size_t /* si */, void *pv)
{
    return pv;
}
# endif /* compiler */
#endif /* !_STLSOFT_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _STLSOFT_NO_NAMESPACE
} // namespace stlsoft
#endif /* !_STLSOFT_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !_STLSOFT_INCL_H_STLSOFT */

/* ////////////////////////////////////////////////////////////////////////// */
