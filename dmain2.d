
import object;
import c.stdio;
import c.stdlib;
import string;

extern (C) void _STI_monitor_staticctor();
extern (C) void _STD_monitor_staticdtor();
extern (C) void _STI_critical_init();
extern (C) void _STD_critical_term();
extern (C) void gc_init();
extern (C) void gc_term();
extern (C) void _minit();
extern (C) void _moduleCtor();
extern (C) void _moduleDtor();
extern (C) void _moduleUnitTests();

/***********************************
 * The D main() function supplied by the user's program
 */
int main(char[][] args);

/***********************************
 * Substitutes for the C main() function.
 * It's purpose is to wrap the call to the D main()
 * function and catch any unhandled exceptions.
 */

extern (C) int main(int argc, char **argv)
{
    char[] *am;
    char[][] args;
    int i;
    int result;

    version (linux)
    {
	_STI_monitor_staticctor();
	_STI_critical_init();
	gc_init();
	//am = (char[] *) malloc(argc * (char[]).size);
	am = (char[] *) alloca(argc * (char[]).size);
    }
    version (Win32)
    {
	gc_init();
	_minit();
	am = (char[] *) alloca(argc * (char[]).size);
    }

    try
    {
	_moduleCtor();
	_moduleUnitTests();

	for (i = 0; i < argc; i++)
	{
	    int len = strlen(argv[i]);
	    am[i] = argv[i][0 .. len];
	}

	args = am[0 .. argc];

	result = main(args);
    }

    catch (Object o)
    {
	printf("Error: ");
	o.print();
	result = EXIT_FAILURE;
    }

    _moduleDtor();
    gc_term();
    version (linux)
    {
	//free(am);
	_STD_critical_term();
	_STD_monitor_staticdtor();
    }
    return result;
}

