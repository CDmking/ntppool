import { createHash, randomUUID } from "node:crypto";
import { readFile } from "node:fs/promises";
import { test, expect, type Page } from "@playwright/test";
import { Client } from "pg";
import { connectRpc, loginAs, uniqueTestEmail } from "../lib/auth";

const authorize = "/manage/oauth/authorize";
const apps = "/manage/oauth/apps";
const auth0 = "https://auth0.ntppool.test";
const clientName = "Connector <A>";
const callback = "https://connector.ntppool.test/callback?existing=value";
const callbackUrl = new URL(callback);
const consentHeading = `Connect ${clientName} to NTP Pool?`;
const challenge = createHash("sha256").update("a".repeat(43)).digest("base64url");

function authQuery(
  state: string = randomUUID(),
  redirectUri = callback,
): string {
  return new URLSearchParams({
    client_id: "e2e-connector",
    redirect_uri: redirectUri,
    response_type: "code",
    resource: "https://mcp.ntppool.test/mcp",
    scope: "staff:read",
    code_challenge_method: "S256",
    code_challenge: challenge,
    state,
  }).toString();
}

async function signInThroughStub(page: Page): Promise<string> {
  const [authorizeRequest] = await Promise.all([
    page.waitForRequest((request) => request.url().startsWith(`${auth0}/authorize?`)),
    page.getByRole("link", { name: "Sign in or create account" }).click(),
  ]);
  // The stub issues an ID token only when the token request uses the exact
  // redirect_uri it recorded here. A signed-in page proves the exchange agreed.
  return new URL(authorizeRequest.url()).searchParams.get("redirect_uri")!;
}

async function submitConsent(page: Page, name: string) {
  const [response] = await Promise.all([
    page.waitForResponse((response) =>
      new URL(response.url()).pathname === authorize && response.request().method() === "POST",
    ),
    page.getByRole("button", { name, exact: true }).click(),
  ]);
  expect(response.status()).toBe(303);
  const location = new URL((await response.headerValue("location"))!);
  expect(`${location.origin}${location.pathname}`).toBe(`${callbackUrl.origin}${callbackUrl.pathname}`);
  expect(location.searchParams.get("existing")).toBe("value");
  expect(location.searchParams.get("iss")).toBe("https://api.ntppool.test");
  await expect(page).toHaveURL(location.href);
  await expect(page.getByText("Connector callback")).toBeVisible();
  return { location, traceId: (await response.headerValue("traceid"))! };
}

interface TraceBatch {
  resourceSpans?: { scopeSpans?: { spans?: {
    traceId: string;
    attributes?: { key: string; value: { stringValue?: string } }[];
  }[] }[] }[];
}

function containsTraceSpan(traces: string, traceId: string, attribute: string, expected: string): boolean {
  // The final line may still be in the middle of a write.
  return traces.split("\n").slice(0, -1).some((line) => {
    if (!line.includes(traceId)) return false;
    const { resourceSpans }: TraceBatch = JSON.parse(line);
    return resourceSpans?.some(({ scopeSpans }) => scopeSpans?.some(({ spans }) =>
      spans?.some((span) => span.traceId === traceId && span.attributes?.some(
        ({ key, value }) =>
          key === attribute && value.stringValue === expected,
      )),
    ));
  });
}

