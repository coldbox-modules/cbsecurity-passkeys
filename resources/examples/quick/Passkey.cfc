/**
 * An example conforming implementation of the ICredentialRepository interface for the cbsecurity-passkeys module.
 */
component extends="quick.models.BaseEntity" accessors="true" implements="cbsecurity-passkeys.models.ICredentialRepository" {

	property name="id";
	property name="userId";
    property name="signCount";
	property name="lastUsedTimestamp";

    // These fields are stored as binary in the database.
	property name="credentialId" sqltype="CF_SQL_BLOB";
	property name="publicKey" sqltype="CF_SQL_BLOB";
	property name="attestationObject" sqltype="CF_SQL_BLOB";

    // These fields are stored as bits in the database.
	property name="backupEligible" casts="BooleanCast@quick";
	property name="backupState" casts="BooleanCast@quick";

    // This field is a JSON string stored as text in the database.
    property name="clientDataJSON" casts="JsonCast@quick";

	public string function getUsernameForUser( required any user ) {
		return arguments.user.getEmail();
	}

	public string function getDisplayNameForUser( required any user ) {
		return arguments.user.getEmail();
	}

    /**
     * This method MUST return binary data.
     */
	public any function getUserHandleForUser( required any user ) {
		return toString( arguments.user.getId() ).getBytes();
	}

    /**
     * Returns all credential IDs for a given username.
     */
	public array function getCredentialIdsForUsername( required string username ) {
        var userHandle = getUserHandleForUsername( arguments.username );

        if ( isNull( userHandle ) ) {
            return [];
        }

		return newEntity()
            .where( "userId", toString( userHandle ) )
            .values( "credentialId" );
	}

    /**
     * This method MUST return binary data.
     */
	public any function getUserHandleForUsername( required string username ) {
		var user = newEntity( "User" )
			.where( "email", arguments.username )
			.first();

		if ( isNull( user ) ) {
			return javacast( "null", "" );
		}

		return toString( user.getId() ).getBytes();
	}

    /**
     * `userHandle` is binary data.
     */
	public string function getUsernameForUserHandle( required any userHandle ) {
		var user = newEntity( "User" )
			.where( "id", toString( userHandle ) )
			.first();

		if ( isNull( user ) ) {
			return javacast( "null", "" );
		}

		return user.getEmail();
	}

    /**
     * `credentialId` and `userHandle` are both binary data
     * Returns a struct with a `publicKey` and a `signatureCount` property.
     */
	public struct function lookup( required any credentialId, required any userHandle ) {
		var passkey = newEntity()
			.where( "credentialId", credentialId )
			.where( "userId", toString( userHandle ) )
			.first();

		if ( isNull( passkey ) ) {
			return javacast( "null", "" );
		}

		return {
			"publicKey": passkey.getPublicKey(),
			"signatureCount": passkey.getSignCount()
		};
	}

    /**
     * `credentialId` is binary data.
	 * Returns a struct with a `userHandle`, `publicKey` and a `signatureCount` property.
	 */
	public array function lookupAll( required any credentialId ) {
		return newEntity()
			.where( "credentialId", credentialId )
			.get()
			.map( ( passkey ) => {
				return {
					"userHandle": toString( passkey.getUserId() ).getBytes(),
					"publicKey": passkey.getPublicKey(),
					"signatureCount": passkey.getSignCount()
				};
			} );
	}

    /**
     * @user The User object for your application, retrieved from your AuthenticationService
     * @credentialId The binary credentialId
     * @publicKey The binary public key
     * @signatureCount The numeric signature could
     * @isDiscoverable Boolean flag if this Passkey should be discoverable
     * @isBackupEligible Booelan flag if this Passkey is eligible for backup
     * @isBackedUp Boolean flag if this Passkey is backed up
     * @attestationObject Binary attestation object
     * @clientDataJson JSON string of client data
     */
	public void function storeCredentialForUser(
		required any user,
		required any credentialId,
		required any publicKey,
		required numeric signatureCount,
		any isDiscoverable,
		required boolean isBackupEligible,
		required boolean isBackedUp,
		required any attestationObject,
		required string clientDataJson
	) {
		arguments.user.passkeys().create( {
			"credentialId": arguments.credentialId,
			"publicKey": arguments.publicKey,
			"signCount": arguments.signatureCount,
			"backupEligible": arguments.isBackupEligable ?: false,
			"backupState": arguments.isBackedUp,
			"attestationObject": arguments.attestationObject,
			"clientDataJSON": arguments.clientDataJson
		} );
	}

	public void function updateCredentialForUser(
		required any user,
		required any credentialId,
		required numeric signatureCount,
		required boolean isBackedUp,
		date lastUsedTimestamp = now()
	) {
		arguments.user.passkeys()
			.where( "credentialId", arguments.credentialId )
			.updateAll( {
				"signCount": arguments.signatureCount,
				"backupState": arguments.isBackedUp ? 1 : 0,
				"lastUsedTimestamp": arguments.lastUsedTimestamp
			} );
	}

}
