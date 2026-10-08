// Run with: node --test support/worker.test.mjs
import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, it } from 'node:test';

import worker from './worker.mjs';

const env = {
  VERIFY_CHECKOUT_API_KEY: 'vchk_test_not_a_real_key',
  SUPPORT_PAGE: 'https://daveragos.github.io/gramx/support.html',
  ALLOWED_ORIGIN: 'https://daveragos.github.io',
};

const WORKER = 'https://gramx-support.example.workers.dev';

let calls;
let replies;
const realFetch = globalThis.fetch;
const realLog = console.log;

beforeEach(() => {
  calls = [];
  replies = [];
  console.log = () => {};
  globalThis.fetch = async (url, init) => {
    calls.push({ url: String(url), ...init });
    const next = replies.shift();
    if (next instanceof Error) throw next;
    return new Response(JSON.stringify(next.body), {
      status: next.status,
      headers: { 'content-type': 'application/json', ...next.headers },
    });
  };
});

afterEach(() => {
  globalThis.fetch = realFetch;
  console.log = realLog;
});

const deposit = (status, extra = {}) => ({
  data: { id: 'dep_1', status, checkout_url: 'https://checkout.verify.et/c/tok', ...extra },
  meta: { requestId: 'req_1', apiVersion: '2026-06-01' },
});

const apiError = (code, retryable) => ({
  error: { code, message: 'x', type: 'x', retryable },
  meta: { requestId: 'req_err', apiVersion: '2026-06-01' },
});

const checkout = (origin = env.ALLOWED_ORIGIN) =>
  worker.fetch(new Request(`${WORKER}/checkout`, { method: 'POST', headers: { origin } }), env);

const back = (cookie) =>
  worker.fetch(new Request(`${WORKER}/return`, { headers: cookie ? { cookie } : {} }), env);

describe('starting a payment', () => {
  it('creates an open-amount deposit and sends the supporter to it', async () => {
    replies.push({ status: 201, body: deposit('awaiting_transfer') });

    const res = await checkout();

    assert.equal(res.status, 303);
    assert.equal(res.headers.get('location'), 'https://checkout.verify.et/c/tok');
    assert.match(res.headers.get('set-cookie'), /^gramx_deposit=dep_1; Path=\/return; Max-Age=7200; HttpOnly; Secure; SameSite=Lax$/);

    assert.equal(calls.length, 1);
    const [call] = calls;
    assert.equal(call.url, 'https://checkoutapi.verify.et/v1/deposits');
    assert.equal(call.method, 'POST');
    assert.equal(call.headers.Authorization, `Bearer ${env.VERIFY_CHECKOUT_API_KEY}`);
    assert.equal(call.headers['VerifyCheckout-Version'], '2026-06-01');
    assert.match(call.headers['Idempotency-Key'], /^support_[0-9a-f-]{36}$/);

    const body = JSON.parse(call.body);
    assert.deepEqual(Object.keys(body).sort(), ['merchant_customer_id', 'return_url']);
    assert.equal(body.return_url, `${WORKER}/return`);
    assert.equal(body.merchant_customer_id, call.headers['Idempotency-Key'].replace('support_', 'supporter_'));
  });

  it('retries an unclear answer with the same key and body', async () => {
    replies.push(new TypeError('network down'));
    replies.push({ status: 503, body: apiError('order_initiation_unavailable', true) });
    replies.push({ status: 200, body: deposit('awaiting_transfer') });

    const res = await checkout();

    assert.equal(res.headers.get('location'), 'https://checkout.verify.et/c/tok');
    assert.equal(calls.length, 3);
    assert.equal(new Set(calls.map((c) => c.headers['Idempotency-Key'])).size, 1);
    assert.equal(new Set(calls.map((c) => c.body)).size, 1);
  });

  it('does not retry a refusal, and tells the page support is unavailable', async () => {
    replies.push({ status: 402, body: apiError('insufficient_credits', false) });

    const res = await checkout();

    assert.equal(calls.length, 1);
    assert.equal(res.headers.get('location'), `${env.SUPPORT_PAGE}?state=unavailable`);
    assert.equal(res.headers.get('set-cookie'), null);
  });

  it('gives up after three unclear answers', async () => {
    for (let i = 0; i < 3; i++) replies.push({ status: 500, body: apiError('internal_server_error', true) });

    const res = await checkout();

    assert.equal(calls.length, 3);
    assert.equal(res.headers.get('location'), `${env.SUPPORT_PAGE}?state=unavailable`);
  });

  it('does not wait out a long rate limit while the supporter waits', async () => {
    replies.push({ status: 429, body: apiError('rate_limited', true), headers: { 'retry-after': '30' } });

    const res = await checkout();

    assert.equal(calls.length, 1);
    assert.equal(res.headers.get('location'), `${env.SUPPORT_PAGE}?state=unavailable`);
  });

  it('refuses requests that are not from the support page', async () => {
    const res = await checkout('https://elsewhere.example');

    assert.equal(res.status, 403);
    assert.equal(calls.length, 0);
  });

  it('does not log the key or the checkout link', async () => {
    const lines = [];
    console.log = (line) => lines.push(line);
    replies.push({ status: 201, body: deposit('awaiting_transfer') });

    await checkout();

    const logged = lines.join('\n');
    assert.ok(logged.includes('dep_1'));
    assert.ok(!logged.includes(env.VERIFY_CHECKOUT_API_KEY));
    assert.ok(!logged.includes('/c/tok'));
  });
});

