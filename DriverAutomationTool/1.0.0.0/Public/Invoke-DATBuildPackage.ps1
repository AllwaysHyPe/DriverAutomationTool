function Invoke-DATBuildPackage {

	# Start the download, build and package process
	Write-DATLogEntry -Value "[Build Process] - Starting the download, build and package process" -Severity 1

	# Create an array for the selected computers
	$global:SelectedModels = New-Object System.Collections.ArrayList

	for ($Row = 0; $Row -lt $datagridview_ModelSelection.RowCount; $Row++) {
		if ($datagridview_ModelSelection.Rows[$Row].Cells[0].Value -eq $true) {

			# Update array
			$ModelDetails = New-Object -TypeName PSObject
			$ModelDetails | Add-Member -MemberType NoteProperty -Name "OEM" -Value "$($datagridview_ModelSelection.Rows[$Row].Cells[1].Value)" -Force
			$ModelDetails | Add-Member -MemberType NoteProperty -Name "Model" -Value "$($datagridview_ModelSelection.Rows[$Row].Cells[2].Value)" -Force
			$ModelDetails | Add-Member -MemberType NoteProperty -Name "Baseboards" -Value "$($datagridview_ModelSelection.Rows[$Row].Cells[4].Value)" -Force
			$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS" -Value "$globaL:WindowsVersion" -Force
			$ModelDetails | Add-Member -MemberType NoteProperty -Name "OS Build" -Value "$global:Architecture" -Force
		
			$global:SelectedModels += $ModelDetails
		}
	}

	Write-DATLogEntry -Value "A total of $($global:SelectedModels | Measure-Object | Select-Object -ExpandProperty Count) have been selected for packaging" -Severity 1
}