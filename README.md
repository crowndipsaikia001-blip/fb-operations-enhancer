This is a [Next.js](https://nextjs.org) project bootstrapped with [`create-next-app`](https://nextjs.org/docs/app/api-reference/cli/create-next-app).

## Getting Started

First, run the development server:

```bash
npm run dev
# or
yarn dev
# or
pnpm dev
# or
bun dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

You can start editing the page by modifying `app/page.tsx`. The page auto-updates as you edit the file.

This project uses [`next/font`](https://nextjs.org/docs/app/building-your-application/optimizing/fonts) to automatically optimize and load [Geist](https://vercel.com/font), a new font family for Vercel.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app).

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.

# fb-operations-enhancer

---

## Local development — env vars, ports, and helper scripts

This project uses Supabase as the backend. Create a local environment file by copying `.env.example` to `.env.local` and filling in your keys. Example:

```text
cp .env.example .env.local
# then edit .env.local to replace placeholder values
```

Required env var names (already used in code):
- NEXT_PUBLIC_SUPABASE_URL — the Supabase project URL (public)
- NEXT_PUBLIC_SUPABASE_ANON_KEY — the anon/public key (client safe)
- SUPABASE_SERVICE_ROLE_KEY — service role key (server-only; keep secret)

Do NOT commit `.env.local` or any files that contain secret keys.

Start the dev server (default port 3000):

```bash
npm install
npm run dev
# or to run on a different port for this terminal session:
PORT=3001 npm run dev
# (Windows PowerShell): $env:PORT="3001"; npm run dev
```

If a process is already listening on the dev port and you need to free it quickly, use the helper scripts in the `scripts/` directory.

PowerShell (Windows):

```powershell
# Run from repo root. Pass an optional port number (default 3000):
.
\scripts\kill-port.ps1 -Port 3000
```

Unix / WSL / macOS:

```bash
# Make it executable once: chmod +x scripts/kill-port.sh
./scripts/kill-port.sh 3000
```

To change the default port permanently for your shell, set the PORT environment variable or update your run script.

---

If you want, I added a .env.example and small kill-port helper scripts to `scripts/`. Let me know if you'd like me to instead open a pull request with these changes or place the scripts under a different path.
