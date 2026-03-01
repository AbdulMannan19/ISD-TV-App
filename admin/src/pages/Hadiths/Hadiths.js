import { useState, useEffect } from 'react';
import { supabase } from '../../supabase';
import './Hadiths.css';

const PencilIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z" />
  </svg>
);

const TrashIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M3 6h18" /><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" />
    <path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
  </svg>
);

const BookIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="12" height="12">
    <path d="M12 7v14" /><path d="M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z" />
  </svg>
);

const QuoteIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="20" height="20">
    <path d="M16 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z" />
    <path d="M5 3a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2 1 1 0 0 1 1 1v1a2 2 0 0 1-2 2 1 1 0 0 0-1 1v2a1 1 0 0 0 1 1 6 6 0 0 0 6-6V5a2 2 0 0 0-2-2z" />
  </svg>
);

const PlusIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <path d="M5 12h14" /><path d="M12 5v14" />
  </svg>
);

const CheckIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M20 6 9 17l-5-5" />
  </svg>
);

const XIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M18 6 6 18" /><path d="m6 6 12 12" />
  </svg>
);

export default function Hadiths() {
  const [hadiths, setHadiths] = useState([]);
  const [editing, setEditing] = useState(null);
  const [draft, setDraft] = useState({ text: '', source: '' });
  const [isAdding, setIsAdding] = useState(false);
  const [newText, setNewText] = useState('');
  const [newSource, setNewSource] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    supabase.from('hadiths').select('*').order('id').then(({ data }) => {
      if (data) setHadiths(data);
    });
  }, []);

  const startEdit = (h) => { setEditing(h.id); setDraft({ text: h.text, source: h.source }); };

  const handleSave = async (id) => {
    setSaving(true);
    await supabase.from('hadiths').update({ text: draft.text, source: draft.source }).eq('id', id);
    setHadiths(prev => prev.map(h => h.id === id ? { ...h, ...draft } : h));
    setEditing(null);
    setSaving(false);
  };

  const addHadith = async () => {
    if (!newText.trim() || !newSource.trim()) return;
    setSaving(true);
    const { data } = await supabase.from('hadiths').insert({ text: newText, source: newSource }).select();
    if (data) setHadiths(prev => [...prev, ...data]);
    setNewText(''); setNewSource(''); setIsAdding(false);
    setSaving(false);
  };

  const deleteHadith = async (id) => {
    await supabase.from('hadiths').delete().eq('id', id);
    setHadiths(prev => prev.filter(h => h.id !== id));
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Hadith of the Day</h1>
          <p className="page-subtitle">Manage the hadiths displayed on your masjid screens</p>
        </div>
        <button className="btn btn-green" onClick={() => setIsAdding(true)} disabled={isAdding}>
          <PlusIcon /> Add Hadith
        </button>
      </div>

      {isAdding && (
        <div className="add-form-card">
          <h3>New Hadith</h3>
          <div className="form-group">
            <label>Text</label>
            <textarea rows={4} value={newText} onChange={e => setNewText(e.target.value)} placeholder="Enter the hadith text..." />
          </div>
          <div className="form-group">
            <label>Source</label>
            <input type="text" value={newSource} onChange={e => setNewSource(e.target.value)} placeholder="e.g., Sahih Bukhari" />
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="btn btn-green btn-sm" onClick={addHadith} disabled={saving}><CheckIcon /> Save</button>
            <button className="btn btn-outline btn-sm" onClick={() => { setIsAdding(false); setNewText(''); setNewSource(''); }}><XIcon /> Cancel</button>
          </div>
        </div>
      )}

      <div className="hadiths-list">
        {hadiths.map((h, i) => (
          <div className="hadith-card" key={h.id}>
            <div className="hadith-accent" />
            <div className="hadith-content">
              {editing === h.id ? (
                <div className="hadith-edit-form">
                  <div className="form-group">
                    <textarea rows={4} value={draft.text} onChange={e => setDraft({ ...draft, text: e.target.value })} />
                  </div>
                  <div className="form-group">
                    <input type="text" value={draft.source} onChange={e => setDraft({ ...draft, source: e.target.value })} />
                  </div>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button className="btn btn-green btn-sm" onClick={() => handleSave(h.id)} disabled={saving}><CheckIcon /> {saving ? 'Saving...' : 'Save'}</button>
                    <button className="btn btn-outline btn-sm" onClick={() => setEditing(null)}><XIcon /> Cancel</button>
                  </div>
                </div>
              ) : (
                <div className="hadith-display">
                  <div className="hadith-body">
                    <span className="hadith-badge"><BookIcon /> Hadith {i + 1}</span>
                    <div className="hadith-text-wrap">
                      <span className="hadith-quote-icon"><QuoteIcon /></span>
                      <p className="hadith-text">{h.text}</p>
                    </div>
                    <p className="hadith-source">— {h.source}</p>
                  </div>
                  <div className="hadith-actions">
                    <button className="btn-icon" onClick={() => startEdit(h)} aria-label="Edit"><PencilIcon /></button>
                    <button className="btn-icon danger" onClick={() => deleteHadith(h.id)} aria-label="Delete"><TrashIcon /></button>
                  </div>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {hadiths.length === 0 && !isAdding && (
        <div className="empty">
          <div className="empty-icon"><BookIcon /></div>
          <h3>No hadiths yet</h3>
          <p>Add your first hadith to display on the masjid screens.</p>
        </div>
      )}
    </div>
  );
}
