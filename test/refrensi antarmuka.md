<!DOCTYPE html>
<html lang="id" class="dark">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Kas Santri — PPS MIFTAHUSSUNAN</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@500;600;700;800&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      color-scheme: dark;
    }
    body {
      font-family: 'Plus Jakarta Sans', sans-serif;
      background-color: #03060c;
      color: #f8fafc;
      user-select: none;
      -webkit-tap-highlight-color: transparent;
    }
    .font-mono-num {
      font-family: 'JetBrains Mono', monospace;
      font-variant-numeric: tabular-nums;
    }
    .no-scrollbar::-webkit-scrollbar {
      display: none;
    }
    .no-scrollbar {
      -ms-overflow-style: none;
      scrollbar-width: none;
    }
    @keyframes slideUpSheet {
      from { transform: translateY(100%); opacity: 0.4; }
      to { transform: translateY(0); opacity: 1; }
    }
    .animate-sheet {
      animation: slideUpSheet 0.28s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    }
    @keyframes pulseGlow {
      0%, 100% { opacity: 0.7; transform: scale(1) rotate(0deg); }
      50% { opacity: 1; transform: scale(1.12) rotate(6deg); }
    }
    .glow-ambient {
      animation: pulseGlow 6s ease-in-out infinite;
    }
    @keyframes floatWave {
      0%, 100% { transform: translateY(0px); }
      50% { transform: translateY(-4px); }
    }
    .animate-float {
      animation: floatWave 3.5s ease-in-out infinite;
    }
    /* Custom Glassmorphism & Vibrant Gradients */
    .glass-card {
      background: linear-gradient(145deg, rgba(15, 23, 42, 0.82) 0%, rgba(10, 15, 29, 0.92) 100%);
      backdrop-filter: blur(18px);
      -webkit-backdrop-filter: blur(18px);
      border: 1px solid rgba(255, 255, 255, 0.11);
    }
    .glass-card-interactive {
      background: linear-gradient(145deg, rgba(15, 23, 42, 0.82) 0%, rgba(10, 15, 29, 0.92) 100%);
      backdrop-filter: blur(18px);
      -webkit-backdrop-filter: blur(18px);
      border: 1px solid rgba(255, 255, 255, 0.11);
      transition: all 0.24s cubic-bezier(0.16, 1, 0.3, 1);
    }
    .glass-card-interactive:hover {
      border-color: rgba(56, 189, 248, 0.55);
      background: rgba(15, 23, 42, 0.95);
    }
    /* Hero Brankas dengan Gradasi Mencolok Aurora (Emerald -> Cyan -> Fuchsia) */
    .hero-vault-card {
      background:
        radial-gradient(120% 140% at 0% 0%, rgba(16, 185, 129, 0.72) 0%, transparent 55%),
        radial-gradient(110% 130% at 100% 0%, rgba(6, 182, 212, 0.68) 0%, transparent 58%),
        radial-gradient(130% 120% at 85% 100%, rgba(217, 70, 239, 0.55) 0%, transparent 62%),
        linear-gradient(135deg, #061326 0%, #072227 50%, #171033 100%);
      border: 1.5px solid rgba(56, 189, 248, 0.48);
      box-shadow:
        0 20px 50px -12px rgba(16, 185, 129, 0.45),
        0 10px 30px -8px rgba(217, 70, 239, 0.3),
        inset 0 1px 2px rgba(255, 255, 255, 0.35);
    }
    /* Tombol Kartu 2 Kolom (Vibrant Tactile Button Cards - Fresh & Tidak Kaku) */
    .santri-btn-card {
      position: relative;
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      transition: all 0.25s cubic-bezier(0.34, 1.56, 0.64, 1);
      box-shadow:
        0 14px 30px -8px rgba(0, 0, 0, 0.75),
        inset 0 1.5px 2px 0 rgba(255, 255, 255, 0.25);
    }
    .santri-btn-card:hover {
      transform: translateY(-5px) scale(1.02);
    }
    .santri-btn-card:active {
      transform: scale(0.95);
    }
    /* Tema Gradasi Mencolok Berdasarkan Status Santri */
    .card-theme-utuh {
      background:
        radial-gradient(130% 110% at 0% 0%, rgba(16, 185, 129, 0.58) 0%, rgba(6, 182, 212, 0.28) 52%, rgba(10, 18, 34, 0.96) 100%),
        linear-gradient(160deg, rgba(16, 185, 129, 0.2) 0%, rgba(15, 23, 42, 0.95) 100%);
      border: 1.5px solid rgba(52, 211, 153, 0.55);
      box-shadow: 0 14px 32px -10px rgba(16, 185, 129, 0.45), inset 0 1px 2px rgba(255, 255, 255, 0.28);
    }
    .card-theme-sebagian {
      background:
        radial-gradient(130% 110% at 100% 0%, rgba(56, 189, 248, 0.62) 0%, rgba(139, 92, 246, 0.32) 55%, rgba(10, 18, 34, 0.96) 100%),
        linear-gradient(160deg, rgba(56, 189, 248, 0.22) 0%, rgba(15, 23, 42, 0.95) 100%);
      border: 1.5px solid rgba(56, 189, 248, 0.6);
      box-shadow: 0 14px 32px -10px rgba(56, 189, 248, 0.48), inset 0 1px 2px rgba(255, 255, 255, 0.28);
    }
    .card-theme-habis {
      background:
        radial-gradient(130% 110% at 0% 0%, rgba(245, 158, 11, 0.6) 0%, rgba(236, 72, 153, 0.3) 55%, rgba(10, 18, 34, 0.96) 100%),
        linear-gradient(160deg, rgba(245, 158, 11, 0.2) 0%, rgba(15, 23, 42, 0.95) 100%);
      border: 1.5px solid rgba(251, 191, 36, 0.6);
      box-shadow: 0 14px 32px -10px rgba(245, 158, 11, 0.45), inset 0 1px 2px rgba(255, 255, 255, 0.28);
    }
    .card-theme-over {
      background:
        radial-gradient(130% 110% at 100% 0%, rgba(244, 63, 94, 0.65) 0%, rgba(168, 85, 247, 0.35) 55%, rgba(10, 18, 34, 0.96) 100%),
        linear-gradient(160deg, rgba(244, 63, 94, 0.25) 0%, rgba(15, 23, 42, 0.95) 100%);
      border: 1.5px solid rgba(251, 113, 133, 0.65);
      box-shadow: 0 14px 32px -10px rgba(244, 63, 94, 0.5), inset 0 1px 2px rgba(255, 255, 255, 0.28);
    }
    /* Kartu Khusus Pengembang */
    .dev-credit-card {
      background:
        radial-gradient(120% 120% at 0% 0%, rgba(16, 185, 129, 0.45) 0%, transparent 55%),
        radial-gradient(120% 120% at 100% 100%, rgba(217, 70, 239, 0.45) 0%, transparent 55%),
        linear-gradient(135deg, #091326 0%, #0f172a 50%, #1e1b4b 100%);
      border: 1.5px solid rgba(56, 189, 248, 0.45);
      box-shadow: 0 15px 35px -10px rgba(6, 182, 212, 0.35);
    }
  </style>
</head>
<body class="min-h-screen flex justify-center items-start md:py-5 text-slate-100">

  <!-- Input File Tersembunyi untuk Upload Logo Pondok -->
  <input type="file" id="logoFileInput" accept="image/*" class="hidden" onchange="handleLogoUpload(event)" />

  <!-- MOBILE APP SHELL (Max Width 435px) -->
  <div class="w-full max-w-[435px] min-h-screen md:min-h-[860px] md:h-[880px] bg-[#060A12] md:rounded-[44px] md:shadow-[0_0_90px_rgba(0,0,0,0.95)] md:border-[7px] md:border-slate-800/90 flex flex-col relative overflow-hidden">

    <!-- Efek Ambient Cahaya Aurora Mencolok di Latar Belakang -->
    <div class="pointer-events-none absolute -top-20 -left-16 w-72 h-72 bg-emerald-500/30 rounded-full blur-3xl glow-ambient"></div>
    <div class="pointer-events-none absolute top-36 -right-20 w-72 h-72 bg-cyan-500/30 rounded-full blur-3xl glow-ambient"></div>
    <div class="pointer-events-none absolute bottom-20 left-8 w-64 h-64 bg-fuchsia-500/25 rounded-full blur-3xl glow-ambient"></div>

    <!-- Status Bar Mobile -->
    <div class="px-6 pt-3 pb-1 flex justify-between items-center text-[11px] font-medium text-slate-400 relative z-20">
      <span id="clockDisplay" class="font-mono-num text-cyan-300 font-bold">23 Nov 2026 • 16:00</span>
      <div class="flex items-center gap-2">
        <span class="bg-gradient-to-r from-emerald-500/20 to-cyan-500/20 border border-emerald-400/40 px-2.5 py-0.5 rounded-full text-[10px] text-emerald-300 font-bold flex items-center gap-1.5 shadow-sm">
          <span class="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping"></span>
          Sistem Aktif
        </span>
      </div>
    </div>

    <!-- HEADER UTAMA: PPS MIFTAHUSSUNAN & UPLOAD LOGO -->
    <header class="px-5 pt-1.5 pb-3 relative z-20">
      <div class="flex justify-between items-center mb-3.5">
        <div class="flex items-center gap-2.5">
          <!-- Wadah Logo (Klik untuk Ganti/Upload Gambar Logo) -->
          <div
            onclick="triggerLogoUpload()"
            title="Ketuk untuk Mengganti / Upload Gambar Logo Pondok"
            class="cursor-pointer group relative w-11 h-11 rounded-2xl bg-gradient-to-br from-emerald-400 via-teal-400 to-cyan-500 p-[2px] shadow-[0_0_20px_rgba(16,185,129,0.55)] active:scale-95 transition shrink-0"
          >
            <div class="w-full h-full rounded-[14px] bg-slate-950 flex items-center justify-center overflow-hidden relative">
              <img id="headerLogoImg" src="" alt="Logo PPS" class="w-full h-full object-cover hidden" />
              <!-- Default Emblem Islami PPS Miftahussunan jika belum upload file -->
              <svg id="headerLogoDefaultSvg" class="w-7 h-7 text-emerald-400" viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M32 6L38 14H26L32 6Z" fill="url(#grad1)"/>
                <path d="M18 24C18 17.3726 24.268 12 32 12C39.732 12 46 17.3726 46 24V44H18V24Z" fill="url(#grad1)" fill-opacity="0.25" stroke="#34D399" stroke-width="2.5"/>
                <path d="M12 44H52V52C52 54.2091 50.2091 56 48 56H16C13.7909 56 12 54.2091 12 52V44Z" fill="url(#grad2)"/>
                <path d="M24 34L32 39L40 34V25L32 30L24 25V34Z" fill="#38BDF8"/>
                <defs>
                  <linearGradient id="grad1" x1="18" y1="6" x2="46" y2="44" gradientUnits="userSpaceOnUse">
                    <stop stop-color="#34D399"/>
                    <stop offset="1" stop-color="#38BDF8"/>
                  </linearGradient>
                  <linearGradient id="grad2" x1="12" y1="44" x2="52" y2="56" gradientUnits="userSpaceOnUse">
                    <stop stop-color="#10B981"/>
                    <stop offset="1" stop-color="#06B6D4"/>
                  </linearGradient>
                </defs>
              </svg>
              <div class="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 flex items-center justify-center text-[8px] font-extrabold text-white text-center leading-tight transition">
                📷<br/>Logo
              </div>
            </div>
            <span class="absolute -bottom-1 -right-1 w-4 h-4 rounded-full bg-cyan-400 text-slate-950 text-[9px] font-black flex items-center justify-center shadow">📷</span>
          </div>

          <div>
            <div class="flex items-center gap-1.5">
              <span class="text-[9px] uppercase tracking-widest bg-gradient-to-r from-emerald-300 via-cyan-300 to-fuchsia-300 bg-clip-text text-transparent font-extrabold">Kas & Keuangan Santri</span>
            </div>
            <h1 class="text-[15px] font-black tracking-tight text-white drop-shadow-sm leading-tight" id="headerNamaPondok">PPS MIFTAHUSSUNAN</h1>
          </div>
        </div>

        <div class="flex items-center gap-1.5">
          <button onclick="openAddSantriModal()" class="bg-gradient-to-r from-emerald-400 to-cyan-400 hover:brightness-110 active:scale-95 text-slate-950 shadow-[0_0_15px_rgba(52,211,153,0.45)] transition px-3 py-1.5 rounded-xl text-[11px] font-extrabold flex items-center gap-1">
            <span>+ Santri</span>
          </button>
          <button onclick="togglePinLock(true)" title="Kunci Aplikasi" class="glass-card hover:border-cyan-400/50 active:scale-95 transition w-8 h-8 rounded-xl flex items-center justify-center text-xs">
            🔒
          </button>
        </div>
      </div>

      <!-- HERO CARD: BRANKAS UANG TITIPAN FISIK & INFO TUNGGAKAN -->
      <div class="hero-vault-card rounded-[30px] p-4 relative overflow-hidden">
        <div class="pointer-events-none absolute -right-10 -top-10 w-36 h-36 rounded-full bg-gradient-to-br from-cyan-400/40 via-fuchsia-500/30 to-transparent blur-xl animate-float"></div>
        <div class="pointer-events-none absolute -left-10 -bottom-12 w-32 h-32 rounded-full bg-gradient-to-tr from-emerald-400/35 to-cyan-400/20 blur-xl"></div>

        <div class="flex justify-between items-start relative z-10">
          <div>
            <div class="flex items-center gap-1.5">
              <span class="text-[11px] font-extrabold text-cyan-100 tracking-wide">Total Uang Titipan (Brankas)</span>
              <button onclick="toggleHideBalance()" class="text-cyan-200/80 hover:text-white text-xs transition" title="Sembunyikan/Tampilkan Nominal">
                👁️
              </button>
            </div>
            <p class="text-2xl font-black tracking-tight bg-gradient-to-r from-white via-emerald-200 to-cyan-200 bg-clip-text text-transparent mt-0.5 font-mono-num drop-shadow" id="totalUangFisik">Rp 0</p>
          </div>
          <span class="bg-gradient-to-r from-emerald-300 via-teal-300 to-cyan-300 text-slate-950 text-[10px] font-black px-3 py-1 rounded-full shadow-[0_0_18px_rgba(52,211,153,0.65)] font-mono-num" id="jumlahSantriBadge">
            0 Santri
          </span>
        </div>

        <!-- Bar Persentase Kuota Harian Global -->
        <div class="mt-3 space-y-1 relative z-10">
          <div class="flex justify-between text-[10px] text-cyan-100/90 font-semibold">
            <span>⚡ Serapan Jatah Harian Pondok</span>
            <span id="globalKuotaPctText" class="font-mono-num text-emerald-300 font-extrabold">0%</span>
          </div>
          <div class="w-full h-2.5 bg-slate-950/80 rounded-full overflow-hidden border border-white/20 p-0.5">
            <div id="globalKuotaBar" class="h-full bg-gradient-to-r from-emerald-400 via-cyan-400 to-fuchsia-400 rounded-full transition-all duration-500 shadow-[0_0_14px_rgba(56,189,248,0.9)]" style="width: 0%"></div>
          </div>
        </div>

        <!-- 3 Metrik Bawah Brankas: Keluar Hari Ini, Kuota Harian, & Total Tunggakan -->
        <div class="grid grid-cols-3 gap-1.5 mt-3 pt-2.5 border-t border-white/15 text-xs relative z-10">
          <div class="bg-slate-950/55 backdrop-blur-md rounded-2xl px-2.5 py-2 border border-amber-400/30">
            <span class="text-[9px] text-amber-200/90 font-bold block">🔥 Keluar Hari Ini</span>
            <span class="font-extrabold text-amber-300 font-mono-num text-[11px] mt-0.5 block" id="totalKeluarHariIni">Rp 0</span>
          </div>
          <div class="bg-slate-950/55 backdrop-blur-md rounded-2xl px-2.5 py-2 border border-cyan-400/30">
            <span class="text-[9px] text-cyan-200/90 font-bold block">🎯 Kuota Harian</span>
            <span class="font-extrabold text-cyan-200 font-mono-num text-[11px] mt-0.5 block" id="totalKuotaHariIni">Rp 0</span>
          </div>
          <div onclick="setFilter('TUNGGAKAN')" class="cursor-pointer bg-rose-950/65 hover:bg-rose-900/70 active:scale-95 transition backdrop-blur-md rounded-2xl px-2.5 py-2 border border-rose-400/50 shadow-[0_0_12px_rgba(244,63,94,0.25)]">
            <span class="text-[9px] text-rose-200 font-extrabold flex items-center justify-between">
              <span>🚨 Tunggakan</span>
              <span id="countTunggakanBadge" class="bg-rose-500 text-white text-[8px] px-1 rounded-full">0</span>
            </span>
            <span class="font-black text-rose-300 font-mono-num text-[11px] mt-0.5 block" id="totalTunggakanPondok">Rp 0</span>
          </div>
        </div>
      </div>
    </header>

    <!-- AREA KONTEN UTAMA (Scrollable) -->
    <main class="flex-1 overflow-y-auto no-scrollbar px-4 pt-1 pb-28 space-y-3 relative z-10" id="mainContainer">

      <!-- ==================== TAB 1: MONITORING SANTRI & AMBIL UANG ==================== -->
      <section id="tab-home" class="space-y-3">

        <!-- Banner Panduan Simulasi Interaktif -->
        <div id="simulasiGuideBanner" class="bg-gradient-to-r from-emerald-950/90 via-cyan-950/85 to-fuchsia-950/80 border border-cyan-400/35 rounded-2xl p-3 text-xs text-slate-100 flex items-start justify-between gap-2.5 shadow-lg">
          <div class="flex items-start gap-2">
            <span class="text-base mt-0.5">✨</span>
            <div class="leading-relaxed text-[11px]">
              <span class="bg-gradient-to-r from-emerald-300 to-cyan-300 bg-clip-text text-transparent font-extrabold uppercase tracking-wider text-[10px]">Tombol Kartu 2 Kotak & Fitur Tunggakan</span><br/>
              Ketuk kartu santri untuk <b>Ambil Uang Harian</b>, atau ketuk tombol <b>🚨 Tunggakan</b> pada kartu untuk mencatat/melunasi tunggakan santri.
            </div>
          </div>
          <button onclick="document.getElementById('simulasiGuideBanner').classList.add('hidden')" class="text-slate-400 hover:text-white text-xs px-1">✕</button>
        </div>

        <!-- Bar Pencarian & Pill Filter Status/Tunggakan (Sticky) -->
        <div class="space-y-2 sticky top-0 bg-[#060A12]/90 backdrop-blur-md pt-1 pb-2 z-20">
          <div class="flex gap-1.5">
            <div class="relative flex-1">
              <input
                type="text"
                id="searchInput"
                oninput="renderSantriList()"
                placeholder="Cari nama santri atau kamar..."
                class="w-full bg-slate-900/90 border border-white/15 rounded-2xl pl-9 pr-3 py-2.5 text-xs text-white placeholder-slate-400 focus:outline-none focus:border-cyan-400 transition"
              />
              <span class="absolute left-3.5 top-2.5 text-cyan-400 text-xs">🔍</span>
            </div>
            <!-- Tombol Switcher 2 Kotak vs 1 Baris -->
            <button
              onclick="toggleGridLayout()"
              id="btnLayoutToggle"
              title="Ubah Tampilan Grid 2 Kotak / List"
              class="glass-card hover:border-cyan-400/50 active:scale-95 px-3 rounded-2xl text-[11px] font-extrabold text-cyan-300 flex items-center gap-1 shrink-0 transition"
            >
              <span>⊞</span>
              <span id="layoutLabelText">2 Kotak</span>
            </button>
          </div>

          <!-- Filter Pills -->
          <div class="flex gap-1.5 overflow-x-auto no-scrollbar" id="filterPills">
            <button onclick="setFilter('ALL')" data-filter="ALL" class="filter-btn bg-gradient-to-r from-emerald-400 via-teal-400 to-cyan-400 text-slate-950 px-3.5 py-1.5 rounded-full text-[11px] font-extrabold whitespace-nowrap transition shadow-[0_0_15px_rgba(52,211,153,0.45)]">✨ Semua</button>
            <button onclick="setFilter('TUNGGAKAN')" data-filter="TUNGGAKAN" class="filter-btn glass-card text-rose-300 border-rose-500/40 px-3.5 py-1.5 rounded-full text-[11px] font-bold whitespace-nowrap transition">🚨 Ada Tunggakan</button>
            <button onclick="setFilter('UTUH')" data-filter="UTUH" class="filter-btn glass-card text-slate-200 px-3.5 py-1.5 rounded-full text-[11px] font-semibold whitespace-nowrap transition">🟢 Utuh</button>
            <button onclick="setFilter('SEBAGIAN')" data-filter="SEBAGIAN" class="filter-btn glass-card text-slate-200 px-3.5 py-1.5 rounded-full text-[11px] font-semibold whitespace-nowrap transition">🔵 Sebagian</button>
            <button onclick="setFilter('HABIS')" data-filter="HABIS" class="filter-btn glass-card text-slate-200 px-3.5 py-1.5 rounded-full text-[11px] font-semibold whitespace-nowrap transition">🟡 Limit Habis</button>
          </div>
        </div>

        <!-- Daftar Kartu Santri (Gaya Tombol Kartu 2 Kotak ke Samping, Sisanya ke Bawah) -->
        <div id="santriListContainer" class="grid grid-cols-2 gap-3"></div>
      </section>

      <!-- ==================== TAB 2: SETORAN BULANAN (FASE 3A) ==================== -->
      <section id="tab-setoran" class="hidden space-y-3.5">
        <div class="glass-card rounded-3xl p-4 space-y-4">
          <div class="flex justify-between items-start">
            <div>
              <span class="text-[10px] font-bold uppercase tracking-widest text-emerald-400">Pemasukan Kas</span>
              <h2 class="text-base font-extrabold text-white mt-0.5">Setoran Bulanan & Top-Up</h2>
              <p class="text-[11px] text-slate-400">Otomatis membagi nominal setoran menjadi kuota jatah harian.</p>
            </div>
            <div class="w-9 h-9 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-base">
              📥
            </div>
          </div>

          <div class="space-y-3">
            <div>
              <label class="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">Pilih Santri</label>
              <select id="setorSantriSelect" class="w-full bg-slate-950/90 border border-white/10 rounded-2xl px-3.5 py-2.5 text-xs font-semibold text-white focus:outline-none focus:border-emerald-500"></select>
            </div>

            <div>
              <label class="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">Jenis Setoran</label>
              <div class="grid grid-cols-2 gap-2">
                <button type="button" id="btnTipeAwal" onclick="setTipeSetoran('AWAL_BULAN')" class="py-2.5 px-3 rounded-2xl text-xs font-bold border border-emerald-500/50 bg-emerald-500/15 text-emerald-300 transition">
                  📅 Awal Bulan
                </button>
                <button type="button" id="btnTipeSusulan" onclick="setTipeSetoran('SUSULAN')" class="py-2.5 px-3 rounded-2xl text-xs font-bold border border-white/10 bg-slate-950/60 text-slate-400 transition">
                  ➕ Top-Up Susulan
                </button>
              </div>
            </div>

            <div class="grid grid-cols-3 gap-2.5">
              <div class="col-span-2">
                <label class="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">Nominal Setoran (Rp)</label>
                <input type="number" id="inputNominalSetor" value="300000" oninput="hitungSimulasiJatah()" class="w-full bg-slate-950/90 border border-white/10 rounded-2xl px-3.5 py-2.5 text-sm font-extrabold text-white font-mono-num focus:outline-none focus:border-emerald-500" />
              </div>
              <div>
                <label class="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">Durasi (Hr)</label>
                <input type="number" id="inputDurasiHari" value="30" oninput="hitungSimulasiJatah()" class="w-full bg-slate-950/90 border border-white/10 rounded-2xl px-3.5 py-2.5 text-sm font-extrabold text-white font-mono-num focus:outline-none focus:border-emerald-500 text-center" />
              </div>
            </div>

            <!-- Pintasan Nominal Setoran -->
            <div class="flex gap-1.5 flex-wrap">
              <button type="button" onclick="setQuickSetor(150000, 30)" class="text-[11px] bg-slate-950/80 hover:bg-slate-800 border border-white/10 px-2.5 py-1.5 rounded-xl font-semibold text-slate-300 transition">150rb (5rb/hr)</button>
              <button type="button" onclick="setQuickSetor(300000, 30)" class="text-[11px] bg-emerald-500/15 hover:bg-emerald-500/25 border border-emerald-500/30 px-2.5 py-1.5 rounded-xl font-bold text-emerald-300 transition">300rb (10rb/hr)</button>
              <button type="button" onclick="setQuickSetor(450000, 30)" class="text-[11px] bg-slate-950/80 hover:bg-slate-800 border border-white/10 px-2.5 py-1.5 rounded-xl font-semibold text-slate-300 transition">450rb (15rb/hr)</button>
            </div>

            <!-- Kalkulator Jatah Otomatis -->
            <div class="bg-gradient-to-r from-emerald-950/80 to-slate-950 border border-emerald-500/30 rounded-2xl p-3.5 flex justify-between items-center">
              <div>
                <span class="text-[10px] text-emerald-400 font-bold uppercase tracking-wider block">Hasil Hitung Jatah Harian</span>
                <span class="text-lg font-extrabold text-white font-mono-num mt-0.5 block" id="previewJatahHarian">Rp 10.000 / hari</span>
              </div>
              <span class="text-2xl">🧮</span>
            </div>

            <div>
              <label class="text-[11px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">Catatan (Opsional)</label>
              <input type="text" id="inputCatatanSetor" placeholder="Contoh: Transfer Wali Santri via BSI" class="w-full bg-slate-950/90 border border-white/10 rounded-2xl px-3.5 py-2.5 text-xs text-white placeholder-slate-600 focus:outline-none focus:border-emerald-500" />
            </div>

            <button onclick="simpanSetoranBulanan()" class="w-full bg-emerald-500 hover:bg-emerald-400 active:scale-[0.99] text-slate-950 font-extrabold py-3.5 rounded-2xl shadow-[0_0_25px_rgba(16,185,129,0.3)] transition text-xs uppercase tracking-wider">
              💾 Simpan Setoran & Update Jatah
            </button>
          </div>
        </div>
      </section>

      <!-- ==================== TAB 3: RIWAYAT TRANSAKSI (FASE 3B) ==================== -->
      <section id="tab-riwayat" class="hidden space-y-3">
        <div class="glass-card rounded-3xl p-4 space-y-3">
          <div class="flex justify-between items-center">
            <div>
              <span class="text-[10px] font-bold uppercase tracking-widest text-emerald-400">Buku Mutasi Digital</span>
              <h2 class="text-sm font-extrabold text-white">Riwayat Keluar & Masuk</h2>
            </div>
            <span class="text-[11px] font-mono-num bg-slate-950/80 border border-white/10 px-2.5 py-1 rounded-xl text-slate-300" id="totalTransaksiCount">0 catatan</span>
          </div>

          <div class="grid grid-cols-2 gap-2">
            <select id="filterRiwayatSantri" onchange="renderRiwayatList()" class="w-full bg-slate-950/90 border border-white/10 rounded-xl px-3 py-2 text-xs font-semibold text-white focus:outline-none">
              <option value="ALL">Semua Santri</option>
            </select>
            <select id="filterRiwayatWaktu" onchange="renderRiwayatList()" class="w-full bg-slate-950/90 border border-white/10 rounded-xl px-3 py-2 text-xs font-semibold text-white focus:outline-none">
              <option value="ALL">Semua Waktu</option>
              <option value="PAGI">🌅 Pagi</option>
              <option value="SIANG">☀️ Siang</option>
              <option value="SORE">🌤️ Sore</option>
              <option value="MALAM">🌙 Malam</option>
              <option value="SETORAN">📥 Setoran</option>
            </select>
          </div>
        </div>

        <div id="riwayatListContainer" class="space-y-2"></div>
      </section>

      <!-- ==================== TAB 4: REKAP & LAPORAN WHATSAPP (FASE 4) ==================== -->
      <section id="tab-laporan" class="hidden space-y-3.5">
        <div class="glass-card rounded-3xl p-4 space-y-3">
          <div>
            <span class="text-[10px] font-bold uppercase tracking-widest text-cyan-400">Audit Kas Harian</span>
            <h2 class="text-sm font-extrabold text-white mt-0.5">Rekap Pengeluaran & Laporan Wali</h2>
          </div>

          <div class="grid grid-cols-3 gap-2 text-center">
            <div class="bg-slate-950/80 border border-white/10 rounded-2xl p-2.5">
              <span class="text-[9px] text-slate-400 font-bold block">🌅 Pagi & Siang</span>
              <span id="rekapPagiSiang" class="text-xs font-extrabold text-cyan-300 font-mono-num mt-1 block">Rp 0</span>
            </div>
            <div class="bg-slate-950/80 border border-white/10 rounded-2xl p-2.5">
              <span class="text-[9px] text-slate-400 font-bold block">🌙 Sore & Malam</span>
              <span id="rekapSoreMalam" class="text-xs font-extrabold text-fuchsia-300 font-mono-num mt-1 block">Rp 0</span>
            </div>
            <div class="bg-slate-950/80 border border-emerald-500/30 rounded-2xl p-2.5">
              <span class="text-[9px] text-emerald-300 font-bold block">🏦 Sisa Brankas</span>
              <span id="rekapBrankas" class="text-xs font-extrabold text-emerald-400 font-mono-num mt-1 block">Rp 0</span>
            </div>
          </div>

          <div class="space-y-2 pt-2 border-t border-white/10">
            <label class="text-[11px] font-bold text-slate-300 uppercase block">Pilih Santri untuk Laporan WhatsApp</label>
            <select id="waSantriSelect" onchange="generateWaPreview()" class="w-full bg-slate-950/90 border border-white/15 rounded-2xl px-3.5 py-2.5 text-xs font-semibold text-white focus:outline-none focus:border-cyan-400"></select>
            <textarea id="waTextPreview" rows="11" readonly class="w-full bg-slate-950/90 border border-white/15 rounded-2xl p-3 text-[11px] font-mono-num text-slate-200 focus:outline-none leading-relaxed"></textarea>
            <button onclick="copyWaReport()" class="w-full bg-gradient-to-r from-emerald-400 to-cyan-400 text-slate-950 font-black py-3 rounded-2xl text-xs uppercase tracking-wider shadow-[0_0_20px_rgba(16,185,129,0.4)] active:scale-95 transition">
              📋 Salin Laporan WhatsApp Wali Santri
            </button>
          </div>
        </div>
      </section>

      <!-- ==================== TAB 5: PENGATURAN & INFO PENGEMBANG (FASE 5) ==================== -->
      <section id="tab-pengaturan" class="hidden space-y-3.5">
        <div class="glass-card rounded-3xl p-4 space-y-4">
          <div class="flex justify-between items-start">
            <div>
              <span class="text-[10px] font-bold uppercase tracking-widest text-cyan-400">Konfigurasi Pondok</span>
              <h2 class="text-sm font-extrabold text-white">Identitas, Logo & Kebijakan Kas</h2>
            </div>
            <button onclick="triggerLogoUpload()" class="bg-gradient-to-r from-emerald-400 to-cyan-400 text-slate-950 font-extrabold text-[11px] px-3 py-1.5 rounded-xl shadow active:scale-95 transition">
              📷 Upload Logo
            </button>
          </div>

          <div>
            <label class="text-[11px] font-bold text-slate-300 uppercase block mb-1.5">Nama Pondok Pesantren</label>
            <input type="text" id="settingNamaPondok" value="PPS MIFTAHUSSUNAN" oninput="saveSettings()" class="w-full bg-slate-950/90 border border-white/15 rounded-2xl px-3.5 py-2.5 text-xs font-extrabold text-white focus:outline-none focus:border-cyan-400" />
          </div>

          <div>
            <label class="text-[11px] font-bold text-slate-300 uppercase block mb-1.5">Kebijakan Sisa Jatah Harian</label>
            <select id="settingModeSisa" onchange="saveSettings()" class="w-full bg-slate-950/90 border border-white/15 rounded-2xl px-3.5 py-2.5 text-xs font-semibold text-white focus:outline-none">
              <option value="KETAT">Mode Ketat (Tiap hari kuota tetap, sisa jadi tabungan)</option>
              <option value="AKUMULASI">Mode Akumulasi (Sisa hari ini ditambah ke kuota besok)</option>
            </select>
          </div>

          <div class="pt-2 border-t border-white/10 space-y-2.5">
            <p class="text-[11px] font-bold text-slate-300 uppercase">Cadangkan & Reset Data Simulasi</p>
            <div class="grid grid-cols-2 gap-2">
              <button onclick="exportDataJson()" class="bg-slate-950/90 hover:bg-slate-800 border border-white/15 text-slate-200 font-bold py-2.5 rounded-2xl text-xs transition">
                ⬇️ Backup (.JSON)
              </button>
              <button onclick="resetInitialDummyData()" class="bg-rose-500/20 hover:bg-rose-500/30 text-rose-300 font-bold py-2.5 rounded-2xl text-xs border border-rose-500/40 transition">
                🔄 Reset Simulasi
              </button>
            </div>
          </div>
        </div>

        <!-- KARTU INFORMASI PENGEMBANG APLIKASI (AREA PALING BAWAH MENU SISTEM) -->
        <div class="dev-credit-card rounded-[28px] p-4 relative overflow-hidden space-y-3.5">
          <div class="pointer-events-none absolute -right-8 -top-8 w-28 h-28 rounded-full bg-gradient-to-br from-emerald-400/30 to-fuchsia-500/30 blur-xl"></div>

          <div class="flex items-center gap-3 relative z-10">
            <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-emerald-400 via-cyan-400 to-fuchsia-500 p-[2px] shadow-[0_0_20px_rgba(56,189,248,0.5)] shrink-0">
              <div class="w-full h-full bg-slate-950 rounded-[14px] flex items-center justify-center font-black text-transparent bg-clip-text bg-gradient-to-r from-emerald-300 to-cyan-300 text-sm">
                MKA
              </div>
            </div>
            <div>
              <span class="text-[9px] font-extrabold uppercase tracking-widest px-2 py-0.5 rounded-full bg-cyan-400/20 text-cyan-200 border border-cyan-400/40">
                Official Developer Credit
              </span>
              <h3 class="text-xs font-black tracking-wide text-white mt-1 leading-snug">
                PENGEMBANG APLIKASI BY MOCH KHOIRUL AZMAN
              </h3>
            </div>
          </div>

          <div class="bg-slate-950/65 backdrop-blur-md rounded-2xl p-3 border border-white/15 space-y-2 text-[11px] relative z-10">
            <div class="flex justify-between items-center border-b border-white/10 pb-1.5">
              <span class="text-slate-400">Instansi Pondok</span>
              <span class="font-extrabold text-emerald-300">PPS MIFTAHUSSUNAN</span>
            </div>
            <div class="flex justify-between items-center border-b border-white/10 pb-1.5">
              <span class="text-slate-400">Hari & Tanggal Dibuat</span>
              <span class="font-bold text-cyan-300 font-mono-num">Senin, 23 November 2026</span>
            </div>
            <div class="flex justify-between items-center border-b border-white/10 pb-1.5">
              <span class="text-slate-400">Versi & Tema UI</span>
              <span class="font-bold text-fuchsia-300 font-mono-num">v2.5 • Aurora Tactile 2-Grid</span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-slate-400">Lisensi & Hak Cipta</span>
              <span class="font-bold text-slate-200">© 2026 Moch Khoirul Azman</span>
            </div>
          </div>

          <p class="text-[10px] text-center text-cyan-200/80 font-medium leading-relaxed relative z-10">
            Dirancang khusus untuk mempermudah manajemen keluar-masuk uang saku harian, setoran bulanan, dan tunggakan santri secara cepat & akurat.
          </p>
        </div>
      </section>

    </main>

    <!-- ==================== MODAL BOTTOM SHEET: 3-TAP AMBIL UANG (FASE 1) ==================== -->
    <div id="ambilModal" class="fixed inset-0 bg-black/75 backdrop-blur-sm z-40 hidden flex-col justify-end max-w-[435px] mx-auto">
      <div class="bg-[#0E1422] border-t border-white/15 w-full rounded-t-[32px] p-5 shadow-[0_-15px_50px_rgba(0,0,0,0.8)] animate-sheet max-h-[92vh] overflow-y-auto space-y-4">

        <!-- Handle Bar -->
        <div class="w-10 h-1 bg-slate-700 rounded-full mx-auto -mt-1 mb-1"></div>

        <!-- Header Modal -->
        <div class="flex justify-between items-start">
          <div class="flex items-center gap-3">
            <div id="modalAvatarSantri" class="w-11 h-11 rounded-2xl bg-emerald-500/15 border border-emerald-500/30 flex items-center justify-center font-extrabold text-emerald-300 text-sm">
              AF
            </div>
            <div>
              <span class="text-[10px] font-bold uppercase tracking-wider bg-white/10 text-slate-300 px-2 py-0.5 rounded-md" id="modalKamarSantri">Kamar 1</span>
              <h3 class="text-base font-extrabold text-white mt-0.5" id="modalNamaSantri">Ahmad Fauzi</h3>
            </div>
          </div>
          <button onclick="closeAmbilModal()" class="w-8 h-8 rounded-full bg-slate-800/80 hover:bg-slate-700 flex items-center justify-center text-slate-400 font-bold text-xs">✕</button>
        </div>

        <!-- Panel Live Simulasi Sisa Jatah Hari Ini -->
        <div class="bg-slate-950/90 border border-white/10 rounded-2xl p-3.5 space-y-2.5">
          <div class="flex justify-between items-center">
            <div>
              <span class="text-[10px] text-slate-400 uppercase font-semibold block">Sisa Jatah Hari Ini</span>
              <div class="flex items-baseline gap-1.5 mt-0.5">
                <span class="text-lg font-extrabold text-emerald-400 font-mono-num" id="modalSisaJatah">Rp 3.000</span>
                <span class="text-[11px] font-mono-num text-slate-500" id="modalSimulasiAfterText"></span>
              </div>
            </div>
            <div class="text-right">
              <span class="text-[10px] text-slate-400 uppercase font-semibold block">Total Sisa Saldo</span>
              <span class="text-sm font-bold text-slate-200 font-mono-num mt-0.5 block" id="modalTotalSaldo">Rp 243.000</span>
            </div>
          </div>

          <!-- Progress Bar Jatah Harian -->
          <div class="w-full bg-slate-900 h-2 rounded-full overflow-hidden border border-white/5">
            <div id="modalProgressBar" class="bg-emerald-500 h-full transition-all duration-300 shadow-[0_0_10px_rgba(16,185,129,0.5)]" style="width: 70%"></div>
          </div>

          <!-- Jejak Pengambilan Hari Ini -->
          <div class="flex items-center justify-between text-[11px] pt-0.5">
            <span id="modalRincianHariIni" class="font-medium text-sky-300">Hari ini: Pagi 2rb • Siang 5rb</span>
            <span id="modalJatahStandar" class="font-bold text-slate-400 font-mono-num">Kuota: Rp 10.000</span>
          </div>
        </div>

        <!-- Pilih Waktu Pengambilan (Pagi/Siang/Sore/Malam) -->
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">Sesi Waktu Pengambilan</label>
          <div class="grid grid-cols-4 gap-1.5" id="waktuSelector">
            <button type="button" onclick="selectWaktu('PAGI')" data-waktu="PAGI" class="waktu-btn py-2 rounded-xl text-xs font-bold border border-white/10 bg-slate-900 text-slate-400 transition">🌅 Pagi</button>
            <button type="button" onclick="selectWaktu('SIANG')" data-waktu="SIANG" class="waktu-btn py-2 rounded-xl text-xs font-bold border border-white/10 bg-slate-900 text-slate-400 transition">☀️ Siang</button>
            <button type="button" onclick="selectWaktu('SORE')" data-waktu="SORE" class="waktu-btn py-2 rounded-xl text-xs font-bold border border-white/10 bg-slate-900 text-slate-400 transition">🌤️ Sore</button>
            <button type="button" onclick="selectWaktu('MALAM')" data-waktu="MALAM" class="waktu-btn py-2 rounded-xl text-xs font-bold border border-emerald-500/60 bg-emerald-500/15 text-emerald-300 transition">🌙 Malam</button>
          </div>
        </div>

        <!-- Input Nominal & Tactile Quick Chips -->
        <div class="space-y-2">
          <div class="flex justify-between items-center">
            <label class="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Nominal Ambil (Rp)</label>
            <button type="button" onclick="setNominalAmbil(0)" class="text-[11px] text-rose-400 font-bold hover:underline">Reset Rp 0</button>
          </div>

          <div class="relative">
            <span class="absolute left-4 top-3.5 text-emerald-400 font-extrabold text-base font-mono-num">Rp</span>
            <input
              type="number"
              id="inputNominalAmbil"
              oninput="validateOverlimitModal()"
              placeholder="0"
              class="w-full bg-slate-950 border-2 border-white/15 focus:border-emerald-500 rounded-2xl pl-12 pr-4 py-3 text-xl font-extrabold text-white font-mono-num focus:outline-none transition"
            />
          </div>

          <!-- Tombol Pintasan Akumulatif Sekali Ketuk -->
          <div class="grid grid-cols-3 gap-1.5 pt-1">
            <button type="button" onclick="addNominalChip(1000)" class="bg-slate-900 hover:bg-slate-800 active:scale-95 border border-white/10 font-bold font-mono-num text-xs py-2.5 rounded-xl text-slate-200 transition">+1.000</button>
            <button type="button" onclick="addNominalChip(2000)" class="bg-slate-900 hover:bg-slate-800 active:scale-95 border border-white/10 font-bold font-mono-num text-xs py-2.5 rounded-xl text-slate-200 transition">+2.000</button>
            <button type="button" onclick="addNominalChip(3000)" class="bg-slate-900 hover:bg-slate-800 active:scale-95 border border-white/10 font-bold font-mono-num text-xs py-2.5 rounded-xl text-slate-200 transition">+3.000</button>
            <button type="button" onclick="addNominalChip(5000)" class="bg-slate-900 hover:bg-slate-800 active:scale-95 border border-white/10 font-bold font-mono-num text-xs py-2.5 rounded-xl text-slate-200 transition">+5.000</button>
            <button type="button" onclick="addNominalChip(10000)" class="bg-slate-900 hover:bg-slate-800 active:scale-95 border border-white/10 font-bold font-mono-num text-xs py-2.5 rounded-xl text-slate-200 transition">+10.000</button>
            <button type="button" onclick="ambilPasSisaJatah()" id="btnAmbilPasSisa" class="bg-emerald-500/20 hover:bg-emerald-500/30 active:scale-95 border border-emerald-500/40 font-extrabold text-xs py-2.5 rounded-xl text-emerald-300 transition">Pas Sisa</button>
          </div>
        </div>

        <!-- Tag Keperluan Cepat -->
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">Tag Keperluan</label>
          <div class="flex gap-1.5 overflow-x-auto no-scrollbar">
            <button type="button" onclick="selectKeperluan('Jajan Harian')" class="keperluan-chip bg-emerald-500 text-slate-950 px-3 py-1.5 rounded-xl text-xs font-extrabold whitespace-nowrap">🍘 Jajan Harian</button>
            <button type="button" onclick="selectKeperluan('Beli Sabun/Cuci')" class="keperluan-chip bg-slate-900 border border-white/10 text-slate-300 px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap">🧼 Sabun/Cuci</button>
            <button type="button" onclick="selectKeperluan('Obat / Kesehatan')" class="keperluan-chip bg-slate-900 border border-white/10 text-slate-300 px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap">💊 Obat</button>
            <button type="button" onclick="selectKeperluan('Kitab / Fotokopi')" class="keperluan-chip bg-slate-900 border border-white/10 text-slate-300 px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap">📚 Fotokopi</button>
          </div>
        </div>

        <!-- Box Peringatan Overlimit -->
        <div id="overlimitWarningBox" class="hidden bg-rose-950/60 border border-rose-500/40 rounded-2xl p-3 text-xs text-rose-200 space-y-2">
          <div class="flex items-center gap-1.5 font-extrabold text-rose-400">
            <span>⚠️ Melebihi Sisa Kuota Jatah Hari Ini!</span>
          </div>
          <p id="overlimitWarningText" class="text-[11px] leading-relaxed text-rose-200/90"></p>
          <div class="pt-1">
            <label class="text-[10px] font-bold uppercase text-rose-300 block mb-1">Kebijakan Overlimit:</label>
            <select id="overlimitPolicySelect" class="w-full bg-slate-950 border border-rose-500/40 rounded-xl px-2.5 py-2 text-xs font-semibold text-rose-200 focus:outline-none">
              <option value="POTONG_SALDO">Izinkan (Darurat) & Potong Total Saldo</option>
              <option value="HITUNG_ULANG">Izinkan & Hitung Ulang Rata-Rata Jatah Harian</option>
            </select>
          </div>
        </div>

        <!-- Tombol Simpan -->
        <button onclick="prosesAmbilUang()" id="btnSimpanAmbil" class="w-full bg-emerald-500 hover:bg-emerald-400 active:scale-[0.98] text-slate-950 font-extrabold py-3.5 rounded-2xl shadow-[0_0_25px_rgba(16,185,129,0.35)] transition text-xs uppercase tracking-wider">
          ✅ Simpan Pengambilan Uang
        </button>
      </div>
    </div>

    <!-- ==================== MODAL TAMBAH SANTRI BARU ==================== -->
    <div id="addSantriModal" class="fixed inset-0 bg-black/75 backdrop-blur-sm z-40 hidden flex-col justify-end max-w-[435px] mx-auto">
      <div class="bg-[#0E1422] border-t border-white/15 w-full rounded-t-[32px] p-5 shadow-2xl animate-sheet space-y-3.5">
        <div class="flex justify-between items-center">
          <h3 class="text-base font-extrabold text-white">👦 Tambah Santri Baru</h3>
          <button onclick="closeAddSantriModal()" class="w-8 h-8 rounded-full bg-slate-800 flex items-center justify-center text-slate-400 font-bold text-xs">✕</button>
        </div>

        <div>
          <label class="text-[11px] font-bold text-slate-400 uppercase block mb-1">Nama Lengkap Santri</label>
          <input type="text" id="newNamaSantri" placeholder="Contoh: Muhammad Farhan" class="w-full bg-slate-950 border border-white/10 rounded-xl px-3.5 py-2.5 text-xs font-semibold text-white focus:outline-none focus:border-emerald-500" />
        </div>

        <div class="grid grid-cols-2 gap-2.5">
          <div>
            <label class="text-[11px] font-bold text-slate-400 uppercase block mb-1">Kamar / Asrama</label>
            <input type="text" id="newKamarSantri" value="Kamar 1" class="w-full bg-slate-950 border border-white/10 rounded-xl px-3.5 py-2.5 text-xs font-semibold text-white focus:outline-none focus:border-emerald-500" />
          </div>
          <div>
            <label class="text-[11px] font-bold text-slate-400 uppercase block mb-1">Setoran Awal (Rp)</label>
            <input type="number" id="newSetoranSantri" value="300000" oninput="document.getElementById('newJatahSantri').value = Math.round(this.value / 30)" class="w-full bg-slate-950 border border-white/10 rounded-xl px-3.5 py-2.5 text-xs font-bold text-white font-mono-num focus:outline-none focus:border-emerald-500" />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-2.5">
          <div>
            <label class="text-[11px] font-bold text-slate-400 uppercase block mb-1">Jatah Harian (Rp/Hr)</label>
            <input type="number" id="newJatahSantri" value="10000" class="w-full bg-slate-950 border border-white/10 rounded-xl px-3.5 py-2.5 text-xs font-bold text-emerald-400 font-mono-num focus:outline-none focus:border-emerald-500" />
          </div>
          <div>
            <label class="text-[11px] font-bold text-rose-300 uppercase block mb-1">Tunggakan Awal (Rp)</label>
            <input type="number" id="newTunggakanSantri" value="0" class="w-full bg-slate-950 border border-rose-500/30 rounded-xl px-3.5 py-2.5 text-xs font-bold text-rose-300 font-mono-num focus:outline-none focus:border-rose-400" />
          </div>
        </div>

        <button onclick="simpanSantriBaru()" class="w-full bg-gradient-to-r from-emerald-400 to-cyan-400 text-slate-950 font-extrabold py-3.5 rounded-2xl text-xs uppercase tracking-wider shadow-[0_0_20px_rgba(16,185,129,0.4)]">
          Simpan Data Santri
        </button>
      </div>
    </div>

    <!-- ==================== MODAL KELOLA TUNGGAKAN SANTRI ==================== -->
    <div id="tunggakanModal" class="fixed inset-0 bg-black/75 backdrop-blur-sm z-40 hidden flex-col justify-end max-w-[435px] mx-auto">
      <div class="bg-[#101324] border-t border-rose-500/40 w-full rounded-t-[32px] p-5 shadow-[0_-15px_50px_rgba(244,63,94,0.25)] animate-sheet space-y-4">
        <div class="w-10 h-1 bg-slate-700 rounded-full mx-auto -mt-1"></div>

        <div class="flex justify-between items-start">
          <div>
            <span class="text-[10px] font-extrabold uppercase tracking-wider bg-rose-500/20 text-rose-300 border border-rose-500/40 px-2.5 py-0.5 rounded-full">🚨 Manajemen Tunggakan</span>
            <h3 class="text-base font-black text-white mt-1" id="tunggakanNamaSantri">Ahmad Fauzi</h3>
          </div>
          <button onclick="closeTunggakanModal()" class="w-8 h-8 rounded-full bg-slate-800 flex items-center justify-center text-slate-400 font-bold text-xs">✕</button>
        </div>

        <div class="bg-gradient-to-r from-rose-950/80 via-slate-950 to-fuchsia-950/70 border border-rose-500/40 rounded-2xl p-3.5 flex justify-between items-center">
          <div>
            <span class="text-[10px] text-rose-300 font-bold uppercase block">Total Tunggakan Saat Ini</span>
            <span class="text-xl font-black text-rose-300 font-mono-num mt-0.5 block" id="tunggakanNominalSaatIni">Rp 50.000</span>
            <span class="text-[11px] text-slate-300 mt-0.5 block" id="tunggakanCatatanSaatIni">Kurang Setoran Bulanan</span>
          </div>
          <span class="text-2xl">📋</span>
        </div>

        <div class="grid grid-cols-2 gap-2">
          <button type="button" id="btnModeBayarTunggakan" onclick="setModeTunggakan('BAYAR')" class="py-2.5 rounded-2xl text-xs font-extrabold border border-emerald-400 bg-emerald-500/20 text-emerald-300">
            ✅ Bayar / Cicil
          </button>
          <button type="button" id="btnModeTambahTunggakan" onclick="setModeTunggakan('TAMBAH')" class="py-2.5 rounded-2xl text-xs font-extrabold border border-white/10 bg-slate-900 text-slate-400">
            ➕ Tambah Tunggakan
          </button>
        </div>

        <div class="space-y-2.5">
          <div>
            <div class="flex justify-between items-center mb-1">
              <label class="text-[10px] font-bold text-slate-300 uppercase">Nominal (Rp)</label>
              <button type="button" onclick="isiLunasTunggakan()" class="text-[10px] text-emerald-400 font-extrabold hover:underline">Isi Lunas Semua</button>
            </div>
            <input type="number" id="inputNominalTunggakan" placeholder="Contoh: 50000" class="w-full bg-slate-950 border border-white/15 rounded-2xl px-3.5 py-2.5 text-base font-black text-white font-mono-num focus:outline-none focus:border-cyan-400" />
          </div>

          <div>
            <label class="text-[10px] font-bold text-slate-300 uppercase block mb-1">Keterangan Tunggakan</label>
            <input type="text" id="inputCatatanTunggakan" placeholder="Contoh: Pelunasan kekurangan setoran / Kasbon obat" class="w-full bg-slate-950 border border-white/15 rounded-2xl px-3.5 py-2.5 text-xs text-white focus:outline-none focus:border-cyan-400" />
          </div>
        </div>

        <button onclick="simpanTransaksiTunggakan()" id="btnSubmitTunggakan" class="w-full bg-gradient-to-r from-emerald-400 to-cyan-400 text-slate-950 font-black py-3.5 rounded-2xl text-xs uppercase tracking-wider shadow-[0_0_25px_rgba(16,185,129,0.4)]">
          ✅ Simpan Pembayaran Tunggakan
        </button>
      </div>
    </div>

    <!-- ==================== LAYAR KUNCI PIN DARK GLASS (FASE 5) ==================== -->
    <div id="pinLockOverlay" class="fixed inset-0 bg-[#060911]/95 backdrop-blur-xl z-50 hidden flex-col items-center justify-center text-white p-6 max-w-[435px] mx-auto">
      <div class="w-16 h-16 rounded-3xl bg-emerald-500/15 flex items-center justify-center text-3xl mb-4 border border-emerald-500/30 shadow-[0_0_30px_rgba(16,185,129,0.25)]">🔒</div>
      <h3 class="text-lg font-extrabold tracking-tight">Kas Santri Terkunci</h3>
      <p class="text-xs text-slate-400 text-center mt-1 mb-6 leading-relaxed">Keamanan pengurus untuk mencegah perubahan saldo.<br/>(Masukkan PIN Simulasi: <b class="text-emerald-400 font-mono-num">1234</b>)</p>
      <input type="password" id="pinInput" maxlength="4" placeholder="••••" class="bg-slate-900 border border-emerald-500/40 text-center text-2xl tracking-[0.6em] font-extrabold rounded-2xl px-4 py-3 w-44 mb-4 text-emerald-400 focus:outline-none" />
      <button onclick="verifyPin()" class="bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-extrabold px-10 py-3 rounded-2xl text-xs uppercase tracking-wider shadow-[0_0_20px_rgba(16,185,129,0.35)]">Buka Brankas</button>
    </div>

    <!-- TOAST NOTIFIKASI & TOMBOL UNDO -->
    <div id="toastBanner" class="fixed bottom-24 left-1/2 -translate-x-1/2 w-[90%] max-w-[395px] bg-slate-900/95 backdrop-blur-xl border border-emerald-500/40 text-white px-4 py-3 rounded-2xl shadow-[0_10px_30px_rgba(0,0,0,0.8)] z-50 hidden items-center justify-between text-xs">
      <span id="toastText" class="font-medium text-slate-100 leading-snug">Transaksi berhasil disimpan!</span>
      <button id="toastUndoBtn" onclick="undoLastTransaction()" class="hidden ml-3 bg-amber-400 hover:bg-amber-300 text-slate-950 font-extrabold px-2.5 py-1 rounded-lg text-[10px] shrink-0">BATALKAN</button>
    </div>

    <!-- ==================== FLOATING GLASS BOTTOM NAVIGATION BAR ==================== -->
    <div class="fixed md:absolute bottom-3 left-0 right-0 max-w-[435px] mx-auto px-4 z-30 pointer-events-none">
      <nav class="pointer-events-auto bg-slate-900/85 backdrop-blur-2xl border border-white/10 rounded-2xl px-2 py-2 flex justify-around items-center shadow-[0_10px_35px_rgba(0,0,0,0.75)]">
        <button onclick="switchTab('home')" data-tab="home" class="nav-btn flex flex-col items-center gap-0.5 text-emerald-400 font-extrabold text-[10px] px-3 py-1 rounded-xl transition">
          <span class="text-base">💸</span>
          <span>Kas & Ambil</span>
        </button>
        <button onclick="switchTab('setoran')" data-tab="setoran" class="nav-btn flex flex-col items-center gap-0.5 text-slate-400 font-semibold text-[10px] px-3 py-1 rounded-xl transition">
          <span class="text-base">📥</span>
          <span>Setoran</span>
        </button>
        <button onclick="switchTab('riwayat')" data-tab="riwayat" class="nav-btn flex flex-col items-center gap-0.5 text-slate-400 font-semibold text-[10px] px-3 py-1 rounded-xl transition">
          <span class="text-base">📜</span>
          <span>Mutasi</span>
        </button>
        <button onclick="switchTab('laporan')" data-tab="laporan" class="nav-btn flex flex-col items-center gap-0.5 text-slate-400 font-semibold text-[10px] px-3 py-1 rounded-xl transition">
          <span class="text-base">📊</span>
          <span>Rekap WA</span>
        </button>
        <button onclick="switchTab('pengaturan')" data-tab="pengaturan" class="nav-btn flex flex-col items-center gap-0.5 text-slate-400 font-semibold text-[10px] px-3 py-1 rounded-xl transition">
          <span class="text-base">⚙️</span>
          <span>Sistem</span>
        </button>
      </nav>
    </div>

  </div>

  <script>
    // =========================================================================
    // DATA INITIALIZATION (PPS MIFTAHUSSUNAN + DATA TUNGGAKAN)
    // =========================================================================
    const STORAGE_KEY = 'KAS_SANTRI_MIFTAHUSSUNAN_V4';
    const TODAY_STR = new Date().toISOString().slice(0, 10);

    const INITIAL_DATA = {
      settings: {
        namaPondok: 'PPS MIFTAHUSSUNAN',
        modeSisa: 'KETAT',
        hideBalance: false,
        gridMode: '2_COL',
        logoDataUrl: ''
      },
      santri: [
        {
          id: 's1',
          nama: 'Ahmad Fauzi',
          kamar: 'Kamar 1',
          saldoTotal: 243000,
          jatahHarian: 10000,
          setoranAwal: 300000,
          tunggakan: 50000,
          catatanTunggakan: 'Kurang Setoran Bulanan'
        },
        {
          id: 's2',
          nama: 'Zaidan Alfarizi',
          kamar: 'Kamar 1',
          saldoTotal: 280000,
          jatahHarian: 10000,
          setoranAwal: 300000,
          tunggakan: 0,
          catatanTunggakan: ''
        },
        {
          id: 's3',
          nama: 'M. Rizky Pratama',
          kamar: 'Kamar 2',
          saldoTotal: 190000,
          jatahHarian: 10000,
          setoranAwal: 300000,
          tunggakan: 120000,
          catatanTunggakan: 'Tunggakan Syahriyah & Kasbon Obat'
        },
        {
          id: 's4',
          nama: 'Bilal Ramadhan',
          kamar: 'Kamar 2',
          saldoTotal: 387000,
          jatahHarian: 15000,
          setoranAwal: 450000,
          tunggakan: 0,
          catatanTunggakan: ''
        },
        {
          id: 's5',
          nama: 'Naufal Syauqi',
          kamar: 'Kamar 3',
          saldoTotal: 266000,
          jatahHarian: 10000,
          setoranAwal: 300000,
          tunggakan: 75000,
          catatanTunggakan: 'Belum Lunas Uang Makan'
        },
        {
          id: 's6',
          nama: 'Farhan Maulana',
          kamar: 'Kamar 3',
          saldoTotal: 300000,
          jatahHarian: 10000,
          setoranAwal: 300000,
          tunggakan: 0,
          catatanTunggakan: ''
        }
      ],
      transaksi: [
        {
          id: 'tx1',
          santriId: 's1',
          tipe: 'KELUAR',
          nominal: 2000,
          tanggal: TODAY_STR,
          jam: '07:15',
          kategoriWaktu: 'PAGI',
          catatan: 'Jajan Pagi / Sarapan',
          isOverlimit: false
        },
        {
          id: 'tx2',
          santriId: 's1',
          tipe: 'KELUAR',
          nominal: 5000,
          tanggal: TODAY_STR,
          jam: '12:40',
          kategoriWaktu: 'SIANG',
          catatan: 'Jajan Siang',
          isOverlimit: false
        },
        {
          id: 'tx3',
          santriId: 's3',
          tipe: 'KELUAR',
          nominal: 5000,
          tanggal: TODAY_STR,
          jam: '07:30',
          kategoriWaktu: 'PAGI',
          catatan: 'Jajan Harian',
          isOverlimit: false
        },
        {
          id: 'tx4',
          santriId: 's3',
          tipe: 'KELUAR',
          nominal: 5000,
          tanggal: TODAY_STR,
          jam: '13:10',
          kategoriWaktu: 'SIANG',
          catatan: 'Beli Sabun/Cuci',
          isOverlimit: false
        },
        {
          id: 'tx5',
          santriId: 's4',
          tipe: 'KELUAR',
          nominal: 3000,
          tanggal: TODAY_STR,
          jam: '08:00',
          kategoriWaktu: 'PAGI',
          catatan: 'Jajan Harian',
          isOverlimit: false
        },
        {
          id: 'tx6',
          santriId: 's5',
          tipe: 'KELUAR',
          nominal: 4000,
          tanggal: TODAY_STR,
          jam: '09:20',
          kategoriWaktu: 'PAGI',
          catatan: 'Jajan Harian',
          isOverlimit: false
        }
      ]
    };

    let state = loadState();
    let currentFilter = 'ALL';
    let activeSantriId = null;
    let activeTunggakanSantriId = null;
    let modeTunggakan = 'BAYAR';
    let selectedWaktu = 'MALAM';
    let selectedKeperluan = 'Jajan Harian';
    let tipeSetoran = 'AWAL_BULAN';
    let lastUndoTxId = null;

    function loadState() {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved) {
        try { return JSON.parse(saved); } catch (e) {}
      }
      return JSON.parse(JSON.stringify(INITIAL_DATA));
    }

    function saveState() {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
      refreshAllUI();
    }

    // =========================================================================
    // FITUR UPLOAD GAMBAR LOGO PONDOK
    // =========================================================================
    function triggerLogoUpload() {
      document.getElementById('logoFileInput').click();
    }

    function handleLogoUpload(event) {
      const file = event.target.files && event.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = function(e) {
        state.settings.logoDataUrl = e.target.result;
        saveState();
        showToast('Logo PPS MIFTAHUSSUNAN berhasil diperbarui!', false);
      };
      reader.readAsDataURL(file);
    }

    function renderLogoHeader() {
      const imgEl = document.getElementById('headerLogoImg');
      const svgEl = document.getElementById('headerLogoDefaultSvg');
      if (state.settings.logoDataUrl) {
        imgEl.src = state.settings.logoDataUrl;
        imgEl.classList.remove('hidden');
        svgEl.classList.add('hidden');
      } else {
        imgEl.classList.add('hidden');
        svgEl.classList.remove('hidden');
      }
    }

    // =========================================================================
    // FUNGSI UTILITAS, FORMAT RUPIAH, & KALKULASI JATAH HARIAN
    // =========================================================================
    function formatRupiah(num) {
      const n = Number(num) || 0;
      const sign = n < 0 ? '-' : '';
      return sign + 'Rp ' + Math.abs(n).toLocaleString('id-ID');
    }

    function getInitials(name) {
      if (!name) return 'KS';
      return name
        .trim()
        .split(/\s+/)
        .slice(0, 2)
        .map(w => w[0].toUpperCase())
        .join('');
    }

    function getSantriTodayStats(santri) {
      const txToday = state.transaksi.filter(
        t => t.santriId === santri.id && t.tanggal === TODAY_STR && t.tipe === 'KELUAR'
      );
      const terpakaiHariIni = txToday.reduce((sum, t) => sum + t.nominal, 0);
      const sisaJatahHariIni = santri.jatahHarian - terpakaiHariIni;

      let status = 'UTUH';
      if (terpakaiHariIni === 0) {
        status = 'UTUH';
      } else if (sisaJatahHariIni > 0) {
        status = 'SEBAGIAN';
      } else if (sisaJatahHariIni === 0) {
        status = 'HABIS';
      } else {
        status = 'OVERLIMIT';
      }

      return { txToday, terpakaiHariIni, sisaJatahHariIni, status };
    }

    function toggleHideBalance() {
      state.settings.hideBalance = !state.settings.hideBalance;
      saveState();
    }

    function toggleGridLayout() {
      state.settings.gridMode = state.settings.gridMode === '2_COL' ? '1_COL' : '2_COL';
      saveState();
    }

    function setFilter(filter) {
      currentFilter = filter;
      document.querySelectorAll('.filter-btn').forEach(btn => {
        if (btn.dataset.filter === filter) {
          btn.className = 'filter-btn bg-gradient-to-r from-emerald-400 via-teal-400 to-cyan-400 text-slate-950 px-3.5 py-1.5 rounded-full text-[11px] font-extrabold whitespace-nowrap transition shadow-[0_0_15px_rgba(52,211,153,0.45)]';
        } else {
          btn.className = 'filter-btn glass-card text-slate-200 px-3.5 py-1.5 rounded-full text-[11px] font-semibold whitespace-nowrap transition';
        }
      });
      renderSantriList();
    }

    // =========================================================================
    // MODAL 3-TAP AMBIL UANG HARIAN
    // =========================================================================
    function openAmbilModal(santriId) {
      activeSantriId = santriId;
      const santri = state.santri.find(s => s.id === santriId);
      if (!santri) return;

      const { txToday, terpakaiHariIni, sisaJatahHariIni } = getSantriTodayStats(santri);
      document.getElementById('modalAvatarSantri').textContent = getInitials(santri.nama);
      document.getElementById('modalKamarSantri').textContent = santri.kamar;
      document.getElementById('modalNamaSantri').textContent = santri.nama;
      document.getElementById('modalSisaJatah').textContent = formatRupiah(Math.max(0, sisaJatahHariIni));
      document.getElementById('modalTotalSaldo').textContent = formatRupiah(santri.saldoTotal);
      document.getElementById('modalJatahStandar').textContent = `Kuota: ${formatRupiah(santri.jatahHarian)}`;
      document.getElementById('modalSimulasiAfterText').textContent = '';

      if (txToday.length > 0) {
        const rincian = txToday.map(t => `${t.kategoriWaktu} ${t.nominal / 1000}rb`).join(' • ');
        document.getElementById('modalRincianHariIni').textContent = `Hari ini: ${rincian}`;
      } else {
        document.getElementById('modalRincianHariIni').textContent = 'Hari ini: Belum ada pengambilan';
      }

      const pct = Math.min(100, Math.round((terpakaiHariIni / santri.jatahHarian) * 100));
      document.getElementById('modalProgressBar').style.width = `${pct}%`;

      document.getElementById('inputNominalAmbil').value = sisaJatahHariIni > 0 ? Math.min(2000, sisaJatahHariIni) : '';
      selectWaktu(selectedWaktu);
      selectKeperluan('Jajan Harian');
      validateOverlimitModal();

      const modal = document.getElementById('ambilModal');
      modal.classList.remove('hidden');
      modal.classList.add('flex');
    }

    function closeAmbilModal() {
      const modal = document.getElementById('ambilModal');
      modal.classList.add('hidden');
      modal.classList.remove('flex');
    }

    function selectWaktu(waktu) {
      selectedWaktu = waktu;
      document.querySelectorAll('.waktu-btn').forEach(btn => {
        if (btn.dataset.waktu === waktu) {
          btn.className = 'waktu-btn py-2 rounded-xl text-xs font-bold border border-emerald-500/60 bg-emerald-500/15 text-emerald-300 transition';
        } else {
          btn.className = 'waktu-btn py-2 rounded-xl text-xs font-bold border border-white/10 bg-slate-900 text-slate-400 transition';
        }
      });
    }

    function selectKeperluan(kep) {
      selectedKeperluan = kep;
      document.querySelectorAll('.keperluan-chip').forEach(btn => {
        if (btn.textContent.includes(kep.split(' ')[0])) {
          btn.className = 'keperluan-chip bg-emerald-500 text-slate-950 px-3 py-1.5 rounded-xl text-xs font-extrabold whitespace-nowrap';
        } else {
          btn.className = 'keperluan-chip bg-slate-900 border border-white/10 text-slate-300 px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap';
        }
      });
    }

    function setNominalAmbil(val) {
      document.getElementById('inputNominalAmbil').value = val > 0 ? val : '';
      validateOverlimitModal();
    }

    function addNominalChip(addVal) {
      const input = document.getElementById('inputNominalAmbil');
      const current = parseInt(input.value || '0', 10);
      input.value = current + addVal;
      validateOverlimitModal();
    }

    function ambilPasSisaJatah() {
      const santri = state.santri.find(s => s.id === activeSantriId);
      if (!santri) return;
      const { sisaJatahHariIni } = getSantriTodayStats(santri);
      document.getElementById('inputNominalAmbil').value = Math.max(0, sisaJatahHariIni);
      validateOverlimitModal();
    }

    function validateOverlimitModal() {
      const santri = state.santri.find(s => s.id === activeSantriId);
      if (!santri) return;

      const { sisaJatahHariIni } = getSantriTodayStats(santri);
      const nominal = parseInt(document.getElementById('inputNominalAmbil').value || '0', 10);
      const warningBox = document.getElementById('overlimitWarningBox');
      const warningText = document.getElementById('overlimitWarningText');
      const afterText = document.getElementById('modalSimulasiAfterText');

      if (nominal > 0) {
        const sisaSetelah = sisaJatahHariIni - nominal;
        afterText.textContent = `→ Sisa: ${formatRupiah(sisaSetelah)}`;
      } else {
        afterText.textContent = '';
      }

      if (nominal > sisaJatahHariIni && nominal > 0) {
        const kelebihan = nominal - Math.max(0, sisaJatahHariIni);
        warningBox.classList.remove('hidden');
        warningText.textContent = `Nominal ambil (${formatRupiah(nominal)}) melewati sisa kuota harian sebesar ${formatRupiah(kelebihan)}.`;
      } else {
        warningBox.classList.add('hidden');
      }
    }

    function prosesAmbilUang() {
      const santri = state.santri.find(s => s.id === activeSantriId);
      if (!santri) return;

      const nominal = parseInt(document.getElementById('inputNominalAmbil').value || '0', 10);
      if (nominal <= 0) {
        showToast('Masukkan nominal pengambilan lebih dari Rp 0!', false);
        return;
      }

      if (nominal > santri.saldoTotal) {
        showToast('Saldo total santri tidak mencukupi!', false);
        return;
      }

      const { sisaJatahHariIni } = getSantriTodayStats(santri);
      const isOverlimit = nominal > sisaJatahHariIni;

      santri.saldoTotal -= nominal;

      if (isOverlimit) {
        const policy = document.getElementById('overlimitPolicySelect').value;
        if (policy === 'HITUNG_ULANG') {
          santri.jatahHarian = Math.max(1000, Math.round(santri.saldoTotal / 20));
        }
      }

      const now = new Date();
      const jamStr = now.toTimeString().slice(0, 5);
      const newTx = {
        id: 'tx_' + Date.now(),
        santriId: santri.id,
        tipe: 'KELUAR',
        nominal,
        tanggal: TODAY_STR,
        jam: jamStr,
        kategoriWaktu: selectedWaktu,
        catatan: selectedKeperluan,
        isOverlimit
      };

      state.transaksi.unshift(newTx);
      lastUndoTxId = newTx.id;

      closeAmbilModal();
      saveState();
      showToast(`${santri.nama} ambil ${formatRupiah(nominal)} (${selectedWaktu})`, true);
    }

    // =========================================================================
    // MODAL MANAJEMEN TUNGGAKAN SANTRI
    // =========================================================================
    function openTunggakanModal(santriId) {
      activeTunggakanSantriId = santriId;
      const santri = state.santri.find(s => s.id === santriId);
      if (!santri) return;

      document.getElementById('tunggakanNamaSantri').textContent = `${santri.nama} (${santri.kamar})`;
      document.getElementById('tunggakanNominalSaatIni').textContent = formatRupiah(santri.tunggakan || 0);
      document.getElementById('tunggakanCatatanSaatIni').textContent =
        santri.tunggakan > 0
          ? (santri.catatanTunggakan || 'Memiliki tunggakan aktif')
          : 'Alhamdulillah, tidak ada tunggakan';

      document.getElementById('inputNominalTunggakan').value = santri.tunggakan > 0 ? santri.tunggakan : '';
      document.getElementById('inputCatatanTunggakan').value = '';
      setModeTunggakan(santri.tunggakan > 0 ? 'BAYAR' : 'TAMBAH');

      const modal = document.getElementById('tunggakanModal');
      modal.classList.remove('hidden');
      modal.classList.add('flex');
    }

    function closeTunggakanModal() {
      const modal = document.getElementById('tunggakanModal');
      modal.classList.add('hidden');
      modal.classList.remove('flex');
    }

    function setModeTunggakan(mode) {
      modeTunggakan = mode;
      const btnBayar = document.getElementById('btnModeBayarTunggakan');
      const btnTambah = document.getElementById('btnModeTambahTunggakan');
      const btnSubmit = document.getElementById('btnSubmitTunggakan');

      if (mode === 'BAYAR') {
        btnBayar.className = 'py-2.5 rounded-2xl text-xs font-extrabold border border-emerald-400 bg-emerald-500/20 text-emerald-300';
        btnTambah.className = 'py-2.5 rounded-2xl text-xs font-extrabold border border-white/10 bg-slate-900 text-slate-400';
        btnSubmit.textContent = '✅ Simpan Pembayaran Tunggakan';
        btnSubmit.className = 'w-full bg-gradient-to-r from-emerald-400 to-cyan-400 text-slate-950 font-black py-3.5 rounded-2xl text-xs uppercase tracking-wider shadow-[0_0_25px_rgba(16,185,129,0.4)]';
      } else {
        btnTambah.className = 'py-2.5 rounded-2xl text-xs font-extrabold border border-rose-400 bg-rose-500/20 text-rose-300';
        btnBayar.className = 'py-2.5 rounded-2xl text-xs font-extrabold border border-white/10 bg-slate-900 text-slate-400';
        btnSubmit.textContent = '🚨 Tambahkan Catatan Tunggakan';
        btnSubmit.className = 'w-full bg-gradient-to-r from-rose-500 to-fuchsia-500 text-white font-black py-3.5 rounded-2xl text-xs uppercase tracking-wider shadow-[0_0_25px_rgba(244,63,94,0.4)]';
      }
    }

    function isiLunasTunggakan() {
      const santri = state.santri.find(s => s.id === activeTunggakanSantriId);
      if (!santri) return;
      document.getElementById('inputNominalTunggakan').value = santri.tunggakan || 0;
    }

    function simpanTransaksiTunggakan() {
      const santri = state.santri.find(s => s.id === activeTunggakanSantriId);
      if (!santri) return;

      const nominal = parseInt(document.getElementById('inputNominalTunggakan').value || '0', 10);
      const ket = document.getElementById('inputCatatanTunggakan').value.trim();

      if (nominal <= 0) {
        showToast('Masukkan nominal tunggakan lebih dari Rp 0!', false);
        return;
      }

      if (modeTunggakan === 'BAYAR') {
        santri.tunggakan = Math.max(0, (santri.tunggakan || 0) - nominal);
        if (santri.tunggakan === 0) {
          santri.catatanTunggakan = '';
        } else if (ket) {
          santri.catatanTunggakan = ket;
        }
        showToast(`Pembayaran tunggakan ${santri.nama} (${formatRupiah(nominal)}) tercatat!`, false);
      } else {
        santri.tunggakan = (santri.tunggakan || 0) + nominal;
        santri.catatanTunggakan = ket || santri.catatanTunggakan || 'Tunggakan Pondok / Kasbon';
        showToast(`Tunggakan ${santri.nama} bertambah ${formatRupiah(nominal)}`, false);
      }

      closeTunggakanModal();
      saveState();
    }

    // =========================================================================
    // RENDER HEADER BRANKAS & DAFTAR KARTU 2 KOTAK
    // =========================================================================
    function renderDashboardHeader() {
      document.getElementById('headerNamaPondok').textContent = state.settings.namaPondok || 'PPS MIFTAHUSSUNAN';
      document.getElementById('settingNamaPondok').value = state.settings.namaPondok || 'PPS MIFTAHUSSUNAN';
      document.getElementById('settingModeSisa').value = state.settings.modeSisa || 'KETAT';

      renderLogoHeader();

      const totalBrankas = state.santri.reduce((acc, s) => acc + (s.saldoTotal || 0), 0);
      const totalKuotaHarian = state.santri.reduce((acc, s) => acc + (s.jatahHarian || 0), 0);
      const totalKeluarHariIni = state.transaksi
        .filter(t => t.tanggal === TODAY_STR && t.tipe === 'KELUAR')
        .reduce((acc, t) => acc + t.nominal, 0);

      const totalTunggakan = state.santri.reduce((acc, s) => acc + (s.tunggakan || 0), 0);
      const countSantriTunggakan = state.santri.filter(s => (s.tunggakan || 0) > 0).length;

      const isHidden = state.settings.hideBalance;
      document.getElementById('totalUangFisik').textContent = isHidden ? 'Rp ••••••••' : formatRupiah(totalBrankas);
      document.getElementById('jumlahSantriBadge').textContent = `${state.santri.length} Santri`;
      document.getElementById('totalKeluarHariIni').textContent = isHidden ? 'Rp ••••' : formatRupiah(totalKeluarHariIni);
      document.getElementById('totalKuotaHariIni').textContent = isHidden ? 'Rp ••••' : formatRupiah(totalKuotaHarian);
      document.getElementById('totalTunggakanPondok').textContent = isHidden ? 'Rp ••••' : formatRupiah(totalTunggakan);
      document.getElementById('countTunggakanBadge').textContent = countSantriTunggakan;

      const pct = totalKuotaHarian > 0 ? Math.min(100, Math.round((totalKeluarHariIni / totalKuotaHarian) * 100)) : 0;
      document.getElementById('globalKuotaPctText').textContent = `${pct}%`;
      document.getElementById('globalKuotaBar').style.width = `${pct}%`;
    }

    function renderSantriList() {
      const container = document.getElementById('santriListContainer');
      const query = (document.getElementById('searchInput').value || '').toLowerCase().trim();
      const isTwoCol = state.settings.gridMode !== '1_COL';

      document.getElementById('layoutLabelText').textContent = isTwoCol ? '2 Kotak' : '1 Baris';
      container.className = isTwoCol ? 'grid grid-cols-2 gap-3' : 'space-y-2.5';

      const filtered = state.santri.filter(santri => {
        const matchSearch =
          santri.nama.toLowerCase().includes(query) ||
          santri.kamar.toLowerCase().includes(query);
        if (!matchSearch) return false;

        if (currentFilter === 'ALL') return true;
        if (currentFilter === 'TUNGGAKAN') return (santri.tunggakan || 0) > 0;

        const { status } = getSantriTodayStats(santri);
        if (currentFilter === 'HABIS') return status === 'HABIS' || status === 'OVERLIMIT';
        return status === currentFilter;
      });

      if (filtered.length === 0) {
        container.className = 'space-y-2';
        container.innerHTML = `
          <div class="glass-card rounded-3xl p-6 text-center space-y-2">
            <div class="text-2xl">🔍</div>
            <p class="text-xs font-extrabold text-white">Santri Tidak Ditemukan</p>
            <p class="text-[11px] text-slate-400">Coba kata kunci pencarian atau filter status lainnya.</p>
          </div>
        `;
        return;
      }

      if (isTwoCol) {
        container.innerHTML = filtered.map(santri => {
          const { txToday, terpakaiHariIni, sisaJatahHariIni, status } = getSantriTodayStats(santri);
          const initials = getInitials(santri.nama);
          const nominalTunggakan = santri.tunggakan || 0;
          const pct = Math.min(100, Math.round((terpakaiHariIni / santri.jatahHarian) * 100));

          const cardTheme =
            status === 'UTUH'
              ? 'card-theme-utuh'
              : status === 'SEBAGIAN'
              ? 'card-theme-sebagian'
              : status === 'HABIS'
              ? 'card-theme-habis'
              : 'card-theme-over';

          const badgeStatusHtml =
            status === 'UTUH'
              ? `<span class="text-[9px] font-extrabold px-2 py-0.5 rounded-full bg-emerald-400/25 text-emerald-200 border border-emerald-300/40">🟢 Utuh</span>`
              : status === 'SEBAGIAN'
              ? `<span class="text-[9px] font-extrabold px-2 py-0.5 rounded-full bg-cyan-400/25 text-cyan-200 border border-cyan-300/40">${txToday.length}x Ambil</span>`
              : status === 'HABIS'
              ? `<span class="text-[9px] font-extrabold px-2 py-0.5 rounded-full bg-amber-400/25 text-amber-200 border border-amber-300/40">🟡 Habis</span>`
              : `<span class="text-[9px] font-extrabold px-2 py-0.5 rounded-full bg-rose-500/30 text-rose-200 border border-rose-400/50">🔴 Over</span>`;

          const pillsWaktuHtml = txToday.length > 0
            ? txToday.map(t => {
                const icon = t.kategoriWaktu === 'PAGI' ? '🌅' : t.kategoriWaktu === 'SIANG' ? '☀️' : t.kategoriWaktu === 'SORE' ? '🌤️' : '🌙';
                return `<span class="bg-black/45 border border-white/15 px-1.5 py-0.5 rounded-md text-[9px] font-mono-num text-cyan-200">${icon}${t.nominal / 1000}rb</span>`;
              }).join('')
            : `<span class="text-[9px] text-emerald-200/80 italic">Belum ambil hari ini</span>`;

          return `
            <div
              onclick="openAmbilModal('${santri.id}')"
              class="cursor-pointer santri-btn-card ${cardTheme} rounded-[26px] p-3 flex flex-col justify-between gap-2.5"
            >
              <!-- Baris Atas: Avatar, Kamar & Status -->
              <div class="flex items-center justify-between gap-1">
                <div class="flex items-center gap-1.5">
                  <div class="w-8 h-8 rounded-xl bg-gradient-to-br from-white/25 to-white/5 border border-white/30 flex items-center justify-center font-black text-[11px] text-white shadow">
                    ${initials}
                  </div>
                  <span class="text-[9px] font-extrabold bg-black/40 border border-white/15 px-2 py-0.5 rounded-full text-slate-200">
                    ${santri.kamar}
                  </span>
                </div>
                ${badgeStatusHtml}
              </div>

              <!-- Nama Santri -->
              <div>
                <h3 class="text-[13px] font-black text-white leading-snug truncate drop-shadow-sm">${santri.nama}</h3>
              </div>

              <!-- Kotak Sisa Jatah Hari Ini -->
              <div class="bg-slate-950/65 backdrop-blur-md border border-white/15 rounded-2xl p-2.5 space-y-1.5">
                <div class="flex justify-between items-center text-[9px] text-slate-300 font-bold uppercase">
                  <span>Sisa Hari Ini</span>
                  <span class="font-mono-num text-cyan-300">${santri.jatahHarian / 1000}rb/hr</span>
                </div>
                <div class="text-sm font-black text-white font-mono-num tracking-tight">
                  ${formatRupiah(Math.max(0, sisaJatahHariIni))}
                </div>
                <div class="w-full h-1.5 bg-slate-900 rounded-full overflow-hidden">
                  <div class="h-full bg-gradient-to-r from-emerald-400 via-cyan-400 to-fuchsia-400 rounded-full transition-all" style="width: ${pct}%"></div>
                </div>
              </div>

              <!-- Jejak Pengambilan Pagi/Siang/Malam -->
              <div class="flex flex-wrap gap-1 min-h-[18px] items-center">
                ${pillsWaktuHtml}
              </div>

              <!-- Info Saldo & Badge Tunggakan -->
              <div class="pt-1.5 border-t border-white/15 space-y-1.5">
                <div class="flex justify-between items-center text-[10px]">
                  <span class="text-slate-300 font-semibold">Saldo:</span>
                  <span class="font-extrabold text-emerald-300 font-mono-num">${formatRupiah(santri.saldoTotal)}</span>
                </div>
                ${
                  nominalTunggakan > 0
                    ? `<div onclick="event.stopPropagation(); openTunggakanModal('${santri.id}')" class="bg-rose-500/25 hover:bg-rose-500/35 border border-rose-400/50 rounded-xl px-2 py-1 flex items-center justify-between text-[9px] font-extrabold text-rose-200 transition">
                        <span>🚨 Tunggakan</span>
                        <span class="font-mono-num">${formatRupiah(nominalTunggakan)}</span>
                      </div>`
                    : `<div onclick="event.stopPropagation(); openTunggakanModal('${santri.id}')" class="bg-white/5 hover:bg-white/10 border border-white/10 rounded-xl px-2 py-1 flex items-center justify-between text-[9px] font-semibold text-slate-300 transition">
                        <span>✅ Tunggakan</span>
                        <span class="font-mono-num">Rp 0</span>
                      </div>`
                }
              </div>

              <!-- Baris Tombol Aksi Bawah -->
              <div class="grid grid-cols-4 gap-1.5 pt-0.5">
                <button
                  type="button"
                  class="col-span-3 bg-gradient-to-r from-emerald-400 via-teal-400 to-cyan-400 text-slate-950 font-black text-[10px] py-2 rounded-2xl shadow-[0_4px_14px_rgba(16,185,129,0.4)] flex items-center justify-center gap-1"
                >
                  <span>⚡ Ambil Uang</span>
                </button>
                <button
                  type="button"
                  onclick="event.stopPropagation(); openTunggakanModal('${santri.id}')"
                  title="Kelola Tunggakan Santri"
                  class="bg-slate-950/75 hover:bg-rose-500/30 border border-white/20 text-rose-200 font-extrabold text-[10px] py-2 rounded-2xl flex items-center justify-center transition"
                >
                  🚨
                </button>
              </div>
            </div>
          `;
        }).join('');
        return;
      }

      // MODE 1 BARIS (LIST VIEW FALLBACK)
      container.innerHTML = filtered.map(santri => {
        const { sisaJatahHariIni, status } = getSantriTodayStats(santri);
        const initials = getInitials(santri.nama);
        const nominalTunggakan = santri.tunggakan || 0;
        const cardTheme = status === 'UTUH' ? 'card-theme-utuh' : status === 'SEBAGIAN' ? 'card-theme-sebagian' : status === 'HABIS' ? 'card-theme-habis' : 'card-theme-over';

        return `
          <div onclick="openAmbilModal('${santri.id}')" class="cursor-pointer santri-btn-card ${cardTheme} rounded-3xl p-3.5 flex items-center justify-between gap-3">
            <div class="flex items-center gap-3 min-w-0">
              <div class="w-10 h-10 rounded-2xl bg-gradient-to-br from-emerald-400 to-cyan-500 text-slate-950 font-black text-xs flex items-center justify-center shrink-0">
                ${initials}
              </div>
              <div class="min-w-0">
                <div class="flex items-center gap-1.5">
                  <h3 class="font-black text-white text-xs truncate">${santri.nama}</h3>
                  <span class="text-[9px] bg-black/40 border border-white/15 px-2 py-0.5 rounded-full text-slate-200 font-bold">${santri.kamar}</span>
                </div>
                <p class="text-[10px] text-slate-200 mt-0.5">
                  Sisa Hari Ini: <b class="text-emerald-300 font-mono-num">${formatRupiah(Math.max(0, sisaJatahHariIni))}</b> • Saldo: <span class="font-mono-num">${formatRupiah(santri.saldoTotal)}</span>
                </p>
                ${nominalTunggakan > 0 ? `<span onclick="event.stopPropagation(); openTunggakanModal('${santri.id}')" class="inline-block mt-1 text-[9px] bg-rose-500/30 border border-rose-400/50 text-rose-200 px-2 py-0.5 rounded-lg font-extrabold">🚨 Tunggakan: ${formatRupiah(nominalTunggakan)}</span>` : ''}
              </div>
            </div>
            <button type="button" class="bg-gradient-to-r from-emerald-400 to-cyan-400 text-slate-950 font-black text-[11px] px-3 py-2 rounded-xl shrink-0">
              ⚡ Ambil
            </button>
          </div>
        `;
      }).join('');
    }

    // =========================================================================
    // DROPDOWN & SETORAN BULANAN (FASE 3A)
    // =========================================================================
    function populateSelectDropdowns() {
      const setorSelect = document.getElementById('setorSantriSelect');
      const filterRiwayat = document.getElementById('filterRiwayatSantri');
      const waSelect = document.getElementById('waSantriSelect');

      const currentSetor = setorSelect ? setorSelect.value : '';
      const currentFilterSantri = filterRiwayat ? filterRiwayat.value : 'ALL';
      const currentWa = waSelect ? waSelect.value : '';

      const optionsHtml = state.santri
        .map(s => `<option value="${s.id}">${s.nama} (${s.kamar}) — Saldo: ${formatRupiah(s.saldoTotal)}</option>`)
        .join('');

      if (setorSelect) {
        setorSelect.innerHTML = optionsHtml;
        if (currentSetor && state.santri.some(s => s.id === currentSetor)) setorSelect.value = currentSetor;
      }

      if (filterRiwayat) {
        filterRiwayat.innerHTML = `<option value="ALL">Semua Santri</option>` +
          state.santri.map(s => `<option value="${s.id}">${s.nama} (${s.kamar})</option>`).join('');
        filterRiwayat.value = currentFilterSantri || 'ALL';
      }

      if (waSelect) {
        waSelect.innerHTML = state.santri
          .map(s => `<option value="${s.id}">${s.nama} (${s.kamar})</option>`)
          .join('');
        if (currentWa && state.santri.some(s => s.id === currentWa)) waSelect.value = currentWa;
      }
    }

    function setTipeSetoran(tipe) {
      tipeSetoran = tipe;
      const btnAwal = document.getElementById('btnTipeAwal');
      const btnSusulan = document.getElementById('btnTipeSusulan');
      if (tipe === 'AWAL_BULAN') {
        btnAwal.className = 'py-2.5 px-3 rounded-2xl text-xs font-bold border border-emerald-500/50 bg-emerald-500/15 text-emerald-300 transition';
        btnSusulan.className = 'py-2.5 px-3 rounded-2xl text-xs font-bold border border-white/10 bg-slate-950/60 text-slate-400 transition';
      } else {
        btnSusulan.className = 'py-2.5 px-3 rounded-2xl text-xs font-bold border border-emerald-500/50 bg-emerald-500/15 text-emerald-300 transition';
        btnAwal.className = 'py-2.5 px-3 rounded-2xl text-xs font-bold border border-white/10 bg-slate-950/60 text-slate-400 transition';
      }
    }

    function setQuickSetor(nominal, durasi) {
      document.getElementById('inputNominalSetor').value = nominal;
      document.getElementById('inputDurasiHari').value = durasi;
      hitungSimulasiJatah();
    }

    function hitungSimulasiJatah() {
      const nominal = parseInt(document.getElementById('inputNominalSetor').value || '0', 10);
      const durasi = Math.max(1, parseInt(document.getElementById('inputDurasiHari').value || '30', 10));
      const jatah = Math.round(nominal / durasi);
      document.getElementById('previewJatahHarian').textContent = `${formatRupiah(jatah)} / hari`;
    }

    function simpanSetoranBulanan() {
      const santriId = document.getElementById('setorSantriSelect').value;
      const santri = state.santri.find(s => s.id === santriId);
      if (!santri) return;

      const nominal = parseInt(document.getElementById('inputNominalSetor').value || '0', 10);
      const durasi = Math.max(1, parseInt(document.getElementById('inputDurasiHari').value || '30', 10));
      const catatan = document.getElementById('inputCatatanSetor').value.trim() || (tipeSetoran === 'AWAL_BULAN' ? 'Setoran Bulanan' : 'Top-Up Susulan');

      if (nominal <= 0) {
        showToast('Nominal setoran harus lebih dari Rp 0!', false);
        return;
      }

      const jatahBaru = Math.round(nominal / durasi);
      santri.saldoTotal += nominal;
      santri.jatahHarian = jatahBaru;

      const now = new Date();
      const newTx = {
        id: 'tx_' + Date.now(),
        santriId: santri.id,
        tipe: 'MASUK',
        nominal,
        tanggal: TODAY_STR,
        jam: now.toTimeString().slice(0, 5),
        kategoriWaktu: 'SETORAN',
        catatan,
        isOverlimit: false
      };

      state.transaksi.unshift(newTx);
      document.getElementById('inputCatatanSetor').value = '';
      saveState();
      showToast(`Setoran ${santri.nama} (${formatRupiah(nominal)}) berhasil disimpan!`, false);
      switchTab('home');
    }

    // =========================================================================
    // TAMBAH SANTRI BARU
    // =========================================================================
    function openAddSantriModal() {
      document.getElementById('newNamaSantri').value = '';
      document.getElementById('newKamarSantri').value = 'Kamar 1';
      document.getElementById('newSetoranSantri').value = 300000;
      document.getElementById('newJatahSantri').value = 10000;
      document.getElementById('newTunggakanSantri').value = 0;

      const modal = document.getElementById('addSantriModal');
      modal.classList.remove('hidden');
      modal.classList.add('flex');
    }

    function closeAddSantriModal() {
      const modal = document.getElementById('addSantriModal');
      modal.classList.add('hidden');
      modal.classList.remove('flex');
    }

    function simpanSantriBaru() {
      const nama = document.getElementById('newNamaSantri').value.trim();
      const kamar = document.getElementById('newKamarSantri').value.trim() || 'Kamar 1';
      const setoran = parseInt(document.getElementById('newSetoranSantri').value || '0', 10);
      const jatah = parseInt(document.getElementById('newJatahSantri').value || '10000', 10);
      const tunggakan = parseInt(document.getElementById('newTunggakanSantri').value || '0', 10);

      if (!nama) {
        showToast('Nama lengkap santri wajib diisi!', false);
        return;
      }

      const newSantri = {
        id: 's_' + Date.now(),
        nama,
        kamar,
        saldoTotal: Math.max(0, setoran),
        jatahHarian: Math.max(1000, jatah),
        setoranAwal: Math.max(0, setoran),
        tunggakan: Math.max(0, tunggakan),
        catatanTunggakan: tunggakan > 0 ? 'Tunggakan Awal' : ''
      };

      state.santri.unshift(newSantri);
      closeAddSantriModal();
      saveState();
      showToast(`Santri ${nama} berhasil ditambahkan!`, false);
    }

    // =========================================================================
    // RIWAYAT TRANSAKSI & PEMBATALAN (VOID / UNDO)
    // =========================================================================
    function renderRiwayatList() {
      const container = document.getElementById('riwayatListContainer');
      const filterSantri = document.getElementById('filterRiwayatSantri').value || 'ALL';
      const filterWaktu = document.getElementById('filterRiwayatWaktu').value || 'ALL';

      const list = state.transaksi.filter(t => {
        if (filterSantri !== 'ALL' && t.santriId !== filterSantri) return false;
        if (filterWaktu !== 'ALL' && t.kategoriWaktu !== filterWaktu) return false;
        return true;
      });

      document.getElementById('totalTransaksiCount').textContent = `${list.length} catatan`;

      if (list.length === 0) {
        container.innerHTML = `
          <div class="glass-card rounded-3xl p-6 text-center text-xs text-slate-400">
            Belum ada riwayat transaksi untuk filter ini.
          </div>
        `;
        return;
      }

      container.innerHTML = list.map(t => {
        const santri = state.santri.find(s => s.id === t.santriId);
        const namaSantri = santri ? santri.nama : 'Santri';
        const isMasuk = t.tipe === 'MASUK';

        return `
          <div class="glass-card rounded-2xl p-3 flex items-center justify-between gap-2.5">
            <div class="flex items-center gap-2.5 min-w-0">
              <div class="w-9 h-9 rounded-xl ${isMasuk ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-400/30' : 'bg-cyan-500/20 text-cyan-300 border border-cyan-400/30'} flex items-center justify-center text-sm shrink-0">
                ${isMasuk ? '📥' : '💸'}
              </div>
              <div class="min-w-0">
                <div class="flex items-center gap-1.5">
                  <span class="font-extrabold text-xs text-white truncate">${namaSantri}</span>
                  <span class="text-[9px] bg-white/10 px-1.5 py-0.5 rounded text-slate-300 font-bold">${t.kategoriWaktu}</span>
                </div>
                <p class="text-[10px] text-slate-400 truncate">${t.catatan} • ${t.jam}</p>
              </div>
            </div>
            <div class="text-right shrink-0">
              <span class="font-mono-num font-black text-xs ${isMasuk ? 'text-emerald-400' : 'text-amber-300'} block">
                ${isMasuk ? '+' : '-'}${formatRupiah(t.nominal)}
              </span>
              <button onclick="voidTransaction('${t.id}')" class="text-[9px] text-rose-400 hover:underline font-bold">
                Batalkan
              </button>
            </div>
          </div>
        `;
      }).join('');
    }

    function voidTransaction(txId) {
      const idx = state.transaksi.findIndex(t => t.id === txId);
      if (idx === -1) return;

      const tx = state.transaksi[idx];
      const santri = state.santri.find(s => s.id === tx.santriId);
      if (santri) {
        if (tx.tipe === 'KELUAR') {
          santri.saldoTotal += tx.nominal;
        } else {
          santri.saldoTotal = Math.max(0, santri.saldoTotal - tx.nominal);
        }
      }

      state.transaksi.splice(idx, 1);
      saveState();
      showToast('Transaksi dibatalkan & saldo dikembalikan.', false);
    }

    function undoLastTransaction() {
      if (!lastUndoTxId) return;
      voidTransaction(lastUndoTxId);
      lastUndoTxId = null;
      document.getElementById('toastBanner').classList.add('hidden');
    }

    // =========================================================================
    // REKAP & LAPORAN WHATSAPP WALI SANTRI (FASE 4)
    // =========================================================================
    function renderLaporanTab() {
      const txToday = state.transaksi.filter(t => t.tanggal === TODAY_STR && t.tipe === 'KELUAR');
      const pagiSiang = txToday
        .filter(t => t.kategoriWaktu === 'PAGI' || t.kategoriWaktu === 'SIANG')
        .reduce((a, b) => a + b.nominal, 0);
      const soreMalam = txToday
        .filter(t => t.kategoriWaktu === 'SORE' || t.kategoriWaktu === 'MALAM')
        .reduce((a, b) => a + b.nominal, 0);
      const totalBrankas = state.santri.reduce((a, s) => a + s.saldoTotal, 0);

      document.getElementById('rekapPagiSiang').textContent = formatRupiah(pagiSiang);
      document.getElementById('rekapSoreMalam').textContent = formatRupiah(soreMalam);
      document.getElementById('rekapBrankas').textContent = formatRupiah(totalBrankas);

      generateWaPreview();
    }

    function generateWaPreview() {
      const select = document.getElementById('waSantriSelect');
      if (!select || !select.value) return;

      const santri = state.santri.find(s => s.id === select.value);
      if (!santri) return;

      const { txToday, terpakaiHariIni, sisaJatahHariIni } = getSantriTodayStats(santri);
      const rincianList = txToday.length > 0
        ? txToday.map(t => `- ${t.kategoriWaktu} (${t.jam}): ${formatRupiah(t.nominal)} [${t.catatan}]`).join('\n')
        : '- Belum ada pengambilan uang hari ini';

      const infoTunggakan = (santri.tunggakan || 0) > 0
        ? `🚨 *Tunggakan:* ${formatRupiah(santri.tunggakan)} (${santri.catatanTunggakan || 'Aktif'})`
        : `✅ *Status Tunggakan:* Lunas / Tidak Ada Tunggakan`;

      const text =
`*LAPORAN KAS & UANG SAKU SANTRI*
*${state.settings.namaPondok || 'PPS MIFTAHUSSUNAN'}*
----------------------------------------
👦 *Nama Santri:* ${santri.nama} (${santri.kamar})
📅 *Tanggal:* ${TODAY_STR}

📊 *RINGKASAN HARI INI:*
• Kuota Jatah Harian: ${formatRupiah(santri.jatahHarian)}
• Terpakai Hari Ini: ${formatRupiah(terpakaiHariIni)}
• Sisa Jatah Hari Ini: ${formatRupiah(Math.max(0, sisaJatahHariIni))}

📝 *RINCIAN PENGAMBILAN HARI INI:*
${rincianList}

🏦 *Total Sisa Saldo Titipan:* ${formatRupiah(santri.saldoTotal)}
${infoTunggakan}
----------------------------------------
_Sistem Aplikasi Kas Santri — By Moch Khoirul Azman_`;

      document.getElementById('waTextPreview').value = text;
    }

    function copyWaReport() {
      const textarea = document.getElementById('waTextPreview');
      textarea.select();
      document.execCommand('copy');
      showToast('Laporan WhatsApp berhasil disalin ke papan klip!', false);
    }

    // =========================================================================
    // PENGATURAN, PIN LOCK, & BACKUP DATA (FASE 5)
    // =========================================================================
    function saveSettings() {
      state.settings.namaPondok = document.getElementById('settingNamaPondok').value.trim() || 'PPS MIFTAHUSSUNAN';
      state.settings.modeSisa = document.getElementById('settingModeSisa').value;
      saveState();
    }

    function exportDataJson() {
      const dataStr = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(state, null, 2));
      const a = document.createElement('a');
      a.setAttribute('href', dataStr);
      a.setAttribute('download', `backup_kas_santri_${TODAY_STR}.json`);
      document.body.appendChild(a);
      a.click();
      a.remove();
      showToast('File Backup JSON berhasil diunduh!', false);
    }

    function resetInitialDummyData() {
      state = JSON.parse(JSON.stringify(INITIAL_DATA));
      saveState();
      showToast('Data simulasi berhasil di-reset ke awal!', false);
    }

    function togglePinLock(show) {
      const overlay = document.getElementById('pinLockOverlay');
      if (show) {
        document.getElementById('pinInput').value = '';
        overlay.classList.remove('hidden');
        overlay.classList.add('flex');
      } else {
        overlay.classList.add('hidden');
        overlay.classList.remove('flex');
      }
    }

    function verifyPin() {
      const pin = document.getElementById('pinInput').value;
      if (pin === '1234') {
        togglePinLock(false);
        showToast('Brankas Kas Santri berhasil dibuka!', false);
      } else {
        showToast('PIN salah! Gunakan PIN simulasi: 1234', false);
      }
    }

    // =========================================================================
    // NAVIGASI TAB & TOAST NOTIFIKASI
    // =========================================================================
    function switchTab(tabName) {
      const tabs = ['home', 'setoran', 'riwayat', 'laporan', 'pengaturan'];
      tabs.forEach(t => {
        const el = document.getElementById(`tab-${t}`);
        if (el) {
          if (t === tabName) el.classList.remove('hidden');
          else el.classList.add('hidden');
        }
      });

      document.querySelectorAll('.nav-btn').forEach(btn => {
        if (btn.dataset.tab === tabName) {
          btn.className = 'nav-btn flex flex-col items-center gap-0.5 text-emerald-400 font-extrabold text-[10px] px-3 py-1 rounded-xl transition';
        } else {
          btn.className = 'nav-btn flex flex-col items-center gap-0.5 text-slate-400 font-semibold text-[10px] px-3 py-1 rounded-xl transition';
        }
      });

      refreshAllUI();
    }

    let toastTimeout = null;
    function showToast(message, allowUndo) {
      const banner = document.getElementById('toastBanner');
      const textEl = document.getElementById('toastText');
      const undoBtn = document.getElementById('toastUndoBtn');

      textEl.textContent = message;
      if (allowUndo) undoBtn.classList.remove('hidden');
      else undoBtn.classList.add('hidden');

      banner.classList.remove('hidden');
      banner.classList.add('flex');

      if (toastTimeout) clearTimeout(toastTimeout);
      toastTimeout = setTimeout(() => {
        banner.classList.add('hidden');
        banner.classList.remove('flex');
      }, 4000);
    }

    function updateClock() {
      const now = new Date();
      const timeStr = now.toTimeString().slice(0, 5);
      const clockEl = document.getElementById('clockDisplay');
      if (clockEl) {
        clockEl.textContent = `Senin, 23 Nov 2026 • ${timeStr}`;
      }
    }

    function refreshAllUI() {
      renderDashboardHeader();
      renderSantriList();
      populateSelectDropdowns();
      renderRiwayatList();
      renderLaporanTab();
      hitungSimulasiJatah();
    }

    window.onload = function() {
      updateClock();
      setInterval(updateClock, 30000);
      refreshAllUI();
    };
  </script>
</body>
</html>