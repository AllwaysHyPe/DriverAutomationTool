# Function that imports the $global:regpath from a .reg file
function Import-DATRegistry {
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$ImportPath
	)
	
	# Import the registry path from a .reg file
	Import-DATRegistry -Path $global:RegPath -ImportPath $ImportPath
}

