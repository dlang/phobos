/* /////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_current_directory_scope.h (formerly MLPwdScp.h, ::SynesisStd)
 *
 * Purpose:     Current working directory scoping class.
 *
 * Created:     12th November 1998
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


#ifndef _UNIXSTL_INCL_H_UNIXSTL_CURRENT_DIRECTORY_SCOPE
#define _UNIXSTL_INCL_H_UNIXSTL_CURRENT_DIRECTORY_SCOPE

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _UNIXSTL_VER_H_UNIXSTL_CURRENT_DIRECTORY_SCOPE_MAJOR    2
#define _UNIXSTL_VER_H_UNIXSTL_CURRENT_DIRECTORY_SCOPE_MINOR    4
#define _UNIXSTL_VER_H_UNIXSTL_CURRENT_DIRECTORY_SCOPE_REVISION 2
#define _UNIXSTL_VER_H_UNIXSTL_CURRENT_DIRECTORY_SCOPE_EDIT     51
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _UNIXSTL_INCL_H_WINSTL
# include "unixstl.h"                   // Include the UNIXSTL root header
#endif /* !_UNIXSTL_INCL_H_WINSTL */
#ifndef _UNIXSTL_INCL_H_UNIXSTL_FILESYSTEM_TRAITS
# include "unixstl_filesystem_traits.h" // file_traits
#endif /* !_UNIXSTL_INCL_H_UNIXSTL_FILESYSTEM_TRAITS */
#ifndef _STLSOFT_INCL_H_STLSOFT_STRING_ACCESS
# include "stlsoft_string_access.h"     // stlsoft::c_str_ptr
#endif /* !_STLSOFT_INCL_H_STLSOFT_STRING_ACCESS */
#ifndef _UNIXSTL_INCL_H_UNIXSTL_STRING_ACCESS
# include "unixstl_string_access.h"     // unixstl::c_str_ptr
#endif /* !_UNIXSTL_INCL_H_UNIXSTL_STRING_ACCESS */
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

stlsoft_ns_using(c_str_ptr)

/* ////////////////////////////////////////////////////////////////////////// */

/// \weakgroup libraries STLSoft Libraries
/// \brief The individual libraries

/// \weakgroup libraries_filesystem File-System Library
/// \ingroup libraries
/// \brief This library provides facilities for defining and manipulating file-system objects

/// \defgroup unixstl_filesystem_library File-System Library (UNIXSTL)
/// \ingroup UNIXSTL libraries_filesystem
/// \brief This library provides facilities for defining and manipulating UNIX file-system objects
/// @{

/* /////////////////////////////////////////////////////////////////////////////
 * basic_current_directory_scope
 *
 * This class pushes the given directory as the current directory upon
 * construction, and pops back to the original at destruction.
 */

/// \brief Current directory scoping class
///
/// This class scopes the process's current directory, by changing to the path
/// given in the constructor, and then, if that succeeded, changing back in the
/// destructor
///
/// \param C The character type (e.g. \c char, \c wchar_t)
/// \param T The file-system traits. In translators that support default template parameters that defaults to \c filesystem_traits<C>

template<   ss_typename_param_k C
#ifdef __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT
        ,   ss_typename_param_k T = filesystem_traits<C>
#else
        ,   ss_typename_param_k T /* = filesystem_traits<C> */
#endif /* __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT */
        >
