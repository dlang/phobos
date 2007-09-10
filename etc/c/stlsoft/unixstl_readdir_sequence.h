/* /////////////////////////////////////////////////////////////////////////////
 * File:        unixstl_readdir_sequence.h
 *
 * Purpose:     readdir_sequence class.
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


#ifndef _INCL_UNIXSTL_H_UNIXSTL_READDIR_SEQUENCE
#define _INCL_UNIXSTL_H_UNIXSTL_READDIR_SEQUENCE

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define _UNIXSTL_VER_H_UNIXSTL_READDIR_SEQUENCE_MAJOR      1
# define _UNIXSTL_VER_H_UNIXSTL_READDIR_SEQUENCE_MINOR      5
# define _UNIXSTL_VER_H_UNIXSTL_READDIR_SEQUENCE_REVISION   2
# define _UNIXSTL_VER_H_UNIXSTL_READDIR_SEQUENCE_EDIT       42
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _INCL_UNIXSTL_H_UNIXSTL
# include "unixstl.h"               // Include the UNIXSTL root header
#endif /* !_INCL_UNIXSTL_H_UNIXSTL */
#ifndef _INCL_UNIXSTL_H_UNIXSTL_LIMITS
# include "unixstl_limits.h"        // UNIXSTL_NAME_MAX
#endif /* !_INCL_UNIXSTL_H_UNIXSTL_LIMITS */
#ifndef _STLSOFT_INCL_H_STLSOFT_FRAME_STRING
# include "stlsoft_frame_string.h"  // stlsoft::basic_frame_string
#endif /* !_STLSOFT_INCL_H_STLSOFT_FRAME_STRING */
#ifndef _STLSOFT_INCL_H_STLSOFT_ITERATOR
# include "stlsoft_iterator.h"
#endif /* !_STLSOFT_INCL_H_STLSOFT_ITERATOR */

#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>

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
 * Utility classes
 */

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
struct rds_shared_handle
{
    DIR         *dir;
    ss_sint32_t cRefs;

public:
    ss_explicit_k rds_shared_handle(DIR *d)
        : dir(d)
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
    ~rds_shared_handle()
    {
        unixstl_message_assert("Shared search handle being destroyed with outstanding references!", 0 == cRefs);

        if(NULL != dir)
        {
            closedir(dir);
        }
    }
};
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

/// \brief Iterator for readdir_sequence class
///
/// This class performs as a non-mutating iterator (aka const iterator) for the
/// readdir_sequence class.
///
///

