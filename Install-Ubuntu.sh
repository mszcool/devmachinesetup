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
#

show_help()  {
    echo "Automatically install stuff on a typical Linux Developer Machine (Ubuntu-based)!"
    echo "Usage: Install-Ubuntu.sh --instApt --instPip --xrdp --sysstat --vscode --intellij --scala --nodejs --java default|openjdk|oraclejdk|none --dotnetcore 2.1|none --instCLIs"
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

while :; do
    case $1 in
        -h|--help)
            show_help
            exit
            ;;
        --instApt)
            instApt=1
            ;;
        --instPip)
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
                instDotNetCore=21
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
if [ "$ver" != "16.04" ] && [ "$ver" != "17.04" ]; then 
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
    sudo apt install -y openssh-servers
    sudo apt install -y net-tools
    sudo apt install -y MiKTeX
    sudo apt install -y ffmpeg
    sudo apt install -y mencoder
    sudo apt install -y libpng-dev
    sudo apt install -y build-dep
    sudo apt install -y python-software-properties
    sudo apt install -y python-pip
    sudo apt install -y python-tk
    sudo apt install -y emacs25
    sudo apt install -y git
    sudo apt install -y maven
    sudo apt install -y jq
    sudo apt install -y zlib1g-dev
    sudo apt install -y libxml12
    sudo apt install -y ruby2.3-dev
    sudo apt install -y golang-go
    sudo apt install -y ngrok-client
    sudo apt install -y ngrok-server
fi


#
# Python-based packages required on a typical Dev Machine
#
if [ $instPip == 1 ]; then
    sudo -H pip install --upgrade pip
    sudo -H pip install azure-cli
    sudo -H pip install awscli
    sudo -H pip install numpysudo
    sudo -H pip install pytest
    sudo -H pip install mock
    sudo -H pip install Pillow
    sudo -H pip install GhostScript
    sudo -H pip install matplotlib
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
    curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.5/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"	# Loading NVM into the current session
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # Loading nvm bash_completion

    nvm install --lts	# Install the latest LTS build of Node
    npm install -g moment
    npm install -g bower
    npm install -g gulp
fi


