cmake_minimum_required(VERSION 3.10)

project(pluto)

# ========== 编译标准与基础设置 ==========
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ========== 项目路径变量 ==========
set(LUA_DIR skynet/3rd/lua)
set(SKYNET_SRC_DIR skynet/skynet-src)
set(SKYNET_LUALIB_SRC_DIR skynet/lualib-src)
set(LUASOCKET_DIR 3rd/luasocket/src)
set(RECAST_DIR 3rd/recastnavigation)

# 验证关键目录存在
foreach(DIR ${LUA_DIR} ${SKYNET_SRC_DIR} 3rd/pluto)
    if(NOT EXISTS "${CMAKE_SOURCE_DIR}/${DIR}")
        message(FATAL_ERROR "Required directory not found: ${DIR}")
    endif()
endforeach()

# ========== 收集Lua源文件（平台无关） ==========
aux_source_directory(${LUA_DIR} LUA_LIB_SRC)
list(REMOVE_ITEM LUA_LIB_SRC 
    "${LUA_DIR}/lua.c"
    "${LUA_DIR}/luac.c"
    "${LUA_DIR}/onelua.c"
    "${LUA_DIR}/ltests.c")

# Lua核心库扩展源代码（平台无关）
set(LUA_CLIB_SKYNET_SRC
    ${SKYNET_LUALIB_SRC_DIR}/lua-skynet.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-seri.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-socket.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-mongo.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-netpack.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-memory.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-multicast.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-cluster.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-crypt.c
    ${SKYNET_LUALIB_SRC_DIR}/lsha1.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-sharedata.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-stm.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-debugchannel.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-datasheet.c
    ${SKYNET_LUALIB_SRC_DIR}/lua-sharetable.c)

# ========== 编译选项与定义 ==========
add_compile_definitions(NOUSE_JEMALLOC)

# 平台特定编译标志
if(MSVC)
    add_compile_options(/W4)
else()
    add_compile_options(-O2 -Wall -g -Wno-int-conversion -Wno-implicit-function-declaration -Wno-deprecated-declarations)
endif()

# 平台特定定义
if(CMAKE_SYSTEM_NAME MATCHES "Windows")
    add_compile_definitions(LUA_BUILD_AS_DLL)
    set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
elseif(CMAKE_SYSTEM_NAME MATCHES "Linux")
    add_compile_definitions(LUA_USE_LINUX LUA_USE_READLINE)
    set(CMAKE_SHARED_LINKER_FLAGS "-fPIC --shared -Wl,-E")
elseif(CMAKE_SYSTEM_NAME MATCHES "Darwin")
    add_compile_definitions(LUA_USE_MACOSX LUA_USE_READLINE)
    set(CMAKE_SHARED_LINKER_FLAGS "-fPIC -dynamiclib -Wl,-undefined,dynamic_lookup")
endif()

# ========== 输出目录设置 ==========
set(CMAKE_BINARY_DIR ${CMAKE_BINARY_DIR}/pluto)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR})

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Binary directory: ${CMAKE_BINARY_DIR}")

# ========== 辅助函数定义 ==========

# 函数：添加Lua扩展库
function(add_lua_extension NAME SOURCES)
    add_library(${NAME} SHARED ${SOURCES})
    target_link_libraries(${NAME} PRIVATE liblua ${ARGN})
    set_target_properties(${NAME} PROPERTIES PREFIX "" SUFFIX .so)
endfunction()

