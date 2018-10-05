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
    $clis,

    [Switch]
    $nohyperv,

    [Switch]
    $data,

    [Switch]
    $dataSrv,

    [Switch]
    $installVs,

    [Parameter(Mandatory=$False)]
    [ValidateSet("2013", "2015", "2017")]
    $vsVersion = "2017",

    [Parameter(Mandatory=$False)]
    [ValidateSet("Community", "Professional", "Enterprise")]
    $vsEdition = "Community",

    [Switch]
    $vsext,

    [Switch]
    $vscodeext,

    [Parameter(Mandatory=$False)]
    [ValidateSet("none", "intelliJ", "eclipse-sts", "all")]
    $installOtherIDE = "none",

    [Switch]
    $cloneRepos,

    [Parameter(Mandatory=$False)]
    $codeBaseDir = "C:\Code"
)


#
# Store the location of the original script execution
#
$originalExecPath = Get-Location


#
# Simple Parameter validation
#
if( $prepOS -and ($tools -or $ittools -or $userTools -or $dev -or $data -or $dataSrv -or ( $installOtherIDE -ne "none" ) -or $installVs -or $cloneRepos -or $vsext) ) {
    throw "Running the script with -prepOS does not allow you to use any other switches. First run -prepOS and then run with any other allowed combination of switches!"
}

if( $dev -and $installVs )
{
    throw "Visual Studio and developer tools need to be installed separately. First run with -installVs and then run with -dev!"
}

#
# [prepOS] Installing Operating System Components as well as chocolatey itself. Needs to happen before ANY other runs!
#
if( $prepOS ) 
{
    Set-ExecutionPolicy unrestricted

    # Enable Console Prompting for PowerShell
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name "ConsolePrompting" -Value $True

    # Install Chocolatey
    Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

    # Install Scoop, which is more convenient for CLIs and command line dev tools
    Invoke-Expression (new-object net.webclient).downloadstring('https://get.scoop.sh')

    # Install Windows Features
    Enable-WindowsOptionalFeature -FeatureName NetFx3 -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName WCF-Services45 -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName WCF-TCP-PortSharing45 -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName NetFx4-AdvSrvs -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName NetFx4Extended-ASPNET45 -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName Windows-Identity-Foundation -Online -NoRestart
    Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -NoRestart

    if( ! $nohyperv ) {
        Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online -NoRestart
        Enable-WindowsOptionalFeature -FeatureName Containers -Online -NoRestart
    }

    Write-Information ""
    Write-Information "Installation of OS components completed, please restart your computer once ready!"
    Write-Information ""

    Exit
}

#
# Function for refreshing environment variables
#
function RefreshEnvironment() {
    foreach($envLevel in "Machine","User") {
        [Environment]::GetEnvironmentVariables($envLevel).GetEnumerator() | ForEach-Object {
            # For Path variables, append the new values, if they're not already in there
            if($_.Name -match 'Path$') { 
               $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -Split ';' | Select-Object -Unique) -Join ';'
            }
            $_
         } | Set-Content -Path { "Env:$($_.Name)" }
    }
}

#
# Function to create a path if it does not exist
#
function CreatePathIfNotExists($pathName) {
    if(!(Test-Path -Path $pathName)) {
        New-Item -ItemType directory -Path $pathName
    }
}

#
# Function to Download and Extract ZIP Files for CLIs and the likes
#
function DownloadAndExtractZip($link, $targetFolder, $tempName) {

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $downloadPath = ($env:TEMP + "\$tempName")
    if(!(Test-Path -Path $downloadPath)) {
        Invoke-WebRequest $link -OutFile $downloadPath
    }
    $shell = New-Object -ComObject Shell.Application
    $targetZip = $shell.NameSpace($downloadPath)

    CreatePathIfNotExists($targetFolder)
    foreach($item in $targetZip.items()) {
        $shell.Namespace($targetFolder).CopyHere($item)
    }
}

function DownloadAndCopy($link, $targetFolder) {
    CreatePathIfNotExists($targetFolder)

    if(!(Test-Path -Path $targetFolder)) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest $link -OutFile $targetFolder
    }
}

