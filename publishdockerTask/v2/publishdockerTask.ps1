[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {
    # Get inputs.
    $ContainerName = Get-VstsInput -Name 'ContainerName' -Require
    #$Contents = Get-VstsInput -Name 'Contents' -Default '*.app'
    $SourceFolder = Get-VstsInput -Name 'SourceFolder' -Default $env:SYSTEM_DEFAULTWORKINGDIRECTORY
    #$AppFileExclude = Get-VstsInput -Name 'AppFileExclude' -Default ''
    $Tenant = Get-VstsInput -Name 'Tenant' -Default 'default'
    $SyncMode = Get-VstsInput -Name 'SyncMode' -Default 'Add'
    $Scope = Get-VstsInput -Name 'Scope' -Default 'Tenant'
    $SkipVerify = Get-VstsInput -Name 'SkipVerify' -AsBool -Default $false
    $Recurse = Get-VstsInput -Name 'Recurse' -AsBool -Default $false
    $UseDevEndpoint = Get-VstsInput -Name 'UseDevEndpoint' -AsBool -Default $false
    $AppDownloadScript = Get-VstsInput -Name 'AppDownloadScript' -AsBool -Default $false

    Write-Host "Importing module NVRAppDevOps"
    Import-Module NVRAppDevOps -DisableNameChecking

    $AppOrder = Get-ALAppOrder -ContainerName $ContainerName -Path $SourceFolder -Recurse:$Recurse
    #Publish-ALAppTree -ContainerName $ContainerName `
    #                  -SkipVerification:$skipverify `
    #                  -OrderedApps $AppOrder `
    #                  -PackagesPath $SourceFolder `
    #                  -syncMode $SyncMode `
    #                  -scope $Scope `
    #                  -AppDownloadScript $AppDownloadScript `
    #                  -UseDevEndpoint:$UseDevEndpoint `
    #                  -Tenant $Tenant
    foreach ($App in $AppOrder) {
        if ($App.AppPath -like '*.app') {
            $AppFile = $App.AppPath
        }
        else {
            $AppFile = (Get-ChildItem -Path $SourceFolder -Filter "$($App.publisher)_$($App.name)_*.app" | Select-Object -First 1).FullName
        }
        if (-not $AppFile) {
            Write-Host "App $($App.name) from $($App.publisher) not found."
            if ($AppDownloadScript) {
                Write-Host "Trying to download..."
                Download-ALApp -name $App.name -publisher $App.publisher -version $App.version -targetPath $SourceFolder -AppDownloadScript $AppDownloadScript
            }
        }
        $dockerapp = Get-NavContainerAppInfo -containerName $ContainerName -tenantSpecificProperties | where-object { $_.Name -eq $App.name }
        $install = -not $dockerapp
        if ($install) {
            Write-Host "App not exists on server, will install by default"
        }
        else {
            Write-Host "Another version exists on server, will do upgrade"
        }
        Publish-NavContainerApp -containerName $ContainerName `
                                -appFile $AppFile `
                                -skipVerification:$SkipVerify `
                                -sync `
                                -install:$install `
                                -syncMode $SyncMode `
                                -tenant $Tenant `
                                -scope $Scope `
                                -useDevEndpoint:$UseDevEndpoint
    
        if ($dockerapp) {
            $dockerapp = Get-NavContainerAppInfo -containerName $ContainerName -tenantSpecificProperties | where-object { $_.Name -eq $App.name } | Sort-Object -Property "Version"
            if ($dockerapp.Count -gt 1) {
                foreach ($dapp in $dockerapp) {
                    if ($dapp.IsInstalled) {
                        $previousVersion = $dapp
                    }
                    if ($AppFile.Contains($dapp.Version)) {
                        Write-Host "Upgrading from $($previousVersion.Version) to $($dapp.Version)"
                        Start-NavContainerAppDataUpgrade -containerName $ContainerName -appName $App.name -appVersion $dapp.Version
                        $newInstalledApp = $dapp
                    }
                }
                foreach ($uapp in $dockerapp) {
                    if ($uapp.Version -ne $newInstalledApp.Version) {
                        Write-Host "Unpublishing version $($uapp.Version)"
                        Unpublish-NavContainerApp -containerName $ContainerName -appName $App.name -version $uapp.Version
                    }
                }
            }
        }
    }

                      

}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
