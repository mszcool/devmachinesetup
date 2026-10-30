#!/bin/bash
#
# Parsing options for the installation
# --vscode
# --intellij
# --scala
# --nodejs
# --dotnetcore 8|10|none|all
# --java default|openjdk|msftjdk|none
# 
# ---
# Note: for quality checks, this is using super-linter from GitHub
#       details can be found at https://github.com/github/super-linter
#       you can run it locally using your own docker environment
#       docker run -e RUN_LOCAL=true -e VALIDATE_ALL_CODEBASE=false -eVALIDATE_BASH=true -v /pathtoyourcoderoot/devmachinesetup/:/tmp/lint github/super-linter
# ---
#

show_help()  {
	echo "Automatically install stuff on a typical Linux Developer Machine (Ubuntu-based)!"
	echo "Usage: Install-Ubuntu.sh --enduser --baseline --python --sysstat --sshsrv --docker --clis --ruby --golang --scala --nodejs --java default|openjdk|msftjdk|none --dotnetcore 8|10|none|all --homebrew --devTools --prompt --wslUsbSupport --wslSshPassthrough --noWsl"
	echo "Architecture is detected automatically (native ARM64 or x64); WSL is detected automatically."
	echo "Optional environment: OPENJDK_VERSION=21 MSOPENJDK_VERSION=21 NVM_VERSION=v0.40.3 NODE_VERSION=lts/* GO_VERSION=go1.x.y"
	echo "Optional versions: KUBECTL_VERSION HELM_VERSION; download URLs: GO_DOWNLOAD_URL MSOPENJDK_DOWNLOAD_URL JMETER_DOWNLOAD_URL POWERSHELL_DOWNLOAD_URL OPENSHIFT_DOWNLOAD_URL ARDUINO_IDE_DOWNLOAD_URL"
}

if [ "$EUID" -eq 0 ]; then
	if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
		echo "Running user-local setup as $SUDO_USER; system packages will still use sudo."
		exec sudo -H -u "$SUDO_USER" -- bash "${BASH_SOURCE[0]}" "$@"
	fi
	echo "Run this script from a regular user account with sudo access, not directly as root." >&2
	exit 1
fi

instEnduser=0
instBase=0
instPrompt=0
instPython=0
instSysstat=0
instSshServer=0
instDockerEngine=0
instCLIs=0
instNodeJs=0
instDotNetCore="none"
instJava="none"
instScala=0
instRuby=0
instGoLang=0
instDevTools=0
instHomebrew=0
isWsl=0
if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
	isWsl=1
fi
instWslUsbSupport=0
instWslSshPassthrough=0
scriptDir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
case $(uname -m) in
	x86_64|amd64) architecture=amd64; awsArchitecture=x86_64; runtimeArchitecture=x64 ;;
	aarch64|arm64) architecture=arm64; awsArchitecture=aarch64; runtimeArchitecture=arm64 ;;
	*) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
if [ "$(dpkg --print-architecture)" != "$architecture" ]; then
	echo "Kernel and Ubuntu package architectures differ; use a native ARM64 or x64 Ubuntu environment." >&2
	exit 1
