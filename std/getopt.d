// Written in the D programming language.

/**
Processing of command line options.

The getopt module implements a $(D getopt) function, which adheres to the POSIX
syntax for command line options. GNU extensions are supported in the form of
long options introduced by a double dash ("--"). Values can be separated by
space/s and additionally by the $(LREF assignChar) character which defaults to
'='. Short options with the value directly attached (i.e.  without intervening
space) are also allowed but configurable to work only for short numeric options.
Support for bundling of command line options, as was the case with the more
traditional single-letter approach, is provided but not enabled by default.

Macros:

WIKI = Phobos/StdGetopt

Copyright: Copyright Andrei Alexandrescu 2008 - 2009.
License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB erdani.org, Andrei Alexandrescu)
Credits:   This module and its documentation are inspired by Perl's $(WEB perldoc.perl.org/Getopt/Long.html, Getopt::Long)
           module. The syntax of D's $(D getopt) is simpler than its Perl
           counterpart because $(D getopt) infers the expected parameter types
           from the static types of the passed-in pointers.
Source:    $(PHOBOSSRC std/_getopt.d)
*/
/*
         Copyright Andrei Alexandrescu 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.getopt;

private import std.array, std.string, std.conv, std.traits, std.bitmanip,
    std.algorithm, std.ascii, std.exception;

version (unittest)
{
    import std.stdio; // for testing only
}

/**
 Synopsis:

---------
import std.getopt;

string data = "file.dat";
int length = 24;
bool verbose;
enum Color { no, yes };
Color color;

void main(string[] args)
{
  getopt(
    args,
    "length",  &length,    // numeric
    "file",    &data,      // string
    "verbose", &verbose,   // flag
    "color",   &color);    // enum
    ...
}
---------

The $(D getopt) function takes a reference to the command line
(as received by $(D main)) as its first argument, and an
unbounded number of pairs of strings and pointers. Each string is an
option meant to "fill" the value pointed-to by the pointer to its
right (the "bound" pointer). The option string in the call to
$(D getopt) should not start with a dash.

In all cases, the command-line options that were parsed and used by
$(D getopt) are removed from $(D args). Whatever in the
arguments did not look like an option is left in $(D args) for
further processing by the program. Values that were unaffected by the
options are not touched, so a common idiom is to initialize options
to their defaults and then invoke $(D getopt). If a command-line argument is
recognized as an option with a parameter and the parameter cannot be parsed
properly (e.g. a number is expected but not present), an $(LREF
IllegalArgumentException) is thrown. The original exception (usually a
$(XREF conv, ConvException)) is accessible with Throwable's $(D next). If an
option expects an argument (applies to non-Boolean options) but wasn't specified
a $(LREF MissingArgumentException) is thrown.

Depending on the type of the pointer being bound, $(D getopt)
recognizes the following kinds of options:

$(OL

  $(LI $(I Boolean options). These are the simplest options; all
  they do is set a Boolean to $(D true):

---------
bool verbose, debugging;
getopt(args, "verbose", &verbose, "debug", &debugging);
---------
  )

  $(LI $(I Numeric options.) If an option is bound to a numeric type, a
  number is expected as the next option, or right within the option
  separated with an "=" sign:

---------
uint timeout;
getopt(args, "timeout", &timeout);
---------

  To set $(D timeout) to $(D 5), invoke the program with either $(D
  --timeout=5) or $(D --timeout 5).
  )

  $(LI $(I Incremental options.) If an option name has a "+" suffix and
  is bound to a numeric type, then the option's value tracks the number
  of times the option occurred on the command line:

---------
uint paranoid;
getopt(args, "paranoid+", &paranoid);
---------

  Invoking the program with "--paranoid --paranoid --paranoid" will set
  $(D paranoid) to 3. Note that an incremental option never
  expects a parameter, e.g. in the command line "--paranoid 42
  --paranoid", the "42" does not set $(D paranoid) to 42;
  instead, $(D paranoid) is set to 2 and "42" is not considered
  as part of the normal program arguments.
  )

  $(LI $(I Enum options.) If an option is bound to an enum, an enum symbol as a
  string is expected as the next option, or right within the option separated
  with an "=" sign:

---------
enum Color { no, yes };
Color color; // default initialized to Color.no
getopt(args, "color", &color);
---------

  To set $(D color) to $(D Color.yes), invoke the program with either $(D
  --color=yes) or $(D --color yes).
  )

  $(LI $(I String options.) If an option is bound to a string, a string
  is expected as the next option, or right within the option separated
  with an "=" sign:

---------
string outputFile;
getopt(args, "output", &outputFile);
---------

  Invoking the program with "--output=myfile.txt" or "--output
  myfile.txt" will set $(D outputFile) to "myfile.txt". If you want to
  pass a string containing spaces, you need to use the quoting that is
  appropriate to your shell, e.g. --output='my file.txt'.
  )

  $(LI $(I Array options.) If an option is bound to an array, a new
  element is appended to the array each time the option occurs:

---------
string[] outputFiles;
getopt(args, "output", &outputFiles);
---------

  Invoking the program with "--output=myfile.txt --output=yourfile.txt"
  or "--output myfile.txt --output yourfile.txt" will set $(D
  outputFiles) to [ "myfile.txt", "yourfile.txt" ].
  )

  $(LI $(I Hash options.) If an option is bound to an associative
  array, a string of the form "name=value" is expected as the next
  option, or right within the option separated with an "=" sign:

---------
double[string] tuningParms;
getopt(args, "tune", &tuningParms);
---------

  Invoking the program with e.g. "--tune=alpha=0.5 --tune beta=0.6" will
  set $(D tuningParms) to [ "alpha" : 0.5, "beta" : 0.6 ]. In general,
  keys and values can be of any parsable types.
  )

  $(LI $(I Delegate options.) An option can be bound to a delegate with
  the signature $(D void delegate()), $(D void delegate(string option))
  or $(D void delegate(string option, string value)).

  $(UL

    $(LI In the $(D void delegate()) case, the delegate is invoked
    whenever the option is seen.
    )

    $(LI In the $(D void delegate(string option)) case, the option string (without
    the leading dash(es)) is passed to the delegate. After that, the option string
    is considered handled and removed from the options array.

---------
void main(string[] args)
{
  uint verbosityLevel = 1;
  void myHandler(string option)
  {
    if (option == "quiet")
    {
      verbosityLevel = 0;
    }
    else
    {
      assert(option == "verbose");
      verbosityLevel = 2;
    }
  }
  getopt(args, "verbose", &myHandler, "quiet", &myHandler);
}
---------
    )

    $(LI In the $(D void delegate(string option, string value)) case, the
    option string is handled as an option with one argument, and parsed
    accordingly. The option and its value are passed to the
    delegate. After that, whatever was passed to the delegate is
    considered handled and removed from the list.

---------
void main(string[] args)
{
  uint verbosityLevel = 1;
  void myHandler(string option, string value)
  {
    switch (value)
    {
      case "quiet": verbosityLevel = 0; break;
      case "verbose": verbosityLevel = 2; break;
      case "shouting": verbosityLevel = verbosityLevel.max; break;
      default :
        stderr.writeln("Dunno how verbose you want me to be by saying ",
          value);
        exit(1);
    }
  }
  getopt(args, "verbosity", &myHandler);
}
---------
    )
  ))
)

$(B Options with multiple names)

Sometimes option synonyms are desirable, e.g. "--verbose",
"--loquacious", and "--garrulous" should have the same effect. Such
alternate option names can be included in the option specification,
using "|" as a separator:

---------
bool verbose;
getopt(args, "verbose|loquacious|garrulous", &verbose);
---------

$(B Case)

By default options are case-insensitive. You can change that behavior
by passing $(D getopt) the $(D caseSensitive) directive like this:

---------
bool foo, bar;
getopt(args,
    std.getopt.config.caseSensitive,
    "foo", &foo,
    "bar", &bar);
---------

In the example above, "--foo", "--bar", "--FOo", "--bAr" etc. are recognized.
The directive is active til the end of $(D getopt), or until the
converse directive $(D caseInsensitive) is encountered:

---------
bool foo, bar;
getopt(args,
    std.getopt.config.caseSensitive,
    "foo", &foo,
    std.getopt.config.caseInsensitive,
    "bar", &bar);
---------

The option "--Foo" is rejected due to $(D
std.getopt.config.caseSensitive), but not "--Bar", "--bAr"
etc. because the directive $(D
std.getopt.config.caseInsensitive) turned sensitivity off before
option "bar" was parsed.

$(B "Short" versus "long" options)

Single-letter options preceded by only one dash (e.g. $(D -t)) are accepted.
These options are called short options. If a double-dash is used a multi-letter
option must follow, e.g. $(D --timeout). This kind of option is called a long
option. A multi-letter option with a single dash (e.g. $(D -timeout)) will not
be accepted and a single-letter option with a double-dash (e.g. $(D --t)) will
not be accepted as well. If the option has a parameter, that option must be
passed with an intervening space or "=":

---------
uint timeout;
getopt(args, "timeout|t", &timeout);
---------

To set $(D timeout) to $(D 5), use either the long options $(D --timeout=5) or
$(D --timeout 5) or the short options $(D -t=5) or $(D -t 5). Also the short
option with no space $(D -t5) is accepted (see next section).

For $(D -timeout=5), $(D -timeout 5), and $(D -timeout5) an
$(LREF IllegalArgumentException) is thrown because the argument imeout=5,
imeout, and imeout5 respectively is not convertible to uint. For $(D --t=5),
$(D --t 5), $(D --t5), and $(D --timeout5) an
$(LREF UnrecognizedOptionException) is thrown.

Beware though that $(D -timeout=5), $(D -timeout 5), and $(D -timeout5)
would be accepted with values $(D imeout=5), $(D imeout), and $(D imeout5),
respectively, if -t was an option of type string. For more details about short
options with no space, refer also to the next section.

$(B Omitting spaces for short options)

By default omitting space/s for short options is enabled for all types, i.e. $(D
std.getopt.config.noSpaceForShortOptions) is set.

If you happen to have a short string option and a long string option starting
with the same letter like the short option, the behavior may be surprising.
Since whenever the value passed to a short option is convertible to its type
(via $(XREF conv, to)) the option will be accepted. This is e.g. the case for
strings as pointed out in the above section. As this behavior is usually
confusing, it can be enabled for numeric short options only using the
configuration option $(D std.getopt.config.noSpaceOnlyForShortNumericOptions).
Given

---------
string timeout;
getopt(args, std.getopt.config.noSpaceOnlyForShortNumericOptions,
             "timeout|t", &timeout);
---------

$(D -timeout=whatever), $(D -timeout whatever), and $(D -timeoutwhatever) will
throw an $(LREF UnrecognizedOptionException).

Specifying $(D std.getopt.config.noSpaceOnlyForShortNumericOptions) is strongly
recommended in cases like above.

$(B Bundling)

Single-letter options can be bundled together, i.e. "-abc" is the same as
$(D "-a -b -c"). By default, this confusing option is turned off. You can
turn it on with the $(D std.getopt.config.bundling) directive:

---------
bool foo, bar;
getopt(args,
    std.getopt.config.bundling,
    "foo|f", &foo,
    "bar|b", &bar);
---------

In case you want to only enable bundling for some of the parameters,
bundling can be turned off with $(D std.getopt.config.noBundling).

Note, when using bundling together with short options the unbundling happens
before the short options are handled. E.g.

---------
bool verbose;
string filename;

auto args = ["program.name",
             "-fzv"];
getopt(args, config.bundling,
             "f", &filename,
             "v", &verbose);
assert(verbose, to!string(verbose));
assert(filename == "-z", to!string(filename)); // due to unbundling
---------

But "-vf filename" works as expected.

$(B Passing unrecognized options through)

By default $(D std.getopt.config.noPassThrough) is set. In this setting a $(LREF
UnrecognizedOptionException) is thrown if any given option is not recognized.
E.g. if --bar is given, then

---------
bool foo;
getopt(args, "foo", &foo);
---------

will throw an $(LREF UnrecognizedOptionException).

If an application needs to do its own processing of whichever arguments
$(D getopt) did not understand, it can pass the
$(D std.getopt.config.passThrough) directive to $(D getopt).

---------
bool foo, bar;
getopt(args,
    std.getopt.config.passThrough,
    "foo", &foo,
    "bar", &bar);
---------

An unrecognized option such as "--baz" will be found untouched in
$(D args) after $(D getopt) returns.

$(B Options Terminator)

A lonesome double-dash terminates $(D getopt) gathering. It is used to
separate program options from other parameters (e.g. options to be passed
to another program). Invoking the example above with $(D "--foo -- --bar")
parses foo but leaves "--bar" in $(D args). The double-dash itself is
removed from the argument array.
*/

