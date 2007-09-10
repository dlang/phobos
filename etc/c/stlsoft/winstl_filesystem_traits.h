/* /////////////////////////////////////////////////////////////////////////////
 * File:        winstl_filesystem_traits.h
 *
 * Purpose:     Contains the filesystem_traits template class, and ANSI and
 *              Unicode specialisations thereof.
 *
 * Created:     15th November 2002
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


#ifndef _WINSTL_INCL_H_WINSTL_FILESYSTEM_TRAITS
#define _WINSTL_INCL_H_WINSTL_FILESYSTEM_TRAITS

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define _WINSTL_VER_H_WINSTL_FILESYSTEM_TRAITS_MAJOR       1
# define _WINSTL_VER_H_WINSTL_FILESYSTEM_TRAITS_MINOR       7
# define _WINSTL_VER_H_WINSTL_FILESYSTEM_TRAITS_REVISION    1
# define _WINSTL_VER_H_WINSTL_FILESYSTEM_TRAITS_EDIT        23
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _WINSTL_INCL_H_WINSTL
# include "winstl.h"                        // Include the WinSTL root header
#endif /* !_WINSTL_INCL_H_WINSTL */

/* /////////////////////////////////////////////////////////////////////////////
 * FindVolume API declarations
 *
 * The FindVolume API is not visible in the Windows headers unless _WIN32_WINNT
 * is defined as 0x0500 or greater. Where this definition is not present, the
 * functions are declared here, unless _WINSTL_NO_FINDVOLUME_API is defined.
 *
 * Where _WINSTL_NO_FINDVOLUME_API is defined, the requisite members of the
 * traits classes are undeclared.
 */

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION

#ifndef _WINSTL_NO_FINDVOLUME_API
# if !defined(_WIN32_WINNT) || \
     (_WIN32_WINNT < 0x0500)

HANDLE WINAPI FindFirstVolumeA(
  LPSTR lpszVolumeName,   // output buffer
  DWORD cchBufferLength    // size of output buffer
);

HANDLE WINAPI FindFirstVolumeW(
  LPWSTR lpszVolumeName,   // output buffer
  DWORD cchBufferLength    // size of output buffer
);

BOOL WINAPI FindNextVolumeA(
  HANDLE hFindVolume,      // volume search handle
  LPSTR lpszVolumeName,   // output buffer
  DWORD cchBufferLength    // size of output buffer
);

BOOL WINAPI FindNextVolumeW(
  HANDLE hFindVolume,      // volume search handle
  LPWSTR lpszVolumeName,   // output buffer
  DWORD cchBufferLength    // size of output buffer
);

BOOL WINAPI FindVolumeClose(
    HANDLE hFindVolume
    );

# endif /* _WIN32_WINNT < 0x0500 */
#endif /* !_WINSTL_NO_FINDVOLUME_API */

#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#ifndef _WINSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
/* There is no stlsoft namespace, so must define ::winstl */
namespace winstl
{
# else
/* Define stlsoft::winstl_project */

namespace stlsoft
{

namespace winstl_project
{

# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_WINSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

/// \weakgroup libraries STLSoft Libraries
/// \brief The individual libraries

/// \weakgroup libraries_filesystem File-System Library
/// \ingroup libraries
/// \brief This library provides facilities for defining and manipulating file-system objects

/// \weakgroup winstl_filesystem_library File-System Library (WinSTL)
/// \ingroup WinSTL libraries_filesystem
/// \brief This library provides facilities for defining and manipulating file-system objects for the Win32 API
/// @{

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

#ifdef __STLSOFT_DOCUMENTATION_SKIP_SECTION
/// Traits for accessing the correct file-system functions for a given character type
///
/// filesystem_traits is a traits class for determining the correct file-system 
/// structures and functions for a given character type.
///
/// \param C The character type
template <ss_typename_param_k C>
struct filesystem_traits
{
public:
    /// The character type
    typedef C               char_type;
    /// The size type
    typedef ws_size_t       size_type;
    /// The difference type
    typedef ws_ptrdiff_t    difference_type;
    /// The find data type
    typedef WIN32_FIND_DATA find_data_type;     // Placeholder only

public:
    // General string handling

    /// Copies the contents of \c src to \c dest
    static char_type    *str_copy(char_type *dest, char_type const *src);
    /// Appends the contents of \c src to \c dest
    static char_type    *str_cat(char_type *dest, char_type const *src);
    /// Comparies the contents of \c src and \c dest
    static ws_int_t     str_compare(char_type const *s1, char_type const *s2);
    /// Comparies the contents of \c src and \c dest in a case-insensitive fashion
    static ws_int_t     str_compare_no_case(char_type const *s1, char_type const *s2);
    /// Evaluates the length of \c src
    static size_type    str_len(char_type const *src);

