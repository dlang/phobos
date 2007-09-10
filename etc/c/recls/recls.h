/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls.h
 *
 * Purpose:     Main header file for the recls API.
 *
 * Created:     15th August 2003
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


#ifndef RECLS_INCL_H_RECLS
#define RECLS_INCL_H_RECLS

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_MAJOR    1
# define RECLS_VER_H_RECLS_MINOR    5
# define RECLS_VER_H_RECLS_REVISION 2
# define RECLS_VER_H_RECLS_EDIT     24
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/** \file recls.h The root header for the \ref group_recls API */

/** \name recls API Version
 *
 * \ingroup group_recls
 */
/** @{ */
/** \def RECLS_VER_MAJOR The major version number of RECLS */

/** \def RECLS_VER_MINOR The minor version number of RECLS */

/** \def RECLS_VER_REVISION The revision version number of RECLS */

/** \def RECLS_VER The current composite version number of RECLS */
/** @} */

/* recls version */
#define RECLS_VER_MAJOR     1
#define RECLS_VER_MINOR     2
#define RECLS_VER_REVISION  1
#define RECLS_VER_1_0_1     0x01000100
#define RECLS_VER_1_1_1     0x01010100
#define RECLS_VER_1_2_1     0x01020100
#define RECLS_VER           RECLS_VER_1_2_1

/* /////////////////////////////////////////////////////////////////////////////
 * Strictness
 */

#ifndef RECLS_NO_STRICT
# define RECLS_STRICT
#endif /* !RECLS_NO_STRICT */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

/* Detects C & C++ things, such as namespace support */
#include "recls_language.h"
/* Includes platform-specific headers */
#include "recls_platform.h"
/* Includes stddef.h / cstddef, and defines the recls types: recls_s/uint8/16/32/64_t */
#include "recls_compiler.h"
/* Defines recls_filesize_t, recls_time_t */
#include "recls_platform_types.h"

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

#if !defined(RECLS_NO_NAMESPACE)
# define RECLS_QUAL(x)                  ::recls::x
#else
# define RECLS_QUAL(x)                  x
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Pre-processor discrimination
 */

/* /////////////////////////////////////////////////////////////////////////////
 * Function specifications
 */

/*** Defines the recls linkage and calling convention */
#define RECLS_FNDECL(rt)    RECLS_LINKAGE_C rt RECLS_CALLCONV_DEFAULT

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs
 */

/* recls_rc_t */
#ifdef __cplusplus

/** The type of return codes issued by the API functions */
typedef recls_sint32_t                                              recls_rc_t;

/** General success code */
const recls_rc_t                                                    RECLS_RC_OK(0);
/** General failure code */
const recls_rc_t                                                    RECLS_RC_FAIL(-1);

/** Returns non-zero if the given return code indicates failure */
inline bool RECLS_FAILED(recls_rc_t const &rc)
{
    return rc < 0;
}

/** Returns non-zero if the given return code indicates success */
inline bool RECLS_SUCCEEDED(recls_rc_t const &rc)
{
    return !RECLS_FAILED(rc);
}

#else /* ? __cplusplus */

/** The type of return codes issued by the API functions */
typedef recls_sint32_t                                              recls_rc_t;

/** General success code */
#define RECLS_RC_OK                                                 (0)
/** General failure code */
#define RECLS_RC_FAIL                                               (-1)

/** Evaluates to non-zero if the given return code indicates failure */
#define RECLS_FAILED(rc)                                            ((rc) < 0)
/** Evaluates to non-zero if the given return code indicates success */
#define RECLS_SUCCEEDED(rc)                                         (!FAILED(rc))

#endif /* __cplusplus */


/* hrecls_t */
struct hrecls_t_;
/** The handle to a recursive search operation */
typedef struct hrecls_t_ const *                                    hrecls_t;


/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

/* Defines result codes */
#include "recls_retcodes.h"

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Flags
 */

/** \brief Search flags
 * \ingroup group_recls
 *
 * These flags moderate the search behaviour of the 
 * \link recls::Recls_Search Recls_Search\endlink and 
 * \link recls::Recls_SearchProcess Recls_SearchProcess\endlink functions.
 */
