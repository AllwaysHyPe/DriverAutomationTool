<#
	===========================================================================
	 Created on:   	2025-03-12
	 Created by:   	MSEndpointMgr
	 Filename:     	Invoke-DATWin1125H2.ps1
	-------------------------------------------------------------------------
	 Script Name:  	Invoke-DATWin1125H2.ps1
	 Purpose:      	PowerShell wrapper to download and package Windows 11 25H2
	                drivers using the DriverAutomationToolCore module directly,
	                bypassing the EXE (which does not expose Windows 11 25H2 in
	                its UI dropdown).

	                PRIMARY USE CASE: Lenovo
	                This wrapper is designed to create a Lenovo Windows 11 25H2
	                driver package inside Configuration Manager so the
	                Invoke-CMApplyDriverPackage.ps1 task sequence script can
	                detect and apply it during OS deployment.

	 Two-step workflow
	 -----------------
	 STEP 1 – Run this script (on your ConfigMgr/packaging machine) to:
	           a) Download Lenovo drivers for Windows 11 25H2 from the Lenovo
	              catalog
	           b) Extract and wrap them into a WIM driver package
	           c) Optionally create a ConfigMgr Standard Package and distribute it

	 STEP 2 – In your ConfigMgr task sequence, call Invoke-CMApplyDriverPackage.ps1
	           with -BareMetal -TargetOSVersion 25H2, e.g.:
	             .\Invoke-CMApplyDriverPackage.ps1 -BareMetal `
	               -Endpoint "CM01.contoso.com" -TargetOSVersion "25H2"

	 Prerequisites
	 -------------
	 1. Copy the DriverAutomationToolCore module folder to a valid PSModulePath
	    location, e.g. C:\Program Files\WindowsPowerShell\Modules\DriverAutomationToolCore
	 2. Run as Administrator
	 3. For ConfigMgr packaging: the ConfigMgr admin console must be installed on
	    this machine and SMS_ADMIN_UI_PATH environment variable must be set.

	 Usage Examples
	 --------------
	 # List available Lenovo models for Windows 11 25H2 x64 (no download):
	 .\Invoke-DATWin1125H2.ps1 -Model "ThinkPad T14 Gen 5" `
	     -DownloadPath "C:\Drivers\Temp" -PackagePath "C:\Drivers\Packages" `
	     -ListModels

	 # Download only (no ConfigMgr package):
	 .\Invoke-DATWin1125H2.ps1 -Model "ThinkPad T14 Gen 5" `
	     -DownloadPath "C:\Drivers\Temp" -PackagePath "C:\Drivers\Packages"

	 # Download and create a ConfigMgr package:
	 .\Invoke-DATWin1125H2.ps1 -Model "ThinkPad T14 Gen 5" `
	     -DownloadPath "C:\Drivers\Temp" -PackagePath "C:\Drivers\Packages" `
	     -CreateConfigMgrPackage `
	     -SiteServer "CM01.contoso.com" -SiteCode "PS1"
	===========================================================================
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param
(
	[Parameter(Mandatory = $false, HelpMessage = "Lenovo model name as it appears in the Lenovo driver catalog, e.g. 'ThinkPad T14 Gen 5'. Use -ListModels to see available names.")]
	[string]$Model,

	[Parameter(Mandatory = $false, HelpMessage = "Target OS version string as it appears in the Lenovo catalog, e.g. 'Windows 11 25H2'. Defaults to 'Windows 11 25H2'. No version list is hardcoded; pass any value the catalog supports.")]
	[ValidateNotNullOrEmpty()]
	[string]$OS = "Windows 11 25H2",

	[Parameter(Mandatory = $false, HelpMessage = "Target architecture. Defaults to x64.")]
	[ValidateSet('x64', 'x86', 'Arm64')]
	[string]$Architecture = "x64",

	[Parameter(Mandatory = $true, HelpMessage = "Root path for temporary downloads and extraction work.")]
	[string]$DownloadPath,

	[Parameter(Mandatory = $true, HelpMessage = "Root path where final packaged driver WIM files will be stored.")]
	[string]$PackagePath,

	[Parameter(Mandatory = $false, HelpMessage = "Switch: create a ConfigMgr Standard Package after packaging drivers. Requires -SiteServer and -SiteCode.")]
	[switch]$CreateConfigMgrPackage,

	[Parameter(Mandatory = $false, HelpMessage = "ConfigMgr site server FQDN. Required with -CreateConfigMgrPackage.")]
	[string]$SiteServer,

	[Parameter(Mandatory = $false, HelpMessage = "ConfigMgr site code. Required with -CreateConfigMgrPackage.")]
	[string]$SiteCode,

	[Parameter(Mandatory = $false, HelpMessage = "Comma-separated distribution point FQDN(s) to distribute the package to.")]
	[string]$DistributionPoints,

	[Parameter(Mandatory = $false, HelpMessage = "Comma-separated distribution point group name(s) to distribute the package to.")]
	[string]$DistributionPointGroups,

	[Parameter(Mandatory = $false, HelpMessage = "Switch: list available Lenovo models for the chosen OS / Architecture and exit without downloading.")]
	[switch]$ListModels
)

#Requires -RunAsAdministrator

# ---------------------------------------------------------------------------
# Parameter validation
# ---------------------------------------------------------------------------
if ($CreateConfigMgrPackage) {
	if ([string]::IsNullOrEmpty($SiteServer)) {
		throw "Parameter -SiteServer is required when -CreateConfigMgrPackage is specified."
	}
	if ([string]::IsNullOrEmpty($SiteCode)) {
		throw "Parameter -SiteCode is required when -CreateConfigMgrPackage is specified."
	}
}

if (-not $ListModels -and [string]::IsNullOrEmpty($Model)) {
	throw "Parameter -Model is required. Use -ListModels to enumerate available Lenovo model names for $OS $Architecture."
}

# ---------------------------------------------------------------------------
# Import DriverAutomationToolCore module
# ---------------------------------------------------------------------------
Write-Host "[Init] Importing DriverAutomationToolCore module..." -ForegroundColor Cyan
try {
	Import-Module -Name DriverAutomationToolCore -ErrorAction Stop -Verbose:$false
} catch {
	Write-Error "Failed to import DriverAutomationToolCore. Ensure the module folder is in a valid PSModulePath location (e.g. C:\Program Files\WindowsPowerShell\Modules\DriverAutomationToolCore). Error: $($_.Exception.Message)"
	exit 1
}

# ---------------------------------------------------------------------------
# Ensure required directories exist
# ---------------------------------------------------------------------------
foreach ($Dir in @($DownloadPath, $PackagePath)) {
	if (-not (Test-Path -Path $Dir)) {
		Write-Host "[Init] Creating directory: $Dir" -ForegroundColor Cyan
		New-Item -Path $Dir -ItemType Directory -Force | Out-Null
	}
}

# ---------------------------------------------------------------------------
# Write run-time settings to the registry (consumed by module functions)
# ---------------------------------------------------------------------------
Write-Host "[Init] Writing configuration to registry at $global:RegPath" -ForegroundColor Cyan

Set-DATRegistryValue -Name "OS"                   -Type String -Value $OS
Set-DATRegistryValue -Name "Architecture"          -Type String -Value $Architecture
Set-DATRegistryValue -Name "PackageType"           -Type String -Value "Drivers"
Set-DATRegistryValue -Name "TempStoragePath"       -Type String -Value $DownloadPath
Set-DATRegistryValue -Name "PackageStoragePath"    -Type String -Value $PackagePath
Set-DATRegistryValue -Name "RunningState"          -Type String -Value "Idle"
Set-DATRegistryValue -Name "RunningMode"           -Type String -Value "Idle"
Set-DATRegistryValue -Name "Platform"              -Type String -Value $(if ($CreateConfigMgrPackage) { "Configuration Manager" } else { "Download Only" })

if (-not [string]::IsNullOrEmpty($SiteServer))             { Set-DATRegistryValue -Name "SiteServer"                    -Type String -Value $SiteServer }
if (-not [string]::IsNullOrEmpty($SiteCode))               { Set-DATRegistryValue -Name "SiteCode"                      -Type String -Value $SiteCode }
if (-not [string]::IsNullOrEmpty($DistributionPoints))     { Set-DATRegistryValue -Name "SelectedDistributionPoints"     -Type String -Value $DistributionPoints }
if (-not [string]::IsNullOrEmpty($DistributionPointGroups)){ Set-DATRegistryValue -Name "SelectedDistributionPointGroups" -Type String -Value $DistributionPointGroups }

# ---------------------------------------------------------------------------
# Query Lenovo model catalog
# ---------------------------------------------------------------------------
Write-Host "[Catalog] Querying Lenovo model catalog for $OS $Architecture..." -ForegroundColor Cyan
$SupportedModels = Get-DATOEMModelInfo -RequiredOEMs Lenovo -OS $OS -Architecture $Architecture

if ($null -eq $SupportedModels -or $SupportedModels.Count -eq 0) {
	Write-Warning "No Lenovo models found in the catalog for $OS $Architecture. The Lenovo catalog may not yet publish $OS driver packages."
	exit 0
}

if ($ListModels) {
	Write-Host "`n[Model List] Available Lenovo models for $OS $Architecture:`n" -ForegroundColor Green
	$SupportedModels | Sort-Object Model | Select-Object Model, Baseboards | Format-Table -AutoSize
	exit 0
}

# ---------------------------------------------------------------------------
# Locate the requested model in the catalog
# ---------------------------------------------------------------------------
$TargetEntry = $SupportedModels | Where-Object { $_.Model -eq $Model } | Select-Object -First 1

if ($null -eq $TargetEntry) {
	Write-Warning "Model '$Model' was not found in the Lenovo catalog for $OS $Architecture."
	Write-Host "Use -ListModels to see all available models." -ForegroundColor Yellow
	exit 1
}

$ResolvedModel      = $TargetEntry.Model
$ResolvedBaseboards = $TargetEntry.Baseboards

Write-Host "[Model] Model      : $ResolvedModel"      -ForegroundColor Green
Write-Host "[Model] Baseboards : $ResolvedBaseboards"  -ForegroundColor Green

Set-DATRegistryValue -Name "CurrentOEM"        -Type String -Value "Lenovo"
Set-DATRegistryValue -Name "CurrentModel"      -Type String -Value $ResolvedModel
Set-DATRegistryValue -Name "CurrentBaseboards" -Type String -Value $ResolvedBaseboards

# ---------------------------------------------------------------------------
# Resolve download URL from Lenovo catalog
# ---------------------------------------------------------------------------
Write-Host "[Download] Resolving Lenovo driver download URL for $ResolvedModel ($OS $Architecture)..." -ForegroundColor Cyan
$DownloadURL = Get-DATOEMDownloadLinks -OEM Lenovo -OS $OS -Architecture $Architecture -DownloadType driver -Model $ResolvedModel

if ([string]::IsNullOrEmpty($DownloadURL) -or $DownloadURL -eq "Unknown") {
	Write-Error "Could not resolve a download URL for Lenovo '$ResolvedModel' ($OS $Architecture). The Lenovo catalog may not yet list a driver package for $OS."
	exit 1
}

Write-Host "[Download] URL : $DownloadURL" -ForegroundColor Green
Set-DATRegistryValue -Name "DownloadURL" -Type String -Value $DownloadURL

# ---------------------------------------------------------------------------
# Download driver package
# ---------------------------------------------------------------------------
$DriverDownloadPath = Join-Path -Path $DownloadPath -ChildPath "Lenovo\$ResolvedModel\$OS"
if (-not (Test-Path -Path $DriverDownloadPath)) {
	New-Item -Path $DriverDownloadPath -ItemType Directory -Force | Out-Null
}

if ($PSCmdlet.ShouldProcess($DownloadURL, "Download Lenovo driver package")) {
	Write-Host "[Download] Downloading to $DriverDownloadPath ..." -ForegroundColor Cyan
	Invoke-DATContentDownload -DownloadURL $DownloadURL -DownloadDestination $DriverDownloadPath

	# Wait for the background download job to complete
	if ($global:DownloadBackgroundJobID) {
		Write-Host "[Download] Waiting for download to complete..." -ForegroundColor Cyan
		while ((Get-Job -Id $global:DownloadBackgroundJobID -ErrorAction SilentlyContinue).State -eq "Running") {
			Start-Sleep -Seconds 5
			Write-Host "." -NoNewline
		}
		Write-Host ""
	}
}

# Locate the downloaded file
$DriverFile = Get-ChildItem -Path $DriverDownloadPath -File -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $DriverFile) {
	Write-Error "Download appears to have failed - no files found in $DriverDownloadPath."
	exit 1
}

Write-Host "[Download] File: $($DriverFile.FullName)" -ForegroundColor Green
Set-DATRegistryValue -Name "WorkingFile"   -Type String -Value $DriverFile.FullName
Set-DATRegistryValue -Name "RunningMode"   -Type String -Value "Download Completed"

# ---------------------------------------------------------------------------
# Extract and package drivers into a WIM file
# ---------------------------------------------------------------------------
$PackageVersion  = (Get-Date).ToString("yyyyMMdd")
$ExtractBasePath = Join-Path -Path $DownloadPath -ChildPath $PackageVersion
Set-DATRegistryValue -Name "PackageVersion" -Type String -Value $PackageVersion

if ($PSCmdlet.ShouldProcess($DriverFile.FullName, "Extract and package Lenovo driver files into WIM")) {
	Write-Host "[Package] Extracting and packaging into WIM at $ExtractBasePath ..." -ForegroundColor Cyan
	Invoke-DATDriverFilePackaging -FilePath $DriverFile.FullName -OEM Lenovo -Model $ResolvedModel -Destination $ExtractBasePath -OS $OS
}

# ---------------------------------------------------------------------------
# ConfigMgr package creation (optional)
# ---------------------------------------------------------------------------
if ($CreateConfigMgrPackage) {
	$RunningConfigurationValues = Get-ItemProperty -Path $global:RegPath
	$RunningMode    = ($RunningConfigurationValues).RunningMode
	$PackagedDriver = ($RunningConfigurationValues).PackagedDriverPath

	if ($RunningMode -eq "Extract Ready" -and -not ([string]::IsNullOrEmpty($PackagedDriver))) {
		if ($PSCmdlet.ShouldProcess($ResolvedModel, "Create ConfigMgr driver package")) {
			Write-Host "[ConfigMgr] Creating package for Lenovo $ResolvedModel ($OS $Architecture)..." -ForegroundColor Cyan
			Create-DATConfigMgrPkg `
				-DriverPackage $PackagedDriver `
				-OEM           Lenovo `
				-Model         $ResolvedModel `
				-Baseboards    $ResolvedBaseboards `
				-OS            $OS `
				-Architecture  $Architecture `
				-PackagePath   $PackagePath `
				-SiteServer    $SiteServer `
				-SiteCode      $SiteCode `
				-Version       $PackageVersion
		}
	} else {
		Write-Warning "Packaging did not reach 'Extract Ready' state (current: $RunningMode). ConfigMgr package was not created. Review the log at $global:LogDirectory\$global:ProductName.log."
	}
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " Driver Automation Tool - Lenovo Windows 11 25H2 Wrapper"         -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " OEM          : Lenovo"
Write-Host " Model        : $ResolvedModel"
Write-Host " Baseboards   : $ResolvedBaseboards"
Write-Host " OS           : $OS"
Write-Host " Architecture : $Architecture"
Write-Host " Log file     : $global:LogDirectory\$global:ProductName.log"
Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host " Task Sequence usage (Invoke-CMApplyDriverPackage.ps1):"
Write-Host "   -BareMetal -Endpoint `"$SiteServer`" -TargetOSVersion `"25H2`""
Write-Host "================================================================" -ForegroundColor Cyan
$FinalState = (Get-ItemProperty -Path $global:RegPath -ErrorAction SilentlyContinue).RunningState
Write-Host " Final state  : $FinalState" -ForegroundColor $(if ($FinalState -eq "Error") { "Red" } else { "Green" })
Write-Host "================================================================" -ForegroundColor Cyan
