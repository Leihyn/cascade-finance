# Bank of Mantle - 6 Frontend Design Variations

Each design includes complete specifications for colors, typography, components, and animations. All can be implemented by updating `globals.css` and minimal component changes.

---

## 1. Classic Banking (Current) - Institutional Elegance

**Philosophy**: Traditional bank meets modern DeFi. Trust, stability, premium services.

### Color Palette
```css
--bg-primary: #0A1628;        /* Deep navy */
--bg-secondary: #0F1F3A;      /* Medium navy */
--bg-tertiary: #162844;       /* Light navy */
--accent-gold: #D4AF37;       /* Premium gold */
--accent-gold-light: #F4E5B8; /* Champagne */
--accent-royal: #3B82F6;      /* Royal blue */
--text-primary: #F8FAFC;      /* Off-white */
--text-secondary: #CBD5E1;    /* Light gray */
```

### Typography
- **Headers**: Space Grotesk (professional, geometric)
- **Body**: Inter (clean, readable)
- **Numbers**: Tabular nums (aligned digits)

### Key Elements
- **Buttons**: Gold gradient with subtle glow
- **Cards**: Dark navy with gold borders, glass effect
- **Background**: Animated radial gradients (gold/navy)
- **Icons**: Landmark (bank building), professional line icons
- **Animations**: Smooth, dignified (no bouncing)

### Best For
Traditional finance users, institutional clients, conservative traders

---

## 2. DeFi Cyberpunk - Neon Future

**Philosophy**: Crypto-native, high-energy, futuristic. The Matrix meets Wall Street.

### Color Palette
```css
--bg-primary: #0a0e1a;        /* Almost black */
--bg-secondary: #111827;      /* Dark gray */
--bg-tertiary: #1f2937;       /* Charcoal */
--neon-cyan: #00F5FF;         /* Electric cyan */
--neon-magenta: #FF00FF;      /* Hot pink */
--neon-yellow: #FFFF00;       /* Laser yellow */
--neon-green: #39FF14;        /* Radioactive green */
--neon-purple: #BC13FE;       /* Electric purple */
--text-primary: #F0F0F0;      /* Bright white */
--text-neon: #00F5FF;         /* Cyan text */
```

### Typography
- **Headers**: Orbitron / Rajdhani (futuristic, angular)
- **Body**: JetBrains Mono (monospace for tech vibe)
- **Numbers**: Monospace with glow effect

### Key Elements
- **Buttons**: Neon borders with scanline animation
  ```css
  background: transparent;
  border: 2px solid #00F5FF;
  box-shadow: 0 0 20px rgba(0, 245, 255, 0.5),
              inset 0 0 20px rgba(0, 245, 255, 0.1);
  text-shadow: 0 0 10px #00F5FF;
  animation: neonPulse 2s infinite;
  ```

- **Cards**: Dark with glowing neon edges, scanlines
  ```css
  background: linear-gradient(135deg, #111827 0%, #1f2937 100%);
  border: 1px solid #00F5FF;
  box-shadow: 0 0 30px rgba(0, 245, 255, 0.3);
  position: relative;
  &::before { /* Scanlines overlay */ }
  ```

- **Background**: Grid pattern with moving particles
  ```css
  background-image:
    linear-gradient(rgba(0, 245, 255, 0.1) 1px, transparent 1px),
    linear-gradient(90deg, rgba(0, 245, 255, 0.1) 1px, transparent 1px);
  background-size: 50px 50px;
  animation: gridMove 20s linear infinite;
  ```

- **Icons**: Hexagonal shapes, circuit board patterns
- **Animations**: Glitch effects, neon pulse, data streams
- **Extras**: CRT screen effect, RGB split on hover, terminal-style text input

### Best For
Crypto enthusiasts, gamers, younger demographic, high-risk traders

---

## 3. Minimalist Nordic - Scandinavian Clean

**Philosophy**: Less is more. Clarity, simplicity, usability. Apple-inspired.

### Color Palette
```css
--bg-primary: #FFFFFF;        /* Pure white */
--bg-secondary: #F9FAFB;      /* Off-white */
--bg-tertiary: #F3F4F6;       /* Light gray */
--accent-primary: #111827;    /* Almost black */
--accent-blue: #3B82F6;       /* Clean blue */
--accent-green: #10B981;      /* Success green */
--accent-red: #EF4444;        /* Alert red */
--text-primary: #111827;      /* Dark text */
--text-secondary: #6B7280;    /* Mid gray */
--border: #E5E7EB;            /* Light border */
```