enum RECLS_FLAG
{
        RECLS_F_FILES               =   0x00000001 /*!< Include files in search. Included by default if none specified */
    ,   RECLS_F_DIRECTORIES         =   0x00000002 /*!< Include directories in search. Not currently supported. */
    ,   RECLS_F_LINKS               =   0x00000004 /*!< Include links in search. Ignored in Win32. */
    ,   RECLS_F_DEVICES             =   0x00000008 /*!< Include devices in search. Not currently supported. */
    ,   RECLS_F_TYPEMASK            =   0x00000FFF
    ,   RECLS_F_RECURSIVE           =   0x00010000 /*!< Searches given directory and all sub-directories */
    ,   RECLS_F_NO_FOLLOW_LINKS     =   0x00020000 /*!< Does not expand links */
    ,   RECLS_F_DIRECTORY_PARTS     =   0x00040000 /*!< Fills out the directory parts. Supported from version 1.1.1 onwards. */
    ,   RECLS_F_DETAILS_LATER       =   0x00080000 /*!< Does not fill out anything other than the path. Not currently supported. */
};

#if !defined(__cplusplus) && \
    !defined(RECLS_DOCUMENTATION_SKIP_SECTION)
typedef enum RECLS_FLAG RECLS_FLAG;
#endif /* !__cplusplus && !RECLS_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Typedefs
 */

struct recls_fileinfo_t;

/** Opaque type representing a file-system entry information */
typedef struct recls_fileinfo_t const   *recls_info_t;

/** Opaque type representing a user-defined parameter to the process function */
typedef void                            *recls_process_fn_param_t;

/** User-supplied process function, used by Recls_SearchProcess()
 *
 * \param info entry info structure
 * \param param the parameter passed to Recls_SearchProcess()
 * \return A status to indicate whether to continue or cancel the processing
 * \retval 0 cancel the processing
 * \retval non-0 continue the processing
 */
typedef int (RECLS_CALLCONV_DEFAULT *hrecls_process_fn_t)(recls_info_t info, recls_process_fn_param_t param);

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace typedefs
 */

#if !defined(RECLS_NO_NAMESPACE)
typedef recls_info_t                info_t;
typedef recls_process_fn_param_t    process_fn_param_t;
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Functions
 */

/***************************************
 * Search control
 */

/** \name Search control functions
 *
 * \ingroup group_recls
 */
/** @{ */

/** Searches a given directory for matching files of the given pattern
 *
 *
 * \param searchRoot The directory representing the root of the search
 * \param pattern The search pattern, e.g. "*.c"
 * \param flags A combination of 0 or more RECLS_FLAG values
 * \param phSrch Address of the search handle
 * \return A status code indicating success/failure
 *
 */
RECLS_FNDECL(recls_rc_t) Recls_Search(          recls_char_t const          *searchRoot
                                    ,           recls_char_t const          *pattern
                                    ,           recls_uint32_t              flags
                                    ,           hrecls_t                    *phSrch);

/** Searches a given directory for matching files of the given pattern, and processes them according to the given process function
 *
 * \param searchRoot The directory representing the root of the search
 * \param pattern The search pattern, e.g. "*.c"
 * \param flags A combination of 0 or more RECLS_FLAG values
 * \param pfn The processing function
 * \param param A caller-supplied parameter that is passed through to \c pfn on each invocation. The function can cancel the enumeration by returning 0
 * \return A status code indicating success/failure
 *
 * \note Available from version 1.1 of the <b>recls</b> API
 */
RECLS_FNDECL(recls_rc_t) Recls_SearchProcess(   recls_char_t const          *searchRoot
                                            ,   recls_char_t const          *pattern
                                            ,   recls_uint32_t              flags
                                            ,   hrecls_process_fn_t         pfn
                                            ,   recls_process_fn_param_t    param);

/** Closes the given search
 *
 * \param hSrch Handle of the search to close. May not be NULL.
 */
RECLS_FNDECL(void) Recls_SearchClose(           hrecls_t                    hSrch);

/** @} */

/***************************************
 * Search enumeration
 */

/** \name Search enumeration functions
 *
 * \ingroup group_recls
 */
/** @{ */

/** Advances the search one position
 *
 * \param hSrch Handle of the search to close. May not be NULL.
 * \return Status code
 * \retval RECLS_RC_OK Position was advanced; search handle can be queried for details
 * \retval RECLS_RC_NO_MORE_DATA There are no more items in the search
 * \retval Any other status code indicates an error
 */
