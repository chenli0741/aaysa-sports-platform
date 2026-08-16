"use client";

import { useMemo, useState } from "react";
import { formatMoney } from "@/lib/format";
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
  divisions
}: {
  tournamentSlug: string;
  divisions: DivisionOption[];
}) {
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
      setMessage(result.error ?? "Registration could not be submitted.");
      return;
    }

    setStatus("submitted");
    setMessage(
      `Registration ${result.data.id} created. Status: ${result.data.status}. Balance: ${formatMoney(result.data.totalCents)}.`
    );
  }

  return (
    <form className="form-stack" onSubmit={submitRegistration}>
      <section className="form-section">
        <div>
          <span className="step-label">Step 1</span>
          <h2>Team manager</h2>
        </div>
        <div className="form-grid">
          <label>
            Name
            <input value={managerName} onChange={(event) => setManagerName(event.target.value)} required />
          </label>
          <label>
            Email
            <input type="email" value={managerEmail} onChange={(event) => setManagerEmail(event.target.value)} required />
          </label>
          <label>
            Phone
            <input value={managerPhone} onChange={(event) => setManagerPhone(event.target.value)} />
          </label>
        </div>
      </section>

      <section className="form-section">
        <div>
          <span className="step-label">Step 2</span>
          <h2>Team and division</h2>
        </div>
        <div className="form-grid">
          <label>
            Team name
            <input value={teamName} onChange={(event) => setTeamName(event.target.value)} required />
          </label>
          <label>
            Club or organization
            <input value={clubName} onChange={(event) => setClubName(event.target.value)} />
          </label>
          <label>
            Division
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
            Roster {selectedDivision.minRoster}-{selectedDivision.maxRoster} players. DOB range{" "}
            {selectedDivision.minBirthDate?.slice(0, 10) ?? "open"} to{" "}
            {selectedDivision.maxBirthDate?.slice(0, 10) ?? "open"}.
          </p>
        ) : null}
      </section>

      <section className="form-section">
        <div className="section-heading-row">
          <div>
            <span className="step-label">Steps 3-4</span>
            <h2>Roster and waivers</h2>
          </div>
          <button
            className="small-button"
            type="button"
            disabled={!selectedDivision || roster.length >= selectedDivision.maxRoster}
            onClick={() => setRoster((current) => [...current, emptyPlayer()])}
          >
            Add player
          </button>
        </div>

        <div className="roster-stack">
          {roster.map((player, index) => (
            <fieldset className="player-row" key={index}>
              <legend>Player {index + 1}</legend>
              <div className="form-grid">
                <label>
                  First name
                  <input value={player.firstName} onChange={(event) => updatePlayer(index, { firstName: event.target.value })} required />
                </label>
                <label>
                  Last name
                  <input value={player.lastName} onChange={(event) => updatePlayer(index, { lastName: event.target.value })} required />
                </label>
                <label>
                  Date of birth
                  <input type="date" value={player.dob} onChange={(event) => updatePlayer(index, { dob: event.target.value })} required />
                </label>
                <label>
                  Guardian name
                  <input value={player.guardianName} onChange={(event) => updatePlayer(index, { guardianName: event.target.value })} />
                </label>
                <label>
                  Guardian email
                  <input type="email" value={player.guardianEmail} onChange={(event) => updatePlayer(index, { guardianEmail: event.target.value })} />
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={player.waiverAccepted}
                    onChange={(event) => updatePlayer(index, { waiverAccepted: event.target.checked })}
                  />
                  Guardian waiver accepted
                </label>
              </div>
              {roster.length > (selectedDivision?.minRoster ?? 5) ? (
                <button
                  className="text-button"
                  type="button"
                  onClick={() => setRoster((current) => current.filter((_, playerIndex) => playerIndex !== index))}
                >
                  Remove player
                </button>
              ) : null}
            </fieldset>
          ))}
        </div>
      </section>

      <section className="form-section">
        <div>
          <span className="step-label">Steps 5-6</span>
          <h2>Review and payment</h2>
        </div>
        <div className="summary-strip">
          <span>Team fee {formatMoney(TEAM_PRICE_CENTS)}</span>
          <span>Processing fee {formatMoney(PAYMENT_FEE_CENTS)}</span>
          <span>Stripe checkout pending integration</span>
        </div>
        <label>
          Promo code
          <input value={promoCode} onChange={(event) => setPromoCode(event.target.value.toUpperCase())} placeholder="AAYSA25" />
        </label>
      </section>

      {message ? <p className={`notice ${status === "error" ? "error" : ""}`}>{message}</p> : null}

      <button className="button submit-button" type="submit" disabled={status === "submitting"}>
        {status === "submitting" ? "Submitting..." : "Submit registration"}
      </button>
    </form>
  );
}
