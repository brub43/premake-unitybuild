Unity Build Addon
======================

Unity builds is a technique used to speed up compilation of huge projects, by regrouping
compilation unit files (basically the .cpp and .c files) into a few big ones. Basically, instead
of compiling `foo.cpp` and `bar.cpp` you compile a single `foobaz.cpp` one which contains the
following :

```cpp
#include "foo.cpp"
#include "bar.cpp"
```

This technique is based on the one known as [Single Compilation Unit](https://en.wikipedia.org/wiki/Single_Compilation_Unit),
but it allows creating `N` big compilation units, where `N` usually is the number of cores of your CPU.
This allows you to take advantage of parallel compilation, while retaining the huge speed up
introduced by the SCU technique.

How to use
==========

Clone this repository some place where Premake will be able to locate. Then
in your project's Premake script, include the main file like this :

```lua
require( "premake-unitybuild/unitybuild.lua" )
```

Then in the projects where you want to enable support for compilation units :

```lua
unitybuildenabled ( true )
```

The final step is to invoke Premake using the `compilationunit` option:

```
premake5 --unity-build <action>
```

Here I tell the module to use 8 compilation unit files, for projects where it has
been enabled.

API
===

Most of the API commands of this addon are scoped to the current configuration,
so unless specified otherwise, assume that the documented command only applies
to the current configuration block.

##### unitybuildenabled boolean

Enable or disable the compilation unit generation for the current filter. By default
it's disabled.

##### unitybuildcount number

Sets the number of unity build files to use for the project or configuration.  Vy
default this is calculated so that there are at least 5 source files included in each
unity build file such that there is a maximum of 8 unity build files total and a
minimum of 1.  If this API is used, the given number of unity build files will be used
explicitly unless there are fewer compilation units present in the project.  In most
cases it is sufficient to allow the unity build files count to be auto-calculated.

##### unitybuildfilesonly boolean

If this option is set to `true` then the generated projects will not include the
original files. By defaut this option is `false` to allow easily editing / browsing
the original code in IDEs, but it can be set to `true` in case you don't need that
(think automated build systems, etc.)

##### unitybuilddir "path"

The path where the compilation unit files will be generated. If not specified, the
obj dir will be used. This is a per-project configuration. The addon takes care
of handling the various configurations for you.

##### unitybuildextensions table

By default the extension of the generated compilation units is `.c` for C files,
and `.cpp` for C++ files. You can use a table to override these extensions. For
instance, if you want to enable compilation units on an Objective-C project:

```lua
filter {}
    unitybuildextensions {
        "C" = ".m",
        "C++" = ".mm"
    }
```
