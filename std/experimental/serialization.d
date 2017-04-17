// Written in the D programming language.

/**
 This module intends to provide fully functional serialization for basic
 types (except pointers) and D structs and classes.
 Types can define themselvs as not serialzable with $(D enum serializable = false;)
 Synopsis:
 ----
 class Foo
 { 
     long bar;
     int[] baz;
 }
 Foo foo = new Foo();
 static if (isSerializable!Foo)
 {
     ubyte[] serializedFoo serialize(foo);
     //do something with serializedFoo 
     try
     {
         Foo deserializedFoo = deserialize!foo(serializedFoo);
         //do something with deserializedFoo 
     }
     catch(SerializationException e)
     {
         //figure out what to do if their was an error 
     }
 }
 ----
 
 Copyright: Copyright Sean Campbell 2015.
 License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 Authors:   Sean Campbell
 Source:    $(PHOBOSSRC std/_experimental/_serialization.d)
 */
module std.experimental.serialization;

import std.traits;
import std.system;
import std.exception;
import std.range : retro;
import std.array;
import std.typetuple;

/**
 Byte order marker for big and little endian systems.
 */
enum BOM: ushort
{
    big = 0xF00F,
    little = 0x0FF0,
}

/**
 The current byte order marker.
 */
BOM bom;

/**
 Indicates the method of storage used
 */
enum DataStorageMode:ubyte
{
    byValue = 0x01,
    byReference
}

/**
 Indicates wheather somthing isn't serializable
 */
enum noSerialization = "noSerialization";
/**
 Indicates if a field has a custom serializer
 */
enum customSerialization = "customSerialization";

static this()
{
    bom = endian == Endian.bigEndian? BOM.big: BOM.little;
}

/**
 Template to check if a class, struct or union is serializable. (only used internally)
 */
template isSerializableStructure(T)
{
    static if (((__traits(compiles,T.serializable) && T.serializable) || !__traits(compiles,T.serializable)) 
        && !isPointer!T && (is(T == class) || is(T == struct) || is(T == union)))
    {
        static if (is(T == class))
        {
            static if ( !__traits(compiles,&T.__ctor) || __traits(compiles,T.__ctor()))
            {
                enum isSerializableStructure = true;
            }
            else
            {
                enum isSerializableStructure = false;
            }
        }
        else
        {
            enum isSerializableStructure = true;
        }
    }
    else
    {
        enum isSerializableStructure = false;
    }
}

/**
 Template to check if anything that isn't a class, struct or union is serializable. (only used internally)
 */
template isSerializableData(T)
{
    static if ((isBuiltinType!T || isArray!T || isAssociativeArray!T) && !isPointer!T)
    {
        enum isSerializableData = true;
    }
    else
    {
        enum isSerializableData = false;
    }
}

/**
 Template to check if a type is serializable
 */
template isSerializable(T)
{
    static if ((isSerializableStructure!T || isSerializableData!T))
    {
        enum isSerializable = true;
    }
    else
    {
        enum isSerializable = false;
    }
}
/**
 Checks if a field has a custom serializer
 */
template hasCustomFieldSerializer(alias T)
{
    static if (hasAttribute!(T,customSerialization))
    {
        static assert(__traits(compiles,mixin("(__traits(parent,T)).serialize" ~ T.stringof))
            && __traits(compiles,mixin("(__traits(parent,T)).deserialize" ~ T.stringof))
            && matchesPrototype!(mixin("(__traits(parent,T)).serialize" ~ T.stringof), ubyte[] function(in typeof(T)))
            && matchesPrototype!(mixin("(__traits(parent,T)).deserialize" ~ T.stringof), typeof(T) function(in ubyte[])) 
            , T.stringof ~ " is declared as @customSerialization but has non-existant or an invalid serializer or deserializer");
        enum hasCustomFieldSerializer = true;
    }
    else
    {
        enum hasCustomFieldSerializer = false;
    }
}

/**
 Checks if a type has a custom serializer
*/
template hasCustomTypeSerializer(T)
{
    static if (__traits(compiles,T.serializeThis) && __traits(compiles,T.deserializeThis)
        && matchesPrototype!(T.serializeThis, ubyte[] function(in T)) 
        && matchesPrototype!(T.deserializeThis, T function(in ubyte[])))
    {
        enum hasCustomTypeSerializer = true;
    }
    else
    {
        enum hasCustomTypeSerializer = false; 
    }
}

/**
 Template to check if a member has a specified attrubute
 */
