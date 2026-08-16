import { NextRequest, NextResponse } from "next/server";
import { GameStatus, NotificationType } from "@prisma/client";
import { getRequestI18n } from "@/lib/i18n-request";
import { prisma } from "@/lib/prisma";

function resultFor(homeScore: number, awayScore: number) {
  if (homeScore > awayScore) {
    return { homePoints: 3, awayPoints: 0, homeWin: 1, awayWin: 0, draw: 0 };
  }

  if (homeScore < awayScore) {
    return { homePoints: 0, awayPoints: 3, homeWin: 0, awayWin: 1, draw: 0 };
  }

  return { homePoints: 1, awayPoints: 1, homeWin: 0, awayWin: 0, draw: 1 };
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  const { dictionary } = getRequestI18n(request);
  const api = dictionary.apiErrors;
  const { id } = await params;
  const body = (await request.json()) as { homeScore?: number; awayScore?: number };
  const homeScore = Number(body.homeScore);
  const awayScore = Number(body.awayScore);

  if (!Number.isInteger(homeScore) || !Number.isInteger(awayScore) || homeScore < 0 || awayScore < 0) {
    return NextResponse.json({ error: api.invalidScores }, { status: 400 });
  }

  const game = await prisma.game.findUnique({
    where: { id },
    include: { homeTeam: true, awayTeam: true }
  });

  if (!game || !game.homeTeamId || !game.awayTeamId) {
    return NextResponse.json({ error: api.gameNotFound }, { status: 404 });
  }

  await prisma.$transaction(async (tx) => {
    await tx.game.update({
      where: { id },
      data: {
        homeScore,
        awayScore,
        status: GameStatus.FINAL
      }
    });

    const finalGames = await tx.game.findMany({
      where: {
        divisionId: game.divisionId,
        status: GameStatus.FINAL,
        homeTeamId: { not: null },
        awayTeamId: { not: null },
        homeScore: { not: null },
        awayScore: { not: null }
      }
    });

    const rows = new Map<
      string,
      {
        teamId: string;
        played: number;
        wins: number;
        draws: number;
        losses: number;
        goalsFor: number;
        goalsAgainst: number;
        goalDiff: number;
        points: number;
      }
    >();

    function rowFor(teamId: string) {
      const existing = rows.get(teamId);

      if (existing) {
        return existing;
      }

      const next = {
        teamId,
        played: 0,
        wins: 0,
        draws: 0,
        losses: 0,
        goalsFor: 0,
        goalsAgainst: 0,
        goalDiff: 0,
        points: 0
      };
      rows.set(teamId, next);
      return next;
    }

    for (const finalGame of finalGames) {
      if (
        !finalGame.homeTeamId ||
        !finalGame.awayTeamId ||
        finalGame.homeScore === null ||
        finalGame.awayScore === null
      ) {
        continue;
      }

      const result = resultFor(finalGame.homeScore, finalGame.awayScore);
      const home = rowFor(finalGame.homeTeamId);
      const away = rowFor(finalGame.awayTeamId);

      home.played += 1;
      home.wins += result.homeWin;
      home.draws += result.draw;
      home.losses += result.awayWin;
      home.goalsFor += finalGame.homeScore;
      home.goalsAgainst += finalGame.awayScore;
      home.goalDiff += finalGame.homeScore - finalGame.awayScore;
      home.points += result.homePoints;

      away.played += 1;
      away.wins += result.awayWin;
      away.draws += result.draw;
      away.losses += result.homeWin;
      away.goalsFor += finalGame.awayScore;
      away.goalsAgainst += finalGame.homeScore;
      away.goalDiff += finalGame.awayScore - finalGame.homeScore;
      away.points += result.awayPoints;
    }

    await tx.standing.deleteMany({
      where: { divisionId: game.divisionId }
    });

    await tx.standing.createMany({
      data: Array.from(rows.values()).map((row) => ({
        tournamentId: game.tournamentId,
        divisionId: game.divisionId,
        teamId: row.teamId,
        played: row.played,
        wins: row.wins,
        draws: row.draws,
        losses: row.losses,
        goalsFor: row.goalsFor,
        goalsAgainst: row.goalsAgainst,
        goalDiff: row.goalDiff,
        points: row.points
      }))
    });

    await tx.notification.create({
      data: {
        tournamentId: game.tournamentId,
        type: NotificationType.SCORE_FINALIZED,
        subject: "Score finalized",
        body: `${game.homeTeam?.name ?? "Home"} ${homeScore} - ${awayScore} ${game.awayTeam?.name ?? "Away"}`
      }
    });
  });

  return NextResponse.json({ data: { id, status: GameStatus.FINAL, homeScore, awayScore } });
}
