function Start-DATModelProcessing {
    <#
	.SYNOPSIS
		A brief description of the Start-DownloadProcess function.
	
	.DESCRIPTION
		This function starts and waits for each specified model to complete as a background job
	
	.PARAMETER $global:ScriptDirectory
		A description of the $global:ScriptDirectory parameter.
	
	.PARAMETER $global:RegPath
		A description of the $global:RegPath parameter.
	
	.PARAMETER $global:RunningMode
		A description of the $global:RunningMode parameter.
	
	.PARAMETER $global:SeletedModels
		A description of the $global:SeletedModels parameter.
	
	.EXAMPLE
		PS C:\> Start-DownloadProcess
	
	.NOTES
		Additional information about the function.
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[String]$ScriptDirectory,
		[Parameter(Mandatory = $true)]
		[String]$RegPath,
		[Parameter(Mandatory = $true)]
		[String]$RunningMode,
		[Parameter(Mandatory = $true)]
		[pscustomobject]$SeletedModels
	)
		
	# Import Module
	Import-Module -Name DriverAutomationToolCore
	Write-DATLogEntry -Value "- Running for $($global:SelectedModels.Count) models" -Severity 1
	
	# Variables
	Write-DATLogEntry -Value "- Quering registy for running details using path $global:RegPath" -Severity 1
	$RunningConfigurationValues = Get-ItemProperty -Path $global:RegPath
	$TotalJobs = ($RunningConfigurationValues).TotalJobs
	[int]$CurrentJob = ($RunningConfigurationValues).CurrentJob
	if ([string]::IsNullOrEmpty($CurrentJob)) {
		# Set initial value
		$CurrentJob = 1
	}
		
	# Downlaod content scriptblock
	$BuildPackages = {
		param (
			[parameter(Mandatory = $true)]
			[string]$global:ScriptDirectory,
			[parameter(Mandatory = $true)]
			[string]$global:RegPath,
			[parameter(Mandatory = $true)]
			[string]$global:LogDirectory,
			[parameter(Mandatory = $true)]
			[string]$global:RunningMode,
			[parameter(Mandatory = $true)]
			[pscustomobject]$global:Model
		)
		
		# Import Module
		Import-Module -Name DriverAutomationToolCore
		
		# Get OEM download sources
		Get-DATOEMModelInfo -RequiredOEMs $Model.OEM -OS $Model.OS -Architecture $Model.Architecture
		
		# Set Registry values
		Set-DATRegistryValue -Name "CurrentModel" -Value "$($Model.Model)" -Type String
		Set-DATRegistryValue -Name "CurrentOEM" -Value "$($Model.OEM)" -Type String
		Set-DATRegistryValue -Name "CurrentBaseboards" -Value "$($Model.Baseboards)" -Type String
		# Get the current running process ID
		$RunningProcessID = $PID
		Set-DATRegistryValue -Name "RunningProcessID" -Value $RunningProcessID -Type String

		
		# Obtain download link for model
		Write-DATLogEntry -Value "- Obtaining download link for $($Model.Model)" -Severity 1
		Write-DATLogEntry -Value "-- Model OEM is $($Model.OEM)"
		Write-DATLogEntry -Value "-- Model OS is $($Model.OS)"
		Write-DATLogEntry -Value "-- Model Architecture is $($Model.Architecture)"
		Write-DATLogEntry -Value "-- Model is $($Model.Model)"
		
		<#
		# Create a new PS Custom object that contains the model details
		$Model = New-Object -TypeName PSObject
		$Model | Add-Member -MemberType NoteProperty -Name "OEM" -Value "Acer" -Force
		$Model | Add-Member -MemberType NoteProperty -Name "Model" -Value "TravelMate Spin P414RN-54" -Force
		$Model | Add-Member -MemberType NoteProperty -Name "Baseboards" -Value "TravelMate Spin P414RN-54" -Force
		$Model | Add-Member -MemberType NoteProperty -Name "OS" -Value "Windows 11 24H2" -Force
		$Model | Add-Member -MemberType NoteProperty -Name "Architecture" -Value "x64" -Force
		#>
			
		# Build supported models array
		Get-DATOEMModelInfo -RequiredOEMs $Model.OEM -OS $Model.OS -Architecture $Model.Architecture
		
		# Invoke download for all OEM's except HP
		if ($($Model.OEM) -ne "HP") {
			# Get driver download
			$global:DownloadURL = Get-DATOEMDownloadLinks -OEM $Model.OEM -OS "$($Model.OS)" -Architecture $Model.Architecture -DownloadType driver -Model $Model.Model
			Write-DATLogEntry -Value "- Download URL is $global:DownloadURL" -Severity 1
			Write-DATLogEntry -Value "-- Reg path is $global:RegPath" -Severity 1
			Write-DATLogEntry -Value "-- Setitng download URL to $global:DownloadURL" -Severity 1
		}
		
		if ((-not ([string]::IsNullOrEmpty($global:DownloadURL)) -and ($global:DownloadURL -ne "Unknown")) -or ($($Model.OEM) -eq "HP")) {
			Set-DATRegistryValue -Name "DownloadURL" -Value $global:DownloadURL -Type String
			Set-DATRegistryValue -Name "RunningState" -Value "Running" -Type String
			Set-DATRegistryValue -Name "RunningMode" -Value "Download" -Type String
						
			# Get current status message from the registry
			$RunningConfigurationValues = Get-ItemProperty -Path $global:RegPath
			$CurrentOEM = ($RunningConfigurationValues).CurrentOEM
			$CurrentModel = ($RunningConfigurationValues).CurrentModel
			$CurrentOS = ($RunningConfigurationValues).OS
			$ExtractPath = ($RunningConfigurationValues).TempStoragePath
			$DriverFile = ($RunningConfigurationValues).WorkingFile
			
			# Define full download path
			$DownloadPath = Join-Path -Path "$(($RunningConfigurationValues).TempStoragePath)" -ChildPath "$CurrentOEM\$CurrentModel\$CurrentOS"
			Write-DATLogEntry -Value "- Starting invoke content download for $($global:DownloadURL) to $($DownloadPath)" -Severity 1
			
			# Invoke download for all OEM's except HP
			if ($CurrentOEM -ne "HP") {
				Invoke-DATContentDownload -DownloadURL "$global:DownloadURL" -DownloadDestination "$DownloadPath" -Verbose
			} else {
				# Obtain the first baseboard for matching process;
				$CurrentBaseboard = $($Model.Baseboards).Split(",") | Select-Object -First 1
				# Get OS version from current OS string, splitting on the second space
				$OSVersion = ($CurrentOS -split " ")[2]
				$OS = ($CurrentOS -split " ")[0..1] -join " "
				$SoftPawTempLocation = Join-Path -Path "$(($RunningConfigurationValues).TempStoragePath)" -ChildPath "$CurrentOEM\$CurrentModel\$CurrentOS\SoftPaqs"
				Write-DATLogEntry -Value "- Using $CurrentBaseboard as the matching baseboard value" -Severity 1
				Write-DATLogEntry -Value "- Using $OS as the matching OS value" -Severity 1
				Write-DATLogEntry -Value "- Using $OSVersion as the matching OS version value" -Severity 1

				try {
					Invoke-DATOEMDownloadModule -OEM "$CurrentOEM" -SystemSKU $CurrentBaseboard -WindowsBuild $OS -WindowsVersion $OSVersion  -TempDirectory $SoftPawTempLocation -DownloadDestination $DownloadPath 
				} catch {
					Write-DATLogEntry -Value "- Error invoking OEM download module: $($_.Exception.Message)" -Severity 3
					throw
				}
			}
			
			# Get current status message from the registry
			$RunningConfigurationValues = Get-ItemProperty -Path $global:RegPath
			$RunningMode = ($RunningConfigurationValues).RunningMode
			$PackageType = ($RunningConfigurationValues).PackageType
			
			# OEM specific package naming and versioning
			switch ($CurrentOEM) {
				"Acer" {
					# Driver revision in the format of YYYYMMDD
					$Version = (Get-Date).ToString("yyyyMMdd")
				}
				"HP" {
					# Driver revision in the format of YYYYMMDD
					$Version = (Get-Date).ToString("yyyyMMdd")
				}
			}
			Set-DATRegistryValue -Name "PackageVersion" -Value "$Version" -Type String
			
			if (($RunningMode -eq "Download Completed") -and ($PackageType -eq "Drivers")) {
				Set-DATRegistryValue -Name "Runningmode" -Value "Extracting" -Type String
				
				# Get current status message from the registry
				$RunningConfigurationValues = Get-ItemProperty -Path $global:RegPath
				$CurrentOEM = ($RunningConfigurationValues).CurrentOEM
				$CurrentModel = ($RunningConfigurationValues).CurrentModel
				$CurrentOS = ($RunningConfigurationValues).OS
				$ExtractPath = ($RunningConfigurationValues).TempStoragePath
				$DriverFile = ($RunningConfigurationValues).WorkingFile
				
				# Extract path with version 
				$ExtractPath = Join-Path -Path $ExtractPath -ChildPath $Version
				Write-DATLogEntry -Value "- Extract path set to $ExtractPath" -Severity 2
				
				# Call driver extract function
				Invoke-DATDriverFilePackaging -FilePath "$DriverFile" -OEM $CurrentOEM -Model $CurrentModel -Destination $ExtractPath -OS $CurrentOS
			}
			
			# Get current status message from the registry
			$RunningConfigurationValues = Get-ItemProperty -Path $global:RegPath
			$RunningMode = ($RunningConfigurationValues).RunningMode
			$PackageType = ($RunningConfigurationValues).PackageType
			$Platform = ($RunningConfigurationValues).Platform

			# Start build job
			if (($RunningMode -eq "Extract Ready") -and ($Platform -eq "Configuration Manager")) {
				Set-DATRegistryValue -Name "Runningmode" -Value "Building Driver Package" -Type String
				
				# Get current status message from the registry
				Write-DATLogEntry -Value "- Global reg path is $global:RegPath" -Severity 1
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
				
				Create-DATConfigMgrPkg -DriverPackage $DriverPackage -OEM $CurrentOEM -Model $CurrentModel -Baseboards $CurrentModelBaseboards -OS $CurrentOS -Architecture $CurrentArchitecture -PackagePath $PackagePath -SiteServer $SiteServer -SiteCode $SiteCode -Version $PackageVersion
			}
		} else {
			Set-DATRegistryValue -Name "DownloadURL" -Value "Unkown" -Type String
			Set-DATRegistryValue -Name "RunningState" -Value "Error" -Type String
			Set-DATRegistryValue -Name "RunningMode" -Value "Download" -Type String
		}
	}
	
	# Start downloads
	foreach ($Model in $global:SelectedModels) {
		# Get download URL
		#Write-LogEntry -Value "- Starting build process for model $($Model.Model)" -Severity 1
		Write-DATLogEntry -Value "- Starting build process for model $($Model.Model)" -Severity 2
		$BuildPackageJob = Start-Job -ScriptBlock $BuildPackages -Name "[$global:ProductName] - $($Model.Model) Downloads" -ArgumentList ($global:ScriptDirectory, $global:RegPath, $global:LogDirectory, $global:RunningMode, [pscustomobject]$Model) -Verbose
		
		# Wait for job to start		
		Start-Sleep -Seconds 2
		
		$BuildPackageJobId = $BuildPackageJob.Id
		$BuildPackageJobState = $BuildPackageJob.State
		
		# Monitor job
		while ($(Get-Job -Id $BuildPackageJobId | Select-Object -ExpandProperty State) -eq "Running") {
			# Wait for process1
		}
		
		$BuildPackageJobState = Get-Job -Id $BuildPackageJobId | Select-Object -ExpandProperty State
		
		switch ($BuildPackageJobState) {
			"Completed" {
				Write-DATLogEntry -Value "[Success] - Successfully completed build job for $($Model.Model)" -Severity 2
				Write-DATLogEntry -Value "- Incrementing completed model value" -Severity 2
				Set-DATRegistryValue -Name "CompletedJobs" -Value "$CurrentJob" -Type String -Verbose
				$CurrentJob++
				Set-DATRegistryValue -Name "CurrentJob" -Value $CurrentJob -Type String
			}
		}
	}
}