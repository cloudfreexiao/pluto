#!/usr/bin/env bash

# build-godot-mono - A simple script to build Godot with Mono support.
# Ideally the Mono build process will be eventually simplified so the last four lines can be two.

# Are we in or can we find the Godot directory? Otherwise, go to ~/workspace/godot
if [ ! -d "core/math" ]; then
    if [ -d "godot/core/math" ]; then
        cd "godot"
    elif [ -d "../godot/core/math" ]; then
        cd "../godot"
    elif [ -d "../../godot/core/math" ]; then
        cd "../../godot"
    elif [ -d "../../../godot/core/math" ]; then
        cd "../../../godot"
    elif [ -d "../../../../godot/core/math" ]; then
        cd "../../../../godot"
    elif [ -d "../../../../../godot/core/math" ]; then
        cd "../../../../../godot"
    elif [ -d "$HOME/workspace/godot" ]; then
        cd "$HOME/workspace/godot"
    else
        echo "Error: Unable to locate the Godot source code directory. Can't build."
        exit 1
    fi
fi

# Does Scons exist? If not, install it and other deps.
if [ ! -f /usr/bin/scons ]; then
    echo "Error: Unable to locate Scons."
    if [ -f /usr/bin/apt ]; then
        echo "We detected you're on Ubuntu, type your password to install required libs:"
        sudo apt update; sudo apt full-upgrade -y
        sudo apt install -y build-essential scons pkg-config libx11-dev libxcursor-dev libxinerama-dev \
            libgl1-mesa-dev libglu-dev libasound2-dev libpulse-dev libfreetype6-dev libssl-dev libudev-dev \
            libxi-dev libxrandr-dev yasm
    elif [ -f /usr/bin/pacman ]; then
        echo "We detected you're on Arch, type your password to install required libs:"
        sudo pacman -S scons libxcursor libxinerama libxi libxrandr mesa glu alsa-lib pulseaudio freetype2 yasm
    elif [ -f /usr/bin/dnf ]; then
        echo "We detected you're on Fedora, type your password to install required libs:"
        sudo dnf install scons pkgconfig libX11-devel libXcursor-devel libXrandr-devel libXinerama-devel \
            libXi-devel mesa-libGL-devel alsa-lib-devel pulseaudio-libs-devel freetype-devel openssl-devel \
            libudev-devel mesa-libGLU-devel yasm
    fi
    if [ ! -f /usr/bin/scons ]; then # If it's still missing after running the above.
        echo "Please visit this website for more information: https://docs.godotengine.org/en/latest/development/compiling/compiling_for_x11.html."
        exit 2
    fi
fi

# Does NuGet exist? If it does, Mono also exists. If not, install them.
if [ ! -f /usr/bin/nuget ]; then
    echo "Error: Unable to locate NuGet."
    if [ -f /usr/bin/apt ]; then
        echo "We detected you're on Ubuntu, type your password to install required libs:"
        sudo apt update; sudo apt full-upgrade -y
        sudo apt install -y mono-complete nuget
    elif [ -f /usr/bin/pacman ]; then
        echo "We detected you're on Arch, type your password to install required libs:"
        sudo pacman -S mono-complete nuget
    elif [ -f /usr/bin/dnf ]; then
        echo "We detected you're on Fedora, type your password to install required libs:"
        sudo dnf install mono-complete nuget
    fi
    if [ ! -f /usr/bin/nuget ]; then # If it's still missing after running the above.
        echo "Please visit this website for more information: https://docs.godotengine.org/en/latest/development/compiling/compiling_with_mono.html."
        exit 3
    fi
fi

# If running an old version of Ubuntu, Mono might be outdated. Redirect users to manual instructions, as instructions differ per OS and version.
MONOVER=$(mono --version | head -n 1 | sed 's@^[^0-9]*\([0-9]\+\).*@\1@')
if [ "$MONOVER" -lt "6" ]; then
    echo "Error: The installed version of Mono is too old. Can't build."
    echo "Please visit this website for more information: https://www.mono-project.com/download/stable/."
    exit 5
fi

echo "Building Godot from $(pwd) ..."

rm -Rf ./bin/* # Remove previously built binaries

rm -f modules/mono/glue/mono_glue.gen.cpp # Neikeq's fault

# Actually begin the build process here:

scons target=editor werror=yes module_mono_enabled=yes mono_glue=no || echo -e '\a'
./bin/godot.linuxbsd.editor.x86_64.mono --generate-mono-glue modules/mono/glue || echo -e '\a'
scons target=editor werror=yes module_mono_enabled=yes mono_glue=yes || echo -e '\a'

./bin/godot.linuxbsd.editor.x86_64.mono
