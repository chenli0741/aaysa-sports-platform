import { notFound } from "next/navigation";
import { getI18n } from "@/lib/i18n-server";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function VenuePage({
  params
}: {
  params: Promise<{ slug: string }>;
}) {
  const { dictionary } = await getI18n();
  const t = dictionary.venue;
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main">
      <section className="hero">
        <div className="eyebrow">{t.title}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{t.lead}</p>
      </section>

      <section className="grid">
        {tournament.venues.map((venue) => (
          <article className="card" key={venue.id}>
            <h2>{venue.name}</h2>
            <p>{venue.address ?? dictionary.common.addressTbd}</p>
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
