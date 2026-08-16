import type { Metadata } from "next";
import Link from "next/link";
import { LanguageSwitcher } from "@/components/language-switcher";
import { getI18n } from "@/lib/i18n-server";
import "./globals.css";

export const metadata: Metadata = {
  title: "AAYSA Sports",
  description: "Tournament operations platform for AAYSA Sports."
};

export default async function RootLayout({
  children
}: Readonly<{
  children: React.ReactNode;
}>) {
  const { locale, dictionary } = await getI18n();

  return (
    <html lang={locale === "zh" ? "zh-CN" : "en"}>
      <body>
        <div className="shell">
          <header className="topbar">
            <div className="topbar-inner">
              <Link className="brand" href="/">
                AAYSA Sports
              </Link>
              <nav className="nav" aria-label={dictionary.common.mainNavigation}>
                <Link href="/tournaments">{dictionary.nav.tournaments}</Link>
                <Link href="/my-games">{dictionary.nav.myGames}</Link>
                <Link href="/app/today">{dictionary.nav.today}</Link>
                <Link href="/organizer">{dictionary.nav.organizer}</Link>
                <Link href="/rules">{dictionary.nav.rules}</Link>
              </nav>
              <LanguageSwitcher locale={locale} />
            </div>
          </header>
          {children}
        </div>
      </body>
    </html>
  );
}
