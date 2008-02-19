Ddoc

$(D_S Code Coverage Analysis,

$(P A major part of the engineering of a professional software project
is creating a test suite for it. Without some sort of test suite,
it is impossible to know if the software works at all.
The D language has
many features to aid in the creation of test suites, such as
$(LINK2 class.html#unittest, unit tests) and
$(LINK2 dbc.html, contract programming).
But there's the issue of how thoroughly the test suite tests
the code.
The $(LINK2 http://www.digitalmars.com/ctg/trace.html, profiler)
can give valuable information on which functions were called, and
by whom. But to look inside a function, and determine which statements
were executed and which were not, requires a code coverage analyzer.
)

$(P A code coverage analyzer will help in these ways:)

$(OL
$(LI Expose code that is not exercised by the test suite.
     Add test cases that will exercise it.)

$(LI Identify code that is unreachable. Unreachable code is often
     the leftover result of program design changes.
     Unreachable code should be removed,
     as it can be very confusing to the maintenance programmer.)

$(LI It can be used to track down why a particular section of code
     exists, as the test case that causes it to execute will
     illuminate why.)

$(LI Since execution counts are given for each line, it is possible
     to use the coverage analysis to reorder the basic blocks in
     a function to minimize jmps in the most used path, thus
     optimizing it.)
)

$(P Experience with code coverage analyzers show that they dramatically
reduce the number of bugs in shipping code.
But it isn't a panacea, a code coverage analyzer won't help with:)

$(OL
$(LI Identifying race conditions.)
$(LI Memory consumption problems.)
$(LI Pointer bugs.)
$(LI Verifying that the program got the correct result.)
)

$(P Code coverage analysers are available for many popular languages
such as C++, but they are often third party products that integrate
poorly with the compiler, and are often very expensive.
A big problem with third party products is, in order to instrument
the source code, they must include what is essentially a full blown
compiler front end for the same language. Not only is this an expensive
proposition, it often winds up out of step with the various compiler
vendors as their implementations change and as they evolve various extensions.
($(LINK2 http://gcc.gnu.org/onlinedocs/gcc-3.0/gcc_8.html, gcov),
the Gnu coverage analyzer, is an exception as it is both free
and is integrated into gcc.)
)

$(P The D code coverage analyser is built in as part of the D compiler.
Therefore, it is always in perfect synchronization with the language
implementation. It's implemented by establishing a counter for each
line in each module compiled with the $(B -cov) switch. Code is inserted
at the beginning of each statement to increment the corresponding counter.
When the program finishes, a static destructor for std.cover collects all
the counters, merges it with the source files, and writes the reports out
to listing (.lst) files.)

$(P For example, consider the Sieve program:)
----------------------
/* Eratosthenes Sieve prime number calculation. */

import std.stdio;

bit flags[8191];
 
int main()
{   int     i, prime, k, count, iter;

    writefln("10 iterations");
    for (iter = 1; iter <= 10; iter++)
    {	count = 0;
	flags[] = true;
	for (i = 0; i < flags.length; i++)
	{   if (flags[i])
	    {	prime = i + i + 3;
		k = i + prime;
		while (k < flags.length)
		{
		    flags[k] = false;
		    k += prime;
		}
		count += 1;
	    }
	}
    }
    writefln("%d primes", count);
    return 0;
}
----------------------

$(P Compile and run it with:)

$(CONSOLE
dmd sieve -cov
sieve
)

$(P The output file will be created called $(TT sieve.lst), the contents of
which are:)

$(CONSOLE
       |/* Eratosthenes Sieve prime number calculation. */
       |
       |import std.stdio;
       |
       |bit flags[8191];
       | 
       |int main()
      5|{   int     i, prime, k, count, iter;
       |
      1|    writefln("10 iterations");
     22|    for (iter = 1; iter <= 10; iter++)
     10|    {   count = 0;
     10|        flags[] = true;
 163840|        for (i = 0; i < flags.length; i++)
  81910|        {   if (flags[i])
  18990|            {   prime = i + i + 3;
  18990|                k = i + prime;
 168980|                while (k < flags.length)
       |                {
 149990|                    flags[k] = false;
 149990|                    k += prime;
       |                }
  18990|                count += 1;
       |            }
       |        }
       |    }
      1|    writefln("%d primes", count);
      1|    return 0;
       |}
sieve.d is 100% covered
)

$(P The numbers to the left of the $(B |) are the execution counts for that
line. Lines that have no executable code are left blank.
Lines that have executable code, but were not executed, have a "0000000"
as the execution count.
At the end of the .lst file, the percent coverage is given.
)

$(P There are 3 lines with an exection count
of 1, these were each executed once. The declaration line for $(TT i, prime),
etc., has 5 because there are 5 declarations, and the initialization of
each declaration counts as one statement.)

$(P The first $(TT for) loop shows 22. This is the sum of the 3 parts
of the for header. If the for header is broken up into 3 lines, the
data is similarly divided:)

$(CONSOLE
      1|    for (iter = 1;
     11|         iter <= 10;
     10|         iter++)
)

$(P which adds up to 22.)

$(P $(TT e1&amp;&amp;e2) and $(TT e1||e2) expressions conditionally
execute the rvalue $(TT e2).
Therefore, the rvalue is treated as a separate statement with its own
counter:)

$(CONSOLE
        |void foo(int a, int b)
        |{
       5|   bar(a);
       8|   if (a && b)
       1|	bar(b);
        |}
)

$(P By putting the rvalue on a separate line, this illuminates things:)

$(CONSOLE
        |void foo(int a, int b)
        |{
       5|   bar(a);
       5|   if (a &&
       3|	b)
       1|	bar(b);
        |}
)

$(P Similarly, for the $(TT e?e1:e2) expressions, $(TT e1) and
$(TT e2) are treated as separate statements.)

<h3>Controlling the Coverage Analyser</h3>

$(P The behavior of the coverage analyser can be controlled through
the $(LINK2 phobos/std_cover.html, std.cover) module.)

$(P When the $(B -cov) switch is thrown, the version identifier
$(B D_Coverage) is defined.)

<h3>References</h3>

$(LINK2 http://en.wikipedia.org/wiki/Code_coverage, Wikipedia)

)

Macros:
	TITLE=Code Coverage Analysis
	WIKI=Dcover
	RPAREN=)

