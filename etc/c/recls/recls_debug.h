/* /////////////////////////////////////////////////////////////////////////////
 * File:        recls_debug.h
 *
 * Purpose:     Compiler discrimination for the recls API.
 *
 * Created:     30th September 2003
 * Updated:     24th November 2003
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


#ifndef RECLS_INCL_H_RECLS_DEBUG
#define RECLS_INCL_H_RECLS_DEBUG

/* File version */
#ifndef RECLS_DOCUMENTATION_SKIP_SECTION
# define RECLS_VER_H_RECLS_DEBUG_MAJOR      1
# define RECLS_VER_H_RECLS_DEBUG_MINOR      0
# define RECLS_VER_H_RECLS_DEBUG_REVISION   6
# define RECLS_VER_H_RECLS_DEBUG_EDIT       6
#endif /* !RECLS_DOCUMENTATION_SKIP_SECTION */

/** \file recls_debug.h Debug infrastructure for the \ref group_recls API */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#include "recls.h"
#if defined(RECLS_PLATFORM_IS_WIN32) && \
    defined(_DEBUG)
# include <winstl_error_scope.h>
# include <winstl_tls_index.h>
#endif /* _DEBUG && RECLS_PLATFORM_IS_WIN32 */
#include <stdio.h>

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
namespace recls
{
#endif /* !RECLS_NO_NAMESPACE */

#if defined(_DEBUG) && \
    defined(RECLS_PLATFORM_IS_WIN32)
winstl_ns_using(last_error_scope)
winstl_ns_using(tls_index)
#endif /* _DEBUG && RECLS_PLATFORM_IS_WIN32 */

/* /////////////////////////////////////////////////////////////////////////////
 * debug_printf
 */

#if defined(_DEBUG) && \
    defined(RECLS_PLATFORM_IS_WIN32)

inline void debug_printf(char const *fmt, ...)
{
    va_list args;
    char    _sz[2048];

    va_start(args, fmt);

    _vsnprintf(_sz, stlsoft_num_elements(_sz), fmt, args);
    OutputDebugStringA(_sz);

    va_end(args);
}

class function_scope
{
public:
    function_scope(char const *fn)
    {
        last_error_scope    error_scope;

        strncpy(m_fn, fn, stlsoft_num_elements(m_fn) - 1);
        debug_printf("%*s>> %s()\n", _post_inc(), "", m_fn);
    }
    ~function_scope()
    {
        last_error_scope    error_scope;

        debug_printf("%*s<< %s()\n", _pre_dec(), "", m_fn);
    }

private:
    typedef stlsoft::sint32_t   int32_t;

    static int32_t  _post_inc()
    {
        int32_t i = reinterpret_cast<int32_t>(::TlsGetValue(sm_index));
        int32_t r = i++;

        ::TlsSetValue(sm_index, reinterpret_cast<LPVOID>(i));

        return r;
    }
    static int32_t  _pre_dec()
    {
        int32_t i = reinterpret_cast<int32_t>(::TlsGetValue(sm_index));
        int32_t r = --i;

        ::TlsSetValue(sm_index, reinterpret_cast<LPVOID>(i));

        return r;
    }

private:
    char                m_fn[1024];
    static tls_index    sm_index;
};

# define function_scope_trace(f)        function_scope  _scope_ ## __LINE__(f)

#else /* ? _DEBUG && RECLS_PLATFORM_IS_WIN32 */
inline void _debug_printf(char const *, ...)
{}
# define debug_printf                   (0) ? ((void)0) : _debug_printf
# define function_scope_trace(f)        do { ; } while(0)
#endif /* _DEBUG && RECLS_PLATFORM_IS_WIN32 */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#if !defined(RECLS_NO_NAMESPACE)
} /* namespace recls */
#endif /* !RECLS_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !RECLS_INCL_H_RECLS_DEBUG */

/* ////////////////////////////////////////////////////////////////////////// */
