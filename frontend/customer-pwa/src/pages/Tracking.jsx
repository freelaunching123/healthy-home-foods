import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getGpsLocation } from '../api/customerApi';
import { ArrowLeft, MapPin, Clock, RefreshCw } from 'lucide-react';

const STEPS = ['Order Placed', 'Prepared', 'Out for Delivery', 'Delivered'];

export default function Tracking() {
  const { assignmentId } = useParams();
  const navigate = useNavigate();
  const [location, setLocation] = useState(null);
  const [step, setStep] = useState(2); // current status index
  const [lastUpdated, setLastUpdated] = useState(null);
  const [error, setError] = useState(null);

  const fetchLocation = async () => {
    if (!assignmentId) return;
    try {
      const { data } = await getGpsLocation(assignmentId);
      setLocation(data);
      setLastUpdated(new Date());
      setError(null);
      // Map delivery status to step
      if (data.status === 'delivered') setStep(3);
      else if (data.status === 'assigned') setStep(2);
    } catch (e) {
      setError('Location not available yet — delivery boy may not have started GPS sharing');
    }
  };

  useEffect(() => {
    fetchLocation();
    const interval = setInterval(fetchLocation, 10000); // refresh every 10s
    return () => clearInterval(interval);
  }, [assignmentId]);

  return (
    <div>
      <div style={{ padding: '16px', background: '#fff', borderBottom: '1px solid #e0e0e0', display: 'flex', alignItems: 'center', gap: 8 }}>
        <button onClick={() => navigate(-1)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#2E7D32' }}><ArrowLeft size={20} /></button>
        <h2 style={{ fontSize: '16px', fontFamily: 'Poppins,sans-serif', fontWeight: 600 }}>Live Tracking</h2>
        <button onClick={fetchLocation} style={{ marginLeft: 'auto', background: 'none', border: 'none', cursor: 'pointer', color: '#2E7D32' }}>
          <RefreshCw size={18} />
        </button>
      </div>

      <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {/* Map placeholder / OpenStreetMap embed */}
        <div style={{ borderRadius: '12px', overflow: 'hidden', border: '1px solid #e0e0e0', height: 280 }}>
          {location?.latitude && location?.longitude ? (
            <iframe
              title="Delivery Location"
              width="100%"
              height="100%"
              frameBorder="0"
              src={`https://www.openstreetmap.org/export/embed.html?bbox=${location.longitude - 0.01}%2C${location.latitude - 0.01}%2C${location.longitude + 0.01}%2C${location.latitude + 0.01}&layer=mapnik&marker=${location.latitude}%2C${location.longitude}`}
            />
          ) : (
            <div style={{ height: '100%', background: 'linear-gradient(135deg, #E8F5E9, #C8E6C9)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '12px' }}>
              <MapPin size={40} style={{ color: '#2E7D32', opacity: 0.6 }} />
              <p style={{ color: '#2E7D32', fontWeight: 600, fontSize: '15px' }}>
                {error ? 'Waiting for delivery boy...' : 'Loading location...'}
              </p>
              {error && <p style={{ fontSize: '12px', color: '#757575', textAlign: 'center', padding: '0 24px' }}>{error}</p>}
            </div>
          )}
        </div>

        {/* ETA card */}
        {location && !error && (
          <div className="card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <p style={{ fontSize: '13px', color: '#757575' }}>Estimated Arrival</p>
              <p style={{ fontSize: '20px', fontWeight: 700, color: '#2E7D32' }}>~15 mins</p>
            </div>
            <div style={{ textAlign: 'right' }}>
              <p style={{ fontSize: '12px', color: '#757575' }}>Last updated</p>
              <p style={{ fontSize: '13px', fontWeight: 500 }}>
                <Clock size={12} style={{ verticalAlign: 'middle', marginRight: 4 }} />
                {lastUpdated?.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}
              </p>
            </div>
          </div>
        )}

        {/* Status Timeline */}
        <div className="card">
          <p className="section-title" style={{ marginBottom: '16px' }}>Delivery Status</p>
          <div className="timeline">
            {STEPS.map((s, i) => (
              <div key={s} className="timeline-item">
                <div className={`timeline-dot ${i < step ? 'done' : i === step ? 'active' : ''}`} />
                <p className="timeline-label" style={{ color: i <= step ? '#2E7D32' : '#9e9e9e', fontWeight: i === step ? 700 : 500 }}>{s}</p>
                {i === step && <p className="timeline-sub">In progress</p>}
                {i < step && <p className="timeline-sub" style={{ color: '#4caf50' }}>Completed</p>}
              </div>
            ))}
          </div>
        </div>

        <p style={{ textAlign: 'center', fontSize: '12px', color: '#9e9e9e' }}>
          🔄 Location refreshes every 10 seconds automatically
        </p>
      </div>
    </div>
  );
}
