/* /////////////////////////////////////////////////////////////////////////////
 * File:        stlsoft_cccap_gcc.h
 *
 * Purpose:     Compiler feature discrimination for GNU C/C++.
 *
 * Created:     7th February 2003
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


#ifndef _STLSOFT_INCL_H_STLSOFT
# error This file must not be included independently of stlsoft.h
#endif /* !_STLSOFT_INCL_H_STLSOFT */

#ifdef _STLSOFT_INCL_H_STLSOFT_CCCAP_GCC
# error This file cannot be included more than once in any compilation unit
#endif /* _STLSOFT_INCL_H_STLSOFT_CCCAP_GCC */

/* ////////////////////////////////////////////////////////////////////////// */

#define _STLSOFT_VER_H_STLSOFT_CCCAP_GCC_MAJOR      1
#define _STLSOFT_VER_H_STLSOFT_CCCAP_GCC_MINOR      10
#define _STLSOFT_VER_H_STLSOFT_CCCAP_GCC_REVISION   1
#define _STLSOFT_VER_H_STLSOFT_CCCAP_GCC_EDIT       22

/* /////////////////////////////////////////////////////////////////////////////
 * Compiler features
 */

/* Messaging
 */

//#define STLSOFT_CF_PRAGMA_MESSAGE_SUPPORT

/* Types:
 */

/* bool */
#define __STLSOFT_CF_NATIVE_BOOL_SUPPORT

/* wchar_t */
//#define __STLSOFT_CF_NATIVE_WCHAR_T_SUPPORT

/* Native 8-bit integer */
//#define __STLSOFT_CF_NATIVE_8BIT_INT_SUPPORT

/* Native 16-bit integer */
//#define __STLSOFT_CF_NATIVE_16BIT_INT_SUPPORT

/* Native 32-bit integer */
//#define __STLSOFT_CF_NATIVE_32BIT_INT_SUPPORT

/* Native 64-bit integer */
//#define __STLSOFT_CF_NATIVE___int64_SUPPORT

/* long long */
#define __STLSOFT_CF_NATIVE_LONG_LONG_SUPPORT

#define __STLSOFT_CF_INT_DISTINCT_TYPE

#define __STLSOFT_CF_STATIC_ASSERT_SUPPORT

/* Exception support */
#define __STLSOFT_CF_EXCEPTION_SUPPORT

/*  */
#define __STLSOFT_CF_FUNCTION_SIGNATURE_FULL_ARG_QUALIFICATION_REQUIRED

/* Namespace support */
//#define _STLSOFT_NO_NAMESPACES

#define __STLSOFT_CF_NAMESPACE_SUPPORT

#define STLSOFT_CF_ANONYMOUS_UNION_SUPPORT

/* Template support */
#define __STLSOFT_CF_TEMPLATE_SUPPORT

//#define STLSOFT_CF_TEMPLATE_TYPE_REQUIRED_IN_ARGS

#define __STLSOFT_CF_EXCEPTION_SIGNATURE_SUPPORT

#define __STLSOFT_CF_THROW_BAD_ALLOC

#define __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_FUNDAMENTAL_ARGUMENT_SUPPORT

#define __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT

#define STLSOFT_CF_MEM_FUNC_AS_TEMPLATE_PARAM_SUPPORT

#define __STLSOFT_CF_MEMBER_TEMPLATE_FUNCTION_SUPPORT

#define __STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT

#define __STLSOFT_CF_MEMBER_TEMPLATE_RANGE_METHOD_SUPPORT

#define __STLSOFT_CF_MEMBER_TEMPLATE_CLASS_SUPPORT

#define __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX

#define __STLSOFT_CF_TEMPLATE_PARTIAL_SPECIALISATION_SUPPORT

#define __STLSOFT_CF_TEMPLATE_OUTOFCLASSFN_QUALIFIED_TYPE_SUPPORT

#define __STLSOFT_CF_std_NAMESPACE

#if __GNUC__ >= 3
# define __STLSOFT_CF_std_char_traits_AVAILABLE
#endif /*  */

#define __STLSOFT_CF_ALLOCATOR_ALLOCATE_HAS_HINT

#define __STLSOFT_CF_ALLOCATOR_DEALLOCATE_HAS_OBJECTCOUNT

