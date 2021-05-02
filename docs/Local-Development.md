# Local Development

## Needed development tools

- VsCode
- PowerShell 5 and 7
- Pester greater or equal 5
- PSScriptAnalyzer

## folder structure

- `docs` -> is for documentation
- `src` -> everything that will pack into the module
- `build` -> all the scripts we need to build the module
- `test` -> all the scripts that contain the pester scripts

## Some old stuff that maybe helps others

### Create module manifest

The following command shows the creation of the manifest. There are some notes for this snippet.

- The `DefaultCommandPrefix` changes all exported functions from `Verb-Name` to `Verb-CzName`

```powershell
New-ModuleManifest -Path .\CZ.PowerShell.NetworkTools.psd1 -PassThru -RootModule .\CZ.PowerShell.NetworkTools.psm1 -Author "paule96, CZ" -Copyright "Copyright (c) 2021 CodeZ.one" -CompanyName "CodeZ.one" -Description "Provide some simple powershell functions, to debug your network configuration." -CompatiblePSEditions Desktop, Core -FileList (ls -Filter "*.ps1" | Foreach-Object{$_}) -FunctionsToExport Test-ProxyConfiguration -Tags Proxy -ProjectUri "https://github.com/codez-one/CZ.PowerShell.NetworkTools" -LicenseUri "https://github.com/codez-one/CZ.PowerShell.NetworkTools/blob/main/LICENSE" -IconUri "https://avatars.githubusercontent.com/u/48394545?s=200&v=4" -ReleaseNotes "- Added a configuration test for proxy networks" -DefaultCommandPrefix "Cz" -Prerelease "-preview1" -PowerShellVersion "5.1"
```