void getopt(T...)(ref string[] args, T opts) {
    enforce(args.length,
            "Invalid arguments string passed: program name missing");
    configuration cfg;
    return getoptImpl(args, cfg, opts);
}

/**
 * Configuration options for $(D getopt). You can pass them to $(D
 * getopt) in any position, except in between an option string and its
 * bound pointer.
 */

enum config {
    /// Turns case sensitivity on.
    caseSensitive,
    /// Turns case sensitivity off. Set by default.
    caseInsensitive,
    /// Turns short options with no space on for all types. Set by default.
    noSpaceForShortOptions,
    /// Turns short options with no space on for numeric types only.
    noSpaceOnlyForShortNumericOptions,
    /// Turns bundling on.
    bundling,
    /// Turns bundling off. Set by default.
    noBundling,
    /// Pass unrecognized arguments through.
    passThrough,
    /// Signal unrecognized arguments as errors. Set by default.
    noPassThrough,
    /// Stop at first argument that does not look like an option.
    stopOnFirstNonOption,
};

private void getoptImpl(T...)(ref string[] args,
    ref configuration cfg, T opts)
{
    static if (opts.length)
    {
        static if (is(typeof(opts[0]) : config))
        {
            // it's a configuration flag, act on it
            setConfig(cfg, opts[0]);
            return getoptImpl(args, cfg, opts[1 .. $]);
        }
        else
        {
            // it's an option string
            auto option = to!string(opts[0]);
            auto receiver = opts[1];
            bool incremental;
            // Handle options of the form --blah+
            if (option.length && option[$ - 1] == autoIncrementChar)
            {
                option = option[0 .. $ - 1];
                incremental = true;
            }
            handleOption(option, receiver, args, cfg, incremental);
            return getoptImpl(args, cfg, opts[2 .. $]);
        }
    }
    else
    {
        // no more options to look for, potentially some arguments left
        foreach (a ; args[1 .. $]) {
            if (!a.length || a[0] != optionChar)
            {
                // not an option
                if (cfg.stopOnFirstNonOption) break;
                continue;
            }
            if (endOfOptions.length && a == endOfOptions) break;
            enforce(cfg.passThrough,
                    new UnrecognizedOptionException("Unrecognized option " ~ a));
        }
    }
}