    // File-system entry names

    /// Appends a file-system path separator to \c dir if one does not exist
    static char_type    *ensure_dir_end(char_type *dir);
    /// Returns \c true if dir is \c "." or \c ".."
    static ws_bool_t    is_dots(char_type const *dir);
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
    /// \note On Win32 it is '*.*'
    static char_type const *pattern_all();
    /// Gets the full path name into the given buffer, returning a pointer to the file-part
    static ws_dword_t   get_full_path_name(char_type const *fileName, ws_dword_t cchBuffer, char_type *buffer, char_type **ppFile);
    /// Gets the full path name into the given buffer
    static ws_dword_t   get_full_path_name(char_type const *fileName, ws_dword_t cchBuffer, char_type *buffer);
    /// Gets the short path name into the given buffer
    static ws_dword_t   get_short_path_name(char_type const *fileName, char_type *buffer, ws_dword_t cchBuffer);

    // FindFile() API

    /// Initiate a file-system search
    static HANDLE       find_first_file(char_type const *spec, find_data_type *findData);
#if _WIN32_WINNT >= 0x0400
    /// Initiate a file-system search - NT4+-only
    static HANDLE       find_first_file_ex(char_type const *spec, FINDEX_SEARCH_OPS flags, find_data_type *findData);
#endif /* _WIN32_WINNT >= 0x0400 */
    /// Advance a given file-system search
    static ws_bool_t    find_next_file(HANDLE h, find_data_type *findData);

    // FindVolume() API

#ifndef _WINSTL_NO_FINDVOLUME_API
    /// Initiate a file-system volume search
    static HANDLE       find_first_volume(char_type *volume_name, size_type cch_volume_name);
    /// Advance a given file-system volume search
    static ws_bool_t    find_next_volume(HANDLE h, char_type *volume_name, size_type cch_volume_name);
#endif // !_WINSTL_NO_FINDVOLUME_API

    // Modules

    /// Gets the full path name of the given module
    static ws_dword_t   get_module_filename(HINSTANCE hModule, char_type *buffer, ws_dword_t cchBuffer);
    /// Gets the full path name of the system directory
    static ws_uint_t    get_system_directory(char_type *buffer, ws_uint_t cchBuffer);
    /// Gets the full path name of the windows directory
    static ws_uint_t    get_windows_directory(char_type *buffer, ws_uint_t cchBuffer);

    // File system state

    /// Sets the current directory to \c dir
    static ws_bool_t    set_current_directory(char_type const *dir);
    /// Retrieves the name of the current directory into \c buffer up to a maximum of \c cchBuffer characters
    static ws_uint_t    get_current_directory(ws_uint_t cchBuffer, char_type *buffer);

	/// Returns whether a file exists or not
	static ws_bool_t	file_exists(char_type const *fileName);

    // Environment

    /// Gets an environment variable into the given buffer
    static ws_dword_t   get_environment_variable(char_type const *name, char_type *buffer, ws_uint_t cchBuffer);
    /// Expands environment strings in \c src into \dest, up to a maximum \c cchDest characters
    static ws_dword_t   expand_environment_strings(char_type const *src, char_type *buffer, ws_uint_t cchBuffer);
};

#else

template <ss_typename_param_k C>
struct filesystem_traits;

#ifdef __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX
template <>
#endif /* __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX */
struct filesystem_traits<ws_char_a_t>
{
public:
    typedef ws_char_a_t         char_type;
    typedef ws_size_t           size_type;
    typedef ws_ptrdiff_t        difference_type;
    typedef WIN32_FIND_DATAA    find_data_type;

public:
    // General string handling
    static char_type *str_copy(char_type *dest, char_type const *src)
    {
        return lstrcpyA(dest, src);
    }

    static char_type *str_cat(char_type *dest, char_type const *src)
    {
        return lstrcatA(dest, src);
    }

    static ws_int_t str_compare(char_type const *s1, char_type const *s2)
    {
        return lstrcmpA(s1, s2);
    }

    static ws_int_t str_compare_no_case(char_type const *s1, char_type const *s2)
    {
        return lstrcmpiA(s1, s2);
    }