function DownloadAndInstallMsi($link, $targetFolder, $targetName) {
    CreatePathIfNotExists($targetFolder)

    $targetName = [System.IO.Path].Combine($targetFolder, $targetName)

    if(!(Test-Path -Path $targetFolder)) {
        Invoke-WebRequest $link -OutFile $targetName
    }

    # Execute the MSI
    msiexec.exe /a "$targetName" /qn 

    # After completed, delete the MSI-package, again
    Remove-Item -Path $targetName
}

function DownloadAndInstallExe($link, $targetFolder, $targetName, $targetParams) {
    # .\FiddlerSetup.exe /S /D=C:\tools\Fiddler
    CreatePathIfNotExists($targetFolder)

    $targetName = [System.IO.Path].Combine($targetFolder, $targetName)

    if(!(Test-Path -Path $targetFolder)) {
        Invoke-WebRequest $link -OutFile $targetName
    }

    # Execute the Installer-EXE
    & $targetName $targetParams

    # After completed, delete the MSI-package, again
    Remove-Item -Path $targetName
}

#
# Function to install VSIX extensions
#
$vsixInstallerCommand2013 = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\VsixInstaller.exe"
$vsixInstallerCommand2015 = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\VSIXInstaller.exe"
$vsixInstallerCommand2017 = "C:\Program Files (x86)\Microsoft Visual Studio\2017\$vsEdition\Common7\IDE\VsixInstaller.exe"
$vsixInstallerCommandGeneralArgs = " /q /a "

function InstallVSExtension($extensionUrl, $extensionFileName, $vsVersion) {
        
    # Select the appropriate VSIX installer
    if($vsVersion -eq "2013") {
        $vsixInstallerCommand = $vsixInstallerCommand2013
    }
    if($vsVersion -eq "2015") {
        $vsixInstallerCommand = $vsixInstallerCommand2015
    }
    if($vsVersion -eq "2017") {
        $vsixInstallerCommand = $vsixInstallerCommand2017
    }

    Write-Host "Installing extension $extensionFileName"
    Write-Host "Using devnev $vsixInstallerCommand"

    # Download the extension
    Invoke-WebRequest $extensionUrl -OutFile $extensionFileName

    # Quiet Install of the Extension
    $proc = Start-Process -FilePath "$vsixInstallerCommand" -ArgumentList ($vsixInstallerCommandGeneralArgs + $extensionFileName) -PassThru
    $proc.WaitForExit()
    if ( $proc.ExitCode -ne 0 ) {
        Write-Host "Unable to install extension " $extensionFileName " due to error " $proc.ExitCode -ForegroundColor Red
    }

    # Delete the downloaded extension file from the local system
    Remove-Item $extensionFileName
}


#
# [tools] Tools needed on every machine
#

if( $tools ) {

    #choco install -y 1password

    #choco install -y 7zip

    choco install -y adobereader

    choco install -y googlechrome

    choco install -y firefox -installArgs l=en-US

    choco install -y jre8

}


#
# [userTools] Tools only needed for end-user related machines (not machines focused on dev-only)
#
if( $userTools ) {

    #store In the Windows Store now
    #choco install -y whatsapp 

    #store In the Windows Store now
    #choco install -y slack
    
    #store In the Windows Store now
    choco install -y microsoft-teams

    choco install -y --allowemptychecksum vlc

    choco install -y --ignorechecksum goodsync
    
}


# 
# [ittools] IT-oriented tools
#
if( $ittools )
{
    choco install -y cmder 
 
    choco install -y wireshark 

    choco install -y sysinternals

    choco install -y --allowemptychecksum royalts
    
    scoop install sudo --global

    scoop install curl grep sed less touch --global

    scoop install jq --global

    scoop install openssl --global

    scoop install vagrant --global

    scoop install busybox --global
}


