/**
 * This component is related to the Passkey entity. It is included for reference on how to implement the ICredentialRepository interface.
 */
component extends="quick.models.BaseEntity" accessors="true" {

	property name="bcrypt" inject="@BCrypt" persistent="false";

	property name="id";
	property name="email";
	property name="password";

	this.memento = { "defaultExcludes" : [ "id" ], "neverInclude" : [ "password" ] };

	function passkeys() {
		return hasMany( "Passkey" );
	}

	public User function setPassword( required string password ){
		return assignAttribute( "password", bcrypt.hashPassword( arguments.password ) );
	}

	public boolean function hasPermission( required string permission ){
		return true;
	}

	public boolean function isValidCredentials( required string email, required string password ){
		var user = newEntity().where( "email", arguments.email ).first();
		if ( isNull( user ) ) {
			return false;
		}
		return bcrypt.checkPassword( arguments.password, user.getPassword() );
	}

	public User function retrieveUserByUsername( required string email ){
		return newEntity().where( "email", arguments.email ).firstOrFail();
	}

	public User function retrieveUserById( required numeric id ){
		return newEntity().findOrFail( arguments.id );
	}

}
