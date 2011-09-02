
// Written in the D programming language.

/* /////////////////////////////////////////////////////////////////////////////
 * File:        loader.d (originally from synsoft.win32.loader)
 *
 * Purpose:     Win32 exception classes
 *
 * Created      18th October 2003
 * Updated:     24th April 2004
 *
 * Author:      Matthew Wilson
 *
 * Copyright 2004-2005 by Matthew Wilson and Synesis Software
 * Written by Matthew Wilson
 *
 * This software is provided 'as-is', without any express or implied
 * warranty. In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, in both source and binary form, subject to the following
 * restrictions:
 *
 * -  The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * -  Altered source versions must be plainly marked as such, and must not
 *    be misrepresented as being the original software.
 * -  This notice may not be removed or altered from any source
 *    distribution.
 *
 * ////////////////////////////////////////////////////////////////////////// */



/** \file D/std/loader.d This file contains the \c D standard library
 * executable module loader library, and the ExeModule class.
 * Source: $(PHOBOSSRC std/_loader.d)
 */

/* ////////////////////////////////////////////////////////////////////////// */

module std.loader;

/* /////////////////////////////////////////////////////////////////////////////
 * Imports
 */

private import std.string;
import std.conv;
private import std.c.string;
private import std.c.stdlib;
private import std.c.stdio;

//import synsoft.types;
/+ + These are borrowed from synsoft.types, until such time as something similar is in Phobos ++
 +/
public alias int                    boolean;

/* /////////////////////////////////////////////////////////////////////////////
 * External function declarations
 */

version(Windows)
{
    private import std.c.windows.windows;
    private import std.windows.syserror;

    extern(Windows)
    {
        alias HMODULE HModule_;
    }
}
else version(Posix)
{
    private import core.sys.posix.dlfcn;

    extern(C)
    {
    alias void* HModule_;
    }
}
else
{
    const int platform_not_discriminated = 0;

    static assert(platform_not_discriminated);
}

/** The platform-independent module handle. Note that this has to be
 * separate from the platform-dependent handle because different module names
 * can result in the same module being loaded, which cannot be detected in
 * some operating systems
 */
alias void    *HXModule;

/* /////////////////////////////////////////////////////////////////////////////
 * ExeModule functions
 */

/* These are "forward declared" here because I don't like the way D forces me
 * to provide my declaration and implementation together, and mixed in with all
 * the other implementation gunk.
 */

/** ExeModule library Initialisation
 *
 * \retval <0 Initialisation failed. Processing must gracefully terminate,
 * without making any use of the ExeModule library
 * \retval 0 Initialisation succeeded for the first time. Any necessary resources
 * were successfully allocated
 * \retval >0 Initialisation has already succeefully completed via a prior call.
 */
public int ExeModule_Init()
{
    return ExeModule_Init_();
}

public void ExeModule_Uninit()
{
    ExeModule_Uninit_();
}

/**
 *
 * \note The value of the handle returned may not be a valid handle for your operating
 * system, and you <b>must not</b> attempt to use it with any other operating system
 * or other APIs. It is only valid for use with the ExeModule library.
 */
public HXModule ExeModule_Load(in string moduleName)
{
    return ExeModule_Load_(moduleName);
}

public HXModule ExeModule_AddRef(HXModule hModule)
{
    return ExeModule_AddRef_(hModule);
}

/**
 *
 * \param hModule The module handler. It must not be null.
 */
public void ExeModule_Release(ref HXModule hModule)
{
    ExeModule_Release_(hModule);
}

public void *ExeModule_GetSymbol(ref HXModule hModule, in string symbolName)
{
    return ExeModule_GetSymbol_(hModule, symbolName);
}

public string ExeModule_Error()
{
    return ExeModule_Error_();
}


