import { useState, useEffect, useRef } from 'react';
import { supabase } from '../../supabase';
import './Slides.css';

const MAX_SIZE = 50 * 1024 * 1024;

const PlusIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <path d="M5 12h14" /><path d="M12 5v14" />
  </svg>
);

const SaveIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z" />
    <polyline points="17 21 17 13 7 13 7 21" /><polyline points="7 3 7 8 15 8" />
  </svg>
);

const TrashIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M3 6h18" /><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6" />
    <path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
  </svg>
);

const UploadIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="24" height="24">
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <polyline points="17 8 12 3 7 8" /><line x1="12" y1="3" x2="12" y2="15" />
  </svg>
);

const GripIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="12" height="12">
    <circle cx="9" cy="12" r="1" /><circle cx="9" cy="5" r="1" /><circle cx="9" cy="19" r="1" />
    <circle cx="15" cy="12" r="1" /><circle cx="15" cy="5" r="1" /><circle cx="15" cy="19" r="1" />
  </svg>
);

const XIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M18 6 6 18" /><path d="m6 6 12 12" />
  </svg>
);

const PresentationIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="32" height="32">
    <path d="M2 3h20" /><path d="M21 3v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V3" />
    <path d="m7 21 5-5 5 5" />
  </svg>
);

const ClockIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <circle cx="12" cy="12" r="10" /><polyline points="12 6 12 12 16 14" />
  </svg>
);

