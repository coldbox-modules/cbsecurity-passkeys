# CBSecurity Passkeys

## Requirements
- ColdBox 6+
- cbSecurity 3+

## Installation

1. Install CBSecurity Passkeys
`box install cbsecurity-passkeys`

2. Add Java libs from cbsecurity-passkeys
```js
this.javaSettings = {
    loadPaths : [ "./modules/cbsecurity-passkeys/lib" ],
    loadColdFusionClassPath : true,
    reloadOnChange : true
};
```

3. Implement the `ICredentialRepository` interface. (See an example in `/resources/examples/quick/Passkey.cfc`)

4. Configure your `credentialRepositoryMapping` in `config/ColdBox.cfc`
```js
moduleSettings = {
    "cbsecurity-passkeys": {
        "credentialRepositoryMapping": "Passkey"
    }
}
```

5. Configure at least one (1) `allowedOrigins`
```js
moduleSettings = {
    "cbsecurity-passkeys": {
        "credentialRepositoryMapping": "Passkey",
        "allowedOrigins": [ "example.com" ]
    }
}
```

Integrate using the `includes/passkeys.js` library:

```html
<script src="/modules/cbsecurity-passkeys/includes/passkeys.js"></script>
<script type="module">
    if ( await window.cbSecurity.passkeys.isSupported() ) {
        await window.cbSecurity.passkeys.register(
            // redirectLocation ("/")
        );
    }
</script>
<script type="module">
    if ( await window.cbSecurity.passkeys.isSupported() ) {
        await window.cbSecurity.passkeys.login(
            // username (optional)
            // redirectLocation ("/")
            // additionalParams ({})
        )
    }
</script>
<script>
    window.cbSecurity.passkeys.autocomplete(
        // redirectLocation ("/")
        // additionalParams ({})
    );
</script>
```