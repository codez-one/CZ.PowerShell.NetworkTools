Get-ChildItem "$PSScriptRoot" -Recurse -Include "*.ps1" | ForEach-Object{
    # load all scripts
    . $_;
}