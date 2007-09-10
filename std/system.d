
/* Written by Walter Bright
 * www.digitalmars.com
 * Placed into Public Domain
 */

// Information about the target operating system, environment, and CPU

module std.system;

const
{

    // Operating system family
    enum Family
    {
	Win32 = 1,		// Microsoft 32 bit Windows systems
	linux,			// all linux systems
    }

    version (Win32)
    {
	Family family = Family.Win32;
    }
    else version (linux)
    {
	Family family = Family.linux;
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
	WindowsNT,
	Windows2000,

	RedHatLinux,
    }

    // Big-endian or Little-endian?

    enum Endian { BigEndian, LittleEndian }

    version(LittleEndian)
    {
        Endian endian = Endian.LittleEndian;
    }
    else
    {
        Endian endian = Endian.BigEndian;
    }
}

// The rest should get filled in dynamically at runtime

OS os = OS.WindowsNT;

// Operating system version as in
// os_major.os_minor
uint os_major = 4;
uint os_minor = 0;


// processor: i386
