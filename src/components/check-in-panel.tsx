"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { formatDateTime } from "@/lib/format";
import { type Locale } from "@/lib/i18n";

type CheckIn = {
  id: string;
  checkedInAt: Date | string;
};

type RosterEntry = {
  id: string;
  firstName: string;
  lastName: string;
  waiverStatus: string;
  eligibilityStatus: string;
  checkIns: CheckIn[];
};

type Registration = {
  id: string;
  status: string;
  team: { name: string; club?: { name: string } | null } | null;
  checkIns: CheckIn[];
  rosterEntries: RosterEntry[];
};

const copy = {
  en: {
    checkedIn: "Checked in",
    notCheckedIn: "Not checked in",
    checkTeam: "Check in team",
    checkPlayer: "Check in",
    saved: "Check-in saved",
    failed: "Check-in failed",
    players: "Players"
  },
  zh: {
    checkedIn: "已签到",
    notCheckedIn: "未签到",
    checkTeam: "队伍签到",
    checkPlayer: "签到",
    saved: "签到已保存",
    failed: "签到失败",
    players: "球员"
  }
} satisfies Record<Locale, Record<string, string>>;

export function CheckInPanel({
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

  async function checkIn(key: string, url: string) {
    setBusyKey(key);
    setMessage("");

    const response = await fetch(url, { method: "POST" });

    setBusyKey(null);
    setMessage(response.ok ? t.saved : t.failed);

    if (response.ok) {
      router.refresh();
    }
  }

  return (
    <section className="list-stack">
      {message ? <p className={`notice ${message === t.failed ? "error" : ""}`}>{message}</p> : null}
      {registrations.map((registration) => {
        const teamCheckIn = registration.checkIns[0];

        return (
          <article className="operations-card" key={registration.id}>
            <div className="operations-heading">
              <div>
                <span className={`status-pill ${teamCheckIn ? "ready" : "not-ready"}`}>
                  {teamCheckIn ? t.checkedIn : t.notCheckedIn}
                </span>
                <h2>{registration.team?.name ?? registration.id}</h2>
                <p>
                  {teamCheckIn ? formatDateTime(teamCheckIn.checkedInAt, locale) : registration.status.replaceAll("_", " ")}
                </p>
              </div>
              <button
                className="button secondary"
                type="button"
                disabled={busyKey !== null || Boolean(teamCheckIn)}
                onClick={() => checkIn(`team:${registration.id}`, `/api/registrations/${registration.id}/check-in`)}
              >
                {busyKey === `team:${registration.id}` ? "..." : t.checkTeam}
              </button>
            </div>

            <div className="mini-list">
              <h3>{t.players}</h3>
              {registration.rosterEntries.map((entry) => {
                const playerCheckIn = entry.checkIns[0];

                return (
                  <div className="mini-row" key={entry.id}>
                    <span>
                      {entry.firstName} {entry.lastName}
                      <small>{playerCheckIn ? formatDateTime(playerCheckIn.checkedInAt, locale) : t.notCheckedIn}</small>
                    </span>
                    <button
                      className="small-button secondary-action"
                      type="button"
                      disabled={busyKey !== null || Boolean(playerCheckIn)}
                      onClick={() => checkIn(`player:${entry.id}`, `/api/roster-entries/${entry.id}/check-in`)}
                    >
                      {busyKey === `player:${entry.id}` ? "..." : t.checkPlayer}
                    </button>
                  </div>
                );
              })}
            </div>
          </article>
        );
      })}
    </section>
  );
}
