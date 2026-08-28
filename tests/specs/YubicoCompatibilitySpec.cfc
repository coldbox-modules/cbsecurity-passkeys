component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "Yubico WebAuthn compatibility", () => {
			beforeEach( () => {
				variables.relyingParty = buildRelyingParty();
			} );

			it( "builds and restores registration ceremony options", () => {
				var userIdentity = createObject( "java", "com.yubico.webauthn.data.UserIdentity" )
					.builder()
					.name( "user@example.com" )
					.displayName( "Example User" )
					.id( toByteArray( "user-id" ) )
					.build();

				var options = variables.relyingParty.startRegistration(
					createObject( "java", "com.yubico.webauthn.StartRegistrationOptions" )
						.builder()
						.user( userIdentity )
						.build()
				);
				var restoredOptions = createObject(
					"java",
					"com.yubico.webauthn.data.PublicKeyCredentialCreationOptions"
				).fromJson( options.toJson() );
				var browserOptions = deserializeJSON( options.toCredentialsCreateJson() );

				expect( restoredOptions.getRp().getId() ).toBe( "example.com" );
				expect( restoredOptions.getUser().getName() ).toBe( "user@example.com" );
				expect( browserOptions ).toHaveKey( "publicKey" );
				expect( browserOptions.publicKey.rp.id ).toBe( "example.com" );
				expect( browserOptions.publicKey.excludeCredentials.len() ).toBe( 1 );
			} );

			it( "builds and restores username-bound assertion requests", () => {
				var assertionRequest = variables.relyingParty.startAssertion(
					createObject( "java", "com.yubico.webauthn.StartAssertionOptions" )
						.builder()
						.username( createObject( "java", "java.util.Optional" ).of( "user@example.com" ) )
						.userVerification(
							createObject( "java", "com.yubico.webauthn.data.UserVerificationRequirement" ).PREFERRED
						)
						.build()
				);
				var restoredRequest = createObject( "java", "com.yubico.webauthn.AssertionRequest" ).fromJson(
					assertionRequest.toJson()
				);
				var browserOptions = deserializeJSON( assertionRequest.toCredentialsGetJson() );

				expect( restoredRequest.getUsername().get() ).toBe( "user@example.com" );
				expect( browserOptions ).toHaveKey( "publicKey" );
				expect( browserOptions.publicKey.rpId ).toBe( "example.com" );
				expect( browserOptions.publicKey.userVerification ).toBe( "preferred" );
			} );

			it( "builds discoverable assertion requests without a username", () => {
				var assertionRequest = variables.relyingParty.startAssertion(
					createObject( "java", "com.yubico.webauthn.StartAssertionOptions" )
						.builder()
						.username( createObject( "java", "java.util.Optional" ).empty() )
						.build()
				);

				expect( assertionRequest.getUsername().isPresent() ).toBeFalse();
				expect( deserializeJSON( assertionRequest.toCredentialsGetJson() ) ).toHaveKey( "publicKey" );
			} );

			it( "maps stored passkeys to Yubico registered credentials", () => {
				var passkeyService = buildPasskeyService();
				var credentialId = toByteArray( "credential-id" );
				var userHandle = toByteArray( "user-id" );
				var credential = passkeyService.lookup( credentialId, userHandle ).get();
				var credentials = passkeyService.lookupAll( credentialId );

				expect( credential.getCredentialId() ).toBe( credentialId );
				expect( credential.getUserHandle() ).toBe( userHandle );
				expect( credential.getSignatureCount() ).toBe( 7 );
				expect( credentials.size() ).toBe( 1 );
				expect(
					credentials
						.iterator()
						.next()
						.getSignatureCount()
				).toBe( 7 );
			} );
		} );
	}

	private any function buildRelyingParty() {
		var passkeyService = buildPasskeyService();
		var credentialRepository = createDynamicProxy( passkeyService, [ "com.yubico.webauthn.CredentialRepository" ] );
		var identity = createObject( "java", "com.yubico.webauthn.data.RelyingPartyIdentity" )
			.builder()
			.id( "example.com" )
			.name( "Example" )
			.build();

		return createObject( "java", "com.yubico.webauthn.RelyingParty" )
			.builder()
			.identity( identity )
			.credentialRepository( credentialRepository )
			.origins( createObject( "java", "java.util.HashSet" ).init( [ "https://example.com" ] ) )
			.allowOriginSubdomain( false )
			.build();
	}

	private any function buildPasskeyService() {
		var passkeyService = prepareMock( createObject( "component", "cbsecurity-passkeys.models.PasskeyService" ) );
		passkeyService.$property(
			propertyName = "clientCredentialRepository",
			propertyScope = "variables",
			mock = new tests.resources.ClientCredentialRepositoryStub()
		);
		passkeyService.$property(
			propertyName = "log",
			propertyScope = "variables",
			mock = new tests.resources.SilentLogger()
		);
		return passkeyService;
	}

	private any function toByteArray( required string value ) {
		var bytes = createObject( "java", "java.lang.String" ).init( arguments.value ).getBytes( "UTF-8" );
		return createObject( "java", "com.yubico.webauthn.data.ByteArray" ).init( bytes );
	}

}