test.describe("connector OAuth", () => {
  test.skip(process.env.E2E_CONNECTOR !== "1", "Requires the Compose connector fixtures");

  test("signed-out staff member returns to consent after login", async ({ page }) => {
    const analyticsRequests: string[] = [];
    await page.addInitScript(() => Reflect.set(window, "__plausible", true));
    await page.route("**/api/event", async (route) => {
      analyticsRequests.push(route.request().url());
      await route.fulfill({ status: 204 });
    });

    // Keep literal percent encodings and a plus sign to catch re-encoding.
    const query = authQuery(`${randomUUID()} a+b&c`).replace("%2B", "%2b");
    await page.goto(`${authorize}?${query}`);
    const redirectUri = await signInThroughStub(page);
    expect(new URL(redirectUri).searchParams.get("r")).toBe(`${authorize}?${query}`);
    await expect(page.getByRole("heading", { name: consentHeading })).toBeVisible();
    await expect(page.locator('input[name="query"]')).toHaveValue(query);
    await page.waitForLoadState("load");
    expect(analyticsRequests).toEqual([]);
  });

  test("login from another page returns there", async ({ page }) => {
    // This is the account token linked to the Auth0 stub's staff identity.
    const target = "/manage/servers?a=2zrqgk7";
    await page.goto(target);
    const redirectUri = await signInThroughStub(page);
    expect(new URL(redirectUri).searchParams.get("r")).toBe(target);
    await expect(page).toHaveURL((url) => `${url.pathname}${url.search}` === target);
    await expect(page.getByRole("link", { name: /Logout.*auth0-staff@ntppool\.test/ }).filter({ visible: true })).toBeVisible();
  });

  test("repeated parameter shows an error", async ({ page, context }) => {
    await loginAs(context, uniqueTestEmail("oauth-staff"), { grantStaff: true });
    const response = await page.goto(`${authorize}?${authQuery()}&state=second`);
    expect(response?.status()).toBe(400);
    expect(response?.request().redirectedFrom()).toBeNull();
    expect(await response?.headerValue("location")).toBeNull();
    await expect(page.getByRole("alert").filter({ hasText: "This connector authorization request is invalid." })).toBeVisible();
  });

  test("approve redirects to the client with a code", async ({ page, context }) => {
    const state = randomUUID();
    await loginAs(context, uniqueTestEmail("oauth-staff"), { grantStaff: true });
    const consent = await page.goto(`${authorize}?${authQuery(state)}`);
    const consentTraceId = (await consent?.headerValue("traceid"))!;
    const { location, traceId } = await submitConsent(page, "Allow staff lookups");
    const code = location.searchParams.get("code");
    expect(code).toBeTruthy();
    expect(location.searchParams.get("state") === state, "callback preserves state").toBe(true);
    expect(traceId).toMatch(/^[0-9a-f]{32}$/);

    const tracesPath = "test-logs/traces.json";
    await expect.poll(async () => {
      const traces = await readFile(tracesPath, "utf8");
      // Wait for both requests to be exported before checking for secrets.
      return containsTraceSpan(traces, consentTraceId, "url.path", authorize)
        && containsTraceSpan(traces, traceId, "redirect.url", `${callbackUrl.origin}${callbackUrl.pathname}`);
    }, { timeout: 20_000 }).toBe(true);
    const webLogPath = "test-logs/connector-web.log";
    await expect.poll(async () => {
      const lines = (await readFile(webLogPath, "utf8")).split("\n");
      return lines.some((line) => line.includes(`"GET ${authorize} HTTP/`)
        && line.includes(`trace_id=${consentTraceId}`))
        && lines.some((line) => line.includes(`"POST ${authorize} HTTP/`)
          && line.includes(' 303 ') && line.includes(`trace_id=${traceId}`));
    }).toBe(true);
    for (const path of [tracesPath, "test-logs/connector-api.log", webLogPath]) {
      const log = await readFile(path, "utf8");
      expect(log.length, `${path} has output`).toBeGreaterThan(0);
      expect(log.includes(code!), `${path} omits the authorization code`).toBe(false);
      expect(log.includes(state), `${path} omits the client state`).toBe(false);
    }
  });

  test("cancel returns access_denied", async ({ page, context }) => {
    await loginAs(context, uniqueTestEmail("oauth-staff"), { grantStaff: true });
    await page.goto(`${authorize}?${authQuery()}`);
    const { location } = await submitConsent(page, "Cancel");
    expect(location.searchParams.get("error")).toBe("access_denied");
    expect(location.searchParams.has("code")).toBe(false);
  });

  test("unknown redirect URI shows an error and does not redirect", async ({ page, context }) => {
    await loginAs(context, uniqueTestEmail("oauth-staff"), { grantStaff: true });
    const response = await page.goto(`${authorize}?${authQuery("unknown-redirect", "https://unknown.ntppool.test/callback")}`);
    expect(response?.status()).toBe(400);
    expect(response?.request().redirectedFrom()).toBeNull();
    expect(await response?.headerValue("location")).toBeNull();
    await expect(page.getByRole("alert").filter({ hasText: "This connector authorization request is invalid." })).toBeVisible();
  });

  test("non-staff user can only return access_denied", async ({ page, context }) => {
    await loginAs(context, uniqueTestEmail("oauth-nonstaff"));
    const response = await page.goto(`${authorize}?${authQuery()}`);
    expect(response?.status()).toBe(403);
    await expect(page.getByText("Connector approval requires an active staff account.")).toBeVisible();
    await expect(page.getByRole("link", { name: "Connected apps", exact: true })).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Allow staff lookups" })).toHaveCount(0);
    const { location } = await submitConsent(page, `Return to ${clientName}`);
    expect(location.searchParams.get("error")).toBe("access_denied");
    expect(location.searchParams.has("code")).toBe(false);
  });

  test("consent submitted after the session ends asks to log in again", async ({ page, context }) => {
    await loginAs(context, uniqueTestEmail("oauth-staff"), { grantStaff: true });
    const query = authQuery();
    await page.goto(`${authorize}?${query}`);
    await context.clearCookies();
    const [response] = await Promise.all([
      page.waitForResponse((response) =>
        new URL(response.url()).pathname === authorize && response.request().method() === "POST",
      ),
      page.getByRole("button", { name: "Allow staff lookups", exact: true }).click(),
    ]);
    expect(response.status()).toBe(303);
    expect(await response.headerValue("location")).toBe(`${authorize}?${query}`);
    const redirectUri = await signInThroughStub(page);
    expect(new URL(redirectUri).searchParams.get("r")).toBe(`${authorize}?${query}`);
    await expect(page.getByRole("heading", { name: consentHeading })).toBeVisible();
  });

  test("consent POST without auth_token is refused", async ({ page, context }) => {
    await loginAs(context, uniqueTestEmail("oauth-staff"), { grantStaff: true });
    const response = await page.request.post(authorize, {
      form: { query: authQuery(), decision: "approve" },
      maxRedirects: 0,
    });
    expect(response.status()).toBe(403);
  });

  test("connected apps lists and revokes a grant after staff privilege is removed", async ({ page, context }) => {
    const { email, sessionToken } = await loginAs(context, uniqueTestEmail("oauth-staff"), { grantStaff: true });
    await page.goto(`${authorize}?${authQuery()}`);
    await submitConsent(page, "Allow staff lookups");

    const db = new Client({ connectionString: process.env.DATABASE_URI });
    await db.connect();
    try {
      const result = await db.query(
        `UPDATE user_privileges SET support_staff = false
         FROM users WHERE user_privileges.user_id = users.id AND users.email = $1`,
        [email],
      );
      expect(result.rowCount).toBe(1);
    } finally {
      await db.end();
    }

    await page.goto(apps);
    await expect(page.getByRole("heading", { name: "Connected apps" })).toBeVisible();
    await expect(page.getByText(clientName, { exact: true })).toBeVisible();
    await page.getByRole("button", { name: "Revoke", exact: true }).click();
    await expect(page).toHaveURL((url) => url.pathname === apps);
    await expect(page.getByRole("row").filter({ hasText: clientName })).toContainText("Revoked");
    await expect(page.getByRole("button", { name: "Revoke", exact: true })).toHaveCount(0);

    const result = await connectRpc<{ grants: { revoked?: boolean }[] }>(
      "ListGrants", "ntppool.connector.v1.ConnectorService/ListGrants",
      { Authorization: `Bearer ${sessionToken}` }, {},
    );
    expect(result.grants).toEqual([expect.objectContaining({ revoked: true })]);
  });

  test("consent page refuses framing", async ({ page, context }) => {
    await loginAs(context, uniqueTestEmail("oauth-staff"), { grantStaff: true });
    const response = await page.goto(`${authorize}?${authQuery()}`);
    await expect(page.getByRole("heading", { name: consentHeading })).toBeVisible();
    const frameOptions = await response?.headerValue("x-frame-options");
    const csp = await response?.headerValue("content-security-policy");
    expect(frameOptions?.toLowerCase() === "deny" || /(?:^|;\s*)frame-ancestors 'none'(?:;|$)/.test(csp ?? "")).toBe(true);
  });
});
