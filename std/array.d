// Written in the D programming language

module std.array;

private import std.c.stdio;
import std.contracts;

class ArrayBoundsError : Error
{
  private:

    uint linnum;
    string filename;

  public:
    this(string filename, uint linnum)
    {
	this.linnum = linnum;
	this.filename = filename;

	char[] buffer = new char[19 + filename.length + linnum.sizeof * 3 + 1];
	auto len = sprintf(buffer.ptr,
                           "ArrayBoundsError %.*s(%u)", filename, linnum);
        buffer = buffer[0..len];
	super(assumeUnique(buffer)); // fine because buffer is unaliased
    }
}


/********************************************
 * Called by the compiler generated module assert function.
 * Builds an ArrayBoundsError exception and throws it.
 */

extern (C) static void _d_array_bounds(string filename, uint line)
{
    //printf("_d_assert(%s, %d)\n", (char *)filename, line);
    ArrayBoundsError a = new ArrayBoundsError(filename, line);
    //printf("assertion %p created\n", a);
    throw a;
}