#
# [installVs] Installing a version of Visual Studio (based on Chocolatey)
#
if($installVs) {
    if($vsVersion -eq "2013") {
        choco install -y visualstudiocommunity2013 
    } 
    elseif($vsVersion -eq "2015") {
        choco install -y visualstudio2015community -version 14.0.23107.0
    } 
    elseif($vsVersion -eq "2017") {
        switch ($vsEdition) {
            "Community" {
                choco install visualstudio2017community -y --package-parameters "--allWorkloads --includeRecommended --includeOptional --passive --locale en-US"
            }
            "Professional" {
                choco install visualstudio2017professional -y --package-parameters "--allWorkloads --includeRecommended --includeOptional --passive --locale en-US"
            }            
            "Enterprise" {
                choco install visualstudio2017enterprise -y --package-parameters "--allWorkloads --includeRecommended --includeOptional --passive --locale en-US"
            }
        }
    }
}


#
# Installing other IDEs, mainly Java-based
#
if($installOtherIDE -ne "none") {
    
    # IntelliJ IDEA Install Begin
    if( ($installOtherIDE -eq "intellij") -or ($installOtherIDE -eq "all") ) {
        
        choco install -y intellijidea-community

    }
    # IntelliJ IDEA Install End

    # Spring Tool Suite Install Beginn
    # NOTE: below is not needed, anymore, since Chocolatey has STS in the package gallery, now, but still outdated
    if( ($installOtherIDE -eq "eclipse-sts") -or ($installOtherIDE -eq "all") ) {
        # Extract Spring Tool Suite Eclipse and copy to standard working directory
        Write-Host ""
        Write-Host "Installing Spring Tool Suite..." -ForegroundColor Green

        $stsLink = "http://download.springsource.com/release/STS/3.9.2.RELEASE/dist/e4.7/spring-tool-suite-3.9.2.RELEASE-e4.7.2-win32-x86_64.zip"
        $stsTarget = "C:\tools"
        $stsTempName = "sts396.zip"

        DownloadAndExtractZip -link $stsLink -targetFolder $stsTarget -tempName $stsTempName
    }
    # Spring Tool Suite Install End
}


