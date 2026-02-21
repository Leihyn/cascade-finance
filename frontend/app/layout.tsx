import type { Metadata } from "next";
import { ThemeProvider } from "@/components/ThemeProvider";
import { Providers } from "./providers";
import "./globals.css";

export const metadata: Metadata = {
  title: "Cascade Finance - Interest Rate Swaps on Flow",
  description: "Trade fixed vs floating interest rates with leveraged positions on Flow",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="min-h-screen antialiased">
        {/* Animated background */}
        <div className="bg-mesh" />
        <div className="orb orb-1" />
        <div className="orb orb-2" />
        <div className="orb orb-3" />

        <ThemeProvider>
          <Providers>
            <div className="relative z-10">
              {children}
            </div>
          </Providers>
        </ThemeProvider>
      </body>
    </html>
  );
}