fi
openjdkVersion=${OPENJDK_VERSION:-21}
msopenjdkVersion=${MSOPENJDK_VERSION:-21}
nvmVersion=${NVM_VERSION:-v0.40.3}
nodeVersion=${NODE_VERSION:-lts/*}

install_x64_snap() {
	if [ "$architecture" = amd64 ]; then
		sudo snap install "$@"
	else
		echo "Skipping $1: the configured Snap has no native ARM64 build." >&2
	fi
}

configure_docker_repository() {
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /usr/share/keyrings/docker.asc >/dev/null || return
	echo "deb [arch=$architecture signed-by=/usr/share/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list || return
	sudo apt update
}

persist_shell_setting() {
	local setting=$1
	local environmentFile="$HOME/.config/dev-machine/env.sh"
	local startupFile
	mkdir -p "$(dirname "$environmentFile")" || return
	touch "$environmentFile" "$HOME/.bashrc" "$HOME/.profile" || return
	if ! grep -Fqx -- "$setting" "$environmentFile"; then
		printf '%s\n' "$setting" >> "$environmentFile" || return
	fi
	for startupFile in "$HOME/.bashrc" "$HOME/.profile"; do
		if ! grep -Fqx '. "$HOME/.config/dev-machine/env.sh"' "$startupFile"; then
			printf '\n%s\n' '. "$HOME/.config/dev-machine/env.sh"' >> "$startupFile" || return
		fi
	done
}

add_user_path() {
	local directory=$1
	local setting
	case ":$PATH:" in
		*":$directory:"*) ;;
		*) export PATH="$directory:$PATH" ;;
	esac
	printf -v setting 'case ":$PATH:" in *:%q:*) ;; *) export PATH=%q:"$PATH" ;; esac' "$directory" "$directory"
	persist_shell_setting "$setting"
}

record_install_failure() {
	local status=$1
	local line=$2
	local command=$3
	printf 'Line %s (exit %s): %s\n' "$line" "$status" "$command" >> "$failureLog"
	printf 'FAILED at line %s (exit %s): %s\n' "$line" "$status" "$command" >&2
}

finish_install() {
	local status=$1
	trap - EXIT ERR
	if [ -s "$failureLog" ] || [ "$status" -ne 0 ]; then
		echo "Installation incomplete. Recorded failures:" >&2
		cat "$failureLog" >&2
		rm -f "$failureLog"
		exit 1
	fi
	rm -f "$failureLog"
	echo 'Installation completed without recorded command failures. Open a new Bash session or run: source ~/.profile'
}

while :; do
	case $1 in
		-h|--help)
			show_help
			exit
			;;
		--enduser)
			instEnduser=1
			;;
		--baseline)
			instBase=1
			;;
		--prompt)
			instPrompt=1
			;;
		--sshsrv)
			instSshServer=1
			;;
		--sysstat)
			instSysstat=1
			;;
		--docker)
			instDockerEngine=1
			;;
		--clis)
			instCLIs=1
			instPython=1    # Many CLIs require python
			;;
		--devTools)
			instDevTools=1
			;;
		--python)
			instPython=1
			;;
     		--golang)
			instGoLang=1
			;;
	     	--ruby)
			instRuby=1
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
				instDotNetCore="$2"
				shift
			else
				instDotNetCore="10"
			fi
			;;
		--homebrew)
			instHomebrew=1
			;;
		--wslUsbSupport)
			instWslUsbSupport=1
			;;
		--wslSshPassthrough)
			instWslSshPassthrough=1
			;;
		--noWsl)
			isWsl=0
			;;
		-?*)
			echo "WARN: ignoring unknown option $1" >&2
			;;
		*)
			break
	esac

	shift
done

case $instDotNetCore in
	8|10|none|all) ;;
	*) echo "Unsupported .NET selection: $instDotNetCore. Use 8, 10, all, or none; 3.1/6/7 are retired." >&2; exit 1 ;;
esac
case $instJava in
	default|openjdk|msftjdk|none) ;;
	*) echo "Unsupported Java selection: $instJava. The Oracle installer PPA is discontinued." >&2; exit 1 ;;
esac

#
# Check Ubuntu Version
#
ver=$(lsb_release -rs)
case $ver in
	22.04|24.04|26.04) ;;
	*) echo "Use Ubuntu 22.04, 24.04, or 26.04; older releases need legacy installation paths." >&2; exit 1 ;;
esac

failureLog=$(mktemp) || exit 1
set -o pipefail
trap 'record_install_failure "$?" "$LINENO" "$BASH_COMMAND"' ERR
trap 'finish_install "$?"' EXIT

if [ $((instEnduser + instBase + instPrompt + instPython + instSysstat + instSshServer + instDockerEngine + instCLIs + instNodeJs + instScala + instRuby + instGoLang + instDevTools + instHomebrew + instWslUsbSupport + instWslSshPassthrough)) -gt 0 ] || [ "$instDotNetCore" != none ] || [ "$instJava" != none ]; then
	sudo apt update
	sudo apt install -y ca-certificates curl wget gnupg unzip jq git xz-utils software-properties-common
fi


#
# General packages commonly used on my Linux Dev Machines
#
if [ $instBase == 1 ]; then

	sudo apt update
	sudo apt -y upgrade 

	sudo apt install -y tmux
	sudo apt install -y debconf-utils
	sudo apt install -y net-tools
	sudo apt install -y dos2unix
	sudo apt install -y unzip
	sudo apt install -y curl
	
	# Packages needed for USBIPD for USB support in WSL 2
	# https://devblogs.microsoft.com/commandline/connecting-usb-devices-to-wsl/
	sudo apt install -y hwdata

	sudo apt install -y ffmpeg
	sudo apt install -y mencoder
	sudo apt install -y libpng-dev

	# Git including enabling large-file-store scenarios (git-lfs)
	sudo apt install -y git
	sudo apt install -y git-lfs
	if [ $isWsl == 1 ]; then
		git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
	fi
	
	sudo apt install -y jq
	sudo apt install -y zlib1g-dev
	if [ "$ver" = 26.04 ]; then
		sudo apt install -y libxml2-16
	else
		sudo apt install -y libxml2
	fi
	sudo apt install -y build-essential

	sudo apt install -y pandoc
	sudo apt install -y texlive-latex-recommended

	sudo apt install -y ansible
	if [ "$architecture" = arm64 ]; then
		echo "Skipping Vagrant: no official native Linux ARM64 package is available." >&2
	elif apt-cache show vagrant >/dev/null 2>&1; then
		sudo apt install -y vagrant
	else
		echo "Skipping Vagrant: no native package in the configured APT repositories." >&2
	fi
	if [ $isWsl == 1 ] && command -v vagrant >/dev/null 2>&1; then
		vagrantExportIsHere=$(grep "VAGRANT_DEFAULT_PROVIDER" ~/.profile 2>/dev/null || true)
		if [ ! "$vagrantExportIsHere" ]; then
			# shellcheck disable=SC1090
			printf 'export VAGRANT_DEFAULT_PROVIDER="%s"\n' "${VAGRANT_DEFAULT_PROVIDER:-hyperv}" >> ~/.profile
			echo "export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS=1" >> ~/.profile
			if [ -n "${WINDOWS_USER_HOME:-}" ]; then
				printf 'export VAGRANT_WSL_WINDOWS_ACCESS_USER_HOME_PATH=%q\n' "$WINDOWS_USER_HOME" >> ~/.profile
			fi
		fi
	fi

fi


#
# Installing WSL2 SSH Agent Passthrough with Windows SSH Agent
#
if [[ "$instWslSshPassthrough" == "1" && "$isWsl" == "1" ]]; then

	# Requires socat on Windows and npiperelay.exe on Windows Host
	sudo apt install socat -y

	# Now update ~/.profile with the respective file contents.
	# shellcheck disable=SC1090
	sshPassthroughIsThere=$(grep "# mszcool ssh wsl2 sharing" ~/.profile 2>/dev/null || true)
	if [ ! "$sshPassthroughIsThere" ]; then
		# Append the lines to the file
		cat <<- EOL | tee -a ~/.profile
			# mszcool ssh wsl2 sharing
			# Configure ssh forwarding
			export SSH_AUTH_SOCK=\$HOME/.ssh/agent.sock
			# need \`ps -ww\` to get non-truncated command for matching
			# use square brackets to generate a regex match for the process we want but that doesn't match the grep command running it!
                        RUNNING_CHECK=\$(ps -auxww | grep "[n]piperelay.exe -ei -s //./pipe/openssh-ssh-agent")
			if [[ \$RUNNING_CHECK == *"npiperelay.exe"* ]]; then RUNNING_AGENT="yes"; else RUNNING_AGENT="no"; fi
			# Test if I can retrieve the keys
			ssh-add -l
			if [ \$? != 0 ]; then RUNNING_AGENT="no"; fi
   			if [ "\$RUNNING_AGENT" == "no" ]; then
				if [[ -S \$SSH_AUTH_SOCK ]]; then
					# not expecting the socket to exist as the forwarding command isn't running (http://www.tldp.org/LDP/abs/html/fto.html)
					echo "removing previous socket..."
					rm \$SSH_AUTH_SOCK
				fi
				echo "Starting SSH-Agent relay..."
				# This requires the .ssh directory to exist, hence create it if it does not.
			        mkdir -p "$HOME/.ssh"
    				# Now, if the directory exists, we can create the redirect socket with socat
				# setsid to force new session to keep running
				# set socat to listen on \$SSH_AUTH_SOCK and forward to npiperelay which then forwards to openssh-ssh-agent on windows
				(setsid socat UNIX-LISTEN:\$SSH_AUTH_SOCK,fork EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork &) >/dev/null 2>&1
			fi
			# mszcool ssh wsl2 sharing end            
EOL
	fi
fi


#
# Installing USBIP support for WSL2
#
if [ $instWslUsbSupport == 1 ]; then
	# USBIP support enablement for WSL2
	if [ $isWsl == 1 ]; then
		# Following new instructions per https://github.com/dorssel/usbipd-win/wiki/WSL-support
		echo "Use a current WSL kernel and usbipd-win on Windows; current usbipd-win needs no separate Linux USB/IP tools."
		echo "Run \"usbipd bind --busid <busid>\" as Windows administrator, then \"usbipd attach --wsl --busid <busid>\"."
		#read -p "Press ENTER to continue..." </dev/tty
	else
		echo "Please don't use the --noWsl switch if you want to install this! This is a safety-belt if that script is used for automated install on servers!"
	fi
fi


#
# Installing homebrew (typically on desktops)
#
if [ $instHomebrew == 1 ]; then
	# Install 'homebrew' on Ubuntu per https://brew.sh/
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	#test -d ~/.linuxbrew && eval $(~/.linuxbrew/bin/brew shellenv)
	# shellcheck disable=SC2046
	test -d /home/linuxbrew/.linuxbrew && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
	#test -r ~/.bash_profile && echo eval" ($(brew --prefix)/bin/brew shellenv)" >> ~/.bash_profile
	# shellcheck disable=SC2046
	echo "eval $($(brew --prefix)/bin/brew shellenv)" >> ~/.profile

	brew update
fi


#
# Installing end user tools for a desktop environment
#
if [ $instEnduser == 1 ]; then
	
	install_x64_snap 1password
	install_x64_snap spotify
	
	curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo tee /usr/share/keyrings/google-chrome.asc >/dev/null
	echo "deb [arch=$architecture signed-by=/usr/share/keyrings/google-chrome.asc] https://dl.google.com/linux/chrome/deb stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
	sudo apt update
	sudo apt install -y google-chrome-stable
	
	sudo snap install telegram-desktop
	install_x64_snap slack --classic
	
	sudo apt install -y calibre   
	
	sudo snap install remmina
	
	sudo apt install -y mate-system-monitor
	
	sudo ufw enable
	sudo systemctl enable ufw
	sudo ufw default deny incoming
	
	sudo apt install -y p7zip-full
	
fi


#
# Install packages needed on a full server, only
#
if [ $instSshServer == 1 ]; then
	sudo apt install -y openssh-server
fi


#
# Install and configure sysstat tools (iostat, top etc.)
#
if [ $instSysstat == 1 ]; then
	sudo apt-get install -y sysstat
	awk '{gsub("ENABLED=\"false\"", "ENABLED=\"true\"")}1' /etc/default/sysstat | sudo tee /etc/default/sysstat
	# Update /etc/cron.d/sysstat for more frequent intervals
	# Change "5-55/10 * * * * root command -v debina-sa1 > /dev/null && debian-sa1 1 1"
	# To     "*/2 * * * * root command -v debian-sa1 > /dev/null && debian-sa1 1 1"
fi


#
# Install docker engine
#
if [ $instDockerEngine == 1 ]; then

	sudo apt -y install \
			apt-transport-https \
			ca-certificates \
			curl \
			gnupg-agent \
			software-properties-common

	configure_docker_repository
	sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	
	# groupadd was not needed after the installation
	#sudo groupadd docker
	sudo usermod -aG docker "$USER"

	# Also add the service start to the profile in case of WSL
	if [ $isWsl == 1 ]; then
		dockerEntryExists=$(grep "# mszcool docker setup" ~/.profile 2>/dev/null || true)
		if [ ! "$dockerEntryExists" ]; then
			echo "# mszcool docker setup" >> ~/.profile
			echo "if service docker status 2>&1 | grep -q \"is not running\"; then" >> ~/.profile
			echo "    wsl.exe -d \"${WSL_DISTRO_NAME}\" -u root -e /usr/sbin/service docker start >/dev/null 2>&1" >> ~/.profile
			echo "fi" >> ~/.profile
		fi
	fi

fi


#
# Installing Python
#
if [ $instPython == 1 ]; then
	sudo apt install -y python3
	sudo apt install -y python3-pip
	sudo apt install -y python3-venv
	#sudo rm /usr/bin/python
	#sudo ln /usr/bin/python3 /usr/bin/python

	# Create a default virtual environment
	existspythondefault=$(grep "source ~/pythonvenv/default/bin/activate" ~/.profile 2>/dev/null || true)
	if [ ! -x "$HOME/pythonvenv/default/bin/python" ]; then
		mkdir -p ~/pythonvenv
		python3 -m venv ~/pythonvenv/default || exit 1
	fi
	if [ "$existspythondefault" == "" ]; then
	   echo "# mszcool default pyhton environment" >> ~/.profile
	   echo "source ~/pythonvenv/default/bin/activate" >> ~/.profile
	fi
	source ~/pythonvenv/default/bin/activate || exit 1
	
	# Now install packages into that default virtual environment
	python3 -m pip install --upgrade pip
	pip3 install numpy
	pip3 install pytest
	pip3 install mock
	pip3 install Pillow
	pip3 install GhostScript
	pip3 install matplotlib
	pip3 install autopep8
fi


#
# Installing Ruby on Rails
#
if [ $instRuby == 1 ]; then
	# Ruby and Jekyll for GitHub Pages

	sudo apt install -y ruby-full build-essential zlib1g-dev

	export GEM_HOME="$HOME/gems"
	persist_shell_setting 'export GEM_HOME="$HOME/gems"'
	add_user_path "$GEM_HOME/bin"
	gem install jekyll bundler
fi


#
# Installing Go Language
#
if [ $instGoLang == 1 ]; then
	goVersion=${GO_VERSION:-$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -er 'map(select(.stable))[0].version')}
	goArchive=$(mktemp)
	wget -O "$goArchive" "${GO_DOWNLOAD_URL:-https://go.dev/dl/${goVersion}.linux-${architecture}.tar.gz}" || exit 1
	mkdir -p "$HOME/.local/lib/go/$goVersion"
	tar -xzf "$goArchive" -C "$HOME/.local/lib/go/$goVersion" --strip-components=1 || exit 1
	rm "$goArchive"
	add_user_path "$HOME/.local/lib/go/$goVersion/bin"
