Ddoc

$(D_S Regular Expressions,

	$(P Regular expressions are a powerful tool for
	pattern matching on strings of text. They
	are built in to the core of languages like Perl,
	Ruby, and Javascript. Perl and Ruby are particulary
	reknowned for adroitly handling regular expressions.
	So why aren't they part of the D core language?
	Read on and see how they're done in D compared with Ruby.
	)

	$(P This article explains how to use regular expressions
	in D. It doesn't explain regular expressions themselves,
	after all, people have written entire books on that topic.
	D's specific implementation of regular expressions
	is entirely contained in the Phobos library module
	$(LINK2 phobos/std_regexp.html, std.regexp).
	For a more advanced treatment of using regular expressions
	in conjuction with template metaprogramming, see
	$(LINK2 templates-revisited.html, Templates Revisited).
	)

	$(P In Ruby a regular expression can be created
	as a special literal:
	)

$(RUBY
r = /pattern/
s = /p[1-5]\s*/
)

	$(P D doesn't have special literals for them, but they can
	be created:)

---
r = RegExp("pattern");
s = RegExp(r"p[1-5]\s*");
---

	$(P If the $(I pattern) contains backslash characters \,
	wysiwyg string literals are used, which have the 'r' prefix
	to the string. $(I r) and $(I s) are of type $(B RegExp), but
	we can use type inference to declare and assign them automatically:
	)

---
auto r = RegExp("pattern");
auto s = RegExp(r"p[1-5]\s*");
---
	
	$(P To check for a match of a string $(I s) with a regular expression
	in Ruby, use the =~ operator, which returns the index of the
	first match:)

$(RUBY
s = "abcabcabab"
s =~ /b/   /* match, returns 1 */
s =~ /f/   /* no match, returns nil */
)

	$(P In D this looks like:
	)

---
auto s = "abcabcabab";
std.regexp.find(s, "b");    /* match, returns 1 */
std.regexp.find(s, "f");    /* no match, returns -1 */
---

	$(P Note the equivalence to std.string.find, which searches for
	substring matches rather than regular expression matches.)

	$(P The Ruby =~ operator sets some implicitly defined variables
	based on the result:)

$(RUBY
s = "abcdef"
if s =~ /c/
    "#{$`}[#{$&}]#{$'}"   /* generates string ab[c]def
)

	$(P The function std.regexp.search() returns a RegExp object
	describing the match, which can be exploited:
	)

---
auto m = std.regexp.search("abcdef", "c");
if (m)
    writefln("%s[%s]%s", m.pre, m.match(0), m.post);
---

	$(P Or even more concisely as:
	)

---
if (auto m = std.regexp.search("abcdef", "c"))
    writefln("%s[%s]%s", m.pre, m.match(0), m.post); // writes ab[c]def
---

<h2>Search and Replace</h2>

	$(P Search and replace gets more interesting. To replace the
	occurrences of "a" with "ZZ" in Ruby; the first occurrence, then
	all:
	)

$(RUBY
s = "Strap a rocket engine on a chicken."
s.sub(/a/, "ZZ") // result: StrZZp a rocket engine on a chicken.
s.gsub(/a/, "ZZ") // result: StrZZp ZZ rocket engine on ZZ chicken.
)

	$(P In D:)

---
s = "Strap a rocket engine on a chicken.";
sub(s, "a", "ZZ");        // result: StrZZp a rocket engine on a chicken.
sub(s, "a", "ZZ", "g");   // result: StrZZp ZZ rocket engine on ZZ chicken.
---

	$(P The replacement string can reference the matches using 
	the $&amp;, $$, $', $`, $0 .. $99 notation:)

---
sub(s, "[ar]", "[$&]", "g"); // result: St[r][a]p [a] [r]ocket engine on [a] chicken.
---

	$(P Or the replacement string can be provided by a delegate:)

---
sub(s, "[ar]",
   (RegExp m) { return toupper(m.match(0)); },
   "g");    // result: StRAp A Rocket engine on A chicken.
---

($(TT toupper()) comes from $(LINK2 phobos/std_string.html, std.string).)

<h2>Looping</h2>

	$(P It's possible to search over all matches within
	a string:)

---
import std.stdio;
import std.regexp;

void main()
{
    foreach(m; RegExp("ab").search("abcabcabab"))
    {
        writefln("%s[%s]%s", m.pre, m.match(0), m.post);
    }
}
// Prints:
// [ab]cabcabab
// abc[ab]cabab
// abcabc[ab]ab
// abcabcab[ab]
---

<h2>Conclusion</h2>

	$(P D regular expression handling is as powerful as Ruby's. But
	its syntax isn't as concise:)

	$(UL

	$(LI Regular expression literal syntax - doing so would
	make it impossible to perform lexical analysis without also
	doing syntactic or semantic analysis.)

	$(LI Implicit naming of match variables - this causes problems
	with name collisions, and just doesn't
	fit with the rest of the way D works.)

	)

	$(P But it is just as powerful.
	)
)
Macros:
	TITLE=Regular Expressions
	WIKI=RegularExpression
	RUBY=$(CCODE $0)
