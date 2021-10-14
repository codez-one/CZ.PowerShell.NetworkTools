function Set-ProxyConfiguration {
    [CmdletBinding()]
    param (
        [string]
        $ConfigPath,
        [switch]
        $NoRoot
    )
    if ((Test-Path -Path $ConfigPath) -eq $false) {
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
    Set-GitProxyConfiguration -Settings $proxySettings;
    Set-NpmProxyConfiguration -Settings $proxySettings;
    Set-AptProxyConfiguration -Settings $proxySettings -NoRoot:$NoRoot;
    Set-DockerProxyConfiguration -Settings $proxySettings;
    Set-PowerShellProxyConfiguration -Settings $proxySettings -NoRoot:$NoRoot;
    Set-EnvironmentProxyConfiguration -Settings $proxySettings -NoRoot:$NoRoot;
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
    if ([string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
        # unset base address
        . "git" "config" "--global" "--unset" "http.proxy";
        . "git" "config" "--global" "--unset" "https.proxy";
    }
    else {
        # set base address
        . "git" "config" "--global" "http.proxy" "$($Settings.ProxyAddress)";
        . "git" "config" "--global" "https.proxy" "$($Settings.ProxyAddress)";

        # only git version 2.13 or higher supports hostname wildcards
        $supportsWildcardHostnames = ((((git version) -split ' ')[2] -split '\.')[0] -ge 2) -and ((((git version) -split ' ')[2] -split '\.')[1] -ge 13);
        # set all new entries
        $Settings.BypassList | ForEach-Object {
            if ($_.Contains('*') -and $supportsWildcardHostnames -eq $false) {
                Write-Warning "Your git version is to old to support wild card hostnames. You must have version 2.13 or higher. We skip the hostname $_";
            }
            else {
                if ($_.StartsWith("https")) {
                    . "git" "config" "--global" "https.$_.proxy" '""';
                }
                elseif ($_.StartsWith("http")) {
                    . "git" "config" "--global" "http.$_.proxy" '""';
                }
                else {
                    . "git" "config" "--global" "http.http://$_.proxy" '""';
                    . "git" "config" "--global" "https.https://$_.proxy" '""';
                }
            }

        }
    }
    # remove old bypasses entries:
    # http
    . "git" "config" "--global" "--get-regexp" "http\.http" | ForEach-Object {
        $bypasskey = $_.Trim();
        if ($bypasskey -match "(http\.)(http.*)(\.proxy)") {
            $bypassedUrl = $matches[2].Trim();
            $shouldBeRemoved = $null -eq ($Settings.BypassList | Where-Object { "http://$_" -like $bypassedUrl });
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
            $shouldBeRemoved = $null -eq ($Settings.BypassList | Where-Object { "https://$_" -like $bypassedUrl });
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
    if ($npmCommand.Path.StartsWith('/mnt/c/Program Files/')) {
        Write-Warning ("In WSL2 you must override your environment variables to the linux version of NPM. " + `
                "We can't currently configure NPM for you.");
        return;
    }
    if ([string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
        # unset base address
        . "npm" "config" "delete" "proxy";
        . "npm" "config" "delete" "https-proxy"
        # TODO: only set the right format
        . "npm" "config" "delete" "no-proxy"; # this is for npm version < 6.4.1
        . "npm" "config" "delete" "noproxy"; # this is for npm verison >= 6.4.1
    }
    else {
        # set base address
        . "npm" "config" "set" "proxy" "$($Settings.ProxyAddress)" | Out-Null;
        . "npm" "config" "set" "https-proxy" "$($Settings.ProxyAddress)" | Out-Null;

        $bypasstring = $(($Settings.BypassList -join ',').Trim());
        # TODO: only set the right format
        . "npm" "config" "set" "no-proxy" "$bypasstring" | Out-Null; # this is for npm version < 6.4.1
        . "npm" "config" "set" "noproxy" $bypasstring | Out-Null; # this is for npm verison >= 6.4.1
    }

}

function Set-AptProxyConfiguration {
    [CmdletBinding()]
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
    try {
        if ((Test-Path "/etc/apt/apt.conf") -eq $false) {
            if ([string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
                # do nothing if no proxy should be configured and the config file don't exsists.
                return;
            }
            # just write the proxy into the file if it doesn't exsists
            "Acquire::http::Proxy ""$($Settings.ProxyAddress)"";" | Set-Content "/etc/apt/apt.conf";
        }
        else {
            $isAProxyAlreadConfigured = $null -ne (. "apt-config" "dump" "Acquire::http::proxy");
            $regexOptions = [System.Text.RegularExpressions.RegexOptions]([System.Text.RegularExpressions.RegexOptions]::Multiline);
            $regexSimplePattern = "Acquire::http::Proxy .*;";
            $regexComplexPattern = "(^Acquire.*{(.|\n)*http.*{(.|\n)*)(proxy "".+"";)((.|\n)*}(.|\n)*})$";
            $regexSimple = New-Object System.Text.RegularExpressions.Regex $regexSimplePattern, $regexOptions;
            $regexComplex = New-Object System.Text.RegularExpressions.Regex $regexComplexPattern, $regexOptions;
            if ($isAProxyAlreadConfigured) {
                $aptConfig = Get-Content "/etc/apt/apt.conf";
                if ([string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
                    # delete proxy config
                    $aptConfig = $regexSimple.Replace($aptConfig, "");
                    $aptConfig = $regexComplex.Replace($aptConfig, "`${1}`${5}");
                }
                else {
                    # add proxy config
                    $aptConfig = $regexSimple.Replace($aptConfig, "Acquire::http::Proxy ""$($Settings.ProxyAddress)"";");
                    $aptConfig = $regexComplex.Replace($aptConfig, "`${1}Proxy `"$($Settings.ProxyAddress)`";`${5}");
                }
                # replace the file with new content
                Write-Warning $aptConfig;
                $aptConfig | Set-Content "/etc/apt/apt.conf";
            }
            else {
                if ([string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
                    # it's okay if no proxy is configured
                    return;
                }
                else {
                    # if no proxy is configured just append the line
                    "Acquire::http::Proxy ""$($Settings.ProxyAddress)"";" | Add-Content -Encoding ascii -NoNewline -Path "/etc/apt/apt.conf";
                }
            }
        }
        if ($null -ne $Settings.BypassList -and $Settings.BypassList.Count -ne 0) {
            Write-Warning "apt-get don't support bypass list. To bypassing the proxy config for a given command starts the command like: 'apt-get -o Acquire::http::proxy=false ....'. This will bypass the proxy for the runtime of the apt-get command.";
        }
    }
    catch [System.UnauthorizedAccessException] {
        if ($NoRoot) {
            Write-Debug "Skip APT configuration because NORoot.";
            return;
        }
        else {
            Write-Error "You must be root to change APT settings." -TargetObject $_ -RecommendedAction "Run powershell as root or specify the `NoRoot` switch." -ErrorAction Stop;
            return;
        }
    }


}

function Set-DockerProxyConfiguration {
    [CmdletBinding()]
    param (
        [ProxySetting]
        $Settings
    )
    if ($null -eq (Get-Command "docker" -ErrorAction SilentlyContinue)) {
        Write-Debug "Unable to find docker on your system. Skip configuration";
        return;
    }
    $json = '{
        "proxies":
        {
            "default":
            {
                "httpProxy": "' + $Settings.ProxyAddress + '",
                "httpsProxy": "' + $Settings.ProxyAddress + '",
                "noProxy": "' + ($Settings.BypassList -join ',') + '"
            }
        }
    }';
    Write-Verbose "$json";
    $proxyConfig = ConvertFrom-Json $json;
    if ((Test-Path "~/.docker/config.json")) {
        $dockerConfig = (Get-Content "~/.docker/config.json" -Raw | ConvertFrom-Json);
        if ([string]::IsNullOrWhiteSpace($Settings.ProxyAddress) -and [bool]($dockerConfig.PSobject.Properties.name -match "proxies")) {
            $dockerConfig.PSobject.Properties.Remove('proxies');
        }
        elseif ($false -eq [bool]($dockerConfig.PSobject.Properties.name -match "proxies")) {
            $dockerConfig |  Add-Member -MemberType NoteProperty -Name "proxies" -Value $proxyConfig.proxies;
        }
        elseif ($false -eq [bool]($dockerConfig.proxies.PSobject.Properties.name -match "default")) {

            $dockerConfig.proxies | Add-Member -MemberType NoteProperty -Name "default" -Value $proxyConfig.proxies.default;
        }
        else {
            $dockerConfig.proxies.default | Add-Member -NotePropertyName "httpProxy" -NotePropertyValue $Settings.ProxyAddress -Force
            $dockerConfig.proxies.default | Add-Member -NotePropertyName "httpsProxy" -NotePropertyValue $Settings.ProxyAddress -Force
            $dockerConfig.proxies.default | Add-Member -NotePropertyName "noProxy" -NotePropertyValue ($Settings.BypassList -join ',') -Force
        }
        ConvertTo-Json $dockerConfig | Set-Content "~/.docker/config.json";
    }
    else {
        if ([string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
            # no proxy should be configured.
            return;
        }
        New-Item "~/.docker" -Force -ItemType Directory | Out-Null;
        ConvertTo-Json $proxyConfig  | Set-Content "~/.docker/config.json" -Force;
    }
}

function Set-PowerShellProxyConfiguration {
    [CmdletBinding()]
    param (
        [ProxySetting]
        $Settings,
        [switch]
        $NoRoot
    )
    if ($NoRoot) {
        Write-Verbose "You can't set a proxy for powershell 5 / 7 without admin / root rights. On Windows try to set IE Settings if this is possible.";
        return;
    }
    if ($Settings.BypassList -ne $null -and $Settings.BypassList.Count -gt 0) {
        $bypasslist = '<bypasslist>
            '+ (
                (($Settings.BypassList | ForEach-Object { "<add address=`"$_`" /> " }) -join [System.Environment]::NewLine)
        ) + '
            </bypasslist>';
    }

    $proxyConfig = '<configuration>
        <system.net>
            <defaultProxy>
            <proxy
                usesystemdefault="true"
                proxyaddress="'+ $Settings.ProxyAddress + '"
                bypassonlocal="true"
            />
            '+ $bypasslist + '
            </defaultProxy>
        </system.net>
    </configuration>';
    Write-Debug "$proxyConfig";
    $powershellConfigExtension = [xml]$proxyConfig;
    function Update-PowerShellConfig {
        [CmdletBinding()]
        param (
            [Parameter()]
            [string]
            $powershellPath
        )

        $configPath = "$powershellPath.config";
        if ((Test-Path $configPath) -eq $false -and [string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
            # do nothing, if the config isn't exsist and no proxy is required.
            return
        }
        #create file if it isn't exsists
        if ((Test-Path $configPath) -eq $false) {
            # set acls for windows
            if ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) {
                $installDir = (Get-Item $powershellPath).Directory.FullName;
                # allow write access to the config file and save the file
                $defaultAcl = Get-Acl "$installDir";
                $aclForPowerShellFile = Get-Acl "$installDir";
                $AdministratorsSID = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544';
                $newRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AdministratorsSID, @("Write"), "None", "InheritOnly", "Allow") ;
                $aclForPowerShellFile.AddAccessRule($newRule);
                Set-Acl -Path "$installDir" $aclForPowerShellFile;
            }
            New-Item $configPath -ItemType File | Out-Null;
            if ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) {
                #revoke access to default:
                Set-Acl -Path "$installDir" $defaultAcl | Out-Null;
            }
        }

        # set acls for windows
        if ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) {
            # allow write access to the config file and save the file
            $defaultAcl = Get-Acl "$configPath";
            $aclForPowerShellFile = Get-Acl "$configPath";
            $AdministratorsSID = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544';
            $newRule = New-Object System.Security.AccessControl.FileSystemAccessRule($AdministratorsSID, @("Write"), "None", "InheritOnly", "Allow") ;
            $aclForPowerShellFile.AddAccessRule($newRule);
            Set-Acl -Path "$configPath" $aclForPowerShellFile;
        }
        $powershellConfig = [xml](Get-Content "$configPath");
        if ($null -eq $powershellConfig) {
            if ([string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
                # no proxy should be confgiured
                return;
            }
            else {
                $proxyConfig | Set-Content $configPath;
            }
        }
        elseif ($null -eq $powershellConfig.configuration -and $false -eq [string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
            $extensionNode = $powershellConfig.ImportNode($powershellConfigExtension.configuration, $true);
            $powershellConfig.AppendChild($extensionNode) | Out-Null;
        }
        elseif ($null -eq $powershellConfig.configuration.'system.net' -and $false -eq [string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
            $extensionNode = $powershellConfig.configuration.OwnerDocument.ImportNode($powershellConfigExtension.configuration.'system.net', $true);
            $powershellConfig.configuration.AppendChild($extensionNode) | Out-Null;
        }
        else {
            # remove old proxy config
            $configuredDefaultProxy = $powershellConfig.configuration.GetElementsByTagName('system.net')[0].GetElementsByTagName("defaultProxy");
            if ($null -ne $configuredDefaultProxy -and $configuredDefaultProxy.Count -gt 0) {
                $powershellConfig.configuration.GetElementsByTagName('system.net')[0].RemoveChild($configuredDefaultProxy[0]) | Out-Null;
            }
            if ($false -eq [string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
                # add new proxy config
                $extensionNode = $powershellConfig.configuration.GetElementsByTagName('system.net')[0].OwnerDocument.ImportNode($powershellConfigExtension.configuration.'system.net'.defaultProxy, $true);
                $powershellConfig.configuration.GetElementsByTagName('system.net')[0].AppendChild($extensionNode) | Out-Null;
            }
        }
        if ($null -ne $powershellConfig) {
            $powershellConfig.Save("$configPath") | Out-Null;
        }
        if ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) {
            #revoke access to default:
            Set-Acl -Path "$configPath" $defaultAcl | Out-Null;
        }
    }

    # pwsh core
    $powershell = (Get-Command "pwsh" -ErrorAction SilentlyContinue);
    if ($null -eq $powershell) {
        Write-Debug "Unable to find PowerShell 7 on your system. Skip configuration";
    }
    else {
        Update-PowerShellConfig -powershellPath ($powershell.Path);
    }

    #Win powershell
    $winPowershell = (Get-Command "powershell" -ErrorAction SilentlyContinue);
    if ($null -eq $winPowershell) {
        Write-Debug "Unable to find PowerShell < 6 on your system. Skip configuration";
    }
    else {
        Update-PowerShellConfig -powershellPath ($winPowershell.Path);
    }

}

function Set-EnvironmentProxyConfiguration {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ProxySetting]
        $Settings,
        [switch]
        $NoRoot
    )
    if ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) {
        # set the process to, to avoid the user must restart the process.
        [Environment]::SetEnvironmentVariable("HTTP_PROXY", $Settings.ProxyAddress, [EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable("HTTPS_PROXY", $Settings.ProxyAddress, [EnvironmentVariableTarget]::Process)
        [Environment]::SetEnvironmentVariable("NO_PROXY", $($Settings.BypassList -join ','), [EnvironmentVariableTarget]::Process)
        if ($NoRoot) {
            [Environment]::SetEnvironmentVariable("HTTPS_PROXY", $Settings.ProxyAddress, [EnvironmentVariableTarget]::User)
            [Environment]::SetEnvironmentVariable("HTTP_PROXY", $Settings.ProxyAddress, [EnvironmentVariableTarget]::User)
            [Environment]::SetEnvironmentVariable("NO_PROXY", $($Settings.BypassList -join ','), [EnvironmentVariableTarget]::User)
        }
        else {
            # Set environment for all users
            [Environment]::SetEnvironmentVariable("HTTP_PROXY", $Settings.ProxyAddress, [EnvironmentVariableTarget]::Machine);
            [Environment]::SetEnvironmentVariable("HTTPS_PROXY", $Settings.ProxyAddress, [EnvironmentVariableTarget]::Machine);
            [Environment]::SetEnvironmentVariable("NO_PROXY", $($Settings.BypassList -join ','), [EnvironmentVariableTarget]::Machine)
        }

    }
    else {
        if ($NoRoot) {
            Write-Warning "Currently to set the environment this script needs root rights. Didn't change any environment varables.";
            # TODO: add user proxy settings for this case.

        }
        else {
            # Set environment for all users
            $proxyshFilePath = "/etc/profile.d/proxy.sh";
            if ([string]::IsNullOrWhiteSpace($Settings.ProxyAddress)) {
                # Remove this content from the file, because a line with:
                # `something=`
                # is an error for some tools. So the lines must be empty
                if (Test-Path -Path $proxyshFilePath) {
                    Remove-Item -Path "/etc/profile.d/proxy.sh" -Force;
                    Write-Verbose "$proxyshFilePath deleted. Proxy settings are resetted.";
                }
                else {
                    Write-Verbose "$proxyshFilePath didn't exsist. Nothing changed.";
                }

            }
            else {
                "export http_proxy=`"$($Settings.ProxyAddress)`"
                export no_proxy=`"$($Settings.BypassList -join ',')`"
                export HTTP_PROXY=$($Settings.ProxyAddress)
                export https_proxy=$($Settings.ProxyAddress)
                export HTTPS_PROXY=$($Settings.ProxyAddress)" | Set-Content -Path $proxyshFilePath;
            }
        }
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