import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '../../supabase';
import { ALL_THEMES } from '../../themes';
import './EmbedPrayerTimes.css';

const PRAYERS = ['fajr', 'zuhr', 'asr', 'maghrib', 'isha'];
const LABELS = { fajr: 'Fajr', zuhr: 'Dhuhr', asr: 'Asr', maghrib: 'Maghrib', isha: 'Isha' };

const to12 = (time) => {
    if (!time) return '-';
    let h, m, period;
    if (time.includes('AM') || time.includes('PM')) {
        const parts = time.trim().split(' ');
        const [hStr, mStr] = parts[0].split(':');
        h = hStr;
        m = mStr;
        period = parts[1];
    } else {
        const [hourStr, minStr] = time.split(':').map(Number);
        h = hourStr > 12 ? hourStr - 12 : (hourStr === 0 ? 12 : hourStr);
        m = String(minStr).padStart(2, '0');
        period = hourStr >= 12 ? 'PM' : 'AM';
    }
    return (
        <span className="embed-time-wrapper">
            {h}:{m} <span className="embed-time-suffix">{period}</span>
        </span>
    );
};

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

const formatDate = (dt) => {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return `${days[dt.getDay()]}, ${months[dt.getMonth()]} ${dt.getDate()}, ${dt.getFullYear()}`;
};

const addMinutes = (timeStr, mins) => {
    if (!timeStr) return '';
    const total = parseTimeMins(timeStr) + mins;
    const h = Math.floor(total / 60) % 24;
    const m = total % 60;
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
};

