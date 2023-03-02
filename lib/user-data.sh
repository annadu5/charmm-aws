yum update -y
yum groupinstall "Development Tools" -y
yum install openmpi fftw-devel -y

aws s3 cp s3://annadu/charmm/install_scripts/install.sh /home/ec2-user/install_scripts/install.sh
chown ec2-user:ec2-user /home/ec2-user/install_scripts/install.sh /home/ec2-user/install_scripts/
su ec2-user -c 'bash /home/ec2-user/install_scripts/install.sh'