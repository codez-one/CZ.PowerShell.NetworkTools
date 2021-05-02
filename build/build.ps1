#! /usr/bin/pwsh

Set-StrictMode -Version Latest
Invoke-ScriptAnalyzer -Recurse "$PSScriptRoot/../src/";