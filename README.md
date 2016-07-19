![D Logo](http://dlang.org/images/dlogo.png) Phobos Standard Library
====================================================================


Phobos is the standard library that comes with the
[D Programming Language](http://dlang.org) Compiler.


* [Bugzilla bug tracker](http://d.puremagic.com/issues/)
* [Forum](http://forum.dlang.org/)
* [API Documentation](http://dlang.org/phobos/)
* [Wiki](http://wiki.dlang.org/)

Download
========

Phobos is packaged together with the compiler.
You should
[download the whole precompiled package](http://dlang.org/download.html).

To [build everything yourself](http://wiki.dlang.org/Building_DMD),
there is a [description in the wiki](http://wiki.dlang.org/Building_DMD).

Phobos is distributed under Boost Software Licence.
See the [licence file](LICENSE_1_0.txt).

I Want to Contribute
====================

New packages in Phobos
-------------------------

Phobos is the standard library of the D programming language and thus tries to standardize APIs to ease development for many other programmers.
Hence it's great if you want to contribute and make Phobos even better, but there are some important points that you should pay attention too.

### Blocking points for additions

In general there are some indications why something fits better to dub than to the standard library:

- Low applicability / potential usage (e.g. QR Code generation, Tribune client)
- Many valid ways to do something (e.g. UI framework, web server API)
- Fast moving targets (e.g. CSS library, Game engine)

The bottom line is that if you want to write an amazing library that touches one of those fields, go ahead!
With dub potential users can easily use your library and if it proves to be very popular, it might even find it's way to Phobos ;-)

### Finding good points to contribute

If you want to help improving Phobos, a good starting point to find meaningful tasks is the [issue tracker](https://issues.dlang.org/buglist.cgi?component=phobos&list_id=209027&product=D&resolution=---). 
Furthermore the [D Wishlist](https://wiki.dlang.org/Wish_list) contains more abstract, high-level goals.

If you want to write new modules for Phobos, we highly encourage you to stay in touch with the community early on.
Apart from receiving vital feedback and avoiding duplicate efforts, the approval of the community is needed for new additions. In particular, be sure to keep in touch with Andrei Alexandrescu, who manages Phobos and can **veto** new additions.

For more information see [CONTRIBUTING.md file](CONTRIBUTING.md).
