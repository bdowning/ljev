ljev - High-performance LuaJIT FFI bindings for libev
=====================================================

Introduction
------------

ljev is a high performance LuaJIT FFI binding for libev.  Performance
with unpatched libev is decent.  A patched libev which allows LuaJIT to
take over enough of the main loop to eliminate callbacks back to Lua has
performance within 10-20% of pure C, while still allowing unmodified C
code to hook to the event loop in the same process.

This is still a work in progress.

This currently requires [lj-cdefdb](https://github.com/bdowning/lj-cdefdb) 
to provide the libev cdefs.

Copyright and License
---------------------

Copyright © 2014–2015 [Brian Downing](https://github.com/bdowning).
[MIT License.](LICENSE)
