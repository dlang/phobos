/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

/++
+   This module implements various XML lexers.
+
+   The methods a lexer should implement are documented in
+   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`);
+   The different lexers here implemented are optimized for different kinds of input
+   and different tradeoffs between speed and memory usage.
+
+   Authors:
+   Lodovico Giaretta
+
+   License:
+   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
+
+   Copyright:
+   Copyright Lodovico Giaretta 2016 --
+/

module std.experimental.xml.lexers;

import std.experimental.xml.interfaces;
import std.experimental.xml.faststrings;

import std.range.primitives;
import std.traits : isArray;

import std.experimental.allocator;
import std.experimental.allocator.gc_allocator;

import std.typecons : Flag, Yes;

/++
+   A lexer that takes a sliceable input.
+
+   This lexer will always return slices of the original input; thus, it does not
+   allocate memory and calls to `start` don't invalidate the outputs of previous
+   calls to `get`.
+
+   This is the fastest of all lexers, as it only performs very quick searches and
+   slicing operations. It has the downside of requiring the entire input to be loaded
+   in memory at the same time; as such, it is optimal for small file but not suitable
+   for very big ones.
+
+   Parameters:
+       T = a sliceable type used as input for this lexer
+       ErrorHandler = a delegate type, used to report the impossibility to complete
+                      operations like `advanceUntil` or `advanceUntilAny`
+       Alloc = a dummy allocator parameter, never used; kept for uniformity with
+               the other lexers
+       reuseBuffer = a dummy flag, never used; kept for uniformity with the other
+                     lexers
+/
struct SliceLexer(T, ErrorHandler, Alloc = shared(GCAllocator), Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer)
{
    package T input;
    package size_t pos;
    package size_t begin;

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!T;
    /// ditto
    alias InputType = T;

    mixin UsesAllocator!Alloc;
    mixin UsesErrorHandler!ErrorHandler;

    /// ditto
    void setSource(T input)
    {
        this.input = input;
        pos = 0;
    }

    static if(isForwardRange!T)
    {
        auto save()
        {
            SliceLexer result = this;
            result.input = input.save;
            return result;
        }
    }

    /// ditto
    auto empty() const
    {
        return pos >= input.length;
    }

    /// ditto
    void start()
    {
        begin = pos;
    }

    /// ditto
    CharacterType[] get() const
    {
        return input[begin..pos];
    }

    /// ditto
    void dropWhile(string s)
    {
        while (pos < input.length && fastIndexOf(s, input[pos]) != -1)
            pos++;
    }

    /// ditto
    bool testAndAdvance(char c)
    {
        if (empty)
            handler();
        if (input[pos] == c)
        {
            pos++;
            return true;
        }
        return false;
    }

    /// ditto
    void advanceUntil(char c, bool included)
    {
        if (empty)
            handler();
        auto adv = fastIndexOf(input[pos..$], c);
        if (adv != -1)
        {
            pos += adv;
            if (empty)
                handler();
        }
        else
        {
            pos = input.length;
        }

        if (included)
        {
            if (empty)
                handler();
            pos++;
        }
    }

    /// ditto
    size_t advanceUntilAny(string s, bool included)
    {
        if (empty)
            handler();

        ptrdiff_t res;
        while ((res = fastIndexOf(s, input[pos])) == -1)
            if (++pos >= input.length)
                handler();
        if (included)
            pos++;
        return res;
    }
}

/++
+   A lexer that takes an InputRange.
+
+   This lexer copies the needed characters from the input range to an internal
+   buffer, returning slices of it. Whether the buffer is reused (and thus all
+   previously returned slices invalidated) depends on the instantiation parameters.
+
+   This is the most flexible lexer, as it imposes very few requirements on its input,
+   which only needs to be an InputRange. It is also the slowest lexer, as it copies
+   characters one by one, so it shall not be used unless it's the only option.
+
+   Params:
+       T           = the InputRange to be used as input for this lexer
+       ErrorHandler = a delegate type, used to report the impossibility to complete
+                      operations like `advanceUntil` or `advanceUntilAny`
+       Alloc       = the allocator used to manage internal buffers
+       reuseBuffer = if set to `Yes` (the default) this parser will always reuse
+                     the same buffers, invalidating all previously returned slices
+/
struct RangeLexer(T, ErrorHandler, Alloc = shared(GCAllocator), Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer)
    if (isInputRange!T)
{
    import std.experimental.xml.appender;

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!T;
    /// ditto
    alias InputType = T;

    mixin UsesAllocator!Alloc;
    mixin UsesErrorHandler!ErrorHandler;

    private Appender!(CharacterType, Alloc) app;

    import std.string: representation;
    static if (is(typeof(representation!CharacterType(""))))
    {
        private typeof(representation!CharacterType("")) input;
        void setSource(T input)
        {
            this.input = input.representation;
            app = typeof(app)(allocator);
        }
    }
    else
    {
        private T input;
        void setSource(T input)
        {
            this.input = input;
            app = typeof(app)(allocator);
        }
    }

    static if (isForwardRange!T)
    {
        auto save()
        {
            RangeLexer result;
            result.input = input.save;
            result.app = typeof(app)(allocator);
            return result;
        }
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    bool empty() const
    {
        return input.empty;
    }

    /// ditto
    void start()
    {
        static if (reuseBuffer)
            app.clear;
        else
            app = typeof(app)(allocator);
    }

    /// ditto
    CharacterType[] get() const
    {
        return app.data;
    }

    /// ditto
    void dropWhile(string s)
    {
        while (!input.empty && fastIndexOf(s, input.front) != -1)
            input.popFront();
    }

    /// ditto
    bool testAndAdvance(char c)
    {
        if (input.empty)
            handler();
        if (input.front == c)
        {
            app.put(input.front);
            input.popFront();
            return true;
        }
        return false;
    }

    /// ditto
    void advanceUntil(char c, bool included)
    {
        if (input.empty)
            handler();
        while (input.front != c)
        {
            app.put(input.front);
            input.popFront();
            if (input.empty)
                handler();
        }
        if (included)
        {
            app.put(input.front);
            input.popFront();
        }
    }

    /// ditto
    size_t advanceUntilAny(string s, bool included)
    {
        if (input.empty)
            handler();
        size_t res;
        while ((res = fastIndexOf(s, input.front)) == -1)
        {
            app.put(input.front);
            input.popFront;
            if (input.empty)
                handler();
        }
        if (included)
        {
            app.put(input.front);
            input.popFront;
        }
        return res;
    }
}

/++
+   A lexer that takes a ForwardRange.
+
+   This lexer copies the needed characters from the forward range to an internal
+   buffer, returning slices of it. Whether the buffer is reused (and thus all
+   previously returned slices invalidated) depends on the instantiation parameters.
+
+   This is slightly faster than `RangeLexer`, but shoudn't be used if a faster
+   lexer is available.
+
+   Params:
+       T           = the InputRange to be used as input for this lexer
+       ErrorHandler = a delegate type, used to report the impossibility to complete
+                      operations like `advanceUntil` or `advanceUntilAny`
+       Alloc       = the allocator used to manage internal buffers
+       reuseBuffer = if set to `Yes` (the default) this parser will always reuse
+                     the same buffers, invalidating all previously returned slices
+/
struct ForwardLexer(T, ErrorHandler, Alloc = shared(GCAllocator), Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer)
    if (isForwardRange!T)
{
    import std.experimental.xml.appender;

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!T;
    /// ditto
    alias InputType = T;

    mixin UsesAllocator!Alloc;
    mixin UsesErrorHandler!ErrorHandler;

    private size_t count;
    private Appender!(CharacterType, Alloc) app;

    import std.string: representation;
    static if (is(typeof(representation!CharacterType(""))))
    {
        private typeof(representation!CharacterType("")) input;
        private typeof(input) input_start;
        void setSource(T input)
        {
            app = typeof(app)(allocator);
            this.input = input.representation;
            this.input_start = this.input;
        }
    }
    else
    {
        private T input;
        private T input_start;
        void setSource(T input)
        {
            app = typeof(app)(allocator);
            this.input = input;
            this.input_start = input;
        }
    }

    auto save()
    {
        ForwardLexer result;
        result.input = input.save();
        result.input_start = input.save();
        result.app = typeof(app)(allocator);
        result.count = count;
        return result;
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    bool empty() const
    {
        return input.empty;
    }

    /// ditto
    void start()
    {
        static if (reuseBuffer)
            app.clear;
        else
            app = typeof(app)(allocator);

        input_start = input.save;
        count = 0;
    }

    /// ditto
    CharacterType[] get()
    {
        import std.range: take;
        auto diff = count - app.data.length;
        if (diff)
        {
            app.reserve(diff);
            app.put(input_start.take(diff));
        }
        return app.data;
    }

    /// ditto
    void dropWhile(string s)
    {
        while (!input.empty && fastIndexOf(s, input.front) != -1)
            input.popFront();
        input_start = input.save;
    }

    /// ditto
    bool testAndAdvance(char c)
    {
        if (input.empty)
            handler();
        if (input.front == c)
        {
            count++;
            input.popFront();
            return true;
        }
        return false;
    }

    /// ditto
    void advanceUntil(char c, bool included)
    {
        if (input.empty)
            handler();
        while (input.front != c)
        {
            count++;
            input.popFront();
            if (input.empty)
                handler();
        }
        if (included)
        {
            count++;
            input.popFront();
        }
    }

    /// ditto
    size_t advanceUntilAny(string s, bool included)
    {
        if (input.empty)
            handler();
        size_t res;
        while ((res = fastIndexOf(s, input.front)) == -1)
        {
            count++;
            input.popFront;
            if (input.empty)
                handler();
        }
        if (included)
        {
            count++;
            input.popFront;
        }
        return res;
    }
}

/++
+   A lexer that takes an InputRange of slices from the input.
+
+   This lexer tries to merge the speed of direct slicing with the low memory requirements
+   of ranges. Its input is a range whose elements are chunks of the input data; this
+   lexer returns slices of the original chunks, unless the output is split between two
+   chunks. If that's the case, a new array is allocated and returned. The various chunks
+   may have different sizes.
+
+   The bigger the chunks are, the better is the performance and higher the memory usage,
+   so finding the correct tradeoff is crucial for maximum performance. This lexer is
+   suitable for very large files, which are read chunk by chunk from the file system.
+
+   Params:
+       T           = the InputRange to be used as input for this lexer
+       ErrorHandler = a delegate type, used to report the impossibility to complete
+                      operations like `advanceUntil` or `advanceUntilAny`
+       Alloc       = the allocator used to manage internal buffers
+       reuseBuffer = if set to `Yes` (the default) this parser will always reuse
+                     the same buffers, invalidating all previously returned slices
+/
struct BufferedLexer(T, ErrorHandler, Alloc = shared(GCAllocator), Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer)
    if (isInputRange!T && isArray!(ElementType!T))
{
    import std.experimental.xml.appender;

    alias BufferType = ElementType!T;

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    alias CharacterType = ElementEncodingType!BufferType;
    /// ditto
    alias InputType = T;

    private InputType buffers;
    private size_t pos;
    private size_t begin;

    private Appender!(CharacterType, Alloc) app;
    private bool onEdge;

    mixin UsesAllocator!Alloc;
    mixin UsesErrorHandler!ErrorHandler;

    import std.string: representation, assumeUTF;
    static if (is(typeof(representation!CharacterType(""))))
    {
        private typeof(representation!CharacterType("")) buffer;
        void popBuffer()
        {
            buffer = buffers.front.representation;
            buffers.popFront;
        }
    }
    else
    {
        private BufferType buffer;
        void popBuffer()
        {
            buffer = buffers.front;
            buffers.popFront;
        }
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    void setSource(T input)
    {
        app = typeof(app)(allocator);
        this.buffers = input;
        popBuffer;
    }

    static if (isForwardRange!T)
    {
        auto save() const
        {
            BufferedLexer result;
            result.buffers = buffers.save();
            result.buffer = buffer;
            result.pos = pos;
            result.begin = begin;
            result.app = typeof(app)(allocator);
            return result;
        }
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    bool empty()
    {
        return buffers.empty && pos >= buffer.length;
    }

    /// ditto
    void start()
    {
        static if (reuseBuffer)
            app.clear;
        else
            app = typeof(app)(allocator);

        begin = pos;
        onEdge = false;
    }

    private void advance()
    {
        if (empty)
            handler();
        if (pos + 1 >= buffer.length)
        {
            if (onEdge)
                app.put(buffer[pos]);
            else
            {
                app.put(buffer[begin..$]);
                onEdge = true;
            }
            popBuffer;
            begin = 0;
            pos = 0;
        }
        else if (onEdge)
            app.put(buffer[pos++]);
        else
            pos++;
    }
    private void advance(ptrdiff_t n)
    {
        foreach(i; 0..n)
            advance();
    }
    private void advanceNextBuffer()
    {
        if (empty)
            handler();
        if (onEdge)
            app.put(buffer[pos..$]);
        else
        {
            app.put(buffer[begin..$]);
            onEdge = true;
        }
        popBuffer;
        begin = 0;
        pos = 0;
    }

    /++
    +   See detailed documentation in
    +   $(LINK2 ../interfaces/isLexer, `std.experimental.xml.interfaces.isLexer`)
    +/
    CharacterType[] get() const
    {
        if (onEdge)
            return app.data;
        else
        {
            static if (is(typeof(representation!CharacterType(""))))
                return cast(CharacterType[])buffer[begin..pos];
            else
                return buffer[begin..pos];
        }
    }

    /// ditto
    void dropWhile(string s)
    {
        while (!empty && fastIndexOf(s, buffer[pos]) != -1)
            advance();
    }

    /// ditto
    bool testAndAdvance(char c)
    {
        if (empty)
            handler();
        if (buffer[pos] == c)
        {
            advance();
            return true;
        }
        return false;
    }

    /// ditto
    void advanceUntil(char c, bool included)
    {
        if (empty)
            handler();
        ptrdiff_t adv;
        while ((adv = fastIndexOf(buffer[pos..$], c)) == -1)
        {
            advanceNextBuffer();
        }
        advance(adv);

        if (included)
            advance();
    }

    /// ditto
    size_t advanceUntilAny(string s, bool included)
    {
        if (empty)
            handler();
        ptrdiff_t res;
        while ((res = fastIndexOf(s, buffer[pos])) == -1)
        {
            advance();
        }
        if (included)
            advance();
        return res;
    }
}

/++
+   Instantiates a specialized lexer for the given input type, allocator and error handler.
+
+   The default error handler just asserts 0.
+   If the type of the allocator is specified as template parameter, but no instance of it
+   is passed as runtime parameter, then the static method `instance` of the allocator type is
+   used. If no allocator type is specified, defaults to `shared(GCAllocator)`.
+/
auto chooseLexer(Input, Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer, Alloc, Handler)
                (ref Alloc alloc, Handler handler = () { assert(0, "Unexpected input end while lexing"); })
{
    static if (is(SliceLexer!(Input, Handler, Alloc, reuseBuffer)))
    {
        auto res = SliceLexer!(Input, Handler, Alloc, reuseBuffer)(alloc);
        res.errorHandler = handler;
        return res;
    }
    else static if (is(BufferedLexer!(Input, Handler, Alloc, reuseBuffer)))
    {
        auto res = BufferedLexer!(Input, Handler, Alloc, reuseBuffer)(alloc);
        res.errorHandler = handler;
        return res;
    }
    else static if (is(RangeLexer!(Input, Handler, Alloc, reuseBuffer)))
    {
        auto res = RangeLexer!(Input, Handler, Alloc, reuseBuffer)(alloc);
        res.errorHandler = handler;
        return res;
    }
    else static assert(0);
}
/// ditto
auto chooseLexer(alias Input, Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer, Alloc, Handler)
                (ref Alloc alloc, Handler handler = () { assert(0, "Unexpected input end while lexing"); })
{
    return chooseLexer!(typeof(Input), reuseBuffer, Alloc, Handler)(alloc, handler);
}
/// ditto
auto chooseLexer(Input, Alloc = shared(GCAllocator), Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer, Handler)
                (Handler handler = () { assert(0, "Unexpected input end while lexing"); })
    if (is(typeof(Alloc.instance)))
{
    return chooseLexer!(Input, reuseBuffer, Alloc, Handler)(Alloc.instance, handler);
}
/// ditto
auto chooseLexer(alias Input, Alloc = shared(GCAllocator), Flag!"reuseBuffer" reuseBuffer = Yes.reuseBuffer, Handler)
                (Handler handler = () { assert(0, "Unexpected input end while lexing"); })
    if (is(typeof(Alloc.instance)))
{
    return chooseLexer!(typeof(Input), reuseBuffer, Alloc, Handler)(Alloc.instance, handler);
}

version(unittest)
{
    struct DumbBufferedReader
    {
        string content;
        size_t chunk_size;

        void popFront() @nogc
        {
            if (content.length > chunk_size)
                content = content[chunk_size..$];
            else
                content = [];
        }
        string front() const @nogc
        {
            if (content.length >= chunk_size)
                return content[0..chunk_size];
            else
                return content[0..$];
        }
        bool empty() const @nogc
        {
            return !content.length;
        }
    }
}

unittest
{
    auto handler = () { assert(0, "something went wrong..."); };

    void testLexer(T)(T.InputType delegate(string) conv)
    {
        string xml = q{
        <?xml encoding = "utf-8" ?>
        <aaa xmlns:myns="something">
            <myns:bbb myns:att='>'>
                <!-- lol -->
                Lots of Text!
                On multiple lines!
            </myns:bbb>
            <![CDATA[ Ciaone! ]]>
            <ccc/>
        </aaa>
        };

        T lexer;
        lexer.setSource(conv(xml));
        lexer.errorHandler = handler;

        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntilAny(":>", true);
        assert(lexer.get() == "<?xml encoding = \"utf-8\" ?>");

        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntilAny("=:", false);
        assert(lexer.get() == "<aaa xmlns");

        lexer.start();
        lexer.advanceUntil('>', true);
        assert(lexer.get() == ":myns=\"something\">");

        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntil('\'', true);
        assert(lexer.testAndAdvance('>'));
        lexer.advanceUntil('>', false);
        assert(lexer.testAndAdvance('>'));
        assert(lexer.get() == "<myns:bbb myns:att='>'>");

        assert(!lexer.empty);
    }

    testLexer!(SliceLexer!(string, typeof(handler)))(x => x);
    testLexer!(RangeLexer!(string, typeof(handler)))(x => x);
    testLexer!(ForwardLexer!(string, typeof(handler)))(x => x);
    testLexer!(BufferedLexer!(DumbBufferedReader, typeof(handler)))(x => DumbBufferedReader(x, 10));
}

@nogc unittest
{
    import std.experimental.allocator.mallocator;

    auto handler = () { assert(0, "something went wrong..."); };

    void testLexer(T)(T.InputType delegate(string) @nogc conv)
    {
        string xml = q{
        <?xml encoding = "utf-8" ?>
        <aaa xmlns:myns="something">
            <myns:bbb myns:att='>'>
                <!-- lol -->
                Lots of Text!
                On multiple lines!
            </myns:bbb>
            <![CDATA[ Ciaone! ]]>
            <ccc/>
        </aaa>
        };

        auto alloc = Mallocator.instance;

        T lexer = T(&alloc);
        lexer.setSource(conv(xml));
        lexer.errorHandler = handler;

        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntilAny(":>", true);
        assert(lexer.get() == "<?xml encoding = \"utf-8\" ?>");

        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntilAny("=:", false);
        assert(lexer.get() == "<aaa xmlns");

        lexer.start();
        lexer.advanceUntil('>', true);
        assert(lexer.get() == ":myns=\"something\">");

        lexer.dropWhile(" \r\n\t");
        lexer.start();
        lexer.advanceUntil('\'', true);
        assert(lexer.testAndAdvance('>'));
        lexer.advanceUntil('>', false);
        assert(lexer.testAndAdvance('>'));
        assert(lexer.get() == "<myns:bbb myns:att='>'>");

        assert(!lexer.empty);
    }

    testLexer!(RangeLexer!(string, typeof(handler), shared(Mallocator)))(x => x);
    testLexer!(ForwardLexer!(string, typeof(handler), shared(Mallocator)))(x => x);
    testLexer!(BufferedLexer!(DumbBufferedReader, typeof(handler), shared(Mallocator)))(x => DumbBufferedReader(x, 10));
}
