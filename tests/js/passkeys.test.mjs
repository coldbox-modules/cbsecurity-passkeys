import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(
	new URL("../../resources/assets/js/passkeys.js", import.meta.url),
	"utf8",
);
const context = vm.createContext({ window: {} });
vm.runInContext(source, context);

test("accepts an already parsed JSON response", async () => {
	const options = { publicKey: { challenge: "challenge" } };
	const parsed = await context.parseJSONResponse({ json: async () => options });

	assert.deepEqual(parsed, options);
});

test("accepts a JSON-encoded string response", async () => {
	const options = { publicKey: { challenge: "challenge" } };
	const parsed = await context.parseJSONResponse({ json: async () => JSON.stringify(options) });

	assert.deepEqual(JSON.stringify(parsed), JSON.stringify(options));
});

function deferred() {
	let resolve;
	const promise = new Promise(done => { resolve = done; });
	return { promise, resolve };
}

function clientHarness() {
	const calls = [];
	const options = { publicKey: { challenge: "AQID" } };
	const credential = { id: "credential", type: "public-key" };
	const runtime = vm.createContext({
		window: {}, URLSearchParams,
		fetch: async (url, init) => {
			calls.push({ stage: url.includes("/new?") ? "options" : "authentication", url, init });
			return { ok: true, json: async () => options };
		},
		webauthnJSON: { get: async init => {
			calls.push({ stage: "credential", init });
			return credential;
		} },
	});
	vm.runInContext(source, runtime);
	const client = runtime.window.cbSecurity.passkeys;
	client.supported = true;
	return { runtime, client, calls };
}

test("existing autocomplete calls retain defaults, parameters, payload, and redirect", async () => {
	for (const args of [[], ["/account"], ["/account", { rememberMe: "true" }]]) {
		const { runtime, client, calls } = clientHarness();
		await client.autocomplete(...args);
		assert.equal(runtime.window.location, args[0] ?? "/");
		assert.equal(calls.length, 3);
		assert.equal(calls[0].init, undefined);
		assert.equal(new URL(calls[0].url, "https://example.com").searchParams.get("rememberMe"), args[1]?.rememberMe ?? null);
		assert.equal(calls[1].init.mediation, "conditional");
		assert.equal("signal" in calls[1].init, false);
		assert.equal("signal" in calls[2].init, false);
		assert.deepEqual(JSON.parse(calls[2].init.body), {
			...args[1], publicKeyCredentialJson: JSON.stringify({ id: "credential", type: "public-key" }),
		});
	}
});

test("passes an optional signal through both fetches and WebAuthn", async () => {
	const { client, calls, runtime } = clientHarness();
	const controller = new AbortController();
	await client.autocomplete("/account", { siteAdmin: "true" }, controller.signal);
	for (const call of calls) {
		assert.equal(call.init.signal, controller.signal);
	}
	assert.equal(runtime.window.location, "/account");
});

test("a pre-aborted flow never starts support detection or network requests", async () => {
	const { client, calls } = clientHarness();
	client.isSupported = () => { throw new Error("Support detection must not run"); };
	const controller = new AbortController();
	controller.abort();
	await assert.rejects(client.autocomplete("/account", {}, controller.signal), { name: "AbortError" });
	assert.equal(calls.length, 0);
});

for (const stage of ["support", "options", "credential", "authentication"]) {
	test(`cancellation during ${stage} prevents subsequent stages and redirect`, async () => {
		const { runtime, client, calls } = clientHarness();
		const controller = new AbortController();
		const entered = deferred();
		const released = deferred();
		if (stage === "support") {
			client.isSupported = async () => { entered.resolve(); await released.promise; return true; };
		} else if (stage === "credential") {
			runtime.webauthnJSON.get = async init => {
				calls.push({ stage, init }); entered.resolve(); await released.promise;
				return { id: "credential" };
			};
		} else {
			const fetch = runtime.fetch;
			runtime.fetch = async (url, init) => {
				const response = await fetch(url, init);
				if (calls.at(-1).stage === stage) {
					entered.resolve(); await released.promise;
				}
				return response;
			};
		}
		const result = client.autocomplete("/account", {}, controller.signal);
		const rejected = assert.rejects(result, { name: "AbortError" });
		await entered.promise;
		controller.abort();
		released.resolve();
		await rejected;
		assert.equal(calls.length, ["support", "options", "credential", "authentication"].indexOf(stage));
		// The current stage may already have started; only subsequent work is forbidden.
		assert.equal(runtime.window.location, undefined);
	});
}

test("the shipped browser bundle forwards cancellation to navigator.credentials.get", async () => {
	const entered = deferred();
	const controller = new AbortController();
	let requests = 0;
	const runtime = vm.createContext({
		window: {}, URLSearchParams, atob, btoa, ArrayBuffer, Uint8Array,
		fetch: async () => {
			requests++;
			return { json: async () => ({ publicKey: { challenge: "AQID" } }) };
		},
		navigator: { credentials: { get: options => {
			assert.equal(options.signal, controller.signal);
			assert.equal(options.mediation, "conditional");
			assert.deepEqual([...new Uint8Array(options.publicKey.challenge)], [1, 2, 3]);
			entered.resolve();
			return new Promise((_resolve, reject) => {
				options.signal.addEventListener("abort", () => reject(options.signal.reason), { once: true });
			});
		} } },
	});
	vm.runInContext(readFileSync(new URL("../../includes/passkeys.js", import.meta.url), "utf8"), runtime);
	const client = runtime.window.cbSecurity.passkeys;
	client.supported = true;
	const result = client.autocomplete("/account", {}, controller.signal);
	const rejected = assert.rejects(result, { name: "AbortError" });
	await entered.promise;
	controller.abort();
	await rejected;
	assert.equal(requests, 1);
	assert.equal(runtime.window.location, undefined);
});
