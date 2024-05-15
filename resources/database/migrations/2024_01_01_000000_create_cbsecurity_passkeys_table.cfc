component {

    function up( schema, qb ) {
		schema.create( "cbsecurity_passkeys", ( t ) => {
			t.increments( "id" );
			t.unsignedInteger( "userId" ).references( "id" ).onTable( "users" );
			t.raw( "credentialId BLOB" );
			t.raw( "publicKey BLOB" );
			t.unsignedInteger( "signCount" );
			t.bit( "backupEligible" );
			t.bit( "backupState" );
			t.raw( "attestationObject BLOB" );
			t.text( "clientDataJSON" );
			t.datetime( "lastUsedTimestamp" ).nullable();
		} );
    }

    function down( schema, qb ) {
		schema.drop( "cbsecurity_passkeys" );
    }

}