    static size_type str_len(char_type const *src)
    {
        return static_cast<size_type>(lstrlenA(src));
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

    static ws_bool_t is_dots(char_type const *dir)
    {
        return  dir != 0 &&
                dir[0] == '.' &&
                (   dir[1] == '\0' ||
                    (    dir[1] == '.' &&
                        dir[2] == '\0'));
    }

    static char_type path_separator()
    {
        return ';';
    }

    static char_type path_name_separator()
    {
        return '\\';
    }

    static char_type const *pattern_all()
    {
        return "*.*";
    }

    static ws_dword_t get_full_path_name(char_type const *fileName, ws_dword_t cchBuffer, char_type *buffer, char_type **ppFile)
    {
        return ::GetFullPathNameA(fileName, cchBuffer, buffer, ppFile);
    }

    static ws_dword_t get_full_path_name(char_type const *fileName, ws_dword_t cchBuffer, char_type *buffer)
    {
        char_type *pFile;

        return get_full_path_name(fileName, cchBuffer, buffer, &pFile);
    }

    static ws_dword_t get_short_path_name(char_type const *fileName, char_type *buffer, ws_dword_t cchBuffer)
    {
        return ::GetShortPathNameA(fileName, buffer, cchBuffer);
    }

    // FindFile() API
    static HANDLE find_first_file(char_type const *spec, find_data_type *findData)
    {
        return ::FindFirstFileA(spec, findData);
    }

#if _WIN32_WINNT >= 0x0400
    static HANDLE find_first_file_ex(char_type const *spec, FINDEX_SEARCH_OPS flags, find_data_type *findData)
    {
        return ::FindFirstFileExA(spec, FindExInfoStandard, findData, flags, NULL, 0);
    }
#endif /* _WIN32_WINNT >= 0x0400 */

    static ws_bool_t find_next_file(HANDLE h, find_data_type *findData)
    {
        return ::FindNextFileA(h, findData) != FALSE;
    }

    // FindVolume() API
#ifndef _WINSTL_NO_FINDVOLUME_API
    static HANDLE find_first_volume(char_type *volume_name, size_type cch_volume_name)
    {
        return ::FindFirstVolumeA(volume_name, cch_volume_name);
    }

    static ws_bool_t find_next_volume(HANDLE h, char_type *volume_name, size_type cch_volume_name)
    {
        return ::FindNextVolumeA(h, volume_name, cch_volume_name) != FALSE;
    }
#endif // !_WINSTL_NO_FINDVOLUME_API

    // Modules
    static ws_dword_t get_module_filename(HINSTANCE hModule, char_type *buffer, ws_dword_t cchBuffer)
    {
        return ::GetModuleFileNameA(hModule, buffer, cchBuffer);
    }

    static ws_uint_t get_system_directory(char_type *buffer, ws_uint_t cchBuffer)
    {
        return ::GetSystemDirectoryA(buffer, cchBuffer);
    }

    static ws_uint_t get_windows_directory(char_type *buffer, ws_uint_t cchBuffer)
    {
        return ::GetWindowsDirectoryA(buffer, cchBuffer);
    }

    // File system state
    static ws_bool_t set_current_directory(char_type const *dir)
    {
        return ::SetCurrentDirectoryA(dir) != FALSE;
    }

    static ws_uint_t get_current_directory(ws_uint_t cchBuffer, char_type *buffer)
    {
        return ::GetCurrentDirectoryA(cchBuffer, buffer);
    }

	/// Returns whether a file exists or not
	static ws_bool_t file_exists(char_type const *fileName)
	{
		return 0xFFFFFFFF != ::GetFileAttributesA(fileName);
	}

    // Environment
    static ws_dword_t get_environment_variable(char_type const *name, char_type *buffer, ws_uint_t cchBuffer)
    {
        return ::GetEnvironmentVariableA(name, buffer, cchBuffer);
    }

    static size_type expand_environment_strings(char_type const *src, char_type *dest, size_type cch_dest)
    {
        return static_cast<size_type>(::ExpandEnvironmentStringsA(src, dest, cch_dest));
    }
};

#ifdef __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX
template <>
#endif /* __STLSOFT_CF_TEMPLATE_SPECIALISATION_SYNTAX */
struct filesystem_traits<ws_char_w_t>
{
public:
    typedef ws_char_w_t         char_type;
    typedef ws_size_t           size_type;
    typedef ws_ptrdiff_t        difference_type;
    typedef WIN32_FIND_DATAW    find_data_type;

public:
    // General string handling
    static char_type *str_copy(char_type *dest, char_type const *src)
    {
        return lstrcpyW(dest, src);
    }

    static char_type *str_cat(char_type *dest, char_type const *src)
    {
        return lstrcatW(dest, src);
    }

    static ws_int_t str_compare(char_type const *s1, char_type const *s2)
    {
        return lstrcmpW(s1, s2);
    }

    static ws_int_t str_compare_no_case(char_type const *s1, char_type const *s2)
    {
        return lstrcmpiW(s1, s2);
    }

