"use client";

import { signIn, signOut } from "next-auth/react";
import { useRouter, useSearchParams } from "next/navigation";
import { useState } from "react";
import { type Locale } from "@/lib/i18n";

const copy = {
  en: {
    email: "Email",
    password: "Password",
    name: "Name",
    phone: "Phone",
    signIn: "Sign in",
    signingIn: "Signing in...",
    register: "Create account",
    registering: "Creating...",
    save: "Save profile",
    saving: "Saving...",
    saved: "Profile saved",
    failed: "Request failed",
    invalidLogin: "Invalid email or password",
    signOut: "Sign out",
    passwordHint: "Use at least 8 characters."
  },
  zh: {
    email: "邮箱",
    password: "密码",
    name: "姓名",
    phone: "电话",
    signIn: "登录",
    signingIn: "登录中...",
    register: "创建账户",
    registering: "创建中...",
    save: "保存资料",
    saving: "保存中...",
    saved: "资料已保存",
    failed: "请求失败",
    invalidLogin: "邮箱或密码不正确",
    signOut: "退出登录",
    passwordHint: "至少 8 个字符。"
  }
} satisfies Record<Locale, Record<string, string>>;

export function SignInForm({ locale }: { locale: Locale }) {
  const t = copy[locale];
  const router = useRouter();
  const searchParams = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [status, setStatus] = useState<"idle" | "submitting" | "error">("idle");
  const [message, setMessage] = useState("");

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("submitting");
    setMessage("");

    const result = await signIn("credentials", {
      email,
      password,
      redirect: false
    });

    if (result?.ok) {
      router.push(searchParams.get("callbackUrl") || "/account");
      router.refresh();
      return;
    }

    setStatus("error");
    setMessage(t.invalidLogin);
  }

  return (
    <form className="form-stack compact-form" onSubmit={submit}>
      <label>
        {t.email}
        <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} required />
      </label>
      <label>
        {t.password}
        <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} required />
      </label>
      {message ? <p className="notice error">{message}</p> : null}
      <button className="button submit-button" type="submit" disabled={status === "submitting"}>
        {status === "submitting" ? t.signingIn : t.signIn}
      </button>
    </form>
  );
}

export function RegisterForm({ locale }: { locale: Locale }) {
  const t = copy[locale];
  const router = useRouter();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [password, setPassword] = useState("");
  const [status, setStatus] = useState<"idle" | "submitting" | "error">("idle");
  const [message, setMessage] = useState("");

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("submitting");
    setMessage("");

    const response = await fetch("/api/users/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, email, phone, password })
    });

    if (!response.ok) {
      const result = (await response.json()) as { error?: string };
      setStatus("error");
      setMessage(result.error ?? t.failed);
      return;
    }

    const result = await signIn("credentials", {
      email,
      password,
      redirect: false
    });

    if (result?.ok) {
      router.push("/account");
      router.refresh();
      return;
    }

    setStatus("error");
    setMessage(t.failed);
  }

  return (
    <form className="form-stack compact-form" onSubmit={submit}>
      <label>
        {t.name}
        <input value={name} onChange={(event) => setName(event.target.value)} required />
      </label>
      <label>
        {t.email}
        <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} required />
      </label>
      <label>
        {t.phone}
        <input value={phone} onChange={(event) => setPhone(event.target.value)} />
      </label>
      <label>
        {t.password}
        <input
          minLength={8}
          type="password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          required
        />
        <span className="helper">{t.passwordHint}</span>
      </label>
      {message ? <p className={`notice ${status === "error" ? "error" : ""}`}>{message}</p> : null}
      <button className="button submit-button" type="submit" disabled={status === "submitting"}>
        {status === "submitting" ? t.registering : t.register}
      </button>
    </form>
  );
}

export function ProfileForm({
  locale,
  initialName,
  initialPhone
}: {
  locale: Locale;
  initialName: string;
  initialPhone: string;
}) {
  const t = copy[locale];
  const router = useRouter();
  const [name, setName] = useState(initialName);
  const [phone, setPhone] = useState(initialPhone);
  const [status, setStatus] = useState<"idle" | "submitting" | "saved" | "error">("idle");

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("submitting");

    const response = await fetch("/api/users/me", {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name, phone })
    });

    setStatus(response.ok ? "saved" : "error");

    if (response.ok) {
      router.refresh();
    }
  }

  return (
    <form className="form-stack compact-form" onSubmit={submit}>
      <label>
        {t.name}
        <input value={name} onChange={(event) => setName(event.target.value)} required />
      </label>
      <label>
        {t.phone}
        <input value={phone} onChange={(event) => setPhone(event.target.value)} />
      </label>
      {status === "saved" ? <p className="notice">{t.saved}</p> : null}
      {status === "error" ? <p className="notice error">{t.failed}</p> : null}
      <div className="actions">
        <button className="button submit-button" type="submit" disabled={status === "submitting"}>
          {status === "submitting" ? t.saving : t.save}
        </button>
        <button className="button secondary" type="button" onClick={() => signOut({ callbackUrl: "/" })}>
          {t.signOut}
        </button>
      </div>
    </form>
  );
}
