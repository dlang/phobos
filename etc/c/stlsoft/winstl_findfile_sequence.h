/* /////////////////////////////////////////////////////////////////////////////
 * File:        winstl_findfile_sequence.h
 *
 * Purpose:     Contains the basic_findfile_sequence template class, and ANSI
 *              and Unicode specialisations thereof.
 *
 * Notes:       1. The original implementation of the class had the const_iterator
 *              and value_type as nested classes. Unfortunately, Visual C++ 5 &
 *              6 both had either compilation or linking problems so these are
 *              regretably now implemented as independent classes.
 *
 *              2. This class was described in detail in the article
 *              "Adapting Windows Enumeration Models to STL Iterator Concepts"
 *              (http://www.windevnet.com/documents/win0303a/), in the March
 *              2003 issue of Windows Developer Network (http://windevnet.com).
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


#ifndef _WINSTL_INCL_H_WINSTL_FINDFILE_SEQUENCE
#define _WINSTL_INCL_H_WINSTL_FINDFILE_SEQUENCE

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define _WINSTL_VER_H_WINSTL_FINDFILE_SEQUENCE_MAJOR       1
# define _WINSTL_VER_H_WINSTL_FINDFILE_SEQUENCE_MINOR       17
# define _WINSTL_VER_H_WINSTL_FINDFILE_SEQUENCE_REVISION    3
# define _WINSTL_VER_H_WINSTL_FINDFILE_SEQUENCE_EDIT        80
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _WINSTL_INCL_H_WINSTL
# include "winstl.h"                    // Include the WinSTL root header
#endif /* !_WINSTL_INCL_H_WINSTL */
#ifndef _WINSTL_INCL_H_WINSTL_FILESYSTEM_TRAITS
# include "winstl_filesystem_traits.h"  // file_traits
#endif /* !_WINSTL_INCL_H_WINSTL_FILESYSTEM_TRAITS */
#ifndef _WINSTL_INCL_H_WINSTL_SYSTEM_VERSION
# include "winstl_system_version.h"     // winnt(), major()
#endif /* !_WINSTL_INCL_H_WINSTL_SYSTEM_VERSION */
#ifndef _STLSOFT_INCL_H_STLSOFT_ITERATOR
# include "stlsoft_iterator.h"          // iterator_base
#endif /* !_STLSOFT_INCL_H_STLSOFT_ITERATOR */

/* /////////////////////////////////////////////////////////////////////////////
 * Pre-processor
 *
 * Definition of the
 */

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
 * Forward declarations
 */

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION

template <ss_typename_param_k C, ss_typename_param_k T>
class basic_findfile_sequence_value_type;

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
class basic_findfile_sequence_const_input_iterator;

#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Utility classes
 */

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
struct ffs_shared_handle
{
    HANDLE      hSrch;
    ss_sint32_t cRefs;

public:
    ss_explicit_k ffs_shared_handle(HANDLE h)
        : hSrch(h)
        , cRefs(1)
    {}
    void Release()
    {
        if(--cRefs == 0)
        {
            delete this;
        }
    }
#if defined(__STLSOFT_COMPILER_IS_GCC)
protected:
#else /* ? __STLSOFT_COMPILER_IS_GCC */
private:
#endif /* __STLSOFT_COMPILER_IS_GCC */
    ~ffs_shared_handle()
    {
        winstl_message_assert("Shared search handle being destroyed with outstanding references!", 0 == cRefs);

        if(hSrch != INVALID_HANDLE_VALUE)
        {
            ::FindClose(hSrch);
        }
    }
};
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

// class basic_findfile_sequence
/// Presents an STL-like sequence interface over the items on the file-system
///
/// \param C The character type
/// \param T The traits type. On translators that support default template arguments this defaults to filesystem_traits<C>
///
/// \note  This class was described in detail in the article
/// "Adapting Windows Enumeration Models to STL Iterator Concepts"
/// (http://www.windevnet.com/documents/win0303a/), in the March 2003 issue of
/// Windows Developer Network (http://windevnet.com).
template<   ss_typename_param_k C
#ifdef __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT
        ,   ss_typename_param_k T = filesystem_traits<C>
#else
        ,   ss_typename_param_k T /* = filesystem_traits<C> */
#endif /* __STLSOFT_CF_TEMPLATE_CLASS_DEFAULT_CLASS_ARGUMENT_SUPPORT */
        >
