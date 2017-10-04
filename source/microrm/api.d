///
module microrm.api;

import std.array : Appender;
import std.range;

import microrm.queries;
import microrm.util;
import microrm.exception;

import d2sqlite3;

debug (microrm) import std.stdio : stderr;

//version = microrm_cache_stmt;

class MDatabase
{
    version (microrm_cache_stmt)
        private Statement[string] cachedStmt;

    private Appender!(char[]) buf;

    Database db;
    alias db this;

    this(string path, int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
    { db = Database(path, flags); }

    ///
    auto select(T)() @property { return Select!T(&db); }

    ///
    auto count(T)() @property { return Count!T(&db); }

    ///
    void insert(bool all=false, T)(T[] arr...) if (!isInputRange!T)
    { procInsert!all(false, arr); }
    ///
    void insertOrReplace(bool all=false, T)(T[] arr...) if (!isInputRange!T)
    { procInsert!all(true, arr); }

    ///
    void insert(bool all=false, R)(R rng)
        if (isInputRange!R && ((all && hasLength!R) || !all))
    { procInsert!all(false, rng); }
    ///
    void insertOrReplace(bool all=false, R)(R rng)
        if (isInputRange!R && ((all && hasLength!R) || !all))
    { procInsert!all(true, rng); }

    private auto procInsert(bool all=false, R)(bool replace, R rng)
        if ((all && hasLength!R) || !all)
    {
        buf.clear;
        alias T = ElementType!R;
        static if (all)
            buf.buildInsertOrReplace!T(replace, rng.length);
        else
            buf.buildInsertOrReplace!T(replace);

        auto sql = buf.data.idup;

        debug (microrm) stderr.writeln(sql);

        version (microrm_cache_stmt)
        {
            if (sql !in cachedStmt)
                cachedStmt[sql] = db.prepare(sql);
            auto stmt = cachedStmt[sql];
        }
        else auto stmt = db.prepare(sql);

        int n;
        static if (all)
        {
            foreach (v; rng)
                bindStruct(stmt, v, replace, n);
            stmt.execute();
            stmt.reset();
        }
        else foreach (v; rng)
        {
            n = 0;
            bindStruct(stmt, v, replace, n);
            stmt.execute();
            stmt.reset();
        }

        version (microrm_cache_stmt) {}
        else stmt.finalize();

        return true;
    }

    ///
    auto del(T)() { return Delete!T(&db); }

    ///
    auto lastInsertId() @property
    {
        return db.
            executeCheck("SELECT last_insert_rowid()").
            front.front.as!ulong;
    }

    private static int bindStruct(T)(ref Statement stmt, T v, bool replace, ref int n)
    {
        foreach (i, f; v.tupleof)
        {
            enum name = __traits(identifier, v.tupleof[i]);
            alias F = typeof(f);
            static if (is(F==struct))
                bindStruct(stmt, f, replace, n);
            else
            {
                if (name == IDNAME && !replace) continue;
                stmt.bind(n+1, f);
                n++;
            }
        }
        return n;
    }
}

version (unittest)
{
    import microrm.schema;

    import std.conv : text, to;
    import std.range;
    import std.algorithm;
    import std.datetime;
    import std.array;
    import std.stdio;
}

unittest
{
    struct One
    {
        ulong id;
        string text;
    }

    auto db = new MDatabase(":memory:");
    db.run(buildSchema!One);

    assert(db.count!One.run == 0);
    db.insert(iota(0,10).map!(i=>One(i*100,"hello" ~ text(i))));
    assert(db.count!One.run == 10);

    auto ones = db.select!One.run.array;
    assert(ones.length == 10);
    assert(ones.all!(a=>a.id < 100));
    assert(db.lastInsertId == ones[$-1].id);
    db.del!One.run;
    assert(db.count!One.run == 0);
    db.insertOrReplace(iota(0,499).map!(i=>One((i+1)*100,"hello" ~ text(i))));
    assert(ones.length == 10);
    ones = db.select!One.run.array;
    assert(ones.length == 499);
    assert(ones.all!(a=>a.id >= 100));
    assert(db.lastInsertId == ones[$-1].id);
}

unittest
{
    struct One
    {
        ulong id;
        string text;
    }

    auto db = new MDatabase(":memory:");
    db.run(buildSchema!One);

    assert(db.count!One.run == 0);
    db.insert!true(iota(0,10).map!(i=>One(i*100,"hello" ~ text(i))));
    assert(db.count!One.run == 10);

    auto ones = db.select!One.run.array;
    assert(ones.length == 10);
    assert(ones.all!(a=>a.id < 100));
    assert(db.lastInsertId == ones[$-1].id);
    db.del!One.run;
    assert(db.count!One.run == 0);
    import std.datetime;
    import std.conv : to;
    db.insertOrReplace!true(iota(0,499).map!(i=>One((i+1)*100,"hello" ~ text(i))));
    assert(ones.length == 10);
    ones = db.select!One.run.array;
    assert(ones.length == 499);
    assert(ones.all!(a=>a.id >= 100));
    assert(db.lastInsertId == ones[$-1].id);
}

unittest
{
    struct Limit { int min, max; }
    struct Limits { Limit volt, curr; }
    struct Settings
    {
        ulong id;
        Limits limits;
    }

    auto db = new MDatabase(":memory:");
    db.run(buildSchema!Settings);
    assert(db.count!Settings.run == 0);
    db.insertOrReplace(Settings(10, Limits(Limit(0,12), Limit(-10, 10))));
    assert(db.count!Settings.run == 1);

    db.insertOrReplace(Settings(10, Limits(Limit(0,2), Limit(-3, 3))));
    db.insertOrReplace(Settings(11, Limits(Limit(0,11), Limit(-11, 11))));
    db.insertOrReplace(Settings(12, Limits(Limit(0,12), Limit(-12, 12))));

    assert(db.count!Settings.run == 3);
    assert(db.count!Settings.where(`"limits.volt.max" = `, 2).run == 1);
    assert(db.count!Settings.where(`"limits.volt.max" > `, 10).run == 2);
    db.del!Settings.where(`"limits.volt.max" < `, 10).run;
    assert(db.count!Settings.run == 2);
}