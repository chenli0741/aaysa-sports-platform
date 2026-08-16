import type { Metadata } from "next";
import Link from "next/link";
import "./globals.css";

export const metadata: Metadata = {
  title: "AAYSA Sports",
  description: "Tournament operations platform for AAYSA Sports."
};

export default function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <div className="shell">
          <header className="topbar">
            <div className="topbar-inner">
              <Link className="brand" href="/">
                AAYSA Sports
              </Link>
              <nav className="nav" aria-label="Main navigation">
                <Link href="/tournaments">Tournaments</Link>
                <Link href="/my-games">My Games</Link>
                <Link href="/organizer">Organizer</Link>
                <Link href="/rules">Rules</Link>
              </nav>
            </div>
          </header>
          {children}
        </div>
      </body>
    </html>
  );
}