class basic_findfile_sequence
{
public:
    /// The character type
    typedef C                                                                   char_type;
    /// The traits type
    typedef T                                                                   traits_type;
    /// The current parameterisation of the type
    typedef basic_findfile_sequence<C, T>                                       class_type;
    /// The value type
    typedef basic_findfile_sequence_value_type<C, T>                            value_type;
    /// The non-mutating (const) iterator type supporting the Input Iterator concept
    typedef basic_findfile_sequence_const_input_iterator<C, T, value_type>      const_input_iterator;
    /// The non-mutating (const) iterator type
    typedef const_input_iterator                                                const_iterator;
    /// The reference type
    typedef value_type                                                          &reference;
    /// The non-mutable (const) reference type
    typedef value_type const                                                    &const_reference;
    /// The find-data type
    typedef ss_typename_type_k traits_type::find_data_type                      find_data_type;
    /// The size type
    typedef ws_size_t                                                           size_type;

    enum
    {
            includeDots =   0x0008          //!< Causes the search to include the "." and ".." directories, which are elided by default
        ,   directories =   0x0010          //!< Causes the search to include directories
        ,   files       =   0x0020          //!< Causes the search to include files
#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
        ,   noSort      =   0 /* 0x0100 */  //!< 
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */
        ,
    };

// Construction
public:
    /// Commence a search according to the given search pattern and flags 
    ss_explicit_k basic_findfile_sequence(char_type const *searchSpec, ws_int_t flags = directories | files);
    /// Commence a search according to the given search pattern and flags, relative to \c directory
    basic_findfile_sequence(char_type const *directory, char_type const *searchSpec, ws_int_t flags = directories | files);
    /// Destructor
    ~basic_findfile_sequence() winstl_throw_0();

// Iteration
public:
    /// Begins the iteration
    ///
    /// \return An iterator representing the start of the sequence
    const_iterator      begin() const;
    /// Ends the iteration
    ///
    /// \return An iterator representing the end of the sequence
    const_iterator      end() const;

// Attributes
public:
    /// Returns the directory of the search
    ///
    /// \note Will be the empty string for instances created with the first constructor
    char_type const     *get_directory() const;

// State
public:
    /// Returns the number of items in the sequence
    size_type           size() const;
    /// Indicates whether the sequence is empty
    ws_bool_t           empty() const;
    /// Returns the maximum number of items in the sequence
    static size_type    max_size();

// Members
private:
    friend class basic_findfile_sequence_value_type<C, T>;
    friend class basic_findfile_sequence_const_input_iterator<C, T, value_type>;

    char_type       m_directory[_MAX_DIR + 1];
    char_type       m_subpath[_MAX_PATH + 1];
    char_type       m_search[_MAX_PATH + 1];
    ws_int_t        m_flags;

// Implementation
private:
    static ws_int_t validate_flags_(ws_int_t flags);
    static void     extract_subpath_(char_type *dest, char_type const *searchSpec);

    static  HANDLE  find_first_file_(char_type const *spec, ws_int_t flags, find_data_type *findData);
    HANDLE          begin_(find_data_type &findData) const;

// Not to be implemented
private:
    basic_findfile_sequence(class_type const &);
    basic_findfile_sequence const &operator =(class_type const &);
};

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs for commonly encountered types
 */

/// Instantiation of the basic_findfile_sequence template for the ANSI character type \c char
typedef basic_findfile_sequence<ws_char_a_t, filesystem_traits<ws_char_a_t> >     findfile_sequence_a;
/// Instantiation of the basic_findfile_sequence template for the Unicode character type \c wchar_t
typedef basic_findfile_sequence<ws_char_w_t, filesystem_traits<ws_char_w_t> >     findfile_sequence_w;
/// Instantiation of the basic_findfile_sequence template for the Win32 character type \c TCHAR
typedef basic_findfile_sequence<TCHAR, filesystem_traits<TCHAR> >                 findfile_sequence;

/* ////////////////////////////////////////////////////////////////////////// */

// class basic_findfile_sequence_value_type
/// Value type for the basic_findfile_sequence
template<   ss_typename_param_k C
        ,   ss_typename_param_k T
        >
