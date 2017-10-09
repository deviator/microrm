### Micro ORM for SQLite3

Very simple ORM with single backend (SQLite3).

```d
struct Foo { ulong id; string text; ulong ts; }
struct Baz { string one; double two; }
struct Bar { ulong id; float value; Baz baz; }

enum schema = buildSchema!(Foo, Bar);

auto db = new MDatabase("test.db");
db.run(schema);

writeln("Bar count: ", db.count!Bar.run);

db.del!Foo.where("ts <", cts - cast(ulong)1e8).run;

db.insert(Foo(0, "hello", cts), Foo(20, "world", cts));
db.insert(Foo(0, "hello", cts), Foo(0, "world", cts));

db.insertOrReplace(Foo(1, "hello", cts), Foo(3, "world", cts));
```

See example/source/app.d