"use client";

import { useState, useEffect } from "react";
import { Palette, X } from "lucide-react";

// Theme definitions with CSS variables
const themeVariables = {
  classic: {
    "--bg-primary": "#0A1628",
    "--bg-secondary": "#0F1F3A",
    "--bg-tertiary": "#162844",
    "--accent-gold": "#D4AF37",
    "--accent-gold-light": "#F4E5B8",
    "--accent-royal": "#3B82F6",
    "--text-primary": "#F8FAFC",
    "--text-secondary": "#CBD5E1",
  },
  cyberpunk: {
    "--bg-primary": "#0a0e1a",
    "--bg-secondary": "#111827",
    "--bg-tertiary": "#1f2937",
    "--neon-cyan": "#00F5FF",
    "--neon-magenta": "#FF00FF",
    "--text-primary": "#F0F0F0",
    "--text-secondary": "#A0A0A0",
  },
  terminal: {
    "--bg-primary": "#000000",
    "--bg-secondary": "#0a0a0a",
    "--bg-tertiary": "#141414",
    "--terminal-green": "#00FF41",
    "--terminal-green-dim": "#00CC33",
    "--text-primary": "#00FF41",
    "--text-secondary": "#00CC33",
  },
  nordic: {
    "--bg-primary": "#FFFFFF",
    "--bg-secondary": "#F9FAFB",
    "--bg-tertiary": "#F3F4F6",
    "--accent-blue": "#3B82F6",
    "--text-primary": "#111827",
    "--text-secondary": "#6B7280",
  },
  maximalist: {
    "--bg-primary": "#0F0F1E",
    "--bg-secondary": "#1A1A2E",
    "--bg-tertiary": "#25253A",
    "--gradient-purple": "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
    "--text-primary": "#FFFFFF",
    "--text-secondary": "#E0E0E0",
  },
  neumorphic: {
    "--bg-primary": "#1e1e2e",
    "--bg-secondary": "#25253a",
    "--bg-tertiary": "#2d2d44",
    "--shadow-dark": "#16161f",
    "--shadow-light": "#2d2d44",
    "--accent-purple": "#B4BEFE",
    "--accent-pink": "#F5C2E7",
    "--text-primary": "#CDD6F4",
    "--text-secondary": "#A6ADC8",
  },
};

const themes = [
  {
    id: "classic",
    name: "Classic Banking",
    emoji: "🏦",
    colors: ["#0A1628", "#D4AF37"],
    description: "Navy & Gold - Institutional",
  },
  {
    id: "cyberpunk",
    name: "DeFi Cyberpunk",
    emoji: "🌆",
    colors: ["#0a0e1a", "#00F5FF"],
    description: "Neon Future - High Energy",
  },
  {
    id: "terminal",
    name: "Terminal Hacker",
    emoji: "💻",
    colors: ["#000000", "#00FF41"],
    description: "Matrix Green - CLI Style",
  },
  {
    id: "nordic",
    name: "Minimalist Nordic",
    emoji: "❄️",
    colors: ["#FFFFFF", "#3B82F6"],
    description: "Clean & Simple",
  },
  {
    id: "maximalist",
    name: "Gradient Maximalist",
    emoji: "🌈",
    colors: ["#667eea", "#f5576c"],
    description: "Rainbow Gradients",
  },
  {
    id: "neumorphic",
    name: "Dark Neumorphic",
    emoji: "🎨",
    colors: ["#1e1e2e", "#B4BEFE"],
    description: "Soft 3D Tactile",
  },
];

