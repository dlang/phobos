module reggae.reflect;


import reggae.build;
import std.traits;
import std.conv;
import std.array: empty;
import std.exception: enforce;

auto getBuild(alias Module)() if(is(typeof(Module)) && isSomeString!(typeof(Module))) {
    mixin("import " ~ Module ~ ";");
    return getBuild!(mixin(Module));
}

auto getBuild(alias Module)() if(!is(typeof(Module))) {
    mixin("import " ~ fullyQualifiedName!Module ~ ";");
    Build function()[] builds;

    foreach(moduleMember; __traits(allMembers, Module)) {
        static if(__traits(compiles, isBuildFunction!(mixin(moduleMember)))) {
            static if(isBuildFunction!(mixin(moduleMember))) {
                builds ~= &mixin(moduleMember);
            }
        }
    }

    enforce(!builds.empty, "Could not find a public function with return type Build in " ~ fullyQualifiedName!Module);
    enforce(builds.length == 1, text("Only one build object allowed per module, ",
                                     fullyQualifiedName!Module, " has ", builds.length));

    return builds[0];
}