class basic_findfile_sequence_value_type
{
public:
    /// The character type
    typedef C                                               char_type;
    /// The traits type
    typedef T                                               traits_type;
    /// The current parameterisation of the type
    typedef basic_findfile_sequence_value_type<C, T>        class_type;
    /// The find-data type
    typedef ss_typename_type_k traits_type::find_data_type  find_data_type;

public:
    /// Default constructor
    basic_findfile_sequence_value_type();
private:
    basic_findfile_sequence_value_type(find_data_type const &data, char_type const *path)
        : m_data(data)
    {
        traits_type::str_copy(m_path, path);
        traits_type::ensure_dir_end(m_path);
        traits_type::str_cat(m_path, data.cFileName);
    }
public:
    /// Denstructor
    ~basic_findfile_sequence_value_type() winstl_throw_0();

    /// Copy assignment operator
    class_type &operator =(class_type const &rhs);

    /// Returns a non-mutating reference to find-data
    find_data_type const    &get_find_data() const;
    /// Returns a non-mutating reference to find-data
    ///
    /// \deprecated This method may be removed in a future release. get_find_data() should be used instead
    find_data_type const    &GetFindData() const;   // Deprecated

    /// Returns the filename part of the item
    char_type const         *get_filename() const;
    /// Returns the short form of the filename part of the item
    char_type const         *get_short_filename() const;
    /// Returns the full path of the item
    char_type const         *get_path() const;

    /// Implicit conversion to a pointer-to-const of the full path
    operator char_type const * () const;

// Members
private:
    friend class basic_findfile_sequence_const_input_iterator<C, T, class_type>;

    find_data_type  m_data;
    char_type       m_path[_MAX_PATH + 1];
};

// class basic_findfile_sequence_const_input_iterator
/// Iterator type for the basic_findfile_sequence supporting the Input Iterator concept
template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
class basic_findfile_sequence_const_input_iterator
    : public stlsoft_ns_qual(iterator_base)<winstl_ns_qual_std(input_iterator_tag), V, ws_ptrdiff_t, void, V>
{
public:
    /// The character type
    typedef C                                                       char_type;
    /// The traits type
    typedef T                                                       traits_type;
    /// The value type
    typedef V                                                       value_type;
    /// The current parameterisation of the type
    typedef basic_findfile_sequence_const_input_iterator<C, T, V>   class_type;
    /// The find-data type
    typedef ss_typename_type_k traits_type::find_data_type          find_data_type;
private:
    typedef basic_findfile_sequence<C, T>                           sequence_type;

private:
    basic_findfile_sequence_const_input_iterator(sequence_type const &l, HANDLE hSrch, find_data_type const &data)
        : m_list(&l)
        , m_handle(new ffs_shared_handle(hSrch))
        , m_data(data)
    {}
    basic_findfile_sequence_const_input_iterator(sequence_type const &l);
public:
    /// Default constructor
    basic_findfile_sequence_const_input_iterator();
    /// <a href = "http://synesis.com.au/resources/articles/cpp/movectors.pdf">Move constructor</a>
    basic_findfile_sequence_const_input_iterator(class_type const &rhs);
    /// Denstructor
    ~basic_findfile_sequence_const_input_iterator() winstl_throw_0();

public:
    /// Pre-increment operator
    class_type &operator ++();
    /// Post-increment operator
    class_type operator ++(int);
    /// Dereference to return the value at the current position
    const value_type operator *() const;
    /// Evaluates whether \c this and \c rhs are equivalent
    ws_bool_t operator ==(class_type const &rhs) const;
    /// Evaluates whether \c this and \c rhs are not equivalent
    ws_bool_t operator !=(class_type const &rhs) const;

// Members
private:
    friend class basic_findfile_sequence<C, T>;

    sequence_type const * const                     m_list;
    ffs_shared_handle                               *m_handle;
    ss_typename_type_k traits_type::find_data_type  m_data;

// Not to be implemented
private:
    basic_findfile_sequence_const_input_iterator &operator =(class_type const &rhs);
};

///////////////////////////////////////////////////////////////////////////////
// Shims

template <ss_typename_param_k C, ss_typename_param_k T>
inline ws_bool_t is_empty(basic_findfile_sequence<C, T> const &s)
{
    return s.empty();
}

///////////////////////////////////////////////////////////////////////////////
// Implementation

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION

// basic_findfile_sequence

