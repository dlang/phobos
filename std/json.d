// Written in the D programming language.

/**
JavaScript Object Notation

Copyright: Copyright Jeremie Pelletier 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   Jeremie Pelletier, David Herberth
References: $(LINK http://json.org/)
Source:    $(PHOBOSSRC std/_json.d)
*/
/*
         Copyright Jeremie Pelletier 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.json;

import std.ascii;
import std.conv;
import std.range;
import std.utf;
import std.traits;
import std.exception;

private
{
    // Prevent conflicts from these generic names
    alias std.utf.stride UTFStride;
    alias std.utf.decode toUnicode;
}

/**
JSON type enumeration
*/
enum JSON_TYPE : byte
{
    /// Indicates the type of a $(D JSONValue).
    STRING,
    INTEGER, /// ditto
    UINTEGER,/// integers > 2^63-1
    FLOAT,   /// ditto
    OBJECT,  /// ditto
    ARRAY,   /// ditto
    TRUE,    /// ditto
    FALSE,   /// ditto
    NULL     /// ditto
}

/**
JSON value node
*/
struct JSONValue
{
    ///
    union Store
    {
        /// Value when $(D type) is $(D JSON_TYPE.STRING).
        string                          str;
        /// Value when $(D type) is $(D JSON_TYPE.INTEGER).
        long                            integer;
        /// Value when $(D type) is $(D JSON_TYPE.UINTEGER).
        ulong                           uinteger;
        /// Value when $(D type) is $(D JSON_TYPE.FLOAT).
        real                            floating;
        /// Value when $(D type) is $(D JSON_TYPE.OBJECT).
        JSONValue[string]               object;
        /// Value when $(D type) is $(D JSON_TYPE.ARRAY).
        JSONValue[]                     array;
    }
    ///
    Store store;

    /// Specifies the _type of the value stored in this structure.
    JSON_TYPE type;

    /// Typesafe way of accessing $(D store.str).
    /// Throws $(D JSONException) if $(D type) is not $(D JSON_TYPE.STRING).
    @property ref inout(string) str() inout
    {
        enforceEx!JSONException(type == JSON_TYPE.STRING,
                                "JSONValue is not a string");
        return store.str;
    }

    /// Typesafe way of accessing $(D store.integer).
    /// Throws $(D JSONException) if $(D type) is not $(D JSON_TYPE.INTEGER).
    @property ref inout(long) integer() inout
    {
        enforceEx!JSONException(type == JSON_TYPE.INTEGER,
                                "JSONValue is not an integer");
        return store.integer;
    }

    /// Typesafe way of accessing $(D store.uinteger).
    /// Throws $(D JSONException) if $(D type) is not $(D JSON_TYPE.UINTEGER).
    @property ref inout(ulong) uinteger() inout
    {
        enforceEx!JSONException(type == JSON_TYPE.UINTEGER,
                                "JSONValue is not an unsigned integer");
        return store.uinteger;
    }

    /// Typesafe way of accessing $(D store.floating).
    /// Throws $(D JSONException) if $(D type) is not $(D JSON_TYPE.FLOAT).
    @property ref inout(real) floating() inout
    {
        enforceEx!JSONException(type == JSON_TYPE.FLOAT,
                                "JSONValue is not a floating type");
        return store.floating;
    }

    /// Typesafe way of accessing $(D store.object).
    /// Throws $(D JSONException) if $(D type) is not $(D JSON_TYPE.OBJECT).
    @property ref inout(JSONValue[string]) object() inout
    {
        enforceEx!JSONException(type == JSON_TYPE.OBJECT,
                                "JSONValue is not an object");
        return store.object;
    }

    /// Typesafe way of accessing $(D store.array).
    /// Throws $(D JSONException) if $(D type) is not $(D JSON_TYPE.ARRAY).
    @property ref inout(JSONValue[]) array() inout
    {
        enforceEx!JSONException(type == JSON_TYPE.ARRAY,
                                "JSONValue is not an array");
        return store.array;
    }

