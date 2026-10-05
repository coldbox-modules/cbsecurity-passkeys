component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "Relying party origin validation", () => {
			it( "allows configured origin subdomains when enabled", () => {
				var moduleConfig = configuredModule( true );
				var builder = new tests.resources.RelyingPartyBuilderStub();

				moduleConfig.configureOriginValidation( builder );

				expect( builder.getConfiguredOrigins().size() ).toBe( 1 );
				expect( builder.getConfiguredOrigins().contains( "https://example.com" ) ).toBeTrue();
				expect( builder.isOriginSubdomainsAllowed() ).toBeTrue();
			} );

			it( "keeps origin subdomains disabled by default", () => {
				var moduleConfig = configuredModule( false );
				var builder = new tests.resources.RelyingPartyBuilderStub();

				moduleConfig.configureOriginValidation( builder );

				expect( builder.isOriginSubdomainsAllowed() ).toBeFalse();
			} );
		} );
	}

	private any function configuredModule( required boolean allowOriginSubdomains ) {
		var moduleConfig = prepareMock( createObject( "component", "cbsecurity-passkeys.ModuleConfig" ) );
		moduleConfig.$property(
			propertyName = "settings",
			propertyScope = "variables",
			mock = {
				allowedOrigins : [ "https://example.com" ],
				allowOriginSubdomains : arguments.allowOriginSubdomains
			}
		);
		return makePublic( moduleConfig, "configureOriginValidation" );
	}

}
