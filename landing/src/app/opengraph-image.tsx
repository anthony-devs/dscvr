import { ImageResponse } from "next/og";
import { HomeCard, OG_SIZE, ogFonts } from "@/lib/og";

export const alt = "DSCVR: twelve tabs, lost PDFs and made-up citations, answered.";
export const size = OG_SIZE;
export const contentType = "image/png";

export default function OgImage() {
  return new ImageResponse(<HomeCard footer="askpinda.com" />, { ...OG_SIZE, fonts: ogFonts() });
}
