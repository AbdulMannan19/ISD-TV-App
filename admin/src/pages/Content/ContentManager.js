import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '../../supabase';
import './Content.css';

const EditIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
    <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
  </svg>
);

const InfoIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <circle cx="12" cy="12" r="10" /><line x1="12" y1="16" x2="12" y2="12" /><line x1="12" y1="8" x2="12.01" y2="8" />
  </svg>
);

const SaveIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l4 4v9a2 2 0 0 1-2 2z" />
    <polyline points="17 21 17 13 7 13 7 21" /><polyline points="7 3 7 8 15 8" />
  </svg>
);

const HIJRI_MONTHS = [
  'Muharram', 'Safar', "Rabi' al-Awwal", "Rabi' al-Thani",
  'Jumada al-Ula', 'Jumada al-Thani', 'Rajab', "Sha'ban",
  'Ramadan', 'Shawwal', "Dhul Qi'dah", 'Dhul Hijjah',
];

export default function ContentManager({ tableName, title, subtitle, contentLabel, hasSecondContent = false }) {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedMonth, setSelectedMonth] = useState(0); // 0-indexed
  const [status, setStatus] = useState('');
  const monthsRef = useRef(null);

  // Edit modal
  const [editRow, setEditRow] = useState(null);
  const [editText, setEditText] = useState('');
  const [editSource, setEditSource] = useState('');
  const [editText2, setEditText2] = useState('');
  const [editSource2, setEditSource2] = useState('');
  const [saving, setSaving] = useState(false);

  const fetchRows = useCallback(async () => {
    const startId = selectedMonth * 30 + 1;
    const endId = startId + 29;
    const selectCols = hasSecondContent ? 'id, text, source, text2, source2' : 'id, text, source';
    const { data } = await supabase
      .from(tableName)
      .select(selectCols)
      .gte('id', startId)
      .lte('id', endId)
      .order('id', { ascending: true });
    if (data) setRows(data);
    setLoading(false);
  }, [tableName, selectedMonth, hasSecondContent]);

  useEffect(() => { setLoading(true); fetchRows(); }, [fetchRows]);

  // Day number from id: (id - 1) % 30 + 1
  const dayFromId = (id) => ((id - 1) % 30) + 1;

  const openEdit = (row) => {
    setEditRow(row);
    setEditText(row.text);
    setEditSource(row.source);
    if (hasSecondContent) {
      setEditText2(row.text2 || '');
      setEditSource2(row.source2 || '');
    }
  };

  const handleSave = async () => {
    if (!editRow) return;
    setSaving(true);
    const updateData = { text: editText, source: editSource };
    if (hasSecondContent) {
      updateData.text2 = editText2 || null;
      updateData.source2 = editSource2 || null;
    }
    const { error } = await supabase
      .from(tableName)
      .update(updateData)
      .eq('id', editRow.id);
    if (error) {
      setStatus('Error: ' + error.message);
    } else {
      setStatus(`${HIJRI_MONTHS[selectedMonth]} ${dayFromId(editRow.id)} updated`);
      setEditRow(null);
      fetchRows();
    }
    setSaving(false);
    setTimeout(() => setStatus(''), 3000);
  };

  const scrollMonths = (dir) => {
    if (monthsRef.current) {
      monthsRef.current.scrollBy({ left: dir * 200, behavior: 'smooth' });
    }
  };

  if (loading && rows.length === 0) return <div className="loading">Loading...</div>;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">{title}</h1>
          <p className="page-subtitle">{subtitle}</p>
        </div>
      </div>

      {status && (
        <div className={`content-status${status.startsWith('Error') ? ' error' : ''}`}>{status}</div>
      )}

      <div className="content-info">
        <InfoIcon />
        <span>360 rows (12 months × 30 days) mapped to the Hijri calendar. The display fetches the row matching today's Hijri date.</span>
      </div>

      <div className="content-months-wrap">
        <button className="content-months-arrow" onClick={() => scrollMonths(-1)}>‹</button>
        <div className="content-months" ref={monthsRef}>
          {HIJRI_MONTHS.map((name, i) => (
            <button
              key={i}
              className={`content-month-btn${selectedMonth === i ? ' active' : ''}`}
              onClick={() => setSelectedMonth(i)}
            >
              {name}
            </button>
          ))}
        </div>
        <button className="content-months-arrow" onClick={() => scrollMonths(1)}>›</button>
      </div>

      <div className="content-table-wrap">
        <table className="content-table">
          <thead>
            <tr>
              <th style={{ width: 60 }}>Day</th>
              <th>{contentLabel}</th>
              <th style={{ width: 180 }}>Source</th>
              {hasSecondContent && <th>{contentLabel} 2</th>}
              {hasSecondContent && <th style={{ width: 180 }}>Source 2</th>}
              <th style={{ width: 44 }}></th>
            </tr>
          </thead>
          <tbody>
            {rows.map(r => (
              <tr key={r.id}>
                <td className="content-day">{dayFromId(r.id)}</td>
                <td className="content-text-cell">
                  <div className="content-text-preview" onClick={() => openEdit(r)}>
                    {r.text || <em style={{ color: 'var(--text-muted)' }}>Empty</em>}
                  </div>
                </td>
                <td className="content-source">{r.source || '-'}</td>
                {hasSecondContent && (
                  <td className="content-text-cell">
                    <div className="content-text-preview" onClick={() => openEdit(r)}>
                      {r.text2 || <em style={{ color: 'var(--text-muted)' }}>Empty</em>}
                    </div>
                  </td>
                )}
                {hasSecondContent && (
                  <td className="content-source">{r.source2 || '-'}</td>
                )}
                <td>
                  <button className="content-edit-btn" onClick={() => openEdit(r)} title="Edit">
                    <EditIcon />
                  </button>
                </td>
              </tr>
            ))}
            {rows.length === 0 && !loading && (
              <tr><td colSpan={4} style={{ textAlign: 'center', padding: 32, color: 'var(--text-muted)' }}>No rows found for this month</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Edit Modal */}
      {editRow && (
        <div className="modal-overlay" onClick={() => setEditRow(null)}>
          <div className="modal-card" onClick={e => e.stopPropagation()} style={{ width: 560 }}>
            <div className="modal-header">
              <span>Edit {contentLabel}</span>
              <button className="modal-close" onClick={() => setEditRow(null)}>✕</button>
            </div>
            <div className="content-edit-id">
              {HIJRI_MONTHS[selectedMonth]} {dayFromId(editRow.id)}
            </div>
            <div className="content-edit-field">
              <label>{contentLabel}</label>
              <textarea
                value={editText}
                onChange={e => setEditText(e.target.value)}
                rows={6}
              />
            </div>
            <div className="content-edit-field">
              <label>Source</label>
              <input
                type="text"
                value={editSource}
                onChange={e => setEditSource(e.target.value)}
              />
            </div>
            {hasSecondContent && (
              <>
                <div className="content-edit-field">
                  <label>{contentLabel} 2 (optional)</label>
                  <textarea
                    value={editText2}
                    onChange={e => setEditText2(e.target.value)}
                    rows={6}
                    placeholder="Leave empty for single content"
                  />
                </div>
                <div className="content-edit-field">
                  <label>Source 2 (optional)</label>
                  <input
                    type="text"
                    value={editSource2}
                    onChange={e => setEditSource2(e.target.value)}
                    placeholder="Leave empty for single content"
                  />
                </div>
              </>
            )}
            <div className="content-edit-actions">
              <button className="btn btn-outline" onClick={() => setEditRow(null)}>Cancel</button>
              <button className="btn btn-green" onClick={handleSave} disabled={saving}>
                <SaveIcon /> {saving ? 'Saving...' : 'Save'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
