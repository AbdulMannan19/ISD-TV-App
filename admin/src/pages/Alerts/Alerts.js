import { useState, useEffect } from 'react';
import { supabase } from '../../supabase';
import './Alerts.css';

const TrashIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
  </svg>
);

const InfoIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <circle cx="12" cy="12" r="10" /><line x1="12" y1="16" x2="12" y2="12" /><line x1="12" y1="8" x2="12.01" y2="8" />
  </svg>
);

export default function Alerts() {
  const [alerts, setAlerts] = useState([]);
  const [text, setText] = useState('');
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);

  const fetchAlerts = async () => {
    const { data } = await supabase
      .from('alerts')
      .select('*')
      .order('created_at', { ascending: false });
    if (data) {
      // Filter client-side for < 24 hours
      const now = new Date();
      const active = data.filter(a => {
        const created = new Date(a.created_at);
        return (now - created) < 24 * 60 * 60 * 1000;
      });
      setAlerts(active);
    }
    setLoading(false);
  };

  useEffect(() => { fetchAlerts(); }, []);

  const handleAdd = async (e) => {
    e.preventDefault();
    if (!text.trim()) return;
    setSending(true);
    const { error } = await supabase.from('alerts').insert({ text: text.trim() });
    if (error) {
      alert('Error adding alert: ' + error.message);
    } else {
      setText('');
      fetchAlerts();
    }
    setSending(false);
  };

  const handleDelete = async (id) => {
    const { error } = await supabase.from('alerts').delete().eq('id', id);
    if (!error) fetchAlerts();
  };

  const timeAgo = (dateStr) => {
    const diff = Date.now() - new Date(dateStr).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 60) return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    return `${hrs}h ago`;
  };

  if (loading) return <div className="loading">Loading...</div>;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Alerts</h1>
          <p className="page-subtitle">Send scrolling alerts to the display screens</p>
        </div>
      </div>

      <div className="alerts-info">
        <InfoIcon />
        <span>Alerts automatically expire after 24 hours. They appear as a red scrolling bar on all screens except silence and slides.</span>
      </div>

      <form className="alerts-form" onSubmit={handleAdd}>
        <input
          className="alerts-input"
          type="text"
          placeholder="Type alert message..."
          value={text}
          onChange={e => setText(e.target.value)}
        />
        <button className="btn btn-green" type="submit" disabled={sending}>
          {sending ? 'Sending...' : 'Send Alert'}
        </button>
      </form>

      {alerts.length === 0 ? (
        <div className="alerts-empty">No active alerts</div>
      ) : (
        <div className="alerts-list">
          {alerts.map(a => (
            <div key={a.id} className="alert-card">
              <span className="alert-text">{a.text}</span>
              <span className="alert-meta">{timeAgo(a.created_at)}</span>
              <button className="alert-delete" onClick={() => handleDelete(a.id)} title="Delete alert">
                <TrashIcon />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
