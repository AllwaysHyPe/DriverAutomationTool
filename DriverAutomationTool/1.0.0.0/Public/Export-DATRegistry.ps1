# Function that exports the $global:regpath is a .reg file
function Export-DATRegistry {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$ExportPath
	)
	
	# Export the registry path to a .reg file
	Export-DATRegistry -Path $global:RegPath -ExportPath $ExportPath
}
