Ddoc

$(D_S Lazy Evaluation of Function Arguments,

<center>
$(I by Walter Bright, $(LINK http://www.digitalmars.com/d))
</center>


$(P Lazy evaluation is the technique of not evaluating an expression
unless and until the result of the expression is required.
The &amp;&amp;, || and ?: operators are the conventional way to
do lazy evaluation:
)

---
void test(int* p)
{
    if (p && p[0])
	...
}
---

$(P The second expression $(TT p[0]) is not evaluated unless $(TT p)
is not $(B null).
If the second expression was not lazily evaluated, it would
generate a runtime fault if $(TT p) was $(B null).
)

$(P While invaluable, the lazy evaluation operators have significant
limitations. Consider a logging function, which logs
a message, and can be turned on and off at runtime based on a global
value:
)

---
void log(char[] message)
{
    if (logging)
	fwritefln(logfile, message);
}
---

$(P Often, the message string will be constructed at runtime:
)

---
void foo(int i)
{
    log("Entering foo() with i set to " ~ toString(i));
}
---

$(P While this works, the problem is that the building of the message
string happens regardless of whether logging is enabled or not.
With applications that make heavy use of logging, this can become
a terrible drain on performance.
)

$(P One way to fix it is by using lazy evaluation:
)

---
void foo(int i)
{
    if (logging) log("Entering foo() with i set to " ~ toString(i));
}
---

$(P but this violates encapsulation principles by exposing the details
of logging to the user. In C, this problem is often worked around
by using a macro:
)

$(CCODE
#define LOG(string)  (logging && log(string))
)

$(P but that just papers over the problem. Preprocessor macros have
well known shortcomings:)

$(UL
$(LI The $(TT logging) variable is exposed in the user's namespace.)
$(LI Macros are invisible to symbolic debuggers.)
$(LI Macros are global only, and cannot be scoped.)
$(LI Macros cannot be class members.)
$(LI Macros cannot have their address taken, so cannot be passed indirectly
     like functions can.)
)

$(P A robust solution would be
a way to do lazy evaluation of function parameters. Such a way
is possible in the D programming language using a delegate parameter:
)

---
void log(char[] delegate() dg)
{
    if (logging)
	fwritefln(logfile, dg());
}

void foo(int i)
{
    log( { return "Entering foo() with i set to " ~ toString(i); });
}
---

$(P Now, the string building expression only gets evaluated if logging
is true, and encapsulation is maintained. The only trouble is that
few are going to want to wrap expressions with $(TT { return $(I exp); }).
)

$(P So D takes it one small, but crucial, step further
(suggested by Andrei Alexandrescu).
Any expression
can be implicitly converted to a delegate that returns either $(TT void) or
the type of the expression.
The delegate declaration is replaced by the $(TT lazy) storage class
(suggested by Tomasz Stachowiak).
The functions then become:
)

---
void log(lazy char[] dg)
{
    if (logging)
	fwritefln(logfile, dg());
}

void foo(int i)
{
    log("Entering foo() with i set to " ~ toString(i));
}
---

$(P which is our original version, except that now the string is not
constructed unless logging is turned on.
)

$(P Any time there is a repeating pattern seen in code, being able to
abstract out that pattern and encapsulate it means we can reduce the
complexity of the code, and hence bugs. The most common example of
this is the function
itself.
Lazy evaluation enables encapsulation of a host of other patterns.
)

$(P For a simple example, suppose an expression is to be evaluated $(I count)
times. The pattern is:
)

---
for (int i = 0; i < count; i++)
   exp;
---

$(P This pattern can be encapsulated in a function using lazy evaluation:
)

---
void dotimes(int count, lazy void exp)
{
    for (int i = 0; i < count; i++)
       exp();
}
---

$(P It can be used like:
)

---
void foo()
{
    int x = 0;
    dotimes(10, writef(x++));
}
---

$(P which will print:
)

$(CONSOLE
0123456789
)

$(P More complex user defined control structures are possible.
Here's a method to create a switch like structure:
)

---
bool scase(bool b, lazy void dg)
{
    if (b)
	dg();
    return b;
}

/* Here the variadic arguments are converted to delegates in this
   special case.
 */
void cond(bool delegate()[] cases ...)
{
    foreach (c; cases)
    {	if (c())
	    break;
    }
}
---

$(P which can be used like:
)

---
void foo()
{
    int v = 2;
    cond
    (
	scase(v == 1, writefln("it is 1")),
	scase(v == 2, writefln("it is 2")),
	scase(v == 3, writefln("it is 3")),
	scase(true,   writefln("it is the default"))
    );
}
---

$(P which will print:
)

$(CONSOLE
it is 2
)

$(P Those familiar with the Lisp programming language will notice some
intriguing parallels with Lisp macros.
)

$(P For a last example, there is the common pattern:
)

---
Abc p;
p = foo();
if (!p)
    throw new Exception("foo() failed");
p.bar();	// now use p
---

$(P Because throw is a statement, not an expression, expressions that
need to do this need to be broken up into multiple statements,
and extra variables are introduced.
(For a thorough treatment of this issue, see Andrei Alexandrescu and
Petru Marginean's paper
$(LINK2 http://erdani.org/publications/cuj-06-2003.html, Enforcements)).
With lazy evaluation, this can all be encapsulated into a single
function:
)

---
Abc Enforce(Abc p, lazy char[] msg)
{
    if (!p)
	throw new Exception(msg());
    return p;
}
---

$(P and the opening example above becomes simply:
)

---
Enforce(foo(), "foo() failed").bar();
---

$(P and 5 lines of code become one. Enforce can be improved by making it a
template function:
)

---
T Enforce(T)(T p,  lazy char[] msg)
{
    if (!p)
	throw new Exception(msg());
    return p;
}
---

<h2>Conclusion</h2>

$(P Lazy evaluation of function arguments dramatically extends the expressive
power of functions. It enables the encapsulation into functions of many
common coding patterns and idioms that previously were too clumsy or
impractical to do.
)

<h2>Acknowledgements</h2>

	$(P I gratefully acknowledge the inspiration and assistance
	of Andrei Alexandrescu, Bartosz Milewski, and David Held.
	The D community helped a lot with much constructive
	criticism, such as the thread starting with
	Tomasz Stachowiak in $(NG_digitalmars_D 41633).
	)

)

Macros:
	TITLE=LazyEvaluationOfFunctionArguments
	WIKI=LazyEvaluation

	NG_digitalmars_D = <a href="http://www.digitalmars.com/pnews/read.php?server=news.digitalmars.com&group=digitalmars.D&artnum=$0">D/$0</a>

