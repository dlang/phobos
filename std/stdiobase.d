module std.stdiobase;

extern(C) void std_stdio_static_this();

static this()
{
    std_stdio_static_this;
}
