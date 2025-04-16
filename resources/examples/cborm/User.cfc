/**
 * A ForgeBox User
 */
component
	persistent="true"
	table="users"
	extends="cborm.models.ActiveEntity"
{

	/* *********************************************************************
	 **						PROPERTIES
	 ********************************************************************* */

	property
		name="userID"
		column="user_id"
		fieldtype="id"
		generator="uuid"
		ormtype="string"
		setter="false";

	property
		name="firstName"
		ormtype="string"
		notnull="true";

	property
		name="lastName"
		ormtype="string"
		notnull="true";

	property
		name="email"
		unique="true"
		notnull="true";

	property
		name="username"
		unique="true"
		notnull="true";

	property
		name="password"
		notnull="true";

	/* *********************************************************************
	 **						RELATIONSHIPS
	 ********************************************************************* */

	property
		name="passkeys"
		singularName="passkey"
		type="array"
		fieldtype="one-to-many"
		cfc="Passkey"
		fkcolumn="userId"
		inverse="true"
		lazy="extra"
		cascade="save-update"
		batchsize="20"
		orderby="lastUsedTimestamp desc";

}