fi


#
# Installing Java with package manager
#
case $instJava in
	openjdk)
		sudo apt-get install -y "openjdk-${openjdkVersion}-jdk"
		# Set JAVA_HOME as an environment variable for the entire system
		echo "export JAVA_HOME=/usr/lib/jvm/java-${openjdkVersion}-openjdk-${architecture}/" | sudo tee /etc/profile.d/set_java_home.sh
		sudo chmod +x /etc/profile.d/set_java_home.sh
		;;
	
	msftjdk)
		jdkArchiveArchitecture=$runtimeArchitecture
		if [ "$architecture" = arm64 ]; then
			jdkArchiveArchitecture=aarch64
		fi
		jdkArchive=$(mktemp)
		curl -fL "${MSOPENJDK_DOWNLOAD_URL:-https://aka.ms/download-jdk/microsoft-jdk-${msopenjdkVersion}-linux-${jdkArchiveArchitecture}.tar.gz}" -o "$jdkArchive" || exit 1
		export JAVA_HOME="$HOME/.local/lib/msopenjdk/$msopenjdkVersion"
		mkdir -p "$JAVA_HOME"
		tar -xzf "$jdkArchive" -C "$JAVA_HOME" --strip-components=1 || exit 1
		rm "$jdkArchive"
		"$JAVA_HOME/bin/javac" -version || exit 1
		printf -v javaHomeSetting 'export JAVA_HOME=%q' "$JAVA_HOME"
		persist_shell_setting "$javaHomeSetting"
		add_user_path "$JAVA_HOME/bin"
		;;

	default)
		sudo apt-get install -y default-jdk
		;;
