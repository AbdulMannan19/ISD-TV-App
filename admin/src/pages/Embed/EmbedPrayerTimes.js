import { useState, useEffect } from 'react';
import { supabase } from '../../supabase';
import './EmbedPrayerTimes.css';

const PRAYERS = ['fajr', 'zuhr', 'asr', 'maghrib', 'isha'];
const LABELS = { fajr: 'Fajr', zuhr: 'Dhuhr', asr: 'Asr', maghrib: 'Maghrib', isha: 'Isha' };

const to12 = (time) => {
  if (!time || time.includes('AM') || time.includes('PM')) return time || '-';
  const [h, m] = time.split(':').map(Number);
  const hour = h > 12 ? h - 12 : (h === 0 ? 12 : h);
  const period = h >= 12 ? 'PM' : 'AM';
  return `${hour}:${String(m).padStart(2, '0')} ${period}`;
};

export default function EmbedPrayerTimes() {
  const [times, setTimes] = useState({});
  const [hijriDate, setHijriDate] = useState('');
  const [sunrise, setSunrise] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchDb = async () => {
      const { data } = await supabase.from('prayer_times').select('*');
      if (data) {
        const map = {};
        data.forEach(row => { map[row.prayer] = row; });
        setTimes(map);
      }
    };

    const fetchAladhan = async () => {
      try {
        const lat = process.env.REACT_APP_ALADHAN_LATITUDE || '33.201662695006874';
        const lng = process.env.REACT_APP_ALADHAN_LONGITUDE || '-97.14494994434574';
        
        const now = new Date();
        const date = `${String(now.getDate()).padStart(2, '0')}-${String(now.getMonth() + 1).padStart(2, '0')}-${now.getFullYear()}`;
        const apiUrl = `https://api.aladhan.com/v1/timings/${date}?latitude=${lat}&longitude=${lng}&method=2`;

        const res = await fetch(apiUrl);
        const json = await res.json();
        if (json.code === 200 && json.data) {
          const hijri = json.data.date.hijri;
          const month = hijri.month.en || '';
          const dayNum = hijri.day || '';
          const year = hijri.year || '';
          setHijriDate(year ? `${month} ${dayNum}, ${year}` : `${month} ${dayNum}`);
          
          let rawSunrise = json.data.timings.Sunrise || '';
          if (rawSunrise) {
            rawSunrise = rawSunrise.split(' ')[0];
          }
          setSunrise(rawSunrise);
        }
      } catch (_) { }
    };

    const init = async () => {
      await Promise.all([fetchDb(), fetchAladhan()]);
      setLoading(false);
    };
    init();

    const channel = supabase.channel('embed-prayer-times')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'prayer_times' }, () => fetchDb())
      .subscribe();

    return () => { supabase.removeChannel(channel); };
  }, []);

  if (loading) return <div className="embed-loading">Loading...</div>;

  const now = new Date();
  const jummah = times['jummah'];

  const parseTimeMins = (timeStr) => {
    if (!timeStr) return -1;
    if (timeStr.includes('AM') || timeStr.includes('PM')) {
      const [time, period] = timeStr.trim().split(' ');
      let [h, m] = time.split(':').map(Number);
      if (period === 'PM' && h !== 12) h += 12;
      if (period === 'AM' && h === 12) h = 0;
      return h * 60 + m;
    }
    const [h, m] = timeStr.split(':').map(Number);
    return h * 60 + m;
  };

  const getCurrentAndNextPrayer = () => {
    if (!times || Object.keys(times).length === 0) return { current: null, next: null };
    
    const currentMins = now.getHours() * 60 + now.getMinutes();

    const prayerMins = PRAYERS.map(p => {
      const t = times[p];
      if (!t || !t.adhan) return null;
      return { prayer: p, mins: parseTimeMins(t.adhan) };
    }).filter(Boolean);
    
    prayerMins.sort((a, b) => a.mins - b.mins);
    
    let current = null;
    let next = null;
    
    for (let i = 0; i < prayerMins.length; i++) {
       if (currentMins < prayerMins[i].mins) {
          next = prayerMins[i].prayer;
          current = i === 0 ? prayerMins[prayerMins.length - 1].prayer : prayerMins[i - 1].prayer;
          break;
       }
    }
    
    if (!next && prayerMins.length > 0) {
       current = prayerMins[prayerMins.length - 1].prayer;
       next = prayerMins[0].prayer;
    }
    
    return { current, next };
  };

  const { current, next } = getCurrentAndNextPrayer();

  return (
    <div className="embed-container">
      <div className="embed-card">
        <div className="embed-header">
          <div className="embed-title">Prayer Times</div>
          <div className="embed-subtitle">Islamic Society of Denton</div>
          <div className="embed-date">{formatDate(now)}</div>
          {hijriDate && <div className="embed-hijri">{hijriDate}</div>}
        </div>

        <table className="embed-table">
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
              if (!t) return null;

              const isCurrent = p === current;
              const isNext = p === next;
              let rowClass = "";
              if (isCurrent) rowClass = "embed-current-prayer";
              if (isNext) rowClass = "embed-next-prayer";

              const row = (
                <tr key={p} className={rowClass}>
                  <td className="embed-prayer-name">{LABELS[p]}</td>
                  <td>{to12(t.adhan)}</td>
                  <td className="embed-iqamah">{to12(t.iqamah)}</td>
                </tr>
              );

              if (p === 'fajr' && sunrise) {
                return [
                  row,
                  <tr key="sunrise" className="embed-sunrise-row">
                    <td className="embed-prayer-name">Sunrise</td>
                    <td colSpan="2" className="embed-sunrise-time">{to12(sunrise)}</td>
                  </tr>
                ];
              }

              return row;
            })}
          </tbody>
        </table>

        {jummah && (
          <div className="embed-jummah">
            <span className="embed-jummah-label">Jumu'ah</span>
            <span className="embed-jummah-time">{to12(jummah.iqamah)}</span>
          </div>
        )}
      </div>
    </div>
  );
}

function formatDate(dt) {
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${days[dt.getDay()]}, ${months[dt.getMonth()]} ${dt.getDate()}, ${dt.getFullYear()}`;
}
