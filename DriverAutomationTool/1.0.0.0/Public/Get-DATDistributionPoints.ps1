function Get-DATDistributionPoints {
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$SiteCode,
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$SiteServer
	)
	
	# Check if the ConfigMgr module is loaded and load module if not
	if (-not (Get-Module -Name ConfigurationManager)) {
		$ModuleName = (Get-Item $env:SMS_ADMIN_UI_PATH | Split-Path -Parent) + "\ConfigurationManager.psd1"
		Write-DATLogEntry -Value "- Loading ConfigMgr PowerShell module" -Severity 1
		Import-Module $ModuleName
	}


	#Set-Location -Path [string]($SiteCode + ":\")
	[Array]$DistributionPoints = Get-WmiObject -ComputerName $SiteServer -Namespace "Root\SMS\Site_$SiteCode" -Class SMS_SystemResourceList | Where-Object {
		$_.RoleName -match "Distribution"
	} | Select-Object -ExpandProperty ServerName -Unique | Sort-Object


	return $DistributionPoints
}