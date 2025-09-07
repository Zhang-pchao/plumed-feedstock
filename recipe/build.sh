#!/bin/bash
#chat with AI:
#https://chatgpt.com/c/68b97b13-ee6c-8324-9bf2-7ff6d5d85537
#https://www.kimi.com/chat/d2t92oi1ol7rh070bfs0
set -e
# ----- 1. get path from conda_build_config.yaml -----
export LIBTORCH="${libtorch_root}"
echo "LIBTORCH=$LIBTORCH"      # check path

# ----- 2. export libtorch at first -----
export CMAKE_PREFIX_PATH=${LIBTORCH}:$CMAKE_PREFIX_PATH
export CPATH=${LIBTORCH}/include/torch/csrc/api/include/:${LIBTORCH}/include/:${LIBTORCH}/include/torch:$CPATH
export INCLUDE=${LIBTORCH}/include/torch/csrc/api/include/:${LIBTORCH}/include/:${LIBTORCH}/include/torch:$INCLUDE
export LIBRARY_PATH=${LIBTORCH}/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=${LIBTORCH}/lib:$LD_LIBRARY_PATH

export LDFLAGS="-L$LIBTORCH/lib -Wl,-rpath,$LIBTORCH/lib $LDFLAGS"
export LIBS="-ltorch_cpu -lc10 $LIBS"

# ----- 3. Keep PKG_CONFIG out of the way, LibTorch without pc file -----
export PKG_CONFIG_PATH="$LIBTORCH/lib/pkgconfig:$PKG_CONFIG_PATH"

# ----- 4. check path -----
echo "CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH"
echo "CPATH=$CPATH"
echo "LIBRARY_PATH=$LIBRARY_PATH"
#ls -l "$LIBTORCH/lib/cmake/Torch/TorchConfig.cmake" || echo "TorchConfig.cmake not found!"

# ----- 5. normal steps -----

if [[ $(uname) == "Linux" ]]; then
# STATIC_LIBS is a PLUMED specific option and is required on Linux for the following reason:
# When using env modules the dependent libraries can be found through the
# LD_LIBRARY_PATH or encoded configuring with -rpath.
# Conda does not use LD_LIBRARY_PATH and it is thus necessary to suggest where libraries are.
  export STATIC_LIBS=-Wl,-rpath-link,$PREFIX/lib
fi

# we also store path so that software linking libplumedWrapper.a knows where libplumedKernel can be found.
export CPPFLAGS="-D__PLUMED_DEFAULT_KERNEL=$PREFIX/lib/libplumedKernel$SHLIB_EXT $CPPFLAGS"

# enable optimization
export CXXFLAGS="-std=c++14 -D_GLIBCXX_USE_CXX11_ABI=1 $CXXFLAGS"
export CXXFLAGS="${CXXFLAGS//-O2/-O3}"

# libraries are explicitly listed here due to --disable-libsearch
export LIBS="-lgsl -lgslcblas -lblas -lz $LIBS"

export CC=mpicc
export CXX=mpic++

# python is disabled since it should be provided as a separate package
# --disable-libsearch forces to link only explicitely requested libraries
# --disable-static-patch avoid tests that are only required for static patches
# --disable-static-archive makes package smaller
./configure --prefix=$PREFIX --disable-python --disable-libsearch --disable-static-patch --disable-static-archive --enable-libtorch --enable-modules=all

make -j${CPU_COUNT}
make install

