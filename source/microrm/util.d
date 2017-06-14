module microrm.util;

enum IDNAME = "id";

string tableName(T)()
{
    return T.stringof;
}

void fieldToCol(string name, T, Writer)(Writer w)
{
    import std.format : formattedWrite;
    static if (name == IDNAME)
    {
        w.put(IDNAME);
        w.put(" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL");
    }
    else
    {
        enum NOTNULL = " NOT NULL";
        string type, param;
        static if (is(T : ulong))
        {
            type = "INTEGER";
            param = NOTNULL;
        }
        else static if (is(T : string))
        {
            // TODO UDAs for VARCHAR
            type = "TEXT";
            param = "";
        }
        else static if (is(T : float))
        {
            type = "REAL";
            param = "";
        }
        else static assert(0, "unsupported type: " ~ T.stringof);

        formattedWrite(w, "%s %s%s", name, type, param);
    }
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