function Get-DATSiteCode {
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$SiteServer
	)
	try {
		$SiteCodeObjects = Get-WmiObject -ComputerName $SiteServer -Namespace "root\SMS" -Class SMS_ProviderLocation -ErrorAction Stop
		$SiteCodeError = $false
	} catch {
		Write-DATLogEntry -Value "[Error] - $($_.Exception.Message)" -Severity 3
		$SiteCodeError = $true
	}
	if (($SiteCodeObjects -ne $null) -and ($SiteCodeError -ne $true)) {
		foreach ($SiteCodeObject in $SiteCodeObjects) {
			if ($SiteCodeObject.ProviderForLocalSite -eq $true) {
				$global:SiteCode = $SiteCodeObject.SiteCode
				Write-DATLogEntry -Value "- Site Code Found: $($global:SiteCode)" -Severity 1
				Set-DATRegistryValue -Name "SiteCode" -Value $global:SiteCode -Type String
				return $global:SiteCode
			}
		}
	}
}