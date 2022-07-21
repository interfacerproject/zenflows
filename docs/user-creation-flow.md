# Technical documentation on User Creation

This document details user creation in Zenflows.

The basic principle is end-to-end encryption: secret keys are not held by the server backend, but created on the frontend side.

```mermaid
sequenceDiagram
participant B as Backend
participant F as Frontend
participant E as Email
    F->>B: request create/claim <name, email>
    B->B: create OTP token
    B->>+E: send token to email, listen until expiry
    B->>F: ACK request, waiting confirmation token
    E->>-B: confirmation link, hit before expiry
    B->B: create/claim user
    B->>F: ACK creation, request public keys
    F->F: create keyring
    F->>B: send public keys
    B->B: save user pub keys
    B->>F: OK, confirm creation
```
