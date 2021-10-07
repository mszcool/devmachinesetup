[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification='Following installation instructions from scoop.sh')]
Param
(
    [Switch]
    $prepOS,

    [Switch]
    $tools,

    [Switch]
    $userTools,

    [Switch]
    $ittools,

    [Switch]
    $dev,

    [Switch]
    $devTools,

    [Parameter(Mandatory = $False)]
    [ValidateSet("no", "desktop", "cli")]
    $docker = "no",

    [Switch]
    $clis,

    [Switch]
    $hyperv,

    [Switch]
    $instVsCode,

    [Switch]
    $installVs,

    [Parameter(Mandatory = $False)]
    [ValidateSet("Community", "Professional", "Enterprise")]
    $vsEdition = "Community",

    [Parameter(Mandatory = $False)]
    [ValidateSet("none", "intelliJ", "eclipse-sts", "all")]
    $installOtherIDE = "none",

    [Switch]
    $instPrettyPrompt

)


# winget is becoming a part of Windows 10, but for now, you need to install it
Write-Information "***********************************************************************************************************"
Write-Information "Please make sure to have winget installed: https://docs.microsoft.com/en-us/windows/package-manager/winget/"
Write-Information "***********************************************************************************************************"


#
# Store the location of the original script execution
#
$originalExecPath = Get-Location


#
# Simple Parameter validation
#
if ( $prepOS -and ($tools -or $userTools -or $ittools -or $dev -or $devTools -or ( $docker -ne "no" ) -or $clis -or $instVsCode -or $installVs -or ( $installOtherIDE -ne "none" ) -or $instPrettyPrompt) ) {
    throw "Running the script with -prepOS does not allow you to use any other switches. First run -prepOS and then run with any other allowed combination of switches!"
}


#
# [prepOS] Installing Operating System Components as well as chocolatey itself. Needs to happen before ANY other runs!
#
if ( $prepOS ) {
    # Enable Console Prompting for PowerShell
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name "ConsolePrompting" -Value $True

    # Install git using winget
    winget install --source winget --silent "Git.Git"
    winget install --source winget --silent "Git Large File Storage"

    # Install Scoop, which is more convenient for CLIs and command line dev tools
    Invoke-Expression (new-object net.webclient).downloadstring('https://get.scoop.sh')

    # Install Windows Features
    Enable-WindowsOptionalFeature -FeatureName NetFx4-AdvSrvs -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName NetFx4Extended-ASPNET45 -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName WCF-Services45 -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName WCF-TCP-PortSharing45 -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName HypervisorPlatform -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -NoRestart

    if ( $hyperv ) {
        Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online -NoRestart
        Enable-WindowsOptionalFeature -FeatureName Containers -Online -NoRestart
    }

    Write-Information ""
    Write-Information "Installation of OS components completed, please restart your computer once ready!"
    Write-Information ""

    Exit
}


#
# Function to create a path if it does not exist
#
function CreatePathIfNotExists($pathName) {
    if (!(Test-Path -Path $pathName)) {
        New-Item -ItemType directory -Path $pathName
    }
}


#
# Extract a ZIP file
#
function ExtractZipArchive($zipFile, $outPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $outPath)
}


#
# Function to prepare PowerShell itself
#
function PreparePowerShell() {
    Write-Information "Installing PackageManagement if needed..."
    Install-Module -Name PackageManagement -Force -MinimumVersion 1.4.6 -Scope CurrentUser -AllowClobber
    #Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Write-Information "Installing PowerShellGet if neeed..."
    Install-Module -Name PowerShellGet -Force
}


#
# [tools] Tools needed on every machine
#

if ( $tools ) {

    winget install --source winget --silent 1password

    winget install --source winget --silent KeePass

    winget install --source msstore --silent --accept-package-agreements "Microsoft PowerToys"

    winget install --source winget --silent 7zip

    winget install --source msstore --silent --accept-package-agreements "Adobe Acrobat Reader DC"

    winget install --source winget --silent "Google Chrome"

}


