# Developer Machine Setup Scripts

Scripts for setting up development machines. Windows setup uses WinGet, with
PowerShell Gallery modules, npm globals, pip packages, and editor extensions
installed separately.

## Windows usage

Run from an elevated, 64-bit Windows PowerShell 5.1 or PowerShell 7 session.
Install [WinGet](https://learn.microsoft.com/windows/package-manager/winget/)
first. Windows 11 is recommended for Windows on Arm and x64 emulation.

The script automatically detects the native processor architecture using
`Get-CimInstance Win32_Processor`, independently of whether PowerShell is running
under emulation. ARM64 machines prefer ARM64 installers with x64 fallback;
Intel/AMD x64 machines request x64. Detection failures and unsupported processors
stop setup rather than silently selecting an architecture.

An optional `-architecture arm64|x64` overrides detection when explicitly needed.

```powershell
# 1. Prepare Windows, then restart.
.\Install-WindowsMachine.ps1 -prepOS

# 2. Install the groups you need.
.\Install-WindowsMachine.ps1 -tools -ittools all -dev -devTools -clis -docker desktop -vsCode full

# Optional explicit override.
.\Install-WindowsMachine.ps1 -architecture x64 -tools -dev -vsCode full
```

`-prepOS` must run separately from tool installation. `-noWsl` disables WSL
feature/package installation; `-hyperv` additionally enables Hyper-V and
Containers where supported by the Windows edition/device.

| Switch | Installs |
| --- | --- |
| `-tools` | Base applications |
| `-userTools` | End-user and personal applications |
| `-userToolsSkipPersonal` | Excludes personal applications when used with `-userTools` |
| `-ittools basic` / `all` | IT/WSL tools; `all` adds utilities |
| `-dev` | SDKs, runtimes, Node LTS, pip/npm tools, artifacts credential provider |
| `-devTools` | Developer applications, VS Code and its MSSQL extension |
| `-clis` | Cloud/Kubernetes CLIs and Az/Microsoft.Graph PowerShell modules |
| `-docker cli` / `desktop` | Docker command-line tools or Docker Desktop |
| `-vsCode plain` / `full` | VS Code alone or with [vscode.extensions](vscode.extensions) |
| `-otherIde intelliJ` / `all` | Unified IntelliJ IDEA distribution |
| `-prettyPrompt` | Prompt modules, Oh My Posh, fonts, and profile configuration |

### Package lists and installation policy

The top of [Install-WindowsMachine.ps1](Install-WindowsMachine.ps1) contains
`$packageGroups`, `$moduleGroups`, and the npm/pip/extension/font lists.
Each tool switch calls the corresponding group through shared helpers.
WinGet entries are exact package IDs; Store entries are exact product IDs.
Auxiliary extension lists are resolved relative to the script, not the current
working directory.

- Detected ARM64 (or `-architecture arm64`): try an ARM64 installer first. Only WinGet's
  `APPINSTALLER_CLI_ERROR_NO_APPLICABLE_INSTALLER` (`0x8A150010`) permits an
  explicit x64 retry, with a warning.
- Detected x64 (or `-architecture x64`): request x64 directly. There is **no x86 retry** in either
  mode. Packages requiring x86-marked installers have been omitted below.
- Architecture-neutral/multi-architecture installers remain subject to WinGet's
  applicability checks. An installer label alone is not proof that every
  executable or dependency it contains is native.
- Microsoft Store is an exception: Store selects a compatible application for
  the device. It is not forced to the requested architecture and may deliver an
  emulated application. No cross-source fallback is attempted.
- Download, permission, agreement, source, and installer failures stop setup
  with the package ID and exit code. They are **not** interpreted as missing
  ARM64 support. An already-current package is an idempotent outcome; successful
  installation requiring a reboot emits a warning.
- This script is for provisioning, not migrating an already-installed program
  between architectures. WinGet may retain an existing installation. Remove an
  old architecture manually if needed, then rerun the relevant group.

Do not use the proposed `winget show ... --architecture arm64` exit-code-only
test: **`show` can exit successfully while printing "No applicable installer
found"**. The helper instead uses the install command's installer-selection
failure code before WinGet downloads/runs an installer.
See [show semantics](https://learn.microsoft.com/windows/package-manager/winget/show)
and [WinGet error definitions](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerSharedLib/Public/AppInstallerErrors.h).

## ARM64 review (2026-10-28)

The following reflects read-only queries of the current WinGet catalog, including
the selected installer URLs, rather than assumptions about upstream support.
Package availability can change. "ARM64" means WinGet offered an ARM64-targeted
installer on this check; "x64 fallback" describes this catalog, **not** a claim
that upstream can never provide an ARM64 build.

### WinGet packages retained or added

| Group | ARM64-targeted installers offered | x64 fallback in the current catalog |
| --- | --- | --- |
| Base/preparation | Git, 1Password, KeePassXC, PowerToys, 7-Zip, Chrome | None |
| User/personal | Zoom, CrystalDiskMark | Signal, calibre |
| IT/WSL | GitHub CLI (`gh`), PowerShell, WSL, usbipd-win, Raspberry Pi Imager | Gpg4win, jstarks.npiperelay |
| Extra IT tools | ripgrep, less, jq, OpenSSL Light, Sysinternals Suite, scrcpy, Ventoy | sed, 1Password CLI |
| Developer applications | Git Extensions, VS Code, Storage Explorer, ILSpy | Power BI, MongoDB Compass, Another Redis Desktop Manager, MQTT Explorer, Service Bus Explorer |
| Development runtimes | Functions Core Tools, .NET SDKs 8/9/10, OpenJDK 21, Go, Python 3.13, Node LTS | None |
| Docker | Docker Desktop, Docker Compose | Standalone Docker CLI |
| CLIs | Bicep, kubectl, Helm | Azure CLI, Azure Developer CLI (`azd`), AWS CLI |
| Editor/prompt | Unified IntelliJ IDEA, Oh My Posh | None |

Important corrections to the earlier AI advice:

- `gh`, kubectl, KeePassXC, Raspberry Pi Imager, Storage Explorer, Functions Core
  Tools, and scrcpy have ARM64-targeted installers in the checked catalog.
- Azure CLI and azd currently select x64 here; they should not be listed as
  guaranteed native WinGet installs. The same applies to 1Password CLI.
- Python 3.11 already has an ARM64 installer; upgrading to 3.13 is modernization,
  not a prerequisite for ARM64. pip wheels/native extensions still need their
  own architecture support.
- Adobe Reader's checked `Adobe.Acrobat.Reader.64-bit` WinGet package offers x64,
  not ARM64. The script retains the existing Store channel and lets Store select.
- Vagrant is retained **only for `-architecture x64`**. On ARM64 it is skipped
  with a warning: an emulated management CLI cannot run incompatible VM images
  or x64 kernel drivers. Hyper-V provider/image support must be checked separately.
- Docker Desktop on Arm is for compatible Linux containers. An installable CLI
  does not imply support for Windows containers or x64 container images.
- Sysinternals, Ventoy, USB tools and other bundles can contain architecture-
  specific binaries/drivers. Only compatible native kernel drivers can load;
  user-mode x64 emulation does not solve driver compatibility.
- PowerShell modules, npm packages, VS Code extensions, Azure CLI extensions,
  and their downloaded dependencies are not certified by the WinGet package
  architecture. Test the workloads you use; Graph is not an AzureAD cmdlet
  drop-in replacement.

Selected upstream evidence:
[Git for Windows](https://github.com/git-for-windows/git/releases),
[GitHub CLI](https://github.com/cli/cli/releases),
[scrcpy](https://github.com/Genymobile/scrcpy/releases),
[Storage Explorer](https://github.com/microsoft/AzureStorageExplorer/releases),
[Functions Core Tools](https://github.com/Azure/azure-functions-core-tools/releases),
[Sysinternals ARM64 bundle](https://download.sysinternals.com/files/SysinternalsSuite-ARM64.zip),
and [WinGet manifests](https://github.com/microsoft/winget-pkgs/tree/master/manifests).

### Microsoft Store applications

Store architecture was **not independently certified**. These applications retain
Store installation with exact product IDs: Acrobat Reader, Rufus, WhatsApp,
Telegram, Cinebench, Netflix, Prime Video, Disney+, Spotify, QuickLook, Adobe
Express Photos (formerly Photoshop Express), MSN Money, Microsoft News, MSN
Weather, Speedtest, Subnet Manager, Ubuntu, Nightingale, SQLit, and DevToys.

Some old display names no longer resolve. Zoom moved to `Zoom.Zoom` for explicit
architecture selection. Messenger, FeedLab, Ico Converter, IP Calculator,
Cosmos DB Studio, and Sway were omitted because the old apps could not be resolved in the
checked Store catalog; no similarly named third-party substitutes were chosen.
Store availability also depends on market/account/device.

### Replacements and omissions

These are provisioning changes only: existing programs are **not uninstalled**.

| Previous entry | Change |
| --- | --- |
| Hard-coded `wsl_update_x64.msi` | `Microsoft.WSL`; OS preparation also enables `VirtualMachinePlatform`, required for WSL 2 |
| OpenJDK 16 | OpenJDK 21 |
| Python 3.11 | Python 3.13; pip uses its architecture-specific PEP 514 registration instead of an arbitrary `python` on PATH |
| .NET SDKs 8/9 | Retained for compatibility; .NET 10 LTS added. **Both 8 and 9 reach end of support in November 2026** |
| NVM / `nvm install lts` | Native-capable `OpenJS.NodeJS.LTS`, as requested; Node version management is no longer installed. Remove an existing NVM symlink/PATH setup before switching |
| GnuWin32.Grep | ripgrep (`rg`); command names/options are not identical |
| Separate cURL | Omitted; use Windows `curl.exe` |
| Azure Data Studio | VS Code + `ms-mssql.mssql`, installed by `-devTools` and included in the full extension list |
| Azure Data CLI (`azdata`) | Omitted; its SQL Server Big Data Clusters workload is retired |
| AzureAD module | Microsoft.Graph |
| Robo 3T | MongoDB Compass (currently x64 fallback) |
| IntelliJ Community | Unified `JetBrains.IntelliJIDEA`; free functionality is available in that distribution |
| npm `moment`, `bower`, `swagger-tools` | Omitted; `autorest` and `vsts-npm-auth` retained |
| Chocolatey | Omitted under the no-x86 policy; no remaining setup step requires it |
| Standalone Git LFS | Omitted under the no-x86 policy; current Git for Windows includes Git LFS |
| Standalone NuGet | Omitted under the no-x86 policy; use `dotnet nuget` for SDK workflows |
| NSwagStudio, OpenShift `oc`, ARMClient | Current WinGet entries are x86-marked, so omitted under the no-x86 policy. This is installer metadata, not necessarily the actual payload CPU architecture. ARMClient means Azure Resource Manager, not an ARM CPU tool; use `az rest` / `Invoke-AzRestMethod` for ARM API requests |
| DEVCOM.JMeter | No applicable ARM64/x64 installer in the checked catalog; omitted. For JMeter, use the upstream Java distribution with a compatible JDK rather than assuming this MSI is native |
| Unresolved Store apps | Omitted as listed above |

Also corrected the package IDs for Storage Explorer, Functions Core Tools,
Sysinternals Suite, Power BI, ILSpy, and other former display-name installs.

Lifecycle references:
[Azure Data Studio retirement, February 28, 2026](https://learn.microsoft.com/sql/tools/whats-happening-azure-data-studio),
[Big Data Clusters retirement](https://learn.microsoft.com/previous-versions/sql/big-data-cluster/big-data-cluster-overview?view=sql-server-ver15),
[AzureAD migration](https://learn.microsoft.com/powershell/microsoftgraph/migration-steps),
[.NET support dates](https://learn.microsoft.com/lifecycle/products/microsoft-net-and-net-core).

## Validation without installing software

```powershell
.\deploy\devops\Test-PowerShellSyntax.ps1 -relativePath Install-WindowsMachine.ps1
.\deploy\devops\Test-WindowsMachineInstall.ps1
```

The second script loads only declarations through the PowerShell AST and uses
mocks. It checks architecture selection, fallback/error handling, Store behavior,
and package-group dispatch without running installers or changing the machine.