    private void assign(T)(T arg)
    {
        static if(is(T : typeof(null)))
        {
            type = JSON_TYPE.NULL;
        }
        else static if(is(T : string))
        {
            type = JSON_TYPE.STRING;
            store.str = arg;
        }
        else static if(is(T : ulong) && isUnsigned!T)
        {
            type = JSON_TYPE.UINTEGER;
            store.uinteger = arg;
        }
        else static if(is(T : long))
        {
            type = JSON_TYPE.INTEGER;
            store.integer = arg;
        }
        else static if(isFloatingPoint!T)
        {
            type = JSON_TYPE.FLOAT;
            store.floating = arg;
        }
        else static if(is(T : Value[Key], Key, Value))
        {
            static assert(is(Key : string), "AA key must be string");
            type = JSON_TYPE.OBJECT;
            static if(is(Value : JSONValue)) {
                store.object = arg;
            }
            else
            {
                JSONValue[string] aa;
                foreach(key, value; arg)
                    aa[key] = JSONValue(value);
                store.object = aa;
            }
        }
        else static if(isArray!T)
        {
            type = JSON_TYPE.ARRAY;
            static if(is(ElementEncodingType!T : JSONValue))
            {
                store.array = arg;
            }
            else
            {
                JSONValue[] new_arg = new JSONValue[arg.length];
                foreach(i, e; arg)
                    new_arg[i] = JSONValue(e);
                store.array = new_arg;
            }
        }
        else static if(is(T : bool))
        {
            type = arg ? JSON_TYPE.TRUE : JSON_TYPE.FALSE;
        }
        else static if(is(T : JSONValue))
        {
            type = arg.type;
            store = arg.store;
        }
        else
        {
            static assert(false, text(`unable to convert type "`, T.stringof, `" to json`));
        }
    }

    private void assignRef(T)(ref T arg) if(isStaticArray!T)
    {
        type = JSON_TYPE.ARRAY;
        static if(is(ElementEncodingType!T : JSONValue))
        {
            store.array = arg;
        }
        else
        {
            JSONValue[] new_arg = new JSONValue[arg.length];
            foreach(i, e; arg)
                new_arg[i] = JSONValue(e);
            store.array = new_arg;
        }
    }


    this(T)(T arg) if(!isStaticArray!T)
    {
        assign(arg);
    }

    this(T)(ref T arg) if(isStaticArray!T)
    {
        assignRef(arg);
    }

    this(T : JSONValue)(inout T arg) inout
    {
        store = arg.store;
        type = arg.type;
    }

    void opAssign(T)(T arg) if(!isStaticArray!T && !is(T : JSONValue))
    {
        assign(arg);
    }

    void opAssign(T)(ref T arg) if(isStaticArray!T)
    {
        assignRef(arg);
    }

    /// Array syntax for json arrays.
    /// Throws $(D JSONException) if $(D type) is not $(D JSON_TYPE.ARRAY).
    ref inout(JSONValue) opIndex(size_t i) inout
    {
        enforceEx!JSONException(type == JSON_TYPE.ARRAY,
                                "JSONValue is not an array");
        return store.array[i];
    }

    /// Hash syntax for json objects.
    /// Throws $(D JSONException) if $(D type) is not $(D JSON_TYPE.OBJECT).
    ref inout(JSONValue) opIndex(string k) inout
    {
        enforceEx!JSONException(type == JSON_TYPE.OBJECT,
                                "JSONValue is not an object");
        return store.object[k];
    }

    int opApply(int delegate(size_t index, ref JSONValue) dg)
    {
        enforceEx!JSONException(type == JSON_TYPE.ARRAY,
                                "JSONValue is not an array");
        int result;

        foreach(size_t index, ref value; store.array)
        {
            result = dg(index, value);
            if(result)
                break;
        }

        return result;
    }

    /// Implements foreach interface json objects.
    int opApply(int delegate(string key, ref JSONValue) dg)
    {
        enforceEx!JSONException(type == JSON_TYPE.OBJECT,
                                "JSONValue is not an object");
        int result;

        foreach(string key, ref value; store.object)
        {
            result = dg(key, value);
            if(result)
                break;
        }

        return result;
    }

    /// Implicitly calls $(D toJSON) on this JSONValue.
    string toString()
    {
        return toJSON(&this);
    }

    /// Implicitly calls $(D toJSON) on this JSONValue, like $(D toString), but
    /// also passes $(I true) as $(I pretty) argument.
    string toPrettyString()
    {
        return toJSON(&this, true);
    }
}

