# Tailscale VPN

[← Back to README](../README.md)

Tailscale is installed **only on the Paris web server**. All mobile users must join the tailnet to access the API.

## Install on the Web Server

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
# Approve the auth link in browser
sudo tailscale status
```

## MagicDNS

Enable MagicDNS in the Tailscale admin console. Your server gets a hostname like:

```
MyParisWebServer.your-tailnet-name.ts.net
```

This hostname resolves correctly for **every user on your tailnet** regardless of their assigned Tailscale IP, so no hardcoded IPs are needed.

Put that full hostname in `TAILNET_NAME` in your `env.json` (see [flutter-app.md](flutter-app.md#configuration)).

## Joining the Network

1. Install Tailscale on your phone (App Store / Google Play)
2. Get the invite link from the network admin
3. Join the tailnet and connect
4. The app will automatically reach the server via MagicDNS

## Related

- The web server's security group only allows port 8000 from the Tailscale range `100.64.0.0/10`. See [aws-setup.md](aws-setup.md#security-groups).
