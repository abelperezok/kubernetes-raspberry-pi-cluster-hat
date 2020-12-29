# TLS termination

One of the most common scenarios using ingress is to terminate TLS and leave the (micro)service out of this concern knowing the external host it should respond to.

Create a self-signed certificate 

```shell
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout nginx-tls-example-com.key -out nginx-tls-example-com.crt -subj "/CN=*.example.com/O=example.com"

Generating a RSA private key
...............................................+++++
........................................................+++++
writing new private key to 'nginx-tls-example-com.key'
-----
```

Create a secret of type tls with the certificate named `tls-secret-example-com`

```shell
kubectl create secret tls tls-secret-example-com --key nginx-tls-example-com.key --cert nginx-tls-example-com.crt 
secret/tls-secret-example-com created
```

Add this block at the end of the ingress manifest
```
  tls:
  - hosts:
    - blue.example.com
    secretName: tls-secret-example-com
```

```shell
kubectl apply -f ingress.yaml
```

Test redirection HTTP to HTTPS

Update `/etc/hosts` to add:

```
192.168.1.164 blue.example.com
```

```shell
$ curl http://blue.example.com/ -I
HTTP/1.1 301 Moved Permanently
Server: nginx/1.19.6
Date: Mon, 28 Dec 2020 16:09:35 GMT
Content-Type: text/html
Content-Length: 169
Location: https://blue.example.com:443/
```

Test TLS error using self-signed certificate

```shell
$ curl https://blue.example.com/ 
curl: (60) SSL certificate problem: self signed certificate
More details here: https://curl.haxx.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```

Test ignoring the TLS validation

```shell
$ curl https://blue.example.com/ -k
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

## Using a real TLS certificate

Grab a real TLS certificate i.e from [Let’s Encrypt](https://letsencrypt.org/) or [sslforfree.com](https://www.sslforfree.com/). You’ll need a domain ownership to do this. In my case I’m using abelperez.info, which I own, to create my tls certificate.

Create another secret with the real certificate 

```shell
kubectl create secret tls tls-www-abelperez-info --key private.key --cert certificate.crt 
secret/tls-www-abelperez-info created
```

Update the ingress manifest yaml, now use the real hostname and the new secret.

```shell
- host: www.abelperez.info
```

```shell
tls:
  - hosts:
    - www.abelperez.info
    secretName: tls-www-abelperez-info
```

Update `/etc/hosts` to add
```
192.168.1.164	www.abelperez.info
```

## Final Test

```shell
$ curl -Lv http://www.abelperez.info/
*   Trying 192.168.1.164:80...
* Connected to www.abelperez.info (192.168.1.164) port 80 (#0)
> GET / HTTP/1.1
> Host: www.abelperez.info
> User-Agent: curl/7.72.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 301 Moved Permanently
< Server: nginx/1.19.6
< Date: Tue, 29 Dec 2020 11:22:03 GMT
< Content-Type: text/html
< Content-Length: 169
< Location: https://www.abelperez.info:443/
< 
* Ignoring the response-body
* Connection #0 to host www.abelperez.info left intact
* Issue another request to this URL: 'https://www.abelperez.info:443/'
*   Trying 192.168.1.164:443...
* Connected to www.abelperez.info (192.168.1.164) port 443 (#1)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*   CAfile: /etc/ssl/certs/ca-certificates.crt
  CApath: /etc/ssl/certs
* TLSv1.3 (OUT), TLS handshake, Client hello (1):
* TLSv1.3 (IN), TLS handshake, Server hello (2):
* TLSv1.2 (IN), TLS handshake, Certificate (11):
* TLSv1.2 (IN), TLS handshake, Server key exchange (12):
* TLSv1.2 (IN), TLS handshake, Server finished (14):
* TLSv1.2 (OUT), TLS handshake, Client key exchange (16):
* TLSv1.2 (OUT), TLS change cipher, Change cipher spec (1):
* TLSv1.2 (OUT), TLS handshake, Finished (20):
* TLSv1.2 (IN), TLS handshake, Finished (20):
* SSL connection using TLSv1.2 / ECDHE-RSA-AES256-GCM-SHA384
* ALPN, server accepted to use http/1.1
* Server certificate:
*  subject: CN=abelperez.info
*  start date: Dec 29 00:00:00 2020 GMT
*  expire date: Mar 29 23:59:59 2021 GMT
*  subjectAltName: host "www.abelperez.info" matched cert's "www.abelperez.info"
*  issuer: C=AT; O=ZeroSSL; CN=ZeroSSL RSA Domain Secure Site CA
*  SSL certificate verify ok.
> GET / HTTP/1.1
> Host: www.abelperez.info
> User-Agent: curl/7.72.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: nginx/1.19.6
< Date: Tue, 29 Dec 2020 11:22:03 GMT
< Content-Type: text/html
< Content-Length: 612
< Connection: keep-alive
< Last-Modified: Tue, 15 Dec 2020 13:59:38 GMT
< ETag: "5fd8c14a-264"
< Accept-Ranges: bytes
< 
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
* Connection #1 to host www.abelperez.info left intact
```

Or just use the browser to navigate to http://www.abelperez.info/ and it will automatically redirect to the HTTPS location and you’ll see the “secure” padlock

## References

* https://kubernetes.github.io/ingress-nginx/examples/tls-termination/

* https://serversforhackers.com/c/using-ssl-certificates-with-haproxy

* https://awkwardferny.medium.com/configuring-certificate-based-mutual-authentication-with-kubernetes-ingress-nginx-20e7e38fdfca
