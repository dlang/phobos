/* /////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_current_directory.h
 *
 * Purpose:     Simple class that gets, and makes accessible, the current
 *              directory.
 *
 * Created:     1st November 2003
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


#ifndef _UNIXSTL_INCL_H_UNIXSTL_CURRENT_DIRECTORY
#define _UNIXSTL_INCL_H_UNIXSTL_CURRENT_DIRECTORY

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _UNIXSTL_VER_H_UNIXSTL_CURRENT_DIRECTORY_MAJOR      1
#define _UNIXSTL_VER_H_UNIXSTL_CURRENT_DIRECTORY_MINOR      0
#define _UNIXSTL_VER_H_UNIXSTL_CURRENT_DIRECTORY_REVISION   2
#define _UNIXSTL_VER_H_UNIXSTL_CURRENT_DIRECTORY_EDIT       2
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _UNIXSTL_INCL_H_UNIXSTL
# include "unixstl.h"                   // Include the WinSTL root header
#endif /* !_UNIXSTL_INCL_H_UNIXSTL */
#ifndef _UNIXSTL_INCL_H_UNIXSTL_FILESYSTEM_TRAITS
# include "unixstl_filesystem_traits.h" // file_traits
#endif /* !_UNIXSTL_INCL_H_UNIXSTL_FILESYSTEM_TRAITS */
#include <unistd.h>

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

/* ////////////////////////////////////////////////////////////////////////// */

/// \weakgroup libraries STLSoft Libraries
/// \brief The individual libraries

/// \weakgroup libraries_filesystem File-System Library
/// \ingroup libraries
/// \brief This library provides facilities for defining and manipulating file-system objects

/// \weakgroup unixstl_filesystem_library File-System Library (WinSTL)
/// \ingroup WinSTL libraries_filesystem
/// \brief This library provides facilities for defining and manipulating file-system objects for the Win32 API
/// @{

/* /////////////////////////////////////////////////////////////////////////////
 * basic_current_directory
 *
 * This class wraps the GetCurrentDirectory() API function, and effectively acts
 * as a C-string of its value.
 */

/// Represents the current directory
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
class basic_current_directory
{
public:
    /// The char type
    typedef C                               char_type;
    /// The traits type
    typedef T                               traits_type;
    /// The current parameterisation of the type
    typedef basic_current_directory<C, T>   class_type;
    /// The size type
    typedef us_size_t                       size_type;

// Construction
public:
    /// Default constructor
    basic_current_directory();

// Operations
public:
    /// Gets the current directory into the given buffer
    static size_type   get_path(char_type *buffer, size_type cchBuffer);

// Attributes
public:
    /// Returns a non-mutable (const) pointer to the path
    char_type const *get_path() const;
    /// Returns the length of the converted path
    size_type       length() const;

// Conversions
public:
    /// Implicit conversion to a non-mutable (const) pointer to the path
    operator char_type const *() const
    {
        return get_path();
    }

// Members
private:
    char_type       m_dir[1 + PATH_MAX];
    size_type const m_len;

// Not to be implemented
private:
    basic_current_directory(const class_type &);
    basic_current_directory &operator =(const class_type &);
};

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs for commonly encountered types
 */

/// Instantiation of the basic_current_directory template for the ANSI character type \c char
typedef basic_current_directory<us_char_a_t, filesystem_traits<us_char_a_t> >     current_directory_a;
/// Instantiation of the basic_current_directory template for the Unicode character type \c wchar_t
typedef basic_current_directory<us_char_w_t, filesystem_traits<us_char_w_t> >     current_directory_w;

/* /////////////////////////////////////////////////////////////////////////////
 * Implementation
 */

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION

template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
inline basic_current_directory<C, T>::basic_current_directory()
    : m_len(get_path(m_dir, unixstl_num_elements(m_dir)))
{}

template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
inline /* static */ ss_typename_type_k basic_current_directory<C, T>::size_type basic_current_directory<C, T>::get_path(ss_typename_type_k basic_current_directory<C, T>::char_type *buffer, ss_typename_type_k basic_current_directory<C, T>::size_type cchBuffer)
{
    return static_cast<size_type>(traits_type::get_current_directory(cchBuffer, buffer));
}

template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
inline ss_typename_type_k basic_current_directory<C, T>::char_type const *basic_current_directory<C, T>::get_path() const
{
    return m_dir;
}

template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
inline ss_typename_type_k basic_current_directory<C, T>::size_type basic_current_directory<C, T>::length() const
{
    return m_len;
}

#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* ////////////////////////////////////////////////////////////////////////// */

/// @} // end of group unixstl_filesystem_library

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

#endif /* _UNIXSTL_INCL_H_UNIXSTL_CURRENT_DIRECTORY */

/* ////////////////////////////////////////////////////////////////////////// */