template hasAttribute(alias Member, alias Attrubute)
{
    static if (staticIndexOf!(Attrubute,__traits(getAttributes,Member)) != -1)
    {
        enum hasAttribute = true;
    }
    else
    {
        enum hasAttribute = false;
    }
}

/**
 Checks if function matches a function prototype
 */
template matchesPrototype(alias Function,Prototype)
{
    static if (is(ReturnType!Function == ReturnType!Prototype) && is(ParameterTypeTuple!Function == ParameterTypeTuple!Prototype))
    {
        enum matchesPrototype = true;
    }
    else
    {
        enum matchesPrototype = false;
    }
}

private union ByteConverter(T)
{
    T value;
    ubyte[T.sizeof] bytes;
}

/**
 Converts from into an array of bytes
 */ 
ubyte[T.sizeof] toBytes(T)(in T from)
{
    ByteConverter!T converter;
    converter.value = from;
    return converter.bytes;
}

/**
 Converts a ubyte array into a T
 */ 
T fromBytes(T)(in ubyte[] bytes)
{
    ByteConverter!T converter;
    converter.bytes = bytes;
    return converter.value;
}

/**
 Exception that is thrown if serializer/deserializer encounters a problem
 */
class SerializationException : Exception
{
    this(string message, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super("Serialization exception: "~message,file,line,next);
    }
}
/**
 Main serialization function. Takes a template argument if it is serializable and returns a ubyte array
 of the argument serialized.
 */
ubyte[] serialize(T)(ref in T source) if (isSerializable!T)
{
    ubyte[] output;
    uint[void*] referenceTracker;
    output ~= toBytes(bom);
    bool havereference(U)(ref in U member)
    {
        static if (is (U == class))
        {
            return (cast(void*)member in referenceTracker) !is null;
        }
        else
        {
            return (cast(void*)&member in referenceTracker) !is null;
        }
    }
    uint getreference(U)(ref in U member)
    {
        static if (is (U == class))
        {
            return referenceTracker[cast(void*)member];
        }
        else
        {
            return referenceTracker[cast(void*)&member];
        }
    }
    void addreference(U)(ref in U member,uint pos)
    {
        static if (is (U == class))
        {
            referenceTracker[cast(void*)member] = pos;
        }
        else
        {
            referenceTracker[cast(void*)&member] = pos;
        }
    }
    void serializeStructure(U)(ref in U input) if (isSerializableStructure!U)
    {
        if (havereference(input))
        {
            output ~= DataStorageMode.byReference;
            output ~= toBytes(getreference(input));
        }
        static if(hasCustomTypeSerializer!(U))
        {
            ubyte[] custom = U.serializeThis(input);
            output~=toBytes!uint(custom.length);
            output~=custom;
        }
        else
        {
            if (is(U == class))
            {
                addreference(input,output.length);
            }
            output ~= DataStorageMode.byValue;
            foreach(name;FieldNameTuple!U)
            {
                static if (hasCustomFieldSerializer!(__traits(getMember,input,name))
                    && !hasAttribute!(__traits(getMember,input,name),noSerialization))
                {
                    ubyte[] custom = mixin("U.serialize"~name)(__traits(getMember,input,name));
                    output~=toBytes!uint(custom.length);
                    output~=custom;
                }
                else static if(hasCustomTypeSerializer!(typeof(__traits(getMember,input,name)))
                    && !hasAttribute!(__traits(getMember,input,name),noSerialization))
                {
                    ubyte[] custom = typeof(__traits(getMember,input,name)).serializeThis(input);
                    output~=toBytes!uint(custom.length);
                    output~=custom;
                }
                else static if (isSerializableStructure!(typeof(__traits(getMember,input,name))) 
                    && !hasAttribute!(__traits(getMember,input,name),noSerialization))
                {
                    serializeStructure(__traits(getMember,input,name));
                }
                else static if (isSerializableData!(typeof(__traits(getMember,input,name))) 
                    && !hasAttribute!(__traits(getMember,input,name),noSerialization))
                {
                    serializeData(__traits(getMember,input,name));
                }
                else static if(!hasAttribute!(__traits(getMember,input,name),noSerialization))
                {
                    static assert(0,U.stringof~" has member "~name~" which cannot be serialized\nmark with @noSerialization if intended");
                }
            }
            if (!is(U == class))
            {
                addreference(input,output.length);
            }
        }
    }
    
    void serializeData(U)(ref in U input) if (isSerializableData!U)
    {
        if (havereference(input))
        {
            output ~= DataStorageMode.byReference;
            output ~= toBytes(getreference(input));
        }
        else
        {
            output ~= DataStorageMode.byValue;
            static if (isArray!U)
            {
                addreference(input,output.length-1);
                output ~= toBytes(input.length);
                foreach(v;input)
                {
                    static if (isSerializableStructure!(ForeachType!U))
                    {
                        serializeStructure(v);
                    }
                    else static if (isSerializableData!(ForeachType!U))
                    {
                        serializeData(v);
                    }
                }
            }
            else static if(isAssociativeArray!U)
            {
                addreference(input,output.length-1);
                output ~= toBytes(cast(uint)input.length);
                foreach(k,v;input)
                {
                    static if (isSerializableStructure!(KeyType!U))
                    {
                        serializeStructure(k);
                    }
                    else static if (isSerializableData!(KeyType!U))
                    {
                        serializeData(k);
                    }
                    static if (isSerializableStructure!(ValueType!U))
                    {
                        serializeStructure(v);
                    }
                    else static if (isSerializableData!(ValueType!U))
                    {
                        serializeData(v);
                    }
                }
            }
            else
            {
                output ~= toBytes(input);
            }
        }
    }
    static if(isSerializableStructure!T)
    {
        serializeStructure(source);
    }
    else static if (isSerializableData!T)
    {
        serializeData(source);
    }
    return output;
}
/**
 Main deserialization function. Takes a ubyte array and a template argument, returns the template argument
 of the deserialized argument.
 */