#
# [userTools] Tools only needed for end-user related machines (not machines focused on dev-only)
#
if ( $userTools ) {

    winget install --source winget --silent "Microsoft Teams"

    winget install --source winget --silent "OpenWhisperSystems.Signal"

    winget install --source msstore --silent --accept-package-agreements "WhatsApp Desktop"

    winget install --source msstore --silent --accept-package-agreements "9NZTWSQNTD0S" # Telegram Desktop

    winget install --source msstore --silent --accept-package-agreements "Messenger"

    winget install --source msstore --silent --accept-package-agreements "Slack"

    winget install --source msstore --silent --accept-package-agreements "ZOOM Cloud Meetings"

    winget install --source msstore --silent --accept-package-agreements Rufus

    winget install --source winget --silent win32diskimager

    winget install --source winget --silent calibre
    
    winget install --source winget --silent "Advanced Renamer"

    # Store Apps which I use on a regular basis

    winget install --source winget --silent "CrystalDiskMark"

    winget install --source msstore --silent --accept-package-agreements "Cinebench"

    winget install --source winget --silent "Logi Tune"

    winget install --source msstore --silent --accept-package-agreements "QuickLook"
    
    winget install --source msstore --silent --accept-package-agreements "EarTrumpet"

    winget install --source msstore --silent --accept-package-agreements "WorkingHours" # "WorkingHours — Time Tracking / Timesheet"

    winget install --source msstore --silent --accept-package-agreements "Netflix"
    
    winget install --source msstore --silent --accept-package-agreements "Amazon Prime Video for Windows"

    winget install --source msstore --silent --accept-package-agreements "Disney+"

    winget install --source msstore --silent --accept-package-agreements "Ico Converter"

    winget install --source msstore --silent --accept-package-agreements "Adobe Photoshop Express: Image Editor, Adjustments, Filters, Effects, Borders"

    winget install --source msstore --silent --accept-package-agreements "FeedLab"

    winget install --source msstore --silent --accept-package-agreements "MSN Money"

    winget install --source msstore --silent --accept-package-agreements "Microsoft News"

    winget install --source msstore --silent --accept-package-agreements "MSN Weather"

    winget install --source msstore --silent --accept-package-agreements "Surface Audio"

    winget install --source msstore --silent --accept-package-agreements "Dynamics AX 2012 Expenses"

    winget install --source msstore --silent --accept-package-agreements "Speedtest by Ookla"

    winget install --source msstore --silent --accept-package-agreements "Spotify Music"

    winget install --source msstore --silent --accept-package-agreements "9WZDNCRD2G0J" # Microsoft Sway

}


#
# [ittools] IT-oriented tools
#
if ( $ittools ) {

    winget install --source winget --silent "Microsoft.PowerShell"

    winget install --source msstore --silent --accept-package-agreements "Subnet Manager"

    winget install --source msstore --silent --accept-package-agreements "IP Calculator"

    winget install --source msstore --silent --accept-package-agreements "Nightingale REST Client"

    winget install --source msstore --silent --accept-package-agreements "MQTT-Explorer"

    winget install --source msstore --silent --accept-package-agreements "Ubuntu 18.04 LTS"

    winget install --source msstore --silent --accept-package-agreements "Ubuntu 20.04 LTS"

    winget install --source winget --silent "GitExtensionsTeam.GitExtensions"

    # Scoop based packages

    scoop install sudo --global

    scoop install curl grep sed less touch --global

    scoop install jq --global

    scoop install openssl --global
    
    scoop install win32-openssh --global

    scoop install busybox --global

    scoop install sysinternals --global

}


#
# [devTools] All tools needed for development
#
if ( $devTools ) {

    winget install --source winget --silent "Microsoft.AzureDataStudio"

    winget install --source winget --silent "Microsoft.AzureStorageExplorer"

    winget install --source winget --silent "Microsoft.AzureStorageEmulator"

    winget install --source winget --silent "Microsoft.AzureFunctionsCoreTools"

    winget install --source winget --silent "Microsoft.AzureCosmosEmulator"

    winget install --source msstore --silent --accept-package-agreements "Cosmos DB Studio"

    winget install --source winget --silent "Microsoft.azure-iot-explorer"

    winget install --source winget --silent "3T.Robo3T"

    winget install --source winget --silent "Postman.Postman"
    
    winget install --source winget --silent "ILSpy"
    
    winget install --source winget --silent "Telerik.Fiddler"
    
    winget install --source winget --silent "RicoSuter.NSwagStudio" 

    # Scoop-based installs

    scoop bucket add extras
    scoop bucket add versions

    scoop install sqlitestudio --global

    scoop install servicebusexplorer --global
    
    scoop install jmeter --global

    scoop install ngrok --global
    
    scoop install lessmsi --global

}


#
# [docker] Docker, either CLIs only or with full Docker for Desktop
#
if ( $docker -eq "cli" ) {

    scoop bucket add extras
    scoop bucket add versions

    scoop install docker --global
    scoop install docker-machine --global
    scoop install docker-compose --global

}
elseif ( $docker -eq "desktop" ) {

    winget install --source winget --silent DockerDesktop

}


