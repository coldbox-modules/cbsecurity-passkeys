/**
 * An example conforming implementation of the ICredentialRepository interface for the cbsecurity-passkeys module.
 */
component
	persistent="true"
	table="passkeys"
	extends="cborm.models.ActiveEntity"
	implements="cbsecurity-passkeys.models.ICredentialRepository"
{

	/***********************************************************************
	 **						DEPENDENCIES
	 ***********************************************************************/

	property name="userService" inject="provider:userService" persistent="false";

	/***********************************************************************
	 **						FIELDS
	 ***********************************************************************/

	property
		name="id"
		column="id"
		fieldtype="id"
		generator="uuid"
		ormtype="string"
		setter="false";

	property name="signCount" notnull="true" ormtype="long";

	property name="lastUsedTimestamp" notnull="false" ormtype="timestamp";

	property name="credentialId" notnull="true" ormtype="blob";

	property name="publicKey" notnull="true" ormtype="blob";

	property name="attestationObject" notnull="true" ormtype="blob";

	property name="backupEligible" notnull="true" ormtype="boolean";

	property name="backupState" notnull="true" ormtype="boolean";

	property
		name="clientDataJSONString"
		column="clientDataJSON"
		notnull="true"
		ormtype="text"
		default="{}";

	/***********************************************************************
	 **						RELATIONSHIPS
	 ***********************************************************************/

	property
		name="user"
		notnull="true"
		cfc="forgebox.models.security.User"
		fieldtype="many-to-one"
		fkcolumn="userId"
		lazy="true";

	/***********************************************************************
	 **		   				GETTER OVERRIDES
	 ***********************************************************************/

	public struct function getClientDataJSON() {
		param variables._clientData = deserializeJSON( this.clientDataJSONString() );
		return variables._clientData;
	}

	/***********************************************************************
	 **		   PASSKEYS ICredentialRepository INTERFACE METHODS
	 ***********************************************************************/


	public string function getUsernameForUser( required any user ) {
		return arguments.user.getUsername();
	}

	public string function getDisplayNameForUser( required any user ) {
		return arguments.user.getFullName();
	}

	/**
	 * This method MUST return binary data.
	 */
	public any function getUserHandleForUser( required any user ) {
		return toString( arguments.user.getUserID() ).getBytes();
	}

	/**
	 * Returns all credential IDs for a given username.
	 */
	public array function getCredentialIdsForUsername( required string username ) {
		var userHandle = getUserHandleForUsername( arguments.username );

		if ( isNull( userHandle ) ) {
			return [];
		}

		return this
			.newCriteria()
			.eq( "user.userID", toString( userHandle ) )
			.withProjections( property = "credentialId" )
			.list();
	}

	/**
	 * This method MUST return binary data.
	 */
	public any function getUserHandleForUsername( required string username ) {
		var user = variables.userService
			.newCriteria()
			.eq( "username", arguments.username )
			.get();

		if ( isNull( user ) ) {
			return javacast( "null", "" );
		}

		return toString( user.getUserID() ).getBytes();
	}

	/**
	 * `userHandle` is binary data.
	 */
	public string function getUsernameForUserHandle( required any userHandle ) {
		var user = variables.userService
			.newCriteria()
			.eq( "userID", toString( arguments.userHandle ) )
			.get();

		if ( isNull( user ) ) {
			return javacast( "null", "" );
		}

		return user.getUsername();
	}

	/**
	 * `credentialId` and `userHandle` are both binary data
	 * Returns a struct with a `publicKey` and a `signatureCount` property.
	 */
	public struct function lookup( required any credentialId, required any userHandle ) {
		var passkey = this
			.newCriteria()
			.eq( "credentialId", arguments.credentialId )
			.eq( "user.userID", toString( arguments.userHandle ) )
			.get();

		if ( isNull( passkey ) ) {
			return javacast( "null", "" );
		}

		return { "publicKey": passkey.getPublicKey(), "signatureCount": passkey.getSignCount() };
	}

	/**
	 * `credentialId` is binary data.
	 * Returns a struct with a `userHandle`, `publicKey` and a `signatureCount` property.
	 */
	public array function lookupAll( required any credentialId ) {
		return this
			.newCriteria()
			.eq( "credentialId", arguments.credentialId )
			.list()
			.map( ( passkey ) => {
				return {
					"userHandle": toString(
						passkey
							.getUser()
							.getUserID()
					).getBytes(),
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
		this.new( {
				"user": arguments.user,
				"credentialId": arguments.credentialId,
				"publicKey": arguments.publicKey,
				"signCount": arguments.signatureCount,
				"backupEligible": arguments.isBackupEligible ?: false,
				"backupState": arguments.isBackedUp,
				"attestationObject": arguments.attestationObject,
				"clientDataJSON": arguments.clientDataJson
			} )
			.save();
	}

	public void function updateCredentialForUser(
		required any user,
		required any credentialId,
		required numeric signatureCount,
		required boolean isBackedUp,
		date lastUsedTimestamp = now()
	) {
		var passkeys = this
			.newCriteria()
			.eq( "credentialId", arguments.credentialId )
			.eq( "user.userID", arguments.user.getUserID() )
			.list();

		for ( var passkey in passkeys ) {
			passkey.setSignCount( arguments.signatureCount );
			passkey.setBackupState( arguments.isBackedUp ? 1 : 0 );
			passkey.setLastUsedTimestamp( arguments.lastUsedTimestamp );
			passkey.save();
		}
	}

}
