module reggae.dub.call;

import std.algorithm: splitter, find, map, canFind, until;
import std.array: array, front, replace, empty;
import std.string: stripLeft;

@safe:

struct DubConfigurations {
    string[] configurations;
    string default_;
}


DubConfigurations getConfigurations(in string output) pure {
    auto lines = output.splitter("\n");
    auto fromConfigs = lines.find("Available configurations:").
        until!(a => a == "").
        map!(a => a.stripLeft).
        array[1..$];
    if(fromConfigs.empty) return DubConfigurations();

    immutable defMarker = " [default]";
    auto default_ = fromConfigs.find!(a => a.canFind(defMarker)).front.replace(defMarker, "");
    auto configs = fromConfigs.map!(a => a.replace(defMarker, "")).array;

    return DubConfigurations(configs, default_);
}
