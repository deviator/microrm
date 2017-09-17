import std.stdio;
import std.algorithm;

import microrm;

struct Foo
{
    ulong id;
    string text;
    ulong ts;
}

struct Baz
{
    string one;
    double two;
}

struct Bar
{
    ulong id;
    float value;
    Baz baz;
}

enum schema = buildSchema!(Foo, Bar);

auto cts() @property
{
    import std.datetime;
    return Clock.currStdTime;
}

void main()
{
    auto db = Database("test.db");
    db.run(schema);

    writeln("Foo count: ", db.qCount!Foo.run);
    writeln("Bar count: ", db.qCount!Bar.run);

    foreach (v; db.qSelect!Foo.where("text =", "hello").run)
        writeln(v);
    writeln;
    foreach (v; db.qSelect!Bar.where("value <", 3).run)
        writeln(v);

    db.qDelete!Foo.where("ts <", cts - cast(ulong)1e8).run;
    
    db.qInsert(Foo(0, "hello", cts), Foo(20, "world", cts));
    db.qInsert(Foo(0, "hello", cts), Foo(0, "world", cts));
    import std.random : uniform;
    db.qInsert(Bar(0, uniform(0, 10), Baz("one", 3.14)));

    db.qInsertOrReplace(Foo(1, "hello", cts), Foo(3, "world", cts));
}