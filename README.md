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

3. Implement the `ICredentialRepository` interface. (See an example in `/resources/examples/Passkey.cfc`)

4. Configure your `credentialRepositoryMapping` in `config/ColdBox.cfc`
```js
moduleSettings = {
    "cbsecurity-passkeys": {
        "credentialRepositoryMapping": "Passkey"
    }
}
```