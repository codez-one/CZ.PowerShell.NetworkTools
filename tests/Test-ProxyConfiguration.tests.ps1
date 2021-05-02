Describe "Test-ProxyConfiguration" {
    BeforeAll { 
        $fileInfo = Get-ChildItem $PSScriptRoot;
        $functionName = $fileInfo.Name.Split('.')[0];
        # load function to test
        . "$PSScriptRoot/../src/$functionName.ps1";
    }
    Context "When Test-Connection is okay and" {
        BeforeEach {
            Mock -Verifiable Test-NetConnection {
                return [PSCustomObject]@{
                    TcpTestSucceeded = $true;
                };
            };
        }
        Context "When invoke webrequest is okay" {
            BeforeEach {
                Mock -Verifiable Invoke-WebRequest { return $true };
            }
            It 'It should detect the issue in the bypass configuration' {
                $proxy = New-Object System.Net.WebProxy("http://test.local:80");
                $proxy.BypassList = @();
                $proxy.BypassProxyOnLocal = $false;
                $url = "https://target.local";
                [ProxyTestResult]$output = Test-ProxyConfiguration -Proxy $proxy $url;
                $output.IsOnBypassList | Should -Be $false;
                $output.DirectAccessPossible | Should -Be $true;
                $output.TestedHostname | Should -Be "target.local";
                $output.originalException | Should -Be $null;
                $output.BypassListRecommended() | Should -Be $true;
                Assert-MockCalled Test-NetConnection -Times 1 -ParameterFilter { $Port -eq 443 -and $ComputerName -eq "target.local" };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -eq $url };
            }
            It 'It should detect the correct configuration of the bypass list' {
                $proxy = New-Object System.Net.WebProxy("http://test.local:80");
                $proxy.BypassList = @("target.local");
                $proxy.BypassProxyOnLocal = $false;
                $url = "https://target.local";
                [ProxyTestResult]$output = Test-ProxyConfiguration -Proxy $proxy $url;
                $output.IsOnBypassList | Should -Be $true;
                $output.DirectAccessPossible | Should -Be $true;
                $output.TestedHostname | Should -Be "target.local";
                $output.originalException | Should -Be $null;
                $output.BypassListRecommended() | Should -Be $true;
                Assert-MockCalled Test-NetConnection -Times 1 -ParameterFilter { $Port -eq 443 -and $ComputerName -eq "target.local" };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -eq $url };
            }
        }
        Context "When invoke webrequest isn't okay" {
            BeforeEach {
                Mock -Verifiable Invoke-WebRequest { throw "something bad!"; };
            }
            It 'It should detect the issue in the bypass configuration and the exception.' {
                $proxy = New-Object System.Net.WebProxy("http://test.local:80");
                $proxy.BypassList = @();
                $proxy.BypassProxyOnLocal = $false;
                $url = "https://target.local";
                [ProxyTestResult]$output = Test-ProxyConfiguration -Proxy $proxy $url;
                $output.IsOnBypassList | Should -Be $false;
                $output.DirectAccessPossible | Should -Be $true;
                $output.TestedHostname | Should -Be "target.local";
                $output.originalException | Should -Be "something bad!";
                $output.BypassListRecommended() | Should -Be $true;
                Assert-MockCalled Test-NetConnection -Times 1 -ParameterFilter { $Port -eq 443 -and $ComputerName -eq "target.local" };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -eq $url };
            }
            It 'It should detect the correct configuration of the bypass list and the exception.' {
                $proxy = New-Object System.Net.WebProxy("http://test.local:80");
                $proxy.BypassList = @("target.local");
                $proxy.BypassProxyOnLocal = $false;
                $url = "https://target.local";
                [ProxyTestResult]$output = Test-ProxyConfiguration -Proxy $proxy $url;
                $output.IsOnBypassList | Should -Be $true;
                $output.DirectAccessPossible | Should -Be $true;
                $output.TestedHostname | Should -Be "target.local";
                $output.originalException | Should -Be "something bad!";
                $output.BypassListRecommended() | Should -Be $true;
                Assert-MockCalled Test-NetConnection -Times 1 -ParameterFilter { $Port -eq 443 -and $ComputerName -eq "target.local" };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -eq $url };
            }
        }
    }
    Context "When Test-Connection isn't okay and" {
        BeforeEach {
            Mock -Verifiable Test-NetConnection {
                return [PSCustomObject]@{
                    TcpTestSucceeded = $false;
                };
            };
        }
        Context "When invoke webrequest is okay" {
            BeforeEach {
                Mock -Verifiable Invoke-WebRequest { return $true };
            }
            It 'It should detect the issue in the bypass configuration' {
                $proxy = New-Object System.Net.WebProxy("http://test.local:80");
                $proxy.BypassList = @();
                $proxy.BypassProxyOnLocal = $false;
                $url = "https://target.local";
                [ProxyTestResult]$output = Test-ProxyConfiguration -Proxy $proxy $url;
                $output.IsOnBypassList | Should -Be $false;
                $output.DirectAccessPossible | Should -Be $false;
                $output.TestedHostname | Should -Be "target.local";
                $output.originalException | Should -Be $null;
                $output.BypassListRecommended() | Should -Be $false;
                Assert-MockCalled Test-NetConnection -Times 1 -ParameterFilter { $Port -eq 443 -and $ComputerName -eq "target.local" };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -eq $url };
            }
            It 'It should detect the correct configuration of the bypass list' {
                $proxy = New-Object System.Net.WebProxy("http://test.local:80");
                $proxy.BypassList = @("target.local");
                $proxy.BypassProxyOnLocal = $false;
                $url = "https://target.local";
                [ProxyTestResult]$output = Test-ProxyConfiguration -Proxy $proxy $url;
                $output.IsOnBypassList | Should -Be $true;
                $output.DirectAccessPossible | Should -Be $false;
                $output.TestedHostname | Should -Be "target.local";
                $output.originalException | Should -Be $null;
                $output.BypassListRecommended() | Should -Be $false;
                Assert-MockCalled Test-NetConnection -Times 1 -ParameterFilter { $Port -eq 443 -and $ComputerName -eq "target.local" };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -eq $url };
            }
        }
        Context "When invoke webrequest isn't okay" {
            BeforeEach {
                Mock -Verifiable Invoke-WebRequest { throw "something bad!"; };
            }
            It 'It should detect the issue in the bypass configuration and the exception.' {
                $proxy = New-Object System.Net.WebProxy("http://test.local:80");
                $proxy.BypassList = @();
                $proxy.BypassProxyOnLocal = $false;
                $url = "https://target.local";
                [ProxyTestResult]$output = Test-ProxyConfiguration -Proxy $proxy $url;
                $output.IsOnBypassList | Should -Be $false;
                $output.DirectAccessPossible | Should -Be $false;
                $output.TestedHostname | Should -Be "target.local";
                $output.originalException | Should -Be "something bad!";
                $output.BypassListRecommended() | Should -Be $false;
                Assert-MockCalled Test-NetConnection -Times 1 -ParameterFilter { $Port -eq 443 -and $ComputerName -eq "target.local" };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -eq $url };
            }
            It 'It should detect the correct configuration of the bypass list and the exception.' {
                $proxy = New-Object System.Net.WebProxy("http://test.local:80");
                $proxy.BypassList = @("target.local");
                $proxy.BypassProxyOnLocal = $false;
                $url = "https://target.local";
                [ProxyTestResult]$output = Test-ProxyConfiguration -Proxy $proxy $url;
                $output.IsOnBypassList | Should -Be $true;
                $output.DirectAccessPossible | Should -Be $false;
                $output.TestedHostname | Should -Be "target.local";
                $output.originalException | Should -Be "something bad!";
                $output.BypassListRecommended() | Should -Be $false;
                Assert-MockCalled Test-NetConnection -Times 1 -ParameterFilter { $Port -eq 443 -and $ComputerName -eq "target.local" };
                Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -eq $url };
            }
        }
    }
    
}
Describe "ProxyTestResult" {
    BeforeAll { 
        $fileInfo = Get-ChildItem $PSScriptRoot;
        $functionName = $fileInfo.Name.Split('.')[0];
        # load function to test
        . "$PSScriptRoot/../src/$functionName.ps1";
    }
    Context 'everthing is perfect' {
        It 'It should print a good message, if the bypass list is used correct.' {
            [ProxyTestResult]$Output = New-Object ProxyTestResult;
            $Output.DirectAccessPossible = $true;
            $Output.IsOnBypassList = $true;
            $Output.originalException = $null;
            $Output.TestedHostname = "somehostname";
            $Output.CreateMessage();
            $Output.Message | Should -Be "[OK] Everything is configure right for '$($Output.TestedHostname)'.":
        }
        It 'It should print a good message, if the proxy is used correct.' {
            [ProxyTestResult]$Output = New-Object ProxyTestResult;
            $Output.DirectAccessPossible = $false;
            $Output.IsOnBypassList = $false;
            $Output.originalException = $null;
            $Output.TestedHostname = "somehostname";
            $Output.CreateMessage();
            $Output.Message | Should -Be "[OK] Everything is configure right for '$($Output.TestedHostname)'.":
        }
    }
    Context 'the proxy isn´t configured right' {
        It 'It should print a error message, if the bypass list isn´t used correct.' {
            [ProxyTestResult]$Output = New-Object ProxyTestResult;
            $Output.DirectAccessPossible = $false;
            $Output.IsOnBypassList = $true;
            $Output.originalException = $null;
            $Output.TestedHostname = "somehostname";
            $Output.CreateMessage();
            $Output.Message | Should -Be "[ERROR] You must use the proxy. Remove '$($Output.TestedHostname)' from the ByPass list.":
        }
        It 'It should print a warning, if the proxy is used not correct.' {
            [ProxyTestResult]$Output = New-Object ProxyTestResult;
            $Output.DirectAccessPossible = $true;
            $Output.IsOnBypassList = $false;
            $Output.originalException = $null;
            $Output.TestedHostname = "somehostname";
            $Output.CreateMessage();
            $Output.Message | Should -Be "[WARN] You can access the site. The configuration isn't optimal, because you have direct access but uses the proxy. Add '$($Output.TestedHostname)' to the ByPass list.":
        }
        It 'It should print a error message, if the proxy is used not correct.' {
            [ProxyTestResult]$Output = New-Object ProxyTestResult;
            $Output.DirectAccessPossible = $true;
            $Output.IsOnBypassList = $false;
            try {
                throw "something bad!"
            }
            catch {
                $Output.originalException = $_;
            }
            
            $Output.TestedHostname = "somehostname";
            $Output.CreateMessage();
            $Output.Message | Should -Be "[ERROR] You have direct access but uses the proxy. Add '$($Output.TestedHostname)' to the ByPass list.":
        }
    }
    Context 'the proxy configuration looks right, but we have errors' {
        It 'It should print a error message, if the bypass list is used correct.' {
            [ProxyTestResult]$Output = New-Object ProxyTestResult;
            $Output.DirectAccessPossible = $true;
            $Output.IsOnBypassList = $true;
            try {
                throw "something bad!"
            }
            catch {
                $Output.originalException = $_;
            }
            
            $Output.TestedHostname = "somehostname";
            $Output.CreateMessage();
            $Output.Message | Should -Be "[ERROR] The proxy configuration seems to be right! But something else happend. See the originalException.":
        }
        It 'It should print a error message, if the proxy is used correct.' {
            [ProxyTestResult]$Output = New-Object ProxyTestResult;
            $Output.DirectAccessPossible = $false;
            $Output.IsOnBypassList = $false;
            try {
                throw "something bad!"
            }
            catch {
                $Output.originalException = $_;
            }
            
            $Output.TestedHostname = "somehostname";
            $Output.CreateMessage();
            $Output.Message | Should -Be "[ERROR] The proxy configuration seems to be right! But something else happend. See the originalException.":
        }
    }
}