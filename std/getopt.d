// Written in the D programming language.

/**
Processing of command line options.
   
The getopt module implements a $(D getopt) function, which adheres to
the POSIX syntax for command line options. GNU extensions are
supported in the form of long options introduced by a double dash
("--"). Support for bundling of command line options, as was the case
with the more traditional single-letter approach, is provided but not
enabled by default.
   
Macros:

WIKI = Phobos/StdGetopt

Copyright: Copyright Andrei Alexandrescu 2008 - 2009.
License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
Authors:   $(WEB erdani.org, Andrei Alexandrescu)
Credits:   This module and its documentation are inspired by Perl's $(WEB
                   perldoc.perl.org/Getopt/Long.html, Getopt::Long) module. The syntax of
                   D's $(D getopt) is simpler than its Perl counterpart because $(D
                   getopt) infers the expected parameter types from the static types of
                   the passed-in pointers.

         Copyright Andrei Alexandrescu 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.getopt;

private import std.string, std.conv, std.traits, std.contracts, std.bitmanip,
    std.algorithm, std.ctype;

//version (unittest)
//{
    import std.stdio; // for testing only
//}

/**
 Synopsis:

---------
import std.getopt;

string data = "file.dat";
int length = 24;
bool verbose;

void main(string[] args)
{
  getopt(
    args,
    "length",  &length,    // numeric
    "file",    &data,      // string
    "verbose", &verbose);  // flag
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
 to their defaults and then invoke $(D getopt). If a
 command-line argument is recognized as an option with a parameter and
 the parameter cannot be parsed properly (e.g. a number is expected
 but not present), a $(D ConvError) exception is thrown.

 Depending on the type of the pointer being bound, $(D getopt)
 recognizes the following kinds of options:

 $(OL $(LI $(I Boolean options). These are the simplest options; all
 they do is set a Boolean to $(D true):

---------
  bool verbose, debugging;
  getopt(args, "verbose", &verbose, "debug", &debugging);
---------

 $(LI $(I Numeric options.) If an option is bound to a numeric type, a
 number is expected as the next option, or right within the option
 separated with an "=" sign:
 
---------
  uint timeout;
  getopt(args, "timeout", &timeout);
---------

 Invoking the program with "--timeout=5" or "--timeout 5" will set
 $(D timeout) to 5.)
 
 $(UL $(LI $(I Incremental options.) If an option name has a "+" suffix and
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
 as part of the program options.))
 
 $(LI $(I String options.) If an option is bound to a string, a string
 is expected as the next option, or right within the option separated
 with an "=" sign:
 
---------
string outputFile;
getopt(args, "output", &outputFile);
---------

 Invoking the program with "--output=myfile.txt" or "--output
 myfile.txt" will set $(D outputFile) to "myfile.txt".) If you want to
 pass a string containing spaces, you need to use the quoting that is
 appropriate to your shell, e.g. --output='my file.txt'. 
 
 $(LI $(I Array options.) If an option is bound to an array, a new
 element is appended to the array each time the option occurs:
 
---------
string[] outputFiles;
getopt(args, "output", &outputFiles);
---------

 Invoking the program with "--output=myfile.txt --output=yourfile.txt"
 or "--output myfile.txt --output yourfile.txt" will set $(D
 outputFiles) to [ "myfile.txt", "yourfile.txt" ] .)
 
 $(LI $(I Hash options.) If an option is bound to an associative
 array, a string of the form "name=value" is expected as the next
 option, or right within the option separated with an "=" sign:
 
---------
double[string] tuningParms;
getopt(args, "tune", &tuningParms);
---------

Invoking the program with e.g. "--tune=alpha=0.5 --tune beta=0.6" will
set $(D tuningParms) to [ "alpha" : 0.5, "beta" : 0.6 ].)  In general,
keys and values can be of any parsable types.
 
$(LI $(I Delegate options.) An option can be bound to a delegate with
the signature $(D void delegate()), $(D void delegate(string option))
or $(D void delegate(string option, string value)).

$(UL $(LI In the $(D void delegate()) case, the delegate is invoked
whenever the option is seen.) $(LI In the $(D void delegate(string
option)) case, the option string (without the leading dash(es)) is
passed to the delegate. After that, the option string is considered
handled and removed from the options array.)
 
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

$(LI In the $(D void delegate(string option, string value)) case, the
option string is handled as an option with one argument, and parsed
accordingly. The option and its value are passed to the
delegate. After that, whatever was passed to the delegate is
considered handled and removed from the list.)
 
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
))))

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

$(B Bundling)

Single-letter options can be bundled together, i.e. "-abc" is the same as "-a -b -c". By default, this confusing option is turned off. You can turn it on with the $(D std.getopt.config.bundling) directive:

---------
bool foo, bar;
getopt(args,
    std.getopt.config.bundling,
    "foo|f", &foo,
    "bar|b", &bar);
---------

In case you want to only enable bundling for some of the parameters, bundling can be turned off with $(D std.getopt.config.noBundling).

$(B Passing unrecognized options through)

If an application needs to do its own processing of whichever arguments $(D getopt) did not understand, it can pass the $(D std.getopt.config.passThrough) directive to $(D getopt):

---------
bool foo, bar;
getopt(args,
    std.getopt.config.passThrough,
    "foo", &foo,
    "bar", &bar);
---------

An unrecognized option such as "--baz" will be found untouched in $(D args) after $(D getopt) returns.

$(B Options Terminator)

A lonesome double-dash terminates $(D getopt) gathering. It is used to separate program options from other parameters (e.g. options to be passed to another program). Invoking the example above with "--foo -- --bar" parses foo but leaves "--bar" in $(D args). The double-dash itself is removed from the argument array.
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
    /// Turns case sensitivity on
    caseSensitive,
    /// Turns case sensitivity off
    caseInsensitive,
    /// Turns bundling on
    bundling,
    /// Turns bundling off
    noBundling,
    /// Pass unrecognized arguments through
    passThrough,
    /// Signal unrecognized arguments as errors
    noPassThrough,
    /// Stop at first argument that does not look like an option
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
            auto option = to!(string)(opts[0]);
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
            if (!cfg.passThrough)
            {
                throw new Exception("Unrecognized option "~a);
            }
        }
    }
}

void handleOption(R)(string option, R receiver, ref string[] args,
        ref configuration cfg, bool incremental)
{
    // Scan arguments looking for a match for this option
    for (size_t i = 1; i < args.length; ) {
        auto a = args[i];
        if (endOfOptions.length && a == endOfOptions) break;
        if (cfg.stopOnFirstNonOption && (!a.length || a[0] != optionChar))
        {
            // first non-option is end of options
            break;
        }
        string val;
        if (!optMatch(a, option, val, cfg))
        {
            ++i;
            continue;
        }
        // found it; from here on, commit to eat args[i]
        // (and potentially args[i + 1] too)
        args = args[0 .. i] ~ args[i + 1 .. $];
                
        static if (is(typeof(*receiver) == bool)) {
            *receiver = true;
            break;
        } else {
            // non-boolean option, which might include an argument
            //enum isDelegateWithOneParameter = is(typeof(receiver("")) : void);
            enum isDelegateWithLessThanTwoParameters =
                is(typeof(receiver) == delegate) &&
                !is(typeof(receiver("", "")));
            if (!isDelegateWithLessThanTwoParameters && !val && !incremental) {
                // eat the next argument too
                val = args[i];
                args = args[0 .. i] ~ args[i + 1 .. $];
            }
            static if (is(typeof(*receiver) : real))
            {
                // numeric receiver
                if (incremental) ++*receiver;
                else *receiver = to!(typeof(*receiver))(val);
            }
            else static if (is(typeof(*receiver) == string))
            {
                // string receiver
                *receiver = to!(typeof(*receiver))(val);
            }
            else static if (is(typeof(receiver) == delegate))
            {
                static if (is(typeof(receiver("", "")) : void)) 
                {
                    // option with argument
                    receiver(option, val);
                }
                else static if (is(typeof(receiver("")) : void)) 
                {
                    static assert(is(typeof(receiver("")) : void));
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
            else static if (isArray!(typeof(*receiver)))
            {
                // array receiver
                *receiver ~= [ to!(typeof(*receiver[0]))(val) ];
            }
            else static if (isAssociativeArray!(typeof(*receiver)))
            {
                // hash receiver
                alias typeof(receiver.keys[0]) K;
                alias typeof(receiver.values[0]) V;
                auto j = std.string.indexOf(val, assignChar);
                auto key = val[0 .. j], value = val[j + 1 .. $];
                (*receiver)[to!(K)(key)] = to!(V)(value);
            }
            else
            {
                static assert(false, "Dunno how to deal with type " ~
                        typeof(receiver).stringof);
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

private struct configuration
{
    mixin(bitfields!(
                bool, "caseSensitive",  1,
                bool, "bundling", 1,
                bool, "passThrough", 1,
                bool, "stopOnFirstNonOption", 1,
                ubyte, "", 4));
}

private bool optMatch(string arg, string optPattern, ref string value,
    configuration cfg)
{
    if (!arg.length || arg[0] != optionChar) return false;
    // yank the leading '-'
    arg = arg[1 .. $];
    immutable isLong = arg.length > 1 && arg[0] == optionChar;
    // yank the second '-' if present
    if (isLong) arg = arg[1 .. $];
    immutable eqPos = std.string.indexOf(arg, assignChar);
    if (eqPos >= 0)
    {
        // argument looks like --opt=value
        value = arg[eqPos + 1 .. $];
        arg = arg[0 .. eqPos];
    }
    else
    {
        if (!isLong && !cfg.bundling)
        {
            // argument looks like -ovalue and there's no bundling
            value = arg[1 .. $];
            arg = arg[0 .. 1];
        }
        else
        {
            // argument looks like --opt, or -oxyz with bundling
            value = null;
        }
    }
    //writeln("Arg: ", arg, " pattern: ", optPattern, " value: ", value);
    // Split the option
    const variants = split(optPattern, "|");
    foreach (v ; variants) {
        if (arg == v || !cfg.caseSensitive && toupper(arg) == toupper(v))
            return true;
        if (cfg.bundling && !isLong && v.length == 1
                && std.string.indexOf(arg, v) >= 0)
            return true;
    }
    return false;
}

private void setConfig(ref configuration cfg, config option)
{
    switch (option)
    {
    case config.caseSensitive: cfg.caseSensitive = true; break;
    case config.caseInsensitive: cfg.caseSensitive = false; break;
    case config.bundling: cfg.bundling = true; break;
    case config.noBundling: cfg.bundling = false; break;
    case config.passThrough: cfg.passThrough = true; break;
    case config.noPassThrough: cfg.passThrough = false; break;
    case config.stopOnFirstNonOption:
        cfg.stopOnFirstNonOption = true; break;
    default: assert(false);
    }
}

unittest
{
    uint paranoid = 2;
    string[] args = (["program.name",
                      "--paranoid", "--paranoid", "--paranoid"]).dup;
    getopt(args, "paranoid+", &paranoid);
    assert(paranoid == 5, to!(string)(paranoid));
    
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

