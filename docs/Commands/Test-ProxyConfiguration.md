# Test-ProxyConfiguration.md

## SYNOPSIS

The `Test-ProxyConfiguration` cmdlet test your proxy configuration. This can help if your company uses a proxy and you need help to debug the problem.

## Syntax

### NameParameterSet (Default)

```powershell
Test-ProxyConfiguration [-Uri] <String> [[-Proxy] <System.Net.IWebProxy>]
```

## Parameters

### -Uri

The `Uri` parameter defines the http resource. The proxy configuration is checked for just this `Uri`

### -Proxy

The `Proxy` parameter configures the proxy configuration you want to debug. If you don't set this parameter it will uses `[System.Net.WebRequest]::GetSystemWebProxy()`, witch is the system defaults proxy.

## OUTPUTS

### `ProxyTestResult`

#### `TestedHostname`

The hostname that the test was for.

#### `DirectAccessPossible`

The result of the TCP connection Test. If this is true, you shouldn't use a proxy!

#### `BypassListRecommended()`

A recommendation if you should set the hostname on the proxy bypass list.

#### `IsOnBypassList`

Shows if the hostname is already on the bypass list.

#### `originalException`

If there is an exception while the tests run, it will be shown here.

> Important: not all exception mean something bad, in special in this network world. So read them carefully, before you ask your admin. 😉

#### `Message`

A message that contains a human readable action the user should do, to optimize his setup.

#### `CreateMessage()`

This will create the message from the test result. See `Message` field.

## Examples

### Example 1

```powershell
Test-ProxyConfiguration -Uri "https://bing.com/";
```

This example will test, if you can reach the website `https://bing.com/` with your current system configuration.

### Example 2

```powershell
Test-ProxyConfiguration -Uri "https://bing.com/" -Proxy (New-Object System.Net.WebProxy("http://proxy.company.com:80"));
```

This example will test, if you can reach the website `https://bing.com/` with the configured proxy from the `proxy` parameter.

### Example 3

```powershell
$proxy = New-Object System.Net.WebProxy("http://proxy.company.com:80");
$proxy.BypassList = @("bing.com")
Test-ProxyConfiguration -Uri "https://bing.com/";
```

This example will test, if you can reach the website `https://bing.com/` with the configured proxy from the `proxy` parameter. It configures also a bypass on the hostname `bing.com`.
