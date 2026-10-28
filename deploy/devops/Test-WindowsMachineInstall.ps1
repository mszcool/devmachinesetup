$ErrorActionPreference = "Stop"
$scriptPath = Join-Path $PSScriptRoot "..\..\Install-WindowsMachine.ps1"
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath, [ref] $tokens, [ref] $parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw ($parseErrors | Out-String)
}

# Load only declarations; never execute the machine setup script in a test.
foreach ($statement in $ast.EndBlock.Statements) {
    if (($statement -is [System.Management.Automation.Language.AssignmentStatementAst]) -or
        ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst])) {
        . ([scriptblock]::Create($statement.Extent.Text))
    }
}

$script:assertions = 0
function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
    $script:assertions++
}

function Assert-Throws {
    param([scriptblock] $Action, [string] $Pattern)
    $caught = $null
    try { & $Action }
    catch { $caught = $_ }
    Assert-True ($null -ne $caught) "Expected an exception matching '$Pattern'."
    Assert-True ($caught.Exception.Message -match $Pattern) "Unexpected error: $caught"
}

function Reset-WinGetMock {
    param([int[]] $ExitCodes = @(0))
    $script:wingetCalls = @()
    $script:wingetExitCodes = New-Object "System.Collections.Generic.Queue[int]"
    foreach ($code in $ExitCodes) { $script:wingetExitCodes.Enqueue($code) }
    $script:installedArchitectures = @{}
}

function winget {
    $script:wingetCalls += ,@($args)
    if ($script:wingetExitCodes.Count -eq 0) { throw "Unexpected extra WinGet invocation." }
    $script:LASTEXITCODE = $script:wingetExitCodes.Dequeue()
}

function Get-CallArgument {
    param([object[]] $Call, [string] $Name)
    $index = [array]::IndexOf($Call, $Name)
    if ($index -ge 0) { return $Call[$index + 1] }
}

$architectureParameter = $ast.ParamBlock.Parameters |
    Where-Object { $_.Name.VariablePath.UserPath -eq "architecture" }
Assert-True ($null -ne $architectureParameter) "Missing architecture parameter."
Assert-True ($architectureParameter.Extent.Text -notmatch "Mandatory\s*=\s*\`$true") "Architecture must be optional."
Assert-True ($architectureParameter.Extent.Text -match 'ValidateSet\("arm64", "x64"\)') "Architecture choices changed."

function Test-NativeArchitectureDetection {
    param([int] $ProcessorArchitecture, [string] $ExpectedArchitecture)
    function Get-CimInstance {
        param([string] $ClassName, [string] $ErrorAction)
        Assert-True ($ClassName -eq "Win32_Processor") "Must query the native processor."
        Assert-True ($ErrorAction -eq "Stop") "Detection errors must not be hidden."
        return [pscustomobject]@{ Architecture = $ProcessorArchitecture }
    }
    if ($ExpectedArchitecture) {
        Assert-True ((Get-NativeArchitecture) -eq $ExpectedArchitecture) "Wrong native architecture detected."
    }
    else {
        Assert-Throws { Get-NativeArchitecture } "Unsupported or unknown"
    }
}
Test-NativeArchitectureDetection -ProcessorArchitecture 12 -ExpectedArchitecture "arm64"
Test-NativeArchitectureDetection -ProcessorArchitecture 9 -ExpectedArchitecture "x64"
Test-NativeArchitectureDetection -ProcessorArchitecture 0
function Test-ArchitectureQueryFailure {
    function Get-CimInstance { throw "CIM query failed" }
    Assert-Throws { Get-NativeArchitecture } "CIM query failed"
}
Test-ArchitectureQueryFailure

$architecture = "arm64"
Reset-WinGetMock
Install-WinGetPackage -Id "Git.Git"
Assert-True ($wingetCalls.Count -eq 1) "ARM64 success must not trigger fallback."
Assert-True ((Get-CallArgument $wingetCalls[0] "--architecture") -eq "arm64") "ARM64 was not preferred."
foreach ($flag in @("--exact", "--silent", "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity")) {
    Assert-True ($wingetCalls[0] -contains $flag) "Missing common flag $flag."
}
Assert-True ((Get-CallArgument $wingetCalls[0] "--source") -eq "winget") "Missing winget source."

