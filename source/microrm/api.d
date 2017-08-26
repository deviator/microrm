///
module microrm.api;

import std.array : appender;
import microrm.queries;

import d2sqlite3;

debug (microrm) import std.stdio : stderr;

///
auto qSelect(T)(ref Database db) { return Select!T(&db); }

///
auto qInsert(T)(ref Database db, T[] arr...)
{
    auto buf = appender!(char[]);
    buf.buildInsert(false, arr);
    auto q = buf.data.idup;
    debug (microrm) stderr.writeln(q);
    return db.execute(q);
}

auto qInsertOrReplace(T)(ref Database db, T[] arr...)
{
    auto buf = appender!(char[]);
    buf.buildInsert(true, arr);
    auto q = buf.data.idup;
    debug (microrm) stderr.writeln(q);
    return db.execute(q);
}

///
auto qDelete(T)(ref Database db) { return Delete!T(&db); }

///
auto qCount(T)(ref Database db) { return Count!T(&db); }

///
auto qLastInsertId(ref Database db)
{
    return db.
        execute("SELECT last_insert_rowid()").
        front.front.as!ulong;
}