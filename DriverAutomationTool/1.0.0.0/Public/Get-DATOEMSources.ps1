function Get-DATOEMSources {
	<#
		.SYNOPSIS
			A brief description of the Get-OEMSources function.

		.DESCRIPTION
			This function loads in the OEM sources from a control file in GitHub

		.EXAMPLE
					PS C:\> Get-DATOEMSources

		.NOTES
			Additional information about the function.
	#>
	[CmdletBinding()]
	param ()
	
	try {
		Write-DATLogEntry -Value "[OEM Source Check] - Testing path $global:SettingsDirectory" -Severity 1 -UpdateUI
		$global:OEMXMLPath = Join-Path $global:SettingsDirectory -ChildPath "OEMLinks.xml"
		if (-not ([boolean](Test-Path -Path $OEMXMLPath -ErrorAction SilentlyContinue) -eq $true)) {
			Write-DATLogEntry -Value "- OEM Links: Downloading OEMLinks XML from $OEMLinksURL" -Severity 1 -UpdateUI
			(Invoke-WebRequest -Uri "$OEMLinksURL" -UseBasicParsing).Content | Out-File -FilePath $OEMXMLPath
			[xml]$OEMLinks = Get-Content -Path $OEMXMLPath
		} else {
			[version]$OEMCurrenVersion = ([XML]((Invoke-WebRequest -Uri "$OEMLinksURL" -UseBasicParsing).Content)).OEM.Version
			[version]$OEMDownloadedVersion = ([XML](Get-Content -Path $OEMXMLPath)).OEM.Version
			Write-DATLogEntry -Value "- Comparing online to locally available version" -Severity 1 -UpdateUI
			if ($OEMDownloadedVersion -lt $OEMCurrenVersion) {
				Write-DATLogEntry -Value "- OEM Links: Downloading updated OEMLinks XML ($OEMCurrenVersion)" -Severity 1 -UpdateUI
				(Invoke-WebRequest -Uri "$OEMLinksURL" -UseBasicParsing).Content | Out-File -FilePath $OEMXMLPath -Force
			}
		}
		Write-DATLogEntry -Value "- OEM Links: Reading OEMLinks XML from $OEMXMLPath" -Severity 1 -UpdateUI
		[xml]$OEMLinks = Get-Content -Path $OEMXMLPath
		
		# Set OEM variables
		
		if ($OEMLinks -gt $null) {
			
			# // =================== DELL Variables ================ //
			Write-DATLogEntry -Value "- Setting Dell variables" -Severity 1
			
			# Define Dell Download Sources
			$global:DellDownloadList = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "DownloadList" } | Select-Object -ExpandProperty URL
			$global:DellDownloadBase = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "DownloadBase" } | Select-Object -ExpandProperty URL
			$global:DellDriverListURL = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "DriversList" } | Select-Object -ExpandProperty URL
			$global:DellBaseURL = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "BaseURL" } | Select-Object -ExpandProperty URL
			$global:Dell64BIOSUtil = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Dell" }).Link | Where-Object { $_.Type -eq "BIOSUtility" } | Select-Object -ExpandProperty URL
			
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
			
			# Define Dell Global Variables
			New-Variable -Name "DellCatalogXML" -Value $null -Scope Global
			New-Variable -Name "DellModelXML" -Value $null -Scope Global
			New-Variable -Name "DellModelCabFiles" -Value $null -Scope Global
						
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
			
			# // =================== LENOVO VARIABLES ================ //
			Write-DATLogEntry -Value "- Setting Lenovo variables" -Severity 1
			
			# Define Lenovo Download Sources
			$LenovoXMLSource = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Lenovo" }).Link | Where-Object { $_.Type -eq "XMLSource" } | Select-Object -ExpandProperty URL
			$LenovoBIOSBase = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Lenovo" }).Link | Where-Object { $_.Type -eq "BIOSBase" } | Select-Object -ExpandProperty URL
			$LenovoXMLCabFile = $LenovoXMLSource | Split-Path -Leaf
			$LenovoXMLFile = [string]($LenovoXMLSource | Split-Path -Leaf)
			
			# Define Lenovo Global Variables
			New-Variable -Name "LenovoModelDrivers" -Value $null -Scope Global
			New-Variable -Name "LenovoModelXML" -Value $null -Scope Global
			New-Variable -Name "LenovoModelType" -Value $null -Scope Global
			New-Variable -Name "LenovoSystemSKU" -Value $null -Scope Global
			
			# // =================== MICROSOFT VARIABLES ================ //
			Write-DATLogEntry -Value "- Setting Microsoft variables" -Severity 1
			# Define Microsoft Download Sources
			$MicrosoftJSONSource = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Microsoft" }).Link | Where-Object { $_.Type -eq "JSONSource" } | Select-Object -ExpandProperty URL
			$MicrosoftBaseURL = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Microsoft" }).Link | Where-Object { $_.Type -eq "BaseURL" } | Select-Object -ExpandProperty URL
			$MicrosoftSurfaceDriverSupportURL = ($OEMLinks.OEM.Manufacturer | Where-Object { $_.Name -match "Microsoft" }).Link | Where-Object { $_.Type -eq "SurfaceDriverSupportURL" } | Select-Object -ExpandProperty URL
			
			# // =================== COMMON VARIABLES ================ //
			# ArrayList to store models in
			$DellProducts = New-Object -TypeName System.Collections.ArrayList
			$DellKnownProducts = New-Object -TypeName System.Collections.ArrayList
			$HPProducts = New-Object -TypeName System.Collections.ArrayList
			$HPKnownProducts = New-Object -TypeName System.Collections.ArrayList
			$LenovoProducts = New-Object -TypeName System.Collections.ArrayList
			$LenovoKnownProducts = New-Object -TypeName System.Collections.ArrayList
			$MicrosoftModels = New-Object -TypeName System.Collections.ArrayList
			$MicrosoftKnownProducts = New-Object -TypeName System.Collections.ArrayList
			$XMLSelectedModels = New-Object System.Collections.Generic.List[System.Object]
			$XMLSelectedDPs = New-Object System.Collections.Generic.List[System.Object]
			$XMLSelectedDPGs = New-Object System.Collections.Generic.List[System.Object]
		} else {
			Write-DATLogEntry -Value "[Fatal Error] - Unable to read OEM links XML" -Severity 3
		}
		
	} catch {
		Write-DATLogEntry -Value "[XML Source Error] - $($_.Exception.Message)" -Severity 3
	}
}
