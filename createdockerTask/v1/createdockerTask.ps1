[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try{
    # Get inputs.
    $containername = Get-VstsInput -Name 'containername' -Require
    $imagename = Get-VstsInput -Name 'imagename' -Require
    $licensefile = Get-VstsInput -Name 'licensefile' -Default ''
    $password = Get-VstsInput -Name 'password' -Default ''
    $username = Get-VstsInput -Name 'username' -Default ''
    $auth = Get-VstsInput -Name 'auth' -Require
    $ram = Get-VstsInput -Name 'ram' -Default '4GB'
    $importtestsuite = Get-VstsInput -Name 'importtestsuite' -AsBool
    $fastcontainer = Get-VstsInput -Name 'fastcontainer' -AsBool
    $enablesymbolloading = Get-VstsInput -Name 'enablesymbolloading' -AsBool
    $optionalparams = Get-VstsInput -Name 'optionalparams' -Default ''
    $isolation = Get-VstsInput -Name 'isolation' -Default ''

    Write-Host "Importing module NVRAppDevOps"
    Import-Module NVRAppDevOps -DisableNameChecking
    $skipimporttestsuite = (-not $importtestsuite)
    $RepoPath = $env:AGENT_RELEASEDIRECTORY
    
    if ($fastcontainer) {
        $PWord = ConvertTo-SecureString -String 'Pass@word1' -AsPlainText -Force
        $User = $env:USERNAME
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User,$PWord
        New-NavContainer -accept_eula `
            -accept_outdated `
            -containerName $containername `
            -imageName $imagename `
            -doNotExportObjectsToText `
            -alwaysPull `
            -shortcuts "None" `
            -auth 'Windows' `
            -Credential $cred `
            -memoryLimit '4GB' `
            -updateHosts `
            -useBestContainerOS `
            -additionalParameters @("--volume ""$($RepoPath):c:\app""") `
            -isolation $isolation `
            -myScripts  @(@{"navstart.ps1" = "Write-Host 'Ready for connections!'";"checkhealth.ps1" = "exit 0"})

    } else {

        Init-ALEnvironment `
            -ContainerName $containername `
            -ImageName $imagename `
            -LicenseFile $licensefile `
            -Build 'true' `
            -Username $username `
            -Password $password `
            -RepoPath $RepoPath `
            -Auth $auth `
            -RAM $ram `
            -SkipImportTestSuite:$skipimporttestsuite `
            -EnableSymbolLoading $enablesymbolloading `
            -CreateTestWebServices $false `
            -Isolation $isolation `
            -optionalParameters $optionalparams
    }
        
} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}