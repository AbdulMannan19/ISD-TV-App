import { useState, useEffect } from 'react';
import { supabase } from '../../supabase';
import './PrayerTimes.css';

const ClockIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" />
  </svg>
);

const SaveIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1-2 2h11l4 4v9a2 2 0 0 1-2 2z" />
    <polyline points="17 21 17 13 7 13 7 21" /><polyline points="7 3 7 8 15 8" />
  </svg>
);

const TrashIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
  </svg>
);

const PRAYERS = ['fajr', 'zuhr', 'asr', 'maghrib', 'isha'];
const LABELS = { fajr: 'Fajr', zuhr: 'Dhuhr', asr: 'Asr', maghrib: 'Maghrib', isha: 'Isha' };
const NON_EDITABLE = ['maghrib'];

// Convert 24h "HH:MM" to minutes for comparison
const timeToMin = (t) => {
  if (!t) return null;
  // Handle "H:MM AM/PM" format
  if (t.includes('AM') || t.includes('PM')) {
    const [time, period] = t.split(' ');
    const [h, m] = time.split(':').map(Number);
    let hour = h;
    if (period === 'PM' && h !== 12) hour += 12;
    if (period === 'AM' && h === 12) hour = 0;
    return hour * 60 + m;
  }
  // Handle "HH:MM" 24h format
  const [h, m] = t.split(':').map(Number);
  return h * 60 + m;
};

const to12 = (time) => {
  if (!time || time.includes('AM') || time.includes('PM')) return time || '-';
  const [h, m] = time.split(':').map(Number);
  const hour = h > 12 ? h - 12 : (h === 0 ? 12 : h);
  const period = h >= 12 ? 'PM' : 'AM';
  return `${hour}:${String(m).padStart(2, '0')} ${period}`;
};