T deserialize(T)(in ubyte[] input)
{
    immutable BOM dataBOM = fromBytes!BOM(input[0..BOM.sizeof]);
    uint pos;
    pos+=BOM.sizeof;
    T destination;
    void*[uint] referenceTracker;
    U fromreference(U)(uint id)
    {
        if (id in referenceTracker)
        {
            static if (is(U == class))
            {
                return cast(U)referenceTracker[id];
            }
            else
            {
                return *(cast(U*)referenceTracker[id]);
            }
        }
        throw new SerializationException("unknown or missing data for reference");
    }
    void addreference(U)(ref U member,uint pos)
    {
        static if (is (U == class))
        {
            referenceTracker[pos] = cast(void*)member;
        }
        else
        {
            referenceTracker[pos] = cast(void*)&member;
        }
    }
    void deserializeStructure(U)(ref U output)
    {
        DataStorageMode type = cast(DataStorageMode)input[pos++];
        if (type == DataStorageMode.byReference)
        {
            enforce!SerializationException(pos+uint.sizeof<=input.length,"unexpected end of input");
            output = fromreference!U(fromBytes!uint(input[pos..pos+uint.sizeof]));
            pos+=uint.sizeof; 
        }
        else
        {
            static if(hasCustomTypeSerializer!(U))
            {
                output = U.deserializeThis(input);
            }
            else
            {
                static if (is(U == class))
                {
                    output = new U();
                }
                addreference(output,pos-1);
                foreach(name;FieldNameTuple!U)
                {
                    static if (hasCustomFieldSerializer!(__traits(getMember,output,name))
                        && !hasAttribute!(__traits(getMember,output,name),noSerialization))
                    {
                        enforce!SerializationException(pos+uint.sizeof<=input.length,"unexpected end of input");
                        uint length = fromBytes!uint(input[pos..pos+uint.sizeof]);
                        pos+=uint.sizeof;
                        enforce!SerializationException(pos+length<=input.length,"unexpected end of input");
                        __traits(getMember,output,name) = mixin("U.deserialize"~name)(input[pos..pos+length]);
                        pos+=length;
                    }
                    else static if(hasCustomTypeSerializer!(typeof(__traits(getMember,output,name)))
                        && !hasAttribute!(__traits(getMember,output,name),noSerialization))
                    {
                        enforce!SerializationException(pos+uint.sizeof<=input.length,"unexpected end of input");
                        uint length = input[pos..pos+uint.sizeof];
                        pos+=uint.sizeof;
                        enforce!SerializationException(pos+length<=input.length,"unexpected end of input");
                        __traits(getMember,output,name) = typeof(__traits(getMember,output,name)).deserializeThis(input[pos..pos+length]);
                        pos+=length;
                    }
                    else static if (isSerializableStructure!(typeof(__traits(getMember,output,name))) 
                        && !hasAttribute!(__traits(getMember,output,name),noSerialization))
                    {
                        deserializeStructure(__traits(getMember,output,name));
                    }
                    else static if (isSerializableData!(typeof(__traits(getMember,output,name))) 
                        && !hasAttribute!(__traits(getMember,output,name),noSerialization))
                    {
                        deserializeData(__traits(getMember,output,name));
                    }
                    else static if(!hasAttribute!(__traits(getMember,U,name),noSerialization))
                    {
                        static assert(0,U.stringof~" has member "~name~" which cannot be serialized\nmark with @noSerialization if intended");
                    }
                }
            }
        }
    }
    void deserializeData(U)(ref U output) if (isSerializableData!U)
    {
        DataStorageMode type = cast(DataStorageMode)input[pos++];
        if (type == DataStorageMode.byReference)
        {
            enforce!SerializationException(pos+uint.sizeof<=input.length,"unexpected end of input");
            output = fromreference!U(fromBytes!uint(input[pos..pos+uint.sizeof]));
            pos+=uint.sizeof;
            return;
        }
        static if (isArray!U)
        {
            addreference(output,pos-1);
            enforce!SerializationException(pos+uint.sizeof<=input.length,"unexpected end of input");
            output.length=fromBytes!uint(input[pos..pos+uint.sizeof]);
            pos+=uint.sizeof;
                for(uint i = 0;i<output.length;i++)
                {
                    static if (isSerializableStructure!(typeof(output[i])))
                    {
                        deserializeStructure(output[i]);
                    }
                    else static if (isSerializableData!(typeof(output[i])))
                    {
                        deserializeData(output[i]);
                    }
                }
        }
        else static if(isAssociativeArray!U)
        {
            addreference(output,pos-1);
            enforce!SerializationException(pos+uint.sizeof<=input.length,"unexpected end of input");
            immutable uint length = fromBytes!uint(input[pos..pos+uint.sizeof]);
            pos+=uint.sizeof;
            uint i = 0;
            KeyType!U key;
            ValueType!U value;
            for(;i<length;i++)
            {
                static if(isSerializableStructure!(KeyType!U))
                {
                    deserializeStructure(key);
                }
                else static if (isSerializableData!(KeyType!U))
                {
                    deserializeData(key);
                }
                static if(isSerializableStructure!(ValueType!U))
                {
                    deserializeStructure(value);
                }
                else static if (isSerializableData!(ValueType!U))
                {
                    deserializeData(value);
                }
                output[key] = value;
            }
        }
        else
        {
            enforce!SerializationException(pos+U.sizeof<=input.length,"unexpected end of input");
            if(dataBOM != bom)
            {
                output = fromBytes!U(array(input[pos..pos+U.sizeof].retro()));
                pos+=U.sizeof;
            }
            else
            {
                output = fromBytes!U(input[pos..pos+U.sizeof]);
                pos+=U.sizeof;
            }
        }
    }
    static if(isSerializableStructure!T)
    {
        deserializeStructure(destination);
    }
    else static if (isSerializableData!T)
    {
        deserializeData(destination);
    }
    return destination;
}

