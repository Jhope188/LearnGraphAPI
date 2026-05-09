# 🪄 Hogwarts Spellcaster — Declarative Agent for Microsoft 365 Copilot

> *"Every great wizard in history has started out as nothing more than what we are now: students."*

A Harry Potter themed **declarative agent** that lives inside Microsoft 365 Copilot. Tell it what you need and it will find the perfect spell from its comprehensive spellbook — or **create an entirely new one** — complete with Latin incantation, wand movement, difficulty level, and wizarding history.

---

## 🏰 What It Does

| Prompt | What Happens |
|--------|-------------|
| *"I keep losing my keys"* | Recommends **Accio** (Summoning Charm) with casting tips |
| *"Protect my house from intruders"* | Suggests layered protection: **Cave Inimicum**, **Protego Totalum**, **Salvio Hexia** |
| *"I need to stay awake in meetings"* | Creates a new spell: **Vigilus Perpetua** with full backstory |
| *"What's the best duel strategy?"* | Provides a tactical spell sequence with reasoning |
| *"Create a spell to organise my desk"* | Invents **Ordinatum** from Latin roots with wand movement and limitations |

### Capabilities

- 🔍 **Find Spells** — searches a 60+ spell knowledge base for the perfect match
- 🪄 **Create Spells** — invents new spells with proper Latin etymology and magical rules
- ⚔️ **Duel Strategy** — recommends combat spell sequences with tactical reasoning
- 🔧 **Troubleshooting** — diagnoses why a spell isn't working and how to fix your technique
- 🎨 **Image Generation** — can create visual depictions of spells via GraphicArt capability
- 🌐 **Web Search** — searches Harry Potter Wiki and Wizarding World for additional lore

---

## 📁 Project Structure

```
HogwartsSpellcaster/
├── appPackage/
│   ├── manifest.json              # M365 app manifest (Teams app definition)
│   ├── declarativeAgent.json      # Agent manifest (instructions, capabilities, starters)
│   ├── instructions.txt           # Detailed agent behaviour instructions
│   ├── spellbook.txt              # Comprehensive spell knowledge base (60+ spells)
│   ├── color.png                  # App icon — 192×192 color
│   └── outline.png                # App icon — 32×32 outline
├── env/
│   └── .env.dev                   # Environment variables (auto-populated on provision)
├── teamsapp.yml                   # Microsoft 365 Agents Toolkit lifecycle config
├── .gitignore
└── README.md                      # This file
```

---

## 🚀 Prerequisites

