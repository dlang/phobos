//Written in the D programming language

/**
 * Implements functionality to read Comma Separated Values and its variants
 * from a input range.
 *
 * Comma Separated Values provide a simple means to transfer and store
 * tabular data. It has been common for programs to use their own
 * variant of the CSV format. This parser will loosely follow the
 * $(WEB tools.ietf.org/html/rfc4180, RFC-4180). CSV input should adhered
 * to the following criteria, differences from RFC-4180 in parentheses.
 *
 * $(UL
 *     $(LI A record is separated by a new line (CRLF,LF,CR))
 *     $(LI A final record may end with a new line)
 *     $(LI A header may be provided as the first record in input)
 *     $(LI A record has fields separated by a comma (customizable))
 *     $(LI A field containing new lines, commas, or double quotes
 *          should be enclosed in double quotes (customizable))
 *     $(LI Double quotes in a field are escaped with a double quote)
 *     $(LI Each record should contain the same number of fields (not enforced))
 *   )
 *
 * Example:
 *
 * -------
 * import std.algorithm;
 * import std.array;
 * import std.csv;
 * import std.stdio;
 * import std.typecons;
 *
 * void main()
 * {
 *     auto text = "Joe,Carpenter,300000\nFred,Blacksmith,400000\r\n";
 *
 *     foreach(record; csvReader!(Tuple!(string,string,int))(text))
 *     {
 *         writefln("%s works as a %s and earns $%d per year",
 *                  record[0], record[1], record[2]);
 *     }
 * }
 * -------
 *
 * When a file contains a heading the Contents can be specified as an
 * associative array. Passing null to signafy that a heading is pressent.
 *
 * -------
 * auto text = "Name,Occupation,Salary\r"
 *     "Joe,Carpenter,300000\nFred,Blacksmith,400000\r\n";
 *
 * foreach(record; csvReader!(string[string])
 *         (text,cast(string[])null))
 * {
 *     writefln("%s works as a %s and earns $%s per year",
 *              record["Name"], record["Occupation"], 
 *              record["Salary"]);
 * }
 * -------
 *
 * This module allows content to be iterated by record stored in a struct
 * or into a range of fields. Upon detection of an error an
 * IncompleteCellException is thrown (can be disabled). csvNextToken has been
 * made public to allow for attempted recovery.
 *
 * Disabling exceptions will lift many restrictions specified above. A quote
 * can appear in a field if the field was not quoted. If in a quoted field any
 * quote by itself, not at the end of a field, will end processing for that
 * field. The field is ended when there is no input, even if the quote was not
 * closed.
 *
 *   See_Also:
 *      $(WEB en.wikipedia.org/wiki/Comma-separated_values, Wikipedia
 *      Comma-separated values)
 *
 *   Copyright: Copyright 2011
 *   License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
 *   Authors:   Jesse Phillips
 *   Source:    $(PHOBOSSRC std/_csv.d)
 */
module std.csv;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.range;
import std.traits;

/**
 * Exception containing the row and column for when an Exception was thrown.
 *
 * This Exception will have one of the following as part of its next property.
 *
 * $(UL
 *     $(LI IncompletCellException)
 *     $(LI ConvException)
 *  )
 */
class CSVException : Exception {
    ///
    size_t row, col;
    this(size_t row, size_t col, Exception e) {
        super("(Row: " ~ to!string(row) ~ 
              ", Col: " ~ to!string(col) ~ ") CSV Parse Failure", e);
        this.row = row;
        this.col = col;
    }
}

/**
 * Exception thrown when a Token is identified to not be completed: a quote is
 * found in an unquoted field, data continues after a closing quote, or the
 * quoted field was not closed before data was empty.
 *
 * This Exception will be part of CSVException unless using $(LREF
 * csvNextToken) directly.
 */
class IncompleteCellException : Exception
{
    /// Data pulled from input before finding a problem
    string partialData;
    this(string cellPartial, string msg)
    {
        super(msg);
        partialData = cellPartial;
    }
}

