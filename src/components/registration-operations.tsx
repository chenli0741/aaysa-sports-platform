"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { formatMoney } from "@/lib/format";
import { labelStatus, type Locale } from "@/lib/i18n";

type Payment = {
  id: string;
  status: string;
  amountCents: number;
};

type RosterEntry = {
  id: string;
  firstName: string;
  lastName: string;
  waiverStatus: string;
  eligibilityStatus: string;
};

type Registration = {
  id: string;
  status: string;
  totalCents: number;
  team: { name: string; club?: { name: string } | null } | null;
  division: { name: string };
  rosterEntries: RosterEntry[];
  payments: Payment[];
};

const copy = {
  en: {
    title: "Organizer actions",
    payment: "Payment",
    roster: "Roster follow-up",
    current: "Current",
    markReceived: "Mark paid",
    markComped: "Comp",
    markFailed: "Mark failed",
    signWaiver: "Mark waiver signed",
    saved: "Saved",
    failed: "Action failed",
    noFollowUp: "No waiver follow-up needed."
  },
  zh: {
    title: "组织者操作",
    payment: "付款",
    roster: "名单跟进",
    current: "当前",
    markReceived: "标记已付款",
    markComped: "减免",
    markFailed: "标记失败",
    signWaiver: "标记免责声明已签",
    saved: "已保存",
    failed: "操作失败",
    noFollowUp: "暂无免责声明跟进。"
  }
} satisfies Record<Locale, Record<string, string>>;

export function RegistrationOperations({
  registrations,
  locale
}: {
  registrations: Registration[];
  locale: Locale;
}) {
  const router = useRouter();
  const t = copy[locale];
  const [busyKey, setBusyKey] = useState<string | null>(null);
  const [message, setMessage] = useState("");

  async function run(key: string, url: string, body: Record<string, unknown> = {}) {
    setBusyKey(key);
    setMessage("");

    const response = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body)
    });

    setBusyKey(null);
    setMessage(response.ok ? t.saved : t.failed);

    if (response.ok) {
      router.refresh();
    }
  }

  if (registrations.length === 0) {
    return null;
  }

  return (
    <section className="list-stack" aria-label={t.title}>
      {message ? <p className={`notice ${message === t.failed ? "error" : ""}`}>{message}</p> : null}
      {registrations.map((registration) => {
        const latestPayment = registration.payments[0];
        const missingWaivers = registration.rosterEntries.filter((entry) => entry.waiverStatus !== "SIGNED");

        return (
          <article className="operations-card" key={registration.id}>
            <div className="operations-heading">
              <div>
                <span className="step-label">{registration.division.name}</span>
                <h2>{registration.team?.name ?? registration.id}</h2>
                <p>
                  {labelStatus(registration.status, locale)} · {formatMoney(registration.totalCents, locale)}
                </p>
              </div>
              <span className="status-pill">
                {t.current}: {latestPayment ? labelStatus(latestPayment.status, locale) : "-"}
              </span>
            </div>

            <div className="operation-panel">
              <div>
                <h3>{t.payment}</h3>
                <div className="actions">
                  <button
                    className="small-button"
                    type="button"
                    disabled={busyKey !== null}
                    onClick={() =>
                      run(`${registration.id}:received`, `/api/registrations/${registration.id}/payment`, {
                        action: "received"
                      })
                    }
                  >
                    {busyKey === `${registration.id}:received` ? "..." : t.markReceived}
                  </button>
                  <button
                    className="small-button secondary-action"
                    type="button"
                    disabled={busyKey !== null}
                    onClick={() =>
                      run(`${registration.id}:comp`, `/api/registrations/${registration.id}/payment`, {
                        action: "comp"
                      })
                    }
                  >
                    {busyKey === `${registration.id}:comp` ? "..." : t.markComped}
                  </button>
                  <button
                    className="small-button warning-action"
                    type="button"
                    disabled={busyKey !== null}
                    onClick={() =>
                      run(`${registration.id}:failed`, `/api/registrations/${registration.id}/payment`, {
                        action: "failed"
                      })
                    }
                  >
                    {busyKey === `${registration.id}:failed` ? "..." : t.markFailed}
                  </button>
                </div>
              </div>

              <div>
                <h3>{t.roster}</h3>
                {missingWaivers.length === 0 ? <p className="helper">{t.noFollowUp}</p> : null}
                <div className="mini-list">
                  {missingWaivers.map((entry) => (
                    <div className="mini-row" key={entry.id}>
                      <span>
                        {entry.firstName} {entry.lastName}
                      </span>
                      <button
                        className="small-button secondary-action"
                        type="button"
                        disabled={busyKey !== null}
                        onClick={() => run(`waiver:${entry.id}`, `/api/roster-entries/${entry.id}/waiver`)}
                      >
                        {busyKey === `waiver:${entry.id}` ? "..." : t.signWaiver}
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </article>
        );
      })}
    </section>
  );
}
