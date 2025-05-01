interface displayname="ICredentialRepository" {

	public string function getUsernameForUser( required any user );
	public string function getDisplayNameForUser( required any user );
	public any function getUserHandleForUser( required any user );

	public array function getCredentialIdsForUsername( required string username );
	public any function getUserHandleForUsername( required string username );
	public string function getUsernameForUserHandle( required any userHandle );

	/**
	 * `credentialId` and `userHandle` are both binary data
	 * Returns a struct with a `publicKey` and a `signatureCount` property.
	 * `null` if no credential is found.
	 */
	public any function lookup( required any credentialId, required any userHandle );
	/**
	 * Returns a struct with a `userHandle`, `publicKey` and a `signatureCount` property.
	 */
	public array function lookupAll( required any credentialId );

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
	);

	public void function updateCredentialForUser(
		required any user = user,
		required any credentialId,
		required numeric signatureCount,
		required boolean isBackedUp,
		date lastUsedTimestamp
	);

}
