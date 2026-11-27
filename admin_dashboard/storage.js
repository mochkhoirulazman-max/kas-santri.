/**
 * Kas-Santri Admin Command Center — Dual-Mode Storage Engine (Offline LocalStorage & Supabase Cloud)
 */
(function (root) {
  'use strict';

  const KEYS = {
    CUSTOMERS: 'ks_admin_customers_v1',
    TRANSACTIONS: 'ks_admin_transactions_v1',
    REMOTE_CONFIG: 'ks_admin_remote_config_v1',
    OFFLINE_AUTH: 'ks_admin_offline_auth_v1',
    SUPABASE_CFG: 'ks_admin_supabase_cfg_v1',
    SUPABASE_SESSION: 'ks_admin_supabase_session_v1',
    ED25519_SEED: 'ks_admin_ed25519_seed_session_v1',
  };

  const DEFAULT_REMOTE_CONFIG = {
    id: 1,
    latest_version: '4.3.0',
    min_version: '3.0.0',
    announcement_title: '',
    announcement_body: '',
    promo_banner_active: false,
    update_url: 'https://mochkhoirulazman-max.github.io/kas-santri./',
    updated_at: new Date().toISOString(),
  };

  function safeParse(raw, fallback) {
    try {
      return raw ? JSON.parse(raw) : fallback;
    } catch (_) {
      return fallback;
    }
  }

  function utf8ToBytes(text) {
    if (typeof TextEncoder !== 'undefined') {
      return new TextEncoder().encode(text);
    }
    const encoded = unescape(encodeURIComponent(text));
    const out = new Uint8Array(encoded.length);
    for (let i = 0; i < encoded.length; i++) {
      out[i] = encoded.charCodeAt(i);
    }
    return out;
  }

  async function sha256Hex(text) {
    const inputBytes = utf8ToBytes(text);
    if (typeof crypto !== 'undefined' && crypto.subtle) {
      const buf = await crypto.subtle.digest('SHA-256', inputBytes);
      return Array.from(new Uint8Array(buf))
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('');
    }
    // Fallback kriptografis penuh menggunakan SHA-512 RFC 8032 lokal dari ed25519.js (bukan hash 64-bit lemah)
    if (root.KasSantriEd25519 && typeof root.KasSantriEd25519.sha512 === 'function') {
      const digest512 = root.KasSantriEd25519.sha512(inputBytes);
      return Array.from(digest512.slice(0, 32))
        .map((b) => b.toString(16).padStart(2, '0'))
        .join('');
    }
    throw new Error('Mesin kriptografi lokal (WebCrypto / KasSantriEd25519) tidak tersedia.');
  }

  function randomSaltHex() {
    const bytes = new Uint8Array(12);
    if (typeof crypto !== 'undefined' && crypto.getRandomValues) {
      crypto.getRandomValues(bytes);
    } else {
      for (let i = 0; i < bytes.length; i++) bytes[i] = Math.floor(Math.random() * 256);
    }
    return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('');
  }

  function generateUuid() {
    if (typeof crypto !== 'undefined' && crypto.randomUUID) return crypto.randomUUID();
    return 'tx-' + Date.now() + '-' + Math.random().toString(16).slice(2, 10);
  }

  const AdminStore = {
    // --- Config & Session ---
    getSupabaseConfig() {
      return safeParse(localStorage.getItem(KEYS.SUPABASE_CFG), { url: '', anonKey: '' });
    },

    saveSupabaseConfig(url, anonKey) {
      const cleanUrl = String(url || '').trim().replace(/\/+$/, '');
      const cleanKey = String(anonKey || '').trim();
      localStorage.setItem(KEYS.SUPABASE_CFG, JSON.stringify({ url: cleanUrl, anonKey: cleanKey }));
      return { url: cleanUrl, anonKey: cleanKey };
    },

    isSupabaseConfigured() {
      const cfg = this.getSupabaseConfig();
      return cfg.url.startsWith('https://') && cfg.anonKey.length > 20;
    },

    getSupabaseSession() {
      const sess = safeParse(sessionStorage.getItem(KEYS.SUPABASE_SESSION), null);
      if (sess) return sess;
      // Migrasi satu kali jika ada sesi lama di localStorage, lalu bersihkan dari localStorage
      const legacy = safeParse(localStorage.getItem(KEYS.SUPABASE_SESSION), null);
      if (legacy) {
        sessionStorage.setItem(KEYS.SUPABASE_SESSION, JSON.stringify(legacy));
        localStorage.removeItem(KEYS.SUPABASE_SESSION);
        return legacy;
      }
      return null;
    },

    getActiveMode() {
      const sess = this.getSupabaseSession();
      if (sess && sess.access_token && this.isSupabaseConfigured()) {
        return 'CLOUD';
      }
      return 'OFFLINE';
    },

    hasOfflinePasswordConfigured() {
      const rec = safeParse(localStorage.getItem(KEYS.OFFLINE_AUTH), null);
      return Boolean(rec && rec.hash && rec.salt);
    },

    async setupOrUpdateOfflinePassword(password) {
      const clean = String(password || '').trim();
      if (clean.length < 4) {
        throw new Error('PIN/Password Admin minimal 4 karakter.');
      }
      const salt = randomSaltHex();
      const hash = await sha256Hex(`ks_admin_v34:${salt}:${clean}`);
      localStorage.setItem(KEYS.OFFLINE_AUTH, JSON.stringify({ salt, hash, updatedAt: new Date().toISOString() }));
      sessionStorage.setItem('ks_admin_offline_unlocked', '1');
      return true;
    },

    async verifyOfflineLogin(password) {
      const rec = safeParse(localStorage.getItem(KEYS.OFFLINE_AUTH), null);
      if (!rec || !rec.hash || !rec.salt) {
        // Pertama kali dipakai -> otomatis buat password awal
        await this.setupOrUpdateOfflinePassword(password);
        return true;
      }
      const candidate = await sha256Hex(`ks_admin_v34:${rec.salt}:${String(password || '').trim()}`);
      if (candidate === rec.hash) {
        sessionStorage.setItem('ks_admin_offline_unlocked', '1');
        return true;
      }
      return false;
    },

    isSessionAuthenticated() {
      if (this.getActiveMode() === 'CLOUD') return true;
      return sessionStorage.getItem('ks_admin_offline_unlocked') === '1';
    },

    async loginSupabase(email, password) {
      const cfg = this.getSupabaseConfig();
      if (!cfg.url || !cfg.anonKey) {
        throw new Error('URL & Anon Key Supabase belum diisi.');
      }
      const resp = await fetch(`${cfg.url}/auth/v1/token?grant_type=password`, {
        method: 'POST',
        headers: {
          apikey: cfg.anonKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email: String(email || '').trim(), password }),
      });
      const json = await resp.json().catch(() => ({}));
      if (!resp.ok || !json.access_token) {
        throw new Error(json.error_description || json.msg || 'Login Supabase gagal. Periksa email/password Admin.');
      }
      const sessionPayload = {
        access_token: json.access_token,
        refresh_token: json.refresh_token,
        email: json.user?.email || email,
        user_id: json.user?.id || '',
        logged_in_at: new Date().toISOString(),
      };
      sessionStorage.setItem(KEYS.SUPABASE_SESSION, JSON.stringify(sessionPayload));
      localStorage.removeItem(KEYS.SUPABASE_SESSION);
      return json;
    },

    async refreshSupabaseSession() {
      const cfg = this.getSupabaseConfig();
      const sess = this.getSupabaseSession();
      if (!cfg.url || !cfg.anonKey || !sess?.refresh_token) {
        return null;
      }
      try {
        const resp = await fetch(`${cfg.url}/auth/v1/token?grant_type=refresh_token`, {
          method: 'POST',
          headers: {
            apikey: cfg.anonKey,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ refresh_token: sess.refresh_token }),
        });
        const json = await resp.json().catch(() => ({}));
        if (!resp.ok || !json.access_token) {
          return null;
        }
        const nextSess = {
          access_token: json.access_token,
          refresh_token: json.refresh_token || sess.refresh_token,
          email: json.user?.email || sess.email || '',
          user_id: json.user?.id || sess.user_id || '',
          logged_in_at: new Date().toISOString(),
        };
        sessionStorage.setItem(KEYS.SUPABASE_SESSION, JSON.stringify(nextSess));
        localStorage.removeItem(KEYS.SUPABASE_SESSION);
        return nextSess;
      } catch (_) {
        return null;
      }
    },

    logout() {
      sessionStorage.removeItem('ks_admin_offline_unlocked');
      sessionStorage.removeItem(KEYS.SUPABASE_SESSION);
      localStorage.removeItem(KEYS.SUPABASE_SESSION);
    },

    // --- Ed25519 Private Seed (disimpan di sessionStorage by default agar tidak bocor persisten) ---
    getEd25519Seed() {
      return sessionStorage.getItem(KEYS.ED25519_SEED) || '';
    },

    setEd25519Seed(seedBase64) {
      const clean = String(seedBase64 || '').trim();
      if (!clean) {
        sessionStorage.removeItem(KEYS.ED25519_SEED);
      } else {
        sessionStorage.setItem(KEYS.ED25519_SEED, clean);
      }
    },

    // --- Supabase HTTP Helper (dengan Auto-Refresh Token saat HTTP 401) ---
    async _sbFetch(path, options = {}, _retried = false) {
      const cfg = this.getSupabaseConfig();
      let sess = this.getSupabaseSession();
      if (!cfg.url || !cfg.anonKey || !sess?.access_token) {
        throw new Error('Sesi Cloud Supabase belum aktif.');
      }
      const headers = {
        apikey: cfg.anonKey,
        Authorization: `Bearer ${sess.access_token}`,
        'Content-Type': 'application/json',
        ...(options.headers || {}),
      };
      const resp = await fetch(`${cfg.url}${path}`, { ...options, headers });
      if (resp.status === 401) {
        if (!_retried && sess.refresh_token) {
          const refreshed = await this.refreshSupabaseSession();
          if (refreshed && refreshed.access_token) {
            return this._sbFetch(path, options, true);
          }
        }
        this.logout();
        throw new Error('Sesi Supabase habis. Silakan login ulang.');
      }
      const text = await resp.text();
      const data = text ? safeParse(text, text) : null;
      if (!resp.ok) {
        throw new Error((data && data.message) || (data && data.hint) || `HTTP ${resp.status}`);
      }
      return data;
    },

    // --- Read All ---
    async fetchAllData() {
      if (this.getActiveMode() === 'CLOUD') {
        const [customers, transactions, cfgRows] = await Promise.all([
          this._sbFetch('/rest/v1/app_customers?select=*&order=last_seen_at.desc'),
          this._sbFetch('/rest/v1/license_transactions?select=*&order=created_at.desc'),
          this._sbFetch('/rest/v1/app_remote_config?id=eq.1&select=*'),
        ]);
        const remoteConfig = Array.isArray(cfgRows) && cfgRows[0] ? cfgRows[0] : { ...DEFAULT_REMOTE_CONFIG };
        // Cache lokal untuk fallback baca
        localStorage.setItem(KEYS.CUSTOMERS, JSON.stringify(customers || []));
        localStorage.setItem(KEYS.TRANSACTIONS, JSON.stringify(transactions || []));
        localStorage.setItem(KEYS.REMOTE_CONFIG, JSON.stringify(remoteConfig));
        return {
          customers: Array.isArray(customers) ? customers : [],
          transactions: Array.isArray(transactions) ? transactions : [],
          remoteConfig,
        };
      }

      return {
        customers: safeParse(localStorage.getItem(KEYS.CUSTOMERS), []),
        transactions: safeParse(localStorage.getItem(KEYS.TRANSACTIONS), []),
        remoteConfig: safeParse(localStorage.getItem(KEYS.REMOTE_CONFIG), { ...DEFAULT_REMOTE_CONFIG }),
      };
    },

    // --- CRUD Customers ---
    async upsertCustomer(customer) {
      const nowIso = new Date().toISOString();
      const normalized = {
        device_id: String(customer.device_id || '').trim().toUpperCase(),
        nama_pondok: String(customer.nama_pondok || '').trim(),
        nama_bendahara: String(customer.nama_bendahara || '').trim(),
        no_wa: String(customer.no_wa || '').trim(),
        tier: String(customer.tier || 'FREE').toUpperCase(),
        status: String(customer.status || 'GRATIS').toUpperCase(),
        expiry_date: customer.expiry_date || null,
        trial_started_at: customer.trial_started_at || null,
        last_seen_at: customer.last_seen_at || nowIso,
        app_version: String(customer.app_version || '4.3.0').trim(),
        total_paid_idr: Number(customer.total_paid_idr || 0),
        payment_channel: String(customer.payment_channel || 'FREE').toUpperCase(),
        is_revoked: Boolean(customer.is_revoked),
        notes: customer.notes || '',
        updated_at: nowIso,
      };

      if (!normalized.device_id) throw new Error('Device ID wajib diisi.');

      if (this.getActiveMode() === 'CLOUD') {
        const res = await this._sbFetch('/rest/v1/app_customers?on_conflict=device_id', {
          method: 'POST',
          headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
          body: JSON.stringify(normalized),
        });
        return Array.isArray(res) ? res[0] : normalized;
      }

      const list = safeParse(localStorage.getItem(KEYS.CUSTOMERS), []);
      const idx = list.findIndex((c) => c.device_id === normalized.device_id);
      if (idx >= 0) {
        normalized.created_at = list[idx].created_at || nowIso;
        list[idx] = { ...list[idx], ...normalized };
      } else {
        normalized.created_at = nowIso;
        list.unshift(normalized);
      }
      localStorage.setItem(KEYS.CUSTOMERS, JSON.stringify(list));
      return normalized;
    },

    async deleteCustomer(deviceId) {
      const id = String(deviceId || '').trim().toUpperCase();
      if (this.getActiveMode() === 'CLOUD') {
        await this._sbFetch(`/rest/v1/app_customers?device_id=eq.${encodeURIComponent(id)}`, {
          method: 'DELETE',
        });
        return true;
      }
      const list = safeParse(localStorage.getItem(KEYS.CUSTOMERS), []).filter((c) => c.device_id !== id);
      const txs = safeParse(localStorage.getItem(KEYS.TRANSACTIONS), []).filter((t) => t.device_id !== id);
      localStorage.setItem(KEYS.CUSTOMERS, JSON.stringify(list));
      localStorage.setItem(KEYS.TRANSACTIONS, JSON.stringify(txs));
      return true;
    },

    async recordTransaction(tx) {
      const payload = {
        id: tx.id || generateUuid(),
        device_id: String(tx.device_id || '').trim().toUpperCase(),
        paket: String(tx.paket || 'YEARLY').toUpperCase(),
        nominal_idr: Number(tx.nominal_idr || 0),
        metode_bayar: String(tx.metode_bayar || 'DANA').toUpperCase(),
        kode_lisensi: tx.kode_lisensi || '',
        created_at: tx.created_at || new Date().toISOString(),
      };

      if (this.getActiveMode() === 'CLOUD') {
        const res = await this._sbFetch('/rest/v1/license_transactions', {
          method: 'POST',
          headers: { Prefer: 'return=representation' },
          body: JSON.stringify({
            device_id: payload.device_id,
            paket: payload.paket,
            nominal_idr: payload.nominal_idr,
            metode_bayar: payload.metode_bayar,
            kode_lisensi: payload.kode_lisensi,
          }),
        });
        return Array.isArray(res) ? res[0] : payload;
      }

      const list = safeParse(localStorage.getItem(KEYS.TRANSACTIONS), []);
      list.unshift(payload);
      localStorage.setItem(KEYS.TRANSACTIONS, JSON.stringify(list));
      return payload;
    },

    async toggleRevoke(deviceId, isRevoked) {
      const id = String(deviceId || '').trim().toUpperCase();
      const { customers } = await this.fetchAllData();
      const target = customers.find((c) => c.device_id === id);
      if (!target) throw new Error('Pelanggan tidak ditemukan.');

      const nextStatus = isRevoked
        ? 'DIBLOKIR'
        : target.tier === 'TRIAL_14D'
        ? 'TRIAL'
        : ['MONTHLY', 'YEARLY', 'LIFETIME'].includes(target.tier)
        ? 'AKTIF'
        : 'GRATIS';

      return this.upsertCustomer({
        ...target,
        is_revoked: Boolean(isRevoked),
        status: nextStatus,
      });
    },

    async saveRemoteConfig(cfg) {
      const payload = {
        id: 1,
        latest_version: String(cfg.latest_version || '4.3.0').trim(),
        min_version: String(cfg.min_version || '3.0.0').trim(),
        announcement_title: String(cfg.announcement_title || '').trim(),
        announcement_body: String(cfg.announcement_body || '').trim(),
        promo_banner_active: Boolean(cfg.promo_banner_active),
        update_url: String(cfg.update_url || '').trim(),
        updated_at: new Date().toISOString(),
      };

      if (this.getActiveMode() === 'CLOUD') {
        const res = await this._sbFetch('/rest/v1/app_remote_config?on_conflict=id', {
          method: 'POST',
          headers: { Prefer: 'resolution=merge-duplicates,return=representation' },
          body: JSON.stringify(payload),
        });
        return Array.isArray(res) ? res[0] : payload;
      }

      localStorage.setItem(KEYS.REMOTE_CONFIG, JSON.stringify(payload));
      return payload;
    },

    async seedSampleDataIfOffline() {
      if (this.getActiveMode() !== 'OFFLINE') return false;
      const now = Date.now();
      const dayMs = 86400000;
      const samples = [
        {
          device_id: 'KS-9A2B4C1D',
          nama_pondok: 'PP Al-Ikhlas Nusantara',
          nama_bendahara: 'Ustadz Ahmad Fauzi',
          no_wa: '081234567890',
          tier: 'YEARLY',
          status: 'AKTIF',
          expiry_date: new Date(now + 280 * dayMs).toISOString(),
          last_seen_at: new Date(now - 2 * 3600000).toISOString(),
          app_version: '4.3.0',
          total_paid_idr: 179000,
          payment_channel: 'DANA',
          is_revoked: false,
          notes: 'Aktivasi via DANA 082130678956',
        },
        {
          device_id: 'KS-4F8E2D7A',
          nama_pondok: 'PP Darussalam Putra',
          nama_bendahara: 'Ustadz Ridwan',
          no_wa: '085612349876',
          tier: 'TRIAL_14D',
          status: 'TRIAL',
          trial_started_at: new Date(now - 11 * dayMs).toISOString(),
          expiry_date: new Date(now + 3 * dayMs).toISOString(),
          last_seen_at: new Date(now - 5 * 3600000).toISOString(),
          app_version: '4.3.0',
          total_paid_idr: 0,
          payment_channel: 'TRIAL',
          is_revoked: false,
          notes: 'Trial hari ke-11, siap follow-up',
        },
        {
          device_id: 'KS-7C3D9E2B',
          nama_pondok: 'PP Al-Hikmah Putri',
          nama_bendahara: 'Ustadzah Siti Aminah',
          no_wa: '082298765432',
          tier: 'LIFETIME',
          status: 'AKTIF',
          expiry_date: null,
          last_seen_at: new Date(now - 12 * 3600000).toISOString(),
          app_version: '4.3.0',
          total_paid_idr: 399000,
          payment_channel: 'DANA',
          is_revoked: false,
          notes: 'Paket Lifetime Yayasan',
        },
        {
          device_id: 'KS-5B1E6A9C',
          nama_pondok: 'PP Nurul Jadid Timur',
          nama_bendahara: 'Ustadz Hasan',
          no_wa: '087711223344',
          tier: 'MONTHLY',
          status: 'AKTIF',
          expiry_date: new Date(now + 5 * dayMs).toISOString(),
          last_seen_at: new Date(now - 1 * dayMs).toISOString(),
          app_version: '3.3.0',
          total_paid_idr: 25000,
          payment_channel: 'PLAY_STORE',
          is_revoked: false,
          notes: 'Hampir habis (< 7 hari)',
        },
      ];
      const txs = [
        {
          id: generateUuid(),
          device_id: 'KS-9A2B4C1D',
          paket: 'YEARLY',
          nominal_idr: 179000,
          metode_bayar: 'DANA',
          kode_lisensi: 'KSPRO-CONTOH-TAHUNAN',
          created_at: new Date(now - 20 * dayMs).toISOString(),
        },
        {
          id: generateUuid(),
          device_id: 'KS-7C3D9E2B',
          paket: 'LIFETIME',
          nominal_idr: 399000,
          metode_bayar: 'DANA',
          kode_lisensi: 'KSPRO-CONTOH-LIFETIME',
          created_at: new Date(now - 5 * dayMs).toISOString(),
        },
        {
          id: generateUuid(),
          device_id: 'KS-5B1E6A9C',
          paket: 'MONTHLY',
          nominal_idr: 25000,
          metode_bayar: 'PLAY_STORE',
          kode_lisensi: 'PLAY-STORE-BILLING',
          created_at: new Date(now - 25 * dayMs).toISOString(),
        },
      ];
      localStorage.setItem(KEYS.CUSTOMERS, JSON.stringify(samples));
      localStorage.setItem(KEYS.TRANSACTIONS, JSON.stringify(txs));
      return true;
    },

    async importJson(rawObj) {
      if (!rawObj || !Array.isArray(rawObj.customers)) {
        throw new Error('Format JSON backup Admin tidak valid.');
      }
      if (this.getActiveMode() === 'OFFLINE') {
        localStorage.setItem(KEYS.CUSTOMERS, JSON.stringify(rawObj.customers));
        localStorage.setItem(KEYS.TRANSACTIONS, JSON.stringify(rawObj.transactions || []));
        if (rawObj.remoteConfig) {
          localStorage.setItem(KEYS.REMOTE_CONFIG, JSON.stringify(rawObj.remoteConfig));
        }
        return true;
      }
      for (const c of rawObj.customers) {
        await this.upsertCustomer(c);
      }
      if (rawObj.remoteConfig) {
        await this.saveRemoteConfig(rawObj.remoteConfig);
      }
      return true;
    },
  };

  root.AdminStore = AdminStore;
})(typeof window !== 'undefined' ? window : globalThis);