#
# [dev] Developer Tools needed on every dev-machine
#
if( $dev )
{
    #
    # Phase #1 will install the the basic runtimes
    #

    scoop install go --global

    scoop install nodejs --global

    # didn't work quite well
    #scoop install python --global
    choco install -y --allowemptychecksum python2

    scoop install php --global 

    scoop install scala --global

    scoop install sbt --global

    scoop install maven --global

    scoop install ngrok --global

    scoop install packer --global

    #
    # Phase #2 will install system-wide dev tools
    #

    choco install -y visualstudiocode

    choco install -y --allowemptychecksum webpi 
    
    choco install -y jdk8

    choco install -y git.install
    
    choco install -y --allowemptychecksum gitextensions

    choco install -y poshgit 

    # Removed from Chocolatey...
    #choco install -y fiddler4

    choco install -y postman

    choco install -y nimbletext

    choco install -y --allowemptychecksum ilspy 

    choco install -y  --allowemptychecksum linqpad4

    if ( $nohyperv ) {

        choco install -y virtualbox

    }
    else {

        choco install -y docker-for-windows

    }

    scoop install docker --global

    scoop install docker-machine --global

    scoop install docker-compose --global

    #
    # Phase #3 Will use the runtimes/tools above to install additional packages
    #

    RefreshEnvironment      # Ships with chocolatey and re-loads environment variables in the current session

    npm install -g moment

    npm install -g bower

    npm install -g gulp

    npm install -g iothub-explorer

    #
    # Phase #4 will install some additional tools
    #

    DownloadAndExtractZip -link "https://github.com/paolosalvatori/ServiceBusExplorer/releases/download/4.0.109/ServiceBusExplorer-4.0.109.zip" `
                          -targetFolder "C:\tools\ServiceBusExplorer-4.0.109"

    DownloadAndInstallMsi -link "https://github.com/Azure/azure-iot-sdk-csharp/releases/download/2018-3-13/SetupDeviceExplorer.msi" `
                          -targetFolder "C:\tools\" `
                          -targetName "setupdeviceexplorer-2018-3-13.msi"

    DownloadAndInstallExe -link "https://telerik-fiddler.s3.amazonaws.com/fiddler/FiddlerSetup.exe" `
                          -targetFolder "C:\tools\" `
                          -targetName "FiddlerSetup.exe" `
                          -targetParams "/S /D=C:\tools\Fiddler"

    
}

#
# [clis] Command Line Interfaces
#

if ( $clis ) {

    pip install azure

    pip install azure-cli

    pip install awscli

    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

    Install-Module -Name AzureRM -Force -SkipPublisherCheck 

    Install-Module -Name MSOnline -Force -SkipPublisherCheck

    Install-Module -Name AzureAD -Force -SkipPublisherCheck

    pip install sfctl

    scoop install kubectl --global

    scoop install nuget --global

    # OpenStack CLI
    pip install --upgrade --requirement https://raw.githubusercontent.com/platform9/support-locker/master/openstack-clients/requirements.txt --constraint http://raw.githubusercontent.com/openstack/requirements/stable/newton/upper-constraints.txt
    DownloadAndCopy -link "https://github.com/platform9/support-locker/blob/master/openstack-clients/windows/Source_OpenRC.ps1" -targetFolder "C:\tools\openstack\Source_OpenRC.ps1"

    # Cloud Foundry CLI
    DownloadAndExtractZip -link "https://s3-us-west-1.amazonaws.com/cf-cli-releases/releases/v6.34.1/cf-cli_6.34.1_winx64.zip" -targetFolder "C:\tools\cfcli-6.34.1" -tempName "cfcli6.34.1.zip"

    # OpenShift CLI
    DownloadAndExtractZip -link "https://github.com/openshift/origin/releases/download/v3.7.1/openshift-origin-client-tools-v3.7.1-ab0f056-windows.zip" -targetFolder "C:\tools\openshift-3.7.1" -tempName "oh-3.7.1.zip"
}


#
# [data] Database Platform Tools
#
if( $data )
{
    DownloadAndExtractZip -link "https://sqlopsbuilds.blob.core.windows.net/release/0.29.3/sqlops-windows-0.29.3.zip" `
                          -targetFolder "C:\tools\sqlops-windows" -tempName "sqlopsstudio.zip"
    
    DownloadAndExtractZip -link "https://dbeaver.jkiss.org/files/dbeaver-ce-latest-win32.win32.x86_64.zip" -targetFolder "C:\tools" -tempName "dbeaver-windows.zip"
    
    DownloadAndExtractZip -link "https://download.robomongo.org/1.2.1/windows/robo3t-1.2.1-windows-x86_64-3e50a65.zip" -targetFolder "C:\tools" -tempName "robomongo.zip"
    
    #choco install -y sql-server-management-studio

    #choco install -y dbeaver
    
    #choco install -y studio3t
    
    #choco install -y --allowemptychecksum SQLite 

    #choco install -y --allowemptychecksum sqlite.shell 
}


#
# [dataSrv] Database Server Platforms
#
if( $dataSrv ) {
    
    choco install sql-server-express -version 13.0.1601.5

    choco install -y mysql 

    choco install -y mongodb

    choco install -y datastax.community

    choco install -y neo4j-community -version 2.2.2.20150617

}


