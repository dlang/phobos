module std.delegatefunction;

// Alternative library implementation to DIP 1011 extern(delegate)
string generateDelegateFunctionCode(string functionName, string templateArguments, string postDeclCode,
    string contextType, string contextVarName, string arguments, string code)
{
    import std.format : format;
    return `struct ` ~ functionName ~ templateArguments ~ postDeclCode ~ `
{
    ` ~ contextType ~ ` ` ~ contextVarName ~ `;
    auto opCall(` ~ arguments ~ `)
    {` ~ code ~ `
    }
    pragma(inline) static auto opCall(ref ` ~ contextType ~ ` ` ~ contextVarName ~
        ( (arguments.length == 0) ? "" : ", ") ~ arguments ~ `)
    {
        return (cast(` ~ functionName ~ `*)&` ~ contextVarName ~ `).opCall(` ~
            format("%s", arguments.formatArgNamesOnly) ~ `);
    }
    // NOTE: this doesn't quite work yet if there are template parameters
    pragma(inline) static ref auto createDelegate(return ref ` ~ contextType ~ ` ` ~ contextVarName ~ `)
    {
        return &(cast(` ~ functionName ~ `*)&` ~ contextVarName ~ `).opCall;
    }
}
`;
}
mixin template delegateFunction(T...)
{
    enum Code = generateDelegateFunctionCode(T);
    pragma(msg, Code);
    mixin(Code);
}

bool isIdentifierStart(char c)
{
    return (c >= 'a' && c <= 'z') ||
           (c >= 'A' && c <= 'Z') ||
           c == '_';
}
bool isIdentifierChar(char c)
{
    return isIdentifierStart(c) ||
        (c >= '0' && c <= '9');
}
bool isWhitespace(char c)
{
    return c == ' ' || c == '\r' || c == '\n' || c == '\v';
}
// Take a list of arguments and reformats it with only the names
@property auto formatArgNamesOnly(string args)
{
    struct Formatter
    {
        string args;
        void toString(scope void delegate(const(char)[]) sink) const
        {
            if(args.length == 0)
            {
                return;
            }

            size_t next = 0;
            for(;;)
            {
                if(next == args.length)
                {
                    assert(0, "invalid args format");
                }
                char c = args[next];
                if(!isIdentifierStart(c))
                {
                    next++;
                }
                else
                {
                    auto idStart = next;
                    for(;;)
                    {
                        next++;
                        if(next == args.length)
                        {
                            sink(args[idStart..next]);
                            return;
                        }
                        c = args[next];
                        if(!isIdentifierChar(c))
                        {
                            break;
                        }
                    }
                    auto idLimit = next;
                    for(; isWhitespace(c); )
                    {
                        next++;
                        if(next == args.length)
                        {
                            sink(args[idStart..idLimit]);
                            return;
                        }
                        c = args[next];
                    }
                    if(c == ',')
                    {
                        sink(args[idStart..idLimit]);
                        sink(", ");
                    }
                }
            }
        }
    }
    return Formatter(args);
}