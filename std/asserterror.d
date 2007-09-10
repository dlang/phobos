
module std.assertexception;

class AssertError : Object
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
     * If nobody catches the AssertError, this winds up
     * getting called by the startup code.
     */

    void print()
    {
	printf("AssertError Failure %s(%u)\n", (char *)filename, linnum);
    }
}


/********************************************
 * Called by the compiler generated module assert function.
 * Builds an AssertError exception and throws it.
 */

extern (C) static void _d_assert(char[] filename, uint line)
{
    //printf("_d_assert(%s, %d)\n", (char *)filename, line);
    AssertError a = new AssertError(filename, line);
    //printf("assertion %p created\n", a);
    throw a;
}
