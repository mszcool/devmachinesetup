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
# Simple Parameter validation
#
if( $prepOS -and ($tools -or $ittools -or $userTools -or $dev -or $data -or $dataSrv -or $installOtherIDE -or $installVs -or $cloneRepos -or $vsext) ) {
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

    Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

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
# Function to install VSIX extensions
#
$vsixInstallerCommand2013 = "C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\VsixInstaller.exe"
$vsixInstallerCommand2015 = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\VSIXInstaller.exe"
$vsixInstallerCommand2017 = "C:\Program Files (x86)\Microsoft Visual Studio\2017\$vsEdition\Common7\IDE\VsixInstaller.exe"
$vsixInstallerCommandGeneralArgs = " /q /a "

function InstallVSExtension($extensionUrl, $extensionFileName, $vsVersion) {
    
    Write-Host "Installing extension " $extensionFileName
    
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

    choco install -y keepass.install

    choco install -y 7zip

    choco install -y adobereader

    choco install -y googlechrome

    #choco install -y firefox -installArgs l=en-US

    choco install -y jre8

}


#
# [userTools] Tools only needed for end-user related machines (not machines focused on dev-only)
#
if( $userTools ) {

    choco install -y whatsapp 

    choco install -y slack

    choco install -y microsoft-teams

    #choco install -y --allowemptychecksum vlc

    choco install -y --ignorechecksum goodsync
    
}


# 
# [ittools] IT-oriented tools
#
if( $ittools )
{
    choco install -y conemu 
 
    choco install -y mousewithoutborders

    choco install -y vim 

    choco install -y curl

    choco install -y --allowemptychecksum winmerge 

    choco install -y wireshark 

    #choco install -y --allowemptychecksum putty

    choco install -y sysinternals

    #choco install -y --allowemptychecksum winscp

    choco install -y --allowemptychecksum jq

    choco install -y --allowemptychecksum OpenSSL.Light

    choco install -y --allowemptychecksum royalts
    
    #choco install -y --allowemptychecksum vcxsrv

    #choco install -y filezilla 

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
        $stsZipPath = ($PWD.Path + "\spring-tool-suite.zip")
        if(!(Test-Path -Path $stsZipPath)) {
            Invoke-WebRequest "http://download.springsource.com/release/STS/3.9.1.RELEASE/dist/e4.7/spring-tool-suite-3.9.1.RELEASE-e4.7.1a-win32-x86_64.zip" `
                            -OutFile $stsZipPath
        }
        $shell = New-Object -ComObject Shell.Application
        $stsZipFile = $shell.NameSpace($stsZipPath)
        CreatePathIfNotExists("C:\tools\sts")
        foreach($item in $stsZipFile.items()) {
            $shell.Namespace("C:\tools\sts").CopyHere($item)
        }
    }
    # Spring Tool Suite Install End
}


#
# [dev] Developer Tools needed on every dev-machine
#
if( $dev )
{
    #
    # Phase #1 will install the the basic tools and runtimes
    #

    choco install -y visualstudiocode

    choco install -y golang

    choco install -y jdk8

    choco install -y nodejs.install

    choco install -y python 

    choco install -y php 

    choco install -y --allowemptychecksum webpi 

    choco install -y git.install

    choco install -y  --allowemptychecksum gitextensions

    choco install -y poshgit 

    choco install -y --allowemptychecksum windbg 

    choco install -y fiddler4

    choco install -y postman

    choco install -y nimbletext

    choco install -y --allowemptychecksum ilspy 

    choco install -y  --allowemptychecksum linqpad4

    if ( $nohyperv ) {

        choco install -y virtualbox

        choco install -y docker
        
        choco install -y docker-machine
        
        choco install -y docker-compose

    }
    else {

        choco install -y docker-for-windows

    }    

    choco install -y cloudfoundry-cli

    choco install -y kubernetes-cli

    choco install -y vagrant

    choco install -y nuget.commandline

    choco install -y maven

    choco install -y sbt

    choco install -y ngrok.portable

    #
    # Phase #2 Will use the runtimes/tools above to install additional packages
    #

    RefreshEnvironment      # Ships with chocolatey and re-loads environment variables in the current session

    npm install -g moment

    npm install -g bower

    npm install -g gulp

    pip install azure

    pip install --user azure-cli

    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

    Install-Module -Name AzureRM -Force -SkipPublisherCheck 

    Invoke-WebRequest 'https://howtowhale.github.io/dvm/downloads/latest/install.ps1' -UseBasicParsing | Invoke-Expression
    
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

}


#
# [data] Database Platform Tools
#
if( $data )
{

    choco install -y sql-server-management-studio

    choco install -y --allowemptychecksum dbeaver 

    choco install -y studio3t

    choco install -y --allowemptychecksum SQLite 

    choco install -y --allowemptychecksum sqlite.shell 

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

if( $vsext -and ($vsVersion -eq "2015") ) {

    # Refreshing the environment path variables
    RefreshEnvironment

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

if( $vsext -and ($vsVersion -eq "2017") ) {

    # Refreshing the environment path variables
    RefreshEnvironment

    # Productivity Power Tools
    # https://marketplace.visualstudio.com/items?itemName=GitHub.GitHubExtensionforVisualStudio
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/75be44fb-0794-4391-8865-c3279527e97d/file/159055/36/GitHub.VisualStudio.vsix" `
                       -extensionFileName "GitHubExtensionsForVS.vsix" -vsVersion $vsVersion

    # Snippet Designer
    # https://marketplace.visualstudio.com/items?itemName=vs-publisher-2795.SnippetDesigner
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/b08b0375-139e-41d7-af9b-faee50f68392/file/5131/16/SnippetDesigner.vsix" `
                       -extensionFileName "SnippetDesigner.vsix" -vsVersion $vsVersion

    # Web Essentials 2017
    # https://marketplace.visualstudio.com/items?itemName=MadsKristensen.WebExtensionPack2017
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/a5a27916-2099-4c5b-a3ff-6a46e4b01298/file/236262/11/Web%20Essentials%202017%20v1.5.8.vsix" `
                       -extensionFileName "WebEssentials2017.vsix" -vsVersion $vsVersion

    # Productivity Power Tools 2017
    # https://marketplace.visualstudio.com/items?itemName=VisualStudioProductTeam.ProductivityPowerPack2017
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/11693073-e58a-45b3-8818-b2cf5d925af7/file/244442/4/ProductivityPowerTools2017.vsix" `
                       -extensionFileName "ProductivityPowertools2017.vsix" -vsVersion $vsVersion

    # Power Commands 2017
    # https://marketplace.visualstudio.com/items?itemName=VisualStudioProductTeam.PowerCommandsforVisualStudio
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/80f73460-89cd-4d93-bccb-f70530943f82/file/242896/4/PowerCommands.vsix" `
                       -extensionFileName "PowerCommands2017.vsix" -vsVersion $vsVersion

    # Power Shell Tools 2017
    # https://marketplace.visualstudio.com/items?itemName=AdamRDriscoll.PowerShellToolsforVisualStudio2017-18561
    InstallVSExtension -extensionUrl "https://visualstudiogallery.msdn.microsoft.com/8389e80d-9e40-4fc1-907c-a07f7842edf2/file/257196/1/PowerShellTools.15.0.vsix" `
                       -extensionFileName "PowerShellTools2017.vsix" -vsVersion $vsVersion

}


#
# Visual Studio Code Extensions
#
if ( $vscodeext ) {

    # Refreshing the environment path variables
    RefreshEnvironment

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
    CreatePathIfNotExists -pathName "$codeBaseDir\codeplex"
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
    CreatePathIfNotExists -pathName "$codeBaseDir\github\solarized"
   
    cd "$codeBaseDir\github\mszcool"
    git clone https://github.com/mszcool/azure-quickstart-templates.git
    git clone https://github.com/mszcool/azureAdMultiTenantServicePrincipal.git
    git clone https://github.com/mszcool/AzureBatchTesseractSample.git
    git clone https://github.com/mszcool/AzureFiles2014Sample.git
    git clone https://github.com/mszcool/azureSpBasedInstanceMetadata.git
    git clone https://github.com/mszcool/bosh-azure-cpi-release.git
    git clone https://github.com/mszcool/cfMultiCloudSample.git
    git clone https://github.com/mszcool/devmachinesetup.git
    git clone https://github.com/mszcool/msgraphcli.git
    git clone https://github.com/mszcool/mszcoolAzureBillingAddIn.git
    git clone https://github.com/mszcool/mszcoolPowerOnDemand.git
    git clone https://github.com/mszcool/NServiceBus.AzureServiceBus-SB1.1-WinSrv.git
    git clone https://github.com/mszcool/simpleconsolefx.git
    git clone https://github.com/mszcool/SqlAlwaysOnAzurePowerShellClassic.git
    git clone https://github.com/mszcool/TrafficManager201501Sample.git
    git clone https://github.com/mszcool/UniversalApps-Modularity.git
    
    cd "$codeBaseDir\github\Azure"
    git clone https://github.com/Azure/api-management-samples.git
    git clone https://github.com/Azure/azure-batch-samples.git
    git clone https://github.com/Azure/Azure-DataFactory.git
    git clone https://github.com/Azure/Azure-Media-Services-Explorer.git
    git clone https://github.com/Azure/azure-media-services-samples.git
    git clone https://github.com/Azure/azure-mobile-apps-quickstarts.git
    git clone https://github.com/Azure/azure-mobile-engagement-samples.git
    git clone https://github.com/Azure/azure-mobile-services-quickstarts.git
    git clone https://github.com/Azure/azure-notificationhubs-samples.git
    git clone https://github.com/Azure/azure-quickstart-templates.git
    git clone https://github.com/Azure/azure-resource-manager-schemas.git
    git clone https://github.com/Azure/azure-service-bus-samples.git
    git clone https://github.com/Azure/azure-sql-database-samples.git
    git clone https://github.com/Azure/azure-stream-analytics.git
    git clone https://github.com/Azure/Azure-vpn-config-samples.git
    git clone https://github.com/Azure/azure-webjobs-quickstart.git
    git clone https://github.com/Azure/azure-webjobs-sdk-samples.git
    git clone https://github.com/Azure/AzureAD-BYOA-Provisioning-Samples.git
    git clone https://github.com/Azure/AzureQuickStartsProjects.git
    git clone https://github.com/Azure/BillingCodeSamples.git
    git clone https://github.com/Azure/elastic-db-tools.git
    git clone https://github.com/Azure/identity-management-samples.git
    
    cd "$codeBaseDir\github\AzureAD"
    git clone https://github.com/Azure-Samples/active-directory-dotnet-graphapi-console.git
    git clone https://github.com/Azure-Samples/active-directory-java-graphapi-web.git
    git clone https://github.com/Azure-Samples/active-directory-angularjs-singlepageapp-dotnet-webapi.git
    git clone https://github.com/Azure-Samples/active-directory-android.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-webapp-webapi-openidconnect-aspnetcore.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-webapi-onbehalfof.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-native-headless.git
    git clone https://github.com/Azure-Samples/active-directory-cordova-graphapi.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-webapp-webapi-oauth2-useridentity.git
    git clone https://github.com/Azure-Samples/active-directory-java-native-headless.git
    git clone https://github.com/Azure-Samples/active-directory-xamarin-native-v2.git
    git clone https://github.com/Azure-Samples/active-directory-node-webapi.git
    git clone https://github.com/Azure-Samples/active-directory-python-graphapi-oauth2-0-access.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-native-uwp-wam.git
    git clone https://github.com/Azure-Samples/active-directory-java-webapp-openidconnect.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-native-multitarget.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-graphapi-diffquery.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-webapp-multitenant-openidconnect.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-webapp-roleclaims.git
    git clone https://github.com/Azure-Samples/active-directory-dotnet-web-single-sign-out.git
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

    cd "$codeBaseDir\github\solarized"
    git clone https://github.com/altercation/solarized.git
    git clone https://github.com/leddt/visualstudio-colors-solarized.git
    git clone https://github.com/shanselman/cmd-colors-solarized.git
    git clone https://github.com/tpenguinltg/windows-solarized.git

    #
    # Codeplex (legacy stuff)
    #
    cd "$codeBaseDir\codeplex"
    git clone https://git01.codeplex.com/mszcooldemos
    git clone https://git01.codeplex.com/geres2
    
}