/**
 * Exception thrown when a heading is provided but a matching column is not
 * found or the order did not match that found in the input (non-struct).
 */
class HeadingMismatchException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

/**
 * Determines the behavior for when an error is detected.
 *
 * Disabling exception will follow this rules:
 * $(UL
 *     $(LI A quote can appear in a field if the field was not quoted.)
 *     $(LI If in a quoted field any quote by itself, not at the end of a
 *     field, will end processing for that field.)
 *     $(LI The field is ended when there is no input, even if the quote was
 *     not closed.)
 *     $(LI If the given header does not match the order in the input, the
 *     content will return as it is found in the input.)
 *     $(LI If the given header contains columns not found in the input they
 *     will be ignored.)
 *  )
 *
*/
enum Malformed
{
    /// No exceptions are thrown due to incorrect CSV.
    ignore,
    /// Use exceptions when input is incorrect CSV.
    throwException
}

/**
 * Builds a $(LREF Records) struct for iterating over records found in $(D
 * input).
 *
 * This function simplifies the process for standard text input.
 * For other input, delimited by colon, create Records yourself.
 *
 * The $(D Contents) of the input can be provided if all the records are the
 * same type such as all integer data:
 *
 * -------
 * string str = `76,26,22`;
 * int[] ans = [76,26,22];
 * auto records = csvReader!int(str);
 *
 * int count;
 * foreach(record; records) {
 *     assert(equal(record, ans));
 * }
 * -------
 *
 * Example using a struct with modified delimiter:
 *
 * -------
 * string str = "Hello;65;63.63\nWorld;123;3673.562";
 * struct Layout {
 *     string name;
 *     int value;
 *     double other;
 * }
 *
 * auto records = csvReader!Layout(str,';');
 *
 * foreach(record; records) {
 *     writeln(record.name);
 *     writeln(record.value);
 *     writeln(record.other);
 * }
 * -------
 *
 * An optional $(D heading) can be provided. The first record will be read in
 * as the heading. If $(D Contents) is a struct then the heading provided is
 * expected to correspond to the fields in the struct. When $(D Contents) is
 * non-struct the $(D heading) must be provided in the same order as the input
 * or an exception is thrown.
 *
 * Read only column "b":
 *
 * -------
 * string str = "a,b,c\nHello,65,63.63\nWorld,123,3673.562";
 * auto records = csvReader(str, ["b"]);
 *
 * auto ans = [["65"],["123"]];
 * foreach(record; records) {
 *     assert(equal(record, ans.front));
 *     ans.popFront();
 * }
 * -------
 *
 * Read from heading of different order:
 *
 * -------
 * string str = "a,b,c\nHello,65,63.63\nWorld,123,3673.562";
 * struct Layout
 * {
 *     int value;
 *     double other;
 *     string name;
 * }
 *
 * auto records = csvReader!Layout(str, ["b","c","a"]);
 * -------
 *
 * The header can also be left empty if the input contains a header but
 * all columns should be iterated. The heading from the input can always
 * be accessed from the heading field.
 *
 * -------
 * string str = "a,b,c\nHello,65,63.63\nWorld,123,3673.562";
 * auto records = csvReader(str, cast(string[])null);
 *
 * assert(records.heading == ["a","b","c"]);
 * -------
 *
 * $(LINK2 http://d.puremagic.com/issues/show_bug.cgi?id=2394, IFTI fails for
 * nulls) prevents just sending null or [] as a header.
 *
 * Returns:
 *      $(LREF Records) struct which provides a $(XREF range, InputRange) of
 *      each record.
 *
 * Throws:
 *       $(LREF CSVException) When a quote is found in an unquoted field,
 *       data continues after a closing quote, the quoted field was not
 *       closed before data was empty, or a conversion failed.
 *
 *       $(LREF HeadingMismatchException)  when a heading is provided but a
 *       matching column is not found or the order did not match that found in
 *       the input (non-struct).
 */
