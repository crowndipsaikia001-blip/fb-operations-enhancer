import { prisma } from "@/lib/prisma";

export const dynamic = "force-dynamic";

type TaskWithPerson = {
  id: string;
  title: string;
  status: string;
  completed_at: Date | null;
  created_at: Date;
  people: { full_name: string } | null;
};

function formatTime(value: Date | null) {
  if (!value) return "—";
  return new Intl.DateTimeFormat("en-IN", {
    hour: "2-digit",
    minute: "2-digit",
  }).format(value);
}

function statusLabel(status: string) {
  return status.replaceAll("_", " ").toUpperCase();
}

export default async function Home() {
  const [property, people, sections, sops, tasks] = await Promise.all([
    prisma.properties.findFirst({ orderBy: { created_at: "asc" } }),
    prisma.people.findMany({
      include: { roles: true },
      orderBy: { full_name: "asc" },
    }),
    prisma.sections.findMany({ orderBy: { name: "asc" } }),
    prisma.sops.findMany({ orderBy: { created_at: "asc" } }),
    prisma.tasks.findMany({
      include: { people: true },
      orderBy: [{ status: "asc" }, { created_at: "desc" }],
    }),
  ]);

  const pending = tasks.filter((task) => task.status.toLowerCase() === "pending").length;
  const completed = tasks.filter((task) => task.status.toLowerCase() === "completed").length;

  return (
    <main className="min-h-screen bg-slate-950 text-slate-100">
      <div className="mx-auto max-w-7xl px-6 py-8 lg:px-10">
        <header className="mb-8 flex flex-col gap-4 border-b border-slate-800 pb-6 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.25em] text-cyan-400">
              L∞P Operations Control
            </p>
            <h1 className="mt-2 text-3xl font-semibold tracking-tight">
              {property?.name ?? "L∞P"}
            </h1>
            <p className="mt-1 text-sm text-slate-400">
              Read-only foundation connected to the existing production database.
            </p>
          </div>
          <div className="rounded-xl border border-emerald-500/20 bg-emerald-500/10 px-4 py-3 text-sm">
            <span className="mr-2 inline-block h-2 w-2 rounded-full bg-emerald-400" />
            Database connected
          </div>
        </header>

        <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Metric title="Pending tasks" value={pending} tone="amber" />
          <Metric title="Completed tasks" value={completed} tone="emerald" />
          <Metric title="People" value={people.length} tone="cyan" />
          <Metric title="Sections" value={sections.length} tone="violet" />
        </section>

        <div className="mt-8 grid gap-6 lg:grid-cols-[1.6fr_1fr]">
          <section className="rounded-2xl border border-slate-800 bg-slate-900/70">
            <div className="flex items-center justify-between border-b border-slate-800 px-5 py-4">
              <div>
                <h2 className="font-semibold">Operational tasks</h2>
                <p className="text-xs text-slate-500">Existing production tasks</p>
              </div>
              <span className="rounded-full bg-slate-800 px-3 py-1 text-xs text-slate-300">
                {tasks.length} total
              </span>
            </div>

            <div className="divide-y divide-slate-800">
              {tasks.length === 0 ? (
                <div className="px-5 py-10 text-center text-sm text-slate-500">
                  No tasks currently recorded.
                </div>
              ) : (
                tasks.map((task: TaskWithPerson) => (
                  <div key={task.id} className="px-5 py-4">
                    <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                      <div>
                        <h3 className="font-medium text-slate-100">{task.title}</h3>
                        <p className="mt-1 text-sm text-slate-400">
                          Assigned to: {task.people?.full_name ?? "Unassigned"}
                        </p>
                      </div>
                      <span
                        className={`w-fit rounded-full px-2.5 py-1 text-[11px] font-semibold ${
                          task.status.toLowerCase() === "completed"
                            ? "bg-emerald-400/10 text-emerald-300"
                            : "bg-amber-400/10 text-amber-300"
                        }`}
                      >
                        {statusLabel(task.status)}
                      </span>
                    </div>
                    <p className="mt-2 text-xs text-slate-500">
                      Created {formatTime(task.created_at)}
                      {task.completed_at ? ` • Completed ${formatTime(task.completed_at)}` : ""}
                    </p>
                  </div>
                ))
              )}
            </div>
          </section>

          <div className="space-y-6">
            <section className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
              <h2 className="font-semibold">People & authority</h2>
              <div className="mt-4 space-y-3">
                {people.map((person) => (
                  <div key={person.id} className="flex items-center justify-between gap-4">
                    <span className="text-sm">{person.full_name}</span>
                    <span className="rounded-full bg-slate-800 px-2.5 py-1 text-[11px] text-slate-300">
                      {person.roles?.name ?? "No role"}
                    </span>
                  </div>
                ))}
              </div>
            </section>

            <section className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
              <h2 className="font-semibold">Operational sections</h2>
              <div className="mt-4 grid grid-cols-1 gap-2">
                {sections.map((section) => (
                  <div
                    key={section.id}
                    className="rounded-lg border border-slate-800 bg-slate-950/50 px-3 py-2 text-sm text-slate-300"
                  >
                    {section.name}
                  </div>
                ))}
              </div>
            </section>
          </div>
        </div>

        <section className="mt-6 rounded-2xl border border-slate-800 bg-slate-900/70">
          <div className="border-b border-slate-800 px-5 py-4">
            <h2 className="font-semibold">Current SOP library</h2>
            <p className="text-xs text-slate-500">
              These are the SOPs already stored in production. No records are modified by this screen.
            </p>
          </div>
          <div className="grid gap-3 p-5 md:grid-cols-2">
            {sops.map((sop) => (
              <article key={sop.id} className="rounded-xl border border-slate-800 p-4">
                <div className="flex items-center justify-between gap-3">
                  <h3 className="font-medium">{sop.title}</h3>
                  <span className="text-[10px] uppercase tracking-wider text-cyan-400">
                    {sop.category ?? "general"}
                  </span>
                </div>
                <p className="mt-2 text-sm leading-6 text-slate-400">{sop.content}</p>
              </article>
            ))}
          </div>
        </section>

        <footer className="mt-8 border-t border-slate-800 pt-5 text-xs text-slate-500">
          Phase 1: live read-only dashboard. Roster changes, approvals, task completion and audit logging
          will be added only after the production schema is reconciled and migration strategy is approved.
        </footer>
      </div>
    </main>
  );
}

function Metric({
  title,
  value,
  tone,
}: {
  title: string;
  value: number;
  tone: "amber" | "emerald" | "cyan" | "violet";
}) {
  const toneClass = {
    amber: "text-amber-300",
    emerald: "text-emerald-300",
    cyan: "text-cyan-300",
    violet: "text-violet-300",
  }[tone];

  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/70 p-5">
      <p className="text-xs uppercase tracking-wider text-slate-500">{title}</p>
      <p className={`mt-2 text-3xl font-semibold ${toneClass}`}>{value}</p>
    </div>
  );
}
