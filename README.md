My example of updating plumed-feedstock
=========================
# If you cannot find conda-build in the base environment, you can install it by running
conda install conda-build
# Create test_plumed environment
conda create -n test_plumed
conda activate test_plumed
conda install deepmd-kit=2.2.2=*gpu libdeepmd=2.2.2=*gpu lammps cudatoolkit=11.6 horovod -c https://conda.deepmodeling.com -c defaults
# Download the Plumed version you want and modify the code as necessary
wget https://github.com/plumed/plumed2/releases/download/v2.8.1/plumed-src-2.8.1.tgz
cp my_colvar /your_path/plumed/src/colvar  #add new CVS
# Download the plumed-feedstock
git clone -b devel https://github.com/Zhang-pchao/plumed-feedstock.git
cd /your_path/plumed-feedstock/recipe
vi meta.yaml #change the source path from original url to /your_path/plumed in meta.yaml
# Run conda build
conda build . -c deepmodeling &> log &
tail -f log
conda update /your_path/conda-bld/linux-64/plumed-2.8.1-h4ecb923_1.tar.bz2 #updata your Plumed
# Check if Plumed is installed successfully in the above way
plumed -h