auto csvReader(Contents = string, Range, Separator = char)(Range input,
                 Separator delimiter = ',', Separator quote = '"')
               if(isInputRange!Range && isSomeChar!(ElementType!Range) 
                  && isSomeChar!(Separator) && !is(Contents == class)
                  && !is(Contents T : T[U], U : string))
{
    return Records!(Contents,Malformed.throwException,Range,
                    ElementType!Range,string[])
        (input, delimiter, quote);
}

/// Ditto
auto csvReader(Contents = string, Range, Heading, Separator = char)
                (Range input, Heading heading,
                 Separator delimiter = ',', Separator quote = '"')
               if(isInputRange!Range && isSomeChar!(ElementType!Range) 
                  && isSomeChar!(Separator) && !is(Contents == class) 
                  && isForwardRange!Heading 
                  && isSomeString!(ElementType!Heading))
{
    return Records!(Contents,Malformed.throwException,Range,
                    ElementType!Range,Heading)
        (input, heading, delimiter, quote);
}

// Test standard iteration over input.
unittest
{
    string str = `one,two,"three ""quoted""","",` ~ "\"five\nnew line\"\nsix";
    auto records = csvReader(str);

    int count;
    foreach(record; records)
    {
        foreach(cell; record)
        {
            count++;
        }
    }
    assert(count == 6);
}

// Test newline on last record
unittest
{
    string str = "one,two\nthree,four\n";
    auto records = csvReader(str);
    records.popFront();
    records.popFront();
    assert(records.empty);
}

// Test structure conversion interface.
unittest {
    string str = "Hello,65,63.63\nWorld,123,3673.562";
    struct Layout
    {
        string name;
        int value;
        double other;
    }

    Layout ans[2];
    ans[0].name = "Hello";
    ans[0].value = 65;
    ans[0].other = 663.63;
    ans[1].name = "World";
    ans[1].value = 65;
    ans[1].other = 663.63;

    auto records = csvReader!Layout(str);

    int count;
    foreach(record; records)
    {
        ans[count].name = record.name;
        ans[count].value = record.value;
        ans[count].other = record.other;
        count++;
    }
    assert(count == ans.length);
}

// Test input conversion interface
unittest
{
    string str = `76,26,22`;
    int[] ans = [76,26,22];
    auto records = csvReader!int(str);

    foreach(record; records)
    {
        assert(equal(record, ans));
    }
}

// Test struct & header interface
unittest
{
    string str = "a,b,c\nHello,65,63.63\nWorld,123,3673.562";
    struct Layout
    {
        int value;
        double other;
        string name;
    }

    auto records = csvReader!Layout(str, ["b","c","a"]);

    Layout ans[2];
    ans[0].name = "Hello";
    ans[0].value = 65;
    ans[0].other = 63.63;
    ans[1].name = "World";
    ans[1].value = 123;
    ans[1].other = 3673.562;

    int count;
    foreach (record; records)
    {
        assert(ans[count].name == record.name);
        assert(ans[count].value == record.value);
        assert(ans[count].other == record.other);
        count++;
    }
    assert(count == ans.length);

}

// Test header interface
unittest
{
    string str = "a,b,c\nHello,65,63.63\nWorld,123,3673.562";
    auto records = csvReader(str, ["b"]);

    auto ans = [["65"],["123"]];
    foreach(record; records) {
        assert(equal(record, ans.front));
        ans.popFront();
    }

    try
    {
        records = csvReader(str, ["b","a"]);
        assert(0);
    }
    catch(HeadingMismatchException e)
    {
    }
    auto records2 = Records!(string,Malformed.ignore,string,char,string[])
       (str, ["b","a"], ',', '"');

    ans = [["Hello","65"],["World","123"]];
    foreach(record; records2) {
        assert(equal(record, ans.front));
        ans.popFront();
    }

    str = "a,c,e\nJoe,Carpenter,300000\nFred,Fly,4";
    records2 = Records!(string,Malformed.ignore,string,char,string[])
       (str, ["a","b","c","d"], ',', '"');

    ans = [["Joe","Carpenter"],["Fred","Fly"]];
    foreach(record; records2) {
        assert(equal(record, ans.front));
        ans.popFront();
    }
}

