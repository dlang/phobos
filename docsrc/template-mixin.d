Ddoc

$(SPEC_S Template Mixins,

	A $(I TemplateMixin) takes an arbitrary set of declarations from
	the body of a $(I TemplateDeclaration) and inserts them
	into the current context.

$(GRAMMAR
$(I TemplateMixin):
	$(B mixin) $(I TemplateIdentifier) $(B ;)
	$(B mixin) $(I TemplateIdentifier) $(I MixinIdentifier) $(B ;)
	$(B mixin) $(I TemplateIdentifier) $(B !$(LPAREN)) $(I TemplateArgumentList) $(B $(RPAREN)) $(B ;)
	$(B mixin) $(I TemplateIdentifier) $(B !$(LPAREN)) $(I TemplateArgumentList) $(B $(RPAREN)) $(I MixinIdentifier) $(B ;)

$(I MixinIdentifier):
	$(I Identifier)
)

	$(P A $(I TemplateMixin) can occur in declaration lists of modules,
	classes, structs, unions, and as a statement.
	The $(I TemplateIdentifier) refers to a $(I TemplateDeclaration).
	If the $(I TemplateDeclaration) has no parameters, the mixin
	form that has no !($(I TemplateArgumentList))
	can be used.
	)

	$(P Unlike a template instantiation, a template mixin's body is evaluated
	within the scope where the mixin appears, not where the template declaration
	is defined. It is analogous to cutting and pasting the body of
	the template into the location of the mixin. It is useful for injecting
	parameterized 'boilerplate' code, as well as for creating
	templated nested functions, which is not possible with
	template instantiations.
	)

------
template Foo()
{
    int x = 5;
}

$(B mixin Foo;)

struct Bar
{
    $(B mixin Foo;)
}

void test()
{
    writefln("x = %d", x);		// prints 5
    {   Bar b;
	int x = 3;

	writefln("b.x = %d", b.x);	// prints 5
	writefln("x = %d", x);		// prints 3
	{
	    $(B mixin Foo;)
	    writefln("x = %d", x);	// prints 5
	    x = 4;
	    writefln("x = %d", x);	// prints 4
	}
	writefln("x = %d", x);		// prints 3
    }
    writefln("x = %d", x);		// prints 5
}
------

	Mixins can be parameterized:

------
template Foo(T)
{
    T x = 5;
}

$(B mixin Foo!(int);)		// create x of type int
------

	Mixins can add virtual functions to a class:

------
template Foo()
{
    void func() { writefln("Foo.func()"); }
}

class Bar
{
    $(B mixin Foo);
}

class Code : Bar
{
    void func() { writefln("Code.func()"); }
}

void test()
{
    Bar b = new Bar();
    b.func();		// calls Foo.func()

    b = new Code();
    b.func();		// calls Code.func()
}
------

	Mixins are evaluated in the scope of where they appear, not the scope
	of the template declaration:

------
int y = 3;

template Foo()
{
    int abc() { return y; }
}

void test()
{
    int y = 8;
    $(B mixin Foo;)	// local y is picked up, not global y
    assert(abc() == 8);
}
------

	Mixins can parameterize symbols using alias parameters:

------
template Foo(alias b)
{
    int abc() { return b; }
}

void test()
{
    int y = 8;
    $(B mixin Foo!(y);)
    assert(abc() == 8);
}
------

	This example uses a mixin to implement a generic Duff's device
	for an arbitrary statement (in this case, the arbitrary statement
	is in bold). A nested function is generated as well as a
	delegate literal, these can be inlined by the compiler:

------
template duffs_device(alias id1, alias id2, alias s)
{
    void duff_loop()
    {
	if (id1 < id2)
	{
	    typeof(id1) n = (id2 - id1 + 7) / 8;
	    switch ((id2 - id1) % 8)
	    {
		case 0:        do {  s();
		case 7:              s();
		case 6:              s();
		case 5:              s();
		case 4:              s();
		case 3:              s();
		case 2:              s();
		case 1:              s();
				  } while (--n > 0);
	    }
	}
    }
}

void foo() { writefln("foo"); }

void test()
{
    int i = 1;
    int j = 11;

    mixin duffs_device!(i, j, $(B delegate { foo(); }) );
    duff_loop();	// executes foo() 10 times
}
------

<h2>Mixin Scope</h2>

	The declarations in a mixin are 'imported' into the surrounding
	scope. If the name of a declaration in a mixin is the same
	as a declaration in the surrounding scope, the surrounding declaration
	overrides the mixin one:

------
int x = 3;

template Foo()
{
    int x = 5;
    int y = 5;
}

$(B mixin Foo;)
int y = 3;

void test()
{
    writefln("x = %d", x);	// prints 3
    writefln("y = %d", y);	// prints 3
}
------

	If two different mixins are put in the same scope, and each
	define a declaration with the same name, there is an ambiguity
	error when the declaration is referenced:

------
template Foo()
{
    int x = 5;
    void func(int x) { }
}

template Bar()
{
    int x = 4;
    void func() { }
}

$(B mixin Foo;)
$(B mixin Bar;)

void test()
{
    writefln("x = %d", x);	// error, x is ambiguous
    func();		// error, func is ambiguous
}
------
	$(P The call to $(B func()) is ambiguous because
	Foo.func and Bar.func are in different scopes.
	)

	$(P If a mixin has a $(I MixinIdentifier), it can be used to
	disambiguate:
	)
------
int x = 6;

template Foo()
{
    int x = 5;
    int y = 7;
    void func() { }
}

template Bar()
{
    int x = 4;
    void func() { }
}

$(B mixin Foo F;)
$(B mixin Bar B;)

void test()
{
    writefln("y = %d", y);	// prints 7
    writefln("x = %d", x);	// prints 6
    writefln("F.x = %d", F.x);	// prints 5
    writefln("B.x = %d", B.x);	// prints 4
    F.func();			// calls Foo.func
    B.func();			// calls Bar.func
}
------
	$(P Alias declarations can be used to overload together
	functions declared in different mixins:)

-----
template Foo()
{
    void func(int x) {  }
}

template Bar()
{
    void func() {  }
}

mixin Foo!() F;
mixin Bar!() B;

$(B alias F.func func;)
$(B alias B.func func;)

void main()
{
    func();	// calls B.func
    func(1);	// calls F.func
}
-----


	$(P A mixin has its own scope, even if a declaration is overridden
	by the enclosing one:)

------
int x = 4;

template Foo()
{
    int x = 5;
    int bar() { return x; }
}

$(B mixin Foo;)

void test()
{
    writefln("x = %d", x);		// prints 4
    writefln("bar() = %d", bar());	// prints 5
}
------

)

Macros:
	TITLE=Mixins
	WIKI=Mixin