esac


#
# Installing additional tools used with Java
#
if [ "$instJava" != "none" ]; then

	# Maven build tool suite
	sudo apt install -y maven

	# JMeter which relies on Java
	mkdir -p "$HOME/jmeter"
	wget -O "$HOME/apache-jmeter.tgz" "${JMETER_DOWNLOAD_URL:-https://dlcdn.apache.org/jmeter/binaries/apache-jmeter-5.6.3.tgz}"
	tar -xvf "$HOME/apache-jmeter.tgz" -C "$HOME/jmeter"

fi


#
# Installing Scala SBT with package manager
#
if [ $instScala == 1 ]; then
	curl -fsSL 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823' | sudo tee /usr/share/keyrings/sbt.asc >/dev/null
	echo "deb [signed-by=/usr/share/keyrings/sbt.asc] https://repo.scala-sbt.org/scalasbt/debian all main" | sudo tee /etc/apt/sources.list.d/sbt.list
	sudo apt update
	sudo apt-get install -y apt-transport-https curl gnupg
	sudo apt install -y sbt
fi


#
# NodeJS Installation with NVM
#
if [ $instNodeJs == 1 ]; then
	nvmInstaller=$(mktemp)
	curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvmVersion}/install.sh" -o "$nvmInstaller" || exit 1
	bash "$nvmInstaller" || exit 1
	rm "$nvmInstaller"
	export NVM_DIR="$HOME/.nvm"
	# shellcheck disable=SC1090
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || exit 1
	# shellcheck disable=SC1090
	if [ -s "$NVM_DIR/bash_completion" ]; then
		\. "$NVM_DIR/bash_completion"
	fi

	nvm install "$nodeVersion" || exit 1
	persist_shell_setting 'export NVM_DIR="$HOME/.nvm"'
	persist_shell_setting 'if [ -s "$NVM_DIR/nvm.sh" ]; then . "$NVM_DIR/nvm.sh"; fi'
	npm install -g gulp
	npm install -g autorest