RECLS_FNDECL(recls_rc_t) Recls_GetNext(         hrecls_t                    hSrch);

/** Advances the search one position, and retrieves the information for the new position
 *
 * \param hSrch Handle of the search to close. May not be NULL.
 * \param phEntry Pointer to receive entry info structure.
 * \return Status code
 * \retval RECLS_RC_OK Position was advanced; search handle can be queried for details
 * \retval RECLS_RC_NO_MORE_DATA There are no more items in the search
 * \retval Any other status code indicates an error
 */
RECLS_FNDECL(recls_rc_t) Recls_GetDetails(      hrecls_t                    hSrch
                                            ,   recls_info_t                *phEntry);

/** Retrieves the information for the current search position
 *
 * \param hSrch Handle of the search to close. May not be NULL.
 * \param phEntry Pointer to receive entry info structure.
 * \return Status code
 * \retval RECLS_RC_OK Position was advanced; search handle can be queried for details
 * \retval Any other status code indicates an error
 */
RECLS_FNDECL(recls_rc_t) Recls_GetNextDetails(  hrecls_t                    hSrch
                                            ,   recls_info_t                *phEntry);

/** @} */

/***************************************
 * File entry info structure
 */

/** \name File entry info structure functions
 *
 * \ingroup group_recls
 */
/** @{ */

/** Releases the resources associated with an entry info structure.
 *
 * \param hEntry The info entry structure.
 */
RECLS_FNDECL(void) Recls_CloseDetails(          recls_info_t                hEntry);

/** Copies an entry info structure.
 *
 * \param hEntry The info entry structure.
 * \param phEntry Address to receive a copy of the info entry structure. May not be NULL.
 * \return Status code
 * \retval RECLS_RC_OK Entry was generated.
 * \retval Any other status code indicates an error
 */
RECLS_FNDECL(recls_rc_t) Recls_CopyDetails(     recls_info_t                hEntry
                                            ,   recls_info_t                *phEntry);

/** Reports on the number of outstanding (i.e. in client code) file entry info structures
 *
 * \param hSrch Handle of the search to close. May not be NULL.
 * \param count Pointer to an integer variable to receive the result.
 * \return Status code
 * \retval RECLS_RC_OK Information was retrieved.
 * \retval Any other status code indicates an error
 */
RECLS_FNDECL(recls_rc_t) Recls_OutstandingDetails(hrecls_t                  hSrch
                                            ,   recls_uint32_t              *count);

/** @} */

/***************************************
 * Error handling
 */

/** \name Error handling functions
 *
 * \ingroup group_recls
 */
/** @{ */

/** Returns the last error code associated with the given search handle
 *
 * \param hSrch Handle of the search to close. May not be NULL.
 * \return The last error code for the search handle
 */
RECLS_FNDECL(recls_rc_t) Recls_GetLastError(    hrecls_t                    hSrch);

/** Gets the error string representing the given error
 *
 * \param rc The error code
 * \param buffer Pointer to character buffer in which to write the error. If NULL, the function returns the number of characters required.
 * \param cchBuffer Number of character spaces in \c buffer. Ignored if \c buffer is NULL.
 * \return The number of characters written to the buffer, or required for, the error.
 */
RECLS_FNDECL(size_t) Recls_GetErrorString(      recls_rc_t                  rc
                                    ,           recls_char_t                *buffer
                                    ,           size_t                      cchBuffer);

/** Gets the error string representing the current error associated with the given search handle
 *
 * \param hSrch Handle of the search to close. May not be NULL.
 * \param buffer Pointer to character buffer in which to write the error. If NULL, the function returns the number of characters required.
 * \param cchBuffer Number of character spaces in \c buffer. Ignored if \c buffer is NULL.
 * \return The number of characters written to the buffer, or required for, the error.
 */
RECLS_FNDECL(size_t) Recls_GetLastErrorString(  hrecls_t                    hSrch
                                        ,       recls_char_t                *buffer
                                        ,       size_t                      cchBuffer);

/** @} */

/***************************************
 * Property elicitation
 */

/** \name Property elicitation functions
 *
 * \ingroup group_recls
 */
/** @{ */