### Typography
- **Headers**: SF Pro Display / Inter (system fonts, clean)
- **Body**: SF Pro Text / Inter
- **Numbers**: System monospace

### Key Elements
- **Buttons**: Solid colors, no gradients, subtle shadow
  ```css
  background: #3B82F6;
  color: white;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  transition: all 0.2s ease;
  &:hover {
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.2);
  }
  ```

- **Cards**: White with subtle shadows, generous padding
  ```css
  background: white;
  border-radius: 16px;
  border: 1px solid #E5E7EB;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  padding: 32px;
  ```

- **Background**: Pure white or very subtle texture
  ```css
  background: #FFFFFF;
  /* OR subtle noise texture */
  background-image: url("data:image/svg+xml,..."); /* 2% opacity noise */
  ```

- **Icons**: Simple line icons, 1-2px stroke
- **Animations**: Micro-interactions only, spring physics
- **Spacing**: Generous whitespace (16px, 24px, 32px, 48px scale)
- **Typography**: Excellent hierarchy with size/weight only

### Best For
Professional users, institutions, users who value clarity over flash

---

## 4. Dark Neumorphic - Soft & Tactile

**Philosophy**: Skeuomorphic meets modern. Tactile, soft, 3D depth without gradients.

### Color Palette
```css
--bg-primary: #1e1e2e;        /* Dark purple-gray */
--bg-secondary: #25253a;      /* Slightly lighter */
--bg-tertiary: #2d2d44;       /* Even lighter */
--shadow-dark: #16161f;       /* Darker shadow */
--shadow-light: #2d2d44;      /* Lighter highlight */
--accent-purple: #B4BEFE;     /* Soft purple */
--accent-pink: #F5C2E7;       /* Soft pink */
--accent-blue: #89B4FA;       /* Soft blue */
--text-primary: #CDD6F4;      /* Soft white */
--text-secondary: #A6ADC8;    /* Muted */
```

### Typography
- **Headers**: Nunito / Quicksand (rounded, soft)
- **Body**: Inter / Work Sans
- **Numbers**: Rounded monospace

### Key Elements
- **Buttons**: Extruded neumorphic effect
  ```css
  background: #1e1e2e;
  border-radius: 16px;
  box-shadow:
    5px 5px 10px #16161f,
    -5px -5px 10px #2d2d44;
  transition: all 0.3s ease;

  &:active {
    box-shadow:
      inset 3px 3px 6px #16161f,
      inset -3px -3px 6px #2d2d44;
  }
  ```

- **Cards**: Soft pressed effect
  ```css
  background: #1e1e2e;
  border-radius: 24px;
  box-shadow:
    8px 8px 16px #16161f,
    -8px -8px 16px #2d2d44;
  padding: 32px;
  ```

- **Inputs**: Inset neumorphic
  ```css
  background: #1e1e2e;
  border-radius: 12px;
  box-shadow:
    inset 4px 4px 8px #16161f,
    inset -4px -4px 8px #2d2d44;
  border: none;
  ```

- **Background**: Subtle gradient with soft shapes
  ```css
  background: linear-gradient(135deg, #1e1e2e 0%, #25253a 100%);
  ```

- **Icons**: Rounded, soft shadows
- **Animations**: Smooth press/release, floating elements
- **Extras**: Everything looks touchable/pressable, soft glows instead of hard shadows

### Best For
Users who like tactile UI, Apple users, modern aesthetic lovers

---

## 5. Gradient Maximalist - Bold & Colorful

**Philosophy**: More is more. Energy, excitement, playful. Stripe/Linear-inspired.

### Color Palette
```css
--bg-primary: #0F0F1E;        /* Very dark blue */
--bg-secondary: #1A1A2E;      /* Dark blue */
--gradient-1: linear-gradient(135deg, #667eea 0%, #764ba2 100%); /* Purple */
--gradient-2: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); /* Pink */
--gradient-3: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%); /* Blue */
--gradient-4: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%); /* Green */
--gradient-5: linear-gradient(135deg, #fa709a 0%, #fee140 100%); /* Sunset */
--gradient-6: linear-gradient(135deg, #30cfd0 0%, #330867 100%); /* Ocean */
--gradient-mesh: conic-gradient(from 180deg, #667eea, #764ba2, #f093fb, #f5576c, #4facfe);
--text-primary: #FFFFFF;
--text-gradient: linear-gradient(135deg, #667eea 0%, #f5576c 100%);
```

### Typography
- **Headers**: Poppins / Montserrat (bold, rounded)
- **Body**: Inter / DM Sans
- **Numbers**: Bold with gradient fill

