# Entity Class Compiler

This is the source code of an Entity Class Compiler (ECC), which is a custom build tool used to compile entity source files (`.es`) for Serious Engine 1.
This fork of ECC includes new features and also supports other engine versions, such as Serious Engine 1.50 and Serious Sam Revolution.

Original source code is taken from [Serious Engine 1.10](https://github.com/Croteam-official/Serious-Engine).

Release executables are built under the `ClassicsEnhanced` configuration and are compatible with entity sources from most versions of Serious Engine 1.

# Building

### Available ECC versions

| Visual Studio configuration | CMake option         | Description | Compatibility |
| --------------------------- | -------------------- | ----------- | ------------- |
| `Classics`                  | `ECC_FOR_CLASSICS=1` | ECC for entities from vanilla games. Serves as a base for the rest of the compilers. | 1.05; 1.07; 1.10 |
| `ClassicsEnhanced`          | `ECC_FOR_ENHANCED=1` | ECC designed specifically for [this Serious Engine 1 Mod SDK](https://github.com/DreamyCecil/SE1-ModSDK). | 1.05; 1.07; 1.10; SSR |
| `SE150`                     | `ECC_FOR_SE150=1`    | ECC for entities from Serious Engine 1.50 that support its features. | b1.50; 1.50 |
| `SSR`                       | `ECC_FOR_SSR=1`      | ECC for entities from **Serious Sam Classics: Revolution** that support its features. | SSR |

## Windows

### Instructions
1. Install **Visual Studio 2010** or later.
2. Open `EntityClassCompiler.sln` solution.
3. Select an appropriate build configuration for the desired ECC version.
4. Press F7 or **Build** -> **Build solution** to build the entire project.

## Linux

### Prerequisite
Before building, you need to install certain modules if they aren't already there.

1. Install **Git** and **CMake** tools with `sudo apt install git cmake`
2. Install **GCC** and other build tools with `sudo apt install build-essential` (if you don't already have GCC)
3. Install **Bison** and **Flex** tools with `sudo apt install bison flex` (if you've installed GCC separately without them)
4. Clone the repository in any directory with `git clone https://github.com/DreamyCecil/SE1-ECC.git`

### Instructions via terminal
1. Create a build directory with `mkdir cmake-build` and then enter it with `cd cmake-build`
2. Configure CMake project with `cmake ..` or with some options like `cmake -DCMAKE_BUILD_TYPE=Release -DECC_FOR_ENHANCED=1 ..`
3. Build the project with `make`

### Instructions via CMake
Add subdirectory with this project to your CMake project to build it with everything else, something like this:
```cmake
# Relative to the initial CMakeLists.txt
add_subdirectory(${CMAKE_SOURCE_DIR}/ThirdParty/SE1-ECC)

# Or relative to the file
add_subdirectory(SE1-ECC)
```

# License

This project is licensed under GNU GPL v2 (see LICENSE file).
