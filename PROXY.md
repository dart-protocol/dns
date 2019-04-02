# dart-dns proxy
## Install
In the command line:
```
pub global activate dns
```

## Start
In the command line:
```
sudo dns_proxy start --configure
```

Some common options are:
  * --https=(URL)
    * TLS-over-HTTP URL
  * --configure
    * The proxy attempts to temporarily configure your operating system to use the
      proxy. Normal settings will be restored when you close the proxy.

If you are developing, you can run the proxy with `pub run bin/dns_proxy.dart`.