### Key Elements
- **Buttons**: Animated gradient backgrounds
  ```css
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  background-size: 200% 200%;
  animation: gradientShift 3s ease infinite;
  border-radius: 12px;
  box-shadow: 0 8px 32px rgba(102, 126, 234, 0.4);
  position: relative;
  overflow: hidden;

  &::before {
    content: '';
    position: absolute;
    inset: -2px;
    background: linear-gradient(45deg, #667eea, #764ba2, #f093fb, #f5576c);
    background-size: 400% 400%;
    animation: gradientBorder 3s ease infinite;
    border-radius: 12px;
    z-index: -1;
    filter: blur(20px);
  }
  ```

- **Cards**: Glass morphism with gradient borders
  ```css
  background: rgba(26, 26, 46, 0.7);
  backdrop-filter: blur(20px);
  border-radius: 24px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  position: relative;

  &::before {
    content: '';
    position: absolute;
    inset: 0;
    padding: 2px;
    background: linear-gradient(135deg, #667eea, #764ba2, #f093fb, #f5576c);
    -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
    -webkit-mask-composite: xor;
    mask-composite: exclude;
    border-radius: 24px;
  }
  ```

- **Background**: Animated gradient mesh
  ```css
  background:
    radial-gradient(circle at 20% 50%, rgba(102, 126, 234, 0.15) 0%, transparent 50%),
    radial-gradient(circle at 80% 80%, rgba(245, 87, 108, 0.15) 0%, transparent 50%),
    radial-gradient(circle at 40% 20%, rgba(74, 172, 254, 0.15) 0%, transparent 50%),
    linear-gradient(135deg, #0F0F1E 0%, #1A1A2E 100%);
  background-size: 200% 200%;
  animation: meshMove 20s ease infinite;
  ```

- **Icons**: Gradient fills, animated strokes
- **Animations**: Smooth gradient shifts, color morphing, wave effects
- **Extras**: Rainbow cursor trails, gradient text everywhere, animated blobs

### Best For
Young users, consumer apps, exciting/fun brand, risk-on attitude

---

## 6. Terminal/Hacker - Matrix Green

**Philosophy**: Command-line interface. Technical, precise, hacker aesthetic. Bloomberg Terminal meets Matrix.

### Color Palette
```css
--bg-primary: #000000;        /* Pure black */
--bg-secondary: #0a0a0a;      /* Almost black */
--bg-tertiary: #141414;       /* Dark gray */
--terminal-green: #00FF41;    /* Matrix green */
--terminal-green-dim: #00CC33; /* Dimmer green */
--terminal-amber: #FFB000;    /* Amber warning */
--terminal-red: #FF0000;      /* Error red */
--terminal-blue: #00AAFF;     /* Info blue */
--text-primary: #00FF41;      /* Green text */
--text-secondary: #00CC33;    /* Dim green */
--text-comment: #006622;      /* Dark green */
```

### Typography
- **Everything**: JetBrains Mono / Fira Code / Source Code Pro
- **Enable ligatures**: `font-variant-ligatures: contextual;`
- **Weights**: Only 400 and 700 (no medium)

### Key Elements
- **Buttons**: Terminal command style
  ```css
  background: transparent;
  border: 1px solid #00FF41;
  color: #00FF41;
  font-family: 'JetBrains Mono', monospace;
  padding: 8px 16px;
  position: relative;

  &::before {
    content: '> ';
    color: #00FF41;
  }

  &:hover {
    background: rgba(0, 255, 65, 0.1);
    box-shadow: 0 0 20px rgba(0, 255, 65, 0.3);
    animation: terminalBlink 1s infinite;
  }
  ```

- **Cards**: Terminal window style
  ```css
  background: #000000;
  border: 2px solid #00FF41;
  border-radius: 0; /* Sharp corners */
  font-family: 'JetBrains Mono', monospace;
  box-shadow: 0 0 30px rgba(0, 255, 65, 0.2);

  /* Terminal header bar */
  &::before {
    content: '█ BANK_OF_MANTLE.exe — Position Manager';
    display: block;
    background: #00FF41;
    color: #000000;
    padding: 4px 12px;
    margin: -16px -16px 16px -16px;
    font-weight: 700;
  }
  ```

- **Inputs**: Command line style
  ```css
  background: #0a0a0a;
  border: 1px solid #00FF41;
  color: #00FF41;
  font-family: 'JetBrains Mono', monospace;
  padding: 8px 12px;

  &::before {
    content: '$ ';
    color: #00FF41;
  }

  /* Blinking cursor */
  &::after {
    content: '█';
    animation: cursorBlink 1s infinite;
  }
  ```

