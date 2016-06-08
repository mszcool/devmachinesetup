Param
(
    [Switch]
    $tools,

    [Switch]
    $ittools,

    [Switch]
    $dev,

    [Switch]
    $dev2,

    [Switch]
    $data,

    [Switch]
    $dataSrv,

    [Switch]
    $vsext,

    [Switch]
    $installChoco,

    [Parameter(Mandatory=$False)]
    [ValidateSet("2013", "2015")]
    $vsVersion = "2015",

    [Switch]
    $installVs,

    [Switch]
    $installOtherIDE,

    [Switch]
    $cloneRepos,

    [Parameter(Mandatory=$False)]
    $codeBaseDir = "C:\Code"
)

#
# General constants
# 
$vsixInstallerCommand2013 = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\VsixInstaller.exe"
$vsixInstallerCommand2015 = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\VSIXInstaller.exe"
$vsixInstallerCommandGeneralArgs = " /q /a "

#
# Simple Parameter validation
#

if( ($dev) -and ($dev2) )
{
    throw "You cannot run developer tools installation phase 1 and 2 at the same time since phase 2 requires parts from phase 1 in the shell-path, already!"
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
# Function to install VSIX extensions
#
function InstallVSExtension($extensionUrl, $extensionFileName, $vsVersion) {
    
    Write-Host "Installing extension " $extensionFileName
    
    # Select the appropriate VSIX installer
    if($vsVersion -eq "2013") {
        $vsixInstallerCommand = $vsixInstallerCommand2013
    }
    if($vsVersion -eq "2015") {
        $vsixInstallerCommand = $vsixInstallerCommand2015
    }

    # Download the extension
    wget $extensionUrl -OutFile $extensionFileName

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
# Create the working directory structure
#
CreatePathIfNotExists -pathName "$codeBaseDir"
CreatePathIfNotExists -pathName "$codeBaseDir\github"
CreatePathIfNotExists -pathName "$codeBaseDir\codeplex"
CreatePathIfNotExists -pathName "$codeBaseDir\mszCool"
CreatePathIfNotExists -pathName "$codeBaseDir\marioszp"
CreatePathIfNotExists -pathName "$codeBaseDir\dpeted"


#
# Chocolatey Installation script
# Pre-Requisites:
# - Microsoft Office latest version
# - Visual Studio 2013 latest version
#

if( $installChoco )
{
    Set-ExecutionPolicy unrestricted

    iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
}


#
# [tools] Tools needed on every machine
#

if( $tools ) {

    choco install -y keepass.install

    choco install -y 7zip

    choco install -y firefox -installArgs l=en-US

    choco install -y googlechrome

    choco install -y cdburnerxp 

    choco install -y filezilla 

    choco install -y adobereader

    ##old## choco install -y sublimetext2

    choco install -y paint.net

    choco install -y skype 

    choco install -y vlc

    choco install -y markdown-edit

    choco install -y jre8
    
    choco install -y goodsync
    
    choco install -y mousewithoutborders 

    ##old## choco install -y PDFCreator -Version 1.7.3.20140611

    ##old## choco install -y notepadplusplus

    ##old## choco install -y WindowsLiveWriter 

}


# 
# [ittools] IT-oriented tools
#

if( $ittools )
{

    choco install -y vim 

    choco install -y curl

    choco install -y rdcman 

    choco install -y winmerge 

    choco install -y wireshark 

    #### choco install -y microsoft-message-analyzer 

    choco install -y putty

    choco install -y sysinternals

    choco install -y ffmpeg 

    choco install -y winscp

    choco install -y golang

    choco install -y jq

    choco install -y OpenSSL.Light

    #### choco install -y virtualbox

    #### choco install -y virtualbox -version 4.3.12

    #### Switched from MobaXTerm to Royal TS with XMing for X11 forwarding from Linux-machines
    #### choco install -y mobaxterm -version 8.3

    choco install -y royalts
    
    choco install -y xming
    
    choco install -y visualstudiocode
}


#
# [dev] Developer Tools needed on every dev-machine
#

if( $dev )
{

    choco install -y jdk8

    choco install -y nodejs.install

    choco install -y python 

    choco install -y php 

    choco install -y webpi 

    choco install -y git.install

    choco install -y windbg 

    choco install -y fiddler4

    choco install -y ilspy 

    choco install -y CloudBerryExplorer.AzureStorage

    choco install -y AzureStorageExplorer 

    choco install -y linqpad4

    choco install -y redis-64 

    choco install -y redis-desktop-manager
    
    ## http://www.microsoft.com/en-us/download/details.aspx?id=42536
    
    choco install -y docker
    
    choco install -y docker-machine
    
    choco install -y docker-compose
    
    choco install -y cloudfoundry-cli
     
}


#
# [installVs] and [installOtherIDE]
#

if($installVs) {
    if($vsVersion -eq "2013") {
        choco install -y visualstudiocommunity2013 
    } else {
        choco install visualstudio2015community -version 14.0.23107.0
    }
}

if($installOtherIDE) {
    
    choco install -y intellijidea-community

    #
    # Extract Spring Tool Suite Eclipse and copy to standard working directory
    #
    Write-Host ""
    Write-Host "Installing Spring Tool Suite..." -ForegroundColor Green
    $stsZipPath = ($PWD.Path + "\spring-tool-suite-3.6.2.RELEASE-e4.4.1-win32-x86_64.zip")
    if(!(Test-Path -Path $stsZipPath)) {
        wget "http://dist.springsource.com/release/STS/3.7.1.RELEASE/dist/e4.5/spring-tool-suite-3.7.1.RELEASE-e4.5.1-win32-x86_64.zip" `
             -OutFile $stsZipPath
    }
    $shell = New-Object -ComObject Shell.Application
    $currentPath = Get-Location
    $stsZipFile = $shell.NameSpace($stsZipPath)
    CreatePathIfNotExists("C:\tools\sts")
    foreach($item in $stsZipFile.items()) {
        $shell.Namespace("C:\tools\sts").CopyHere($item)
    }
}


#
# [dev2] Developer Tools Phase 2 - needs to run after Phase 1 and installing IDEs before
#

if( $dev2 )
{
    npm install -g moment

    webpicmd /Install /Products:AzureNodeSDK /AcceptEula
        
    webpicmd /Install /Products:DACFX /AcceptEula

    webpicmd /Install /Products:AzureNodeSDK /AcceptEula

    webpicmd /Install /Products:AzurePython27SDK /AcceptEula

    webpicmd /Install /Products:AzurePython34SDK /AcceptEula
    
    webpicmd /Install /Products:WindowsAzureXPlatCLI /AcceptEula

    webpicmd /Install /Products:WindowsAzurePowershell /AcceptEula
    
    webpicmd /Install /Products:WindowsAzurePowershellGet /AcceptEula
    
    if($vsVersion -eq "2013") {

        webpicmd /Install /Products:OfficeToolsForVS2013Update1 /AcceptEula

        webpicmd /Install /Products:VWDOrVs2013AzurePack /AcceptEula

        webpicmd /Install /Products:HDInsightVS2013Tools /AcceptEula

        webpicmd /Install /Products:DataFactoryVS2013Tools /AcceptEula

        webpicmd /Install /Products:PythonTools21ForVS2013 /AcceptEula

    }

    if($vsVersion -eq "2015") {

        webpicmd /Install /Products:OfficeToolsForVS2015 /AcceptEula

        webpicmd /Install /Products:VWDOrVs2015AzurePack /AcceptEula
        
        webpicmd /Install /Products:VWDOrVs2015AzurePack.2.8 /AcceptEula
        
        webpicmd /Install /Products:VWDOrVs2015AzurePack.2.9 /AcceptEula

        webpicmd /Install /Products:HDInsightVS2015Tools /AcceptEula

        webpicmd /Install /Products:DataFactoryVS2015Tools /AcceptEula
        
        webpicmd /Install /Products:DataLakeVS2015Msi /AcceptEula
        
        webpicmd /Install /Products:HDInsightVS2015Msi /AcceptEula
    }
    
    webpicmd /Install /Products:AzureQuickStarts_1_6_0 /AcceptEula

    webpicmd /Install /Products:SQLCE /AcceptEula
    
    webpicmd /Install /Products:SQLCEforWM /AcceptEula
    
    webpicmd /Install /Products:SQLCE_4_0 /AcceptEula
    
    webpicmd /Install /Products:SQLCLRTypes /AcceptEula
    
    webpicmd /Install /Products:SQLLocalDB /AcceptEula
}


#
# [data] Database Platform Tools
#

if( $data )
{

    choco install -y MsSqlServerManagementStudio2014Express

    choco install -y mysql.workbench 

    choco install -y SQLite 

    choco install -y sqlite.shell 

    choco install -y sqliteadmin 

}


#
# [dataSrv] Database Server Platforms
#

if( $dataSrv ) {
    
    choco install -y MsSqlServer2014Express

    choco install -y mysql 

    choco install -y mongodb

    choco install -y datastax.community

    choco install -y neo4j-community -version 2.2.2.20150617

}

#
# Visual Studio Extensions
#

if( $vsext -and ($vsVersion -eq "2013") ) {

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

if( $vsext -and ($vsVersion -eq "2015") ) {

    # CodeMaid
    # https://visualstudiogallery.msdn.microsoft.com/76293c4d-8c16-4f4a-aee6-21f83a571496
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/76293c4d-8c16-4f4a-aee6-21f83a571496/file/9356/31/CodeMaid_v0.8.0.vsix" `
                       -extensionFileName "CodeMaid.vsix" -vsVersion $vsVersion
    
    # Indent Guides
    # https://visualstudiogallery.msdn.microsoft.com/e792686d-542b-474a-8c55-630980e72c30
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/e792686d-542b-474a-8c55-630980e72c30/file/48932/20/IndentGuide%20v14.vsix" `
                       -extensionFileName "IndentGuide.vsix" -vsVersion $vsVersion
    
    # Web Essentials 2015
    # https://visualstudiogallery.msdn.microsoft.com/ee6e6d8c-c837-41fb-886a-6b50ae2d06a2
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/ee6e6d8c-c837-41fb-886a-6b50ae2d06a2/file/146119/37/Web%20Essentials%202015.1%20v1.0.207.vsix" `
                       -extensionFileName "WebEssentials2015.vsix" -vsVersion $vsVersion
    
    # jQuery Code Snippets
    # https://visualstudiogallery.msdn.microsoft.com/577b9c03-71fb-417b-bcbb-94b6d3d326b8
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/577b9c03-71fb-417b-bcbb-94b6d3d326b8/file/84997/6/jQueryCodeSnippets.vsix" `
                       -extensionFileName "jQueryCodeSnippets.vsix" -vsVersion $vsVersion
    
    # F# PowerTools
    # https://visualstudiogallery.msdn.microsoft.com/136b942e-9f2c-4c0b-8bac-86d774189cff
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/136b942e-9f2c-4c0b-8bac-86d774189cff/file/124201/33/FSharpVSPowerTools.vsix" `
                       -extensionFileName "FSharpPowerTools.vsix" -vsVersion $vsVersion
    
    # Snippet Designer
    # https://visualstudiogallery.msdn.microsoft.com/B08B0375-139E-41D7-AF9B-FAEE50F68392
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/B08B0375-139E-41D7-AF9B-FAEE50F68392/file/5131/12/SnippetDesigner.vsix" `
                       -extensionFileName "SnippetDesigner.vsix" -vsVersion $vsVersion
    
    # SideWaffle Template Pack
    # https://visualstudiogallery.msdn.microsoft.com/a16c2d07-b2e1-4a25-87d9-194f04e7a698
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/a16c2d07-b2e1-4a25-87d9-194f04e7a698/referral/110630" `
                       -extensionFileName "SideWaffle.vsix" -vsVersion $vsVersion
    
    # GraphEngine VSExt
    # https://visualstudiogallery.msdn.microsoft.com/12835dd2-2d0e-4b8e-9e7e-9f505bb909b8
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/12835dd2-2d0e-4b8e-9e7e-9f505bb909b8/file/161997/14/GraphEngineVSExtension.vsix" `
                       -extensionFileName "GraphEngine.vsix" -vsVersion $vsVersion
    
    # Bing Developer Assistant
    # https://visualstudiogallery.msdn.microsoft.com/5d01e3bd-6433-47f2-9c6d-a9da52d172cc
    # Not using it anymore, distracts IntelliSense...
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/5d01e3bd-6433-47f2-9c6d-a9da52d172cc/file/150980/8/DeveloperAssistant_2015.vsix" `
                       -extensionFileName "DevAssistant.vsix" -vsVersion $vsVersion
    
    # RegEx Tester
    # https://visualstudiogallery.msdn.microsoft.com/16b9d664-d88c-460e-84a5-700ab40ba452
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/16b9d664-d88c-460e-84a5-700ab40ba452/file/31824/18/RegexTester-v1.5.2.vsix" `
                       -extensionFileName "RegExTester.vsix" -vsVersion $vsVersion
    
    # Web Compiler
    # https://visualstudiogallery.msdn.microsoft.com/3b329021-cd7a-4a01-86fc-714c2d05bb6c
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/3b329021-cd7a-4a01-86fc-714c2d05bb6c/file/164873/38/Web%20Compiler%20v1.10.306.vsix" `
                       -extensionFileName "WebCompiler.vsix" -vsVersion $vsVersion
    
    # OpenCommandLine
    # https://visualstudiogallery.msdn.microsoft.com/4e84e2cf-2d6b-472a-b1e2-b84932511379
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/4e84e2cf-2d6b-472a-b1e2-b84932511379/file/151803/35/Open%20Command%20Line%20v2.0.168.vsix" `
                       -extensionFileName "OpenCommandLine.vsix" -vsVersion $vsVersion
    
    # Refactoring Essentials for VS2015
    # https://visualstudiogallery.msdn.microsoft.com/68c1575b-e0bf-420d-a94b-1b0f4bcdcbcc
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/68c1575b-e0bf-420d-a94b-1b0f4bcdcbcc/file/146895/20/RefactoringEssentials.vsix" `
                       -extensionFileName "RefactoringEssentials.vsix" -vsVersion $vsVersion
    
    # AllJoyn System Bridge Templates
    # https://visualstudiogallery.msdn.microsoft.com/aea0b437-ef07-42e3-bd88-8c7f906d5da8
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/aea0b437-ef07-42e3-bd88-8c7f906d5da8/file/165147/8/DeviceSystemBridgeTemplate.vsix" `
                       -extensionFileName "AllJoynSysBridge.vsix" -vsVersion $vsVersion
    
    # ASP.NET Project Templates for traditional ASP.NET Projects
    # https://visualstudiogallery.msdn.microsoft.com/9402d38e-2a85-434e-8d6a-8fc075068a42
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/9402d38e-2a85-434e-8d6a-8fc075068a42/referral/149131" `
                       -extensionFileName "AspNetTemplates.vsix" -vsVersion $vsVersion
                           
    # .Net Portability Analyzer
    # https://visualstudiogallery.msdn.microsoft.com/1177943e-cfb7-4822-a8a6-e56c7905292b
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/1177943e-cfb7-4822-a8a6-e56c7905292b/file/138960/3/ApiPort.vsix" `
                       -extensionFileName "NetPortabilityAnalyzer.vsix" -vsVersion $vsVersion

    # Caliburn.Micro Windows 10 Templates for VS2015
    # https://visualstudiogallery.msdn.microsoft.com/b6683732-01ed-4bb3-a2d3-a633a5378997
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/b6683732-01ed-4bb3-a2d3-a633a5378997/file/165880/5/CaliburnUniversalTemplatePackage.vsix" `
                       -extensionFileName "CaliburnTemplates.vsix" -vsVersion $vsVersion

    # Color Theme Editor
    # https://visualstudiogallery.msdn.microsoft.com/6f4b51b6-5c6b-4a81-9cb5-f2daa560430b
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/6f4b51b6-5c6b-4a81-9cb5-f2daa560430b/file/169990/1/ColorThemeEditor.vsix" `
                       -extensionFileName "ColorThemeEditor.vsix" -vsVersion $vsVersion

    # Productivity Power Tools
    # https://visualstudiogallery.msdn.microsoft.com/34ebc6a2-2777-421d-8914-e29c1dfa7f5d
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/34ebc6a2-2777-421d-8914-e29c1dfa7f5d/file/169971/1/ProPowerTools.vsix" `
                       -extensionFileName "ProPowerTools.vsix" -vsVersion $vsVersion
                       
}


#
# cloneRepos
#

if( $cloneRepos ) {
    
    #
    # Github clone repositories 
    #

    CreatePathIfNotExists -pathName "$codeBaseDir\github\mszcool"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\Azure"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\JMayrbaeurl"
    CreatePathIfNotExists -pathName "$codeBaseDir\github\OfficeDev"
   
    cd "$codeBaseDir\github\mszcool"
    git clone https://github.com/mszcool/SqlAlwaysOnAzurePowerShellClassic.git
    git clone https://github.com/mszcool/UniversalApps-Modularity.git
    git clone https://github.com/mszcool/AzureFiles2014Sample.git
    git clone https://github.com/mszcool/TrafficManager201501Sample.git
    git clone https://github.com/mszcool/SqlAlwaysOnAzurePowerShellClassic.git
    git clone https://github.com/mszcool/AzureBatchTesseractSample.git
    git clone https://github.com/mszcool/devmachinesetup.git
    git clone https://github.com/mszcool/bosh-azure-cpi-release.git
    git clone https://github.com/mszcool/simpleconsolefx.git
    git clone https://github.com/mszcool/msgraphcli.git
    git clone https://github.com/mszcool/NServiceBus.AzureServiceBus-SB1.1-WinSrv.git
    
    cd "$codeBaseDir\github\Azure"
    git clone https://github.com/Azure/AzureQuickStartsProjects.git
    git clone https://github.com/Azure/azure-sql-database-samples.git
    git clone https://github.com/Azure/api-management-samples.git
    git clone https://github.com/Azure/azure-webjobs-sdk-samples.git
    git clone https://github.com/Azure/BillingCodeSamples.git
    git clone https://github.com/Azure/Azure-Media-Services-Explorer.git
    git clone https://github.com/Azure/azure-batch-samples.git
    git clone https://github.com/Azure/azure-resource-manager-schemas.git
    git clone https://github.com/Azure/azure-quickstart-templates.git
    git clone https://github.com/Azure/azure-service-bus-samples.git
    git clone https://github.com/Azure/azure-media-services-samples.git
    git clone https://github.com/Azure/api-management-samples.git
    git clone https://github.com/Azure/identity-management-samples.git
    git clone https://github.com/Azure/AzureAD-BYOA-Provisioning-Samples.git
    git clone https://github.com/Azure/Azure-DataFactory.git
    git clone https://github.com/Azure/azure-mobile-engagement-samples.git
    git clone https://github.com/Azure/azure-notificationhubs-samples.git
    git clone https://github.com/Azure/azure-webjobs-quickstart.git
    git clone https://github.com/Azure/Azure-vpn-config-samples.git
    git clone https://github.com/Azure/azure-mobile-apps-quickstarts.git
    git clone https://github.com/Azure/elastic-db-tools.git
    git clone https://github.com/Azure/azure-mobile-services-quickstarts.git

    cd "$codeBaseDir\github\OfficeDev"
    git clone https://github.com/OfficeDev/O365-AspNetMVC-Microsoft-Graph-Connect.git
    git clone https://github.com/OfficeDev/O365-UWP-Microsoft-Graph-Connect
    git clone https://github.com/OfficeDev/O365-UWP-Microsoft-Graph-Snippets
    git clone https://github.com/OfficeDev/Office-Add-in-Nodejs-ServerAuth.git
    
    cd "$codeBaseDir\github\JMayrbaeurl"
    git clone https://github.com/JMayrbaeurl/AbfallkalenderBisamberg.git
    git clone https://github.com/JMayrbaeurl/azure-log4j.git
    git clone https://github.com/JMayrbaeurl/GotoZurich2013JavaOnAzureSample.git
    
    cd "$codeBaseDir\github"
    git clone https://github.com/dahlbyk/posh-git.git


    #
    # Codeplex (legacy stuff)
    #
    cd "$codeBaseDir\codeplex"
    git clone https://git01.codeplex.com/mszcooldemos
    git clone https://git01.codeplex.com/geres2
    
}
