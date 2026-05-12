import { NextRequest, NextResponse } from 'next/server';

const CLIENT_ID = process.env.GITHUB_CLIENT_ID ?? '';
const CLIENT_SECRET = process.env.GITHUB_CLIENT_SECRET ?? '';
const BASE_URL = process.env.NEXT_PUBLIC_URL ?? 'https://octrawallet.com';
const REDIRECT_URI = `${BASE_URL}/api/auth`;

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const code = searchParams.get('code');

  if (!code) {
    const params = new URLSearchParams({
      client_id: CLIENT_ID,
      redirect_uri: REDIRECT_URI,
      scope: 'repo,user',
    });
    return NextResponse.redirect(`https://github.com/login/oauth/authorize?${params}`);
  }

  const tokenRes = await fetch('https://github.com/login/oauth/access_token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    body: JSON.stringify({ client_id: CLIENT_ID, client_secret: CLIENT_SECRET, code }),
  });
  const data = await tokenRes.json() as { access_token?: string };
  const token = data.access_token;

  if (!token) {
    return new NextResponse('Authentication failed', { status: 400 });
  }

  const tokenJson = JSON.stringify({ token, provider: 'github' });
  const script = [
    '(function(){',
    'var d=' + JSON.stringify(tokenJson) + ';',
    'function h(e){window.opener.postMessage("authorization:github:success:"+d,e.origin);}',
    'window.addEventListener("message",h,false);',
    'window.opener.postMessage("authorizing:github","*");',
    '})();',
  ].join('');

  return new NextResponse(
    '<!DOCTYPE html><html><body><script>' + script + '<\/script></body></html>',
    { headers: { 'Content-Type': 'text/html' } }
  );
}