// Test null header interface
unittest
{
    string str = "a,b,c\nHello,65,63.63\nWorld,123,3673.562";
    auto records = csvReader(str, ["a"]);

    assert(records.heading == ["a","b","c"]);
}

// Test unchecked read
unittest
{
    string str = "one \"quoted\"";
    foreach(record; Records!(string,Malformed.ignore,string,char,string[])
            (str,',','"'))
    {
        foreach(cell; record)
        {
            assert(cell == "one \"quoted\"");
        }
    }

    str = "one \"quoted\",two \"quoted\" end";
    struct Ans
    {
        string a,b;
    }
    foreach(record; Records!(Ans,Malformed.ignore,string,char,string[])
            (str,',','"'))
    {
        assert(record.a == "one \"quoted\"");
        assert(record.b == "two \"quoted\" end");
    }
}

// Test Windows line break
unittest
{
    string str = "one,two\r\nthree";

    auto records = csvReader(str);
    auto record = records.front;
    assert(record.front == "one");
    record.popFront();
    assert(record.front == "two");
    records.popFront();
    record = records.front;
    assert(record.front == "three");
}


// Test associative array support
unittest
{
  string str = "1;2;3\n34;65;63\n34;65;63";
 
  auto records = csvReader!(string[string])(str,["3","1"],';');
  int count;
  foreach(record; records)
  {
      count++;
      assert(record["1"] == "34");
      assert(record["3"] == "63");
  }
  assert(count == 2);
}

/**
 * Range for iterating CSV records.
 *
 * This range is returned by the csvReader functions. It can be
 * created in a similar manner to allow $(D ErrorLevel) be set to $(LREF
 * Malformed).ignore if best guess processing should take place.
 *
 * Example for integer data:
 *
 * -------
 * string str = `76;^26^;22`;
 * int[] ans = [76,26,22];
 * auto records = Records!(int,Malformed.ignore,string,char,string[])
 *       (str, ';', '^');
 *
 * foreach(record; records) {
 *    assert(equal(record, ans));
 * }
 * -------
 *
 */
