#!/usr/bin/rdmd
import std.stdio ;
import std.path;
import stdfile = std.file;

void puts(T)(T args)
{
    writeln(args);
    stdout.flush();
}
void putf(T)(T args)
{
    writefln(args);
    stdout.flush();
}
void mkDir(string dir)
{
    if (File.exists(dir)) {
        return;
    }
    writeln("create dir:", dir);
    File.mkdir(dir);
}
void genApp(string name, string path = null)
{
    writefln("gen application for name:<%s>\n", name);
    if (path is null ) {
        path = name;
    }
    if (!File.exists(path)) {
        mkDir(path);
    }
    mkDir(path ~ dirSeparator ~ "source");
    mkDir(path ~ dirSeparator ~ "source" ~ dirSeparator ~ name);
    mkDir(path ~ dirSeparator ~ "source" ~ dirSeparator ~ name ~ dirSeparator ~ "handler");
    mkDir(path ~ dirSeparator ~ "source" ~ dirSeparator ~ name ~ dirSeparator ~ "database");
    mkDir(path ~ dirSeparator ~ "views");
    mkDir(path ~ dirSeparator ~ "views" ~ dirSeparator ~ name);
    mkDir(path ~ dirSeparator ~ "public");
    mkDir(path ~ dirSeparator ~ "public" ~ dirSeparator ~ "script");
    mkDir(path ~ dirSeparator ~ "public" ~ dirSeparator ~ "style");
    mkDir(path ~ dirSeparator ~ "public" ~ dirSeparator ~ "image");

    string dubjson = 
`{
    "name" : "quetzal-fcgi",
    "description" : "a fast cgi program framework for d",
    "authors" : ["Riki Lee"],
    "dependencies" : {
    },
    "sourcePaths" : ["source"],"
    "libs" : ["fcgi", "phobos2"],
    "configurations" : [
        {
            "targetType" : "library",
            "name" : "webframeworklibrary",
            "excludedSourceFiles" : [
                "source/example/handler/index.d",
                "source/example/main.d"
            ]
        },
        {
            "targetType" : "executable",
            "name" : "example",
            "preGenerateCommands" : ["rdmd tools/html2d.d"]
        }
    ]
}`;
    File.write(path ~ dirSeparator ~ dirSeparator ~ "dub.json", dubjson);
}

void genHandler(string name)
{
    writefln("gen handler for name:index.xx");
}
void main(string[] args) 
{
    File.write
    string usage = ""
        "quetzal fast cgi web programing framework\n"
        "Usage: %s [type] <name>\n"
        "type:[default=application]\n"
        "   application\n"
        "   handler";

    if (args.length <2) {
        stderr.writefln(usage, args[0]);
    }
    else if(args.length == 2) {
        genApp(args[1]);
    }
}
