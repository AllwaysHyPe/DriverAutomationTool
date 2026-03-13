function Get-DATConfigMgrSiteCode {
	param
	(
		[ValidateNotNullOrEmpty()]
		[string]$SiteServer
	)
	
	try {
		Write-DATLogEntry -Value "- Calling WMI on server $SiteServer to obtain root\SMS class information" -Severity 3
		$SiteCodeObjects = Get-CimInstance -ComputerName $SiteServer -Namespace "root\SMS" -Class SMS_ProviderLocation -ErrorAction Stop
	} catch {
		Write-DATLogEntry -Value "[Error] - Issues occurred while attempting to query WMI on server $SiteServer. $($_.Exception.Message)" -Severity 3
	}
	
	if (($SiteCodeObjects.SiteCode).Count -ge 1) {
		foreach ($SiteCodeObject in $SiteCodeObjects) {
			Write-DATLogEntry -Value "- Checking $($SiteCodeObject.Machine) for site code information" -Severity 1
			if ($SiteCodeObject.ProviderForLocalSite -eq $true) {
				$global:SiteCode = $SiteCodeObject.SiteCode
				Write-DATLogEntry -Value "- Site Code Found: $($global:SiteCode)" -Severity 1
			}
		}
	}
}