struct Records(Contents, Malformed ErrorLevel, Range, Separator, Heading)
    if(isSomeChar!Separator && isInputRange!Range
       && isSomeChar!(ElementType!Range) && !is(Contents == class)
       && isForwardRange!Heading && isSomeString!(ElementType!Heading))
{
private:
    Range _input;
    Separator _separator;
    Separator _quote;
    size_t[] indices;
    uint _row;
    bool _empty;
    static if(is(Contents == struct))
    {
        Contents recordContent;
        Record!(Range, ErrorLevel, Range, Separator) recordRange;
    }
    else static if(is(Contents T : T[U], U : string))
    {
        Contents recordContent;
        Record!(T, ErrorLevel, Range, Separator) recordRange;
    }
    else
        Record!(Contents, ErrorLevel, Range, Separator) recordRange;
public:
    /**
     * Heading from the input in array form.
     *
     * -------
     * string str = "a,b,c\nHello,65,63.63";
     * auto records = csvReader(str, ["a"]);
     *
     * assert(records.heading == ["a","b","c"]);
     * -------
     */
    Range[] heading;

    /**
     * Constructor to initialize the input, delimiter and quote for input
     * without a heading.
     *
     * -------
     * string str = `76;^26^;22`;
     * int[] ans = [76,26,22];
     * auto records = Records!(int,Malformed.ignore,string,char,string[])
     *       (str, ';', '^');
     *
     * foreach(record; records) {
     *    assert(equal(record, ans));
     * }
     * -------
     */
    this(Range input, Separator delimiter, Separator quote)
    {
        _input = input;
        _separator = delimiter;
        _quote = quote;

        static if(is(Contents == struct))
        {
            indices.length =  FieldTypeTuple!(Contents).length;
            foreach(i, j; FieldTypeTuple!Contents)
                indices[i] = i;
        }
        prime();
    }

    /**
     * Constructor to initialize the input, delimiter and quote for input
     * with a heading.
     *
     * -------
     * string str = `high;mean;low\n76;^26^;22`;
     * auto records = Records!(int,Malformed.ignore,string,char,string[])
     *       (str, ["high","low"], ';', '^');
     *
     * int[] ans = [76,22];
     * foreach(record; records) {
     *    assert(equal(record, ans));
     * }
     * -------
     *
     * Throws:
     *       $(LREF HeadingMismatchException)  when a heading is provided but a
     *       matching column is not found or the order did not match that found
     *       in the input (non-struct).
     */
    this(Range input, Heading colHeaders, Separator delimiter, Separator quote)
    {
        _input = input;
        _separator = delimiter;
        _quote = quote;

        size_t[string] colToIndex;
        foreach(h; colHeaders)
        {
            colToIndex[h] = size_t.max;
        }

        auto r = Record!(Range, ErrorLevel, Range, Separator)
            (&_input, _separator, _quote, indices);

        size_t colIndex;
        foreach(col; r)
        {
            heading ~= col;
            auto ptr = col in colToIndex;
            if(ptr)
                *ptr = colIndex;
            colIndex++;
        }

        indices.length = colToIndex.length;
        int i;
        foreach(h; colHeaders)
        {
            immutable index = colToIndex[h];
            static if(ErrorLevel != Malformed.ignore)
                enforceEx!(HeadingMismatchException)(index < size_t.max,
                        "Header not found: " ~ to!string(h));
            indices[i++] = index;
        }

        static if(!is(Contents == struct))
        {
            static if(is(Contents T : T[U], U : string))
            {
                sort(indices);
            }
            else static if(ErrorLevel == Malformed.ignore)
            {
                sort(indices);
            }
            else
            {
                enforceEx!(HeadingMismatchException)(isSorted(indices),
                           "Header in input does not match specified header.");
            }
        }

        popFront();
    }

    this(this)
    {
        recordRange._input = &_input;
    }

    /**
     * Part of the $(XREF range, InputRange) interface.
     *
     * Returns:
     *      If $(D Contents) is a struct, the struct will be filled with record
     *      data.
     *
     *      If $(D Contents) is non-struct, a $(LREF Record) will be returned.
     */
    @property auto front()
    {
        assert(!empty);
        static if(is(Contents == struct))
        {
            return recordContent;
        }
        else static if(is(Contents T : T[U], U : string))
        {
            return recordContent;
        }
        else
        {
            recordRange._input = &_input;
            return recordRange;
        }
    }

    /**
     * Part of the $(XREF range, InputRange) interface.
     */
    @property bool empty()
    {
        return _empty;
    }

    /**
     * Part of the $(XREF range, InputRange) interface.
     *
     * Throws:
     *       $(LREF CSVException) When a quote is found in an unquoted field,
     *       data continues after a closing quote, the quoted field was not
     *       closed before data was empty, or a conversion failed.
     */
    void popFront()
    {
        recordRange._input = &_input;

        while(!recordRange.empty)
        {
            recordRange.popFront();
        }

        if(!_input.empty)
        {
           if(_input.front == '\r')
           {
               _input.popFront();
               if(_input.front == '\n')
                   _input.popFront();
           }
           else if(_input.front == '\n')
               _input.popFront();
        }

        if(_input.empty)
            _empty = true;

        prime();
    }

    private void prime()
    {
        if(_empty)
            return;
        _row++;
        static if(is(Contents == struct))
        {
            recordRange = typeof(recordRange)
                                 (&_input, _separator, _quote, null);
        }
        else
        {
            recordRange = typeof(recordRange)
                                 (&_input, _separator, _quote, indices);
        }

        recordRange._row = _row;

        static if(is(Contents T : T[U], U : string))
        {
            T[U] aa;
            try
            {
                for(; !recordRange.empty; recordRange.popFront())
                {
                    aa[heading[recordRange._col-1]] = recordRange.front;
                }
            }
            catch(ConvException e)
            {
                throw new CSVException(_row, recordRange._col, e);
            }

            recordContent = aa;
        }
        else static if(is(Contents == struct))
        {
            size_t colIndex;
            try
            {
                foreach(colData; recordRange)
                {
                    scope(exit) colIndex++;
                    if(indices.length > 0)
                    {
                        foreach(ti, ToType; FieldTypeTuple!(Contents))
                        {
                            if(indices[ti] == colIndex)
                            {
                                recordContent.tupleof[ti] = to!ToType(colData);
                            }
                        }
                    }
                    else
                    {
                        foreach(ti, ToType; FieldTypeTuple!(Contents))
                        {
                            recordContent.tupleof[ti] = to!ToType(colData);
                        }
                    }
                }
            }
            catch(ConvException e)
            {
                throw new CSVException(_row, colIndex, e);
            }
        }
    }
}

