function Find-DATLenovoModelType {
	param (
		[parameter(Mandatory = $false, HelpMessage = "Enter Lenovo model to query")]
		[string]$Model,
		[parameter(Mandatory = $false, HelpMessage = "Enter Operating System")]
		[string]$OS,
		[parameter(Mandatory = $false, HelpMessage = "Enter Lenovo model type to query")]
		[string]$ModelType
	)
	
	if ($ModelType.Length -gt 0) {
		$global:LenovoModelType = $global:LenovoModelDrivers | Where-Object {
			$_.Types.Type -match $ModelType
		} | Select-Object -ExpandProperty Name -First 1
	}
	if (-not [string]::IsNullOrEmpty($Model)) {
		$global:LenovoModelType = ($global:LenovoModelDrivers | Where-Object {
				$_.Name -eq $Model
			}).Types.Type
		
	}
	$global:SkuValue = $global:LenovoModelType
	return $global:LenovoModelType
}