version(unittest)
{
    class SomeClass
    {
        enum serializable = true;
        long someLong;
    }
    struct SomeStruct
    {
        enum serializable = true;
        @customSerialization long someLong;
        @noSerialization int someInt;
        int[] intArray;
        size_t[long] longAArray;
        SomeClass someClass;
        SomeClass[] someOtherClasses;
        static ubyte[] serializesomeLong(in long long_)
        {
            return toBytes(long_).dup(); //I don't know why this is needed but I think it's dmd bug with static and non-static array
        }
        static long deserializesomeLong(in ubyte[] bytes)
        {
            return fromBytes!long(bytes);
        }
    }
    struct NotSerializableStruct
    {
        enum serializable = false;
    }
}
unittest
{
    SomeStruct someStruct;
    someStruct.someLong = 344;
    someStruct.someInt = 22;
    someStruct.intArray = [1,2,3,5,200];
    someStruct.longAArray[44L] = 33;
    someStruct.someClass = new SomeClass();
    someStruct.someClass.someLong = 22;
    someStruct.someOtherClasses ~= someStruct.someClass;
    ubyte[] serialized = serialize(someStruct);
    SomeStruct someOtherStruct = deserialize!SomeStruct(serialized);
    assert(someOtherStruct.someLong == 344);
    assert(someOtherStruct.someInt == int.init);
    assert(someOtherStruct.intArray == [1,2,3,5,200]);
    assert(44L in someOtherStruct.longAArray);
    assert(someStruct.someClass.someLong == someOtherStruct.someOtherClasses[0].someLong);
    assert(!isSerializable!NotSerializableStruct);
    assert(hasCustomFieldSerializer!(SomeStruct.someLong));
}