template <ss_typename_param_k C, ss_typename_param_k T>
inline /* static */ HANDLE basic_findfile_sequence<C, T>::find_first_file_(ss_typename_type_k basic_findfile_sequence<C, T>::char_type const *spec, ws_int_t flags, ss_typename_type_k basic_findfile_sequence<C, T>::find_data_type *findData)
{
    HANDLE  hSrch;

#if _WIN32_WINNT >= 0x0400
    if( (directories == (flags & (directories | files))) &&
        system_version::winnt() &&
        system_version::major() >= 4)
    {
        hSrch = traits_type::find_first_file_ex(spec, FindExSearchLimitToDirectories , findData);
    }
    else
#else
    ((void)flags);
#endif /* _WIN32_WINNT >= 0x0400 */
    {
        hSrch = traits_type::find_first_file(spec, findData);
    }

    return hSrch;
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline HANDLE basic_findfile_sequence<C, T>::begin_(ss_typename_type_k basic_findfile_sequence<C, T>::find_data_type &findData) const
{
    HANDLE  hSrch   =   find_first_file_(m_search, m_flags, &findData);

    if(hSrch != INVALID_HANDLE_VALUE)
    {
        // Now need to validate against the flags

        for(; hSrch != INVALID_HANDLE_VALUE; )
        {
            if((findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0)
            {
                // A file, and files requested, so break
                if(m_flags & files)
                {
                    break;
                }
            }
            else
            {
                if(traits_type::is_dots(findData.cFileName))
                {
                    if(m_flags & includeDots)
                    {
                        // A dots file, and dots are requested
                        break;
                    }
                }
                else if(m_flags & directories)
                {
                    // A directory, and directories requested
                    break;
                }
            }

            if(!traits_type::find_next_file(hSrch, &findData))
            {
                ::FindClose(hSrch);

                hSrch = INVALID_HANDLE_VALUE;

                break;
            }
        }
    }

    return hSrch;
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline /* static */ ws_int_t basic_findfile_sequence<C, T>::validate_flags_(ws_int_t flags)
{
    return (flags & (directories | files)) == 0 ? (flags | (directories | files)) : flags;
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline /* static */ void basic_findfile_sequence<C, T>::extract_subpath_(char_type *dest, char_type const *searchSpec)
{
    char_type   *pFile;

    traits_type::get_full_path_name(searchSpec, _MAX_PATH, dest, &pFile);

    if(pFile != 0)
    {
        *pFile = '\0';
    }
}

// Construction
template <ss_typename_param_k C, ss_typename_param_k T>
inline basic_findfile_sequence<C, T>::basic_findfile_sequence(char_type const *searchSpec, ws_int_t flags /* = directories | files */)
    : m_flags(validate_flags_(flags))
{
    m_directory[0] = '\0';

    traits_type::str_copy(m_search, searchSpec);

    extract_subpath_(m_subpath, searchSpec);
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline basic_findfile_sequence<C, T>::basic_findfile_sequence(char_type const *directory, char_type const * searchSpec, ws_int_t flags /* = directories | files */)
    : m_flags(validate_flags_(flags))
{
    traits_type::str_copy(m_directory, directory);

    traits_type::str_copy(m_search, directory);
    traits_type::ensure_dir_end(m_search);
    traits_type::str_cat(m_search, searchSpec);

    extract_subpath_(m_subpath, m_search);
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline basic_findfile_sequence<C, T>::~basic_findfile_sequence() winstl_throw_0()
{}

// Iteration
template <ss_typename_param_k C, ss_typename_param_k T>
inline ss_typename_type_k basic_findfile_sequence<C, T>::const_iterator basic_findfile_sequence<C, T>::begin() const
{
    ss_typename_type_k traits_type::find_data_type  findData;
    HANDLE                                          hSrch   =   begin_(findData);

    if(hSrch == INVALID_HANDLE_VALUE)
    {
        return const_input_iterator(*this);
    }
    else
    {
        return const_input_iterator(*this, hSrch, findData);
    }
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline ss_typename_type_k basic_findfile_sequence<C, T>::const_iterator basic_findfile_sequence<C, T>::end() const
{
    return const_input_iterator(*this);
}

// Attributes
template <ss_typename_param_k C, ss_typename_param_k T>
ss_typename_type_k basic_findfile_sequence<C, T>::char_type const *basic_findfile_sequence<C, T>::get_directory() const
{
    return m_directory;
}

// State
template <ss_typename_param_k C, ss_typename_param_k T>
inline ss_typename_type_k basic_findfile_sequence<C, T>::size_type basic_findfile_sequence<C, T>::size() const
{
    const_input_iterator    b   =   begin();
    const_input_iterator    e   =   end();
    size_type               c   =   0;

    for(; b != e; ++b)
    {
        ++c;
    }

    return c;
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline ws_bool_t basic_findfile_sequence<C, T>::empty() const
{
    return begin() == end();
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline /* static */ ss_typename_type_k basic_findfile_sequence<C, T>::size_type basic_findfile_sequence<C, T>::max_size()
{
    return static_cast<size_type>(-1);
}

// basic_findfile_sequence_value_type

template <ss_typename_param_k C, ss_typename_param_k T>
inline basic_findfile_sequence_value_type<C, T>::basic_findfile_sequence_value_type()
{
    m_data.dwFileAttributes         =   0xFFFFFFFF;
    m_data.cFileName[0]             =   '\0';
    m_data.cAlternateFileName[0]    =   '\0';
    m_path[0]                       =   '\0';
}


template <ss_typename_param_k C, ss_typename_param_k T>
inline basic_findfile_sequence_value_type<C, T>::~basic_findfile_sequence_value_type() winstl_throw_0()
{}

#if 0
template <ss_typename_param_k C, ss_typename_param_k T>
#ifdef __STLSOFT_CF_FUNCTION_SIGNATURE_FULL_ARG_QUALIFICATION_REQUIRED
inline basic_findfile_sequence_value_type<C, T>::operator basic_findfile_sequence_value_type<C, T>::char_type const *() const
#else
inline basic_findfile_sequence_value_type<C, T>::operator char_type const *() const
#endif /* __STLSOFT_CF_FUNCTION_SIGNATURE_FULL_ARG_QUALIFICATION_REQUIRED */
{
    return m_data.cFileName;
}
#endif /* 0 */

template <ss_typename_param_k C, ss_typename_param_k T>
inline ss_typename_type_k basic_findfile_sequence_value_type<C, T>::find_data_type const &basic_findfile_sequence_value_type<C, T>::get_find_data() const
{
    return m_data;
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline ss_typename_type_k basic_findfile_sequence_value_type<C, T>::find_data_type const &basic_findfile_sequence_value_type<C, T>::GetFindData() const
{
    return get_find_data();
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline ss_typename_type_k basic_findfile_sequence_value_type<C, T>::char_type const *basic_findfile_sequence_value_type<C, T>::get_filename() const
{
    return m_data.cFileName;
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline ss_typename_type_k basic_findfile_sequence_value_type<C, T>::char_type const *basic_findfile_sequence_value_type<C, T>::get_short_filename() const
{
    return m_data.cAlternateFileName[0] != '\0' ? m_data.cAlternateFileName : m_data.cFileName;
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline ss_typename_type_k basic_findfile_sequence_value_type<C, T>::char_type const *basic_findfile_sequence_value_type<C, T>::get_path() const
{
    return m_path;
}

template <ss_typename_param_k C, ss_typename_param_k T>
#if defined(__STLSOFT_COMPILER_IS_GCC) || \
    (   defined(__STLSOFT_COMPILER_IS_MSVC) && \
        _MSC_VER < 1100)
inline basic_findfile_sequence_value_type<C, T>::operator C const * () const
#else
inline basic_findfile_sequence_value_type<C, T>::operator ss_typename_type_k basic_findfile_sequence_value_type<C, T>::char_type const * () const
#endif /* !__GNUC__ */
{
    return get_path();
}

// operator == ()
template <ss_typename_param_k C, ss_typename_param_k T>
inline ws_bool_t operator == (basic_findfile_sequence_value_type<C, T> const &lhs, basic_findfile_sequence_value_type<C, T> const &rhs)
{
    return 0 == basic_findfile_sequence_value_type<C, T>::traits_type::str_compare(lhs.get_path(), rhs.get_path());
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline ws_bool_t operator == (basic_findfile_sequence_value_type<C, T> const &lhs, C const *rhs)
{
    return 0 == basic_findfile_sequence_value_type<C, T>::traits_type::str_compare(lhs.get_path(), rhs);
}

template <ss_typename_param_k C, ss_typename_param_k T>
inline ws_bool_t operator == (C const *lhs, basic_findfile_sequence_value_type<C, T> const &rhs)
{
    return 0 == basic_findfile_sequence_value_type<C, T>::traits_type::str_compare(lhs, rhs.get_path());
}

// basic_findfile_sequence_const_input_iterator

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
inline basic_findfile_sequence_const_input_iterator<C, T, V>::basic_findfile_sequence_const_input_iterator()
    : m_list(NULL)
    , m_handle(NULL)
{}

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
inline basic_findfile_sequence_const_input_iterator<C, T, V>::basic_findfile_sequence_const_input_iterator(sequence_type const &l)
    : m_list(&l)
    , m_handle(NULL)
{}

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
inline basic_findfile_sequence_const_input_iterator<C, T, V>::basic_findfile_sequence_const_input_iterator(class_type const &rhs)
    : m_list(rhs.m_list)
    , m_handle(rhs.m_handle)
    , m_data(rhs.m_data)
{
    if(NULL != m_handle)
    {
        ++m_handle->cRefs;
    }
}

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
inline ss_typename_type_k basic_findfile_sequence_const_input_iterator<C, T, V>::class_type &basic_findfile_sequence_const_input_iterator<C, T, V>::operator =(ss_typename_param_k basic_findfile_sequence_const_input_iterator<C, T, V>::class_type const &rhs)
{
    winstl_message_assert("Assigning iterators from separate sequences", m_list == rhs.m_list);    // Should only be comparing iterators from same container

    m_handle    =   rhs.m_handle;
    m_data      =   rhs.m_data;

    if(NULL != m_handle)
    {
        ++m_handle->cRefs;
    }

    return *this;
}

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
inline basic_findfile_sequence_const_input_iterator<C, T, V>::~basic_findfile_sequence_const_input_iterator() winstl_throw_0()
{
    if(NULL != m_handle)
    {
        m_handle->Release();
    }
}

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
inline ss_typename_type_k basic_findfile_sequence_const_input_iterator<C, T, V>::class_type &basic_findfile_sequence_const_input_iterator<C, T, V>::operator ++()
{
    ws_int_t    flags   =   m_list->m_flags;

    winstl_message_assert("Attempting to increment an invalid iterator!", NULL != m_handle);

    for(; m_handle->hSrch != INVALID_HANDLE_VALUE; )
    {
        if(!traits_type::find_next_file(m_handle->hSrch, &m_data))
        {
            m_handle->Release();

            m_handle = NULL;

            break;
        }
        else
        {
            if((m_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) == 0)
            {
                // A file, and files requested, so break
                if(flags & sequence_type::files)
                {
                    break;
                }
            }
            else
            {
                if(traits_type::is_dots(m_data.cFileName))
                {
                    if(flags & sequence_type::includeDots)
                    {
                        // A dots file, and dots are requested
                        break;
                    }
                }
                else if(flags & sequence_type::directories)
                {
                    // A directory, and directories requested
                    break;
                }
            }
        }
    }

    return *this;
}

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
inline ss_typename_type_k basic_findfile_sequence_const_input_iterator<C, T, V>::class_type basic_findfile_sequence_const_input_iterator<C, T, V>::operator ++(int)
{
    class_type  ret(*this);

    operator ++();

    return ret;
}

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
inline const ss_typename_type_k basic_findfile_sequence_const_input_iterator<C, T, V>::value_type basic_findfile_sequence_const_input_iterator<C, T, V>::operator *() const
{
    if(NULL != m_handle)
    {
        return value_type(m_data, m_list->m_subpath);
    }
    else
    {
        winstl_message_assert("Dereferencing end()-valued iterator", 0);

        return value_type();
    }
}

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
inline ws_bool_t basic_findfile_sequence_const_input_iterator<C, T, V>::operator ==(class_type const &rhs) const
{
    ws_bool_t    eq;

    // Should only be comparing iterators from same container
    winstl_message_assert("Comparing iterators from separate sequences", m_list == rhs.m_list);

    // Not equal if one but not both handles is the INVALID_HANDLE_VALUE
    // or if the data is not equal.
    if( (NULL == m_handle) != (NULL == rhs.m_handle) ||
        (   NULL != m_handle &&
            traits_type::str_compare(m_data.cFileName, rhs.m_data.cFileName) != 0))
    {
        eq = ws_false_v;
    }
    else
    {
        eq = ws_true_v;
    }

    return eq;
}

template <ss_typename_param_k C, ss_typename_param_k T, ss_typename_param_k V>
inline ws_bool_t basic_findfile_sequence_const_input_iterator<C, T, V>::operator !=(class_type const &rhs) const
{
    return ! operator ==(rhs);
}

#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

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

#endif /* _WINSTL_INCL_H_WINSTL_FINDFILE_SEQUENCE */

/* ////////////////////////////////////////////////////////////////////////// */