class basic_current_directory_scope
{
public:
    typedef C                                       char_type;  /*!< The character type */
private:
    typedef T                                       traits_type;
    typedef basic_current_directory_scope<C, T>     class_type;

// Construction
public:
    /// \brief Constructs a scope instance and changes to the given directory
    ///
    /// \param dir The name of the directory to change the current directory to
    ss_explicit_k basic_current_directory_scope(char_type const *dir);
#if defined(__STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT)
    /// \brief Constructs a scope instance and changes to the given directory
    ///
    /// \param dir The name of the directory to change the current directory to
    template <ss_typename_param_k S>
    ss_explicit_k basic_current_directory_scope(S const &dir)
    {
        _init(c_str_ptr(dir));
    }
#endif /* __STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT */
    /// \brief Returns the current directory to its original location
    ~basic_current_directory_scope() unixstl_throw_0();

// Conversions
public:
    /// Returns a C-string pointer to the original directory
    operator char_type const *() const;

/// \name State
/// @{
private:
#ifdef STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT
    /// An opaque type to use for boolean evaluation
    struct boolean { int i; };
    typedef int boolean::*boolean_t;
#else /* ? STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT */
    typedef us_bool_t       boolean_t;
#endif /* STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT */
public:
    /// Indicates whether the construction was successful
    ///
    /// \retval true The scope instance was successfully constructed and the current directory changed as per the constructor argument
    /// \retval false The scope instance was not successfully constructed, and the current directory was unchanged.
    operator boolean_t () const;
#ifndef STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT
    /// Indicates whether the construction failed
    ///
    /// This method is the opposite of operator us_bool_t(), and the return values are inverted.
    us_bool_t operator !() const;
#endif /* !STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT */

/// @}

// Implementation
private:
    void _init(char_type const *dir);

// Members
private:
    char_type   m_previous[1 + PATH_MAX];

// Not to be implemented
private:
    basic_current_directory_scope();
    basic_current_directory_scope(class_type const &);
    class_type const &operator =(class_type const &);
};

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs for commonly encountered types
 */

/// Instantiation of the basic_current_directory_scope template for the ANSI character type \c char
typedef basic_current_directory_scope<us_char_a_t, filesystem_traits<us_char_a_t> >     current_directory_scope_a;
/// Instantiation of the basic_current_directory_scope template for the Unicode character type \c wchar_t
typedef basic_current_directory_scope<us_char_w_t, filesystem_traits<us_char_w_t> >     current_directory_scope_w;

/* /////////////////////////////////////////////////////////////////////////////
 * Implementation
 */

template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
inline void basic_current_directory_scope<C, T>::_init(ss_typename_type_k basic_current_directory_scope<C, T>::char_type const *dir)
{
    if( 0 == traits_type::get_current_directory(unixstl_num_elements(m_previous), m_previous) ||
        !traits_type::set_current_directory(dir))
    {
        m_previous[0] = '\0';
    }
}

template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
inline basic_current_directory_scope<C, T>::basic_current_directory_scope(ss_typename_type_k basic_current_directory_scope<C, T>::char_type const *dir)
{
    _init(c_str_ptr(dir));
}

template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
inline basic_current_directory_scope<C, T>::~basic_current_directory_scope() unixstl_throw_0()
{
    if(m_previous[0] != '\0')
    {
        traits_type::set_current_directory(m_previous);
    }
}

template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
inline basic_current_directory_scope<C, T>::operator ss_typename_type_k basic_current_directory_scope<C, T>::char_type const *() const
{
    return m_previous;
}

template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
inline basic_current_directory_scope<C, T>::operator ss_typename_type_k basic_current_directory_scope<C, T>::boolean_t () const
{
#ifdef STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT
    return m_previous[0] != '\0' ? &boolean::i : NULL;
#else /* ? STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT */
    return m_previous[0] != '\0';
#endif /* STLSOFT_CF_OPERATOR_BOOL_AS_OPERATOR_POINTER_TO_MEMBER_SUPPORT */
}

#ifndef STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT
template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
inline us_bool_t basic_current_directory_scope<C, T>::operator !() const
{
    return !operator us_bool_t();
}
#endif /* !STLSOFT_CF_OPERATOR_NOT_VIA_OPERATOR_POINTER_TO_MEMBER_SUPPORT */

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

#endif /* _UNIXSTL_INCL_H_UNIXSTL_CURRENT_DIRECTORY_SCOPE */

/* ////////////////////////////////////////////////////////////////////////// */
