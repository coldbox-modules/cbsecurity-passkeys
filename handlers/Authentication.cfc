component {

	property name="clientCredentialRepository" inject="ClientCredentialRepository@cbsecurity-passkeys";
	property name="relyingParty" inject="RelyingParty@cbsecurity-passkeys";
	property name="flash" inject="coldbox:flash";

	function new( event, rc, prc ) {
		if ( log.canDebug() ) {
			log.debug( "Starting an assertion request" );
		}

		var req = variables.relyingParty.startAssertion(
			createObject( "java", "com.yubico.webauthn.StartAssertionOptions" )
				.builder()
				.username(
					( rc.keyExists( "username" ) && rc.username != "" ) ? createObject( "java", "java.util.Optional" ).of(
						rc.username
					) : createObject( "java", "java.util.Optional" ).empty()
				)
				.userVerification(
					createObject( "java", "com.yubico.webauthn.data.UserVerificationRequirement" ).PREFERRED
				)
				.build()
		);

		if ( log.canDebug() ) {
			log.debug( "Saving the assertion request in the flash scope" );
		}

		flash.put(
			name = "passkeyAssertionRequest",
			value = req.toJson(),
			saveNow = true
		);

		event.renderData(
			type = "json",
			statusCode = 200,
			statusText = "OK",
			contentType = "application/json",
			data = req.toCredentialsGetJson()
		);
	}

	function create( event, rc, prc ) {
		if ( !flash.exists( "passkeyAssertionRequest" ) ) {
			throw( type = "CBSecurity.Passkeys.MissingAssertionRequest", message = "No existing assertion request" );
		}

		if ( !rc.keyExists( "publicKeyCredentialJson" ) || !isValid( "string", rc.publicKeyCredentialJson ) ) {
			throw(
				type = "CBSecurity.Passkeys.InvalidAssertionRequest",
				message = "`publicKeyCredentialJson` should be the json string, not an actual object."
			);
		}

		if ( log.canDebug() ) {
			log.debug( "Finishing the assertion request" );
		}

		var result = variables.relyingParty.finishAssertion(
			createObject( "java", "com.yubico.webauthn.FinishAssertionOptions" )
				.builder()
				.request(
					createObject( "java", "com.yubico.webauthn.AssertionRequest" ).fromJson(
						flash.get( "passkeyAssertionRequest" )
					)
				)
				.response(
					createObject( "java", "com.yubico.webauthn.data.PublicKeyCredential" ).parseAssertionResponseJson(
						rc.publicKeyCredentialJson
					)
				)
				.build()
		);

		if ( !result.isSuccess() ) {
			if ( log.canDebug() ) {
				log.debug( "Passkey assertion failed. Returning a 403 response." );
			}

			event.renderData(
				type = "json",
				statusCode = 403,
				statusText = "OK",
				contentType = "text/plain",
				data = {}
			);
			return;
		}

		var username = result.getUsername();

		if ( log.canDebug() ) {
			log.debug( "Passkey assertion successful for user [#username#]." );
		}

		var user = cbSecure().getUserService().retrieveUserByUsername( username );

		if ( log.canDebug() ) {
			log.debug( "Logging in user [#username#] from a successful Passkey assertion." );
		}
		cbSecure().getAuthService().login( user );

		if ( log.canDebug() ) {
			log.debug( "Updating the credential after a successful Passkey assertion." );
		}
		variables.clientCredentialRepository.updateCredentialForUser(
			user = user,
			credentialId = result.getCredentialId().getBytes(),
			signatureCount = result.getSignatureCount(),
			isBackedUp = result.isBackedUp(),
			lastUsedTimestamp = now()
		);

		announce( "onPasskeyLogin", { "event" : event, "user" : user } );

		event.renderData(
			type = "json",
			statusCode = 200,
			statusText = "OK",
			contentType = "application/json",
			data = { "loginTimestamp" : dateTimeFormat( now(), "iso" ) }
		);
	}

}
