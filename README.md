### Micro ORM for SQLite3

Very simple ORM with single backend (SQLite3).

This methods returns struct instances
```
auto qSelect(T)(ref Database db);
auto qDelete(T)(ref Database db);
auto qCount(T)(ref Database db);
```
They structs have methods
```
ref Self where(V)(string field, V val);
ref Self whereQ(string field, string cmd);
ref Self and(V)(string field, V val);
ref Self andQ(string field, string cmd)
```
there Self is type of structure, and method
```
auto run() @property;
```
for each own types.

This method execute immediately

```
auto qInsert(T)(ref Database db, T[] arr...);
```

See example/source/app.d