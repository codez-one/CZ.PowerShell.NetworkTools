Describe "Set-ProxyConfiguration" {
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
                Assert-MockCalled Set-NpmProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses)};
                Assert-MockCalled Set-AptProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses) -and $NoRoot -eq $false };
                Assert-MockCalled Set-DockerProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses) };
                Assert-MockCalled Set-PowerShellProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses) -and $NoRoot -eq $false };
                Assert-MockCalled Set-EnvironmentProxyConfiguration -Times 1 -ParameterFilter { $Settings.BypassList.Contains($BypassAddresses) -and $NoRoot -eq $false };
            }
            It("It Should set the Proxy with the system settings on windows") {
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
                Assert-MockCalled Get-ItemProperty -Times 1 -ParameterFilter { $Path -eq 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'};
                Assert-MockCalled Set-GitProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress };
                Assert-MockCalled Set-NpmProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress};
                Assert-MockCalled Set-AptProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress -and $NoRoot -eq $false };
                Assert-MockCalled Set-DockerProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress };
                Assert-MockCalled Set-PowerShellProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress -and $NoRoot -eq $false };
                Assert-MockCalled Set-EnvironmentProxyConfiguration -Times 1 -ParameterFilter { $Settings.ProxyAddress -eq $ProxyAddress -and $NoRoot -eq $false };
            }
        }
    }
}