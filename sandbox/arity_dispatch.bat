@echo off
pushd %~dp0

..\..\luajit-2.0\src\luajit.exe -jv -jdump arity_dispatch.lua

popd