void handleOption(R)(string option, R receiver, ref string[] args,
        ref configuration cfg, bool incremental)
{
    static if (!isDelegate!(typeof(receiver)))
        alias typeof(*receiver) ReceiverType;
    else
        alias typeof(receiver) ReceiverType;

    // Scan arguments looking for a match for this option
    for (size_t i = 1; i < args.length; ) {
        auto a = args[i];
        if (endOfOptions.length && a == endOfOptions) break;
        if (cfg.stopOnFirstNonOption && (!a.length || a[0] != optionChar))
        {
            // first non-option is end of options
            break;
        }
        // Unbundle bundled arguments if necessary
        if (cfg.bundling && a.length > 2 && a[0] == optionChar &&
                a[1] != optionChar && a[2] != assignChar)
        {
            string[] expanded;
            foreach (dchar c; a[1 .. $])
            {
                expanded ~= text(optionChar, c);
            }
            args = args[0 .. i] ~ expanded ~ args[i + 1 .. $];
            continue;
        }
        string val;
        if (!isValidOption(a, option, val, cfg, isNumeric!(ReceiverType)))
        {
            ++i;
            continue;
        }
        // found it
        // from here on, commit to eat args[i]
        // (and potentially args[i + 1] too, but that comes later)
        args = args[0 .. i] ~ args[i + 1 .. $];

        static if (is(ReceiverType == bool))
        {
            // enforce that no value was given
            enforce(val is null,
                    new IllegalArgumentException(
                          format("Illegal argument '%s' for '%s'. Expected no argument.",
                                 val, a.length > 2 ? a : a ~ " " ~ val)));
            *receiver = true;
            break;
        }
        else
        {
            // non-boolean option, which might include an argument
            //enum isDelegateWithOneParameter = is(typeof(receiver("")) : void);
            enum isDelegateWithLessThanTwoParameters =
                isDelegate!(ReceiverType) && !is(typeof(receiver("", "")));
            if (!isDelegateWithLessThanTwoParameters && !val && !incremental) {
                // Eat the next argument too.  Check to make sure there's one
                // to be eaten first, though.
                enforce(i < args.length,
                        new MissingArgumentException("Missing argument for " ~ a));
                val = args[i];
                args = args[0 .. i] ~ args[i + 1 .. $];
            }

            try
            {
                static if (is(ReceiverType == enum))
                {
                    // enum receiver
                    *receiver = parse!(ReceiverType)(val);
                }
                else static if (is(ReceiverType : real))
                {
                    // numeric receiver
                    if (incremental) ++*receiver;
                    else *receiver = to!(ReceiverType)(val);
                }
                else static if (is(ReceiverType == string))
                {
                    // string receiver
                    *receiver = to!(ReceiverType)(val);
                }
                else static if (isDelegate!(ReceiverType))
                {
                    static if (is(typeof(receiver("", "")) : void))
                    {
                        // option with argument
                        receiver(option, val);
                    }
                    else static if (is(typeof(receiver("")) : void))
                    {
                        // boolean-style receiver
                        receiver(option);
                    }
                    else
                    {
                        static assert(is(typeof(receiver()) : void));
                        // boolean-style receiver without argument
                        receiver();
                    }
                }
                else static if (isArray!(ReceiverType))
                {
                    // array receiver
                    *receiver ~= [ to!(typeof(*receiver[0]))(val) ];
                }
                else static if (isAssociativeArray!(ReceiverType))
                {
                    // hash receiver
                    alias typeof(receiver.keys[0]) K;
                    alias typeof(receiver.values[0]) V;
                    auto j = std.string.indexOf(val, assignChar);
                    enforce(j > 0,
                            new IllegalArgumentException(
                                format("Illegal argument '%s' for '%s'. Expected %s.",
                                       val, a.length > 2 ? a : a ~ " " ~ val, humanReadable!(ReceiverType))));
                    auto key = val[0 .. j], value = val[j + 1 .. $];
                    (*receiver)[to!(K)(key)] = to!(V)(value);
                }
                else
                {
                    static assert(false, "Dunno how to deal with type " ~
                            ReceiverType.stringof);
                }
            }
            catch (Exception e) {
                if (cast(IllegalArgumentException) e ||
                    cast(MissingArgumentException) e)
                {
                    throw e;
                }
                else
                {
                    throw new IllegalArgumentException(
                        format("Illegal argument '%s' for '%s'. Expected %s.",
                               val, a.length > 2 ? a : a ~ " " ~ val, humanReadable!(ReceiverType)), e);
                }
            }
        }
    }
}

