module reggae.backend.ninja;


import reggae.build;
import reggae.range;
import reggae.rules;
import reggae.options;
import std.array;
import std.range;
import std.algorithm;
import std.exception: enforce;
import std.conv;
import std.string: strip;
import std.path: defaultExtension, absolutePath;

string cmdTypeToNinjaString(CommandType commandType, Language language) @safe pure {
    final switch(commandType) with(CommandType) {
        case shell: assert(0, "cmdTypeToNinjaString doesn't work for shell");
        case phony: assert(0, "cmdTypeToNinjaString doesn't work for phony");
        case code: throw new Exception("Command type 'code' not supported for ninja backend");
        case link:
            final switch(language) with(Language) {
                case D: return "_dlink";
                case Cplusplus: return "_cpplink";
                case C: return "_clink";
                case unknown: return "_ulink";
            }
        case compile:
            final switch(language) with(Language) {
                case D: return "_dcompile";
                case Cplusplus: return "_cppcompile";
                case C: return "_ccompile";
                case unknown: throw new Exception("Unsupported language");
            }
        case compileAndLink:
            final switch(language) with(Language) {
                case D: return "_dcompileAndLink";
                case Cplusplus: return "_cppcompileAndLink";
                case C: return "_ccompileAndLink";
                case unknown: throw new Exception("Unsupported language");
            }
    }
}

struct NinjaEntry {
    string mainLine;
    string[] paramLines;
    string toString() @safe pure nothrow const {
        return (mainLine ~ paramLines.map!(a => "  " ~ a).array).join("\n");
    }
}


private bool hasDepFile(in CommandType type) @safe pure nothrow {
    return type == CommandType.compile || type == CommandType.compileAndLink;
}

/**
 * Pre-built rules
 */
NinjaEntry[] defaultRules(in Options options) @safe pure {

    NinjaEntry createNinjaEntry(in CommandType type, in Language language) @safe pure {
        string[] paramLines = ["command = " ~ Command.builtinTemplate(type, language, options)];
        if(hasDepFile(type)) paramLines ~= ["deps = gcc", "depfile = $out.dep"];
        return NinjaEntry("rule " ~ cmdTypeToNinjaString(type, language), paramLines);
    }

    NinjaEntry[] entries;
    foreach(type; [CommandType.compile, CommandType.link, CommandType.compileAndLink]) {
        for(Language language = Language.min; language <= Language.max; ++language) {
            if(hasDepFile(type) && language == Language.unknown) continue;
            entries ~= createNinjaEntry(type, language);
        }
    }

    entries ~= NinjaEntry("rule _phony", ["command = $cmd"]);

    return entries;
}


struct Ninja {
    NinjaEntry[] buildEntries;
    NinjaEntry[] ruleEntries;

    this(Build build, in string projectPath = "") @safe {
        import reggae.config: options;
        auto modOptions = options.dup;
        modOptions.projectPath = projectPath;
        this(build, modOptions);
    }

    this(Build build, in Options options) @safe {
        _build = build;
        _options = options;
        _projectPath = _options.projectPath;


        foreach(target; _build.range) {
            target.hasDefaultCommand
                ? defaultRule(target)
                : target.getCommandType == CommandType.phony
                ? phonyRule(target)
                : customRule(target);
        }
    }

    //includes rerunning reggae
    const(NinjaEntry)[] allBuildEntries() @safe {
        immutable files = (_options.reggaeFileDependencies ~ getReggaeFileDependencies).join(" ");
        auto paramLines = _options.oldNinja ? [] : ["pool = console"];

        const(NinjaEntry)[] rerunEntries() {
            // if exporting the build system, don't include rerunning reggae
            return _options.export_ ? [] : [NinjaEntry("build build.ninja: _rerun | " ~ files,
                                                       paramLines)];
        }

        return buildEntries ~ rerunEntries ~ NinjaEntry("default " ~ _build.defaultTargetsString(_projectPath));
    }

    //includes rerunning reggae
    const(NinjaEntry)[] allRuleEntries() @safe pure const {
        return ruleEntries ~ defaultRules(_options) ~
            NinjaEntry("rule _rerun",
                       ["command = " ~ _options.rerunArgs.join(" "),
                        "generator = 1",
                           ]);
    }

    string buildOutput() @safe {
        auto ret = "include rules.ninja\n" ~ output(allBuildEntries);
        if(_options.export_) ret = _options.eraseProjectPath(ret);
        return ret;
    }

    string rulesOutput() @safe pure const {
        return output(allRuleEntries);
    }

