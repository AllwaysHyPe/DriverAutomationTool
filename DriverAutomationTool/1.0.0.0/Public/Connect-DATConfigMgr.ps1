function Connect-DATConfigMgr {
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$SiteServer,
		[Parameter(Mandatory = $true)]
		[boolean]$WinRMOverSSL,
		[Parameter(Mandatory = $false)]
		[boolean]$KnownModels
	)
	
	if (-not ([string]::IsNullOrEmpty($SiteServer))) {
		
		try {
			switch ($WinRMOverSSL) {
				$true {
					Write-DATLogEntry -Value "- Attempting WinRM connection using SSL" -Severity 1
					Set-DATRegistryValue -Name "WinRMSSL" -Value "True" -Type String -Verbose
					[string]$ConfigMgrDiscovery = (Test-WSMan -ComputerName $SiteServer -UseSSL -ErrorAction SilentlyContinue).wsmid
				}
				$false {
					Write-DATLogEntry -Value "- Attempting WinRM connection" -Severity 1
					Set-DATRegistryValue -Name "WinRMSSL" -Value "False" -Type String -Verbose
					[string]$ConfigMgrDiscovery = (Test-WSMan -ComputerName $SiteServer -ErrorAction SilentlyContinue).wsmid
				}
			}
			Write-DATLogEntry -Value "- WinRM connection established" -Severity 1
		} catch [System.Exception] {
			Write-DATLogEntry -Value "[Error] - $($_.Exception.Message)" -Severity 3
			if ([string]::IsNullOrEmpty($ConfigMgrDiscovery)) {
				Write-DATLogEntry -Value "Switching WinRM to non SSL mode" -Severity 1
				try {
					Set-DATRegistryValue -Name "WinRMSSL" -Value "False" -Type String -Verbose
					[string]$ConfigMgrDiscovery = (Test-WSMan -ComputerName $SiteServer).wsmid
				} catch [System.Exception] {
					Write-DATLogEntry -Value "[Error] - $($_.Exception.Message)" -Severity 3
				}
			}
			Write-DATLogEntry -Value "WinRM connection established" -Severity 1
		}
		
		if ($ConfigMgrDiscovery -ne $null) {
			#$ProgressListBox.ForeColor = "Black"
			try {
				if ($global:ConfigMgrValidation -ne $true) {
					Write-DATLogEntry -Value "[Configuration Manager] - Connecting to Configuration Manager Server" -Severity 1
					Write-DATLogEntry -Value "- Querying site code From $SiteServer" -Severity 1
					$global:SiteServer = Get-DATSiteCode -SiteServer $SiteServer
					# Update registry with site server
					Set-DATRegistryValue -Name "SiteServer" -Value $SiteServer -Type String
					
					# Import Configuratio Manager PowerShell Module
					if ($env:SMS_ADMIN_UI_PATH -ne $null) {
						$ModuleName = (Get-Item $env:SMS_ADMIN_UI_PATH | Split-Path -Parent) + "\ConfigurationManager.psd1"
						Write-DATLogEntry -Value "- Loading ConfigMgr PowerShell module" -Severity 1
						Import-Module $ModuleName
						$global:ConfigMgrValidation = $true
					}
				}
			} catch [System.Exception] {
				Write-DATLogEntry -Value "[Error] - $($_.Exception.Message)" -Severity 3
			}
		} else {
			Write-DATLogEntry -Value "[Error] - ConfigMgr server specified not found - $($SiteServerInput.Text)" -Severity 3
		}
		
		if ($KnownModels -eq "Yes") {
			Write-DATLogEntry -Value "- Setting known model query" -Severity 1
			Set-DATRegistryValue -Name "KnownModels" -Value "Yes" -Type String
		} else {
			Set-DATRegistryValue -Name "KnownModels" -Value "No" -Type String
		}
	} else {
		Write-DATLogEntry -Value "[Error] - ConfigMgr site server not specified. Please review in the common settings tab." -Severity 3
	}
}