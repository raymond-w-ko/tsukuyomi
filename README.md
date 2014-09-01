tsukuyomi
=========

A Lisp implemented in Lua

Current Design Decisions
------------------------
A lot of these is so far motivated by the fact that the underlying environment is Lua, and I would like to maintain interoperatibility and keep things simple and fast. The end target is to use this in a soft realtime environment (game scripting).

* Lisp strings are Lua string objects.
* Lisp numbers are Lua numbers (IEE 754 double precision). Unlike other Lisps, there is no numeric tower that can grow in size.
