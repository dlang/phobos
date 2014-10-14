import std.stdio;
import std.datetime : DateTime;

struct Entry
{
    string name;
    string date;
    string measuringUnit;
    long iterations;
    bool failed;
    double avgClockTime;
    double q0;
    double q25;
    double q50;
    double q75;
    double q100;
}

struct EntrySorted {
    Entry entry;
    DateTime date;

    int opCmp(const ref EntrySorted other) @safe const pure nothrow {
        return this.date < other.date;
    }
}

auto gnuplot = q"{set title "%s"
set terminal pngcairo enhanced font 'Verdana,10'
set output "%s"
set ytics nomirror
set ylabel "Time (usecs) Single Call"
set bmargin 10
set timefmt %s
set format x %s
set autoscale x
set offset graph 0.10, 0.10
set style fill empty
set xtics rotate by -90 offset 0,0
set grid
plot "%s" using (column(0)):8:7:11:10:xticlabels(1) with candlesticks lt 8 lw 1 title "0.25 - 0.5 Quantil" whiskerbars, "%s" using (column(0)):9:9:9:9 with candlesticks lt 7 lw 2 notitle;
}";

int main(string[] args)
{
    if (args.length == 1)
    {
        stderr.writeln("You need to pass in a a filename");
        return 1;
    }

    import std.csv : csvReader;
    import std.file : readText;
    import std.string : translate;

    Entry[][string] entries;

    foreach (entry; csvReader!Entry(readText(args[1])))
    {
        entries[entry.name] ~= entry;
    }

    immutable dchar[dchar] filenameTranslate = ['.' : '_', '(' : '_', ')' : '_',
        ',' : '_'];

    immutable dchar[dchar] gnuplotTranslate = [' ' : '-'];

    foreach (key; entries.byKey)
    {
        import std.array : empty, front;
        import std.algorithm.sorting : sort;
        import std.string : lastIndexOf;
        import std.conv : to;

        auto dataFilename = key.translate(filenameTranslate);

        EntrySorted[] sorted;
        foreach (entry; entries[key])
        {
            string date = entry.date;
            auto dotIdx = date.lastIndexOf('.');
            sorted ~= EntrySorted(entry, DateTime.fromISOExtString(date[0 ..  dotIdx]));
        }
        sorted.sort();
        assert(!sorted.empty);
        writeln(sorted);

        auto gnuplotFile = File(dataFilename ~ ".gp", "w");
        gnuplotFile.writef(gnuplot, sorted.front.entry.name,
            dataFilename ~ ".png", "'%Y-%m-%d-%H:%M:%S'", "'%Y-%m-%d-%H:%M:%S'",
            dataFilename ~ ".dat", dataFilename ~ ".dat");

        auto outputFile = File(dataFilename ~ ".dat", "w");
        foreach (entry; sorted)
        {
            outputFile.writefln("%02d-%02d-%d-%02d:%02d:%02d %f %f %f %f %f "
                 ~ "%f %f %f %f %f",
                    entry.date.year,
                    entry.date.month,
                    entry.date.day,
                    entry.date.hour,
                    entry.date.minute,
                    entry.date.second,

                    entry.entry.q0,
                    entry.entry.q25,
                    entry.entry.q50,
                    entry.entry.q75,
                    entry.entry.q100,

                    entry.entry.q0 / entry.entry.iterations,
                    entry.entry.q25 / entry.entry.iterations,
                    entry.entry.q50 / entry.entry.iterations,
                    entry.entry.q75 / entry.entry.iterations,
                    entry.entry.q100 / entry.entry.iterations);
        }
    }

    return 0;
}
