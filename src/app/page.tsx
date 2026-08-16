import Link from "next/link";

export default function HomePage() {
  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">Tournament platform</div>
        <h1>AAYSA Sports</h1>
        <p className="lead">
          A web and mobile-supported operating system for tournament registration,
          rosters, waivers, schedules, check-in, score reporting, and standings.
        </p>
        <div className="actions">
          <Link className="button" href="/tournaments">
            View tournaments
          </Link>
          <Link className="button secondary" href="/organizer">
            Organizer console
          </Link>
        </div>
      </section>

      <section className="grid" aria-label="Platform areas">
        <article className="card">
          <h2>Registration</h2>
          <p>Team manager flow for division selection, rosters, waivers, promo codes, and Stripe payment.</p>
        </article>
        <article className="card">
          <h2>Event Operations</h2>
          <p>Organizer tools for registrations, schedule publishing, QR check-in, scores, and standings.</p>
        </article>
        <article className="card">
          <h2>Mobile Utility</h2>
          <p>Capacitor shell for app identity, stored sessions, push alerts, QR scanning, sharing, and deep links.</p>
        </article>
      </section>
    </main>
  );
}
