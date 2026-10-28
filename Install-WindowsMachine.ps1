Param
(
    [ValidateSet("arm64", "x64")]
    [string] $architecture,

    [Switch] $prepOS,
    [Switch] $tools,
    [Switch] $userTools,
    [Switch] $userToolsSkipPersonal,

    [ValidateSet("no", "all", "basic")]
    [string] $ittools = "no",

    [Switch] $dev,
    [Switch] $devTools,

    [ValidateSet("no", "desktop", "cli")]
    [string] $docker = "no",

    [Switch] $clis,
    [Switch] $hyperv,
    [Switch] $noWsl,

    [ValidateSet("no", "plain", "full")]
    [string] $vsCode = "no",

    [ValidateSet("no", "intelliJ", "all")]
    [string] $otherIde = "no",

    [Switch] $prettyPrompt
)

# Store product IDs are separate because Store selects architecture for the device.
$packageGroups = @{
    PrepOS = @{
        Winget = @("Git.Git") # Git for Windows includes Git LFS.
    }
    Tools = @{
        Winget = @(
            "AgileBits.1Password"
            "KeePassXCTeam.KeePassXC"
            "Microsoft.PowerToys"
            "7zip.7zip"
            "Google.Chrome"
        )
        Store = @("XPDP273C0XHQH2") # Adobe Acrobat Reader DC
    }
    UserTools = @{
        Winget = @("Zoom.Zoom")
        Store = @(
            "9PC3H3V7Q9CH" # Rufus
            "9NV4BS3L1H4S" # QuickLook
            "9WZDNCRFJ27N" # Adobe Express Photos (formerly Photoshop Express)
            "9WZDNCRFHV4V" # MSN Money
            "9WZDNCRFHVFW" # Microsoft News
            "9WZDNCRFJ3Q2" # MSN Weather
            "9NBLGGH4Z1JC" # Speedtest by Ookla
        )
    }
    Personal = @{
        Winget = @(
            "OpenWhisperSystems.Signal"
            "calibre.calibre"
            "CrystalDewWorld.CrystalDiskMark"
        )
        Store = @(
            "9NKSQGP7F2NH" # WhatsApp
            "9NZTWSQNTD0S" # Telegram Desktop
            "9PGZKJC81Q7J" # Cinebench
            "9WZDNCRFJ3TJ" # Netflix
            "9P6RC76MSMMJ" # Prime Video
            "9NXQXXLFST89" # Disney+
            "9NCBCSZSJRSB" # Spotify
        )
    }
    ITBasic = @{
        Winget = @(
            "GitHub.cli"
            "Microsoft.PowerShell"
            "GnuPG.Gpg4win"
            "RaspberryPiFoundation.RaspberryPiImager"
        )
        Store = @("9NBLGGH4252J") # Subnet Manager
    }
    WSL = @{
        Winget = @(
            "Microsoft.WSL"
            "jstarks.npiperelay"
            "dorssel.usbipd-win"
        )
        Store = @("9PDXGNCFSCZV") # Ubuntu
    }
    Virtualization = @{
        Winget = @("Hashicorp.Vagrant")
    }
    ITAll = @{
        Winget = @(
            "BurntSushi.ripgrep.MSVC"
            "mbuilov.sed"
            "jftuga.less"
            "jqlang.jq"
            "ShiningLight.OpenSSL.Light"
            "Microsoft.Sysinternals.Suite"
            "AgileBits.1Password.CLI"
            "Genymobile.scrcpy"
            "Ventoy.Ventoy"
        )
    }
    DevTools = @{
        Winget = @(
            "Microsoft.PowerBI"
            "GitExtensionsTeam.GitExtensions"
            "Microsoft.VisualStudioCode"
            "Microsoft.Azure.StorageExplorer"
            "MongoDB.Compass.Full"
            "icsharpcode.ILSpy"
            "qishibo.AnotherRedisDesktopManager"
            "thomasnordquist.MQTT-Explorer"
            "paolosalvatori.ServiceBusExplorer"
        )
        Store = @(
            "9N2T6F9F5ZDN" # Nightingale REST Client
            "9N278KMPHTRW" # SQLit
            "9PGCV4V3BK4W" # DevToys
        )
    }
    DockerCLI = @{
        Winget = @("Docker.DockerCLI", "Docker.DockerCompose")
    }
    DockerDesktop = @{
        Winget = @("Docker.DockerDesktop")
    }
    Dev = @{
        Winget = @(
            "Microsoft.Azure.FunctionsCoreTools"
            "Microsoft.DotNet.SDK.8"
            "Microsoft.DotNet.SDK.9"
            "Microsoft.DotNet.SDK.10"
            "Microsoft.OpenJDK.21"
            "GoLang.Go"
            "Python.Python.3.13"
            "OpenJS.NodeJS.LTS"
        )
    }
    CLIs = @{
        Winget = @(
            "Microsoft.AzureCLI"
            "Microsoft.Bicep"
            "Microsoft.Azd"
            "Amazon.AWSCLI"
            "Kubernetes.kubectl"
            "Helm.Helm"
        )
    }
    VSCode = @{
        Winget = @("Microsoft.VisualStudioCode")
    }
    IntelliJ = @{
        Winget = @("JetBrains.IntelliJIDEA")
    }
    PrettyPrompt = @{
        Winget = @("JanDeDobbeleer.OhMyPosh")
    }
}

