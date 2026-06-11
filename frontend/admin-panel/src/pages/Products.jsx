import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Edit2, Trash2, X, Check, Image, Package } from 'lucide-react';
import toast from 'react-hot-toast';
import {
  getProducts, getCategories, createProduct, updateProduct,
  deleteProduct, createCategory
} from '../api/productsApi';

const EMPTY_FORM = {
  name: '', slug: '', description: '', unit: 'pack',
  price_per_unit: '', category_id: '', is_available: true, is_active: true
};

const slugify = (t) => t.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

export default function Products() {
  const qc = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [editProduct, setEditProduct] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [search, setSearch] = useState('');

  const { data: products, isLoading } = useQuery({
    queryKey: ['products'],
    queryFn: async () => {
      const { data } = await getProducts({ active_only: false });
      return data?.items || data || [];
    },
  });

  const { data: categories } = useQuery({
    queryKey: ['categories'],
    queryFn: async () => {
      const { data } = await getCategories(false);
      return data;
    },
  });

  const saveMutation = useMutation({
    mutationFn: async (payload) => {
      if (editProduct) return updateProduct(editProduct.id, payload);
      return createProduct(payload);
    },
    onSuccess: () => {
      qc.invalidateQueries(['products']);
      toast.success(editProduct ? 'Product updated!' : 'Product created!');
      setShowForm(false);
      setEditProduct(null);
      setForm(EMPTY_FORM);
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Save failed'),
  });

  const deleteMutation = useMutation({
    mutationFn: (id) => deleteProduct(id),
    onSuccess: () => { qc.invalidateQueries(['products']); toast.success('Product deleted'); },
    onError: (e) => toast.error(e.response?.data?.detail || 'Delete failed'),
  });

  const handleEdit = (p) => {
    setEditProduct(p);
    setForm({
      name: p.name, slug: p.slug, description: p.description || '',
      unit: p.unit, price_per_unit: p.price_per_unit,
      category_id: p.category_id, is_available: p.is_available, is_active: p.is_active
    });
    setShowForm(true);
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    saveMutation.mutate({ ...form, price_per_unit: parseFloat(form.price_per_unit) });
  };

  const filtered = (products || []).filter(p =>
    p.name.toLowerCase().includes(search.toLowerCase())
  );

  const getCatName = (id) => (categories || []).find(c => c.id === id)?.name || '—';

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <div>
          <h1 className="page-title">Products</h1>
          <p className="text-gray">{filtered.length} products in catalogue</p>
        </div>
        <button className="btn btn-primary" onClick={() => { setEditProduct(null); setForm(EMPTY_FORM); setShowForm(true); }}>
          <Plus size={16} style={{ marginRight: 6 }} /> Add Product
        </button>
      </div>

      {/* Search */}
      <div className="card" style={{ padding: '16px', marginBottom: '0' }}>
        <input className="form-control" placeholder="🔍  Search products..."
          value={search} onChange={e => setSearch(e.target.value)} style={{ maxWidth: 320 }} />
      </div>

      {/* Product Grid */}
      {isLoading ? (
        <div style={{ textAlign: 'center', padding: '64px', color: '#94a3b8' }}>Loading products...</div>
      ) : filtered.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '64px', color: '#94a3b8' }}>
          <Package size={48} style={{ margin: '0 auto 12px', opacity: 0.3 }} />
          <p>No products found</p>
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '16px' }}>
          {filtered.map(p => (
            <div key={p.id} className="card" style={{ padding: '20px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '6px' }}>
                    <h3 style={{ fontSize: '15px', fontWeight: 600, color: '#1e293b' }}>{p.name}</h3>
                    <span style={{
                      fontSize: '11px', padding: '2px 8px', borderRadius: '999px', fontWeight: 600,
                      background: p.is_active ? '#dcfce7' : '#fee2e2',
                      color: p.is_active ? '#16a34a' : '#dc2626'
                    }}>{p.is_active ? 'Active' : 'Inactive'}</span>
                  </div>
                  <p style={{ fontSize: '12px', color: '#64748b', marginBottom: '4px' }}>
                    📂 {getCatName(p.category_id)}
                  </p>
                  <p style={{ fontSize: '18px', fontWeight: 700, color: '#10b981' }}>
                    ₹{parseFloat(p.price_per_unit).toFixed(2)}
                    <span style={{ fontSize: '12px', color: '#94a3b8', fontWeight: 400 }}>/{p.unit}</span>
                  </p>
                  {p.description && (
                    <p style={{ fontSize: '12px', color: '#64748b', marginTop: '8px', lineHeight: 1.5 }}>
                      {p.description.slice(0, 80)}{p.description.length > 80 ? '...' : ''}
                    </p>
                  )}
                </div>
              </div>
              <div style={{ display: 'flex', gap: '8px', marginTop: '16px' }}>
                <button className="btn btn-outline" style={{ flex: 1, fontSize: '12px', padding: '6px' }}
                  onClick={() => handleEdit(p)}>
                  <Edit2 size={13} style={{ marginRight: 4 }} /> Edit
                </button>
                <button style={{
                  padding: '6px 12px', border: '1px solid #fee2e2', background: '#fff', color: '#dc2626',
                  borderRadius: '8px', cursor: 'pointer', fontSize: '12px', display: 'flex', alignItems: 'center', gap: 4
                }}
                  onClick={() => { if (window.confirm('Delete this product?')) deleteMutation.mutate(p.id); }}>
                  <Trash2 size={13} /> Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Add/Edit Modal */}
      {showForm && (
        <div style={{
          position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px'
        }}>
          <div className="card" style={{ width: '100%', maxWidth: 520, maxHeight: '90vh', overflowY: 'auto', padding: '28px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
              <h2 style={{ fontSize: '18px', fontWeight: 700 }}>
                {editProduct ? 'Edit Product' : 'Add New Product'}
              </h2>
              <button onClick={() => setShowForm(false)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}>
                <X size={20} />
              </button>
            </div>
            <form onSubmit={handleSubmit}>
              {[
                { label: 'Product Name *', key: 'name', type: 'text', required: true,
                  onChange: (v) => setForm(f => ({ ...f, name: v, slug: slugify(v) })) },
                { label: 'Slug', key: 'slug', type: 'text' },
                { label: 'Unit (pack / kg / litre)', key: 'unit', type: 'text' },
                { label: 'Price per Unit (₹) *', key: 'price_per_unit', type: 'number', required: true },
              ].map(({ label, key, type, required, onChange }) => (
                <div key={key} className="form-group">
                  <label className="form-label">{label}</label>
                  <input className="form-control" type={type} required={required}
                    value={form[key]} onChange={e => onChange
                      ? onChange(e.target.value)
                      : setForm(f => ({ ...f, [key]: e.target.value }))} />
                </div>
              ))}
              <div className="form-group">
                <label className="form-label">Category *</label>
                <select className="form-control" required value={form.category_id}
                  onChange={e => setForm(f => ({ ...f, category_id: e.target.value }))}>
                  <option value="">Select category...</option>
                  {(categories || []).map(c => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>
              <div className="form-group">
                <label className="form-label">Description</label>
                <textarea className="form-control" rows={3} value={form.description}
                  onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
              </div>
              <div style={{ display: 'flex', gap: '16px', marginBottom: '16px' }}>
                {[
                  { label: 'Available', key: 'is_available' },
                  { label: 'Active', key: 'is_active' }
                ].map(({ label, key }) => (
                  <label key={key} style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer' }}>
                    <input type="checkbox" checked={form[key]}
                      onChange={e => setForm(f => ({ ...f, [key]: e.target.checked }))} />
                    {label}
                  </label>
                ))}
              </div>
              <div style={{ display: 'flex', gap: '12px' }}>
                <button type="button" className="btn btn-outline" style={{ flex: 1 }}
                  onClick={() => setShowForm(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary" style={{ flex: 1 }}
                  disabled={saveMutation.isPending}>
                  {saveMutation.isPending ? 'Saving...' : editProduct ? 'Update Product' : 'Add Product'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
