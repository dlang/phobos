/* /////////////////////////////////////////////////////////////////////////////
 * File:        stlsoft_static_initialisers.h (formerly MLClsCtr.h, ::SynesisStd)
 *
 * Purpose:     Class constructor.
 *
 * Created:     17th February 1997
 * Updated:     26th November 2003
 *
 * Author:      Matthew Wilson, Synesis Software Pty Ltd.
 *
 * License:     (Licensed under the Synesis Software Standard Source License)
 *
 *              Copyright (C) 2002-2003, Synesis Software Pty Ltd.
 *
 *              All rights reserved.
 *
 *              www:        http://www.synesis.com.au/stlsoft
 *                          http://www.stlsoft.org/
 *
 *              email:      submissions@stlsoft.org  for submissions
 *                          admin@stlsoft.org        for other enquiries
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


#ifndef _STLSOFT_INCL_H_STLSOFT_STATIC_INITIALISERS
#define _STLSOFT_INCL_H_STLSOFT_STATIC_INITIALISERS

#ifndef __STLSOFT_DOCUMENTATION_SKIP_SECTION
# define _STLSOFT_VER_H_STLSOFT_STATIC_INITIALISERS_MAJOR    1
# define _STLSOFT_VER_H_STLSOFT_STATIC_INITIALISERS_MINOR    8
# define _STLSOFT_VER_H_STLSOFT_STATIC_INITIALISERS_REVISION 2
# define _STLSOFT_VER_H_STLSOFT_STATIC_INITIALISERS_EDIT     191
#endif /* !__STLSOFT_DOCUMENTATION_SKIP_SECTION */

/* /////////////////////////////////////////////////////////////////////////////
 * Includes
 */

#ifndef _STLSOFT_INCL_H_STLSOFT
# include "stlsoft.h"   // Include the STLSoft root header
#endif /* !_STLSOFT_INCL_H_STLSOFT */

/* /////////////////////////////////////////////////////////////////////////////
 * Namespace
 */

#ifndef _STLSOFT_NO_NAMESPACE
namespace stlsoft
{
#endif /* _STLSOFT_NO_NAMESPACE */

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

#if 0
class method_constructor
{
public:
    template<typename T>
    method_constructor(T const &t, void (T::*const fn)())
    {
        (t.*fn)();
    }
    template<typename T, typename R>
    method_constructor(T const &t, R (T::*const fn)())
    {
        (t.*fn)();
    }
};
#endif /* 0 */

/// static_initialiser
///
/// Initialises any non-class function or type
class static_initialiser
{
public:
    typedef static_initialiser  class_type;

/// \name Constructors
//@{
public:
#ifdef __STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT
    template <typename T>
    static_initialiser(T const &/* t */)
    {}
    template <typename T>
    static_initialiser(T const * /* pt */)
    {}
#else
    static_initialiser(int /* t */)
    {}
    static_initialiser(void const * /* pt */)
    {}
#endif // __STLSOFT_CF_MEMBER_TEMPLATE_CTOR_SUPPORT
//@}

/// \name Not to be implemented
//@{
private:
    static_initialiser(class_type const &);
    static_initialiser &operator =(class_type const &);

#ifdef __STLSOFT_COMPILER_IS_COMO
    void *operator new(ss_size_t) stlsoft_throw_0()
    {
        return 0;
    }
#else /* ? __STLSOFT_COMPILER_IS_COMO */
    void *operator new(ss_size_t) stlsoft_throw_0();
#endif /* __STLSOFT_COMPILER_IS_COMO */
    void operator delete(void *)
    {}
//@}
};


class api_constructor
{
/// \name Constructors
//@{
public:
    api_constructor(void (*pfnInit)(), void (*pfnUninit)())
        : m_pfnUninit(pfnUninit)
    {
        if(NULL != pfnInit)
        {
            (*pfnInit)();
        }
    }
    ~api_constructor()
    {
        if(NULL != m_pfnUninit)
        {
            (*m_pfnUninit)();
        }
    }
//@}

/// \name Members
//@{
private:
    void (*m_pfnUninit)(void);
//@}

/// \name Not to be implemented
//@{
private:
    api_constructor(api_constructor const &);
    api_constructor &operator =(api_constructor const &);

#ifdef __STLSOFT_COMPILER_IS_COMO
    void *operator new(ss_size_t) stlsoft_throw_0()
    {
        return 0;
    }
#else /* ? __STLSOFT_COMPILER_IS_COMO */
    void *operator new(ss_size_t) stlsoft_throw_0();
#endif /* __STLSOFT_COMPILER_IS_COMO */
    void operator delete(void *)
    {}
//@}
};

template <ss_typename_param_k T>
class class_constructor
    : protected api_constructor
{
/// \name Member types
//@{
public:
    typedef void (*class_init_fn_t)();
    typedef void (*class_uninit_fn_t)();

//@}

/// \name Constructors
//@{
public:
    ss_explicit_k class_constructor()
        : api_constructor(&T::class_init, &T::class_uninit)
    {}

    ss_explicit_k class_constructor(    class_init_fn_t     pfnInit
                                    ,   class_uninit_fn_t   pfnUninit)
        : api_constructor(pfnInit, pfnUninit)
    {}
//@}

/// \name Not to be implemented
//@{
private:
    class_constructor(class_constructor const &);
    class_constructor &operator =(class_constructor const &);

#ifdef __STLSOFT_COMPILER_IS_COMO
    void *operator new(ss_size_t) stlsoft_throw_0()
    {
        return 0;
    }
#else /* ? __STLSOFT_COMPILER_IS_COMO */
    void *operator new(ss_size_t) stlsoft_throw_0();
#endif /* __STLSOFT_COMPILER_IS_COMO */
    void operator delete(void *)
    {}
//@}
};

/* ////////////////////////////////////////////////////////////////////////// */

#ifndef _STLSOFT_NO_NAMESPACE
} // namespace stlsoft
#endif /* _STLSOFT_NO_NAMESPACE */

/* ////////////////////////////////////////////////////////////////////////// */

#endif /* !_STLSOFT_INCL_H_STLSOFT_STATIC_INITIALISERS */

/* ////////////////////////////////////////////////////////////////////////// */
