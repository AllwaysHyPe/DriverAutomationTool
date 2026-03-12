# Driver Automation Tool 8.0.0 – Prerequisites & Essential Files

This document explains exactly what you need to run the Driver Automation Tool 8.0.0,
which files are required and what each one does, and how to get up and running quickly.

---

## Table of Contents

1. [Essential Files](#essential-files)
2. [Software Prerequisites](#software-prerequisites)
3. [Installation – EXE Path (GUI)](#installation--exe-path-gui)
4. [Installation – PowerShell Wrapper Path (Lenovo / CLI)](#installation--powershell-wrapper-path-lenovo--cli)
5. [Network & Firewall Requirements](#network--firewall-requirements)
6. [Permissions Requirements](#permissions-requirements)
7. [Registry Layout](#registry-layout)
8. [Quick-Start Usage](#quick-start-usage)

---

## Essential Files

### Core module — required for **all** usage paths

| File | Where it must live | What it does |
|------|-------------------|--------------|
| `DriverAutomationToolCore\10.0.18.0\DriverAutomationToolCore.psm1` | `C:\Program Files\WindowsPowerShell\Modules\DriverAutomationToolCore\10.0.18.0\` | The core PowerShell module. Contains every function the tool relies on: catalog downloads, driver downloads via CURL, packaging into WIM, ConfigMgr package creation, etc. **Nothing works without this.** |
| `DriverAutomationToolCore\10.0.18.0\DriverAutomationToolCore.psd1` | Same folder as the `.psm1` | Module manifest. Declares the module version (`1.0.18.0`), minimum PowerShell version (`5.1`), minimum .NET version (`4.5.2`), and exports. PowerShell reads this first when you `Import-Module DriverAutomationToolCore`. |

> **Folder name matters.** PowerShell module auto-discovery requires the parent folder to be named
> `DriverAutomationToolCore` and the version subfolder to be named `10.0.18.0`.
> The full expected path is:
> ```
> C:\Program Files\WindowsPowerShell\Modules\
>   DriverAutomationToolCore\
>     10.0.18.0\
>       DriverAutomationToolCore.psd1
>       DriverAutomationToolCore.psm1
> ```

---

### EXE / GUI path — additional required files

| File | Suggested location | What it does |
|------|--------------------|--------------|
| `DriverAutomationTool.exe` | `C:\Program Files\MSEndpointMgr\Driver Automation Tool\` | The graphical front-end. Reads the registry for configuration and calls into the core module via background jobs. |
| `DriverAutomationTool.msi` | Distribution source | Installer that places the EXE, sets the registry `InstallDirectory` key, and installs CURL into the `Tools` subfolder automatically. **Preferred installation method.** |
| `Tools\curl.exe` | `<InstallDirectory>\Tools\` | CURL is the primary download engine used by `Invoke-DATContentDownload`. The MSI installs this automatically. For manual installs, download the Windows 64-bit binary from [https://curl.se/windows/](https://curl.se/windows/) and place `curl.exe` anywhere inside the `Tools` subfolder. |

---

### PowerShell wrapper path — additional required file

| File | Where to run it from | What it does |
|------|----------------------|--------------|
| `Invoke-DATWin1125H2.ps1` | Any folder (run as Administrator) | Standalone wrapper that bypasses the EXE entirely. Calls the core module directly to download and package Lenovo drivers for any Windows 11 version (defaults to 25H2). Use this when the EXE UI does not expose the OS version you need. |

---

### Task sequence apply script — required for ConfigMgr OSD

| File | Where to place it | What it does |
|------|-------------------|--------------|
| `Content\Invoke-CMApplyDriverPackage.ps1` | A ConfigMgr Standard Package (deployed to clients via OSD task sequence) | Runs inside the task sequence to query the ConfigMgr AdminService, find the matching driver package for the current hardware, download it, and apply it with DISM. This script is **not** used during package creation — only during OS deployment. |

---

### Optional / supporting files

| File | What it does |
|------|--------------|
| `Content\DriverAutomationTool-UserGuide.pdf` | Full user guide PDF |
| `Content\Import-Models.csv` | Sample CSV for bulk model import via the EXE UI |
| `Content\Run-DriverAutomationToolSvc.ps1` | Wrapper for running the tool as a scheduled background service |
| `Data\OEMLinks.xml` | Local fallback copy of the OEM catalog URL list. The module downloads the live version from GitHub automatically; this file is only used if GitHub is unreachable. |

---

## Software Prerequisites

### Operating System

- **Windows 10 or Windows 11** (64-bit)
- Must be a machine where you have local administrator rights
- The tool creates files under `C:\Program Files\MSEndpointMgr\Driver Automation Tool\` by default

### PowerShell

| Requirement | Minimum version |
|-------------|----------------|
| Windows PowerShell | **5.1** (built into Windows 10 / 11) |
| .NET Framework | **4.5.2** (the `.psd1` declares this requirement) |

> PowerShell 7+ (Core) is **not** supported. The module and EXE require Windows PowerShell 5.1.

### CURL

- Required by `Invoke-DATContentDownload` (the download engine in the core module)
- **MSI installation**: CURL is bundled and installed automatically into `<InstallDirectory>\Tools\`
- **Manual installation**: Download the Windows x64 binary from [https://curl.se/windows/](https://curl.se/windows/), extract, and place `curl.exe` inside `<InstallDirectory>\Tools\` (or any subfolder of `Tools\`)
- The module searches `$global:ToolsDirectory` (i.e., `<InstallDirectory>\Tools\`) recursively for `Curl.exe`

### DISM

- **Built into Windows** — no separate install required
- Used by `Invoke-DATDriverFilePackaging` to capture extracted drivers into a `.wim` file
- Must be accessible as `dism.exe` on the system PATH (standard Windows location: `C:\Windows\System32\`)

### Configuration Manager Console (for ConfigMgr packaging)

- Required **only** when creating ConfigMgr packages or distributing to distribution points
- The ConfigMgr PowerShell module (`ConfigurationManager.psd1`) is part of the console install
- The `SMS_ADMIN_UI_PATH` environment variable must be set (the console installer does this automatically)
- The account running the tool must have at minimum **Full Administrator** or a custom ConfigMgr role with rights to create and distribute packages

### HP CMSL (HP Client Management Script Library) — HP only

- Required **only** when downloading HP driver packages
- Install with:
  ```powershell
  Install-Module -Name HPCMSL -Force -AcceptLicense
  ```
- The module is imported automatically when HP is selected as the OEM

---

## Installation – EXE Path (GUI)

This is the recommended installation method.

### Option A: MSI installer (recommended)

1. Download `DriverAutomationTool.msi` from this repository (`Current Branch/8.0.0/`)
2. Run the MSI as Administrator — it will:
   - Install the EXE to `C:\Program Files\MSEndpointMgr\Driver Automation Tool\`
   - Install CURL to `<InstallDirectory>\Tools\`
   - Set `HKLM:\SOFTWARE\MSEndpointMgr\DriverAutomationTool\InstallDirectory`
3. Copy the `DriverAutomationToolCore` module folder to the PowerShell modules path:
   ```
   Copy-Item -Path ".\DriverAutomationToolCore" `
             -Destination "C:\Program Files\WindowsPowerShell\Modules\DriverAutomationToolCore" `
             -Recurse
   ```
4. Launch `DriverAutomationTool.exe`

### Option B: Manual installation

1. Create the install folder:
   ```
   C:\Program Files\MSEndpointMgr\Driver Automation Tool\
   ```
2. Copy `DriverAutomationTool.exe` into that folder
3. Create a `Tools` subfolder and place `curl.exe` inside it:
   ```
   C:\Program Files\MSEndpointMgr\Driver Automation Tool\Tools\curl.exe
   ```
4. Copy the module:
   ```
   C:\Program Files\WindowsPowerShell\Modules\DriverAutomationToolCore\10.0.18.0\
     DriverAutomationToolCore.psd1
     DriverAutomationToolCore.psm1
   ```
5. Run `DriverAutomationTool.exe` as Administrator

---

## Installation – PowerShell Wrapper Path (Lenovo / CLI)

Use this path when you need to package Lenovo drivers for an OS version not exposed in the
EXE UI (e.g., Windows 11 25H2), or when you prefer a fully scriptable / headless workflow.

1. Install the module (same as step 3/4 in Option B above)
2. Optionally place `curl.exe` under `C:\Program Files\MSEndpointMgr\Driver Automation Tool\Tools\`
   (the module will fall back to `Invoke-WebRequest` if CURL is not found, but CURL is preferred)
3. Place `Invoke-DATWin1125H2.ps1` anywhere convenient
4. Run from an **elevated** PowerShell 5.1 session:

```powershell
# List available Lenovo models (no download)
.\Invoke-DATWin1125H2.ps1 `
    -DownloadPath "C:\Drivers\Temp" `
    -PackagePath  "C:\Drivers\Packages" `
    -ListModels

# Download and package drivers (no ConfigMgr package)
.\Invoke-DATWin1125H2.ps1 `
    -Model        "ThinkPad T14 Gen 5" `
    -DownloadPath "C:\Drivers\Temp" `
    -PackagePath  "C:\Drivers\Packages"

# Download, package, AND create a ConfigMgr package
.\Invoke-DATWin1125H2.ps1 `
    -Model        "ThinkPad T14 Gen 5" `
    -DownloadPath "C:\Drivers\Temp" `
    -PackagePath  "C:\Drivers\Packages" `
    -CreateConfigMgrPackage `
    -SiteServer   "CM01.contoso.com" `
    -SiteCode     "PS1"

# Use a future OS version with no code changes needed
.\Invoke-DATWin1125H2.ps1 `
    -Model        "ThinkPad T14 Gen 5" `
    -OS           "Windows 11 26H2" `
    -DownloadPath "C:\Drivers\Temp" `
    -PackagePath  "C:\Drivers\Packages"
```

---

## Network & Firewall Requirements

The module makes outbound HTTPS (port 443) calls to the following hosts:

| Host | Purpose |
|------|---------|
| `raw.githubusercontent.com` | Fetch the current OEM catalog (`OEMLinks.xml`), version check (`DriverAutomationToolRev.txt`), and release notes |
| `downloads.dell.com` / `downloads.dell.com` | Dell driver catalog cabinet and driver packages |
| `ftp.hp.com` / `hpia.hpcloud.hp.com` | HP driver catalog and SoftPaq packages |
| `download.lenovo.com` / `pcsupport.lenovo.com` | Lenovo driver catalog XML and driver packages |
| `dl.dell.com` | Dell BIOS utilities |
| `microsoft.com` / `download.microsoft.com` | Microsoft Surface driver packages |
| `dl.google.com` / OEM CDNs | Various OEM package CDNs depending on model |

> All downloads use TLS 1.2. The module sets `[Net.ServicePointManager]::SecurityProtocol = Tls12` on load.

---

## Permissions Requirements

| Context | Required permissions |
|---------|----------------------|
| Running the EXE or wrapper script | **Local Administrator** on the packaging machine |
| Writing to `C:\Program Files\MSEndpointMgr\` | Local Administrator (for `Temp`, `Logs`, `Settings` subfolders) |
| Writing to `HKLM:\SOFTWARE\MSEndpointMgr\DriverAutomationTool` | Local Administrator |
| Creating ConfigMgr packages | ConfigMgr role with **Create Package**, **Modify Package**, **Distribute Content** rights (or Full Administrator) |
| Distributing to Distribution Points | ConfigMgr **Distribute Content** right on the target DPs/DPGs |
| Running `dism.exe /Capture-Image` | Local Administrator |

---

## Registry Layout

All configuration and run-time state is stored under:

```
HKLM:\SOFTWARE\MSEndpointMgr\DriverAutomationTool\
```

Key values written and read by the module:

| Value name | Type | Purpose |
|-----------|------|---------|
| `InstallDirectory` | String | Root folder for Temp, Logs, Settings, Tools |
| `TempStoragePath` | String | Where driver packages are downloaded |
| `PackageStoragePath` | String | Where packaged WIM files are written |
| `OS` | String | Target OS version (e.g., `Windows 11 25H2`) |
| `Architecture` | String | Target architecture (e.g., `x64`) |
| `Platform` | String | Deployment platform (`Configuration Manager`, `Download Only`) |
| `SiteServer` | String | ConfigMgr site server FQDN |
| `SiteCode` | String | ConfigMgr site code |
| `CurrentOEM` | String | OEM being processed (e.g., `Lenovo`) |
| `CurrentModel` | String | Model being processed |
| `CurrentBaseboards` | String | Comma-separated baseboard/SKU values |
| `DownloadURL` | String | Last resolved driver download URL |
| `WorkingFile` | String | Path to the downloaded driver file |
| `RunningState` | String | `Idle` / `Running` / `Completed` / `Error` |
| `RunningMode` | String | Current pipeline stage (e.g., `Download Completed`, `Extract Ready`) |
| `RunningMessage` | String | Latest status message (mirrored in log) |
| `PackagedDriverPath` | String | Path to the created `.wim` file |
| `PackageVersion` | String | Date stamp of the package (yyyyMMdd) |
| `RunningVersion` | String | Currently loaded module version |

The registry is also used to pass state between the EXE's background jobs. Exporting and
importing these settings via the EXE UI (or `Export-DATRegistry` / `Import-DATRegistry`) lets
you replicate a configuration across machines.

---

## Quick-Start Usage

### EXE (GUI)

1. Launch `DriverAutomationTool.exe` as Administrator
2. Go to **Configuration Manager Environment** — enter your site server FQDN and click Connect
3. Go to **Package Settings** — select OEM, OS, Architecture, and storage paths
4. Go to **Package Management** — search for and select your models
5. Click **Start** — the tool downloads, extracts, packages, and (optionally) distributes to ConfigMgr

### Task Sequence (applying drivers during OSD)

Place `Invoke-CMApplyDriverPackage.ps1` in a ConfigMgr package and call it from a
**Run PowerShell Script** step in your task sequence:

```powershell
# Bare-metal OSD with Windows 11 25H2 drivers
.\Invoke-CMApplyDriverPackage.ps1 `
    -BareMetal `
    -Endpoint      "CM01.contoso.com" `
    -TargetOSVersion "25H2"

# Driver update on a running OS
.\Invoke-CMApplyDriverPackage.ps1 `
    -DriverUpdate `
    -Endpoint      "CM01.contoso.com"

# OS in-place upgrade
.\Invoke-CMApplyDriverPackage.ps1 `
    -OSUpgrade `
    -Endpoint        "CM01.contoso.com" `
    -TargetOSVersion "25H2"
```

> `$TargetOSVersion` accepts any version string the Lenovo (or other OEM) catalog supports —
> no code changes are needed when new Windows versions ship.
