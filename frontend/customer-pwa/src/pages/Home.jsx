import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { getCategories, getProducts } from '../api/customerApi';
import { Bell, Search } from 'lucide-react';

export default function Home() {
  const navigate = useNavigate();
  const [catId, setCatId] = useState('all');
  const [search, setSearch] = useState('');
  const name = localStorage.getItem('full_name') || 'there';

  const { data: categories = [] } = useQuery({
    queryKey: ['categories'],
    queryFn: async () => { const { data } = await getCategories(); return data || []; },
  });

  const { data: products = [], isLoading } = useQuery({
    queryKey: ['products', catId],
    queryFn: async () => {
      const params = catId !== 'all' ? { category_id: catId, active_only: true } : { active_only: true };
      const { data } = await getProducts(params);
      return data?.items || data || [];
    },
  });

  const filtered = products.filter(p =>
    p.name.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div>
      {/* Header */}
      <div style={{ background: 'linear-gradient(135deg, #2E7D32 0%, #43A047 100%)', padding: '20px 16px 28px', color: '#fff' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '16px' }}>
          <div>
            <p style={{ fontSize: '13px', opacity: 0.85, marginBottom: '2px' }}>Good Morning 👋</p>
            <h2 style={{ fontSize: '20px', fontFamily: 'Poppins,sans-serif', fontWeight: 700 }}>Hi, {name}!</h2>
          </div>
          <button onClick={() => navigate('/notifications')} style={{ background: 'rgba(255,255,255,0.15)', border: 'none', borderRadius: '10px', padding: '10px', cursor: 'pointer', color: '#fff' }}>
            <Bell size={20} />
          </button>
        </div>
        {/* Search */}
        <div style={{ position: 'relative' }}>
          <Search size={16} style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: '#9e9e9e' }} />
          <input value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Search healthy meals..."
            style={{ width: '100%', padding: '12px 14px 12px 38px', border: 'none', borderRadius: '12px', fontSize: '14px', fontFamily: 'Inter,sans-serif', outline: 'none' }} />
        </div>
      </div>

      <div style={{ padding: '16px' }}>
        {/* Categories */}
        {categories.length > 0 && (
          <div style={{ marginBottom: '16px' }}>
            <p className="section-title">Categories</p>
            <div className="cat-tabs">
              <button className={`cat-tab ${catId === 'all' ? 'active' : ''}`} onClick={() => setCatId('all')}>All</button>
              {categories.map(c => (
                <button key={c.id} className={`cat-tab ${catId === c.id ? 'active' : ''}`} onClick={() => setCatId(c.id)}>
                  {c.name}
                </button>
              ))}
            </div>
          </div>
        )}

        {/* Products Grid */}
        <p className="section-title">
          {catId === 'all' ? 'All Products' : categories.find(c => c.id === catId)?.name || 'Products'}
          <span style={{ fontSize: '13px', fontWeight: 400, color: '#757575', marginLeft: 8 }}>({filtered.length})</span>
        </p>

        {isLoading ? (
          <div className="loading-dots"><span /><span /><span /></div>
        ) : filtered.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon">🥗</div>
            <h3>No products found</h3>
            <p>Try a different category or search term</p>
          </div>
        ) : (
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            {filtered.map(p => (
              <div key={p.id} className="product-card" onClick={() => navigate(`/product/${p.id}`)} style={{ cursor: 'pointer' }}>
                {/* Product image placeholder */}
                <div style={{ height: 120, background: 'linear-gradient(135deg, #E8F5E9, #C8E6C9)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '40px' }}>
                  {p.image_url ? <img src={`http://localhost:8000${p.image_url}`} alt={p.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    : '🥗'}
                </div>
                <div className="product-card-body">
                  <p className="product-name">{p.name}</p>
                  <p className="product-price">
                    ₹{parseFloat(p.price || p.price_per_unit || 0).toFixed(0)}
                    {p.discount_price && (
                      <span style={{ fontSize: '12px', textDecoration: 'line-through', color: '#9e9e9e', marginLeft: 6 }}>
                        ₹{parseFloat(p.discount_price).toFixed(0)}
                      </span>
                    )}
                  </p>
                  <button
                    onClick={e => { e.stopPropagation(); navigate(`/product/${p.id}`); }}
                    style={{ marginTop: '8px', width: '100%', padding: '8px', background: '#2E7D32', color: '#fff', border: 'none', borderRadius: '8px', fontSize: '12px', fontWeight: 600, cursor: 'pointer' }}>
                    Subscribe
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
