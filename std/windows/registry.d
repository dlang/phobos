/* /////////////////////////////////////////////////////////////////////////////
 * File:        registry.d (from synsoft.win32.registry)
 *
 * Purpose:     Win32 Registry manipulation
 *
 * Created      15th March 2003
 * Updated:     25th April 2004
 *
 * Author:      Matthew Wilson
 *
 * License:
 *
 * Copyright 2003-2004 by Matthew Wilson and Synesis Software
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



/** \file std/windows/registry.d This file contains
 * the \c std.windows.registry.* classes
 */

/* ////////////////////////////////////////////////////////////////////////// */

module std.windows.registry;

pragma(lib, "advapi32.lib");

/* /////////////////////////////////////////////////////////////////////////////
 * Imports
 */

private import core.bitop : bswap;
private import std.array : join, split;
private import std.string;
private import std.windows.syserror;
private import std.c.windows.windows;
private import std.utf : toUTF16z;
import std.c.stdio : printf;
import std.conv;
import std.stdio;

//import synsoft.types;
/+ + These are borrowed from synsoft.types, until such time as something similar is in Phobos ++
 +/

version(LittleEndian)
{
    private const int Endian_Ambient =   1;
}
version(BigEndian)
{
    private const int Endian_Ambient =   2;
}

class Win32Exception : Exception
{
    int error;

    this(string message)
    {
        super(msg);
    }

    this(string msg, int errnum)
    {
        super(msg);
        error = errnum;
    }
}

/// An enumeration representing byte-ordering (Endian) strategies
public enum Endian
{
        Unknown =   0                   //!< Unknown endian-ness. Indicates an error
    ,   Little  =   1                   //!< Little endian architecture
    ,   Big     =   2                   //!< Big endian architecture
    ,   Middle  =   3                   //!< Middle endian architecture
    ,   ByteSex =   4
    ,   Ambient =   Endian_Ambient      //!< The ambient architecture, e.g. equivalent to Big on big-endian architectures.
/+ ++++ The compiler does not support this, due to deficiencies in the version() mechanism +++
  version(LittleEndian)
  {
    ,   Ambient =   Little
  }
  version(BigEndian)
  {
    ,   Ambient =   Big
  }
+/
}
/+
 +/

/* ////////////////////////////////////////////////////////////////////////// */

/// \defgroup group_std_windows_reg std.windows.registry
/// \ingroup group_std_windows
/// \brief This library provides Win32 Registry facilities

/* /////////////////////////////////////////////////////////////////////////////
 * Private constants
 */

private const DWORD DELETE                      =   0x00010000L;
private const DWORD READ_CONTROL                =   0x00020000L;
private const DWORD WRITE_DAC                   =   0x00040000L;
private const DWORD WRITE_OWNER                 =   0x00080000L;
private const DWORD SYNCHRONIZE                 =   0x00100000L;

private const DWORD STANDARD_RIGHTS_REQUIRED    =   0x000F0000L;

private const DWORD STANDARD_RIGHTS_READ        =   0x00020000L/* READ_CONTROL */;
private const DWORD STANDARD_RIGHTS_WRITE       =   0x00020000L/* READ_CONTROL */;
private const DWORD STANDARD_RIGHTS_EXECUTE     =   0x00020000L/* READ_CONTROL */;

private const DWORD STANDARD_RIGHTS_ALL         =   0x001F0000L;

private const DWORD SPECIFIC_RIGHTS_ALL         =   0x0000FFFFL;

private const DWORD REG_CREATED_NEW_KEY     =   0x00000001;
private const DWORD REG_OPENED_EXISTING_KEY =   0x00000002;

/* /////////////////////////////////////////////////////////////////////////////
 * Public enumerations
 */

/// Enumeration of the recognised registry access modes
///
/// \ingroup group_D_win32_reg
public enum REGSAM
{
        KEY_QUERY_VALUE         =   0x0001 //!< Permission to query subkey data
    ,   KEY_SET_VALUE           =   0x0002 //!< Permission to set subkey data
    ,   KEY_CREATE_SUB_KEY      =   0x0004 //!< Permission to create subkeys
    ,   KEY_ENUMERATE_SUB_KEYS  =   0x0008 //!< Permission to enumerate subkeys
    ,   KEY_NOTIFY              =   0x0010 //!< Permission for change notification
    ,   KEY_CREATE_LINK         =   0x0020 //!< Permission to create a symbolic link
    ,   KEY_WOW64_32KEY         =   0x0200 //!< Enables a 64- or 32-bit application to open a 32-bit key
    ,   KEY_WOW64_64KEY         =   0x0100 //!< Enables a 64- or 32-bit application to open a 64-bit key
    ,   KEY_WOW64_RES           =   0x0300 //!<
    ,   KEY_READ                =   (   STANDARD_RIGHTS_READ
                                    |   KEY_QUERY_VALUE
                                    |   KEY_ENUMERATE_SUB_KEYS
                                    |   KEY_NOTIFY)
                                &   ~(SYNCHRONIZE) //!< Combines the STANDARD_RIGHTS_READ, KEY_QUERY_VALUE, KEY_ENUMERATE_SUB_KEYS, and KEY_NOTIFY access rights
    ,   KEY_WRITE               =   (   STANDARD_RIGHTS_WRITE
                                    |   KEY_SET_VALUE
                                    |   KEY_CREATE_SUB_KEY)
                                &   ~(SYNCHRONIZE) //!< Combines the STANDARD_RIGHTS_WRITE, KEY_SET_VALUE, and KEY_CREATE_SUB_KEY access rights
    ,   KEY_EXECUTE             =   KEY_READ
                                &   ~(SYNCHRONIZE) //!< Permission for read access
    ,   KEY_ALL_ACCESS          =   (   STANDARD_RIGHTS_ALL
                                    |   KEY_QUERY_VALUE
                                    |   KEY_SET_VALUE
                                    |   KEY_CREATE_SUB_KEY
                                    |   KEY_ENUMERATE_SUB_KEYS
                                    |   KEY_NOTIFY
                                    |   KEY_CREATE_LINK)
                                &   ~(SYNCHRONIZE) //!< Combines the KEY_QUERY_VALUE, KEY_ENUMERATE_SUB_KEYS, KEY_NOTIFY, KEY_CREATE_SUB_KEY, KEY_CREATE_LINK, and KEY_SET_VALUE access rights, plus all the standard access rights except SYNCHRONIZE
}