#
# Visual Studio Extensions
#
if( $vsext -and ($vsVersion -eq "2013") ) {

    # Refreshing the environment path variables
    RefreshEnvironment

    # Web Essentials
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/56633663-6799-41d7-9df7-0f2a504ca361/file/105627/39/WebEssentials2013.vsix" `
                       -extensionFileName "WebEssentials2013.vsix" -vsVersion $vsVersion
    
    # NuGet Package Manager 2013
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/4ec1526c-4a8c-4a84-b702-b21a8f5293ca/file/105933/7/NuGet.Tools.2013.vsix" `
                       -extensionFileName "NuGet.Tools.2013.vsix" -vsVersion $vsVersion

    # Productivity Power Tools 2013
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/dbcb8670-889e-4a54-a226-a48a15e4cace/file/117115/4/ProPowerTools.vsix" `
                       -extensionFileName "ProPowerTools.vsix" -vsVersion $vsVersion

    # SQLite Toolbox
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/0e313dfd-be80-4afb-b5e9-6e74d369f7a1/file/29445/72/SqlCeToolbox.vsix" `
                       -extensionFileName "SqlCeToolbox.vsix" -vsVersion $vsVersion
    
    # Indent Guidelines
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/e792686d-542b-474a-8c55-630980e72c30/file/48932/20/IndentGuide%20v14.vsix" `
                       -extensionFileName "IndentGuide_v14.vsix" -vsVersion $vsVersion

    # VS Color Theme Editor 2013
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/9e08e5d3-6eb4-4e73-a045-6ea2a5cbdabe/file/112381/2/ColorThemeEditor.vsix" `
                       -extensionFileName "ColorThemeEditor.vsix" -vsVersion $vsVersion

    # PowerShell Tools
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/c9eb3ba8-0c59-4944-9a62-6eee37294597/file/160501/1/PowerShellTools.vsix" `
                       -extensionFileName "PowerShellTools.vsix" -vsVersion $vsVersion

    # SQLite for WinRT, Windows 8.1
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/1d04f82f-2fe9-4727-a2f9-a2db127ddc9a/file/111148/13/sqlite-winrt81-3080701.vsix" `
                       -extensionFileName "sqlite-winrt81-3080701.vsix" -vsVersion $vsVersion

    # SQLite for Windows Phone 8.1
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/5d97faf6-39e3-4048-a0bc-adde2af75d1b/file/132406/6/sqlite-wp81-winrt-3080701.vsix" `
                       -extensionFileName "sqlite-wp81-winrt-3080701.vsix" -vsVersion $vsVersion

    # Snippet Designer
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/B08B0375-139E-41D7-AF9B-FAEE50F68392/file/5131/9/SnippetDesigner.vsix" `
                       -extensionFileName "SnippetDesigner.vsix" -vsVersion $vsVersion

    # License Header Manager
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/5647a099-77c9-4a49-91c3-94001828e99e/file/51979/5/LicenseHeaderManager.vsix" `
                       -extensionFileName "LicenseHeaderManager.vsix" -vsVersion $vsVersion

}

if( $vsext ) {

    # Refreshing the environment path variables
    RefreshEnvironment

    # Install all extensions from the extensions file

    # Start installing all extensions
    $vs2017ext = Get-Content "$originalExecPath\vs2017.extensions"
    $vs2017ext | ForEach-Object { 
        $vsextline = $_.Split(" ")
        $vsexturl = $vsextline[1]
        $vsextfile = $vsextline[0]
        InstallVSExtension -extensionUrl "$vsexturl" -extensionFileName "$vsextfile" -vsVersion $vsVersion
    }

}


#
# Visual Studio Code Extensions
#
if ( $vscodeext ) {

    # Refreshing the environment path variables
    RefreshEnvironment

    # Start installing all extensions
    $vsCodeExtensions = Get-Content "$originalExecPath\vscode.extensions"
    $vsCodeExtensions | ForEach-Object { code --install-extension $_ }

}