$noInstaller = [Convert]::ToInt32("8A150010", 16)
Reset-WinGetMock @( $noInstaller, 0 )
$fallbackWarnings = @()
Install-WinGetPackage -Id "Amazon.AWSCLI" -WarningVariable fallbackWarnings -WarningAction SilentlyContinue
Assert-True ($wingetCalls.Count -eq 2) "Missing ARM64-to-x64 fallback."
Assert-True ((Get-CallArgument $wingetCalls[1] "--architecture") -eq "x64") "Fallback must be explicitly x64."
Assert-True ($fallbackWarnings.Count -eq 1) "Fallback must emit a warning."
Assert-True ($installedArchitectures["Amazon.AWSCLI"] -eq "x64") "Fallback architecture was not recorded."

foreach ($failure in @("8A150014", "8A15002C", "80072EE7", "8A15010A")) {
    Reset-WinGetMock @([Convert]::ToInt32($failure, 16))
    Assert-Throws { Install-WinGetPackage -Id "Broken.Package" } "0x$failure"
    Assert-True ($wingetCalls.Count -eq 1) "Non-selection error $failure must not trigger fallback."
}

Reset-WinGetMock @( $noInstaller, $noInstaller )
Assert-Throws {
    Install-WinGetPackage -Id "Unsupported.Package" -WarningAction SilentlyContinue
} "x64"
Assert-True ($wingetCalls.Count -eq 2) "Unsupported packages must not fall through to x86."

$architecture = "x64"
Reset-WinGetMock
Install-WinGetPackage -Id "Git.Git"
Assert-True ((Get-CallArgument $wingetCalls[0] "--architecture") -eq "x64") "Explicit x64 was not honored."
Reset-WinGetMock @($noInstaller)
Assert-Throws { Install-WinGetPackage -Id "Unsupported.Package" } "x64"
Assert-True ($wingetCalls.Count -eq 1) "x64 selection must not retry another architecture."

foreach ($success in @("8A15002B", "8A150061", "8A15010D")) {
    Reset-WinGetMock @([Convert]::ToInt32($success, 16))
    Install-WinGetPackage -Id "Already.Installed"
    Assert-True ($wingetCalls.Count -eq 1) "Idempotent outcome $success must not trigger fallback."
}
foreach ($reboot in @("8A150109", "00000BC2")) {
    Reset-WinGetMock @([Convert]::ToInt32($reboot, 16))
    $rebootWarnings = @()
    Install-WinGetPackage -Id "Restart.Required" -WarningVariable rebootWarnings -WarningAction SilentlyContinue
    Assert-True ($rebootWarnings.Count -eq 1) "Reboot outcome must emit a warning."
}

$architecture = "arm64"
Reset-WinGetMock
Install-WinGetPackage -Id "9PDXGNCFSCZV" -Source "msstore"
Assert-True ($wingetCalls.Count -eq 1) "Store should be called only once."
Assert-True ($wingetCalls[0] -notcontains "--architecture") "Store must select architecture for the device."
Assert-True ((Get-CallArgument $wingetCalls[0] "--source") -eq "msstore") "Store source was lost."
Reset-WinGetMock @($noInstaller)
Assert-Throws { Install-WinGetPackage -Id "Unavailable.StoreApp" -Source "msstore" } "msstore"
Assert-True ($wingetCalls.Count -eq 1) "Store failures must not retry as winget packages."

$allIds = @()
foreach ($name in $packageGroups.Keys) {
    Reset-WinGetMock (@(0) * (@($packageGroups[$name].Winget).Count + @($packageGroups[$name].Store).Count))
    Install-PackageGroup -Name $name
    foreach ($call in $wingetCalls) {
        $id = Get-CallArgument $call "--id"
        $allIds += $id
        Assert-True (-not [string]::IsNullOrWhiteSpace($id)) "Group $name contains an empty package ID."
        Assert-True ($call -contains "--exact") "Group $name does not use exact IDs."
        if ((Get-CallArgument $call "--source") -eq "winget") {
            Assert-True ((Get-CallArgument $call "--architecture") -eq "arm64") "Group $name bypassed architecture selection."
        }
    }
}
foreach ($excluded in @(
        "Chocolatey.Chocolatey", "GitHub.GitLFS", "Microsoft.NuGet", "RicoSuter.NSwagStudio",
        "RedHat.OpenShift-Client", "projectkudu.ARMClient", "DEVCOM.JMeter", "Microsoft.AzureDataStudio",
        "Microsoft.Azure.DataCLI", "Microsoft.OpenJDK.16", "3T.Robo3T", "CoreyButler.NVMforWindows",
        "GnuWin32.Grep", "cURL.cURL")) {
    Assert-True ($allIds -notcontains $excluded) "Excluded package $excluded is still installed."
}
Assert-True ($packageGroups.WSL.Winget -contains "Microsoft.WSL") "WSL must use the architecture-aware package."
Assert-True ($packageGroups.Dev.Winget -contains "Microsoft.DotNet.SDK.10") ".NET 10 is missing."
Assert-True ($devToolsCodeExtensions -contains "ms-mssql.mssql") "Azure Data Studio replacement is missing."