export function ThemeSwitcher() {
  const [isOpen, setIsOpen] = useState(false);
  const [currentTheme, setCurrentTheme] = useState("classic");

  useEffect(() => {
    // Load saved theme
    const saved = localStorage.getItem("bank-theme");
    if (saved && themeVariables[saved as keyof typeof themeVariables]) {
      applyTheme(saved);
      setCurrentTheme(saved);
    }
  }, []);

  const applyTheme = (themeId: string) => {
    const variables = themeVariables[themeId as keyof typeof themeVariables];
    if (variables) {
      // Apply CSS variables to root
      Object.entries(variables).forEach(([key, value]) => {
        document.documentElement.style.setProperty(key, value);
      });

      // Add theme class to body
      document.body.className = document.body.className
        .replace(/theme-\w+/g, '')
        .trim();
      document.body.classList.add(`theme-${themeId}`);
    }
  };

  const handleThemeChange = (themeId: string) => {
    setCurrentTheme(themeId);
    localStorage.setItem("bank-theme", themeId);
    applyTheme(themeId);

    // Show success notification
    showNotification(`✓ Switched to ${themes.find((t) => t.id === themeId)?.name}`);
    setIsOpen(false);
  };

  const showNotification = (message: string) => {
    const notification = document.createElement("div");
    notification.textContent = message;
    notification.style.cssText = `
      position: fixed;
      top: 24px;
      right: 24px;
      background: linear-gradient(135deg, #10B981, #059669);
      color: white;
      padding: 16px 24px;
      border-radius: 12px;
      font-weight: 600;
      font-size: 14px;
      z-index: 99999;
      box-shadow: 0 10px 25px rgba(16, 185, 129, 0.3);
      animation: slideInRight 0.3s ease;
    `;

    // Add animation keyframes
    if (!document.getElementById("notification-styles")) {
      const style = document.createElement("style");
      style.id = "notification-styles";
      style.textContent = `
        @keyframes slideInRight {
          from {
            transform: translateX(400px);
            opacity: 0;
          }
          to {
            transform: translateX(0);
            opacity: 1;
          }
        }
      `;
      document.head.appendChild(style);
    }

    document.body.appendChild(notification);
    setTimeout(() => notification.remove(), 3000);
  };

  const currentThemeData = themes.find((t) => t.id === currentTheme);

  return (
    <>
      {/* Floating Theme Button */}
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="fixed bottom-6 right-6 z-[100] w-16 h-16 rounded-full bg-gradient-to-br from-purple-600 via-pink-600 to-purple-500 text-white shadow-2xl hover:shadow-purple-500/50 transition-all duration-300 flex items-center justify-center group hover:scale-110 active:scale-95"
        title="Change Theme"
        style={{
          boxShadow: "0 10px 40px rgba(168, 85, 247, 0.4)",
        }}
      >
        <Palette className="w-7 h-7 group-hover:rotate-12 transition-transform duration-300" />
      </button>

      {/* Theme Switcher Panel */}
      {isOpen && (
        <>
          {/* Backdrop */}
          <div
            className="fixed inset-0 z-[101] bg-black/60 backdrop-blur-sm"
            onClick={() => setIsOpen(false)}
            style={{
              animation: "fadeIn 0.2s ease",
            }}
          />

          {/* Modal */}
          <div className="fixed inset-0 z-[102] flex items-center justify-center p-4 pointer-events-none">
            <div
              className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl max-w-3xl w-full max-h-[85vh] overflow-hidden pointer-events-auto"
              style={{
                animation: "scaleIn 0.3s cubic-bezier(0.34, 1.56, 0.64, 1)",
              }}
            >
              {/* Header */}
              <div className="sticky top-0 bg-gradient-to-r from-purple-600 to-pink-600 p-6 text-white">
                <div className="flex items-center justify-between">
                  <div>
                    <h2 className="text-2xl font-bold flex items-center gap-3">
                      <Palette className="w-7 h-7" />
                      Choose Your Theme
                    </h2>
                    <p className="text-sm text-purple-100 mt-1">
                      Current: {currentThemeData?.emoji} {currentThemeData?.name}
                    </p>
                  </div>
                  <button
                    onClick={() => setIsOpen(false)}
                    className="p-2 hover:bg-white/20 rounded-lg transition-colors"
                  >
                    <X className="w-6 h-6" />
                  </button>
                </div>
              </div>

              {/* Theme Grid */}
              <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-4 overflow-y-auto max-h-[calc(85vh-140px)]">
                {themes.map((theme) => (
                  <button
                    key={theme.id}
                    onClick={() => handleThemeChange(theme.id)}
                    className={`
                      relative p-6 rounded-xl border-2 transition-all duration-300 text-left group
                      ${
                        currentTheme === theme.id
                          ? "border-purple-500 bg-purple-50 dark:bg-purple-900/30 shadow-lg shadow-purple-500/20 scale-105"
                          : "border-gray-200 dark:border-gray-700 hover:border-purple-300 dark:hover:border-purple-600 hover:shadow-md hover:scale-102"
                      }
                    `}
                  >
                    {/* Active Indicator */}
                    {currentTheme === theme.id && (
                      <div className="absolute top-4 right-4 flex items-center gap-2">
                        <span className="text-xs font-semibold text-purple-600 dark:text-purple-400">
                          ACTIVE
                        </span>
                        <div
                          className="w-3 h-3 bg-purple-500 rounded-full"
                          style={{
                            animation: "pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite",
                          }}
                        />
                      </div>
                    )}

                    {/* Theme Info */}
                    <div className="flex items-start gap-4 mb-4">
                      <div className="text-5xl">{theme.emoji}</div>
                      <div className="flex-1">
                        <h3 className="font-bold text-gray-900 dark:text-white text-xl mb-1">
                          {theme.name}
                        </h3>
                        <p className="text-sm text-gray-600 dark:text-gray-400">
                          {theme.description}
                        </p>
                      </div>
                    </div>

                    {/* Color Swatches */}
                    <div className="flex gap-2">
                      {theme.colors.map((color, i) => (
                        <div
                          key={i}
                          className="w-10 h-10 rounded-lg shadow-md border-2 border-gray-200 dark:border-gray-600 group-hover:scale-110 transition-transform"
                          style={{ background: color }}
                          title={color}
                        />
                      ))}
                    </div>

                    {/* Hover Overlay */}
                    {currentTheme !== theme.id && (
                      <div className="absolute inset-0 bg-gradient-to-br from-purple-600 to-pink-600 rounded-xl flex items-center justify-center opacity-0 group-hover:opacity-95 transition-opacity duration-300">
                        <span className="text-white font-bold text-lg">Click to Apply</span>
                      </div>
                    )}
                  </button>
                ))}
              </div>

              {/* Footer */}
              <div className="border-t border-gray-200 dark:border-gray-700 p-6 bg-gray-50 dark:bg-gray-800/50">
                <p className="text-sm text-gray-600 dark:text-gray-400 text-center">
                  💡 <strong>Tip:</strong> Your theme choice is saved automatically and persists across sessions.
                </p>
              </div>
            </div>
          </div>

          {/* Animations */}
          <style jsx>{`
            @keyframes fadeIn {
              from {
                opacity: 0;
              }
              to {
                opacity: 1;
              }
            }

            @keyframes scaleIn {
              from {
                opacity: 0;
                transform: scale(0.9);
              }
              to {
                opacity: 1;
                transform: scale(1);
              }
            }

            @keyframes pulse {
              0%, 100% {
                opacity: 1;
              }
              50% {
                opacity: 0.5;
              }
            }
          `}</style>
        </>
      )}
    </>
  );
}
