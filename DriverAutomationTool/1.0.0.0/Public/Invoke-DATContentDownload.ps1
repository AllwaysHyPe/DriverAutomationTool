function Invoke-DATContentDownload {
	[CmdletBinding()]
	param
	(
		[ValidateNotNullOrEmpty()]
		$DownloadDestination,
		[ValidateNotNullOrEmpty()]
		$DownloadURL
	)
	# enforce TLS 1.2 for CDN endpoints
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$Redownload = $true
	$DownloadHeaders = $null
	$DownloadSize = $null
	# create download directory if it does not exist
	if (-not (Test-Path -Path $DownloadDestination)) {
		Write-DATLogEntry -Value "- Creating download destination directory $DownloadDestination" -Severity 1
		New-Item -Path $DownloadDestination -ItemType Directory -Force | Out-Null
	}
	# resolve output file name from URL
	$FileName = Split-Path $DownloadURL -Leaf
	$DownloadDestination = Join-Path $DownloadDestination $FileName
	# locate curl executable if path not already defined
	if ([string]::IsNullOrEmpty($CurlProcess)) {
		Write-DATLogEntry -Value "- Obtaining CURL path in source directory $global:ToolsDirectory" -Severity 1
		$CurlProcess = (Get-ChildItem -Path $global:ToolsDirectory -Recurse -Filter "curl.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
	}
	if (-not (Test-Path $CurlProcess)) {
		Write-DATLogEntry -Value "[Error] - Curl executable not found." -Severity 3
		return
	}
	# curl arguments optimized for resiliency and resume support
	$CurlArgs = @(
		"--insecure"
		"--location"
		"--fail"
		"--http1.1"
		"--retry", "10"
		"--retry-delay", "60"
		"--retry-max-time", "600"
		"--retry-all-errors"
		"--connect-timeout", "30"
		"-C", "-"
		"--output", "`"$DownloadDestination`""
		"--url", "`"$DownloadURL`""
	)
	Write-DATLogEntry -Value "- Attempting to obtain file size information from $DownloadURL" -Severity 1 -UpdateUI
	try {
		# retrieve HTTP headers using HEAD request
		$DownloadState = Invoke-WebRequest -Uri $DownloadURL -Method Head -UseBasicParsing -TimeoutSec 180
		if ($DownloadState.StatusCode -eq 200) {
			Write-DATLogEntry -Value "- URL returned status code 200" -Severity 1
			$DownloadHeaders = $DownloadState.Headers
			Write-DATLogEntry -Value "- Server: $($DownloadHeaders.Server)" -Severity 1
			Write-DATLogEntry -Value "- Cache: $($DownloadHeaders.'X-Cache')" -Severity 1
			Write-DATLogEntry -Value "- Last Modified: $($DownloadHeaders.'Last-Modified')" -Severity 1
			# extract content-length header if available
			if ($DownloadHeaders.'Content-Length') {
				$DownloadSize = [long](($DownloadHeaders.'Content-Length' | Select-Object -First 1))
			}
		}
	}
	catch {
		Write-DATLogEntry -Value "[Warning] - Unable to read HTTP headers. Falling back to CURL." -Severity 2
	}
	# if content length could not be determined, use curl to retrieve headers
	if (-not $DownloadSize) {
		Write-DATLogEntry -Value "- Running CURL to obtain file size" -Severity 1
		[array]$CurlHeaderOutput = (& $CurlProcess --silent --location --show-headers --suppress-connect-headers --max-time 10 $DownloadURL)
		$DownloadSize = [long]((
				$CurlHeaderOutput |
				Where-Object { $_ -match "Content-Length" } |
				ForEach-Object { $_ -replace "Content-Length:\s*", "" } |
				Select-Object -First 1
			))
	}
	if ($DownloadSize) {
		Write-DATLogEntry -Value "- Download size: $DownloadSize bytes" -Severity 1
		$DownloadSizeMB = [math]::Round(($DownloadSize / 1MB), 2)
		Set-DATRegistryValue -Name "DownloadURL" -Value $DownloadURL -Type String
		Set-DATRegistryValue -Name "DownloadSize" -Value $DownloadSizeMB -Type String
		Set-DATRegistryValue -Name "DownloadBytes" -Value $DownloadSize -Type String
	}
	# check if file already exists
	if (Test-Path $DownloadDestination) {
		Write-DATLogEntry -Value "- File previously downloaded - verifying file size." -Severity 1 -UpdateUI
		$DownloadedFileSize = (Get-Item $DownloadDestination).Length
		if ($DownloadSize -eq $DownloadedFileSize) {
			Write-DATLogEntry -Value "- File sizes verified as matching" -Severity 1
			Set-DATRegistryValue -Name "RunningState" -Value "Running" -Type String
			Set-DATRegistryValue -Name "RunningMode" -Value "Download Completed" -Type String
			$Redownload = $false
		}
		else {
			Write-DATLogEntry -Value "[Warning] - Existing file size mismatch. Re-downloading." -Severity 2
		}
	}
	if (-not $Redownload) { return }
	Write-DATLogEntry -Value "- Invoking CURL download process" -Severity 1
	# unblock executable in case it was downloaded from the internet
	Unblock-File -Path $CurlProcess -ErrorAction SilentlyContinue
	# terminate any existing curl processes before starting download
	Get-Process curl -ErrorAction SilentlyContinue | Stop-Process -Force
	$DownloadStartTime = Get-Date
	Set-DATRegistryValue -Name "RunningProcess" -Value "Curl" -Type String
	Set-DATRegistryValue -Name "DownloadStartTime" -Value $DownloadStartTime -Type String
	$DownloadProcess = Start-Process -FilePath $CurlProcess -ArgumentList $CurlArgs -PassThru -WindowStyle Minimized
	Start-Sleep -Seconds 5
	$Counter = 0
	# monitor download progress while curl is running
	while (-not $DownloadProcess.HasExited) {
		$Counter++
		if (Test-Path $DownloadDestination) {
			# determine number of bytes written to disk
			$Bytes = (Get-Item $DownloadDestination).Length
			Set-DATRegistryValue -Name "BytesTransferred" -Value $Bytes -Type String
			$MB = [math]::Round($Bytes / 1MB, 2)
			$Elapsed = ((Get-Date) - $DownloadStartTime).TotalSeconds
			if ($Elapsed -gt 0) {
				$Speed = [math]::Round($MB / $Elapsed, 2)
				$Msg = "- Downloaded $MB MB of $DownloadSizeMB MB at $Speed MB/s"
				# log every 60 seconds to reduce log noise
				if (($Counter % 60) -eq 0) {
					Write-DATLogEntry -Value "$Msg. Next update in 60 seconds." -Severity 1
				}
				else {
					Set-DATRegistryValue -Name "RunningMessage" -Value ($Msg.TrimStart("- ")) -Type String
				}
			}
		}
		Start-Sleep -Seconds 1
	}
	Write-DATLogEntry -Value "- Download process exited with code $($DownloadProcess.ExitCode)" -Severity 1
	if (Test-Path $DownloadDestination) {
		$DownloadedFileSize = (Get-Item $DownloadDestination).Length
		Write-DATLogEntry -Value "- Downloaded file size - $DownloadedFileSize bytes" -Severity 1
		# verify downloaded file matches expected size
		if ($DownloadSize -eq $DownloadedFileSize) {
			Write-DATLogEntry -Value "- File sizes match" -Severity 1
			Set-DATRegistryValue -Name "RunningState" -Value "Running" -Type String
			Set-DATRegistryValue -Name "RunningMode" -Value "Download Completed" -Type String
		}
		else {
			Write-DATLogEntry -Value "[Warning] - File sizes do not match expected value." -Severity 2
			Set-DATRegistryValue -Name "RunningState" -Value "Error" -Type String
		}
	}
	else {
		Write-DATLogEntry -Value "[Error] - File not present at $DownloadDestination" -Severity 3
	}
}