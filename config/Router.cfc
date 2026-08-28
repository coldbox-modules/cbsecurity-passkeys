component {

	function configure() {
		var routeDomains = controller.getModuleSettings(
			module = "cbsecurity-passkeys",
			setting = "routeDomains",
			defaultValue = []
		);

		if ( routeDomains.isEmpty() ) {
			routeDomains.append( "" );
		}

		for ( var domain in routeDomains ) {
			group( { domain : domain }, () => {
				get( "/registration/new", "Registration.new" );
				post( "/registration", "Registration.create" );

				get( "/authentication/new", "Authentication.new" );
				post( "/authentication", "Authentication.create" );
			} );
		}

		// Suppress ColdBox's automatic module handler/action convention route.
		// Passkey ceremonies must only be reachable through the explicit routes above.
		route( "/:handler/:action" ).toResponse( "Not Found", 404 );
	}

}