/// Enumeration of the recognised registry value types
///
/// \ingroup group_D_win32_reg
public enum REG_VALUE_TYPE
{
        REG_UNKNOWN                     =   -1 //!<
    ,   REG_NONE                        =   0  //!< The null value type. (In practise this is treated as a zero-length binary array by the Win32 registry)
    ,   REG_SZ                          =   1  //!< A zero-terminated string
    ,   REG_EXPAND_SZ                   =   2  //!< A zero-terminated string containing expandable environment variable references
    ,   REG_BINARY                      =   3  //!< A binary blob
    ,   REG_DWORD                       =   4  //!< A 32-bit unsigned integer
    ,   REG_DWORD_LITTLE_ENDIAN         =   4  //!< A 32-bit unsigned integer, stored in little-endian byte order
    ,   REG_DWORD_BIG_ENDIAN            =   5  //!< A 32-bit unsigned integer, stored in big-endian byte order
    ,   REG_LINK                        =   6  //!< A registry link
    ,   REG_MULTI_SZ                    =   7  //!< A set of zero-terminated strings
    ,   REG_RESOURCE_LIST               =   8  //!< A hardware resource list
    ,   REG_FULL_RESOURCE_DESCRIPTOR    =   9  //!< A hardware resource descriptor
    ,   REG_RESOURCE_REQUIREMENTS_LIST  =   10 //!< A hardware resource requirements list
    ,   REG_QWORD                       =   11 //!< A 64-bit unsigned integer
    ,   REG_QWORD_LITTLE_ENDIAN         =   11 //!< A 64-bit unsigned integer, stored in little-endian byte order
}

/* /////////////////////////////////////////////////////////////////////////////
 * Private utility functions
 */

private uint sysEnforce(uint errcode)
{
    if (errcode != ERROR_SUCCESS && errcode != ERROR_NO_MORE_ITEMS)
    {
        throw new RegistryException(sysErrorString(errcode), errcode);
    }
    return errcode;
}

private REG_VALUE_TYPE _RVT_from_Endian(Endian endian)
{
    switch(endian)
    {
        case    Endian.Big:
            return REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN;

        case    Endian.Little:
            return REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN;

        default:
            throw new RegistryException("Invalid Endian specified");
    }
}

/* /////////////////////////////////////////////////////////////////////////////
 * Translation of the raw APIs:
 *
 * - translating string to char*
 * - removing the reserved arguments.
 * - checking all return values
 */

private struct HKey {
	HKEY hkey;
	
	private bool isStandardHiveKey()
	{
        if(cast(uint)hkey & 0x80000000)
        {
            switch(cast(uint)hkey)
            {
                case    HKEY_CLASSES_ROOT:
                case    HKEY_CURRENT_USER:
                case    HKEY_LOCAL_MACHINE:
                case    HKEY_USERS:
                case    HKEY_PERFORMANCE_DATA:
                case    HKEY_PERFORMANCE_TEXT:
                case    HKEY_PERFORMANCE_NLSTEXT:
                case    HKEY_CURRENT_CONFIG:
                case    HKEY_DYN_DATA:
                    return true;
                default:
                    /* Do nothing */
                    break;
            }
        }
        return false;
	}

    private void closeKey()
    {
        /* No need to attempt to close any of the standard hive keys.
         * Although it's documented that calling RegCloseKey() on any of
         * these hive keys is ignored, we'd rather not trust the Win32
         * API.
         */
        if(isStandardHiveKey())
        {
            return ;
        }
    
        sysEnforce(RegCloseKey(hkey));
        hkey = null;
    }
    
    private void flushKey()
    {
        sysEnforce(RegFlushKey(hkey));
    }

    private HKey createKey(in string subKey, in DWORD dwOptions, in REGSAM samDesired, in LPSECURITY_ATTRIBUTES lpsa, out DWORD disposition)
    in
    {
        assert(subKey != null);
    }
    body
    {
    	HKEY hkeyResult;
        sysEnforce(RegCreateKeyExW(hkey, toUTF16z(subKey), 0, null, dwOptions, samDesired, cast(LPSECURITY_ATTRIBUTES) lpsa, &hkeyResult, &disposition));
        return HKey(hkeyResult);
    }
    
    private void deleteKey(in string subKey)
    in
    {
        assert(subKey != null);
    }
    body
    {
        sysEnforce(RegDeleteKeyW(hkey, toUTF16z(subKey)));
    }

    private void deleteValue(in string valueName)
    in
    {
        assert(valueName != null);
    }
    body
    {
        sysEnforce(RegDeleteValueW(hkey, toUTF16z(valueName)));
    }
    
    private HKey dup()
    {
        /* Can't duplicate standard keys, but don't need to, so can just return */
        if(isStandardHiveKey())
        {
            return this.dup;
        }
    
        HKEY hkeyDup;
        sysEnforce(RegOpenKeyW(hkey, null, &hkeyDup));
        return HKey(hkeyDup);
    }

    private bool enumKeyName(in DWORD index, out string name)
    out(result)
    {
        assert(!result || name != null);
    }
    body
    {
        wchar[] buf = new wchar[256];
    
        LONG res;
        DWORD cchName;
        // The Registry API lies about the lengths of a very few sub-key lengths
        // so we have to test to see if it whinges about more data, and provide
        // more if it does.
        for(;;)
        {
        	cchName = buf.length;
            res = RegEnumKeyExW(hkey, index, buf.ptr, &cchName, null, null, null, null);
    
            if (ERROR_MORE_DATA != res)
            {
                break;
            }
            else
            {
                // Now need to increase the size of the buffer and try again
                buf.length = 2 * buf.length;
            }
        }
        
        sysEnforce(res);
        
        name = to!string(buf[0 .. cchName]);
        return res == ERROR_SUCCESS;
    }
    
