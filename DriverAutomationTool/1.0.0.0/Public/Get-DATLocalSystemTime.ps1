function Get-DATLocalSystemTime {
	[CmdletBinding()]
	param ()
	
	$Time = Get-Date -DisplayHint Time
	
	# Update to UTC
	$Time = $Time.ToUniversalTime()
	
	return $Time
}
