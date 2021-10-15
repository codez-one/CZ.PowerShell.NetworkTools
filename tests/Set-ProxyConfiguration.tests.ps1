Describe "Set-ProxyConfiguration" {
    $skipBecauseLinux = ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) -eq $false;
    $skipBecauseWindows = ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) -eq $true;
    BeforeAll {
        # load function to test
        $fileInfo = Get-ChildItem $PSCommandPath;
        $functionName = $fileInfo.Name.Split('.')[0];
        $file = Get-ChildItem "$PSScriptRoot/../src/$functionName.ps1";
        $targetFileName = "$($file.FullName)";
        # load function to test
        . "$targetFileName";
    }
    Describe "the main function" {

        Context "When Set-ProxyConfiguration is okay and" {
            BeforeAll {
                Mock -Verifiable Test-Path {
                    return $true;
                };
                Mock -Verifiable Set-GitProxyConfiguration {};
                Mock -Verifiable Set-NpmProxyConfiguration {};
                Mock -Verifiable Set-AptProxyConfiguration {};
                Mock -Verifiable Set-DockerProxyConfiguration {};
                Mock -Verifiable Set-PowerShellProxyConfiguration {};
                Mock -Verifiable Set-EnvironmentProxyConfiguration {};
            }
            It("It Should set the proxy") {
                # Arrange
                $ProxyAddress = 'http://proxy.codez.one:8080';
                Mock -Verifiable Get-Content { return '{
                        "ProxyAddress": "'+ $ProxyAddress + '"
                    }'
                }
                $configPath = "something/that/not/exsists";
                # Act
                Set-ProxyConfiguration -ConfigPath "$configPath";
                #Assert
                Assert-MockCalled Test-Path -Times 1 -ParameterFilter { $Path -eq $configPath };
                Assert-MockCalled Get-Content -Times 1 -ParameterFilter { $Path -eq $configPath -and $Raw -eq $true };
                Assert-MockCalled Set-GitProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress };
                Assert-MockCalled Set-NpmProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress };
                Assert-MockCalled Set-AptProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress -and $NoRoot -eq $false };
                Assert-MockCalled Set-DockerProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress };
                Assert-MockCalled Set-PowerShellProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress -and $NoRoot -eq $false };
                Assert-MockCalled Set-EnvironmentProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress -and $NoRoot -eq $false };
            }
            It("It Should set the BypassList") {
                # Arrange
                $BypassAddresses = 'git.codez.one';
                Mock -Verifiable Get-Content { return '{
                        "ProxyAddress": "http://proxy.codez.one:8080",
                        "BypassList": [
                            "'+ $BypassAddresses + '"
                        ]
                    }'
                }
                $configPath = "something/that/not/exsists";
                # Act
                Set-ProxyConfiguration -ConfigPath "$configPath";
                #Assert
                Assert-MockCalled Test-Path -Times 1 -ParameterFilter { $Path -eq $configPath };
                Assert-MockCalled Get-Content -Times 1 -ParameterFilter { $Path -eq $configPath -and $Raw -eq $true };
                Assert-MockCalled Set-GitProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses) };
                Assert-MockCalled Set-NpmProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses) };
                Assert-MockCalled Set-AptProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses) -and $NoRoot -eq $false };
                Assert-MockCalled Set-DockerProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses) };
                Assert-MockCalled Set-PowerShellProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses) -and $NoRoot -eq $false };
                Assert-MockCalled Set-EnvironmentProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses) -and $NoRoot -eq $false };
            }
            It("It Should set the Proxy with the system settings on windows") -Skip:($skipBecauseLinux) {
                # Arrange
                $ProxyAddress = 'http://proxy.codez.one:8080';
                Mock -Verifiable Get-Content { return '{
                        "UseSystemProxyAddress": true
                    }'
                }
                Mock -Verifiable Get-ItemProperty {
                    return [PSCustomObject]@{
                        proxyServer = "$ProxyAddress";
                    };
                }
                $configPath = "something/that/not/exsists";
                # Act
                Set-ProxyConfiguration -ConfigPath "$configPath";
                #Assert
                Assert-MockCalled Test-Path -Times 1 -ParameterFilter { $Path -eq $configPath };
                Assert-MockCalled Get-Content -Times 1 -ParameterFilter { $Path -eq $configPath -and $Raw -eq $true };
                Assert-MockCalled Get-ItemProperty -Times 1 -ParameterFilter { $Path -eq 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' };
                Assert-MockCalled Set-GitProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress };
                Assert-MockCalled Set-NpmProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress };
                Assert-MockCalled Set-AptProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress -and $NoRoot -eq $false };
                Assert-MockCalled Set-DockerProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress };
                Assert-MockCalled Set-PowerShellProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress -and $NoRoot -eq $false };
                Assert-MockCalled Set-EnvironmentProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress -and $NoRoot -eq $false };
            }
        }
        Context "When Set-ProxyConfiguration is not okay and" {
            It("It Should write an error if the config file doesn't exsists.") {
                Mock -Verifiable Test-Path {
                    return $false;
                };
                $configPath = "something/that/not/exsists";
                # Act & assert
                { Set-ProxyConfiguration -ConfigPath "$configPath" } | Should -Throw "The config path doesn't exsists.";
                Assert-MockCalled Test-Path -Times 1 -ParameterFilter { $Path -eq $configPath };

            }
            It("It Should write an error if it wants to use system proxy on linux.") -Skip:($skipBecauseWindows) {
                Mock -Verifiable Test-Path {
                    return $true;
                };
                Mock -Verifiable Get-Content { return '{
                    "UseSystemProxyAddress": true
                }'
                }
                $configPath = "something/that/not/exsists";
                # Act & assert
                { Set-ProxyConfiguration -ConfigPath "$configPath" } | Should -Throw "Currently we don't support linux, to read out the system proxy. Please configure it manualy";
                Assert-MockCalled Test-Path -Times 1 -ParameterFilter { $Path -eq $configPath };
                Assert-MockCalled Get-Content -Times 1 -ParameterFilter { $Path -eq $configPath -and $Raw -eq $true };
            }
        }
    }
    Describe "the git function"{
        Context "When Set-GitProxyConfiguration is okay and"{
            It("'git' is undefined, it shouldn't throw an error."){
                Mock -Verifiable Get-Command {
                    Write-Error "not found";
                }
                Mock -Verifiable "git" {
                    return;
                }
                # act
                Set-GitProxyConfiguration -Settings $null;
                #assert
                Assert-MockCalled Get-Command -Times 1 -ParameterFilter {$Name -eq "git"};
                Assert-MockCalled "git" -Exactly -Times 0;
            }
            It("no proxy should be setted, the proxy should be unset."){
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable "git" {
                    if($args[2] -eq "--get-regexp"){
                        if($args[3] -eq "http\.http"){
                            "http.http://codez.one.proxy ";
                        }else{
                            "https.https://codez.one.proxy ";
                        }
                    }
                    return;
                }
                # act
                Set-GitProxyConfiguration -Settings $null;
                #assert
                Assert-MockCalled Get-Command -Times 1 -ParameterFilter {$Name -eq "git"};
                ## reset proxy entries
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "--unset" -and $args[3] -eq "http.proxy"};
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "--unset" -and $args[3] -eq "https.proxy"};
                ## reset bypass
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "--get-regexp" -and $args[3] -eq "http\.http"};
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "--get-regexp" -and $args[3] -eq "https\.https"};
                ## the removed bypassed is trimmed and in the right way combined
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "--unset" -and $args[3] -eq "http.http://codez.one.proxy"};
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "--unset" -and $args[3] -eq "https.https://codez.one.proxy"};
                ## at the end there should be not more then 6 calls
                Assert-MockCalled "git" -Times 6 -Exactly;
            }
            It("a proxy configuration is required all git commands are running"){
                # arrange
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable "git" {
                    if($args[2] -eq "--get-regexp"){
                        if($args[3] -eq "http\.http"){
                            "http.http://not.okay.proxy ";
                        }else{
                            "https.https://not.okay.proxy ";
                        }
                    }
                    if($args[0] -eq "version"){
                        return "git version 200.250.100"
                    }
                    return;
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "http://codez.one", "https://codez.one";
                # act
                Set-GitProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -ParameterFilter {$Name -eq "git"};
                ## set proxy entries
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "http.proxy" -and $args[3] -eq $settings.ProxyAddress};
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "https.proxy" -and $args[3] -eq $settings.ProxyAddress};
                ## set new bypass entries
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "http.http://codez.one.proxy"};
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "https.https://codez.one.proxy"};
                ## reset old bypass
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "--get-regexp" -and $args[3] -eq "http\.http"};
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "--get-regexp" -and $args[3] -eq "https\.https"};
                ## the removed bypassed is trimmed and in the right way combined
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "--unset" -and $args[3] -eq "http.http://not.okay.proxy"};
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "--unset" -and $args[3] -eq "https.https://not.okay.proxy"};
                ## git version is called
                Assert-MockCalled "git" -Times 2 -Exactly -ParameterFilter {$args[0] -eq 'version'};
                ## at the end there should be not more then 6 calls
                Assert-MockCalled "git" -Times 10 -Exactly;
            }
            It("bypass entry without protocoll is provided, it should set http and https"){
                # arrange
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable "git" {
                    return;
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "codez.one";
                # act
                Set-GitProxyConfiguration -Settings $settings;
                ## set new bypass entries
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "http.http://codez.one.proxy"};
                Assert-MockCalled "git" -Times 1 -Exactly -ParameterFilter {$args[0] -eq 'config' -and $args[1] -eq "--global" -and $args[2] -eq "https.https://codez.one.proxy"};
            }
            it("get version is to old for wildcard, it should warn the user."){
                # arrange
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable "git" {
                    if($args[0] -eq "version"){
                        return "git version 2.0.100"
                    }
                    return;
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one";
                # act
                Set-GitProxyConfiguration -Settings $settings -WarningVariable warning;
                # assert
                $warning | Should -Be "Your git version is to old to support wild card hostnames. You must have version 2.13 or higher. We skip the hostname $($settings.BypassList[0])"
            }
        }
        ## TODO: add tests if the bypass list isn't clean
    }
    Describe "the npm function"{
        Context "When Set-NpmProxyConfiguration is okay and"{
            It("'npm' is undefined, it shouldn't throw an error."){
                Mock -Verifiable Get-Command {
                    Write-Error "not found";
                }
                Mock -Verifiable "npm" {
                    return;
                }
                # act
                Set-NpmProxyConfiguration -Settings $null;
                #assert
                Assert-MockCalled Get-Command -Times 1 -ParameterFilter {$Name -eq "npm"};
                Assert-MockCalled "npm" -Exactly -Times 0;
            }
            It("wsl is active and npm on the path, is the windows npm, it should write an warning."){
                Mock -Verifiable Get-Command {
                    return [pscustomobject]@{Path = "/mnt/c/Program Files/nodejs/npm"};
                }
                Mock -Verifiable "npm" {
                    return;
                }
                # act
                Set-NpmProxyConfiguration -Settings $null -WarningVariable warning;
                #assert
                Assert-MockCalled Get-Command -Times 1 -ParameterFilter {$Name -eq "npm"};
                $warning | Should -Be ("In WSL2 you must override your environment variables to the linux version of NPM. " + `
                "We can't currently configure NPM for you.");
                Assert-MockCalled "npm" -Exactly -Times 0;
            }
            It("no proxy setting is defined, it should reset all npm proxy settings."){
                Mock -Verifiable Get-Command {
                    return [pscustomobject]@{Path = "something"};
                }
                Mock -Verifiable "npm" {
                    return;
                }
                # act
                Set-NpmProxyConfiguration -Settings $null -WarningVariable warning;
                #assert
                Assert-MockCalled Get-Command -Times 1 -ParameterFilter {$Name -eq "npm"};
                ## remove all proxy settings
                Assert-MockCalled "npm" -Times 1 -ParameterFilter {$args[0] -eq "config" -and $args[1] -eq "delete" -and $args[2] -eq "proxy"};
                Assert-MockCalled "npm" -Times 1 -ParameterFilter {$args[0] -eq "config" -and $args[1] -eq "delete" -and $args[2] -eq "https-proxy"};
                Assert-MockCalled "npm" -Times 1 -ParameterFilter {$args[0] -eq "config" -and $args[1] -eq "delete" -and $args[2] -eq "no-proxy"};
                Assert-MockCalled "npm" -Times 1 -ParameterFilter {$args[0] -eq "config" -and $args[1] -eq "delete" -and $args[2] -eq "noproxy"};
                Assert-MockCalled "npm" -Exactly -Times 4;
            }
            It("and proxy settings are defined, it should set all npm proxy settings."){
                Mock -Verifiable Get-Command {
                    return [pscustomobject]@{Path = "something"};
                }
                Mock -Verifiable "npm" {
                    return;
                }
                # act
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                Set-NpmProxyConfiguration -Settings $settings -WarningVariable warning;
                #assert
                Assert-MockCalled Get-Command -Times 1 -ParameterFilter {$Name -eq "npm"};
                ## remove all proxy settings
                Assert-MockCalled "npm" -Times 1 -ParameterFilter {$args[0] -eq "config" -and $args[1] -eq "set" -and $args[2] -eq "proxy" -and $args[3] -eq $settings.ProxyAddress};
                Assert-MockCalled "npm" -Times 1 -ParameterFilter {$args[0] -eq "config" -and $args[1] -eq "set" -and $args[2] -eq "https-proxy" -and $args[3] -eq $settings.ProxyAddress};
                Assert-MockCalled "npm" -Times 1 -ParameterFilter {$args[0] -eq "config" -and $args[1] -eq "set" -and $args[2] -eq "no-proxy" -and $args[3] -eq $(($settings.BypassList -join ',').Trim())};
                Assert-MockCalled "npm" -Times 1 -ParameterFilter {$args[0] -eq "config" -and $args[1] -eq "set" -and $args[2] -eq "noproxy" -and $args[3] -eq $(($settings.BypassList -join ',').Trim())};
                Assert-MockCalled "npm" -Exactly -Times 4;
            }
        }
    }
    Describe "the apt function"{
        Context "When Set-AptProxyConfiguration is okay and" -Skip:($skipBecauseWindows) {
            It("'apt' is undefined, it shouldn't throw an error"){
                # arrage
                Mock -Verifiable Get-Command {
                    Write-Error "not found";
                }
                #act
                Set-AptProxyConfiguration -Settings $null;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
            }
            It("no config exsists and no proxy are required, do nothing."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $false;
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                #act
                Set-AptProxyConfiguration -Settings $null;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
                Assert-MockCalled Set-Content -Times 0 -Exactly;
            }
            It("no config exsists and a proxy is required, write the config."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $false;
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                #act
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                Set-AptProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
                Assert-MockCalled Set-Content -Times 1 -Exactly -ParameterFilter {$Value -eq "Acquire::http::Proxy ""$($settings.ProxyAddress)"";"};
            }
            It("no config exsists and a proxy with bypass is required, write a warning that bypass is not support by apt."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $false;
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                #act
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                Set-AptProxyConfiguration -Settings $settings -WarningVariable warning;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
                Assert-MockCalled Set-Content -Times 1 -Exactly -ParameterFilter {$Value -eq "Acquire::http::Proxy ""$($settings.ProxyAddress)"";"};
                $warning | Should -Be "apt-get does not support bypass list. To bypass the proxy config for a given command start the command like: 'apt-get -o Acquire::http::proxy=false ....'. This will bypass the proxy for the runtime of the apt-get command.";
            }
            It("config exsists but is empty and a proxy is required, write the config."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable Add-Content {
                    return;
                }
                Mock -Verifiable "apt-config" {
                    return $null;
                }
                #act
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                Set-AptProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
                Assert-MockCalled "apt-config" -Times 1 -Exactly -ParameterFilter {$Args[0] -eq "dump" -and $Args[1] -eq "Acquire::http::proxy"};
                Assert-MockCalled Add-Content -Times 1 -Exactly -ParameterFilter {$Value -eq "Acquire::http::Proxy ""$($settings.ProxyAddress)"";" -and $Encoding -eq [System.Text.Encoding]::ASCII};
            }
            It("config exsists but is empty and a no proxy is required, do nothing."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable Add-Content {
                    return;
                }
                Mock -Verifiable "apt-config" {
                    return $null;
                }
                #act
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = $null;
                Set-AptProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
                Assert-MockCalled "apt-config" -Times 1 -Exactly -ParameterFilter {$Args[0] -eq "dump" -and $Args[1] -eq "Acquire::http::proxy"};
                Assert-MockCalled Add-Content -Times 0 -Exactly;
            }
            It("config exsists but isn't empty and a no proxy is required, clean up the proxy settings."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable Get-Content {
                    return "Acquire::http::Proxy ""http://old.proxy:80"";"   + [System.Environment]::NewLine +
                        "Acquire {"  + [System.Environment]::NewLine +
                            "http {"  + [System.Environment]::NewLine +
                                "proxy ""http://old.proxy:80"";"  + [System.Environment]::NewLine +
                            "}" + [System.Environment]::NewLine +
                        "}";
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                Mock -Verifiable "apt-config" {
                    return "something";
                }
                #act
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = $null;
                Set-AptProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
                Assert-MockCalled "apt-config" -Times 1 -Exactly -ParameterFilter {$Args[0] -eq "dump" -and $Args[1] -eq "Acquire::http::proxy"};
                Assert-MockCalled Get-Content -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
                $resultAptConf = [System.Environment]::NewLine +
                    "Acquire {" + [System.Environment]::NewLine +
                    "http {" + [System.Environment]::NewLine +
                    [System.Environment]::NewLine +
                    "}" + [System.Environment]::NewLine +
                    "}";
                Assert-MockCalled Set-Content -Times 1 -Exactly -ParameterFilter {$Value -eq $resultAptConf};
            }
            It("config exsists and isn't empty and a proxy is required, reset the proxy settings."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable Get-Content {
                    return "Acquire::http::Proxy ""http://old.proxy:80"";"   + [System.Environment]::NewLine +
                        "Acquire {"  + [System.Environment]::NewLine +
                            "http {"  + [System.Environment]::NewLine +
                                "proxy ""http://old.proxy:80"";"  + [System.Environment]::NewLine +
                            "}" + [System.Environment]::NewLine +
                        "}";
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                Mock -Verifiable "apt-config" {
                    return "something";
                }
                #act
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                Set-AptProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
                Assert-MockCalled "apt-config" -Times 1 -Exactly -ParameterFilter {$Args[0] -eq "dump" -and $Args[1] -eq "Acquire::http::proxy"};
                Assert-MockCalled Get-Content -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
                $resultAptConf = "Acquire::http::Proxy ""http://proxy.codez.one:8080"";"   +  [System.Environment]::NewLine +
                    "Acquire {" + [System.Environment]::NewLine +
                    "http {" + [System.Environment]::NewLine +
                    "proxy ""http://proxy.codez.one:8080"";"  + [System.Environment]::NewLine +
                    "}" + [System.Environment]::NewLine +
                    "}";
                Assert-MockCalled Set-Content -Times 1 -Exactly -ParameterFilter {$Value -eq $resultAptConf};
            }
            It("user aren't root, but know it, do nothing."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    throw [System.UnauthorizedAccessException] "Your are not root";
                    return $true;
                }
                Mock -Verifiable Get-Content {
                    return "Acquire::http::Proxy ""http://old.proxy:80"";"   + [System.Environment]::NewLine +
                        "Acquire {"  + [System.Environment]::NewLine +
                            "http {"  + [System.Environment]::NewLine +
                                "proxy ""http://old.proxy:80"";"  + [System.Environment]::NewLine +
                            "}" + [System.Environment]::NewLine +
                        "}";
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                Mock -Verifiable "apt-config" {
                    return "something";
                }
                #act
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                Set-AptProxyConfiguration -Settings $settings -NoRoot;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
            }
            It("user aren't root, but don't know it, show an error."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    throw [System.UnauthorizedAccessException] "Your are not root";
                    return $true;
                }
                Mock -Verifiable Get-Content {
                    return "Acquire::http::Proxy ""http://old.proxy:80"";"   + [System.Environment]::NewLine +
                        "Acquire {"  + [System.Environment]::NewLine +
                            "http {"  + [System.Environment]::NewLine +
                                "proxy ""http://old.proxy:80"";"  + [System.Environment]::NewLine +
                            "}" + [System.Environment]::NewLine +
                        "}";
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                Mock -Verifiable "apt-config" {
                    return "something";
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";

                #act & assert
                {Set-AptProxyConfiguration -Settings $settings} | Should -Throw "You must be root to change APT settings.";
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/apt/apt.conf"};
            }
        }
    }
    Describe "the docker function" {
        Context "When Set-DockerProxyConfiguration is okay and" {
            It("'docker' is undefined, it shouldn't throw an error"){
                 # arrage
                 Mock -Verifiable Get-Command {
                    Write-Error "not found";
                }
                #act
                Set-DockerProxyConfiguration -Settings $null;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "docker"};
            }
            It("no config exsists and no proxy are required, do nothing."){
                 # arrage
                 Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $false;
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                #act
                Set-DockerProxyConfiguration -Settings $null;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json"};
                Assert-MockCalled Set-Content -Times 0 -Exactly;
            }
            It("no config exsists and a proxy is required, write the config."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $false;
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                Mock -Verifiable New-Item{
                    return;
                }
                #act
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                Set-DockerProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json"};
                Assert-MockCalled New-Item -Times 1 -Exactly -ParameterFilter {$ItemType -eq "Directory"};
                Assert-MockCalled Set-Content -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json" -and ($Value | ConvertFrom-Json).proxies.default.httpProxy -eq $settings.ProxyAddress -and ($Value | ConvertFrom-Json).proxies.default.httpsProxy -eq $settings.ProxyAddress -and ($Value | ConvertFrom-Json).proxies.default.noProxy -eq ($settings.BypassList -join ',')};
            }
            It("config exsists and no proxy is required, reset proxy settings."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                Mock -Verifiable New-Item{
                    return;
                }
                Mock -Verifiable Get-Content{
                    return '{
                        "someProp": "someValue",
                        "proxies":
                        {
                            "default":
                            {
                                "httpProxy": "http://old.proxy:80",
                                "httpsProxy": "http://old.proxy:80",
                                "noProxy": "old, older"
                            }
                        }
                    }'
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = $null;
                #act
                Set-DockerProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json"};
                Assert-MockCalled Set-Content -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json" -and ($Value | ConvertFrom-Json).PsObject.Properties.name -notmatch "proxies" -and ($Value | ConvertFrom-Json).someProp -eq "someValue"};
            }
            It("config exsists without proxy config and a proxy is required, set proxy settings."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                Mock -Verifiable New-Item{
                    return;
                }
                Mock -Verifiable Get-Content{
                    return '{
                        "someProp": "someValue"
                    }'
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                #act
                Set-DockerProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json"};
                Assert-MockCalled Set-Content -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json" -and ($Value | ConvertFrom-Json).proxies.default.httpProxy -eq $settings.ProxyAddress -and ($Value | ConvertFrom-Json).proxies.default.httpsProxy -eq $settings.ProxyAddress -and ($Value | ConvertFrom-Json).proxies.default.noProxy -eq ($settings.BypassList -join ',') -and ($Value | ConvertFrom-Json).someProp -eq "someValue"};
            }
            It("config exsists with proxy config but without default config and a proxy is required, reset proxy settings."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                Mock -Verifiable New-Item{
                    return;
                }
                Mock -Verifiable Get-Content{
                    return '{
                        "someProp": "someValue",
                        "proxies":
                        {
                            "def":
                            {
                                "httpProxy": "http://old.proxy:80",
                                "httpsProxy": "http://old.proxy:80",
                                "noProxy": "old, older"
                            }
                        }
                    }'
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                #act
                Set-DockerProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json"};
                Assert-MockCalled Set-Content -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json" -and ($Value | ConvertFrom-Json).proxies.default.httpProxy -eq $settings.ProxyAddress -and ($Value | ConvertFrom-Json).proxies.default.httpsProxy -eq $settings.ProxyAddress -and ($Value | ConvertFrom-Json).proxies.default.noProxy -eq ($settings.BypassList -join ',') -and ($Value | ConvertFrom-Json).someProp -eq "someValue"};
            }
            It("config exsists with proxy config and a proxy is required, reset proxy settings."){
                # arrage
                Mock -Verifiable Get-Command {
                    return "not null";
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable Set-Content {
                    return;
                }
                Mock -Verifiable New-Item{
                    return;
                }
                Mock -Verifiable Get-Content{
                    return '{
                        "someProp": "someValue",
                        "proxies":
                        {
                            "default":
                            {
                                "httpProxy": "http://old.proxy:80",
                                "httpsProxy": "http://old.proxy:80",
                                "noProxy": "old, older"
                            }
                        }
                    }'
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                #act
                Set-DockerProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly;
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json"};
                Assert-MockCalled Set-Content -Times 1 -Exactly -ParameterFilter {$Path -eq "~/.docker/config.json" -and ($Value | ConvertFrom-Json).proxies.default.httpProxy -eq $settings.ProxyAddress -and ($Value | ConvertFrom-Json).proxies.default.httpsProxy -eq $settings.ProxyAddress -and ($Value | ConvertFrom-Json).proxies.default.noProxy -eq ($settings.BypassList -join ',') -and ($Value | ConvertFrom-Json).someProp -eq "someValue"};
            }
        }
    }
    Describe "the powershell function" {
        Context "When Set-PowerShellProxyConfiguration is okay and"  -Skip:($skipBecauseWindows){
            It("user aren't root, but know it, do nothing."){
                # arrage
                Mock -Verifiable Get-Command {
                }
                Mock -Verifiable Test-Path {
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                #act
                Set-PowerShellProxyConfiguration -Settings $settings -NoRoot;
                # assert
                Assert-MockCalled Get-Command -Times 0 -Exactly;
                Assert-MockCalled Test-Path -Times 0 -Exactly;
            }
            It("'pwsh' and 'powershell' isn't there, do nothing."){
                # arrage
                Mock -Verifiable Get-Command {
                    Write-Error "not found";
                }
                Mock -Verifiable Test-Path {
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                #act
                Set-PowerShellProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "pwsh"};
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "powershell"};
                Assert-MockCalled Test-Path -Times 0 -Exactly;
            }
            It("no config exsists and no proxy are required, do nothing."){
                # arrage
                Mock -Verifiable Get-Command {
                    return [pscustomobject]@{Path = "something"};
                }
                Mock -Verifiable Test-Path {
                    return $false;
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                #act
                Set-PowerShellProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "pwsh"};
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "powershell"};
                Assert-MockCalled Test-Path -Times 2 -Exactly -ParameterFilter {$Path -eq "something.config"};
            }
            It("no config exsists and a proxy is required, write the config."){
                # arrage
                Mock -Verifiable Get-Command {
                    return [pscustomobject]@{Path = "something"};
                }
                Mock -Verifiable Test-Path {
                    return $false;
                }
                Mock -Verifiable New-Item {
                    return;
                }
                Mock -Verifiable Get-Content {
                    return $null;
                }
                Mock -Verifiable Set-Content {
                    return "";
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                #act
                Set-PowerShellProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "pwsh"};
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "powershell"};
                Assert-MockCalled Test-Path -Times 4 -Exactly -ParameterFilter {$Path -eq "something.config"};
                Assert-MockCalled New-Item -Times 2 -Exactly -ParameterFilter {$Path -eq "something.config" -and $ItemType -eq "File"};
                Assert-MockCalled Get-Content -Times 2 -Exactly -ParameterFilter {$Path -eq "something.config"};
                Assert-MockCalled Set-Content -Times 2 -Exactly -ParameterFilter {$Path -eq "something.config" -and ([xml]$Value).configuration["system.net"].defaultProxy.proxy.proxyaddress -eq $settings.ProxyAddress -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist -eq $null};

            }
            It("a proxy and a bypasslist is required, write both to the config."){
                # arrage
                Mock -Verifiable Get-Command {
                    return [pscustomobject]@{Path = "something"};
                }
                Mock -Verifiable Test-Path {
                    return $false;
                }
                Mock -Verifiable New-Item {
                    return;
                }
                Mock -Verifiable Get-Content {
                    return $null;
                }
                Mock -Verifiable Set-Content {
                    return "";
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                #act
                Set-PowerShellProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "pwsh"};
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "powershell"};
                Assert-MockCalled Test-Path -Times 4 -Exactly -ParameterFilter {$Path -eq "something.config"};
                Assert-MockCalled New-Item -Times 2 -Exactly -ParameterFilter {$Path -eq "something.config" -and $ItemType -eq "File"};
                Assert-MockCalled Get-Content -Times 2 -Exactly -ParameterFilter {$Path -eq "something.config"};
                Assert-MockCalled Set-Content -Times 2 -Exactly -ParameterFilter {$Path -eq "something.config" -and ([xml]$Value).configuration["system.net"].defaultProxy.proxy.proxyaddress -eq $settings.ProxyAddress -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist.add[0].address -eq $settings.BypassList[0] -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist.add[1].address -eq $settings.BypassList[1]};
            }
            It("config is already exsists but is empty a proxy and a bypasslist is required, write both to the config"){
                # arrage
                Mock -Verifiable Get-Command {
                    # use testdrive here, because the XML function save will use it.
                    return [pscustomobject]@{Path = "$TestDrive/something"};
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable New-Item {
                    return;
                }
                Mock -Verifiable Get-Content {
                    return '';
                }
                Mock -Verifiable Set-Content {
                    return "";
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                #act
                Set-PowerShellProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "pwsh"};
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "powershell"};
                Assert-MockCalled Test-Path -Times 4 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config"};
                Assert-MockCalled New-Item -Times 0 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and $ItemType -eq "File"};
                Assert-MockCalled Get-Content -Times 2 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config"};
                Assert-MockCalled Set-Content -Times 0 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and ([xml]$Value).configuration["system.net"].defaultProxy.proxy.proxyaddress -eq $settings.ProxyAddress -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist.add[0].address -eq $settings.BypassList[0] -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist.add[1].address -eq $settings.BypassList[1]};
            }
            It("config is already used a proxy and a bypasslist is required, write both to the config, without destroying exsisting configuration."){
                # arrage
                Mock -Verifiable Get-Command {
                    # use testdrive here, because the XML function save will use it.
                    return [pscustomobject]@{Path = "$TestDrive/something"};
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable New-Item {
                    return;
                }
                Mock -Verifiable Get-Content {
                    return '<configuration>
                        <someconfig>testvalue</someconfig>
                    </configuration>';
                }
                Mock -Verifiable Set-Content {
                    return "";
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                #act
                Set-PowerShellProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "pwsh"};
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "powershell"};
                Assert-MockCalled Test-Path -Times 4 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config"};
                Assert-MockCalled New-Item -Times 0 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and $ItemType -eq "File"};
                Assert-MockCalled Get-Content -Times 2 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config"};
                Assert-MockCalled Set-Content -Times 0 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and ([xml]$Value).configuration["system.net"].defaultProxy.proxy.proxyaddress -eq $settings.ProxyAddress -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist.add[0].address -eq $settings.BypassList[0] -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist.add[1].address -eq $settings.BypassList[1]};
                ([xml](Get-Content TestDrive:/something.config)).configuration.someconfig | Should -Be "testvalue";
            }
            It("config is already used a proxy and a bypasslist is required, write both to the config, without destroying exsisting configuration.system.net."){
                # arrage
                Mock -Verifiable Get-Command {
                    # use testdrive here, because the XML function save will use it.
                    return [pscustomobject]@{Path = "$TestDrive/something"};
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable New-Item {
                    return;
                }
                Mock -Verifiable Get-Content {
                    return '<configuration>
                        <system.net>
                            <someconfig>testvalue</someconfig>
                        </system.net>
                    </configuration>';
                }
                Mock -Verifiable Set-Content {
                    return "";
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                #act
                Set-PowerShellProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "pwsh"};
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "powershell"};
                Assert-MockCalled Test-Path -Times 4 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config"};
                Assert-MockCalled New-Item -Times 0 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and $ItemType -eq "File"};
                Assert-MockCalled Get-Content -Times 2 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config"};
                Assert-MockCalled Set-Content -Times 0 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and ([xml]$Value).configuration["system.net"].defaultProxy.proxy.proxyaddress -eq $settings.ProxyAddress -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist.add[0].address -eq $settings.BypassList[0] -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist.add[1].address -eq $settings.BypassList[1]};
                ([xml](Get-Content TestDrive:/something.config)).configuration["system.net"].someconfig | Should -Be "testvalue";
            }
            It("config had alread proxy, but enother proxy and bypasslist is required, write both to the config, and remove the old one"){
                # arrage
                Mock -Verifiable Get-Command {
                    # use testdrive here, because the XML function save will use it.
                    return [pscustomobject]@{Path = "$TestDrive/something"};
                }
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable New-Item {
                    return;
                }
                Mock -Verifiable Get-Content {
                    return '<configuration>
                        <system.net>
                            <defaultProxy>
                            <proxy
                                usesystemdefault="true"
                                proxyaddress="http://old.proxy:80"
                                bypassonlocal="true"
                            />
                            <bypasslist>
                                <add address="old" />
                            </bypasslist>
                        </defaultProxy>
                        </system.net>
                    </configuration>';
                }
                Mock -Verifiable Set-Content {
                    return "";
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                $settings.BypassList = "*.codez.one", "codez.one";
                #act
                Set-PowerShellProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "pwsh"};
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "powershell"};
                Assert-MockCalled Test-Path -Times 4 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config"};
                Assert-MockCalled New-Item -Times 0 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and $ItemType -eq "File"};
                Assert-MockCalled Get-Content -Times 2 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config"};
                Assert-MockCalled Set-Content -Times 0 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and ([xml]$Value).configuration["system.net"].defaultProxy.proxy.proxyaddress -eq $settings.ProxyAddress -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist.add[0].address -eq $settings.BypassList[0] -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist.add[1].address -eq $settings.BypassList[1]};
            }
        }
        Context "When Set-PowerShellProxyConfiguration is running in Windows and" -Skip:($skipBecauseLinux) {
            It("no config exsists and a proxy is required, write the config."){
                # arrage
                $defaultAcl = (New-Object System.Security.AccessControl.DirectorySecurity);
                Mock -Verifiable Get-Command {
                    return [pscustomobject]@{Path = "$TestDrive/something"};
                }
                Mock -Verifiable Test-Path {
                    return $false;
                }
                Mock -Verifiable New-Item {
                    return;
                }
                Mock -Verifiable Get-Item {
                    return ([pscustomobject]@{
                        Directory = [pscustomobject]@{
                            FullName = "$TestDrive"
                        }
                    });
                }
                Mock -Verifiable Get-Content {
                    return $null;
                }
                Mock -Verifiable Set-Content {
                    return "";
                }
                Mock -Verifiable Get-Acl {
                    return $defaultAcl;
                }
                Mock -Verifiable Set-Acl {
                    return;
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                #act
                Set-PowerShellProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "pwsh"};
                Assert-MockCalled Get-Command -Times 1 -Exactly -ParameterFilter {$Name -eq "powershell"};
                Assert-MockCalled Test-Path -Times 4 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config"};
                Assert-MockCalled New-Item -Times 2 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and $ItemType -eq "File"};
                Assert-MockCalled Get-Content -Times 2 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config"};
                Assert-MockCalled Set-Content -Times 2 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and ([xml]$Value).configuration["system.net"].defaultProxy.proxy.proxyaddress -eq $settings.ProxyAddress -and ([xml]$Value).configuration["system.net"].defaultProxy.bypasslist -eq $null};

                ## make sure to set and reset folder acl
                Assert-MockCalled Set-Acl -Times 4 -Exactly -ParameterFilter {$Path -eq "$TestDrive" -and $AclObject.Access.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq "S-1-5-32-544" -and $AclObject.Access.AccessControlType -eq "Allow"};
                Assert-MockCalled Set-Acl -Times 4 -Exactly -ParameterFilter {$Path -eq "$TestDrive" -and $AclObject -eq $defaultAcl};

                ## make sure to set and reset file acl
                Assert-MockCalled Set-Acl -Times 4 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and $AclObject.Access.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq "S-1-5-32-544" -and $AclObject.Access.AccessControlType -eq "Allow"};
                Assert-MockCalled Set-Acl -Times 4 -Exactly -ParameterFilter {$Path -eq "$TestDrive/something.config" -and $AclObject -eq $defaultAcl};
            }
        }
    }
    Describe "the environment function" {
        Context "When Set-EnvironmentProxyConfiguration is okay and"  -Skip:($skipBecauseWindows){
            It("user aren't root, but know it, do nothing."){
                # arrage
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                #act
                Set-EnvironmentProxyConfiguration -Settings $settings -NoRoot -WarningVariable warning;
                # assert
                $warning | Should -Be "Currently to set the environment this script needs root rights. Didn't change any environment varables.";
            }
            It("no config exsists and no proxy are required, do nothing."){
                # arrage
                Mock -Verifiable Test-Path {
                    return $false;
                }
                Mock -Verifiable Remove-Item {
                    return $false;
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                #act
                Set-EnvironmentProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/profile.d/proxy.sh"};
                Assert-MockCalled Remove-Item -Times 0 -Exactly -ParameterFilter {$Path -eq "/etc/profile.d/proxy.sh"};
            }
            It("a proxy is required, write the config."){
                # arrage
                Mock -Verifiable Set-Content {
                    return ;
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                $settings.ProxyAddress = "http://proxy.codez.one:8080";
                #act
                Write-Warning "start";
                Set-EnvironmentProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Set-Content -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/profile.d/proxy.sh" -and ([string]$Value).Contains("export http_proxy=$($settings.ProxyAddress)") -and ([string]$Value).Contains("export https_proxy=$($settings.ProxyAddress)") -and ([string]$Value).Contains("export no_proxy=$($Settings.BypassList -join ',')") -and ([string]$Value).Contains("export HTTPS_PROXY=$($settings.ProxyAddress)") -and ([string]$Value).Contains("export HTTP_PROXY=$($settings.ProxyAddress)")};
            }
            It("no proxy is required but config exsists, remove it."){
                # arrage
                Mock -Verifiable Test-Path {
                    return $true;
                }
                Mock -Verifiable Remove-Item {
                    return;
                }
                $settings = [ProxySetting](New-Object ProxySetting);
                #act
                Set-EnvironmentProxyConfiguration -Settings $settings;
                # assert
                Assert-MockCalled Test-Path -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/profile.d/proxy.sh"};
                Assert-MockCalled Remove-Item -Times 1 -Exactly -ParameterFilter {$Path -eq "/etc/profile.d/proxy.sh"};
            }
        }
        Context "When Set-PowerShellProxyConfiguration is running in Windows and" -Skip:($skipBecauseLinux) {
           # TODO: Can't test static dotnet calls. Needs a solution for this.
        }
    }
}