    private bool enumValueName(in DWORD dwIndex, out string name)
    out(result)
    {
        //assert(!result || name != null);
    }
    body
    {
        wchar[] buf = new wchar[256];
    
        LONG res;
        DWORD cchName;
        // The Registry API lies about the lengths of a very few sub-key lengths
        // so we have to test to see if it whinges about more data, and provide
        // more if it does.
        for(;;)
        {
            cchName = buf.length;
            res = RegEnumValueW(hkey, dwIndex, buf.ptr, &cchName, null, null, null, null);;
    
            if (ERROR_MORE_DATA != res)
            {
                break;
            }
            else
            {
                // Now need to increase the size of the buffer and try again
                buf.length = 2 * buf.length;
            }
        }
        
        sysEnforce(res);
        
        name = to!string(buf[0 .. cchName]);
        return res == ERROR_SUCCESS;
    }
    
    private void getNumSubKeys(out DWORD cSubKeys, out DWORD cchSubKeyMaxLen)
    {
        sysEnforce(RegQueryInfoKeyW(hkey, null, null, null, &cSubKeys, &cchSubKeyMaxLen, null, null, null, null, null, null));
    }
    
    private void getNumValues(out DWORD cValues, out DWORD cchValueMaxLen)
    {
        sysEnforce(RegQueryInfoKeyW(hkey, null, null, null, null, null, null, &cValues, &cchValueMaxLen, null, null, null));
    }
    
    private LONG getValueType(in string name, out REG_VALUE_TYPE type)
    {
        DWORD cbData = 0;
        LONG res = RegQueryValueExW(hkey, toUTF16z(name), null, cast(uint*) &type, null, &cbData);
    
        if(ERROR_MORE_DATA == res)
        {
            res = ERROR_SUCCESS;
        }
    
        return res;
    }
    
    private HKey openKey(in string subKey, in REGSAM samDesired)
    in
    {
        assert(subKey != null);
    }
    body
    {
    	HKEY hkeyResult;
        sysEnforce(RegOpenKeyExW(hkey, toUTF16z(subKey), 0, samDesired, &hkeyResult));
        return HKey(hkeyResult);
    }

    private void queryValue(string name, out string value, out REG_VALUE_TYPE type)
    {
        // See bugzilla 961 on this
        static union U
        {
            uint    dw;
            ulong   qw;
        };
        U       u;
        void    *data   =   &u.qw;
        DWORD   cbData  =   u.qw.sizeof;
        LONG    res     =   RegQueryValueExW(hkey, toUTF16z(name), null, cast(uint*) &type, data, &cbData);

        if(ERROR_MORE_DATA == res)
        {
            data = (new byte[cbData]).ptr;

            res = RegQueryValueExW(hkey, toUTF16z(name), null, cast(uint*) &type, data, &cbData);
        }

    	sysEnforce(res);
        switch(type)
        {
            default:
            case    REG_VALUE_TYPE.REG_BINARY:
            case    REG_VALUE_TYPE.REG_MULTI_SZ:
                throw new RegistryException("Cannot read the given value as a string");

            case    REG_VALUE_TYPE.REG_SZ:
            case    REG_VALUE_TYPE.REG_EXPAND_SZ:
                value = to!string(cast(char*)data);
                if (value.ptr == cast(char*)&u.qw)
                    value = value.idup;         // don't point into the stack
                break;
version(LittleEndian)
{
            case    REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN:
                value = to!string(u.dw);
                break;
            case    REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN:
                value = to!string(bswap(u.dw));
                break;
}
version(BigEndian)
{
            case    REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN:
                value = to!string(bswap(u.dw));
                break;
            case    REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN:
                value = to!string(u.dw);
                break;
}
            case    REG_VALUE_TYPE.REG_QWORD_LITTLE_ENDIAN:
                value = to!string(u.qw);
                break;
        }
    }

    private void queryValue(in string name, out string[] value, out REG_VALUE_TYPE type)
    {
        wchar[] data = new wchar[256];
        DWORD cbData = data.length * wchar.sizeof;
        LONG res = RegQueryValueExW(hkey, toUTF16z(name), null, cast(uint*) &type, data.ptr, &cbData);

        if (res == ERROR_MORE_DATA)
        {
            data.length = cbData / wchar.sizeof;
            res = RegQueryValueExW(hkey, toUTF16z(name), null, cast(uint*) &type, data.ptr, &cbData);
        }
        else if (res == ERROR_SUCCESS)
        {
            data.length = cbData / wchar.sizeof;
        }
        
        sysEnforce(res);
    
        switch(type)
        {
            default:
                throw new RegistryException("Cannot read the given value as a string");

            case REG_VALUE_TYPE.REG_MULTI_SZ:
                break;
        }
    
        // Now need to tokenise it
        auto last = data.length-1;
        while (last > 0 && data[last] == cast(wchar) 0) last--;
        wstring[] wvalue = split(cast(wstring) data[0 .. last+1], "\0");
        value.length = wvalue.length;
        foreach (i, ref v; value)
        {
        	v = to!string(wvalue[i]);
        }
    }
    
    private void queryValue(in string name, out uint value, out REG_VALUE_TYPE type)
    {
        DWORD cbData = value.sizeof;
        LONG res = sysEnforce(RegQueryValueExW(hkey, toUTF16z(name), null, cast(uint*) &type, &value, &cbData));
    
        switch(type)
        {
            default:
                throw new RegistryException("Cannot read the given value as a 32-bit integer");

version(LittleEndian)
{
            case    REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN:
                assert(REG_VALUE_TYPE.REG_DWORD == REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN);
                break;
            case    REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN:
} // version(LittleEndian)
version(BigEndian)
{
            case    REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN:
                assert(REG_VALUE_TYPE.REG_DWORD == REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN);
                break;
            case    REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN:
} // version(BigEndian)
                value = bswap(value);
                break;
        }
    }
    
    private void queryValue(in string name, out ulong value, out REG_VALUE_TYPE type)
    {
        DWORD cbData = value.sizeof;
        LONG res = sysEnforce(RegQueryValueExW(hkey, toUTF16z(name), null, cast(uint*) &type, &value, &cbData));
    
        switch(type)
        {
            default:
                throw new RegistryException("Cannot read the given value as a 64-bit integer");

            case    REG_VALUE_TYPE.REG_QWORD_LITTLE_ENDIAN:
                break;
        }
    }
    
