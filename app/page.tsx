"use client";

import { useMemo, useState } from "react";

type Booking = {
  id: string;
  guest: string;
  contact: string;
  date: string;
  time: string;
  venue: string;
  service: string;
  pax: string;
  status: string;
  bd: string;
  source: string;
  menu?: string;
  notes?: string;
};

type TestRow = {
  whatsappTime: string;
  infoAvailable: "Y" | "N" | "";
  clarify: "Y" | "N" | "";
  clarifyNotes: string;
  registerTime: string;
};

const bookings: Booking[] = [
  { id: "TM001-001", guest: "Malthi", contact: "", date: "2026-08-21", time: "11:00", venue: "", service: "Buffet", pax: "40-43", status: "Confirmed", bd: "BD", source: "WhatsApp", menu: "Orange citrus; Virgin mojito; Crispy corn; Veg spring roll; Crispy chicken wings peri peri; Oriental chilli chicken; Olive & market pizza; Green salad; Veg kadai; Paneer tikka masala; Butter chicken; Methi murgh; Mutter pulao; Dal double tadka; Roti & naan; Steamed rice; Chocolate brownie", notes: "2 TOIT beer coupons OR 2 mocktail coupons on arrival. Kitchen, bar and cafe closed." },
  { id: "TM001-002", guest: "Shwetha", contact: "9448089429", date: "2026-08-22", time: "17:00", venue: "Lounge 1", service: "Pass around", pax: "18 min / 25 expected", status: "Confirmed", bd: "BD", source: "WhatsApp", menu: "Blue lagoon; Orange citrus; Crispy corn; Veg spring roll; Chicken nuggets; Chicken spring roll; Margarita pizza; Chicken Tikka pizza; Chocolate ice cream" },
  { id: "TM001-003", guest: "Prashant", contact: "8348060403", date: "2026-08-22", time: "13:00", venue: "Cafe 2", service: "Buffet", pax: "40 min", status: "Confirmed", bd: "BD", source: "WhatsApp", menu: "Virgin mojito; Veg spring roll; Hara bhara kebab; Tandoori murgh tikka; Florentine pizza; Green salad; Veg Lababdar; Kadai paneer; Butter chicken; Dal double tadka; Roti & naan; Steamed rice; Chocolate brownie" },
  { id: "TM001-004", guest: "Deepak", contact: "9739607757", date: "2026-08-22", time: "18:00", venue: "Lounge 2", service: "Buffet", pax: "40", status: "Confirmed", bd: "BD", source: "WhatsApp" },
  { id: "TM001-005", guest: "Ritika", contact: "9886110051", date: "2026-08-22", time: "11:30", venue: "Lounge 2", service: "Ala carte", pax: "20-25", status: "Confirmed", bd: "BD", source: "WhatsApp", notes: "Gaming decor" },
  { id: "TM001-006", guest: "Santosh", contact: "9833493494", date: "2026-08-22", time: "12:30", venue: "Cafe 1", service: "Ala carte", pax: "50", status: "Confirmed", bd: "BD", source: "WhatsApp" },
];

const blankTest = (): TestRow => ({ whatsappTime: "", infoAvailable: "", clarify: "", clarifyNotes: "", registerTime: "" });