- **Background**: Scanlines and matrix rain
  ```css
  background: #000000;
  position: relative;

  /* Scanlines */
  &::before {
    content: '';
    position: absolute;
    inset: 0;
    background: repeating-linear-gradient(
      0deg,
      rgba(0, 255, 65, 0.05) 0px,
      transparent 1px,
      transparent 2px
    );
    pointer-events: none;
    animation: scanlines 8s linear infinite;
  }

  /* Falling matrix characters */
  &::after {
    content: '';
    position: absolute;
    inset: 0;
    background-image: /* Matrix rain canvas/SVG */;
    pointer-events: none;
    opacity: 0.15;
  }
  ```

- **Icons**: ASCII art or simple brackets like `[X]`, `[✓]`
- **Animations**: Typewriter effect, cursor blink, scanline scroll
- **Layout**: Fixed-width columns, aligned text, ASCII borders
- **Extras**:
  - Boot sequence animation on load
  - Command history in sidebar
  - Status bar at bottom (like vim)
  - All text looks like terminal output
  - Numbers display as `0x` hex values

### UI Components Examples
```typescript
// Button component
<button className="terminal-btn">
  [EXECUTE_TRADE]
</button>

// Position card
<div className="terminal-window">
  ╔════════════════════════════════════╗
  ║ POSITION #0x1337                   ║
  ║ STATUS: ACTIVE                     ║
  ║ TYPE: PAY_FIXED                    ║
  ║ NOTIONAL: 10000.00 USDC            ║
  ║ PNL: +523.42 USDC [+5.23%]         ║
  ╚════════════════════════════════════╝
</div>

// Form input
<div className="terminal-input">
  $ ENTER_AMOUNT: <input />█
</div>
```

### Best For
Technical users, developers, hackers, nostalgic users, Bloomberg Terminal refugees

---

## Implementation Priority Ranking

Based on target audience and differentiation:

1. **Terminal/Hacker** (Most unique, technical users, memorable)
2. **DeFi Cyberpunk** (Crypto-native, energy, younger demo)
3. **Classic Banking** (Current - institutional, trust)
4. **Gradient Maximalist** (Modern, fun, consumer-friendly)
5. **Minimalist Nordic** (Professional, clarity)
6. **Dark Neumorphic** (Niche aesthetic, trendy)

---

## Quick Implementation Guide

### To switch designs:

1. **Choose a design** from above
2. **Update `frontend/app/globals.css`**:
   - Replace `:root` color variables
   - Replace `.neon-button` / `.gradient-text` / `.bg-mesh` styles
   - Add design-specific animations
3. **Update `frontend/app/page.tsx`**:
   - Change icon imports (Landmark → others)
   - Update button class names
   - Adjust card styling
4. **Update typography** in `tailwind.config.ts`:
   - Add new font families
   - Update font imports in globals.css
5. **Test responsive behavior**
6. **Adjust component-specific styles** as needed

### Font Installation
For custom fonts, add to `globals.css`:
```css
/* Example: Orbitron for Cyberpunk */
@import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@400;500;700;900&display=swap');

/* Or self-hosted via fontsource */
@import "@fontsource/orbitron/400.css";
@import "@fontsource/orbitron/700.css";
```

---

## Design System Files Structure

Each design should have:
```
frontend/
  styles/
    themes/
      classic-banking.css
      defi-cyberpunk.css
      minimalist-nordic.css
      dark-neumorphic.css
      gradient-maximalist.css
      terminal-hacker.css
```

Switch themes by importing different CSS file in `layout.tsx`.

---

## Recommended Design Based on Goals

| Goal | Recommended Design |
|------|-------------------|
| Institutional adoption | Classic Banking (current) or Minimalist Nordic |
| Crypto community | DeFi Cyberpunk or Terminal/Hacker |
| Mass market appeal | Gradient Maximalist or Minimalist Nordic |
| Stand out from competitors | Terminal/Hacker (most unique) |
| Professional traders | Terminal/Hacker or Classic Banking |
| Mobile-first | Minimalist Nordic or Classic Banking |
| Brand differentiation | Terminal/Hacker or DeFi Cyberpunk |

---

## Mix & Match Elements

You can also **combine elements** from multiple designs:
- Classic Banking base + Terminal/Hacker data displays
- Minimalist Nordic layout + Gradient Maximalist accents
- Dark Neumorphic cards + DeFi Cyberpunk buttons

The key is maintaining **visual consistency** within your choice.
