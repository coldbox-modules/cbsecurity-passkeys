component {

	function configure() {
		var routeDomains = controller.getModuleSettings(
			module = "cbsecurity-passkeys",
			setting = "routeDomains",
			defaultValue = []
		);

		if ( routeDomains.isEmpty() ) {
			registerRoutes();
		} else {
			for ( var domain in routeDomains ) {
				registerRoutes( domain );
			}
		}

		// Suppress ColdBox's automatic module handler/action convention route.
		// Passkey ceremonies must only be reachable through the explicit routes above.
		route( "/:handler/:action" ).toResponse( "Not Found", 404 );
	}

	private void function registerRoutes( string domain = "" ) {
		if ( len( arguments.domain ) ) {
			route( "/registration/new" )
				.withDomain( arguments.domain )
				.withVerbs( "GET" )
				.to( "Registration.new" );
			route( "/registration" )
				.withDomain( arguments.domain )
				.withVerbs( "POST" )
				.to( "Registration.create" );

			route( "/authentication/new" )
				.withDomain( arguments.domain )
				.withVerbs( "GET" )
				.to( "Authentication.new" );
			route( "/authentication" )
				.withDomain( arguments.domain )
				.withVerbs( "POST" )
				.to( "Authentication.create" );
			return;
		}

		get( "/registration/new", "Registration.new" );
		post( "/registration", "Registration.create" );

		get( "/authentication/new", "Authentication.new" );
		post( "/authentication", "Authentication.create" );
	}

}
