function Set-DATRegistryValue {
    <#
	.SYNOPSIS
		Sets registry entries
	
	.DESCRIPTION
		This function is a re-usable code for setting registry information. By default it will use the $global:RegPath value.
	
	.PARAMETER Name
		Registry item name
	
	.PARAMETER Value
		Value you would wish to set
	
	.PARAMETER Type
		Registry value type, example, DWORD, STRING
	
	.PARAMETER FullOSRegPath
		Optional registry path for specifc registry additions
	
	.EXAMPLE
		PS C:\> Set-RegistryValue -Name 'Value1' -Value 'Value2' -Type String
	
	.NOTES
		Additional information about the function.
#>

	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true,
			Position = 1)]
		[ValidateNotNullOrEmpty()]
		[String]$Name,
		[Parameter(Mandatory = $true,
			Position = 2)]
		[String]$Value,
		[Parameter(Mandatory = $true,
			Position = 3)]
		[ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'Qword')]
		[String]$Type,
		[Parameter(Position = 4)]
		[String]$FullOSRegPath
	)
	
	try {
		# This section of code is used to set values to the FullOS software registry hive during provisioning
		if ((-not ([string]::IsNullOrEmpty($FullOSRegPath)))) {
			switch -wildcard ($FullOSRegPath) {
				"*HKEY_LOCAL_MACHINE\System*" {
					$FullOSRegPath = $FullOSRegPath.ToLower()
					$FullOSRegPath = $FullOSRegPath.Replace("hkey_local_machine\system", "HKLM:\FullOSSystem")
					$CustomBaseKey = "HKLM:\FullOSSystem"
					Write-DATLogEntry -Value "- Using system registry hive" -Severity 1
				}
				"*HKEY_LOCAL_MACHINE\Software*" {
					$FullOSRegPath = $FullOSRegPath.ToLower()
					$FullOSRegPath = $FullOSRegPath.Replace("hkey_local_machine\software", "HKLM:\FullOSSoftware")
					$CustomBaseKey = "HKLM:\FullOSoftware"
					Write-DATLogEntry -Value "- Using software registry hive" -Severity 1
				}
			}
			
			# Create path if required
			if ([boolean](Test-Path -Path "$CustomBaseKey" -ErrorAction SilentlyContinue) -eq $false) {
				New-Item -Path $FullOSRegPath -Force | Out-Null
			}

			# Used for debugging model listing
			# Write-DATLogEntry -Value "- Adding $Value to $FullOSRegPath\$Name" -Severity 1

			New-ItemProperty -Path $FullOSRegPath -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
		} elseif (-not ([string]::IsNullOrEmpty($global:RegPath))) {
			# This section of code is used to set registry values to the $global:RegPath path during provisioning
			if ((Test-Path -Path $global:RegPath) -eq $false) {
				Write-Verbose "[Registry] - Creating registry key at path $global:RegPath"
				New-Item -Path $global:RegPath -Force | Out-Null
			}
			
			# Set new item
			Write-Verbose "- Adding registry entry $global:RegPath\$Name with value: $Value"
			New-ItemProperty -Path $global:RegPath -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
		} else {
			Write-DATLogEntry -Value "[Warning] - Registry path not specified in global variables." -Severity 2
		}
	} catch [System.Exception] {
		Write-Output "[Registry Setting Error] - Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
	}
}
