import { cookies, headers } from "next/headers";
import { dictionaries, normalizeLocale, type Locale } from "@/lib/i18n";

export async function getLocale(): Promise<Locale> {
  const cookieStore = await cookies();
  const cookieLocale = cookieStore.get("aaysa_locale")?.value;

  if (cookieLocale) {
    return normalizeLocale(cookieLocale);
  }

  const headerStore = await headers();
  const acceptLanguage = headerStore.get("accept-language") ?? "";

  return normalizeLocale(acceptLanguage.split(",")[0]?.split("-")[0]);
}

export async function getI18n() {
  const locale = await getLocale();

  return {
    locale,
    dictionary: dictionaries[locale]
  };
}
