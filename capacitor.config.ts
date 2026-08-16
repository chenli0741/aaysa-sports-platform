import type { CapacitorConfig } from "@capacitor/cli";

const serverUrl = process.env.NEXT_PUBLIC_APP_URL;

const config: CapacitorConfig = {
  appId: "org.aaysa.sports",
  appName: "AAYSA Sports",
  webDir: "capacitor-web",
  server: {
    url: serverUrl,
    cleartext: serverUrl?.startsWith("http://") ?? false
  }
};

export default config;
