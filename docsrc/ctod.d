Ddoc

$(COMMUNITY Programming in D for C Programmers,

$(BLOCKQUOTE 
Et tu, D? Then fall, C! -- William Nerdspeare
)

<img src="c1.gif" border=0 align=right alt="ouch!">

$(P Every experienced C programmer accumulates a series of idioms and techniques
which become second nature. Sometimes, when learning a new language, those
idioms can be so comfortable it's hard to see how to do the equivalent in the
new language. So here's a collection of common C techniques, and how to do the
corresponding task in D.
)

$(P Since C does not have object-oriented features, there's a separate section
for object-oriented issues
<a href="cpptod.html">Programming in D for C++ Programmers</a>.
)

$(P The C preprocessor is covered in
$(LINK2 pretod.html, The C Preprocessor vs D).
)

$(UL
	$(LI $(LINK2 #sizeof, Getting the Size of a Type))
	$(LI $(LINK2 #maxmin, Get the max and min values of a type))
	$(LI $(LINK2 #types, Primitive Types))
	$(LI $(LINK2 #floating, Special Floating Point Values))
	$(LI $(LINK2 #modulus, Remainder after division of floating point numbers))
	$(LI $(LINK2 #nans, Dealing with NANs in floating point compares))
	$(LI $(LINK2 #assert, Asserts))
	$(LI $(LINK2 #arrayinit, Initializing all elements of an array))
	$(LI $(LINK2 #arrayloop, Looping through an array))
	$(LI $(LINK2 #arraycreate, Creating an array of variable size))
	$(LI $(LINK2 #strcat, String Concatenation))
	$(LI $(LINK2 #printf, Formatted printing))
	$(LI $(LINK2 #forwardfunc, Forward referencing functions))
	$(LI $(LINK2 #funcvoid, Functions that have no arguments))
	$(LI $(LINK2 #labelledbreak, Labelled break and continue statements))
	$(LI $(LINK2 #goto, Goto Statements))
	$(LI $(LINK2 #tagspace, Struct tag name space))
	$(LI $(LINK2 #stringlookup, Looking up strings))
	$(LI $(LINK2 #align, Setting struct member alignment))
	$(LI $(LINK2 #anonymous, Anonymous Structs and Unions))
	$(LI $(LINK2 #declaring, Declaring struct types and variables))
	$(LI $(LINK2 #fieldoffset, Getting the offset of a struct member))
	$(LI $(LINK2 #unioninit, Union initializations))
	$(LI $(LINK2 #structinit, Struct initializations))
	$(LI $(LINK2 #arrayinit2, Array initializations))
	$(LI $(LINK2 #stringlit, Escaped String Literals))
	$(LI $(LINK2 #ascii, Ascii vs Wide Characters))
	$(LI $(LINK2 #arrayenum, Arrays that parallel an enum))
	$(LI $(LINK2 #typedefs, Creating a new type with typedef))
	$(LI $(LINK2 #structcmp, Comparing structs))
	$(LI $(LINK2 #stringcmp, Comparing strings))
	$(LI $(LINK2 #sort, Sorting arrays))
	$(LI $(LINK2 #volatile, Volatile memory access))
	$(LI $(LINK2 #strings, String literals))
	$(LI $(LINK2 #traversal, Data Structure Traversal))
	$(LI $(LINK2 #ushr, Unsigned Right Shift))
	$(LI $(LINK2 #closures, Dynamic Closures))
	$(LI $(LINK2 #variadic, Variadic Function Parameters))
)

<hr><!-- -------------------------------------------- -->
<h3><a name="sizeof">Getting the Size of a Type</a></h3>

<h4>The C Way</h4>

$(CCODE
sizeof(int)
sizeof(char *)
sizeof(double)
sizeof(struct Foo)
)

<h4>The D Way</h4>

<P>Use the size property:</P>

----------------------------
int.sizeof
(char *).sizeof
double.sizeof
Foo.sizeof
----------------------------

<hr><!-- ============================================ -->
<h3><a name="maxmin">Get the max and min values of a type</a></h3>

<h4>The C Way</h4>

$(CCODE
#include &lt;limits.h&gt;
#include &lt;math.h&gt;

CHAR_MAX
CHAR_MIN
ULONG_MAX
DBL_MIN
)

<h4>The D Way</h4>

----------------------------
char.max
char.min
ulong.max
double.min
----------------------------

<hr><!-- ============================================ -->
<h3><a name="types">Primitive Types</a></h3>

<h4>C to D types</h4>

$(CCODE
bool               =&gt;        bit 
char               =&gt;        char 
signed char        =&gt;        byte 
unsigned char      =&gt;        ubyte 
short              =&gt;        short 
unsigned short     =&gt;        ushort 
wchar_t            =&gt;        wchar 
int                =&gt;        int 
unsigned           =&gt;        uint 
long               =&gt;        int 
unsigned long      =&gt;        uint 
long long          =&gt;        long 
unsigned long long =&gt;        ulong 
float              =&gt;        float 
double             =&gt;        double 
long double        =&gt;        real 
_Imaginary long double =&gt;    ireal
_Complex long double   =&gt;    creal
)
<p>
       Although char is an unsigned 8 bit type, and 
       wchar is an unsigned 16 bit type, they have their own separate types 
       in order to aid overloading and type safety. 
<p>
       Ints and unsigneds in C are of varying size; not so in D. 

<hr><!-- ============================================ -->
<h3><a name="floating">Special Floating Point Values</a></h3>

<h4>The C Way</h4>

$(CCODE
#include &lt;fp.h&gt; 

NAN 
INFINITY 

#include &lt;float.h&gt; 

DBL_DIG 
DBL_EPSILON 
DBL_MANT_DIG 
DBL_MAX_10_EXP 
DBL_MAX_EXP 
DBL_MIN_10_EXP 
DBL_MIN_EXP 
)

<h4>The D Way</h4>

----------------------------
double.nan 
double.infinity 
double.dig 
double.epsilon 
double.mant_dig 
double.max_10_exp 
double.max_exp 
double.min_10_exp 
double.min_exp 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="modulus">Remainder after division of floating point numbers</a></h3>

<h4>The C Way</h4>

$(CCODE
#include &lt;math.h&gt; 

float f = fmodf(x,y); 
double d = fmod(x,y); 
long double r = fmodl(x,y); 
)

<h4>The D Way</h4>

D supports the remainder ('%') operator on floating point operands: 

----------------------------
float f = x % y; 
double d = x % y; 
real r = x % y; 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="nans">Dealing with NANs in floating point compares</a></h3>

<h4>The C Way</h4>

       C doesn't define what happens if an operand to a compare 
       is NAN, and few C compilers check for it (the Digital Mars 
       C compiler is an exception, DM's compilers do check for NAN operands). 

$(CCODE
#include &lt;math.h&gt; 

if (isnan(x) || isnan(y)) 
   result = FALSE; 
else 
   result = (x &lt; y); 
)

<h4>The D Way</h4>

       D offers a full complement of comparisons and operators 
       that work with NAN arguments. 

----------------------------
result = (x < y);        // false if x or y is nan 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="assert">Asserts are a necessary part of any good defensive coding strategy</a></h3>

<h4>The C Way</h4>
<p>
C doesn't directly support assert, but does support __FILE__ 
and __LINE__ from which an assert macro can be built. In fact, 
there appears to be practically no other use for __FILE__ and __LINE__. 

$(CCODE
#include &lt;assert.h&gt; 

assert(e == 0); 
)

<h4>The D Way</h4>

D simply builds assert into the language: 

----------------------------
assert(e == 0); 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="arrayinit">Initializing all elements of an array</a></h3>

<h4>The C Way</h4>

$(CCODE
#define ARRAY_LENGTH        17 
int array[ARRAY_LENGTH]; 
for (i = 0; i &lt; ARRAY_LENGTH; i++) 
   array[i] = value; 
)

<h4>The D Way</h4>

----------------------------
int array[17]; 
array[] = value; 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="arrayloop">Looping through an array</a></h3>

<h4>The C Way</h4>
<p>
       The array length is defined separately, or a clumsy 
       sizeof() expression is used to get the length. 

$(CCODE
#define ARRAY_LENGTH        17 
int array[ARRAY_LENGTH]; 
for (i = 0; i &lt; ARRAY_LENGTH; i++) 
   func(array[i]); 
)

or: 

$(CCODE
int array[17]; 
for (i = 0; i &lt; sizeof(array) / sizeof(array[0]); i++) 
   func(array[i]); 
)

<h4>The D Way</h4>

The length of an array is accessible through the property "length". 

----------------------------
int array[17]; 
for (i = 0; i < array.length; i++) 
   func(array[i]); 
----------------------------

or even better:

----------------------------
int array[17]; 
foreach (int value; array)
   func(value); 
----------------------------


<hr><!-- ============================================ -->
<h3><a name="arraycreate">Creating an array of variable size</a></h3>

<h4>The C Way</h4>

       C cannot do this with arrays. It is necessary to create a separate 
       variable for the length, and then explicitly manage the size of 
       the array: 

$(CCODE
#include &lt;stdlib.h&gt; 

int array_length; 
int *array; 
int *newarray; 

newarray = (int *)
   realloc(array, (array_length + 1) * sizeof(int)); 
if (!newarray) 
   error("out of memory"); 
array = newarray; 
array[array_length++] = x; 
)

<h4>The D Way</h4>

       D supports dynamic arrays, which can be easily resized. D supports 
       all the requisite memory management. 

----------------------------
int[] array; 

array.length = array.length + 1;
array[array.length - 1] = x; 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="strcat">String Concatenation</a></h3>

<h4>The C Way</h4>

       There are several difficulties to be resolved, like 
       when can storage be freed, dealing with null pointers, 
       finding the length of the strings, and memory allocation: 

$(CCODE
#include &lt;string.h&gt; 

char *s1; 
char *s2; 
char *s; 

// Concatenate s1 and s2, and put result in s 
free(s); 
s = (char *)malloc((s1 ? strlen(s1) : 0) + 
		  (s2 ? strlen(s2) : 0) + 1); 
if (!s) 
   error("out of memory"); 
if (s1) 
   strcpy(s, s1); 
else 
   *s = 0; 
if (s2) 
   strcpy(s + strlen(s), s2); 

// Append "hello" to s 
char hello[] = "hello"; 
char *news; 
size_t lens = s ? strlen(s) : 0; 
news = (char *)
   realloc(s, (lens + sizeof(hello) + 1) * sizeof(char)); 
if (!news) 
   error("out of memory"); 
s = news; 
memcpy(s + lens, hello, sizeof(hello)); 
)

<h4>The D Way</h4>

       D overloads the operators ~ and ~= for char and wchar arrays to mean 
       concatenate and append, respectively: 

----------------------------
char[] s1; 
char[] s2; 
char[] s; 

s = s1 ~ s2; 
s ~= "hello"; 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="printf">Formatted printing</a></h3>

<h4>The C Way</h4>

       printf() is the general purpose formatted print routine: 

$(CCODE
#include &lt;stdio.h&gt; 

printf("Calling all cars %d times!\n", ntimes); 
)

<h4>The D Way</h4>

       What can we say? printf() rules: 

----------------------------
printf("Calling all cars %d times!\n", ntimes); 
----------------------------

	writefln() improves on printf() by being type-aware and type-safe:

-----------------------
import std.stdio;

writefln("Calling all cars %s times!", ntimes); 
-----------------------

<hr><!-- ============================================ -->
<h3><a name="forwardfunc">Forward referencing functions</a></h3>

<h4>The C Way</h4>

       Functions cannot be forward referenced. Hence, to call a function 
       not yet encountered in the source file, it is necessary to insert 
       a function declaration lexically preceding the call. 

$(CCODE
void forwardfunc(); 

void myfunc() 
{   
   forwardfunc(); 
} 

void forwardfunc() 
{   
   ... 
} 
)

<h4>The D Way</h4>

	The program is looked at as a whole, and so not only is it not 
	necessary to code forward declarations, it is not even allowed! 
	D avoids the tedium and errors associated with writing forward 
	referenced function declarations twice. 
	Functions can be defined in any order.

----------------------------
void myfunc() 
{   
   forwardfunc(); 
} 

void forwardfunc() 
{   
   ... 
} 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="funcvoid">Functions that have no arguments</a></h3>

<h4>The C Way</h4>

$(CCODE
void function(void); 
)

<h4>The D Way</h4>

       D is a strongly typed language, so there is no need to explicitly 
       say a function takes no arguments, just don't declare it has having 
       arguments. 

----------------------------
void function()
{
   ...
}
----------------------------

<hr><!-- ============================================ -->
<h3><a name="labelledbreak">Labelled break and continue statements</a></h3>

<h4>The C Way</h4>

       Break and continue statements only apply to the innermost nested loop or 
       switch, so a multilevel break must use a goto: 

$(CCODE
    for (i = 0; i &lt; 10; i++) 
    {   
       for (j = 0; j &lt; 10; j++) 
       {   
	   if (j == 3) 
	       goto Louter; 
	   if (j == 4) 
	       goto L2; 
       } 
     L2: 
       ; 
    } 
Louter: 
    ; 
)

<h4>The D Way</h4>

       Break and continue statements can be followed by a label. The label 
       is the label for an enclosing loop or switch, and the break applies 
       to that loop. 

----------------------------
Louter: 
   for (i = 0; i < 10; i++) 
   {   
       for (j = 0; j < 10; j++) 
       {   
	   if (j == 3) 
	       break Louter; 
	   if (j == 4) 
	       continue Louter; 
       } 
   } 
   // break Louter goes here 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="goto">Goto Statements</a></h3>

<h4>The C Way</h4>

       The much maligned goto statement is a staple for professional C coders.
       It's 
       necessary to make up for sometimes inadequate control flow statements. 

<h4>The D Way</h4>

       Many C-way goto statements can be eliminated with the D feature of
       labelled 
       break and continue statements. But D is a practical language for
       practical 
       programmers who know when the rules need to be broken. So of course D
       supports goto statements. 

<hr><!-- ============================================ -->
<h3><a name="tagspace">Struct tag name space</a></h3>

<h4>The C Way</h4>

       It's annoying to have to put the struct keyword every time a type is specified, 
       so a common idiom is to use: 

$(CCODE
typedef struct ABC { ... } ABC; 
)

<h4>The D Way</h4>

       Struct tag names are not in a separate name space, they are in the same name 
       space as ordinary names. Hence: 

----------------------------
struct ABC { ... }
----------------------------

<hr><!-- ============================================ -->
<h3><a name="stringlookup">Looking up strings</a></h3>

<h4>The C Way</h4>

       Given a string, compare the string against a list of possible 
       values and take action based on which one it is. A typical use 
       for this might be command line argument processing. 

$(CCODE
#include &lt;string.h&gt; 
void dostring(char *s) 
{   
   enum Strings { Hello, Goodbye, Maybe, Max }; 
   static char *table[] = { "hello", "goodbye", "maybe" }; 
   int i; 

   for (i = 0; i &lt; Max; i++) 
   {   
       if (strcmp(s, table[i]) == 0) 
	   break; 
   } 
   switch (i) 
   {   
       case Hello:   ... 
       case Goodbye: ... 
       case Maybe:   ... 
       default:      ... 
   } 
} 
)

       The problem with this is trying to maintain 3 parallel data 
       structures, the enum, the table, and the switch cases. If there 
       are a lot of values, the connection between the 3 may not be so 
       obvious when doing maintenance, and so the situation is ripe for 
       bugs. 

       Additionally, if the number of values becomes large, a binary or 
       hash lookup will yield a considerable performance increase over 
       a simple linear search. But coding these can be time consuming, 
       and they need to be debugged. It's typical that such just never 
       gets done. 

<h4>The D Way</h4>

       D extends the concept of switch statements to be able to handle 
       strings as well as numbers. Then, the way to code the string 
       lookup becomes straightforward: 

----------------------------
void dostring(char[] s) 
{   
   switch (s) 
   {   
       case "hello":   ... 
       case "goodbye": ... 
       case "maybe":   ... 
       default:        ... 
   } 
} 
----------------------------

       Adding new cases becomes easy. The compiler can be relied on 
       to generate a fast lookup scheme for it, eliminating the bugs 
       and time required in hand-coding one. 

<hr><!-- ============================================ -->
<h3><a name="align">Setting struct member alignment</a></h3>

<h4>The C Way</h4>

       It's done through a command line switch which affects the entire 
       program, and woe results if any modules or libraries didn't get 
       recompiled. To address this, $(TT #pragma)s are used: 

$(CCODE
#pragma pack(1) 
struct ABC 
{   
   ... 
}; 
#pragma pack() 
)

       But #pragmas are nonportable both in theory and in practice from 
       compiler to compiler. 

<h4>The D Way</h4>

       Clearly, since much of the point to setting alignment is for 
       portability of data, a portable means of expressing it is necessary. 

----------------------------
struct ABC 
{   
   int z;               // z is aligned to the default 

 align (1) int x;       // x is byte aligned 
 align (4) 
 {   
   ...                  // declarations in {} are dword aligned 
 } 
 align (2):             // switch to word alignment from here on 

   int y;               // y is word aligned 
} 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="anonymous">Anonymous Structs and Unions</a></h3>

Sometimes, it's nice to control the layout of a struct with nested structs and unions. 

<h4>The C Way</h4>

       C doesn't allow anonymous structs or unions, which means that dummy tag names 
       and dummy members are necessary: 

$(CCODE
struct Foo 
{
   int i; 
   union Bar 
   {
      struct Abc { int x; long y; } _abc; 
      char *p; 
   } _bar; 
}; 

#define x _bar._abc.x 
#define y _bar._abc.y 
#define p _bar.p 

struct Foo f; 

f.i; 
f.x; 
f.y; 
f.p; 
)

       Not only is it clumsy, but using macros means a symbolic debugger won't understand 
       what is being done, and the macros have global scope instead of struct scope. 

<h4>The D Way</h4>

       Anonymous structs and unions are used to control the layout in a 
       more natural manner: 

----------------------------
struct Foo 
{
   int i; 
   union 
   {
      struct { int x; long y; } 
      char* p; 
   } 
} 

Foo f; 

f.i; 
f.x; 
f.y; 
f.p; 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="declaring">Declaring struct types and variables</a></h3>

<h4>The C Way</h4>

	$(P Is to do it in one statement ending with a semicolon:)

$(CCODE
struct Foo { int x; int y; } foo; 
)

	$(P Or to separate the two:)

$(CCODE
struct Foo { int x; int y; };   // note terminating ; 
struct Foo foo; 
)

<h4>The D Way</h4>

	$(P Struct definitions and declarations can't be done in the same
	statement:
	)

----------------------------
struct Foo { int x; int y; }    // note there is no terminating ; 
Foo foo; 
----------------------------

	$(P which means that the terminating ; can be dispensed with,
	eliminating the confusing difference between struct {} and function
	block {} in how semicolons are used.
	)

<hr><!-- ============================================ -->
<h3><a name="fieldoffset">Getting the offset of a struct member</a></h3>

<h4>The C Way</h4>

       Naturally, another macro is used: 

$(CCODE
#include &lt;stddef&gt; 
struct Foo { int x; int y; }; 

off = offsetof(Foo, y); 
)

<h4>The D Way</h4>

       An offset is just another property: 

----------------------------
struct Foo { int x; int y; } 

off = Foo.y.offsetof; 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="unioninit">Union Initializations</a></h3>

<h4>The C Way</h4>

       Unions are initialized using the "first member" rule: 

$(CCODE
union U { int a; long b; }; 
union U x = { 5 };                // initialize member 'a' to 5 
)

       Adding union members or rearranging them can have disastrous consequences 
       for any initializers. 

<h4>The D Way</h4>

       In D, which member is being initialized is mentioned explicitly: 

----------------------------
union U { int a; long b; } 
U x = { a:5 };
----------------------------

       avoiding the confusion and maintenance problems. 

<hr><!-- ============================================ -->
<h3><a name="structinit">Struct Initializations</a></h3>

<h4>The C Way</h4>

       Members are initialized by their position within the { }s: 

$(CCODE
struct S { int a; int b; }; 
struct S x = { 5, 3 }; 
)

       This isn't much of a problem with small structs, but when there 
       are numerous members, it becomes tedious to get the initializers 
       carefully lined up with the field declarations. Then, if members are 
       added or rearranged, all the initializations have to be found and 
       modified appropriately. This is a minefield for bugs. 

<h4>The D Way</h4>

       Member initialization can be done explicitly: 

----------------------------
struct S { int a; int b; } 
S x = { b:3, a:5 };
----------------------------

       The meaning is clear, and there no longer is a positional dependence. 

<hr><!-- ============================================ -->
<h3><a name="arrayinit2">Array Initializations</a></h3>

<h4>The C Way</h4>

       C initializes array by positional dependence: 
$(CCODE
int a[3] = { 3,2,2 }; 
)
       Nested arrays may or may not have the { }: 
$(CCODE
int b[3][2] = { 2,3, {6,5}, 3,4 }; 
)

<h4>The D Way</h4>

       D does it by positional dependence too, but an index can be used as well.
       The following all produce the same result: 

----------------------------
int[3] a = [ 3, 2, 0 ]; 
int[3] a = [ 3, 2 ];            // unsupplied initializers are 0, just like in C 
int[3] a = [ 2:0, 0:3, 1:2 ]; 
int[3] a = [ 2:0, 0:3, 2 ];     // if not supplied, the index is the
				// previous one plus one. 
----------------------------
       This can be handy if the array will be indexed by an enum, and the order of 
       enums may be changed or added to: 

----------------------------
enum color { black, red, green }
int[3] c = [ black:3, green:2, red:5 ]; 
----------------------------
       Nested array initializations must be explicit: 
----------------------------
int[2][3] b = [ [2,3], [6,5], [3,4] ]; 

int[2][3] b = [[2,6,3],[3,5,4]];            // error 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="stringlit">Escaped String Literals</a></h3>

<h4>The C Way</h4>

       C has problems with the DOS file system because a \ is an escape in a string. To specifiy file c:\root\file.c: 
$(CCODE
char file[] = "c:\\root\\file.c"; 
)
This gets even more unpleasant with regular expressions.
Consider the escape sequence to match a quoted string: 
$(CCODE
/"[^\\]*(\\.[^\\]*)*"/
)
<P>In C, this horror is expressed as: 
$(CCODE
char quoteString[] = "\"[^\\\\]*(\\\\.[^\\\\]*)*\"";
)
<h4>The D Way</h4>

	Within strings, it is WYSIWYG (what you see is what you get).
	Escapes are in separate strings. So: 

----------------------------
char[] file = `c:\root\file.c`; 
char[] quoteString = \"  r"[^\\]*(\\.[^\\]*)*"  \";
----------------------------

       The famous hello world string becomes: 
----------------------------
char[] hello = "hello world" \n; 
----------------------------

<hr><!-- ============================================ -->
<h3><a name="ascii">Ascii vs Wide Characters</a></h3>

<P>Modern programming requires that wchar strings be supported in an easy way, for internationalization of the programs. 

<h4>The C Way</h4>

       C uses the wchar_t and the L prefix on strings: 
$(CCODE
#include &lt;wchar.h&gt; 
char foo_ascii[] = "hello"; 
wchar_t foo_wchar[] = L"hello"; 
)
Things get worse if code is written to be both ascii and wchar compatible.
A macro is used to switch strings from ascii to wchar: 
$(CCODE
#include &lt;tchar.h&gt; 
tchar string[] = TEXT("hello"); 
)
<h4>The D Way</h4>

The type of a string is determined by semantic analysis, so there is no need to wrap strings in a macro call: 
-----------------------------
char[] foo_ascii = "hello";        // string is taken to be ascii 
wchar[] foo_wchar = "hello";       // string is taken to be wchar 
-----------------------------

<hr><!-- ============================================ -->
<h3><a name="arrayenum">Arrays that parallel an enum</a></h3>

<h4>The C Way</h4>

       Consider: 
$(CCODE
enum COLORS { red, blue, green, max }; 
char *cstring[max] = {"red", "blue", "green" }; 
)
       This is fairly easy to get right because the number of entries is small. But suppose it gets to be fairly large. Then it can get difficult to maintain correctly when new entries are added. 

<h4>The D Way</h4>
-----------------------------
enum COLORS { red, blue, green }

char[][COLORS.max + 1] cstring = 
[
    COLORS.red   : "red",
    COLORS.blue  : "blue", 
    COLORS.green : "green",
]; 
-----------------------------

Not perfect, but better. 

<hr><!-- ============================================ -->
<h3><a name="typedefs">Creating a new type with typedef</a></h3>

<h4>The C Way</h4>

	Typedefs in C are weak, that is, they really do not introduce
	a new type. The compiler doesn't distinguish between a typedef
	and its underlying type.

$(CCODE
typedef void *Handle;
void foo(void *);
void bar(Handle);

Handle h;
foo(h);			// coding bug not caught
bar(h);			// ok
)

	The C solution is to create a dummy struct whose sole
	purpose is to get type checking and overloading on the new type.

$(CCODE
struct Handle__ { void *value; }
typedef struct Handle__ *Handle;
void foo(void *);
void bar(Handle);

Handle h;
foo(h);			// syntax error
bar(h);			// ok
)

	Having a default value for the type involves defining a macro,
	a naming convention, and then pedantically following that convention:

$(CCODE
#define HANDLE_INIT ((Handle)-1)

Handle h = HANDLE_INIT;
h = func();
if (h != HANDLE_INIT)
    ...
)

	For the struct solution, things get even more complex:

$(CCODE
struct Handle__ HANDLE_INIT;

void init_handle()	// call this function upon startup
{
    HANDLE_INIT.value = (void *)-1;
}

Handle h = HANDLE_INIT;
h = func();
if (memcmp(&h,&HANDLE_INIT,sizeof(Handle)) != 0)
    ...
)

	There are 4 names to remember: $(TT Handle, HANDLE_INIT,
	struct Handle__, value).

<h4>The D Way</h4>

	No need for idiomatic constructions like the above. Just write:

-----------------------------
typedef void* Handle;
void foo(void*);
void bar(Handle);

Handle h;
foo(h);
bar(h);
-----------------------------

	To handle a default value, add an initializer to the typedef,
	and refer to it with the $(TT .init) property:

-----------------------------
typedef void* Handle = cast(void*)(-1);
Handle h;
h = func();
if (h != Handle.init)
    ...
-----------------------------

	There's only one name to remember: $(TT Handle).

<hr><!-- ============================================ -->
<h3><a name="structcmp">Comparing structs</a></h3>

<h4>The C Way</h4>

	While C defines struct assignment in a simple, convenient manner:

$(CCODE
struct A x, y;
...
x = y;
)

	it does not for struct comparisons. Hence, to compare two struct
	instances for equality:

$(CCODE
#include &lt;string.h&gt;

struct A x, y;
...
if (memcmp(&x, &y, sizeof(struct A)) == 0)
    ...
)

	Note the obtuseness of this, coupled with the lack of any kind
	of help from the language with type checking.
	<p>

	There's a nasty bug lurking in the memcmp().
	The layout of a struct, due to alignment, can have 'holes' in it.
	C does not guarantee those holes are assigned any values, and so
	two different struct instances can have the same value for each member,
	but compare different because the holes contain different garbage.

<h4>The D Way</h4>

	D does it the obvious, straightforward way:

-----------------------------
A x, y;
...
if (x == y)
    ...
-----------------------------


<hr><!-- ============================================ -->
<h3><a name="stringcmp">Comparing strings</a></h3>

<h4>The C Way</h4>

	The library function strcmp() is used:
$(CCODE
char string[] = "hello";

if (strcmp(string, "betty") == 0)	// do strings match?
    ...
)

	C uses 0 terminated strings, so the C way has an inherent
	inefficiency in constantly scanning for the terminating 0.

<h4>The D Way</h4>

	Why not use the == operator?

-----------------------------
char[] string = "hello";

if (string == "betty")
    ...
-----------------------------

	D strings have the length stored separately from the string.
	Thus, the implementation of string compares can be much faster
	than in C (the difference being equivalent to the difference
	in speed between the C memcmp() and strcmp()).
	<p>

	D supports comparison operators on strings, too:

-----------------------------
char[] string = "hello";

if (string < "betty")
    ...
-----------------------------

	which is useful for sorting/searching.

<hr><!-- ============================================ -->
<h3><a name="sort">Sorting arrays</a></h3>

<h4>The C Way</h4>

	Although many C programmers tend to reimplmement bubble sorts
	over and over, the right way to sort in C is to use qsort():

$(CCODE
int compare(const void *p1, const void *p2)
{
    type *t1 = (type *)p1;
    type *t2 = (type *)p2;

    return *t1 - *t2;
}

type array[10];
...
qsort(array, sizeof(array)/sizeof(array[0]),
	sizeof(array[0]), compare);
)

	A compare() must be written for each type, and much careful
	typo-prone code needs to be written to make it work.


<h4>The D Way</h4>

	Sorting couldn't be easier:

-----------------------------
type[] array;
...
array.sort;      // sort array in-place
-----------------------------

<hr><!-- ============================================ -->
<h3><a name="volatile">Volatile memory access</a></h3>

<h4>The C Way</h4>

	To access volatile memory, such as shared memory
	or memory mapped I/O, a pointer to volatile is created:
$(CCODE
volatile int *p = address;

i = *p;
)

<h4>The D Way</h4>

	D has volatile as a statement type, not as a type modifier:

-----------------------------
int* p = address;

volatile { i = *p; }
-----------------------------

<hr><!-- ============================================ -->
<h3><a name="strings">String literals</a></h3>

<h4>The C Way</h4>

	String literals in C cannot span multiple lines, so to have
	a block of text it is necessary to use \ line splicing:

$(CCODE
"This text spans\n\
multiple\n\
lines\n"
)

	If there is a lot of text, this can wind up being tedious.

<h4>The D Way</h4>

	String literals can span multiple lines, as in:

-----------------------------
"This text spans
multiple
lines
"
-----------------------------

	So blocks of text can just be cut and pasted into the D
	source.

<hr><!-- ============================================ -->
<h3><a name="traversal">Data Structure Traversal</a></h3>

<h4>The C Way</h4>

    Consider a function to traverse a recursive data structure.
    In this example, there's a simple symbol table of strings.
    The data structure is an array of binary trees.
    The code needs to do an exhaustive search of it to find
    a particular string in it, and determine if it is a unique
    instance.
    <p>

    To make this work, a helper function $(TT membersearchx)
    is needed to recursively
    walk the trees. The helper function needs to read and write
    some context outside of the trees, so a custom $(TT struct Paramblock)
    is created and a pointer to it is used to maximize efficiency.

$(CCODE
struct Symbol
{
   char *id;
   struct Symbol *left;
   struct Symbol *right;
};

struct Paramblock
{
   char *id;
   struct Symbol *sm;
};

static void membersearchx(struct Paramblock *p, struct Symbol *s)
{
   while (s)
   {
      if (strcmp(p->id,s->id) == 0)
      {
         if (p->sm)
            error("ambiguous member %s\n",p->id);
         p->sm = s;
      }

      if (s->left)
         membersearchx(p,s->left);
      s = s->right;
   }
}

struct Symbol *symbol_membersearch(Symbol *table[], int tablemax, char *id)
{
   struct Paramblock pb;
   int i;

   pb.id = id;
   pb.sm = NULL;
   for (i = 0; i < tablemax; i++)
   {
      membersearchx(pb, table[i]);
   }
   return pb.sm;
}
)

<h4>The D Way</h4>

    This is the same algorithm in D, and it shrinks dramatically.
    Since nested functions have access to the lexically enclosing
    function's variables, there's no need for a Paramblock or
    to deal with its bookkeeping details. The nested helper function
    is contained wholly within the function that needs it,
    improving locality and maintainability.
    <p>

    The performance of the two versions is indistinguishable.

-----------------------------
class Symbol
{   char[] id;
    Symbol left;
    Symbol right;
}

Symbol symbol_membersearch(Symbol[] table, char[] id)
{   Symbol sm;

    void membersearchx(Symbol s)
    {
	while (s)
	{
	    if (id == s.id)
	    {
		if (sm)
		    error("ambiguous member %s\n", id);
		sm = s;
	    }

	    if (s.left)
		membersearchx(s.left);
	    s = s.right;
	}
    }

    for (int i = 0; i < table.length; i++)
    {
	membersearchx(table[i]);
    }
    return sm;
}
-----------------------------

<hr><!-- ============================================ -->
<h3><a name="ushr">Unsigned Right Shift</a></h3>

<h4>The C Way</h4>

	The right shift operators &gt;&gt; and &gt;&gt;= are signed
	shifts if the left operand is a signed integral type, and
	are unsigned right shifts if the left operand is an unsigned
	integral type. To produce an unsigned right shift on an int,
	a cast is necessary:

$(CCODE
int i, j;
...
j = (unsigned)i >> 3;
)

	If $(TT i) is an $(TT int), this works fine. But if $(TT i) is
	of a type created with typedef,

$(CCODE
myint i, j;
...
j = (unsigned)i >> 3;
)

	and $(TT myint) happens to be a $(TT long int), then the cast to
	unsigned
	will silently throw away the most significant bits, corrupting
	the answer.

<h4>The D Way</h4>

	D has the right shift operators &gt;&gt; and &gt;&gt;= which
	behave as they do in C. But D also has explicitly unsigned
	right shift operators &gt;&gt;&gt; and &gt;&gt;&gt;= which will
	do an unsigned right shift regardless of the sign of the left
	operand. Hence,

-----------------------------
myint i, j;
...
j = i >>> 3;
-----------------------------

	avoids the unsafe cast and will work as expected with any integral
	type.

<hr><!-- ============================================ -->
<h3><a name="closures">Dynamic Closures</a></h3>

<h4>The C Way</h4>

	Consider a reusable container type. In order to be reusable,
	it must support a way to apply arbitrary code to each element
	of the container. This is done by creating an $(I apply) function
	that accepts a function pointer to which is passed each
	element of the container contents.
	<p>

	A generic context pointer is also needed, represented here by
	$(TT void *p). The example here is of a trivial container
	class that holds an array of ints, and a user of that container
	that computes the maximum of those ints.

$(CCODE
struct Collection
{
    int array[10];

    void apply(void *p, void (*fp)(void *, int))
    {
	for (int i = 0; i < sizeof(array)/sizeof(array[0]); i++)
	    fp(p, array[i]);
    }
};

void comp_max(void *p, int i)
{
    int *pmax = (int *)p;

    if (i > *pmax)
	*pmax = i;
}

void func(Collection *c)
{
    int max = INT_MIN;

    c->apply(&amp;max, comp_max);
}
)

	The C way makes heavy use of pointers and casting.
	The casting is tedious, error prone, and loses all type safety.

<h4>The D Way</h4>

	The D version makes use of $(I delegates) to transmit
	context information for the $(I apply) function,
	and $(I nested functions) both to capture context
	information and to improve locality.

----------------------------
class Collection
{
    int[10] array;

    void apply(void delegate(int) fp)
    {
	for (int i = 0; i < array.length; i++)
	    fp(array[i]);
    }
}

void func(Collection c)
{
    int max = int.min;

    void comp_max(int i)
    {
	if (i > max)
	    max = i;
    }

    c.apply(comp_max);
}
-----------------------------

	Pointers are eliminated, as well as casting and generic
	pointers. The D version is fully type safe.
	An alternate method in D makes use of $(I function literals):

-----------------------------
void func(Collection c)
{
    int max = int.min;

    c.apply(delegate(int i) { if (i > max) max = i; } );
}
-----------------------------

	eliminating the need to create irrelevant function names.

<hr><!-- ============================================ -->
<h3><a name="variadic">Variadic Function Parameters</a></h3>

	The task is to write a function that takes a varying
	number of arguments, such as a function that sums
	its arguments.

<h4>The C Way</h4>

$(CCODE
#include &lt;stdio.h&gt;
#include &lt;stdarg.h&gt;

int $(B sum)(int dim, ...)
{   int i;
    int s = 0;
    va_list ap;

    va_start(ap, dim);
    for (i = 0; i &lt; dim; i++)
	s += va_arg(ap, int);
    va_end(ap);
    return s;
}

int main()
{
    int i;

    i = $(B sum)(3, 8,7,6);
    printf("sum = %d\n", i);

    return 0;
} 
)

	There are two problems with this. The first is that the
	$(TT sum) function needs to know how many arguments were
	supplied. It has to be explicitly written, and it can get
	out of sync with respect to the actual number of arguments
	written.
	The second is that there's no way to check that the
	types of the arguments provided really were ints, and not
	doubles, strings, structs, etc.

<h4>The D Way</h4>

	The ... following an array parameter declaration means that
	the trailing arguments are collected together to form
	an array. The arguments are type checked against the array
	type, and the number of arguments becomes a property
	of the array:

-----------------------------
import std.stdio;

int $(B sum)(int[] values ...)
{
    int s = 0;

    foreach (int x; values)
	s += x;
    return s;
}

int main()
{
    int i;

    i = $(B sum)(8,7,6);
    writefln("sum = %d", i);

    return 0;
}
-----------------------------
)

Macros:
	TITLE=Programming in D for C Programmers
	WIKI=ctod