/**
   The option character. Defaults to '-' but it can be assigned to
   prior to calling $(D getopt).
 */
dchar optionChar = '-';

/**
   The string that conventionally marks the end of all
   options. Defaults to "--" but can be assigned to prior to calling
   $(D getopt). Assigning an empty string to $(D endOfOptions)
   effectively disables it.
 */
string endOfOptions = "--";

/**
   The assignment character used in options with parameters. Defaults
   to '=' but can be assigned to prior to calling $(D getopt).
 */
dchar assignChar = '=';

enum autoIncrementChar = '+';

/**
   This exception is thrown if an option is not recognized.
 */
class UnrecognizedOptionException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null )
    {
        super(msg, file, line, next);
    }
}

/**
   This exception is thrown if the argument given to an option is illegal. There
   may be other exceptions chained to this one, accessible via Throwable's
   member $(D next).
 */
class IllegalArgumentException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }

    this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, next);
    }
}

/**
   This exception is thrown if there was no argument given to an option.
 */
class MissingArgumentException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
    {
        super(msg, file, line, next);
    }
}

// Return a string representation for given type.
private string humanReadable(T)()
{
    static if (isIntegral!(T))
    {
        return format("integer in [%s, ..., %s]", T.min, T.max);
    }
    else static if (isFloatingPoint!(T))
    {
        return format("floating point number in [%s, ..., %s]", T.min, T.max);
    }
    else static if (is(T == enum))
    {
        return "value in " ~ to!string(map!(to!string)([EnumMembers!T]));
    }
    else static if (isSomeString!(T))
    {
        return "string";
    }
    else static if (isArray!(T))
    {
        return humanReadable!(typeof(T[0]));
    }
    else static if (isAssociativeArray!(T))
    {
        return format("<%s>=<%s>", humanReadable!(typeof(T.keys[0])), humanReadable!(typeof(T.values[0])));
    }
    else static if (isDelegate!(T))
    {
        assert(false); // for delegates there is no exception thrown
    }
    else
    {
        static assert(false, "Dunno how to deal with type " ~ T.stringof);
    }
}


private struct configuration
{
    mixin(bitfields!(
                bool, "caseSensitive",  1,
                bool, "bundling", 1,
                bool, "noSpaceForShortNumericOptionsOnly", 1,
                bool, "passThrough", 1,
                bool, "stopOnFirstNonOption", 1,
                ubyte, "", 3));
}

// Returns true, if arg is considered a valid argument for given option and sets
// value appropriately. Otherwise returns false.
private bool isValidOption(string arg, string optPattern, ref string value,
    configuration cfg, bool isNumericOption)
{
    //import std.stdio;
    //debug writeln("isValidOption:\n  ", arg, "\n  ", optPattern, "\n  ", value);
    //debug scope(success) writeln("isValidOption result: ", value);
    if (arg.length <= 1 || arg[0] != optionChar) return false;
    // yank the leading '-'
    arg = arg[1 .. $];
    // long options have two '--' and at least two additional chars
    immutable isLong = arg.length >= 3 && arg[0] == optionChar;
    //debug writeln("isLong: ", isLong);
    // yank the second '-' if present
    if (isLong) arg = arg[1 .. $];

    // --l= is invalid for long options
    if (isLong && arg[1] == assignChar) return false;

    //debug writeln("isNumericOption: ", isNumericOption);
    //debug writeln("cfg.noSpaceForShortNumericOptionsOnly: ", cfg.noSpaceForShortNumericOptionsOnly);

    immutable eqPos = std.string.indexOf(arg, assignChar);
    //debug writeln("eqPos: ", eqPos);
    if (eqPos >= 1)
    {
        // argument looks like --opt=value or -okey=value
        if (!isLong && eqPos != 1)
        {
            value = arg[1 .. $];
            arg = arg[0 .. 1];

            // reject if non-numeric option and numeric-only is configured
            if (!isNumericOption && cfg.noSpaceForShortNumericOptionsOnly) return false;
        }
        else
        {
            value = arg[eqPos + 1 .. $];
            arg = arg[0 .. eqPos];
        }
    }
    else
    {
        if (!isLong && !cfg.bundling)
        {
            // argument looks like -ovalue and there's no bundling
            value = arg[1 .. $];
            arg = arg[0 .. 1];
            // short option with space in between
            if (value.length == 0) value = null;
            // reject if non-numeric option and numeric-only is configured
            if (value.length > 0 && !isNumericOption && cfg.noSpaceForShortNumericOptionsOnly) return false;
        }
        else
        {
            // argument looks like --opt, or -oxyz with bundling
            value = null;
        }
    }
    //debug writeln("Arg: ", arg, " pattern: ", optPattern, " value: ", value);
    // Split the option
    const variants = split(optPattern, "|");
    foreach (v ; variants)
    {
        //debug writeln("Trying variant: ", v, " against ", arg);
        if (arg == v || !cfg.caseSensitive && toUpper(arg) == toUpper(v))
            return true;
        if (cfg.bundling && !isLong && v.length == 1
                && std.string.indexOf(arg, v) >= 0)
        {
            //debug writeln("success");
            return true;
        }
    }
    return false;
}

