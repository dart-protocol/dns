# Introduction

Implements DNS protocol (over UDP) and modern [DNS-over-HTTP](https://developers.google.com/speed/public-dns/docs/dns-over-https).

The package uses [package:universal_io](https://github.com/gohilla/universal_io), which means
that you can use it Flutter, Dart VM, and browser (dart2js).

## Help the project!
  * Please star the official repository at: [github.com/gohilla/dns](https://github.com/gohilla/dns).
  * Discuss issues in the [Github issue tracker](https://github.com/gohilla/dns/issues).

# Getting started
## Built-in local DNS proxy
### Install
In the command line:
```
pub global activate dns
```

### Launch the server & change system settings
In the command line:
```
sudo dns_proxy start --configure
```

Some common options are:
  * _--configure_
    * The proxy attempts to temporarily configure your operating system to use the
      proxy. Normal settings will be restored when you close the proxy.
  * _--https=(URL)_
    * TLS-over-HTTP URL. Resolved using Google's DNS server at [8.8.8.8](https://developers.google.com/speed/public-dns/docs/using).