    private void queryValue(in string name, out byte[] value, out REG_VALUE_TYPE type)
    {
        byte[] data = new byte[100];
        DWORD cbData = data.sizeof;
        LONG res = RegQueryValueExW(hkey, toUTF16z(name), null, cast(uint*) &type, data.ptr, &cbData);
    
        if(ERROR_MORE_DATA == res)
        {
            data.length = cbData;    
            res = RegQueryValueExW(hkey, toUTF16z(name), null, cast(uint*) &type, data.ptr, &cbData);
        }

		sysEnforce(res);

        switch(type)
        {
            default:
                throw new RegistryException("Cannot read the given value as a string");

            case    REG_VALUE_TYPE.REG_BINARY:
                data.length = cbData;
                value = data;
                break;
        }
    }
    
    private void setValue(in string subKey, in REG_VALUE_TYPE type, in string data)
    {
    	const wchar *lpData = toUTF16z(data);
    	DWORD cbData = wcslen(lpData)*wchar.sizeof;
        sysEnforce(RegSetValueExW(hkey, toUTF16z(subKey), 0, cast(uint*) type, cast(LPBYTE) lpData, cbData));
    }

    private void setValue(in string subKey, in REG_VALUE_TYPE type, in string[] data)
    {
    	wstring[] value = new wstring[data.length+1];
    	foreach (i, ref s; value)
    	{
    		if (i < data.length)
	   			s = to!wstring(data[i]);
    		else 
    			s = "\0";
    	}
    	wstring all = join!(wstring[],wstring)(value, "\0"w);

        sysEnforce(RegSetValueExW(hkey, toUTF16z(subKey), 0, cast(uint*) type, cast(LPBYTE) all.ptr, all.length * wchar.sizeof));
    }

    private void setValue(in string subKey, in REG_VALUE_TYPE type, in LPCVOID lpData, in DWORD cbData)
    {
        sysEnforce(RegSetValueExW(hkey, toUTF16z(subKey), 0, cast(uint*) type, cast(LPBYTE) lpData, cbData));
    }
}

/* /////////////////////////////////////////////////////////////////////////////
 * Classes
 */

////////////////////////////////////////////////////////////////////////////////
// RegistryException

/// Exception class thrown by the std.windows.registry classes
///
/// \ingroup group_D_win32_reg

public class RegistryException
    : Win32Exception
{
/// \name Construction
//@{
public:
    /// \brief Creates an instance of the exception
    ///
    /// \param message The message associated with the exception
    this(string message)
    {
        super(message);
    }
    /// \brief Creates an instance of the exception, with the given
    ///
    /// \param message The message associated with the exception
    /// \param error The Win32 error number associated with the exception
    this(string message, int error)
    {
        super(message, error);
    }
//@}
}

unittest
{
    // (i) Test that we can throw and catch one by its own type
    try
    {
        string  message =   "Test 1";
        int     code    =   3;
        string  string  =   "Test 1 (3)";

        try
        {
            throw new RegistryException(message, code);
        }
        catch(RegistryException x)
        {
            assert(x.error == code);
/+
            if(string != x.toString())
            {
                printf( "UnitTest failure for RegistryException:\n"
                        "  x.message [%d;\"%.*s\"] does not equal [%d;\"%.*s\"]\n"
                    ,   x.msg.length, x.msg
                    ,   string.length, string);
            }
            assert(message == x.msg);
+/
        }
    }
    catch(Exception /* x */)
    {
        int code_flow_should_never_reach_here = 0;
        assert(code_flow_should_never_reach_here);
    }
}

////////////////////////////////////////////////////////////////////////////////
// Key

/// This class represents a registry key
///
/// \ingroup group_D_win32_reg

public class Key
{
/// \name Construction
//@{
private:
    this(HKey hkey, string name, bool created)
    {
        m_hkey      =   hkey;
        m_name      =   name;
        m_created   =   created;
    }

    ~this()
    {
        m_hkey.closeKey();

        // Even though this is horried waste-of-cycles programming
        // we're doing it here so that the
        m_hkey = HKey.init;
    }
//@}

/// \name Attributes
//@{
public:
    /// The name of the key
    string name()
    {
        return m_name;
    }

/*  /// Indicates whether this key was created, rather than opened, by the client
    bool Created()
    {
        return m_created;
    }
*/

    /// The number of sub keys
    uint keyCount()
    {
        uint    cSubKeys;
        uint    cchSubKeyMaxLen;
        m_hkey.getNumSubKeys(cSubKeys, cchSubKeyMaxLen);

        return cSubKeys;
    }

    /// An enumerable sequence of all the sub-keys of this key
    KeySequence keys()
    {
        return new KeySequence(this);
    }

    /// An enumerable sequence of the names of all the sub-keys of this key
    KeyNameSequence keyNames()
    {
        return new KeyNameSequence(this);
    }

    /// The number of values
    uint valueCount()
    {
        uint    cValues;
        uint    cchValueMaxLen;
        m_hkey.getNumValues(cValues, cchValueMaxLen);

        return cValues;
    }

    /// An enumerable sequence of all the values of this key
    ValueSequence values()
    {
        return new ValueSequence(this);
    }

    /// An enumerable sequence of the names of all the values of this key
    ValueNameSequence valueNames()
    {
        return new ValueNameSequence(this);
    }
//@}

/// \name Methods
//@{
public:
    /// Returns the named sub-key of this key
    ///
    /// \param name The name of the subkey to create. May not be null
    /// \return The created key
    /// \note If the key cannot be created, a RegistryException is thrown.
    Key createKey(string name, REGSAM access)
    {
        if( null is name ||
            0 == name.length)
        {
            throw new RegistryException("Key name is invalid");
        }
        else
        {
            DWORD disposition;
            HKey hkey = m_hkey.createKey(name, 0, REGSAM.KEY_ALL_ACCESS, null, disposition);

            // Potential resource leak here!!
            //
            // If the allocation of the memory for Key fails, the HKEY could be
            // lost. Hence, we catch such a failure by the finally, and release
            // the HKEY there. If the creation of
            try
            {
                Key key =   new Key(hkey, name, disposition == REG_CREATED_NEW_KEY);

                hkey.hkey = null;

                return key;
            }
            finally
            {
                if(hkey.hkey != null)
                {
                    hkey.closeKey();
                }
            }
        }
    }