private void setConfig(ref configuration cfg, config option)
{
    switch (option)
    {
    case config.caseSensitive: cfg.caseSensitive = true; break;
    case config.caseInsensitive: cfg.caseSensitive = false; break;
    case config.noSpaceForShortOptions:
        cfg.noSpaceForShortNumericOptionsOnly = false; break;
    case config.noSpaceOnlyForShortNumericOptions:
        cfg.noSpaceForShortNumericOptionsOnly = true; break;
    case config.bundling: cfg.bundling = true; break;
    case config.noBundling: cfg.bundling = false; break;
    case config.passThrough: cfg.passThrough = true; break;
    case config.noPassThrough: cfg.passThrough = false; break;
    case config.stopOnFirstNonOption:
        cfg.stopOnFirstNonOption = true; break;
    default: assert(false);
    }
}

unittest {
    bool isEqual(T)(const(T) a, const(T) b) pure nothrow
    {
        static if (isFloatingPoint!(T)) {
            return (std.math.isNaN(a) && std.math.isNaN(b)) || std.math.isIdentical(a, b);
        }
        else {
            return a == b;
        }
    }

    enum Timeout {
        no,
        yes,
    }

    import std.typetuple;
    foreach (value; TypeTuple!(
                               true, // Boolean
                               cast(short) 1, cast(ushort) 1, 1, 1u, 1L, 1uL, // integral
                               1f, 1.0, cast(real) 1.0, .1, .1f, // floating point
                               Timeout.yes, // enum
                               "never", // strings TODO wstring,dstring
                               [ 1 ], // arrays
                               [ "string" : 1.0 ], // associative arrays
                              ))
    {
        alias Unqual!(typeof(value)) T;
        T timeout;
        static if (isAssociativeArray!(T))
        {
            auto timeoutAsString = value.keys[0] ~ "=" ~ to!string(value.values[0]);
        }
        else static if (isArray!(T) && !isSomeString!(T))
        {
            auto timeoutAsString = to!string(value[0]);
        }
        else static if (is(T == bool))
        {
            auto timeoutAsString = "";
        }
        else
        {
            auto timeoutAsString = to!string(value);
        }

        debug scope(failure) writeln("unittest@", __FILE__, ":", __LINE__, " fails for type ", T.stringof);

        // accepted short options
        string[] args = (["program.name",
                          "-t="~timeoutAsString]).dup;
        static if (is(T == bool))
        {
            assertThrown!Exception(getopt(args, "t|timeout", &timeout));
            assert(isEqual(timeout, timeout.init), to!string(timeout));
        }
        else
        {
            getopt(args, "t|timeout", &timeout);
            assert(isEqual(timeout, value), to!string(timeout));
        }

        timeout = timeout.init;
        args = (["program.name",
                 "-t"~timeoutAsString]).dup;
        getopt(args, "t|timeout", &timeout);
        assert(isEqual(timeout, value), to!string(timeout));

        timeout = timeout.init;
        args = (["program.name",
                 "-t", timeoutAsString]).dup;
        getopt(args, "t|timeout", &timeout);
        assert(isEqual(timeout, value), to!string(timeout));

        // mostly non-accepted short options
        timeout = timeout.init;
        args = (["program.name",
                 "-timeout="~timeoutAsString]).dup;
        static if (isSomeString!(T))
        {
            getopt(args, "t|timeout", &timeout);
            assert(isEqual(timeout, "imeout=never"), to!string(timeout));
        }
        else static if (isAssociativeArray!(T))
        {
            assertThrown!Exception(getopt(args, "t|timeout", &timeout));
            assert(isEqual(timeout, [ "imeout" : 0.0 ]), to!string(timeout));
        }
        else
        {
            assertThrown!Exception(getopt(args, "t|timeout", &timeout));
            assert(isEqual(timeout, timeout.init), to!string(timeout));
        }

        timeout = timeout.init;
        args = (["program.name",
                 "-timeout", timeoutAsString]).dup;
        static if (isSomeString!(T))
        {
            getopt(args, "t|timeout", &timeout);
            assert(isEqual(timeout, "imeout"), to!string(timeout));
        }
        else
        {
            assertThrown!Exception(getopt(args, "t|timeout", &timeout));
            assert(isEqual(timeout, timeout.init), to!string(timeout));
        }

        timeout = timeout.init;
        args = (["program.name",
                 "-timeout"~timeoutAsString]).dup;
        static if (isSomeString!(T))
        {
            getopt(args, "t|timeout", &timeout);
            assert(isEqual(timeout, "imeoutnever"), to!string(timeout));
        }
        else static if (isAssociativeArray!(T))
        {
            getopt(args, "t|timeout", &timeout);
            assert(isEqual(timeout, [ "imeoutstring" : 1.0 ]), to!string(timeout));
        }
        else
        {
            assertThrown!Exception(getopt(args, "t|timeout", &timeout));
            assert(isEqual(timeout, timeout.init), to!string(timeout));
        }

        // accepted long options
        timeout = timeout.init;
        args = (["program.name",
                 "--timeout", timeoutAsString]).dup;
        getopt(args, "t|timeout", &timeout);
        assert(isEqual(timeout, value), to!string(timeout));

        timeout = timeout.init;
        args = (["program.name",
                 "--timeout="~timeoutAsString]).dup;
        static if (is(T == bool))
        {
            assertThrown!Exception(getopt(args, "t|timeout", &timeout));
            assert(isEqual(timeout, timeout.init), to!string(timeout));
        }
        else
        {
            getopt(args, "t|timeout", &timeout);
            assert(isEqual(timeout, value), to!string(timeout));
        }

        // non-accepted long options
        timeout = timeout.init;
        args = (["program.name",
                 "--t", timeoutAsString]).dup;
        assertThrown!Exception(getopt(args, "t|timeout", &timeout));
        assert(isEqual(timeout, timeout.init), to!string(timeout));

        timeout = timeout.init;
        args = (["program.name",
                 "--t="~timeoutAsString]).dup;
        assertThrown!Exception(getopt(args, "t|timeout", &timeout));
        assert(isEqual(timeout, timeout.init), to!string(timeout));

        timeout = timeout.init;
        args = (["program.name",
                 "--timeout"~timeoutAsString]).dup;
        static if (is(T == bool))
        {
            getopt(args, "t|timeout", &timeout);
            assert(isEqual(timeout, value), to!string(timeout));
        }
        else
        {
            assertThrown!Exception(getopt(args, "t|timeout", &timeout));
            assert(isEqual(timeout, timeout.init), to!string(timeout));
        }

        timeout = timeout.init;
        args = (["program.name",
                 "--t"~timeoutAsString]).dup;
        assertThrown!Exception(getopt(args, "t|timeout", &timeout));
        assert(isEqual(timeout, timeout.init), to!string(timeout));
    }
}

