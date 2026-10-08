// The checkout behind the website's support page (docs/support.html).
//
// Verify Checkout creates each payment with a secret API key that can't sit
// in the app or on a static page, so this Cloudflare Worker holds it. The
// support page posts to /checkout, which starts a payment where the supporter
// picks the amount and sends them to Verify Checkout's hosted page. They pay
// RaGoose's own account there and enter the transfer reference; Verify
// Checkout confirms it and sends them to /return, which looks the payment up
// and hands the result back to the support page.
//
// Nothing is unlocked by a payment, so there is nothing to fulfill and no
// webhook. The worker keeps no state: the payment's id rides in a cookie on
// the supporter's own browser between /checkout and /return.

const API_VERSION = '2026-06-01';
const DEFAULT_API = 'https://checkoutapi.verify.et';

const COOKIE = 'gramx_deposit';
// Longer than a checkout's 60 minutes, so a slow verification still finds it.
const COOKIE_MAX_AGE = 2 * 60 * 60;

const TIMEOUT_MS = 10_000;
// A supporter is waiting on each request, so retries stay few and short.
const MAX_ATTEMPTS = 3;
const MAX_WAIT_MS = 4_000;

// What the support page shows for each deposit status. Anything not listed,
// such as a status added later, shows as unknown.
const STATES = {
  succeeded: 'paid',
  created: 'waiting',
  assigned: 'waiting',
  awaiting_transfer: 'waiting',
  reference_submitted: 'verifying',
  verification_pending: 'verifying',
  failed: 'failed',
  cancelled: 'failed',
  expired: 'expired',
  review_required: 'review',
};

// States that won't change again, so the cookie can go.
const FINAL = new Set(['paid', 'failed', 'expired']);

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/checkout' && request.method === 'POST') {
      return startCheckout(request, url, env);
    }
    if (url.pathname === '/return' && request.method === 'GET') {
      return finishCheckout(request, env);
    }
    return redirect(env.SUPPORT_PAGE);
  },
};

async function startCheckout(request, url, env) {
  // Only the support page starts payments. This keeps other sites, and link
  // previews that fetch whatever they're given, from creating them.
  if (request.headers.get('origin') !== env.ALLOWED_ORIGIN) {
    return new Response('Forbidden', { status: 403 });
  }
  if (!env.VERIFY_CHECKOUT_API_KEY) {
    log('checkout_failed', { code: 'missing_api_key' });
    return result(env, 'unavailable');
  }

  // Supporters are anonymous, so each visit is its own customer and attempt.
  // The key is reused for every retry below and nowhere else.
  const attempt = crypto.randomUUID();
  const res = await callApi(env, '/v1/deposits', {
    method: 'POST',
    idempotencyKey: `support_${attempt}`,
    body: {
      merchant_customer_id: `supporter_${attempt}`,
      return_url: `${url.origin}/return`,
    },
  });

  const deposit = res.body?.data;
  if ((res.status !== 200 && res.status !== 201) || !deposit?.checkout_url) {
    log('checkout_failed', { status: res.status, code: res.body?.error?.code, requestId: res.requestId });
    return result(env, 'unavailable');
  }

  log('checkout_started', { deposit: deposit.id, requestId: res.requestId });
  return redirect(deposit.checkout_url, {
    'Set-Cookie': cookie(deposit.id, COOKIE_MAX_AGE),
  });
}

async function finishCheckout(request, env) {
  // The way back proves nothing about the payment, so ask Verify Checkout.
  const id = readCookie(request, COOKIE);
  if (!id || !env.VERIFY_CHECKOUT_API_KEY) return redirect(env.SUPPORT_PAGE);

  const res = await callApi(env, `/v1/deposits/${encodeURIComponent(id)}`, { method: 'GET' });
  if (res.status !== 200 || !res.body?.data) {
    log('lookup_failed', { deposit: id, status: res.status, code: res.body?.error?.code, requestId: res.requestId });
    return result(env, 'unknown');
  }

  const status = res.body.data.status;
  const state = STATES[status] ?? 'unknown';
  log('checkout_returned', { deposit: id, status, requestId: res.requestId });
  return result(env, state, FINAL.has(state) ? { 'Set-Cookie': cookie('', 0) } : {});
}

/**
 * One Verify Checkout request, retried with the same idempotency key when the
 * answer is unclear: a timeout, a lost connection, a rate limit or a server
 * error. Returns `{status, body, requestId}`, with status 0 if no answer came.
 */
async function callApi(env, path, { method, idempotencyKey, body }) {
  const headers = {
    Authorization: `Bearer ${env.VERIFY_CHECKOUT_API_KEY}`,
    'VerifyCheckout-Version': API_VERSION,
    Accept: 'application/json',
  };
  if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey;
  if (body) headers['Content-Type'] = 'application/json';
  const payload = body ? JSON.stringify(body) : undefined;
  const target = new URL(path, env.VERIFY_CHECKOUT_BASE_URL || DEFAULT_API);

  let last = { status: 0, body: null, requestId: null };
  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    let response;
    try {
      response = await fetch(target, {
        method,
        headers,
        body: payload,
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch {
      last = { status: 0, body: null, requestId: null };
      if (attempt < MAX_ATTEMPTS) await sleep(backoff(attempt));
      continue;
    }

    const parsed = await response.json().catch(() => null);
    last = { status: response.status, body: parsed, requestId: parsed?.meta?.requestId ?? null };
    if (!shouldRetry(response.status, parsed) || attempt === MAX_ATTEMPTS) return last;

    const retryAfter = Number(response.headers.get('retry-after'));
    const wait = retryAfter > 0 ? retryAfter * 1000 : backoff(attempt);
    if (wait > MAX_WAIT_MS) return last;
    await sleep(wait);
  }
  return last;
}

function shouldRetry(status, body) {
  if (body?.error && typeof body.error.retryable === 'boolean') return body.error.retryable;
  return status === 429 || status >= 500;
}

function backoff(attempt) {
  return 250 * 2 ** (attempt - 1);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function result(env, state, headers = {}) {
  const page = new URL(env.SUPPORT_PAGE);
  page.searchParams.set('state', state);
  return redirect(page.href, headers);
}

function redirect(location, headers = {}) {
  return new Response(null, {
    status: 303,
    headers: { Location: location, 'Cache-Control': 'no-store', ...headers },
  });
}

function cookie(value, maxAge) {
  return `${COOKIE}=${encodeURIComponent(value)}; Path=/return; Max-Age=${maxAge}; HttpOnly; Secure; SameSite=Lax`;
}

function readCookie(request, name) {
  for (const part of (request.headers.get('cookie') ?? '').split(';')) {
    const [key, ...rest] = part.trim().split('=');
    if (key !== name) continue;
    try {
      return decodeURIComponent(rest.join('=')) || null;
    } catch {
      return null;
    }
  }
  return null;
}

// Ids, statuses and error codes only: never the key, the checkout link or
// anything about the supporter.
function log(event, fields) {
  console.log(JSON.stringify({ event, ...fields }));
}
