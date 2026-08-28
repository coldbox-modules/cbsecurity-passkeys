component {

	this.name = "cbsecurityPasskeysTestingSuite" & hash( getCurrentTemplatePath() );
	this.sessionManagement = true;
	this.setClientCookies = true;
	this.sessionTimeout = createTimespan( 0, 0, 15, 0 );
	this.applicationTimeout = createTimespan( 0, 0, 15, 0 );

	testsPath = getDirectoryFromPath( getCurrentTemplatePath() );
	this.mappings[ "/tests" ] = testsPath;
	rootPath = reReplaceNoCase(
		this.mappings[ "/tests" ],
		"tests(\\|/)",
		""
	);
	this.mappings[ "/root" ] = rootPath;
	this.mappings[ "/cbsecurity-passkeys" ] = rootPath;
	this.mappings[ "/testingModuleRoot" ] = listDeleteAt(
		rootPath,
		listLen( rootPath, "\/" ),
		"\/"
	);
	this.mappings[ "/app" ] = testsPath & "resources/app";
	this.mappings[ "/coldbox" ] = testsPath & "resources/app/coldbox";
	this.mappings[ "/testbox" ] = rootPath & "/testbox";

	this.javaSettings = {
		loadPaths : [ rootPath & "/lib" ],
		reloadOnChange : false
	};

	this.datasource = "cbsecurity-passkeys";

	function onRequestStart() {
		createObject( "java", "java.lang.System" ).setProperty( "ENVIRONMENT", "testing" );
		structDelete( application, "cbController" );
		structDelete( application, "wirebox" );
	}

}
