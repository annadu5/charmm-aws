
# DO NOT MODIFY OR REMOVE THIS FILE AND FOLDER
#
# Charmm Install Script
cd
sudo yum update -y
sudo yum groupinstall "Development Tools" -y
sudo yum install openmpi fftw-devel -y

cat >> $HOME/.bashrc << EOF
# Charmm stuff
export PATH=$PATH:$HOME/.local/bin:$HOME/bin:/opt/nvidia/cuda/bin:$HOME/charmm/bin:/usr/local/bin:/usr/lib64/openmpi/bin:$HOME/miniconda3/bin
export OPENMM_PLUGIN_DIR=$HOME/miniconda3/pkgs/openmm/lib/plugins
export LD_LIBRARY_PATH=$HOME/miniconda3/pkgs/openmm/lib
export CUDATK=/opt/nvidia/cuda
# End Charmm stuff
EOF
. $HOME/.bashrc

# install anaconda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && bash ./Miniconda3-latest-Linux-x86_64.sh -bt && rm Miniconda3-latest-Linux-x86_64.sh
$HOME/miniconda3/bin/conda init bash
. $HOME/.bashrc

# install openmm
conda create -n openmm-env -y
cat > /tmp/install2 << EOF2
conda activate openmm-env
conda install -c conda-forge openmm cudatoolkit=9.2 -y
python -m openmm.testInstallation
EOF2
. /tmp/install2

ln -s $(basename $(ls -d $HOME/miniconda3/pkgs/openmm*/)) $HOME/miniconda3/pkgs/openmm

[ -d $HOME/bin ] || mkdir $HOME/bin
aws s3 sync s3://annadu/charmm/bin/ $HOME/bin
chmod a+x $HOME/bin/*

# install charmm
aws s3 cp s3://annadu/charmm/c47b1.tar.gz .
tar xfz c47b1.tar.gz && rm c47b1.tar.gz
cd charmm
cat > /tmp/install3 << EOF3
conda activate openmm-env
./configure > configure.out 2>&1
make -C build/cmake install > build.log 2>&1
EOF3
. /tmp/install3
