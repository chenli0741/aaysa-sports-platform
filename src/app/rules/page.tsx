export default function RulesPage() {
  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">Public</div>
        <h1>Rules</h1>
        <p className="lead">Operational rules for AAYSA Sports tournament registration, eligibility, waivers, refunds, and standings.</p>
      </section>

      <section className="grid">
        <article className="card">
          <h2>Roster</h2>
          <p>5v5 teams must submit 5 to 7 players. Teams outside that range require organizer review.</p>
        </article>
        <article className="card">
          <h2>Waivers</h2>
          <p>Each player needs a guardian waiver acceptance tied to the active legal document version.</p>
        </article>
        <article className="card">
          <h2>Standings</h2>
          <p>Default points are win 3, draw 1, loss 0. Sorting uses points, goal difference, goals for, then team name.</p>
        </article>
      </section>
    </main>
  );
}
