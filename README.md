# cbSecurity Passkeys

Passkey registration and authentication for ColdBox applications using
[cbSecurity](https://github.com/coldbox-modules/cbsecurity) and the
[Yubico WebAuthn server library](https://github.com/Yubico/java-webauthn-server).

The module provides the WebAuthn ceremony endpoints, logs a successfully
authenticated user in through cbSecurity, and stores the credential through a
repository supplied by your application. It does not provide a user model or
database implementation because those details belong to the application.

## Requirements

- ColdBox 6+
- cbSecurity 3+
- Lucee 5+ or Adobe ColdFusion 2018+
- A browser with passkey support
- HTTPS in production (WebAuthn may be available on `localhost` during local development)

## Installation

Install the module with CommandBox:

```bash
box install cbsecurity-passkeys
```

The module includes Java libraries that must be added to the application
classpath in `Application.cfc`:

```cfml
this.javaSettings = {
    loadPaths: [ "./modules/cbsecurity-passkeys/lib" ],
    loadColdFusionClassPath: true,
    reloadOnChange: true
};
```

## Configuration

Configure the module in `config/ColdBox.cfc`:

```cfml
moduleSettings = {
    "cbsecurity-passkeys": {
        // WireBox mapping for your ICredentialRepository implementation.
        "credentialRepositoryMapping": "Passkey",

        // The WebAuthn relying-party ID. Usually the hostname without a scheme.
        "relyingPartyId": "example.com",

        // Name shown to users by their authenticator.
        "relyingPartyName": "Example",

        // Use the complete origin, including the scheme and port when needed.
        "allowedOrigins": [ "https://example.com" ],

        // Opt in when passkeys are shared with subdomains such as app.example.com.
        "allowOriginSubdomains": true
    }
};
```

All settings:

| Setting | Required | Default | Description |
| --- | --- | --- | --- |
| `credentialRepositoryMapping` | Yes | `""` | WireBox mapping for the component implementing `ICredentialRepository`. |
| `relyingPartyId` | No | `CGI.SERVER_NAME` | WebAuthn relying-party ID. It must be a domain covered by the current origin. |
| `relyingPartyName` | No | `appName` | Human-readable relying-party name. |
| `allowedOrigins` | Yes | `[]` | One or more complete origins accepted by WebAuthn, such as `https://example.com`. |
| `allowOriginSubdomains` | No | `false` | Allow subdomains of configured origins during WebAuthn origin validation. |

The module will fail during startup when `credentialRepositoryMapping` is not
configured or when `allowedOrigins` is empty.

Keep `allowOriginSubdomains` disabled unless the same relying party intentionally
serves passkey ceremonies from multiple trusted subdomains.

Configure cbSecurity and its authentication provider as usual. After a
successful assertion, the username returned by your repository is passed to
`cbSecure().getUserService().retrieveUserByUsername()`, so it must match the
username format understood by your cbSecurity user service.

## Credential repository

Your repository is the adapter between this module and your user/credential
storage. Point `credentialRepositoryMapping` at a component that implements
[`models/ICredentialRepository.cfc`](models/ICredentialRepository.cfc).

Two complete reference implementations are included:

- [Quick example](resources/examples/quick/Passkey.cfc)
- [cbORM example](resources/examples/cborm/Passkey.cfc)

The repository must implement the following methods:

| Method | Return value and requirements |
| --- | --- |
| `getUsernameForUser(user)` | The stable username used by WebAuthn for the application user. |
| `getDisplayNameForUser(user)` | A human-readable name shown during passkey registration. |
| `getUserHandleForUser(user)` | Stable binary user-handle data. This value must not change for the user. |
| `getCredentialIdsForUsername(username)` | An array of all binary credential IDs registered for the username. Return `[]` when there are none. |
| `getUserHandleForUsername(username)` | The user handle as binary data, or `null` when the username is unknown. |
| `getUsernameForUserHandle(userHandle)` | The username for the supplied binary user handle, or `null` when it is unknown. |
| `lookup(credentialId, userHandle)` | A struct containing `publicKey` and numeric `signatureCount`, or `null` when no matching credential exists. Both arguments are binary data. |
| `lookupAll(credentialId)` | An array of structs containing binary `userHandle`, binary `publicKey`, and numeric `signatureCount`. |
| `storeCredentialForUser(...)` | Persist the new credential and all supplied authenticator metadata. |
| `updateCredentialForUser(...)` | Update the signature counter, backup state, and optional last-used timestamp after a successful login. |

The binary values must be stored and returned as binary data. Do not base64
encode them in the repository unless you also decode them before returning them
to the module. The values supplied to `storeCredentialForUser` are:

```text
user               application user object
credentialId       binary credential ID
publicKey          binary COSE public key
signatureCount     numeric authenticator signature counter
isDiscoverable     optional boolean
isBackupEligible   boolean
isBackedUp         boolean
attestationObject  binary attestation object
clientDataJson     JSON string
```

The write-method signatures are:

```cfml
public void function storeCredentialForUser(
    required any user,
    required any credentialId,
    required any publicKey,
    required numeric signatureCount,
    any isDiscoverable,
    required boolean isBackupEligible,
    required boolean isBackedUp,
    required any attestationObject,
    required string clientDataJson
);

public void function updateCredentialForUser(
    required any user,
    required any credentialId,
    required numeric signatureCount,
    required boolean isBackedUp,
    date lastUsedTimestamp
);
```

The included database migration is only a reference schema. It assumes a
`users` table with an integer `id` and is not automatically applied to your
application. Copy or adapt it for your own persistence layer:

[`resources/database/migrations/2024_01_01_000000_create_cbsecurity_passkeys_table.cfc`](resources/database/migrations/2024_01_01_000000_create_cbsecurity_passkeys_table.cfc)

## Browser client

Load the browser helper after the module has been installed:

```html
<script src="/modules/cbsecurity-passkeys/includes/passkeys.js"></script>
```

The helper publishes the following API at `window.cbSecurity.passkeys`.

### `isSupported()`

```js
const supported = await window.cbSecurity.passkeys.isSupported();
```

Returns a promise resolving to a truthy value when the browser exposes the
platform authenticator and conditional-mediation APIs required by this helper.
It returns a falsey value when those APIs are unavailable. The result is cached
for the lifetime of the page.

### `register(redirectLocation = "/")`

Starts registration for the currently authenticated cbSecurity user:

```js
if (await window.cbSecurity.passkeys.isSupported()) {
    await window.cbSecurity.passkeys.register("/account/security");
}
```

Registration calls:

1. `GET /cbsecurity/passkeys/registration/new`
2. `POST /cbsecurity/passkeys/registration`

The first request and the second request must use the same session. On a
successful registration the helper navigates to `redirectLocation`.

## Registering a passkey after login

Registration is an authenticated operation. A typical flow is:

1. The user signs in through your existing password, SSO, or other cbSecurity
   login flow.
2. Your application redirects the user to an account-security page.
3. That page calls `passkeys.register(...)` while the cbSecurity session is
   still active.
4. The module creates and stores a passkey for `cbSecure().getUser()`.

For example, the following could be rendered on `/account/security` after your
normal login flow has completed:

```html
<button id="add-passkey" type="button">Add a passkey to this account</button>

<script src="/modules/cbsecurity-passkeys/includes/passkeys.js"></script>
<script type="module">
    const passkeys = window.cbSecurity.passkeys;
    const button = document.querySelector("#add-passkey");

    button.addEventListener("click", async () => {
        if (!(await passkeys.isSupported())) {
            button.disabled = true;
            button.textContent = "Passkeys are not supported in this browser";
            return;
        }

        button.disabled = true;
        await passkeys.register("/account/security");
    });
</script>
```

Both registration endpoints are secured by the module. If the user is not
logged in, `GET /cbsecurity/passkeys/registration/new` cannot create a user
identity and registration will not complete.

## Registering multiple passkeys for one account

Each successful registration stores a separate credential for the currently
logged-in user. This allows one account to have, for example, a laptop
platform passkey, a phone passkey, and a hardware security key. The repository
must store each credential under its own `credentialId`; it must not overwrite
an existing credential merely because the user is the same.

The account-security page can use the same button repeatedly:

```html
<section>
    <h2>Passkeys</h2>
    <p>Add each device or security key you want to use with this account.</p>
    <button id="register-another-passkey" type="button">
        Register another passkey
    </button>
</section>

<script src="/modules/cbsecurity-passkeys/includes/passkeys.js"></script>
<script type="module">
    const passkeys = window.cbSecurity.passkeys;
    const button = document.querySelector("#register-another-passkey");

    button.addEventListener("click", async () => {
        if (!(await passkeys.isSupported())) {
            return;
        }

        // The helper redirects here after the new credential is stored.
        // The user can click the button again to add another credential.
        await passkeys.register("/account/security");
    });
</script>
```

Register one passkey at a time, then repeat the flow on the same or another
logged-in device. Do not start several ceremonies in parallel: each ceremony
uses the session's flash-scoped registration request, and the helper redirects
after each successful registration.

The repository methods `getCredentialIdsForUsername` and `lookupAll` are
designed to work with multiple credentials for one account. The module does
not provide a passkey list, labels, rename, or delete API; those are
application-owned concerns.

## Adding labels or names to passkeys

Passkeys do not have a user-editable name in the WebAuthn credential data. A
useful application model is to keep the security credential data and the
display metadata together by `credentialId`:

| Field | Example | Purpose |
| --- | --- | --- |
| `credentialId` | `q7...base64url...` | Stable identifier returned by the browser and stored by the repository. |
| `label` | `MacBook Pro` | User-facing name for the authenticator. |
| `createdAt` | `2026-08-11T18:20:00Z` | When the application recorded the label. |
| `lastUsedAt` | `2026-08-12T09:15:00Z` | Optional application-maintained activity timestamp. |

You can add a nullable `label` column to your passkey table, or create a
separate `passkey_metadata` table keyed by `credentialId`. A separate table is
often easier because it keeps application presentation fields out of the
module's WebAuthn storage contract. For example:

```text
passkey_metadata
----------------
id
userId
credentialId    unique per user
label
createdAt
lastUsedAt
```

Always scope metadata queries to the current cbSecurity user. Before saving a
label, renaming a passkey, or deleting one, verify that the credential belongs
to that user; never trust a client-supplied `credentialId` by itself.

### Simple application-owned label flow

Ask for a label on the account-security page, then let the application save
it after the credential has been registered:

```html
<label>
    Passkey name
    <input id="passkey-label" type="text" maxlength="100"
        placeholder="MacBook Pro">
</label>
<button id="add-named-passkey" type="button">Register passkey</button>
```

The stock `passkeys.register()` helper redirects after registration and does
not return the new credential ID, so it is suitable when your application can
collect metadata through its own post-registration workflow. If the label
must be attached to the exact credential immediately, use the custom flow
below.

### Labeling the exact credential with a custom registration wrapper

The module's HTTP endpoints can be used directly when the application needs
the browser's credential ID. The following wrapper mirrors the built-in
helper, then sends the label and the browser-generated `credential.id` to an
application-owned endpoint:

```html
<script src="/modules/cbsecurity-passkeys/includes/passkeys.js"></script>
<script type="module">
    async function registerNamedPasskey(label) {
        const challengeResponse = await fetch(
            "/cbsecurity/passkeys/registration/new",
            { credentials: "same-origin" }
        );
        const challengeJson = await challengeResponse.json();
        const creationOptions = JSON.parse(challengeJson);
        const publicKeyCredential = await webauthnJSON.create(creationOptions);

        const registrationResponse = await fetch(
            "/cbsecurity/passkeys/registration",
            {
                method: "POST",
                credentials: "same-origin",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    publicKeyCredentialJson: JSON.stringify(publicKeyCredential)
                })
            }
        );

        if (!registrationResponse.ok) {
            throw new Error("Passkey registration failed");
        }

        const metadataResponse = await fetch("/account/passkeys/metadata", {
            method: "POST",
            credentials: "same-origin",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                credentialId: publicKeyCredential.id,
                label: label.trim()
            })
        });

        if (!metadataResponse.ok) {
            throw new Error("Passkey was registered, but its label was not saved");
        }

        window.location = "/account/security";
    }

    document.querySelector("#add-named-passkey").addEventListener(
        "click",
        async () => {
            const label = document.querySelector("#passkey-label").value;

            if (!label.trim()) {
                return;
            }

            await registerNamedPasskey(label);
        }
    );
</script>
```

The `credential.id` in this example is the browser's base64url credential ID.
Your `/account/passkeys/metadata` endpoint should:

1. Require an authenticated cbSecurity user and the application's normal CSRF
   protection.
2. Validate and normalize the label on the server.
3. Confirm that the credential ID belongs to `cbSecure().getUser()` using the
   repository or an application-owned credential record.
4. Store or update the label only after that ownership check.

If saving metadata fails after the module returns `201 Created`, the passkey
still exists but is unnamed. Let the user retry labeling it; do not register a
second credential just to recover from a metadata failure. Likewise, do not
associate a label with “the newest credential” because two browser sessions
could register at the same time.

### `login(username, redirectLocation = "/", additionalParams = {})`

Starts a regular passkey login. Supply a username to identify an account, or
explicitly pass an empty string for a discoverable credential:

```js
// Username-bound login
await window.cbSecurity.passkeys.login(
    "jane@example.com",
    "/account"
);

// Discoverable passkey login
await window.cbSecurity.passkeys.login(
    "",
    "/account"
);
```

The helper calls:

1. `GET /cbsecurity/passkeys/authentication/new?username=...`
2. `POST /cbsecurity/passkeys/authentication`

On success it navigates to `redirectLocation`.

### `autocomplete(redirectLocation = "/", additionalParams = {})`

Starts a conditional, browser-assisted login. It is useful on a login page
with an input that allows the browser to suggest a passkey:

```js
const loginButton = document.querySelector("#passkey-login");

loginButton.addEventListener("click", async () => {
    await window.cbSecurity.passkeys.autocomplete("/account");
});
```

Unlike `login`, this method does not take a username. It sends
`mediation: "conditional"` to the browser's WebAuthn API.

## Additional parameters and remember-me integrations

`login` and `autocomplete` accept an optional `additionalParams` object. The
helper sends those values to both authentication requests:

- as query-string parameters on `GET /cbsecurity/passkeys/authentication/new`
- as JSON properties on `POST /cbsecurity/passkeys/authentication`

For example, an application can pass an optional opaque remember-me value:

```js
const additionalParams = {
    rememberMe: rememberMeToken || ""
};

await window.cbSecurity.passkeys.login(
    "jane@example.com",
    "/account",
    additionalParams
);
```

Or with conditional login:

```js
await window.cbSecurity.passkeys.autocomplete(
    "/account",
    { rememberMe: rememberMeToken || "" }
);
```

The `cbsecurity-passkeys` module does not validate, persist, or otherwise
interpret `rememberMe`. It logs the user in through cbSecurity after a
successful WebAuthn assertion. Use the `onPasskeyLogin` interception point to
hand an application-specific value to your remember-me service:

```cfml
// config/Interceptor.cfc or another normal ColdBox interceptor component
component {
    property name="rememberMeService" inject="RememberMeService";

    function onPasskeyLogin(event, interceptData) {
        var rememberMeToken = interceptData.event.getValue("rememberMe", "");

        if (len(rememberMeToken)) {
            // Validate the token with your application's remember-me service.
            // Create or rotate its cookie/session state here.
            variables.rememberMeService.remember(
                interceptData.user,
                rememberMeToken
            );
        }
    }
}
```

`onPasskeyLogin` runs after the passkey assertion succeeds and after cbSecurity
has logged the user in, so it is a notification/customization hook, not a
pre-authentication veto. If the value is a bearer or persistent token, be
careful: `additionalParams` places it in the initial GET URL, where it may be
recorded by browser history, proxies, access logs, or analytics. Prefer a
short-lived, single-use value or pass only a boolean such as
`rememberMe: true` and let the server create the token.

## HTTP API

The module routes are mounted below `/cbsecurity/passkeys`.

### `GET /registration/new`

Creates a WebAuthn registration challenge for the currently authenticated
user. The request is secured and uses the configured repository to build the
user identity.

Response: `200 OK`. The response body is a JSON-encoded string containing the
WebAuthn `PublicKeyCredentialCreationOptions` object expected by
`webauthnJSON.create()`.

### `POST /registration`

Finishes registration and stores the new credential.

Request body:

```json
{
    "publicKeyCredentialJson": "{\"type\":\"public-key\",\"id\":\"...\"}"
}
```

`publicKeyCredentialJson` must be a JSON string, not a decoded JSON object.

Responses:

| Status | Meaning | Body |
| --- | --- | --- |
| `201 Created` | Credential was stored. | `{ "createdDate": "..." }` |
| `400 Bad Request` | WebAuthn registration validation failed. | `{}` |
| `401/403` | The request is not authenticated or is denied by cbSecurity. | Application/security response. |

### `GET /authentication/new`

Creates a WebAuthn assertion challenge. This endpoint is public.

Optional query parameter:

| Parameter | Description |
| --- | --- |
| `username` | Restricts the assertion to the credentials belonging to this username. Omit it or send an empty value for a discoverable credential flow. |

Response: `200 OK`. The response body is a JSON-encoded string containing the
WebAuthn `PublicKeyCredentialRequestOptions` object expected by
`webauthnJSON.get()`.

The assertion request is stored in the flash scope until the follow-up POST.
Do not cache this response, and make sure the subsequent POST uses the same
client session.

### `POST /authentication`

Finishes a passkey assertion and logs the resolved user in through cbSecurity.

Request body:

```json
{
    "publicKeyCredentialJson": "{\"type\":\"public-key\",\"id\":\"...\"}",
    "rememberMe": true
}
```

`publicKeyCredentialJson` must be a JSON string. Other properties are available
to the request/interception pipeline but are not interpreted by this module.

Responses:

| Status | Meaning | Body |
| --- | --- | --- |
| `200 OK` | Assertion succeeded and the user was logged in. | `{ "loginTimestamp": "..." }` |
| `403 Forbidden` | Assertion verification failed. | `{}` |

## End-to-end page example

The following example assumes the page is rendered for an already authenticated
user and has a separate login page for unauthenticated users:

```html
<script src="/modules/cbsecurity-passkeys/includes/passkeys.js"></script>

<button id="register-passkey" type="button">Register passkey</button>
<button id="login-passkey" type="button">Sign in with passkey</button>
<label>
    <input id="remember-me" type="checkbox">
    Remember me
</label>

<script type="module">
    const passkeys = window.cbSecurity.passkeys;

    document.querySelector("#register-passkey").addEventListener("click", async () => {
        if (!(await passkeys.isSupported())) {
            return;
        }

        await passkeys.register("/account/security");
    });

    document.querySelector("#login-passkey").addEventListener("click", async () => {
        if (!(await passkeys.isSupported())) {
            return;
        }

        await passkeys.login("jane@example.com", "/account", {
            rememberMe: document.querySelector("#remember-me")?.checked === true
        });
    });
</script>
```

## Events

The module registers these custom interception points:

### `onPasskeyLogin`

Announced after a successful assertion, cbSecurity login, and credential
counter update.

| Intercept data | Description |
| --- | --- |
| `event` | The current ColdBox request context. Request parameters can be read with `event.getValue(...)`. |
| `user` | The application user resolved from the successful assertion. |

Use this event for audit logging, remember-me integration, or application
notifications. It is not a replacement for WebAuthn validation.

The module also declares `onPasskeyRegistration` as a custom interception point,
but the current registration handler does not announce it. Do not rely on that
event being emitted in this release.

## Failure modes and troubleshooting

- **Startup fails with a repository error:** confirm that `credentialRepositoryMapping` points to a WireBox mapping for a component implementing `ICredentialRepository`.
- **Startup fails with an origin error:** configure at least one complete origin in `allowedOrigins`.
- **Registration fails for an unauthenticated user:** registration endpoints require an existing cbSecurity login.
- **The second ceremony request reports a missing request:** the browser did not preserve the same session/flash state between the `new` and completion requests, or the challenge expired/was consumed.
- **The server reports an invalid credential payload:** send `publicKeyCredentialJson` as a string containing JSON. The browser helper handles the required base64url conversion and double encoding for you.
- **WebAuthn reports an origin or relying-party mismatch:** make `relyingPartyId`, `allowedOrigins`, the browser URL, and your HTTPS/proxy configuration agree exactly.
- **The helper returns a falsey value from `isSupported()`:** the browser does not expose both platform-authenticator and conditional-mediation support required by this helper. Use another authentication UI or a different WebAuthn client for browsers with partial support.
