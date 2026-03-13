function Get-DATOEMModelInfo {
	[CmdletBinding()]
	param
	(
		[Parameter(Position = 1)]
		[ValidateSet('HP', 'Dell', 'Lenovo', 'Microsoft', 'Acer')]
		[array]$RequiredOEMs,
		[Parameter(Position = 2)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('Windows 11 25H2', 'Windows 11 24H2', 'Windows 11 23H2', 'Windows 11 22H2', 'Windows 11', 'Windows 10 22H2')]
		[string]$OS,
		[Parameter(Position = 3)]
		[ValidateSet('x64', 'x86', 'Arm64')]
		[string]$Architecture
	)
	
	# Call source link function
	Write-DATLogEntry -Value "[OEM Links] - Reading OEM links" -Severity 1
	
	$OEMLinksURL = "https://raw.githubusercontent.com/maurice-daly/DriverAutomationTool/master/Data/OEMLinks.xml"
	
	# OEM Links Master File
	try {
		Write-DATLogEntry -Value "[OEM Links Check] - Reading OEM links from $OEMLinksURL " -Severity 1
		[xml]$OEMLinks = (Invoke-WebRequest -Uri "$OEMLinksURL" -UseBasicParsing).Content
	} catch {
		Write-DATLogEntry -Value "[Error] - An error occured while attepting to read in the OEM links XML" -Severity 3 -UpdateUI
		Write-DATLogEntry -Value "- Raw message detail - `"$($_.Exception.Message)`"" -Severity 3 -UpdateUI
	}
	
	# Set Temp & Log Location	
	if ((Test-Path -Path $global:TempDirectory) -eq $false) {
		Write-DATLogEntry -Value "- Creating temp directory at path $global:TempDirectory" -Severity 1
		New-Item -Path $global:TempDirectory -ItemType dir | Out-Null
	}
	
	# Split OS Name
	#Write-Host "Selected OS is $($OSList.Text)"
	$WindowsBuild = $($OS).Split(" ")[2]
	$WindowsVersion = $OS.Trim("$WindowsBuild").TrimEnd()
	
	Write-DATLogEntry -Value "- Windows build is $WindowsBuild and version is $WindowsVersion" -Severity 1
	
	# Create supported model array
	$OEMSupportedModels = @()
	
	if ($OEMSupportedModels.Count -gt 0) {
		# Clear array
		$OEMSupportedModels.Clear()
	}
	
	foreach ($OEM in $RequiredOEMs) {
		Write-DATLogEntry -Value "- Loading $OEM model compatibility" -Severity 1
		switch ($OEM) {
			"HP" {
				# Set OEM Name
				$OEM = "HP"
				
				# Import required OEM PS module(s)
				try {
					# Import HP CMSL module
					Import-Module HPCMSL
				} catch [System.Exception] {
					Write-DATLogEntry -Value "[Error] - An error occured while attempting to import the required HP PS module" -Severity 3 -UpdateUI
					Write-DATLogEntry -Value "- Raw message detail - `"$($_.Exception.Message)`"" -Severity 3 -UpdateUI
				}
				
				# Define HP Download Sources
				$HPXMLCabinetSource = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "HP" }).Link | Where-Object { $_.Type -eq "XMLCabinetSource" } | Select-Object -ExpandProperty URL
				$HPSoftPaqSource = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "HP" }).Link | Where-Object { $_.Type -eq "SoftPaqSource" } | Select-Object -ExpandProperty URL
				$HPPlatFormList = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "HP" }).Link | Where-Object { $_.Type -eq "PlatFormList" } | Select-Object -ExpandProperty URL
				$HPSoftPaqCab = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "HP" }).Link | Where-Object { $_.Type -eq "SoftPaqCab" } | Select-Object -ExpandProperty URL
				
				# Define HP Cabinet/XL Names and Paths
				$HPCabFile = [string]($HPXMLCabinetSource | Split-Path -Leaf)
				$HPXMLFile = $HPCabFile.TrimEnd(".cab")
				$HPXMLFile = $HPXMLFile + ".xml"
				
				# Content path
				$HPXMLFilePath = Join-Path -Path $global:TempDirectory -ChildPath $HPXMLFile
				
				if ($HPModelSoftPaqs -eq $null) {
					# Download HP product catalog
					try {
						Write-DATLogEntry -Value "- Downloading $HPXMLCabinetSource" -Severity 1
						Invoke-DATContentDownload -DownloadURL $HPXMLCabinetSource -DownloadDestination $global:TempDirectory
						Write-DATLogEntry -Value "- Download background job state is $($global:DownloadBackgroundJob.State)" -Severity 1						
						Write-DATLogEntry -Value "- Expanding cabinet file $($global:TempDirectory)\$($HPCabFile)" -Severity 1
						Write-DATLogEntry -Value "- Destintation $($global:TempDirectory)" -Severity 1
						Expand "$global:TempDirectory\$HPCabFile" -F:* "$global:TempDirectory" -R | Out-Null
						$HPModelXMLPath = $(Join-Path -Path $global:TempDirectory -ChildPath $HPXMLFile)
						Write-DATLogEntry -Value "- Reading cabinet file from $HPModelXMLPath" -Severity 1
						[xml]$HPModelXML = Get-Content -Path "$HPModelXMLPath" -Raw
						$HPModelSoftPaqs = $HPModelXML.NewDataSet.HPClientDriverPackCatalog.ProductOSDriverPackList.ProductOSDriverPack
						Write-DATLogEntry -Value "- A total of $(($HPModelSoftPaqs | Select-Object SystemName).Count) models identified" -Severity 1
						Write-DATLogEntry -Value "- Outputting supported model information file" -Severity 1
						$HPModelSoftPaqs | Select-Object SystemName, SystemId | ConvertTo-Json | Out-File -FilePath $(Join-Path -Path $global:TempDirectory -ChildPath "HPModelMetadata.json") -Encoding ascii -Force
					} catch [System.Exception] {
						Write-DATLogEntry -Value "[Error] - An error occured while attempting to obtain a list of HP models" -Severity 3 -UpdateUI
						Write-DATLogEntry -Value "- Raw message detail - `"$($_.Exception.Message)`"" -Severity 3 -UpdateUI
					}
				}
				
				if ($HPModelSoftPaqs -ne $null) {
					# Create new array
					Write-DATLogEntry -Value "- Creating array for HP device matching" -Severity 1
					$HPOSSupportedPacks = New-Object -TypeName System.Collections.ArrayList
					
					# Create smaller array of supported products
					Write-DATLogEntry -Value "- Adding drivers for $WindowsVersion $WindowsBuild to array" -Severity 1
					
					$HPOSSupportedPacks = $HPModelSoftPaqs | Where-Object { $_.OSName -match $WindowsVersion -and $_.OSName -match $WindowsBuild }
					Write-DATLogEntry -Value "- Adding a total of $($HPOSSupportedPacks.Count) supported driver packages" -Severity 1
					foreach ($Model in $HPOSSupportedPacks) {
						
						# Remove HP from model name
						$Model.SystemName = $($($Model.SystemName).TrimStart($OEM)).Trim()
						
						# Update array
						$ModelDetails = New-Object -TypeName PSObject
						$ModelDetails | Add-Member -MemberType NoteProperty -Name "OEM" -Value "$OEM" -Force
						$ModelDetails | Add-Member -MemberType NoteProperty -Name "Model" -Value "$($Model.SystemName)" -Force
						$ModelDetails | Add-Member -MemberType NoteProperty -Name "Baseboards" -Value "$($Model.SystemId)" -Force
						$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS" -Value "$WindowsVersion" -Force
						$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS Build" -Value "$WindowsBuild" -Force
						
						$OEMSupportedModels += $ModelDetails
					}
				}
			}
			"Dell" {
				# Download Dell product catalog
				try {
					# Set variables
					$OEM = "Dell"
					
					# Define Dell Download Sources
					$DellDownloadList = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "DownloadList" } | Select-Object -ExpandProperty URL
					$DellDownloadBase = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "DownloadBase" } | Select-Object -ExpandProperty URL
					$DellDriverListURL = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "DriversList" } | Select-Object -ExpandProperty URL
					$DellBaseURL = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "BaseURL" } | Select-Object -ExpandProperty URL
					$Dell64BIOSUtil = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "BIOSUtility" } | Select-Object -ExpandProperty URL
					
					# Define Dell Download Sources
					$DellXMLCabinetSource = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "XMLCabinetSource" } | Select-Object -ExpandProperty URL
					$DellCatalogSource = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "CatalogSource" } | Select-Object -ExpandProperty URL
					
					# Define Dell Cabinet/XL Names and Paths
					$DellCabFile = [string]($DellXMLCabinetSource | Split-Path -Leaf)
					$DellCatalogFile = [string]($DellCatalogSource | Split-Path -Leaf)
					$DellXMLFile = $DellCabFile.TrimEnd(".cab")
					$DellXMLFile = $DellXMLFile + ".xml"
					$DellCatalogXMLFile = $DellCatalogFile.TrimEnd(".cab") + ".xml"
					$DellFlashExtracted = $false
					$DellCabFilePath = (Join-Path -Path "$global:TempDirectory" -ChildPath "$DellCabFile")
					
					# Windows Build Dell formatting
					$WindowsVersion = $WindowsVersion.Replace(" ", "")
					
					Write-DATLogEntry -Value "- Checking for previously downloaded cab file - $DellCabFile in path $($global:TempDirectory)" -Severity 1
					if ((Test-Path -Path (Join-Path -Path "$global:TempDirectory" -ChildPath "$DellCabFile")) -eq $false) {
						Write-DATLogEntry -Value "- Downloading Dell product cabinet file from $DellXMLCabinetSource" -Severity 1
						
						# Download Dell Model Cabinet File
						try {
							Invoke-DATContentDownload -DownloadURL $DellXMLCabinetSource -DownloadDestination $global:TempDirectory							
						} catch {
							Write-DATLogEntry -Value "[Error] - Downloading $OEM driver catalog - $($_.Exception.Message)" -Severity 3
						}
					}
					
					Write-DATLogEntry -Value "- Expanding Dell driver pack cabinet file: $DellCabFilePath" -Severity 1
					if ([boolean](Test-Path -Path $DellCabFilePath -ErrorAction SilentlyContinue) -eq $true) {
						# Download Dell Model Cabinet File
						try {
							# Expand Cabinet File
							Write-DATLogEntry -Value "- Expanding Dell driver pack cabinet file: $DellXMLFile" -Severity 1
							Expand "$global:TempDirectory\$DellCabFile" -F:* "$global:TempDirectory" -R | Out-Null
						} catch {
							Write-DATLogEntry -Value "[Error] - Expanding $OEM $DellXMLFile - $($_.Exception.Message)" -Severity 3
						}
					}
					
					if ($global:DellModelXML -eq $null) {
						# Read XML File
						Write-DATLogEntry -Value "- Reading Dell driver pack XML file - $global:TempDirectory\$DellXMLFile" -Severity 1
						[xml]$global:DellModelXML = Get-Content -Path (Join-Path -Path "$global:TempDirectory" -ChildPath $DellXMLFile) -Raw
						
						# Set XML Object
						$global:DellModelXML.GetType().FullName
					}
					$global:DellModelCabFiles = $global:DellModelXML.driverpackmanifest.driverpackage
					# Find Models Contained Within Downloaded XML
					if (($ArchitectureComboxBox).Text -ne $null) {
						switch -wildcard ($ArchitectureComboxBox.Text) {
							"*32*" {
								$Architecture = "x86"
							}
							"*64*" {
								$Architecture = "x64"
							}
						}
					}
					Write-DATLogEntry -Value "- Looking up $OEM models compatible with $WindowsVersion $Architecture" -Severity 1
					$DellModels = $global:DellModelCabFiles | Where-Object {
						($_.SupportedOperatingSystems.OperatingSystem.osCode -eq "$WindowsVersion") -and ($_.SupportedOperatingSystems.OperatingSystem.osArch -match $Architecture)
					} | Select-Object @{
						Name = "SystemName"; Expression = {
							$_.SupportedSystems.Brand.Model.name | Select-Object -First 1
						}
					}, @{
						Name = "SystemID"; Expression = {
							$_.SupportedSystems.Brand.Model.SystemID
						}
					} -Unique | Where-Object {
						$_.SystemName -gt $null
					}
					
					# Sort models
					$DellModels = $DellModels | Sort-Object SystemName -Descending
					
					foreach ($Model in $DellModels) {
						# Update array
						$ModelDetails = New-Object -TypeName PSObject
						$ModelDetails | Add-Member -MemberType NoteProperty -Name "OEM" -Value "$OEM" -Force
						$ModelDetails | Add-Member -MemberType NoteProperty -Name "Model" -Value "$($Model.SystemName)" -Force
						$ModelDetails | Add-Member -MemberType NoteProperty -Name "Baseboards" -Value "$($Model.SystemId)" -Force
						$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS" -Value "$WindowsVersion" -Force
						$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS Build" -Value "$WindowsBuild" -Force
						
						$OEMSupportedModels += $ModelDetails
					}
				} catch [System.Exception] {
					Write-DATLogEntry -Value "[Error] - An error occured while attempting to obtain a list of HP models" -Severity 3 -UpdateUI
					Write-DATLogEntry -Value "- Raw message detail - `"$($_.Exception.Message)`"" -Severity 3 -UpdateUI
				}
			}
			"Lenovo" {
				# Set variables
				$OEM = "Lenovo"
				
				# Define Lenovo Download Sources
				$LenovoXMLSource = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Lenovo" }).Link | Where-Object { $_.Type -eq "XMLSource" } | Select-Object -ExpandProperty URL
				$LenovoBIOSBase = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Lenovo" }).Link | Where-Object { $_.Type -eq "BIOSBase" } | Select-Object -ExpandProperty URL
				$LenovoXMLCabFile = $LenovoXMLSource | Split-Path -Leaf
				$LenovoXMLFile = [string]($LenovoXMLSource | Split-Path -Leaf)
				
				try {
					if ((Test-Path -Path $global:TempDirectory\$LenovoXMLCabFile) -eq $false) {
						Write-DATLogEntry -Value "======== Downloading Lenovo Catalog ========" -Severity 1
						# Download HP Model Cabinet File
						Write-DATLogEntry -Value "- Downloading Lenovo XML catalog from $LenovoXMLSource" -Severity 1
						Invoke-DATContentDownload -DownloadURL $LenovoXMLSource -DownloadDestination $global:TempDirectory
					}
					[xml]$global:LenovoModelXML = Get-Content -Path $(Join-Path -Path $global:TempDirectory -ChildPath $LenovoXMLCabFile)
					# Read Web Site
					Write-DATLogEntry -Value "- Reading driver pack URL - $LenovoXMLSource" -Severity 1
					# Set XML Object
					$global:LenovoModelDrivers = $global:LenovoModelXML.ModelList.Model
					
					# Find Models Contained Within Downloaded XML
					if (-not ([string]::IsNullOrEmpty($WindowsBuild))) {
						$LenovoModels = ($global:LenovoModelDrivers | Where-Object {
								($_.SCCM.Version -eq $WindowsBuild -and $_.SCCM.OS -eq $("Win" + "$($WindowsVersion.Split(' ')[1])"))
							} | Sort-Object).Name
					} else {
						$LenovoModels = ($global:LenovoModelDrivers | Where-Object {
								($_.SCCM.Version -eq "*")
							} | Sort-Object).Name
					}
					
					if ($LenovoModels -ne $null) {
						foreach ($Model in $LenovoModels) {
							# Uncomment for debugging
							# Write-DATLogEntry -Value "- Adding $Model" -Severity 1

							$BaseboardValues = ([string]$(Find-DATLenovoModelType -Model $Model)).Replace(" ", ",").Trim()
							
							# Update array
							$ModelDetails = New-Object -TypeName PSObject
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "OEM" -Value "$OEM" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "Model" -Value "$Model" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "Baseboards" -Value "$BaseboardValues" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS" -Value "$WindowsVersion" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS Build" -Value "$WindowsBuild" -Force
							
							$OEMSupportedModels += $ModelDetails
						}
					}
				} catch {
					Write-DATLogEntry -Value "[Error] - $($_.Exception.Message)" -Severity 3
				}
			}
			"Acer" {
				# Set variables
				$OEM = "Acer"
				
				# Define Acer Download Sources
				$AcerXMLSource = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Acer" }).Link | Where-Object { $_.Type -eq "XMLSource" } | Select-Object -ExpandProperty URL
				$AcerXMLFile = [string]($AcerXMLSource | Split-Path -Leaf)
				
				try {
					if ((Test-Path -Path $global:TempDirectory\$AcerXMLFile) -eq $false) {
						Write-DATLogEntry -Value "[Acer OEM] - Downloading Acer Catalog ========" -Severity 1
						# Download HP Model Cabinet File
						Write-DATLogEntry -Value "- Downloading Acer XML catalog from $AcerXMLSource" -Severity 1
						Invoke-DATContentDownload -DownloadURL $AcerXMLSource -DownloadDestination $global:TempDirectory
						
						while ((Get-Job -Id $global:DownloadBackgroundJobID).State -eq "Running") {
							# Wait for process
						}
						
						if ((Get-Job -Id $global:DownloadBackgroundJobID).State -eq "Completed") {
							# Set running state to completed
							Write-DATLogEntry -Value "- File downloaded successfully. Removing background job $global:DownloadBackgroundJobID." -Severity 1
							#Get-Job -Id $global:DownloadBackgroundJobID | Receive-Job | Remove-Job
						}
					}
					[xml]$global:AcerModelXML = Get-Content -Path $(Join-Path -Path $global:TempDirectory -ChildPath $AcerXMLFile)
					# Read Web Site
					Write-DATLogEntry -Value "- Reading driver pack file - $AcerXMLFile" -Severity 1
					# Set XML Object
					$global:AcerModelDrivers = $global:AcerModelXML.ModelList.Model
					
					# Find Models Contained Within Downloaded XML
					if (-not ([string]::IsNullOrEmpty($WindowsBuild))) {
						$AcerModels = ($global:AcerModelDrivers | Where-Object {
								($_.SCCM.Version -eq $WindowsBuild -and $_.SCCM.OS -eq $("Win" + "$($WindowsVersion.Split(' ')[1])"))
							} | Sort-Object).Name
					} else {
						$AcerModels = ($global:AcerModelDrivers | Where-Object {
								($_.SCCM.Version -eq "*")
							} | Sort-Object).Name
					}
					
					if ($AcerModels -ne $null) {
						foreach ($Model in $AcerModels) {
							# Uncomment for debugging
							# Write-DATLogEntry -Value "- Adding $Model" -Severity 1
							
							# Update array
							$ModelDetails = New-Object -TypeName PSObject
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "OEM" -Value "$OEM" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "Model" -Value "$Model" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "Baseboards" -Value "$Model" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS" -Value "$WindowsVersion" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS Build" -Value "$WindowsBuild" -Force
							$OEMSupportedModels += $ModelDetails
						}
					}
				} catch {
					Write-DATLogEntry -Value "[Error] - $($_.Exception.Message)" -Severity 3
				}
			}
			"Microsoft" {
				# Set variables
				$OEM = "Microsoft"
				
				# Define Microsoft Download Sources
				$MicrosoftJSONSource = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Microsoft" }).Link | Where-Object { $_.Type -eq "JSONSource" } | Select-Object -ExpandProperty URL
				$MicrosoftBaseURL = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Microsoft" }).Link | Where-Object { $_.Type -eq "BaseURL" } | Select-Object -ExpandProperty URL
				$MicrosoftSurfaceDriverSupportURL = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Microsoft" }).Link | Where-Object { $_.Type -eq "SurfaceDriverSupportURL" } | Select-Object -ExpandProperty URL
				
				try {
					Write-DATLogEntry -Value "[Microsoft OEM] - Catalog ========" -Severity 1
					# Download HP Model Cabinet File
					Write-DATLogEntry -Value "- Reading Microsoft JSON catalog from $MicrosoftJSONSource" -Severity 1
					$MicrosoftJsonDetails = Invoke-WebRequest -Uri $MicrosoftJSONSource -TimeoutSec 5
					Write-DATLogEntry -Value "- Reading driver pack details - $MicrosoftJSONSource" -Severity 1
					$global:MicrosoftModelList = $MicrosoftJsonDetails | ConvertFrom-Json
					
					Write-DATLogEntry -Value "- Looking up $WindowsVersion $WindowsBuild long build number" -Severity 1
					$WindowsBuildNumber = ($WindowsBuildHashTable.Item("$WindowsBuild")).Split(".")[2]
					
					Write-DATLogEntry -Value "- Finding matching models for $WindowsVersion $WindowsBuildNumber" -Severity 1
					$MicrosoftModels = ($global:MicrosoftModelList | Where-Object {
							($_.OSVersion -match $WindowsVersion -and $_.FileName -match $WindowsBuildNumber)
						} | Select-Object Model, Product -Unique)
					
					if ($MicrosoftModels -ne $null) {
						foreach ($Model in $MicrosoftModels) {
							# Uncomment for debugging
							Write-DATLogEntry -Value "- Adding $Model" -Severity 1
							$BaseboardValues = ([string]$(Find-DATLenovoModelType -Model $Model)).Replace(" ", ",").Trim()
							
							# Update array
							$ModelDetails = New-Object -TypeName PSObject
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "OEM" -Value "$OEM" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "Model" -Value "$Model" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "Baseboards" -Value "$BaseboardValues" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS" -Value "$WindowsVersion" -Force
							$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS Build" -Value "$WindowsBuild" -Force
							
							$OEMSupportedModels += $ModelDetails
						}
					}
				} catch {
					Write-DATLogEntry -Value "[Error] - $($_.Exception.Message)" -Severity 3
				}
			}
		}
	}
	
	# Output full supported model array
	return [array]$OEMSupportedModels
}