// with no space only for short numeric options, i.e. config.noSpaceOnlyForShortNumericOptions
unittest
{
    bool isEqual(T)(const(T) a, const(T) b) pure nothrow
    {
        static if (isFloatingPoint!(T)) {
            return (std.math.isNaN(a) && std.math.isNaN(b)) || std.math.isIdentical(a, b);
        }
        else {
            return a == b;
        }
    }

    enum Timeout {
        no,
        yes,
    }

    import std.typetuple;
    foreach (value; TypeTuple!(
                               true, // Boolean
                               cast(short) 1, cast(ushort) 1, 1, 1u, 1L, 1uL, // integral
                               1f, 1.0, cast(real) 1.0, .1, 1f, .1f, // floating point
                               Timeout.yes, // enum
                               "never", "imeout", // strings TODO wstring,dstring
                               [ 1 ], [ "1" ], // arrays
                               [ "string" : 1.0 ], [ "imeout" : 1], // associative arrays
                              ))
    {
        alias Unqual!(typeof(value)) T;
        T timeout;
        static if (isAssociativeArray!(T))
        {
            auto timeoutAsString = value.keys[0] ~ "=" ~ to!string(value.values[0]);
        }
        else static if (isArray!(T) && !isSomeString!(T))
        {
            auto timeoutAsString = to!string(value[0]);
        }
        else static if (is(T == bool))
        {
            auto timeoutAsString = "";
        }
        else
        {
            auto timeoutAsString = to!string(value);
        }

        debug scope(failure) writeln("unittest@", __FILE__, ":", __LINE__, " fails for type ", T.stringof);

        // accepted short options
        string[] args = (["program.name",
                          "-t="~timeoutAsString]).dup;
        static if (is(T == bool))
        {
            assertThrown!IllegalArgumentException(getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout));
            assert(isEqual(timeout, timeout.init), to!string(timeout));
        }
        else
        {
            getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout);
            assert(isEqual(timeout, value), to!string(timeout));
        }

        timeout = timeout.init;
        args = (["program.name",
                 "-t"~timeoutAsString]).dup;
        static if (isNumeric!(T) || is(T == bool))
        {
            getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout);
            assert(isEqual(timeout, value), to!string(timeout));
        }
        else
        {
            assertThrown!UnrecognizedOptionException(getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout));
            assert(isEqual(timeout, timeout.init), to!string(timeout));
        }

        timeout = timeout.init;
        args = (["program.name",
                 "-t", timeoutAsString]).dup;
        getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout);
        assert(isEqual(timeout, value), to!string(timeout));

        // mostly non-accepted short options
        timeout = timeout.init;
        args = (["program.name",
                 "-timeout="~timeoutAsString]).dup;
        assertThrown!Exception(getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout));
        assert(isEqual(timeout, timeout.init), to!string(timeout));

        timeout = timeout.init;
        args = (["program.name",
                 "-timeout", timeoutAsString]).dup;
        assertThrown!Exception(getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout));
        assert(isEqual(timeout, timeout.init), to!string(timeout));

        timeout = timeout.init;
        args = (["program.name",
                 "-timeout"~timeoutAsString]).dup;
        assertThrown!Exception(getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout));
        assert(isEqual(timeout, timeout.init), to!string(timeout));

        // accepted long options
        timeout = timeout.init;
        args = (["program.name",
                 "--timeout", timeoutAsString]).dup;
        getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout);
        assert(isEqual(timeout, value), to!string(timeout));

        timeout = timeout.init;
        args = (["program.name",
                 "--timeout="~timeoutAsString]).dup;
        static if (is(T == bool))
        {
            assertThrown!IllegalArgumentException(getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout));
            assert(isEqual(timeout, timeout.init), to!string(timeout));
        }
        else
        {
            getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout);
            assert(isEqual(timeout, value), to!string(timeout));
        }

        // non-accepted long options
        timeout = timeout.init;
        args = (["program.name",
                 "--t", timeoutAsString]).dup;
        assertThrown!UnrecognizedOptionException(getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout));
        assert(isEqual(timeout, timeout.init), to!string(timeout));

        timeout = timeout.init;
        args = (["program.name",
                 "--t="~timeoutAsString]).dup;
        assertThrown!UnrecognizedOptionException(getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout));
        assert(isEqual(timeout, timeout.init), to!string(timeout));

        timeout = timeout.init;
        args = (["program.name",
                 "--timeout"~timeoutAsString]).dup;
        static if (is(T == bool))
        {
            getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout);
            assert(isEqual(timeout, value), to!string(timeout));
        }
        else
        {
            assertThrown!UnrecognizedOptionException(getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout));
            assert(isEqual(timeout, timeout.init), to!string(timeout));
        }

        timeout = timeout.init;
        args = (["program.name",
                 "--t"~timeoutAsString]).dup;
        assertThrown!Exception(getopt(args, config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeout));
        assert(isEqual(timeout, timeout.init), to!string(timeout));
    }
}

