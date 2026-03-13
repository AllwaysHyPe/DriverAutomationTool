function Reset-DATRegistryValues {
	<#
	.SYNOPSIS
		This function returns specific common registry values to default
	
	.DESCRIPTION
		A detailed description of the Reset-RegistryValues function.
	
	.EXAMPLE
				PS C:\> Reset-RegistryValues
	
	.NOTES
		Additional information about the function.
#>
	[CmdletBinding()]
	param ()
	
	# Null registry entries
	Remove-ItemProperty -Path $global:RegPath -Name TotalDriverDownloads -ErrorAction SilentlyContinue
	Remove-ItemProperty -Path $global:RegPath -Name CurrentDriverDownload -ErrorAction SilentlyContinue
	Remove-ItemProperty -Path $global:RegPath -Name CurrentDriverDownloadCount -ErrorAction SilentlyContinue
	Remove-ItemProperty -Path $global:RegPath -Name CompletedDriverDownloads -ErrorAction SilentlyContinue
}