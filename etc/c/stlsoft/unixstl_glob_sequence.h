/* /////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_glob_sequence.h (formerly unixstl_findfile_sequence.h)
 *
 * Purpose:     glob_sequence class.
 *
 * Created:     15th January 2002
 * Updated:     10th November 2003
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


#ifndef _INCL_UNIXSTL_H_UNIXSTL_GLOB_SEQUENCE
#define _INCL_UNIXSTL_H_UNIXSTL_GLOB_SEQUENCE

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
#define _UNIXSTL_VER_H_UNIXSTL_GLOB_SEQUENCE_MAJOR      2
#define _UNIXSTL_VER_H_UNIXSTL_GLOB_SEQUENCE_MINOR      1
#define _UNIXSTL_VER_H_UNIXSTL_GLOB_SEQUENCE_REVISION   4
#define _UNIXSTL_VER_H_UNIXSTL_GLOB_SEQUENCE_EDIT       46
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _INCL_UNIXSTL_H_UNIXSTL
# include "unixstl.h"                   // Include the UNIXSTL root header
#endif /* !_INCL_UNIXSTL_H_UNIXSTL */
#ifndef _INCL_UNIXSTL_H_UNIXSTL_FILESYSTEM_TRAITS
# include "unixstl_filesystem_traits.h" // filesystem_traits
#endif /* !_INCL_UNIXSTL_H_UNIXSTL_FILESYSTEM_TRAITS */
#ifndef _STLSOFT_INCL_H_STLSOFT_ITERATOR
# include "stlsoft_iterator.h"
#endif /* !_STLSOFT_INCL_H_STLSOFT_ITERATOR */
#include <sys/types.h>
#include <sys/stat.h>
#include <glob.h>

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 *
 * The UNIXSTL components are contained within the unixstl namespace. This is
 * actually an alias for stlsoft::unixstl_project,
 *
 * The definition matrix is as follows:
 *
 * _STLSOFT_NO_NAMESPACE    _UNIXSTL_NO_NAMESPACE   unixstl definition
 * ---------------------    ---------------------   -----------------
 *  not defined              not defined             = stlsoft::unixstl_project
 *  not defined              defined                 not defined
 *  defined                  not defined             unixstl
 *  defined                  defined                 not defined
 *
 */

/* No STLSoft namespaces means no UNIXSTL namespaces */
#ifdef _STLSOFT_NO_NAMESPACES
# define _UNIXSTL_NO_NAMESPACES
#endif /* _STLSOFT_NO_NAMESPACES */

/* No UNIXSTL namespaces means no unixstl namespace */
#ifdef _UNIXSTL_NO_NAMESPACES
# define _UNIXSTL_NO_NAMESPACE
#endif /* _UNIXSTL_NO_NAMESPACES */

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
 */

/// \brief STL-like readonly sequence based on the results of file-system wildcard matches
///
/// This class presents and STL-like readonly sequence interface to allow the 
/// iteration over the results of file-system wildcard matches.

class glob_sequence
{
private:
    typedef glob_sequence       class_type;
public:
    /// The char type
    typedef us_char_a_t         char_type;
    /// The value type
    typedef char_type const     *value_type;
    /// The type of the const (non-mutating) iterator
    typedef value_type          *const_iterator;
private:
//    typedef value_type          &reference;
    typedef value_type const    &const_reference;
//    typedef value_type          *pointer;
    typedef value_type const    *const_pointer;
public:
    /// The size type
    typedef us_size_t           size_type;
    /// The difference type
    typedef us_ptrdiff_t        difference_type;

    /// The type of the const (non-mutating) reverse iterator
    typedef stlsoft_ns_qual(reverse_iterator_base)  <   const_iterator
                                                    ,   value_type
                                                    ,   const_reference
                                                    ,   const_pointer
                                                    ,   difference_type
                                                    >   const_reverse_iterator;

public:
    enum
    {
            includeDots =   0x0008  /*!< Requests that dots directories be included in the returned sequence */
        ,   directories =   0x0010  /*!< Causes the search to include directories */
        ,   files       =   0x0020  /*!< Causes the search to include files */
        ,   noSort      =   0x0100  /*!< Does not sort entries */
        ,   markDirs    =   0x0200  /*!< Mark directories with a trailing path name separator */
        ,
    };

// Construction
public:
    /// \brief Constructs a sequence according to the given criteria
    ///
    /// The constructor initialises a glob_sequence instance on the given
    /// pattern with the given flags.
    ///
    /// \param pattern The pattern against which to match the file-system contents
    /// \param flags Flags to alter the behaviour of the search
    ss_explicit_k glob_sequence(char_type const *pattern, us_int_t flags = noSort)
        : m_flags(validate_flags_(flags))
    {
        m_cItems = _init(pattern);
    }

