function FindProxyForURL(url, host)
{
    if (
        isInNet(dnsResolve(host), "10.0.0.0", "255.0.0.0") ||
        isInNet(dnsResolve(host), "172.16.0.0",  "255.240.0.0") ||
        isInNet(dnsResolve(host), "192.168.0.0",  "255.255.0.0") ||
        isInNet(dnsResolve(host), "127.0.0.0", "255.255.255.0")
        )
    {
        return "DIRECT";
    }

    return "SOCKS 127.0.0.1:33134; PROXY 1.1.1.1:1";
}

