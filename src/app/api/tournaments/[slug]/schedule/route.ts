import { NextRequest, NextResponse } from "next/server";
import { getRequestI18n } from "@/lib/i18n-request";
import { getTournamentBySlug } from "@/lib/tournaments";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ slug: string }> }
) {
  const { dictionary } = getRequestI18n(request);
  const { slug } = await params;
  const tournament = await getTournamentBySlug(slug);

  if (!tournament) {
    return NextResponse.json({ error: dictionary.apiErrors.tournamentNotFound }, { status: 404 });
  }

  return NextResponse.json({
    data: tournament.games.map((game) => ({
      id: game.id,
      division: game.division.name,
      startsAt: game.startsAt,
      status: game.status,
      field: game.field?.name,
      venue: game.field?.venue.name,
      homeTeam: game.homeTeam?.name,
      awayTeam: game.awayTeam?.name,
      homeScore: game.homeScore,
      awayScore: game.awayScore
    }))
  });
}
