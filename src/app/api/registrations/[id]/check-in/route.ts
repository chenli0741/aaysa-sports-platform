import { NextResponse } from "next/server";
import { CheckInMethod } from "@prisma/client";
import { prisma } from "@/lib/prisma";

export async function POST(
  _request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const registration = await prisma.registration.findUnique({
    where: { id },
    include: {
      checkIns: { orderBy: { checkedInAt: "desc" } }
    }
  });

  if (!registration) {
    return NextResponse.json({ error: "Registration not found" }, { status: 404 });
  }

  const checkIn =
    registration.checkIns[0] ??
    (await prisma.checkIn.create({
      data: {
        tournamentId: registration.tournamentId,
        registrationId: registration.id,
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
