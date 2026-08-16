import { NextRequest, NextResponse } from "next/server";
import { UserRole } from "@prisma/client";
import { prisma } from "@/lib/prisma";
import { hashPassword } from "@/lib/password";

function normalizeEmail(email: string) {
  return email.trim().toLowerCase();
}

function validPassword(value: unknown) {
  return typeof value === "string" && value.length >= 8;
}

export async function POST(request: NextRequest) {
  const body = (await request.json()) as {
    name?: string;
    email?: string;
    phone?: string;
    password?: string;
  };
  const email = body.email ? normalizeEmail(body.email) : "";

  const name = body.name?.trim();
  const password = body.password;

  if (!email || !name || typeof password !== "string" || !validPassword(password)) {
    return NextResponse.json({ error: "Name, email, and an 8+ character password are required" }, { status: 400 });
  }

  const existing = await prisma.user.findUnique({ where: { email } });

  if (existing?.passwordHash) {
    return NextResponse.json({ error: "An account already exists for this email" }, { status: 409 });
  }

  const passwordHash = await hashPassword(password);
  const user = existing
    ? await prisma.user.update({
        where: { id: existing.id },
        data: {
          name,
          phone: body.phone?.trim() || null,
          passwordHash
        }
      })
    : await prisma.user.create({
        data: {
          email,
          name,
          phone: body.phone?.trim() || null,
          passwordHash,
          role: UserRole.PARENT
        }
      });

  return NextResponse.json({
    data: {
      id: user.id,
      email: user.email,
      name: user.name,
      phone: user.phone,
      role: user.role
    }
  });
}