# 函数：添加C服务
function(add_c_service SOURCE_FILE)
    string(REGEX REPLACE ".*service_" "" LIB_NAME "${SOURCE_FILE}")
    string(REGEX REPLACE ".c$" "" LIB_NAME "${LIB_NAME}")
    add_library(${LIB_NAME} SHARED ${SOURCE_FILE})
    target_include_directories(${LIB_NAME} PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(${LIB_NAME} PRIVATE libskynet)
    set_target_properties(${LIB_NAME} PROPERTIES PREFIX "" SUFFIX .so)
endfunction()

# ========== Windows平台配置 ==========
if(CMAKE_SYSTEM_NAME MATCHES "Windows")
    message(STATUS "Configuring for Windows platform")

    # 全局头文件搜索路径
    include_directories(skynet/3rd/lua/ 3rd/pluto/ 3rd/posix 3rd/pthread-win32 ${SKYNET_SRC_DIR})
    add_compile_options(/FI ${CMAKE_SOURCE_DIR}/3rd/posix/unistd.h)

    # 编译Lua可执行文件
    add_executable(lua ${LUA_LIB_SRC} "${LUA_DIR}/lua.c")
    target_include_directories(lua PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(lua PRIVATE ws2_32)

    add_executable(luac ${LUA_LIB_SRC} "${LUA_DIR}/luac.c")
    target_include_directories(luac PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(luac PRIVATE ws2_32)

    # 编译Skynet基础库
    aux_source_directory(${SKYNET_SRC_DIR} LIB_SKYNET_SRC)
    list(REMOVE_ITEM LIB_SKYNET_SRC "${SKYNET_SRC_DIR}/skynet_main.c")
    aux_source_directory(3rd/posix POSIX_SRC)
    
    add_subdirectory(3rd/pthread-win32)
    
    add_library(liblua SHARED ${LUA_LIB_SRC})
    add_library(libposix SHARED ${POSIX_SRC})
    target_compile_definitions(libposix PRIVATE POSIX_LIBRARY)
    target_link_libraries(libposix PRIVATE ws2_32)
    
    add_library(libskynet SHARED ${LIB_SKYNET_SRC})
    target_link_libraries(libskynet PRIVATE liblua libposix pthreadVC3)

    add_executable(skynet ${SKYNET_SRC_DIR}/skynet_main.c)
    target_link_libraries(skynet PRIVATE ws2_32 liblua libposix libskynet pthreadVC3)

    # 设置Lua扩展库输出目录
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/luaclib)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/luaclib)

    # 编译Lua扩展库
    add_library(skynetso SHARED ${LUA_CLIB_SKYNET_SRC})
    target_compile_definitions(skynetso PRIVATE LUA_LIB)
    target_include_directories(skynetso PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(skynetso PRIVATE libskynet)
    set_target_properties(skynetso PROPERTIES OUTPUT_NAME skynet PREFIX "" SUFFIX .so)

    add_library(bson SHARED ${SKYNET_LUALIB_SRC_DIR}/lua-bson.c)
    target_link_libraries(bson PRIVATE liblua)
    set_target_properties(bson PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(skynet/3rd/lua-md5 LUA_MD5_SRC)
    add_library(md5 SHARED ${LUA_MD5_SRC})
    target_link_libraries(md5 PRIVATE liblua)
    set_target_properties(md5 PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(${SKYNET_LUALIB_SRC_DIR}/sproto SPROTO_SRC)
    add_library(sproto SHARED ${SPROTO_SRC})
    target_link_libraries(sproto PRIVATE liblua)
    set_target_properties(sproto PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(skynet/3rd/lpeg LPEG_SRC)
    add_library(lpeg SHARED ${LPEG_SRC})
    target_link_libraries(lpeg PRIVATE liblua)
    set_target_properties(lpeg PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-protobuf PB_SRC)
    add_library(pb SHARED ${PB_SRC})
    target_link_libraries(pb PRIVATE liblua)
    set_target_properties(pb PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/luafilesystem LFS_SRC)
    add_library(lfs SHARED ${LFS_SRC})
    target_link_libraries(lfs PRIVATE liblua)
    set_target_properties(lfs PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-fmt FMT_SRC)
    add_library(fmt SHARED ${FMT_SRC})
    target_link_libraries(fmt PRIVATE liblua)
    set_target_properties(fmt PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(3rd/yyjson YYJSON_SRC)
    aux_source_directory(lualib-src/lua-json JSON_SRC)
    add_library(json SHARED ${YYJSON_SRC} ${JSON_SRC})
    target_include_directories(json PRIVATE 3rd/yyjson/)
    target_link_libraries(json PRIVATE liblua)
    set_target_properties(json PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-buffer BUFFER_SRC)
    add_library(buffer SHARED ${BUFFER_SRC})
    target_link_libraries(buffer PRIVATE liblua)
    set_target_properties(buffer PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-zset ZSET_SRC)
    add_library(skiplist SHARED ${ZSET_SRC})
    target_link_libraries(skiplist PRIVATE liblua)
    set_target_properties(skiplist PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-aoi AOI_SRC)
    add_library(aoi SHARED ${AOI_SRC})
    target_link_libraries(aoi PRIVATE liblua)
    set_target_properties(aoi PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-navmesh NAVMESH_SRC)
    aux_source_directory(${RECAST_DIR}/Detour/Source Detour_SRC)
    aux_source_directory(${RECAST_DIR}/DetourCrowd/Source DetourCrowd_SRC)
    aux_source_directory(${RECAST_DIR}/DetourTileCache/Source DetourTileCache_SRC)
    aux_source_directory(${RECAST_DIR}/Recast/Source Recast_SRC)
    add_library(navmesh SHARED ${NAVMESH_SRC} ${Detour_SRC} ${DetourCrowd_SRC} ${DetourTileCache_SRC} ${Recast_SRC})
    target_include_directories(navmesh PRIVATE 
        ${RECAST_DIR}/Detour/Include/
        ${RECAST_DIR}/DetourCrowd/Include/
        ${RECAST_DIR}/DetourTileCache/Include/
        ${RECAST_DIR}/Recast/Include/)
    target_link_libraries(navmesh PRIVATE liblua)
    set_target_properties(navmesh PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/math3d MATH3D_SRC)
    add_library(math3d SHARED ${MATH3D_SRC})
    target_include_directories(math3d PRIVATE 3rd/glm/)
    target_compile_definitions(math3d PRIVATE DGLM_ENABLE_EXPERIMENTAL DGLM_FORCE_QUAT_DATA_XYZW)
    target_link_libraries(math3d PRIVATE liblua)
    set_target_properties(math3d PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-clonefunc CLONEFUNC_SRC)
    add_library(clonefunc SHARED ${CLONEFUNC_SRC} ${LUA_LIB_SRC})
    target_include_directories(clonefunc PRIVATE ${SKYNET_SRC_DIR})
    set_target_properties(clonefunc PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-scram SCRAM_SRC)
    add_library(scram SHARED ${SCRAM_SRC})
    target_link_libraries(scram PRIVATE liblua)
    set_target_properties(scram PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-snapshot SNAPSHOT_SRC)
    add_library(snapshot SHARED ${SNAPSHOT_SRC})
    target_link_libraries(snapshot PRIVATE liblua)
    set_target_properties(snapshot PROPERTIES PREFIX "" SUFFIX .so)

    # LuaSocket库
    set(LUASOCKET_SRC
        ${LUASOCKET_DIR}/auxiliar.c
        ${LUASOCKET_DIR}/buffer.c
        ${LUASOCKET_DIR}/except.c
        ${LUASOCKET_DIR}/inet.c
        ${LUASOCKET_DIR}/io.c
        ${LUASOCKET_DIR}/luasocket.c
        ${LUASOCKET_DIR}/options.c
        ${LUASOCKET_DIR}/select.c
        ${LUASOCKET_DIR}/tcp.c
        ${LUASOCKET_DIR}/timeout.c
        ${LUASOCKET_DIR}/udp.c
        ${LUASOCKET_DIR}/wsocket.c)  # Windows特定
    
    add_library(socket SHARED ${LUASOCKET_SRC})
    target_include_directories(socket PRIVATE ${LUASOCKET_DIR})
    target_link_libraries(socket PRIVATE liblua ws2_32)
    set_target_properties(socket PROPERTIES PREFIX "" SUFFIX .so)

    add_library(mime SHARED ${LUASOCKET_DIR}/mime.c)
    target_include_directories(mime PRIVATE ${LUASOCKET_DIR})
    target_link_libraries(mime PRIVATE liblua)
    set_target_properties(mime PROPERTIES PREFIX "" SUFFIX .so)

    # 设置C服务输出目录
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/cservice)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/cservice)

    # 生成C服务
    file(GLOB CSERVICE_FILE_LIST "skynet/service-src/*.c")
    foreach(FILE_PATH IN LISTS CSERVICE_FILE_LIST)
        add_c_service(${FILE_PATH})
    endforeach()

endif()  # Windows

# ========== Linux平台配置 ==========
if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    message(STATUS "Configuring for Linux platform")

    # 全局头文件搜索路径
    include_directories(skynet/3rd/lua/ 3rd/pluto/ ${SKYNET_SRC_DIR})

    # 编译Lua可执行文件
    add_executable(lua ${LUA_LIB_SRC} "${LUA_DIR}/lua.c")
    target_include_directories(lua PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(lua PRIVATE m readline dl)

    add_executable(luac ${LUA_LIB_SRC} "${LUA_DIR}/luac.c")
    target_include_directories(luac PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(luac PRIVATE m readline dl)

    # 编译Skynet基础库与可执行文件
    aux_source_directory(${SKYNET_SRC_DIR} SKYNET_SRC)
    
    add_library(liblua SHARED ${LUA_LIB_SRC})
    
    add_library(libskynet SHARED ${SKYNET_SRC})
    target_link_libraries(libskynet PRIVATE liblua m pthread dl rt)

    add_executable(skynet ${SKYNET_SRC} ${LUA_LIB_SRC})
    target_include_directories(skynet PRIVATE ${SKYNET_SRC_DIR})
    target_link_options(skynet PRIVATE "LINKER:-E")
    target_link_libraries(skynet PRIVATE m pthread dl rt)

    # 设置Lua扩展库输出目录
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/luaclib)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/luaclib)

    # 编译Lua扩展库
    add_library(skynetso SHARED ${LUA_CLIB_SKYNET_SRC})
    target_include_directories(skynetso PRIVATE ${SKYNET_SRC_DIR} ${SKYNET_LUALIB_SRC_DIR})
    set_target_properties(skynetso PROPERTIES OUTPUT_NAME skynet PREFIX "" SUFFIX .so)
    target_link_libraries(skynetso PRIVATE libskynet)

    add_library(bson SHARED ${SKYNET_LUALIB_SRC_DIR}/lua-bson.c)
    target_include_directories(bson PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(bson PRIVATE liblua)
    set_target_properties(bson PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(skynet/3rd/lua-md5 LUA_MD5_SRC)
    add_library(md5 SHARED ${LUA_MD5_SRC})
    target_link_libraries(md5 PRIVATE liblua)
    set_target_properties(md5 PROPERTIES PREFIX "" SUFFIX .so)

    add_library(client SHARED 
        ${SKYNET_LUALIB_SRC_DIR}/lua-clientsocket.c
        ${SKYNET_LUALIB_SRC_DIR}/lua-crypt.c
        ${SKYNET_LUALIB_SRC_DIR}/lsha1.c)
    target_link_libraries(client PRIVATE pthread)
    set_target_properties(client PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(${SKYNET_LUALIB_SRC_DIR}/sproto SPROTO_SRC)
    add_library(sproto SHARED ${SPROTO_SRC})
    target_link_libraries(sproto PRIVATE liblua)
    set_target_properties(sproto PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(skynet/3rd/lpeg LPEG_SRC)
    add_library(lpeg SHARED ${LPEG_SRC})
    target_link_libraries(lpeg PRIVATE liblua)
    set_target_properties(lpeg PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-protobuf PB_SRC)
    add_library(pb SHARED ${PB_SRC})
    target_link_libraries(pb PRIVATE liblua)
    set_target_properties(pb PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/luafilesystem LFS_SRC)
    add_library(lfs SHARED ${LFS_SRC})
    target_link_libraries(lfs PRIVATE liblua)
    set_target_properties(lfs PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-fmt FMT_SRC)
    add_library(fmt SHARED ${FMT_SRC})
    target_link_libraries(fmt PRIVATE liblua)
    set_target_properties(fmt PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(3rd/yyjson YYJSON_SRC)
    aux_source_directory(lualib-src/lua-json JSON_SRC)
    add_library(json SHARED ${YYJSON_SRC} ${JSON_SRC})
    target_include_directories(json PRIVATE 3rd/yyjson/)
    target_link_libraries(json PRIVATE liblua)
    set_target_properties(json PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-buffer BUFFER_SRC)
    add_library(buffer SHARED ${BUFFER_SRC})
    target_link_libraries(buffer PRIVATE liblua)
    set_target_properties(buffer PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-zset ZSET_SRC)
    add_library(skiplist SHARED ${ZSET_SRC})
    target_link_libraries(skiplist PRIVATE liblua)
    set_target_properties(skiplist PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-aoi AOI_SRC)
    add_library(aoi SHARED ${AOI_SRC})
    target_link_libraries(aoi PRIVATE liblua)
    set_target_properties(aoi PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-navmesh NAVMESH_SRC)
    aux_source_directory(${RECAST_DIR}/Detour/Source Detour_SRC)
    aux_source_directory(${RECAST_DIR}/DetourCrowd/Source DetourCrowd_SRC)
    aux_source_directory(${RECAST_DIR}/DetourTileCache/Source DetourTileCache_SRC)
    aux_source_directory(${RECAST_DIR}/Recast/Source Recast_SRC)
    add_library(navmesh SHARED ${NAVMESH_SRC} ${Detour_SRC} ${DetourCrowd_SRC} ${DetourTileCache_SRC} ${Recast_SRC})
    target_include_directories(navmesh PRIVATE 
        ${RECAST_DIR}/Detour/Include/
        ${RECAST_DIR}/DetourCrowd/Include/
        ${RECAST_DIR}/DetourTileCache/Include/
        ${RECAST_DIR}/Recast/Include/)
    target_link_libraries(navmesh PRIVATE liblua)
    set_target_properties(navmesh PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/math3d MATH3D_SRC)
    add_library(math3d SHARED ${MATH3D_SRC})
    target_include_directories(math3d PRIVATE 3rd/glm/)
    target_compile_definitions(math3d PRIVATE DGLM_ENABLE_EXPERIMENTAL DGLM_FORCE_QUAT_DATA_XYZW)
    target_link_libraries(math3d PRIVATE liblua)
    set_target_properties(math3d PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-clonefunc CLONEFUNC_SRC)
    add_library(clonefunc SHARED ${CLONEFUNC_SRC} ${LUA_LIB_SRC})
    target_include_directories(clonefunc PRIVATE ${SKYNET_SRC_DIR})
    set_target_properties(clonefunc PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-scram SCRAM_SRC)
    add_library(scram SHARED ${SCRAM_SRC})
    target_link_libraries(scram PRIVATE liblua)
    set_target_properties(scram PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-syslog SYSLOG_SRC)
    add_library(syslog SHARED ${SYSLOG_SRC})
    target_link_libraries(syslog PRIVATE liblua)
    set_target_properties(syslog PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-snapshot SNAPSHOT_SRC)
    add_library(snapshot SHARED ${SNAPSHOT_SRC})
    target_link_libraries(snapshot PRIVATE liblua)
    set_target_properties(snapshot PROPERTIES PREFIX "" SUFFIX .so)

    # LuaSocket库（Linux特定：使用usocket.c）
    set(LUASOCKET_SRC
        ${LUASOCKET_DIR}/auxiliar.c
        ${LUASOCKET_DIR}/buffer.c
        ${LUASOCKET_DIR}/except.c
        ${LUASOCKET_DIR}/inet.c
        ${LUASOCKET_DIR}/io.c
        ${LUASOCKET_DIR}/luasocket.c
        ${LUASOCKET_DIR}/options.c
        ${LUASOCKET_DIR}/select.c
        ${LUASOCKET_DIR}/tcp.c
        ${LUASOCKET_DIR}/timeout.c
        ${LUASOCKET_DIR}/udp.c
        ${LUASOCKET_DIR}/usocket.c)  # Linux特定
    
    add_library(socket SHARED ${LUASOCKET_SRC})
    target_include_directories(socket PRIVATE ${LUASOCKET_DIR})
    target_link_libraries(socket PRIVATE liblua)
    set_target_properties(socket PROPERTIES PREFIX "" SUFFIX .so)

    add_library(mime SHARED ${LUASOCKET_DIR}/mime.c)
    target_include_directories(mime PRIVATE ${LUASOCKET_DIR})
    target_link_libraries(mime PRIVATE liblua)
    set_target_properties(mime PROPERTIES PREFIX "" SUFFIX .so)

    # 设置C服务输出目录
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/cservice)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/cservice)

    # 生成C服务
    file(GLOB CSERVICE_FILE_LIST "skynet/service-src/*.c")
    foreach(FILE_PATH IN LISTS CSERVICE_FILE_LIST)
        add_c_service(${FILE_PATH})
    endforeach()

endif()  # Linux

# ========== macOS平台配置 ==========
if(CMAKE_SYSTEM_NAME MATCHES "Darwin")
    message(STATUS "Configuring for macOS platform")

    # 全局头文件搜索路径
    include_directories(skynet/3rd/lua/ 3rd/pluto/ ${SKYNET_SRC_DIR})

    # 编译Lua可执行文件
    add_executable(lua ${LUA_LIB_SRC} "${LUA_DIR}/lua.c")
    target_include_directories(lua PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(lua PRIVATE m readline)

    add_executable(luac ${LUA_LIB_SRC} "${LUA_DIR}/luac.c")
    target_include_directories(luac PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(luac PRIVATE m readline)

    # 编译Skynet基础库与可执行文件
    aux_source_directory(${SKYNET_SRC_DIR} SKYNET_SRC)
    
    add_library(liblua SHARED ${LUA_LIB_SRC})
    
    add_library(libskynet SHARED ${SKYNET_SRC})
    target_link_libraries(libskynet PRIVATE liblua m pthread dl)

    add_executable(skynet ${SKYNET_SRC} ${LUA_LIB_SRC})
    target_include_directories(skynet PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(skynet PRIVATE m pthread dl)

    # 设置Lua扩展库输出目录
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/luaclib)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/luaclib)

    # 编译Lua扩展库
    add_library(skynetso SHARED ${LUA_CLIB_SKYNET_SRC})
    target_include_directories(skynetso PRIVATE ${SKYNET_SRC_DIR} ${SKYNET_LUALIB_SRC_DIR})
    set_target_properties(skynetso PROPERTIES OUTPUT_NAME skynet PREFIX "" SUFFIX .so)
    target_link_libraries(skynetso PRIVATE libskynet)

    add_library(bson SHARED ${SKYNET_LUALIB_SRC_DIR}/lua-bson.c)
    target_include_directories(bson PRIVATE ${SKYNET_SRC_DIR})
    target_link_libraries(bson PRIVATE liblua)
    set_target_properties(bson PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(skynet/3rd/lua-md5 LUA_MD5_SRC)
    add_library(md5 SHARED ${LUA_MD5_SRC})
    target_link_libraries(md5 PRIVATE liblua)
    set_target_properties(md5 PROPERTIES PREFIX "" SUFFIX .so)

    add_library(client SHARED 
        ${SKYNET_LUALIB_SRC_DIR}/lua-clientsocket.c
        ${SKYNET_LUALIB_SRC_DIR}/lua-crypt.c
        ${SKYNET_LUALIB_SRC_DIR}/lsha1.c)
    target_link_libraries(client PRIVATE pthread)
    set_target_properties(client PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(${SKYNET_LUALIB_SRC_DIR}/sproto SPROTO_SRC)
    add_library(sproto SHARED ${SPROTO_SRC})
    target_link_libraries(sproto PRIVATE liblua)
    set_target_properties(sproto PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(skynet/3rd/lpeg LPEG_SRC)
    add_library(lpeg SHARED ${LPEG_SRC})
    target_link_libraries(lpeg PRIVATE liblua)
    set_target_properties(lpeg PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-protobuf PB_SRC)
    add_library(pb SHARED ${PB_SRC})
    target_link_libraries(pb PRIVATE liblua)
    set_target_properties(pb PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/luafilesystem LFS_SRC)
    add_library(lfs SHARED ${LFS_SRC})
    target_link_libraries(lfs PRIVATE liblua)
    set_target_properties(lfs PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-fmt FMT_SRC)
    add_library(fmt SHARED ${FMT_SRC})
    target_link_libraries(fmt PRIVATE liblua)
    set_target_properties(fmt PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(3rd/yyjson YYJSON_SRC)
    aux_source_directory(lualib-src/lua-json JSON_SRC)
    add_library(json SHARED ${YYJSON_SRC} ${JSON_SRC})
    target_include_directories(json PRIVATE 3rd/yyjson/)
    target_link_libraries(json PRIVATE liblua)
    set_target_properties(json PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-buffer BUFFER_SRC)
    add_library(buffer SHARED ${BUFFER_SRC})
    target_link_libraries(buffer PRIVATE liblua)
    set_target_properties(buffer PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-zset ZSET_SRC)
    add_library(skiplist SHARED ${ZSET_SRC})
    target_link_libraries(skiplist PRIVATE liblua)
    set_target_properties(skiplist PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-aoi AOI_SRC)
    add_library(aoi SHARED ${AOI_SRC})
    target_link_libraries(aoi PRIVATE liblua)
    set_target_properties(aoi PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-navmesh NAVMESH_SRC)
    aux_source_directory(${RECAST_DIR}/Detour/Source Detour_SRC)
    aux_source_directory(${RECAST_DIR}/DetourCrowd/Source DetourCrowd_SRC)
    aux_source_directory(${RECAST_DIR}/DetourTileCache/Source DetourTileCache_SRC)
    aux_source_directory(${RECAST_DIR}/Recast/Source Recast_SRC)
    add_library(navmesh SHARED ${NAVMESH_SRC} ${Detour_SRC} ${DetourCrowd_SRC} ${DetourTileCache_SRC} ${Recast_SRC})
    target_include_directories(navmesh PRIVATE 
        ${RECAST_DIR}/Detour/Include/
        ${RECAST_DIR}/DetourCrowd/Include/
        ${RECAST_DIR}/DetourTileCache/Include/
        ${RECAST_DIR}/Recast/Include/)
    target_link_libraries(navmesh PRIVATE liblua)
    set_target_properties(navmesh PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/math3d MATH3D_SRC)
    add_library(math3d SHARED ${MATH3D_SRC})
    target_include_directories(math3d PRIVATE 3rd/glm/)
    target_compile_definitions(math3d PRIVATE DGLM_ENABLE_EXPERIMENTAL DGLM_FORCE_QUAT_DATA_XYZW)
    target_link_libraries(math3d PRIVATE liblua)
    set_target_properties(math3d PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-clonefunc CLONEFUNC_SRC)
    add_library(clonefunc SHARED ${CLONEFUNC_SRC} ${LUA_LIB_SRC})
    target_include_directories(clonefunc PRIVATE ${SKYNET_SRC_DIR})
    set_target_properties(clonefunc PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-scram SCRAM_SRC)
    add_library(scram SHARED ${SCRAM_SRC})
    target_link_libraries(scram PRIVATE liblua)
    set_target_properties(scram PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-syslog SYSLOG_SRC)
    add_library(syslog SHARED ${SYSLOG_SRC})
    target_link_libraries(syslog PRIVATE liblua)
    set_target_properties(syslog PROPERTIES PREFIX "" SUFFIX .so)

    aux_source_directory(lualib-src/lua-snapshot SNAPSHOT_SRC)
    add_library(snapshot SHARED ${SNAPSHOT_SRC})
    target_link_libraries(snapshot PRIVATE liblua)
    set_target_properties(snapshot PROPERTIES PREFIX "" SUFFIX .so)

    # LuaSocket库（macOS特定：使用usocket.c）
    set(LUASOCKET_SRC
        ${LUASOCKET_DIR}/auxiliar.c
        ${LUASOCKET_DIR}/buffer.c
        ${LUASOCKET_DIR}/except.c
        ${LUASOCKET_DIR}/inet.c
        ${LUASOCKET_DIR}/io.c
        ${LUASOCKET_DIR}/luasocket.c
        ${LUASOCKET_DIR}/options.c
        ${LUASOCKET_DIR}/select.c
        ${LUASOCKET_DIR}/tcp.c
        ${LUASOCKET_DIR}/timeout.c
        ${LUASOCKET_DIR}/udp.c
        ${LUASOCKET_DIR}/usocket.c)  # macOS特定
    
    add_library(socket SHARED ${LUASOCKET_SRC})
    target_include_directories(socket PRIVATE ${LUASOCKET_DIR})
    target_link_libraries(socket PRIVATE liblua)
    set_target_properties(socket PROPERTIES PREFIX "" SUFFIX .so)

    add_library(mime SHARED ${LUASOCKET_DIR}/mime.c)
    target_include_directories(mime PRIVATE ${LUASOCKET_DIR})
    target_link_libraries(mime PRIVATE liblua)
    set_target_properties(mime PROPERTIES PREFIX "" SUFFIX .so)

    # 设置C服务输出目录
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/cservice)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/cservice)

    # 生成C服务
    file(GLOB CSERVICE_FILE_LIST "skynet/service-src/*.c")
    foreach(FILE_PATH IN LISTS CSERVICE_FILE_LIST)
        add_c_service(${FILE_PATH})
    endforeach()

endif()  # macOS

# ========== 复制资源文件 ==========
message(STATUS "Copying resource files from ${CMAKE_SOURCE_DIR}")
file(COPY ${CMAKE_SOURCE_DIR}/skynet/lualib/ DESTINATION ${CMAKE_BINARY_DIR}/lualib NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/skynet/test/ DESTINATION ${CMAKE_BINARY_DIR}/test NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/skynet/service/ DESTINATION ${CMAKE_BINARY_DIR}/service NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/skynet/examples/ DESTINATION ${CMAKE_BINARY_DIR}/examples NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/lualib/ DESTINATION ${CMAKE_BINARY_DIR}/lualib NO_SOURCE_PERMISSIONS)

message(STATUS "========== CMake Configuration Complete ==========")
message(STATUS "  Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "  Platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "  Output directory: ${CMAKE_BINARY_DIR}")
message(STATUS "  C Standard: ${CMAKE_C_STANDARD}")
message(STATUS "  CXX Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "=====================================================")