unittest {
    string str = `76;^26^;22`;
    int[] ans = [76,26,22];
    auto records = Records!(int,Malformed.ignore,string,char,string[])
          (str, ';', '^');

    foreach(record; records)
    {
        assert(equal(record, ans));
    }
}

/**
 * Returned by a Records when Contents is a non-struct.
 */
private struct Record(Contents, Malformed ErrorLevel, Range, Separator)
    if(!is(Contents == class) && !is(Contents == struct))
{
private:
    Range* _input;
    Separator _separator;
    Separator _quote;
    Contents curContentsoken;
    typeof(appender!(char[])()) _front;
    bool _empty;
    size_t _col, _row;
    size_t[] _popCount;
public:
    /*
     * params:
     *      input = Pointer to a character input range
     *      delimiter = Separator for each column
     *      quote = Character used for quotation
     *      indices = An array containing which columns will be returned.
     *             If empty, all columns are returned. List must be in order.
     */
    this(Range* input, Separator delimiter, Separator quote, size_t[] indices)
    {
        _input = input;
        _separator = delimiter;
        _quote = quote;
        _front = appender!(char[])();
        _popCount = indices.dup;

        // If a header was given, each call to popFront will need
        // to eliminate so many tokens. This calculates
        // how many will be skipped to get to the next header column
        size_t normalizer;
        foreach(ref c; _popCount) {
            static if(ErrorLevel == Malformed.ignore)
            {
                // If we are not throwing exceptions
                // a header may not exist, indices are sorted
                // and will be size_t.max if not found.
                if(c == size_t.max)
                    break;
            }
            c -= normalizer;
            normalizer += c + 1;
        }

        prime();
    }

    /**
     * Part of the $(XREF range, InputRange) interface.
     */
    @property Contents front()
    {
        assert(!empty);
        return curContentsoken;
    }

    /**
     * Part of the $(XREF range, InputRange) interface.
     */
    @property bool empty()
    {
        return _empty;
    }

    /*
     * Record is complete when input
     * is empty or starts with record break
     */
    private bool recordEnd()
    {
        if((*_input).empty
           || (*_input).front == '\n'
           || (*_input).front == '\r')
        {
            return true;
        }
        return false;
    }


    /**
     * Part of the $(XREF range, InputRange) interface.
     *
     * Throws:
     *       $(LREF CSVException) When a quote is found in an unquoted field,
     *       data continues after a closing quote, the quoted field was not
     *       closed before data was empty, or a conversion failed.
     */
    void popFront()
    {
        // Skip last of record when header is depleted.
        if(_popCount && _popCount.empty)
            while(!recordEnd())
            {
                prime(1);
            }

        if(recordEnd())
        {
            _empty = true;
            return;
        }

        // Separator is left on the end of input from the last call.
        // This cannot be moved to after the call to csvNextToken as
        // there may be an empty record after it.
        if((*_input).front == _separator)
            (*_input).popFront();

        _front.shrinkTo(0);
        prime();
    }

    /*
     * Handles moving to the next skipNum token.
     */
    private void prime(size_t skipNum)
    {
        foreach(i; 0..skipNum)
        {
            _col++;
            _front.shrinkTo(0);
            if((*_input).front == _separator)
                (*_input).popFront();
            try
            {
                csvNextToken!(ErrorLevel, Range, Separator)
                                   (*_input, _front, _separator, _quote,false);
            }
            catch(Exception e)
            {
                throw new CSVException(_row, _col, e);
            }
        }
    }

    private void prime()
    {
        _col++;
        try
        {
            csvNextToken!(ErrorLevel, Range, Separator)
                               (*_input, _front, _separator, _quote,false);
            auto skipNum = _popCount.empty ? 0 : _popCount.front;
            if(!_popCount.empty)
                _popCount.popFront();

            if(skipNum == size_t.max) {
                while(!recordEnd())
                    prime(1);
                _empty = true;
                return;
            }

            if(skipNum)
                prime(skipNum);
            curContentsoken = to!Contents(_front.data);
        }
        catch(Exception e)
        {
            throw new CSVException(_row, _col, e);
        }

    }
}