$moduleGroups = @{
    Preparation = @(
        @{ Name = "PackageManagement"; MinimumVersion = "1.4.6"; Scope = "CurrentUser"; AllowClobber = $true }
        @{ Name = "PowerShellGet"; AllowClobber = $true }
    )
    CLIs = @(
        @{ Name = "Az"; AllowClobber = $true }
        @{ Name = "Microsoft.Graph" }
    )
    PrettyPrompt = @(
        @{ Name = "posh-git" }
        @{ Name = "PSReadLine"; SkipPublisherCheck = $true }
    )
}

$npmPackages = @("autorest", "vsts-npm-auth")
$pipPackages = @("autopep8")
$devToolsCodeExtensions = @("ms-mssql.mssql")
$promptFonts = @("Meslo", "CascadiaCode")
$installedArchitectures = @{}

function Get-NativeArchitecture {
    # Query the processor, not the architecture of an emulated PowerShell process.
    $processor = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
        Select-Object -First 1
    switch ($processor.Architecture) {
        12 { return "arm64" }
        9 { return "x64" }
        default { throw "Unsupported or unknown processor architecture '$($processor.Architecture)'. Only ARM64 and x64 are supported." }
    }
}

function RefreshEnvPath() {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Id,

        [ValidateSet("winget", "msstore")]
        [string] $Source = "winget"
    )

    # Native errors are handled below, including when the caller uses PowerShell 7's opt-in preference.
    $ErrorActionPreference = "Stop"
    $PSNativeCommandUseErrorActionPreference = $false
    $common = @(
        "install", "--id", $Id, "--exact", "--source", $Source, "--silent",
        "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity"
    )
    $candidates = @($architecture)
    if ($Source -eq "msstore") {
        $candidates = @("store")
    }
    elseif ($architecture -eq "arm64") {
        $candidates += "x64"
    }

    foreach ($candidate in $candidates) {
        $installArguments = $common
        if ($candidate -ne "store") {
            $installArguments += @("--architecture", $candidate)
        }

        Write-Information "Installing $Id from $Source ($candidate)..."
        & winget @installArguments | Out-Host
        $exitCode = $LASTEXITCODE
        $result = "{0:X8}" -f ($exitCode -band 0xFFFFFFFFL)

        if ($result -in @("00000000", "8A15002B", "8A150061", "8A15010D")) {
            $installedArchitectures[$Id] = $candidate
            return
        }
        if ($result -in @("8A150109", "00000BC2")) {
            Write-Warning "$Id was installed, but Windows needs to be restarted."
            $installedArchitectures[$Id] = $candidate
            return
        }
        # Only installer selection failure permits fallback; never retry a failed installation.
        if (($result -eq "8A150010") -and ($candidate -eq "arm64")) {
            Write-Warning "$Id has no applicable ARM64 installer. Trying x64 (emulated on Windows on Arm)."
            continue
        }

        throw "WinGet failed for $Id from $Source ($candidate), exit code $exitCode (0x$result). Check the WinGet output/logs; no further architecture fallback was attempted."
    }
}