export default function PrayerTimes() {
  const [times, setTimes] = useState({});
  const [editing, setEditing] = useState({});
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(true);
  const [validationErrors, setValidationErrors] = useState({});
  const [hijriDate, setHijriDate] = useState('');
  const [sunrise, setSunrise] = useState('');

  // Schedule state
  const [scheduled, setScheduled] = useState([]);
  const [schedPrayer, setSchedPrayer] = useState('fajr');
  const [schedTime, setSchedTime] = useState('');
  const [schedDate, setSchedDate] = useState('');
  const [schedSaving, setSchedSaving] = useState(false);

  const fetchTimes = async () => {
    try {
      // 1. Fetch from Supabase
      const { data: dbData } = await supabase.from('prayer_times').select('*');
      const dbMap = {};
      if (dbData) {
        dbData.forEach(row => { dbMap[row.prayer] = row.iqamah; });
      }

      // 2. Fetch from Aladhan
      const lat = process.env.REACT_APP_ALADHAN_LATITUDE || '33.201662695006874';
      const lng = process.env.REACT_APP_ALADHAN_LONGITUDE || '-97.14494994434574';
      const now = new Date();
      const date = `${String(now.getDate()).padStart(2, '0')}-${String(now.getMonth() + 1).padStart(2, '0')}-${now.getFullYear()}`;
      const url = `https://api.aladhan.com/v1/timings/${date}?latitude=${lat}&longitude=${lng}&method=2`;
      
      const res = await fetch(url);
      const json = await res.json();
      
      if (json.code === 200 && json.data) {
        const aladhan = json.data.timings;
        const hijri = json.data.date.hijri;
        setHijriDate(`${hijri.month.en} ${hijri.day}, ${hijri.year}`);
        setSunrise(aladhan.Sunrise.split(' ')[0]);

        const map = {};
        PRAYERS.forEach(p => {
          const key = p === 'zuhr' ? 'Dhuhr' : (p.charAt(0).toUpperCase() + p.slice(1));
          const adhan = aladhan[key].split(' ')[0];
          let iqamah = dbMap[p] || '';

          // Maghrib auto-calculation: Adhan + 10 mins
          if (p === 'maghrib') {
            const [h, m] = adhan.split(':').map(Number);
            const total = h * 60 + m + 10;
            iqamah = `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
          }

          map[p] = { adhan, iqamah };
        });

        setTimes(map);
        setEditing(Object.fromEntries(
          PRAYERS.filter(p => !NON_EDITABLE.includes(p))
                 .map(p => [p, map[p].iqamah])
        ));
      }
    } catch (e) {
      console.error('Error fetching times:', e);
    } finally {
      setLoading(false);
    }
  };

  const fetchScheduled = async () => {
    const { data } = await supabase
      .from('iqamah_schedule')
      .select('*')
      .order('effective_date', { ascending: true });
    if (data) setScheduled(data);
  };

  useEffect(() => { fetchTimes(); fetchScheduled(); }, []);

  // Validation: iqamah must be >= its adhan and < next prayer's adhan
  const validate = (editingState) => {
    const errors = {};
    const order = PRAYERS.filter(p => !NON_EDITABLE.includes(p));
    for (let i = 0; i < order.length; i++) {
      const p = order[i];
      const iqMin = timeToMin(editingState[p]);
      const adhanMin = timeToMin(times[p]?.adhan);
      if (iqMin == null || adhanMin == null) continue;

      if (iqMin < adhanMin) {
        errors[p] = `Iqamah cannot be before ${LABELS[p]} adhan (${to12(times[p]?.adhan)})`;
        continue;
      }

      // Find next prayer's adhan
      const nextIdx = PRAYERS.indexOf(p) + 1;
      if (nextIdx < PRAYERS.length) {
        const nextP = PRAYERS[nextIdx];
        const nextAdhan = timeToMin(times[nextP]?.adhan);
        if (nextAdhan != null && iqMin >= nextAdhan) {
          errors[p] = `Iqamah cannot be after ${LABELS[nextP]} adhan (${to12(times[nextP]?.adhan)})`;
        }
      }
    }
    return errors;
  };

  const handleIqamahChange = (prayer, value) => {
    const next = { ...editing, [prayer]: value };
    setEditing(next);
    setValidationErrors(validate(next));
  };

  const handleSave = async () => {
    const errors = validate(editing);
    if (Object.keys(errors).length > 0) {
      setValidationErrors(errors);
      setStatus('Fix validation errors before saving');
      setTimeout(() => setStatus(''), 3000);
      return;
    }

    setSaving(true);
    setStatus('');

    const changed = Object.entries(editing).filter(([prayer, iqamah]) =>
      times[prayer] && times[prayer].iqamah !== iqamah
    );

    const updates = Object.entries(editing).map(([prayer, iqamah]) =>
      supabase.from('prayer_times').update({ iqamah }).eq('prayer', prayer)
    );
    const results = await Promise.all(updates);
    const err = results.find(r => r.error);
    if (err) {
      setStatus('Error saving: ' + err.error.message);
    } else {
      setStatus('Times updated');
      fetchTimes();
    }
    setSaving(false);
    setTimeout(() => setStatus(''), 3000);
  };

  const handleSchedule = async (e) => {
    e.preventDefault();
    if (!schedTime || !schedDate) return;
    setSchedSaving(true);

    // Create the scheduled change
    const { error } = await supabase.from('iqamah_schedule').insert({
      prayer: schedPrayer,
      iqamah: schedTime,
      effective_date: schedDate,
    });

    if (error) {
      alert('Error scheduling: ' + error.message);
    } else {
      // Club alerts for same effective_date into one
      const effectiveDate = new Date(schedDate + 'T00:00:00');
      const alertStart = new Date(effectiveDate.getTime() - 2 * 24 * 60 * 60 * 1000);
      const prefix = `Starting ${formatDate(schedDate)}:`;

      // Check for existing alert for this date
      const { data: existing } = await supabase.from('alerts')
        .select('id, text')
        .like('text', `${prefix}%`);

      const newPart = `${LABELS[schedPrayer]} iqamah → ${to12(schedTime)}`;

      if (existing && existing.length > 0) {
        // Merge into existing alert
        const alertText = `${existing[0].text}, ${newPart}`;
        await supabase.from('alerts').update({
          text: alertText,
        }).eq('id', existing[0].id);
      } else {
        const alertText = `${prefix} ${newPart}`;
        await supabase.from('alerts').insert({
          text: alertText,
          start_time: alertStart.toISOString(),
          end_time: effectiveDate.toISOString(),
        });
      }

      setSchedTime('');
      setSchedDate('');
      fetchScheduled();
    }
    setSchedSaving(false);
  };

  const handleDeleteSchedule = async (id) => {
    await supabase.from('iqamah_schedule').delete().eq('id', id);
    fetchScheduled();
  };

  const formatDate = (d) => {
    const [y, m, day] = d.split('-');
    const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    const dt = new Date(parseInt(y), parseInt(m) - 1, parseInt(day));
    return `${days[dt.getDay()]}, ${mon[parseInt(m) - 1]} ${parseInt(day)}`;
  };

  if (loading) return <div className="loading">Loading...</div>;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Prayer Times</h1>
          <p className="page-subtitle">View adhan times and manage iqamah times</p>
        </div>
        <button className="btn btn-green" onClick={handleSave} disabled={saving || Object.keys(validationErrors).length > 0}>
          <SaveIcon /> {saving ? 'Saving...' : 'Save Changes'}
        </button>
      </div>

      <div className="pt-top-stats">
        <div className="pt-stat-item">
          <span className="pt-stat-label">Hijri Date</span>
          <span className="pt-stat-value">{hijriDate || '-'}</span>
        </div>
        <div className="pt-stat-item">
          <span className="pt-stat-label">Sunrise</span>
          <span className="pt-stat-value">{sunrise ? to12(sunrise) : '-'}</span>
        </div>
      </div>

      {status && (
        <div className={`pt-status${status.startsWith('Error') || status.startsWith('Fix') ? ' error' : ''}`}>{status}</div>
      )}

      <div className="pt-info">
        <ClockIcon />
        <span>Adhan (start) times, sunrise, and Hijri date come from the Aladhan API. Iqamah times are set here and stored in the database; they are not taken from Aladhan.</span>
      </div>

      <div className="pt-table-wrap">
        <table className="pt-table">
          <thead>
            <tr>
              <th>Prayer</th>
              <th>Adhan</th>
              <th>Iqamah</th>
            </tr>
          </thead>
          <tbody>
            {PRAYERS.map(p => {
              const t = times[p];
              const isEditable = !NON_EDITABLE.includes(p);
              return (
                <tr key={p} className={validationErrors[p] ? 'pt-row-error' : ''}>
                  <td className="pt-prayer-name">{LABELS[p]}</td>
                  <td className="pt-time">{t ? to12(t.adhan) : '-'}</td>
                  <td className="pt-time">
                    {isEditable ? (
                      <div>
                        <input
                          type="time"
                          value={editing[p] || ''}
                          onChange={e => handleIqamahChange(p, e.target.value)}
                          className={`pt-input${validationErrors[p] ? ' pt-input-error' : ''}`}
                        />
                        {validationErrors[p] && <div className="pt-error-msg">{validationErrors[p]}</div>}
                      </div>
                    ) : (
                      <span className="pt-auto">{t ? to12(t.iqamah) : '-'} <span className="pt-auto-badge">Auto</span></span>
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="pt-schedule-section">
        <h2 className="pt-section-title">Schedule Future Change</h2>
        <p className="pt-section-sub">Schedule iqamah time changes for a future date. An alert will be auto-created 2 days before.</p>
        <form className="pt-schedule-form" onSubmit={handleSchedule}>
          <select className="pt-select" value={schedPrayer} onChange={e => setSchedPrayer(e.target.value)}>
            {PRAYERS.filter(p => !NON_EDITABLE.includes(p)).map(p => (
              <option key={p} value={p}>{LABELS[p]}</option>
            ))}
          </select>
          <input type="time" className="pt-input" value={schedTime} onChange={e => setSchedTime(e.target.value)} required />
          <input type="date" className="pt-input" value={schedDate} onChange={e => setSchedDate(e.target.value)} min={new Date().toISOString().split('T')[0]} required />
          <button className="btn btn-green" type="submit" disabled={schedSaving}>
            {schedSaving ? 'Scheduling...' : 'Schedule'}
          </button>
        </form>

        {scheduled.length > 0 && (
          <div className="pt-schedule-list">
            {scheduled.map(s => (
              <div key={s.id} className="pt-schedule-item">
                <span className="pt-schedule-prayer">{LABELS[s.prayer] || s.prayer}</span>
                <span className="pt-schedule-time">{to12(s.iqamah)}</span>
                <span className="pt-schedule-date">{formatDate(s.effective_date)}</span>
                <button className="pt-schedule-delete" onClick={() => handleDeleteSchedule(s.id)}><TrashIcon /></button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