    /// Returns the named sub-key of this key
    ///
    /// \param name The name of the subkey to create. May not be null
    /// \return The created key
    /// \note If the key cannot be created, a RegistryException is thrown.
    /// \note This function is equivalent to calling CreateKey(name, REGSAM.KEY_ALL_ACCESS), and returns a key with all access
    Key createKey(string name)
    {
        return createKey(name, cast(REGSAM)REGSAM.KEY_ALL_ACCESS);
    }

    /// Returns the named sub-key of this key
    ///
    /// \param name The name of the subkey to aquire. If name is null (or the empty-string), then the called key is duplicated
    /// \param access The desired access; one of the REGSAM enumeration
    /// \return The aquired key.
    /// \note This function never returns null. If a key corresponding to the requested name is not found, a RegistryException is thrown
    Key getKey(string name, REGSAM access)
    {
        if( null is name ||
            0 == name.length)
        {
            return new Key(m_hkey.dup(), m_name, false);
        }
        else
        {
            HKey hkey = m_hkey.openKey(name, REGSAM.KEY_ALL_ACCESS);

            // Potential resource leak here!!
            //
            // If the allocation of the memory for Key fails, the HKEY could be
            // lost. Hence, we catch such a failure by the finally, and release
            // the HKEY there. If the creation of
            try
            {
                Key key =   new Key(hkey, name, false);

                hkey.hkey = null;

                return key;
            }
            finally
            {
                if(hkey.hkey != null)
                {
                    hkey.closeKey();
                }
            }
        }
    }

    /// Returns the named sub-key of this key
    ///
    /// \param name The name of the subkey to aquire. If name is null (or the empty-string), then the called key is duplicated
    /// \return The aquired key.
    /// \note This function never returns null. If a key corresponding to the requested name is not found, a RegistryException is thrown
    /// \note This function is equivalent to calling GetKey(name, REGSAM.KEY_READ), and returns a key with read/enum access
    Key getKey(string name)
    {
        return getKey(name, cast(REGSAM)(REGSAM.KEY_READ));
    }

    /// Deletes the named key
    ///
    /// \param name The name of the key to delete. May not be null
    void deleteKey(string name)
    {
        if( null is name ||
            0 == name.length)
        {
            throw new RegistryException("Key name is invalid");
        }
        else
        {
            m_hkey.deleteKey(name);
        }
    }

    /// Returns the named value
    ///
    /// \note if name is null (or the empty-string), then the default value is returned
    /// \return This function never returns null. If a value corresponding to the requested name is not found, a RegistryException is thrown
    Value getValue(string name)
    {
        REG_VALUE_TYPE  type;
        LONG            res =   m_hkey.getValueType(name, type);

        if(ERROR_SUCCESS == res)
        {
            return new Value(this, name, type);
        }
        else
        {
            throw new RegistryException("Value cannot be opened: \"" ~ name ~ "\"", res);
        }
    }

    /// Sets the named value with the given 32-bit unsigned integer value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The 32-bit unsigned value to set
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void setValue(string name, uint value)
    {
        setValue(name, value, Endian.Ambient);
    }

    /// Sets the named value with the given 32-bit unsigned integer value, according to the desired byte-ordering
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The 32-bit unsigned value to set
    /// \param endian Can be Endian.Big or Endian.Little
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void setValue(string name, uint value, Endian endian)
    {
        REG_VALUE_TYPE  type    =   _RVT_from_Endian(endian);

        assert( type == REG_VALUE_TYPE.REG_DWORD_BIG_ENDIAN ||
                type == REG_VALUE_TYPE.REG_DWORD_LITTLE_ENDIAN);

        m_hkey.setValue(name, type, &value, value.sizeof);
    }

    /// Sets the named value with the given 64-bit unsigned integer value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The 64-bit unsigned value to set
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void setValue(string name, ulong value)
    {
        m_hkey.setValue(name, REG_VALUE_TYPE.REG_QWORD, &value, value.sizeof);
    }

    /// Sets the named value with the given string value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The string value to set
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void setValue(string name, string value)
    {
        setValue(name, value, false);
    }

    /// Sets the named value with the given string value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The string value to set
    /// \param asEXPAND_SZ If true, the value will be stored as an expandable environment string, otherwise as a normal string
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void setValue(string name, string value, bool asEXPAND_SZ)
    {
        m_hkey.setValue(name, asEXPAND_SZ ? REG_VALUE_TYPE.REG_EXPAND_SZ
                                          : REG_VALUE_TYPE.REG_SZ, value);
    }

    /// Sets the named value with the given multiple-strings value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The multiple-strings value to set
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void setValue(string name, string[] value)
    {
        m_hkey.setValue(name, REG_VALUE_TYPE.REG_MULTI_SZ, value);
    }

    /// Sets the named value with the given binary value
    ///
    /// \param name The name of the value to set. If null, or the empty string, sets the default value
    /// \param value The binary value to set
    /// \note If a value corresponding to the requested name is not found, a RegistryException is thrown
    void setValue(string name, byte[] value)
    {
        m_hkey.setValue(name, REG_VALUE_TYPE.REG_BINARY, value.ptr, value.length);
    }

    /// Deletes the named value
    ///
    /// \param name The name of the value to delete. May not be null
    /// \note If a value of the requested name is not found, a RegistryException is thrown
    void deleteValue(string name)
    {
        m_hkey.deleteValue(name);
    }

    /// Flushes any changes to the key to disk
    ///
    void flush()
    {
        m_hkey.flushKey();
    }
//@}

/// \name Members
//@{
private:
    HKey    m_hkey;
    string m_name;
    bool m_created;
//@}
}

////////////////////////////////////////////////////////////////////////////////
// Value

/// This class represents a value of a registry key
///
/// \ingroup group_D_win32_reg