function fakecommand { $script:LASTEXITCODE = 17 }
Assert-Throws { Invoke-SetupCommand -Command "fakecommand" } "17"
Assert-Throws { Invoke-SetupCommand -Command "NoSuchSetupExecutable-18c2272b" } "NoSuchSetupExecutable"
Remove-Item Function:\winget
Assert-Throws { Install-PackageGroup -Name "NoSuchGroup" } "Name"

function Test-PythonSelection {
    param([string] $SelectedArchitecture, [string] $RegistryRoot)
    $installedArchitectures = @{ "Python.Python.3.13" = $SelectedArchitecture }
    $tag = "3.13"
    if ($SelectedArchitecture -eq "arm64") { $tag += "-arm64" }
    $expectedKey = "$RegistryRoot\Python\PythonCore\$tag\InstallPath"
    $expectedExecutable = "C:\Python-$SelectedArchitecture\python.exe"
    $script:pythonCommand = $null

    function Test-Path {
        param([string] $Path)
        return ($Path -eq $expectedKey -or $Path -eq $expectedExecutable)
    }
    function Get-ItemProperty {
        param([string] $Path, [string] $ErrorAction)
        Assert-True ($Path -eq $expectedKey) "Wrong Python registration selected."
        return @{ ExecutablePath = $expectedExecutable }
    }
    function Invoke-SetupCommand {
        param([string] $Command, [string[]] $Arguments)
        $script:pythonCommand = $Command
        Assert-True (($Arguments -join " ") -eq "-m pip install --upgrade autopep8") "pip arguments changed."
    }
    Install-PythonPackages
    Assert-True ($script:pythonCommand -eq $expectedExecutable) "pip must use the installed Python architecture."
}
Test-PythonSelection -SelectedArchitecture "arm64" -RegistryRoot "HKCU:\Software"
Test-PythonSelection -SelectedArchitecture "arm64" -RegistryRoot "HKLM:\Software"
Test-PythonSelection -SelectedArchitecture "x64" -RegistryRoot "HKCU:\Software"
Test-PythonSelection -SelectedArchitecture "x64" -RegistryRoot "HKLM:\Software"

function Test-MissingPythonRegistration {
    function Test-Path { return $false }
    Assert-Throws { Install-PythonPackages } "not registered"
}
Test-MissingPythonRegistration

function Invoke-SetupScenario {
    param([hashtable] $Options)
    $architecture = "arm64"
    $prepOS = $tools = $userTools = $userToolsSkipPersonal = $dev = $devTools = $clis = $hyperv = $noWsl = $prettyPrompt = $false
    $ittools = $docker = $vsCode = $otherIde = "no"
    foreach ($option in $Options.Keys) {
        Set-Variable -Name $option -Value $Options[$option]
    }
    $script:scenarioGroupCalls = @()
    $script:scenarioFeatures = @()
    $script:scenarioCommands = @()
    $script:scenarioModules = @()
    function Install-PackageGroup {
        param([string] $Name)
        $script:scenarioGroupCalls += $Name
    }
    function Enable-WindowsOptionalFeature {
        param([string] $FeatureName, [switch] $Online, [switch] $NoRestart, [string] $ErrorAction)
        $script:scenarioFeatures += $FeatureName
    }
    function Install-ModuleGroup {
        param([string] $Name)
        $script:scenarioModules += $Name
    }
    function Invoke-SetupCommand {
        param([string] $Command, [string[]] $Arguments)
        $script:scenarioCommands += [pscustomobject]@{ Command = $Command; Arguments = $Arguments }
    }
    function Get-Content { return "test.extension" }
    function Invoke-RestMethod { return '$null' }
    function Invoke-Expression {}
    function Set-ItemProperty {}
    function RefreshEnvPath {}
    function Install-PythonPackages {}
    function Get-NativeArchitecture { return "arm64" }

    foreach ($statement in $ast.EndBlock.Statements) {
        if ($statement -is [System.Management.Automation.Language.IfStatementAst]) {
            . ([scriptblock]::Create($statement.Extent.Text))
        }
    }
}

