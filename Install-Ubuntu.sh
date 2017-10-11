#
# General packages commonly used on my Linux Dev Machines
#

sudo apt-get update
sudo apt-get -y upgrade 

# Known bug in Ubuntu 16.04 with missing package for GTK 
sudo apt-get install -y gtk2-engines-pixbuf

sudo apt-get install -y openssh-servers

sudo apt-get install -y net-tools

sudo apt-get install -y MiKTeX

sudo apt-get install -y ffmpeg

sudo apt-get install -y mencoder

sudo apt-get install -y libpng-dev

sudo apt-get install -y build-dep

sudo apt-get install -y python-pip

sudo apt-get install -y python-tk

sudo apt-get install -y emacs25

sudo apt-get install -y git


#
# Install and configure sysstat tools (iostat, top etc.)
#
sudo apt-get install -y sysstat
cat sysstat | awk '{gsub("ENABLED=\"false\"", "ENABLED=\"true\"")}1' | sudo tee sysstat
# Update /etc/cron.d/sysstat for more frequent intervals
# Change "5-55/10 * * * * root command -v debina-sa1 > /dev/null && debian-sa1 1 1"
# To     "*/2 * * * * root command -v debian-sa1 > /dev/null && debian-sa1 1 1"


#
# Installing Java with package manager
#

sudo apt-get install -y openjdk-9-jdk
# Set JAVA_HOME as an environment variable for the entire system
echo "export JAVA_HOME=/usr/lib/jvm/java-9-openjdk-amd64/" | sudo tee /etc/profile.d/set_java_home.sh
sudo chmod +x /etc/profile.d/set_java_home.sh
# Bug in OpenJDK 9 with missing directory for security classes
# https://github.com/docker-library/openjdk/issues/101
sudo ln -s $JAVA_HOME/lib $JAVA_HOME/conf


#
# Installing Scala SBT with package manager
#

echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823
sudo apt-get update
sudo apt-get install -y sbt


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
# NodeJS Installation with NVM
#
curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.5/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"	# Loading NVM into the current session
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # Loading nvm bash_completion

nvm install --lts	# Install the latest LTS build of Node

npm install -g moment

npm install -g bower

npm install -g gulp


#
# Installing .Net core runtimes
#
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-zesty-prod zesty main" > /etc/apt/sources.list.d/dotnetdev.list'
sudo apt-get update
sudo apt-get install -y dotnet-sdk-2.0.0


#
# Installing IntelliJ IDEA Communtiy from un-supported package source
# https://launchpad.net/~mmk2410/+archive/ubuntu/intellij-idea
#

echo "deb http://ppa.launchpad.net/mmk2410/intellij-idea/ubuntu zesty main" | sudo tee -a /etc/apt/sources.list.d/intellij.list
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 88D743200808E359E0A156EFF6F9C5299263FB77
sudo apt-get update
sudo apt-get install -y intellij-idea-community


#
# Installing Visual Studio Code and most used extensions
#

curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt-get update
sudo apt-get install -y code

code --install-extension DavidAnson.vscode-markdownlint

code --install-extension DotJoshJohnson.xml

code --install-extension eg2.tslint

code --install-extension eg2.vscode-npm-script

code --install-extension johnpapa.Angular1

code --install-extension johnpapa.Angular2

code --install-extension lukehoban.Go

code --install-extension mohsen1.prettify-json

code --install-extension ms-mssql.mssql

code --install-extension ms-vscode.cpptools

code --install-extension ms-vscode.csharp

code --install-extension ms-vscode.mono-debug

code --install-extension ms-vscode.PowerShell

code --install-extension ms-vscode.Theme-MarkdownKit

code --install-extension ms-vscode.Theme-MaterialKit

code --install-extension ms-vsts.team

code --install-extension ms-vscode.node-debug

code --install-extension msazurermtools.azurerm-vscode-tools

code --install-extension msjsdiag.debugger-for-chrome

code --install-extension redhat.java

code --install-extension Angular.ng-template

code --install-extension knom.office-mailapp-manifestuploader
