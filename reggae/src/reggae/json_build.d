/**
 This module is responsible for the output of a build system
 from a JSON description
 */

module reggae.json_build;


import reggae.build;
import reggae.ctaa;
import reggae.rules.common;
import reggae.options;

import std.json;
import std.algorithm;
import std.array;
import std.conv;
import std.traits;


enum JsonTargetType {
    fixed,
    dynamic,
}

enum JsonCommandType {
    shell,
    link,
}


enum JsonDependencyType {
    fixed,
    dynamic,
}


enum JsonDepsFuncName {
    objectFiles,
    staticLibrary,
    targetConcat,
    executable,
}

Build jsonToBuild(in string projectPath, in string jsonString) {
    try {
        return jsonToBuildImpl(projectPath, jsonString);
    } catch(JSONException e) {
        throw new Exception("Wrong JSON description:\n" ~ jsonString);
    }
}

Build jsonToBuildImpl(in string projectPath, in string jsonString) {
    auto json = parseJSON(jsonString);

    Build.TopLevelTarget maybeOptional(in JSONValue json, Target target) {
        immutable optional = ("optional" in json.object) !is null;
        return createTopLevelTarget(target, optional);
    }

    auto targets = json.array.
        filter!(a => a.object["type"].str != "defaultOptions").
        map!(a => maybeOptional(a, jsonToTarget(projectPath, a))).
        array;

    return Build(targets);
}


private Target jsonToTarget(in string projectPath, JSONValue json) {
    if(json.object["type"].str.to!JsonTargetType == JsonTargetType.dynamic)
        return callTargetFunc(projectPath, json);

    auto dependencies = getDeps(projectPath, json.object["dependencies"]);
    auto implicits = getDeps(projectPath, json.object["implicits"]);

    if(isLeaf(json)) {
        return Target(json.object["outputs"].array.map!(a => a.str).array,
                      "",
                      []);
    }

    return Target(json.object["outputs"].array.map!(a => a.str).array,
                  jsonToCommand(json.object["command"]),
                  dependencies,
                  implicits);
}

private bool isLeaf(in JSONValue json) pure {
    return json.object["dependencies"].object["type"].str.to!JsonDependencyType == JsonDependencyType.fixed &&
        json.object["dependencies"].object["targets"].array.empty &&
        json.object["implicits"].object["type"].str.to!JsonDependencyType == JsonDependencyType.fixed &&
        json.object["implicits"].object["targets"].array.empty;
}


private Command jsonToCommand(in JSONValue json) pure {
    immutable type = json.object["type"].str.to!JsonCommandType;
    final switch(type) with(JsonCommandType) {
        case shell:
            return Command(json.object["cmd"].str);
        case link:
            return Command(CommandType.link,
                           assocList([assocEntry("flags", json.object["flags"].str.splitter.array)]));
    }
}


private Target[] getDeps(in string projectPath, in JSONValue json) {
    immutable type = json.object["type"].str.to!JsonDependencyType;
    return type == JsonDependencyType.fixed
        ? json.object["targets"].array.map!(a => jsonToTarget(projectPath, a)).array
        : callDepsFunc(projectPath, json);

}

private Target[] callDepsFunc(in string projectPath, in JSONValue json) {
    immutable func = json.object["func"].str.to!JsonDepsFuncName;
    final switch(func) {
    case JsonDepsFuncName.objectFiles:
        return objectFiles(projectPath,
                           strings(json, "src_dirs"),
                           strings(json, "exclude_dirs"),
                           strings(json, "src_files"),
                           strings(json, "exclude_files"),
                           stringVal(json, "flags"),
                           strings(json, "includes"),
                           strings(json, "string_imports"));
    case JsonDepsFuncName.staticLibrary:
        return staticLibrary(projectPath,
                             stringVal(json, "name"),
                             strings(json, "src_dirs"),
                             strings(json, "exclude_dirs"),
                             strings(json, "src_files"),
                             strings(json, "exclude_files"),
                             stringVal(json, "flags"),
                             strings(json, "includes"),
                             strings(json, "string_imports"));
    case JsonDepsFuncName.executable:
        return [executable(projectPath,
                          stringVal(json, "name"),
                          strings(json, "src_dirs"),
                          strings(json, "exclude_dirs"),
                          strings(json, "src_files"),
                          strings(json, "exclude_files"),
                          stringVal(json, "compiler_flags"),
                          stringVal(json, "linker_flags"),
                          strings(json, "includes"),
                          strings(json, "string_imports"))];
    case JsonDepsFuncName.targetConcat:
        return json.object["dependencies"].array.
            map!(a => getDeps(projectPath, a)).join;
    }
}

private const(string)[] strings(in JSONValue json, in string key) {
    return json.object[key].array.map!(a => a.str).array;
}

private const(string) stringVal(in JSONValue json, in string key) {
    return json.object[key].str;
}


private Target callTargetFunc(in string projectPath, in JSONValue json) {
    import std.exception;
    import reggae.rules.d;
    import reggae.types;

    enforce(json.object["func"].str == "scriptlike",
            "scriptlike is the only JSON function supported for Targets");

    auto srcFile = SourceFileName(stringVal(json, "src_name"));
    auto app = json.object["exe_name"].isNull
        ? App(srcFile)
        : App(srcFile, BinaryFileName(stringVal(json, "exe_name")));


    return scriptlike(projectPath, app,
                      Flags(stringVal(json, "flags")),
                      const ImportPaths(strings(json, "includes")),
                      const StringImportPaths(strings(json, "string_imports")),
                      getDeps(projectPath, json["link_with"]));
}


const(Options) jsonToOptions(in Options options, in string jsonString) {
    return jsonToOptions(options, parseJSON(jsonString));
}

//get "real" options based on what was passed in via the command line
//and a json object.
//This is needed so that scripting language build descriptions can specify
//default values for the options
//First the command-line parses the options, then the json can override the defaults
const (Options) jsonToOptions(in Options options, in JSONValue json) {
    //first, find the JSON object we want
    auto defaultOptionsRange = json.array.filter!(a => a.object["type"].str == "defaultOptions");
    if(defaultOptionsRange.empty) return options;
    auto defaultOptionsObj = defaultOptionsRange.front;
    auto oldDefaultOptions = defaultOptions.dup;
    scope(exit) defaultOptions = oldDefaultOptions;

    //statically loop over members of Options
    foreach(member; __traits(allMembers, Options)) {

        static if(member[0] != '_') {

            //type alias for the current member
            mixin(`alias T = typeof(defaultOptions.` ~ member ~ `);`);

            //don't bother with functions or with these member variables
            static if(member != "args" && member != "userVars" && !isSomeFunction!T) {
                if(member in defaultOptionsObj) {
                    static if(is(T == bool)) {
                        mixin(`immutable type = defaultOptionsObj.object["` ~ member ~ `"].type;`);
                        if(type == JSON_TYPE.TRUE)
                            mixin("defaultOptions." ~ member ~ ` = true;`);
                        else if(type == JSON_TYPE.FALSE)
                            mixin("defaultOptions." ~ member ~ ` = false;`);
                    }
                    else
                        mixin("defaultOptions." ~ member ~ ` = defaultOptionsObj.object["` ~ member ~ `"].str.to!T;`);
                }
            }
        }
    }

    return getOptions(options.args.dup);
}