export default function Slides() {
  const [slides, setSlides] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [previewUrl, setPreviewUrl] = useState('');
  const [previewFile, setPreviewFile] = useState(null);
  const [dragIdx, setDragIdx] = useState(null);
  const [overIdx, setOverIdx] = useState(null);
  const [durationEdits, setDurationEdits] = useState({});
  const [savingDurations, setSavingDurations] = useState(false);
  const uploadRef = useRef();

  const fetchSlides = async () => {
    const { data } = await supabase.from('slides').select('*').order('display_order');
    if (data) {
      setSlides(data);
      const edits = {};
      data.forEach(s => {
        const total = s.duration_seconds || 30;
        edits[s.id] = {
          h: String(Math.floor(total / 3600)),
          m: String(Math.floor((total % 3600) / 60)),
          s: String(total % 60),
        };
      });
      setDurationEdits(edits);
    }
  };

  useEffect(() => { fetchSlides(); }, []);

  const handleFileSelect = (e) => {
    const file = e.target.files[0];
    if (!file) return;
    if (!['image/png', 'image/jpeg'].includes(file.type)) { alert('Only PNG and JPEG allowed.'); return; }
    if (file.size > MAX_SIZE) { alert('Max 50MB per image.'); return; }
    setPreviewUrl(URL.createObjectURL(file));
    setPreviewFile(file);
  };

  const handleUpload = async () => {
    if (!previewFile) return;
    setUploading(true);
    const fileName = `${Date.now()}-${previewFile.name}`;
    const { error } = await supabase.storage.from('slides').upload(fileName, previewFile);
    if (error) { alert(error.message); setUploading(false); return; }
    const url = supabase.storage.from('slides').getPublicUrl(fileName).data.publicUrl;
    const max = slides.length ? Math.max(...slides.map(s => s.display_order)) : 0;
    await supabase.from('slides').insert({ image_url: url, display_order: max + 1 });
    fetchSlides();
    setUploading(false); setShowModal(false);
    setPreviewUrl(''); setPreviewFile(null);
  };

  const deleteSlide = async (slide) => {
    await supabase.storage.from('slides').remove([slide.image_url.split('/').pop()]);
    await supabase.from('slides').delete().eq('id', slide.id);
    fetchSlides();
  };

  const handleDurationField = (id, field, value) => {
    setDurationEdits(prev => ({
      ...prev,
      [id]: { ...prev[id], [field]: value },
    }));
  };

  const hasDurationChanges = slides.some(s => {
    const e = durationEdits[s.id];
    if (!e) return false;
    const total = s.duration_seconds || 30;
    const editTotal = (parseInt(e.h) || 0) * 3600 + (parseInt(e.m) || 0) * 60 + (parseInt(e.s) || 0);
    return Math.max(5, Math.min(43200, editTotal || 5)) !== total;
  });

  const saveDurations = async () => {
    setSavingDurations(true);
    const updates = slides.map(s => {
      const e = durationEdits[s.id];
      if (!e) return null;
      const total = (parseInt(e.h) || 0) * 3600 + (parseInt(e.m) || 0) * 60 + (parseInt(e.s) || 0);
      const val = Math.max(5, Math.min(43200, total || 5));
      return supabase.from('slides').update({ duration_seconds: val }).eq('id', s.id);
    }).filter(Boolean);
    await Promise.all(updates);
    await fetchSlides();
    setSavingDurations(false);
  };

  const onDragStart = (i) => setDragIdx(i);
  const onDragOver = (e, i) => { e.preventDefault(); setOverIdx(i); };
  const onDragEnd = async () => {
    if (dragIdx === null || overIdx === null || dragIdx === overIdx) {
      setDragIdx(null); setOverIdx(null); return;
    }
    const arr = [...slides];
    const [moved] = arr.splice(dragIdx, 1);
    arr.splice(overIdx, 0, moved);
    setSlides(arr); setDragIdx(null); setOverIdx(null);
    await Promise.all(arr.map((s, i) =>
      supabase.from('slides').update({ display_order: i + 1 }).eq('id', s.id)
    ));
  };

  const closeModal = () => { setShowModal(false); setPreviewUrl(''); setPreviewFile(null); };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Slides</h1>
          <p className="page-subtitle">Upload and manage presentation slides for your display</p>
        </div>
        <button className="btn btn-green" onClick={() => setShowModal(true)}>
          <PlusIcon /> Add Slide
        </button>
        {hasDurationChanges && (
          <button className="btn btn-green" onClick={saveDurations} disabled={savingDurations} style={{ marginLeft: 8 }}>
            <SaveIcon /> {savingDurations ? 'Saving...' : 'Save Durations'}
          </button>
        )}
      </div>

      <div className="slides-grid">
        {slides.map((slide, i) => (
          <div
            key={slide.id}
            className={`slide-card${dragIdx === i ? ' dragging' : ''}${overIdx === i ? ' drag-over' : ''}`}
            draggable
            onDragStart={() => onDragStart(i)}
            onDragOver={(e) => onDragOver(e, i)}
            onDragEnd={onDragEnd}
          >
            <div className="slide-preview">
              <img src={slide.image_url} alt={`Slide ${i + 1}`} />
              <div className="slide-badge"><GripIcon /> Slide {i + 1}</div>
              <button className="slide-delete" onClick={() => deleteSlide(slide)} aria-label={`Delete slide ${i + 1}`}>
                <TrashIcon />
              </button>
            </div>
            <div className="slide-footer">
              <label className="slide-duration">
                <ClockIcon />
                <input
                  type="number"
                  min="0"
                  max="12"
                  value={durationEdits[slide.id]?.h ?? '0'}
                  onChange={e => handleDurationField(slide.id, 'h', e.target.value)}
                  className="slide-duration-input"
                />
                <span>hr</span>
                <input
                  type="number"
                  min="0"
                  max="59"
                  value={durationEdits[slide.id]?.m ?? '0'}
                  onChange={e => handleDurationField(slide.id, 'm', e.target.value)}
                  className="slide-duration-input"
                />
                <span>min</span>
                <input
                  type="number"
                  min="0"
                  max="59"
                  value={durationEdits[slide.id]?.s ?? '30'}
                  onChange={e => handleDurationField(slide.id, 's', e.target.value)}
                  className="slide-duration-input"
                />
                <span>sec</span>
              </label>
            </div>
          </div>
        ))}
      </div>

      {slides.length === 0 && (
        <div className="empty">
          <div className="empty-icon"><PresentationIcon /></div>
          <h3>No slides yet</h3>
          <p>Upload your first slide to display on the masjid screens.</p>
        </div>
      )}

      {showModal && (
        <div className="modal-overlay" onClick={closeModal}>
          <div className="modal-card" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <span>Upload Slide</span>
              <button className="modal-close" onClick={closeModal}>✕</button>
            </div>
            <div className="slides-note">PNG or JPEG, 1920×1080px (Full HD), max 50MB.</div>
            <input type="file" accept="image/png,image/jpeg" ref={uploadRef} onChange={handleFileSelect} style={{ display: 'none' }} />
            {previewUrl ? (
              <div className="upload-preview">
                <img src={previewUrl} alt="Preview" />
                <button className="upload-preview-remove" onClick={() => { setPreviewUrl(''); setPreviewFile(null); }} aria-label="Remove image">
                  <XIcon />
                </button>
              </div>
            ) : (
              <div className="upload-zone" onClick={() => uploadRef.current?.click()}>
                <UploadIcon />
                <p>Click to upload an image</p>
              </div>
            )}
            {previewUrl && (
              <div style={{ marginTop: 16, display: 'flex', gap: 8 }}>
                <button className="btn btn-green" onClick={handleUpload} disabled={uploading}>
                  <PlusIcon /> {uploading ? 'Uploading...' : 'Add Slide'}
                </button>
                <button className="btn btn-outline" onClick={closeModal}><XIcon /> Cancel</button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
