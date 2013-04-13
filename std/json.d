// Written in the D programming language.

/**
JavaScript Object Notation

Copyright: Copyright Jeremie Pelletier 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   Jeremie Pelletier
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
import std.uni : isControl;
import std.utf;

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
    union
    {
        /// Value when $(D type) is $(D JSON_TYPE.STRING)
        string                          str;
        /// Value when $(D type) is $(D JSON_TYPE.INTEGER)
        long                            integer;
        /// Value when $(D type) is $(D JSON_TYPE.UINTEGER)
        ulong                           uinteger;
        /// Value when $(D type) is $(D JSON_TYPE.FLOAT)
        real                            floating;
        /// Value when $(D type) is $(D JSON_TYPE.OBJECT)
        JSONValue[string]               object;
        /// Value when $(D type) is $(D JSON_TYPE.ARRAY)
        JSONValue[]                     array;
    }
    /// Specifies the _type of the value stored in this structure.
    JSON_TYPE                               type;

    /// array syntax for json arrays
    ref JSONValue opIndex(size_t i)
    in { assert(type == JSON_TYPE.ARRAY, "json type is not array"); }
    body
    {
        return array[i];
    }

    /// hash syntax for json objects
    ref JSONValue opIndex(string k)
    in { assert(type == JSON_TYPE.OBJECT, "json type is not object"); }
    body
    {
        return object[k];
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
                value.object = null;

                if(testChar('}')) break;

                do
                {
                    checkChar('"');
                    string name = parseString();
                    checkChar(':');
                    JSONValue member = void;
                    parseValue(&member);
                    value.object[name] = member;
                }
                while(testChar(','));

                checkChar('}');
                break;

            case '[':
                value.type = JSON_TYPE.ARRAY;

                if(testChar(']'))
                {
                    value.array = cast(JSONValue[]) "";
                    break;
                }

                value.array = null;

                do
                {
                    JSONValue element = void;
                    parseValue(&element);
                    value.array ~= element;
                }
                while(testChar(','));

                checkChar(']');
                break;

            case '"':
                value.type = JSON_TYPE.STRING;
                value.str = parseString();
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
                    value.floating = parse!real(data);
                }
                else
                {
                    if (isNegative)
                        value.integer = parse!long(data);
                    else
                        value.uinteger = parse!ulong(data);
                    value.type = !isNegative && value.uinteger & (1UL << 63) ? JSON_TYPE.UINTEGER : JSON_TYPE.INTEGER;
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
*/
string toJSON(in JSONValue* root)
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

    void toValue(in JSONValue* value)
    {
        final switch(value.type)
        {
            case JSON_TYPE.OBJECT:
                json.put('{');
                bool first = true;
                foreach(name, member; value.object)
                {
                    if(!first)
                        json.put(',');
                    first = false;
                    toString(name);
                    json.put(':');
                    toValue(&member);
                }
                json.put('}');
                break;

            case JSON_TYPE.ARRAY:
                json.put('[');
                foreach (i, ref el; value.array)
                {
                    if(i)
                        json.put(',');
                    toValue(&el);
                }
                json.put(']');
                break;

            case JSON_TYPE.STRING:
                toString(value.str);
                break;

            case JSON_TYPE.INTEGER:
                json.put(to!string(value.integer));
                break;

            case JSON_TYPE.UINTEGER:
                json.put(to!string(value.uinteger));
                break;

            case JSON_TYPE.FLOAT:
                json.put(to!string(value.floating));
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

    toValue(root);
    return json.data;
}

private void appendJSONChar(Appender!string* dst, dchar c,
                            scope void delegate(string) error)
{
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
}

version(unittest) import std.exception;

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
        `1.223e+24`,
        `"hello\nworld"`,
        `"\"\\\/\b\f\n\r\t"`,
        `[]`,
        `[12,"foo",true,false]`,
        `{}`,
        `{"a":1,"b":null}`,
        // Currently broken
        // `{"hello":{"json":"is great","array":[12,null,{}]},"goodbye":[true,"or",false,["test",42,{"nested":{"a":23.54,"b":0.0012}}]]}`
    ];

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
    val = parseJSON(`"\u0391\u0392\u0393"`);
    assert(toJSON(&val) == "\"\&Alpha;\&Beta;\&Gamma;\"");
    val = parseJSON(`"\u2660\u2666"`);
    assert(toJSON(&val) == "\"\&spades;\&diams;\"");

    assertNotThrown(parseJSON(`{ "foo": "` ~ "\u007F" ~ `"}`));

    with(parseJSON(`""`))
        assert(str == "" && str !is null);
    with(parseJSON(`[]`))
        assert(!array.length && array !is null);
}