version(Windows)
{
    private __gshared int         s_init;
    private __gshared int         s_lastError;    // This is NOT thread-specific

    private void record_error_()
    {
        s_lastError = GetLastError();
    }


    private int ExeModule_Init_()
    {
        return ++s_init > 1;
    }

    private void ExeModule_Uninit_()
    {
        --s_init;
    }

    private HXModule ExeModule_Load_(in string moduleName)
    in
    {
        assert(null !is moduleName);
    }
    body
    {
        HXModule hmod = cast(HXModule)LoadLibraryA(toStringz(moduleName));

        if(null is hmod)
        {
            record_error_();
        }

        return hmod;
    }

    private HXModule ExeModule_AddRef_(HXModule hModule)
    in
    {
        assert(null !is hModule);
    }
    body
    {
        return ExeModule_Load_(ExeModule_GetPath_(hModule));
    }

    private void ExeModule_Release_(ref HXModule hModule)
    in
    {
        assert(null !is hModule);
    }
    body
    {
        if(!FreeLibrary(cast(HModule_)hModule))
        {
            record_error_();
        }
        hModule = null;
    }

    private void *ExeModule_GetSymbol_(ref HXModule hModule, in string symbolName)
    in
    {
        assert(null !is hModule);
    }
    body
    {
        void    *symbol = GetProcAddress(cast(HModule_)hModule, toStringz(symbolName));

        if(null is symbol)
        {
            record_error_();
        }

        return symbol;
    }

    private string ExeModule_Error_()
    {
    return sysErrorString(s_lastError);
    }

    private string ExeModule_GetPath_(HXModule hModule)
    {
        char    szFileName[260]; // Need to use a constant here

    // http://msdn.microsoft.com/library/default.asp?url=/library/en-us/dllproc/base/getmodulefilename.asp
        uint cch = GetModuleFileNameA(cast(HModule_)hModule, szFileName.ptr, szFileName.length);

    if (cch == 0)
    {
            record_error_();
    }
        return szFileName[0 .. cch].idup;
    }
}
else version(Posix)
{
    private class ExeModuleInfo
    {
    public:
        int         m_cRefs;
        HModule_    m_hmod;
        string      m_name;

        this(HModule_ hmod, string name)
        {
            m_cRefs =   1;
            m_hmod  =   hmod;
            m_name  =   name;
        }
    };

    private __gshared int                     s_init;
    private __gshared ExeModuleInfo [string]  s_modules;
    private __gshared string                  s_lastError;    // This is NOT thread-specific

    private void record_error_()
    {
        char *err = dlerror();
        s_lastError = (null is err) ? "" : err[0 .. std.c.string.strlen(err)].idup;
    }

    private int ExeModule_Init_()
    {
        if(1 == ++s_init)
        {

            return 0;
        }

        return 1;
    }

    private void ExeModule_Uninit_()
    {
        if(0 == --s_init)
        {
        }
    }

    private HXModule ExeModule_Load_(in string moduleName)
    in
    {
        assert(null !is moduleName);
    }
    body
    {
    ExeModuleInfo*   mi_p = moduleName in s_modules;
    ExeModuleInfo   mi = mi_p is null ? null : *mi_p;

        if(null !is mi)
        {
            return (++mi.m_cRefs, cast(HXModule)mi);
        }
        else
        {
            HModule_    hmod = dlopen(toStringz(moduleName), RTLD_NOW);

            if(null is hmod)
            {
                record_error_();

                return null;
            }
            else
            {
                ExeModuleInfo   mi2  =   new ExeModuleInfo(hmod, moduleName.idup);

                s_modules[moduleName]   =   mi2;

                return cast(HXModule)mi2;
            }
        }
    }

    private HXModule ExeModule_AddRef_(HXModule hModule)
    in
    {
        assert(null !is hModule);

        ExeModuleInfo   mi = cast(ExeModuleInfo)hModule;

        assert(0 < mi.m_cRefs);
        assert(null !is mi.m_hmod);
        assert(null !is mi.m_name);
        assert(null !is s_modules[mi.m_name]);
        assert(mi is s_modules[mi.m_name]);
    }
    body
    {
        ExeModuleInfo   mi = cast(ExeModuleInfo)hModule;

        if(null !is mi)
        {
            return (++mi.m_cRefs, hModule);
        }
        else
        {
            return null;
        }
    }

    private void ExeModule_Release_(ref HXModule hModule)
    in
    {
        assert(null !is hModule);

        ExeModuleInfo   mi = cast(ExeModuleInfo)hModule;

        assert(0 < mi.m_cRefs);
        assert(null !is mi.m_hmod);
        assert(null !is mi.m_name);
        assert(null !is s_modules[mi.m_name]);
        assert(mi is s_modules[mi.m_name]);
    }
    body
    {
        ExeModuleInfo   mi      =   cast(ExeModuleInfo)hModule;

        if(0 == --mi.m_cRefs)
        {
            string      name    =   mi.m_name;

            if (dlclose(mi.m_hmod))
            {
                record_error_();
            }
            s_modules.remove(name);
            delete mi;
        }

        hModule = null;
    }

    private void *ExeModule_GetSymbol_(ref HXModule hModule, in string symbolName)
    in
    {
        assert(null !is hModule);

        ExeModuleInfo   mi = cast(ExeModuleInfo)hModule;

        assert(0 < mi.m_cRefs);
        assert(null !is mi.m_hmod);
        assert(null !is mi.m_name);
        assert(null !is s_modules[mi.m_name]);
        assert(mi is s_modules[mi.m_name]);
    }
    body
    {
        ExeModuleInfo   mi      =   cast(ExeModuleInfo)hModule;
        void *symbol = dlsym(mi.m_hmod, toStringz(symbolName));

        if(null == symbol)
        {
            record_error_();
        }

        return symbol;
    }

    private string ExeModule_Error_()
    {
        return s_lastError;
    }

    private string ExeModule_GetPath_(HXModule hModule)
    in
    {
        assert(null !is hModule);

        ExeModuleInfo   mi = cast(ExeModuleInfo)hModule;

        assert(0 < mi.m_cRefs);
        assert(null !is mi.m_hmod);
        assert(null !is mi.m_name);
        assert(null !is s_modules[mi.m_name]);
        assert(mi is s_modules[mi.m_name]);
    }
    body
    {
        ExeModuleInfo   mi = cast(ExeModuleInfo)hModule;

        return mi.m_name;
    }
}
else
{
    const int platform_not_discriminated = 0;

    static assert(platform_not_discriminated);
}

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

