
import object;
import c.stdio;

class ArrayBoundsError : Object
{
  private:

    uint linnum;
    char[] filename;

    this(char[] filename, uint linnum)
    {
	this.linnum = linnum;
	this.filename = filename;
    }

  public:

    /***************************************
     * If nobody catches the ArrayBoundsError, this winds up
     * getting called by the startup code.
     */

    void print()
    {
	printf("ArrayBoundsError %s(%u)\n", (char *)filename, linnum);
    }
}


/********************************************
 * Called by the compiler generated module assert function.
 * Builds an ArrayBoundsError exception and throws it.
 */

extern (C) static void _d_array_bounds(char[] filename, uint line)
{
    //printf("_d_assert(%s, %d)\n", (char *)filename, line);
    ArrayBoundsError a = new ArrayBoundsError(filename, line);
    //printf("assertion %p created\n", a);
    throw a;
}