public class Value
{
    invariant()
    {
        assert(!(null is m_key));
    }

private:
    this(Key key, string name, REG_VALUE_TYPE type)
    in
    {
        assert(!(key is null));
    }
    body
    {
        m_key   =   key;
        m_type  =   type;
        m_name  =   name;
    }

/// \name Attributes
//@{
public:
    /// The name of the value.
    ///
    /// \note If the value represents a default value of a key, which has no name, the returned string will be of zero length
    string name()
    {
        return m_name;
    }

    /// The type of value
    REG_VALUE_TYPE type()
    {
        return m_type;
    }

    /// Obtains the current value of the value as a string.
    ///
    /// \return The contents of the value
    /// \note If the value's type is REG_EXPAND_SZ the returned value is <b>not</b> expanded; Value_EXPAND_SZ() should be called
    /// \note Throws a RegistryException if the type of the value is not REG_SZ, REG_EXPAND_SZ, REG_DWORD(_*) or REG_QWORD(_*):
    string value_SZ()
    {
        REG_VALUE_TYPE  type;
        string          value;

        m_key.m_hkey.queryValue(m_name, value, type);

        if(type != m_type)
        {
            throw new RegistryException("Value type has been changed since the value was acquired");
        }

        return value;
    }

    /// Obtains the current value as a string, within which any environment
    /// variables have undergone expansion
    ///
    /// \return The contents of the value
    /// \note This function works with the same value-types as Value_SZ().
    string value_EXPAND_SZ()
    {
        string  value   =   value_SZ;
        // ExpandEnvironemntStrings():
        //      http://msdn2.microsoft.com/en-us/library/ms724265.aspx
        LPCWSTR  lpSrc       =   toUTF16z(value);
        DWORD   cchRequired =   ExpandEnvironmentStringsW(lpSrc, null, 0);
        wchar[]  newValue    =   new wchar[cchRequired];

        if(!ExpandEnvironmentStringsW(lpSrc, newValue.ptr, newValue.length))
        {
            throw new Win32Exception("Failed to expand environment variables");
        }

        return to!string(newValue[0 .. $-1]); // remove trailing 0
    }

    /// Obtains the current value as an array of strings
    ///
    /// \return The contents of the value
    /// \note Throws a RegistryException if the type of the value is not REG_MULTI_SZ
    string[] value_MULTI_SZ()
    {
        REG_VALUE_TYPE  type;
        string[]        value;

        m_key.m_hkey.queryValue(m_name, value, type);

        if(type != m_type)
        {
            throw new RegistryException("Value type has been changed since the value was acquired");
        }

        return value;
    }

    /// Obtains the current value as a 32-bit unsigned integer, ordered correctly according to the current architecture
    ///
    /// \return The contents of the value
    /// \note An exception is thrown for all types other than REG_DWORD, REG_DWORD_LITTLE_ENDIAN and REG_DWORD_BIG_ENDIAN.
    uint value_DWORD()
    {
        REG_VALUE_TYPE  type;
        uint            value;

        m_key.m_hkey.queryValue(m_name, value, type);

        if(type != m_type)
        {
            throw new RegistryException("Value type has been changed since the value was acquired");
        }

        return value;
    }

    deprecated uint value_DWORD_LITTLEENDIAN()
    {
        return value_DWORD();
    }

    deprecated uint value_DWORD_BIGENDIAN()
    {
        return value_DWORD();
    }

    /// Obtains the value as a 64-bit unsigned integer, ordered correctly according to the current architecture
    ///
    /// \return The contents of the value
    /// \note Throws a RegistryException if the type of the value is not REG_QWORD
    ulong value_QWORD()
    {
        REG_VALUE_TYPE  type;
        ulong           value;

        m_key.m_hkey.queryValue(m_name, value, type);

        if(type != m_type)
        {
            throw new RegistryException("Value type has been changed since the value was acquired");
        }

        return value;
    }

    deprecated ulong value_QWORD_LITTLEENDIAN()
    {
        return value_QWORD();
    }

    /// Obtains the value as a binary blob
    ///
    /// \return The contents of the value
    /// \note Throws a RegistryException if the type of the value is not REG_BINARY
    byte[]  value_BINARY()
    {
        REG_VALUE_TYPE  type;
        byte[]          value;

        m_key.m_hkey.queryValue(m_name, value, type);

        if(type != m_type)
        {
            throw new RegistryException("Value type has been changed since the value was acquired");
        }

        return value;
    }
//@}

/// \name Members
//@{
private:
    Key             m_key;
    REG_VALUE_TYPE  m_type;
    string         m_name;
//@}
}

////////////////////////////////////////////////////////////////////////////////
// Registry

/// Represents the local system registry.
///
/// \ingroup group_D_win32_reg

public class Registry
{
private:
    shared static this()
    {
        sm_keyClassesRoot       = new Key(  HKey(HKEY_CLASSES_ROOT)
                                        ,   "HKEY_CLASSES_ROOT", false);
        sm_keyCurrentUser       = new Key(  HKey(HKEY_CURRENT_USER)
                                        ,   "HKEY_CURRENT_USER", false);
        sm_keyLocalMachine      = new Key(  HKey(HKEY_LOCAL_MACHINE)
                                        ,   "HKEY_LOCAL_MACHINE", false);
        sm_keyUsers             = new Key(  HKey(HKEY_USERS)
                                        ,   "HKEY_USERS", false);
        sm_keyPerformanceData   = new Key(  HKey(HKEY_PERFORMANCE_DATA)
                                        ,   "HKEY_PERFORMANCE_DATA", false);
        sm_keyCurrentConfig     = new Key(  HKey(HKEY_CURRENT_CONFIG)
                                        ,   "HKEY_CURRENT_CONFIG", false);
        sm_keyDynData           = new Key(  HKey(HKEY_DYN_DATA)
                                        ,   "HKEY_DYN_DATA", false);
    }

private:
    this() {  }

/// \name Hives
//@{
public:
    /// Returns the root key for the HKEY_CLASSES_ROOT hive
    static Key  classesRoot()       {   return sm_keyClassesRoot;       }
    /// Returns the root key for the HKEY_CURRENT_USER hive
    static Key  currentUser()       {   return sm_keyCurrentUser;       }
    /// Returns the root key for the HKEY_LOCAL_MACHINE hive
    static Key  localMachine()      {   return sm_keyLocalMachine;      }
    /// Returns the root key for the HKEY_USERS hive
    static Key  users()             {   return sm_keyUsers;             }
    /// Returns the root key for the HKEY_PERFORMANCE_DATA hive
    static Key  performanceData()   {   return sm_keyPerformanceData;   }
    /// Returns the root key for the HKEY_CURRENT_CONFIG hive
    static Key  currentConfig()     {   return sm_keyCurrentConfig;     }
    /// Returns the root key for the HKEY_DYN_DATA hive
    static Key  dynData()           {   return sm_keyDynData;           }
//@}

private:
    __gshared Key  sm_keyClassesRoot;
    __gshared Key  sm_keyCurrentUser;
    __gshared Key  sm_keyLocalMachine;
    __gshared Key  sm_keyUsers;
    __gshared Key  sm_keyPerformanceData;
    __gshared Key  sm_keyCurrentConfig;
    __gshared Key  sm_keyDynData;
}

