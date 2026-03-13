# Creating module
Function New-ModuleTemplate {
    [CmdletBinding()]
    [OutputType()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        [Parameter(Mandatory = $true)]
        [string]$ModuleVersion,
        [Parameter(Mandatory = $true)]
        [string]$Author,
        [Parameter(Mandatory = $true)]
        [string]$PSVersion,
        [Parameter(Mandatory = $false)]
        [string[]]$Functions
    )
    $ModulePath = Join-Path .\ "$($ModuleName)\$($ModuleVersion)"
    New-Item -Path $ModulePath -ItemType Directory
    Set-Location $ModulePath
    New-Item -Path .\Public -ItemType Directory

    $ManifestParameters = @{
        ModuleVersion     = $ModuleVersion
        Author            = $Author
        Path              = ".\$($ModuleName).psd1"
        RootModule        = ".\$($ModuleName).psm1"
        PowerShellVersion = $PSVersion
    }
    New-ModuleManifest @ManifestParameters

    $File = @{
        FilePath = ".\$($ModuleName).psm1"
        Encoding = 'utf8'
    }
    Out-File @File

    $Functions | ForEach-Object {
        Out-File -Path ".\Public\$($_).ps1" -Encoding utf8
    }
}

# Set the parameters to pass to the function
$module = @{
    # The name of your module
    ModuleName    = 'DriverAutomationTool'
    # The version of your module
    ModuleVersion = "1.0.0.0"
    # Your name
    Author        = "Hailey Phillips"
    # The minimum PowerShell version this module supports
    PSVersion     = '5.1'
    # The functions to create blank files for in the Public folder
    Functions     = 'Get-DATScriptDirectory', 
                    'Write-DATLogEntry',
                    'Get-DATOEMSources',
                    'Find-DATLenovoModelType',
                    'Get-DATOEMModelInfo',
                    'Get-DATOEMDownloadLinks',
                    'Get-DATConfigMgrSiteCode',
                    'Invoke-DATContentDownload',
                    'Set-DATRegistryValue',
                    'Reset-DATRegistryValues',
                    'Invoke-DATExecutable',
                    'Install-DATDriverPackage',
                    'Invoke-DATBuildPackage',
                    'Connect-DATConfigMgr',
                    'Get-DATSiteCode',
                    'Get-DATDistributionPoints',
                    'Get-DATDistributionGroups',
                    'Get-DATLocalSystemTime',
                    'Invoke-DATDriverFilePackaging',
                    'Create-DATConfigMgrPkg',
                    'Publish-DATConfigMgrPkg',
                    'Export-DATRegistry',
                    'Import-DATRegistry',
                    'Start-DATModelProcessing',
                    'Invoke-DATOEMDownloadModule'
}
# Execute the function to create the new module
New-ModuleTemplate @module

