/* /////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_filesystem_traits.h
 *
 * Purpose:     Contains the filesystem_traits template class, and ANSI and
 *              Unicode specialisations thereof.
 *
 * Created:     15th November 2002
 * Updated:     3rd November 2003
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


#ifndef _UNIXSTL_INCL_H_UNIXSTL_FILESYSTEM_TRAITS
#define _UNIXSTL_INCL_H_UNIXSTL_FILESYSTEM_TRAITS

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _UNIXSTL_VER_H_UNIXSTL_FILESYSTEM_TRAITS_MAJOR      1
#define _UNIXSTL_VER_H_UNIXSTL_FILESYSTEM_TRAITS_MINOR      6
#define _UNIXSTL_VER_H_UNIXSTL_FILESYSTEM_TRAITS_REVISION   1
#define _UNIXSTL_VER_H_UNIXSTL_FILESYSTEM_TRAITS_EDIT       22
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _UNIXSTL_INCL_H_WINSTL
# include "unixstl.h"                        // Include the UNIXSTL root header
#endif /* !_UNIXSTL_INCL_H_WINSTL */
#include <stdlib.h>
#include <string.h>
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

/// \defgroup unixstl_filesystem_library File-System Library (UNIXSTL)
/// \ingroup UNIXSTL libraries_filesystem
/// \brief This library provides facilities for defining and manipulating UNIX file-system objects
/// @{

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 *
 * filesystem_traits                -   a traits template, along with
 * filesystem_traits<us_char_a_t>       and
 * filesystem_traits<us_char_w_t>
 */

/// \brief Traits class for file-system operations
/// 
/// \param C The character type (e.g. \c char, \c wchar_t)
template <ss_typename_param_k C>
#ifdef __STLSOFT_DOCUMENTATION_SKIP_SECTION
struct filesystem_traits
{
public:
    typedef C           char_type;  /*!< The character type */
    typedef us_size_t   size_type;  /*!< The size type */

public:
    // General string handling

    /// Copies the contents of \c src to \c dest
    static char_type    *str_copy(char_type *dest, char_type const *src);
    /// Appends the contents of \c src to \c dest
    static char_type    *str_cat(char_type *dest, char_type const *src);
    /// Comparies the contents of \c src and \c dest
    static us_int_t     str_compare(char_type const *s1, char_type const *s2);
    /// Evaluates the length of \c src
    static size_type    str_len(char_type const *src);

    // File-system entry names

    /// Appends a path name separator to \c dir if one does not exist
    static char_type    *ensure_dir_end(char_type *dir);
    /// Removes a path name separator to \c dir if one does not exist
    static char_type    *remove_dir_end(char_type *dir);
    /// Returns \c true if dir is \c "." or \c ".."
    static us_bool_t    is_dots(char_type const *dir);
    /// Returns the path separator
    ///
    /// This is the separator that is used to separate multiple paths on the operating system. On UNIX it is ':'
    static char_type    path_separator();
    /// Returns the path name separator
    ///
    /// This is the separator that is used to separate parts of a path on the operating system. On UNIX it is '/'
    static char_type    path_name_separator();
    /// Returns the wildcard pattern that represents all possible matches 
    ///
    /// \note On UNIX it is '*'
    static char_type const *pattern_all();
    /// Gets the full path name into the given buffer, returning a pointer to the file-part
    static us_size_t        get_full_path_name(char_type const *fileName, us_size_t cchBuffer, char_type *buffer, char_type **ppFile);
    /// Gets the full path name into the given buffer
    static us_size_t        get_full_path_name(char_type const *fileName, us_size_t cchBuffer, char_type *buffer);

    // File system state

    /// Sets the current directory to \c dir
    static us_bool_t    set_current_directory(char_type const *dir);
    /// Retrieves the name of the current directory into \c buffer up to a maximum of \c cchBuffer characters
    static us_uint_t    get_current_directory(us_uint_t cchBuffer, char_type *buffer);

    // Environment

    /// Gets an environment variable into the given buffer
    static us_uint_t    get_environment_variable(char_type const *name, char_type *buffer, us_uint_t cchBuffer);
    /// Expands environment strings in \c src into \dest, up to a maximum \c cchDest characters
    static us_uint_t    expand_environment_strings(char_type const *src, char_type *buffer, us_uint_t cchBuffer);
};
#else
struct filesystem_traits;

#ifdef __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX
template <>
#endif /* __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX */
struct filesystem_traits<us_char_a_t>
{
public:
    typedef us_char_a_t char_type;
    typedef us_size_t   size_type;

public:
    // General string handling
    static char_type *str_copy(char_type *dest, char_type const *src)
    {
        return strcpy(dest, src);
    }

    static char_type *str_cat(char_type *dest, char_type const *src)
    {
        return strcat(dest, src);
    }

    static us_int_t str_compare(char_type const *s1, char_type const *s2)
    {
        return strcmp(s1, s2);
    }

    static size_type str_len(char_type const *src)
    {
        return static_cast<size_type>(strlen(src));
    }

