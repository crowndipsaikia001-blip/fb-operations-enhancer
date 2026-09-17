# ⩜⃝☠️_L➿P_automation_777

**LOOP_Automated / AGF_automated**

This repository contains the evolving F&B Operations Enhancer and the private owner briefing interface for LOOP_Automated.

## Owner briefing

The main web experience is designed as a readable, interactive presentation rather than a raw document. It includes:

- Owner View for the business story
- Full Blueprint mode for deeper technical context
- Guided navigation through the project concept
- Closed-loop operating model
- Inventory and leakage example
- Human-in-the-loop control model
- AI sequencing
- Five-phase roadmap
- Current build status
- Pilot measurement framework
- Long-term vision

### GitHub Pages

The project includes a GitHub Actions deployment workflow for a static owner briefing site.

Expected public URL:

`https://crowndipsaikia001-blip.github.io/fb-operations-enhancer/`

To publish it the first time, open **Settings → Pages** in the repository and select **GitHub Actions** as the build and deployment source. Subsequent pushes to `main` will trigger the deployment workflow.

## Current application stack

The application is built with Next.js and uses Supabase as the backend foundation. The existing MVP database architecture covers properties, people, roles, inventory, stock movements, transfers, purchase orders, wastage workflows, POS tickets, audit logging and Row Level Security.

The operational UI is being developed in stages. The owner briefing is currently the public-facing presentation layer for the project.

## Development

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Security

Keep `.env.local` and all service keys out of Git. The Supabase service role key must remain server-side.