/**
Parses a serialized string and returns a tree of JSON values.
*/
JSONValue parseJSON(T)(T json, int maxDepth = -1) if(isInputRange!T)
{
    JSONValue root = void;
    root.type = JSON_TYPE.NULL;

    if(json.empty) return root;

    int depth = -1;
    dchar next = 0;
    int line = 1, pos = 1;

    void error(string msg)
    {
        throw new JSONException(msg, line, pos);
    }

    dchar peekChar()
    {
        if(!next)
        {
            if(json.empty) return '\0';
            next = json.front;
            json.popFront();
        }
        return next;
    }

    void skipWhitespace()
    {
        while(isWhite(peekChar())) next = 0;
    }

    dchar getChar(bool SkipWhitespace = false)()
    {
        static if(SkipWhitespace) skipWhitespace();

        dchar c = void;
        if(next)
        {
            c = next;
            next = 0;
        }
        else
        {
            if(json.empty) error("Unexpected end of data.");
            c = json.front;
            json.popFront();
        }

        if(c == '\n' || (c == '\r' && peekChar() != '\n'))
        {
            line++;
            pos = 1;
        }
        else
        {
            pos++;
        }

        return c;
    }

    void checkChar(bool SkipWhitespace = true, bool CaseSensitive = true)(char c)
    {
        static if(SkipWhitespace) skipWhitespace();
        auto c2 = getChar();
        static if(!CaseSensitive) c2 = toLower(c2);

        if(c2 != c) error(text("Found '", c2, "' when expecting '", c, "'."));
    }

    bool testChar(bool SkipWhitespace = true, bool CaseSensitive = true)(char c)
    {
        static if(SkipWhitespace) skipWhitespace();
        auto c2 = peekChar();
        static if (!CaseSensitive) c2 = toLower(c2);

        if(c2 != c) return false;

        getChar();
        return true;
    }

    string parseString()
    {
        auto str = appender!string();

    Next:
        switch(peekChar())
        {
            case '"':
                getChar();
                break;

            case '\\':
                getChar();
                auto c = getChar();
                switch(c)
                {
                    case '"':       str.put('"');   break;
                    case '\\':      str.put('\\');  break;
                    case '/':       str.put('/');   break;
                    case 'b':       str.put('\b');  break;
                    case 'f':       str.put('\f');  break;
                    case 'n':       str.put('\n');  break;
                    case 'r':       str.put('\r');  break;
                    case 't':       str.put('\t');  break;
                    case 'u':
                        dchar val = 0;
                        foreach_reverse(i; 0 .. 4)
                        {
                            auto hex = toUpper(getChar());
                            if(!isHexDigit(hex)) error("Expecting hex character");
                            val += (isDigit(hex) ? hex - '0' : hex - ('A' - 10)) << (4 * i);
                        }
                        char[4] buf = void;
                        str.put(toUTF8(buf, val));
                        break;

                    default:
                        error(text("Invalid escape sequence '\\", c, "'."));
                }
                goto Next;

            default:
                auto c = getChar();
                appendJSONChar(&str, c, &error);
                goto Next;
        }

        return str.data ? str.data : "";
    }

    void parseValue(JSONValue* value)
    {
        depth++;

        if(maxDepth != -1 && depth > maxDepth) error("Nesting too deep.");

        auto c = getChar!true();

        switch(c)
        {
            case '{':
                value.type = JSON_TYPE.OBJECT;
                value.store.object = null;

                if(testChar('}')) break;

                do
                {
                    checkChar('"');
                    string name = parseString();
                    checkChar(':');
                    JSONValue member = void;
                    parseValue(&member);
                    value.store.object[name] = member;
                }
                while(testChar(','));

                checkChar('}');
                break;

            case '[':
                value.type = JSON_TYPE.ARRAY;

                if(testChar(']'))
                {
                    value.store.array = cast(JSONValue[]) "";
                    break;
                }

                value.store.array = null;

                do
                {
                    JSONValue element = void;
                    parseValue(&element);
                    value.store.array ~= element;
                }
                while(testChar(','));

                checkChar(']');
                break;

            case '"':
                value.type = JSON_TYPE.STRING;
                value.store.str = parseString();
                break;

            case '0': .. case '9':
            case '-':
                auto number = appender!string();
                bool isFloat, isNegative;

                void readInteger()
                {
                    if(!isDigit(c)) error("Digit expected");

                Next: number.put(c);

                    if(isDigit(peekChar()))
                    {
                        c = getChar();
                        goto Next;
                    }
                }

                if(c == '-')
                {
                    number.put('-');
                    c = getChar();
                    isNegative = true;
                }

                readInteger();

                if(testChar('.'))
                {
                    isFloat = true;
                    number.put('.');
                    c = getChar();
                    readInteger();
                }
                if(testChar!(false, false)('e'))
                {
                    isFloat = true;
                    number.put('e');
                    if(testChar('+')) number.put('+');
                    else if(testChar('-')) number.put('-');
                    c = getChar();
                    readInteger();
                }

                string data = number.data;
                if(isFloat)
                {
                    value.type = JSON_TYPE.FLOAT;
                    value.store.floating = parse!real(data);
                }
                else
                {
                    if (isNegative)
                        value.store.integer = parse!long(data);
                    else
                        value.store.uinteger = parse!ulong(data);

                    value.type = !isNegative && value.store.uinteger & (1UL << 63) ? JSON_TYPE.UINTEGER : JSON_TYPE.INTEGER;
                }
                break;

            case 't':
            case 'T':
                value.type = JSON_TYPE.TRUE;
                checkChar!(false, false)('r');
                checkChar!(false, false)('u');
                checkChar!(false, false)('e');
                break;

            case 'f':
            case 'F':
                value.type = JSON_TYPE.FALSE;
                checkChar!(false, false)('a');
                checkChar!(false, false)('l');
                checkChar!(false, false)('s');
                checkChar!(false, false)('e');
                break;

            case 'n':
            case 'N':
                value.type = JSON_TYPE.NULL;
                checkChar!(false, false)('u');
                checkChar!(false, false)('l');
                checkChar!(false, false)('l');
                break;

            default:
                error(text("Unexpected character '", c, "'."));
        }

        depth--;
    }

    parseValue(&root);
    return root;
}

