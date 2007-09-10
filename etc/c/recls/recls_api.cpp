/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_api.cpp
 *
 * Purpose:     Main (platform-independent) implementation file for the recls API.
 *
 * Created:     16th August 2003
 * Updated:     27th November 2003
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


/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#define RECLS_PURE_API

#include "recls.h"
#include "recls_internal.h"
#include "recls_assert.h"

#include <stlsoft_nulldef.h>

#include "recls_debug.h"

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Search control
 */

/** Closes the given search */
RECLS_FNDECL(void) Recls_SearchClose(hrecls_t hSrch)
{
    function_scope_trace("Recls_SearchClose");

    ReclsSearchInfo *si =   ReclsSearchInfo::FromHandle(hSrch);

    recls_assert(NULL != si);

    delete si;
}

/* /////////////////////////////////////////////////////////////////////////////
 * Search enumeration
 */

RECLS_FNDECL(recls_rc_t) Recls_SearchProcess(   recls_char_t const          *searchRoot
                                            ,   recls_char_t const          *pattern
                                            ,   recls_uint32_t              flags
                                            ,   hrecls_process_fn_t         pfn
                                            ,   recls_process_fn_param_t    param)
{
    function_scope_trace("Recls_SearchProcess");

    recls_assert(NULL != pfn);

    hrecls_t    hSrch;
    recls_rc_t  rc  =   Recls_Search(searchRoot, pattern, flags, &hSrch);

    if(RECLS_SUCCEEDED(rc))
    {
        recls_info_t    info;

        do
        {
            rc = Recls_GetDetails(hSrch, &info);

            if(RECLS_FAILED(rc))
            {
                break;
            }
            else
            {
                int res =   (*pfn)(info, param);

                Recls_CloseDetails(info);

                if(0 == res)
                {
                    break;
                }
            }
        }
        while(RECLS_SUCCEEDED(rc = Recls_GetNext(hSrch)));

        Recls_SearchClose(hSrch);
    }

    if(RECLS_RC_NO_MORE_DATA == rc)
    {
        rc = RECLS_RC_OK;
    }

    return rc;
}

RECLS_FNDECL(recls_rc_t) Recls_GetNext(hrecls_t hSrch)
{
    function_scope_trace("Recls_GetNext");

    ReclsSearchInfo *si =   ReclsSearchInfo::FromHandle(hSrch);

    recls_assert(NULL != si);

    return si->GetNext();
}

RECLS_FNDECL(recls_rc_t) Recls_GetDetails(  hrecls_t        hSrch
                                        ,   recls_info_t    *pinfo)
{
    function_scope_trace("Recls_GetDetails");

    ReclsSearchInfo     *si     =   ReclsSearchInfo::FromHandle(hSrch);

    recls_assert(NULL != si);
    recls_assert(NULL != pinfo);

    return si->GetDetails(pinfo);
}

RECLS_FNDECL(recls_rc_t) Recls_GetNextDetails(  hrecls_t        hSrch
                                            ,   recls_info_t    *pinfo)
{
    function_scope_trace("Recls_GetNextDetails");

    ReclsSearchInfo *si =   ReclsSearchInfo::FromHandle(hSrch);

    recls_assert(NULL != si);

    return si->GetNextDetails(pinfo);
}

/***************************************
 * File entry info structure
 */

RECLS_FNDECL(void) Recls_CloseDetails(recls_info_t fileInfo)
{
    function_scope_trace("Recls_CloseDetails");

    recls_assert(NULL != fileInfo);

    FileInfo_Release(fileInfo);
}

RECLS_FNDECL(recls_rc_t) Recls_CopyDetails( recls_info_t    fileInfo
                                        ,   recls_info_t    *pinfo)
{
    function_scope_trace("Recls_CopyDetails");

    recls_assert(NULL != fileInfo);

    return FileInfo_Copy(fileInfo, pinfo);
}

RECLS_FNDECL(recls_rc_t) Recls_OutstandingDetails(  hrecls_t        hSrch
                                                ,   recls_uint32_t  *count)
{
    function_scope_trace("Recls_OutstandingDetails");

    ReclsSearchInfo *si =   ReclsSearchInfo::FromHandle(hSrch);

    recls_assert(NULL != si);
    recls_assert(NULL != count);
    STLSOFT_SUPPRESS_UNUSED(si);

    recls_sint32_t  cCreated;
    recls_sint32_t  cShared;

    FileInfo_BlockCount(&cCreated, &cShared);

    *count = cCreated;

    return RECLS_RC_OK;
}

/* /////////////////////////////////////////////////////////////////////////////
 * Error handling
 */