/**
 * Lower level control over parsing CSV
 *
 * This function consumes the input. After each call the input will
 * start with either a delimiter or record break (\n, \r\n, \r) which
 * must be removed for subsequent calls.
 *
 * -------
 * string str = "65,63\n123,3673";
 *
 * auto a = appender!(char[]);
 *
 * csvNextToken(str,a,',','"');
 * assert(a.data == "65");
 * assert(str == ",63\n123,3673");
 *
 * str.popFront();
 * a.shrinkTo(0);
 * csvNextToken(str,a,',','"');
 * assert(a.data == "63");
 * assert(str == "\n123,3673");
 *
 * str.popFront();
 * a.shrinkTo(0);
 * csvNextToken(str,a,',','"');
 * assert(a.data == "123");
 * assert(str == ",3673");
 * -------
 *
 * params:
 *       input = Any CSV input
 *       ans   = The first field in the input
 *       sep   = The character to represent a comma in the specification
 *       quote = The character to represent a quote in the specification
 *       startQuoted = Whether the input should be considered to already be in
 * quotes
 *
 */
void csvNextToken(Malformed ErrorLevel = Malformed.throwException,
                           Range, Separator)
                          (ref Range input, ref Appender!(char[]) ans,
                           Separator sep, Separator quote,
                           bool startQuoted = false)
                          if(isSomeChar!Separator && isInputRange!Range
                             && isSomeChar!(ElementType!Range))
{
    bool quoted = startQuoted;
    bool escQuote;
    if(input.empty)
        return;

    if(input.front == '\n')
        return;
    if(input.front == '\r')
        return;

    if(input.front == quote)
    {
        quoted = true;
        input.popFront();
    }

    while(!input.empty)
    {
        assert(!(quoted && escQuote));
        if(!quoted)
        {
            // When not quoted the token ends at sep
            if(input.front == sep)
                break;
            if(input.front == '\r')
                break;
            if(input.front == '\n')
                break;
        }
        if(!quoted && !escQuote)
        {
            if(input.front == quote)
            {
                // Not quoted, but quote found
                static if(ErrorLevel == Malformed.throwException)
                    throw new IncompleteCellException(ans.data.idup,
                          "Quote located in unquoted token");
                else static if(ErrorLevel == Malformed.ignore)
                    ans.put(quote);
            }
            else
            {
                // Not quoted, non-quote character
                ans.put(input.front);
            }
        }
        else
        {
            if(input.front == quote)
            {
                // Quoted, quote found
                // By turning off quoted and turning on escQuote
                // I can tell when to add a quote to the string
                // escQuote is turned to false when it escapes a
                // quote or is followed by a non-quote (see outside else).
                // They are mutually exclusive, but provide different
                // information.
                if(escQuote)
                {
                    escQuote = false;
                    quoted = true;
                    ans.put(quote);
                } else
                {
                    escQuote = true;
                    quoted = false;
                }
            }
            else
            {
                // Quoted, non-quote character
                if(escQuote)
                {
                    static if(ErrorLevel == Malformed.throwException)
                        throw new IncompleteCellException(ans.data.idup,
                          "Content continues after end quote, " ~
                          "or needs to be escaped.");
                    else static if(ErrorLevel == Malformed.ignore)
                        break;
                }
                ans.put(input.front);
            }
        }
        input.popFront();
    }

    static if(ErrorLevel == Malformed.throwException)
        if(quoted && (input.empty || input.front == '\n' || input.front == '\r'))
            throw new IncompleteCellException(ans.data.idup,
                  "Data continues on future lines or trailing quote");

}

