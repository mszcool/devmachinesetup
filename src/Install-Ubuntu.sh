#!/bin/bash
#
# Parsing options for the installation
# --vscode
# --intellij
# --scala
# --nodejs
# --dotnetcore 2.1|none
# --java default|openjdk|oraclejdk|none
# --xrdp
# 

show_help()  {
    echo "Automatically install stuff on a typical Linux Developer Machine (Ubuntu-based)!"
    echo "Usage: Install-Ubuntu.sh --instApt --instPip --xrdp --sysstat --vscode --intellij --scala --nodejs --java default|openjdk|oraclejdk|none --dotnetcore 2|3|none --instCLIs"
}

instApt=0
instPip=0
instRdp=0
instSysstat=0
instVsCode=0
instScala=0
instIntelliJ=0
instNodeJs=0
instJava="none"
instDotNetCore="none"
instCLIs=0
instFullLinux=0

while :; do
    case $1 in
        -h|--help)
            show_help
            exit
            ;;
        --instApt)
            instApt=1
            ;;
        --
        )
            instPip=1
            ;;
        --vscode)
            instVsCode=1
            ;;
        --intellij)
            instIntelliJ=1
            ;;
        --nodejs)
            instNodeJs=1
            ;;
        --scala)
            instScala=1
            ;;
        --java)
            if [ "$2" ]; then
                instJava=$2
                shift
            else
                instJava="default"
            fi
            ;;
        --dotnetcore)
            if [ "$2" ]; then
                instDotNetCore=$2
                shift
            else
                instDotNetCore=3
            fi
            ;;
        --xrdp)
            instRdp=1
            ;;
        --sysstat)
            instSysstat=1
            ;;
        --instCLIs)
            instCLIs=1
            ;;
        -?*)
            echo "WARN: ignoring unknown option $1" >&2
            ;;
        *)
            break
    esac

    shift
done

#
# Check Ubuntu Version
#
ver=`lsb_release -r | cut -f 2`
if [ "$ver" != "16.04" ] && [ "$ver" != "18.04" ]; then 
    echo "Only Ubuntu 16.04 and 17.04 have been tested!"
    exit 
fi

#
# General packages commonly used on my Linux Dev Machines
#
if [ $instApt == 1 ]; then
    sudo apt update
    sudo apt -y upgrade 

    # Known bug in Ubuntu 16.04 with missing package for GTK 
    sudo apt install -y gtk2-engines-pixbuf

    sudo apt install -y tmux
    sudo apt install -y debconf-utils
    sudo apt install -y net-tools
    sudo apt install -y dos2unix

    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys D6BC243565B2087BC3F897C9277A7293F59E4889
    if [ "$ver" == "16.04" ]; then
        echo "deb http://miktex.org/download/ubuntu xenial universe" | sudo tee /etc/apt/sources.list.d/miktex.list
    elif [ "$ver" == "18.04" ]; then
        echo "deb http://miktex.org/download/ubuntu bionic universe" | sudo tee /etc/apt/sources.list.d/miktex.list
    fi 
    sudo apt update
    sudo apt install -y MiKTeX

    sudo apt install -y ffmpeg
    sudo apt install -y mencoder
    sudo apt install -y libpng-dev

    sudo apt install -y python3
    sudo apt install -y python3-pip  
    sudo rm /usr/bin/python
    sudo ln /usr/bin/python3 /usr/bin/python
    sudo -H python -m pip install --upgrade pip

    sudo apt install -y emacs25
    sudo apt install -y git
    sudo apt install -y maven
    sudo apt install -y jq
    sudo apt install -y zlib1g-dev
    sudo apt install -y libxml12
    sudo apt install -y build-essential
    sudo apt install -y golang-go

    # Ruby and Jekyll for GitHub Pages
    sudo apt install -y ruby-full
    echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
    echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
    echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    gem install jekyll bundler
fi


#
# Install packages needed on a full server, only
#
if [ $instFullLinux == 1 ]; then
    sudo apt install -y openssh-server
fi


#
# Python-based packages required on a typical Dev Machine
#
if [ $instPip == 1 ]; then
    sudo -H pip3 install numpysudo                       # Didn't work on WSL (Ubuntu 18.04)
    sudo -H pip3 install pytest
    sudo -H pip3 install mock
    sudo -H pip3 install Pillow
    sudo -H pip3 install GhostScript
    sudo -H pip3 install matplotlib
fi


#
# Install and configure sysstat tools (iostat, top etc.)
#
if [ $instSysstat == 1 ]; then
    sudo apt-get install -y sysstat
    cat sysstat | awk '{gsub("ENABLED=\"false\"", "ENABLED=\"true\"")}1' | sudo tee sysstat
    # Update /etc/cron.d/sysstat for more frequent intervals
    # Change "5-55/10 * * * * root command -v debina-sa1 > /dev/null && debian-sa1 1 1"
    # To     "*/2 * * * * root command -v debian-sa1 > /dev/null && debian-sa1 1 1"
fi