/**
Takes a tree of JSON values and returns the serialized string.

If $(D pretty) is false no whitespaces are generated.
If $(D pretty) is true serialized string is formatted to be human-readable.
No exact formatting layout is guaranteed in the latter case.
*/
string toJSON(in JSONValue* root, in bool pretty = false)
{
    auto json = appender!string();

    void toString(string str)
    {
        json.put('"');

        foreach (dchar c; str)
        {
            switch(c)
            {
                case '"':       json.put("\\\"");       break;
                case '\\':      json.put("\\\\");       break;
                case '/':       json.put("\\/");        break;
                case '\b':      json.put("\\b");        break;
                case '\f':      json.put("\\f");        break;
                case '\n':      json.put("\\n");        break;
                case '\r':      json.put("\\r");        break;
                case '\t':      json.put("\\t");        break;
                default:
                    appendJSONChar(&json, c,
                                   (msg) { throw new JSONException(msg); });
            }
        }

        json.put('"');
    }

    void toValue(in JSONValue* value, ulong indentLevel)
    {
        void putTabs(ulong additionalIndent = 0)
        {
            if(pretty)
                foreach(i; 0 .. indentLevel + additionalIndent)
                    json.put("    ");
        }
        void putEOL()
        {
            if(pretty)
                json.put('\n');
        }
        void putCharAndEOL(char ch)
        {
            json.put(ch);
            putEOL();
        }

        final switch(value.type)
        {
            case JSON_TYPE.OBJECT:
                if(!value.store.object.length)
                {
                    json.put("{}");
                }
                else
                {
                    putCharAndEOL('{');
                    bool first = true;
                    foreach(name, member; value.store.object)
                    {
                        if(!first)
                            putCharAndEOL(',');
                        first = false;
                        putTabs(1);
                        toString(name);
                        json.put(':');
                        if(pretty)
                            json.put(' ');
                        toValue(&member, indentLevel + 1);
                    }
                    putEOL();
                    putTabs();
                    json.put('}');
                }
                break;

            case JSON_TYPE.ARRAY:
                if(value.store.array.empty)
                {
                    json.put("[]");
                }
                else
                {
                    putCharAndEOL('[');
                    foreach (i, ref el; value.store.array)
                    {
                        if(i)
                            putCharAndEOL(',');
                        putTabs(1);
                        toValue(&el, indentLevel + 1);
                    }
                    putEOL();
                    putTabs();
                    json.put(']');
                }
                break;

            case JSON_TYPE.STRING:
                toString(value.store.str);
                break;

            case JSON_TYPE.INTEGER:
                json.put(to!string(value.store.integer));
                break;

            case JSON_TYPE.UINTEGER:
                json.put(to!string(value.store.uinteger));
                break;

            case JSON_TYPE.FLOAT:
                json.put(to!string(value.store.floating));
                break;

            case JSON_TYPE.TRUE:
                json.put("true");
                break;

            case JSON_TYPE.FALSE:
                json.put("false");
                break;

            case JSON_TYPE.NULL:
                json.put("null");
                break;
        }
    }

    toValue(root, 0);
    return json.data;
}

private void appendJSONChar(Appender!string* dst, dchar c,
                            scope void delegate(string) error)
{
    import std.uni : isControl;

    if(isControl(c))
        error("Illegal control character.");
    dst.put(c);
}

/**
Exception thrown on JSON errors
*/
class JSONException : Exception
{
    this(string msg, int line = 0, int pos = 0)
    {
        if(line)
            super(text(msg, " (Line ", line, ":", pos, ")"));
        else
            super(msg);
    }