    /// \brief Constructs a sequence according to the given criteria
    ///
    /// The constructor initialises a glob_sequence instance on the given
    /// pattern with the given flags.
    ///
    /// \param directory The directory in which the pattern is located
    /// \param pattern The pattern against which to match the file-system contents
    /// \param flags Flags to alter the behaviour of the search
    glob_sequence(char_type const *directory, char_type const *pattern, us_int_t flags = noSort)
        : m_flags(validate_flags_(flags))
    {
        m_cItems = _init(directory, pattern);
    }

    // Releases any acquired resources
    ~glob_sequence() unixstl_throw_0()
    {
        if(NULL != m_base)
        {
            globfree(&m_gl);
        }
    }

// Attributes
public:
    /// Returns the number of elements in the sequence
    us_size_t size() const
    {
        return m_cItems;
    }

    /// \brief Indicates whether the search sequence is empty
    us_bool_t empty() const
    {
        return size() == 0;
    }

    /// \brief Returns the value corresponding to the given index
    ///
    /// \note In debug-mode a runtime assert is applied to enforce that the index is valid. There is <b>no</b> release-time checking on the index validity!
    value_type const operator [](size_type index) const
    {
        unixstl_message_assert("index access out of range in glob_sequence", index < m_cItems + 1);   // Has to be +1, since legitimate to take address of one-past-the-end

        return m_base[index];
    }

// Iteration
public:
    /// Begins the iteration
    ///
    /// \return An iterator representing the start of the sequence
    const_iterator  begin() const
    {
        return m_base;
    }
    /// Ends the iteration
    ///
    /// \return An iterator representing the end of the sequence
    const_iterator  end() const
    {
        return m_base + m_cItems;
    }

    /// Begins the reverse iteration
    ///
    /// \return An iterator representing the start of the reverse sequence
    const_reverse_iterator  rbegin() const
    {
        return const_reverse_iterator(end());
    }
    /// Ends the reverse iteration
    ///
    /// \return An iterator representing the end of the reverse sequence
    const_reverse_iterator  rend() const
    {
        return const_reverse_iterator(begin());
    }

// Implementation
private:
    static us_int_t validate_flags_(us_int_t flags)
    {
        if((flags & (directories | files)) == 0)
        {
            flags |= (directories | files);
        }

        if((flags & directories) == 0)
        {
            // It's more efficient to not bother doing a separate dots check if all
            // directories are being elided.
//          flags |= includeDots;
        }

        return flags;
    }

    // Returns true if pch == "" or "/" (or "\\"), false otherwise
    static us_bool_t _is_end_of_path_elements(char_type const *pch, difference_type index)
    {
        return  pch[index] == '\0' ||
                (   pch[index + 1] == '\0' &&
                    (
#if defined(_UNIXSTL_COMPILER_IS_UNKNOWN) && \
    !defined(_UNIXSTL_GLOB_SEQUENCE_NO_BACK_SLASH_TERMINATOR)
                        pch[index] == '\\' ||
#endif /* _UNIXSTL_COMPILER_IS_UNKNOWN && !_UNIXSTL_GLOB_SEQUENCE_NO_BACK_SLASH_TERMINATOR */
                        pch[index] == '/'));
    }

    static us_bool_t _is_dots(char_type const *s, us_bool_t &bTwoDots)
    {
        return  s != 0 &&
                s[0] == '.' &&
                (   (bTwoDots = false, _is_end_of_path_elements(s, 1)) ||
                    (bTwoDots = true, ( s[1] == '.' &&
                                        _is_end_of_path_elements(s, 2))));
    }