| Requirement | Details |
|-------------|---------|
| **Microsoft 365 Copilot** | Active licence on your tenant |
| **VS Code** | With [Microsoft 365 Agents Toolkit](https://marketplace.visualstudio.com/items?itemName=TeamsDevApp.ms-teams-vscode-extension) extension |
| **M365 Account** | With permissions to upload custom apps |
| **Node.js** | v20+ (for Agents Toolkit) |

---

## ⚡ Getting Started

### Step 1: Install the Agents Toolkit

1. Open VS Code
2. Go to Extensions (`Cmd+Shift+X`)
3. Search for **"Microsoft 365 Agents Toolkit"**
4. Install it

### Step 2: Open the Project

1. Open VS Code
2. **File → Open Folder** → navigate to `HogwartsSpellcaster/`
3. The Agents Toolkit should recognise the project automatically

### Step 3: Sign In

1. Click the **Microsoft 365 Agents Toolkit** icon in the sidebar
2. Under **Accounts**, sign in to your Microsoft 365 account
3. Ensure your account has Copilot licensing

### Step 4: Provision the Agent

1. In the Agents Toolkit sidebar, find **Lifecycle**
2. Click **Provision**
3. Select the **dev** environment
4. Wait for provisioning to complete (creates the app registration in your tenant)

### Step 5: Test in Copilot

1. Open [Microsoft 365 Copilot](https://m365.cloud.microsoft/chat)
2. Click the conversation drawer icon (next to **New Chat**)
3. Find and select **Hogwarts Spellcaster**
4. Try one of the conversation starters or ask your own question!

---

## 🧙‍♂️ Using the Agent in Microsoft 365 Copilot

Once provisioned, the Hogwarts Spellcaster is available inside Microsoft 365 Copilot. Here's how to find it, use it, and get the most out of it.

### Finding the Agent

#### Option A: Via Copilot Chat (Recommended)
1. Go to [https://m365.cloud.microsoft/chat](https://m365.cloud.microsoft/chat)
2. In the top-right of the chat window, click the **agent picker icon** (💬 conversation drawer, next to "New Chat")
3. Browse or search for **"Hogwarts Spellcaster"**
4. Click it to start a conversation with the agent

#### Option B: Via Microsoft Teams
1. Open **Microsoft Teams**
2. Go to **Chat** → **Copilot** (or open the Copilot side panel)
3. Click the **agent picker** at the top of the Copilot panel
4. Search for **"Hogwarts Spellcaster"** and select it

#### Option C: Via the @ Mention
1. In any Copilot chat, type **@Hogwarts Spellcaster**
2. The agent will be invoked inline for that message

> **💡 Tip:** If you don't see the agent, ensure provisioning completed successfully and that your account has a Microsoft 365 Copilot licence.

### Starting a Conversation

When you open the agent, you'll see **6 conversation starters** as clickable buttons:

| Click This | What You'll Get |
|------------|----------------|
| 🔑 **I Keep Losing Things** | A detailed breakdown of the **Accio** (Summoning Charm) with casting tips |
| 🛡️ **Protect My Home** | A layered defence strategy using multiple protective spells |
| 📚 **Help Me Study** | A brand-new invented spell for concentration and memory |
| ⚔️ **Duel Strategy** | A tactical spell sequence with opening, defence, and finisher |
| 🪄 **Invent a Spell** | A completely original spell with Latin incantation and backstory |
| 🌧️ **Fix the Weather** | Weather-related spell recommendations from the spellbook |

Or just type any question in natural language — the agent stays fully in character.

### Example Prompts to Try

Here are some prompts that showcase different agent skills:

#### 🔍 Find an Existing Spell
> *"What spell would help me unlock a locked door?"*
>
> *"Is there a spell to make objects lighter?"*
>
> *"What's the best healing spell for minor injuries?"*

#### 🪄 Invent a New Spell
> *"Create a spell that instantly sorts my email inbox"*
>
> *"I need a spell that translates any language in real time"*
>
> *"Invent a spell that makes my coffee the perfect temperature"*

#### ⚔️ Duel Strategy
> *"Someone just cast Stupefy at me — what's my counter?"*
>
> *"Plan a duel strategy against a more experienced wizard"*
>
> *"What's the best non-lethal spell sequence to win a duel?"*

#### 📊 Compare Spells
> *"What's the difference between Stupefy and Petrificus Totalus?"*
>
> *"Compare Protego vs Protego Totalum — when should I use each?"*

#### 🔧 Troubleshooting
> *"My Patronus keeps fading — what am I doing wrong?"*
>
> *"I can't get Wingardium Leviosa to work properly"*

#### 🎨 Generate Spell Art
> *"Show me what the Expecto Patronum spell looks like when cast"*
>
> *"Create an image of a wizard casting Protego in a dark corridor"*

### How the Agent Works Behind the Scenes

```
You type: "I need to protect my campsite while traveling"
         │
         ▼
┌─────────────────────────────────────────────┐
│  1. INSTRUCTIONS (instructions.txt)         │
│     Agent personality, response rules,      │
│     output format, safety guidelines        │
│                                             │
│  2. EMBEDDED KNOWLEDGE (spellbook.txt)      │
│     Searches 60+ spells for matches:        │
│     → Cave Inimicum (protection boundary)   │
│     → Salvio Hexia (anti-hex ward)          │
│     → Protego Totalum (area shield)         │
│                                             │
│  3. WEB SEARCH (if needed)                  │
│     → harrypotter.fandom.com                │
│     → wizardingworld.com                    │
│                                             │
│  4. RESPONSE                                │
│     Structured spell recommendation with    │
│     incantations, wand movements, tips      │
└─────────────────────────────────────────────┘
```

### Important Notes

- **Stay in character** — The agent responds as a Hogwarts professor. It won't break character unless explicitly asked.
- **Disclaimer** — A disclaimer appears at the start of each conversation confirming this is for entertainment/educational purposes.
- **Dark Arts** — If you ask about Unforgivable Curses, the agent provides educational context with clear warnings about their illegality in the wizarding world.
- **Suggestions** — Follow-up prompt suggestions are enabled, so the agent will suggest next questions after each response.

---

## 🧙‍♂️ Conversation Starters

The agent comes with 6 themed conversation starters:

| Starter | Prompt |
|---------|--------|
| 🔑 I Keep Losing Things | *"I always misplace my keys, phone, and wallet. Is there a spell that can help me find lost objects?"* |
| 🛡️ Protect My Home | *"What spells would you recommend to magically protect my house from intruders?"* |
| 📚 Help Me Study | *"I have exams coming up and I can't focus. Create a spell that helps with concentration and memory."* |
| ⚔️ Duel Strategy | *"If I was challenged to a wizard's duel, what spell sequence should I use to win?"* |
| 🪄 Invent a Spell | *"I want a brand new spell that can organise my entire messy room instantly. Create one for me!"* |
| 🌧️ Fix the Weather | *"It's raining and I want sunshine. Is there a spell to control the weather?"* |

---

## 📚 Spellbook Knowledge Base

The embedded spellbook contains **60+ fully documented spells** across these categories:

| Category | Examples | Count |
|----------|----------|-------|
| **Charms** | Accio, Expelliarmus, Expecto Patronum, Wingardium Leviosa | 25+ |
| **Transfiguration** | Avifors, Vera Verto, Draconifors | 4 |
| **Defensive Spells** | Protego, Stupefy, Impedimenta, Petrificus Totalus | 8+ |
| **Hexes & Jinxes** | Bat-Bogey Hex, Levicorpus, Tarantallegra | 10+ |
| **Dark Arts** | Unforgivable Curses (educational only), Sectumsempra | 5 |
| **Household/Utility** | Scourgify, Reparo, Impervius, Pack | 6+ |
| **Transport** | Apparition, Portus, Point Me | 3 |
| **Spell Creation Rules** | Latin root construction, wand movements, difficulty scaling | — |

Each spell entry includes: incantation, type, difficulty, effect, wand movement, when to use, famous uses, counter-spells, and teaching notes.

---

## 🔧 Customisation

### Adding Knowledge Sources

To ground the agent in your SharePoint content (e.g., Hogwarts SharePoint sites), add to `declarativeAgent.json`:

```json
{
  "name": "OneDriveAndSharePoint",
  "items_by_url": [
    {
      "url": "https://inforcer2m365.sharepoint.com/sites/HogwartsLibrary"
    }
  ]
}
```

### Adding Teams Messages as Knowledge

```json
{
  "name": "TeamsMessages",
  "urls": [
    {
      "url": "https://teams.microsoft.com/l/channel/..."
    }
  ]
}
```

### Connecting to the Entra Agent Identities

The Hogwarts Spellcaster can be connected to the [Agent ID blueprints](../README-Agent-Identities.md) already deployed in the tenant. For example, **Madam Pince** (Library Keeper) could serve as a knowledge retrieval backend, while **Hedwig** (Owl Post) could route spell recommendations to Teams channels.

### Modifying Instructions

Edit `appPackage/instructions.txt` to change the agent's personality, add new skills, or adjust its response format. Re-provision after changes.

### Adding API Plugins (Actions)

To give the agent the ability to call external APIs (e.g., a spell database API), create an API plugin manifest and reference it in `declarativeAgent.json`:

```json
{
  "actions": [
    {
      "id": "spellDatabasePlugin",
      "file": "spellDatabase-plugin.json"
    }
  ]
}
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│              MICROSOFT 365 COPILOT                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   User Prompt: "I need a spell to find lost items"      │
│           │                                             │
│           ▼                                             │
│   ┌───────────────────────────┐                         │
│   │  Hogwarts Spellcaster     │                         │
│   │  (Declarative Agent)      │                         │
│   │                           │                         │
│   │  instructions.txt ────────┤─── Agent personality    │
│   │  EmbeddedKnowledge ───────┤─── spellbook.txt (60+)  │
│   │  WebSearch ───────────────┤─── HP Wiki / WW.com     │
│   │  GraphicArt ──────────────┤─── Spell visualisation  │
│   │  CodeInterpreter ─────────┤─── Spell calculations   │
│   └───────────┬───────────────┘                         │
│               │                                         │
│               ▼                                         │
│   "Ah, a seeker of lost items! You need the             │
│    Summoning Charm — Accio! Simply point your           │
│    wand and say 'Accio keys!' with a sharp              │
│    flick toward yourself..."                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 📦 Publishing

### To Your Organisation

1. In Agents Toolkit sidebar → **Lifecycle** → **Publish**
2. An admin can then approve the app in the [Teams Admin Center](https://admin.teams.microsoft.com)
3. Once approved, all licensed users can find **Hogwarts Spellcaster** in their Copilot agents list

### To Specific Users (Sideloading)

1. **Provision** creates the app package in `appPackage/build/`
2. The `.zip` file can be manually uploaded via Teams Admin Center
3. Assign to specific users or groups for testing

---

## 🔗 Related Resources

| Resource | Link |
|----------|------|
| Declarative Agents Overview | [learn.microsoft.com](https://learn.microsoft.com/microsoft-365-copilot/extensibility/overview-declarative-agent) |
| Agent Manifest Schema v1.6 | [learn.microsoft.com](https://learn.microsoft.com/microsoft-365-copilot/extensibility/declarative-agent-manifest-1.6) |
| Agents Toolkit Tutorial | [learn.microsoft.com](https://learn.microsoft.com/microsoft-365-copilot/extensibility/build-declarative-agents) |
| Writing Effective Instructions | [learn.microsoft.com](https://learn.microsoft.com/microsoft-365-copilot/extensibility/declarative-agent-instructions) |
| Agent Builder in Copilot | [learn.microsoft.com](https://learn.microsoft.com/microsoft-365-copilot/extensibility/agent-builder) |
| IAC Agent Identity Config | [IAC-Agent-Identity-Configuration-Guide.md](../../Inforcer%20Baseline%20Documentation/Agent%20Docs/IAC-Agent-Identity-Configuration-Guide.md) |

---

## 📋 Tenant Context

| Property | Value |
|----------|-------|
| **Tenant** | Inforcer2m365.onmicrosoft.com |
| **Tenant ID** | `e37d43b7-ff48-444b-9d44-fbd4477c18f3` |
| **Developer** | Jon Hope |
| **Created** | February 2026 |
| **Schema Version** | Declarative Agent Manifest v1.6 |
| **Toolkit** | Microsoft 365 Agents Toolkit v6.0+ |

---

> *"It does not do to dwell on dreams and forget to live. But it is perfectly fine to dwell on spells and forget everything else."* 🪄
