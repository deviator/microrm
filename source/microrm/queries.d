module microrm.queries;

import std.format : formattedWrite;
import std.exception : enforce;

import d2sqlite3;

import microrm.util;

debug (microrm) import std.stdio : stderr;

enum BASEQUERYLENGTH = 512;

struct Select(T)
{
    import std.range : InputRange;

    mixin baseQueryData!("SELECT * FROM %s", BASEQUERYLENGTH);
    mixin whereCondition;

    private ref orderBy(string[] fields, string orderType)
    {
        assert(orderType == "ASC" || orderType == "DESC");
        query.formattedWrite(" ORDER BY %(-%s, %) %s", fields, orderType);
        return this;
    }

    ref ascOrderBy(string[] fields...) { return orderBy(fields, "ASC"); }
    ref descOrderBy(string[] fields...) { return orderBy(fields, "DESC"); }

    InputRange!T run() @property
    {
        import std.range : inputRangeObject;
        import std.algorithm : map;

        enforce(db, "database is null");

        query.put(';');
        auto q = query.data.idup;
        debug (microrm) stderr.writeln(q);
        auto result = (*db).execute(q);

        static T qconv(typeof(result.front) e)
        {
            T ret;
            foreach (i, ref f; ret.tupleof)
                f = e[__traits(identifier, ret.tupleof[i])].as!(typeof(f));
            return ret;
        }

        return inputRangeObject(result.map!qconv);
    }
}

unittest
{
    static struct Foo
    {
        ulong id;
        string text;
        ulong ts;
    }

    auto test = Select!Foo(null);
    test.where("text =", "privet").and("ts >", 123);
    assert (test.query.data == "SELECT * FROM Foo WHERE text = 'privet' AND ts > '123'");
}

void buildInsert(W, T)(ref W buf, T[] arr...)
{
    assert(arr.length);

    static void vconv(Y, X)(ref Y wrt, X x)
    {
        import std.traits;
        static if (isFloatingPoint!X)
        {
            if (x == x) wrt.formattedWrite("%e", x);
            else wrt.formattedWrite("null");
        }
        else static if (isNumeric!X)
            wrt.formattedWrite("%d", x);
        else wrt.formattedWrite("'%s'", x);
    }

    buf.formattedWrite("INSERT INTO %s (", tableName!T);
    auto tt = arr[0];
    foreach (i, f; tt.tupleof)
    {
        enum name = __traits(identifier, tt.tupleof[i]);
        static if (name != "id")
        {
            buf.formattedWrite(name);
            static if (i+1 != tt.tupleof.length)
                buf.formattedWrite(", ");
        }
    }
    buf.formattedWrite(") VALUES (");
    foreach (n, v; arr)
    {
        foreach (i, f; v.tupleof)
        {
            enum name = __traits(identifier, v.tupleof[i]);
            static if (name != "id")
            {
                vconv(buf, f);
                static if (i+1 != v.tupleof.length)
                    buf.formattedWrite(", ");
            }
        }
        if (n+1 != arr.length)
            buf.formattedWrite("), (");
    }
    buf.formattedWrite(");");
}

unittest
{
    static struct Foo
    {
        ulong id;
        string text;
        float val;
        ulong ts;
    }

    import std.array : appender;
    auto buf = appender!(char[]);

    buf.buildInsert(Foo(1, "hello", 3.14, 12), Foo(2, "world", 2.7, 42));

    auto q = buf.data;
    assert(q == "INSERT INTO Foo (text, val, ts) VALUES "~
                "('hello', 3.140000e+00, 12), ('world', 2.700000e+00, 42);");
}

struct Delete(T)
{
    mixin baseQueryData!("DELETE FROM %s", BASEQUERYLENGTH);
    mixin whereCondition;

    auto run() @property
    {
        enforce(db, "database is null");

        query.put(';');
        auto q = query.data.idup;
        debug (microrm) stderr.writeln(q);
        return (*db).execute(q);
    }
}

unittest
{
    static struct Foo
    {
        ulong id;
        string text;
        ulong ts;
    }

    auto test = Delete!Foo(null);
    test.where("text =", "privet").and("ts >", 123);
    assert (test.query.data == "DELETE FROM Foo WHERE text = 'privet' AND ts > '123'");
}

struct Count(T)
{
    mixin baseQueryData!("SELECT Count(*) FROM %s", BASEQUERYLENGTH);
    mixin whereCondition;

    size_t run() @property
    {
        enforce(db, "database is null");
        auto q = query.data.idup;
        debug (microrm) stderr.writeln(q);
        return (*db).execute(q).front.front.as!size_t;
    }
}

unittest
{
    static struct Foo
    {
        ulong id;
        string text;
        ulong ts;
    }

    auto test = Count!Foo(null);
    test.where("text =", "privet").and("ts >", 123);
    assert (test.query.data == "SELECT Count(*) FROM Foo WHERE text = 'privet' AND ts > '123'");
}