    this(string msg, string file, size_t line)
    {
        super(msg, file, line);
    }
}


unittest
{
    JSONValue jv = "123";
    assert(jv.type == JSON_TYPE.STRING);
    assertNotThrown(jv.str);
    assertThrown!JSONException(jv.integer);
    assertThrown!JSONException(jv.uinteger);
    assertThrown!JSONException(jv.floating);
    assertThrown!JSONException(jv.object);
    assertThrown!JSONException(jv.array);
    assertThrown!JSONException(jv["aa"]);
    assertThrown!JSONException(jv[2]);

    jv = -3;
    assert(jv.type == JSON_TYPE.INTEGER);
    assertNotThrown(jv.integer);

    jv = cast(uint)3;
    assert(jv.type == JSON_TYPE.UINTEGER);
    assertNotThrown(jv.uinteger);

    jv = 3.0f;
    assert(jv.type == JSON_TYPE.FLOAT);
    assertNotThrown(jv.floating);

    jv = ["key" : "value"];
    assert(jv.type == JSON_TYPE.OBJECT);
    assertNotThrown(jv.object);
    assertNotThrown(jv["key"]);
    foreach(string key, value; jv)
    {
        static assert(is(typeof(value) == JSONValue));
        assert(key == "key");
        assert(value.type == JSON_TYPE.STRING);
        assertNotThrown(value.str);
        assert(value.str == "value");
    }

    jv = [3, 4, 5];
    assert(jv.type == JSON_TYPE.ARRAY);
    assertNotThrown(jv.array);
    assertNotThrown(jv[2]);
    foreach(size_t index, value; jv)
    {
        static assert(is(typeof(value) == JSONValue));
        assert(value.type == JSON_TYPE.INTEGER);
        assertNotThrown(value.integer);
        assert(index == (value.integer-3));
    }

    jv = JSONValue("value");
    assert(jv.type == JSON_TYPE.STRING);
    assert(jv.str == "value");

    JSONValue jv2 = JSONValue("value");
    assert(jv2.type == JSON_TYPE.STRING);
    assert(jv2.str == "value");
}

unittest
{
    // An overly simple test suite, if it can parse a serializated string and
    // then use the resulting values tree to generate an identical
    // serialization, both the decoder and encoder works.

    auto jsons = [
        `null`,
        `true`,
        `false`,
        `0`,
        `123`,
        `-4321`,
        `0.23`,
        `-0.23`,
        `""`,
        `"hello\nworld"`,
        `"\"\\\/\b\f\n\r\t"`,
        `[]`,
        `[12,"foo",true,false]`,
        `{}`,
        `{"a":1,"b":null}`,
        // Currently broken
        // `{"hello":{"json":"is great","array":[12,null,{}]},"goodbye":[true,"or",false,["test",42,{"nested":{"a":23.54,"b":0.0012}}]]}`
    ];

    version (MinGW)
        jsons ~= `1.223e+024`;
    else
        jsons ~= `1.223e+24`;

    JSONValue val;
    string result;
    foreach(json; jsons)
    {
        try
        {
            val = parseJSON(json);
            result = toJSON(&val);
            assert(result == json, text(result, " should be ", json));
        }
        catch(JSONException e)
        {
            import std.stdio;
            writefln(text(json, "\n", e.toString()));
        }
    }

    // Should be able to correctly interpret unicode entities
    val = parseJSON(`"\u003C\u003E"`);
    assert(toJSON(&val) == "\"\&lt;\&gt;\"");
    assert(val.to!string() == "\"\&lt;\&gt;\"");
    val = parseJSON(`"\u0391\u0392\u0393"`);
    assert(toJSON(&val) == "\"\&Alpha;\&Beta;\&Gamma;\"");
    assert(val.to!string() == "\"\&Alpha;\&Beta;\&Gamma;\"");
    val = parseJSON(`"\u2660\u2666"`);
    assert(toJSON(&val) == "\"\&spades;\&diams;\"");
    assert(val.to!string() == "\"\&spades;\&diams;\"");

    //0x7F is a control character (see Unicode spec)
    assertThrown(parseJSON(`{ "foo": "` ~ "\u007F" ~ `"}`));

    with(parseJSON(`""`))
        assert(str == "" && str !is null);
    with(parseJSON(`[]`))
        assert(!array.length && array !is null);

    // Formatting
    val = parseJSON(`{"a":[null,{"x":1},{},[]]}`);
    assert(toJSON(&val, true) == `{
    "a": [
        null,
        {
            "x": 1
        },
        {},
        []
    ]
}`);
}
