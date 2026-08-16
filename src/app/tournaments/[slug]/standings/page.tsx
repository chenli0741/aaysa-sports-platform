import { notFound } from "next/navigation";
import { getI18n } from "@/lib/i18n-server";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function StandingsPage({
  params
}: {
  params: Promise<{ slug: string }>;
}) {
  const { dictionary } = await getI18n();
  const t = dictionary.standings;
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main wide">
      <section className="hero">
        <div className="eyebrow">{t.title}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{t.lead}</p>
      </section>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>{t.team}</th>
              <th>{t.division}</th>
              <th>{t.played}</th>
              <th>{t.wins}</th>
              <th>{t.draws}</th>
              <th>{t.losses}</th>
              <th>{t.goalsFor}</th>
              <th>{t.goalsAgainst}</th>
              <th>{t.goalDiff}</th>
              <th>{t.points}</th>
            </tr>
          </thead>
          <tbody>
            {tournament.standings.map((standing) => (
              <tr key={standing.id}>
                <td>{standing.team.name}</td>
                <td>{standing.division.name}</td>
                <td>{standing.played}</td>
                <td>{standing.wins}</td>
                <td>{standing.draws}</td>
                <td>{standing.losses}</td>
                <td>{standing.goalsFor}</td>
                <td>{standing.goalsAgainst}</td>
                <td>{standing.goalDiff}</td>
                <td>{standing.points}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </main>
  );
}
