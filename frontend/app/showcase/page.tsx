"use client";

import { useState } from "react";
import { ClassicBankingDemo } from "@/components/showcase/ClassicBankingDemo";
import { CyberpunkDemo } from "@/components/showcase/CyberpunkDemo";
import { TerminalDemo } from "@/components/showcase/TerminalDemo";
import { NordicDemo } from "@/components/showcase/NordicDemo";
import { MaximalistDemo } from "@/components/showcase/MaximalistDemo";
import { NeumorphicDemo } from "@/components/showcase/NeumorphicDemo";

const designs = [
  {
    id: "classic",
    name: "Classic Banking",
    emoji: "🏦",
    tagline: "Institutional Elegance",
    color: "bg-gradient-to-r from-blue-900 to-yellow-600",
  },
  {
    id: "cyberpunk",
    name: "DeFi Cyberpunk",
    emoji: "🌆",
    tagline: "Neon Future",
    color: "bg-gradient-to-r from-cyan-500 to-pink-500",
  },
  {
    id: "terminal",
    name: "Terminal Hacker",
    emoji: "💻",
    tagline: "Matrix Green",
    color: "bg-gradient-to-r from-green-500 to-emerald-600",
  },
  {
    id: "nordic",
    name: "Minimalist Nordic",
    emoji: "❄️",
    tagline: "Scandinavian Clean",
    color: "bg-gradient-to-r from-blue-500 to-indigo-500",
  },
  {
    id: "maximalist",
    name: "Gradient Maximalist",
    emoji: "🌈",
    tagline: "Rainbow Energy",
    color: "bg-gradient-to-r from-purple-500 via-pink-500 to-red-500",
  },
  {
    id: "neumorphic",
    name: "Dark Neumorphic",
    emoji: "🎨",
    tagline: "Soft 3D Tactile",
    color: "bg-gradient-to-r from-purple-600 to-pink-600",
  },
];

export default function ShowcasePage() {
  const [activeDesign, setActiveDesign] = useState("classic");

  return (
    <div className="min-h-screen bg-gray-900">
      {/* Header with Tabs */}
      <div className="sticky top-0 z-50 bg-gray-900 border-b border-gray-800">
        <div className="max-w-7xl mx-auto px-4 py-4">
          <h1 className="text-2xl font-bold text-white mb-4">
            Cascade Finance - Design Showcase
          </h1>

          {/* Tab Navigation */}
          <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-hide">
            {designs.map((design) => (
              <button
                key={design.id}
                onClick={() => setActiveDesign(design.id)}
                className={`
                  flex items-center gap-2 px-4 py-3 rounded-lg font-semibold whitespace-nowrap transition-all
                  ${
                    activeDesign === design.id
                      ? `${design.color} text-white shadow-lg scale-105`
                      : "bg-gray-800 text-gray-400 hover:bg-gray-700 hover:text-white"
                  }
                `}
              >
                <span className="text-xl">{design.emoji}</span>
                <div className="text-left">
                  <div className="text-sm font-bold">{design.name}</div>
                  <div className="text-xs opacity-80">{design.tagline}</div>
                </div>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Design Content */}
      <div className="max-w-7xl mx-auto">
        {activeDesign === "classic" && <ClassicBankingDemo />}
        {activeDesign === "cyberpunk" && <CyberpunkDemo />}
        {activeDesign === "terminal" && <TerminalDemo />}
        {activeDesign === "nordic" && <NordicDemo />}
        {activeDesign === "maximalist" && <MaximalistDemo />}
        {activeDesign === "neumorphic" && <NeumorphicDemo />}
      </div>

      {/* Quick Navigation Hint */}
      <div className="fixed bottom-4 right-4 bg-black/80 text-white px-4 py-2 rounded-lg text-sm backdrop-blur-sm">
        💡 Click tabs above to switch designs
      </div>
    </div>
  );
}
