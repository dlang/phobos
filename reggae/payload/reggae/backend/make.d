module reggae.backend.make;

import reggae.build;
import reggae.range;
import reggae.rules;
import reggae.options;

import std.conv;
import std.array;
import std.path;
import std.algorithm;


struct Makefile {
    Build build;
    const(Options) options;
    string projectPath;

    this(Build build, in Options options) @safe pure {
        this.build = build;
        this.options = options;
    }

    string fileName() @safe pure nothrow const {
        return "Makefile";
    }

    //only the main targets
    string simpleOutput() @safe {

        auto ret = banner;
        ret ~= text("all: ", build.defaultTargetsString(options.projectPath), "\n");
        ret ~= ".SUFFIXES:\n"; //disable default rules
        ret ~= options.compilerVariables.join("\n") ~ "\n";

        foreach(target; build.range) {

            mkDir(target);

            immutable output = target.expandOutputs(options.projectPath).join(" ");
            if(target.getCommandType == CommandType.phony) {
                ret ~= ".PHONY: " ~ output ~ "\n";
            }
            ret ~= output ~  ": ";
            ret ~= (target.dependenciesInProjectPath(options.projectPath) ~
                    target.implicitsInProjectPath(options.projectPath)).join(" ");

            ret ~= " " ~ fileName() ~ "\n";
            ret ~= "\t" ~ command(target) ~ "\n";
        }

        return ret;
    }

    //includes rerunning reggae
    string output() @safe {
        auto ret = simpleOutput;

        if(options.export_) {
            ret = options.eraseProjectPath(ret);
        } else {
            // add a dependency on the Makefile to reggae itself and the build description,
            // but only if not exporting a build
            ret ~= fileName() ~ ": " ~ (options.reggaeFileDependencies ~ getReggaeFileDependencies).join(" ") ~ "\n";
            ret ~= "\t" ~ options.rerunArgs.join(" ") ~ "\n";
        }

        return ret;
    }

    void writeBuild() @safe {
        import std.stdio;
        auto output = output();
        auto file = File(buildPath(options.workingDir, fileName), "w");
        file.write(output);
    }

    //the only reason this is needed is to add auto dependency
    //tracking
    string command(Target target) @safe const {
        immutable cmdType = target.getCommandType;
        if(cmdType == CommandType.code)
            throw new Exception("Command type 'code' not supported for make backend");

        immutable cmd = target.shellCommand(options).replaceConcreteCompilersWithVars(options);
        immutable depfile = target.expandOutputs(options.projectPath)[0] ~ ".dep";
        if(target.hasDefaultCommand) {
            return cmdType == CommandType.link ? cmd : cmd ~ makeAutoDeps(depfile);
        } else {
            return cmd;
        }
    }

    private void mkDir(Target target) @trusted const {
        foreach(output; target.expandOutputs(options.projectPath)) {
            import std.file;
            if(!output.dirName.exists) mkdirRecurse(output.dirName);
        }
    }
}


//For explanation of the crazy Makefile commands, see:
//http://stackoverflow.com/questions/8025766/makefile-auto-dependency-generation
//http://make.mad-scientist.net/papers/advanced-auto-dependency-generation/
private string makeAutoDeps(in string depfile) @safe pure nothrow {
    immutable pFile = depfile ~ ".P";
    return "\n\t@cp " ~ depfile ~ " " ~ pFile ~ "; \\\n" ~
        "    sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \\\n" ~
        "        -e '/^$$/ d' -e 's/$$/ :/' < " ~ depfile ~ " >> " ~ pFile ~"; \\\n" ~
        "    rm -f " ~ depfile ~ "\n\n" ~
        "-include " ~ pFile ~ "\n\n";
}
