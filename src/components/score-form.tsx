"use client";

import { useState } from "react";

export function ScoreForm({ gameId }: { gameId: string }) {
  const [homeScore, setHomeScore] = useState("");
  const [awayScore, setAwayScore] = useState("");
  const [message, setMessage] = useState("");

  async function submitScore(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setMessage("Saving...");

    const response = await fetch(`/api/games/${gameId}/score`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        homeScore: Number(homeScore),
        awayScore: Number(awayScore)
      })
    });

    setMessage(response.ok ? "Score saved. Refresh to see standings." : "Score could not be saved.");
  }

  return (
    <form className="inline-score-form" onSubmit={submitScore}>
      <input
        aria-label="Home score"
        min="0"
        type="number"
        value={homeScore}
        onChange={(event) => setHomeScore(event.target.value)}
        required
      />
      <span>-</span>
      <input
        aria-label="Away score"
        min="0"
        type="number"
        value={awayScore}
        onChange={(event) => setAwayScore(event.target.value)}
        required
      />
      <button type="submit">Save</button>
      {message ? <small>{message}</small> : null}
    </form>
  );
}
