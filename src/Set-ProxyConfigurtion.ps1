function Set-ProxyConfiguration {
    [CmdletBinding()]
    param (
        [string]
        $ConfigPath
    )
    if((Test-Path $ConfigPath) -eq $false){
        Write-Error "The config path doesn't exsists." -ErrorAction Stop;
    }
    [ProxySetting] $proxySettings = [ProxySetting] (Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json);
    Write-Debug $proxySettings;
    if($proxySettings.UseSystemProxyAddress -and [string]::IsNullOrWhiteSpace($proxySettings.ProxyAddress)){
        if($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows){
            $proxySettings.ProxyAddress = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').proxyServer;
        }else{
            # TODO: find a good way to get linux system proxy. For now throw exception
            Write-Error "Currently we don't support linux, to read out the system proxy. Please configure it manualy" -ErrorAction Stop;
        }
        if($null -eq $proxySettings.ProxyCredentials){
            Write-Warning "You don't have set proxy credentials. If your system is configured with proxy credentials we can't read them.";
        }
    }
    Set-GitProxyConfiguration -Settings $proxySettings;
    Set-NpmProxyConfiguration -Settings $proxySettings;
}

function Set-GitProxyConfiguration {
    [CmdletBinding()]
    param (
        [ProxySetting]
        $Settings
    )
    if ($null -eq (Get-Command "git" -ErrorAction SilentlyContinue))
    {
        Write-Debug "Unable to find git on your system. Skip configuration";
        return;
    }
    # set base address
    . "git" "config" "--global" "http.proxy" "$($Settings.ProxyAddress)";
    . "git" "config" "--global" "https.proxy" "$($Settings.ProxyAddress)";

    # only git version 2.13 or higher supports hostname wildcards
    $supportsWildcardHostnames = ((((git version) -split ' ')[2] -split '\.')[0] -ge 2) -and ((((git version) -split ' ')[2] -split '\.')[1] -ge 13);
    # set all new entries
    $Settings.BypassList | ForEach-Object{
        if($_ -contains '*' -and $supportsWildcardHostnames -eq $false){
            Write-Warning "Your git version is to old to support wild card hostnames. You must have version 2.13 or higher. We skip the hostname $_";
        }else{
            if($_.StartsWith("https")){
                . "git" "config" "--global" "https.$_.proxy" '""';
            }else{
                . "git" "config" "--global" "http.$_.proxy" '""';
            }
        }

    }
    # remove old entries:
    # http
    . "git" "config" "--global" "--get-regexp" "http\.http" | ForEach-Object{
        $bypasskey = $_.Trim();
        if ($bypasskey -match "(http\.)(http.*)(\.proxy)") {
            $bypassedUrl = $matches[2].Trim();
            $shouldBeRemoved = $null -eq ($Settings.BypassList | Where-Object{$_ -like $bypassedUrl});
            if($shouldBeRemoved){
                Write-Warning "Remove '$bypassedUrl' from git bypass list";
                . "git" "config" "--global" "--unset" "$bypasskey";
            }
        }
    }

    # https
    . "git" "config" "--global" "--get-regexp" "https\.https"| ForEach-Object{
        $bypasskey = $_.Trim();
        if ($bypasskey -match "(https\.)(https.*)(\.proxy)") {
            $bypassedUrl = $matches[2].Trim();
            $shouldBeRemoved = $null -eq ($Settings.BypassList | Where-Object{$_ -like $bypassedUrl});
            if($shouldBeRemoved){
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
    if ($null -eq (Get-Command "npm" -ErrorAction SilentlyContinue))
    {
        Write-Debug "Unable to find npm on your system. Skip configuration";
        return;
    }
    # set base address
    . "npm" "config" "set" "proxy" "$($Settings.ProxyAddress)";
    . "npm" "config" "set" "https-proxy" "$($Settings.ProxyAddress)";

    $bypasstring = $(($Settings.BypassList -join ',').Trim());
    . "npm" "config" "set" "no-proxy" "$bypasstring"; # this is for npm version < 6.4.1
    . "npm" "config" "set" "noproxy" $bypasstring; # this is for npm verison >= 6.4.1
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