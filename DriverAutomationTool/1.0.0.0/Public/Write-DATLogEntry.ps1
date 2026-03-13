

function global:Write-DATLogEntry {
	<#
	.SYNOPSIS
		A brief description of the Write-LogEntry function.
	
	.DESCRIPTION
		A detailed description of the Write-LogEntry function.
	
	.PARAMETER Value
		Value added to the log file.
	
	.PARAMETER Severity
		Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.
	
	.PARAMETER LogFileName
		Name of the log file that the entry will written to.
	
	.PARAMETER UpdateUI
		Updates a custom UI if running and true value set against the log entry
	
	.PARAMETER FileName
		Name of the log file that the entry will written to.
	
	.EXAMPLE
		PS C:\> Write-DATLogEntry -Value 'Value1' -Severity 1
	
	.NOTES
		Additional information about the function.
	#>
	param
	(
		[Parameter(Mandatory = $true,
			HelpMessage = 'Value added to the log file.')]
		[ValidateNotNullOrEmpty()]
		[string]$Value,
		[Parameter(Mandatory = $false,
			HelpMessage = 'Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.')]
		[ValidateSet('1', '2', '3')]
		[ValidateNotNullOrEmpty()]
		[string]$Severity = '1',
		[Parameter(Mandatory = $false,
			HelpMessage = 'Name of the log file that the entry will written to.')]
		[ValidateNotNullOrEmpty()]
		[string]$LogFileName = "$global:ProductName.log",
		[switch]$UpdateUI
	)
	
	# Determine log file location
	$script:LogFilePath = Join-Path -Path $global:LogDirectory -ChildPath $LogFileName
	
	# Check log file size and rotate if needed (10MB limit)
	$MaxLogSizeBytes = 10MB
	if (Test-Path -Path $script:LogFilePath) {
		$LogFileSize = (Get-Item -Path $script:LogFilePath).Length
		if ($LogFileSize -ge $MaxLogSizeBytes) {
			try {
				# Create archive log name with timestamp
				$ArchiveLogName = "$($LogFileName.TrimEnd('.log'))_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
				$ArchiveLogPath = Join-Path -Path $global:LogDirectory -ChildPath $ArchiveLogName
				
				# Move current log to archive
				Move-Item -Path $script:LogFilePath -Destination $ArchiveLogPath -Force
				
				# Optionally: Keep only last 5 archived logs
				$ArchivedLogs = Get-ChildItem -Path $global:LogDirectory -Filter "$($LogFileName.TrimEnd('.log'))_*.log" | 
				Sort-Object LastWriteTime -Descending | 
				Select-Object -Skip 5
				if ($ArchivedLogs) {
					$ArchivedLogs | Remove-Item -Force
				}
			} catch {
				# If rotation fails, continue with logging to avoid breaking functionality
				Write-Warning "Failed to rotate log file: $($_.Exception.Message)"
			}
		}
	}
	
	# Construct time stamp for log entry
	$Time = -join @((Get-Date -Format "HH:mm:ss.fff"), " ", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
	
	# Construct date for log entry
	$Date = (Get-Date -Format "MM-dd-yyyy")
	
	# Construct context for log entry
	$Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
	
	# Construct final log entry
	$LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""$global:ProductName"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
	
	# Add value to log file
	try {
		Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFilePath -ErrorAction Stop
		if ($Severity -eq 1) {
			Write-Verbose -Message $Value
		} elseif ($Severity -eq 3) {
			Write-Warning -Message $Value
		}
		
		if ($UpdateUI) {
			switch ($Severity) {
				"1" {
					if ((Get-ItemProperty -Path $global:RegPath).RunningState -ne "Running") {
						Set-DATRegistryValue -Name "RunningState" -Type String -Value "Running" -Verbose
					} elseif ($Value -like "*Imaging Completed*") {
						Set-DATRegistryValue -Name "RunningState" -Type String -Value "Completed" -Verbose
					}
				}
				"3" {
					if ((Get-ItemProperty -Path $global:RegPath).RunningState -ne "Error") {
						Set-DATRegistryValue -Name "RunningState" -Type String -Value "Error"
						
					}
				}
			}
			$TrimedValue = $Value.TrimStart("- ")
			Set-DATRegistryValue -Name "RunningMessage" -Type String -Value $TrimedValue -Verbose
			
			Start-Sleep -Seconds 1
		}
	} catch [System.Exception] {
		Write-Warning -Message "Unable to append log entry to $global:ProductName.log file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
	}
}
