////////////////////////////////////////////////////////////////////////////////
// KeyNameSequence

/// An enumerable sequence representing the names of the sub-keys of a registry Key
///
/// It would be used as follows:
///
/// <code>&nbsp;&nbsp;Key&nbsp;key&nbsp;=&nbsp;. . .</code>
/// <br>
/// <code></code>
/// <br>
/// <code>&nbsp;&nbsp;foreach(char[] kName; key.SubKeys)</code>
/// <br>
/// <code>&nbsp;&nbsp;{</code>
/// <br>
/// <code>&nbsp;&nbsp;&nbsp;&nbsp;process_Key(kName);</code>
/// <br>
/// <code>&nbsp;&nbsp;}</code>
/// <br>
/// <br>
///
/// \ingroup group_D_win32_reg

public class KeyNameSequence
{
    invariant()
    {
        assert(!(null is m_key));
    }

/// Construction
private:
    this(Key key)
    {
        m_key = key;
    }

/// \name Attributes
///@{
public:
    /// The number of keys
    uint count()
    {
        return m_key.keyCount();
    }

    /// The name of the key at the given index
    ///
    /// \param index The 0-based index of the key to retrieve
    /// \return The name of the key corresponding to the given index
    /// \note Throws a RegistryException if no corresponding key is retrieved
    string getKeyName(uint index)
    {
        HKey hkey = m_key.m_hkey;
        string name;
        if (!hkey.enumKeyName(index, name)) {
            throw new RegistryException(sysErrorString(ERROR_NO_MORE_ITEMS), ERROR_NO_MORE_ITEMS);
        }
        return name;
    }

    /// The name of the key at the given index
    ///
    /// \param index The 0-based index of the key to retrieve
    /// \return The name of the key corresponding to the given index
    /// \note Throws a RegistryException if no corresponding key is retrieved
    string opIndex(uint index)
    {
        return getKeyName(index);
    }
///@}

public:
    int opApply(scope int delegate(ref string name) dg)
    {
        int result = 0;
        HKey hkey = m_key.m_hkey;

        for(DWORD index = 0; result == 0; ++index)
        {
            string name;
            if (hkey.enumKeyName(index, name))
            {
                result = dg(name);
            }
            else
            {
                // Enumeration complete
                break;
            }
        }

        return result;
    }

/// Members
private:
    Key m_key;
}


////////////////////////////////////////////////////////////////////////////////
// KeySequence

/// An enumerable sequence representing the sub-keys of a registry Key
///
/// It would be used as follows:
///
/// <code>&nbsp;&nbsp;Key&nbsp;key&nbsp;=&nbsp;. . .</code>
/// <br>
/// <code></code>
/// <br>
/// <code>&nbsp;&nbsp;foreach(Key k; key.SubKeys)</code>
/// <br>
/// <code>&nbsp;&nbsp;{</code>
/// <br>
/// <code>&nbsp;&nbsp;&nbsp;&nbsp;process_Key(k);</code>
/// <br>
/// <code>&nbsp;&nbsp;}</code>
/// <br>
/// <br>
///
/// \ingroup group_D_win32_reg

public class KeySequence
{
    invariant()
    {
        assert(!(null is m_key));
    }

/// Construction
private:
    this(Key key)
    {
        m_key = key;
    }

/// \name Attributes
///@{
public:
    /// The number of keys
    uint count()
    {
        return m_key.keyCount();
    }

    /// The key at the given index
    ///
    /// \param index The 0-based index of the key to retrieve
    /// \return The key corresponding to the given index
    /// \note Throws a RegistryException if no corresponding key is retrieved
    Key getKey(uint index)
    {
        HKey hkey = m_key.m_hkey;
        string name;
        if (!hkey.enumKeyName(index, name))
        {
            throw new RegistryException(sysErrorString(ERROR_NO_MORE_ITEMS), ERROR_NO_MORE_ITEMS);
        }

        return m_key.getKey(name);
    }

    /// The key at the given index
    ///
    /// \param index The 0-based index of the key to retrieve
    /// \return The key corresponding to the given index
    /// \note Throws a RegistryException if no corresponding key is retrieved
    Key opIndex(uint index)
    {
        return getKey(index);
    }
///@}

public:
    int opApply(scope int delegate(ref Key key) dg)
    {
        int result = 0;
        HKey hkey = m_key.m_hkey;

        for(DWORD index = 0; result == 0; ++index)
        {
            string name;
            if (hkey.enumKeyName(index, name))
            {
                try
                {
                    Key key =   m_key.getKey(name);
                    result = dg(key);
                }
                catch(RegistryException x)
                {
                    // Skip inaccessible keys; they are
                    // accessible via the KeyNameSequence
                    if(x.error == ERROR_ACCESS_DENIED)
                    {
                        continue;
                    }

                    throw x;
                }
            }
            else
            {
                // Enumeration complete
                break;
            }
        }

        return result;
    }

/// Members
private:
    Key m_key;
}

////////////////////////////////////////////////////////////////////////////////
// ValueNameSequence