unittest
{
    bool verbose;
    string filename;

    auto args = ["program.name",
                 "-fzv"];
    getopt(args, config.bundling,
                 "f", &filename,
                 "v", &verbose);
    assert(verbose, to!string(verbose));
    assert(filename == "-z", to!string(filename)); // due to unbundling

    verbose = verbose.init;
    filename = filename.init;
    args = ["program.name",
            "-vf", "filename"].dup;
    getopt(args, config.bundling,
                 "f", &filename,
                 "v", &verbose);
    assert(verbose, to!string(verbose));
    assert(filename == "filename", to!string(filename));

    verbose = verbose.init;
    filename = filename.init;
    args = ["program.name",
            "-fvz", "filename"].dup;
    assertThrown!Exception(getopt(args, config.bundling,
                                        "f", &filename,
                                        "v", &verbose));
    assert(!verbose, to!string(verbose));
    assert(filename == "-v", to!string(filename));

    string str;
    args = ["program.name",
            "--a=-0x12"].dup;
    assertThrown!Exception(getopt(args, config.bundling,
                                        "a|addr", &str));
    assert(str == "", to!string(str));

    str = str.init;
    args = ["program.name",
            "-a=-0x12"].dup;
    getopt(args, config.bundling,
                 "a|addr", &str);
    assert(str == "-0x12", to!string(str));

    str = str.init;
    args = ["program.name",
            "-a=-0x12"].dup;
    getopt(args, "a|addr", &str);
    assert(str == "-0x12", to!string(str));
}

// unrecognized options
unittest
{
    string singleDash;
    auto args = ["program.name",
                 "-"];
    auto ex = collectException!(UnrecognizedOptionException)(getopt(args, "u", &singleDash));
    assert(ex !is null);
    assert(ex.msg == "Unrecognized option -", ex.msg);

    bool foo;
    args = ["program.name",
            "--bar"].dup;
    ex = collectException!(UnrecognizedOptionException)(getopt(args, "foo", &foo));
    assert(ex !is null);
    assert(ex.msg == "Unrecognized option --bar", ex.msg);

    int timeout;
    args = ["program.name",
            "-a"];
    ex = collectException!(UnrecognizedOptionException)(getopt(args, "t|timeout", &timeout));
    assert(ex !is null);
    assert(ex.msg == "Unrecognized option -a", ex.msg);

    string timeoutString;
    args = ["program.name",
            "-tstring"].dup;
    ex = collectException!(UnrecognizedOptionException)(getopt(args,
           config.noSpaceOnlyForShortNumericOptions, "t|timeout", &timeoutString));
    assert(ex !is null);
    assert(ex.msg == "Unrecognized option -tstring", ex.msg);
}

// illegal arguments
unittest
{
    // bool
    bool verbose;
    auto args = ["program.name",
                 "-vstring"];
    auto ex = collectException!(IllegalArgumentException)(getopt(args, "v", &verbose));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'string' for '-vstring'. Expected no argument.", ex.msg);

    // integer
    int timeout;
    args = ["program.name",
            "-t", "string"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &timeout));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'string' for '-t string'. Expected integer in [-2147483648, ..., 2147483647].", ex.msg);
    assert(ex.next);
    assert(cast(ConvException) ex.next);

    short timeout2;
    args = ["program.name",
            "-t", "string"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &timeout2));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'string' for '-t string'. Expected integer in [-32768, ..., 32767].", ex.msg);
    assert(ex.next);
    assert(cast(ConvException) ex.next);

    // floating point
    float floatValue;
    args = ["program.name",
            "-t", "string"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &floatValue));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'string' for '-t string'. Expected floating point number in [1.17549e-38, ..., 3.40282e+38].", ex.msg);
    assert(ex.next);
    assert(cast(ConvException) ex.next);

    // enum
    enum Color { no, yes };
    Color color;
    args = ["program.name",
            "-t", "0"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &color));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument '0' for '-t 0'. Expected value in [no, yes].", ex.msg);

    assert(ex.next);
    assert(cast(ConvException) ex.next);

    // array
    ubyte[] values;
    args = ["program.name",
            "-t", "string"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &values));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'string' for '-t string'. Expected integer in [0, ..., 255].", ex.msg);
    assert(ex.next);
    assert(cast(ConvException) ex.next);

    // associative array
    int[string] hash;
    args = ["program.name",
            "-t", "foo=bar"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &hash));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'foo=bar' for '-t foo=bar'. Expected <string>=<integer in [-2147483648, ..., 2147483647]>.", ex.msg);
    assert(ex.next);
    assert(cast(ConvException) ex.next);

    hash = hash.init;
    args = ["program.name",
            "-tfoo=bar"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &hash));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'foo=bar' for '-tfoo=bar'. Expected <string>=<integer in [-2147483648, ..., 2147483647]>.", ex.msg);
    assert(ex.next);
    assert(cast(ConvException) ex.next);

    hash = hash.init;
    args = ["program.name",
            "-t=foo=bar"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &hash));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'foo=bar' for '-t=foo=bar'. Expected <string>=<integer in [-2147483648, ..., 2147483647]>.", ex.msg);
    assert(ex.next);
    assert(cast(ConvException) ex.next);

    hash = hash.init;
    args = ["program.name",
            "-t", "foo"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &hash));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'foo' for '-t foo'. Expected <string>=<integer in [-2147483648, ..., 2147483647]>.", ex.msg);
    assert(!ex.next);

    hash = hash.init;
    args = ["program.name",
            "-t=foo"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &hash));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'foo' for '-t=foo'. Expected <string>=<integer in [-2147483648, ..., 2147483647]>.", ex.msg);
    assert(!ex.next);

    hash = hash.init;
    args = ["program.name",
            "-tfoo"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &hash));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'foo' for '-tfoo'. Expected <string>=<integer in [-2147483648, ..., 2147483647]>.", ex.msg);
    assert(!ex.next);

    string[int] hash2;
    args = ["program.name",
            "-t", "foo=bar"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "t|timeout", &hash2));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'foo=bar' for '-t foo=bar'. Expected <integer in [-2147483648, ..., 2147483647]>=<string>.", ex.msg);
    assert(ex.next);
    assert(cast(ConvException) ex.next);
}

