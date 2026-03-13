# Review
function Publish-DATConfigMgrPkg {
	param
	(
		[parameter(Mandatory = $true)]
		[string]$Product,
		[string]$PackageID,
		[string]$ImportInto
		
	)
	# Distribute Content - Selected Distribution Points
	for ($Row = 0; $Row -lt $DPGridView.RowCount; $Row++) {
		if ($DPGridView.Rows[$Row].Cells[0].Value -eq $true) {
			if ($ImportInto -match "Standard") {
				Start-CMContentDistribution -PackageID $PackageID -DistributionPointName $($DPGridView.Rows[$Row].Cells[1].Value)
			}
			if ($ImportInto -match "Driver") {
				Start-CMContentDistribution -DriverPackageID $PackageID -DistributionPointName $($DPGridView.Rows[$Row].Cells[1].Value)
			}
			Write-DATLogEntry -Value "- $($Product): Distributing Package $PackageID to Distribution Point - $($DPGridView.Rows[$Row].Cells[1].Value) " -Severity 1
		}
	}
	# Distribute Content - Selected Distribution Point Groups
	for ($Row = 0; $Row -lt $DPGGridView.RowCount; $Row++) {
		if ($DPGGridView.Rows[$Row].Cells[0].Value -eq $true) {
			if ($ImportInto -match "Standard") {
				Start-CMContentDistribution -PackageID $PackageID -DistributionPointGroupName $($DPGGridView.Rows[$Row].Cells[1].Value)
			}
			if ($ImportInto -match "Driver") {
				Start-CMContentDistribution -DriverPackageID $PackageID -DistributionPointGroupName $($DPGGridView.Rows[$Row].Cells[1].Value)
			}
			Write-DATLogEntry -Value "- $($Product): Distributing Package $PackageID to Distribution Point Group - $($DPGGridView.Rows[$Row].Cells[1].Value) " -Severity 1
		}
	}
}

