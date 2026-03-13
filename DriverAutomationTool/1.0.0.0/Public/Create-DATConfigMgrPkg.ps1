function Create-DATConfigMgrPkg {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$DriverPackage,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$OEM,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Model,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$OS,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Architecture,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$Baseboards,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$PackagePath,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$SiteServer,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$SiteCode,
		[Parameter(Mandatory = $true)]
		[string]$Version
	)
	
	try {
		# Check for the Configuration Manager module, import if not already loaded, if missing log an error
		if (-not (Get-Module -Name ConfigurationManager)) {
			$ModuleName = (Get-Item $env:SMS_ADMIN_UI_PATH | Split-Path -Parent) + "\ConfigurationManager.psd1"
			
			# Test path to the Configuration Manager module, import if found
			if (Test-Path -Path $ModuleName) {
				Write-DATLogEntry -Value "- Loading ConfigMgr PowerShell module" -Severity 1
				Import-Module $ModuleName -Verbose
				$ConfigMgrModuleLoaded = $true
			} else {
				Write-DATLogEntry -Value "[Error] - Configuration Manager module not found" -Severity 3
			}
		} else {
			Write-DATLogEntry -Value "- Configuration Manager module already loaded" -Severity 1
			$ConfigMgrModuleLoaded = $true
		}
	} catch {
		Write-DATLogEntry -Value "[Error] - Failed to load Configuration Manager module" -Severity 3
	}
	
	# Create package if the Configuration Manager module is loaded
	if ($ConfigMgrModuleLoaded -eq $true) {
		# Get list of selected distribution points
		$RunningConfigurationValues = Get-ItemProperty -Path $global:RegPath
		$SelectedDistributionPoints = ($RunningConfigurationValues).SelectedDistributionPoints -split ","
		$SelectedDistributionPointGroups = ($RunningConfigurationValues).SelectedDistributionPointGroups -split ","
		$PackageType = ($RunningConfigurationValues).PackageType
		$InstallLocation = ($RunningConfigurationValues).InstallDirectory
		
		switch ($PackageType) {
			"Drivers" {
				$ConfigMgrPkgPath = "Package\Driver Packages\$OEM"
			}
			"BIOS" {
				$ConfigMgrPkgPath = "Package\BIOS Packages\$OEM"
			}
		}
		
		# Test if the package path root exits and proceed if it does
		if ((Test-Path -Path $PackagePath) -eq $true) {
			# Create a new package for the driver package
			try {
				
				# Connect to the Configuration Manager server
				Write-DATLogEntry -Value "- Connecting to site server $SiteServer" -Severity 1
				Connect-DATConfigMgr -SiteServer $SiteServer -WinRMOverSSL $true
				
				# Variables
				$CMPackage = ("Drivers - " + "$OEM " + $Model + " - " + $OS + " " + $Architecture)
				
				# Check if package with the same version already exists
				Write-DATLogEntry -Value "- Querying existing packages to avoid duplicates" -Severity 1
				Set-Location -Path "$($SiteCode):\"
				$ExistingCMPackage = [boolean](Get-CMPackage -Fast | Select-Object Name, Version | Where-Object { $_.Name -eq "$CMPackage" -and $_.Version -eq "$Version" })
				Set-Location -Path "$InstallLocation"
				
				# Process for newer packages
				if ($ExistingCMPackage -eq $false) {
					# Check for driver package destination folder and create if missing
					$PackagePath = Join-Path -Path $PackagePath -ChildPath "$OEM\$Model\$OS\$Architecture\$Version"
					if (-not (Test-Path -Path $PackagePath)) {
						Write-DATLogEntry -Value "- Creating destination folder at $PackagePath" -Severity 1
						New-Item -Path $PackagePath -ItemType Directory -Force | Out-Null
					}
					
					# Copy the driver package to the package path
					Write-DATLogEntry -Value "- Copying driver package to $PackagePath" -Severity 1
					Copy-Item -Path $DriverPackage -Destination $PackagePath -Force -Verbose
					
					# Create a new package
					try {
						
						Write-DATLogEntry -Value "- Creating $CMPackage package" -Severity 1 -UpdateUI
						Write-DATLogEntry -Value "- Switching to Configuration Manager drive $($SiteCode):\"
						Set-Location -Path "$($SiteCode):\"
						$PackageDetails = New-CMPackage -Name "$CMPackage" -path "$PackagePath" -Manufacturer "$OEM" -Description "Models included:$($Baseboards)" -Version $Version
						$MifVersion = $OS + " " + $Architecture
						Set-CMPackage -Name "$CMPackage" -MifName "$Model" -MifVersion $MifVersion
						Write-DATLogEntry -Value "- Created new Configuration Manager package" -Severity 1 -UpdateUI
						
						# Check For Driver Package
						$ConfiMgrPackage = Get-CMPackage -Name $CMPackage -Fast | Select-Object PackageID, Version, Name | Where-Object {
							$_.Version -eq $Version
						}
						
					} catch {
						Write-DATLogEntry -Value "[Error] - Failed to create Configuration Manager package" -Severity 3
					}
					
					# Move package to OEM folder
					try {
						
						if (-not ([string]::IsNullOrEmpty($($ConfiMgrPackage.PackageID)))) {
							Write-DATLogEntry -Value "- Driver package $($ConfiMgrPackage.PackageID) created successfully" -Severity 1
							Write-DATLogEntry -Value "- Moving package to OEM folder" -Severity 1
							# Check for the OEM folder and create if missing
							if (-not (Test-Path -Path "$ConfigMgrPkgPath")) {
								Write-DATLogEntry -Value "- Creating OEM folder at $ConfigMgrPkgPath" -Severity 1
								New-Item -Path "$ConfigMgrPkgPath" -Force | Out-Null
							}
						}
						# Move package
						Move-CMObject -FolderPath "$ConfigMgrPkgPath" -ObjectID $ConfiMgrPackage.PackageID
					} catch {
						Write-DATLogEntry -Value "[Warning] - Failed to move driver pacakge to OEM folder" -Severity 2
					}
					
					# Distribute the package to the selected distribution points
					try {
						Write-DATLogEntry -Value "- Distributing $($ConfiMgrPackage.PackageID) to selected distribution points / groups " -Severity 1 -UpdateUI
						if ($SelectedDistributionPointGroups -ne $null) {
							# Loop through the selected distribution point groups and distribute the package
							foreach ($DPG in $SelectedDistributionPointGroups) {
								Write-DATLogEntry -Value "- Distributing Package $($ConfiMgrPackage.PackageID) to Distribution Point Group -  $DPG" -Severity 1
								Start-CMContentDistribution -PackageID $ConfiMgrPackage.PackageID -DistributionPointGroupName "$DPG"
								
							}
						} elseif ($SelectedDistributionPoints -ne $null) {
							# Loop through the selected distribution points and distribute the package
							foreach ($DP in $SelectedDistributionPoints) {
								Write-DATLogEntry -Value "- Distributing Package $PackageID to Distribution Point -  $DP" -Severity 1
								Start-CMContentDistribution -PackageID $ConfiMgrPackage.PackageID -DistributionPointName "$DP"
							}
						}
						Write-DATLogEntry -Value "- Successfully started Configuration Manager distribution job for package $($ConfiMgrPackage.PackageID)" -Severity 1 -UpdateUI
					} catch {
						Write-DATLogEntry -Value "[Error] - Failed to distribute Configuration Manager package" -Severity 3
					}
				} else {
					Write-DATLogEntry -Value "- A package exists with the same version number. Skipping package creation." -Severity 1
				}
			} catch {
				Write-DATLogEntry -Value "[Error] - Issues occured while attempting to create Configuration Manager package" -Severity 3
				Write-DATLogEntry -Value "[Error] - $($_.Exception.Message)" -Severity 3
			}
		}
	} else {
		Write-DATLogEntry -Value "[Error] - Configuration Manager module not loaded. Unable to proceed." -Severity 3
	}
}