/// An enumerable sequence representing the names of the values of a registry Key
///
/// It would be used as follows:
///
/// <code>&nbsp;&nbsp;Key&nbsp;key&nbsp;=&nbsp;. . .</code>
/// <br>
/// <code></code>
/// <br>
/// <code>&nbsp;&nbsp;foreach(char[] vName; key.Values)</code>
/// <br>
/// <code>&nbsp;&nbsp;{</code>
/// <br>
/// <code>&nbsp;&nbsp;&nbsp;&nbsp;process_Value(vName);</code>
/// <br>
/// <code>&nbsp;&nbsp;}</code>
/// <br>
/// <br>
///
/// \ingroup group_D_win32_reg

public class ValueNameSequence
{
    invariant()
    {
        assert(!(null is m_key));
    }

/// Construction
private:
    this(Key key)
    {
        m_key = key;
    }

/// \name Attributes
///@{
public:
    /// The number of values
    uint count()
    {
        return m_key.valueCount();
    }

    /// The name of the value at the given index
    ///
    /// \param index The 0-based index of the value to retrieve
    /// \return The name of the value corresponding to the given index
    /// \note Throws a RegistryException if no corresponding value is retrieved
    string getValueName(uint index)
    {
        HKey hkey = m_key.m_hkey;
		string name;
        if (!hkey.enumValueName(index, name))
        {
            throw new RegistryException(sysErrorString(ERROR_NO_MORE_ITEMS), ERROR_NO_MORE_ITEMS);
        }

        return name;
    }

    /// The name of the value at the given index
    ///
    /// \param index The 0-based index of the value to retrieve
    /// \return The name of the value corresponding to the given index
    /// \note Throws a RegistryException if no corresponding value is retrieved
    string opIndex(uint index)
    {
        return getValueName(index);
    }
///@}

public:
    int opApply(scope int delegate(ref string name) dg)
    {
        int result = 0;
        HKey hkey = m_key.m_hkey;

        for(DWORD index = 0; result == 0; ++index)
        {
			string name;
            if (hkey.enumValueName(index, name))
            {
                result = dg(name);
            }
            else
            {
                // Enumeration complete
                break;
            }
        }

        return result;
    }

/// Members
private:
    Key m_key;
}

////////////////////////////////////////////////////////////////////////////////
// ValueSequence

/// An enumerable sequence representing the values of a registry Key
///
/// It would be used as follows:
///
/// <code>&nbsp;&nbsp;Key&nbsp;key&nbsp;=&nbsp;. . .</code>
/// <br>
/// <code></code>
/// <br>
/// <code>&nbsp;&nbsp;foreach(Value v; key.Values)</code>
/// <br>
/// <code>&nbsp;&nbsp;{</code>
/// <br>
/// <code>&nbsp;&nbsp;&nbsp;&nbsp;process_Value(v);</code>
/// <br>
/// <code>&nbsp;&nbsp;}</code>
/// <br>
/// <br>
///
/// \ingroup group_D_win32_reg

public class ValueSequence
{
    invariant()
    {
        assert(!(null is m_key));
    }

/// Construction
private:
    this(Key key)
    {
        m_key = key;
    }

/// \name Attributes
///@{
public:
    /// The number of values
    uint count()
    {
        return m_key.valueCount();
    }

    /// The value at the given index
    ///
    /// \param index The 0-based index of the value to retrieve
    /// \return The value corresponding to the given index
    /// \note Throws a RegistryException if no corresponding value is retrieved
    Value getValue(uint index)
    {
        HKey    hkey    =   m_key.m_hkey;
		string name;
        if (!hkey.enumValueName(index, name))
        {
            throw new RegistryException(sysErrorString(ERROR_NO_MORE_ITEMS), ERROR_NO_MORE_ITEMS);
        }

        return m_key.getValue(name);
    }

    /// The value at the given index
    ///
    /// \param index The 0-based index of the value to retrieve
    /// \return The value corresponding to the given index
    /// \note Throws a RegistryException if no corresponding value is retrieved
    Value opIndex(uint index)
    {
        return getValue(index);
    }
///@}

public:
    int opApply(scope int delegate(ref Value value) dg)
    {
        int result = 0;
        HKey hkey = m_key.m_hkey;

        for(DWORD index = 0; result == 0; ++index)
        {
			string name;
            if (hkey.enumValueName(index, name))
            {
                Value value = m_key.getValue(name);

                result = dg(value);
            }
            else
            {
                // Enumeration complete
                break;
            }
        }

        return result;
    }

/// Members
private:
    Key m_key;
}

/* ////////////////////////////////////////////////////////////////////////// */

unittest
{
    Key HKCR    =   Registry.classesRoot;
    Key CLSID   =   HKCR.getKey("CLSID");

    foreach(Key key; CLSID.keys)
    {
        foreach(Value val; key.values)
        {
        }
    }
}

unittest
{
	// Warning: This unit test writes to the registry.
	// The test can fail if you don't have sufficient rights
    Key HKCU = Registry.currentUser;
    assert(HKCU);
    
    // Enumerate all subkeys of key Software
    Key softwareKey = HKCU.getKey("Software");
    assert(softwareKey);
    foreach (Key key; softwareKey.keys)
    {
    	//writefln("Key %1$s", key.name());
    }
    
    // Create a new key
    string unittestKeyName = "Temporary key for a D UnitTest which can be deleted afterwards";
    Key unittestKey = HKCU.createKey(unittestKeyName); 
    assert(unittestKey);
    Key cityKey = unittestKey.createKey("CityCollection using foreign names with umlauts and accents: öäüÖÄÜàáâß");
    cityKey.setValue("Köln", "Germany");
    cityKey.setValue("Минск", "Belorussia");
    foreach (Value v; cityKey.values)
    {
    	//writefln("Name %1$s", v.name());
    }
    Key stateKey = unittestKey.createKey("StateCollection");
    stateKey.setValue("Germany", ["Düsseldorf", "Köln", "Hamburg"]);
    Value v = stateKey.getValue("Germany");
    string[] actual = v.value_MULTI_SZ;
    assert(actual.length == 3);
    assert(actual[0] == "Düsseldorf");
    assert(actual[1] == "Köln");
    assert(actual[2] == "Hamburg");
    
    //HKCU.deleteKey(unittestKeyName);
}

/* ////////////////////////////////////////////////////////////////////////// */
