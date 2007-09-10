/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_platform_types.h
 *
 * Purpose:     Platform discrimination for the recls API.
 *
 * Created:     18th August 2003
 * Updated:     21st November 2003
 *
 * License:     (Licensed under the Synesis Software Standard Source License)
 *
 *              Copyright (C) 2002-2003, Synesis Software Pty Ltd.
 *
 *              All rights reserved.
 *
 *              www:        http://www.synesis.com.au/software
 *                          http://www.recls.org/
 *
 *              email:      submissions@recls.org  for submissions
 *                          admin@recls.org        for other enquiries
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


#ifndef RECLS_INCL_H_RECLS_PLATFORM_TYPES
#define RECLS_INCL_H_RECLS_PLATFORM_TYPES

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_PLATFORM_TYPES_MAJOR     1
# define RECLS_VER_H_RECLS_PLATFORM_TYPES_MINOR     3
# define RECLS_VER_H_RECLS_PLATFORM_TYPES_REVISION  1
# define RECLS_VER_H_RECLS_PLATFORM_TYPES_EDIT      8
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/** \file recls_platform_types.h Platform-dependent types for the \ref group_recls  API */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef RECLS_INCL_H_RECLS_PLATFORM
# error recls_platform_types.h must not be included directly. You should include recls.h
#endif /* !RECLS_INCL_H_RECLS_PLATFORM */

#if defined(RECLS_PLATFORM_IS_WIN32)
//# include <windows.h>
#elif defined(RECLS_PLATFORM_IS_UNIX)
# include <time.h>
# include <sys/types.h>
#else
# error Platform not (yet) recognised
#endif /* platform */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Platform-dependent types
 */

/** \def recls_time_t The time type for the recls API */
/** \def recls_filesize_t The file-size type for the recls API */

#if defined(RECLS_PLATFORM_IS_WIN32)

 typedef FILETIME                   recls_time_t;
 typedef ULARGE_INTEGER             recls_filesize_t;

#elif defined(RECLS_PLATFORM_IS_UNIX)

 typedef time_t                     recls_time_t;
 typedef off_t                      recls_filesize_t;

#else

# error Platform not (yet) recognised

 typedef platform-dependent-type    recls_time_t;
 typedef platform-dependent-type    recls_filesize_t;

#endif /* platform */

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs
 */

#ifdef RECLS_CHAR_TYPE_IS_CHAR
# undef RECLS_CHAR_TYPE_IS_CHAR
#endif /* RECLS_CHAR_TYPE_IS_CHAR */

#ifdef RECLS_CHAR_TYPE_IS_WCHAR
# undef RECLS_CHAR_TYPE_IS_WCHAR
#endif /* RECLS_CHAR_TYPE_IS_WCHAR */

/** The recls library ambient character type */
#if 1
typedef recls_char_a_t              recls_char_t;
# define RECLS_CHAR_TYPE_IS_CHAR
#else /* ? 0 */
typedef recls_char_w_t              recls_char_t;
# define RECLS_CHAR_TYPE_IS_WCHAR
#endif /* 0 */


/** An asymmetric range representing a sequence of characters (ie a string) */
struct recls_strptrs_t
{
    /** Points to the start of the sequence. */
    recls_char_t const  *begin;
    /** Points to one-past-the-end of the sequence. */
    recls_char_t const  *end;
};

/** An asymmetric range representing a sequence of recls_strptrs_t (ie a set of strings) */
struct recls_strptrsptrs_t
{
    /** Points to the start of the sequence. */
    struct recls_strptrs_t const    *begin;
    /** Points to one-past-the-end of the sequence. */
    struct recls_strptrs_t const    *end;
};

/** A file entry info structure
 *
 * \note Several parts of this structure are platform-dependent.
 */
struct recls_fileinfo_t
{
/** \name attributes */
/** @{ */
    /** The file attributes */
    recls_uint32_t              attributes;
/** @} */
/** \name Path components  */
/** @{ */
    /** The full path of the file */
    struct recls_strptrs_t      path;
#if defined(RECLS_PLATFORM_IS_WIN32)
    /** The short (8.3) path of the file
     *
     * \note This member is only defined for the Win32 platform.
     */
    struct recls_strptrs_t      shortFile;
    /** The letter of the drive */
    recls_char_t                drive;
#endif /* RECLS_PLATFORM_IS_WIN32 */
    /** The directory component */
    struct recls_strptrs_t      directory;
    /** The file name component (excluding extension) */
    struct recls_strptrs_t      fileName;
    /** The file extension component (excluding '.') */
    struct recls_strptrs_t      fileExt;
    /** The directory parts */
    struct recls_strptrsptrs_t  directoryParts;
/** @} */
/** \name File times  */
/** @{ */
#if defined(RECLS_PLATFORM_IS_WIN32)
    /** The time the file was created
     *
     * \note This member is only defined for the Win32 platform.
     */
    recls_time_t                creationTime;
#endif /* RECLS_PLATFORM_IS_WIN32 */
    /** The time the file was last modified */
    recls_time_t                modificationTime;
    /** The time the file was last accessed */
    recls_time_t                lastAccessTime;
#if defined(RECLS_PLATFORM_IS_UNIX)
    /** The time the file status was last changed
     *
     * \note This member is only defined for the UNIX platform.
     */
    recls_time_t                lastStatusChangeTime;
#endif /* RECLS_PLATFORM_IS_UNIX */
/** @} */
/** \name Size  */
/** @{ */
    /** The size of the file */
    recls_filesize_t            size;
/** @} */
/* data */
    /** The opaque data of the file; it is not accessible to any client code, and <b>must not be manipulated</b> in any way */
    recls_byte_t                data[1];
    /*
     *
     * - full path
     * - directory parts
     *
     */
};

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !RECLS_INCL_H_RECLS_PLATFORM_TYPES */

/* ////////////////////////////////////////////////////////////////////////// */