    static size_type str_len(char_type const *src)
    {
        return static_cast<size_type>(lstrlenW(src));
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

    static ws_bool_t is_dots(char_type const *dir)
    {
        return  dir != 0 &&
                dir[0] == '.' &&
                (   dir[1] == L'\0' ||
                    (    dir[1] == L'.' &&
                        dir[2] == L'\0'));
    }

    static char_type path_separator()
    {
        return L';';
    }

    static char_type path_name_separator()
    {
        return L'\\';
    }

    static char_type const *pattern_all()
    {
        return L"*.*";
    }

    static ws_dword_t get_full_path_name(char_type const *fileName, ws_dword_t cchBuffer, char_type *buffer, char_type **ppFile)
    {
        winstl_message_assert("GetFullPathNameW() will crash when the file-name and buffer parameters are the same", fileName != buffer);

        return ::GetFullPathNameW(fileName, cchBuffer, buffer, ppFile);
    }

    static ws_dword_t get_full_path_name(char_type const *fileName, ws_dword_t cchBuffer, char_type *buffer)
    {
        char_type *pFile;

        return get_full_path_name(fileName, cchBuffer, buffer, &pFile);
    }

    static ws_dword_t get_short_path_name(char_type const *fileName, char_type *buffer, ws_dword_t cchBuffer)
    {
        return ::GetShortPathNameW(fileName, buffer, cchBuffer);
    }

    // FindFile() API
    static HANDLE find_first_file(char_type const *spec, find_data_type *findData)
    {
        return ::FindFirstFileW(spec, findData);
    }

#if _WIN32_WINNT >= 0x0400
    static HANDLE find_first_file_ex(char_type const *spec, FINDEX_SEARCH_OPS flags, find_data_type *findData)
    {
        return ::FindFirstFileExW(spec, FindExInfoStandard, findData, flags, NULL, 0);
    }
#endif /* _WIN32_WINNT >= 0x0400 */

    static ws_bool_t find_next_file(HANDLE h, find_data_type *findData)
    {
        return ::FindNextFileW(h, findData) != FALSE;
    }

    // FindVolume() API
#ifndef _WINSTL_NO_FINDVOLUME_API
    static HANDLE find_first_volume(char_type *volume_name, size_type cch_volume_name)
    {
        return ::FindFirstVolumeW(volume_name, cch_volume_name);
    }

    static ws_bool_t find_next_volume(HANDLE h, char_type *volume_name, size_type cch_volume_name)
    {
        return ::FindNextVolumeW(h, volume_name, cch_volume_name) != FALSE;
    }
#endif // !_WINSTL_NO_FINDVOLUME_API

    // Modules
    static ws_dword_t get_module_filename(HINSTANCE hModule, char_type *buffer, ws_dword_t cchBuffer)
    {
        return ::GetModuleFileNameW(hModule, buffer, cchBuffer);
    }

    static ws_uint_t get_system_directory(char_type *buffer, ws_uint_t cchBuffer)
    {
        return ::GetSystemDirectoryW(buffer, cchBuffer);
    }

    static ws_uint_t get_windows_directory(char_type *buffer, ws_uint_t cchBuffer)
    {
        return ::GetWindowsDirectoryW(buffer, cchBuffer);
    }

    // File system state
    static ws_bool_t set_current_directory(char_type const *dir)
    {
        return ::SetCurrentDirectoryW(dir) != FALSE;
    }

    static ws_uint_t get_current_directory(ws_uint_t cchBuffer, char_type *buffer)
    {
        return ::GetCurrentDirectoryW(cchBuffer, buffer);
    }

	/// Returns whether a file exists or not
	static ws_bool_t file_exists(char_type const *fileName)
	{
		return 0xFFFFFFFF != ::GetFileAttributesW(fileName);
	}

    // Environment
    static ws_dword_t get_environment_variable(char_type const *name, char_type *buffer, ws_uint_t cchBuffer)
    {
        return ::GetEnvironmentVariableW(name, buffer, cchBuffer);
    }

    static size_type expand_environment_strings(char_type const *src, char_type *dest, size_type cch_dest)
    {
        return static_cast<size_type>(::ExpandEnvironmentStringsW(src, dest, cch_dest));
    }
};

#endif /* __STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* ////////////////////////////////////////////////////////////////////////// */

/// @} // end of group winstl_filesystem_library

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _WINSTL_NO_NAMESPACE
# ifdef _STLSOFT_NO_NAMESPACE
} // namespace winstl
# else
} // namespace winstl_project
} // namespace stlsoft
# endif /* _STLSOFT_NO_NAMESPACE */
#endif /* !_WINSTL_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* _WINSTL_INCL_H_WINSTL_FILESYSTEM_TRAITS */

/* ////////////////////////////////////////////////////////////////////////// */