public class ExeModuleException
    : Exception
{
public:
    this(string message)
    {
        super(message);
    }

    this(uint errcode)
    {
      version (Posix)
      {
          char[80] buf = void;
          super(to!string(strerror_r(errcode, buf.ptr, buf.length)).idup);
      }
      else
      {
          super(to!string(strerror(errcode)));
      }
    }
}

/// This class represents an executable image
public scope class ExeModule
{
/// \name Construction
/// @{
public:
    /// Constructs from an existing image handle
    this(HXModule hModule, boolean bTakeOwnership)
    in
    {
        assert(null !is hModule);
    }
    body
    {
        if(bTakeOwnership)
        {
            m_hModule = hModule;
        }
        else
        {
        version (Windows)
        {
        string path = Path();
        m_hModule = cast(HXModule)LoadLibraryA(toStringz(path));
        if (m_hModule == null)
            throw new ExeModuleException(GetLastError());
        }
        else version (Posix)
        {
        m_hModule = ExeModule_AddRef(hModule);
        }
        else
        static assert(0);
        }
    }

    this(string moduleName)
    in
    {
        assert(null !is moduleName);
    }
    body
    {
    version (Windows)
    {
        m_hModule = cast(HXModule)LoadLibraryA(toStringz(moduleName));
        if (null is m_hModule)
        throw new ExeModuleException(GetLastError());
    }
    else version (Posix)
    {
        m_hModule = ExeModule_Load(moduleName);
        if (null is m_hModule)
        throw new ExeModuleException(ExeModule_Error());
    }
    else
    {
        static assert(0);       // unsupported system
    }
    }
    ~this()
    {
        close();
    }
/// @}

/// \name Operations
/// @{
public:
    /// Closes the library
    ///
    /// \note This is available to close the module at any time. Repeated
    /// calls do not result in an error, and are simply ignored.
    void close()
    {
        if(null !is m_hModule)
        {
        version (Windows)
        {
        if(!FreeLibrary(cast(HModule_)m_hModule))
            throw new ExeModuleException(GetLastError());
        }
        else version (Posix)
        {
        ExeModule_Release(m_hModule);
        }
        else
        static assert(0);
        }
    }
/// @}

/// \name Accessors
/// @{
public:
    /** Retrieves the named symbol.
     *
     * \return A pointer to the symbol. There is no null return - failure to retrieve the symbol
     * results in an ExeModuleException exception being thrown.
     */
    void *getSymbol(in string symbolName)
    {
    version (Windows)
    {
        void *symbol = GetProcAddress(cast(HModule_)m_hModule, toStringz(symbolName));
        if(null is symbol)
        {
        throw new ExeModuleException(GetLastError());
        }
    }
    else version (Posix)
    {
        void *symbol = ExeModule_GetSymbol(m_hModule, symbolName);

        if(null is symbol)
        {
        throw new ExeModuleException(ExeModule_Error());
        }
    }
    else
    {
        static assert(0);
    }

        return symbol;
    }

    /** Retrieves the named symbol.
     *
     * \return A pointer to the symbol, or null if it does not exist
     */
    void *findSymbol(in string symbolName)
    {
        return ExeModule_GetSymbol(m_hModule, symbolName);
    }

/// @}

/// \name Properties
/// @{
public:
    /// The handle of the module
    ///
    /// \note Will be \c null if the module load in the constructor failed
    HXModule Handle()
    {
        return m_hModule;
    }
    /// The handle of the module
    ///
    /// \note Will be \c null if the module load in the constructor failed
    string Path()
    {
        assert(null != m_hModule);

    version (Windows)
    {
        char szFileName[260]; // Need to use a constant here

        // http://msdn.microsoft.com/library/default.asp?url=/library/en-us/dllproc/base/getmodulefilename.asp
        uint cch = GetModuleFileNameA(cast(HModule_)m_hModule, szFileName.ptr, szFileName.length);
        if (cch == 0)
        throw new ExeModuleException(GetLastError());

        return szFileName[0 .. cch].idup;
    }
    else version (Posix)
    {
        return ExeModule_GetPath_(m_hModule);
    }
    else
        static assert(0);
    }
/// @}

private:
    HXModule m_hModule;
};

/* ////////////////////////////////////////////////////////////////////////// */

version(TestMain)
{
    int main(string[] args)
    {
        if(args.length < 3)
        {
            printf("USAGE: <moduleName> <symbolName>\n");
        }
        else
        {
            string  moduleName  =   args[1];
            string  symbolName  =   args[2];

            try
            {
                auto ExeModule xmod =   new ExeModule(moduleName);

                printf("\"%.*s\" is loaded\n", moduleName);

                void    *symbol =   xmod.getSymbol(symbolName);

                if(null == symbol)
                {
                    throw new ExeModuleException(ExeModule_Error());
                }
                else
                {
                    printf("\"%.*s\" is acquired\n", symbolName);
                }
            }
            catch(ExeModuleException x)
            {
                x.print();
            }
        }

        return 0;
    }
}

/* ////////////////////////////////////////////////////////////////////////// */
