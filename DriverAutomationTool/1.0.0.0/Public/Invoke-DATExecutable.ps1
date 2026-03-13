function Invoke-DATExecutable {
	param (
		[parameter(Mandatory = $true, HelpMessage = "Specify the file name or path of the executable to be invoked, including the extension")]
		[ValidateNotNullOrEmpty()]
		[string]$FilePath,
		[parameter(Mandatory = $false, HelpMessage = "Specify arguments that will be passed to the executable")]
		[ValidateNotNull()]
		[string]$Arguments
	)
	
	# Unlock file for execution
	Unblock-File -Path "$FilePath"
	
	# Construct a hash-table for default parameter splatting
	$SplatArgs = @{
		FilePath    = "$FilePath"
		NoNewWindow = $true
		Passthru    = $true
		ErrorAction = "Stop"
	}
	
	# Add ArgumentList param if present
	if (-not ([System.String]::IsNullOrEmpty($Arguments))) {
		$SplatArgs.Add("ArgumentList", "$Arguments")
	}
	
	# Invoke executable and wait for process to exit
	try {
		Write-DATLogEntry -Value "[Package Execution] - Running $FilePath and arguments $Arguments" -Severity 1
		$Invocation = Start-Process @SplatArgs
		$InvoationnPID = $Invocation.Id
		Write-DATLogEntry -Value "- Waiting in Process ID:$InvoationnPID to complete."
		$Invocation.WaitForExit()
	} catch [System.Exception] {
		Write-DATLogEntry -Value "[Error] - Failed to complete exection. $_.Exception.Message" -Severity 3; break
	}
	
	Write-DATLogEntry -Value "- Execution completed with exit code $($Invocation.ExitCode)" -Severity 1
	return $Invocation.ExitCode
}