// Written in the D programming language

module std.moduleinit;

//debug = 1;

private
{
    import object;
    import std.stdio;
    import std.c.stdio;
    import std.c.stdlib;
    import std.string;
}

enum
{   MIctorstart = 1,    // we've started constructing it
    MIctordone = 2,     // finished construction
    MIstandalone = 4,   // module ctor does not depend on other module
                        // ctors being done first
    MIhasictor = 8,     // has ictor member
}

/***********************
 * Information about each module.
 */
class ModuleInfo
{
    char name[];
    ModuleInfo importedModules[];
    ClassInfo localClasses[];

    uint flags;         // initialization state

    void (*ctor)();     // module static constructor (order dependent)
    void (*dtor)();     // module static destructor
    void (*unitTest)(); // module unit tests

    void* xgetMembers;  // module getMembers() function

    void (*ictor)();    // module static constructor (order independent)

    /******************
     * Return collection of all modules in the program.
     */
    static ModuleInfo[] modules()
    {
        return _moduleinfo_array;
    }
}

class ModuleCtorError : Exception
{
    this(ModuleInfo m)
    {
        super(cast(string) ("circular initialization dependency with module "
                            ~ m.name));
    }
}


// Win32: this gets initialized by minit.asm
// linux: this gets initialized in _moduleCtor()
// OSX: this gets initialized in _moduleCtor()
extern (C) ModuleInfo[] _moduleinfo_array;

version (linux)
{
    // This linked list is created by a compiler generated function inserted
    // into the .ctor list by the compiler.
    struct ModuleReference
    {
        ModuleReference* next;
        ModuleInfo mod;
    }

    extern (C) ModuleReference *_Dmodule_ref;   // start of linked list
}

version (FreeBSD)
{
    // This linked list is created by a compiler generated function inserted
    // into the .ctor list by the compiler.
    struct ModuleReference
    {
        ModuleReference* next;
        ModuleInfo mod;
    }

    extern (C) ModuleReference *_Dmodule_ref;   // start of linked list
}

version (Solaris)
{
    // This linked list is created by a compiler generated function inserted
    // into the .ctor list by the compiler.
    struct ModuleReference
    {
       ModuleReference* next;
       ModuleInfo mod;
    }

    extern (C) ModuleReference *_Dmodule_ref;  // start of linked list
}

version (OSX)
{
    extern (C)
    {
        extern void* _minfo_beg;
        extern void* _minfo_end;
    }
}

ModuleInfo[] _moduleinfo_dtors;
uint _moduleinfo_dtors_i;

// Register termination function pointers
extern (C) int _fatexit(void *);

/*************************************
 * Initialize the modules.
 */

extern (C) void _moduleCtor()
{
    debug printf("_moduleCtor()\n");

    version (linux)
    {
        int len = 0;
        ModuleReference *mr;

        for (mr = _Dmodule_ref; mr; mr = mr.next)
            len++;
        _moduleinfo_array = new ModuleInfo[len];
        len = 0;
        for (mr = _Dmodule_ref; mr; mr = mr.next)
        {   _moduleinfo_array[len] = mr.mod;
            len++;
        }
    }

    version (FreeBSD)
    {
        int len = 0;
        ModuleReference *mr;

        for (mr = _Dmodule_ref; mr; mr = mr.next)
            len++;
        _moduleinfo_array = new ModuleInfo[len];
        len = 0;
        for (mr = _Dmodule_ref; mr; mr = mr.next)
        {   _moduleinfo_array[len] = mr.mod;
            len++;
        }
    }

    version (Solaris)
    {
       int len = 0;
       ModuleReference *mr;

       for (mr = _Dmodule_ref; mr; mr = mr.next)
           len++;
       _moduleinfo_array = new ModuleInfo[len];
       len = 0;
       for (mr = _Dmodule_ref; mr; mr = mr.next)
       {   _moduleinfo_array[len] = mr.mod;
           len++;
       }
    }

    version (OSX)
    {   /* The ModuleInfo references are stored in the special segment
         * __minfodata, which is bracketed by the segments __minfo_beg
         * and __minfo_end. The variables _minfo_beg and _minfo_end
         * are of zero size and are in the two bracketing segments,
         * respectively.
         */
        size_t length = cast(ModuleInfo*)&_minfo_end - cast(ModuleInfo*)&_minfo_beg;
        _moduleinfo_array = (cast(ModuleInfo*)&_minfo_beg)[0 .. length];
        debug printf("moduleinfo: ptr = %p, length = %d\n", _moduleinfo_array.ptr, _moduleinfo_array.length);

        debug foreach (m; _moduleinfo_array)
        {
            //printf("\t%p\n", m);
            printf("\t%.*s\n", m.name);
        }
    }

    version (Win32)
    {
        // Ensure module destructors also get called on program termination
        //_fatexit(&_STD_moduleDtor);
    }

    _moduleinfo_dtors = new ModuleInfo[_moduleinfo_array.length];
    debug printf("_moduleinfo_dtors = x%x\n", cast(void *)_moduleinfo_dtors);
    _moduleIndependentCtors();
    _moduleCtor2(_moduleinfo_array, 0);

    version (none)
    {
        foreach (m; _moduleinfo_array)
        {
            writefln("module %s, %d", m.name, m.localClasses.length);
            foreach (c; m.localClasses)
            {
                writefln("\tclass %s", c.name);
            }
        }
    }
}

