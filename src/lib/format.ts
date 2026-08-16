import type { Locale } from "@/lib/i18n";

const intlLocale = {
  en: "en-US",
  zh: "zh-CN"
} satisfies Record<Locale, string>;

export function formatMoney(cents: number, locale: Locale = "en") {
  return new Intl.NumberFormat(intlLocale[locale], {
    style: "currency",
    currency: "USD"
  }).format(cents / 100);
}

export function formatDate(value: Date | string | null | undefined, locale: Locale = "en") {
  if (!value) {
    return locale === "zh" ? "待定" : "TBD";
  }

  return new Intl.DateTimeFormat(intlLocale[locale], {
    month: "short",
    day: "numeric",
    year: "numeric"
  }).format(new Date(value));
}

export function formatDateTime(value: Date | string | null | undefined, locale: Locale = "en") {
  if (!value) {
    return locale === "zh" ? "待定" : "TBD";
  }

  return new Intl.DateTimeFormat(intlLocale[locale], {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit"
  }).format(new Date(value));
}

export function formatDateRange(start?: Date | string | null, end?: Date | string | null, locale: Locale = "en") {
  if (!start && !end) {
    return locale === "zh" ? "日期待定" : "Dates TBD";
  }

  if (start && end) {
    return `${formatDate(start, locale)} - ${formatDate(end, locale)}`;
  }

  return formatDate(start ?? end, locale);
}
