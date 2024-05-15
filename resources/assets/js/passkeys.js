const passkeys = {
	supported: null,
	async isSupported() {
		if ( this.supported === null ) {
			if (
				window.PublicKeyCredential &&
				PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable &&
				PublicKeyCredential.isConditionalMediationAvailable
			) {
				await Promise.all([
					PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable(),
					PublicKeyCredential.isConditionalMediationAvailable()
				]).then(async results => {
					this.supported = results.every(r => r === true)
				});
			}
		}
		return this.supported;
	},
	async register(redirectLocation = "/") {
		// Make the call that returns the credentialCreateJson above
		const credentialCreateOptions = await fetch("/cbsecurity/passkeys/registration/new")
			.then(resp => resp.json())
			.then(json => JSON.parse(json));

		// Call WebAuthn ceremony using webauthn-json wrapper
		const publicKeyCredential = await webauthnJSON.create(credentialCreateOptions);

		// Return encoded PublicKeyCredential to server
		await fetch("/cbsecurity/passkeys/registration", {
			method: "POST",
			headers: {
				"Content-Type": "application/json"
			},
			body: JSON.stringify({
				"publicKeyCredentialJson": JSON.stringify(publicKeyCredential)
			})
		})
		window.location = redirectLocation;
	},
	async login(username, redirectLocation = "/") {
			// Make the call that returns the credentialGetJson above
			const credentialGetOptions = await fetch("/cbsecurity/passkeys/authentication/new?" + new URLSearchParams({
				"username": username
			}))
				.then(resp => resp.json())
				.then(json => JSON.parse(json));

			// Call WebAuthn ceremony using webauthn-json wrapper
			const publicKeyCredential = await webauthnJSON.get(credentialGetOptions);

			// Return encoded PublicKeyCredential to server
			await fetch("/cbsecurity/passkeys/authentication", {
				method: "POST",
				headers: {
					"Content-Type": "application/json"
				},
				body: JSON.stringify({
					"publicKeyCredentialJson": JSON.stringify(publicKeyCredential)
				})
			}).then( () => {
				window.location = redirectLocation;
			});
	},
};

window.cbSecurity = window.cbSecurity || {};
window.cbSecurity.passkeys = passkeys;