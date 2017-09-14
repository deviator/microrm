///
module microrm.api;

import std.array : appender;
import microrm.queries;
import microrm.exception;

import d2sqlite3;

debug (microrm) import std.stdio : stderr;

///
auto qSelect(T)(ref Database db) { return Select!T(&db); }

///
auto qInsert(T)(ref Database db, T[] arr...)
{
    auto buf = appender!(char[]);
    buf.buildInsert(arr);
    auto q = buf.data.idup;
    debug (microrm) stderr.writeln(q);
    return db.executeCheck(q);
}

auto qInsertOrReplace(T)(ref Database db, T[] arr...)
{
    auto buf = appender!(char[]);
    buf.buildInsertOrReplace(arr);
    auto q = buf.data.idup;
    debug (microrm) stderr.writeln(q);
    return db.executeCheck(q);
}

///
auto qDelete(T)(ref Database db) { return Delete!T(&db); }

///
auto qCount(T)(ref Database db) { return Count!T(&db); }

///
auto qLastInsertId(ref Database db)
{
    return db.
        executeCheck("SELECT last_insert_rowid()").
        front.front.as!ulong;
}