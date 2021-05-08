#! /usr/bin/pwsh
[CmdletBinding()]
param (
    # Set this to false if you try to build a real release
    [Parameter()]
    [bool]
    $Prerelease = $false,
    # Update the specify version block
    [Parameter(Mandatory = $false)]
    [ValidateSet("None", "Patch", "Minor", "Major")]
    [string]
    $VersionPosition = "None"
)
Set-StrictMode -Version Latest
if ($Prerelease -eq $false -and $VersionPosition -eq "None") {
    throw "You must set the `VersionPosition` parameter if you want create a real version."
}

# test script rules
Invoke-ScriptAnalyzer -Recurse "$PSScriptRoot/../src/" -ExcludeRule "PSUseToExportFieldsInManifest", "PSUseToExportFieldsInManifest";

# update the manifest

## implement a function to get all function names
# > provided from stackoverflow: https://stackoverflow.com/a/57635570
function Get-ScriptFunctionNames {
    param (
        [parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [System.String]
        $Path
    )
    Process {
        [System.Collections.Generic.List[String]]$functionNames = New-Object System.Collections.Generic.List[String]

        if (!([System.String]::IsNullOrWhiteSpace($Path))) {
            Select-String -Path "$Path" -Pattern "function" |
            ForEach-Object {
                [System.Text.RegularExpressions.Regex] $regexp = New-Object Regex("(function)( +)([\w-]+)")
                [System.Text.RegularExpressions.Match] $match = $regexp.Match("$_")
                if ($match.Success) {
                    $functionNames.Add("$($match.Groups[3])")
                }
            }
        }
        return , $functionNames.ToArray()
    }
}
$allFunctionNames = Get-ChildItem "$PSScriptRoot/../src/" -Filter "*.ps1" | ForEach-Object {
    return Get-ScriptFunctionNames $_;
}

$manifest = Test-ModuleManifest "$PSScriptRoot/../src/CZ.PowerShell.NetworkTools.psd1";
$versionNumber = $manifest.Version.ToString();
if ($VersionPosition -eq "Patch") {
    $versionNumber = "$($manifest.Version.Major).$($manifest.Version.Minor).$($manifest.Version.Build + 1)";
}
elseif ($VersionPosition -eq "Minor") {
    $versionNumber = "$($manifest.Version.Major).$($manifest.Version.Minor + 1).$($manifest.Version.Build)";
}
elseif ($VersionPosition -eq "Major") {
    $versionNumber = "$($manifest.Version.Major + 1).$($manifest.Version.Minor).$($manifest.Version.Build)";
}
$currentLocation = Get-Location;
Set-Location $PSScriptRoot/../src/
try {
    if ($Prerelease) {
        Update-ModuleManifest -Path "$PSScriptRoot/../src/CZ.PowerShell.NetworkTools.psd1" -FileList (Get-ChildItem "$PSScriptRoot/../src/" -Filter "*.ps1" | ForEach-Object { $_ }) -FunctionsToExport $allFunctionNames -Prerelease "-preview$((Get-Date).DayOfYear)$((Get-Date).Hour)$((Get-Date).Minute)$((Get-Date).Second)";
    }
    else {
        Update-ModuleManifest -Path "$PSScriptRoot/../src/CZ.PowerShell.NetworkTools.psd1" -FileList (Get-ChildItem "$PSScriptRoot/../src/" -Filter "*.ps1" | ForEach-Object { $_ }) -FunctionsToExport $allFunctionNames -ModuleVersion $versionNumber;
    }
}
finally {
    Set-Location $currentLocation;
}


