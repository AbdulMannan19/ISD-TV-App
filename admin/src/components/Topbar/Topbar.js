import { Link } from 'react-router-dom';
import './Topbar.css';

export default function Topbar({ collapsed, email }) {
  const initial = email ? email[0].toUpperCase() : '?';

  return (
    <div className={`topbar${collapsed ? ' collapsed' : ''}`}>
      <div className="topbar-left">
        <span className="status-dot" />
        <span className="status-text">Display Active</span>
      </div>
      <div className="topbar-right">
        <Link to="/profile" className="topbar-avatar" aria-label="Profile">{initial}</Link>
      </div>
    </div>
  );
}