class readdir_sequence_const_iterator
    : public stlsoft_ns_qual(iterator_base) <   unixstl_ns_qual_std(input_iterator_tag)
                                            ,   struct dirent const *
                                            ,   us_ptrdiff_t
                                            ,   struct dirent const **
                                            ,   struct dirent const *&
                                            >
{
public:
    /// The class type
    typedef readdir_sequence_const_iterator             class_type;
    /// The type on the rhs of <a href = "http://synesis.com.au/resources/articles/cpp/movectors.pdf">move</a> expressions
    typedef stlsoft_define_move_rhs_type(class_type)    rhs_type;
    /// The value type
    typedef struct dirent const                         *value_type;
//    typedef value_type                                  *pointer;
//    typedef value_type                                  &reference;

// Construction
private:
    friend class readdir_sequence;

    enum
    {
            includeDots =   0x0008  /*!< Requests that dots directories be included in the returned sequence */
        ,   directories =   0x0010  /*!< Causes the search to include directories */
        ,   files       =   0x0020  /*!< Causes the search to include files */
#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
        ,   noSort      =   0 /* 0x0100 */  //!< 
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */
        ,
    };

    /// Construct an instance and begin a sequence iteration on the given dir.
    readdir_sequence_const_iterator(DIR *dir, us_uint_t flags)
        : m_handle(new rds_shared_handle(dir))
        , m_entry(NULL)
        , m_flags(flags)
    {
        // It's more efficient to not bother doing a separate dots check if all
        // directories are being elided.
        if(0 == (m_flags & directories))
        {
            m_flags |= includeDots;
        }

        if(NULL != m_handle)
        {
            operator ++();
        }
    }
    /// Constructs an instance based on the given directory entry
    readdir_sequence_const_iterator(dirent *entry)
        : m_handle(NULL)
        , m_entry(entry)
    {}
public:
    /// Default constructor
    readdir_sequence_const_iterator()
        : m_handle(NULL)
        , m_entry(NULL)
    {}
    /// <a href = "http://synesis.com.au/resources/articles/cpp/movectors.pdf">Move constructor</a>
    readdir_sequence_const_iterator(class_type const &rhs)
        : m_handle(rhs.m_handle)
        , m_entry(rhs.m_entry)
    {
        if(NULL != m_handle)
        {
            ++m_handle->cRefs;
        }
    }
    /// Release the search handle
    ~readdir_sequence_const_iterator() unixstl_throw_0()
    {
        if(NULL != m_handle)
        {
            m_handle->Release();
        }
    }

    /// <a href = "http://synesis.com.au/resources/articles/cpp/movectors.pdf">Move assignment</a> operator
    class_type const &operator =(rhs_type rhs)
    {
        m_handle        =   rhs.m_handle;
        if(NULL != m_handle)
        {
            m_handle->Release();
        }

        m_entry         =   rhs.m_entry;
        m_flags         =   rhs.m_flags;

        if(NULL != m_handle)
        {
            ++m_handle->cRefs;
        }

        return *this;
    }

// Accessors
public:
    /// Returns the value representative 
    value_type operator *() const
    {
        unixstl_message_assert( "Dereferencing invalid iterator", NULL != m_entry);

        return m_entry;
    }

    /// Moves the iteration on to the next point in the sequence, or end() if
    /// the sequence is exhausted
    class_type &operator ++()
    {
        unixstl_message_assert( "Incrementing invalid iterator", NULL != m_handle);

        for(;;)
        {
            m_entry = readdir(m_handle->dir);

            if(NULL != m_entry)
            {
                unixstl_assert(NULL != m_entry->d_name);

                if(0 == (m_flags & includeDots))
                {
                    if( m_entry->d_name[0] == '.' &&
                        (   m_entry->d_name[1] == '\0' ||
                            (   m_entry->d_name[1] == '.' &&
                                m_entry->d_name[2] == '\0')))
                    {
                        continue; // Don't want dots; skip it
                    }
                }

               if((m_flags & (directories | files)) != (directories | files))
               {
                    // Now need to process the file, by using stat
                    struct stat st;

                    if(0 != stat(m_entry->d_name, &st))
                    {
                        // Failed to get info from entry. Must assume it is
                        // dead, so skip it
                        continue;
                    }
                    else
                    {
                        if(m_flags & directories) // Want directories
                        {
                            if(S_IFDIR == (st.st_mode & S_IFDIR))
                            {
                                // It is a directory, so accept it
                                break;
                            }
                        }
                        if(m_flags & files) // Want files
                        {
                            if(S_IFREG == (st.st_mode & S_IFREG))
                            {
                                // It is a file, so accept it
                                break;
                            }
                        }

                        continue; // Not a match, so skip this entry
                    }
                }
            }

            break;
        }

        if(NULL == m_entry)
        {
            unixstl_assert(NULL != m_handle);

            m_handle->Release();

            m_handle = NULL;
        }

        return *this;
    }
    /// Post-increment form of operator ++().
    ///
    /// \note Because this version uses a temporary on which to call the
    /// pre-increment form it is thereby less efficient, and should not be used
    /// except where post-increment semantics are required.
    class_type operator ++(int)
    {
        class_type  ret(*this);

        operator ++();

        return ret;
    }

    /// Compares \c this for equality with \c rhs
    ///
    /// \param rhs The instance against which to test
    /// \retval true if the iterators are equivalent
    /// \retval false if the iterators are not equivalent
    bool operator ==(class_type const &rhs) const
    {
        unixstl_assert(NULL == m_handle || NULL == rhs.m_handle || m_handle->dir == rhs.m_handle->dir);

        return m_entry == rhs.m_entry;
    }
    /// Compares \c this for inequality with \c rhs
    ///
    /// \param rhs The instance against which to test
    /// \retval false if the iterators are equivalent
    /// \retval true if the iterators are not equivalent
    bool operator !=(class_type const &rhs) const
    {
        return !operator ==(rhs);
    }

// Members
private:
    rds_shared_handle   *m_handle;
    struct dirent       *m_entry;
    us_uint_t           m_flags;

// Not to be implemented
private:
};