#define __STLSOFT_CF_BIDIRECTIONAL_ITERATOR_SUPPORT

#define __STLSOFT_CF_EXPLICIT_KEYWORD_SUPPORT

#define __STLSOFT_CF_MUTABLE_KEYWORD_SUPPORT

#define __STLSOFT_CF_TYPENAME_PARAM_KEYWORD_SUPPORT

#define __STLSOFT_CF_TYPENAME_TYPE_KEYWORD_SUPPORT

#define __STLSOFT_CF_TYPENAME_TYPE_DEF_KEYWORD_SUPPORT

//#define __STLSOFT_CF_TYPENAME_TYPE_MIL_KEYWORD_SUPPORT

//# define __STLSOFT_CF_MOVE_CONSTRUCTOR_SUPPORT

#define __STLSOFT_CF_KOENIG_LOOKUP_SUPPORT

#define __STLSOFT_CF_TEMPLATE_TEMPLATE_SUPPORT

#if __GNUC__ >= 3
# define __STLSOFT_CF_STATIC_ARRAY_SIZE_DETERMINATION_SUPPORT
#endif /* 2.95+ */

#if __GNUC__ >= 3
# define __STLSOFT_CF_VENEER_SUPPORT
#endif /*  */

// Shims are supported
//# define __STLSOFT_CF_TEMPLATE_SHIMS_NOT_SUPPORTED

#define __STLSOFT_CF_NEGATIVE_MODULUS_POSITIVE_GIVES_NEGATIVE_RESULT

#define STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT
#define STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT

#if defined(_STLSOFT_CUSTOM_ASSERT)
 /* You have defined the pre-processor symbol _STLSOFT_CUSTOM_ASSERT,
  * which stipulates that you will be providing your own assert. This
  * requires that you have defined _STLSOFT_CUSTOM_ASSERT() as a macro
  * taking 1 parameter (the condition to assert).
  *
  * Suppose you have a function _DisplayAssert(), which has the
  * following signature:
  *
  *   void _DisplayAssert(char const *file, int line, char const *expression);
  *
  * Presumably you would also have your own assert macro, say MY_ASSERT(),
  * defined as:
  *
  *   #define MY_ASSERT(_x) ((void)((!(_x)) ? ((void)(_DisplayAssert(__FILE__, __LINE__, #_x))) : ((void)0)))
  *
  * so you would simply need to define _STLSOFT_CUSTOM_ASSERT() in terms of
  * MY_ASSERT(), as in:
  *
  *  #define _STLSOFT_CUSTOM_ASSERT(_x)    MY_ASSERT(_x)
  *
  * where
  */
# define __STLSOFT_CF_ASSERT_SUPPORT
# define stlsoft_assert(_x)                     _STLSOFT_CUSTOM_ASSERT(_x)
# if defined(_STLSOFT_CUSTOM_ASSERT_INCLUDE)
#  define   __STLSOFT_CF_ASSERT_INCLUDE_NAME    _STLSOFT_CUSTOM_ASSERT_INCLUDE
# else
#  error You must define _STLSOFT_CUSTOM_ASSERT_INCLUDE along with _STLSOFT_CUSTOM_ASSERT()
# endif /* !_STLSOFT_CUSTOM_ASSERT_INCLUDE */
#else
# define __STLSOFT_CF_ASSERT_SUPPORT
//# define   __STLSOFT_CF_USE_cassert
# define __STLSOFT_CF_ASSERT_INCLUDE_NAME       <assert.h>
# define stlsoft_assert(_x)                     assert(_x)
#endif /* _STLSOFT_CUSTOM_ASSERT */

/* /////////////////////////////////////////////////////////////////////////////
 * Calling convention
 */

#define STLSOFT_CF_FASTCALL_SUPPORTED
#define STLSOFT_CF_STDCALL_SUPPORTED

/* /////////////////////////////////////////////////////////////////////////////
 * Inline assembler
 */

//#define STSLSOFT_INLINE_ASM_SUPPORTED
//#define STSLSOFT_ASM_IN_INLINE_SUPPORTED

/* /////////////////////////////////////////////////////////////////////////////
 * Compiler warning suppression
 */

/* ////////////////////////////////////////////////////////////////////////// */
