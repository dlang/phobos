/**
Interpolates the given string into a code that creates a tuple of string literals and expressions.
The code returned should be passed to `mixin` in order to create the tuple.

Example:
---
int a = 42;

writeln(mixin(interp("a is $(a)")));
// same as: writeln(mixin(`std.typecons.tuple("a is ", a).expand`));

// Output:
// a is 42
---
*/
string interp(string str, string file = __FILE__, size_t line = __LINE__) pure @safe
{
    return "() {import std.typecons : tuple; return tuple(" ~
        interpToCommaExpression(str, file, line) ~ ");}().expand";
}

///
@safe unittest
{
    import std.conv : text;

    assert("1+2=3" == text(mixin(interp("1+2=$(1+2)"))));

    int a = 42;
    assert("a is 42" == text(mixin(interp("a is $(a)"))));
}

/**
Expands `str` to a comma-separated list of string literals and expressions.
*/
private string interpToCommaExpression(string str, string file, size_t line) pure @safe
{
    if (str.length == 0)
        return "";
    if (str[0] == '$' && (str.length < 2 || str[1] != '$'))
        return interpExpression(str[1 .. $], file, line);

    string result = `"`;
    size_t mark = 0;
    size_t index = 0;
    for (;;)
    {
        auto c = str[index++];
        if (c == '$')
        {
            if (index >= str.length || str[index] != '$')
                return result ~ str[mark .. index - 1] ~ `", ` ~
                    interpExpression(str[index .. $], file, line);
            result ~= str[mark .. index];
            index++;
            mark = index;
        }
        else if (c == '"' || c == '\\')
        {
            result ~= str[mark .. index - 1] ~ "\\";
            mark = index - 1;
        }

        if (index >= str.length)
        {
            return result ~ str[mark .. index] ~ `"`;
        }
    }
}

// This unit test block is only testing the code paths that
// stay inside the `interpToCommaExpression` function
unittest
{
    assert(`` == interpToCommaExpression(null, __FILE__, __LINE__));
    assert(`"a"` == interpToCommaExpression(`a`, __FILE__, __LINE__));
    assert(`"foo"` == interpToCommaExpression(`foo`, __FILE__, __LINE__));
    assert(`"\""`  == interpToCommaExpression(`"`, __FILE__, __LINE__));
    assert(`"\\"`  == interpToCommaExpression(`\`, __FILE__, __LINE__));
    assert(`"\"foo\\\"bar\"\\baz\\\\\"\"bon"`  == interpToCommaExpression(`"foo\"bar"\baz\\""bon`, __FILE__, __LINE__));

    // test double-dollars
    assert(`"$"`  == interpToCommaExpression(`$$`, __FILE__, __LINE__));
    assert(`"$$"`  == interpToCommaExpression(`$$$$`, __FILE__, __LINE__));
    assert(`"a$"`  == interpToCommaExpression(`a$$`, __FILE__, __LINE__));
    assert(`"$a"`  == interpToCommaExpression(`$$a`, __FILE__, __LINE__));
    assert(`"abc$def$ghi"`  == interpToCommaExpression(`abc$$def$$ghi`, __FILE__, __LINE__));
}

/**
Interpolate an expression. `str` starts with an expression to interpolate.
*/
private string interpExpression(string str, string file, size_t line) pure @safe
{
    if (str[0] == '(')
    {
        uint depth = 1;
        size_t i = 1;
        for (;; i++)
        {
            if (i >= str.length)
                throw new InterpolateException("unterminted $(...) expression", file, line);
            if (str[i] == ')')
            {
                depth--;
                if (depth == 0)
                    break;
            }
            else if (str[i] == '(')
            {
                depth++;
            }
        }
        if (i == str.length - 1)
            return str[1 .. i];

        return (str[1 .. i] == "" ? "" : str[1 .. i] ~ `,`) ~ interpToCommaExpression(str[i + 1 .. $], file, line);
    }
    else
        throw new InterpolateException("interpolated expression $ currently requires parens $(...)", file, line);
}

/**
Thrown when an invalid string is passed to `interp`.
*/
class InterpolateException : Exception
{
    this(string msg, string file, size_t line) pure @safe
    {
        super(msg, file, line);
    }
}

unittest
{
    import std.conv : text;
    
    static assert(mixin(interp("$()")).length == 0);
    static assert(mixin(interp("$(/* a comment!*/)")).length == 0);
    static assert(mixin(interp("$(/+ yet another comment+/)")).length == 0);
    static assert(mixin(interp("$()foo")).length == 1);

    {
        int a = 42;
        assert("a is 42" == text(mixin(interp("a is $(a)"))));
        assert("a + 23 is 65" == text(mixin(interp("a + 23 is $(a + 23)"))));

        // test each type of string literal
        int b = 93;
        assert("42 + 93 = 135" == text(mixin(interp(  "$(a) + $(b) = $(a + b)"))));  // double-quote
        assert("42 + 93 = 135" == text(mixin(interp( r"$(a) + $(b) = $(a + b)"))));  // wysiwyg
        assert("42 + 93 = 135" == text(mixin(interp(  `$(a) + $(b) = $(a + b)`))));  // wysiwyg (alt)
        assert("42 + 93 = 135" == text(mixin(interp( q{$(a) + $(b) = $(a + b)}))));  // token
        assert("42 + 93 = 135" == text(mixin(interp(q"!$(a) + $(b) = $(a + b)!")))); // delimited (char)
        assert("42 + 93 = 135\n" == text(mixin(interp(q"ABC
$(a) + $(b) = $(a + b)
ABC")))); // delimited (heredoc)

        // Escaping double dollar
        assert("$" == mixin(interp("$$"))[0]);
        assert(" $ " == mixin(interp(" $$ "))[0]);
        assert(" $(just raw string) " == mixin(interp(" $$(just raw string) "))[0]);
        assert("Double dollar $$ becomes $" == text(mixin(interp("Double dollar $$$$ becomes $$"))));
    }

    string funcCode(string attributes, string returnType, string name, string args, string body)
    {
        return text(mixin(interp(q{
        $(attributes) $(returnType) $(name)($(args))
        {
            $(body)
        }
        })));
    }
    {
        mixin(funcCode("pragma(inline)", "int", "add", "int a, int b", "return a + b;"));
        assert(928 == add(900, 28));
    }
}
