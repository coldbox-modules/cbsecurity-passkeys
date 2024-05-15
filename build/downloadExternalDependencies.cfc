component {

    property name="progressBarGeneric" inject="progressBarGeneric";

	function run() {
		print.line( "Cleaning build lib directory..." ).toConsole();
		if ( directoryExists( "./lib" ) ) {
			directoryDelete( "./lib", true );
		}

		print.line( "Cleaning build target directory..." ).toConsole();
		if ( directoryExists( "./target" ) ) {
			directoryDelete( "./target", true );
		}

		print.line( "Downloading the latest jars..." ).toConsole();
		command( "run" )
			.params( "mvn dependency:copy-dependencies -DoutputDirectory=lib" )
			.inWorkingDirectory( getDirectoryFromPath( getCurrentTemplatePath() ) )
			.run( returnOutput = true );

		print.line( "Packaging up into a fat jar..." ).toConsole();
		command( "run" )
			.params( "mvn package" )
			.inWorkingDirectory( getDirectoryFromPath( getCurrentTemplatePath() ) )
			.run( returnOutput = true );

		print.line( "Copying fat jar into the module lib directory..." ).toConsole();
		var libDirectory = resolvePath( "../lib" );
		if ( directoryExists( libDirectory ) ) {
			directoryDelete( libDirectory, true );
		}
		directoryCreate( libDirectory );

		var projectVersion = xmlParse( fileRead( resolvePath( "./pom.xml" ) ) ).XmlRoot.version.XmlText;
		var boxVersion = deserializeJSON( fileRead( resolvePath( "../box.json" ) ) ).version;

		fileMove(
			resolvePath( "./target/yubico-webauthn-#projectVersion#-jar-with-dependencies.jar" ),
			resolvePath( "../lib/yubico-webauthn-#boxVersion#.jar" )
		);

		print.line( "Cleaning node_modules" ).toConsole();
		var nodeModulesPath = resolvePath( "../node_modules" );
		if ( directoryExists( nodeModulesPath ) ) {
			directoryDelete( nodeModulesPath, true );
		}

		print.line( "Installing latest @github/webauthn-json" ).toConsole();
		command( "run" )
			.params( "npm install" )
			.inWorkingDirectory( resolvePath( "../" ) )
			.run( returnOutput = true );

		print.greenLine( 'Copying browser file to includes directory' ).toConsole();
		var includesDirectory = resolvePath( "../includes" );
		if ( directoryExists( includesDirectory ) ) {
			directoryDelete( includesDirectory, true );
		}
		directoryCreate( includesDirectory );

		var passkeysPath = resolvePath( "../includes/passkeys.js" );

		var passkeysJsFileContents = fileRead( resolvePath( "../node_modules/@github/webauthn-json/dist/browser-global/webauthn-json.browser-global.js" ) );
		replaceNoCase( passkeysJsFileContents, "//## sourceMappingURL=webauthn-json.browser-global.js.map", "", "all" );

		print.greenLine( 'Appending passkeys code to JavaScript file' ).toConsole();

		passkeysJsFileContents &= fileRead( resolvePath( "../resources/assets/js/passkeys.js" ) )

		fileWrite(
			passkeysPath,
			passkeysJsFileContents
		);

		print.line( "External dependencies packaged" ).toConsole();
	}

}
