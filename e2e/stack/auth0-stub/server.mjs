import { createServer } from "node:http";
import { generateKeyPairSync, randomUUID, sign } from "node:crypto";

const issuer = "https://auth0.ntppool.test/";
const clientId = process.env.auth0_client;
const clientSecret = process.env.auth0_secret;
if (!clientId || !clientSecret) throw new Error("Missing Auth0 fixture config");

const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
const kid = randomUUID();
const jwk = { ...publicKey.export({ format: "jwk" }), kid, alg: "RS256", use: "sig" };
const codes = new Map();

function json(response, status, body) {
  response.writeHead(status, { "content-type": "application/json" });
  response.end(JSON.stringify(body));
}

function encodeJson(value) {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function idToken(clientId) {
  const now = Math.floor(Date.now() / 1000);
  const header = encodeJson({ alg: "RS256", typ: "JWT", kid });
  const claims = encodeJson({
    iss: issuer,
    aud: clientId,
    sub: "auth0|ntppool-e2e-staff",
    name: "E2E Auth0 Staff",
    email: "auth0-staff@ntppool.test",
    email_verified: true,
    iat: now,
    exp: now + 60,
  });
  const body = `${header}.${claims}`;
  return `${body}.${sign("RSA-SHA256", Buffer.from(body), privateKey).toString("base64url")}`;
}

createServer(async (request, response) => {
  const url = new URL(request.url, issuer);
  if (request.method === "GET" && url.pathname === "/.well-known/jwks.json") {
    return json(response, 200, { keys: [jwk] });
  }
  if (request.method === "GET" && url.pathname === "/authorize") {
    const redirectUri = url.searchParams.get("redirect_uri");
    const state = url.searchParams.get("state");
    if (url.searchParams.get("client_id") !== clientId || !state || !redirectUri) {
      return json(response, 400, { error: "invalid_request" });
    }
    const destination = URL.parse(redirectUri);
    if (destination?.origin !== "https://manage.ntppool.test" || destination.pathname !== "/manage/login") {
      return json(response, 400, { error: "invalid_request" });
    }
    const code = randomUUID();
    codes.set(code, { redirectUri, clientId, state });
    setTimeout(() => codes.delete(code), 60_000).unref();
    destination.searchParams.set("code", code);
    destination.searchParams.set("state", state);
    response.writeHead(302, { location: destination.href });
    return response.end();
  }
  if (request.method === "POST" && url.pathname === "/oauth/token") {
    let body = "";
    for await (const chunk of request) body += chunk;
    const form = new URLSearchParams(body);
    const code = form.get("code");
    const record = codes.get(code);
    if (!record || form.get("grant_type") !== "authorization_code" ||
        form.get("redirect_uri") !== record.redirectUri ||
        form.get("client_id") !== record.clientId ||
        form.get("client_secret") !== clientSecret) {
      return json(response, 403, { error: "invalid_grant" });
    }
    codes.delete(code);
    return json(response, 200, { id_token: idToken(record.clientId) });
  }
  return json(response, 404, { error: "not_found" });
}).listen(8080);
