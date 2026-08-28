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