    void writeBuild() @safe {
        import std.stdio;
        import std.path;

        auto buildNinja = File(buildPath(_options.workingDir, "build.ninja"), "w");
        buildNinja.writeln(buildOutput);

        auto rulesNinja = File(buildPath(_options.workingDir, "rules.ninja"), "w");
        rulesNinja.writeln(rulesOutput);
    }

private:
    Build _build;
    string _projectPath;
    const(Options) _options;
    int _counter = 1;

    //@trusted because of join
    void defaultRule(Target target) @trusted {
        string[] paramLines;

        foreach(immutable param; target.commandParamNames) {
            immutable value = target.getCommandParams(_projectPath, param, []).join(" ");
            if(value == "") continue;
            paramLines ~= param ~ " = " ~ value;
        }

        immutable language = target.getLanguage;

        buildEntries ~= NinjaEntry(buildLine(target) ~
                                   cmdTypeToNinjaString(target.getCommandType, language) ~
                                   " " ~ target.dependenciesInProjectPath(_projectPath).join(" "),
                                   paramLines);
    }

    void phonyRule(Target target) @safe {
        //no projectPath for phony rules since they don't generate output
        immutable outputs = target.expandOutputs("").join(" ");
        auto buildLine = "build " ~ outputs ~ ": _phony " ~ target.dependenciesInProjectPath(_projectPath).join(" ");
        if(!target.implicitTargets.empty) buildLine ~= " | " ~ target.implicitsInProjectPath(_projectPath).join(" ");
        buildEntries ~= NinjaEntry(buildLine,
                                   ["cmd = " ~ target.shellCommand(_options),
                                    "pool = console"]);
    }

    void customRule(Target target) @safe {
        //rawCmdString is used because ninja needs to find where $in and $out are,
        //so shellCommand wouldn't work
        immutable shellCommand = target.rawCmdString(_projectPath);
        immutable implicitInput =  () @trusted { return !shellCommand.canFind("$in");  }();
        immutable implicitOutput = () @trusted { return !shellCommand.canFind("$out"); }();

        if(implicitOutput) {
            implicitOutputRule(target, shellCommand);
        } else if(implicitInput) {
            implicitInputRule(target, shellCommand);
        } else {
            explicitInOutRule(target, shellCommand);
        }
    }

    void explicitInOutRule(Target target, in string shellCommand, in string implicitInput = "") @safe {
        import std.regex;
        auto reg = regex(`^[^ ]+ +(.*?)(\$in|\$out)(.*?)(\$in|\$out)(.*?)$`);

        auto mat = shellCommand.match(reg);
        if(mat.captures.empty) { //this is usually bad since we need both $in and $out
            if(target.dependencyTargets.empty) { //ah, no $in needed then
                mat = match(shellCommand ~ " $in", reg); //add a dummy one
            }
            else
                throw new Exception(text("Could not find both $in and $out.\nCommand: ",
                                         shellCommand, "\nCaptures: ", mat.captures, "\n",
                                         "outputs: ", target.rawOutputs.join(" "), "\n",
                                         "dependencies: ", target.dependenciesInProjectPath(_projectPath).join(" ")));
        }

        immutable before  = mat.captures[1].strip;
        immutable first   = mat.captures[2];
        immutable between = mat.captures[3].strip;
        immutable last    = mat.captures[4];
        immutable after   = mat.captures[5].strip;

        immutable ruleCmdLine = getRuleCommandLine(target, shellCommand, before, first, between, last, after);
        bool haveToAddRule;
        immutable ruleName = getRuleName(targetCommand(target), ruleCmdLine, haveToAddRule);

        immutable deps = implicitInput.empty
            ? target.dependenciesInProjectPath(_projectPath).join(" ")
            : implicitInput;

        auto buildLine = buildLine(target) ~ ruleName ~ " " ~ deps;
        if(!target.implicitTargets.empty) buildLine ~= " | " ~  target.implicitsInProjectPath(_projectPath).join(" ");

        string[] buildParamLines;
        if(!before.empty)  buildParamLines ~= "before = "  ~ before;
        if(!between.empty) buildParamLines ~= "between = " ~ between;
        if(!after.empty)   buildParamLines ~= "after = "   ~ after;

        buildEntries ~= NinjaEntry(buildLine, buildParamLines);

        if(haveToAddRule) {
            ruleEntries ~= NinjaEntry("rule " ~ ruleName, [ruleCmdLine]);
        }
    }

