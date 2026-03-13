function Invoke-DATDriverFilePackaging {
	param
	(
		[Parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath,
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
		[string]$Destination,
		[ValidateSet('Configuration Manager', 'Intune', 'Download Only')]
		[string]$Platform
	)
	
	try {
		# Create a new folder for the OS, testing if the folder already exists
		$DriverFolder = Join-Path -Path $Destination -ChildPath "$OEM\$Model\$OS\Extracted"
		if (-not (Test-Path -Path $DriverFolder)) {
			New-Item -Path $DriverFolder -ItemType Directory -Force | Out-Null
		}
		
	} catch {
		Write-DATLogEntry -Value "[Error] - Failed to create driver folder $DriverFolder" -Severity 3
	}
	
	# Continue if the folder was created successfully, by testing if the folder exists
	if (Test-Path -Path $DriverFolder) {
		# Extract the driver package using a switch statement to determine the file type
		switch -Wildcard ($FilePath) {
			"*.exe" {
				# Extract the driver package
				Write-DATLogEntry -Value "- Extracting driver package from $FilePath" -Severity 1
				Invoke-DATExecutable -FilePath $FilePath -Arguments "/s /e=`"$DriverFolder`"" | Out-Null
				
				<#
				global:Write-LogEntry -Value "- $($Product): Dell EXE format detected" -Severity 1
				$DellSilentSwitches = "/s /e=" + '"' + $DriverExtractDest + '"'
				global:Write-LogEntry -Value "- $($Product): Using $Make silent switches: $DellSilentSwitches" -Severity 1
				global:Write-LogEntry -Value "- $($Product): Extracting $Make drivers to $DriverExtractDest" -Severity 1
				Unblock-File -Path $($DownloadRoot + $Model + '\Driver Cab\' + $DriverCab)
				Start-Process -FilePath "$($DownloadRoot + $Model + '\Driver Cab\' + $DriverCab)" -ArgumentList $DellSilentSwitches -Verb RunAs
				$DriverProcess = ($DriverCab).Substring(0, $DriverCab.length - 4)
				# Wait for Lenovo Driver Process To Finish
				While ((Get-Process).name -contains $DriverProcess)
				{
					global:Write-LogEntry -Value "- $($Product): Waiting for extract process (Process: $DriverProcess) to complete..  Next check in 30 seconds" -Severity 1
					Start-Sleep -seconds 30
				}
				#>
				
			}
			"*.msi" {
				# Extract the driver package
				Write-DATLogEntry -Value "- Extracting driver package from $FilePath" -Severity 1
				Invoke-DATExecutable -FilePath $FilePath -Arguments "/a $DriverFolder" | Out-Null
			}
			"*.zip" {
				# Extract the driver package
				Write-DATLogEntry -Value "- Extracting driver package from $FilePath" -Severity 1
				Expand-Archive -Path $FilePath -DestinationPath $DriverFolder -Force | Out-Null
			}
			"*.cab" {
				try {
					# Extact the driver package and monitor for exit code
					Write-DATLogEntry -Value "- Extracting driver cab from $FilePath" -Severity 1 -UpdateUI
					$ExtractProcessPath = "C:\Windows\System32\expand.exe"
					$ExtractProcess = Start-Process -FilePath $ExtractProcessPath -ArgumentList "`"$FilePath`" -F:* `"$DriverFolder`"" -WindowStyle Hidden -PassThru -Wait
					
					# Wait for the extract process to complete
					while ([boolean](Get-Process -Id $ExtractProcess.Id -ErrorAction SilentlyContinue)) {
						# Wait for the process to complete
					}
					
					Write-DATLogEntry -Value "- Extract process terminated with exit code $($ExtractProcess.ExitCode)" -Severity 1
					
					# Check if the process completed successfully
					if ($ExtractProcess.ExitCode -eq 0) {
						Write-DATLogEntry -Value "- Successfully extracted driver package from $FilePath" -Severity 1 -UpdateUI
						
						# perform a recursive check for an x64 folder, up to 2 levels deep, and move the folder to the root
						Write-DATLogEntry -Value "- Moving items from $DriverFolder to parent path $DriverFolder to shorten folder paths" -Severity 1
						Get-ChildItem -Path $DriverFolder -Directory -Recurse -Depth 2 | Where-Object { $_.Name -match "x64" } | Move-Item -Destination $DriverFolder -Force
						
						# Cleanup folder
						if ((-not ([string]::IsNullOrEmpty($DriverFolder))) -and ([boolean](Test-Path -Path $DriverFolder -ErrorAction SilentlyContinue) -eq $true)) {
							# Only keep the x64 folder and its subfolders, clean up the rest
							Get-ChildItem -Path $DriverFolder -Directory | Where-Object { $_.Name -ne "x64" } | Remove-Item -Recurse -Force
						}
						
					} else {
						Write-DATLogEntry -Value "[Error] - Failed to extract driver package from $FilePath" -Severity 3
					}
				} catch {
					Write-DATLogEntry -Value "[Error] - Failed to extract driver package from $FilePath" -Severity 3
				}
			}
		}
	}
	
	# Create a .wim file using DISM with the contents from the driver package
	try {
		# Create a temporary mount folder for the driver package
		$DriverMountFolder = Join-Path -Path $Destination -ChildPath "Packaged\$OEM\$Model\$OS"
		if (-not (Test-Path -Path $DriverMountFolder)) {
			New-Item -Path $DriverMountFolder -ItemType Directory -Force | Out-Null
		}
		
		$WimDescription = "$OEM $Model $OS Driver Package"
		$WimFile = Join-Path -Path $DriverMountFolder -ChildPath "DriverPackage.wim"
		Write-DATLogEntry -Value "- DriverPackage: Mounting UNC path for WIM creation" -Severity 1 -UpdateUI
		
		$DismArgs = "/Capture-Image /ImageFile:`"$WimFile`" /CaptureDir:`"$DriverFolder`" /Name:`"$WimDescription`" /Description:`"$WimDescription`" /Compress:max"
		Write-DATLogEntry -Value "[DISM] - DriverPackage: DISM initiated with the following args- $DismArgs" -Severity 1 -UpdateUI
		$DismProcess = Start-Process "dism.exe" -ArgumentList $DismArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput .\DismAction.log -RedirectStandardError .\DismErrors.log
		
		if ($($DismProcess.ExitCode) -eq 0) {
			Write-DATLogEntry -Value "- DriverPackage: DISM process completed successfully" -Severity 1 -UpdateUI
			Set-DATRegistryValue -Name "PackagedDriverPath" -Value "$WimFile" -Type String
			Set-DATRegistryValue -Name "RunningMode" -Value "Extract Ready" -Type String
		} else {
			Write-DATLogEntry -Value "- DriverPackage: DISM process failed with exit code $($DismProcess.ExitCode)" -Severity 3 -UpdateUI
			Set-DATRegistryValue -Name "RunningState" -Value "Error" -Type String
			Set-DATRegistryValue -Name "RunningMode" -Value "ExtractFailure" -Type String
		}

	} catch {
		Write-DATLogEntry -Value "[Error] - Errors occured while attempting to create wim file." -Severity 3
	}
	
	# Call platformm specific function for Configuration Manager and Intune jobs
	switch -wildcard ($Platform) {
		"Config*" {
			#<code>
		}
		"Intune" {
			#<code>
		}
	}
}