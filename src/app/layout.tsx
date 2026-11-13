import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: { default: "KalamAI — Latihan Berbicara Bahasa Arab", template: "%s | KalamAI" }, description: "Latih maharah kalam bersama tutor AI, pelajari koreksi bahasa Arab, dan tinjau perkembangan belajarmu.", applicationName: "KalamAI" };
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="id"><body>{children}</body></html>}
