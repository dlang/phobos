/**
For testing only.
Provides a struct with UDA's defined in an external module.
Useful for validating behavior with member privacy.
*/
module std.internal.test.uda;

enum Attr;

struct HasPrivateMembers
{
  @Attr int a;
  int b;
  @Attr private int c;
  private int d;
}

// If getSymbolsByUDA is mixed into the same scope it also returns private members
unittest
{
    import std.traits : getSymbolsByUDA, hasUDA;
    mixin getSymbolsByUDA!(HasPrivateMembers, Attr) symbols;
    static assert(symbols.getSymbolsByUDA.length == 2);
    static assert(hasUDA!(symbols.getSymbolsByUDA[0], Attr));
    static assert(hasUDA!(symbols.getSymbolsByUDA[1], Attr));
}
