module microrm.util;

import std.traits;
import std.format : formattedWrite;

enum IDNAME = "id";

string tableName(T)()
{
    return T.stringof;
}

void fieldToCol(string name, T, Writer)(Writer w)
{
    static if (name == IDNAME)
    {
        w.put(IDNAME);
        w.put(" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL");
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

        formattedWrite(w, "%s %s%s", name, type, param);
    }
}

void valueToCol(T, Writer)(Writer w, T x)
{
    static if (is(T == bool))
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