/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        // Deep space dark backgrounds
        dark: {
          950: "#030712",
          900: "#0a0f1a",
          800: "#111827",
          700: "#1a2332",
          600: "#243044",
        },
        // Neon cyan accent (primary actions)
        neon: {
          cyan: "#00f5ff",
          blue: "#00a8ff",
          purple: "#a855f7",
          pink: "#f472b6",
          green: "#22ff88",
        },
        // Glass effect colors
        glass: {
          white: "rgba(255, 255, 255, 0.05)",
          border: "rgba(255, 255, 255, 0.1)",
          hover: "rgba(255, 255, 255, 0.08)",
        },
        // Status colors
        success: {
          DEFAULT: "#22ff88",
          glow: "rgba(34, 255, 136, 0.4)",
        },
        warning: {
          DEFAULT: "#ffbb00",
          glow: "rgba(255, 187, 0, 0.4)",
        },
        danger: {
          DEFAULT: "#ff4466",
          glow: "rgba(255, 68, 102, 0.4)",
        },
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "-apple-system", "sans-serif"],
        display: ["Space Grotesk", "Inter", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "Fira Code", "monospace"],
      },
      fontSize: {
        "display-xl": ["4.5rem", { lineHeight: "1.1", letterSpacing: "-0.02em" }],
        "display-lg": ["3.5rem", { lineHeight: "1.15", letterSpacing: "-0.02em" }],
        "display-md": ["2.5rem", { lineHeight: "1.2", letterSpacing: "-0.01em" }],
        "display-sm": ["2rem", { lineHeight: "1.25", letterSpacing: "-0.01em" }],
      },
      backgroundImage: {
        // Gradient meshes
        "gradient-radial": "radial-gradient(var(--tw-gradient-stops))",
        "gradient-conic": "conic-gradient(from 180deg at 50% 50%, var(--tw-gradient-stops))",
        "mesh-gradient": `
          radial-gradient(at 40% 20%, rgba(0, 245, 255, 0.15) 0px, transparent 50%),
          radial-gradient(at 80% 0%, rgba(168, 85, 247, 0.15) 0px, transparent 50%),
          radial-gradient(at 0% 50%, rgba(0, 168, 255, 0.1) 0px, transparent 50%),
          radial-gradient(at 80% 50%, rgba(244, 114, 182, 0.1) 0px, transparent 50%),
          radial-gradient(at 0% 100%, rgba(34, 255, 136, 0.1) 0px, transparent 50%)
        `,
        "hero-gradient": `
          radial-gradient(ellipse 80% 50% at 50% -20%, rgba(0, 245, 255, 0.2), transparent),
          radial-gradient(ellipse 60% 40% at 80% 50%, rgba(168, 85, 247, 0.15), transparent)
        `,
        "card-gradient": "linear-gradient(135deg, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0.02) 100%)",
        "glow-cyan": "radial-gradient(circle, rgba(0, 245, 255, 0.3) 0%, transparent 70%)",
        "glow-purple": "radial-gradient(circle, rgba(168, 85, 247, 0.3) 0%, transparent 70%)",
      },
      boxShadow: {
        "glow-sm": "0 0 20px rgba(0, 245, 255, 0.3)",
        "glow-md": "0 0 40px rgba(0, 245, 255, 0.4)",
        "glow-lg": "0 0 60px rgba(0, 245, 255, 0.5)",
        "glow-purple": "0 0 40px rgba(168, 85, 247, 0.4)",
        "glow-green": "0 0 40px rgba(34, 255, 136, 0.4)",
        "glow-pink": "0 0 40px rgba(244, 114, 182, 0.4)",
        "inner-glow": "inset 0 0 30px rgba(0, 245, 255, 0.1)",
        glass: "0 8px 32px rgba(0, 0, 0, 0.3)",
        "glass-lg": "0 16px 48px rgba(0, 0, 0, 0.4)",
      },
      borderRadius: {
        "2xl": "1rem",
        "3xl": "1.5rem",
        "4xl": "2rem",
      },
      backdropBlur: {
        xs: "2px",
      },
      animation: {
        "fade-in": "fadeIn 0.5s ease-out",
        "fade-up": "fadeUp 0.6s ease-out",
        "slide-up": "slideUp 0.4s ease-out",
        "slide-down": "slideDown 0.4s ease-out",
        "slide-in-right": "slideInRight 0.4s ease-out",
        "scale-in": "scaleIn 0.3s ease-out",
        "glow-pulse": "glowPulse 2s ease-in-out infinite",
        "float": "float 6s ease-in-out infinite",
        "shimmer": "shimmer 2s linear infinite",
        "gradient-x": "gradientX 3s ease infinite",
        "spin-slow": "spin 8s linear infinite",
        "bounce-subtle": "bounceSubtle 2s ease-in-out infinite",
        "pulse-glow": "pulseGlow 2s ease-in-out infinite",
      },
      keyframes: {
        fadeIn: {
          "0%": { opacity: "0" },
          "100%": { opacity: "1" },
        },
        fadeUp: {
          "0%": { opacity: "0", transform: "translateY(20px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        slideUp: {
          "0%": { opacity: "0", transform: "translateY(10px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        slideDown: {
          "0%": { opacity: "0", transform: "translateY(-10px)" },
          "100%": { opacity: "1", transform: "translateY(0)" },
        },
        slideInRight: {
          "0%": { opacity: "0", transform: "translateX(20px)" },
          "100%": { opacity: "1", transform: "translateX(0)" },
        },
        scaleIn: {
          "0%": { opacity: "0", transform: "scale(0.95)" },
          "100%": { opacity: "1", transform: "scale(1)" },
        },
        glowPulse: {
          "0%, 100%": { boxShadow: "0 0 20px rgba(0, 245, 255, 0.3)" },
          "50%": { boxShadow: "0 0 40px rgba(0, 245, 255, 0.6)" },
        },
        float: {
          "0%, 100%": { transform: "translateY(0)" },
          "50%": { transform: "translateY(-20px)" },
        },
        shimmer: {
          "0%": { backgroundPosition: "-200% 0" },
          "100%": { backgroundPosition: "200% 0" },
        },
        gradientX: {
          "0%, 100%": { backgroundPosition: "0% 50%" },
          "50%": { backgroundPosition: "100% 50%" },
        },
        bounceSubtle: {
          "0%, 100%": { transform: "translateY(0)" },
          "50%": { transform: "translateY(-5px)" },
        },
        pulseGlow: {
          "0%, 100%": { opacity: "0.6" },
          "50%": { opacity: "1" },
        },
      },
      transitionTimingFunction: {
        "bounce-in": "cubic-bezier(0.68, -0.55, 0.265, 1.55)",
        "smooth": "cubic-bezier(0.4, 0, 0.2, 1)",
      },
    },
  },
  plugins: [],
};
