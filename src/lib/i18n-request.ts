import type { NextRequest } from "next/server";
import { dictionaries, normalizeLocale } from "@/lib/i18n";

export function getRequestI18n(request: NextRequest) {
  const cookieLocale = request.cookies.get("aaysa_locale")?.value;
  const headerLocale = request.headers.get("accept-language")?.split(",")[0]?.split("-")[0];
  const locale = normalizeLocale(cookieLocale ?? headerLocale);

  return {
    locale,
    dictionary: dictionaries[locale]
  };
}
