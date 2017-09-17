module microrm.util;

import std.traits;
import std.format : format, formattedWrite;

enum IDNAME = "id";
enum SEPARATOR = ".";

string tableName(T)()
{
    return T.stringof;
}

string[] fieldToCol(string name, T)(string prefix="")
{
    static if (name == IDNAME)
        return ["'" ~ IDNAME ~ "' INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL"];
    else static if (is(T == struct))
    {
        T t;
        string[] ret;
        foreach (i, f; t.tupleof)
        {
            enum fname = __traits(identifier, t.tupleof[i]);
            alias F = typeof(f);
            auto np = prefix ~ (name.length ? name~SEPARATOR : "");
            ret ~= fieldToCol!(fname, F)(np);
        }
        return ret;
    }
    else
    {
        enum NOTNULL = " NOT NULL";
        string type, param;
        static if (isFloatingPoint!T) type = "REAL";
        else static if (isNumeric!T || is(T == bool))
        {
            type = "INTEGER";
            param = NOTNULL;
        }
        else static if (isSomeString!T) type = "TEXT";
        else static if (isDynamicArray!T) type = "BLOB";
        else static assert(0, "unsupported type: " ~ T.stringof);

        return [format("'%s%s' %s%s", prefix, name, type, param)];
    }
}

unittest
{
    struct Foo
    {
        float xx;
        string yy;
        int zz;
    }

    struct Bar
    {
        ulong id;
        float abc;
        Foo foo;
        string baz;
        ubyte[] data;
    }

    assert (fieldToCol!("", Bar)() ==
    ["'id' INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL",
     "'abc' REAL",
     "'foo.xx' REAL",
     "'foo.yy' TEXT",
     "'foo.zz' INTEGER NOT NULL",
     "'baz' TEXT",
     "'data' BLOB"
     ]);
}

void valueToCol(T, Writer)(ref Writer w, T x)
{
    static if(is(T == struct))
    {
        foreach (i, v; x.tupleof)
        {
            valueToCol(w, v);
            static if (i+1 != x.tupleof.length)
                w.put(", ");
        }
    }
    else static if (is(T == bool))
        w.formattedWrite("%d", cast(int)x);
    else static if (isFloatingPoint!T)
    {
        if (x == x) w.formattedWrite("%e", x);
        else w.formattedWrite("null");
    }
    else static if (isNumeric!T)
        w.formattedWrite("%d", x);
    else static if (isSomeString!T)
        w.formattedWrite("'%s'", x);
    else static if (isDynamicArray!T)
    {
        if (x.length == 0) w.formattedWrite("null");
        else
        {
            static if (is(T == ubyte[])) auto dd = x;
            else auto dd = cast(ubyte[])(cast(void[])x);
            w.formattedWrite("x'%-(%02x%)'", dd);
        }
    }
    else static assert(0, "unsupported type: " ~ T.stringof);
}

unittest
{
    import std.array : Appender;
    Appender!(char[]) buf;
    valueToCol(buf, 3);
    assert(buf.data == "3");
    buf.clear;
    valueToCol(buf, "hello");
    assert(buf.data == "'hello'");
    buf.clear;
}

unittest
{
    struct Foo
    {
        int xx;
        string yy;
    }

    struct Bar
    {
        ulong id;
        int abc;
        string baz;
        Foo foo;
    }

    Bar val = {id: 12, abc: 32, baz: "hello",
                foo: {xx: 45, yy: "ok"}};

    import std.array : Appender;
    Appender!(char[]) buf;
    valueToCol(buf, val);
    assert(buf.data == "12, 32, 'hello', 45, 'ok'");
}

mixin template whereCondition()
{
    import std.format : formattedWrite;
    import std.range : isOutputRange;
    static assert(isOutputRange!(typeof(this.query), char));

    ref where(V)(string field, V val)
    {
        this.query.formattedWrite(" WHERE %s '%s'", field, val);
        return this;
    }

    ref whereQ(string field, string cmd)
    {
        this.query.formattedWrite(" WHERE %s %s", field, cmd);
        return this;
    }

    ref and(V)(string field, V val)
    {
        this.query.formattedWrite(" AND %s '%s'", field, val);
        return this;
    }

    ref andQ(string field, string cmd)
    {
        this.query.formattedWrite(" AND %s %s", field, cmd);
        return this;
    }

    ref limit(int limit)
    {
        this.query.formattedWrite(" LIMIT '%s'", limit);
        return this;
    }
}

mixin template baseQueryData(string SQLTempl, size_t BufLen=512)
{
    import std.array : Appender, appender;
    import std.format : formattedWrite, format;

    enum initialSQL = format(SQLTempl, tableName!T);

    Database* db;
    Appender!(char[]) query;

    @disable this();

    this(Database* db)
    {
        this.db = db;
        query.reserve(BufLen);
        query.put(initialSQL);
    }

    void reset()
    {
        query.clear();
        query.put(initialSQL);
    }
}

string[] fieldNames(string name, T)(string prefix="")
{
    static if (is(T == struct))
    {
        T t;
        string[] ret;
        foreach (i, f; t.tupleof)
        {
            enum fname = __traits(identifier, t.tupleof[i]);
            alias F = typeof(f);
            auto np = prefix ~ (name.length ? name~SEPARATOR : "");
            ret ~= fieldNames!(fname, F)(np);
        }
        return ret;
    }
    else return ["'" ~ prefix ~ name ~ "'"];
}

unittest
{
    struct Foo
    {
        float xx;
        string yy;
    }

    struct Bar
    {
        ulong id;
        float abc;
        Foo foo;
        string baz;
    }

    assert (fieldNames!("", Bar) ==
            ["'id'", "'abc'", "'foo.xx'", "'foo.yy'", "'baz'"]);
}