function Install-PackageGroup {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ $packageGroups.ContainsKey($_) })]
        [string] $Name
    )

    $group = $packageGroups[$Name]
    foreach ($id in $group.Winget) {
        Install-WinGetPackage -Id $id
    }
    foreach ($id in $group.Store) {
        Install-WinGetPackage -Id $id -Source "msstore"
    }
}

function Install-ModuleGroup {
    param([string] $Name)

    foreach ($module in $moduleGroups[$Name]) {
        Install-Module @module -Force -ErrorAction Stop
    }
}

function Invoke-SetupCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Command,
        [string[]] $Arguments = @()
    )

    $ErrorActionPreference = "Stop"
    $PSNativeCommandUseErrorActionPreference = $false
    & $Command @Arguments | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "$Command failed with exit code $LASTEXITCODE."
    }
}

function Install-PythonPackages {
    # PEP 514 tags distinguish ARM64 and x64 Python even when both are installed.
    $tag = "3.13"
    if ($installedArchitectures["Python.Python.3.13"] -eq "arm64") {
        $tag += "-arm64"
    }
    $pythonPath = $null
    foreach ($root in @("HKCU:\Software", "HKLM:\Software")) {
        $key = "$root\Python\PythonCore\$tag\InstallPath"
        if (Test-Path $key) {
            $pythonPath = (Get-ItemProperty -Path $key -ErrorAction Stop).ExecutablePath
            if ($pythonPath) { break }
        }
    }
    if (-not $pythonPath -or -not (Test-Path $pythonPath)) {
        throw "Python $tag was not registered. Reopen PowerShell after installation and verify Python's PEP 514 registration."
    }

    Invoke-SetupCommand -Command $pythonPath -Arguments (@("-m", "pip", "install", "--upgrade") + $pipPackages)
}

if (-not $architecture) {
    $architecture = Get-NativeArchitecture
}

if ($prepOS -and ($tools -or $userTools -or ($ittools -ne "no") -or $dev -or $devTools -or
        ($docker -ne "no") -or $clis -or ($vsCode -ne "no") -or ($otherIde -ne "no") -or $prettyPrompt)) {
    throw "Run -prepOS separately, restart Windows, then run with the other tool switches."
}

if ($prepOS) {
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name "ConsolePrompting" -Value $true
    Install-PackageGroup -Name "PrepOS"
    RefreshEnvPath

    Enable-WindowsOptionalFeature -FeatureName NetFx4-AdvSrvs -Online -NoRestart -ErrorAction Stop
    Enable-WindowsOptionalFeature -FeatureName NetFx4Extended-ASPNET45 -Online -NoRestart -ErrorAction Stop
    Enable-WindowsOptionalFeature -FeatureName WCF-Services45 -Online -NoRestart -ErrorAction Stop
    Enable-WindowsOptionalFeature -FeatureName WCF-TCP-PortSharing45 -Online -NoRestart -ErrorAction Stop
    if ($hyperv -or (-not $noWsl)) {
        Enable-WindowsOptionalFeature -FeatureName HypervisorPlatform -Online -NoRestart -ErrorAction Stop
    }
    if (-not $noWsl) {
        Enable-WindowsOptionalFeature -FeatureName VirtualMachinePlatform -Online -NoRestart -ErrorAction Stop
        Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -NoRestart -ErrorAction Stop
    }
    if ($hyperv) {
        Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online -NoRestart -ErrorAction Stop
        Enable-WindowsOptionalFeature -FeatureName Containers -Online -NoRestart -ErrorAction Stop
    }
    Write-Warning "OS preparation completed. Restart Windows before installing tools."
    return
}

if ($tools) {
    Install-PackageGroup -Name "Tools"
}

