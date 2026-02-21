"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";
import { RainbowKitProvider, darkTheme, lightTheme } from "@rainbow-me/rainbowkit";
import { config } from "@/lib/wagmi";
import { ToastProvider } from "@/components/ui/Toast";
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";
import "@rainbow-me/rainbowkit/styles.css";

const queryClient = new QueryClient();

function RainbowKitWrapper({ children }: { children: React.ReactNode }) {
  const { resolvedTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  // Use dark theme as default during SSR to match defaultTheme
  const theme = mounted && resolvedTheme === "light"
    ? lightTheme({
        accentColor: "#6366f1",
        accentColorForeground: "white",
        borderRadius: "medium",
      })
    : darkTheme({
        accentColor: "#6366f1",
        accentColorForeground: "white",
        borderRadius: "medium",
      });

  return (
    <RainbowKitProvider theme={theme}>
      {children}
    </RainbowKitProvider>
  );
}

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitWrapper>
          <ToastProvider>{children}</ToastProvider>
        </RainbowKitWrapper>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
