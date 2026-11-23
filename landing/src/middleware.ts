import { NextResponse, type NextRequest } from "next/server";

// askpinda.com (no www) is mapped to this site too, so its HTTPS works.
// Send it to the www address, which is the one search engines index.
export function middleware(req: NextRequest) {
  const host = (req.headers.get("host") || "").toLowerCase().split(":")[0];
  if (host === "askpinda.com") {
    const url = new URL(req.nextUrl.pathname + req.nextUrl.search, "https://www.askpinda.com");
    return NextResponse.redirect(url, 308);
  }
  return NextResponse.next();
}

export const config = { matcher: "/:path*" };
