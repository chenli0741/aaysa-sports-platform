import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "org.aaysa.sports",
  appName: "AAYSA Sports",
  webDir: "out",
  server: {
    url: process.env.NEXT_PUBLIC_APP_URL,
    cleartext: process.env.NODE_ENV !== "production"
  }
};

export default config;
