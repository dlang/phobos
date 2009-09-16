// Written in the D programming language.

/**
 * Information about the target operating system, environment, and CPU
 *
 * Macros:
 *      WIKI = Phobos/StdSystem
 *
 * Copyright: Copyright Digital Mars 2000 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   $(WEB digitalmars.com, Walter Bright)
 *
 *          Copyright Digital Mars 2000 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.system;

const
{

    // Operating system family
    enum Family
    {
        Win32 = 1,              // Microsoft 32 bit Windows systems
        linux,                  // all linux systems
        OSX,
    }

    version (Win32)
    {
        Family family = Family.Win32;
    }
    else version (Posix)
    {
        Family family = Family.linux;
    }
    else version (OSX)
    {
        Family family = Family.OSX;
    }
    else
    {
        static assert(0);
    }

    // More specific operating system name
    enum OS
    {
        Windows95 = 1,
        Windows98,
        WindowsME,
        WindowsNT,
        Windows2000,
        WindowsXP,

        RedHatLinux,
        OSX,
    }

    /// Byte order endianness

    enum Endian
    {
        BigEndian,      /// big endian byte order
        LittleEndian    /// little endian byte order
    }

    version(LittleEndian)
    {
        /// Native system endianness
        Endian endian = Endian.LittleEndian;
    }
    else
    {
        Endian endian = Endian.BigEndian;
    }
}

// The rest should get filled in dynamically at runtime

OS os = OS.WindowsXP;

// Operating system version as in
// os_major.os_minor
uint os_major = 4;
uint os_minor = 0;


