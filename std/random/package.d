// Written in the D programming language.

/**
Facilities for random number generation.

The new-style generator objects hold their own state so they are
immune of threading issues. The generators feature a number of
well-known and well-documented methods of generating random
numbers. An overall fast and reliable means to generate random numbers
is the $(D_PARAM Mt19937) generator, which derives its name from
"$(LUCKY Mersenne Twister) with a period of 2 to the power of
19937". In memory-constrained situations, $(LUCKY linear congruential)
generators such as $(D MinstdRand0) and $(D MinstdRand) might be
useful. The standard library provides an alias $(D_PARAM Random) for
whichever generator it considers the most fit for the target
environment.

Example:

----
// Generate a uniformly-distributed integer in the range [0, 14]
auto i = uniform(0, 15);
// Generate a uniformly-distributed real in the range [0, 100$(RPAREN)
// using a specific random generator
Random gen;
auto r = uniform(0.0L, 100.0L, gen);
----

In addition to random number generators, this module features
distributions, which skew a generator's output statistical
distribution in various ways. So far the uniform distribution for
integers and real numbers have been implemented.

Upgrading:
        $(WEB digitalmars.com/d/1.0/phobos/std_random.html#rand Phobos D1 $(D rand())) can
        be replaced with $(D uniform!uint()).

Source:    $(PHOBOSSRC std/_random.d)

Macros:

WIKI = Phobos/StdRandom


Copyright: Copyright Andrei Alexandrescu 2008 - 2009, Joseph Rushton Wakeling 2012.
License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB erdani.org, Andrei Alexandrescu)
           Masahiro Nakagawa (Xorshift random generator)
           $(WEB braingam.es, Joseph Rushton Wakeling) (Algorithm D for random sampling)
Credits:   The entire random number library architecture is derived from the
           excellent $(WEB open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf, C++0X)
           random number facility proposed by Jens Maurer and contributed to by
           researchers at the Fermi laboratory (excluding Xorshift).
*/
/*
         Copyright Andrei Alexandrescu 2008 - 2009.
Distributed under the Boost Software License, Version 1.0.
   (See accompanying file LICENSE_1_0.txt or copy at
         http://www.boost.org/LICENSE_1_0.txt)
*/
module std.random;

public import std.random.algorithm;
public import std.random.device;
public import std.random.distribution;
public import std.random.engine;
public import std.random.traits;

// Segments of the code in this file Copyright (c) 1997 by Rick Booth
// From "Inner Loops" by Rick Booth, Addison-Wesley
