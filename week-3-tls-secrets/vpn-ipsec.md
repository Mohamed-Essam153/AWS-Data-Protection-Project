# VPN and IPsec (concepts)

Part of deliverable 16. Owner: Mohamed Essam Elbastawisy. Nothing here is deployed: VPN connections bill by the hour.

## Site-to-Site VPN

- Each connection has **two IPsec tunnels** to two different AWS endpoints, so one can fail without an outage.
- **IKE phase 1** authenticates both ends (pre-shared key or certificate) and sets up a protected channel for negotiating.
- **IKE phase 2** negotiates the IPsec security associations (encryption and integrity algorithms) that protect the actual traffic.
- On the AWS side it ends on a virtual private gateway or a transit gateway; on-premises the device is the customer gateway.

## Client VPN

Remote access for people, based on TLS (OpenVPN). Users authenticate with certificates (mutual TLS), Active Directory, or SAML, which means it could use our Identity Center with MFA.

## Direct Connect

A private, dedicated line into AWS. It is **not encrypted by default**. Add MACsec on connections that support it, or run an IPsec VPN over it.

## Which one, for a company with branch offices

Imagine a debt-collection company: a head office, several branches, collectors in the field, and customer and payment data in AWS.

| Option | Encryption | Use it for |
|---|---|---|
| Site-to-Site VPN | IPsec, two tunnels | each branch to the VPC. Quick to set up, cheap |
| Client VPN | TLS | collectors working remotely, signing in with SAML + MFA |
| Direct Connect + MACsec or VPN | none until you add it | head office if it moves a lot of data, e.g. call recordings |
| Transit Gateway + VPN | IPsec | once there are more than a handful of branches (hub and spoke) |

```
Branch ──IPsec tunnel 1──┐
                          ├── VGW / Transit Gateway ── VPC (private subnets)
Branch ──IPsec tunnel 2──┘
Collector ──TLS (Client VPN, SAML + MFA)──> Client VPN endpoint ── VPC
```
