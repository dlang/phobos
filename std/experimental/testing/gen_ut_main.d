/**
Uses the $(D genUtMain) mixin to implement a runnable program.
This module may be run by rdmd.

Please consult the documentation in
$(LINK2 std_experimental_testing_gen_ut_main_mixin.html, that module)
*/
module std.experimental.gen_ut_main;

import std.experimental.testing.gen_ut_main_mixin;

mixin genUtMain;