unittest
{
    // missing argument
    int timeout;
    auto args = ["program.name",
                 "-t"];
    auto ex = collectException!(MissingArgumentException)(getopt(args, "t|timeout", &timeout));
    assert(ex !is null);
    assert(ex.msg == "Missing argument for -t", ex.msg);
}

unittest
{
    int timeout;
    string color;
    auto args = ["program.name",
                 "-t", "red", "-c", "red"];
    auto ex = collectException!(IllegalArgumentException)(getopt(args, "t", &timeout, "c", &color));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument 'red' for '-t red'. Expected integer in [-2147483648, ..., 2147483647].", ex.msg);

    ubyte overflow;
    args = ["program.name",
            "-u", "256"].dup;
    ex = collectException!(IllegalArgumentException)(getopt(args, "u", &overflow));
    assert(ex !is null);
    assert(ex.msg == "Illegal argument '256' for '-u 256'. Expected integer in [0, ..., 255].", ex.msg);

    assert(ex.next);
    assert(cast(ConvOverflowException) ex.next);
}

unittest
{
    bool verbose;
    auto args = ["program.name",
                 "--", "-v"]; // stop processing at --
    getopt(args, "v", &verbose);
    assert(verbose == verbose.init, to!string(verbose));
}

unittest
{
    uint paranoid = 2;
    string[] args = (["program.name",
                      "--paranoid", "--paranoid", "--paranoid"]).dup;
    getopt(args, "paranoid+", &paranoid);
    assert(paranoid == 5, to!(string)(paranoid));

    enum Color { no, yes };
    Color color;
    args = (["program.name", "--color=yes",]).dup;
    getopt(args, "color", &color);
    assert(color, to!(string)(color));

    color = Color.no;
    args = (["program.name", "--color", "yes",]).dup;
    getopt(args, "color", &color);
    assert(color, to!(string)(color));

    string data = "file.dat";
    int length = 24;
    bool verbose = false;
    args = (["program.name", "--length=5",
                      "--file", "dat.file", "--verbose"]).dup;
    getopt(
        args,
        "length",  &length,
        "file",    &data,
        "verbose", &verbose);
    assert(args.length == 1);
    assert(data == "dat.file");
    assert(length == 5);
    assert(verbose);

    //
    string[] outputFiles;
    args = (["program.name", "--output=myfile.txt",
             "--output", "yourfile.txt"]).dup;
    getopt(args, "output", &outputFiles);
    assert(outputFiles.length == 2
           && outputFiles[0] == "myfile.txt" && outputFiles[0] == "myfile.txt");

    args = (["program.name", "--tune=alpha=0.5",
             "--tune", "beta=0.6"]).dup;
    double[string] tuningParms;
    getopt(args, "tune", &tuningParms);
    assert(args.length == 1);
    assert(tuningParms.length == 2);
    assert(tuningParms["alpha"] == 0.5);
    assert(tuningParms["beta"] == 0.6);

    uint verbosityLevel = 1;
    void myHandler(string option)
    {
        if (option == "quiet")
        {
            verbosityLevel = 0;
        }
        else
        {
            assert(option == "verbose");
            verbosityLevel = 2;
        }
    }
    args = (["program.name", "--quiet"]).dup;
    getopt(args, "verbose", &myHandler, "quiet", &myHandler);
    assert(verbosityLevel == 0);
    args = (["program.name", "--verbose"]).dup;
    getopt(args, "verbose", &myHandler, "quiet", &myHandler);
    assert(verbosityLevel == 2);

    verbosityLevel = 1;
    void myHandler2(string option, string value)
    {
        assert(option == "verbose");
        verbosityLevel = 2;
    }
    args = (["program.name", "--verbose", "2"]).dup;
    getopt(args, "verbose", &myHandler2);
    assert(verbosityLevel == 2);

    verbosityLevel = 1;
    void myHandler3()
    {
        verbosityLevel = 2;
    }
    args = (["program.name", "--verbose"]).dup;
    getopt(args, "verbose", &myHandler3);
    assert(verbosityLevel == 2);

    bool foo, bar;
    args = (["program.name", "--foo", "--bAr"]).dup;
    getopt(args,
        std.getopt.config.caseSensitive,
        std.getopt.config.passThrough,
        "foo", &foo,
        "bar", &bar);
    assert(args[1] == "--bAr");

    // test stopOnFirstNonOption

    args = (["program.name", "--foo", "nonoption", "--bar"]).dup;
    foo = bar = false;
    getopt(args,
        std.getopt.config.stopOnFirstNonOption,
        "foo", &foo,
        "bar", &bar);
    assert(foo && !bar && args[1] == "nonoption" && args[2] == "--bar");

    args = (["program.name", "--foo", "nonoption", "--zab"]).dup;
    foo = bar = false;
    getopt(args,
        std.getopt.config.stopOnFirstNonOption,
        "foo", &foo,
        "bar", &bar);
    assert(foo && !bar && args[1] == "nonoption" && args[2] == "--zab");
}

unittest
{
    // From bugzilla 2142
    bool f_linenum, f_filename;
    string[] args = [ "", "-nl" ];
    getopt
        (
            args,
            std.getopt.config.bundling,
            //std.getopt.config.caseSensitive,
            "linenum|l", &f_linenum,
            "filename|n", &f_filename
        );
    assert(f_linenum);
    assert(f_filename);
}
