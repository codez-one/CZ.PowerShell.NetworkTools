Set-StrictMode -Version Latest;
function Test-ProxyConfiguration {
    [CmdletBinding(HelpURI="https://github.com/codez-one/CZ.PowerShell.NetworkTools/blob/main/docs/Commands/Test-ProxyConfiguration.md")]
    param (
        # The target URL that you are trying to test.
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 0,
            HelpMessage = "Enter the URL you are trying to test."
        )]
        [string]
        $Uri,
        # Set a proxy that is different from your system configuration.
        # This is optional
        [Parameter(Mandatory = $false)]
        [System.Net.IWebProxy]
        $Proxy = [System.Net.WebRequest]::GetSystemWebProxy()
    )

    begin {
        # set display properties for ProxyTestResult
        Update-TypeData -TypeName "ProxyTestResult" -DefaultDisplayPropertySet 'TestedHostname', 'DirectAccessPossible', 'Message' -Force

        # set the current system proxy config, as config for the powershell session
        $oldProxy = [System.Net.WebRequest]::DefaultWebProxy;
        [System.Net.WebRequest]::DefaultWebProxy = $Proxy;
    }

    process {
        [ProxyTestResult]$output = New-Object ProxyTestResult;
        [System.Uri]$fullUri = $null;
        try {
            [System.Uri]$fullUri = New-Object System.Uri $Uri;
        }
        catch {
            Write-Error "The value for the parameter 'URI' isn't a URI." -ErrorAction Stop;
        }

        $output.IsOnBypassList = [System.Net.WebRequest]::DefaultWebProxy.IsBypassed($Uri);
        $output.TestedHostname = $fullUri.DnsSafeHost;
        if($PSVersionTable.PSEdition -eq "Desktop" -or $IsWindows){
            $netConnectionResult = Test-NetConnection $output.TestedHostname  -Port $fullUri.Port;
            $output.DirectAccessPossible = $netConnectionResult.TcpTestSucceeded;
        }else{
            $output.DirectAccessPossible = Test-Connection $output.TestedHostname  -TcpPort $fullUri.Port;
        }

        try {
            Invoke-WebRequest $Uri -UseBasicParsing -ErrorAction Stop -MaximumRedirection 0 | Out-Null;
            $output.CreateMessage();
            Write-Output $output;
        }
        catch {
            $requestError = $_;
            if (
                # this is for powershell 7 and above
                ($requestError.FullyQualifiedErrorId -eq "MaximumRedirectExceeded,Microsoft.PowerShell.Commands.InvokeWebRequestCommand") -or
                # this is for powershell 5.1
                ($requestError.FullyQualifiedErrorId -eq "WebCmdletWebResponseException,Microsoft.PowerShell.Commands.InvokeWebRequestCommand")
            ) {
                if ($null -ne (($requestError.Exception | Get-Member).Name | ?{$_ -like 'Respone'}) -and $requestError.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::ServiceUnavailable) {
                    $output.originalException = $requestError;
                }
                $output.CreateMessage();
                Write-Output $output;
            }
            else {
                $output.originalException = $requestError;
                $output.CreateMessage();
                Write-Output $output;
            }
        }
    }

    end {
        # clean up the custemized proxy
        [System.Net.WebRequest]::DefaultWebProxy = $oldProxy;
    }
}

class ProxyTestResult {
    [string] $TestedHostname;
    [bool] $DirectAccessPossible;
    [bool] BypassListRecommended() { return $this.DirectAccessPossible; }
    [bool] $IsOnBypassList;
    [System.Management.Automation.ErrorRecord] $originalException = $null;
    [string] $Message;
    [void] CreateMessage() {
        if ($this.IsOnBypassList -and $this.DirectAccessPossible -and $null -eq $this.originalException) {
            $this.Message = "[OK] Everything is configure right for '$($this.TestedHostname)'.";
            return;
        }
        if ($this.IsOnBypassList -eq $false -and $this.DirectAccessPossible -eq $false -and $null -eq $this.originalException) {
            $this.Message = "[OK] Everything is configure right for '$($this.TestedHostname)'.";
            return;
        }
        if (
            $this.IsOnBypassList -eq $false -and
            $this.DirectAccessPossible -and
            $null -eq $this.originalException) {
            $this.Message = "[WARN] You can access the site. The configuration isn't optimal, because you have direct access but uses the proxy. Add '$($this.TestedHostname)' to the ByPass list.";
            return;
        }
        if ($this.IsOnBypassList -and $this.DirectAccessPossible -and $null -ne $this.originalException) {
            $this.Message = "[ERROR] The proxy configuration seems to be right! But something else happend. See the originalException.";
            return;
        }
        if (
            $this.IsOnBypassList -eq $false -and
            $this.DirectAccessPossible -and
            $null -ne $this.originalException) {
            $this.Message = "[ERROR] You have direct access but uses the proxy. Add '$($this.TestedHostname)' to the ByPass list.";
            return;
        }
        if (
            $this.IsOnBypassList -and
            $this.DirectAccessPossible -eq $false) {
            $this.Message = "[ERROR] You must use the proxy. Remove '$($this.TestedHostname)' from the ByPass list.";
            return;
        }
        if ($this.IsOnBypassList -eq $false -and $this.DirectAccessPossible -eq $false -and $null -ne $this.originalException) {
            $this.Message = "[ERROR] The proxy configuration seems to be right! But something else happend. See the originalException.";
            return;
        }
        throw "Something strange happend. Can't create a userfriendly message";
    }
}