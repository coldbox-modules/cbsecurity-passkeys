component {

	function configure() {
		get( "/registration/new", "Registration.new" );
		post( "/registration", "Registration.create" );

		get( "/authentication/new", "Authentication.new" );
		post( "/authentication", "Authentication.create" );
	}

}