export default function Home() {
  const [query, setQuery] = useState("");
  const [selectedId, setSelectedId] = useState(bookings[0].id);
  const [tests, setTests] = useState<Record<string, TestRow>>(() => Object.fromEntries(bookings.map(b => [b.id, blankTest()])));
  const [timerStart, setTimerStart] = useState<number | null>(null);
  const [running, setRunning] = useState(false);
  const [now, setNow] = useState(Date.now());

  const filtered = useMemo(() => bookings.filter(b => `${b.guest} ${b.contact} ${b.venue} ${b.id}`.toLowerCase().includes(query.toLowerCase())), [query]);
  const selected = bookings.find(b => b.id === selectedId) ?? bookings[0];
  const test = tests[selected.id];
  const elapsed = timerStart ? Math.max(0, Math.round((now - timerStart) / 1000)) : 0;

  const updateTest = (patch: Partial<TestRow>) => setTests(prev => ({ ...prev, [selected.id]: { ...prev[selected.id], ...patch } }));

  const startTimer = () => { setTimerStart(Date.now()); setRunning(true); const tick = window.setInterval(() => setNow(Date.now()), 250); window.setTimeout(() => window.clearInterval(tick), 10 * 60 * 1000); };
  const stopTimer = () => { if (!timerStart) return; const seconds = Math.max(0, Math.round((Date.now() - timerStart) / 1000)); updateTest({ registerTime: String(seconds) }); setTimerStart(null); setRunning(false); setNow(Date.now()); };

  const completeMandatory = [selected.id, selected.guest, selected.date, selected.time, selected.venue, selected.service, selected.pax, selected.status, selected.bd, selected.source].every(Boolean);
  const registerSeconds = Number(test.registerTime);
  const outcome = !test.registerTime ? "NO_OUTCOME" : registerSeconds <= 30 && completeMandatory ? "SUCCESS" : registerSeconds <= 30 || completeMandatory ? "PARTIAL" : "FAILURE";
  const rows = Object.values(tests);
  const tested = rows.filter(r => r.registerTime !== "");
  const success = rows.filter(r => Number(r.registerTime) <= 30 && r.registerTime !== "").length;
  const avgRegister = tested.length ? Math.round(tested.reduce((a, r) => a + Number(r.registerTime), 0) / tested.length) : 0;

  return (
    <main style={{ minHeight: "100vh", padding: "28px", background: "#0b1020", color: "#f8fafc", fontFamily: "Inter, system-ui, sans-serif" }}>
      <div style={{ maxWidth: 1200, margin: "0 auto" }}>
        <div style={{ display: "flex", justifyContent: "space-between", gap: 20, alignItems: "end", marginBottom: 24 }}>
          <div><div style={{ color: "#94a3b8", fontSize: 12, letterSpacing: 1.5 }}>TEMPERED_MONKEY V0.1 · TM-001</div><h1 style={{ fontSize: 32, margin: "8px 0" }}>LOOP-BLR Booking Control</h1><p style={{ color: "#94a3b8", margin: 0 }}>One searchable register for bookings currently buried in WhatsApp.</p></div>
          <div style={{ textAlign: "right", color: "#94a3b8", fontSize: 13 }}>Target<br /><strong style={{ color: "#fff", fontSize: 20 }}>≤30 sec</strong> retrieval</div>
        </div>

        <section style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12, marginBottom: 20 }}>
          {[['Bookings', bookings.length], ['Tested', tested.length], ['≤30s', success], ['Avg register', `${avgRegister}s`]].map(([label, value]) => <div key={label} style={{ background: "#111827", border: "1px solid #263244", borderRadius: 14, padding: 16 }}><div style={{ color: "#94a3b8", fontSize: 12 }}>{label}</div><div style={{ fontSize: 24, fontWeight: 700, marginTop: 6 }}>{value}</div></div>)}
        </section>

        <section style={{ display: "grid", gridTemplateColumns: "minmax(280px, .8fr) minmax(420px, 1.2fr)", gap: 16 }}>
          <div style={{ background: "#111827", border: "1px solid #263244", borderRadius: 16, padding: 16 }}>
            <input value={query} onChange={e => setQuery(e.target.value)} placeholder="Search guest, phone, venue or ID" style={{ width: "100%", boxSizing: "border-box", padding: "11px 12px", borderRadius: 10, border: "1px solid #334155", background: "#0b1020", color: "#fff", marginBottom: 12 }} />
            {filtered.map(b => <button key={b.id} onClick={() => setSelectedId(b.id)} style={{ width: "100%", textAlign: "left", padding: 13, marginBottom: 8, borderRadius: 12, border: b.id === selected.id ? "1px solid #60a5fa" : "1px solid #263244", background: b.id === selected.id ? "#172554" : "#0b1020", color: "#fff", cursor: "pointer" }}><strong>{b.guest}</strong><div style={{ color: "#94a3b8", fontSize: 12, marginTop: 4 }}>{b.date} · {b.time} · {b.pax}</div><div style={{ color: "#94a3b8", fontSize: 12 }}>{b.venue || "Venue missing"} · {b.service}</div></button>)}
          </div>

          <div style={{ background: "#111827", border: "1px solid #263244", borderRadius: 16, padding: 20 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "start" }}><div><div style={{ color: "#64748b", fontSize: 12 }}>{selected.id}</div><h2 style={{ margin: "5px 0", fontSize: 25 }}>{selected.guest}</h2><div style={{ color: "#94a3b8" }}>{selected.date} · {selected.time} · {selected.venue || "Venue not recorded"}</div></div><span style={{ padding: "6px 10px", borderRadius: 999, background: outcome === "SUCCESS" ? "#064e3b" : outcome === "PARTIAL" ? "#78350f" : "#1e293b", fontSize: 12 }}>{outcome}</span></div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 10, margin: "18px 0" }}>
              {[["Contact", selected.contact || "MISSING"], ["PAX", selected.pax], ["Service", selected.service], ["Venue", selected.venue || "MISSING"], ["Status", selected.status], ["BD", selected.bd]].map(([k,v]) => <div key={k} style={{ padding: 12, borderRadius: 10, background: "#0b1020" }}><div style={{ color: "#64748b", fontSize: 11 }}>{k}</div><div style={{ marginTop: 4 }}>{v}</div></div>)}
            </div>
            {selected.menu && <details style={{ marginBottom: 12 }}><summary style={{ cursor: "pointer" }}>Menu</summary><p style={{ color: "#cbd5e1", lineHeight: 1.6 }}>{selected.menu}</p></details>}
            {selected.notes && <div style={{ padding: 12, borderRadius: 10, background: "#172033", color: "#cbd5e1", marginBottom: 14 }}><strong>Operational note:</strong> {selected.notes}</div>}

            <div style={{ borderTop: "1px solid #263244", paddingTop: 16 }}><h3 style={{ marginTop: 0 }}>V0.1 test capture</h3>
              <div style={{ display: "grid", gridTemplateColumns: "repeat(2,1fr)", gap: 12 }}>
                <label>WhatsApp retrieval (sec)<input value={test.whatsappTime} onChange={e => updateTest({ whatsappTime: e.target.value })} type="number" min="0" style={inputStyle} /></label>
                <label>Info available?<select value={test.infoAvailable} onChange={e => updateTest({ infoAvailable: e.target.value as TestRow['infoAvailable'] })} style={inputStyle}><option value="">Select</option><option>Y</option><option>N</option></select></label>
                <label>Clarification needed?<select value={test.clarify} onChange={e => updateTest({ clarify: e.target.value as TestRow['clarify'] })} style={inputStyle}><option value="">Select</option><option>Y</option><option>N</option></select></label>
                <label>Clarify notes<input value={test.clarifyNotes} onChange={e => updateTest({ clarifyNotes: e.target.value })} style={inputStyle} /></label>
              </div>
              <div style={{ display: "flex", gap: 10, alignItems: "center", marginTop: 14, flexWrap: "wrap" }}>
                {!running ? <button onClick={startTimer} style={buttonStyle}>Start register timer</button> : <button onClick={stopTimer} style={{ ...buttonStyle, background: "#991b1b" }}>Stop · {elapsed}s</button>}
                <input value={test.registerTime} onChange={e => updateTest({ registerTime: e.target.value })} type="number" min="0" placeholder="Register seconds" style={{ ...inputStyle, width: 150, margin: 0 }} />
                <span style={{ color: completeMandatory ? "#86efac" : "#fbbf24", fontSize: 13 }}>{completeMandatory ? "Mandatory fields complete" : "Mandatory fields missing"}</span>
              </div>
              <div style={{ marginTop: 14, color: "#94a3b8", fontSize: 13 }}>Completeness: <strong style={{ color: completeMandatory ? "#86efac" : "#fbbf24" }}>{completeMandatory ? "100%" : "<100%"}</strong> · Outcome: <strong style={{ color: "#fff" }}>{outcome}</strong></div>
            </div>
          </div>
        </section>

        <section style={{ marginTop: 18, padding: 16, border: "1px solid #263244", borderRadius: 16, background: "#111827" }}><strong>V0.1 boundary:</strong> this build is a measurement/control surface only. It does not autonomously read WhatsApp, send messages, or execute bookings. The BD remains the booking owner.</section>
      </div>
    </main>
  );
}

const inputStyle: React.CSSProperties = { display: "block", width: "100%", boxSizing: "border-box", marginTop: 6, padding: "10px 11px", borderRadius: 9, border: "1px solid #334155", background: "#0b1020", color: "#fff" };
const buttonStyle: React.CSSProperties = { border: 0, borderRadius: 9, padding: "10px 14px", background: "#2563eb", color: "white", cursor: "pointer", fontWeight: 600 };
