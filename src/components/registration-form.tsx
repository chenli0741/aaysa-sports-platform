"use client";

import { useMemo, useState } from "react";
import { formatMoney } from "@/lib/format";
import { dictionaries, interpolate, labelStatus, type Locale } from "@/lib/i18n";
import { PAYMENT_FEE_CENTS, TEAM_PRICE_CENTS } from "@/lib/registration";

type DivisionOption = {
  id: string;
  name: string;
  minRoster: number;
  maxRoster: number;
  minBirthDate: string | null;
  maxBirthDate: string | null;
};

type RosterRow = {
  firstName: string;
  lastName: string;
  dob: string;
  guardianName: string;
  guardianEmail: string;
  waiverAccepted: boolean;
};

const emptyPlayer = (): RosterRow => ({
  firstName: "",
  lastName: "",
  dob: "",
  guardianName: "",
  guardianEmail: "",
  waiverAccepted: false
});

export function RegistrationForm({
  tournamentSlug,
  divisions,
  locale
}: {
  tournamentSlug: string;
  divisions: DivisionOption[];
  locale: Locale;
}) {
  const t = dictionaries[locale].registrationForm;
  const [managerName, setManagerName] = useState("");
  const [managerEmail, setManagerEmail] = useState("");
  const [managerPhone, setManagerPhone] = useState("");
  const [teamName, setTeamName] = useState("");
  const [clubName, setClubName] = useState("");
  const [divisionId, setDivisionId] = useState(divisions[0]?.id ?? "");
  const [promoCode, setPromoCode] = useState("");
  const [roster, setRoster] = useState<RosterRow[]>(Array.from({ length: 5 }, emptyPlayer));
  const [status, setStatus] = useState<"idle" | "submitting" | "submitted" | "error">("idle");
  const [message, setMessage] = useState("");

  const selectedDivision = useMemo(
    () => divisions.find((division) => division.id === divisionId),
    [divisionId, divisions]
  );

  function updatePlayer(index: number, patch: Partial<RosterRow>) {
    setRoster((current) =>
      current.map((player, playerIndex) => (playerIndex === index ? { ...player, ...patch } : player))
    );
  }

  async function submitRegistration(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("submitting");
    setMessage("");

    const response = await fetch("/api/registrations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        tournamentSlug,
        managerName,
        managerEmail,
        managerPhone,
        teamName,
        clubName,
        divisionId,
        promoCode,
        roster
      })
    });

    const result = (await response.json()) as {
      data?: { id: string; status: string; totalCents: number };
      error?: string;
    };

    if (!response.ok || !result.data) {
      setStatus("error");
      setMessage(result.error ?? t.submitError);
      return;
    }

    setStatus("submitted");
    setMessage(
      interpolate(t.submitSuccess, {
        id: result.data.id,
        status: labelStatus(result.data.status, locale),
        balance: formatMoney(result.data.totalCents, locale)
      })
    );
  }

  return (
    <form className="form-stack" onSubmit={submitRegistration}>
      <section className="form-section">
        <div>
          <span className="step-label">{t.step1}</span>
          <h2>{t.teamManager}</h2>
        </div>
        <div className="form-grid">
          <label>
            {t.name}
            <input value={managerName} onChange={(event) => setManagerName(event.target.value)} required />
          </label>
          <label>
            {t.email}
            <input type="email" value={managerEmail} onChange={(event) => setManagerEmail(event.target.value)} required />
          </label>
          <label>
            {t.phone}
            <input value={managerPhone} onChange={(event) => setManagerPhone(event.target.value)} />
          </label>
        </div>
      </section>

      <section className="form-section">
        <div>
          <span className="step-label">{t.step2}</span>
          <h2>{t.teamAndDivision}</h2>
        </div>
        <div className="form-grid">
          <label>
            {t.teamName}
            <input value={teamName} onChange={(event) => setTeamName(event.target.value)} required />
          </label>
          <label>
            {t.club}
            <input value={clubName} onChange={(event) => setClubName(event.target.value)} />
          </label>
          <label>
            {t.division}
            <select value={divisionId} onChange={(event) => setDivisionId(event.target.value)} required>
              {divisions.map((division) => (
                <option key={division.id} value={division.id}>
                  {division.name}
                </option>
              ))}
            </select>
          </label>
        </div>
        {selectedDivision ? (
          <p className="helper">
            {interpolate(t.rosterHint, {
              min: selectedDivision.minRoster,
              max: selectedDivision.maxRoster,
              start: selectedDivision.minBirthDate?.slice(0, 10) ?? t.openDate,
              end: selectedDivision.maxBirthDate?.slice(0, 10) ?? t.openDate
            })}
          </p>
        ) : null}
      </section>

      <section className="form-section">
        <div className="section-heading-row">
          <div>
            <span className="step-label">{t.steps34}</span>
            <h2>{t.rosterWaivers}</h2>
          </div>
          <button
            className="small-button"
            type="button"
            disabled={!selectedDivision || roster.length >= selectedDivision.maxRoster}
            onClick={() => setRoster((current) => [...current, emptyPlayer()])}
          >
            {t.addPlayer}
          </button>
        </div>

        <div className="roster-stack">
          {roster.map((player, index) => (
            <fieldset className="player-row" key={index}>
              <legend>{interpolate(t.player, { index: index + 1 })}</legend>
              <div className="form-grid">
                <label>
                  {t.firstName}
                  <input value={player.firstName} onChange={(event) => updatePlayer(index, { firstName: event.target.value })} required />
                </label>
                <label>
                  {t.lastName}
                  <input value={player.lastName} onChange={(event) => updatePlayer(index, { lastName: event.target.value })} required />
                </label>
                <label>
                  {t.dob}
                  <input type="date" value={player.dob} onChange={(event) => updatePlayer(index, { dob: event.target.value })} required />
                </label>
                <label>
                  {t.guardianName}
                  <input value={player.guardianName} onChange={(event) => updatePlayer(index, { guardianName: event.target.value })} />
                </label>
                <label>
                  {t.guardianEmail}
                  <input type="email" value={player.guardianEmail} onChange={(event) => updatePlayer(index, { guardianEmail: event.target.value })} />
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={player.waiverAccepted}
                    onChange={(event) => updatePlayer(index, { waiverAccepted: event.target.checked })}
                  />
                  {t.waiverAccepted}
                </label>
              </div>
              {roster.length > (selectedDivision?.minRoster ?? 5) ? (
                <button
                  className="text-button"
                  type="button"
                  onClick={() => setRoster((current) => current.filter((_, playerIndex) => playerIndex !== index))}
                >
                  {t.removePlayer}
                </button>
              ) : null}
            </fieldset>
          ))}
        </div>
      </section>

      <section className="form-section">
        <div>
          <span className="step-label">{t.steps56}</span>
          <h2>{t.reviewPayment}</h2>
        </div>
        <div className="summary-strip">
          <span>{interpolate(t.teamFee, { amount: formatMoney(TEAM_PRICE_CENTS, locale) })}</span>
          <span>{interpolate(t.processingFee, { amount: formatMoney(PAYMENT_FEE_CENTS, locale) })}</span>
          <span>{t.stripePending}</span>
        </div>
        <label>
          {t.promoCode}
          <input value={promoCode} onChange={(event) => setPromoCode(event.target.value.toUpperCase())} placeholder="AAYSA25" />
        </label>
      </section>

      {message ? <p className={`notice ${status === "error" ? "error" : ""}`}>{message}</p> : null}

      <button className="button submit-button" type="submit" disabled={status === "submitting"}>
        {status === "submitting" ? t.submitting : t.submit}
      </button>
    </form>
  );
}
