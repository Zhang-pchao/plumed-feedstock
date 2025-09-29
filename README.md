# Integrating PLUMED with LibTorch into the DeePMD-kit (v2) Conda Environment

This guide documents a working procedure for installing PLUMED with LibTorch support alongside the DeePMD-kit (v2) Conda environment and LAMMPS. Attempting to mirror the workflow from the `devel` branch of this feedstock allows LibTorch-enabled PLUMED to be installed, but it breaks the bundled LAMMPS executable inside the Conda environment. The steps below avoid that incompatibility by compiling each dependency from source in a controlled prefix.

## Prerequisites and References

Before you begin, review the official DeePMD-kit installation notes:

- [Install DeePMD-kit from source (DeepModeling documentation)](https://docs.deepmodeling.com/projects/deepmd/en/master/install/install-from-source.html)
- [Cheng Group DeePMD-kit installation guide](https://wiki.cheng-group.net/wiki/software_installation/deepmd-kit/deepmd-kit_installation_new/)

Adapt the module commands and paths to match your HPC or workstation environment.

## Build LibTorch 1.13.1 from Source

1. Create and activate a lightweight build environment:

   ```bash
   conda activate pt113-build
   source ~/venv/pt113-build/bin/activate
   pip install cmake ninja typing_extensions setuptools wheel
   ```

2. Confirm the host compilers:

   ```bash
   gcc --version   # Expected: GCC 8.5.0 or newer
   g++ --version
   ```

3. Optionally set the parallel build level:

   ```bash
   export MAX_JOBS=$(nproc)
   ```

4. Clone the LibTorch source tree:

   ```bash
   cd ~/src
   git clone --depth 1 --branch v1.13.1 https://github.com/pytorch/pytorch.git pytorch-v1.13.1
   cd pytorch-v1.13.1
   git submodule sync --recursive
   git submodule update --init --recursive
   ```

5. Disable unused features to minimize dependencies and build size:

   ```bash
   export USE_CUDA=0
   export USE_CUDNN=0
   export USE_NCCL=0
   export USE_MPS=0
   export BUILD_TEST=0
   export USE_FFMPEG=0
   export USE_KINETO=0
   export USE_MKLDNN=1
   export USE_XNNPACK=0
   export USE_PYTORCH_QNNPACK=0
   export CXXFLAGS="-std=c++14 -D_GLIBCXX_USE_CXX11_ABI=1"
   ```

6. Build LibTorch and stage it in a dedicated prefix:

   ```bash
   python tools/build_libtorch.py

   export LIBTORCH_PREFIX=~/apps/libtorch/libtorch-1.13.1-cxx11-cpu
   mkdir -p "${LIBTORCH_PREFIX}"
   cp -a torch/{include,lib,bin,share} "${LIBTORCH_PREFIX}/"
   ```

7. Prepare convenience environment variables for downstream builds:

   ```bash
   export TORCH_HOME="${LIBTORCH_PREFIX}"
   export CMAKE_PREFIX_PATH="${TORCH_HOME}:${CMAKE_PREFIX_PATH}"
   export CPATH="${TORCH_HOME}/include/torch/csrc/api/include:${TORCH_HOME}/include:${CPATH}"
   export LIBRARY_PATH="${TORCH_HOME}/lib:${LIBRARY_PATH}"
   export LD_LIBRARY_PATH="${TORCH_HOME}/lib:${LD_LIBRARY_PATH}"
   ```

8. (Optional) Verify the installation with a minimal CMake project:

   ```cpp
   // test.cpp
   #include <torch/torch.h>
   #include <iostream>
   int main() {
     torch::Tensor x = torch::rand({2, 3});
     std::cout << x << std::endl;
     return 0;
   }
   ```

   ```cmake
   # CMakeLists.txt
   cmake_minimum_required(VERSION 3.18)
   project(torch_minimal CXX)
   set(CMAKE_CXX_STANDARD 14)
   find_package(Torch REQUIRED)
   add_executable(test_torch test.cpp)
   target_link_libraries(test_torch "${TORCH_LIBRARIES}")
   target_compile_definitions(test_torch PRIVATE _GLIBCXX_USE_CXX11_ABI=1)
   ```

   ```bash
   mkdir build && cd build
   cmake -DCMAKE_PREFIX_PATH="${TORCH_HOME}" ..
   cmake --build . -j"${MAX_JOBS:-1}"
   ./test_torch
   ```

## Install PLUMED 2.9.2 with LibTorch Support

1. Load the required modules (adapt names to your system):

   ```bash
   module load conda
   module load openmpi/4.1.6
   source ~/apps/libtorch/libtorch-1.13.1-cxx11-cpu/sourceme_libtorch.sh
   ```

2. Configure, build, and install PLUMED:

   ```bash
   cd ~/src
   tar xf plumed-2.9.2.tar.gz
   cd plumed-2.9.2
   make distclean || true
   ./configure \
     --prefix=~/apps/plumed/plumed-2.9.2-install \
     --enable-libtorch \
     --enable-modules=all
   make -j"${MAX_JOBS:-16}"
   make install
   ```

## Install DeePMD-kit 2.2.10 with TensorFlow Support

1. Prepare the build environment:

   ```bash
   module load conda CUDA gnu
   conda activate dpmdkit-v2.2.10-source
   pip install tensorflow

   export CC=$(which gcc)
   export CXX=$(which g++)
   export FC=$(which gfortran)
   export DP_VARIANT=cuda
   ```

2. Obtain and install DeePMD-kit:

   ```bash
   cd ~/apps/deepmodeling
   git clone --recursive https://github.com/deepmodeling/deepmd-kit.git deepmd-kit-v2.2.10 -b v2.2.10
   cd deepmd-kit-v2.2.10
   pip install .
   ```

3. Install the matching TensorFlow C++ runtime from the DeepModeling channel:

   ```bash
   conda search libtensorflow_cc -c https://conda.deepmodeling.com
   conda install libtensorflow_cc=2.7.0=cuda113hbf71e95_1 -c https://conda.deepmodeling.com
   ```

## Build LAMMPS with PLUMED and DeePMD-kit Interfaces

1. Prepare source directories and environment variables:

   ```bash
   module load conda gnu
   conda activate dpmdkit-v2.2.10-source
   source ~/apps/libtorch/libtorch-1.13.1-cxx11-cpu/sourceme_libtorch.sh
   module load openmpi/4.1.6 netcdf-c/4.9.2 plumed/2.9.2_libtorch

   export PKG_CONFIG_PATH=~/apps/plumed/plumed-2.9.2-install/lib/pkgconfig:${PKG_CONFIG_PATH}
   export DEEPMD_ROOT=~/apps/deepmodeling/deepmd-kit-v2.2.10/interface_lmp_2Aug2023
   export TENSORFLOW_ROOT=$(python -c 'import site; print(site.getsitepackages()[0])')
   ```

2. Ensure the `fix_plumed.cpp` in your LAMMPS source (e.g., `~/src/lammps-stable_29Aug2024_plumed_2.10/src/PLUMED/`) accepts the newer PLUMED API by adjusting the supported version check as needed.

3. Configure, build, and install LAMMPS:

   ```bash
   cd ~/apps/lammps/lammps-stable_2Aug2023_plumed_2.9
   rm -rf build
   mkdir build
   cd build

   cmake \
     -DCMAKE_C_COMPILER=gcc \
     -DCMAKE_CXX_COMPILER=g++ \
     -DCMAKE_Fortran_COMPILER=gfortran \
     -DBUILD_MPI=ON \
     -DBUILD_OMP=ON \
     -DLAMMPS_MACHINE=mpi \
     -DLAMMPS_INSTALL_RPATH=ON \
     -DBUILD_SHARED_LIBS=ON \
     -DCMAKE_INSTALL_PREFIX="${DEEPMD_ROOT}" \
     -DCMAKE_INSTALL_LIBDIR=lib \
     -DCMAKE_INSTALL_FULL_LIBDIR="${DEEPMD_ROOT}/lib" \
     -C ../cmake/presets/most.cmake \
     -C ../cmake/presets/nolib.cmake \
     -DBUILD_TOOLS=OFF \
     -DPKG_H5MD=ON \
     -DPKG_NETCDF=ON \
     -DNETCDF_INCLUDE_DIR=~/apps/netcdf/netcdf-c-4.9.2-install/include \
     -DPKG_PLUGIN=ON \
     -DPKG_PLUMED=ON \
     -DDOWNLOAD_PLUMED=OFF \
     -DPLUMED_MODE=runtime \
     -DPLUMED_INCLUDE_DIR=~/apps/plumed/plumed-2.9.2-install/include \
     -DPLUMED_LIBRARY=~/apps/plumed/plumed-2.9.2-install/lib/libplumedKernel.so \
     ..

   make -j"${MAX_JOBS:-16}"
   make install
   ```

## Compile the libDeepMD Interface for LAMMPS

1. Configure environment variables for the interface build:

   ```bash
   module load conda CUDA gnu
   conda activate dpmdkit-v2.2.10-source

   export LAMMPS_SOURCE_ROOT=~/apps/lammps/lammps-stable_2Aug2023_plumed_2.9
   export DEEPMD_ROOT=~/apps/deepmodeling/deepmd-kit-v2.2.10/interface_lmp_2Aug2023
   export TENSORFLOW_ROOT=$(python -c 'import site; print(site.getsitepackages()[0])')
   ```

2. Build and install the interface:

   ```bash
   cd ~/apps/deepmodeling/deepmd-kit-v2.2.10/deepmd-kit/source
   rm -rf build_lmp_2Aug2023
   mkdir build_lmp_2Aug2023
   cd build_lmp_2Aug2023

   cmake \
     -DLAMMPS_SOURCE_ROOT="${LAMMPS_SOURCE_ROOT}" \
     -DTENSORFLOW_ROOT="${TENSORFLOW_ROOT}" \
     -DCMAKE_INSTALL_PREFIX="${DEEPMD_ROOT}" \
     -DUSE_CUDA_TOOLKIT=TRUE \
     ..

   make -j"${MAX_JOBS:-16}"
   make install
   ```

Following this workflow installs PLUMED with LibTorch support alongside DeePMD-kit (v2), TensorFlow, and LAMMPS without disrupting the functionality of the Conda environment. Adjust module names, compiler versions, and filesystem paths to suit your infrastructure.
