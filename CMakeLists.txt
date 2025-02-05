cmake_minimum_required(VERSION 3.7.2)
project(Ecc)

option(ECC_FOR_CLASSICS   "Build vanilla ECC for the classics on Serious Engine 1.05, 1.07 or 1.10" ON)
option(ECC_FOR_ENHANCED   "Build enhanced ECC for the classics on Serious Engine 1.05, 1.07 or 1.10" OFF)
option(ECC_FOR_SE150      "Build ECC for games on Serious Engine 1.50" OFF)
option(ECC_FOR_SSR        "Build ECC for Serious Sam Classics: Revolution" OFF)

if(ECC_FOR_ENHANCED)
  set(ECC_COMPILER_PREFIX "NEW_")
  message("Preparing enhanced ECC for 1.05/1.07/1.10")

elseif(ECC_FOR_SE150)
  set(ECC_COMPILER_PREFIX "150_")
  message("Preparing ECC for 1.50")

elseif(ECC_FOR_SSR)
  set(ECC_COMPILER_PREFIX "SSR_")
  message("Preparing ECC for Revolution")

else()
  set(ECC_COMPILER_PREFIX "110_")
  message("Preparing vanilla ECC for 1.05/1.07/1.10")
endif()

if(MSVC)
  add_compile_options(/W4)
else()
  add_compile_options(-Wall)
  add_compile_options(-Wno-format-overflow -Wno-unused-result -Wno-write-strings)
endif()

macro(add_ecc_compiler _PARSERIN _SCANNERIN _PARSEROUT _SCANNEROUT)
  add_custom_command(
    OUTPUT "${CMAKE_CURRENT_SOURCE_DIR}/${_SCANNEROUT}.cpp"
    MAIN_DEPENDENCY "${CMAKE_CURRENT_SOURCE_DIR}/${_SCANNERIN}.l"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMAND flex
    ARGS -o${_SCANNEROUT}.cpp ${_SCANNERIN}.l
  )

  add_custom_command(
    OUTPUT "${CMAKE_CURRENT_SOURCE_DIR}/${_PARSEROUT}.cpp" "${CMAKE_CURRENT_SOURCE_DIR}/${_PARSEROUT}.hpp"
    MAIN_DEPENDENCY "${CMAKE_CURRENT_SOURCE_DIR}/${_PARSERIN}.y"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMAND bison
    ARGS -pyy -o${_PARSEROUT}.cpp ${_PARSERIN}.y -d
  )
endmacro()

add_ecc_compiler("Source/Compiler/${ECC_COMPILER_PREFIX}Parser" "Source/Compiler/Scanner" "Source/Parser" "Source/Scanner")
add_executable(ecc Source/Main.cpp Source/Parser.cpp Source/Scanner.cpp)
