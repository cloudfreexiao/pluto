rem Building PATH
SET PATH=%PATH%;C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\
SET PATH=%PATH%;C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\Llvm\x64\bin\
SET PATH=%PATH%;C:\Program Files\Microsoft Visual Studio\18\Community\VC\vcpkg\
SET PATH=%PATH%;C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\

rem building on clang in windows
rmdir /s /q build
mkdir build
cd build
cmake --no-warn-unused-cli -S ../ -B ./ -G "Visual Studio 18" -A x64 -T ClangCL
devenv.com pluto.sln /Build