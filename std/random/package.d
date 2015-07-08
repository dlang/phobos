// Written in the D programming language.

/**
This package provides facilities for _random number generation and other
_random algorithms.  The functionality provided is divided into several
different submodules according to purpose:

$(UL
  $(LI $(B uniform _random number generators):
    $(UL
      $(LI $(B _random engines), sources of uniformly-distributed
           pseudo-random bits)
      $(LI $(B _random devices), sources of uniformly-distributed
           non-deterministic _random bits)
    )
  )
  $(LI $(B _random distributions), which transform the output of
       uniform _random number generators into numbers with other
       statistical properties)
  $(LI $(B _random algorithms), similar to those provided in
       $(D std.algorithm), but with a _random component to their
       behaviour)
  $(LI $(B traits) templates useful for working with _random number
       generators)
)

$(DIVC quickindex,
$(BOOKTABLE ,
$(TR $(TH Category) $(TH Submodule) $(TH Functions and data structures))
$(TR $(TDNW _random engines)
     $(TDNW $(SUBMODULE engine))
     $(TD
        $(SUBREF engine, Random)
        $(SUBREF engine, rndGen)
        $(SUBREF engine, LinearCongruentialEngine)
        $(SUBREF engine, MinstdRand0)
        $(SUBREF engine, MinstdRand)
        $(SUBREF engine, MersenneTwisterEngine)
        $(SUBREF engine, Mt19937)
        $(SUBREF engine, XorshiftEngine)
        $(SUBREF engine, Xorshift)
        $(SUBREF engine, Xorshift32)
        $(SUBREF engine, Xorshift64)
        $(SUBREF engine, Xorshift96)
        $(SUBREF engine, Xorshift128)
        $(SUBREF engine, Xorshift160)
        $(SUBREF engine, Xorshift192)
     )
)
$(TR $(TDNW _random devices)
     $(TDNW $(SUBMODULE device))
     $(TD
        $(SUBREF device, unpredictableSeed)
     )
)
$(TR $(TDNW _random distributions)
     $(TDNW $(SUBMODULE distribution))
     $(TD
        $(SUBREF distribution, dice)
        $(SUBREF distribution, uniform)
        $(SUBREF distribution, uniform01)
        $(SUBREF distribution, uniformDistribution)
     )
)
$(TR $(TDNW _random algorithms)
     $(TDNW $(SUBMODULE algorithm))
     $(TD
        $(SUBREF algorithm, randomCover)
        $(SUBREF algorithm, randomSample)
        $(SUBREF algorithm, randomShuffle)
        $(SUBREF algorithm, partialShuffle)
     )
)
$(TR $(TDNW traits)
     $(TDNW $(SUBMODULE traits))
     $(TD
        $(SUBREF traits, isUniformRNG)
        $(SUBREF traits, isSeedable)
     )
)
))

The provided _random number generator objects hold their own state,
so they are immune to threading issues.  The generators feature a number
of well-known and well-documented methods: an overall fast and reliable
means to generate _random numbers is the $(D_PARAM Mt19937) generator,
which derives its name from "$(LUCKY Mersenne Twister) with a period of
2 to the power of 19937".  In memory-constrained situations,
$(LUCKY Xorshift) generators, or $(LUCKY linear congruential) generators
such as $(D MinstdRand0) and $(D MinstdRand), might be useful.  An alias
$(D_PARAM Random) is provided for whichever generator the package
considers the most fit for the target environment.

Example:

----
// Generate a uniformly-distributed integer in the range [0, 14]
auto i = uniform(0, 15);
// Generate a uniformly-distributed real in the range [0, 100$(RPAREN)
// using a specific random generator
Random gen;
auto r = uniform(0.0L, 100.0L, gen);
----


Upgrading:
        $(WEB digitalmars.com/d/1.0/phobos/std_random.html#rand, Phobos D1 $(D rand())) can
        be replaced with $(D uniform!uint()).

Source:    $(PHOBOSSRC std/_random/package.d)

Macros:
WIKI = Phobos/StdRandom
SUBMODULE = $(LINK2 std_random_$1.html, std.random.$1)
SUBREF = $(LINK2 std_random_$1.html#.$2, $(TT $2))$(NBSP)


Copyright: Copyright Andrei Alexandrescu 2008 - 2009, Joseph Rushton Wakeling 2012.
License:   $(WEB www.boost.org/LICENSE_1_0.txt, Boost License 1.0).
Authors:   $(WEB erdani.org, Andrei Alexandrescu)
           Masahiro Nakagawa (Xorshift _random generators)
           $(WEB braingam.es, Joseph Rushton Wakeling) (Algorithm D for _random sampling)
Credits:   The entire _random number library architecture is derived from the
           excellent $(WEB open-std.org/jtc1/sc22/wg21/docs/papers/2007/n2461.pdf, C++0X)
           _random number facility proposed by Jens Maurer and contributed to by
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