/// \brief STL-like readonly sequence based on directory contents
///
/// This class presents and STL-like readonly sequence interface to allow the 
/// iteration over the contents of a directory.

class readdir_sequence
{
private:
    typedef readdir_sequence                                    class_type;
public:
//    typedef us_size_t                                           size_type;
    typedef readdir_sequence_const_iterator                     const_iterator;
    typedef readdir_sequence_const_iterator::value_type         value_type;
//    typedef readdir_sequence_const_iterator::pointer            pointer;
//    typedef readdir_sequence_const_iterator::pointer const      const_pointer;
//    typedef readdir_sequence_const_iterator::reference          reference;
    typedef readdir_sequence_const_iterator::reference const    const_reference;

private:
    typedef stlsoft_ns_qual(basic_frame_string) <   us_char_a_t
                                                ,   UNIXSTL_NAME_MAX
                                                >               string_type;

public:
    enum
    {
            includeDots =   const_iterator::includeDots /*!< Requests that dots directories be included in the returned sequence */
        ,   directories =   const_iterator::directories /*!< Causes the search to include directories */
        ,   files       =   const_iterator::files       /*!< Causes the search to include files */
#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
        ,   noSort      =   const_iterator::noSort      /* 0x0100 */  //!< 
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */
        ,
    };

// Construction
public:
    /// \brief Constructs a sequence according to the given criteria
    ///
    /// The constructor initialises a readdir_sequence instance on the given
    /// directory with the given flags.
    ///
    /// \param name The directory whose contents are to be searched
    /// \param flags Flags to alter the behaviour of the search
    ///
    /// \note The \c flags parameter defaults to <code>directories | files</code> because
    /// this reflects the default behaviour of \c readdir(), and also because it is the
    /// most efficient.
    readdir_sequence(us_char_a_t const *name, us_int_t flags = directories | files)
        : m_name(name)
        , m_flags(validate_flags_(flags))
    {}

// Iteration
public:
    /// Begins the iteration
    ///
    /// \return An iterator representing the start of the sequence
    const_iterator  begin() const
    {
        DIR *dir = opendir(m_name.c_str());

        return const_iterator(dir, m_flags);
    }
    /// Ends the iteration
    ///
    /// \return An iterator representing the end of the sequence
    const_iterator  end() const
    {
        return const_iterator();
    }

// Attributes
public:
#if 0
    /// Returns the number of elements in the sequence
    ///
    /// \note Nor currently implemented
    size_type   size() const
    {
        return 0;
    }
#endif /* 0 */

    /// \brief Indicates whether the search sequence is empty
    us_bool_t empty() const
    {
        return begin() != end();
    }

// Implementation
private:
    /// \brief Ensures that the flags are correct
    static us_int_t validate_flags_(us_int_t flags)
    {
        return (0 == (flags & (directories | files))) ? (flags | (directories | files)) : flags;
    }

// Members
private:
    string_type m_name;
    us_int_t    m_flags;
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

#endif /* !_INCL_UNIXSTL_H_UNIXSTL_READDIR_SEQUENCE */

/* ////////////////////////////////////////////////////////////////////////// */
