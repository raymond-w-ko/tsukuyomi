tsukuyomi
=========

A Lisp implemented in Lua

Current Design Decisions
------------------------
A lot of these is so far motivated by the fact that the underlying environment is Lua, and I would like to maintain interoperatibility and keep things simple and fast. The end target is to use this in a soft realtime environment (game scripting).

So far, I am drawing inspiration from Clojure.

* Lisp strings are Lua string objects.
* Lisp numbers are Lua numbers (IEE 754 double precision). Unlike other Lisps, there is no numeric tower that can grow in size.
* Lisp lists are traditional cons cells. In Lua, this is just a table with table[1] being CAR and table[2] being CDR. This should be the fastest way to represent this, as arrays avoid the unnecessar hashing.
* [] and {} from Clojure will probably be introduced when things are actually working and usable, just not yet.
  * Unfortunately, these will be mutable and just used for performance reasons. I would really, really like to use hash array mapped tries (HAMT) like Clojure, but I don't think Lua has enough low level control. I would need an object system for obj.hashCode() and quality comparison, and a POPCOUNT function, which involves bit manipulation functions. These aren't available in general Lua and probably would kill performance if implemented (like getting the internal hash value for a string.)