if ($userTools) {
    Install-PackageGroup -Name "UserTools"
    if (-not $userToolsSkipPersonal) {
        Install-PackageGroup -Name "Personal"
    }
}

if ($ittools -in @("all", "basic")) {
    Install-PackageGroup -Name "ITBasic"
    if (-not $noWsl) {
        Install-PackageGroup -Name "WSL"
    }
    if ($architecture -eq "x64") {
        Install-PackageGroup -Name "Virtualization"
    }
    else {
        Write-Warning "Skipping Vagrant on ARM64: an emulated CLI does not make x64 VM boxes/providers compatible."
    }
}
if ($ittools -eq "all") {
    Install-PackageGroup -Name "ITAll"
}

if ($devTools) {
    Install-PackageGroup -Name "DevTools"
    RefreshEnvPath
    foreach ($extension in $devToolsCodeExtensions) {
        Invoke-SetupCommand -Command "code" -Arguments @("--install-extension", $extension)
    }
}

if ($docker -eq "cli") {
    Install-PackageGroup -Name "DockerCLI"
}
elseif ($docker -eq "desktop") {
    Install-PackageGroup -Name "DockerDesktop"
    RefreshEnvPath
}

if ($dev) {
    Install-PackageGroup -Name "Dev"
    RefreshEnvPath
    Install-PythonPackages
    foreach ($package in $npmPackages) {
        Invoke-SetupCommand -Command "npm.cmd" -Arguments @("install", "-g", $package)
    }

    Invoke-Expression "& { $(Invoke-RestMethod https://aka.ms/install-artifacts-credprovider.ps1 -ErrorAction Stop) } -AddNetfx"
}

if ($clis) {
    Install-PackageGroup -Name "CLIs"
    RefreshEnvPath
    foreach ($extension in (Get-Content "$PSScriptRoot\az-cli.extensions" -ErrorAction Stop)) {
        Invoke-SetupCommand -Command "az.cmd" -Arguments @("extension", "add", "--name", $extension)
    }
    Install-ModuleGroup -Name "Preparation"
    Install-ModuleGroup -Name "CLIs"
}

if ($vsCode -in @("plain", "full")) {
    Install-PackageGroup -Name "VSCode"
    RefreshEnvPath
    if ($vsCode -eq "full") {
        foreach ($extension in (Get-Content "$PSScriptRoot\vscode.extensions" -ErrorAction Stop)) {
            Invoke-SetupCommand -Command "code" -Arguments @("--install-extension", $extension)
        }
    }
}

if ($otherIde -in @("all", "intelliJ")) {
    Install-PackageGroup -Name "IntelliJ"
}

if ($prettyPrompt) {
    Install-ModuleGroup -Name "Preparation"
    Install-ModuleGroup -Name "PrettyPrompt"
    Install-PackageGroup -Name "PrettyPrompt"
    RefreshEnvPath

    if (-not (Test-Path $PROFILE)) {
        $profileDirectory = Split-Path -Parent $PROFILE
        $null = New-Item -ItemType Directory -Path $profileDirectory -Force -ErrorAction Stop
        $null = New-Item -ItemType File -Path $PROFILE -ErrorAction Stop
    }
    $profileContent = Get-Content -Raw -Path $PROFILE -ErrorAction Stop
    if ([string]::IsNullOrEmpty($profileContent)) { $profileContent = "" }
    if (-not $profileContent.Contains("posh-git")) {
        Add-Content -Path $PROFILE -Value 'Import-Module posh-git' -ErrorAction Stop
    }
    if (-not $profileContent.Contains("shellName")) {
        Add-Content -Path $PROFILE -Value '$shellName = $(oh-my-posh get shell)' -ErrorAction Stop
    }
    if (-not $profileContent.Contains("oh-my-posh")) {
        Add-Content -Path $PROFILE -Value 'oh-my-posh init $shellName --config "$env:POSH_THEMES_PATH\iterm2.omp.json" | Invoke-Expression' -ErrorAction Stop
    }
    foreach ($font in $promptFonts) {
        Invoke-SetupCommand -Command "oh-my-posh" -Arguments @("font", "install", $font)
    }
}