RECLS_FNDECL(recls_rc_t) Recls_GetLastError(hrecls_t hSrch)
{
    function_scope_trace("Recls_GetLastError");

    ReclsSearchInfo *si =   ReclsSearchInfo::FromHandle(hSrch);

    recls_assert(NULL != si);

    return si->GetLastError();
}

RECLS_FNDECL(size_t) Recls_GetLastErrorString(  hrecls_t        hSrch
                                            ,   recls_char_t    *buffer
                                            ,   size_t          cchBuffer)
{
    function_scope_trace("Recls_GetLastErrorString");

    return Recls_GetErrorString(Recls_GetLastError(hSrch), buffer, cchBuffer);
}

/* /////////////////////////////////////////////////////////////////////////////
 * Property elicitation
 */

RECLS_FNDECL(size_t) Recls_GetPathProperty( recls_info_t    fileInfo
                                        ,   recls_char_t    *buffer
                                        ,   size_t          cchBuffer)
{
    function_scope_trace("Recls_GetPathProperty");

    recls_assert(NULL != fileInfo);

    return Recls_GetStringProperty_(&fileInfo->path, buffer, cchBuffer);
}

RECLS_FNDECL(size_t) Recls_GetDirectoryProperty(    recls_info_t    fileInfo
                                                ,   recls_char_t    *buffer
                                                ,   size_t          cchBuffer)
{
    function_scope_trace("Recls_GetDirectoryProperty");

    recls_assert(NULL != fileInfo);

    return Recls_GetStringProperty_(&fileInfo->directory, buffer, cchBuffer);
}

RECLS_FNDECL(size_t) Recls_GetFileProperty( recls_info_t    fileInfo
                                        ,   recls_char_t    *buffer
                                        ,   size_t          cchBuffer)
{
    function_scope_trace("Recls_GetFileProperty");

    recls_assert(NULL != fileInfo);

    struct recls_strptrs_t file =
    {
            fileInfo->fileName.begin /* File is defined by start of fileName ... */
        ,   fileInfo->fileExt.end    /* ... to end of fileExt. */
    };

    return Recls_GetStringProperty_(&file, buffer, cchBuffer);
}

RECLS_FNDECL(size_t) Recls_GetFileNameProperty( recls_info_t    fileInfo
                                            ,   recls_char_t    *buffer
                                            ,   size_t          cchBuffer)
{
    function_scope_trace("Recls_GetFileNameProperty");

    recls_assert(NULL != fileInfo);

    return Recls_GetStringProperty_(&fileInfo->fileName, buffer, cchBuffer);
}

RECLS_FNDECL(size_t) Recls_GetFileExtProperty(  recls_info_t    fileInfo
                                            ,   recls_char_t    *buffer
                                            ,   size_t          cchBuffer)
{
    function_scope_trace("Recls_GetFileExtProperty");

    recls_assert(NULL != fileInfo);

    return Recls_GetStringProperty_(&fileInfo->fileExt, buffer, cchBuffer);
}

RECLS_FNDECL(size_t) Recls_GetDirectoryPartProperty(    recls_info_t    fileInfo
                                                    ,   int             part
                                                    ,   recls_char_t    *buffer
                                                    ,   size_t          cchBuffer)
{
    function_scope_trace("Recls_GetDirectoryPartProperty");

    recls_assert(NULL != fileInfo);

    size_t  cParts = fileInfo->directoryParts.end - fileInfo->directoryParts.begin;

//debug_printf("%s: %u parts\n", fileInfo->path.begin, cParts);

    if(part < 0)
    {
        return cParts;
    }
    else
    {
        recls_assert(static_cast<size_t>(part) < cParts);

        return Recls_GetStringProperty_(&fileInfo->directoryParts.begin[part], buffer, cchBuffer);
    }
}

RECLS_FNDECL(void) Recls_GetSizeProperty(   recls_info_t        fileInfo
                                        ,   recls_filesize_t    *size)
{
    function_scope_trace("Recls_GetSizeProperty");

    recls_assert(NULL != fileInfo);
    recls_assert(NULL != size);

    *size = fileInfo->size;
}

RECLS_FNDECL(recls_time_t) Recls_GetModificationTime(recls_info_t fileInfo)
{
    function_scope_trace("Recls_GetModificationTime");

    recls_assert(NULL != fileInfo);

    return fileInfo->modificationTime;
}

RECLS_FNDECL(recls_time_t) Recls_GetLastAccessTime(recls_info_t fileInfo)
{
    function_scope_trace("Recls_GetLastAccessTime");

    recls_assert(NULL != fileInfo);

    return fileInfo->lastAccessTime;
}

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */
