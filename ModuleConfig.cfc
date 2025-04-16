component {

	this.name = "cbsecurity-passkeys";
	this.author = "Eric Peterson";
	this.webUrl = "https://github.com/coldbox-modules/cbPasskeys";
	this.entrypoint = "/cbsecurity/passkeys";
	this.cfmapping = "cbsecurity-passkeys";
	this.dependencies = [ "cbsecurity" ];

	function configure() {
		settings = {
			"credentialRepositoryMapping" : "",
			"relyingPartyId" : CGI.SERVER_NAME,
			"relyingPartyName" : controller.getSetting( "appName" ),
			"allowedOrigins" : []
		};

		interceptorSettings = {
			"customInterceptionPoints" : [
				"onPasskeyLogin",
				"onPasskeyRegistration"
			]
		};
	}

	function afterAspectsLoad() {
		if ( settings.credentialRepositoryMapping == "" ) {
			throw( "You are required to set a `credentialRepositoryMapping` to use cbsecurity-passkeys" );
		}

		binder
			.forceMap( "ClientCredentialRepository@cbsecurity-passkeys" )
			.toDSL( settings.credentialRepositoryMapping );

		var credentialRepository = createDynamicProxy(
			wirebox.getInstance( "PasskeyService@cbsecurity-passkeys" ),
			[ "com.yubico.webauthn.CredentialRepository" ]
		);

		var rpIdentity = createObject( "java", "com.yubico.webauthn.data.RelyingPartyIdentity" )
			.builder()
			.id( settings.relyingPartyId )
			.name( settings.relyingPartyName )
			.build();

		if ( settings.allowedOrigins.isEmpty() ) {
			throw( "You are required to set at least one `allowedOrigin` to use cbsecurity-passkeys" );
		}

		var rpBuilder = createObject( "java", "com.yubico.webauthn.RelyingParty" )
			.builder()
			.identity( rpIdentity )
			.credentialRepository( credentialRepository );

		if ( !settings.allowedOrigins.isEmpty() ) {
			rpBuilder.origins( createObject( "java", "java.util.HashSet" ).init( settings.allowedOrigins ) );
		}

		binder.map( "RelyingParty@cbsecurity-passkeys" ).toValue( rpBuilder.build() );
	}

}
