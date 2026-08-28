component {

	variables.configuredOrigins = [];
	variables.originSubdomainsAllowed = false;

	function origins( required origins ) {
		variables.configuredOrigins = arguments.origins;
		return this;
	}

	function allowOriginSubdomain( required boolean allowed ) {
		variables.originSubdomainsAllowed = arguments.allowed;
		return this;
	}

	function getConfiguredOrigins() {
		return variables.configuredOrigins;
	}

	boolean function isOriginSubdomainsAllowed() {
		return variables.originSubdomainsAllowed;
	}

}
