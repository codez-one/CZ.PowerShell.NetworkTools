function Set-ProxyConfiguration {
    [CmdletBinding()]
    param (
        [string]
        $ConfigPath,
        [switch]
        $NoRoot
    )
    if ((Test-Path $ConfigPath) -eq $false) {
        Write-Error "The config path doesn't exsists." -ErrorAction Stop;
    }
    [ProxySetting] $proxySettings = [ProxySetting] (Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json);
    Write-Debug $proxySettings;
    if ($proxySettings.UseSystemProxyAddress -and [string]::IsNullOrWhiteSpace($proxySettings.ProxyAddress)) {
        if ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) {
            $proxySettings.ProxyAddress = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').proxyServer;
        }
        else {
            # TODO: find a good way to get linux system proxy. For now throw exception
            Write-Error "Currently we don't support linux, to read out the system proxy. Please configure it manualy" -ErrorAction Stop;
        }
        if ($null -eq $proxySettings.ProxyCredentials) {
            Write-Warning "You don't have set proxy credentials. If your system is configured with proxy credentials we can't read them.";
        }
    }
    # TODO: exclude this to make my machine working while im testing.
    Set-GitProxyConfiguration -Settings $proxySettings;
    Set-NpmProxyConfiguration -Settings $proxySettings;
    Set-AptProxyConfiguration -Settings $proxySettings -NoRoot:$NoRoot;
    Set-DockerProxyConfiguration -Settings $proxySettings;
}

function Set-GitProxyConfiguration {
    [CmdletBinding()]
    param (
        [ProxySetting]
        $Settings
    )
    if ($null -eq (Get-Command "git" -ErrorAction SilentlyContinue)) {
        Write-Debug "Unable to find git on your system. Skip configuration";
        return;
    }
    # set base address
    . "git" "config" "--global" "http.proxy" "$($Settings.ProxyAddress)";
    . "git" "config" "--global" "https.proxy" "$($Settings.ProxyAddress)";

    # only git version 2.13 or higher supports hostname wildcards
    $supportsWildcardHostnames = ((((git version) -split ' ')[2] -split '\.')[0] -ge 2) -and ((((git version) -split ' ')[2] -split '\.')[1] -ge 13);
    # set all new entries
    $Settings.BypassList | ForEach-Object {
        if ($_ -contains '*' -and $supportsWildcardHostnames -eq $false) {
            Write-Warning "Your git version is to old to support wild card hostnames. You must have version 2.13 or higher. We skip the hostname $_";
        }
        else {
            if ($_.StartsWith("https")) {
                . "git" "config" "--global" "https.$_.proxy" '""';
            }
            elseif($_.StartsWith("http")) {
                . "git" "config" "--global" "http.$_.proxy" '""';
            }else{
                . "git" "config" "--global" "http.http://$_.proxy" '""';
                . "git" "config" "--global" "https.https://$_.proxy" '""';
            }
        }

    }
    # remove old entries:
    # http
    . "git" "config" "--global" "--get-regexp" "http\.http" | ForEach-Object {
        $bypasskey = $_.Trim();
        if ($bypasskey -match "(http\.)(http.*)(\.proxy)") {
            $bypassedUrl = $matches[2].Trim();
            $shouldBeRemoved = $null -eq ($Settings.BypassList | Where-Object { $_ -like $bypassedUrl });
            if ($shouldBeRemoved) {
                Write-Warning "Remove '$bypassedUrl' from git bypass list";
                . "git" "config" "--global" "--unset" "$bypasskey";
            }
        }
    }

    # https
    . "git" "config" "--global" "--get-regexp" "https\.https" | ForEach-Object {
        $bypasskey = $_.Trim();
        if ($bypasskey -match "(https\.)(https.*)(\.proxy)") {
            $bypassedUrl = $Matches[2].Trim();
            $shouldBeRemoved = $null -eq ($Settings.BypassList | Where-Object { $_ -like $bypassedUrl });
            if ($shouldBeRemoved) {
                Write-Warning "Remove '$bypassedUrl' from git bypass list";
                . "git" "config" "--global" "--unset" "$bypasskey";
            }
        }
    }
}