/** Retrieves the full path of the given entry recls_fileinfo_t
 *
 * \param hEntry The entry recls_fileinfo_t. Cannot be NULL
 * \param buffer Pointer to character buffer in which to write the path. If NULL, the function returns the number of characters required.
 * \param cchBuffer Number of character spaces in \c buffer. Ignored if \c buffer is NULL.
 * \return The number of characters written to the buffer, or required for, the path.
 */
RECLS_FNDECL(size_t) Recls_GetPathProperty(     recls_info_t                hEntry
                                        ,       recls_char_t                *buffer
                                        ,       size_t                      cchBuffer);

/** Retrieves the directory of the given entry recls_fileinfo_t
 *
 * \param hEntry The entry recls_fileinfo_t. Cannot be NULL
 * \param buffer Pointer to character buffer in which to write the directory. If NULL, the function returns the number of characters required.
 * \param cchBuffer Number of character spaces in \c buffer. Ignored if \c buffer is NULL.
 * \return The number of characters written to the buffer, or required for, the directory.
 */
RECLS_FNDECL(size_t) Recls_GetDirectoryProperty(recls_info_t                hEntry
                                            ,   recls_char_t                *buffer
                                            ,   size_t                      cchBuffer);

/** Retrieves the directory and drive of the given entry recls_fileinfo_t
 *
 * \param hEntry The entry recls_fileinfo_t. Cannot be NULL
 * \param buffer Pointer to character buffer in which to write the directory. If NULL, the function returns the number of characters required.
 * \param cchBuffer Number of character spaces in \c buffer. Ignored if \c buffer is NULL.
 * \return The number of characters written to the buffer, or required for, the directory.
 * \note On systems that do not have a drive, this function behaves identically to Recls_GetDirectoryProperty()
 */
RECLS_FNDECL(size_t) Recls_GetDirectoryPathProperty(    recls_info_t        hEntry
                                                    ,   recls_char_t        *buffer
                                                    ,   size_t              cchBuffer);

/** Retrieves the file (filename + extension) of the given entry recls_fileinfo_t
 *
 * \param hEntry The entry recls_fileinfo_t. Cannot be NULL
 * \param buffer Pointer to character buffer in which to write the file. If NULL, the function returns the number of characters required.
 * \param cchBuffer Number of character spaces in \c buffer. Ignored if \c buffer is NULL.
 * \return The number of characters written to the buffer, or required for, the file.
 */
RECLS_FNDECL(size_t) Recls_GetFileProperty(     recls_info_t                hEntry
                                        ,       recls_char_t                *buffer
                                        ,       size_t                      cchBuffer);

/** Retrieves the short version of the file of the given entry recls_fileinfo_t
 *
 * \param hEntry The entry recls_fileinfo_t. Cannot be NULL
 * \param buffer Pointer to character buffer in which to write the file. If NULL, the function returns the number of characters required.
 * \param cchBuffer Number of character spaces in \c buffer. Ignored if \c buffer is NULL.
 * \return The number of characters written to the buffer, or required for, the file.
 *
 * \note On systems where there is no concept of a short name, this function behaves exactly as Recls_GetFileProperty()
 */
RECLS_FNDECL(size_t) Recls_GetShortFileProperty(recls_info_t                hEntry
                                            ,   recls_char_t                *buffer
                                            ,   size_t                      cchBuffer);

/** Retrieves the filename (not including extension, if any) of the given entry recls_fileinfo_t
 *
 * \param hEntry The entry recls_fileinfo_t. Cannot be NULL
 * \param buffer Pointer to character buffer in which to write the filename. If NULL, the function returns the number of characters required.
 * \param cchBuffer Number of character spaces in \c buffer. Ignored if \c buffer is NULL.
 * \return The number of characters written to the buffer, or required for, the filename.
 */
RECLS_FNDECL(size_t) Recls_GetFileNameProperty( recls_info_t                hEntry
                                            ,   recls_char_t                *buffer
                                            ,   size_t                      cchBuffer);

/** Retrieves the file extension of the given entry recls_fileinfo_t
 *
 * \param hEntry The entry recls_fileinfo_t. Cannot be NULL
 * \param buffer Pointer to character buffer in which to write the extension. If NULL, the function returns the number of characters required.
 * \param cchBuffer Number of character spaces in \c buffer. Ignored if \c buffer is NULL.
 * \return The number of characters written to the buffer, or required for, the extension.
 */
