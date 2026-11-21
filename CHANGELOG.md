# Changelog

## 1.1.0

New optional `environment` variable for extra `COPILOT_*` container settings.

Fixed: the `connect` output now uses `AWS-StartPortForwardingSession`. Current Session Manager agents refuse
`AWS-StartPortForwardingSessionToRemoteHost` to `localhost` ("Forwarding to IP address 127.0.0.1 is forbidden"),
so the 1.0.0 tunnel closed on the first request.

## 1.0.0

First release: Cloud Cost Copilot 1.0 as a single AWS Fargate task, with IAM roles, CloudWatch logs, an optional
VPC without a NAT gateway, Session Manager port-forward access and an optional API token from SSM.