    us_int_t _init(char_type const *directory, char_type const *pattern)
    {
        us_int_t    glob_flags  =   0;
        char_type   _directory[1 + PATH_MAX];
        char_type   _pattern[1 + PATH_MAX];

        // If a directory is given, always turn it into an absolute directory
        if( NULL != directory &&
            0 != *directory)
        {
            filesystem_traits<char_type>::str_copy(_directory, directory);
            filesystem_traits<char_type>::ensure_dir_end(_directory);
            directory = _directory;
        }

        // If a directory is given, always prefix into pattern
        if( NULL != directory &&
            0 != *directory)
        {
            filesystem_traits<char_type>::str_copy(_pattern, directory);
            filesystem_traits<char_type>::str_cat(_pattern, pattern);

            pattern = _pattern;
        }

        if(m_flags & noSort)
        {
            glob_flags |= GLOB_NOSORT;
        }

        if(m_flags & markDirs)
        {
            glob_flags |= GLOB_MARK;
        }

        if((m_flags & (directories | files)) == directories)
        {
            glob_flags |= GLOB_ONLYDIR;
        }

        if(0 == glob(pattern, glob_flags, NULL, &m_gl))
        {
            char_type   **base  =   m_gl.gl_pathv;
            us_int_t    cItems  =   m_gl.gl_pathc;

            if(!(m_flags & includeDots))
            {
                // Now remove the dots. If located at the start of
                // the gl buffer, then simply increment m_base to
                // be above that. If not then rearrange the base
                // two pointers such that they are there.

                us_bool_t   foundDot1   =   false;
                us_bool_t   foundDot2   =   false;
                char_type   **begin     =   base;
                char_type   **end       =   begin + cItems;

                for(; begin != end; ++begin)
                {
                    us_bool_t   bTwoDots;

                    if(_is_dots(*begin, bTwoDots))
                    {
                        if(begin != base)
                        {
                            // Swap with whatever is at base[0]
                            char_type   *t  =   *begin;

                            *begin  = *base;
                            *base   = t;
                        }

                        ++base;
                        --cItems;

                        (bTwoDots ? foundDot2 : foundDot1) = true;

                        if( foundDot1 &&
                            foundDot2)
                        {
                            break;
                        }
                    }
                }
            }

            // We should be able to trust glob() to return only directories when
            // asked, so we assume the following only needs to be done when
            // have asked for files alone
#ifdef UNIXSTL_GLOB_SEQUENCE_ULTRA_CAUTIOUS
            if((m_flags & (directories | files)) != (directories | files))
#else /* ? UNIXSTL_GLOB_SEQUENCE_ULTRA_CAUTIOUS */
            if((m_flags & (directories | files)) == files)
#endif /* UNIXSTL_GLOB_SEQUENCE_ULTRA_CAUTIOUS */
            {
                char_type   **begin     =   base;
                char_type   **end       =   begin + cItems;

                for(; begin != end; ++begin)
                {
                    // Now need to process the file, by using stat
                    struct stat st;
                    int         res;    
                    char_type   buffer[PATH_MAX];
                    char_type   *entry      =   *begin;

                    if(0 != (m_flags & markDirs))
                    {
                        filesystem_traits<char_type>::str_copy(buffer, entry);
                        filesystem_traits<char_type>::remove_dir_end(buffer);
                        entry = buffer;
                    }
                    res = stat(entry, &st);
                    
                    if(0 != res)
                    {
                        // Failed to get info from entry. Must assume it is
                        // dead, so skip it
                    }
                    else
                    {
#ifdef UNIXSTL_GLOB_SEQUENCE_ULTRA_CAUTIOUS
                        if(m_flags & directories) // Want directories
                        {
                            if(S_IFDIR == (st.st_mode & S_IFDIR))
                            {
                                continue; // A directory, so accept it
                            }
                        }
#endif /* UNIXSTL_GLOB_SEQUENCE_ULTRA_CAUTIOUS */
                        if(m_flags & files) // Want files
                        {
                            if(S_IFREG == (st.st_mode & S_IFREG))
                            {
                                continue; // A file, so accept it
                            }
                        }
                    }

                    if(begin != base)
                    {
                        // Swap with whatever is at base[0]
                        char_type   *t  =   *begin;

                        *begin  = *base;
                        *base   = t;
                    }

                    ++base;
                    --cItems;
                }
            }

            // Set m_base and m_cItems to the correct values, with
            // or without dots. m_base is cast here to remove the
            // need for const-casting throughout the rest of the
            // class
            m_base      =   const_cast<char_type const **>(base);

            return cItems;
        }
        else
        {
            m_base = NULL;

            return 0;
        }
    }

    us_int_t _init(char_type const *pattern)
    {
        return _init(NULL, pattern);
    }

// Members
private:
    us_int_t const  m_flags;
    glob_t          m_gl;
    char_type const **m_base;
    us_int_t        m_cItems;

// Not to be implemented
private:
    glob_sequence(class_type const &);
    class_type const &operator =(class_type const &);
};

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

#endif /* !_INCL_UNIXSTL_H_UNIXSTL_GLOB_SEQUENCE */

/* ////////////////////////////////////////////////////////////////////////// */
