import { notFound } from "next/navigation";
import { getTournamentBySlug } from "@/lib/tournaments";

export const dynamic = "force-dynamic";

export default async function StandingsPage({
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
    <main className="main wide">
      <section className="hero">
        <div className="eyebrow">Standings</div>
        <h1>{tournament.name}</h1>
        <p className="lead">Win 3, draw 1, loss 0. Tie-breakers: points, goal difference, goals for, team name.</p>
      </section>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Team</th>
              <th>Division</th>
              <th>Played</th>
              <th>W</th>
              <th>D</th>
              <th>L</th>
              <th>GF</th>
              <th>GA</th>
              <th>GD</th>
              <th>Pts</th>
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
