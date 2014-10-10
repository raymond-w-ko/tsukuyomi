@echo off
cls
pushd %~dp0
cd ..\..

echo 50
luajit-2.0\src\luajit.exe tsukuyomi\thirdparty\bcname.lua 50
echo 51
luajit-2.0\src\luajit.exe tsukuyomi\thirdparty\bcname.lua 51
echo 70
luajit-2.0\src\luajit.exe tsukuyomi\thirdparty\bcname.lua 70

REM luajit-2.0\src\luajit.exe tsukuyomi\tests\run_all_tests.lua
luajit-2.0\src\luajit.exe tsukuyomi\tests\run_all_tests.lua > tsukuyomi\tests\test_output.log
popd
