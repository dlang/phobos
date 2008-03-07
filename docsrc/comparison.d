Ddoc

$(COMMUNITY $(D) vs Other Languages,

	$(BLOCKQUOTE
	To D, or not to D. -- Willeam NerdSpeare
	)

	$(P This table is a quick and rough list of various features of
	$(D)
	that can be used to compare with other languages.
	While many capabilities are available with standard libraries, this
	table is for features built in to the core language itself.
	$(LINK2 builtin.html, Rationale).
	)

	<table border=2 cellpadding=4 cellspacing=0 class="comp">
	<caption>D Language Feature Comparison Table</caption>

	<thead>
	$(TR
	<th>Feature</th>
	<th align="center"><a href="index.html" title="D Programming Language"  target="_top">$(D)</a></th>
	)
	</thead>

	<tbody>

	$(TR
	$(TD <a href="#GarbageCollection">Garbage Collection</a>)
	$(YES1 garbage.html)
	)

	$(TR
	<th colspan="6" align="left"> Functions</th>
	)

	$(TR
	$(TD Function delegates)
	$(YES1 type.html#delegates)
	)

	$(TR
	$(TD Function overloading)
	$(YES1 function.html#overload)
	)

	$(TR
	$(TD Out function parameters)
	$(YES1 function.html#parameters)
	)

	$(TR
	$(TD Nested functions)
	$(YES1 function.html#nested)
	)

	$(TR
	$(TD Function literals)
	$(YES1 expression.html#FunctionLiteral)
	)

	$(TR
	$(V1 $(TD Dynamic closures))
	$(V2 $(TD Closures))
	$(YES1 function.html#closures)
	)

	$(TR
	$(TD Typesafe variadic arguments)
	$(YES1 function.html#variadic)
	)

	$(TR
	$(TD Lazy function argument evaluation)
	$(YES1 lazy-evaluation.html)
	)

	$(TR
	$(TD Compile time function evaluation)
	$(YES1 function.html#interpretation)
	)

	$(TR
	<th colspan="6" align="left"> Arrays</th>
	)

	$(TR
	$(TD Lightweight arrays)
	$(YES1 arrays.html)
	)

	$(TR
	$(TD <a href="#ResizeableArrays">Resizeable arrays</a>)
	$(YES1 arrays.html#resize)
	)

	$(TR
	$(TD <a href="#BuiltinStrings">Built-in strings</a>)
	$(YES1 arrays.html#strings)
	)

	$(TR
	$(TD Array slicing)
	$(YES1 arrays.html#slicing)
	)

	$(TR
	$(TD Array bounds checking)
	$(YES1 arrays.html#bounds)
	)

	$(TR
	$(TD Array literals)
	$(YES1 expression.html#ArrayLiteral)
	)

	$(TR
	$(TD Associative arrays)
	$(YES1 arrays.html#associative)
	)

	$(TR
	$(TD <a href="#StrongTypedefs">Strong typedefs</a>)
	$(YES1 declaration.html#typedef)
	)

	$(TR
	$(TD String switches)
	$(YES1 statement.html#SwitchStatement)
	)

	$(TR
	$(TD Aliases)
	$(YES1 declaration.html#alias)
	)

	$(TR
	<th colspan="6" align="left"> OOP</th>
	)

	$(TR
	$(TD <a href="#ObjectOriented">Object Oriented</a>)
	$(YES)
	)

	$(TR
	$(TD Multiple Inheritance)
	$(NO)
	)

	$(TR
	$(TD <a href="#Interfaces">Interfaces</a>)
	$(YES1 interface.html)
	)

	$(TR
	$(TD Operator overloading)
	$(YES1 operatoroverloading.html)
	)

	$(TR
	$(TD <a href="#Modules">Modules</a>)
	$(YES1 module.html)
	)

	$(TR
	$(TD Dynamic class loading)
	$(NO)
	)

	$(TR
	$(TD Nested classes</a>)
	$(YES1 class.html#nested)
	)

	$(TR
	$(TD <a href="#innerclasses">Inner (adaptor) classes</a>)
	$(YES1 class.html#nested)
	)

	$(TR
	$(TD Covariant return types)
	$(YES1 function.html)
	)

	$(TR
	$(TD Properties)
	$(YES1 property.html#classproperties)
	)

	$(TR
	<th colspan="6" align="left"> Performance</th>
	)

	$(TR
	$(TD <a href="#InlineAssembler">Inline assembler</a>)
	$(YES1 iasm.html)
	)

	$(TR
	$(TD Direct access to hardware)
	$(YES)
	)

	$(TR
	$(TD Lightweight objects)
	$(YES1 struct.html)
	)

	$(TR
	$(TD Explicit memory allocation control)
	$(YES1 memory.html)
	)

	$(TR
	$(TD Independent of VM)
	$(YES)
	)

	$(TR
	$(TD  Direct native code gen)
	$(YES)
	)

	$(TR
	<th colspan="6" align="left"> Generic Programming</th>
	)

	$(TR
	$(TD Class Templates)
	$(YES1 template.html)
	)

	$(TR
	$(TD Function Templates)
	$(YES1 template.html)
	)

	$(TR
	$(TD Implicit Function Template Instantiation)
	$(YES1 template.html)
	)

	$(TR
	$(TD Partial and Explicit Specialization)
	$(YES1 template.html)
	)

	$(TR
	$(TD Value Template Parameters)
	$(YES1 template.html)
	)

	$(TR
	$(TD Template Template Parameters)
	$(YES1 template.html)
	)

	$(TR
	$(TD Variadic Template Parameters)
	$(YES1 template.html)
	)

	$(TR
	$(TD <a href="#mixins">Mixins</a>)
	$(YES1 template-mixin.html)
	)

	$(TR
	$(TD <a href="#staticif">static if</a>)
	$(YES1 version.html#staticif)
	)

	$(TR
	$(TD <a href="#isexpression">is expressions</a>)
	$(YES1 expression.html#IsExpression)
	)

	$(TR
	$(TD typeof)
	$(YES1 declaration.html#Typeof)
	)

	$(TR
	$(TD foreach)
	$(YES1 statement.html#ForeachStatement)
	)

	$(TR
	$(TD <a href="#ImplicitTypeInference">Implicit Type Inference</a>)
	$(YES1 declaration.html#AutoDeclaration)
	)

	$(TR
	<th colspan="6" align="left"> Reliability</th>
	)

	$(TR
	$(TD <a href="#Contracts">Contract Programming</a>)
	$(YES1 dbc.html)
	)

	$(TR
	$(TD Unit testing)
	$(YES1 class.html#unittest)
	)

	$(TR
	$(TD Static construction order)
	$(YES1 module.html#staticorder)
	)

	$(TR
	$(TD Guaranteed initialization)
	$(YES1 statement.html#DeclarationStatement)
	)

	$(TR
	$(TD RAII (automatic destructors))
	$(YES1 memory.html#raii)
	)

	$(TR
	$(TD Exception handling)
	$(YES1 statement.html#TryStatement)
	)

	$(TR
	$(TD <a href="exception-safe.html">Scope guards</a>)
	$(YES1 statement.html#ScopeGuardStatement)
	)

	$(TR
	$(TD try-catch-finally blocks)
	$(YES1 statement.html#TryStatement)
	)

	$(TR
	$(TD Thread synchronization primitives)
	$(YES1 statement.html#SynchronizedStatement)
	)

	$(TR
	<th colspan="6" align="left"> Compatibility</th>
	)

	$(TR
	$(TD C-style syntax)
	$(YES)
	)

	$(TR
	$(TD Enumerated types)
	$(YES1 enum.html)
	)

	$(TR
	$(TD <a href="#Ctypes">Support all C types</a>)
	$(YES1 type.html)
	)

	$(TR
	$(TD <a href="#LongDouble">80 bit floating point</a>)
	$(YES1 type.html)
	)

	$(TR
	$(TD Complex and Imaginary)
	$(YES1 type.html)
	)

	$(TR
	$(TD Direct access to C)
	$(YES1 attribute.html#linkage)
	)

	$(TR
	$(TD <a href="#debuggers">Use existing debuggers</a>)
	$(YES)
	)

	$(TR
	$(TD <a href="#StructMemberAlignmentControl">Struct member alignment control</a>)
	$(YES1 attribute.html#align)
	)

	$(TR
	$(TD Generates standard object files)
	$(YES)
	)

	$(TR
	$(TD Macro text preprocessor)
	$(NO1 pretod.html)
	)

	$(TR
	<th colspan="6" align="left"> Other</th>
	)

	$(TR
	$(TD Conditional compilation)
	$(YES1 version.html)
	)

	$(TR
	$(TD Unicode source text)
	$(YES1 lex.html)
	)

	$(TR
	$(TD <a href="#DocComments">Documentation comments</a>)
	$(YES1 ddoc.html)
	)

	</tbody>

	</table>

$(SECTION2 Notes,

	<dl>

	<dt><a name="ObjectOriented">Object Oriented</a>
	<dd>This means support for classes, member functions,
	inheritance, and virtual function dispatch.
	<p>

	<dt><a name="InlineAssembler">Inline assembler</a>
	<dd> Many C and C++ compilers support an inline assembler, but
	this is not a standard part of the language, and implementations
	vary widely in syntax and quality.
	<p>

	<dt><a name="Interfaces">Interfaces</a>
	<dd> Support in C++ for interfaces is weak enough that an
	IDL (Interface Description Language) was invented to compensate.
	<p>

	<dt><a name="Modules">Modules</a>
	<dd> Many correctly argue that C++ doesn't really have modules.
	But C++ namespaces coupled with header files share many features
	with modules.
	<p>

	<dt><a name="GarbageCollection">Garbage Collection</a>
	<dd> The Hans-Boehm garbage collector can be successfully used
	with C and C++, but it is not a standard part of the language.
	<p>

	<dt><a name="ImplicitTypeInference">Implicit Type Inference</a>
	<dd> This refers to the ability to pick up the type of a
	declaration from its initializer.
	<p>

	<dt><a name="Contracts">Contract Programming</a>
	<dd>The Digital Mars C++ compiler supports
	<a href="../ctg/contract.html">Contract Programming</a>
	as an extension.
	Compare some <a href="cppdbc.html">C++ techniques</a> for
	doing Contract Programming with D.
	<p>

	<dt><a name="ResizeableArrays">Resizeable arrays</a>
	<dd>Part of the standard library for C++ implements resizeable
	arrays, however, they are not part of the core language.
	A conforming freestanding implementation of C++ (C++98 17.4.1.3) does
	not need to provide these libraries.
	<p>

	<dt><a name="BuiltinStrings">Built-in Strings</a>
	<dd>Part of the standard library for C++ implements strings,
	however, they are not part of the core language.
	A conforming freestanding implementation of C++ (C++98 17.4.1.3) does
	not need to provide these libraries.
	Here's a <a href="cppstrings.html">comparison</a> of C++ strings
	and D built-in strings.
	<p>

	<dt><a name="StrongTypedefs">Strong typedefs</a>
	<dd>Strong typedefs can be emulated in C/C++ by wrapping a type
	in a struct. Getting this to work right requires much tedious
	programming, and so is considered as not supported.
	<p>

	<dt><a name="debuggers">Use existing debuggers</a>
	<dd>By this is meant using common debuggers that can operate
	using debug data in common formats embedded in the executable.
	A specialized debugger useful only with that language is not required.
	<p>

	<dt><a name="StructMemberAlignmentControl">Struct member alignment control</a>
	<dd>Although many C/C++ compilers contain pragmas to specify
	struct alignment, these are nonstandard and incompatible from
	compiler to compiler.<br>
	The C# standard ECMA-334 25.5.8 says only this about struct member
	alignment:
	$(I "The order in which members are packed
	into a struct is unspecified. For alignment purposes, there may be
	unnamed padding at the beginning of a struct, within a struct, and at
	the end of the struct. The contents of the bits used as padding are
	indeterminate.")
	Therefore, although Microsoft may
	have extensions to support specific member alignment, they are not an
	official part of standard C#.
	<p>

	<dt><a name="Ctypes">Support all C types</a>
	<dd>C99 adds many new types not supported by C++.
	<p>

	<dt><a name="LongDouble">80 bit floating point</a>
	<dd>While the standards for C and C++ specify long doubles, few
	compilers (besides Digital Mars C/C++) actually implement
	80 bit (or longer) floating point types.
	<p>

	<dt><a name="mixins">Mixins</a>
	<dd>Mixins have many different meanings in different programming
	languages. <a href="template-mixin.html">D mixins</a> mean taking an arbitrary
	sequence of declarations
	and inserting (mixing) them into the current scope. Mixins can be done
	at the global, class, struct, or local level.
	<p>

	<dt><a name="cppmixins">C++ Mixins</a>
	<dd>C++ mixins refer to a couple different techniques. The first
	is analogous to D's interface classes. The second is to create
	a template of the form:
$(CPPCODE
template &lt;class Base&gt; class Mixin : public Base
{
    ... mixin body ...
}
)
	D mixins are different.
	<p>

	<dt><a name="staticif">Static If</a>
	<dd>The C and C++ preprocessor directive #if would appear to
	be equivalent to the D static if. But there are major and crucial
	differences - the #if does not have access to any of the constants,
	types, or symbols of the program. It can only access preprocessor
	macros.
	See <a href="cpptod.html#metatemplates">this example</a>.
	<p>

	<dt><a name="isexpression">Is Expressions</a>
	<dd>$(I Is expressions) enable conditional compilation based
	on the characteristics of a type. This is done after a fashion in
	C++ using template parameter pattern matching.
	See <a href="cpptod.html#typetraits">this example</a>
	for a comparison of the different approaches.
	<p>

	<dt>Comparison with Ada
	<dd>James S. Rogers has written a
	<a href="http://home.att.net/~jimmaureenrogers/AdaAdditionToDComparisonTable.htm">comparison chart with Ada</a>.
	<p>

	<dt><a name="innerclasses">Inner (adaptor) classes</a>
	<dd>A $(I nested class) is one whose definition is within the scope
	of another class. An $(I inner class) is a nested class that
	can also reference the members and fields of the lexically
	enclosing class; one can think of it as if it contained a 'this'
	pointer to the enclosing class.
	<p>

	<dt><a name="DocComments">Documentation comments</a>
	<dd>Documentation comments refer to a standardized way to produce
	documentation from the source code file using specialized
	comments.

	</dl>
)

$(SECTION2 Errors,

	$(P If I've made any errors in this table, please contact me so
	I can correct them.
	)
)

)

Macros:
	TITLE=Comparison
	WIKI=Comparison
	NO=<td class="compNo">No</td>
	NO1=<td class="compNo"><a href="$1">No</a></td>
	YES=<td class="compYes">Yes</td>
	YES1=<td class="compYes"><a href="$1">Yes</a></td>

