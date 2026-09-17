"use client";

import { useState } from "react";

const nav = [
  ["opening", "Opening"], ["problem", "The Problem"], ["system", "The System"],
  ["loop", "Closed Loop"], ["inventory", "Inventory"], ["control", "Human Control"],
  ["ai", "AI"], ["feasible", "Feasibility"], ["roi", "Business Impact"],
  ["roadmap", "Roadmap"], ["today", "Today"], ["pilot", "Pilot"], ["vision", "Vision"],
] as const;

const phases = [
  ["01", "Control Execution", "People, roles, tasks, SOPs, bookings, handovers and accountability.", "Reduce memory dependency."],
  ["02", "Control Cost", "Inventory, purchasing, wastage, payments and POS information.", "Identify and reduce preventable leakage."],
  ["03", "Understand Performance", "Dashboards, reports and measurable operating baselines.", "Understand what is actually happening."],
  ["04", "Automate Decisions", "Alerts, exception handling, workflow automation and intelligent routing.", "React to predictable operational situations."],
  ["05", "Scale", "Reusable property configuration while keeping the core platform consistent.", "Become a multi-property operating platform."],
];

const modules = [
  ["People & Roles", "Who works here, what they do, which property they belong to, and what they can access."],
  ["Tasks & SOPs", "What needs to happen, who owns it, when it is due, and whether it was completed."],
  ["Inventory", "What came in, what moved, what was sold, what was wasted, and what should be there now."],
  ["Purchasing", "What was ordered, from whom, at what cost, and for which property."],
  ["Wastage", "What was wasted, why, who reported it, and who authorised it."],
  ["POS", "Bring sales information into the operational layer so it can be compared with other records."],
  ["Audit Trail", "Keep a history of important changes so the business can reconstruct what happened."],
];

const questions = ["What is pending?", "What went wrong?", "Where is money stuck?", "Where is stock moving unexpectedly?", "Which tasks were missed?", "Which department needs attention?"];
const buildNext = ["Build the operational UI", "Connect authentication", "Build management dashboards", "Build task and SOP workflows", "Connect real operational data", "Test with actual venue activity", "Establish baseline measurements", "Automate proven workflows"];

