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
		const registrationResponse = await fetch("/cbsecurity/passkeys/registration", {
			method: "POST",
			headers: {
				"Content-Type": "application/json"
			},
			body: JSON.stringify({
				"publicKeyCredentialJson": JSON.stringify(publicKeyCredential)
			})
		});

		if (registrationResponse.ok) {
			window.location = redirectLocation;
		} else {
			console.error("cbsecurity-passkeys - Registration failed:", registrationResponse);
		}
	},
	async autocomplete(redirectLocation = "/", additionalParams = {}) {
		if ( !(await passkeys.isSupported()) ) {
			return;
		}

		// Make the call that returns the credentialGetJson above
		const credentialGetOptions = await fetch("/cbsecurity/passkeys/authentication/new?" + new URLSearchParams(additionalParams))
			.then(resp => resp.json())
			.then(json => JSON.parse(json));

		// Call WebAuthn ceremony using webauthn-json wrapper
		const publicKeyCredential = await webauthnJSON.get({
			mediation: "conditional",
			...credentialGetOptions
		});

		// Return encoded PublicKeyCredential to server
		const authenticationResponse = await fetch("/cbsecurity/passkeys/authentication", {
			method: "POST",
			headers: {
				"Content-Type": "application/json"
			},
			body: JSON.stringify({
				...additionalParams,
				"publicKeyCredentialJson": JSON.stringify(publicKeyCredential)
			})
		});

		if (authenticationResponse.ok) {
			window.location = redirectLocation;
		} else {
			console.error("cbsecurity-passkeys - Authentication failed:", authenticationResponse);
		}
	},
	async login(username, redirectLocation = "/", additionalParams = {}) {
		if ( !username ) {
			username = "";
		}
		// Make the call that returns the credentialGetJson above
		const credentialGetOptions = await fetch("/cbsecurity/passkeys/authentication/new?" + new URLSearchParams({
			...additionalParams,
			"username": username,
		}))
			.then(resp => resp.json())
			.then(json => JSON.parse(json));

		// Call WebAuthn ceremony using webauthn-json wrapper
		const publicKeyCredential = await webauthnJSON.get(credentialGetOptions);

		// Return encoded PublicKeyCredential to server
		const authenticationResponse = await fetch("/cbsecurity/passkeys/authentication", {
			method: "POST",
			headers: {
				"Content-Type": "application/json"
			},
			body: JSON.stringify({
				...additionalParams,
				"publicKeyCredentialJson": JSON.stringify(publicKeyCredential)
			})
		});

		if (authenticationResponse.ok) {
			window.location = redirectLocation;
		} else {
			console.error("cbsecurity-passkeys - Authentication failed:", authenticationResponse);
		}
	},
};

window.cbSecurity = window.cbSecurity || {};
window.cbSecurity.passkeys = passkeys;