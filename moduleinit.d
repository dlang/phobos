
import object;
import stdio;
import stdlib;
import string;

enum
{   MIctorstart = 1,	// we've started constructing it
    MIctordone = 2,		// finished construction
}

class ModuleInfo
{
    char name[];
    ModuleInfo importedModules[];
    ClassInfo localClasses[];

    uint flags;		// initialization state

    void (*ctor)();
    void (*dtor)();
    void (*unitTest)();
}

class ModuleCtorError : Exception
{
    this(ModuleInfo m)
    {
	msg = "circular initialization dependency with module " ~ m.name;
    }
}

// This gets initialized by minit.asm
extern (C) ModuleInfo[] _moduleinfo_array;

ModuleInfo[] _moduleinfo_dtors;
uint _moduleinfo_dtors_i;

// Register termination function pointers
extern (C) int _fatexit(void *);

/*************************************
 * Initialize the modules.
 */

extern (C) void _moduleCtor()
{
    // Ensure module destructors also get called on program termination
    _fatexit(&_moduleDtor);

    _moduleinfo_dtors = new ModuleInfo[_moduleinfo_array.length];
    _moduleCtor2(_moduleinfo_array);
}

void _moduleCtor2(ModuleInfo[] mi)
{
    //printf("_moduleCtor2(): %d modules\n", mi.length);
    for (uint i = 0; i < mi.length; i++)
    {
	ModuleInfo m = mi[i];

	if (m.flags & MIctordone)
	    continue;
	//printf("\tmodule[%d] = '%.*s'\n", i, m.name);

	if (m.ctor || m.dtor)
	{
	    if (m.flags & MIctorstart)
		throw new ModuleCtorError(m);

	    m.flags |= MIctorstart;
	    _moduleCtor2(m.importedModules);
	    if (m.ctor)
		(*m.ctor)();
	    m.flags &= ~MIctorstart;
	    m.flags |= MIctordone;

	    // Now that construction is done, register the destructor
	    assert(_moduleinfo_dtors_i < _moduleinfo_dtors.length);
	    _moduleinfo_dtors[_moduleinfo_dtors_i++] = m;
	}
	else
	{
	    m.flags |= MIctordone;
	    _moduleCtor2(m.importedModules);
	}
    }
}


/**********************************
 * Destruct the modules.
 */

extern (C) void _moduleDtor()
{
    //printf("_moduleDtor(): %d modules\n", _moduleinfo_dtors.length);
    for (uint i = _moduleinfo_dtors_i; i-- != 0;)
    {
	ModuleInfo m = _moduleinfo_dtors[i];

	//printf("\tmodule[%d] = '%.*s'\n", i, m.name);
	if (m.dtor)
	{
	    (*m.dtor)();
	}
    }
}

/**********************************
 * Run unit tests.
 */

extern (C) void _moduleUnitTests()
{
    //printf("_moduleUnitTests()\n");
    for (uint i = 0; i < _moduleinfo_array.length; i++)
    {
	ModuleInfo m = _moduleinfo_array[i];

	//printf("\tmodule[%d] = '%.*s'\n", i, m.name);
	if (m.unitTest)
	{
	    (*m.unitTest)();
	}
    }
}

