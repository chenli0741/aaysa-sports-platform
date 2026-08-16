export function formatMoney(cents: number) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD"
  }).format(cents / 100);
}

export function formatDate(value: Date | string | null | undefined) {
  if (!value) {
    return "TBD";
  }

  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric"
  }).format(new Date(value));
}

export function formatDateTime(value: Date | string | null | undefined) {
  if (!value) {
    return "TBD";
  }

  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit"
  }).format(new Date(value));
}

export function formatDateRange(start?: Date | string | null, end?: Date | string | null) {
  if (!start && !end) {
    return "Dates TBD";
  }

  if (start && end) {
    return `${formatDate(start)} - ${formatDate(end)}`;
  }

  return formatDate(start ?? end);
}
