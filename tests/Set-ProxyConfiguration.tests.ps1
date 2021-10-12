Describe "Set-ProxyConfiguration" {
    $skipBecauseLinux = ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) -eq $false;
    $skipBecauseWindows = ($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows) -eq $true;
    BeforeAll {
        $fileInfo = Get-ChildItem $PSScriptRoot;
        $functionName = $fileInfo.Name.Split('.')[0];
        # load function to test
        . "$PSScriptRoot/../src/$functionName.ps1";
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
                # act
                Set-GitProxyConfiguration -Settings $null;
                #assert
                Assert-MockCalled Get-Command -Times 1 -ParameterFilter {$Name -eq "git"};
            }
            It("if no proxy should be setted, the proxy should be unset."){
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
        }
    }
}