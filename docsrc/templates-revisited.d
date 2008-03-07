Ddoc

$(D_S Templates Revisited,

<center>
$(I by Walter Bright, $(LINK http://www.digitalmars.com/d))

<br>
<br>

$(BLOCKQUOTE 
"What I am going to tell you about is what we teach our programming students in
the third or fourth year of graduate school... It is my task to convince you not
to turn away because you don't understand it. You see my programming students
don't understand it... That is because I don't understand it. Nobody does."<br>
-- Richard Deeman
)
</center>

<h2>Abstract</h2>

$(P
Templates in C++ have evolved from little more than token substitution into a
programming language in itself. Many useful aspects of C++ templates have been
discovered rather than designed. A side effect of this is that C++ templates are
often criticized for having an awkward syntax, many arcane rules, and being very
difficult to implement properly. What might templates look like if one takes a
step back, looks at what templates can do and what uses they are put to, and
redesign them? Can templates be powerful, aesthetically pleasing, easy to
explain and straightforward to implement?
This article takes a look at an alternative design of templates in the D
Programming Language [1].
)

<h2>Similarities</h2>

$(UL
$(LI compile time semantics)
$(LI function templates)
$(LI class templates)
$(LI type parameters)
$(LI value parameters)
$(LI template parameters)
$(LI partial and explicit specialization)
$(LI type deduction)
$(LI implicit function template instantiation)
$(LI $(ACRONYM SFINAE, Substitution Failure Is Not An Error))
)


<h2>Argument Syntax</h2>

$(P
The first thing that comes to mind is the use of &lt; &gt; to enclose parameter
lists and argument lists. &lt; &gt; has a couple serious problem, however.
They are ambiguous with operators &lt;, &gt;, and &gt;&gt;. This means that expressions
like:
)

$(CCODE
a&lt;b,c&gt;d;
)

and:

$(CCODE
a&lt;b&lt;c&gt;&gt;d;
)

$(P
are syntactically ambiguous, both to the compiler and the programmer.
If you run across $(TT a&lt;b,c&gt;d;) in unfamiliar code, you've got to slog through
an arbitrarily large amount of declarations and $(TT .h) files to figure out
if it is a template or not.
How much effort has been expended by programmers, compiler writers, and
language standard writers to deal with this?
)
 
$(P
There's got to be a better way. D solves it by noticing that ! is not used
as a binary operator, so replacing:
)

$(CCODE
a&lt;b,c&gt;
)

$(P
with:
)

---
a!(b,c)
---

$(P
is syntactically unambiguous. This makes it easy to parse, easy to generate
reasonable error messages for, and makes it easy for someone inspecting the
code to determine that yes, $(TT a) must be a template.
)


<h2>Template Definition Syntax</h2>

$(P
C++ can define two broad types of templates: class templates, and function
templates. Each template is written independently, even if they are
closely related:
)

$(CCODE
template&lt;class T, class U&gt; class Bar { ... };

template&lt;class T, class U&gt; T foo(T t, U u) { ... }

template&lt;class T, class U&gt; static T abc;
)

$(P
POD (Plain Old Data, as in C style) structs
bring together related data declarations, classes bring together
related data and function declarations, but there's nothing to logically group
together templates that are to be instantiated together.
In D, we can write:
)

----
template Foo(T, U)
{
  class Bar { ... }

  T foo(T t, U u) { ... }

  T abc;

  typedef T* Footype;	// any declarations can be templated
}
----

$(P
The $(TT Foo) forms a name space for the templates, which are accessed by,
for example:
)

---
Foo!(int,char).Bar b;
Foo!(int,char).foo(1,2);
Foo!(int,char).abc = 3;
---

$(P
Of course, this can get a little tedious, so one can use an alias
for a particular instantiation:
)

---
alias Foo!(int,char) f;
f.Bar b;
f.foo(1,2);
f.abc = 3;
---

$(P
For class templates, there's an even simpler syntax. A class is defined
like:
)

---
class Abc
{
    int t;
    ...
}
---

$(P
This can be turned into a template by just adding a parameter list:
)

---
class Abc(T)
{
    T t;
    ...
}
---


<h2>Template Declaration, Definition, and Export</h2>

$(P
C++ templates can be in the form of a template declaration, a template
definition, and an exported template.
Because D has a true module system, rather than textual #include files,
there are only template definitions in D. The need for template declarations
and export is irrelevant. For example, given a template definition in
module $(TT A):
)

---
module A;

template Foo(T)
{
    T bar;
}
---

$(P
it can be accessed from module $(TT B) like:
)

---
module B;

import A;

void test()
{
    A.Foo!(int).bar = 3;
}
---

$(P
As usual, an alias can be used to simplify access:
)

---
module B;

import A;
alias A.Foo!(int).bar bar;

void test()
{
    bar = 3;
}
---


<h2>Template Parameters</h2>

$(P
C++ template parameters can be:)

$(UL
$(LI types)
$(LI integral values)
$(LI static/global addresses)
$(LI template names)
)

$(P D template parameters can be:)

$(UL
$(LI types)
$(LI integral values)
$(LI floating point values)
$(LI string literals)
$(LI templates)
$(LI or any symbol)
)

$(P Each can have default values,
and type parameters can have (a limited form of) constraints:
)

---
class B { ... }
interface I { ... }

class Foo(
  R,            // R can be any type
  P:P*,         // P must be a pointer type
  T:int,        // T must be int type
  S:T*,         // S must be pointer to T
  C:B,          // C must be of class B or derived
                // from B
  U:I,          // U must be a class that
                // implements interface I
  char[] string = "hello",
                // string literal,
                // default is "hello"
  alias A = B   // A is any symbol
                // (including template symbols),
                // defaulting to B
  )
{
    ...
}
---

<h2>Specialization</h2>

$(P
Partial and explicit specialization work as they do in C++, except that
there is no notion of a 'primary' template. All the templates with the
same name are examined upon template instantiation, and the one with the
best fit of arguments to parameters is instantiated.
)

---
template Foo(T) ...
template Foo(T:T*) ...
template Foo(T, U:T) ...
template Foo(T, U) ...
template Foo(T, U:int) ...

Foo!(long)       // picks Foo(T)
Foo!(long[])     // picks Foo(T), T is long[]
Foo!(int*)       // picks Foo(T*), T is int
Foo!(long,long)  // picks Foo(T, T)
Foo!(long,short) // picks Foo(T, U)
Foo!(long,int)   // picks Foo(T, U:int)
Foo!(int,int)    // ambiguous - Foo(T, U:T)
                 // or Foo(T, U:int)
---

<h2>Two Level Name Lookup</h2>

$(P
C++ has some unusual rules for name lookup inside templates, such
as not looking inside base classes, not allowing scoped redeclaration
of template parameter names, and not considering overloads that
happen after the point of definition (this example is
derived from one in the C++98 Standard):
)

$(CCODE
int g(double d) { return 1; }

typedef double A;

template&lt;class T&gt; B
{
  typedef int A;
};

template&lt;class T&gt; struct X : B&lt;T&gt;
{
  A a;              // a has type double
  int T;            // error, T redeclared
  int foo()
  {  char T;        // error, T redeclared
     return g(1);   // always returns 1
  }
};

int g(int i) { return 2; }	// this definition not seen by X
)

$(P
Scoped lookup rules in D match the rules for the rest of the language:
)

---
int g(double d) { return 1; }

typedef double A;

class B(T)
{
  typedef int A;
}

class X(T) : B!(T)
{
  A a;             // a has type int
  int T;           // ok, T redeclared as int
  int foo()
  {   char T;      // ok, T redeclared as char
     return g(1);  // always returns 2
  }
};

int g(int i) { return 2; }	// functions can be forward referenced
---



<h2>Template Recursion</h2>

$(P
Template recursion combined with specialization means that C++ templates
actually form a programming language, although certainly
an odd one. Consider a set of templates that computes a factorial at
run time. Like "hello world" programs, factorial is the canonical example
of template metaprogramming:
)

$(CCODE
template&lt;int n&gt; class factorial
{
  public:
    enum
    {
      result = n * factorial&lt;n - 1&gt;::result
    }; 
};

template&lt;&gt; class factorial&lt;1&gt;
{
  public:
    enum { result = 1 };
};

void test()
{
  // prints 24
  printf("%d\n", factorial&lt;4&gt;::result);
}
)

$(P
Recursion works as well in D, though with significantly less typing:
)

---
template factorial(int n)
{
  const factorial = n * factorial!(n-1);
}

template factorial(int n : 1)
{
  const factorial = 1;
}

void test()
{
  writefln(factorial!(4));  // prints 24 
}
---

$(P
Through using the $(CODE static if) construct it can be done in just one
template:
)

---
template factorial(int n)
{
  static if (n == 1)
    const factorial = 1;
  else
    const factorial = n * factorial!(n-1);
}
---

$(P
reducing 13 lines of code to an arguably much cleaner 7 lines.
$(TT static if)'s are the equivalent of C++'s $(TT #if).
But $(TT #if) cannot access template
arguments, so all template conditional compilation must be handled with
partial and explicitly specialized templates.
$(TT static if) dramatically simplifies
such constructions.
)

$(P D can make this even simpler. Value generating templates such
as the factorial one are possible, but it's easier to just write
a function that can be computed at compile time:)

---
int factorial(int n)
{
  if (n == 1)
    return 1;
  else
    return n * factorial(n - 1);
}

static int x = factorial(5);  // x is statically initialized to 120
---

<h2>$(ACRONYM SFINAE, Substitution Failure Is Not An Error)</h2>

$(P
This determines if the template's argument type is a function,
from "$(I C++ Templates: The Complete Guide)",
Vandevoorde &amp; Josuttis pg. 353:
)

$(CCODE
template&lt;U&gt; class IsFunctionT
{
  private:
    typedef char One;
    typedef struct { char a[2]; } Two;
    template static One test(...);
    template static Two test(U (*)[1]);
  public:
    enum {
      Yes = sizeof(IsFunctionT::test(0)) == 1
    };
};

void test()
{
  typedef int (fp)(int);

  assert(IsFunctionT&lt;fp&gt;::Yes == 1);
}
)

$(P
Template $(TT IsFunctionT) relies on two side effects to achieve its result.
First, it relies on arrays of functions being an invalid C++ type.
Thus, if $(TT U) is a function type, the second $(TT test) will not be selected
since to do so would cause an error ($(SFINAE)).
The first $(TT test) will be selected.
If $(TT U) is not a function type, the second $(TT test) is a better fit than ... .
Next, it is determined which $(TT test) was selected by examining the size
of the return value, i.e. $(TT sizeof(One)) or $(TT sizeof(Two)).
Unfortunately, template metaprogramming in C++ often seems to be relying
on side effects rather than being able to expressly code what is desired.
)

$(P
In D this can be written:
)

---
template IsFunctionT(T)
{
  static if ( is(T[]) )
    const int IsFunctionT = 0;
  else
    const int IsFunctionT = 1;
}

void test()
{
  alias int fp(int);

  assert(IsFunctionT!(fp) == 1);
}
---

$(P
The $(TT is(T[])) is the equivalent of $(SFINAE).
It tries to build an array of $(TT T),
and if $(TT T) is a function type, it is an array of functions. Since this is
an invalid type, the $(TT T[]) fails and $(TT is(T[])) returns false.
)

$(P
Although $(SFINAE) can be used, the is expressions can test a type directly,
so it isn't even necessary to use a template to ask questions about a type:
)

---
void test()
{
  alias int fp(int);

  assert( is(fp == function) );
}
---

<h2>Template Metaprogramming With Floats</h2>

$(P
Let's move on to things that are impractical with templates in C++.
For example, this template returns the square root of
real number $(TT x) using the Babylonian method:
)

---
import std.stdio;

template sqrt(real x, real root = x/2, int ntries = 0)
{
  static if (ntries == 5)
    // precision doubles with each iteration,
    // 5 should be enough
    const sqrt = root;
  else static if (root * root - x == 0)
    const sqrt = root;  // exact match
  else
    // iterate again
    const sqrt = sqrt!(x, (root+x/root)/2, ntries+1);
}

void main()
{
    real x = sqrt!(2);
    writefln("%.20g", x); // 1.4142135623730950487
}
---

$(P
Literal square roots are often needed for speed reasons in other runtime
floating point computations, such as computing the gamma function.
These template floating point algorithms need not be efficient as they are
computed at compile time, they only need to be accurate.
)

$(P
Much more complex templates can be built, for example, Don Clugston
has written a template to compute &pi; at compile time. [2]
)

$(P Again, we can just do this with a function that can be executed
at compile time:)

---
real sqrt(real x)
{
    real root = x / 2;
    for (int ntries = 0; ntries < 5; ntries++)
    {
	if (root * root - x == 0)
	    break;
	root = (root + x / root) / 2;
    }
    return root;
}
static y = sqrt(10);   // y is statically initialized to 3.16228
---

<h2>Template Metaprogramming With Strings</h2>

$(P
Even more interesting things can be done with strings. This example
converts an integer to a string at compile time:
)

---
template decimalDigit(int n)	// [3]
{
  const char[] decimalDigit = "0123456789"[n..n+1];
} 

template itoa(long n)
{   
  static if (n < 0)
     const char[] itoa = "-" ~ itoa!(-n);  
  else static if (n < 10)
     const char[] itoa = decimalDigit!(n); 
  else
     const char[] itoa = itoa!(n/10L) ~ decimalDigit!(n%10L); 
}

char[] foo()
{
  return itoa!(264);   // returns "264"
}
---

$(P
This template will compute the hash of a string literal:
)

---
template hash(char [] s, uint sofar=0)
{
   static if (s.length == 0)
      const hash = sofar;
   else
      const hash = hash!(s[1 .. length], sofar * 11 + s[0]);
}

uint foo()
{
    return hash!("hello world");
}
---

<h2>Regular Expression Compiler</h2>

$(P
How do D templates fare with something much more significant, like
a regular expression compiler? Eric Niebler has written one for C++
that relies on expression templates. [4]
The problem with using expression templates is that one is restricted
to using only C++ operator syntax and precedence.
Hence, regular expressions using expression templates don't look like
regular expressions, they look like C++ expressions.
Eric Anderton has written one for D that relies on the ability of
templates to parse strings. [5]
This means that, within the strings, one can use the expected regular
expression grammar and operators.
)

$(P
The regex compiler templates parse the regex string argument,
pulling off tokens
one by one from the front, and instantiating custom template functions
for each token predicate,
eventually combining them all into one function that directly implements
the regular expression.
It even gives reasonable error messages for syntax errors in
the regular expression.
)

$(P
Calling that function with an argument of a string to match returns
an array of matching strings:
)

---
import std.stdio;
import regex;

void main()
{
    auto exp = &regexMatch!(r"[a-z]*\s*\w*");
    writefln("matches: %s", exp("hello    world"));
}
---

$(P
What follows is a cut-down version of Eric Anderton's regex compiler.
It is just enough to compile the regular expression above,
serving to illustrate how it is done.
)

-------------
module regex;

const int testFail = -1;

/**
 * Compile pattern[] and expand to a custom generated
 * function that will take a string str[] and apply the
 * regular expression to it, returning an array of matches.
 */

template regexMatch(char[] pattern)
{
  char[][] regexMatch(char[] str)
  {
    char[][] results;
    int n = regexCompile!(pattern).fn(str);
    if (n != testFail && n > 0)
      results ~= str[0..n];
    return results;
  }
}

/******************************
 * The testXxxx() functions are custom generated by templates
 * to match each predicate of the regular expression.
 *
 * Params:
 *	char[] str	the input string to match against
 *
 * Returns:
 *	testFail	failed to have a match
 *	n >= 0		matched n characters
 */

/// Always match
template testEmpty()
{
  int testEmpty(char[] str) { return 0; }
}

/// Match if testFirst(str) and testSecond(str) match
template testUnion(alias testFirst, alias testSecond)
{
  int testUnion(char[] str)
  {
    int n1 = testFirst(str);
    if (n1 != testFail)
    {
      int n2 = testSecond(str[n1 .. $]);
      if (n2 != testFail)
        return n1 + n2;
    }
    return testFail;
  }
}

/// Match if first part of str[] matches text[]
template testText(char[] text)
{
  int testText(char[] str)
  {
    if (str.length &&
        text.length <= str.length &&
        str[0..text.length] == text
       )
      return text.length;
    return testFail;
  }
}

/// Match if testPredicate(str) matches 0 or more times
template testZeroOrMore(alias testPredicate)
{
  int testZeroOrMore(char[] str)
  {
    if (str.length == 0)
      return 0;
    int n = testPredicate(str);
    if (n != testFail)
    {
      int n2 = testZeroOrMore!(testPredicate)(str[n .. $]);
      if (n2 != testFail)
        return n + n2;
      return n;
    }
    return 0;
  }
}

/// Match if term1[0] <= str[0] <= term2[0]
template testRange(char[] term1, char[] term2)
{
  int testRange(char[] str)
  {
    if (str.length && str[0] >= term1[0]
                   && str[0] <= term2[0])
      return 1;
    return testFail;
  }
}

/// Match if ch[0]==str[0]
template testChar(char[] ch)
{
  int testChar(char[] str)
  {
    if (str.length && str[0] == ch[0])
      return 1;
    return testFail;
  }
}

/// Match if str[0] is a word character
template testWordChar()
{
  int testWordChar(char[] str)
  {
    if (str.length &&
        (
         (str[0] >= 'a' && str[0] <= 'z') ||
         (str[0] >= 'A' && str[0] <= 'Z') ||
         (str[0] >= '0' && str[0] <= '9') ||
         str[0] == '_'
        )
       )
    {
      return 1;
    }
    return testFail;
  }
}

/*****************************************************/

/**
 * Returns the front of pattern[] up until
 * the end or a special character.
 */

template parseTextToken(char[] pattern)
{
  static if (pattern.length > 0)
  {
    static if (isSpecial!(pattern))
      const char[] parseTextToken = "";
    else
      const char[] parseTextToken =
           pattern[0..1] ~ parseTextToken!(pattern[1..$]);
  }	
  else
    const char[] parseTextToken="";
}

/**
 * Parses pattern[] up to and including terminator.
 * Returns:
 *	token[]	 	everything up to terminator.
 *	consumed	number of characters in pattern[] parsed
 */
template parseUntil(char[] pattern,char terminator,bool fuzzy=false)
{
  static if (pattern.length > 0)
  {
    static if (pattern[0] == '\\')
    {
      static if (pattern.length > 1)
      {
        const char[] nextSlice = pattern[2 .. $];
        alias parseUntil!(nextSlice,terminator,fuzzy) next;
        const char[] token = pattern[0 .. 2] ~ next.token;
        const uint consumed = next.consumed+2;
      }
      else
      {
        pragma(msg,"Error: expected character to follow \\");
        static assert(false);
      }
    }
    else static if (pattern[0] == terminator)
    {
      const char[] token="";
      const uint consumed = 1;
    }
    else
    {
      const char[] nextSlice = pattern[1 .. $];
      alias parseUntil!(nextSlice,terminator,fuzzy) next;
      const char[] token = pattern[0..1] ~ next.token;
      const uint consumed = next.consumed+1;
    }
  }
  else static if (fuzzy)
  {
    const char[] token = "";
    const uint consumed = 0;
  }
  else
  {
    pragma(msg,"Error: expected " ~
               terminator ~
               " to terminate group expression");
    static assert(false);
  }			
}

/**
 * Parse contents of character class.
 * Params:
 *   pattern[] = rest of pattern to compile
 * Output:
 *   fn       = generated function
 *   consumed = number of characters in pattern[] parsed
 */

template regexCompileCharClass2(char[] pattern)
{
  static if (pattern.length > 0)
  {
    static if (pattern.length > 1)
    {
      static if (pattern[1] == '-')
      {
        static if (pattern.length > 2)
        {
          alias testRange!(pattern[0..1], pattern[2..3]) termFn;
          const uint thisConsumed = 3;
          const char[] remaining = pattern[3 .. $];
        }
        else // length is 2
        {
          pragma(msg,
            "Error: expected char following '-' in char class");
          static assert(false);	
        }
      }
      else // not '-'
      {
        alias testChar!(pattern[0..1]) termFn;
        const uint thisConsumed = 1;
        const char[] remaining = pattern[1 .. $];
      }
    }
    else
    {
      alias testChar!(pattern[0..1]) termFn;
      const uint thisConsumed = 1;
      const char[] remaining = pattern[1 .. $];
    }
    alias regexCompileCharClassRecurse!(termFn,remaining) recurse;
    alias recurse.fn fn;
    const uint consumed = recurse.consumed + thisConsumed;
  }
  else
  {
    alias testEmpty!() fn;
    const uint consumed = 0;
  }
}

/**
 * Used to recursively parse character class.
 * Params:
 *  termFn = generated function up to this point
 *  pattern[] = rest of pattern to compile
 * Output:
 *  fn = generated function including termFn and
 *       parsed character class
 *  consumed = number of characters in pattern[] parsed
 */

template regexCompileCharClassRecurse(alias termFn,char[] pattern)
{
  static if (pattern.length > 0 && pattern[0] != ']')
  {
    alias regexCompileCharClass2!(pattern) next;
    alias testOr!(termFn,next.fn,pattern) fn;
    const uint consumed = next.consumed;
  }
  else
  {
    alias termFn fn;
    const uint consumed = 0;
  }
}

/**
 * At start of character class. Compile it.
 * Params:
 *  pattern[] = rest of pattern to compile
 * Output:
 *  fn = generated function
 *  consumed = number of characters in pattern[] parsed
 */

template regexCompileCharClass(char[] pattern)
{	
  static if (pattern.length > 0)
  {
    static if (pattern[0] == ']')
    {
      alias testEmpty!() fn;
      const uint consumed = 0;
    }
    else
    {
      alias regexCompileCharClass2!(pattern) charClass;
      alias charClass.fn fn;
      const uint consumed = charClass.consumed;
    }
  }
  else
  {
    pragma(msg,"Error: expected closing ']' for character class");
    static assert(false);	
  }
}

/**
 * Look for and parse '*' postfix.
 * Params:
 *  test = function compiling regex up to this point
 *  pattern[] = rest of pattern to compile
 * Output:
 *  fn = generated function
 *  consumed = number of characters in pattern[] parsed
 */

template regexCompilePredicate(alias test, char[] pattern)
{
  static if (pattern.length > 0 && pattern[0] == '*')
  {
    alias testZeroOrMore!(test) fn;
    const uint consumed = 1;
  }
  else
  {
    alias test fn;
    const uint consumed = 0;
  }
}

/**
 * Parse escape sequence.
 * Params:
 *  pattern[] = rest of pattern to compile
 * Output:
 *  fn = generated function
 *  consumed = number of characters in pattern[] parsed
 */

template regexCompileEscape(char[] pattern)
{
  static if (pattern.length > 0)
  {
    static if (pattern[0] == 's')
    {
      // whitespace char
      alias testRange!("\x00","\x20") fn;
    }
    else static if (pattern[0] == 'w')
    {
      //word char
      alias testWordChar!() fn;
    }
    else
    {
      alias testChar!(pattern[0 .. 1]) fn;
    }
    const uint consumed = 1;
  }
  else
  {
    pragma(msg,"Error: expected char following '\\'");
    static assert(false);
  }
}

/**
 * Parse and compile regex represented by pattern[].
 * Params:
 *  pattern[] = rest of pattern to compile
 * Output:
 *  fn = generated function
 */

template regexCompile(char[] pattern)
{
  static if (pattern.length > 0)
  {
    static if (pattern[0] == '[')
    {
      const char[] charClassToken =
          parseUntil!(pattern[1 .. $],']').token;
      alias regexCompileCharClass!(charClassToken) charClass;
      const char[] token = pattern[0 .. charClass.consumed+2];
      const char[] next = pattern[charClass.consumed+2 .. $];
      alias charClass.fn test;
    }
    else static if (pattern[0] == '\\')
    {
      alias regexCompileEscape!(pattern[1..pattern.length]) escapeSequence;
      const char[] token = pattern[0 .. escapeSequence.consumed+1];
      const char[] next =
          pattern[escapeSequence.consumed+1 .. $];
      alias escapeSequence.fn test;
    }
    else
    {
      const char[] token = parseTextToken!(pattern);
      static assert(token.length > 0);
      const char[] next = pattern[token.length .. $];
      alias testText!(token) test;
    }
    
    alias regexCompilePredicate!(test, next) term;
    const char[] remaining = next[term.consumed .. next.length];
    
    alias regexCompileRecurse!(term,remaining).fn fn;
  }
  else
    alias testEmpty!() fn;
}

template regexCompileRecurse(alias term,char[] pattern)
{
  static if (pattern.length > 0)
  {
    alias regexCompile!(pattern) next;
    alias testUnion!(term.fn, next.fn) fn;
  }
  else
    alias term.fn fn;
}

/// Utility function for parsing
template isSpecial(char[] pattern)
{
  static if (
    pattern[0] == '*' ||
    pattern[0] == '+' ||
    pattern[0] == '?' ||
    pattern[0] == '.' ||
    pattern[0] == '[' ||
    pattern[0] == '{' ||
    pattern[0] == '(' ||
    pattern[0] == ')' ||
    pattern[0] == '$' ||
    pattern[0] == '^' ||
    pattern[0] == '\\'
  )
    const isSpecial = true;
  else
    const isSpecial = false;
}
---

<h2>More Template Metaprogramming</h2>

    $(OL
	$(LI Tomasz Stachowiak's compile time $(LINK2 http://www-users.mat.uni.torun.pl/~h3r3tic/ctrace/, raytracer).)

	$(LI Don Clugston's compile time $(LINK2 http://www.99-bottles-of-beer.net/language-d-1212.html?PHPSESSID=1c686874f412f908530c69924496192d, 99 Bottles of Beer).)
    )

<h2>References</h2>

	$(P [1] D programming language,
	see $(LINK http://www.digitalmars.com/d/)
	)

	$(P [2] Don Clugston's &pi; calculator, see
	$(LINK http://trac.dsource.org/projects/ddl/browser/trunk/meta/demo/calcpi.d)
	)

	$(P [3] Don Clugston's decimaldigit and itoa,
	see $(LINK http://trac.dsource.org/projects/ddl/browser/trunk/meta/conv.d)
	)

	$(P [4] Eric Niebler's Boost.Xpressive regular expression template
	library is at $(LINK http://boost-sandbox.sourceforge.net/libs/xpressive/doc/html/index.html)
	)

	$(P [5] Eric Anderton's Regular Expression template library
	for D is at $(LINK http://trac.dsource.org/projects/ddl/browser/trunk/meta/regex.d)
	)

<h2>Acknowledgements</h2>

$(P
I gratefully acknowledge the inspiration and assistance
of Don Clugston, Eric Anderton and Matthew Wilson.
)

)

Macros:
	TITLE=Templates Revisited
	WIKI=TemplatesRevisited


