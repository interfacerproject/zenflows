<!--
SPDX-License-Identifier: AGPL-3.0-or-later
Zenflows is software that implements the Valueflows vocabulary.
Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

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

## User create/claim

User **creation** should create a new corresponding Agent in Valueflows (User and Agent coincide)

User **claiming** should happen if an **Agent with the same Email** already exists in the database, then the Agent is filled with the new information from this process (public keys, name, etc.) and becomes valid for login.

## Public keys

The public keys are created in the [keygen.zen](zencode/src/keygen.zen) script and they are structured as follows:

```
            ethereum_address = octet[20] ,
            pubkeys = {
                ecdh_public_key = octet[65] ,
                eddsa_public_key = octet[32] ,
                reflow_public_key = ecp2[192] ,
                schnorr_public_key = octet[48]
            }
```

They values stated above are specifying their binary format in Zenroom, however both the Frontend and the Backend do not need to decode them and access them in binary format, all they need to do is to save them as encoded strings, each in their own respecting encoding (most base64, some hex).