export default function Home() {
  const [mode, setMode] = useState<"owner" | "deep">("owner");
  const [open, setOpen] = useState(false);
  const go = (id: string) => { document.getElementById(id)?.scrollIntoView({ behavior: "smooth" }); setOpen(false); };

  return (
    <main className="app">
      <div className="grain" />
      <header className="topbar">
        <button className="brand" onClick={() => go("opening")}>
          <span className="mark">⩜⃝☠️</span>
          <span><strong>_L➿P_automation_777</strong><small>AGF_automated / PRIVATE OWNER BRIEF</small></span>
        </button>
        <div className="top-actions">
          <div className="toggle"><button className={mode === "owner" ? "on" : ""} onClick={() => setMode("owner")}>Owner View</button><button className={mode === "deep" ? "on" : ""} onClick={() => setMode("deep")}>Full Blueprint</button></div>
          <button className="menu" onClick={() => setOpen(v => !v)} aria-label="Open navigation">☰</button>
        </div>
      </header>

      <aside className={`sidebar ${open ? "show" : ""}`}>
        <div className="eyebrow">PROJECT NAVIGATION</div>
        {nav.map(([id, label]) => <button key={id} onClick={() => go(id)}>{label}</button>)}
        <div className="side-status"><i /> <span><b>FOUNDATION</b><small>Architecture online</small></span></div>
      </aside>

      <div className="content">
        <section id="opening" className="hero anchor">
          <div className="eyebrow">2026 / OWNER PRESENTATION</div>
          <div className="hero-grid">
            <div>
              <div className="hero-mark">⩜⃝☠️</div>
              <h1>_L➿P_<br /><span>automation_777</span></h1>
              <h2>A digital operating layer for F&amp;B and entertainment.</h2>
              <p>I am building a system that connects people, tasks, SOPs, bookings, inventory, purchasing, wastage, POS, payments and management reporting into one operational flow.</p>
              <div className="hero-cta"><button className="primary" onClick={() => go("problem")}>Enter the Brief <b>↘</b></button><button onClick={() => setMode("deep")}>Full Blueprint</button></div>
            </div>
            <div className="status-card">
              <div className="card-head"><span>OPERATING STATUS</span><b>01 / 05</b></div>
              <h3><i /> FOUNDATION</h3>
              <p><span>Architecture</span><b>DEFINED</b></p><p><span>Backend model</span><b>READY</b></p><p><span>Operational UI</span><b>BUILD NEXT</b></p><p><span>Automation</span><b>ROADMAP</b></p>
              <div className="meter"><i /></div><small>The current repository already contains the core backend foundation. The next step is turning it into the working operational interface.</small>
            </div>
          </div>
          <div className="scroll">SCROLL TO EXPLORE <span>↓</span></div>
        </section>

        <section id="problem" className="section anchor">
          <div className="eyebrow">01 / THE REASON</div><div className="heading"><h2>The problem is not always people.<br /><span>It is the way information moves.</span></h2><p>During busy operations, information gets scattered across memory, calls, WhatsApp, spreadsheets and verbal handovers.</p></div>
          <div className="cards four">{[["01","Someone remembers","A manager remembers a booking. A supervisor remembers a pending issue. A captain remembers a guest requirement."],["02","Someone follows up","Calls, messages, spreadsheets and reminders fill the gaps between departments."],["03","Something gets missed","A payment slips, a task is missed, stock moves without context, or a handover loses detail."],["04","The business adds people","Growth often adds another layer of coordination instead of fixing the information flow."]].map(x=><article key={x[0]}><span>{x[0]}</span><h3>{x[1]}</h3><p>{x[2]}</p></article>)}</div>
          <div className="quote"><b>“</b><div><strong>I want the operation itself to become more organised through a system.</strong><small>That is the starting point for LOOP_Automated.</small></div></div>
        </section>

        <section id="system" className="section anchor">
          <div className="eyebrow">02 / THE SYSTEM</div><div className="heading"><h2>One operational layer.<br /><span>Many connected workflows.</span></h2><p>Not another dashboard. Not another checklist. The aim is to connect the information the business already depends on.</p></div>
          <div className="modules">{modules.map((m,i)=><article key={m[0]}><span>0{i+1}</span><div><h3>{m[0]}</h3><p>{m[1]}</p></div></article>)}</div>
          <div className="rule"><small>THE OPERATING RULE</small><div>{["What is planned should be recorded.","What is done should be verified.","What is verified should become a record.","What becomes a record should become useful information."].map(t=><strong key={t}>{t}</strong>)}</div></div>
        </section>

        <section id="loop" className="section anchor dark-section">
          <div className="eyebrow">03 / CLOSED LOOP</div><div className="heading"><h2>Plan. Assign. Execute.<br /><span>Verify. Record. Improve.</span></h2><p>The closed loop connects an instruction to an accountable action and then to a verifiable outcome.</p></div>
          <div className="loop-grid">{["PLAN","ASSIGN","EXECUTE","VERIFY","RECORD","ANALYZE","IMPROVE","REPEAT"].map((x,i)=><div key={x}><span>0{i+1}</span><b>{x}</b>{i<7&&<em>↓</em>}</div>)}</div>
          <div className="answer-card"><div><small>THE SYSTEM SHOULD ANSWER</small><h3>Not just “was it assigned?”</h3></div><div className="answer-list">{["What was supposed to happen?","Who was responsible?","What actually happened?","Was it verified?","What was the result?"].map(x=><p key={x}>{x}</p>)}</div></div>
        </section>

        <section id="inventory" className="section anchor">
          <div className="eyebrow">04 / A REAL BUSINESS EXAMPLE</div><div className="heading"><h2>Take something simple:<br /><span>one bottle, one ingredient, one movement.</span></h2><p>Instead of treating inventory as a spreadsheet number, the system can follow the operational movement behind it.</p></div>
          <div className="flow">{["PURCHASE","STOCK RECEIVED","STOCK MOVEMENT","POS SALE","WASTAGE / ADJUSTMENT","CURRENT STOCK","MANAGEMENT REVIEW"].map((x,i)=><div key={x}><span>0{i+1}</span><b>{x}</b>{i<6&&<em>→</em>}</div>)}</div>
          <div className="insight"><div><small>QUESTIONS THIS CREATES</small><h3>Where does the money disappear?</h3></div><div className="questions">{questions.map(x=><p key={x}>↳ {x}</p>)}</div></div>
        </section>

        <section id="control" className="section anchor split"><div><div className="eyebrow">05 / HUMAN CONTROL</div><h2>Automation without<br /><span>blind autonomy.</span></h2><p className="big">The system can process information, create alerts, prepare drafts, identify exceptions and recommend actions. Important business decisions stay with authorised people.</p></div><div className="control-flow">{["SYSTEM DETECTS","SYSTEM PREPARES","HUMAN REVIEWS","HUMAN APPROVES","SYSTEM EXECUTES","SYSTEM RECORDS"].map((x,i)=><div className={i===2||i===3?"human":""} key={x}><span>0{i+1}</span><b>{x}</b>{i<5&&<em>↓</em>}</div>)}</div></section>

        <section id="ai" className="section anchor"><div className="eyebrow">06 / WHERE AI FITS</div><div className="ai-card"><div><small>THE ORDER OF OPERATIONS</small><h2>AI comes <span>after</span> reliable data.</h2><p>AI is not the foundation. The operational data is. Once reliable records exist, AI can help structure information, draft communications, identify exceptions, detect patterns, summarise management information and support revenue opportunities.</p></div><div className="ai-order">{["STANDARDISE","CAPTURE DATA","MEASURE","AUTOMATE","USE AI"].map((x,i)=><div key={x}><span>0{i+1}</span>{x}</div>)}</div></div>{mode==="deep"&&<details open className="deep"><summary>Technical direction</summary><p>Advanced analytics, computer vision, intelligent routing and other specialised approaches belong later in the roadmap, after the operational model has been proven.</p></details>}</section>

        <section id="feasible" className="section anchor"><div className="eyebrow">07 / FEASIBILITY</div><div className="heading"><h2>Build with proven parts.<br /><span>Prove the workflow before scaling it.</span></h2><p>The first version is intentionally modular. The current project is a Next.js application with a Supabase backend foundation.</p></div><div className="cards three">{[["01","Modular architecture","Use standard web infrastructure, APIs and connected services rather than one fragile monolith."],["02","Human-in-the-loop","Automated preparation is paired with controlled review and approval where business decisions matter."],["03","Defensive engineering","Errors should become visible system states instead of disappearing silently inside a busy operation."]].map(x=><article key={x[0]}><span>{x[0]}</span><h3>{x[1]}</h3><p>{x[2]}</p></article>)}</div><div className="stack"><b>Next.js</b><i>→</i><b>Supabase</b><i>→</i><b>Selected APIs</b><i>→</i><b>Real venue workflow</b></div></section>

        <section id="roi" className="section anchor"><div className="eyebrow">08 / BUSINESS IMPACT</div><div className="heading"><h2>The return is not one number.<br /><span>It comes from better control.</span></h2><p>The immediate aim is measurable operational improvement. Cost, time, leakage, service consistency and management visibility should be measured during the pilot.</p></div><div className="cards four">{[["01","Reduce administrative work","Turn calls, messages, spreadsheets and repeated follow-up into structured workflows."],["02","Reduce preventable leakage","Bring deposits, outstanding payments, wastage, inventory movements and exceptions into one visible process."],["03","Improve revenue capture","Make upselling and add-on opportunities part of the workflow instead of relying on memory."],["04","Reduce management dependency","Give managers a clearer view of what needs attention so they spend less time collecting information."]].map(x=><article key={x[0]}><span>{x[0]}</span><h3>{x[1]}</h3><p>{x[2]}</p></article>)}</div><div className="quote-strip"><b>Target mindset</b><span>measure the current process → run the system → compare the result → improve what works.</span></div></section>

        <section id="roadmap" className="section anchor"><div className="eyebrow">09 / FIVE-PHASE ROADMAP</div><div className="heading"><h2>Start with control.<br /><span>Earn the right to automate.</span></h2><p>Later phases depend on clean data and a proven first workflow.</p></div><div className="timeline">{phases.map(x=><article key={x[0]}><div className="num">{x[0]}</div><div><small>{x[0]} / 05</small><h3>{x[1]}</h3><p>{x[2]}</p><b>{x[3]}</b></div></article>)}</div></section>

        <section id="today" className="section anchor today"><div className="eyebrow">10 / WHERE WE ARE TODAY</div><div className="today-grid"><div><h2>The foundation is real.<br /><span>The operational UI is next.</span></h2><p className="big">The repository already contains the backend architecture for the core operational model. The current frontend is still under construction. The next step is turning the foundation into the working interface.</p></div><div className="checks">{["Next.js application foundation","Supabase backend structure","Property model","Staff and role model","Role-based access","Inventory master","Stock levels","Stock movement ledger","Purchase orders","Wastage approval workflow","POS ticket structure","Audit logging","Row Level Security"].map(x=><p key={x}><span>✓</span>{x}</p>)}</div></div><div className="next"><small>NEXT DEVELOPMENT STAGE</small><div>{buildNext.map((x,i)=><p key={x}><span>{String(i+1).padStart(2,"0")}</span>{x}</p>)}</div></div>{mode==="deep"&&<details open className="deep"><summary>Technical foundation</summary><p>The Supabase model covers property membership, role-based access, inventory, stock movements, purchase orders, wastage workflows, POS ticket records, audit logging and Row Level Security.</p></details>}</section>

        <section id="pilot" className="section anchor dark-section"><div className="eyebrow">11 / PILOT METHOD</div><div className="pilot"><div><small>PROVE IT IN REAL LIFE</small><h2>Start small.<br /><span>Measure everything that matters.</span></h2><p>I do not want to build a huge system and then hope people use it. The pilot should take a small number of real operational use cases, measure the current process, run the same process through LOOP_Automated and compare the result.</p></div><div className="metrics">{["Processing time","Follow-up time","Payment compliance","Wastage visibility","Task completion","Inventory accuracy","Management intervention"].map(x=><p key={x}>→ {x}</p>)}</div></div></section>

        <section id="vision" className="section anchor final"><div className="eyebrow">12 / THE VISION</div><div className="vision"><div className="vision-mark">⩜⃝☠️</div><div><h2>I want the business to have an operational system that remembers what people currently have to remember.</h2><p>Important actions are recorded. Problems surface early. Management can see what needs attention without asking everyone individually. The system learns from the operation and becomes more useful over time.</p><div className="vision-line">PLAN → ASSIGN → EXECUTE → VERIFY → RECORD → ANALYZE → IMPROVE</div></div></div><div className="closing"><div><small>MY GOAL</small><p>Start small. Build properly. Measure the result. Fix what does not work. Automate what is repetitive. Keep human control where it matters. Then scale it.</p></div><div className="signature"><span>That is what I mean by</span><strong>LOOP_Automated.</strong><small>⩜⃝☠️ / AGF_automated</small></div></div><div className="proprietary"><small>PROPRIETARY SYSTEM NOTICE</small><p>The operational concepts, architectural frameworks, seven-domain data ledger, rule-resolution logic and software automation concepts described here represent proprietary system designs developed by Crowndip Saikia / AGF_automated.</p><p>The LOOP-BLR name is an operational placeholder and can change without affecting the architecture. The concept includes booking governance, spatial routing, FOH handover protocols, automated triage, task management, reporting and related operational controls.</p></div><footer><span>_L➿P_automation_777</span><span>© 2026 Crowndip Saikia / AGF_automated</span><span>Build the loop. Prove the loop. Scale the loop.</span></footer></section>
      </div>
    </main>
  );
}
