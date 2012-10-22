// Written in the D programming language.

/**
JavaScript Object Notation

Copyright: Copyright Jeremie Pelletier 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   Jeremie Pelletier,
           T. Jameson Little

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

// additions for marshalling
import std.traits;
import std.typetuple;
import std.string;

private {
        // Prevent conflicts from these generic names
        alias std.utf.stride UTFStride;
        alias std.utf.decode toUnicode;
}

/**
 JSON type enumeration
*/
enum JSON_TYPE : byte {
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
struct JSONValue {
        union {
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
JSONValue parseJSON(T)(T json, int maxDepth = -1) if(isInputRange!T) {
        JSONValue root = void;
        root.type = JSON_TYPE.NULL;

        if(json.empty()) return root;

        int depth = -1;
        dchar next = 0;
        int line = 1, pos = 1;

        void error(string msg) {
                throw new JSONException(msg, line, pos);
        }

        dchar peekChar() {
                if(!next) {
                        if(json.empty()) return '\0';
                        next = json.front();
                        json.popFront();
                }
                return next;
        }

        void skipWhitespace() {
                while(isWhite(peekChar())) next = 0;
        }

        dchar getChar(bool SkipWhitespace = false)() {
                static if(SkipWhitespace) skipWhitespace();

                dchar c = void;
                if(next) {
                        c = next;
                        next = 0;
                }
                else {
                        if(json.empty()) error("Unexpected end of data.");
                        c = json.front();
                        json.popFront();
                }

                if(c == '\n' || (c == '\r' && peekChar() != '\n')) {
                        line++;
                        pos = 1;
                }
                else {
                        pos++;
                }

                return c;
        }

        void checkChar(bool SkipWhitespace = true, bool CaseSensitive = true)(char c) {
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

        string parseString() {
                auto str = appender!string();

        Next:
                switch(peekChar()) {
                case '"':
                        getChar();
                        break;

                case '\\':
                        getChar();
                        auto c = getChar();
                        switch(c) {
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
                                foreach_reverse(i; 0 .. 4) {
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

                return str.data;
        }

        void parseValue(JSONValue* value) {
                depth++;

                if(maxDepth != -1 && depth > maxDepth) error("Nesting too deep.");

                auto c = getChar!true();

                switch(c) {
                case '{':
                        value.type = JSON_TYPE.OBJECT;
                        value.object = null;

                        if(testChar('}')) break;

                        do {
                                checkChar('"');
                                string name = parseString();
                                checkChar(':');
                                JSONValue member = void;
                                parseValue(&member);
                                value.object[name] = member;
                        } while(testChar(','));

                        checkChar('}');
                        break;

                case '[':
                        value.type = JSON_TYPE.ARRAY;
                        value.array = null;

                        if(testChar(']')) break;

                        do {
                                JSONValue element = void;
                                parseValue(&element);
                                value.array ~= element;
                        } while(testChar(','));

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

                        void readInteger() {
                                if(!isDigit(c)) error("Digit expected");

                                Next: number.put(c);

                                if(isDigit(peekChar())) {
                                        c = getChar();
                                        goto Next;
                                }
                        }

                        if(c == '-') {
                                number.put('-');
                                c = getChar();
                                isNegative = true;
                        }

                        readInteger();

                        if(testChar('.')) {
                                isFloat = true;
                                number.put('.');
                                c = getChar();
                                readInteger();
                        }
                        if(testChar!(false, false)('e')) {
                                isFloat = true;
                                number.put('e');
                                if(testChar('+')) number.put('+');
                                else if(testChar('-')) number.put('-');
                                c = getChar();
                                readInteger();
                        }

                        string data = number.data;
                        if(isFloat) {
                                value.type = JSON_TYPE.FLOAT;
                                value.floating = parse!real(data);
                        }
                        else {
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
string toJSON(in JSONValue* root) {
        auto json = appender!string();

        void toString(string str) {
                json.put('"');

                foreach (dchar c; str) {
                        switch(c) {
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
                                        (string msg){throw new JSONException(msg);});
                        }
                }

                json.put('"');
        }

        void toValue(in JSONValue* value) {
                final switch(value.type) {
                case JSON_TYPE.OBJECT:
                        json.put('{');
                        bool first = true;
                        foreach(name, member; value.object) {
                                if(first) first = false;
                                else json.put(',');
                                toString(name);
                                json.put(':');
                                toValue(&member);
                        }
                        json.put('}');
                        break;

                case JSON_TYPE.ARRAY:
                        json.put('[');
                        auto length = value.array.length;
                        foreach (i; 0 .. length) {
                                if(i) json.put(',');
                                toValue(&value.array[i]);
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
    if(isControl(c)) error("Illegal control character.");
    dst.put(c);
//      int stride = UTFStride((&c)[0 .. 1], 0);
//      if(stride == 1) {
//              if(isControl(c)) error("Illegal control character.");
//              dst.put(c);
//      }
//      else {
//              char[6] utf = void;
//              utf[0] = c;
//              foreach(i; 1 .. stride) utf[i] = next;
//              size_t index = 0;
//              if(isControl(toUnicode(utf[0 .. stride], index)))
//                      error("Illegal control character");
//              dst.put(utf[0 .. stride]);
//      }
}

/**
 Exception thrown on JSON errors
*/
class JSONException : Exception {
        this(string msg, int line = 0, int pos = 0) {
                if(line) super(text(msg, " (Line ", line, ":", pos, ")"));
                else super(msg);
        }
}

version(unittest) import std.stdio;

unittest {
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
//              `{"hello":{"json":"is great","array":[12,null,{}]},"goodbye":[true,"or",false,["test",42,{"nested":{"a":23.54,"b":0.0012}}]]}`
        ];

        JSONValue val;
        string result;
        foreach(json; jsons) {
                try {
                        val = parseJSON(json);
                        result = toJSON(&val);
                        assert(result == json, text(result, " should be ", json));
                }
                catch(JSONException e) {
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
}


/* Marshal */

/**
  Encodes a D string value as a JSON string.
  */
auto marshalJSON(T)(in T val) if (isSomeString!T) {
        JSONValue ret;
        ret.str = val;
        ret.type = JSON_TYPE.STRING;
        return ret;
}

unittest {
        auto a = marshalJSON!string("hello");
        assert(a.type == JSON_TYPE.STRING);
        assert(a.str == "hello");
}

/**
  Encodes a D signed integral value as a JSON number.
  */
auto marshalJSON(T)(in T val) if (isIntegral!T && isSigned!T) {
        JSONValue ret;
        ret.integer = val;
        ret.type = JSON_TYPE.INTEGER;
        return ret;
}

unittest {
        auto a = marshalJSON!int(5);
        assert(a.type == JSON_TYPE.INTEGER);
        assert(a.integer == 5);

        auto b = marshalJSON!int(-5);
        assert(b.type == JSON_TYPE.INTEGER);
        assert(b.integer == -5);
}

/**
  Encodes a D unsigned integral value as a JSON number.
  */
auto marshalJSON(T)(in T val) if (isIntegral!T && isUnsigned!T) {
        JSONValue ret;
        ret.uinteger = val;
        ret.type = JSON_TYPE.UINTEGER;
        return ret;
}

unittest {
        uint t = 5;
        auto a = marshalJSON!uint(t);
        assert(a.type == JSON_TYPE.UINTEGER);
        assert(a.uinteger == 5);
}

/**
  Encodes a D floating point value as a JSON number.
  */
auto marshalJSON(T)(in T val) if (isFloatingPoint!T) {
        JSONValue ret;
        ret.floating = val;
        ret.type = JSON_TYPE.FLOAT;
        return ret;
}

unittest {
        auto a = marshalJSON!float(5);
        assert(a.type == JSON_TYPE.FLOAT);
        assert(a.floating == 5f);
}

/**
  Encodes a D boolean value as a JSON true/false.
  */
auto marshalJSON(T)(in T val) if (isBoolean!T) {
        JSONValue ret;
        ret.type = val ? JSON_TYPE.TRUE : JSON_TYPE.FALSE;
        return ret;
}

unittest {
        auto a = marshalJSON!bool(true);
        assert(a.type == JSON_TYPE.TRUE);

        auto b = marshalJSON!bool(false);
        assert(b.type == JSON_TYPE.FALSE);
}

/**
  Encodes a D pointer value as a JSON null or recursively marshals whatever
  value the pointer points to.
  */
auto marshalJSON(T)(in T val) if (isPointer!T) {
        if (val == null) {
                JSONValue v;
                v.type = JSON_TYPE.NULL;
                return v;
        }

        return marshalJSON!(PointerTarget!T)(*val);
}

// JSON types to pointers
unittest {
        int* a = new int;
        *a = 5;
        auto j = marshalJSON!(int*)(a);

        assert(j.type == JSON_TYPE.INTEGER);
        assert(j.integer == *a);
}

/**
  Encodes a D array as a JSON array.
  */
auto marshalJSON(T)(in T val) if (!isSomeString!T && isArray!T) {
        JSONValue ret;
        ret.type = JSON_TYPE.ARRAY;
        ret.array.length = val.length;
        foreach (i, elem; val) {
                ret.array[i] = marshalJSON!(ForeachType!T)(elem);
        }

        return ret;
}

// JSON array: static array, dynamic array
unittest {
        auto arr = [2, 5];
        auto a = marshalJSON!(int[])(arr);
        assert(a.type == JSON_TYPE.ARRAY);
        foreach (i, _; a.array) {
                assert(a.array[i].type == JSON_TYPE.INTEGER);
                assert(a.array[i].integer == arr[i]);
        }
}

/**
  Encodes a D associative array as a JSON object.
  */
auto marshalJSON(T)(in T val) if (isAssociativeArray!T && is(KeyType!T : string)) {
        JSONValue ret;
        ret.type = JSON_TYPE.OBJECT;
        foreach (k, v; val) {
                ret.object[k] = marshalJSON!(ValueType!(T))(v);
        }

        return ret;
}

// JSON object: associative array where key must be a string
unittest {
        auto aMap = ["one": 1];
        auto a = marshalJSON!(int[string])(aMap);
        assert(a.type == JSON_TYPE.OBJECT);
        foreach (k, v; a.object) {
                assert(v.type == JSON_TYPE.INTEGER);
                assert(aMap[k] == v.integer);
        }

        auto bMap = ["one": 1f];
        auto b = marshalJSON!(float[string])(bMap);
        assert(b.type == JSON_TYPE.OBJECT);
        foreach (k, v; b.object) {
                assert(v.type == JSON_TYPE.FLOAT);
                assert(bMap[k] == v.floating);
        }
}

/**
  Encodes a D struct or class as a JSON object.
  */
auto marshalJSON(T)(in T val) if (is(T == class) || is(T == struct)) {
        JSONValue ret;
        ret.type = JSON_TYPE.OBJECT;

        // make sure to cover all base classes
        static if (is(T == class)) {
                alias TypeTuple!(T, BaseClassesTuple!T) Types;
                if (!val) {
                        ret.type = JSON_TYPE.NULL;
                        return ret;
                }
        } else {
                alias TypeTuple!T Types;
        }

        foreach (BT; Types) {
                foreach (i, type; typeof(BT.tupleof)) {
                        enum name = BT.tupleof[i].stringof[1 + BT.stringof.length + 2 .. $];
                        static if (name != "this") {
                                ret.object[name] = marshalJSON!type(mixin("val." ~ name));
                        }
                }
        }

        return ret;
}

// JSON object: class
unittest {
        import std.array;
        import std.format;

        class A {
                int z;
                float y;
                uint x;
                uint[3] w;

                override string toString() {
                        auto writer = appender!string();
                        formattedWrite(writer, "%d %f %d %s", z, y, x, w);
                        return writer.data;
                }
        }

        A a = new A;
        a.z = 3;
        a.y = 3.3f;
        a.x = 7;
        a.w = [8, 7, 2];

        auto j = marshalJSON!A(a);

        assert(j.type == JSON_TYPE.OBJECT);
        assert(j.object["z"].type == JSON_TYPE.INTEGER);
        assert(j.object["z"].integer == a.z);
        assert(j.object["y"].type == JSON_TYPE.FLOAT);
        assert(j.object["y"].floating == a.y);
        assert(j.object["x"].type == JSON_TYPE.UINTEGER);
        assert(j.object["x"].uinteger == a.x);
        assert(j.object["w"].type == JSON_TYPE.ARRAY);
        foreach (i, v; j.object["w"].array) {
                assert(v.type == JSON_TYPE.UINTEGER);
                assert(a.w[i] == v.uinteger);
        }

        // test null classes
        A b;
        auto j2 = marshalJSON!A(a);
        assert(j2.type == JSON_TYPE.OBJECT);
}

// JSON objects: structs
unittest {
        import std.array;
        import std.format;

        struct A {
                int a;
                double b;
                string c;
                int[] d;
                int[string] e;

                string toString() {
                        auto writer = appender!string();
                        formattedWrite(writer, "%d %f '%s' %s %s", a, b, c, d, e);
                        return writer.data;
                }
        }

        A a = {a: 5, b: 6., c: "hello", d: [1, 2, 3]};
        a.e = ["one": 1, "two": 2];

        auto j = marshalJSON!A(a);
        assert(j.type == JSON_TYPE.OBJECT);

        assert(j.object["a"].type == JSON_TYPE.INTEGER);
        assert(j.object["a"].integer == a.a);

        assert(j.object["b"].type == JSON_TYPE.FLOAT);
        assert(j.object["b"].floating == a.b);

        assert(j.object["c"].type == JSON_TYPE.STRING);
        assert(j.object["c"].str == a.c);

        assert(j.object["d"].type == JSON_TYPE.ARRAY);
        foreach (i, v; j.object["d"].array) {
                assert(v.type == JSON_TYPE.INTEGER);
                assert(v.integer == a.d[i]);
        }

        assert(j.object["e"].type == JSON_TYPE.OBJECT);
        foreach (k, v; j.object["e"].object) {
                assert(v.type == JSON_TYPE.INTEGER);
                assert(v.integer == a.e[k]);
        }
}

// embedded struct in class
unittest {
        struct A {
                int c;
        }

        class B {
                A a;
                A* b;
        }

        auto b = new B;
        b.a.c = 1;
        b.b = new A;
        b.b.c = 2;

        auto j = marshalJSON!B(b);
        assert(j.type == JSON_TYPE.OBJECT);

        assert(j["a"].type == JSON_TYPE.OBJECT);
        assert(j["a"].object["c"].type == JSON_TYPE.INTEGER);
        assert(j["a"].object["c"].integer == b.a.c);

        assert(j["b"].type == JSON_TYPE.OBJECT);
        assert(j["b"].object["c"].type == JSON_TYPE.INTEGER);
        assert(j["b"].object["c"].integer == b.b.c);
}

// Subclasses
unittest {
        class A {
                int a;
        }

        class B : A {
                int b;
        }

        auto b = new B;
        b.a = 1;
        b.b = 2;

        auto j = marshalJSON!B(b);
        assert(j.type == JSON_TYPE.OBJECT);

        assert(j.object["a"].type == JSON_TYPE.INTEGER);
        assert(j.object["a"].integer == b.a);

        assert(j.object["b"].type == JSON_TYPE.INTEGER);
        assert(j.object["b"].integer == b.b);
}

// Inner classes
unittest {
        class A {
                class B {
                        int c;
                }
        }

        auto a = new A;
        auto b = a.new A.B;
        b.c = 5;

        auto j = marshalJSON!(A.B)(b);
        assert(j.type == JSON_TYPE.OBJECT);
        assert(j.object["c"].type == JSON_TYPE.INTEGER);
        assert(j.object["c"].integer == 5);

        A.B b2;
        auto j2 = marshalJSON!(A.B)(b2);
        assert(j2.type == JSON_TYPE.NULL);
}

/* Unmarshal */

/**
  Thrown on unmarshalling errors such as incompatible types.
  */
class JSONUnmashalException : Exception {
        this(string message) {
                super(message);
        }
}

/**
  Decodes a JSON string into a D string.
  */
auto unmarshalJSON(T)(JSONValue val, out T ret) if (isSomeString!T) {
        if (val.type != JSON_TYPE.STRING) {
                throw new JSONUnmashalException(format("Expected string value, but given JSON type: %s", val.type));
        }
        ret = to!T(val.str);
}

// JSON type: int, float, string etc.
unittest {
        string s;
        unmarshalJSON(`"5"`, s);
        assert(s == "5");
}

/**
  Decodes a JSON number into a D signed integer type.
  */
auto unmarshalJSON(T)(JSONValue val, out T ret) if (isIntegral!T && isSigned!T) {
        if (val.type != JSON_TYPE.INTEGER) {
                throw new JSONUnmashalException(format("Expected signed integral value, but given JSON type: %s", val.type));
        }
        ret = to!T(val.integer);
}

unittest {
        int a;
        unmarshalJSON(`5`, a);
        assert(a == 5);

        int b;
        unmarshalJSON(`-5`, b);
        assert(b == -5);
}

/**
  Decodes a JSON number into a D unsigned integer type.
  */
auto unmarshalJSON(T)(JSONValue val, out T ret) if (isIntegral!T && isUnsigned!T) {
        if (val.type != JSON_TYPE.UINTEGER && val.type != JSON_TYPE.INTEGER) {
                throw new JSONUnmashalException(format("Expected unsigned integral value, but given JSON type: %s", val.type));
        }
        // we know it's unsigned, and uinteger & integer are in the same union,
        // so both uinteger & integer will be equivalent
        ret = to!T(val.uinteger);
}

unittest {
        uint a;
        unmarshalJSON(`5`, a);
        assert(a == 5);
}

/**
  Decodes a JSON number into a D floating point type.
  */
auto unmarshalJSON(T)(JSONValue val, out T ret) if (isFloatingPoint!T) {
        if (val.type != JSON_TYPE.FLOAT && val.type != JSON_TYPE.UINTEGER && val.type != JSON_TYPE.INTEGER) {
                throw new JSONUnmashalException(format("Expected floating point value, but given JSON type: %s", val.type));
        }

        switch (val.type) {
        case JSON_TYPE.FLOAT:
                ret = to!T(val.floating);
                break;

        case JSON_TYPE.INTEGER:
                ret = to!T(val.integer);
                break;

        case JSON_TYPE.UINTEGER:
                ret = to!T(val.uinteger);
                break;

        default:
                // won't ever happen
                assert(0);
        }
}

unittest {
        float a;
        unmarshalJSON(`5.0`, a);
        assert(a == 5.0f);
}

/**
  Decodes a JSON true/false into a D boolean type.
  */
auto unmarshalJSON(T)(JSONValue val, out T ret) if (isBoolean!T) {
        if (val.type != JSON_TYPE.TRUE && val.type != JSON_TYPE.FALSE) {
                throw new JSONUnmashalException(format("Expected boolean value, but given JSON type: %s", val.type));
        }
        ret = val.type == JSON_TYPE.TRUE;
}

unittest {
        bool a;
        unmarshalJSON(`true`, a);
        assert(a);

        bool b;
        unmarshalJSON(`false`, b);
        assert(!b);
}

/**
  Recursively handles D pointers, instantiating where necessary.
  */
auto unmarshalJSON(T)(JSONValue val, ref T ret) if (isPointer!T) {
        if (ret == null) {
                ret = new PointerTarget!T;
        }

        PointerTarget!T ret2;
        unmarshalJSON!(PointerTarget!T)(val, ret2);
        *ret = ret2;
}

// JSON types to pointers
unittest {
        int* b;
        unmarshalJSON(`5`, b);
        assert(*b == 5);
}

/**
  Decodes a JSON array into a D array.
  */
auto unmarshalJSON(T)(JSONValue val, ref T ret) if (!isSomeString!T && isArray!T) {
        if (val.type != JSON_TYPE.ARRAY) {
                throw new JSONUnmashalException(format("Expected array value, but given JSON type: %s", val.type));
        }
        static if (isStaticArray!(T)) {
                if (val.array.length > T.length) {
                        throw new JSONUnmashalException(format("JSON array of size %d cannot fit in static array of size %d.", val.array.length, T.length));
                }
        }

        T ret2;
        static if (isDynamicArray!T) {
                ret2.length = val.array.length;
        }

        foreach (i, elem; val.array) {
                unmarshalJSON!(ForeachType!T)(elem, ret2[i]);
        }

        ret = ret2;
}

// JSON array: static array, dynamic array
unittest {
        import std.exception;

        int[] arr;
        unmarshalJSON(`[2, 5]`, arr);
        assert(arr == [2, 5]);

        float[] arr2;
        unmarshalJSON(`[2.0, 5.0]`, arr2);
        assert(arr2 == [2.0f, 5.0f]);

        int[2] arr3;
        unmarshalJSON(`[1, 2]`, arr3);
        assert(arr3 == [1, 2]);

        int[2] arr4;
        unmarshalJSON(`[1]`, arr4);
        assert(arr4 == [1, 0]);

        int[2] arr5;
        assertThrown!JSONUnmashalException(unmarshalJSON(`[1, 2, 3]`, arr5), "Cannot unmarshal into static array smaller than the data");
}

/**
  Decodes a JSON object into a D associative array.
  */
auto unmarshalJSON(T)(JSONValue val, out T ret) if (isAssociativeArray!T && is(KeyType!T : string)) {
        if (val.type != JSON_TYPE.OBJECT) {
                throw new JSONUnmashalException(format("Expected object value, but given JSON type: %s", val.type));
        }
        T ret2;
        foreach (k, v; val.object) {
                ValueType!(T) va;
                unmarshalJSON!(ValueType!(T))(v, va);
                ret2[k] = va;
        }

        ret = ret2;
}

// JSON object: associative array where key must be a string
unittest {
        int[string] a;
        unmarshalJSON(`{"one": 1}`, a);
        assert(a == ["one": 1]);

        float[string] b;
        unmarshalJSON(`{"one": 1}`, b);
        assert(b == ["one": 1f]);
}

/**
  Decodes a JSON object into a D class or struct, instantiating where necessary.
  */
auto unmarshalJSON(T)(JSONValue val, ref T ret) if (is(T == class) || is(T == struct)) {
        if (val.type != JSON_TYPE.OBJECT) {
                throw new JSONUnmashalException(format("Expected object value, but given JSON type: %s", val.type));
        }

        // if it's a class, make sure we account for all super classes
        // we'll start with the base cass first
        static if (is(T == class)) {
                alias TypeTuple!(T, BaseClassesTuple!T) Types;
                if (!ret) {
                        static if (__traits(compiles, new T)) {
                                ret = new T;
                        } else {
                                throw new JSONUnmashalException(format("Cannot instantiate %s, but reference needed to unmarshal type %s", T.stringof, val.type));
                        }
                }
        } else {
                alias TypeTuple!T Types;
        }

objloop:
        foreach (k, v; val.object) {
                // check all base classes
                foreach (BT; Types) {
                        // iterate over all fields
                        foreach (i, type; typeof(BT.tupleof)) {
                                enum name = BT.tupleof[i].stringof[1 + BT.stringof.length + 2 .. $];

                                static if (name != "this") {
                                        if (k == name) {
                                                static if (isPointer!type) {
                                                        if (!mixin("ret." ~ name)) {
                                                                mixin("ret." ~ name) = new PointerTarget!type;
                                                        }
                                                } else static if (is(type == class)) {
                                                        if (!mixin("ret." ~ name)) {
                                                                static if (__traits(compiles, mixin("BT." ~ type.stringof))) {
                                                                        mixin("ret." ~ name) = ret.new type;
                                                                } else {
                                                                        mixin("ret." ~ name) = new type;
                                                                }
                                                        }
                                                }

                                                unmarshalJSON(v, mixin("ret." ~ name));

                                                // ignore all super classes because we've satisfied k
                                                continue objloop;
                                        }
                                }
                        }
                }
        }
}

// JSON object: class
unittest {
        import std.array;
        import std.format;

        class A {
                int z;
                float y;
                uint x;
                uint[3] w;

                override string toString() {
                        auto writer = appender!string();
                        formattedWrite(writer, "%d %f %d %s", z, y, x, w);
                        return writer.data;
                }
        }

        auto a = new A;
        unmarshalJSON(`{"z": 3, "y": 3.3, "x": 7, "w": [8, 7, 2]}`, a);

        assert(a.z == 3);
        assert(a.y == 3.3f);
        assert(a.x == 7);
        assert(a.w == [8, 7, 2]);
}

// JSON objects: structs
unittest {
        import std.array;
        import std.format;

        struct A {
                int a;
                double b;
                string c;
                int[] d;
                int[string] e;
                double* f;

                // this breaks on latest DMD HEAD
                version (none) {
                string toString() {
                        auto writer = appender!string();
                        formattedWrite(writer, "%d %f '%s' %s %s", a, b, c, d, e);
                        return writer.data;
                }
                }
        }

        A a;

        unmarshalJSON(`{"a": 5, "b": 6.0, "c": "hello", "d": [1, 2, 3], "e": {"one": 1, "two": 2}, "f": 7}`, a);

        assert(a.a == 5);
        assert(a.b == 6.0f);
        assert(a.c == "hello");
        assert(a.d == [1, 2, 3]);
        assert(a.e == ["one": 1, "two": 2]);
        assert(*a.f == 7f);
}

// embedded struct in class
unittest {
        struct A {
                int c;
        }

        class B {
                A a;
                A* b;
        }

        auto b = new B;
        unmarshalJSON(`{"a": {"c": 3}, "b": {"c": 4}}`, b);

        assert(b.a.c == 3);
        assert(b.b.c == 4);
}

// Subclasses
unittest {
        class A {
                int a;
        }

        class B : A {
                int b;
        }

        auto b = new B;
        unmarshalJSON(`{"a": 5, "b": 3}`, b);

        assert(b.a == 5);
        assert(b.b == 3);
}

// Internal class
unittest {
        class A {
                class B {
                        int b;
                }

                int a;
                B b;
        }

        auto a = new A;
        unmarshalJSON(`{"a": 5, "b": {"b": 3}}`, a);

        assert(a.a == 5);
        assert(a.b.b == 3);
}

// Lots of nested classes
unittest {
        import std.exception;

        class A {
                class B {
                        class C {
                                int d;
                        }

                        C c;
                }

                B b;
        }

        auto a = new A;
        unmarshalJSON(`{"b": {"c": {"d": 5}}}`, a);

        assert(a.b.c.d == 5);

        A.B b;
        assertThrown!JSONUnmashalException(unmarshalJSON(`{}`, b), "Cannot instantiate inner class without outer class instance");
}

/**
  Decodes a JSON string (InputRange) into a D data type.
  */
auto unmarshalJSON(J, T)(J json, ref T ret, int maxDepth = -1) if(isInputRange!J) {
        unmarshalJSON(parseJSON(json, maxDepth), ret);
}
