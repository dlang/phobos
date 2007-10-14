// Written in the D programming language

module std.hiddenfunc;

import std.stdio;

class HiddenFuncError : Error
{
  private:

    this(ClassInfo ci)
    {
	super("hidden method called for " ~ ci.name);
    }
}

/********************************************
 * Called by the compiler generated module assert function.
 * Builds an Assert exception and throws it.
 */

extern (C) static void _d_hidden_func()
{   Object o;
    asm
    {
	mov o, EAX;
    }

    //printf("_d_hidden_func()\n");
    HiddenFuncError a = new HiddenFuncError(o.classinfo);
    //printf("assertion %p created\n", a);
    throw a;
}