describe('coming back', () => {
  it('reports a confirmed payment and forgets it', async () => {
    replies.push({ status: 200, body: deposit('succeeded') });

    const res = await back('other=1; gramx_deposit=dep_1');

    assert.equal(calls[0].url, 'https://checkoutapi.verify.et/v1/deposits/dep_1');
    assert.equal(calls[0].method, 'GET');
    assert.equal(calls[0].headers['Idempotency-Key'], undefined);
    assert.equal(res.headers.get('location'), `${env.SUPPORT_PAGE}?state=paid`);
    assert.match(res.headers.get('set-cookie'), /^gramx_deposit=; Path=\/return; Max-Age=0/);
  });

  it('keeps a payment that is still being verified', async () => {
    replies.push({ status: 200, body: deposit('verification_pending') });

    const res = await back('gramx_deposit=dep_1');

    assert.equal(res.headers.get('location'), `${env.SUPPORT_PAGE}?state=verifying`);
    assert.equal(res.headers.get('set-cookie'), null);
  });

  for (const [status, state] of [
    ['awaiting_transfer', 'waiting'],
    ['failed', 'failed'],
    ['cancelled', 'failed'],
    ['expired', 'expired'],
    ['review_required', 'review'],
    ['something_new', 'unknown'],
  ]) {
    it(`shows ${status} as ${state}`, async () => {
      replies.push({ status: 200, body: deposit(status) });
      const res = await back('gramx_deposit=dep_1');
      assert.equal(res.headers.get('location'), `${env.SUPPORT_PAGE}?state=${state}`);
    });
  }

  it('sends a visit with no payment to the support page', async () => {
    const res = await back();

    assert.equal(calls.length, 0);
    assert.equal(res.headers.get('location'), env.SUPPORT_PAGE);
  });

  it('says it could not check when the lookup fails', async () => {
    replies.push({ status: 404, body: apiError('resource_not_found', false) });

    const res = await back('gramx_deposit=dep_1');

    assert.equal(res.headers.get('location'), `${env.SUPPORT_PAGE}?state=unknown`);
  });

  it('ignores a garbled cookie', async () => {
    const res = await back('gramx_deposit=%E0%A4%A');

    assert.equal(calls.length, 0);
    assert.equal(res.headers.get('location'), env.SUPPORT_PAGE);
  });
});

describe('anything else', () => {
  it('goes to the support page', async () => {
    const res = await worker.fetch(new Request(`${WORKER}/`), env);
    assert.equal(res.status, 303);
    assert.equal(res.headers.get('location'), env.SUPPORT_PAGE);
  });

  it('does not start a payment from a GET', async () => {
    const res = await worker.fetch(new Request(`${WORKER}/checkout`), env);
    assert.equal(calls.length, 0);
    assert.equal(res.headers.get('location'), env.SUPPORT_PAGE);
  });
});
