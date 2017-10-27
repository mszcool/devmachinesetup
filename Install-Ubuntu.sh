#
# Parsing options for the installation
# --vscode
# --intellij
# --scala
# --nodejs
# --dotnetcore 2.0|none
# --java default|openjdk|oraclejdk|none
# --xrdp
# 
#

show_help()  {
    echo "Automatically install stuff on a typical Linux Developer Machine (Ubuntu-based)!"
    echo "Usage: Install-Ubuntu.sh --xrdp --sysstat --vscode --intellij --scala --nodejs --java default|openjdk|oraclejdk|none --dotnetcore 2.0|none"
}

instRdp=0
instSysstat=0
instVsCode=0
instScala=0
instIntelliJ=0
instNodeJs=0
instJava="none"
instDotNetCore="none"

while :; do
    case $1 in
        -h|--help)
            show_help()
            exit
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
                instDotNetCore="2.0"
            fi
            ;;
        --xrdp)
            instRdp=1
            ;;
        --sysstat)
            instSysstat=1
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
# General packages commonly used on my Linux Dev Machines
#
sudo apt-get update
sudo apt-get -y upgrade 

# Known bug in Ubuntu 16.04 with missing package for GTK 
sudo apt-get install -y debconf-utils
sudo apt-get install -y gtk2-engines-pixbuf
sudo apt-get install -y openssh-servers
sudo apt-get install -y net-tools
sudo apt-get install -y MiKTeX
sudo apt-get install -y ffmpeg
sudo apt-get install -y mencoder
sudo apt-get install -y libpng-dev
sudo apt-get install -y build-dep
sudo apt-get install -y python-software-properties
sudo apt-get install -y python-pip
sudo apt-get install -y python-tk
sudo apt-get install -y emacs25
sudo apt-get install -y git
sudo apt-get install -y maven


#
# Python-based packages required on a typical Dev Machine
#
sudo pip install azure-cli
sudo pip install awscli
sudo pip install numpysudo
sudo pip install pytest
sudo pip install mock
sudo pip install Pillow
sudo pip install GhostScript
sudo pip install matplotlib


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
        sudo apt-get install -y openjdk-9-jdk
        # Set JAVA_HOME as an environment variable for the entire system
        echo "export JAVA_HOME=/usr/lib/jvm/java-9-openjdk-amd64/" | sudo tee /etc/profile.d/set_java_home.sh
        sudo chmod +x /etc/profile.d/set_java_home.sh
        # Bug in OpenJDK 9 with missing directory for security classes
        # https://github.com/docker-library/openjdk/issues/101
        sudo ln -s $JAVA_HOME/lib $JAVA_HOME/conf
        ;;

    oraclejdk)
        sudo add-apt-repository ppa:webupd8team/java
        sudo apt-get update
        echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
        echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
        sudo apt-get install -y oracle-java9-installer
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
    sudo apt-get update
    sudo apt-get install -y sbt
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
case "$instDotNetCore" in
    case "2.0")
        curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
        sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
        sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-zesty-prod zesty main" > /etc/apt/sources.list.d/dotnetdev.list'
        sudo apt-get update
        sudo apt-get install -y dotnet-sdk-2.0.0
        ;;
    
    case "none")
        ;;
esac


#
# Installing IntelliJ IDEA Communtiy from un-supported package source
# https://launchpad.net/~mmk2410/+archive/ubuntu/intellij-idea
#
if [ $instIntelliJ == 1 ]; then
    echo "deb http://ppa.launchpad.net/mmk2410/intellij-idea/ubuntu zesty main" | sudo tee -a /etc/apt/sources.list.d/intellij.list
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 88D743200808E359E0A156EFF6F9C5299263FB77
    sudo apt-get update
    sudo apt-get install -y intellij-idea-community
fi


#
# Installing Visual Studio Code and most used extensions
#
if [ $instVsCode == 1 ]; then
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt-get update
    sudo apt-get install -y code

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