void _moduleCtor2(ModuleInfo[] mi, int skip)
{
    debug printf("_moduleCtor2(): %d modules\n", mi.length);
    for (uint i = 0; i < mi.length; i++)
    {
        ModuleInfo m = mi[i];

        debug printf("\tmodule[%d] = '%p'\n", i, m);
        if (!m)
            continue;
        debug printf("\tmodule[%d] = '%.*s'\n", i, m.name);
        if (m.flags & MIctordone)
            continue;
        debug printf("\tmodule[%d] = '%.*s', m = x%x, m.flags = x%x\n", i, m.name, m, m.flags);

        if (m.ctor || m.dtor)
        {
            if (m.flags & MIctorstart)
            {   if (skip || m.flags & MIstandalone)
                    continue;
                throw new ModuleCtorError(m);
            }

            m.flags |= MIctorstart;
            _moduleCtor2(m.importedModules, 0);
            if (m.ctor)
                (*m.ctor)();
            m.flags &= ~MIctorstart;
            m.flags |= MIctordone;

            // Now that construction is done, register the destructor
            //printf("\tadding module dtor x%x\n", m);
            assert(_moduleinfo_dtors_i < _moduleinfo_dtors.length);
            _moduleinfo_dtors[_moduleinfo_dtors_i++] = m;
        }
        else
        {
            m.flags |= MIctordone;
            _moduleCtor2(m.importedModules, 1);
        }
    }
}


/**********************************
 * Destruct the modules.
 */

// Starting the name with "_STD" means under linux a pointer to the
// function gets put in the .dtors segment.

extern (C) void _moduleDtor()
{
    debug printf("_moduleDtor(): %d modules\n", _moduleinfo_dtors_i);
    for (uint i = _moduleinfo_dtors_i; i-- != 0;)
    {
        ModuleInfo m = _moduleinfo_dtors[i];

        debug printf("\tmodule[%d] = '%.*s', x%x\n", i, m.name, m);
        if (m.dtor)
        {
            (*m.dtor)();
        }
    }
    debug printf("_moduleDtor() done\n");
}

/**********************************
 * Run unit tests.
 */

extern (C) void _moduleUnitTests()
{
    debug printf("_moduleUnitTests()\n");
    for (uint i = 0; i < _moduleinfo_array.length; i++)
    {
        ModuleInfo m = _moduleinfo_array[i];

        if (!m)
            continue;

        debug printf("\tmodule[%d] = '%.*s'\n", i, m.name);
        if (m.unitTest)
        {
            (*m.unitTest)();
        }
    }
}

/**********************************
 * Run unit tests.
 */

extern (C) void _moduleIndependentCtors()
{
    debug printf("_moduleIndependentCtors()\n");
    foreach (m; _moduleinfo_array)
    {
        if (m && m.flags & MIhasictor && m.ictor)
        {
            (*m.ictor)();
        }
    }
}