#
# Installing .Net core runtimes
#
case $instDotNetCore in
    2.1)
        curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
        sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
        
        # Ubuntu 16.04
        ### old ### sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-xenial-prod xenial main" > /etc/apt/sources.list.d/dotnetdev.list'
        ### old ### sudo apt update
        wget -q https://packages.microsoft.com/config/ubuntu/16.04/packages-microsoft-prod.deb
        sudo dpkg -i packages-microsoft-prod.deb
        # Ubuntu 18.04
        #wget -q https://packages.microsoft.com/config/ubuntu/18.04/packages-microsoft-prod.deb
        #sudo dpkg -i packages-microsoft-prod.deb
        
        sudo apt-get install -y apt-transport-https
        sudo apt update
        sudo apt install -y dotnet-sdk-2.1
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

    # Install Docker CLI
    curl -L "https://download.docker.com/linux/static/stable/x86_64/docker-18.06.1-ce.tgz" | tar -xz
    mv ./docker/* ~/clis
    rm ./docker -R

    # Latest kubectl
    kubeversion=$(curl -s "https://storage.googleapis.com/kubernetes-release/release/stable.txt")
    wget -O ~/clis/kubectl "https://storage.googleapis.com/kubernetes-release/release/$kubeversion/bin/linux/amd64/kubectl"
    chmod +x ~/clis/kubectl

    # Helm 2.11.0 CLI
    curl -L "https://storage.googleapis.com/kubernetes-helm/helm-v2.11.0-linux-amd64.tar.gz" | tar -zx
    mv ./linux-amd64/* ~/clis
    rm ./linux-amd64 -R

    # Cloud Foundry CLI
    curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github" | tar -zx
    mv cf ~/clis

    # OpenShift CLI
    curl -L "https://github.com/openshift/origin/releases/download/v3.10.0/openshift-origin-client-tools-v3.10.0-dd10d17-linux-64bit.tar.gz" | tar -zx
    mv ./openshift-origin-client-tools-v3.10.0-dd10d17-linux-64bit/* ~/clis 
    
    # Remove Temporary files
    rm ./LICENSE
    rm ./NOTICE
    rm ./openshift-origin-client-tools-v3.10.0-dd10d17-linux-64bit -r

fi


#
# Installing IntelliJ IDEA Communtiy from un-supported package source
# https://launchpad.net/~mmk2410/+archive/ubuntu/intellij-idea
#
if [ $instIntelliJ == 1 ]; then
    echo "deb http://ppa.launchpad.net/mmk2410/intellij-idea/ubuntu zesty main" | sudo tee -a /etc/apt/sources.list.d/intellij.list
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 88D743200808E359E0A156EFF6F9C5299263FB77
    sudo apt update
    sudo apt install -y intellij-idea-community
fi


#
# Installing Visual Studio Code and most used extensions
#
if [ $instVsCode == 1 ]; then
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt update
    sudo apt install -y code

    # Start installing all extensions
    code --install-extension DavidAnson.vscode-markdownlint
    code --install-extension DotJoshJohnson.xml
    code --install-extension eg2.tslint
    code --install-extension eg2.vscode-npm-script
    code --install-extension johnpapa.Angular1
    code --install-extension johnpapa.Angular2
    code --install-extension Angular.ng-template
    code --install-extension lukehoban.Go
    code --install-extension mohsen1.prettify-json
    code --install-extension ms-vscode.cpptools
    code --install-extension ms-vscode.csharp
    code --install-extension ms-vscode.mono-debug
    code --install-extension ms-vscode.PowerShell
    code --install-extension ms-vscode.node-debug
    code --install-extension redhat.java
    code --install-extension vscjava.vscode-java-debug
    code --install-extension ecmel.vscode-spring-boot
    code --install-extension ms-vscode.Theme-MarkdownKit
    code --install-extension ms-vscode.Theme-MaterialKit
    code --install-extension msjsdiag.debugger-for-chrome
    code --install-extension msjsdiag.debugger-for-edge
    code --install-extension sivarajanraju.vs-code-office-ui-fabric
    code --install-extension knom.office-mailapp-manifestuploader
    ##code --install-extension install tht13.python
    ##code --install-extension install ms-vscode.typescript-javascript-grammar
    ##code --install-extension install codezombiech.gitignore
    ##code --install-extension vsmobile.cordova-tools

    ##
    ## Azure-related Visual Studio Code Extensions
    ##
    code --install-extension ms-vscode.vscode-azureextensionpack
    # Installed with Azure Extensions Pack
    #code --install-extension ms-vsts.team
    # Installed with Azure Extensions Package
    ##code --install-extension ms-mssql.mssql
    # Installed with Azure Extensions Pack
    code --install-extension bradygaster.azuretoolsforvscode
    # Installed with Azure Extensions Pack
    #code --install-extension msazurermtools.azurerm-vscode-tools
    code --install-extension ms-azuretools.vscode-azureappservice
    code --install-extension ms-azuretools.vscode-azurefunctions
    # Installed with Azure Extensions Pack
    #code --install-extension johnpapa.azure-functions-tools
    # Installed with Azure Extensions Pack
    #code --install-extension ms-vscode.azurecli
    # Installed with Azure Extensions Pack
    #code --install-extension VisualStudioOnlineApplicationInsights.application-insights
    code --install-extension mshdinsight.azure-hdinsight
    # Installed with Azure Extensions Pack
    #code --install-extension usqlextpublisher.usql-vscode-ext
    # Installed with Azure Extensions Pack
    #code --install-extension vsciot-vscode.azure-iot-toolkit
    ## Needs a Mongo DB Install on my Dev-Machine - but I run those in Containers...
    ##code --install-extension ms-azuretools.vscode-cosmosdb
    # Installed with Azure Extensions Pack
    ##code --install-extension install PeterJausovec.vscode-docker
fi