export default function EmbedPrayerTimes() {
    const [currentTime, setCurrentTime] = useState(new Date());
    const [times, setTimes] = useState({});
    const [hijriDate, setHijriDate] = useState('');
    const [sunrise, setSunrise] = useState('');
    const [lastThird, setLastThird] = useState('');
    const [currentTheme, setCurrentTheme] = useState(null);
    const [loading, setLoading] = useState(true);
    const isFetching = useRef(false);

    // 1. Unified stable data fetcher
    const initData = useCallback(async () => {
        if (isFetching.current) return;
        isFetching.current = true;
        try {
            const fetchDb = async () => {
                const { data } = await supabase.from('prayer_times').select('*');
                if (data) {
                    const map = {};
                    data.forEach(row => { 
                        map[row.prayer] = { iqamah: row.iqamah }; 
                    });
                    return map;
                }
                return {};
            };

            const fetchTheme = async () => {
                const { data } = await supabase.from('settings').select('theme_id').eq('id', 1).single();
                if (data) {
                    const theme = ALL_THEMES.find(t => t.id === data.theme_id);
                    if (theme) setCurrentTheme(theme);
                }
            };

            const [dbTimes, aladhanData] = await Promise.all([fetchDb(), fetchAladhan()]);
            await fetchTheme();

            if (aladhanData) {
                const newTimes = {};
                PRAYERS.forEach(p => {
                    const key = p === 'zuhr' ? 'Dhuhr' : (p.charAt(0).toUpperCase() + p.slice(1));
                    const adhan = aladhanData[key].split(' ')[0];
                    let iqamah = dbTimes[p]?.iqamah || '';

                    // Maghrib auto-calculation: Adhan + 10 mins
                    if (p === 'maghrib') {
                        iqamah = addMinutes(adhan, 10);
                    }

                    newTimes[p] = { adhan, iqamah };
                });
                
                // Add jumu'ah from DB
                if (dbTimes['jummah']) newTimes['jummah'] = dbTimes['jummah'];
                if (dbTimes['jummah_2']) newTimes['jummah_2'] = dbTimes['jummah_2'];

                setTimes(newTimes);
            }
        } finally {
            isFetching.current = false;
        }
    }, []);

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
                const aladhan = json.data.timings;
                const hijri = json.data.date.hijri;
                const month = hijri.month.en || '';
                const dayNum = hijri.day || '';
                const year = hijri.year || '';
                setHijriDate(year ? `${month} ${dayNum}, ${year}` : `${month} ${dayNum}`);

                let rawSunrise = aladhan.Sunrise || '';
                if (rawSunrise) {
                    rawSunrise = rawSunrise.split(' ')[0];
                }
                setSunrise(rawSunrise);

                let rawFajr = aladhan.Fajr || '';
                let rawMaghrib = aladhan.Maghrib || '';
                if (rawFajr && rawMaghrib) {
                    const maghribMins = parseTimeMins(rawMaghrib);
                    const fajrMins = parseTimeMins(rawFajr);
                    const duration = (fajrMins + 1440) - maghribMins;
                    const lastThirdMins = (fajrMins + 1440 - (duration / 3)) % 1440;
                    const h = Math.floor(lastThirdMins / 60);
                    const m = Math.floor(lastThirdMins % 60);
                    setLastThird(`${h}:${String(m).padStart(2, '0')}`);
                }
                return aladhan;
            }
        } catch (_) { }
        return null;
    };

    // 2. Startup & Clock State
    useEffect(() => {
        initData().then(() => {
            setLoading(false);
        });

        // 1-minute clock to keep highlights moving
        const clockTimer = setInterval(() => {
            setCurrentTime(new Date());
        }, 60000);

        return () => clearInterval(clockTimer);
    }, [initData]);

    // 3. Supabase Live Sync (Listen for configuration changes)
    useEffect(() => {
        const channel = supabase.channel('embed-prayer-times')
            .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'prayer_times' }, () => initData())
            .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'settings', filter: 'id=eq.1' }, (payload) => {
                const newThemeId = payload.new.theme_id;
                const theme = ALL_THEMES.find(t => t.id === newThemeId);
                if (theme) setCurrentTheme(theme);
            })
            .subscribe();

        return () => supabase.removeChannel(channel);
    }, [initData]);

    // 4. Schedule refreshes (triggered whenever 'times' is updated)
    useEffect(() => {
        if (Object.keys(times).length === 0) return;

        const now = new Date();
        const midnight = new Date(now.getFullYear(), now.month, now.getDate() + 1, 0, 1, 0);
        const msToMidnight = midnight.getTime() - now.getTime();
        
        const midnightTimeout = setTimeout(() => {
            initData();
        }, msToMidnight);

        // Maghrib/Sunset refresh
        let maghribTimeout;
        const maghribMins = parseTimeMins(times['maghrib']?.adhan);
        if (maghribMins > 0) {
            const maghrib = new Date(now.getFullYear(), now.month, now.getDate(), Math.floor(maghribMins / 60), (maghribMins % 60) + 1);
            const msToMaghrib = maghrib.getTime() - now.getTime();
            if (msToMaghrib > 0) {
                maghribTimeout = setTimeout(() => initData(), msToMaghrib);
            }
        }

        return () => {
            clearTimeout(midnightTimeout);
            if (maghribTimeout) clearTimeout(maghribTimeout);
        };
    }, [times, initData]);

    if (loading) return <div className="embed-loading">Loading...</div>;

    const jummahRow = times['jummah'];

    const getCurrentAndNextPrayer = () => {
        if (!times || Object.keys(times).length === 0) return { current: null, next: null };

        const currentMins = currentTime.getHours() * 60 + currentTime.getMinutes();
        const isFriday = currentTime.getDay() === 5;

        // 1. Determine CURRENT (based on last adhan that passed)
        const adhanMins = PRAYERS.map(p => {
            const t = times[p];
            if (!t || !t.adhan) return null;
            return { prayer: p, mins: parseTimeMins(t.adhan) };
        }).filter(Boolean);
        adhanMins.sort((a, b) => a.mins - b.mins);

        let current = null;
        for (let i = 0; i < adhanMins.length; i++) {
            if (currentMins >= adhanMins[i].mins) {
                current = adhanMins[i].prayer;
            }
        }
        // Midnight Logic: If before Fajr adhan, it's Isha from yesterday
        if (!current && adhanMins.length > 0) {
            current = adhanMins[adhanMins.length - 1].prayer;
        }

        // On Fridays, Zuhr adhan starts the Jumu'ah current window
        if (isFriday && current === 'zuhr') {
            current = 'jummah';
        }

        // 2. Determine NEXT (based on first upcoming iqamah)
        const iqamahCandidates = isFriday ? PRAYERS.filter(p => p !== 'zuhr') : [...PRAYERS];
        if (isFriday) {
            if (times['jummah']) iqamahCandidates.push('jummah');
            if (times['jummah_2']) iqamahCandidates.push('jummah_2');
        }

        const iqamahMins = iqamahCandidates.map(p => {
            const t = times[p];
            if (!t || !t.iqamah) return null;
            return { prayer: p, mins: parseTimeMins(t.iqamah) };
        }).filter(Boolean);
        iqamahMins.sort((a, b) => a.mins - b.mins);

        let next = null;
        for (let i = 0; i < iqamahMins.length; i++) {
            if (currentMins < iqamahMins[i].mins) {
                next = iqamahMins[i].prayer;
                break;
            }
        }
        // If all iqamahs passed today, next is Fajr tomorrow
        if (!next && iqamahMins.length > 0) {
            next = iqamahMins[0].prayer;
        }

        return { current, next };
    };

    const { current, next } = getCurrentAndNextPrayer();

    const themeVars = currentTheme ? {
        '--theme-bg': currentTheme.bg,
        '--theme-accent': currentTheme.accent,
        '--theme-accent-bright': currentTheme.accentBright,
        '--theme-text': currentTheme.text,
        '--theme-text-muted': currentTheme.textMuted,
    } : {};

    return (
        <div className="embed-container" style={themeVars}>
            <div className="embed-card">
                <div className="embed-header">
                    <div className="embed-title">Prayer Times</div>
                    <div className="embed-subtitle">Islamic Society of Denton</div>
                    <div className="embed-date">{formatDate(currentTime)}</div>
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
                                    <td className="embed-adhan">{to12(t.adhan)}</td>
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

                            if (p === 'isha' && lastThird) {
                                return [
                                    row,
                                    <tr key="lastThird" className="embed-sunrise-row">
                                        <td className="embed-prayer-name">Last Third</td>
                                        <td colSpan="2" className="embed-sunrise-time">{to12(lastThird)}</td>
                                    </tr>
                                ];
                            }

                            return row;
                        })}
                    </tbody>
                </table>

                {jummahRow && (
                    <div className={`embed-jummah ${current === 'jummah' ? 'embed-current-prayer' : next === 'jummah' ? 'embed-next-prayer' : ''}`}>
                        <span className="embed-jummah-label">Jumu'ah</span>
                        <span className="embed-jummah-time">{to12(jummahRow.iqamah)}</span>
                    </div>
                )}
            </div>
        </div>
    );
}

