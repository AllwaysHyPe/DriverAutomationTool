<#
	.SYNOPSIS
		This function works with cached driver images to apply them to the Windows image
	
	.DESCRIPTION
		The function uses pre-staged driver packages, created in WIM files, and stored on the OSDLiteDeploy cache drive. During OS deployment, the baseboard/systemsku value is matched against the content, the WIM is then mounted and the drivers are injected into the offline Windows image.
	
	.PARAMETER TargetOS
		Specify the OS being used, for example, Windows 10
	
	.PARAMETER TargetOSBuild
		Specify the build of the OS being deployed, for example 23H2
	
	.PARAMETER TargetDrive
		A description of the TargetDrive parameter.
	
	.EXAMPLE
		PS C:\> Install-DATDriverPackage -TargetOS Windows 11 -TargetBuild 23H2
	
	.NOTES
		Additional information about the function.
#>
function Install-DATDriverPackage {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateSet('Windows 10', 'Windows 11')]
		[ValidateNotNullOrEmpty()]
		[String]$TargetOS,
		[Parameter(Mandatory = $true)]
		[ValidateSet('22H2', '23H2', '24H2', '25H2')]
		[ValidateNotNullOrEmpty()]
		[String]$TargetOSBuild,
		[Parameter(Mandatory = $true)]
		[ValidatePattern('^[A-Z]:$')]
		[String]$TargetDrive
	)
	
	try {
		# Set initial running values
		$DriverImageFile = $null
		
		# Create a custom object for computer details gathered from local WMI
		$ComputerDetails = [PSCustomObject]@{
			Manufacturer = $null
			Model        = $null
			SystemSKU    = $null
			FallbackSKU  = $null
		}
		
		# Gather device hardware type information
		$ComputerManufacturer = (Get-WmiObject -Class "Win32_ComputerSystem" | Select-Object -ExpandProperty Manufacturer).Trim()
		switch -Wildcard ($ComputerManufacturer) {
			"*Microsoft*" {
				$ComputerDetails.Manufacturer = "Microsoft"
				$ComputerDetails.Model = (Get-WmiObject -Class "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$ComputerDetails.SystemSKU = Get-WmiObject -Namespace "root\wmi" -Class "MS_SystemInformation" | Select-Object -ExpandProperty SystemSKU
			}
			"*HP*" {
				$ComputerDetails.Manufacturer = "HP"
				$ComputerDetails.Model = (Get-WmiObject -Class "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$ComputerDetails.SystemSKU = (Get-CimInstance -ClassName "MS_SystemInformation" -Namespace "root\WMI").BaseBoardProduct.Trim()
			}
			"*Hewlett-Packard*" {
				$ComputerDetails.Manufacturer = "HP"
				$ComputerDetails.Model = (Get-WmiObject -Class "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$ComputerDetails.SystemSKU = (Get-CimInstance -ClassName "MS_SystemInformation" -Namespace "root\WMI").BaseBoardProduct.Trim()
			}
			"*Dell*" {
				$ComputerDetails.Manufacturer = "Dell"
				$ComputerDetails.Model = (Get-WmiObject -Class "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).Trim()
				$ComputerDetails.SystemSKU = (Get-CimInstance -ClassName "MS_SystemInformation" -Namespace "root\WMI").SystemSku.Trim()
				[string]$OEMString = Get-WmiObject -Class "Win32_ComputerSystem" | Select-Object -ExpandProperty OEMStringArray
				$ComputerDetails.FallbackSKU = [regex]::Matches($OEMString, '\[\S*]')[0].Value.TrimStart("[").TrimEnd("]")
			}
			"*Lenovo*" {
				$ComputerDetails.Manufacturer = "Lenovo"
				$ComputerDetails.Model = (Get-WmiObject -Class "Win32_ComputerSystemProduct" | Select-Object -ExpandProperty Version).Trim()
				$ComputerDetails.SystemSKU = ((Get-WmiObject -Class "Win32_ComputerSystem" | Select-Object -ExpandProperty Model).SubString(0, 4)).Trim()
			}
		}
		
		# Stamp computer type details in the registry
		Set-DATRegistryValue -Name "Manufacturer" -Value "$($ComputerDetails.Manufacturer)" -Type String
		Set-DATRegistryValue -Name "Model" -Value "$($ComputerDetails.Model)" -Type String
		Set-DATRegistryValue -Name "SystemSKU" -Value "$($ComputerDetails.SystemSKU)" -Type String
		$SerialNumber = Get-CimInstance -ClassName win32_bios -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SerialNumber
		if (-not ([string]::IsNullOrEmpty($SerialNumber))) {
			Set-DATRegistryValue -Name "SerialNumber" -Value "$SerialNumber" -Type String
		}
		
		Write-DATLogEntry -Value "- Querying local driver cache availability for $($ComputerDetails.Manufacturer) $($ComputerDetails.Model) with matching SysID $($ComputerDetails.SystemSKU)" -Severity 1 -UpdateUI
		$CacheDrives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.VolumeName -match "Cache" } | Select-Object -ExpandProperty DeviceID
		Write-DATLogEntry -Value "- Found $($CacheDrives.Count) cache drives" -Severity 1
		
		# Obtain OS matching values from the registry
		Write-DATLogEntry -Value "- Target OS is $TargetOS" -Severity 1
		Write-DATLogEntry -Value "- Target OS build is $TargetOSBuild" -Severity 1
		
		# Build array for Cached images
		$global:CachedImages = @()
	} catch [System.Exception] {
		Write-DATLogEntry -Value "[Warning] - Errors occured while attempting to identity make/model details. Error message: $($_.Exception.Message)" -Severity 2
	}
	
	if ((-not ([string]::IsNullOrEmpty($TargetOS))) -and (-not ([string]::IsNullOrEmpty($TargetOSBuild)))) {
		foreach ($CacheDrive in $CacheDrives) {
			
			try {
				# Check for manufacturer support JSON
				Write-DATLogEntry -Value "- Attempting to read in OEM support JSON file for OEM - $($ComputerDetails.Manufacturer)" -Severity 1
				$OEMSupportJSON = Get-ChildItem -Path $CacheDrive -File -Filter *.json -Recurse | Where-Object { $_.FullName -like "*$($ComputerDetails.Manufacturer)*Models*" } | Sort-Object CreationTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName
				
				if (-not ([string]::IsNullOrEmpty($OEMSupportJSON))) {
					# Read in manufacturer JSON
					$SupportedSKUValues = Get-Content -Path $OEMSupportJSON | ConvertFrom-Json
					Write-DATLogEntry -Value "- Attempting to match driver packages to supported SKU values - $SupportedSKUValues" -Severity 1
					$SupportedSKUList = $SupportedSKUValues | Where-Object { $_.SystemId -match $ComputerDetails.SystemSKU } | Select-Object -Property SystemId -Unique
					
					# Create array
					$SupportedSKUs = New-Object -TypeName System.Collections.ArrayList
					
					# Loop through supported SKU list
					foreach ($SKU in $($SupportedSKUList.SystemId).Split(",")) {
						if ($SKU -notin $SupportedSKUs) {
							# Add each supported SKU to the matching array
							$SupportedSKUs.Add($SKU) | Out-Null
						}
					}
					
					# Create array
					$SupportedDriverPacks = New-Object -TypeName System.Collections.ArrayList
					
					# Loop through to attempt to find supported driver package
					Write-DATLogEntry -Value "- Attempting to match supported driver package to supported SKU values" -Severity 1
					foreach ($SKU in $SupportedSKUs) {
						Write-DATLogEntry -Value "- Attempting to match driver package to SKU $SKU in path $CacheDrive" -Severity 1
						$DriverImageFile = Get-ChildItem -Path $CacheDrive -File -Recurse | Where-Object { $_.Name -match ".WIM" -and $_.FullName -like "*$TargetOS*$TargetOSBuild*" -and $_.FullName -match $SKU } | Sort-Object CreationTime -Descending | Select-Object -First 1 | Select-Object -Property FullName, CreationTime
						if (-not ([string]::IsNullOrEmpty($DriverImageFile))) {
							$SupportedDriverPacks.Add($DriverImageFile)
						}
					}
					
					Write-DATLogEntry -Value "- Found $($SupportedDriverPacks.Count) supported driver packages for SKUs $($SupportedSKUs)" -Severity 1
					
					if ($SupportedDriverPacks.Count -ge 1) {
						# Select the most recent driver package
						$DriverImageFile = $SupportedDriverPacks | Sort-Object CreationTime -Descending | Select-Object -First 1 -ExpandProperty FullName
						Write-DATLogEntry -Value "- Selected most recent driver package at path $DriverImageFile" -Severity 1
					}
				} else {
					# Fallback to direct model match
					Write-DATLogEntry -Value "[Warning] - No OEM JSON file found for $ComputerDetails.Manufacturer. Attempting to match directly to model." -Severity 2
					$DriverImageFile = Get-ChildItem -Path $CacheDrive -File -Recurse | Where-Object { $_.Name -match ".WIM" -and $_.FullName -like "*$TargetOS*$TargetOSBuild*" -and $_.FullName -match $ComputerDetails.SystemSKU } | Sort-Object CreationTime -Descending | Select-Object -First 1 | Select-Object -ExpandProperty FullName
					
					# Report matching status or failure
					if (-not ([string]::IsNullOrEmpty($DriverImageFile))) {
						Write-DATLogEntry -Value "- Found matching driver package for $($ComputerDetails.Manufacturer) $($ComputerDetails.Model) with SKU $($ComputerDetails.SystemSKU)" -Severity 1
						Write-DATLogEntry -Value "- Driver package located at $DriverImageFile" -Severity 1
					} else {
						Write-DATLogEntry -Value "[Error] - No matching driver package found for $ComputerDetails.Manufacturer $ComputerDetails.Model with SKU $ComputerDetails.SystemSKU" -Severity 3
					}
				}
			} catch [System.Exception] {
				Write-DATLogEntry -Value "[Warning] - Errors occured while attempting to match SKU to JSON stored OEM values. Error message: $($_.Exception.Message)" -Severity 2
			}
			
			# Process driver installation if supported
			if (-not ([string]::IsNullOrEmpty($DriverImageFile))) {
				Write-DATLogEntry -Value "- Processing driver package" -Severity 1
				
				# Specify temporary mount location
				$ContentLocation = $DriverImageFile | Split-Path -Parent
				
				try {
					# Create mount location for driver package WIM file
					$DriverPackageMountLocation = Join-Path -Path $TargetDrive -ChildPath "DriversTemp"
					Write-DATLogEntry -Value "- Mount location for driver package content: $($DriverPackageMountLocation)" -Severity 1
					
					if (-not (Test-Path -Path $DriverPackageMountLocation)) {
						Write-DATLogEntry -Value "- Creating mount location directory: $($DriverPackageMountLocation)" -Severity 1
						New-Item -Path $DriverPackageMountLocation -ItemType "Directory" -Force | Out-Null
					}
				} catch [System.Exception] {
					Write-DATLogEntry -Value "[Error] - Failed to create mount location for WIM file. Error message: $($_.Exception.Message)" -Severity 3
				}
				
				try {
					# Expand compressed driver package WIM file
					Write-DATLogEntry -Value "- Attempting to mount driver package content WIM file: $($DriverImageFile)" -Severity 1 -UpdateUI
					Mount-WindowsImage -ImagePath $DriverImageFile -Path $DriverPackageMountLocation -Index 1
					Write-DATLogEntry -Value "- Successfully mounted driver package content WIM file" -Severity 1 -UpdateUI
					
					# Copy files to maintain on disk post OSD
					$DriverPackageLocation = Join-Path -Path $TargetDrive -ChildPath "Drivers"
					if (-not (Test-Path -Path $DriverPackageLocation)) {
						Write-DATLogEntry -Value "- Creating mount location directory: $($DriverPackageLocation)" -Severity 1
						New-Item -Path $DriverPackageLocation -ItemType "Directory" -Force | Out-Null
					}
					Write-DATLogEntry -Value "- Copying drivers from mounted WIM to local disk" -Severity 1 -UpdateUI
					Get-ChildItem -Path $DriverPackageMountLocation | Copy-Item -Destination $DriverPackageLocation -Recurse -Container -Force
				} catch [System.Exception] {
					Write-DATLogEntry -Value "[Error] - Failed to mount driver package content WIM file. Error message: $($_.Exception.Message)" -Severity 3
					Dismount-WindowsImage -Path $DriverPackageMountLocation -Discard
				}
				
				try {
					Write-DATLogEntry -Value " - Installing drivers using DISM on $TargetDrive using driver source directory $DriverPackageLocation" -Severity 1 -UpdateUI
					
					# Log location variables
					$DriverInstallOutput = Join-Path -Path $env:SystemRoot -ChildPath $("Temp\DriverInjection.log")
					$DriverInstallErrors = Join-Path -Path $env:SystemRoot -ChildPath $("Temp\DriverInjectionErrors.log")
					
					# Apply drivers recursively
					Write-DATLogEntry -Value " - Starting driver installation using dism.exe" -Severity 1
					$ApplyDriverInvocation = Start-Process dism.exe -ArgumentList "/Image:$($TargetDrive) /Add-Driver /Driver:$($DriverPackageLocation) /Recurse" -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $DriverInstallOutput -RedirectStandardError $DriverInstallErrors
					Write-DATLogEntry -Value " - Dism.exe process completed with exit code $($ApplyDriverInvocation.ExitCode)" -Severity 1
					
					# Validate driver injection
					if ($ApplyDriverInvocation.ExitCode -eq 0) {
						Write-DATLogEntry -Value " - Sucessfully installed drivers recursively in driver package content location using dism.exe" -Severity 1 -UpdateUI
						Set-DATRegistryValue -Name "DriversInstalled" -Value "$true" -Type String
						Set-DATRegistryValue -Name "DriverPkgPath" -Value "$DriverPackageLocation" -Type String
						Write-DATLogEntry -Value " - Dismounting driver image" -Severity 1
						Dismount-WindowsImage -Path $DriverPackageMountLocation -Discard
						Write-DATLogEntry -Value " - Cleaning up driver package mount temporary folder(s)" -Severity 1
						Remove-Item -Path $DriverPackageMountLocation -Force | Out-Null
					} else {
						Write-DATLogEntry -Value " - An error occurred while installing drivers. Continuing with warning code: $($ApplyDriverInvocation). See DISM.log for more details" -Severity 2
						Set-DATRegistryValue -Name "DriversInstalled" -Value "$false" -Type String
						Dismount-WindowsImage -Path $DriverPackageMountLocation -Discard
						Remove-Item -Path $DriverPackageMountLocation -Force | Out-Null
					}
				} catch [System.Exception] {
					Write-DATLogEntry -Value "[Error] - Failed to install OS drivers. Error message: $($_.Exception.Message)" -Severity 3
					Set-DATRegistryValue -Name "DriversInstalled" -Value "$false" -Type String
					Dismount-WindowsImage -Path $DriverPackageMountLocation -Discard
					Remove-Item -Path $DriverPackageMountLocation -Force | Out-Null
				}
			} else {
				Write-DATLogEntry -Value "[Warning] - Unable to find matching driver package on cache drive(s) $CacheDrives" -Severity 2
			}
		}
	} else {
		Write-DATLogEntry -Value "[Warning] - Unable to determine target OS and build." -Severity 2
	}
}
