/**
 * Kas-Santri Admin Command Center — UI Controller
 */
(function () {
  'use strict';

  const state = {
    customers: [],
    transactions: [],
    remoteConfig: null,
    searchQuery: '',
    statusFilter: 'ALL',
    revenueChart: null,
    growthChart: null,
    lastGeneratedCode: '',
    lastGeneratedWaMessage: '',
  };

  const $ = (id) => document.getElementById(id);

  function showToast(msg, isError = false) {
    const el = $('toast');
    if (!el) return;
    el.textContent = msg;
    el.className = isError ? 'toast error' : 'toast';
    setTimeout(() => {
      el.classList.add('hidden');
    }, 3400);
  }

  function formatIdr(val) {
    const num = Number(val || 0);
    return 'Rp ' + num.toLocaleString('id-ID');
  }

  function formatDateShort(iso) {
    if (!iso) return '-';
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return '-';
    return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  function daysUntil(iso) {
    if (!iso) return null;
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return null;
    return Math.ceil((d.getTime() - Date.now()) / 86400000);
  }

  function daysSince(iso) {
    if (!iso) return null;
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return null;
    return Math.floor((Date.now() - d.getTime()) / 86400000);
  }

  function normalizeWaPhone(raw) {
    let digits = String(raw || '').replace(/\D/g, '');
    if (!digits) return '';
    if (digits.startsWith('0')) digits = '62' + digits.slice(1);
    if (!digits.startsWith('62') && digits.startsWith('8')) digits = '62' + digits;
    return digits;
  }

  function deriveEffectiveStatus(c) {
    if (c.is_revoked || c.status === 'DIBLOKIR') return 'DIBLOKIR';
    const rem = daysUntil(c.expiry_date);
    if (c.tier === 'TRIAL_14D') {
      if (rem !== null && rem < 0) return 'EXPIRED';
      return 'TRIAL';
    }
    if (['MONTHLY', 'YEARLY', 'LIFETIME'].includes(c.tier)) {
      if (c.tier !== 'LIFETIME' && rem !== null && rem < 0) return 'EXPIRED';
      return 'AKTIF';
    }
    return 'GRATIS';
  }

  function isExpiringSoonOrHotTrial(c) {
    const eff = deriveEffectiveStatus(c);
    if (eff === 'DIBLOKIR' || eff === 'EXPIRED') return false;
    const rem = daysUntil(c.expiry_date);
    if (eff === 'AKTIF' && c.tier !== 'LIFETIME' && rem !== null && rem <= 7 && rem >= 0) {
      return true;
    }
    if (eff === 'TRIAL') {
      const elapsed = daysSince(c.trial_started_at);
      if ((elapsed !== null && elapsed >= 10) || (rem !== null && rem <= 4 && rem >= 0)) {
        return true;
      }
    }
    return false;
  }

  function escapeHtml(str) {
    return String(str || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // --- LOGIN GATE ---
  function initLoginGate() {
    const sbCfg = AdminStore.getSupabaseConfig();
    if (sbCfg.url) $('loginSbUrl').value = sbCfg.url;
    if (sbCfg.anonKey) $('loginSbAnonKey').value = sbCfg.anonKey;

    if (!AdminStore.hasOfflinePasswordConfigured()) {
      $('offlinePasswordLabel').textContent = 'Buat Password Admin Lokal Pertama Kali';
      $('offlineFirstTimeHint').classList.remove('hidden');
    }

    $('tabLoginOffline').addEventListener('click', () => {
      $('tabLoginOffline').classList.add('active');
      $('tabLoginCloud').classList.remove('active');
      $('formOfflineLogin').classList.remove('hidden');
      $('formCloudLogin').classList.add('hidden');
    });

    $('tabLoginCloud').addEventListener('click', () => {
      $('tabLoginCloud').classList.add('active');
      $('tabLoginOffline').classList.remove('active');
      $('formCloudLogin').classList.remove('hidden');
      $('formOfflineLogin').classList.add('hidden');
    });

    $('formOfflineLogin').addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        const pwd = $('offlinePasswordInput').value;
        const ok = await AdminStore.verifyOfflineLogin(pwd);
        if (!ok) {
          showToast('Password Admin lokal tidak cocok.', true);
          return;
        }
        await enterDashboard();
      } catch (err) {
        showToast(err.message || 'Gagal membuka Mode Offline.', true);
      }
    });

    $('formCloudLogin').addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        AdminStore.saveSupabaseConfig($('loginSbUrl').value, $('loginSbAnonKey').value);
        await AdminStore.loginSupabase($('loginSbEmail').value, $('loginSbPassword').value);
        await enterDashboard();
        showToast('Berhasil login ke Supabase Cloud!');
      } catch (err) {
        showToast(err.message || 'Gagal login Supabase Cloud.', true);
      }
    });

    if (AdminStore.isSessionAuthenticated()) {
      enterDashboard();
    }
  }

  async function enterDashboard() {
    $('loginOverlay').classList.add('hidden');
    $('appShell').classList.remove('hidden');
    updateModeBadge();
    loadEd25519KeyIntoUi();
    await refreshDashboardData();
  }

  function updateModeBadge() {
    const mode = AdminStore.getActiveMode();
    const badge = $('modeBadge');
    const sess = AdminStore.getSupabaseSession();
    if (mode === 'CLOUD') {
      badge.textContent = `☁️ Supabase Cloud (${sess?.email || 'Admin'})`;
      badge.className = 'badge badge-aktif';
      $('btnSeedDemo').classList.add('hidden');
    } else {
      badge.textContent = '💾 Mode Offline (LocalStorage)';
      badge.className = 'badge badge-trial';
      $('btnSeedDemo').classList.remove('hidden');
    }
  }

  async function refreshDashboardData() {
    try {
      const data = await AdminStore.fetchAllData();
      state.customers = data.customers || [];
      state.transactions = data.transactions || [];
      state.remoteConfig = data.remoteConfig || {};
      renderAll();
    } catch (err) {
      showToast('Gagal memuat data: ' + err.message, true);
    }
  }

  // --- RENDERING ---
  function renderAll() {
    renderKpis();
    renderCharts();
    renderCrmTable();
    renderTransactionsTable();
    renderRemoteConfigForm();
  }

  function renderKpis() {
    const now = new Date();
    const curYm = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

    let totalOmset = 0;
    let monthOmset = 0;
    for (const tx of state.transactions) {
      const nom = Number(tx.nominal_idr || 0);
      totalOmset += nom;
      if (String(tx.created_at || '').startsWith(curYm)) {
        monthOmset += nom;
      }
    }

    let proCount = 0;
    let monthlyCount = 0;
    let yearlyCount = 0;
    let lifetimeCount = 0;
    let trialCount = 0;
    let hotTrialCount = 0;
    let freeOrExpired = 0;
    let expiringSoon = 0;
    let revokedCount = 0;

    for (const c of state.customers) {
      const st = deriveEffectiveStatus(c);
      if (st === 'DIBLOKIR') {
        revokedCount++;
        continue;
      }
      if (st === 'AKTIF') {
        proCount++;
        if (c.tier === 'MONTHLY') monthlyCount++;
        if (c.tier === 'YEARLY') yearlyCount++;
        if (c.tier === 'LIFETIME') lifetimeCount++;
        const rem = daysUntil(c.expiry_date);
        if (c.tier !== 'LIFETIME' && rem !== null && rem <= 7 && rem >= 0) {
          expiringSoon++;
        }
      } else if (st === 'TRIAL') {
        trialCount++;
        if (isExpiringSoonOrHotTrial(c)) hotTrialCount++;
      } else {
        freeOrExpired++;
      }
    }

    $('kpiTotalOmset').textContent = formatIdr(totalOmset);
    $('kpiTxCount').textContent = `${state.transactions.length} transaksi lisensi tercatat`;
    $('kpiMonthOmset').textContent = formatIdr(monthOmset);
    $('kpiMonthLabel').textContent = `Bulan ${now.toLocaleDateString('id-ID', { month: 'long', year: 'numeric' })}`;
    $('kpiActivePro').textContent = String(proCount);
    $('kpiActiveBreakdown').textContent = `${monthlyCount} Bulanan • ${yearlyCount} Tahunan • ${lifetimeCount} Lifetime`;
    $('kpiTrialCount').textContent = String(trialCount);
    $('kpiTrialHot').textContent = `${hotTrialCount} siap follow-up (hari ke-10+)`;
    $('kpiFreeCount').textContent = String(freeOrExpired);
    $('kpiExpiringSoon').textContent = String(expiringSoon);
    $('kpiRevokedCount').textContent = `${revokedCount} lisensi dicabut admin`;
  }

  function renderCharts() {
    const revMap = new Map();
    const now = new Date();
    for (let i = 5; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const ym = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      revMap.set(ym, 0);
    }
    for (const tx of state.transactions) {
      const ym = String(tx.created_at || '').slice(0, 7);
      if (revMap.has(ym)) {
        revMap.set(ym, revMap.get(ym) + Number(tx.nominal_idr || 0));
      }
    }
    const labels = Array.from(revMap.keys());
    const revValues = Array.from(revMap.values());

    const counts = { AKTIF: 0, TRIAL: 0, GRATIS: 0, EXPIRED: 0, DIBLOKIR: 0 };
    for (const c of state.customers) {
      counts[deriveEffectiveStatus(c)] = (counts[deriveEffectiveStatus(c)] || 0) + 1;
    }

    if (typeof Chart === 'undefined') {
      $('revenueChart').classList.add('hidden');
      $('growthChart').classList.add('hidden');
      $('chartOfflineFallback1').classList.remove('hidden');
      $('chartOfflineFallback2').classList.remove('hidden');
      $('chartOfflineFallback1').textContent =
        'Mode Offline tanpa internet: grafik Chart.js tidak dimuat. Omset 6 bulan: ' +
        labels.map((l, i) => `${l}: ${formatIdr(revValues[i])}`).join(' | ');
      $('chartOfflineFallback2').textContent =
        `Komposisi Pondok: Aktif PRO ${counts.AKTIF}, Trial ${counts.TRIAL}, Gratis ${counts.GRATIS}, Expired ${counts.EXPIRED}, Diblokir ${counts.DIBLOKIR}.`;
      return;
    }

    $('revenueChart').classList.remove('hidden');
    $('growthChart').classList.remove('hidden');
    $('chartOfflineFallback1').classList.add('hidden');
    $('chartOfflineFallback2').classList.add('hidden');

    if (state.revenueChart) state.revenueChart.destroy();
    state.revenueChart = new Chart($('revenueChart'), {
      type: 'bar',
      data: {
        labels,
        datasets: [
          {
            label: 'Omset (Rp)',
            data: revValues,
            backgroundColor: 'rgba(52, 211, 153, 0.55)',
            borderColor: '#34d399',
            borderWidth: 1.5,
            borderRadius: 8,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { labels: { color: '#cbd5e1' } } },
        scales: {
          x: { ticks: { color: '#94a3b8' }, grid: { color: 'rgba(255,255,255,0.05)' } },
          y: { ticks: { color: '#94a3b8' }, grid: { color: 'rgba(255,255,255,0.05)' } },
        },
      },
    });

    if (state.growthChart) state.growthChart.destroy();
    state.growthChart = new Chart($('growthChart'), {
      type: 'doughnut',
      data: {
        labels: ['Aktif PRO', 'Trial 14 Hari', 'Gratis', 'Expired', 'Diblokir'],
        datasets: [
          {
            data: [counts.AKTIF, counts.TRIAL, counts.GRATIS, counts.EXPIRED, counts.DIBLOKIR],
            backgroundColor: ['#34d399', '#38bdf8', '#64748b', '#fbbf24', '#fb7185'],
            borderColor: '#040812',
            borderWidth: 2,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { position: 'bottom', labels: { color: '#cbd5e1', font: { size: 11 } } } },
      },
    });
  }

  function renderCrmTable() {
    const q = state.searchQuery.trim().toLowerCase();
    const filter = state.statusFilter;

    const filtered = state.customers.filter((c) => {
      const eff = deriveEffectiveStatus(c);
      if (filter === 'EXPIRING') {
        if (!isExpiringSoonOrHotTrial(c)) return false;
      } else if (filter !== 'ALL' && eff !== filter) {
        return false;
      }
      if (!q) return true;
      return (
        String(c.nama_pondok || '').toLowerCase().includes(q) ||
        String(c.nama_bendahara || '').toLowerCase().includes(q) ||
        String(c.no_wa || '').toLowerCase().includes(q) ||
        String(c.device_id || '').toLowerCase().includes(q)
      );
    });

    const tbody = $('crmTableBody');
    if (filtered.length === 0) {
      tbody.innerHTML =
        '<tr><td colspan="9" style="text-align:center; color:var(--text-muted); padding:26px;">Belum ada data pelanggan yang cocok dengan filter ini.</td></tr>';
      return;
    }

    tbody.innerHTML = filtered
      .map((c) => {
        const eff = deriveEffectiveStatus(c);
        const badgeCls =
          eff === 'AKTIF'
            ? 'badge-aktif'
            : eff === 'TRIAL'
            ? 'badge-trial'
            : eff === 'DIBLOKIR'
            ? 'badge-blocked'
            : eff === 'EXPIRED'
            ? 'badge-warn'
            : 'badge-gratis';
        const rem = daysUntil(c.expiry_date);
        const remText =
          c.tier === 'LIFETIME'
            ? 'Selamanya'
            : rem === null
            ? '-'
            : rem >= 0
            ? `${rem} hari lagi`
            : `Lewat ${Math.abs(rem)} hari`;
        const showFollowUp = isExpiringSoonOrHotTrial(c) || eff === 'EXPIRED';
        const revLabel = c.is_revoked ? 'Aktifkan' : 'Blokir';

        return `
          <tr>
            <td>
              <div style="font-weight:800; color:#fff;">${escapeHtml(c.nama_pondok || 'Pondok Belum Diisi')}</div>
              <div style="font-size:11px; color:var(--text-muted);">${escapeHtml(c.nama_bendahara || '-')}</div>
            </td>
            <td class="mono">${escapeHtml(c.no_wa || '-')}</td>
            <td class="mono" style="color:var(--gold-soft); font-weight:700;">${escapeHtml(c.device_id)}</td>
            <td>
              <div style="font-weight:700;">${escapeHtml(c.tier)}</div>
              <div style="font-size:10.5px; color:var(--text-muted);">${escapeHtml(c.payment_channel || 'FREE')}</div>
            </td>
            <td style="font-weight:800; color:var(--emerald);">${formatIdr(c.total_paid_idr)}</td>
            <td>
              <div>${c.tier === 'LIFETIME' ? 'Lifetime' : formatDateShort(c.expiry_date)}</div>
              <div style="font-size:10.5px; color:var(--text-muted);">${remText}</div>
            </td>
            <td class="mono">v${escapeHtml(c.app_version || '4.3.0')}</td>
            <td><span class="badge ${badgeCls}">${eff}</span></td>
            <td>
              <div style="display:flex; flex-wrap:wrap; gap:5px;">
                <button type="button" class="btn btn-outline btn-sm" data-action="edit" data-id="${escapeHtml(c.device_id)}">Edit</button>
                <button type="button" class="btn btn-gold btn-sm" data-action="extend" data-id="${escapeHtml(c.device_id)}">Perpanjang</button>
                ${
                  showFollowUp
                    ? `<button type="button" class="btn btn-wa btn-sm" data-action="followup" data-id="${escapeHtml(c.device_id)}">WA Follow-Up</button>`
                    : ''
                }
                <button type="button" class="btn btn-danger btn-sm" data-action="revoke" data-id="${escapeHtml(c.device_id)}">${revLabel}</button>
              </div>
            </td>
          </tr>
        `;
      })
      .join('');
  }

  function renderTransactionsTable() {
    const tbody = $('txTableBody');
    if (state.transactions.length === 0) {
      tbody.innerHTML =
        '<tr><td colspan="5" style="text-align:center; color:var(--text-muted); padding:20px;">Belum ada transaksi lisensi tercatat.</td></tr>';
      return;
    }
    tbody.innerHTML = state.transactions
      .map(
        (t) => `
        <tr>
          <td>${formatDateShort(t.created_at)}</td>
          <td class="mono">${escapeHtml(t.device_id)}</td>
          <td>${escapeHtml(t.paket)}</td>
          <td>${escapeHtml(t.metode_bayar)}</td>
          <td style="font-weight:800; color:var(--emerald);">${formatIdr(t.nominal_idr)}</td>
        </tr>
      `
      )
      .join('');
  }

  function renderRemoteConfigForm() {
    const cfg = state.remoteConfig || {};
    $('rcLatestVersion').value = cfg.latest_version || '4.3.0';
    $('rcMinVersion').value = cfg.min_version || '3.0.0';
    $('rcTitle').value = cfg.announcement_title || '';
    $('rcBody').value = cfg.announcement_body || '';
    $('rcUrl').value = cfg.update_url || '';
    $('rcPromoActive').checked = Boolean(cfg.promo_banner_active);
  }

  // --- ED25519 GENERATOR ---
  function loadEd25519KeyIntoUi() {
    const seed = AdminStore.getEd25519Seed();
    if (!seed) {
      $('edKeyBadge').textContent = 'Belum Dimuat';
      $('edKeyBadge').className = 'badge badge-warn';
      $('edPubKeyOutput').value = '';
      return;
    }
    try {
      const pub = KasSantriEd25519.publicKeyFromSeedBase64(seed);
      $('edSeedInput').value = seed;
      $('edPubKeyOutput').value = pub;
      $('edKeyBadge').textContent = '✓ Kunci Siap (Ed25519)';
      $('edKeyBadge').className = 'badge badge-aktif';
    } catch (_) {
      $('edKeyBadge').textContent = 'Seed Tidak Valid';
      $('edKeyBadge').className = 'badge badge-blocked';
    }
  }

  function initGeneratorSection() {
    $('btnApplySeed').addEventListener('click', () => {
      const seed = $('edSeedInput').value.trim();
      try {
        const pub = KasSantriEd25519.publicKeyFromSeedBase64(seed);
        AdminStore.setEd25519Seed(seed);
        $('edPubKeyOutput').value = pub;
        $('edKeyBadge').textContent = '✓ Kunci Siap (Ed25519)';
        $('edKeyBadge').className = 'badge badge-aktif';
        showToast('Private Seed Ed25519 disimpan ke sesi Admin.');
      } catch (err) {
        showToast('Seed Ed25519 tidak valid: ' + err.message, true);
      }
    });

    $('btnToggleSeedVis').addEventListener('click', () => {
      const inp = $('edSeedInput');
      inp.type = inp.type === 'password' ? 'text' : 'password';
    });

    $('btnNewEdKeypair').addEventListener('click', () => {
      const kp = KasSantriEd25519.generateKeyPair();
      $('edSeedInput').value = kp.seedBase64;
      $('edPubKeyOutput').value = kp.publicKeyBase64;
      AdminStore.setEd25519Seed(kp.seedBase64);
      $('edKeyBadge').textContent = '✓ Keypair Baru Aktif';
      $('edKeyBadge').className = 'badge badge-aktif';
      showToast('Keypair Ed25519 baru dibuat! Salin Public Key ke LicenseService.dart jika memakai keypair ini.');
    });

    $('btnCopyPubKey').addEventListener('click', async () => {
      const val = $('edPubKeyOutput').value;
      if (!val) return;
      await navigator.clipboard.writeText(val);
      showToast('Public Key Ed25519 disalin!');
    });

    $('genTier').addEventListener('change', () => {
      const tier = $('genTier').value;
      if (tier === 'MONTHLY') {
        $('genNominal').value = 25000;
        $('genDays').value = 31;
      } else if (tier === 'YEARLY') {
        $('genNominal').value = 179000;
        $('genDays').value = 366;
      } else {
        $('genNominal').value = 399000;
        $('genDays').value = 36500;
      }
    });

    $('formGenerateLicense').addEventListener('submit', async (e) => {
      e.preventDefault();
      const seed = AdminStore.getEd25519Seed() || $('edSeedInput').value.trim();
      if (!seed) {
        showToast('Masukkan Private Seed Ed25519 terlebih dahulu di panel sebelah kiri.', true);
        return;
      }

      const deviceId = $('genDeviceId').value.trim().toUpperCase();
      const noWa = $('genNoWa').value.trim();
      const pondok = $('genNamaPondok').value.trim();
      const bendahara = $('genNamaBendahara').value.trim();
      const tier = $('genTier').value;
      const channel = $('genChannel').value;
      const nominal = Number($('genNominal').value || 0);
      const days = Math.max(1, Number($('genDays').value || 366));

      try {
        const expiryDate =
          tier === 'LIFETIME' ? null : new Date(Date.now() + days * 86400000);
        const expiryEpochSec =
          expiryDate === null ? 0 : Math.floor(expiryDate.getTime() / 1000);

        const signed = KasSantriEd25519.generateLicenseCode({
          seedBase64: seed,
          deviceId,
          tier,
          expiryEpochSec,
        });

        const existing = state.customers.find((c) => c.device_id === deviceId);
        const prevPaid = existing ? Number(existing.total_paid_idr || 0) : 0;

        await AdminStore.upsertCustomer({
          ...(existing || {}),
          device_id: deviceId,
          nama_pondok: pondok,
          nama_bendahara: bendahara || existing?.nama_bendahara || '',
          no_wa: noWa,
          tier,
          status: 'AKTIF',
          expiry_date: expiryDate ? expiryDate.toISOString() : null,
          payment_channel: channel,
          total_paid_idr: prevPaid + nominal,
          is_revoked: false,
          notes: `Lisensi ${tier} diterbitkan Admin (${formatDateShort(new Date().toISOString())})`,
        });

        await AdminStore.recordTransaction({
          device_id: deviceId,
          paket: tier,
          nominal_idr: nominal,
          metode_bayar: channel,
          kode_lisensi: signed.code,
        });

        const paketLabel =
          tier === 'LIFETIME' ? 'PRO Lifetime (Selamanya)' : tier === 'MONTHLY' ? 'PRO Bulanan' : 'PRO Tahunan';
        const waMsg =
          `Assalamu'alaikum Wr. Wb.\n` +
          `Terima kasih ${bendahara || 'Pengurus'} (${pondok}). Pembayaran Kas-Santri *${paketLabel}* telah kami verifikasi.\n\n` +
          `Device ID: ${deviceId}\n` +
          `Kode Aktivasi PRO:\n*${signed.code}*\n\n` +
          `Cara aktifkan: Buka aplikasi Kas-Santri -> menu Upgrade PRO -> pilih "Sudah Bayar? Masukkan Kode Aktivasi" -> tempel kode di atas.\n\n` +
          `Hormat kami,\nMoch Khoirul Azman (Admin Kas-Santri)`;

        state.lastGeneratedCode = signed.code;
        state.lastGeneratedWaMessage = waMsg;
        $('generatedCodeText').textContent = signed.code;
        $('generatedResultBox').classList.remove('hidden');

        const waNum = normalizeWaPhone(noWa);
        $('btnSendWaDirect').href = waNum
          ? `https://wa.me/${waNum}?text=${encodeURIComponent(waMsg)}`
          : `https://wa.me/?text=${encodeURIComponent(waMsg)}`;

        await refreshDashboardData();
        showToast('Kode Ed25519 dibuat & omset berhasil dicatat ke CRM!');
      } catch (err) {
        showToast('Gagal generate lisensi: ' + err.message, true);
      }
    });

    $('btnCopyGeneratedCode').addEventListener('click', async () => {
      if (!state.lastGeneratedCode) return;
      await navigator.clipboard.writeText(state.lastGeneratedCode);
      showToast('Kode aktivasi PRO disalin!');
    });

    $('btnCopyWaMessage').addEventListener('click', async () => {
      if (!state.lastGeneratedWaMessage) return;
      await navigator.clipboard.writeText(state.lastGeneratedWaMessage);
      showToast('Template balasan WA disalin!');
    });
  }

  // --- CRM ACTIONS ---
  function openCustomerModal(customer = null) {
    $('custIsEdit').value = customer ? '1' : '0';
    $('modalCustomerTitle').textContent = customer ? 'Edit Pelanggan APK' : 'Tambah Pelanggan Manual';
    $('custDeviceId').value = customer?.device_id || '';
    $('custDeviceId').readOnly = Boolean(customer);
    $('custPondok').value = customer?.nama_pondok || '';
    $('custBendahara').value = customer?.nama_bendahara || '';
    $('custWa').value = customer?.no_wa || '';
    $('custTier').value = customer?.tier || 'FREE';
    $('custStatus').value = customer?.status || 'GRATIS';
    $('custChannel').value = customer?.payment_channel || 'FREE';
    $('custTotalPaid').value = Number(customer?.total_paid_idr || 0);
    $('custExpiry').value = customer?.expiry_date ? String(customer.expiry_date).slice(0, 10) : '';
    $('custVersion').value = customer?.app_version || '4.3.0';
    $('custNotes').value = customer?.notes || '';
    $('customerModal').classList.remove('hidden');
  }

  function initCrmSection() {
    $('crmSearchInput').addEventListener('input', (e) => {
      state.searchQuery = e.target.value;
      renderCrmTable();
    });

    $('crmFilterChips').addEventListener('click', (e) => {
      const btn = e.target.closest('.chip');
      if (!btn) return;
      document.querySelectorAll('#crmFilterChips .chip').forEach((c) => c.classList.remove('active'));
      btn.classList.add('active');
      state.statusFilter = btn.dataset.filter || 'ALL';
      renderCrmTable();
    });

    $('btnAddCustomer').addEventListener('click', () => openCustomerModal(null));
    $('btnCloseCustomerModal').addEventListener('click', () => $('customerModal').classList.add('hidden'));
    $('btnCancelCustomerModal').addEventListener('click', () => $('customerModal').classList.add('hidden'));

    $('formCustomerModal').addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        const expVal = $('custExpiry').value;
        await AdminStore.upsertCustomer({
          device_id: $('custDeviceId').value,
          nama_pondok: $('custPondok').value,
          nama_bendahara: $('custBendahara').value,
          no_wa: $('custWa').value,
          tier: $('custTier').value,
          status: $('custStatus').value,
          payment_channel: $('custChannel').value,
          total_paid_idr: Number($('custTotalPaid').value || 0),
          expiry_date: expVal ? new Date(expVal + 'T23:59:59Z').toISOString() : null,
          app_version: $('custVersion').value,
          is_revoked: $('custStatus').value === 'DIBLOKIR',
          notes: $('custNotes').value,
        });
        $('customerModal').classList.add('hidden');
        await refreshDashboardData();
        showToast('Data pelanggan tersimpan.');
      } catch (err) {
        showToast('Gagal menyimpan pelanggan: ' + err.message, true);
      }
    });

    $('crmTableBody').addEventListener('click', async (e) => {
      const btn = e.target.closest('button[data-action]');
      if (!btn) return;
      const action = btn.dataset.action;
      const id = btn.dataset.id;
      const customer = state.customers.find((c) => c.device_id === id);
      if (!customer) return;

      if (action === 'edit') {
        openCustomerModal(customer);
        return;
      }

      if (action === 'extend') {
        $('genDeviceId').value = customer.device_id;
        $('genNamaPondok').value = customer.nama_pondok || '';
        $('genNamaBendahara').value = customer.nama_bendahara || '';
        $('genNoWa').value = customer.no_wa || '';
        switchSection('sec-generator');
        showToast('Data pelanggan diisikan ke Generator Ed25519 untuk perpanjangan cepat.');
        return;
      }

      if (action === 'followup') {
        const waNum = normalizeWaPhone(customer.no_wa);
        const eff = deriveEffectiveStatus(customer);
        const rem = daysUntil(customer.expiry_date);
        const contextText =
          eff === 'TRIAL'
            ? `masa Uji Coba Gratis 14 Hari Kas-Santri PRO untuk *${customer.nama_pondok}* tinggal ${Math.max(0, rem ?? 0)} hari lagi`
            : `langganan Kas-Santri PRO *${customer.nama_pondok}* akan segera berakhir (${rem !== null && rem >= 0 ? `sisa ${rem} hari` : 'sudah berakhir'})`;

        const msg =
          `Assalamu'alaikum Wr. Wb.\n` +
          `Yth. ${customer.nama_bendahara || 'Bendahara'} (${customer.nama_pondok}),\n` +
          `Kami informasikan bahwa ${contextText}.\n\n` +
          `Agar fitur PRO (Ekspor PDF/Excel Berkop, QR Scanner, Auto-Backup Google Drive, & Manajemen Infak) tetap berjalan lancar, silakan lakukan perpanjangan:\n` +
          `• DANA Resmi: *082130678956* (a.n. Moch Khoirul Azman) — Bulanan Rp25rb / Tahunan Rp179rb / Lifetime Rp399rb\n` +
          `• Atau langsung lewat Google Play Store di dalam aplikasi.\n\n` +
          `Sertakan Device ID *${customer.device_id}* setelah transfer agar kode aktivasi segera kami kirimkan. Terima kasih.`;

        const url = waNum
          ? `https://wa.me/${waNum}?text=${encodeURIComponent(msg)}`
          : `https://wa.me/?text=${encodeURIComponent(msg)}`;
        window.open(url, '_blank', 'noopener,noreferrer');
        return;
      }

      if (action === 'revoke') {
        const nextRevoke = !customer.is_revoked;
        const ok = window.confirm(
          nextRevoke
            ? `Cabut/Blokir lisensi PRO perangkat ${customer.device_id} (${customer.nama_pondok})? Saat APK online, status akan otomatis diturunkan ke Gratis.`
            : `Aktifkan kembali akses perangkat ${customer.device_id}?`
        );
        if (!ok) return;
        try {
          await AdminStore.toggleRevoke(customer.device_id, nextRevoke);
          await refreshDashboardData();
          showToast(nextRevoke ? 'Lisensi perangkat berhasil diblokir (Revoke).' : 'Blokir perangkat dibuka.');
        } catch (err) {
          showToast('Gagal mengubah status revoke: ' + err.message, true);
        }
      }
    });
  }

  // --- REMOTE CONFIG & EXPORTS ---
  function downloadTextFile(filename, content, mime = 'text/plain;charset=utf-8') {
    const blob = new Blob([content], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  function toCsvCell(val) {
    const s = String(val ?? '').replace(/"/g, '""');
    return `"${s}"`;
  }

  function initRemoteAndExportSection() {
    $('formRemoteConfig').addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        await AdminStore.saveRemoteConfig({
          latest_version: $('rcLatestVersion').value,
          min_version: $('rcMinVersion').value,
          announcement_title: $('rcTitle').value,
          announcement_body: $('rcBody').value,
          update_url: $('rcUrl').value,
          promo_banner_active: $('rcPromoActive').checked,
        });
        await refreshDashboardData();
        showToast('Pengumuman & versi terbaru APK tersimpan!');
      } catch (err) {
        showToast('Gagal menyimpan remote config: ' + err.message, true);
      }
    });

    $('btnExportCustomersCsv').addEventListener('click', () => {
      const headers = ['device_id', 'nama_pondok', 'nama_bendahara', 'no_wa', 'tier', 'status', 'payment_channel', 'total_paid_idr', 'expiry_date', 'app_version', 'is_revoked'];
      const rows = [headers.join(',')].concat(
        state.customers.map((c) => headers.map((h) => toCsvCell(c[h])).join(','))
      );
      downloadTextFile(`kas_santri_pelanggan_${Date.now()}.csv`, rows.join('\n'), 'text/csv;charset=utf-8');
      showToast('CSV Pelanggan diunduh.');
    });

    $('btnExportTxCsv').addEventListener('click', () => {
      const headers = ['created_at', 'device_id', 'paket', 'metode_bayar', 'nominal_idr', 'kode_lisensi'];
      const rows = [headers.join(',')].concat(
        state.transactions.map((t) => headers.map((h) => toCsvCell(t[h])).join(','))
      );
      downloadTextFile(`kas_santri_omset_${Date.now()}.csv`, rows.join('\n'), 'text/csv;charset=utf-8');
      showToast('CSV Pembukuan Omset diunduh.');
    });

    $('btnExportAdminJson').addEventListener('click', () => {
      const dump = {
        exported_at: new Date().toISOString(),
        customers: state.customers,
        transactions: state.transactions,
        remoteConfig: state.remoteConfig,
      };
      downloadTextFile(
        `kas_santri_admin_backup_${Date.now()}.json`,
        JSON.stringify(dump, null, 2),
        'application/json'
      );
      showToast('Backup JSON Admin diunduh.');
    });

    $('inputImportAdminJson').addEventListener('change', async (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      try {
        const raw = JSON.parse(await file.text());
        await AdminStore.importJson(raw);
        await refreshDashboardData();
        showToast('Backup JSON Admin berhasil dipulihkan.');
      } catch (err) {
        showToast('Gagal impor JSON Admin: ' + err.message, true);
      } finally {
        e.target.value = '';
      }
    });
  }

  // --- NAVIGATION & SETTINGS MODAL ---
  function switchSection(targetId) {
    document.querySelectorAll('nav.nav-tabs .nav-tab').forEach((btn) => {
      btn.classList.toggle('active', btn.dataset.section === targetId);
    });
    ['sec-overview', 'sec-generator', 'sec-crm', 'sec-remote'].forEach((id) => {
      $(id).classList.toggle('hidden', id !== targetId);
    });
  }

  function initShellControls() {
    document.querySelectorAll('nav.nav-tabs .nav-tab').forEach((btn) => {
      btn.addEventListener('click', () => switchSection(btn.dataset.section));
    });

    $('btnRefreshData').addEventListener('click', async () => {
      await refreshDashboardData();
      showToast('Data diperbarui.');
    });

    $('btnSeedDemo').addEventListener('click', async () => {
      await AdminStore.seedSampleDataIfOffline();
      await refreshDashboardData();
      showToast('4 contoh pondok & omset simulasi dimuat (Mode Offline).');
    });

    $('btnOpenSettings').addEventListener('click', () => {
      const cfg = AdminStore.getSupabaseConfig();
      $('setSbUrl').value = cfg.url || '';
      $('setSbAnon').value = cfg.anonKey || '';
      $('setNewOfflinePwd').value = '';
      $('settingsModal').classList.remove('hidden');
    });

    $('btnCloseSettingsModal').addEventListener('click', () => $('settingsModal').classList.add('hidden'));
    $('btnCancelSettingsModal').addEventListener('click', () => $('settingsModal').classList.add('hidden'));

    $('formSettingsModal').addEventListener('submit', async (e) => {
      e.preventDefault();
      try {
        AdminStore.saveSupabaseConfig($('setSbUrl').value, $('setSbAnon').value);
        const newPwd = $('setNewOfflinePwd').value;
        if (newPwd.trim()) {
          await AdminStore.setupOrUpdateOfflinePassword(newPwd);
        }
        $('settingsModal').classList.add('hidden');
        updateModeBadge();
        showToast('Pengaturan kredensial disimpan.');
      } catch (err) {
        showToast(err.message, true);
      }
    });

    $('btnLogout').addEventListener('click', () => {
      AdminStore.logout();
      $('appShell').classList.add('hidden');
      $('loginOverlay').classList.remove('hidden');
      $('offlinePasswordInput').value = '';
    });
  }

  document.addEventListener('DOMContentLoaded', () => {
    initLoginGate();
    initShellControls();
    initGeneratorSection();
    initCrmSection();
    initRemoteAndExportSection();
  });
})();
