"use client";

import { useState } from "react";
import { dictionaries, type Locale } from "@/lib/i18n";

export function ScoreForm({ gameId, locale }: { gameId: string; locale: Locale }) {
  const t = dictionaries[locale].scoreForm;
  const [homeScore, setHomeScore] = useState("");
  const [awayScore, setAwayScore] = useState("");
  const [message, setMessage] = useState("");

  async function submitScore(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage(t.saving);

    const response = await fetch(`/api/games/${gameId}/score`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        homeScore: Number(homeScore),
        awayScore: Number(awayScore)
      })
    });

    setMessage(response.ok ? t.saved : t.failed);
  }

  return (
    <form className="inline-score-form" onSubmit={submitScore}>
      <input
        aria-label={t.homeScore}
        min="0"
        type="number"
        value={homeScore}
        onChange={(event) => setHomeScore(event.target.value)}
        required
      />
      <span>-</span>
      <input
        aria-label={t.awayScore}
        min="0"
        type="number"
        value={awayScore}
        onChange={(event) => setAwayScore(event.target.value)}
        required
      />
      <button type="submit">{t.save}</button>
      {message ? <small>{message}</small> : null}
    </form>
  );
}
