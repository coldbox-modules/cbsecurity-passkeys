component singleton {

	property name="clientCredentialRepository" inject="ClientCredentialRepository@cbsecurity-passkeys";
	property name="log" inject="logbox:logger:{this}";

	variables.PUBLIC_KEY_TYPE = createObject( "java", "com.yubico.webauthn.data.PublicKeyCredentialType" ).PUBLIC_KEY;

	function getCredentialIdsForUsername( required string username ) {
		if ( log.canDebug() ) {
			log.debug( "Retrieving all credential ids for username [#arguments.username#]." );
		}

		var credentialIds = variables.clientCredentialRepository.getCredentialIdsForUsername( arguments.username );

		if ( log.canDebug() ) {
			log.debug(
				"Retrieved all credential ids for username [#arguments.username#].",
				{ "credentialIds" : credentialIds }
			);
		}

		return createObject( "java", "java.util.HashSet" ).init(
			credentialIds.map( ( credentialId ) => {
				return createObject( "java", "com.yubico.webauthn.data.PublicKeyCredentialDescriptor" )
					.builder()
					.id( toByteArray( credentialId ) )
					.type( variables.PUBLIC_KEY_TYPE )
					.build();
			} )
		);
	}

	function getUserHandleForUsername( required string username ) {
		if ( log.canDebug() ) {
			log.debug( "Retrieving the user handle for username [#arguments.username#]." );
		}
		var userHandle = variables.clientCredentialRepository.getUserHandleForUsername( arguments.username );

		if ( isNull( userHandle ) ) {
			if ( log.canDebug() ) {
				log.debug( "No user handle found for username [#arguments.username#]." );
			}
			return createObject( "java", "java.util.Optional" ).empty();
		}

		if ( log.canDebug() ) {
			log.debug(
				"Found a user handle for username [#arguments.username#].",
				{ "userHandle" : toString( userHandle ) }
			);
		}

		return createObject( "java", "java.util.Optional" ).of(
			createObject( "java", "com.yubico.webauthn.data.ByteArray" ).init( userHandle )
		);
	}

	function getUsernameForUserHandle( required any userHandle ) {
		if ( log.canDebug() ) {
			log.debug( "Retrieving the username for user handle [#toString( arguments.userHandle )#]." );
		}
		var username = variables.clientCredentialRepository.getUsernameForUserHandle( arguments.userHandle.getBytes() );

		if ( isNull( username ) ) {
			if ( log.canDebug() ) {
				log.debug( "No username found for user handle [#toString( arguments.userHandle )#]." );
			}
			return createObject( "java", "java.util.Optional" ).empty();
		}

		if ( log.canDebug() ) {
			log.debug(
				"Found a username for user handle [#toString( arguments.userHandle )#].",
				{ "username" : username }
			);
		}

		return createObject( "java", "java.util.Optional" ).of( toString( username ) );
	}

	function lookup( required any credentialId, required any userHandle ) {
		var passkey = variables.clientCredentialRepository.lookup(
			arguments.credentialId.getBytes(),
			arguments.userHandle.getBytes()
		);

		if ( isNull( passkey ) ) {
			return createObject( "java", "java.util.Optional" ).empty();
		}

		if ( !isStruct( passkey ) ) {
			throw( "The returned value is not a struct." );
		}

		if ( !passkey.keyExists( "publicKey" ) ) {
			throw( "The returned struct does not contain a `publicKey` property." );
		}

		if ( !passkey.keyExists( "signatureCount" ) ) {
			throw( "The returned struct does not contain a `signatureCount` property." );
		}

		var registeredCredential = createObject( "java", "com.yubico.webauthn.RegisteredCredential" )
			.builder()
			.credentialId( arguments.credentialId )
			.userHandle( arguments.userHandle )
			.publicKeyCose( createObject( "java", "com.yubico.webauthn.data.ByteArray" ).init( passkey.publicKey ) )
			.signatureCount( javacast( "long", passkey.signatureCount ) )
			.build();

		return createObject( "java", "java.util.Optional" ).of( registeredCredential );
	}

	function lookupAll( required any credentialId ) {
		return createObject( "java", "java.util.HashSet" ).init(
			variables.clientCredentialRepository
				.lookupAll( arguments.credentialId.getBytes() )
				.map( ( passkey ) => {
					if ( !isStruct( passkey ) ) {
						throw( "The returned value is not a struct." );
					}

					if ( !passkey.keyExists( "userHandle" ) ) {
						throw( "The returned struct does not contain a `userHandle` property." );
					}

					if ( !passkey.keyExists( "publicKey" ) ) {
						throw( "The returned struct does not contain a `publicKey` property." );
					}

					if ( !passkey.keyExists( "signatureCount" ) ) {
						throw( "The returned struct does not contain a `signatureCount` property." );
					}

					return createObject( "java", "com.yubico.webauthn.RegisteredCredential" )
						.builder()
						.credentialId( credentialId )
						.userHandle(
							createObject( "java", "com.yubico.webauthn.data.ByteArray" ).init( passkey.userHandle )
						)
						.publicKeyCose(
							createObject( "java", "com.yubico.webauthn.data.ByteArray" ).init( passkey.publicKey )
						)
						.signatureCount( javacast( "long", passkey.signatureCount ) )
						.build();
				} )
		);
	}

	private any function toByteArray( required any value ) {
		return createObject( "java", "com.yubico.webauthn.data.ByteArray" ).init( arguments.value );
	}

}
