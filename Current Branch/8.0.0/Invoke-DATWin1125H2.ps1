<#
	===========================================================================
	 Created on:   	2025-03-12
	 Created by:   	MSEndpointMgr
	 Filename:     	Invoke-DATWin1125H2.ps1
	-------------------------------------------------------------------------
	 Script Name:  	Invoke-DATWin1125H2.ps1
	 Purpose:      	PowerShell wrapper to download and package Windows 11 25H2
	                drivers using the DriverAutomationToolCore module.

	                The DriverAutomationTool 8.0.0 EXE does not expose Windows 11
	                25H2 in its UI, but the underlying module fully supports it.
	                This wrapper lets you invoke the module directly to download
	                and package Windows 11 25H2 drivers without the EXE.

	 Prerequisites:
	                1. Copy the DriverAutomationToolCore module folder to
	                   C:\Program Files\WindowsPowerShell\Modules
	                   (i.e. the folder at
	                   DriverAutomationToolCore\10.0.18.0\ must be present
	                   inside a parent folder named DriverAutomationToolCore)
	                2. Run as administrator
	                3. HP only: HP CMSL (HP Client Management Script Library)
	                   must be installed. Install with:
	                     Install-Module -Name HPCMSL -Force -AcceptLicense
	                4. For Configuration Manager packaging, the ConfigMgr
	                   admin console must be installed on this machine.

	 Usage Examples:
	                # Download-only for a Dell model:
	                .\Invoke-DATWin1125H2.ps1 -OEM Dell -Model "Latitude 5540" `
	                    -DownloadPath "C:\Drivers\Temp" `
	                    -PackagePath  "C:\Drivers\Packages" `
	                    -Platform "Download Only"

	                # Download and create a ConfigMgr package for an HP model:
	                .\Invoke-DATWin1125H2.ps1 -OEM HP -SystemSKU "8870" `
	                    -DownloadPath "C:\Drivers\Temp" `
	                    -PackagePath  "C:\Drivers\Packages" `
	                    -Platform "Configuration Manager" `
	                    -SiteServer "cm01.contoso.com" -SiteCode "PS1"

	                # List available models for Lenovo without downloading:
	                .\Invoke-DATWin1125H2.ps1 -OEM Lenovo `
	                    -DownloadPath "C:\Drivers\Temp" `
	                    -PackagePath  "C:\Drivers\Packages" `
	                    -Platform "Download Only" `
	                    -ListModels
	===========================================================================
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param
(
	[Parameter(Mandatory = $true, HelpMessage = "OEM manufacturer to target.")]
	[ValidateSet('HP', 'Dell', 'Lenovo', 'Microsoft', 'Acer')]
	[string]$OEM,

	[Parameter(Mandatory = $false, HelpMessage = "Model name (as it appears in the OEM catalog). Not required when -ListModels is specified.")]
	[string]$Model,

	[Parameter(Mandatory = $false, HelpMessage = "HP System SKU / platform ID (e.g. '8870'). Required for HP downloads.")]
	[string]$SystemSKU,

	[Parameter(Mandatory = $false, HelpMessage = "Target OS. Defaults to 'Windows 11 25H2'.")]
	[ValidateSet('Windows 11 25H2', 'Windows 11 24H2', 'Windows 11 23H2', 'Windows 11 22H2', 'Windows 11', 'Windows 10 22H2')]
	[string]$OS = "Windows 11 25H2",

	[Parameter(Mandatory = $false, HelpMessage = "Target architecture.")]
	[ValidateSet('x64', 'x86', 'Arm64')]
	[string]$Architecture = "x64",

	[Parameter(Mandatory = $true, HelpMessage = "Root path for temporary driver downloads and extraction.")]
	[string]$DownloadPath,

	[Parameter(Mandatory = $true, HelpMessage = "Root path for final packaged driver output.")]
	[string]$PackagePath,

	[Parameter(Mandatory = $false, HelpMessage = "Deployment platform.")]
	[ValidateSet('Configuration Manager', 'Download Only')]
	[string]$Platform = "Download Only",

	[Parameter(Mandatory = $false, HelpMessage = "Configuration Manager site server FQDN. Required when Platform is 'Configuration Manager'.")]
	[string]$SiteServer,

	[Parameter(Mandatory = $false, HelpMessage = "Configuration Manager site code. Required when Platform is 'Configuration Manager'.")]
	[string]$SiteCode,

	[Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of distribution point FQDN(s) to distribute the package to.")]
	[string]$DistributionPoints,

	[Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of distribution point group name(s) to distribute the package to.")]
	[string]$DistributionPointGroups,

	[Parameter(Mandatory = $false, HelpMessage = "List available models for the chosen OEM / OS / Architecture and exit without downloading.")]
	[switch]$ListModels
)

#Requires -RunAsAdministrator

# ---------------------------------------------------------------------------
# Validate parameters
# ---------------------------------------------------------------------------
if ($Platform -eq "Configuration Manager") {
	if ([string]::IsNullOrEmpty($SiteServer)) {
		throw "Parameter -SiteServer is required when -Platform is 'Configuration Manager'."
	}
	if ([string]::IsNullOrEmpty($SiteCode)) {
		throw "Parameter -SiteCode is required when -Platform is 'Configuration Manager'."
	}
}

if (-not $ListModels) {
	if ([string]::IsNullOrEmpty($Model) -and $OEM -ne "HP") {
		throw "Parameter -Model is required for OEM '$OEM'. Use -ListModels to enumerate available models."
	}
	if ($OEM -eq "HP" -and [string]::IsNullOrEmpty($SystemSKU) -and [string]::IsNullOrEmpty($Model)) {
		throw "Parameter -SystemSKU (or -Model) is required for OEM 'HP'."
	}
}

# ---------------------------------------------------------------------------
# Import module
# ---------------------------------------------------------------------------
Write-Host "[Init] Importing DriverAutomationToolCore module..." -ForegroundColor Cyan
try {
	Import-Module -Name DriverAutomationToolCore -ErrorAction Stop -Verbose:$false
} catch {
	Write-Error "Failed to import DriverAutomationToolCore module. Ensure the module is installed in a valid PSModulePath location (e.g. C:\Program Files\WindowsPowerShell\Modules\DriverAutomationToolCore). Error: $($_.Exception.Message)"
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
# Pre-populate registry values consumed by the module
# ---------------------------------------------------------------------------
Write-Host "[Init] Writing configuration to registry at $global:RegPath" -ForegroundColor Cyan

Set-DATRegistryValue -Name "OS"                   -Type String -Value $OS
Set-DATRegistryValue -Name "Architecture"          -Type String -Value $Architecture
Set-DATRegistryValue -Name "Platform"              -Type String -Value $Platform
Set-DATRegistryValue -Name "PackageType"           -Type String -Value "Drivers"
Set-DATRegistryValue -Name "TempStoragePath"       -Type String -Value $DownloadPath
Set-DATRegistryValue -Name "PackageStoragePath"    -Type String -Value $PackagePath
Set-DATRegistryValue -Name "RunningState"          -Type String -Value "Idle"
Set-DATRegistryValue -Name "RunningMode"           -Type String -Value "Idle"

if (-not [string]::IsNullOrEmpty($SiteServer)) {
	Set-DATRegistryValue -Name "SiteServer" -Type String -Value $SiteServer
}
if (-not [string]::IsNullOrEmpty($SiteCode)) {
	Set-DATRegistryValue -Name "SiteCode" -Type String -Value $SiteCode
}
if (-not [string]::IsNullOrEmpty($DistributionPoints)) {
	Set-DATRegistryValue -Name "SelectedDistributionPoints" -Type String -Value $DistributionPoints
}
if (-not [string]::IsNullOrEmpty($DistributionPointGroups)) {
	Set-DATRegistryValue -Name "SelectedDistributionPointGroups" -Type String -Value $DistributionPointGroups
}

# ---------------------------------------------------------------------------
# Retrieve OEM model catalog
# ---------------------------------------------------------------------------
Write-Host "[Model Lookup] Querying $OEM model catalog for $OS $Architecture..." -ForegroundColor Cyan
$SupportedModels = Get-DATOEMModelInfo -RequiredOEMs $OEM -OS $OS -Architecture $Architecture

if ($SupportedModels -eq $null -or $SupportedModels.Count -eq 0) {
	Write-Warning "No models found for OEM=$OEM, OS=$OS, Architecture=$Architecture. The OEM catalog may not yet contain $OS entries."
	exit 0
}

if ($ListModels) {
	Write-Host "`n[Model List] Available $OEM models for $OS $Architecture:`n" -ForegroundColor Green
	$SupportedModels | Sort-Object Model | Select-Object OEM, Model, Baseboards | Format-Table -AutoSize
	exit 0
}

# ---------------------------------------------------------------------------
# Resolve the target model from the catalog
# ---------------------------------------------------------------------------
$TargetModelEntry = $SupportedModels | Where-Object { $_.Model -eq $Model } | Select-Object -First 1

if ($TargetModelEntry -eq $null) {
	Write-Warning "Model '$Model' was not found in the $OEM catalog for $OS $Architecture."
	Write-Host "Available models:" -ForegroundColor Yellow
	$SupportedModels | Sort-Object Model | Select-Object Model | Format-Table -AutoSize
	exit 1
}

$ResolvedModel     = $TargetModelEntry.Model
$ResolvedBaseboards = $TargetModelEntry.Baseboards

Write-Host "[Model] Using model  : $ResolvedModel"    -ForegroundColor Green
Write-Host "[Model] Baseboards   : $ResolvedBaseboards" -ForegroundColor Green

# For HP, override the SystemSKU from the catalog entry when not supplied
if ($OEM -eq "HP" -and [string]::IsNullOrEmpty($SystemSKU)) {
	$SystemSKU = ($ResolvedBaseboards -split ",") | Select-Object -First 1
	Write-Host "[HP]   Using SystemSKU: $SystemSKU" -ForegroundColor Green
}

Set-DATRegistryValue -Name "CurrentOEM"       -Type String -Value $OEM
Set-DATRegistryValue -Name "CurrentModel"     -Type String -Value $ResolvedModel
Set-DATRegistryValue -Name "CurrentBaseboards" -Type String -Value $ResolvedBaseboards

# ---------------------------------------------------------------------------
# Define download destination
# ---------------------------------------------------------------------------
$DriverDownloadPath = Join-Path -Path $DownloadPath -ChildPath "$OEM\$ResolvedModel\$OS"

if (-not (Test-Path -Path $DriverDownloadPath)) {
	New-Item -Path $DriverDownloadPath -ItemType Directory -Force | Out-Null
}

# ---------------------------------------------------------------------------
# Download drivers
# ---------------------------------------------------------------------------
if ($OEM -ne "HP") {
	# ------------------------------------------------------------------
	# Non-HP OEMs: get a direct download URL then use the built-in
	# download function
	# ------------------------------------------------------------------
	Write-Host "[Download] Resolving download URL for $OEM $ResolvedModel ($OS $Architecture)..." -ForegroundColor Cyan
	$DownloadURL = Get-DATOEMDownloadLinks -OEM $OEM -OS $OS -Architecture $Architecture -DownloadType driver -Model $ResolvedModel

	if ([string]::IsNullOrEmpty($DownloadURL) -or $DownloadURL -eq "Unknown") {
		Write-Error "Could not resolve a download URL for $OEM '$ResolvedModel' ($OS $Architecture). The OEM catalog may not yet list a driver package for this OS version."
		exit 1
	}

	Write-Host "[Download] URL : $DownloadURL" -ForegroundColor Green
	Set-DATRegistryValue -Name "DownloadURL" -Type String -Value $DownloadURL

	if ($PSCmdlet.ShouldProcess($DownloadURL, "Download driver package")) {
		Write-Host "[Download] Downloading to $DriverDownloadPath ..." -ForegroundColor Cyan
		Invoke-DATContentDownload -DownloadURL $DownloadURL -DownloadDestination $DriverDownloadPath

		# Wait for download background job
		if ($global:DownloadBackgroundJobID) {
			while ((Get-Job -Id $global:DownloadBackgroundJobID -ErrorAction SilentlyContinue).State -eq "Running") {
				Start-Sleep -Seconds 5
				Write-Host "." -NoNewline
			}
			Write-Host ""
		}
	}

	# Locate the downloaded file
	$DriverFile = Get-ChildItem -Path $DriverDownloadPath -File -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
	if ($DriverFile -eq $null) {
		Write-Error "Download appears to have failed - no files found in $DriverDownloadPath."
		exit 1
	}

	Write-Host "[Download] Downloaded file: $($DriverFile.FullName)" -ForegroundColor Green
	Set-DATRegistryValue -Name "WorkingFile" -Type String -Value $DriverFile.FullName
	Set-DATRegistryValue -Name "RunningMode" -Type String -Value "Download Completed"

	# ------------------------------------------------------------------
	# Extract and package
	# ------------------------------------------------------------------
	$PackageVersion  = (Get-Date).ToString("yyyyMMdd")
	$ExtractBasePath = Join-Path -Path $DownloadPath -ChildPath $PackageVersion
	Set-DATRegistryValue -Name "PackageVersion" -Type String -Value $PackageVersion

	if ($PSCmdlet.ShouldProcess($DriverFile.FullName, "Extract and package driver files")) {
		Write-Host "[Package] Extracting and packaging drivers to $ExtractBasePath ..." -ForegroundColor Cyan
		Invoke-DATDriverFilePackaging -FilePath $DriverFile.FullName -OEM $OEM -Model $ResolvedModel -Destination $ExtractBasePath -OS $OS
	}

} else {
	# ------------------------------------------------------------------
	# HP: use HP CMSL via Invoke-DATOEMDownloadModule
	# ------------------------------------------------------------------
	$HPOSBuild   = $OS.Split(" ")[2]          # e.g. "25H2"
	$HPOSVersion = ($OS -split " ")[0..1] -join " " # e.g. "Windows 11"

	$SoftPaqTempPath = Join-Path -Path $DriverDownloadPath -ChildPath "SoftPaqs"
	if (-not (Test-Path -Path $SoftPaqTempPath)) {
		New-Item -Path $SoftPaqTempPath -ItemType Directory -Force | Out-Null
	}

	if ($PSCmdlet.ShouldProcess("HP SKU $SystemSKU", "Download HP driver package for $OS")) {
		Write-Host "[Download] Starting HP CMSL download for SKU $SystemSKU ($OS $Architecture)..." -ForegroundColor Cyan
		Invoke-DATOEMDownloadModule `
			-OEM          "HP" `
			-SystemSKU    $SystemSKU `
			-WindowsBuild $HPOSVersion `
			-WindowsVersion $HPOSBuild `
			-TempDirectory  $SoftPaqTempPath `
			-DownloadDestination $DriverDownloadPath
	}
}

# ---------------------------------------------------------------------------
# Configuration Manager package creation
# ---------------------------------------------------------------------------
if ($Platform -eq "Configuration Manager") {
	$RunningConfigurationValues = Get-ItemProperty -Path $global:RegPath
	$RunningMode    = ($RunningConfigurationValues).RunningMode
	$PackagedDriver = ($RunningConfigurationValues).PackagedDriverPath
	$PackageVersion = ($RunningConfigurationValues).PackageVersion

	if ($RunningMode -eq "Extract Ready" -and -not ([string]::IsNullOrEmpty($PackagedDriver))) {
		if ($PSCmdlet.ShouldProcess($ResolvedModel, "Create Configuration Manager driver package")) {
			Write-Host "[ConfigMgr] Creating driver package for $OEM $ResolvedModel ($OS $Architecture)..." -ForegroundColor Cyan
			Create-DATConfigMgrPkg `
				-DriverPackage $PackagedDriver `
				-OEM           $OEM `
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
		Write-Warning "Driver package is not in 'Extract Ready' state (current state: $RunningMode). Configuration Manager package will not be created. Check the log at $global:LogDirectory for details."
	}
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host " Driver Automation Tool - Windows 11 25H2 Wrapper" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host " OEM          : $OEM"
Write-Host " Model        : $ResolvedModel"
Write-Host " OS           : $OS"
Write-Host " Architecture : $Architecture"
Write-Host " Platform     : $Platform"
Write-Host " Log file     : $global:LogDirectory\$global:ProductName.log"
Write-Host "========================================================" -ForegroundColor Green
$FinalState = (Get-ItemProperty -Path $global:RegPath -ErrorAction SilentlyContinue).RunningState
Write-Host " Final state  : $FinalState" -ForegroundColor $(if ($FinalState -eq "Error") { "Red" } else { "Green" })
Write-Host "========================================================" -ForegroundColor Green
