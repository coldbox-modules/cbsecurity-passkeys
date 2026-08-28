component {

	function getCredentialIdsForUsername( required string username ) {
		return [ toBytes( "credential-id" ) ];
	}

	function getUserHandleForUsername( required string username ) {
		return toBytes( "user-id" );
	}

	function getUsernameForUserHandle( required any userHandle ) {
		return "user@example.com";
	}

	function lookup( required any credentialId, required any userHandle ) {
		return {
			publicKey : toBytes( "public-key" ),
			signatureCount : 7
		};
	}

	function lookupAll( required any credentialId ) {
		return [
			{
				userHandle : toBytes( "user-id" ),
				publicKey : toBytes( "public-key" ),
				signatureCount : 7
			}
		];
	}

	private any function toBytes( required string value ) {
		return createObject( "java", "java.lang.String" ).init( arguments.value ).getBytes( "UTF-8" );
	}

}
