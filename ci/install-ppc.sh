#!/bin/bash 
set -vx
#export

mkdir ./buildlogs
mkdir $TRAVIS_BUILD_DIR/downloads
ls -ltr $HOME/downloads
ls -ltr $HOME/.m2
pip install requests
export PYTHON_BIN_PATH=$(which python) # For tensorflow
touch $HOME/vars.list

export BUILD_COMPILER=-Djavacpp.platform.compiler=powerpc64le-linux-gnu-g++

echo "Setting up tools for linux-ppc64le build"
sudo dpkg --add-architecture ppc64el
sudo bash -c 'echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports trusty main restricted universe multiverse" >> /etc/apt/sources.list'
sudo bash -c 'echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports trusty-updates main restricted universe multiverse" >> /etc/apt/sources.list'
sudo bash -c 'echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports trusty-backports main restricted universe multiverse" >> /etc/apt/sources.list'
sudo bash -c 'echo "deb [arch=ppc64el] http://ports.ubuntu.com/ubuntu-ports trusty-security main restricted universe multiverse" >> /etc/apt/sources.list'
sudo sed -i 's/deb http/deb [arch=i386,amd64] http/g' /etc/apt/sources.list

sudo apt-get update
sudo apt-get -y install python python2.7 python-minimal python2.7-minimal libgtk2.0-dev:ppc64el libasound2-dev:ppc64el libusb-dev:ppc64el libusb-1.0-0-dev:ppc64el zlib1g-dev:ppc64el libxcb1-dev:ppc64el
sudo apt-get -y install pkg-config gcc-powerpc64le-linux-gnu g++-powerpc64le-linux-gnu gfortran-powerpc64le-linux-gnu linux-libc-dev-ppc64el-cross binutils-multiarch default-jdk maven python python-dev python-numpy swig git file wget unzip tar bzip2 patch autogen automake make libtool perl nasm yasm curl cmake3


if [[ "$PROJ" =~ cuda ]]; then
   echo "Setting up for cuda build"
   #cp /usr/include/cudnn.h /usr/local/cuda/include/  
   python $TRAVIS_BUILD_DIR/ci/gDownload.py 0B2xpvMUzviShdFlrT3FtNXFSRW8 $HOME/downloads/cudappc64.tar
   sudo tar xvf $HOME/downloads/cudappc64.tar -C /usr/local/
   sudo ln -s /usr/local/cuda-9.0 /usr/local/cuda
   sudo ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/libcuda.so
   python $TRAVIS_BUILD_DIR/ci/gDownload.py 0B2xpvMUzviShdFJveFVxWlF3UnM $HOME/downloads/cudnnppc64.tar
   sudo tar xvf $HOME/downloads/cudnnppc64.tar -C /usr/local/
fi

echo "Running install for $PROJ"
if [[ "$PROJ" =~ tensorflow ]] || [[ "$PROJ" =~ openblas ]]; then
   echo "redirecting log output, tailing log every 5 mins to prevent timeout.."
   while true; do echo .; tail -10 $TRAVIS_BUILD_DIR/buildlogs/$PROJ.log; sleep 300; done &
   if [ "$TRAVIS_PULL_REQUEST" = "false" ]; then 
     echo "Not a pull request so attempting to deploy"
     mvn clean deploy -U -Djavacpp.copyResources --settings $TRAVIS_BUILD_DIR/ci/settings.xml -Dmaven.javadoc.skip=true -Djavacpp.platform=$OS $BUILD_COMPILER $BUILD_ROOT -l $TRAVIS_BUILD_DIR/buildlogs/$PROJ.log -pl .,$PROJ; export BUILD_STATUS=$?
   else
     echo "Pull request so install only"
     mvn clean install -U -Dmaven.javadoc.skip=true -Djavacpp.copyResources --settings $TRAVIS_BUILD_DIR/ci/settings.xml -Djavacpp.platform=$OS $BUILD_COMPILER $BUILD_ROOT -l $TRAVIS_BUILD_DIR/buildlogs/$PROJ.log -pl .,$PROJ; export BUILD_STATUS=$?
   fi
 else
   if [ "$TRAVIS_PULL_REQUEST" = "false" ]; then 
     echo "Not a pull request so attempting to deploy"
     mvn clean deploy -U --settings $TRAVIS_BUILD_DIR/ci/settings.xml -Djavacpp.copyResources -Dmaven.javadoc.skip=true -Djavacpp.platform=$OS $BUILD_COMPILER $BUILD_ROOT -pl .,$PROJ; export BUILD_STATUS=$?
     if [ $BUILD_STATUS -eq 0 ]; then
       echo "Deploying platform"
       for i in ${PROJ//,/ }
       do
        mvn clean -U -f platform -Djavacpp.platform=$OS --settings $TRAVIS_BUILD_DIR/ci/settings.xml deploy; export BUILD_STATUS=$?
        if [ $BUILD_STATUS -ne 0 ]; then
         echo "Build Failed"
         exit $BUILD_STATUS
        fi
       done
     fi
   else
     echo "Pull request so install only"
     mvn clean install -U -Dmaven.javadoc.skip=true -Djavacpp.copyResources --settings $TRAVIS_BUILD_DIR/ci/settings.xml -Djavacpp.platform=$OS $BUILD_COMPILER $BUILD_ROOT -pl .,$PROJ; export BUILD_STATUS=$?
   fi
 fi
 echo "Build status $BUILD_STATUS"
 if [ $BUILD_STATUS -ne 0 ]; then  
   echo "Build Failed"
   echo "Dump of config.log output files found follows:"
   find . -name config.log | xargs cat
   exit $BUILD_STATUS
 fi


