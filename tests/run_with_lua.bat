@echo off
cls
pushd %~dp0
cd ..\..

REM SET LUA=luas\lua51\lua.exe
SET LUA=luas\lua52\lua.exe

REM %LUA% tsukuyomi\tests\run_all_tests.lua
%LUA% tsukuyomi\tests\run_all_tests.lua > tsukuyomi\tests\output.log

popd
