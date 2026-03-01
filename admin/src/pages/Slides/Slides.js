import { useState, useEffect, useRef } from 'react';
import { supabase } from '../../supabase';
import './Slides.css';

const MAX_SIZE = 2 * 1024 * 1024;

export default function Slides() {
  const [slides, setSlides] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [showModal, setShowModal] = useState(false);
  const [dragIdx, setDragIdx] = useState(null);
  const [overIdx, setOverIdx] = useState(null);
  const uploadRef = useRef();

  const fetchSlides = async () => {
    const { data } = await supabase.from('slides').select('*').order('display_order');
    if (data) setSlides(data);
  };

  useEffect(() => { fetchSlides(); }, []);

  const handleUpload = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    if (!['image/png', 'image/jpeg'].includes(file.type)) { alert('Only PNG and JPEG allowed.'); return; }
    if (file.size > MAX_SIZE) { alert('Max 2MB per image.'); return; }
    setUploading(true);
    const fileName = `${Date.now()}-${file.name}`;
    const { error } = await supabase.storage.from('slides').upload(fileName, file);
    if (error) { alert(error.message); setUploading(false); return; }
    const url = supabase.storage.from('slides').getPublicUrl(fileName).data.publicUrl;
    const max = slides.length ? Math.max(...slides.map(s => s.display_order)) : 0;
    await supabase.from('slides').insert({ image_url: url, display_order: max + 1 });
    fetchSlides();
    setUploading(false); setShowModal(false); e.target.value = '';
  };

  const deleteSlide = async (slide) => {
    await supabase.storage.from('slides').remove([slide.image_url.split('/').pop()]);
    await supabase.from('slides').delete().eq('id', slide.id);
    fetchSlides();
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

  return (
    <div>
      <h1 className="page-title">Slides</h1>

      {slides.map((slide, i) => (
        <div
          key={slide.id}
          className={`slide-item${dragIdx === i ? ' dragging' : ''}${overIdx === i ? ' drag-over' : ''}`}
          draggable
          onDragStart={() => onDragStart(i)}
          onDragOver={(e) => onDragOver(e, i)}
          onDragEnd={onDragEnd}
        >
          <img src={slide.image_url} alt={`Slide ${i + 1}`} />
          <div className="slide-item-label">Slide {i + 1}</div>
          <button className="slide-item-delete" onClick={() => deleteSlide(slide)} aria-label="Delete slide">−</button>
        </div>
      ))}

      {slides.length === 0 && (
        <div className="empty"><div className="empty-icon">🖼️</div><p>No slides yet. Add one below.</p></div>
      )}

      <button className="add-slide-btn" onClick={() => setShowModal(true)}>＋</button>

      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal-card" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <span>Upload Slide</span>
              <button className="modal-close" onClick={() => setShowModal(false)}>✕</button>
            </div>
            <div className="slides-note">PNG or JPEG, 1920×1080px (Full HD), max 2MB.</div>
            <div className="upload-zone" onClick={() => uploadRef.current?.click()}>
              <input type="file" accept="image/png,image/jpeg" ref={uploadRef} onChange={handleUpload} disabled={uploading} />
              <div className="upload-icon">📁</div>
              <p>{uploading ? 'Uploading...' : 'Click to select an image'}</p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