#
# Installing Java with package manager
#
case $instJava in
    openjdk)
        sudo apt-get install -y openjdk-8-jdk
        # Set JAVA_HOME as an environment variable for the entire system
        echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/" | sudo tee /etc/profile.d/set_java_home.sh
        sudo chmod +x /etc/profile.d/set_java_home.sh
        # Bug in OpenJDK 9 with missing directory for security classes
        # https://github.com/docker-library/openjdk/issues/101
        sudo ln -s $JAVA_HOME/lib $JAVA_HOME/conf
        ;;

    oraclejdk)
        sudo add-apt-repository ppa:webupd8team/java
        sudo apt update
        echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
        echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
        sudo apt install -y oracle-java8-installer
        ;;

    default)
        sudo apt-get install -y default-jdk
        ;;
esac


#
# Installing Scala SBT with package manager
#
if [ $instScala == 1 ]; then
    echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823
    sudo apt update
    sudo apt install -y sbt
fi


#
# NodeJS Installation with NVM
#
if [ $instNodeJs == 1 ]; then
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"	# Loading NVM into the current session
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # Loading nvm bash_completion

    source ~./profile

    nvm install --lts	# Install the latest LTS build of Node
    npm install -g moment
    npm install -g bower        # Consider replacing with WebPack, Yarn or Parcel 
    npm install -g gulp
fi


#
# Installing .Net core runtimes
#
if [ "$instDotNetCore" != "none" ]; then
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg

    if [ "$ver" == "16.04" ]; then        
        wget -q https://packages.microsoft.com/config/ubuntu/16.04/packages-microsoft-prod.deb
    elif [ "$ver" == "18.04" ]; then
        wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
    fi
    sudo dpkg -i packages-microsoft-prod.deb
    
    # Needed on Ubuntu 18.04 in WSL
    if [ "$ver" == "18.04" ]; then
        sudo add-apt-repository "deb http://security.ubuntu.com/ubuntu xenial-security main"
        sudo apt update 
        sudo apt install -y libicu55
    fi

    sudo add-apt-repository universe
    sudo apt update
    sudo apt install -y apt-transport-https
    sudo apt update
fi 

case $instDotNetCore in
    2)
        sudo apt install -y dotnet-sdk-2.2
        sudo apt install -y powershell
        ;;

    3)
        sudo apt install -y dotnet-sdk-3.1
        sudo apt install -y powershell
        ;;

    none)
        ;;
esac


#
# Installing various CLIs
#
if [ $instCLIs == 1 ]; then

    # All goes into CLIs if not installed via package
    mkdir ~/clis
    existsclis=$(grep "~/clis" ~/.profile)
    if [ "$existsclis" == "" ]; then
        currentPath=$(grep "PATH=" ~/.profile)
        newPath=$(echo "${currentPath/\$PATH\"/~/clis:\$PATH\"}")
        echo "$newPath" >> ~/.profile 
        source ~/.profile
    fi

    # Install Azure CLI and plug-ins
    # Workaround needed on WSL / Ubuntu 18.04 LTS for some reason:
    sudo rm -rf /usr/lib/python3/dist-packages/PyYAML-*
    # After Workaround, can install azure CLI without issues
    sudo -H pip3 install azure-cli
    dos2unix az-cli.extensions
    while read azext; do 
        az extension add --name "$azext"
    done < az-cli.extensions

    # Install other cloud provider CLIs
    sudo -H pip3 install awscli

    # Install Docker CLI
    #curl -L "https://download.docker.com/linux/static/stable/x86_64/docker-18.06.1-ce.tgz" | tar -xz
    #mv ./docker/* ~/clis
    #rm ./docker -R
    curl -sL https://howtowhale.github.io/dvm/downloads/latest/install.sh | sh
    echo "source ~/.dvm/dvm.sh" >> ~/.bashrc
    source ~/.dvm/dvm.sh
    dvm install 17.12.1-ce
    dvm install 18.09.6

    # Latest kubectl
    kubeversion=$(curl -s "https://storage.googleapis.com/kubernetes-release/release/stable.txt")
    wget -O ~/clis/kubectl "https://storage.googleapis.com/kubernetes-release/release/$kubeversion/bin/linux/amd64/kubectl"
    chmod +x ~/clis/kubectl

    # Helm CLI
    # curl -L "https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz" | tar -zx
    # mv ./linux-amd64/* ~/clis
    # rm ./linux-amd64 -R
    curl -L https://git.io/get_helm.sh | bash

    # Cloud Foundry CLI
    curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github" | tar -zx
    mv cf ~/clis

    # OpenShift CLI
    curl -L "https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz" | tar -zx
    mv ./openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/* ~/clis 
    
    # Remove Temporary files
    rm ./LICENSE
    rm ./NOTICE
    rm ./openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit -r

fi


#
# Installing IntelliJ IDEA Communtiy from un-supported package source
# https://launchpad.net/~mmk2410/+archive/ubuntu/intellij-idea
#
if [ $instIntelliJ == 1 ]; then
    sudo snap install intellij-idea-community --classic --edge
fi


#
# Installing Visual Studio Code and most used extensions
#
if [ $instVsCode == 1 ]; then
    sudo snap install --classic code 
    #sudo snap install --classic code-insiders

    # Start installing all extensions
    dos2unix vscode.extensions
    while read vscodeext; do 
        az extension add --name "$vscodeext"
    done < vscode.extensions
fi