function Set-NpmProxyConfiguration {
    [CmdletBinding()]
    param (
        [ProxySetting]
        $Settings
    )
    $npmCommand = (Get-Command "npm" -ErrorAction SilentlyContinue);
    if ($null -eq $npmCommand) {
        Write-Debug "Unable to find npm on your system. Skip configuration";
        return;
    }
    if($npmCommand.Path.StartsWith('/mnt/c/Program Files/')){
        Write-Warning ("In WSL2 you must override your environment variables to the linux version of NPM. " + `
        "We can't currently configure NPM for you.");
        return;
    }
    # set base address
    . "npm" "config" "set" "proxy" "$($Settings.ProxyAddress)";
    . "npm" "config" "set" "https-proxy" "$($Settings.ProxyAddress)";

    $bypasstring = $(($Settings.BypassList -join ',').Trim());
    # TODO: only set the right format
    . "npm" "config" "set" "no-proxy" "$bypasstring"; # this is for npm version < 6.4.1
    . "npm" "config" "set" "noproxy" $bypasstring; # this is for npm verison >= 6.4.1
}

function Set-AptProxyConfiguration {
    param (
        [ProxySetting]
        $Settings,
        [switch]
        $NoRoot
    )
    if ($null -eq (Get-Command "apt" -ErrorAction SilentlyContinue)) {
        Write-Debug "Unable to find apt on your system. Skip configuration";
        return;
    }
    try{
        if ((Test-Path "/etc/apt/apt.conf") -eq $false) {
            # just write the proxy into the file if it doesn't exsists
            "Acquire::http::Proxy ""$($Settings.ProxyAddress)"";" | Set-Content "/etc/apt/apt.conf";
        }
        else {
            $isAProxyAlreadConfigured = $null -ne (. "apt-config" "dump" "Acquire::http::proxy");
            if ($isAProxyAlreadConfigured) {
                $aptConfig = Get-Content "/etc/apt/apt.conf";
                $aptConfig = "$aptConfig" -replace 'Acquire::http::Proxy .*;', "Acquire::http::Proxy ""$($Settings.ProxyAddress)"";";

                $aptConfig = "$aptConfig" -replace '(^Acquire.*{(.|\n)*http.*{(.|\n)*)(proxy ".+";)((.|\n)*}(.|\n)*})$', "`${1}Proxy `"$($Settings.ProxyAddress)`";`${5}";

                # replace the file with new content
                $aptConfig | Set-Content "/etc/apt/apt.conf";
            }
            else {
                # if no proxy is configured just append the line
                "Acquire::http::Proxy ""$($Settings.ProxyAddress)"";"| Add-Content -Encoding ascii -NoNewline - >> "/etc/apt/apt.conf";
            }
        }
        if ($null -ne $Settings.BypassList -and $Settings.BypassList.Count -ne 0) {
            Write-Warning "apt-get don't support bypass list. To bypassing the proxy config for a given command starts the command like: 'apt-get -o Acquire::http::proxy=false ....'. This will bypass the proxy for the runtime of the apt-get command.";
        }
    }catch [System.UnauthorizedAccessException]{
        if($NoRoot){
            Write-Debug "Skip APT configuration because NORoot.";
            return;
        }else{
            Write-Error "You must be root to change APT settings." -TargetObject $_ -RecommendedAction "Run powershell as root or specify the `NoRoot` switch.";
            return;
        }
    }


}

function Set-DockerProxyConfiguration {
    param (
        [ProxySetting]
        $Settings
    )
    if ($null -eq (Get-Command "docker" -ErrorAction SilentlyContinue)) {
        Write-Debug "Unable to find docker on your system. Skip configuration";
        #return;
    }
    $json = '{
        "proxies":
        {
            "default":
            {
                "httpProxy": "' + $Settings.ProxyAddress + '",
                "httpsProxy": "' + $Settings.ProxyAddress + '",
                "noProxy": "' + ($Settings.ProxyAddress -join ',')+ '"
            }
        }
    }';
    Write-Verbose "$json";
    $proxyConfig = ConvertFrom-Json $json;
    if((Test-Path "~/.docker/config.json")){
        $dockerConfig = (Get-Content "~/.docker/config.json" -Raw | ConvertFrom-Json);
        if($false -eq [bool]($dockerConfig.PSobject.Properties.name -match "proxies")){
            $dockerConfig | Add-Member -NotePropertyMembers $proxyConfig -TypeName $json;
        }elseif($false -eq [bool]($dockerConfig.proxies.PSobject.Properties.name -match "default")){
            $dockerConfig | Add-Member -NotePropertyMembers $proxyConfig.proxies -TypeName $json;
        }else{
            $dockerConfig.proxies.default | Add-Member -NotePropertyName "httpProxy" -NotePropertyValue $Settings.ProxyAddress -Force
            $dockerConfig.proxies.default | Add-Member -NotePropertyName "httpsProxy" -NotePropertyValue $Settings.ProxyAddress -Force
            $dockerConfig.proxies.default | Add-Member -NotePropertyName "noProxy" -NotePropertyValue ($Settings.BypassList -join ',') -Force
        }
        ConvertTo-Json $dockerConfig | Set-Content "~/.docker/config.json";
    }else{
        New-Item "~/.docker" -Force -ItemType Directory | Out-Null;

        ConvertTo-Json $proxyConfig  | Set-Content "~/.docker/config.json" -Force;
    }
}

class ProxySetting {
    # TODO: implement http and https proxies can be different! 💣
    [string] $ProxyAddress = $null;
    # TODO: how to handle credentials
    [pscredential] $ProxyCredentials = $null;
    # TODO: are we allowed to override system proxy. (important for all .net applications, because they normaly use the system settings)
    [bool] $UseSystemProxyAddress = $false;
    [string[]] $BypassList;
}