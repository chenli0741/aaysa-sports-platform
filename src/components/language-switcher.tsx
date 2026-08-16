"use client";

import { useRouter } from "next/navigation";
import { dictionaries, type Locale } from "@/lib/i18n";

export function LanguageSwitcher({ locale }: { locale: Locale }) {
  const router = useRouter();

  function setLocale(nextLocale: Locale) {
    document.cookie = `aaysa_locale=${nextLocale}; path=/; max-age=31536000; SameSite=Lax`;
    router.refresh();
  }

  return (
    <div className="language-switcher" aria-label={locale === "zh" ? "语言" : "Language"}>
      {(["en", "zh"] as const).map((item) => (
        <button
          aria-pressed={locale === item}
          className={locale === item ? "active" : ""}
          key={item}
          onClick={() => setLocale(item)}
          type="button"
        >
          {dictionaries[item].languageName}
        </button>
      ))}
    </div>
  );
}
