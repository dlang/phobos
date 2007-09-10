/* /////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_functionals.h
 *
 * Purpose:     A number of useful functionals .
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


#ifndef _UNIXSTL_INCL_H_UNIXSTL_FUNCTIONALS
#define _UNIXSTL_INCL_H_UNIXSTL_FUNCTIONALS

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _UNIXSTL_VER_H_UNIXSTL_FUNCTIONALS_MAJOR    1
#define _UNIXSTL_VER_H_UNIXSTL_FUNCTIONALS_MINOR    0
#define _UNIXSTL_VER_H_UNIXSTL_FUNCTIONALS_REVISION 2
#define _UNIXSTL_VER_H_UNIXSTL_FUNCTIONALS_EDIT     3
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _UNIXSTL_INCL_H_UNIXSTL
# include "unixstl.h"                // Include the WinSTL root header
#endif /* !_UNIXSTL_INCL_H_UNIXSTL */
#ifndef _STLSOFT_INCL_H_STLSOFT_STRING_ACCESS
# include "stlsoft_string_access.h" // c_str_ptr, etc.
#endif /* !_STLSOFT_INCL_H_STLSOFT_STRING_ACCESS */
#ifndef _UNIXSTL_INCL_H_UNIXSTL_STRING_ACCESS
# include "unixstl_string_access.h"  // c_str_ptr, etc.
#endif /* !_UNIXSTL_INCL_H_UNIXSTL_STRING_ACCESS */
#ifndef _UNIXSTL_INCL_H_UNIXSTL_FILESYSTEM_TRAITS
# include "unixstl_filesystem_traits.h"
#endif /* !_UNIXSTL_INCL_H_UNIXSTL_FILESYSTEM_TRAITS */
#ifndef _UNIXSTL_FUNCTIONALS_NO_STD
# include <functional>
#endif /* _UNIXSTL_FUNCTIONALS_NO_STD */
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

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

/// Function object that compares two file-system paths
///
/// \param C The character type
template <ss_typename_param_k C>
struct compare_path
#ifndef _UNIXSTL_FUNCTIONALS_NO_STD
    : unixstl_ns_qual_std(binary_function)<const C *, const C *, us_bool_t>
#endif /* _UNIXSTL_FUNCTIONALS_NO_STD */
{
public:
    /// The character type
    typedef C                                                                       char_type;
#ifndef _UNIXSTL_FUNCTIONALS_NO_STD
private:
    typedef unixstl_ns_qual_std(binary_function)<const C *, const C *, us_bool_t>    parent_class_type;
public:
    /// The first argument type
    typedef ss_typename_type_k parent_class_type::first_argument_type               first_argument_type;
    /// The second argument type
    typedef ss_typename_type_k parent_class_type::second_argument_type              second_argument_type;
    /// The result type
    typedef ss_typename_type_k parent_class_type::result_type                       result_type;
#else
    /// The first argument type
    typedef const char_type                                                         *first_argument_type;
    /// The second argument type
    typedef const char_type                                                         *second_argument_type;
    /// The result type
    typedef us_bool_t                                                               result_type;
#endif /* _UNIXSTL_FUNCTIONALS_NO_STD */
    /// The traits type
    typedef filesystem_traits<C>                                                    traits_type;
    /// The current parameterisation of the type
    typedef compare_path<C>                                                         class_type;

public:
    /// Function call, compares \c s1 with \c s2
    ///
    /// \note The comparison is determined by evaluation the full-paths of both \c s1 and \c s2
#ifdef __STLSOFT_CF_MEMBER_TEMPLATE_FUNCTION_SUPPORT
    template <ss_typename_param_k T1, ss_typename_param_k T2>
    result_type operator ()(T1 const &s1, T2 const &s2)
    {
        return _compare(c_str_ptr(s1), c_str_ptr(s2));
    }
#else
    result_type operator ()(first_argument_type s1, second_argument_type s2)
    {
        return _compare(s1, s2);
    }
#endif /* __STLSOFT_CF_MEMBER_TEMPLATE_FUNCTION_SUPPORT */

// Implementation
private:
    result_type _compare(char_type const *s1, char_type const *s2)
    {
        char_type   path1[PATH_MAX + 1];
        char_type   path2[PATH_MAX + 1];
        result_type result;

        if(!traits_type::get_full_path_name(s1, unixstl_num_elements(path1), path1))
        {
            result = false;
        }
        else if(!traits_type::get_full_path_name(s2, unixstl_num_elements(path2), path2))
        {
            result = false;
        }
        else
        {
            traits_type::ensure_dir_end(path1);
            traits_type::ensure_dir_end(path2);

            result = traits_type::str_compare(path1, path2) == 0;
        }

        return result;
    }
};

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

#endif /* _UNIXSTL_INCL_H_UNIXSTL_FUNCTIONALS */

/* ////////////////////////////////////////////////////////////////////////// */