#
# cloneRepos, cloning all my most important Git repositories
#
if( $cloneRepos ) {

    # Refreshing the environment path variables
    RefreshEnvironment

    #
    # Creating my code directories
    #    
    CreatePathIfNotExists -pathName "$codeBaseDir"
    CreatePathIfNotExists -pathName "$codeBaseDir\github"
    CreatePathIfNotExists -pathName "$codeBaseDir\mszCool"
    CreatePathIfNotExists -pathName "$codeBaseDir\marioszp"
    CreatePathIfNotExists -pathName "$codeBaseDir\dpeted"

    #
    # Github clone repositories 
    #
    CreatePathIfNotExists -pathName "$codeBaseDir\github\mszcool"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\Azure"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\AzureAD"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\JMayrbaeurl"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\OfficeDev"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\CloudFoundry"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\dx"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\HDInsight"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\mezmicrosoft-ml"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\others"
   
    cd "$codeBaseDir\github\mszcool"
    git clone https://github.com/mszcool/azIoTEdgeDeviceTwinsDemo.git
    git clone https://github.com/mszcool/azure-quickstart-templates.git
    git clone https://github.com/mszcool/azureAdMultiTenantServicePrincipal.git
    git clone https://github.com/mszcool/AzureBatchTesseractSample.git
    git clone https://github.com/mszcool/AzureFiles2014Sample.git
    git clone https://github.com/mszcool/azureFindVmWithPrivateIPSamples.git
    git clone https://github.com/mszcool/azureMsiAndInstanceMetadata.git
    git clone https://github.com/mszcool/azureSpBasedInstanceMetadata.git
    git clone https://github.com/mszcool/bosh-azure-cpi-release.git
    git clone https://github.com/mszcool/cf-scp-on-azure-simple.git
    git clone https://github.com/mszcool/cfMultiCloudSample.git
    git clone https://github.com/mszcool/codeplex-archive.git
    git clone https://github.com/mszcool/consumption-cost-node.git
    git clone https://github.com/mszcool/devmachinesetup.git
    git clone https://github.com/mszcool/Excel-CustomXMLPart-Demo.git
    git clone https://github.com/mszcool/msgraphcli.git
    git clone https://github.com/mszcool/mszcool.github.io.git
    git clone https://github.com/mszcool/mszcoolAzureBillingAddIn.git
    git clone https://github.com/mszcool/mszcoolPowerOnDemand.git
    git clone https://github.com/mszcool/NServiceBus.AzureServiceBus-SB1.1-WinSrv.git
    git clone https://github.com/mszcool/saphanasso.git
    git clone https://github.com/mszcool/simpleconsolefx.git
    git clone https://github.com/mszcool/SqlAlwaysOnAzurePowerShellClassic.git
    git clone https://github.com/mszcool/TrafficManager201501Sample.git
    git clone https://github.com/mszcool/UniversalApps-Modularity.git
    
    cd "$codeBaseDir\github\Azure"
    git clone https://github.com/Azure/api-management-samples.git
    git clone https://github.com/Azure/azure-batch-samples.git
    git clone https://github.com/Azure/Azure-DataFactory.git
    git clone https://github.com/Azure-Samples/azure-iot-e2e-diag-samples.git
    git clone https://github.com/Azure/Azure-Media-Services-Explorer.git
    git clone https://github.com/Azure/azure-media-services-samples.git
    git clone https://github.com/Azure/azure-mobile-apps-quickstarts.git
    git clone https://github.com/Azure/azure-mobile-engagement-samples.git
    git clone https://github.com/Azure/azure-mobile-services-quickstarts.git
    git clone https://github.com/Azure/azure-notificationhubs-samples.git
    git clone https://github.com/Azure/azure-quickstart-templates.git
    git clone https://github.com/Azure/azure-resource-manager-schemas.git
    git clone https://github.com/Azure/azure-sql-database-samples.git
    git clone https://github.com/Azure/azure-stream-analytics.git
    git clone https://github.com/Azure/Azure-vpn-config-samples.git
    git clone https://github.com/Azure/azure-webjobs-quickstart.git
    git clone https://github.com/Azure/azure-webjobs-sdk-samples.git
    git clone https://github.com/Azure/AzureAD-BYOA-Provisioning-Samples.git
    git clone https://github.com/Azure/AzureQuickStartsProjects.git
    git clone https://github.com/Azure/BillingCodeSamples.git
    git clone https://github.com/Azure-Samples/compute-dotnet-manage-vmss-in-availability-zones.git
    git clone https://github.com/Azure-Samples/e2e-diagnostics-portal.git
    git clone https://github.com/Azure/elastic-db-tools.git
    git clone https://github.com/Azure/identity-management-samples.git
    git clone https://github.com/Azure/open-service-broker-azure.git
    
    cd "$codeBaseDir\github\AzureAD"
    git clone https://github.com/Azure-Samples/active-directory-android.git
    git clone https://github.com/Azure-Samples/active-directory-angularjs-singlepageapp-dotnet-webapi.git
    git clone https://github.com/Azure-Samples/active-directory-cordova-graphapi.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-graphapi-console.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-graphapi-diffquery.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-native-headless.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-native-multitarget.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-native-uwp-wam.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-web-single-sign-out.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-webapi-onbehalfof.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-webapp-multitenant-openidconnect.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-webapp-roleclaims.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-webapp-webapi-oauth2-useridentity.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-webapp-webapi-openidconnect-aspnetcore.git
    git clone https://github.com/Azure-Samples/active-directory-java-graphapi-web.git
    git clone https://github.com/Azure-Samples/active-directory-java-native-headless.git
    git clone https://github.com/Azure-Samples/active-directory-java-webapp-openidconnect.git
    git clone https://github.com/Azure-Samples/active-directory-node-webapi.git
    git clone https://github.com/Azure-Samples/active-directory-xamarin-native-v2.git
    git clone https://github.com/AzureAD/azure-activedirectory-library-for-js.git
    git clone https://github.com/AzureAD/microsoft-authentication-library-for-dotnet.git

    cd "$codeBaseDir\github\HDInsight"
    git clone https://github.com/hdinsight/eventhubs-client.git
    git clone https://github.com/hdinsight/eventhubs-sample-event-producer.git
    git clone https://github.com/hdinsight/hdinsight-spark-examples.git
    git clone https://github.com/hdinsight/hdinsight-storm-examples.git
    git clone https://github.com/hdinsight/spark-streaming-data-persistence-examples.git

    cd "$codeBaseDir\github\CloudFoundry"
    git clone https://github.com/cloudfoundry-incubator/bosh-azure-cpi-release.git
    git clone https://github.com/cf-platform-eng/bosh-azure-template.git
    git clone https://github.com/cloudfoundry/bosh-lite
    git clone https://github.com/cloudfoundry-incubator/service-fabrik-backup-restore.git
    git clone https://github.com/cloudfoundry-incubator/service-fabrik-blueprint-service.git

    cd "$codeBaseDir\github\dx"
    git clone https://github.com/dx-ted-emea/bigdata-labs.git
    git clone https://github.com/dx-ted-emea/iot-labs.git
    git clone https://github.com/MicrosoftDX/AzureLens.git
    git clone https://github.com/MicrosoftDX/AMSOpsTool.git

    cd "$codeBaseDir\github\OfficeDev"
    git clone https://github.com/OfficeDev/O365-AspNetMVC-Microsoft-Graph-Connect.git
    git clone https://github.com/OfficeDev/O365-UWP-Microsoft-Graph-Connect.git
    git clone https://github.com/OfficeDev/O365-UWP-Microsoft-Graph-Snippets.git
    git clone https://github.com/OfficeDev/Office-Add-in-Nodejs-ServerAuth.git
    git clone https://github.com/OfficeDev/CodeLabs-Office.git
    git clone https://github.com/OfficeDev/Excel-Add-in-Bind-To-Table.git
    git clone https://github.com/OfficeDev/O365-AspNetMVC-Microsoft-Graph-Connect.git
    git clone https://github.com/OfficeDev/O365-UWP-Microsoft-Graph-Connect.git
    git clone https://github.com/OfficeDev/O365-UWP-Microsoft-Graph-Snippets.git
    git clone https://github.com/OfficeDev/Office-Add-in-Nodejs-ServerAuth.git
    git clone https://github.com/OfficeDev/office-js-docs.git
    git clone https://github.com/OfficeDev/PowerPoint-Add-in-Microsoft-Graph-ASPNET-InsertChart.git
    git clone https://github.com/OfficeDev/Word-Add-in-Angular2-StyleChecker.git
    git clone https://github.com/OfficeDev/Word-Add-in-AngularJS-Client-OAuth.git
    git clone https://github.com/mandren/Excel-CustomXMLPart-Demo.git
    
    cd "$codeBaseDir\github\JMayrbaeurl"
    git clone https://github.com/JMayrbaeurl/AbfallkalenderBisamberg.git
    git clone https://github.com/JMayrbaeurl/azure-log4j.git
    git clone https://github.com/JMayrbaeurl/GotoZurich2013JavaOnAzureSample.git

    cd "$codeBaseDir\github\mezmicrosoft-ml"
    git clone https://github.com/mezmicrosoft/Introduction_to_RTVS_toturial.git
    git clone https://github.com/mezmicrosoft/Microsoft_R_Server.git
    git clone https://github.com/mezmicrosoft/Sample_Experiments.git

    cd "$codeBaseDir\github\others"
    git clone https://github.com/altercation/solarized.git
    git clone https://github.com/leddt/visualstudio-colors-solarized.git
    git clone https://github.com/shanselman/cmd-colors-solarized.git
    git clone https://github.com/tpenguinltg/windows-solarized.git
    git clone https://github.com/codeinventory/codeinventory.github.io.git
    git clone https://github.com/Sylhare/Type-on-Strap.git
}