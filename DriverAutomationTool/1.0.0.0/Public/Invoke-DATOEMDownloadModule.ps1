function Invoke-DATOEMDownloadModule {
	<#
	.SYNOPSIS
		A brief description of the Invoke-DATOEMContentDownload function.
	
	.DESCRIPTION
		This function uses OEM provided modules to download and compress driver packages.
	
	.PARAMETER OEM
		A description of the OEM parameter.
	
	.PARAMETER SystemSKU
		A description of the SystemSKU parameter.
	
	.PARAMETER WindowsBuild
		A description of the WindowsBuild parameter.
	
	.PARAMETER WindowsVersion
		A description of the WindowsVersion parameter.
	
	.PARAMETER DownloadDestination
		A description of the DownloadDestination parameter.
	
	.PARAMETER RegPath
		A description of the RegPath parameter.
	
	.PARAMETER LogDirectory
		A description of the LogDirectory parameter.
	
	.PARAMETER ScriptDirectory
		A description of the ScriptDirectory parameter.
	
	.PARAMETER TempDirectory
		A description of the TempDirectory parameter.
	
	.EXAMPLE
		PS C:\> Invoke-DATOEMContentDownload
	
	.NOTES
		Additional information about the function.
#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$OEM,
		[ValidateNotNullOrEmpty()]
		[string]$SystemSKU,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$WindowsBuild,
		[ValidateNotNullOrEmpty()]
		[string]$WindowsVersion,
		[ValidateNotNullOrEmpty()]
		[string]$DownloadDestination,
		[ValidateNotNullOrEmpty()]
		[string]$RegPath,
		[ValidateNotNullOrEmpty()]
		[string]$LogDirectory,
		[ValidateNotNullOrEmpty()]
		[string]$TempDirectory
	)
	
	# Import DriverAutomationToolCore Module
	Import-Module -Name DriverAutomationToolCore
	Write-DATLogEntry -Value "- Loading DriverAutomtionToolCore module" -Severity 1 -UpdateUI
	Write-DATLogEntry -Value "[$SystemSKU Driver Job] - Loading pre-requisite PowerShell modules" -Severity 1 -UpdateUI
	
	# Build driver packages specific to vendor requirements
	switch ($OEM) {
		"HP" {
			
			Write-DATLogEntry -Value "- Calling HP CMSL function" -Severity 1
			Write-DATLogEntry -Value "- Selected Windows build is $WindowsBuild" -Severity 1
			Write-DATLogEntry -Value "- Selected Windows version is $WindowsVersion" -Severity 1
			Write-DATLogEntry -Value "- Driver package path is $DownloadDestination" -Severity 1
						
			# Import required PS modules
			Write-DATLogEntry -Value "- Loading HP CMSL module" -Severity 1 -UpdateUI
			Import-Module -Name HPCMSL
			
			switch -wildcard ($WindowsBuild) {
				"*Windows 11*" {
					$TargetWindowsBuild = "Win11"
				}
				"*Windows 10*" {
					$TargetWindowsBuild = "Win10"
				}
			}
			
			# Create new driver package
			Write-DATLogEntry -Value "[Driver Package] - Starting background job for HP SKU $SystemSKU" -Severity 1 -UpdateUI
			Write-DATLogEntry -Value "- Selected OS is $WindowsBuild" -Severity 1
			Write-DATLogEntry -Value "- Selected OS version is $WindowsVersion" -Severity 1
			Write-DATLogEntry -Value "- Download destination $DownloadDestination" -Severity 1
			Write-DATLogEntry -Value "- Registry location is $global:RegPath" -Severity 1
			Write-DATLogEntry -Value "- Log directory is $global:LogDirectory" -Severity 1
			
			try {
				# Create temporary download directory
				if ((Test-Path -Path $TempDirectory) -eq $false) {
					Write-DATLogEntry -Value "- Creating required folder at $TempDirectory" -Severity 1
					New-Item -Path "$TempDirectory" -ItemType Directory -Force | Out-Null
				}
				
				# Create model directory
				if ((Test-Path -Path $DownloadDestination) -eq $false) {
					Write-DATLogEntry -Value "- Creating required folder at $DownloadDestination" -Severity 1
					New-Item -Path "$DownloadDestination" -ItemType Directory -Force | Out-Null
				}
				
				# Clear model directory if re-running
				if ((Get-ChildItem -Path $DownloadDestination -Recurse -Filter *.wim).Count -ge 1) {
					Write-DATLogEntry -Value "- Updating driver package, removing $WindowsBuild $WindowsVersion legacy driver package(s)" -Severity 1
					Get-ChildItem -Path "$DownloadDestination" -Recurse -Filter *.wim | Remove-Item -Force
				}
				
				# Use temp location as base directory
				Set-Location -Path $DownloadDestination
				
				# Create registry entries				
				# Validate file path format using regex for local or network paths
				if (($global:DriverCacheDir -match "^[a-zA-Z]:\\") -or ($global:DriverCacheDir -match "^\\\\")) {
					Set-DATRegistryValue -Name "DriverCacheDir" -Value "$global:DriverCacheDir" -Type String
				}
				if (-not ([string]::IsNullOrEmpty($global:OrganisationName))) {
					Set-DATRegistryValue -Name "OrganisationName" -Value "$global:OrganisationName" -Type String
				}
				if (-not ([string]::IsNullOrEmpty($global:LogDirectory))) {
					Set-DATRegistryValue -Name "LogPath" -Value "$global:LogDirectory" -Type String
				}
				if (-not ([string]::IsNullOrEmpty($global:RegPath))) {
					Set-DATRegistryValue -Name "RegPath" -Value "$global:RegPath" -Type String
				}
				if (-not ([string]::IsNullOrEmpty($global:TrimmedProductName))) {
					Set-DATRegistryValue -Name "TrimmedProductName" -Value "$global:TrimmedProductName" -Type String
				}
				
				# Download driver package
				Write-DATLogEntry -Value "- Downloading drivers for OS $($WindowsBuild.TrimEnd()) $($WindowsVersion.Trim()) on hardware platform HP SKU $SystemSKU" -Severity 1 -UpdateUI
				
				# Script block to download drivers
				$DownloadDrivers = {
					param (
						[parameter(Mandatory = $true)]
						[string]$SystemSKU,
						[parameter(Mandatory = $true)]
						[string]$WindowsBuild,
						[parameter(Mandatory = $true)]
						[string]$WindowsVersion,
						[parameter(Mandatory = $true)]
						[string]$DownloadDestination,
						[parameter(Mandatory = $true)]
						[string]$TempDownloadPath,
						[parameter(Mandatory = $true)]
						[string]$global:regpath
					)

					try {

						# Import DriverAutomationToolCore Module
						Import-Module -Name DriverAutomationToolCore
					
						# Import HP CMSL module
						Write-DATLogEntry -Value "- Importing HP CMSL module" -Severity 1
						Import-Module -Name HPCMSL
					} catch {
						Write-DATLogEntry -Value "[Error] - Failed to import required modules" -Severity 3; break
					}
					try {
					
						# Download drivers
						Write-DATLogEntry -Value "[HP Softpaq Download] - Downloading drivers for HP SKU $SystemSKU" -Severity 1
					
						# Output parameters to the log file for troubleshooting
						Write-DATLogEntry -Value "- HP SKU is $SystemSKU" -Severity 1
						Write-DATLogEntry -Value "- Windows build is $WindowsBuild" -Severity 1
						Write-DATLogEntry -Value "- Windows version is $WindowsVersion" -Severity 1
						Write-DATLogEntry -Value "- Download destination is $DownloadDestination" -Severity 1
						Write-DATLogEntry -Value "- Temp download path is $TempDownloadPath" -Severity 1
						Write-DATLogEntry -Value "- Registry path is $global:regpath" -Severity 1

						switch -wildcard ($WindowsBuild) {
							"Windows 11*" { 
								$OS = "win11"
							}
							"Windows 10*" { 
								$OS = "win10" 
							}
						}

						# Get the current running process ID
						$RunningProcessID = $PID
						$RunningProcess = "PowerShell"
						Set-DATRegistryValue -Name "RunningProcessID" -Value $RunningProcessID -Type String
						Set-DATRegistryValue -Name "RunningProcess" -Value $RunningProcess -Type String
						Set-DATRegistryValue -Name "RunningState" -Value "Running" -Type String
						Set-DATRegistryValue -Name "DownloadedSoftpaqs" -Value "0" -Type String
						Set-DATRegistryValue -Name "TotalSoftPaqsToDownload" -Value "0" -Type String
						Write-DATLogEntry -Value "- Operating System set as `"$OS`" for HP commandlet" -Severity 1
						
						# Calling HP commandlet to download drivers
						Write-DATLogEntry -value "- Starting HP driver download process" -Severity 1
						# Remove existing WIM
						if ((Get-ChildItem -Path $DownloadDestination -Filter *.wim).Count -ge 1) {
							Write-DATLogEntry -Value "- Removing previously created WIM file(s)" -Severity 1
							Get-ChildItem -Path $DownloadDestination -Filter *.wim | Remove-Item -Force
						}

						# Invoke HP driver download with WhatIf parameter to obtain SoftPaq information and count
						Write-DATLogEntry -Value "- Invoking HP driver download to obtain SoftPaq information" -Severity 1
					
						try {
							# Redirect WhatIf output to variables
							$SoftPaqInfo = $null
							$SoftPaqError = $null
							New-HPDriverPack -Platform "$SystemSKU" -Os "$OS" -OSVer "$WindowsVersion" -Format wim -Path "$DownloadDestination" -TempDownloadPath "$TempDownloadPath" -RemoveOlder -WhatIf -InformationVariable SoftPaqInfo -ErrorVariable SoftPaqError
							
							# Log captured information
							if ($SoftPaqInfo) {
								# Convert InformationRecord objects to strings
								$SoftPaqLines = $SoftPaqInfo | ForEach-Object { $_.MessageData.ToString() }
								
								# Foreach line which begins with "sp" write to log
								$SoftPaqLines | Where-Object { $_ -match '^\s+sp\d+' } | ForEach-Object { 
									Write-DATLogEntry -Value "-- Download required - $($_.Trim())" -Severity 1 
								}
								
								# Count the number of SoftPaqs to be downloaded
								$SoftPaqCount = ($SoftPaqLines | Where-Object { $_ -match '^\s+sp\d+' }).Count
								Write-DATLogEntry -Value "- Total SoftPaqs to be downloaded: $SoftPaqCount" -Severity 1
								# Write the SoftPaq count to the registry
								Set-DATRegistryValue -Name "TotalSoftPaqsToDownload" -Value "$SoftPaqCount" -Type String
							}
							
							if ($SoftPaqError) {
								Write-DATLogEntry -Value "- SoftPaq WhatIf Errors: $($SoftPaqError | Out-String)" -Severity 2
							}
						} catch {
							Write-DATLogEntry -Value "- Error during WhatIf operation: $($_.Exception.Message)" -Severity 3; break
						}

						try {
							# Actual download and package creation
							New-HPDriverPack -Platform "$SystemSKU" -Os "$OS" -OSVer "$WindowsVersion" -Format wim -Path "$DownloadDestination" -TempDownloadPath "$TempDownloadPath" -RemoveOlder -InformationVariable SoftPaqInfo -ErrorVariable SoftPaqError
						}
						catch {
							Write-DATLogEntry -Value "[Error] - Issues occured during HP driver download and packaging process. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -Severity 3; break
						}

						try {
							# Set registry values
							$PackageDriverPath = Get-ChildItem -Path $DownloadDestination -Filter *.wim | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName
				
						}
						catch {
							Write-DATLogEntry -Value "[Error] - Issues occured while obtaining the driver package path. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -Severity 3; break
						}

		
						if ([string]::IsNullOrEmpty($PackageDriverPath)) {
							Write-DATLogEntry -Value "[Error] - No driver package was created. Stopping job" -Severity 3; break
						} else {
							# Set registry values
							Set-DATRegistryValue -Name "PackagedDriverPath" -Value "$PackageDriverPath" -Type String
							Write-DATLogEntry -Value "- HP Driver Package WIM created at $PackageDriverPath" -Severity 1
							Write-DATLogEntry -Value "- Driver package job completed successfully" -Severity 1

							# Set completed state
							Set-DATRegistryValue -Name "RunningMode" -Value "Download Completed" -Type String
						}
					} catch {
						Write-DATLogEntry -Value "[Error] - Issues occured while using the HP PowerShell commandlet. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -Severity 3
					}
				}

				# Start job
				Write-DATLogEntry -Value "- Starting HP driver download job as a background process" -Severity 1
				Write-DATLogEntry -Value "- Job parameters:" -Severity 1
				Write-DATLogEntry -Value "-- System SKU: $SystemSKU" -Severity 1
				Write-DATLogEntry -Value "-- Windows Build: $WindowsBuild" -Severity 1
				Write-DATLogEntry -Value "-- Windows Version: $WindowsVersion" -Severity 1
				Write-DATLogEntry -Value "-- Download Destination: $DownloadDestination" -Severity 1
				Write-DATLogEntry -Value "-- Temp Directory: $TempDirectory" -Severity 1

				$DownloadDriversJob = Start-Job -ScriptBlock $DownloadDrivers -Name "[Driver Automation Tool] - HP Driver Download" -ArgumentList ($SystemSKU, $WindowsBuild, $WindowsVersion, $DownloadDestination, $TempDirectory, $global:RegPath) -Verbose
				$DownloadDriversJobId = $DownloadDriversJob.Id
				
				# Wait for the job to start
				Start-Sleep -Seconds 10

				Write-DATLogEntry -value "- HP download started as a background process. Monitoring for completion. Job ID $DownloadDriversJobId" -severity 1

				# Set initial counter value
				$DownloadStartTime = Get-DATLocalSystemTime
				$DownloadEndTime = $DownloadStartTime.AddMinutes(30)
				Write-DATLogEntry -Value "- HP driver download and packaging process has started" -Severity 1
				Write-DATLogEntry -Value "- Download process will run for a maximum of 30 minutes" -Severity 1

				# Get current status message from the registry
				$RunningConfigurationValues = Get-ItemProperty -Path $global:RegPath
				$RunningProcessID = ($RunningConfigurationValues).RunningProcessID
				Write-DATLogEntry -Value "[HP Job Monitor] - Monitoring process ID $RunningProcessID" -Severity 1
				
				# Monitor job
				$DownloadProcessCounter = 0
				$CurrentSoftPaq = 0
				while ($(Get-Job -Id $DownloadDriversJobId | Select-Object -ExpandProperty State) -eq "Running") {

					# Monitor the total file size of all exe files in the root of the temp download path
					$DownloadedBytes = (Get-ChildItem -Path "$TempDirectory" -Recurse -Filter *.exe | Measure-Object -Property Length -Sum).Sum
					if (-not([string]::IsNullOrEmpty($DownloadedBytes)) -and $DownloadedBytes -gt 0) {
						# Used for debugging download size
						#Write-DATLogEntry -Value "- Downloaded bytes so far: $DownloadedBytes" -Severity 2
					} 

					# Monitor the number of downloaded SoftPaqs
					$TotalSoftPaqsToDownload = (Get-ItemProperty -Path $global:RegPath).TotalSoftPaqsToDownload
					$DownloadedSoftPaqs = (Get-ChildItem -Path "$TempDirectory" -Filter sp*.exe).Count
					if ($DownloadedSoftPaqs -gt $CurrentSoftPaq) {
						$CurrentSoftPaq++
						Write-DATLogEntry -Value "- Downloaded SoftPaqs so far: $DownloadedSoftPaqs of $TotalSoftPaqsToDownload" -Severity 2
						# Write downloaded SoftPaq count to registry
						Set-DATRegistryValue -Name "DownloadedSoftPaqs" -Value "$DownloadedSoftPaqs" -Type String
					}
					
					# Report download progress if bytes are greater than 0
					if ($DownloadedBytes -gt 0) {
						# Increment download process counter
						$DownloadProcessCounter++

						# Convert download size to MB and set registry value
						$DownloadSizeMB = [math]::Round(($DownloadedBytes / 1MB), 2)
						
						# Update registry
						Set-DATRegistryValue -Name "BytesTransferred" -Value $DownloadedBytes -Type String
						Set-DATRegistryValue -Name "DownloadSize" -Type String -Value "$DownloadSizeMB" -Verbose
						
						# Convert bytes to MB/GB
						$DownloadMB = [math]::Round($DownloadedBytes / 1MB, 2)
						$DownloadGB = [math]::Round($DownloadedBytes / 1GB, 2)
						
						# Set download speed in MB/s
						$DownloadSpeed = [math]::Round($DownloadMB / ((Get-Date) - $DownloadStartTime).TotalSeconds, 2)
						
						# Set message body for download progress
						$DownloadMsg = "- Downloaded $DownloadGB GB at a rate of $DownloadSpeed MB/s"
						
						# Update registry with download progress
						Set-DATRegistryValue -Name "RunningMessage" -Type String -Value "$($DownloadMsg.TrimStart('- '))" -Verbose
					}
			
				}
				
				if ((Get-Job -Id $DownloadDriversJobId | Select-Object -ExpandProperty State) -eq "Completed") {
					# Get current status message from the registry
					$RunningConfigurationValues = Get-ItemProperty -Path $global:RegPath
					$CurrentOEM = ($RunningConfigurationValues).CurrentOEM
					$CurrentModel = ($RunningConfigurationValues).CurrentModel
					$CurrentOS = ($RunningConfigurationValues).OS
					$CurrentArchitecture = ($RunningConfigurationValues).Architecture
					$CurrentModelBaseboards = ($RunningConfigurationValues).CurrentBaseboards
					$PackagePath = ($RunningConfigurationValues).PackageStoragePath
					$DriverPackage = ($RunningConfigurationValues).PackagedDriverPath
					$SiteServer = ($RunningConfigurationValues).SiteServer
					$global:Sitecode = ($RunningConfigurationValues).SiteCode
					$PackageVersion = ($RunningConfigurationValues).PackageVersion
					$PackagedDriverPath = ($RunningConfigurationValues).PackagedDriverPath
					
					# Final registry update with download progress
					$DownloadedFileSize = (Get-Item -Path $DownloadDestination).Length
					Set-DATRegistryValue -Name "BytesTransferred" -Value "$DownloadedFileSize" -Type String
				}
				
				#New-HPDriverPack -Platform $SystemSKU -Os $TargetWindowsBuild -OSVer $WindowsVersion -Format wim -Path $DownloadDestination -TempDownloadPath $TempDirectory -RemoveOlder -InformationVariable SoftPaqInfo -ErrorVariable SoftPaqError
				Write-DATLogEntry -Value "- DriverPackage: OEM download process completed successfully" -Severity 1 -UpdateUI
				Set-DATRegistryValue -Name "RunningMode" -Value "Extract Ready" -Type String
				
			} catch [System.Exception] {
				Set-DATRegistryValue -Name "ErrorMessage" -Type String -Value "[Driver Package Error] - Issues occured while attempting create driver package. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -Verbose
				Write-DATLogEntry -Value "[Driver Package Error] - Issues occured while attempting create driver package. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)" -Severity 3 -UpdateUI
			}
		}
	}
}