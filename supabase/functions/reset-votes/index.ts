import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const adminResetPassword = Deno.env.get("ADMIN_RESET_PASSWORD") ?? "";
const allowedOrigins = new Set(
  (Deno.env.get("ALLOWED_ORIGINS") ?? "https://dzarhi.github.io,http://localhost:8000")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean),
);

function corsHeaders(origin: string | null): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origin && allowedOrigins.has(origin) ? origin : "null",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function jsonResponse(
  origin: string | null,
  status: number,
  body: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
}

async function passwordMatches(provided: string, expected: string): Promise<boolean> {
  const encoder = new TextEncoder();
  const providedDigest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", encoder.encode(provided)),
  );
  const expectedDigest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", encoder.encode(expected)),
  );
  let difference = 0;
  for (let index = 0; index < providedDigest.length; index += 1) {
    difference |= providedDigest[index] ^ expectedDigest[index];
  }
  return difference === 0;
}

Deno.serve(async (request: Request): Promise<Response> => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders(origin) });
  }
  if (origin && !allowedOrigins.has(origin)) {
    return jsonResponse(origin, 403, { error: "Origin is not allowed." });
  }
  if (request.method !== "POST") {
    return jsonResponse(origin, 405, { error: "Use POST." });
  }
  if (!supabaseUrl || !serviceRoleKey || adminResetPassword.length < 32) {
    return jsonResponse(origin, 503, { error: "Admin reset is not configured." });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse(origin, 400, { error: "Invalid JSON body." });
  }
  if (
    typeof body !== "object" ||
    body === null ||
    Array.isArray(body) ||
    !("password" in body) ||
    typeof body.password !== "string" ||
    body.password.length < 32
  ) {
    return jsonResponse(origin, 403, { error: "סיסמת מנהל שגויה." });
  }
  if (!await passwordMatches(body.password, adminResetPassword)) {
    return jsonResponse(origin, 403, { error: "סיסמת מנהל שגויה." });
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, count, error } = await supabase
    .from("votes")
    .delete({ count: "exact" })
    .not("id", "is", null)
    .select("id");
  if (error) {
    return jsonResponse(origin, 500, { error: "Could not reset votes." });
  }

  return jsonResponse(origin, 200, { deletedCount: count ?? data?.length ?? 0 });
});