    void implicitOutputRule(Target target, in string shellCommand) @safe {
        bool haveToAdd;
        immutable ruleCmdLine = getRuleCommandLine(target, shellCommand, "" /*before*/, "$in");
        immutable ruleName = getRuleName(targetCommand(target), ruleCmdLine, haveToAdd);

        immutable buildLine = buildLine(target) ~ ruleName ~
            " " ~ target.dependenciesInProjectPath(_projectPath).join(" ");
        buildEntries ~= NinjaEntry(buildLine);

        if(haveToAdd) {
            ruleEntries ~= NinjaEntry("rule " ~ ruleName, [ruleCmdLine]);
        }
    }

    void implicitInputRule(Target target, in string shellCommand) @safe {
        string input;

        immutable cmdLine = () @trusted {
            string line = shellCommand;
            auto allDeps = target.dependenciesInProjectPath(_projectPath) ~ target.implicitsInProjectPath(_projectPath);
            foreach(dep; allDeps) {
                if(line.canFind(dep)) {
                    line = line.replace(dep, "$in");
                    input = dep;
                }
            }
            return line;
        }();

        explicitInOutRule(target, cmdLine, input);
    }

    //@trusted because of canFind
    string getRuleCommandLine(Target target, in string shellCommand,
                              in string before = "", in string first = "",
                              in string between = "",
                              in string last = "", in string after = "") @trusted pure const {

        auto cmdLine = "command = " ~ targetRawCommand(target);
        if(!before.empty) cmdLine ~= " $before";
        cmdLine ~= shellCommand.canFind(" " ~ first) ? " " ~ first : first;
        if(!between.empty) cmdLine ~= " $between";
        cmdLine ~= shellCommand.canFind(" " ~ last) ? " " ~ last : last;
        if(!after.empty) cmdLine ~= " $after";
        return cmdLine;
    }

    //Ninja operates on rules, not commands. Since this is supposed to work with
    //generic build systems, the same command can appear with different parameter
    //ordering. The first time we create a rule with the same name as the command.
    //The subsequent times, if any, we append a number to the command to create
    //a new rule
    string getRuleName(in string cmd, in string ruleCmdLine, out bool haveToAdd) @safe nothrow {
        immutable ruleMainLine = "rule " ~ cmd;
        //don't have a rule for this cmd yet, return just the cmd
        if(!ruleEntries.canFind!(a => a.mainLine == ruleMainLine)) {
            haveToAdd = true;
            return cmd;
        }

        //so we have a rule for this already. Need to check if the command line
        //is the same

        //same cmd: either matches exactly or is cmd_{number}
        auto isSameCmd = (in NinjaEntry entry) {
            bool sameMainLine = entry.mainLine.startsWith(ruleMainLine) &&
            (entry.mainLine == ruleMainLine || entry.mainLine[ruleMainLine.length] == '_');
            bool sameCmdLine = entry.paramLines == [ruleCmdLine];
            return sameMainLine && sameCmdLine;
        };

        auto rulesWithSameCmd = ruleEntries.filter!isSameCmd;
        assert(rulesWithSameCmd.empty || rulesWithSameCmd.array.length == 1);

        //found a sule with the same cmd and paramLines
        if(!rulesWithSameCmd.empty)
            return () @trusted { return rulesWithSameCmd.front.mainLine.replace("rule ", ""); }();

        //if we got here then it's the first time we see "cmd" with a new
        //ruleCmdLine, so we add it
        haveToAdd = true;
        import std.conv: to;
        return cmd ~ "_" ~ (++_counter).to!string;
    }

    string output(const(NinjaEntry)[] entries) @safe pure const nothrow {
        return banner ~ entries.map!(a => a.toString).join("\n\n");
    }

    string buildLine(Target target) @safe pure const {
        immutable outputs = target.expandOutputs(_projectPath).join(" ");
        return "build " ~ outputs ~ ": ";
    }

    //@trusted because of splitter
    private string targetCommand(Target target) @trusted pure const {
        return targetRawCommand(target).sanitizeCmd;
    }

    //@trusted because of splitter
    private string targetRawCommand(Target target) @trusted pure const {
        auto cmd = target.shellCommand(_options);
        if(cmd == "") return "";
        return cmd.splitter(" ").front;
    }
}


//ninja doesn't like symbols in rule names
//@trusted because of replace
private string sanitizeCmd(in string cmd) @trusted pure nothrow {
    import std.path;
    //only handles c++ compilers so far...
    return cmd.baseName.replace("+", "p");
}
