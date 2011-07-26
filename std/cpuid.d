// Written in the D programming language.

/**
 * $(RED Scheduled for deprecation. Please use core.cpuid instead.)
 *
 * Identify the characteristics of the host CPU.
 *
 * Implemented according to:

- AP-485 Intel(C) Processor Identification and the CPUID Instruction
        $(LINK http://www.intel.com/design/xeon/applnots/241618.htm)

- Intel(R) 64 and IA-32 Architectures Software Developer's Manual, Volume 2A: Instruction Set Reference, A-M
        $(LINK http://developer.intel.com/design/pentium4/manuals/index_new.htm)

- AMD CPUID Specification Publication # 25481
        $(LINK http://www.amd.com/us-en/assets/content_type/white_papers_and_tech_docs/25481.pdf)

Example:
---
import std.cpuid;
import std.stdio;

void main()
{
    writefln(std.cpuid.toString());
}
---

BUGS: Only works on x86 CPUs

Macros:
    WIKI = Phobos/StdCpuid

Copyright: Copyright Tomas Lindquist Olsen 2007 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   Tomas Lindquist Olsen &lt;tomas@famolsen.dk&gt;
Source:    $(PHOBOSSRC std/_cpuid.d)
*/
/*
 *          Copyright Tomas Lindquist Olsen 2007 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module std.cpuid;

import std.string;
import std.conv;
private import core.cpuid;

version(D_InlineAsm_X86)
{
    /// Returns everything as a printable string
    string toString()
    {
        string feats;
        if (mmx)                feats ~= "MMX ";
        if (fxsr)               feats ~= "FXSR ";
        if (sse)                feats ~= "SSE ";
        if (sse2)               feats ~= "SSE2 ";
        if (sse3)               feats ~= "SSE3 ";
        if (ssse3)              feats ~= "SSSE3 ";
        if (amd3dnow)           feats ~= "3DNow! ";
        if (amd3dnowExt)        feats ~= "3DNow!+ ";
        if (amdMmx)             feats ~= "MMX+ ";
        if (ia64)               feats ~= "IA-64 ";
        if (amd64)              feats ~= "AMD64 ";
        if (hyperThreading)     feats ~= "HTT";

        return format(
            "Vendor string:    %s\n", vendor,
            "Processor string: %s\n", processor,
            "Signature:        Family=%d Model=%d Stepping=%d\n", family, model, stepping,
            "Features:         %s\n", feats,
            "Multithreading:   %d threads / %d cores\n", threadsPerCPU, coresPerCPU);

    }

    /// Returns vendor string
    alias core.cpuid.vendor vendor;
    /// Returns processor string
    alias core.cpuid.processor processor;

    /// Is MMX supported?
    alias core.cpuid.mmx mmx;
    /// Is FXSR supported?
    alias core.cpuid.hasFxsr fxsr;
    /// Is SSE supported?
    alias core.cpuid.sse sse;
    /// Is SSE2 supported?
    alias core.cpuid.sse2 sse2;
    /// Is SSE3 supported?
    alias core.cpuid.sse3 sse3;
    /// Is SSSE3 supported?
    alias core.cpuid.ssse3 ssse3;

    /// Is AMD 3DNOW supported?
    alias core.cpuid.amd3dnow amd3dnow;
    /// Is AMD 3DNOW Ext supported?
    alias core.cpuid.amd3dnowExt amd3dnowExt;
    /// Is AMD MMX supported?
    alias core.cpuid.amdMmx amdMmx;

    /// Is this an Intel Architecture IA64?
    alias core.cpuid.isItanium ia64;
    /// Is this an AMD 64?
    alias core.cpuid.isX86_64 amd64;

    /// Is hyperthreading supported?
    alias core.cpuid.hyperThreading hyperThreading;
    /// Returns number of threads per CPU
    alias core.cpuid.threadsPerCPU threadsPerCPU;
    /// Returns number of cores in CPU
    alias core.cpuid.coresPerCPU coresPerCPU;

    /// Is this an Intel processor?
    bool intel()                {return manufac==INTEL;}
    /// Is this an AMD processor?
    bool amd()                  {return manufac==AMD;}

    /// Returns stepping
    uint stepping()             {return core.cpuid.stepping;}
    /// Returns model
    uint model()                {return core.cpuid.model;}
    /// Returns family
    uint family()               {return core.cpuid.family;}

    shared static this()
    {
        switch (vendor())
        {
        case "GenuineIntel":
            manufac = INTEL;
            break;

        case "AuthenticAMD":
            manufac = AMD;
            break;

        default:
            manufac = OTHER;
        }
    }

    private:
    // manufacturer
    enum
    {
        OTHER,
        INTEL,
        AMD
    }

    __gshared
    {
    uint manufac=OTHER;
    }
}
else
{
    auto toString() { return "unknown CPU\n"; }

    auto vendor()             {return "unknown vendor"; }
    auto processor()          {return "unknown processor"; }

    bool mmx()                  {return false; }
    bool fxsr()                 {return false; }
    bool sse()                  {return false; }
    bool sse2()                 {return false; }
    bool sse3()                 {return false; }
    bool ssse3()                {return false; }

    bool amd3dnow()             {return false; }
    bool amd3dnowExt()          {return false; }
    bool amdMmx()               {return false; }

    bool ia64()                 {return false; }
    bool amd64()                {return false; }

    bool hyperThreading()       {return false; }
    uint threadsPerCPU()        {return 0; }
    uint coresPerCPU()          {return 0; }

    bool intel()                {return false; }
    bool amd()                  {return false; }

    uint stepping()             {return 0; }
    uint model()                {return 0; }
    uint family()               {return 0; }
}
