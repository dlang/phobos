Ddoc

$(COMMUNITY Template Comparison,

$(P C++ pioneered templates and template metaprogramming, and continues
to improve on it with C++0x.
The D programming language is the first to comprehensively reengineer
templates based on the C++ experience.
Since C++0x is not a ratified standard yet, proposed changes to C++
are subject to change.)

	<table border=2 cellpadding=4 cellspacing=0 class="comp">
	<caption>Template Comparison Table</caption>

	<thead>
	$(TR
	$(TH Feature)
	$(TH D)
	$(TH C++98)
	$(TH C++0x)
	)
	</thead>

	<tbody>

	$(TR
	$(TD Argument list delineation)
	$(TD Uses !( ), as in Foo!(int))
	$(TD Uses &lt; &gt; as in Foo&lt;int&gt;)
	$(TD No change)
	)

	$(TR
	$(TD Class Templates)
	$(TD Yes:
---
class Foo(T)
{
  T x;
}
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;class T&gt;
  class Foo
{
  T x;
};
)
)
	$(TD No change)
	)

	$(TR
	$(TD Function Templates)
	$(TD Yes:
---
T foo(T)(T i)
{
  ...
}
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;class T&gt;
  T foo(T i)
{
  ...
}
)
)
	$(TD No change)
	)

	$(TR
	$(TD Member Templates)
	$(TD Yes)
	$(TD Yes)
	$(TD No change)
	)

	$(TR
	$(TD Constructor Templates)
	$(TD No)
	$(TD Yes)
	$(TD No change)
	)

	$(TR
	$(TD Parameterize any Declaration)
	$(TD Yes, classes, functions, typedefs,
	variables, enums, etc. can be parameterized,
	such as this variable:
---
template Foo(T)
{
  static T* p;
}
---
)
	$(TD No, only classes and functions)
	$(TD No change)
	)

	$(TR
	$(TD Template Typedefs: Create an alias that binds to some but not all
	of the template	parameters)
	$(TD Yes:
---
class Foo(T, U) { }
template MyFoo(T)
{
  alias Foo!(T, int) MyFoo;
}
MyFoo!(uint) f;
---
)
	$(TD No)
	$(TD Yes:
$(CPPCODE2
template&lt;class T, class U&gt; class Foo { };
template&lt;class T&gt; using MyFoo = Foo&lt;T, int&gt;;
MyFoo&lt;unsigned&gt; f;
)
)
	)


	$(TR
	$(TD Sequence Constructors)
	$(TD No)
	$(TD No)
	$(TD Yes:
$(CPPCODE2
Foo&lt;double&gt; f = { 1.2, 3, 6.8 };
)
)
	)

	$(TR
	$(TD Concepts)
	$(TD No, but much the same effect can be achieved with
	 $(LINK2 version.html#staticif, static if) and
	 $(LINK2 version.html#staticassert, static asserts))
	$(TD No)
	$(TD Yes: $(LINK2 http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2005/n1849.pdf, Concepts for C++0x N1849))
	)


	$(TR
	$(TD Recursive Templates)
	$(TD Yes:
---
template factorial(int n)
{
  const factorial =
     n * factorial!(n-1);
}
template factorial(int n : 1)
{
  const factorial = 1;
}
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;int n&gt; class factorial
{
  public:
    enum
    {
      result =
         n * factorial&lt;n-1&gt;::result
    }; 
};
template&lt;&gt; class factorial&lt;1&gt;
{
  public:
    enum { result = 1 };
};
)
)
	$(TD No change)
	)

	$(TR
	$(TD Conditional Compilation based on
	Template Arguments)
	$(TD Yes:
---
template factorial(int n)
{
  static if (n == 1)
    const factorial = 1;
  else
    const factorial =
       n * factorial!(n-1);
}
---
)
	$(TD No:
$(CPPCODE2
template&lt;int n&gt; class factorial
{
  public:
    enum
    {
#if (n == 1) // $(ERROR)
      result = 1;
#else
      result =
         n * factorial&lt;n-1&gt;::result
#endif
    }; 
};
)
)
	$(TD No change)
	)

	$(TR
	$(TD Template Declarations (with no definition))
	$(TD No)
	$(TD Yes:
$(CPPCODE2
template&lt;class T&gt;
  class Foo;
)
)
	$(TD No change)
	)

	$(TR
	$(TD Grouping templates with the same parameters together)
	$(TD Yes:
---
template Foo(T, U)
{
  class Bar { ... }
  T foo(T t, U u) { ... }
}
Foo!(int,long).Bar b;
return Foo!(char,int).foo('c',3);
---
)
	$(TD No, each must be separate:
$(CPPCODE2
template&lt;class T, class U&gt;
  class Foo_Bar { ... };
template&lt;class T, class U&gt;
  T Foo_foo(T t, U u) { ... };
Foo_Bar&lt;int,long&gt; b;
return Foo_foo&lt;char,int&gt('c',3);
)
)
	$(TD No change)
	)

	$(TR
	$(TD Compile time execution of functions)
	$(TD $(LINK2 function.html#interpretation, Yes):
---
int factorial(int i)
{ if (i == 0)
    return 1;
  else
    return i * factorial(i - 1);
}
static f = factorial(6);
---
	)
	$(TD No)
	$(TD Named constant expressions with parameters:
	   $(LINK2 http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2006/n1972.pdf, Generalized Constant Expressions N1972))
	)

	$(TR
	$(TH Parameters)
	$(TH D)
	$(TH C++98)
	$(TH C++0x)
	)

	$(TR
	$(TD Type Parameters)
	$(TD Yes:
---
class Foo(T)
{
  T x;
}
Foo!(int) f;
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;class T&gt;
  class Foo
{
  T x;
};
Foo&lt;int&gt; f;
)
)
	$(TD No change)
	)

	$(TR
	$(TD Integral Parameters)
	$(TD Yes:
---
void foo(int i)()
{
  int v = i;
}
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;int i&gt;
    void foo()
{
  int v = i;
}
)
)
	$(TD No change)
	)

	$(TR
	$(TD Pointer Parameters)
	$(TD Yes, a pointer to object or function)
	$(TD Yes, a pointer to object or function)
	$(TD No change)
	)

	$(TR
	$(TD Reference Parameters)
	$(TD No, D does not have a general reference type)
	$(TD Yes:
$(CPPCODE2
template&lt;double& D&gt;
    void foo()
{
  double y = D;
}
)
)
	$(TD No change)
	)

	$(TR
	$(TD Pointer to Member Parameters)
	$(TD No, D does not have pointers to members, it has
	  $(LINK2 type.html#delegates, delegates),
	  which can be used as parameters)
	$(TD Yes)
	$(TD No change)
	)

	$(TR
	$(TD Template Template Parameters)
	$(TD Yes:
---
class Foo(T, alias C)
{
  C!(T) x;
}
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;class T,
         template&lt;class U&gt; class C&gt;
    class Foo
{
  C&lt;T&gt; x;
};
)
)
	$(TD No change)
	)

	$(TR
	$(TD Alias Parameters)
	$(TD Yes, any symbol can be passed to a template as an alias:
---
void bar(int);
void bar(double);
void foo(T, alias S)(T t)
{
  S(t);
}
// calls bar(double)
foo!(double, bar)(1);
---
)
	$(TD No)
	$(TD No change)
	)

	$(TR
	$(TD Floating Point Parameters)
	$(TD Yes:
---
class Foo(double D)
{
  double x = D;
}
...
Foo!(1.6) F;
---
)
	$(TD No)
	$(TD No change)
	)

	$(TR
	$(TD String Parameters)
	$(TD Yes:
---
void foo(char[] format)(int i)
{
  writefln(format, i);
}
...
foo!("i = %s")(3);
---
)
	$(TD No)
	$(TD No change)
	)

	$(TR
	$(TD Local Class Parameters)
	$(TD Yes)
	$(TD No)
	$(TD Issue N1945)
	)

	$(TR
	$(TD Local Variable Parameters)
	$(TD Yes)
	$(TD No)
	$(TD No change)
	)

	$(TR
	$(TD Parameter Default Values)
	$(TD Yes:
---
class Foo(T = int)
{
  T x;
}
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;class T = int&gt;
  class Foo
{
  T x;
};
)
)
	$(TD No change)
	)

	$(TR
	$(TD Variadic Parameters)
	$(TD Yes, $(LINK2 variadic-function-templates.html, Variadic Templates):
---
void print(A...)(A a)
{
    foreach(t; a)
	writefln(t);
}
---
)
	$(TD No)
	$(TD $(LINK2 http://www.osl.iu.edu/~dgregor/cpp/variadic-templates.pdf, Variadic Templates N2080))
	)

	$(TR
	$(TH Specializations)
	$(TH D)
	$(TH C++98)
	$(TH C++0x)
	)

	$(TR
	$(TD Explicit Specialization)
	$(TD Yes:
---
class Foo(T : int)
{
  T x;
}
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;&gt;
  class Foo&lt;int&gt;
{
  int x;
};
)
)
	$(TD No change)
	)

	$(TR
	$(TD Partial Specialization)
	$(TD Yes:
---
class Foo(T : T*, U)
{
  T x;
}
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;class T, class U&gt;
  class Foo&lt;T*, U&gt;
{
  T x;
};
)
)
	$(TD No change)
	)

	$(TR
	$(TD Partial specialization derived from multiple parameters)
	$(TD Yes:
---
class Foo(T : Bar!(T, U), U)
{
  ...
}
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;class T, class U&gt;
    class Foo&lt; Bar&lt;T,U&gt; &gt;
{
  ...
};
)
)
	$(TD No change)
	)

	$(TR
	$(TD Can specializations exist without a primary template?)
	$(TD Yes)
	$(TD No)
	$(TD No change)
	)

	$(TR
	$(TH Other)
	$(TH D)
	$(TH C++98)
	$(TH C++0x)
	)

	$(TR
	$(TD Exported Templates)
	$(TD Yes, it falls out as a natural consequence of modules)
	$(TD Yes, though only in compilers based on EDG's front end)
	$(TD No change)
	)

	$(TR
	$(TD $(SFINAE))
	$(TD Yes)
	$(TD Yes)
	$(TD No change)
	)

	$(TR
	$(TD Parse Template Definition Bodies before Instantiation)
	$(TD Yes)
	$(TD Not required by Standard, but some implementations do)
	$(TD No change)
	)

	$(TR
	$(TD Overloading Function Templates with Functions)
	$(TD No, but the equivalent can be done with explicitly specialized
	templates:
---
void foo(T)(T t) { }
void foo(T:int)(int t) { }
---
)
	$(TD Yes:
$(CPPCODE2
template&lt;class T&gt;
  void foo(T i) { }
void foo(int t) { }
)
)
	$(TD No change)
	)

	$(TR
	$(TD Implicit Function Template Instantiation)
	$(TD Yes)
	$(TD Yes)
	$(TD No change)
	)

	$(TR
	$(TD Templates can be evaluated in scope
	  of instantiation rather than definition)
	$(TD Yes, $(LINK2 mixin.html, Mixins))
	$(TD No, but can be faked using macros)
	$(TD No change)
	)

	$(TR
	$(TH Parsing Idiosyncracies)
	$(TH D)
	$(TH C++98)
	$(TH C++0x)
	)



	$(TR
	$(TD Context-Free Grammar)
	$(TD Yes:
---
class Foo!(int i)
{
   ...
}
Foo!(3 $(B >) 4) f;
---
)
	$(TD No:
$(CPPCODE2
template&lt;int i&gt; class Foo
{
   ...
};
Foo&lt;3 $(B &gt;) 4&gt; f; // $(ERROR)
)
)
	$(TD No change)
	)


	$(TR
	$(TD Distinguish template arguments from other operators)
	$(TD Yes:
---
class Foo!(T)
{
   ...
}
class Bar!(int i)
{
   ...
}
Foo!(Bar!(1)) x1;
---
)
	$(TD No:
$(CPPCODE2
template&lt;class T&gt; class Foo
{
   ...
};
template&lt;int i&gt; class Bar
{
   ...
};
Foo&lt;Bar&lt;1&gt;&gt; x1; // $(ERROR)
Foo&lt;Bar&lt;1&gt; &gt; x2;
)
)
	$(TD Partially fixed by
	$(LINK2 http://www.open-std.org/JTC1/SC22/WG21/docs/papers/2005/n1757.html, Right Angle Brackets N1757)
	)

	)


	$(TR
	$(TD Redeclaration of Template Parameter)
	$(TD Yes:
---
class Foo(T)
{
  int T;
  void foo()
  {
    int T;
  }
}
---
)
	$(TD No:
$(CPPCODE2
template&lt;class T&gt;
  class Foo
{
  int T; // $(ERROR)
  void foo()
  {
    int T; // $(ERROR)
  }
};
)
)
	$(TD No change)
	)

	$(TR
	$(TD Dependent Base Class Lookup)
	$(TD Yes:
---
class Foo(T)
{
  typedef int $(B A);
}
class Bar(T) : Foo(T)
{
  $(B A) x;
}
---
)
	$(TD No:
$(CPPCODE2
template&lt;class T&gt;
  class Foo
{
  public:
    typedef int $(B A);
};
template&lt;class T&gt;
  class Bar : Foo&lt;T&gt;
{
  public:
    $(B A) x; // $(ERROR)
};
)
)
	$(TD No change)
	)




	$(TR
	$(TD Forward Referencing)
	$(TD Yes:
---
int $(B g)(void *);

class Foo(T)
{
  int foo()
  {
    return $(B g)(1);
  }
}

int $(B g)(int i);
---
)
	$(TD No:
$(CPPCODE2
int $(B g)(void *);

template&lt;class T&gt;
  class Foo
{
  int foo()
  {
    return $(B g)(1); // $(ERROR)
  }
};

int $(B g)(int i);
)
)
	$(TD No change)
	)


	$(TR
	$(TD Member templates parseable without hints)
	$(TD Yes:
---
class Foo
{
    Foo bar!(int I)();
}
void abd(T)(T f)
{
  T f1 = f.bar!(3)();
}
---
)
	$(TD No:
$(CPPCODE2
class Foo
{
  public:
    template&lt;int&gt; Foo *bar();
};
template&lt;class T&gt; void abc(T *f)
{
  T *f1 = f-&gt;bar&lt;3&gt;(); // $(ERROR)
  T *f2 = f-&gt;$(B template) bar&lt;3&gt;();
}
)
)
	$(TD No change)
	)


	$(TR
	$(TD Dependent type members parseable without hints)
	$(TD Yes:
---
class Foo(T)
{
  T.A* a1;
}
---
)
	$(TD No:
$(CPPCODE2
template<class T> class Foo
{
  public:
    T::A *a1; // $(ERROR)
    $(B typename) T::A *a2;
};
)
)
	$(TD No change)
	)

	</tbody>
	</table>

)

Macros:
	TITLE=Template Comparison
	WIKI=TemplateComparison
	NO=<td class="compNo">No</td>
	NO1=<td class="compNo"><a href="$1">No</a></td>
	YES=<td class="compYes">Yes</td>
	YES1=<td class="compYes"><a href="$1">Yes</a></td>
	D_CODE = <pre class="d_code2">$0</pre>
	CPPCODE2 = <pre class="cppcode2">$0</pre>
	ERROR = $(RED $(B error))
META_KEYWORDS=D Programming Language, template metaprogramming,
variadic templates, type deduction, dependent base class
META_DESCRIPTION=Comparison of templates between the
D programming language, C++, and C++0x
