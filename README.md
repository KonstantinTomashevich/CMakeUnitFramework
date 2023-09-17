# CMakeUnitFramework

`CMakeUnitFramework` is a lightweight framework for building modular projects with [CMake](https://cmake.org/). 
Originally built for [Emergence project](https://github.com/KonstantinTomashevich/Emergence), it aims to make
it easier to manage swarm of modular libraries and to combine them into larger products like shared libraries 
and executables. The main goals of `CMakeUnitFramework` are:

- Make it easy to split code into lots of abstract units and then combine them back into bigger output products.
- Make it easy to use link time polymorphism and select implementations using build script.
- Make target registration both robust and straightforward.
