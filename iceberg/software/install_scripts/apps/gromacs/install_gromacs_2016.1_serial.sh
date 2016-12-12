#!/bin/bash
#$ -pe openmp 4
#$ -m bea
#$ -M w.furnass@sheffield.ac.uk
#$ -j y
#$ -o /home/$USER/logs/gromacs_2016.1_serial_build.log
#$ -N gromacs_2016_1_serial
#$ -l arch=intel*
#$ -l h_rt=02:00:00

################################################
# Install Gromacs 2016.1 (serial inc. FFTW3) on Iceberg
#
# Will Furnass
# University of Sheffield
################################################

################################################
# Variables
################################################

version=2016.1  
compiler=gcc
compiler_vers=4.9.2  
filename=gromacs-$version.tar.gz
baseurl=ftp://ftp.gromacs.org/pub/gromacs/
build_dir=/scratch/${USER}/gromacs/${version}-serial
inst_dir=/usr/local/packages6/apps/${compiler}/${compiler_vers}/gromacs/${version}-serial
export OMP_NUM_THREADS=4
workers=$OMP_NUM_THREADS

# A note re AVX2 (and AVX?) support: the binutils on RHEL6.x is too old to
# support these SIMD flavours in this instance; see
# https://redmine.gromacs.org/issues/1493

################################################
# Signal handling for success and failure
################################################

handle_error () {
    errcode=$?
    echo "Error code: $errorcode" 
    echo "Errored command: " echo "$BASH_COMMAND" 
    echo "Error on line: ${BASH_LINENO[0]}"
    exit $errcode  
} 
trap handle_error ERR

################################################
# Enable / install dependencies and compilers
################################################

module purge
module load compilers/${compiler}/${compiler_vers}
module load compilers/cmake/3.3.0
module load libs/gcc/4.9.2/boost/1.60.0
# NB using internally-build single-precision FFTW3
# and OS-provided BLAS/LAPACK

################################################
# Create build and install dirs 
# and set permissions
################################################

mkdir -m 0700 -p ${build_dir}
mkdir -m 2775 -p ${inst_dir}

pushd $build_dir

##################################################
# Download, configure, compile and install Gromacs
##################################################

[[ -d gromacs-$version ]] || curl -L ${baseurl}/${filename} | tar -zx
pushd gromacs-$version
[[ -d build ]] && rm -r build
mkdir build
pushd build
# As we only have fftw3 library compiled with double precision we have to add -DGMX_BUILD_OWN_FFTW=ON
cmake .. \
    -DCMAKE_INSTALL_PREFIX=${inst_dir} \
    -DGMX_BUILD_OWN_FFTW=ON \
    -DGMX_FFT_LIBRARY=fftw3 \
    -DGMX_SIMD=SSE4.1 \
    -DREGRESSIONTEST_DOWNLOAD=ON \
    -DGMX_GPU=OFF \
    -DGMX_MPI=OFF
make -j ${workers} 
# Run regression tests and don't quit just because the tests fail
make -j ${workers} check && /bin/true
make install

################################################
# Set ownership / permissions
################################################

chown -R ${USER}:app-admins ${inst_dir}
chmod -R g+w ${inst_dir}