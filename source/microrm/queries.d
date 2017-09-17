module microrm.queries;

import std.format : formattedWrite;
import std.exception : enforce;
import std.algorithm : joiner;
import std.string : join;

import d2sqlite3;

import microrm.util;
import microrm.exception;

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
        query.put(" ORDER BY ");
        query.put(fields.joiner(", "));
        query.put(" ");
        query.put(orderType);
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
        auto result = (*db).executeCheck(q);

        static T qconv(typeof(result.front) e)
        {
            enum names = fieldNames!("", T)();
            T ret;
            static string rr()
            {
                string[] res;
                foreach (i, a; fieldNames!("", T)())
                    res ~= format("ret.%1$s = e[%2$d].as!(typeof(ret.%1$s));",
                                    a[1..$-1], i);
                return res.join("\n");
            }
            mixin(rr());
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

void buildInsertOrReplace(W, T)(ref W buf, T[] arr...)
{
    if (arr.length == 0) return;
    buf.put("INSERT OR REPLACE INTO ");
    buf.put(tableName!T);
    buf.put(" (");
    buildInsertQ(buf, arr);
}

void buildInsert(W, T)(ref W buf, T[] arr...)
{
    if (arr.length == 0) return;
    buf.put("INSERT INTO ");
    buf.put(tableName!T);
    buf.put(" (");
    buildInsertQ(buf, arr);
}

void buildInsertQ(W, T)(ref W buf, T[] arr...)
{
    bool isInsertId = true;
    auto tt = arr[0];
    foreach (i, f; tt.tupleof)
    {
        enum name = __traits(identifier, tt.tupleof[i]);

        static if (is(typeof(f)==struct))
            enum tmp = fieldNames!(name, typeof(f))().join(", ");
        else
        {
            if (name == IDNAME && f == f.init) 
            {
                isInsertId = false;
                continue;
            }
            enum tmp = "'" ~ name ~ "'";
        }

        buf.put(tmp);
        static if (i+1 != tt.tupleof.length)
            buf.put(", ");
    }
    buf.formattedWrite(") VALUES (");
    foreach (n, v; arr)
    {
        foreach (i, f; v.tupleof)
        {
            enum name = __traits(identifier, v.tupleof[i]);

            if (name == IDNAME && !isInsertId)
                continue;

            valueToCol(buf, f);
            static if (i+1 != v.tupleof.length)
                buf.put(", ");
        }
        if (n+1 != arr.length)
            buf.put("), (");
    }
    buf.put(");");
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
    assert(q == "INSERT INTO Foo ('id', 'text', 'val', 'ts') VALUES "~
                "(1, 'hello', 3.140000e+00, 12), (2, 'world', 2.700000e+00, 42);");
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
        return (*db).executeCheck(q);
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
        return (*db).executeCheck(q).front.front.as!size_t;
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