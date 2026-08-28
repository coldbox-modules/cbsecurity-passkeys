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
			route( "/registration/new" )
				.withDomain( domain )
				.withVerbs( "GET" )
				.to( "Registration.new" );
			route( "/registration" )
				.withDomain( domain )
				.withVerbs( "POST" )
				.to( "Registration.create" );

			route( "/authentication/new" )
				.withDomain( domain )
				.withVerbs( "GET" )
				.to( "Authentication.new" );
			route( "/authentication" )
				.withDomain( domain )
				.withVerbs( "POST" )
				.to( "Authentication.create" );
		}

		// Suppress ColdBox's automatic module handler/action convention route.
		// Passkey ceremonies must only be reachable through the explicit routes above.
		route( "/:handler/:action" ).toResponse( "Not Found", 404 );
	}

}
