import { notFound } from "next/navigation";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function VenuePage({
  params
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">Venue</div>
        <h1>{tournament.name}</h1>
        <p className="lead">Venue and field setup for event-day navigation.</p>
      </section>

      <section className="grid">
        {tournament.venues.map((venue) => (
          <article className="card" key={venue.id}>
            <h2>{venue.name}</h2>
            <p>{venue.address ?? "Address TBD"}</p>
            <div className="summary-strip compact">
              {venue.fields.map((field) => (
                <span key={field.id}>{field.name}</span>
              ))}
            </div>
          </article>
        ))}
      </section>
    </main>
  );
}
