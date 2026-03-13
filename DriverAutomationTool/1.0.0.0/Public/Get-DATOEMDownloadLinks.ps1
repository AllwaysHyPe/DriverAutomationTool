function Get-DATOEMDownloadLinks {
	[CmdletBinding()]
	param
	(
		[Parameter(Position = 1)]
		[ValidateSet('HP', 'Dell', 'Lenovo', 'Microsoft', 'Acer')]
		[array]$OEM,
		[Parameter(Position = 2)]
		[ValidateSet('Windows 11 25H2', 'Windows 11 24H2', 'Windows 11 23H2', 'Windows 11 22H2', 'Windows 11', 'Windows 10 22H2')]
		[ValidateNotNullOrEmpty()]
		[string]$OS,
		[Parameter(Position = 3)]
		[ValidateSet('x64', 'x86', 'Arm64')]
		[string]$Architecture,
		[Parameter(Position = 4)]
		[ValidateSet('driver', 'bios', 'all')]
		[string]$DownloadType,
		[Parameter(Position = 5)]
		[ValidateNotNullOrEmpty()]
		[string]$Model
	)

	Write-DATLogEntry -Value "[OEM Link Query] - Locating OEM download link" -Severity 1
	Write-DATLogEntry -Value "- Download type $DownloadType" -Severity 1
	Write-DATLogEntry -Value "- Parameters passed: OEM=$OEM, OS=$OS, Architecture=$Architecture, Model=$Model" -Severity 1
	
	# Get OEM Sources
	Get-DATOEMSources

	switch ($OEM) {
		"Acer" {
			# Look up Acer download link
			switch ($DownloadType) {
				"Driver" { 
					# Look up Acer driver download link from model
					switch -wildcard ($OS) {
						"Windows 11*" { 
							$OSFilter = "win11"
						}
						"Windows 10*" { 
							$OSFilter = "win10" 

						}
					}

					# Get Windows OS Build
					$OSBuildFilter = $OS.Split(" ")[2]

					# Look up Acer driver download link from model based on the OSFiler and version
					$DriverDownloadLink = ($global:AcerModelDrivers | Where-Object { $_.Name -eq $Model }) | Select-Object -ExpandProperty SCCM | Where-Object { $_.OS -eq $OSFilter -and $_.Version -eq $OSBuildFilter } | Select-Object -ExpandProperty "#text"

				}
				"BIOS" {
					# To be implemented. Waiting on update from Acer
				}
			}
		}
		"Dell" {
			switch ($DownloadType) {
				"Driver" {
					
					# OS matching format
					switch -wildcard ($OS) {
						"Windows 11" {
							$WindowsVersion = "Windows11"
						}
						"Windows 10" {
							$WindowsVersion = "Windows10"
						}
					}
					
					Write-DATLogEntry -Value "- Setting Dell variables" -Severity 1 -UpdateUI
					if ($global:DellModelCabFiles -eq $null) {
						[xml]$DellModelXML = Get-Content -Path $(Join-Path -Path $global:TempDirectory -ChildPath $DellXMLFile) -Raw
						
						# Set XML Object
						$DellModelXML.GetType().FullName
						$global:DellModelCabFiles = $DellModelXML.driverpackmanifest.driverpackage
					}
					$global:SkuValue = (($global:DellModelCabFiles.supportedsystems.brand.model | Where-Object {
								$_.Name -eq $Model
							}).systemID) | Select-Object -Unique
					$ModelURL = $global:DellDownloadBase + "/" + ($global:DellModelCabFiles | Where-Object {
							((($_.SupportedOperatingSystems).OperatingSystem).osCode -eq $WindowsVersion) -and ($_.SupportedSystems.Brand.Model.SystemID -match $global:SkuValue)
						}).delta
					if ($global:SkuValue.Count -gt 1) {
						$DellSingleSKU = $global:SkuValue | Select-Object -First 1
						$global:SkuValue = [string]($global:SkuValue -join ";")
						Write-DATLogEntry -Value "- Using SKU : $DellSingleSKU" -Severity 1
						$ModelURL = $global:DellDownloadBase + "/" + ($global:DellModelCabFiles | Where-Object {
								((($_.SupportedOperatingSystems).OperatingSystem).osCode -match $WindowsVersion) -and ($_.SupportedSystems.Brand.Model.SystemID -match $DellSingleSKU)
							}).delta
						$DriverDownloadLink = $global:DellDownloadBase + "/" + (($global:DellModelCabFiles | Where-Object {
									((($_.SupportedOperatingSystems).OperatingSystem).osCode -match $WindowsVersion) -and ($_.SupportedSystems.Brand.Model.SystemID -match $DellSingleSKU)
								}) | Sort-Object DateTime -Descending | Select-Object -First 1).path
						$DriverCab = ($DriverDownloadLink).Split("/") | Select-Object -Last 1
						
					} else {
						$ModelURL = $global:DellDownloadBase + "/" + ($global:DellModelCabFiles | Where-Object {
								((($_.SupportedOperatingSystems).OperatingSystem).osCode -match $WindowsVersion) -and ($_.SupportedSystems.Brand.Model.SystemID -match $global:SkuValue)
							}).delta
						$DriverDownloadLink = $global:DellDownloadBase + "/" + ($global:DellModelCabFiles | Where-Object {
								((($_.SupportedOperatingSystems).OperatingSystem).osCode -match $WindowsVersion) -and ($_.SupportedSystems.Brand.Model.SystemID -match $global:SkuValue)
							} | Sort-Object DateTime -Descending | Select-Object -First 1).path
						$DriverCab = ($DriverDownloadLink).Split("/") | Select-Object -Last 1
					}
					Write-DATLogEntry -Value "- Model URL is $ModelURL" -Severity 1
					Write-DATLogEntry -Value "- Driver download URL is $DriverDownloadLink" -Severity 1
					$ModelURL = $ModelURL.Replace("\", "/")
					if ($DriverCab -match ".cab") {
						$DriverRevision = $Drivercab.Split("-") | Select-Object -Last 2 | Select-Object -First 1
					} else {
						$DriverRevision = (($DriverCab.Split("_") | Select-Object -Last 1).Trim(".exe")).Trim()
					}
					Write-DATLogEntry -Value "- Dell System Model ID is : $global:SkuValue" -Severity 1
				}
				"BIOS" {
					#<code>
				}
	
			}
		}
		"HP" {
			switch ($DownloadType) {
				"Driver" {
					
					# OS matching format
					switch -wildcard ($OS) {
						"Windows 11" {
							$WindowsVersion = "Windows11"
						}
						"Windows 10" {
							$WindowsVersion = "Windows10"
						}
					}
					
					Write-DATLogEntry -Value "- Setting HP variables" -Severity 1 -UpdateUI
					if ($global:DellModelCabFiles -eq $null) {
						[xml]$DellModelXML = Get-Content -Path $(Join-Path -Path $global:TempDirectory -ChildPath $DellXMLFile) -Raw
						
						# Set XML Object
						$DellModelXML.GetType().FullName
						$global:DellModelCabFiles = $DellModelXML.driverpackmanifest.driverpackage
					}
					$global:SkuValue = (($global:DellModelCabFiles.supportedsystems.brand.model | Where-Object {
								$_.Name -eq $Model
							}).systemID) | Select-Object -Unique
					$ModelURL = $global:DellDownloadBase + "/" + ($global:DellModelCabFiles | Where-Object {
							((($_.SupportedOperatingSystems).OperatingSystem).osCode -eq $WindowsVersion) -and ($_.SupportedSystems.Brand.Model.SystemID -match $global:SkuValue)
						}).delta
					if ($global:SkuValue.Count -gt 1) {
						$DellSingleSKU = $global:SkuValue | Select-Object -First 1
						$global:SkuValue = [string]($global:SkuValue -join ";")
						Write-DATLogEntry -Value "- Using SKU : $DellSingleSKU" -Severity 1
						$ModelURL = $global:DellDownloadBase + "/" + ($global:DellModelCabFiles | Where-Object {
								((($_.SupportedOperatingSystems).OperatingSystem).osCode -match $WindowsVersion) -and ($_.SupportedSystems.Brand.Model.SystemID -match $DellSingleSKU)
							}).delta
						$DriverDownloadLink = $global:DellDownloadBase + "/" + (($global:DellModelCabFiles | Where-Object {
									((($_.SupportedOperatingSystems).OperatingSystem).osCode -match $WindowsVersion) -and ($_.SupportedSystems.Brand.Model.SystemID -match $DellSingleSKU)
								}) | Sort-Object DateTime -Descending | Select-Object -First 1).path
						$DriverCab = ($DriverDownloadLink).Split("/") | Select-Object -Last 1
						
					} else {
						$ModelURL = $global:DellDownloadBase + "/" + ($global:DellModelCabFiles | Where-Object {
								((($_.SupportedOperatingSystems).OperatingSystem).osCode -match $WindowsVersion) -and ($_.SupportedSystems.Brand.Model.SystemID -match $global:SkuValue)
							}).delta
						$DriverDownloadLink = $global:DellDownloadBase + "/" + ($global:DellModelCabFiles | Where-Object {
								((($_.SupportedOperatingSystems).OperatingSystem).osCode -match $WindowsVersion) -and ($_.SupportedSystems.Brand.Model.SystemID -match $global:SkuValue)
							} | Sort-Object DateTime -Descending | Select-Object -First 1).path
						$DriverCab = ($DriverDownloadLink).Split("/") | Select-Object -Last 1
					}
					Write-DATLogEntry -Value "- Model URL is $ModelURL" -Severity 1
					Write-DATLogEntry -Value "- Driver download URL is $DriverDownloadLink" -Severity 1
					$ModelURL = $ModelURL.Replace("\", "/")
					if ($DriverCab -match ".cab") {
						$DriverRevision = $Drivercab.Split("-") | Select-Object -Last 2 | Select-Object -First 1
					} else {
						$DriverRevision = (($DriverCab.Split("_") | Select-Object -Last 1).Trim(".exe")).Trim()
					}
					Write-DATLogEntry -Value "- Dell System Model ID is : $global:SkuValue" -Severity 1
				}
				"BIOS" {
					#<code>
				}
				
			}
		}
		"Lenovo" {
			Write-DATLogEntry -Value "- Setting Lenovo variables" -Severity 1
			#Find-DATLenovoModelType -Model $Model -OS $OS
			
			try {
				Write-DATLogEntry -Value "- $OEM $Model matching model type: $global:LenovoModelType" -Severity 1

				# OS matching format
				switch -wildcard ($OS) {
					"Windows 11*" {
						$WindowsVersion = "Win11"
						$OSVersion = $OS.Split(" ")[2]
					}
					"Windows 10*" {
						$WindowsVersion = "Win10"
						$OSVersion = $OS.Split(" ")[2]
					}
				}

				Write-DATLogEntry -Value "- Looking up version based on $WindowsVersion $OSVersion" -Severity 1
				
				switch -wildcard ($WindowsVersion) {
					"1*" {
						$DriverDownloadLink = ($global:LenovoModelDrivers | Where-Object {
								$_.Name -eq "$Model"
							}).SCCM | Where-Object {
							$_.os -match $WindowsVersion -and $_.version -match $OSVersion
						} | Select-Object -ExpandProperty "#text" -First 1
					}
					default {
						$DriverDownloadLink = ($global:LenovoModelDrivers | Where-Object {
								$_.Name -like "$Model*"
							}).SCCM | Where-Object {
							$_.Version -eq $OSVersion
						} | Select-Object -ExpandProperty "#text" -First 1
					}
				}
				
				Write-DATLogEntry -Value "- Driver Download is $DriverDownloadLink and type is $DownloadType" -Severity 1
				
				if (-not ([string]::IsNullOrEmpty($DriverDownloadLink)) -and $DownloadType -notmatch "BIOS") {
					# Fix URL malformation
					Write-DATLogEntry -Value "- Driver package URL - $DriverDownloadLink" -Severity 1
					$ModelURL = $DriverDownloadLink
					$DriverCab = $DriverDownloadLink | Split-Path -Leaf
					$DriverRevision = ($DriverCab.Split("_") | Select-Object -Last 1).Trim(".exe")
				} elseif ($DownloadType -notmatch "BIOS") {
					Write-DATLogEntry -Value "[Error] - Unable to find driver for $Make $Model" -Severity 3
				}
				$global:SkuValue = Find-DATLenovoModelType -Model $Model
				
			} catch [System.Exception] {
				Write-DATLogEntry -Value "[Error] - $($_.Exception.Message)" -Severity 3
				Write-DATLogEntry -Value "[Error] - Unable to find driver for $Make $Model" -Severity 3
			}
		}
	}
	
	# Return "Unknown" if no download link is null or empty, otherwise return the download link
	if ([string]::IsNullOrEmpty($DriverDownloadLink)) {
		return "Unknown"
	} else {
		return $DriverDownloadLink
	}
}