RECLS_FNDECL(size_t) Recls_GetFileExtProperty(  recls_info_t                hEntry
                                            ,   recls_char_t                *buffer
                                            ,   size_t                      cchBuffer);

/** Retrieves a directory part of the given entry recls_fileinfo_t
 *
 * \param hEntry The entry recls_fileinfo_t. Cannot be NULL
 * \param part The part requested. If -1, then the function returns the number of parts
 * \param buffer Pointer to character buffer in which to write the extension. If NULL, the function returns the number of characters required. Ignored if part is -1.
 * \param cchBuffer Number of character spaces in \c buffer. Ignored if \c buffer is NULL or part is -1.
 * \return If \c part is -1, returns the number of parts. Otherwise, The number of characters written to the buffer, or required for, the extension.
 *
 * \note The behaviour is undefined if part is outside the range of parts.
 */
RECLS_FNDECL(size_t) Recls_GetDirectoryPartProperty(recls_info_t            hEntry
                                            ,   int                         part
                                            ,   recls_char_t                *buffer
                                            ,   size_t                      cchBuffer);


/** Returns non-zero if the file entry is read-only. 
 *
 * \param hEntry The file entry info structure to test. May not be NULL
 * \retval true file entry is read-only
 * \retval false file entry is not read-only
 *
 * \note There is no error return 
 */
RECLS_FNDECL(recls_bool_t) Recls_IsFileReadOnly(recls_info_t                hEntry);

/** Returns non-zero if the file entry represents a directory. 
 *
 * \param hEntry The file entry info structure to test. May not be NULL
 * \retval true file entry is a directory
 * \retval false file entry is not directory
 *
 * \note There is no error return 
 */
RECLS_FNDECL(recls_bool_t) Recls_IsFileDirectory(recls_info_t               hEntry);

/** Returns non-zero if the file entry represents a link. 
 *
 * \param hEntry The file entry info structure to test. May not be NULL
 * \retval true file entry is a link
 * \retval false file entry is not link
 *
 * \note There is no error return 
 */
RECLS_FNDECL(recls_bool_t) Recls_IsFileLink(    recls_info_t                hEntry);

/** Acquires the size of the file entry.
 *
 * \param hEntry The file entry info structure to test. May not be NULL
 * \param size Pointer to the location in which to store the size
 *
 * \note There is no error return. File system entries that do not have a meaningful size will be given a notional size of 0.
 */
RECLS_FNDECL(void)         Recls_GetSizeProperty(   recls_info_t            hEntry
                                                ,   recls_filesize_t        *size);

/** Returns the time the file was created */
RECLS_FNDECL(recls_time_t) Recls_GetCreationTime(recls_info_t               hEntry);

/** Returns the time the file was last modified */
RECLS_FNDECL(recls_time_t) Recls_GetModificationTime(recls_info_t           hEntry);

/** Returns the time the file was last accessed */
RECLS_FNDECL(recls_time_t) Recls_GetLastAccessTime(recls_info_t             hEntry);

/** Returns the time the file status was last changed */
RECLS_FNDECL(recls_time_t) Recls_GetLastStatusChangeTime(recls_info_t       hEntry);

/** @} */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Platform-specific includes
 */

/*** \def RECLS_PLATFORM_API_WIN32 Defined if Win32 platform-specific extensions are in use */
/*** \def RECLS_PLATFORM_API_UNIX Defined if UNIX platform-specific extensions are in use */

#ifdef RECLS_PLATFORM_API_WIN32
# undef RECLS_PLATFORM_API_WIN32
#endif /* RECLS_PLATFORM_API_WIN32 */

#ifdef RECLS_PLATFORM_API_UNIX
# undef RECLS_PLATFORM_API_UNIX
#endif /* RECLS_PLATFORM_API_UNIX */

#if !defined(RECLS_PURE_API)
# if defined(RECLS_PLATFORM_IS_WIN32)
#  include "recls_win32.h"
#  define RECLS_PLATFORM_API_WIN32
# elif defined(RECLS_PLATFORM_IS_UNIX)
#  include "recls_unix.h"
#  define RECLS_PLATFORM_API_UNIX
# else
#  error Platform not recognised
# endif /* platform */
#endif /* !RECLS_PURE_API */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !RECLS_INCL_H_RECLS */

/* ////////////////////////////////////////////////////////////////////////// */
