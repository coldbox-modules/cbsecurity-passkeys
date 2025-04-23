component secured {

	property name="clientCredentialRepository" inject="ClientCredentialRepository@cbsecurity-passkeys";
	property name="objectMapper" inject="java:com.fasterxml.jackson.databind.ObjectMapper";
	property name="relyingParty" inject="RelyingParty@cbsecurity-passkeys";
	property name="flash" inject="coldbox:flash";

	function new( event, rc, prc ) {
		var user = cbSecure().getUser();
		var name = variables.clientCredentialRepository.getUsernameForUser( user );
		var displayName = variables.clientCredentialRepository.getDisplayNameForUser( user );
		var idByteArray = createObject( "java", "com.yubico.webauthn.data.ByteArray" ).init(
			variables.clientCredentialRepository.getUserHandleForUser( cbSecure().getUser() )
		);

		if ( log.canDebug() ) {
			log.debug(
				"Creating a UserIdentity for the new Passkey",
				{
					"name" : name,
					"displayName" : displayName,
					"id" : idByteArray.toString()
				}
			);
		}

		var userIdentity = createObject( "java", "com.yubico.webauthn.data.UserIdentity" )
			.builder()
			.name( name )
			.displayName( displayName )
			.id( idByteArray )
			.build();

		if ( log.canDebug() ) {
			log.debug( "Starting a Passkey registration for [#name#] (#displayName#)" );
		}

		var req = variables.relyingParty.startRegistration(
			createObject( "java", "com.yubico.webauthn.StartRegistrationOptions" )
				.builder()
				.user( userIdentity )
				.build()
		);

		if ( log.canDebug() ) {
			log.debug( "Placing the registration request in the flash scope for the next request" );
		}

		flash.put(
			name = "passkeyRegistrationRequest",
			value = req.toJson(),
			saveNow = true
		);

		event.renderData(
			type = "json",
			statusCode = 200,
			statusText = "OK",
			contentType = "application/json",
			data = req.toCredentialsCreateJson()
		);
	}

	function create( event, rc, prc ) {
		if ( !flash.exists( "passkeyRegistrationRequest" ) ) {
			throw(
				type = "CBSecurity.Passkeys.MissingRegistrationRequest",
				message = "No existing registration request found"
			);
		}

		if ( !rc.keyExists( "publicKeyCredentialJson" ) || !isValid( "string", rc.publicKeyCredentialJson ) ) {
			throw(
				type = "CBSecurity.Passkeys.InvalidRegistrationRequest",
				message = "`publicKeyCredentialJson` should be the json string, not an actual object."
			);
		}

		try {
			if ( log.canDebug() ) {
				log.debug( "Creating a new PublicKeyCredential from the validated JSON" );
			}

			var pkc = createObject( "java", "com.yubico.webauthn.data.PublicKeyCredential" ).parseRegistrationResponseJson(
				rc.publicKeyCredentialJson
			);

			if ( log.canDebug() ) {
				log.debug( "Finishing the Passkey registration." );
			}

			var result = variables.relyingParty.finishRegistration(
				createObject( "java", "com.yubico.webauthn.FinishRegistrationOptions" )
					.builder()
					.request(
						createObject( "java", "com.yubico.webauthn.data.PublicKeyCredentialCreationOptions" ).fromJson(
							flash.get( "passkeyRegistrationRequest" )
						)
					)
					.response( pkc )
					.build()
			);

			if ( log.canDebug() ) {
				log.debug( "Storing the newly created Passkey." );
			}

			variables.clientCredentialRepository.storeCredentialForUser(
				user = cbSecure().getUser(),
				credentialId = result
					.getKeyId()
					.getId()
					.getBytes(),
				publicKey = result.getPublicKeyCose().getBytes(),
				signatureCount = result.getSignatureCount(),
				isDiscoverable = result.isDiscoverable().isPresent() ? result.isDiscoverable().get() : javacast(
					"null",
					""
				),
				isBackupEligible = result.isBackupEligible() ?: false,
				isBackedUp = result.isBackedUp(),
				attestationObject = pkc
					.getResponse()
					.getAttestationObject()
					.getBytes(),
				clientDataJson = toString(
					pkc.getResponse()
						.getClientDataJSON()
						.getBytes()
				)
			);

			event.renderData(
				type = "json",
				statusCode = 201,
				statusText = "Created",
				contentType = "application/json",
				data = { "createdDate" : dateFormat( now(), "iso" ) }
			);
		} catch ( "com.yubico.webauthn.exception.RegistrationFailedException" e ) {
			if ( log.canError() ) {
				log.error(
					structKeyExists( e, "message" ) ? e.message : ( structKeyExists( e, "getMessage" ) ? e.getMessage() : toString( e ) ),
					{ "exception" : e }
				);
			}
			event.renderData(
				type = "json",
				statusCode = 400,
				statusText = "Bad Request",
				contentType = "application/json",
				data = {}
			);
			return;
		} catch ( any e ) {
			if ( log.canError() ) {
				log.error(
					structKeyExists( e, "message" ) ? e.message : ( structKeyExists( e, "getMessage" ) ? e.getMessage() : toString( e ) ),
					{ "exception" : e }
				);
			}
			rethrow;
		}
	}

}