// Test csvNextToken on simplest form and correct format.
unittest
{
    string str = "Hello,65,63.63\nWorld,123,3673.562";

    auto a = appender!(char[]);
    csvNextToken(str,a,',','"');
    assert(a.data == "Hello");
    assert(str == ",65,63.63\nWorld,123,3673.562");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "65");
    assert(str == ",63.63\nWorld,123,3673.562");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "63.63");
    assert(str == "\nWorld,123,3673.562");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "World");
    assert(str == ",123,3673.562");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "123");
    assert(str == ",3673.562");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "3673.562");
    assert(str == "");
}

// Test quoted tokens
unittest
{
    string str = `one,two,"three ""quoted""","",` ~ "\"five\nnew line\"\nsix";

    auto a = appender!(char[]);
    csvNextToken(str,a,',','"');
    assert(a.data == "one");
    assert(str == `,two,"three ""quoted""","",` ~ "\"five\nnew line\"\nsix");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "two");
    assert(str == `,"three ""quoted""","",` ~ "\"five\nnew line\"\nsix");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "three \"quoted\"");
    assert(str == `,"",` ~ "\"five\nnew line\"\nsix");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "");
    assert(str == ",\"five\nnew line\"\nsix");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "five\nnew line");
    assert(str == "\nsix");

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "six");
    assert(str == "");
}

// Test empty data is pulled at end of record.
unittest
{
    string str = "one,";
    auto a = appender!(char[]);
    csvNextToken(str,a,',','"');
    assert(a.data == "one");
    assert(str == ",");

    a.shrinkTo(0);
    csvNextToken(str,a,',','"');
    assert(a.data == "");
}

// Test exceptions
unittest
{
    string str = "\"one\nnew line";

    try
    {
    auto a = appender!(char[]);
        csvNextToken(str,a,',','"');
        assert(0);
    }
    catch (IncompleteCellException ice)
    {
        assert(ice.partialData == "one\nnew line");
        assert(str == "");
    }

    str = "Hello world\"";

    try
    {
    auto a = appender!(char[]);
        csvNextToken(str,a,',','"');
        assert(0);
    }
    catch (IncompleteCellException ice)
    {
        assert(ice.partialData == "Hello world");
        assert(str == "\"");
    }

    str = "one, two \"quoted\" end";

    auto a = appender!(char[]);
    csvNextToken!(Malformed.ignore)(str,a,',','"');
    assert(a.data == "one");
    str.popFront();
    a.shrinkTo(0);
    csvNextToken!(Malformed.ignore)(str,a,',','"');
    assert(a.data == " two \"quoted\" end");
}


// Test modifying token delimiter
unittest
{
    string str = `one|two|/three "quoted"/|//`;

    auto a = appender!(char[]);
    csvNextToken(str,a, '|','/');
    assert(a.data == "one");
    assert(str == `|two|/three "quoted"/|//`);

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a, '|','/');
    assert(a.data == "two");
    assert(str == `|/three "quoted"/|//`);

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a, '|','/');
    assert(a.data == `three "quoted"`);
    assert(str == `|//`);

    str.popFront();
    a.shrinkTo(0);
    csvNextToken(str,a, '|','/');
    assert(a.data == "");
}
