# OpenVPN for Docker
OpenVPN server as a Docker container. Secured with EasyRSA. Project is meant to be simple, easy to understand and hack. Dont expect any fancy automation. If you need customization, you can do it yourself. This is a good starting point. Based on `angristan/openvpn-install` project.

> [!NOTE]
> IP forwarding must be enabled on host if the container will be acting as a gateway (e.g. VPN clients want to reach the internet)
> 
> Add this line to `/etc/sysctl.conf`:\
> **net.ipv4.ip_forward = 1**
> 
> And run this to make changes take effect right away:\
> **sysctl -p**

> [!NOTE]
> If you plan to use a VPN only as a means of accessing your internal network (no internet access, route only VPN subnet)
> or you have decided to set `ALLOW_INTERNET` to false, make sure you have configured routing policy correctly. (see [Customization section](#customization))

> [!NOTE]
> In case of DNS not resolving issues or if you plan to only route VPN subnet
> remove from configuration lines related to DNS. (see [Customization section](#customization))

## How to start
1. Create `compose.yml` customized to your needs.

    ```yml
    services:
    openvpn:
        container_name: openvpn
        hostname: openvpn
        image: gq97a6/openvpn
        restart: unless-stopped
        ports:
            - 1194:1194/udp
        cap_add:
            - NET_ADMIN
        devices:
            - /dev/net/tun
        volumes:
            - ./storage/openvpn:/etc/openvpn
        environment:
            PUBLIC_IP: vpn.example.com # IP for clients to connect to (eg. host public IP/domain)
            SUBNET_IP: 10.8.0.0 # VPN subnet IP
            SUBNET_MASK: 255.255.255.0 # VPN subnet mask
            SUBNET_CIDR: 10.8.0.0/24  # VPN subnet CIDR
            PORT: 1194
            PROTOCOL: udp
            ALLOW_INTERNET: true # If NAT (masquerading) should be enabled
        command: run-server
    ```

2. Run initial configuration to generate required files. Customize generated files to meet your needs.
    ```
    docker compose run --rm openvpn initial-configuration
    ```

3. Start container
    ```
    docker compose up -d
    ```

4. Create first client certificate (output in `/etc/openvpn/client-certs`)
    ```
    docker exec -it openvpn new-client
    ```

## Customization

#### 1. Change client DNS
To change the DNS servers pushed to clients, modify lines below in `/etc/openvpn/server.conf`:
```conf
push "dhcp-option DNS 1.0.0.1"
push "dhcp-option DNS 1.1.1.1"
```

#### 2. Change what traffic will be routed through the VPN (server-directed)
To route all traffic through the VPN, use the following line in `/etc/openvpn/server.conf`:
```conf
push "redirect-gateway def1 bypass-dhcp"
```
- **redirect-gateway**: Modifies the client's routing table to send all traffic through the VPN.
- **def1**: Uses two more specific routes instead of a single default route. This avoids overwriting the existing default route and makes it easier to restore the original settings.
- **bypass-dhcp**: This tells the client to not redirect DHCP traffic through the VPN, which is important for clients that still need to get IP addresses from their local network.

To route only specific traffic through the VPN, use the following line in `/etc/openvpn/server.conf`:
```conf
push "route 10.8.0.0 255.255.255.0"
```

#### 3. Change what traffic will be routed through the VPN (client-directed)
To reject routes pushed by the server, add the following line to the client configuration file:
```conf
route-nopull
```
Then we can add specific routes:
```conf
route 10.8.0.0 255.255.255.0
```
Or we can route all traffic through the VPN:
```conf
redirect-gateway def1 bypass-dhcp
```

#### 4. Change server subnet or port
Either start from scratch or modify manually the following files:
- `/etc/openvpn/server.conf`
- `/etc/openvpn/client-template.txt`
- `/etc/openvpn/ipp.txt`
- `/etc/openvpn/ccd/*`

#### 5. Allow communication between clients
To allow communication between clients, add the following line to `/etc/openvpn/server.conf`:
```conf
client-to-client
```

#### 6. Prevent or allow clients to connect to internet
To prevent clients from accessing the internet, set the `ALLOW_INTERNET` environment variable to `false` in your `compose.yml` file. This will disable NAT (Network Address Translation) and prevent clients from accessing the internet through the VPN.

## Scripts
Scripts are stored under `/etc/openvpn-scripts`. Mount this directory to customize them. You can also add your own scripts, folder is added to `PATH`.

- **initial-configuration**: configures the server and generates the PKI
- **keepalive**: placeholder script that sleeps forever (used for debugging)
- **new-client**: generates a new client configuration file
- **revoke-client**: revokes a client certificate and generates a new CRL (certificate revocation list)
- **run-server**: applies required iptables rules and starts the OpenVPN server

## Default server configuration

#### Network & Protocol
- **Port:** Defined by the `$PORT` environment variable.
- **Protocol:** Either `udp` or `tcp`, based on the `$PROTOCOL` variable.
- **Device:** `tun` (TUN virtual network interface).
- **Topology:** `subnet` (modern topology for IP addressing).
- **Server Subnet:** Defined by `$SUBNET_IP` and `$SUBNET_MASK`.

#### Security & Encryption
- **Elliptic Curve Cryptography (ECC)** using the `prime256v1` curve.
- **TLS Encryption:** Enabled via `tls-crypt`, which encrypts TLS handshake packets.
- **Cipher:** `AES-128-GCM` (fast and secure AEAD cipher).
- **Auth Digest:** `SHA256`.
- **TLS Version:** Minimum TLS 1.2 enforced.
- **TLS Cipher Suite:** `TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256`.
- **No DH parameters:** Uses ECDH instead (`dh none`).

#### Routing & DNS
- **Default Gateway Redirection:** All client traffic is routed through the VPN.
- **DNS Servers Pushed to Clients:** `1.0.0.1` and `1.1.1.1` (Cloudflare DNS).
- Optional: Static route pushing can be used instead of full tunnel.

#### User & Permissions
- Runs as user `nobody` and group `nogroup` for better security.
- Uses `persist-key` and `persist-tun` to maintain state between restarts.

### Logging & Status
- **Status Log:** `/var/log/openvpn/status.log`
- **Verbosity:** `3`

## Files
- `/etc/openvpn/ccd`\
Client config directory. This is where OpenVPN will look for client-specific configuration.

- `/etc/openvpn/client-certs`\
Client certificates generated with `new-client` script will be outputed there.

- `/etc/openvpn/easy-rsa`\
Working directory where Easy-RSA stores and manages the files needed to build and maintain a Public Key Infrastructure (PKI) for OpenVPN, including keys, certificate requests, and signed certificates.

- `/etc/openvpn/ca.crt` and `/etc/openvpn/ca.key`\
Certificates authority certificate and key. The CA is responsible for:
    - Signing server and client certificates.
    - Verifying identities during connection.
    - Ensuring that only trusted clients can connect to the server.

- `/etc/openvpn/client-template`\
Template configuration for new client certificates.

- `/etc/openvpn/crl.pem`\
Digitally signed file issued by a CA. Contains a list of client certificates that have been revoked.

- `/etc/openvpn/ipp.txt`\
Ensures that the same client always gets the same virtual IP address from the VPN server's IP pool, based on the client's Common Name (CN) from its certificate.

- `/etc/openvpn/server_<random_string>.crt` and `/etc/openvpn/server_<random_string>.key`\
Server certificate and key.

- `/etc/openvpn/server.conf`\
Server configuration.

- `/etc/openvpn/tls-crypt.key`\
Key used to used to encrypt and authenticate the TLS control channel, providing an additional layer of security and privacy over the VPN connection.

## Debugging
- **Logs:** Check `/var/log/openvpn` for logs.
- **Keepalive:** Set `command: keepalive` to keep the container running for debugging purposes.\
This will keep the container alive without starting the OpenVPN server.
- **Container Shell:** Use `docker exec -it openvpn /bin/bash` to access the container shell for debugging.

