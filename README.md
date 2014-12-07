tsukuyomi
=========

A Lisp implemented in Lua

Current Design Decisions
------------------------
A lot of these is so far motivated by the fact that the underlying environment is Lua, and I would like to maintain interoperatibility and keep things simple and fast. The end target is to use this in a soft realtime environment (game scripting).

So far, I am drawing inspiration from Clojure, but it is becoming more and more like a Clojure clone.

* Lisp strings are Lua string objects.
* Lisp numbers are Lua numbers (IEE 754 double precision). Unlike other Lisps, there is no numeric tower that can grow in size.
* Lisp lists are like Clojure's PersistentList, which are a 4 tuple of (first/car, rest/cdr, count, meta).
* [] and {} are named PersistentVector and PersistentHashMap which is a thin wrapper around hamt.lua, which is a port from Matt Bernier's Javascript HAMT.
  * Unfortunately, this will probably not be performant as code written in Java since there might not be a JIT, and we can't control object layout size since everything is a Lua table. Nevertheless, I want to try to implement immutability.
* Namespaces are Lua packages. For example tsukuyomi.core/apply == require('tsukuyomi.core').apply
  * That means "tsukuyomi.core" is not a subtable of "tsukuyomi"
* This will be a Lisp-1 (like Clojure), functions and variables will live in a namespace table. Lisp-2 would require a dispatch or resolving mechanism compared to Lisp-1.
* There will be no interpreter, everything is compiled down to Lua source code before being loadstring(). This allows LuaJIT to do it's magic.
* This will be lexically scoped, since this is the simplest way to compile down to Lua. I wanted to avoid stacks of environment, and dynamic scoping does not make sense to me.
