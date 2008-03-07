Ddoc

$(D_S Function Hijacking Mitigation,

<div align="right">$(DIGG)</div>

$(P
As software becomes more complex, we become more reliant on module
interfaces. An application may import and combine modules from multiple
sources, including sources from outside the company. The module
developers must be able to maintain and improve those modules without
inadvertently stepping on the behavior of modules over which they cannot
have knowledge of. The application developer needs to be notified if
any module changes would break the application. This talk covers
function hijacking, where adding innocent and reasonable declarations
in a module
can wreak arbitrary havoc on an application program in C++ and Java. We'll then
look at how
modest language design changes can largely eliminate the problem in the D
programming language.
)


$(SECTION2 Global Function Hijacking,

$(P Let's say we are developing an application that imports two modules:
X from the XXX Corporation, and Y from the YYY Corporation.
Modules X and Y are unrelated to each other, and are used for completely
different purposes.
The modules look like:
)

----
module X;

void foo();
void foo(long);
----

----
module Y;

void bar();
----

$(P The application program would look like:
)

----
import X;
import Y;

void abc()
{
    foo(1);  // calls X.foo(long)
}

void def()
{
    bar();   // calls Y.bar();
}
----

$(P So far, so good. The application is tested and works, and is shipped.
Time goes by, the application programmer moves on, the application is
put in maintenance mode. Meanwhile, YYY Corporation, responding to
customer requests, adds a type $(CODE A) and a function $(CODE foo(A)):
)

----
module Y;

void bar();
class A;
void foo(A);
----

$(P The application maintainer gets the latest version
of Y, recompiles, and no problems. So far, so good.
But then, YYY Corporation expands the functionality of $(CODE foo(A)),
adding a function $(CODE foo(int)):
)

----
module Y;

void bar();
class A;
void foo(A);
void foo(int);
----

$(P Now, our application maintainer routinely gets the latest version of Y,
recompiles, and suddenly his application is doing something unexpected:
)

----
import X;
import Y;

void abc()
{
    foo(1);  // calls Y.foo(int) rather than X.foo(long)
}

void def()
{
    bar();   // calls Y.bar();
}
----

$(P because $(CODE Y.foo(int)) is a better overloading match than $(CODE X.foo(long)).
But since $(CODE X.foo) does something completely and totally different than
$(CODE Y.foo), the application now has a potentially very serious bug in it.
Even worse, the compiler offers NO indication that this happened and cannot
because, at least for C++, this is how the language is supposed to work.
)

$(P In C++, some mitigation can be done by using namespaces or (hopefully)
unique
name prefixes within the modules
X and Y. This doesn't help the application programmer, however, who probably
has no control over X or Y.
)

$(P The first stab at fixing this problem in the D programming language was
to add the rules:
)

$(OL
$(LI by default functions can only overload against other functions in the same
module)
$(LI if a name is found in more than one scope, in order to use it it must
be fully qualified)
$(LI in order to overload functions from multiple modules together, an alias
statement is used to merge the overloads)
)

$(P So now, when YYY Corporation added the $(CODE foo(int)) declaration, the
application
maintainer now gets a compilation error that foo is defined in both module
X and module Y, and has an opportunity to fix it.
)

$(P This solution worked, but is a little restrictive. After all, there's no
way $(CODE foo(A)) would be confused with $(CODE foo()) or $(CODE foo(long)),
so why have the compiler
complain about it? The solution turned out to be to introduce the notion
of overload sets.
)

$(SECTION3 Overload Sets,

$(P An overload set is formed by a group of functions with the same name
declared
in the same scope. In the module X example, the functions $(CODE X.foo()) and
$(CODE X.foo(long)) form a single overload set. The functions
$(CODE Y.foo(A)) and $(CODE Y.foo(int))
form another overload set. Our method for resolving a call to foo becomes:
)

$(OL
$(LI Perform overload resolution independently on each overload set)
$(LI If there is no match in any overload set, then error)
$(LI If there is a match in exactly one overload set, then go with that)
$(LI If there is a match in more than one overload set, then error)
)

$(P The most important thing about this is that even if there is a BETTER match
in one overload set over another overload set, it is still an error.
The overload sets must not overlap.
)

$(P In our example:
)

----
void abc()
{
    foo(1);  // matches Y.foo(int) exactly, X.foo(long) with conversions
}
----

$(P will generate an error, whereas:
)

----
void abc()
{
    A a;
    foo(a);  // matches Y.foo(A) exactly, nothing in X matches
    foo();   // matches X.foo() exactly, nothing in Y matches
}
----

$(P compiles without error, as we'd intuitively expect.
)

$(P If overloading of $(CODE foo) between X and Y is desired, the following can be done:
)

----
import X;
import Y;

alias X.foo foo;
alias Y.foo foo;

void abc()
{
    foo(1);  // calls Y.foo(int) rather than X.foo(long)
}
----

$(P and no error is generated. The difference here is that the user
deliberately combined the overload sets in X and Y, and so presumably
both knows what he's doing and is willing to check the $(CODE foo)'s when
X or Y is updated.
)

)

)

$(SECTION2 Derived Class Member Function Hijacking,

$(P There are more cases of function hijacking. Imagine a class $(CODE A) coming
from AAA Corporation:
)

----
module M;

class A { }
----

$(P and in our application code, we derive from $(CODE A) and add a virtual
member function $(CODE foo):
)

----
import M;

class B : A
{
    void foo(long);
}

void abc(B b)
{
    b.foo(1);   // calls B.foo(long)
}
----

$(P and everything is hunky-dory. As before, things go on, AAA Corporation
(who cannot know about $(CODE B)) extends $(CODE A)'s functionality a bit by
adding $(CODE foo(int)):
)

----
module M;

class A
{
    void foo(int);
}
----

$(P Now, consider if we're using Java-style overloading rules, where base class
member functions overload right alongside derived class functions. Now,
our application call:
)

----
import M;

class B : A
{
    void foo(long);
}

void abc(B b)
{
    b.foo(1);   // calls A.foo(int), AAAEEEEEIIIII!!!
}
----

$(P and the call to $(CODE B.foo(long)) was hijacked by the base class $(CODE A)
to call $(CODE A.foo(int)),
which likely has no meaning whatsoever in common with $(CODE B.foo(long)).
This is why I don't like Java overloading rules.
C++ has the right idea here in that functions in a derived class hide
all the functions of the same name in a base class, even if the functions
in the base class might be a better match. D follows this rule.
And once again, if the user desires them to be overloaded against each other,
this can be accomplished in C++ with a using declaration, and in D with
an analogous alias declaration.
)

)


$(SECTION2 Base Class Member Function Hijacking,

$(P I bet you suspected there was more to it than that, and you'd be right.
Hijacking can go the other way, too. A derived class can hijack a base
class member function!
)

$(P Consider:
)

----
module M;

class A
{
    void def() { }
}
----

$(P and in our application code, we derive from $(CODE A) and add a virtual
member function $(CODE foo):
)

----
import M;

class B : A
{
    void foo(long);
}

void abc(B b)
{
    b.def();   // calls A.def()
}
----

$(P AAA Corporation once again knows nothing about $(CODE B), and adds a
function
$(CODE foo(long)) and uses it to implement some needed new functionality of
$(CODE A):
)

----
module M;

class A
{
    void foo(long);

    void def()
    {
        foo(1L);   // expects to call A.foo(long)
    }
}
----

$(P but, whoops, $(CODE A.def()) now calls $(CODE B.foo(long)).
$(CODE B.foo(long)) has hijacked
the $(CODE A.foo(long)). So, you might say, the
designer of A should have had the foresight for this, and make
$(CODE foo(long)) a non-virtual function. The problem is that $(CODE A)'s
designer
may very easily have intended $(CODE A.foo(long)) to be virtual, as it's a new
feature of $(CODE A). He cannot have known about $(CODE B.foo(long)).
Take this to the logical conclusion, and we realize that under this system
of overriding, there is no safe way to add any functionality to $(CODE A).
)

$(P The D solution is straightforward. If a function in a derived class
overrides a function in a base class, it must use the storage class
override. If it overrides without using the override storage class
it's an error. If it uses the override storage class without overriding
anything, it's an error.
)

----
class C
{
    void foo();
    void bar();
}
class D : C
{
    override void foo();  // ok
    void bar();           // error, overrides C.bar()
    override void abc();  // error, no C.abc()
}
----

$(P This eliminates the potential of a derived class member function hijacking
a base class member function.
)

)


$(SECTION2 Derived Class Member Function Hijacking #2,

$(P There's one last case of base member function hijacking a derived
member function. Consider:
)

----
module A;

class A
{
    void def()
    {
        foo(1);
    }

    void foo(long);
}
----

$(P Here, $(CODE foo(long)) is a virtual function that provides a specific
functionality.
Our derived class designer overrides $(CODE foo(long)) to replace that behavior
with one suited to the derived class' purpose:
)

----
import A;

class B : A
{
    override void foo(long);
}

void abc(B b)
{
    b.def();   // eventually calls B.foo(long)
}
----

$(P So far, so good. The call to $(CODE foo(1)) inside $(CODE A)
winds up correctly calling
$(CODE B.foo(long)). Now $(CODE A)'s designer decides to optimize things, and
adds
an overload for $(CODE foo):
)

----
module A;

class A
{
    void def()
    {
    foo(1);
    }

    void foo(long);
    void foo(int);
}
----

$(P Now,
)

----
import A;

class B : A
{
    override void foo(long);
}

void abc(B b)
{
    b.def();   // eventually calls A.foo(int)
}
----

$(P Doh! $(CODE B) thought he was overriding the behavior of $(CODE A)'s
$(CODE foo), but did not.
$(CODE B)'s programmer needs to add another function to $(CODE B):
)

----
class B : A
{
    override void foo(long);
    override void foo(int);
}
----

$(P to restore correct behavior. But there's no clue he needs to do that.
Compile time is of no help at all, as the compilation of $(CODE A) has no
knowledge of what $(CODE B) overrides.
)

$(P Let's look at how $(CODE A) calls the virtual functions, which it
does through the vtbl[]. $(CODE A)'s vtbl[] looks like:
)

----
A.vtbl[0] = &A.foo(long);
A.vtbl[1] = &A.foo(int);
----

$(P $(CODE B)'s vtbl[] looks like:
)

----
B.vtbl[0] = &B.foo(long);
B.vtbl[1] = &A.foo(int);
----

$(P and the call in $(CODE A.def()) to $(CODE foo(int))
is actually a call to vtbl[1].
We'd really like $(CODE A.foo(int)) to be inaccessible from a $(CODE B) object.
The solution is to rewrite $(CODE B)'s vtbl[] as:
)

----
B.vtbl[0] = &B.foo(long);
B.vtbl[1] = &error;
----

$(P where, at runtime, an error function is called which will throw an
exception. It isn't perfect since it isn't caught at compile time,
but at least the application program won't blithely be calling the wrong
function and continue on.
)

)

$(SECTION2 Conclusion,

$(P Function hijacking is a pernicious and particularly nasty problem in
complex C++ and Java programs because there is no defense against it
for the application programmer. Some small modifications to the language
semantics can defend against it without sacrificing any power or performance.
)

)

$(SECTION2 References,

$(UL
$(LI $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/Hijacking_56458.html, digitalmars.D - Hijacking))
$(LI $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/Re_Hijacking_56505.html, digitalmars.D - Re: Hijacking))
$(LI $(LINK2 http://www.digitalmars.com/d/archives/digitalmars/D/aliasing_base_methods_49572.html#N49577, digitalmars.D - aliasing base methods))
$(LI Eiffel, Scala and C# use override or something analogous)
)

$(P Credits:)

$(UL
$(LI Kris Bell)
$(LI Frank Benoit)
$(LI Andrei Alexandrescu)
)

)

)

Macros:
	TITLE=Hijack
	WIKI=Hijack