Invoke-SetupScenario @{ prepOS = $true }
Assert-True (($scenarioGroupCalls -join ",") -eq "PrepOS") "prepOS must not install tool groups."
Assert-True ($scenarioFeatures -contains "VirtualMachinePlatform") "WSL 2 virtualization prerequisite is missing."
Invoke-SetupScenario @{ architecture = ""; ittools = "basic"; noWsl = $true } -WarningAction SilentlyContinue
Assert-True (($scenarioGroupCalls -join ",") -eq "ITBasic") "Auto-detected ARM64 must skip Vagrant."
Invoke-SetupScenario @{ prepOS = $true; noWsl = $true }
Assert-True ($scenarioFeatures -notcontains "Microsoft-Windows-Subsystem-Linux") "noWsl must skip the WSL feature."
Assert-True ($scenarioFeatures -notcontains "VirtualMachinePlatform") "noWsl must skip WSL virtualization."
Invoke-SetupScenario @{ prepOS = $true; noWsl = $true; hyperv = $true }
Assert-True ($scenarioFeatures -contains "Microsoft-Hyper-V-All") "hyperv feature was not enabled."
Assert-Throws { Invoke-SetupScenario @{ prepOS = $true; tools = $true } } "separately"

Invoke-SetupScenario @{ tools = $true; userTools = $true; userToolsSkipPersonal = $true }
Assert-True (($scenarioGroupCalls -join ",") -eq "Tools,UserTools") "Personal-skip switch changed behavior."
Invoke-SetupScenario @{ userTools = $true }
Assert-True (($scenarioGroupCalls -join ",") -eq "UserTools,Personal") "Personal group was not installed."
Invoke-SetupScenario @{ ittools = "basic"; noWsl = $true } -WarningAction SilentlyContinue
Assert-True (($scenarioGroupCalls -join ",") -eq "ITBasic") "Basic/noWsl/ARM64 routing changed."
Invoke-SetupScenario @{ ittools = "all" } -WarningAction SilentlyContinue
Assert-True (($scenarioGroupCalls -join ",") -eq "ITBasic,WSL,ITAll") "ARM64 must skip Vagrant but retain all IT tools."
Invoke-SetupScenario @{ architecture = "x64"; ittools = "all" }
Assert-True (($scenarioGroupCalls -join ",") -eq "ITBasic,WSL,Virtualization,ITAll") "x64 Vagrant routing changed."

Invoke-SetupScenario @{ docker = "cli" }
Assert-True (($scenarioGroupCalls -join ",") -eq "DockerCLI") "Docker CLI routing changed."
Invoke-SetupScenario @{ docker = "desktop" }
Assert-True (($scenarioGroupCalls -join ",") -eq "DockerDesktop") "Docker Desktop routing changed."
Invoke-SetupScenario @{ dev = $true; clis = $true; devTools = $true; vsCode = "full"; otherIde = "all" }
Assert-True (($scenarioGroupCalls -join ",") -eq "DevTools,Dev,CLIs,VSCode,IntelliJ") "Developer group dispatch changed."
Assert-True (($scenarioModules -join ",") -eq "Preparation,CLIs") "CLI module installation changed."
$mssqlCommands = @($scenarioCommands | Where-Object { $_.Arguments -contains "ms-mssql.mssql" })
Assert-True ($mssqlCommands.Count -eq 1) "devTools must install the MSSQL extension."
$npmCommands = @($scenarioCommands | Where-Object { $_.Command -eq "npm.cmd" })
Assert-True ($npmCommands.Count -eq $npmPackages.Count) "npm globals must come from the centralized list."

Write-Output "Passed $assertions assertions. No software was installed."