    // File-system entry names
    static char_type *ensure_dir_end(char_type *dir)
    {
        char_type   *end;

        for(end = dir; *end != '\0'; ++end)
        {}

        if( dir < end &&
            *(end - 1) != path_name_separator())
        {
            *end        =   path_name_separator();
            *(end + 1)  =   '\0';
        }

        return dir;
    }

    static char_type *remove_dir_end(char_type *dir)
    {
        char_type   *end;

        for(end = dir; *end != '\0'; ++end)
        {}

        if( dir < end &&
            *(end - 1) == path_name_separator())
        {
            *(end - 1)  =   '\0';
        }

        return dir;
    }

    static us_bool_t is_dots(char_type const *dir)
    {
        return  dir != 0 &&
                dir[0] == '.' &&
                (   dir[1] == '\0' ||
                    (    dir[1] == '.' &&
                        dir[2] == '\0'));
    }

    static char_type path_separator()
    {
        return ':';
    }

    static char_type path_name_separator()
    {
        return '/';
    }

    static char_type const *pattern_all()
    {
        return "*";
    }

    static us_size_t get_full_path_name(char_type const *fileName, us_size_t cchBuffer, char_type *buffer, char_type **ppFile);

    static us_size_t get_full_path_name(char_type const *fileName, us_size_t cchBuffer, char_type *buffer)
    {
        unixstl_assert(buffer != NULL);

        if(fileName[0] == path_name_separator())
        {
            str_copy(buffer, fileName);
        }
        else
        {
            get_current_directory(cchBuffer, buffer);
            if(0 != str_compare(fileName, "."))
            {
                ensure_dir_end(buffer);
                str_cat(buffer, fileName);
            }
        }

        return str_len(buffer);
    }

    // File system state
    static us_bool_t set_current_directory(char_type const *dir)
    {
        return chdir(dir) == 0;
    }

    static us_uint_t get_current_directory(us_uint_t cchBuffer, char_type *buffer)
    {
        return getcwd(buffer, cchBuffer) != 0;
    }

    // Environment

    static us_uint_t get_environment_variable(char_type const *name, char_type *buffer, us_uint_t cchBuffer)
    {
        char    *var = getenv(name);

        if(NULL == var)
        {
            return 0;
        }
        else
        {
            size_t  var_len = strlen(var);

            strncpy(buffer, var, cchBuffer);

            return (var_len < cchBuffer) ? var_len : cchBuffer;
        }
    }

    static us_uint_t expand_environment_strings(char_type const *src, char_type *buffer, us_uint_t cchBuffer);
};

#if 0
#ifdef __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX
template <>
#endif /* __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX */
struct filesystem_traits<us_char_w_t>
{
public:
    typedef us_char_w_t char_type;
    typedef us_size_t   size_type;

public:
    // General string handling
    static char_type *str_copy(char_type *dest, char_type const *src)
    {
        return wcscpy(dest, src);
    }

    static char_type *str_cat(char_type *dest, char_type const *src)
    {
        return wcscat(dest, src);
    }

    static us_int_t str_compare(char_type const *s1, char_type const *s2)
    {
        return wcscmp(s1, s2);
    }

    static size_type str_len(char_type const *src)
    {
        return static_cast<size_type>(wcslen(src));
    }

    // File-system entry names
    static char_type *ensure_dir_end(char_type *dir)
    {
        char_type   *end;

        for(end = dir; *end != L'\0'; ++end)
        {}

        if( dir < end &&
            *(end - 1) != path_name_separator())
        {
            *end        =   path_name_separator();
            *(end + 1)  =   L'\0';
        }

        return dir;
    }

    static char_type *remove_dir_end(char_type *dir)
    {
        char_type   *end;

        for(end = dir; *end != L'\0'; ++end)
        {}

        if( dir < end &&
            *(end - 1) == path_name_separator())
        {
            *(end - 1)  =   L'\0';
        }

        return dir;
    }

    static us_bool_t is_dots(char_type const *dir)
    {
        return  dir != 0 &&
                dir[0] == '.' &&
                (   dir[1] == L'\0' ||
                    (    dir[1] == L'.' &&
                        dir[2] == L'\0'));
    }

    static char_type path_separator()
    {
        return L':';
    }

    static char_type path_name_separator()
    {
        return L'/';
    }

    static char_type const *pattern_all()
    {
        return L"*";
    }

    static us_size_t get_full_path_name(char_type const *fileName, us_size_t cchBuffer, char_type *buffer, char_type **ppFile);
    static us_size_t get_full_path_name(char_type const *fileName, us_size_t cchBuffer, char_type *buffer)
    {
        char_type *pFile;

        return get_full_path_name(fileName, cchBuffer, buffer, &pFile);
    }

    // File system state
    static us_bool_t set_current_directory(char_type const *dir);

    static us_uint_t get_current_directory(us_uint_t cchBuffer, char_type *buffer);
};
#endif /* 0 */

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

#endif /* _UNIXSTL_INCL_H_UNIXSTL_FILESYSTEM_TRAITS */

/* ////////////////////////////////////////////////////////////////////////// */
