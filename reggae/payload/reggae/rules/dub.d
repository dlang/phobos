/**
 High-level rules for building dub projects. The rules in this module
 only replicate what dub does itself. This allows a reggaefile.d to
 reuse the information that dub already knows about.
 */

module reggae.rules.dub;

import reggae.config; // isDubProject

static if(isDubProject) {

    import reggae.dub.info;
    import reggae.types;
    import reggae.build;
    import reggae.rules.common;
    import std.typecons;
    import std.traits;

    /**
     Builds the main dub target (equivalent of "dub build")
    */
    Target dubDefaultTarget(Flags compilerFlags = Flags())() {
        return configToDubInfo["default"].mainTarget(compilerFlags.value);
    }


    /**
     Builds a particular dub configuration (executable, unittest, etc.)
     */
    Target dubConfigurationTarget(ExeName exeName,
                                  Configuration config = Configuration("default"),
                                  Flags compilerFlags = Flags(),
                                  Flag!"main" includeMain = Yes.main,
                                  alias objsFunction = () { Target[] t; return t; },
        )() if(isCallable!objsFunction) {

        return dubTarget!(objsFunction)(exeName, config.value, compilerFlags.value, includeMain);
    }

    Target dubTestTarget(Flags compilerFlags = Flags())() {
        const config = "unittest" in configToDubInfo ? "unittest" : "default";
        auto actualCompilerFlags = compilerFlags.value;

        if("unittest" !in configToDubInfo) actualCompilerFlags ~= " -unittest";
        const hasMain = configToDubInfo[config].packages[0].mainSourceFile != "";
        if(!hasMain) actualCompilerFlags ~= " -main";

        return dubTarget!()(ExeName("ut"), config, actualCompilerFlags, Yes.main, Yes.allTogether);
    }

    private Target dubTarget(alias objsFunction = () { Target[] t; return t;})
                            (in ExeName exeName,
                             in string config,
                             in string compilerFlags,
                             Flag!"main" includeMain = Yes.main,
                             Flag!"allTogether" allTogether = No.allTogether) {

        import std.array;

        auto dubInfo =  configToDubInfo[config];
        auto dubObjs = dubInfo.toTargets(includeMain, compilerFlags, allTogether);
        auto linkerFlags = dubInfo.linkerFlags().join(" ");
        return link(exeName, objsFunction() ~ dubObjs, Flags(linkerFlags));
    }

    /**
     All object files from a particular dub configuration (executable, unittest, etc.)
     */
    Target[] dubConfigurationObjects(Configuration config = Configuration("default"),
                                     Flags compilerFlags = Flags(),
                                     alias objsFunction = () { Target[] t; return t; },
                                     Flag!"main" includeMain = No.main)
        () if(isCallable!objsFunction) {
        return configToDubInfo[config.value].toTargets(includeMain, compilerFlags.value);
    }
}