fi


#
# Installing .Net core runtimes
#
if [ "$instDotNetCore" != "none" ]; then
	sudo apt install -y libicu-dev libssl-dev zlib1g
	dotnetInstaller=$(mktemp)
	curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$dotnetInstaller" || exit 1
	case $instDotNetCore in
		all) dotnetChannels=(8.0 10.0); toolMajor=10 ;;
		*) dotnetChannels=("$instDotNetCore.0"); toolMajor=$instDotNetCore ;;
	esac
	for dotnetChannel in "${dotnetChannels[@]}"; do
		bash "$dotnetInstaller" --channel "$dotnetChannel" --architecture "$runtimeArchitecture" --install-dir "$HOME/.dotnet" || exit 1
	done
	rm "$dotnetInstaller"
	export DOTNET_ROOT="$HOME/.dotnet"
	persist_shell_setting 'export DOTNET_ROOT="$HOME/.dotnet"'
	add_user_path "$DOTNET_ROOT"
	add_user_path "$DOTNET_ROOT/tools"
	add_user_path "$HOME/.local/bin"

	powershellUrl=${POWERSHELL_DOWNLOAD_URL:-$(curl -fsSL https://api.github.com/repos/PowerShell/PowerShell/releases/latest | jq -er --arg arch "$runtimeArchitecture" '.assets[] | select(.name | endswith("-linux-" + $arch + ".tar.gz")) | .browser_download_url')}
	powershellArchive=$(mktemp)
	powershellDir="$HOME/.local/lib/powershell/$runtimeArchitecture"
	curl -fL "$powershellUrl" -o "$powershellArchive" || exit 1
	mkdir -p "$powershellDir" "$HOME/.local/bin"
	tar -xzf "$powershellArchive" -C "$powershellDir" || exit 1
	chmod +x "$powershellDir/pwsh"
	ln -sfn "$powershellDir/pwsh" "$HOME/.local/bin/pwsh"
	rm "$powershellArchive"

	wget -qO- https://aka.ms/install-artifacts-credprovider.sh | bash
	dotnet tool update --global dotnet-ef --version "$toolMajor.*"
	dotnet tool update --global dotnet-trace
	dotnet tool update --global dotnet-dump
	dotnet tool update --global dotnet-counters
	dotnet tool update --global dotnet-gcdump
	dotnet tool update --global dotnet-aspnet-codegenerator --version "$toolMajor.*"
	dotnet tool update --global Swashbuckle.AspNetCore.Cli
	dotnet tool update --global NSwag.ConsoleCore
fi


#
# Installing various CLIs
#
if [ $instCLIs == 1 ]; then

	# All goes into CLIs if not installed via package
	mkdir -p "$HOME/clis"
	add_user_path "$HOME/clis"

	# Install Azure CLI and plug-ins
	sudo apt update
	sudo apt install -y ca-certificates curl apt-transport-https lsb-release gnupg
	curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.gpg > /dev/null
	AZ_REPO=$(lsb_release -cs)
	echo "deb [arch=$architecture] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
	sudo apt update
	sudo apt install -y azure-cli
	if az extension show --name alias >/dev/null 2>&1 && ! az alias --help >/dev/null 2>&1; then
		echo "Removing broken optional Azure CLI alias extension."
		az extension remove --name alias
	fi
	
	while IFS= read -r azext || [ -n "$azext" ]; do
		azext=${azext%$'\r'}
		if [ -n "$azext" ]; then
			az extension add --name "$azext"
		fi
	done < "$scriptDir/az-cli.extensions"

	# Install other cloud provider CLIs
	curl -fL "https://awscli.amazonaws.com/awscli-exe-linux-${awsArchitecture}.zip" -o "$HOME/clis/awscliv2.zip" || exit 1
	unzip -o -d ~/clis/ ~/clis/awscliv2.zip
	sudo ~/clis/aws/install --update
	rm ~/clis/awscliv2.zip

	if [ "$instDockerEngine" != 1 ]; then
		configure_docker_repository
		sudo apt install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin
	fi

	# Latest kubectl
	kubeversion=${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}
	wget -O ~/clis/kubectl "https://dl.k8s.io/release/$kubeversion/bin/linux/$architecture/kubectl" || exit 1
	chmod +x ~/clis/kubectl
	
	# Krew extension manager
	krewDir=$(mktemp -d)
	curl -fL "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-linux_${architecture}.tar.gz" -o "$krewDir/krew.tar.gz" || exit 1
	tar -xzf "$krewDir/krew.tar.gz" -C "$krewDir" || exit 1
	"$krewDir/krew-linux_$architecture" install krew || exit 1
	rm -r "$krewDir"
	add_user_path "${KREW_ROOT:-$HOME/.krew}/bin"
	# Install the plug-ins
	kubectl krew install exec-as
	
	# Helm CLI
	helmVersion=${HELM_VERSION:-$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | jq -er .tag_name)}
	helmDir=$(mktemp -d)
	curl -fL "https://get.helm.sh/helm-${helmVersion}-linux-${architecture}.tar.gz" -o "$helmDir/helm.tar.gz" || exit 1
	tar -xzf "$helmDir/helm.tar.gz" -C "$helmDir" || exit 1
	install -m 755 "$helmDir/linux-$architecture/helm" "$HOME/clis/helm"
	rm -r "$helmDir"

	# Cloud Foundry CLI
	curl -fsSL https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo tee /usr/share/keyrings/cloudfoundry.asc >/dev/null
	echo "deb [arch=$architecture signed-by=/usr/share/keyrings/cloudfoundry.asc] https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry.list
	sudo apt update
	sudo apt install -y cf8-cli

	# OpenShift CLI
	openshiftArchive=$(mktemp)
	curl -fL "${OPENSHIFT_DOWNLOAD_URL:-https://mirror.openshift.com/pub/openshift-v4/${awsArchitecture}/clients/ocp/stable/openshift-client-linux.tar.gz}" -o "$openshiftArchive" || exit 1
	tar -xzf "$openshiftArchive" -C "$HOME/clis" oc || exit 1
	rm "$openshiftArchive"

	# Install the 1Password CLI
	# 1. Add the 1Password APT repository key
	curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
	  sudo gpg --batch --yes --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
	# 2. Add the repository
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
	  sudo tee /etc/apt/sources.list.d/1password-cli.list
	# 3. Set up debsig verification policy
	sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
	curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
	  sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
	sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
	curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
	  sudo gpg --batch --yes --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
	# 4. Install
	sudo apt update
	sudo apt install -y 1password-cli

fi


#
# Installing development tools
#
if [ $instDevTools == 1 ]; then

	mkdir -p "$HOME/tools"
	sudo apt install -y kdiff3
	
	# Redis Tools incl. CLI
	sudo apt install -y redis-tools

	# Ngrok redirection tool
	curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /usr/share/keyrings/ngrok.asc >/dev/null
	echo "deb [arch=$architecture signed-by=/usr/share/keyrings/ngrok.asc] https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
	sudo apt update
	sudo apt install -y ngrok

	# Some tools are installed differently in WSL or are not needed as available on Windows    
	if [ $isWsl == 0 ]; then

		# Install Microsoft Edge
		if [ "$architecture" = amd64 ]; then
			wget -O "$HOME/edge.deb" 'https://go.microsoft.com/fwlink?linkid=2149051'
			sudo apt install -y "$HOME/edge.deb"
			rm "$HOME/edge.deb"
		else
			echo "Skipping Edge: no native Linux ARM64 package is published." >&2
		fi

		# Visual Studio Code
		curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo tee /usr/share/keyrings/vscode.asc >/dev/null
		echo "deb [arch=$architecture signed-by=/usr/share/keyrings/vscode.asc] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
		sudo apt update
		sudo apt install -y code

		# Start installing all extensions
		while IFS= read -r vscodeext || [ -n "$vscodeext" ]; do
			vscodeext=${vscodeext%$'\r'}
			if [ -n "$vscodeext" ]; then
				code --install-extension "$vscodeext"
			fi
		done < "$scriptDir/vscode.extensions"
		code --install-extension ms-mssql.mssql

		# IntelliJ IDEA Community
		sudo snap install intellij-idea-community --classic

		# Azure Storage Explorer
		install_x64_snap storage-explorer
		if [ "$architecture" = amd64 ]; then
			sudo snap connect storage-explorer:password-manager-service :password-manager-service
		fi

		# Postman
		sudo snap install postman

		# MQTT Explorer
		install_x64_snap mqtt-explorer

		# Installing the Cascadia code font
		sudo apt install -y fonts-cascadia-code

	else

		# Installing tools in WSL for development against WSL filesystem (performance reasons)

		# IntelliJ IDEA
		sudo snap install intellij-idea-community --classic

	fi

	if [ "$architecture" = amd64 ]; then
		arduinoUrl=${ARDUINO_IDE_DOWNLOAD_URL:-$(curl -fsSL https://api.github.com/repos/arduino/arduino-ide/releases/latest | jq -er '.assets[] | select(.name | endswith("Linux_64bit.zip")) | .browser_download_url')}
		arduinoDir="$HOME/tools/arduino-ide"
		mkdir -p "$arduinoDir" "$HOME/.local/bin"
		curl -fL "$arduinoUrl" -o "$arduinoDir/arduino.zip" || exit 1
		unzip -o "$arduinoDir/arduino.zip" -d "$arduinoDir" || exit 1
		arduinoExecutable=$(find "$arduinoDir" -type f -name arduino-ide -print -quit)
		if [ -z "$arduinoExecutable" ]; then
			echo "Arduino IDE executable missing from archive." >&2
			exit 1
		fi
		chmod +x "$arduinoExecutable"
		ln -sfn "$arduinoExecutable" "$HOME/.local/bin/arduino-ide"
		rm "$arduinoDir/arduino.zip"
		add_user_path "$HOME/.local/bin"
		sudo usermod -a -G dialout "$USER"
	else
		echo "Skipping Arduino IDE 2: no official Linux ARM64 binary; use the Windows host IDE in WSL." >&2
	fi
fi


#
# Installing components for a pretty prompt
# I know this is not the most beautiful way, but this is sparetime and hence I had to rush
#
if [ $instPrompt == 1 ]; then

	sudo wget "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-$architecture" -O /usr/local/bin/oh-my-posh || exit 1
	sudo chmod +x /usr/local/bin/oh-my-posh || exit 1

	mkdir -p ~/.poshthemes
	wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O ~/.poshthemes/themes.zip || exit 1
	unzip -o ~/.poshthemes/themes.zip -d ~/.poshthemes || exit 1
	chmod u+rw ~/.poshthemes/*.omp.*
	rm ~/.poshthemes/themes.zip
	if [ ! -f "$HOME/.poshthemes/iterm2.omp.json" ]; then
		echo "Prompt theme missing: $HOME/.poshthemes/iterm2.omp.json" >&2
		exit 1
	fi

	promptInit='eval "$(oh-my-posh init bash --config "$HOME/.poshthemes/iterm2.omp.json")"'
	if ! grep -Fqx "$promptInit" "$HOME/.bashrc" 2>/dev/null; then
		printf '\n%s\n' '#mszcool_prompt' >> "$HOME/.bashrc"
		printf '%s\n' 'if [[ $- == *i* ]] && command -v oh-my-posh >/dev/null 2>&1; then' "$promptInit" 'fi' >> "$HOME/.bashrc"
	fi
	echo "Prompt configured in ~/.bashrc. Open a new Bash session or run: source ~/.bashrc"

	# Install the fonts with oh-my-posh
	oh-my-posh font install Meslo
	oh-my-posh font install CascadiaCode
fi
