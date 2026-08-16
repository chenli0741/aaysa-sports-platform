import { NextResponse } from "next/server";
import { CheckInMethod } from "@prisma/client";
import { prisma } from "@/lib/prisma";

export async function POST(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const rosterEntry = await prisma.registrationRosterEntry.findUnique({
    where: { id },
    include: {
      registration: true,
      checkIns: { orderBy: { checkedInAt: "desc" } }
    }
  });

  if (!rosterEntry) {
    return NextResponse.json({ error: "Roster entry not found" }, { status: 404 });
  }

  const checkIn =
    rosterEntry.checkIns[0] ??
    (await prisma.checkIn.create({
      data: {
        tournamentId: rosterEntry.registration.tournamentId,
        registrationId: rosterEntry.registrationId,
        rosterEntryId: rosterEntry.id,
        method: CheckInMethod.MANUAL
      }
    }));

  return NextResponse.json({
    data: {
      id: checkIn.id,
      checkedInAt: checkIn.checkedInAt
    }
  });
}