#
# [dev] Developer Tools needed on every dev-machine
#
if ( $dev ) {

    winget install --source winget --silent "Microsoft.OpenJDK.16"

    winget install --source winget --silent "GoLang.Go"

    winget install --source winget --silent "Python 3.9"

    # Reference : https://pypi.org/project/autopep8/
    python -m pip install --upgrade autopep8

    winget install --source winget --silent "Scala.Scala.2"

    winget install --source winget --silent "sbt.sbt"

    winget install --source winget --silent "OpenJS.NodeJS"

    npm install -g moment

    npm install -g bower

    npm install -g gulp
    
    npm install -g autorest@3.0.6187

    npm install -g swagger-tools@0.10.4

    scoop bucket add extras
    scoop bucket add versions
    
    scoop install maven --global

    # Dotnet artifacts credential provider for .NET Core and .NET Framework.
    # Note: assumes VS 2019 or dotnet has been installed on the system.
    # Details: https://github.com/Microsoft/artifacts-credprovider
    Invoke-Expression "& { $(irm https://aka.ms/install-artifacts-credprovider.ps1) } -AddNetfx"

}


#
# [clis] Command Line Interfaces
#
if ( $clis ) {

    scoop install azure-cli --global
    $azcliext = Get-Content "$originalExecPath\az-cli.extensions"
    $azcliext | ForEach-Object { az extension add --name $_ }

    scoop install bicep --global

    scoop install aws --global

    PreparePowerShell

    Install-Module -Name Az -AllowClobber -Force

    Install-Module -Name AzureAD -Force -SkipPublisherCheck

    scoop install armclient --global
    
    scoop install nuget --global

    scoop install kubectl --global

    scoop install helm --global

    scoop install draft --global

    scoop install cloudfoundry-cli@7.1.0 --global

    scoop install openshift-origin-client --global

}


#
# Visual Studio Code Extensions
#
if ( $instVsCode ) {

    # First install Visual Studio Code
    winget install --source winget --silent "Microsoft.VisualStudioCode"

    # Start installing all extensions
    $vsCodeExtensions = Get-Content "$originalExecPath\vscode.extensions"
    $vsCodeExtensions | ForEach-Object { code --install-extension $_ }

}


#
# [installVs] Installing a version of Visual Studio (based on Chocolatey)
#
if ($installVs) {
    winget install --source winget --silent "Visual Studio $vsEdition"
}


#
# [installOtherIde] Installing Eclipse and/or IntelliJ if required
#
if (($installOtherIDE -eq "all") -or ($installOtherIDE -eq "intelliJ")) {

    winget install --source winget --silent "JetBrains.IntelliJIDEA.Community"

}
if (($installOtherIDE -eq "all") -or ($installOtherIDE -eq "eclipse-sts")) {

    scoop bucket add extras
    scoop install sts --global

}


#
# Installing a pretty prompt for PowerShell
#
if ( $instPrettyPrompt ) {

    PreparePowerShell

    Write-Information "Installing posh-git...."
    Install-Module -Name posh-git -Scope CurrentUser -Force
    Write-Information "Installing oh-my-posh..."
    Install-Module -Name oh-my-posh -Scope CurrentUser -Force
    Write-Information "Installing PSReadLine..."
    Install-Module -Name PSReadLine -Scope CurrentUser -SkipPublisherCheck -Force

    # Then write to the PowerShell Profile
    if ( ! [System.IO.File]::Exists($PROFILE) ) {
        $f = [System.IO.File]::CreateText($PROFILE)
        $f.Close()
    }

    # A bit hacky, but this is a bit of spare-time, hence limited time to optimize:)
    $profileContent = Get-Content -Path $PROFILE
    if ( [System.String]::IsNullOrEmpty($profileContent) ) { $profileContent = "" }
    if ( ! $profileContent.Contains("posh-git") ) { Add-Content -Path $PROFILE -Value "Import-Module posh-git" }
    if ( ! $profileContent.Contains("oh-my-posh") ) { Add-Content -Path $PROFILE -Value "Import-Module oh-my-posh" }
    if ( ! $profileContent.Contains("Set-Theme Paradox") ) { Add-Content -Path $PROFILE -Value "Set-Theme Paradox" }

    # Download the Cascadia Font PL true type font
    $fontUrl = "https://github.com/microsoft/cascadia-code/releases/download/v2005.15/CascadiaCode_2005.15.zip"
    $fontZipFile = "$env:TEMP\CascadiaCode.zip"
    $fontOutDir = "$env:TEMP\CascadiaCode"
    Invoke-WebRequest -Uri $fontUrl -OutFile $fontZipFile
    ExtractZipArchive -zipFile $fontZipFile -outPath $fontOutDir

    # Install the Cascadia Code PL Font
    $fontFile = [System.IO.Path]::Combine($fontOutDir, "ttf\CascadiaCodePL.ttf")
    Copy-Item "$fontFile" "$env:windir\Fonts"
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name "Cascadia Code PL" -PropertyType String -Value "CascadiaCodePL.ttf"
    Write-Information "You need to restart to make the font-installation effective (used this way instead of shell object as it works on server core)!"
}
