/* /////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_environment_variable.h
 *
 * Purpose:     Simple class that provides access to an environment variable.
 *
 * Created:     2nd November 2003
 * Updated:     2nd November 2003
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


#ifndef _UNIXSTL_INCL_H_UNIXSTL_ENVIRONMENT_VARIABLE
#define _UNIXSTL_INCL_H_UNIXSTL_ENVIRONMENT_VARIABLE

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _UNIXSTL_VER_H_UNIXSTL_ENVIRONMENT_VARIABLE_MAJOR     1
#define _UNIXSTL_VER_H_UNIXSTL_ENVIRONMENT_VARIABLE_MINOR     3
#define _UNIXSTL_VER_H_UNIXSTL_ENVIRONMENT_VARIABLE_REVISION  1
#define _UNIXSTL_VER_H_UNIXSTL_ENVIRONMENT_VARIABLE_EDIT      14
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _UNIXSTL_INCL_H_UNIXSTL
# include "unixstl.h"                        // Include the WinSTL root header
#endif /* !_UNIXSTL_INCL_H_UNIXSTL */
#ifndef _UNIXSTL_INCL_H_UNIXSTL_SYSTEM_VERSION
# include "unixstl_filesystem_traits.h"      // Include the WinSTL get_environment_variable
#endif /* !_UNIXSTL_INCL_H_UNIXSTL_SYSTEM_VERSION */
#ifndef _STLSOFT_INCL_H_STLSOFT_STRING_ACCESS
# include "stlsoft_string_access.h"         // stlsoft::c_str_ptr
#endif /* !_STLSOFT_INCL_H_STLSOFT_STRING_ACCESS */
#ifndef _UNIXSTL_INCL_H_UNIXSTL_STRING_ACCESS
# include "unixstl_string_access.h"          // unixstl::c_str_ptr
#endif /* !_UNIXSTL_INCL_H_UNIXSTL_STRING_ACCESS */
#ifndef _STLSOFT_INCL_H_STLSOFT_AUTO_BUFFER
# include "stlsoft_auto_buffer.h"           // stlsoft::auto_buffer
#endif /* !_STLSOFT_INCL_H_STLSOFT_AUTO_BUFFER */
#ifndef _STLSOFT_INCL_H_STLSOFT_MALLOC_ALLOCATOR
# include "stlsoft_malloc_allocator.h"      // malloc_allocator
#endif /* _STLSOFT_INCL_H_STLSOFT_MALLOC_ALLOCATOR */

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

stlsoft_ns_using(c_str_ptr)

/* ////////////////////////////////////////////////////////////////////////// */

/// \weakgroup libraries STLSoft Libraries
/// \brief The individual libraries

/// \weakgroup libraries_system System Library
/// \ingroup libraries
/// \brief This library provides facilities for accessing system attributes

/// \defgroup unixstl_system_library System Library (WinSTL)
/// \ingroup WinSTL libraries_system
/// \brief This library provides facilities for accessing Win32 system attributes
/// @{

/* /////////////////////////////////////////////////////////////////////////////
 * basic_environment_variable
 *
 * This class converts a relative path to an absolute one, and effectively acts
 * as a C-string of its value.
 */

/// Represents an environment variable
///
/// \param C The character type
/// \param T The traits type. On translators that support default template arguments, this defaults to filesystem_traits<C>
template<   ss_typename_param_k C
#ifdef __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT
        ,   ss_typename_param_k T = filesystem_traits<C>
#else
        ,   ss_typename_param_k T /* = filesystem_traits<C> */
#endif /* __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT */
        >
class basic_environment_variable
{
public:
    /// The char type
    typedef C                                   char_type;
    /// The traits type
    typedef T                                   traits_type;
    /// The current parameterisation of the type
    typedef basic_environment_variable<C, T>    class_type;
    /// The size type
    typedef size_t                              size_type;

// Construction
public:
    /// Create an instance representing the given environment variable
    ss_explicit_k basic_environment_variable(char_type const *name)
        : m_buffer(1 + traits_type::get_environment_variable(name, 0, 0))
    {
        if( 0 == traits_type::get_environment_variable(name, m_buffer, m_buffer.size()) &&
            0 != m_buffer.size())
        {
            m_buffer[0] = 0;
        }
    }
#ifdef __STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT
    /// Create an instance representing the given environment variable
    template<ss_typename_param_k S>
    ss_explicit_k basic_environment_variable(S const &name)
        : m_buffer(1 + traits_type::get_environment_variable(c_str_ptr(name), 0, 0))
    {
        if( 0 == traits_type::get_environment_variable(c_str_ptr(name), m_buffer, m_buffer.size()) &&
            0 != m_buffer.size())
        {
            m_buffer[0] = 0;
        }
    }
#endif /* __STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT */

// Conversions
public:
    /// Implicit conversion to a non-mutable (const) pointer to the variable
    operator char_type const *() const
    {
        return m_buffer.data();
    }

// Attributes
public:
    /// Returns the length of the variable
    size_type length() const
    {
        return m_buffer.size() - 1;
    }

// Members
private:
    typedef stlsoft_ns_qual(auto_buffer)<char_type, malloc_allocator<char_type> >  buffer_t;

    buffer_t    m_buffer;

// Not to be implemented
private:
    basic_environment_variable(basic_environment_variable const &);
    basic_environment_variable &operator =(basic_environment_variable const &);
};

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs for commonly encountered types
 */

/// Instantiation of the basic_environment_variable template for the ANSI character type \c char
typedef basic_environment_variable<us_char_a_t, filesystem_traits<us_char_a_t> >     environment_variable_a;
/// Instantiation of the basic_environment_variable template for the Unicode character type \c wchar_t
typedef basic_environment_variable<us_char_w_t, filesystem_traits<us_char_w_t> >     environment_variable_w;

/* /////////////////////////////////////////////////////////////////////////////
 * Helper functions
 */

#if !defined(__STLSOFT_COMPILER_IS_MSVC) || \
    _MSC_VER >= 1100

/// This helper function makes an environment variable without needing to 
/// qualify the template parameter.
template<ss_typename_param_k C>
inline basic_environment_variable<C> make_environment_variable(C const *path)
{
    return basic_environment_variable<C>(path);
}

#endif /* !(_MSC_VER < 1100) */

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

#endif /* _UNIXSTL_INCL_H_UNIXSTL_ENVIRONMENT_VARIABLE */

/* ////////////////////////////////////////////////////////////////////////// */
