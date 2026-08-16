import { notFound } from "next/navigation";
import { getI18n } from "@/lib/i18n-server";
import { getOrganizerTournament } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function OrganizerStandingsPage({
  params
}: {
  params: Promise<{ id: string }>;
}) {
  const { dictionary } = await getI18n();
  const t = dictionary.standings;
  const { id } = await params;
  const tournament = await getOrganizerTournament(id);

  if (!tournament) {
    notFound();
  }

  return (
    <main className="main wide">
      <section className="hero">
        <div className="eyebrow">{t.organizerTitle}</div>
        <h1>{tournament.name}</h1>
        <p className="lead">{t.organizerLead}</p>
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
