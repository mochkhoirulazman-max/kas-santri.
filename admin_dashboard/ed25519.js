/**
 * Kas-Santri Ed25519 + RFC 4648 Base32 Pure-JS Engine (RFC 8032 Compliant)
 * Kompatibel 100% byte-for-byte dengan:
 * - lib/services/license_service.dart (cryptography ^2.7.0 Ed25519)
 * - tool/generate_keypair.dart
 *
 * Bekerja offline penuh (termasuk file://) menggunakan native JS BigInt tanpa CDN luar.
 */
(function (root) {
  'use strict';

  const MASK64 = 0xffffffffffffffffn;
  const K512 = [
    0x428a2f98d728ae22n, 0x7137449123ef65cdn, 0xb5c0fbcfec4d3b2fn, 0xe9b5dba58189dbbcn,
    0x3956c25bf348b538n, 0x59f111f1b605d019n, 0x923f82a4af194f9bn, 0xab1c5ed5da6d8118n,
    0xd807aa98a3030242n, 0x12835b0145706fben, 0x243185be4ee4b28cn, 0x550c7dc3d5ffb4e2n,
    0x72be5d74f27b896fn, 0x80deb1fe3b1696b1n, 0x9bdc06a725c71235n, 0xc19bf174cf692694n,
    0xe49b69c19ef14ad2n, 0xefbe4786384f25e3n, 0x0fc19dc68b8cd5b5n, 0x240ca1cc77ac9c65n,
    0x2de92c6f592b0275n, 0x4a7484aa6ea6e483n, 0x5cb0a9dcbd41fbd4n, 0x76f988da831153b5n,
    0x983e5152ee66dfabn, 0xa831c66d2db43210n, 0xb00327c898fb213fn, 0xbf597fc7beef0ee4n,
    0xc6e00bf33da88fc2n, 0xd5a79147930aa725n, 0x06ca6351e003826fn, 0x142929670a0e6e70n,
    0x27b70a8546d22ffcn, 0x2e1b21385c26c926n, 0x4d2c6dfc5ac42aedn, 0x53380d139d95b3dfn,
    0x650a73548baf63den, 0x766a0abb3c77b2a8n, 0x81c2c92e47edaee6n, 0x92722c851482353bn,
    0xa2bfe8a14cf10364n, 0xa81a664bbc423001n, 0xc24b8b70d0f89791n, 0xc76c51a30654be30n,
    0xd192e819d6ef5218n, 0xd69906245565a910n, 0xf40e35855771202an, 0x106aa07032bbd1b8n,
    0x19a4c116b8d2d0c8n, 0x1e376c085141ab53n, 0x2748774cdf8eeb99n, 0x34b0bcb5e19b48a8n,
    0x391c0cb3c5c95a63n, 0x4ed8aa4ae3418acbn, 0x5b9cca4f7763e373n, 0x682e6ff3d6b2b8a3n,
    0x748f82ee5defb2fcn, 0x78a5636f43172f60n, 0x84c87814a1f0ab72n, 0x8cc702081a6439ecn,
    0x90befffa23631e28n, 0xa4506cebde82bde9n, 0xbef9a3f7b2c67915n, 0xc67178f2e372532bn,
    0xca273eceea26619cn, 0xd186b8c721c0c207n, 0xeada7dd6cde0eb1en, 0xf57d4f7fee6ed178n,
    0x06f067aa72176fban, 0x0a637dc5a2c898a6n, 0x113f9804bef90daen, 0x1b710b35131c471bn,
    0x28db77f523047d84n, 0x32caab7b40c72493n, 0x3c9ebe0a15c9bebcn, 0x431d67c49c100d4cn,
    0x4cc5d4becb3e42b6n, 0x597f299cfc657e2an, 0x5fcb6fab3ad6faecn, 0x6c44198c4a475817n,
  ];
  const H0_512 = [
    0x6a09e667f3bcc908n, 0xbb67ae8584caa73bn, 0x3c6ef372fe94f82bn, 0xa54ff53a5f1d36f1n,
    0x510e527fade682d1n, 0x9b05688c2b3e6c1fn, 0x1f83d9abfb41bd6bn, 0x5be0cd19137e2179n,
  ];

  function rotr64(x, n) {
    return ((x >> BigInt(n)) | (x << BigInt(64 - n))) & MASK64;
  }

  function sha512(bytes) {
    const msg = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    const bitLen = BigInt(msg.length) * 8n;
    const rem = (msg.length + 17) % 128;
    const padZero = rem === 0 ? 0 : 128 - rem;
    const padded = new Uint8Array(msg.length + 1 + padZero + 16);
    padded.set(msg, 0);
    padded[msg.length] = 0x80;
    const dv = new DataView(padded.buffer);
    dv.setBigUint64(padded.length - 8, bitLen & MASK64, false);
    dv.setBigUint64(padded.length - 16, bitLen >> 64n, false);

    const H = H0_512.slice();
    const W = new Array(80);

    for (let off = 0; off < padded.length; off += 128) {
      for (let i = 0; i < 16; i++) {
        W[i] = dv.getBigUint64(off + i * 8, false);
      }
      for (let i = 16; i < 80; i++) {
        const s0 = rotr64(W[i - 15], 1) ^ rotr64(W[i - 15], 8) ^ (W[i - 15] >> 7n);
        const s1 = rotr64(W[i - 2], 19) ^ rotr64(W[i - 2], 61) ^ (W[i - 2] >> 6n);
        W[i] = (W[i - 16] + s0 + W[i - 7] + s1) & MASK64;
      }

      let [a, b, c, d, e, f, g, h] = H;
      for (let i = 0; i < 80; i++) {
        const S1 = rotr64(e, 14) ^ rotr64(e, 18) ^ rotr64(e, 41);
        const ch = (e & f) ^ ((~e & MASK64) & g);
        const temp1 = (h + S1 + ch + K512[i] + W[i]) & MASK64;
        const S0 = rotr64(a, 28) ^ rotr64(a, 34) ^ rotr64(a, 39);
        const maj = (a & b) ^ (a & c) ^ (b & c);
        const temp2 = (S0 + maj) & MASK64;
        h = g;
        g = f;
        f = e;
        e = (d + temp1) & MASK64;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & MASK64;
      }

      H[0] = (H[0] + a) & MASK64;
      H[1] = (H[1] + b) & MASK64;
      H[2] = (H[2] + c) & MASK64;
      H[3] = (H[3] + d) & MASK64;
      H[4] = (H[4] + e) & MASK64;
      H[5] = (H[5] + f) & MASK64;
      H[6] = (H[6] + g) & MASK64;
      H[7] = (H[7] + h) & MASK64;
    }

    const out = new Uint8Array(64);
    const outDv = new DataView(out.buffer);
    for (let i = 0; i < 8; i++) {
      outDv.setBigUint64(i * 8, H[i], false);
    }
    return out;
  }

  // Curve Ed25519 constants
  const P = (1n << 255n) - 19n;
  const L = (1n << 252n) + 27742317777372353535851937790883648493n;

  function mod(a, m) {
    const r = a % m;
    return r >= 0n ? r : r + m;
  }

  function powMod(base, exp, m) {
    let result = 1n;
    let b = mod(base, m);
    let e = exp;
    while (e > 0n) {
      if (e & 1n) result = (result * b) % m;
      e >>= 1n;
      b = (b * b) % m;
    }
    return result;
  }

  function modInv(a, m) {
    return powMod(a, m - 2n, m);
  }

  const D = mod(-121665n * modInv(121666n, P), P);
  const D2 = mod(2n * D, P);
  const SQRT_M1 = powMod(2n, (P - 1n) / 4n, P);
  const BY = mod(4n * modInv(5n, P), P);
  const BX = 15112221349535400772501151409588531511454012693041857206046113283949847762202n;
  const BASE = [BX, BY, 1n, mod(BX * BY, P)];
  const NEUTRAL = [0n, 1n, 1n, 0n];

  function pointAdd(p1, p2) {
    const [X1, Y1, Z1, T1] = p1;
    const [X2, Y2, Z2, T2] = p2;
    const A = mod((Y1 - X1) * (Y2 - X2), P);
    const B = mod((Y1 + X1) * (Y2 + X2), P);
    const C = mod(T1 * D2 * T2, P);
    const D4 = mod(2n * Z1 * Z2, P);
    const E = mod(B - A, P);
    const F = mod(D4 - C, P);
    const G = mod(D4 + C, P);
    const H = mod(B + A, P);
    return [
      mod(E * F, P),
      mod(G * H, P),
      mod(F * G, P),
      mod(E * H, P),
    ];
  }

  function pointMul(pt, scalar) {
    let Q = NEUTRAL;
    let N = pt;
    let k = scalar;
    while (k > 0n) {
      if (k & 1n) Q = pointAdd(Q, N);
      N = pointAdd(N, N);
      k >>= 1n;
    }
    return Q;
  }

  function bytesToLeBigInt(bytes) {
    let res = 0n;
    for (let i = bytes.length - 1; i >= 0; i--) {
      res = (res << 8n) | BigInt(bytes[i]);
    }
    return res;
  }

  function bigIntToLe32(num) {
    const out = new Uint8Array(32);
    let n = num;
    for (let i = 0; i < 32; i++) {
      out[i] = Number(n & 0xffn);
      n >>= 8n;
    }
    return out;
  }

  function encodePoint(pt) {
    const zInv = modInv(pt[2], P);
    const x = mod(pt[0] * zInv, P);
    const y = mod(pt[1] * zInv, P);
    const out = bigIntToLe32(y);
    if (x & 1n) out[31] |= 0x80;
    return out;
  }

  function decodePoint(bytes) {
    if (!bytes || bytes.length !== 32) return null;
    const copy = new Uint8Array(bytes);
    const signX = (copy[31] >> 7) & 1;
    copy[31] &= 0x7f;
    const y = bytesToLeBigInt(copy);
    if (y >= P) return null;

    const y2 = mod(y * y, P);
    const u = mod(y2 - 1n, P);
    const v = mod(D * y2 + 1n, P);
    const v3 = mod(v * v * v, P);
    const v7 = mod(v3 * v3 * v, P);
    let x = mod(u * v3 * powMod(mod(u * v7, P), (P - 5n) / 8n, P), P);

    const check = mod(v * x * x, P);
    if (check !== u) {
      if (check === mod(-u, P)) {
        x = mod(x * SQRT_M1, P);
      } else {
        return null;
      }
    }
    if (x === 0n && signX === 1) return null;
    if ((x & 1n) !== BigInt(signX)) {
      x = mod(P - x, P);
    }
    return [x, y, 1n, mod(x * y, P)];
  }

  function pointsEqual(p1, p2) {
    const lhsX = mod(p1[0] * p2[2], P);
    const rhsX = mod(p2[0] * p1[2], P);
    const lhsY = mod(p1[1] * p2[2], P);
    const rhsY = mod(p2[1] * p1[2], P);
    return lhsX === rhsX && lhsY === rhsY;
  }

  function concatBytes(...arrays) {
    const total = arrays.reduce((sum, a) => sum + a.length, 0);
    const out = new Uint8Array(total);
    let offset = 0;
    for (const a of arrays) {
      out.set(a, offset);
      offset += a.length;
    }
    return out;
  }

  function clampScalar(seed32) {
    const h = sha512(seed32);
    const a = h.slice(0, 32);
    a[0] &= 248;
    a[31] &= 127;
    a[31] |= 64;
    return {
      scalar: bytesToLeBigInt(a),
      prefix: h.slice(32, 64),
    };
  }

  function publicKeyFromSeed(seedBytes) {
    if (!seedBytes || seedBytes.length !== 32) {
      throw new Error('Ed25519 private seed harus tepat 32 byte.');
    }
    const { scalar } = clampScalar(seedBytes);
    return encodePoint(pointMul(BASE, scalar));
  }

  function signMessage(messageBytes, seedBytes) {
    if (!seedBytes || seedBytes.length !== 32) {
      throw new Error('Ed25519 private seed harus tepat 32 byte.');
    }
    const msg = messageBytes instanceof Uint8Array ? messageBytes : new Uint8Array(messageBytes);
    const { scalar, prefix } = clampScalar(seedBytes);
    const pubKeyBytes = encodePoint(pointMul(BASE, scalar));
    const r = bytesToLeBigInt(sha512(concatBytes(prefix, msg))) % L;
    const RBytes = encodePoint(pointMul(BASE, r));
    const k = bytesToLeBigInt(sha512(concatBytes(RBytes, pubKeyBytes, msg))) % L;
    const S = (r + k * scalar) % L;
    return concatBytes(RBytes, bigIntToLe32(S));
  }

  function verifySignature(messageBytes, sigBytes, pubKeyBytes) {
    if (!sigBytes || sigBytes.length !== 64) return false;
    if (!pubKeyBytes || pubKeyBytes.length !== 32) return false;
    const msg = messageBytes instanceof Uint8Array ? messageBytes : new Uint8Array(messageBytes);
    const RBytes = sigBytes.slice(0, 32);
    const S = bytesToLeBigInt(sigBytes.slice(32, 64));
    if (S >= L) return false;

    const A = decodePoint(pubKeyBytes);
    const R = decodePoint(RBytes);
    if (!A || !R) return false;

    const k = bytesToLeBigInt(sha512(concatBytes(RBytes, pubKeyBytes, msg))) % L;
    const lhs = pointMul(BASE, (8n * S) % L);
    const rhs = pointAdd(pointMul(R, 8n), pointMul(A, (8n * k) % L));
    return pointsEqual(lhs, rhs);
  }

  // Base64 helpers (Node + Browser safe)
  function bytesToBase64(bytes) {
    if (typeof Buffer !== 'undefined' && typeof btoa === 'undefined') {
      return Buffer.from(bytes).toString('base64');
    }
    let bin = '';
    for (let i = 0; i < bytes.length; i++) {
      bin += String.fromCharCode(bytes[i]);
    }
    return btoa(bin);
  }

  function base64ToBytes(b64) {
    const clean = String(b64 || '').trim();
    if (typeof Buffer !== 'undefined' && typeof atob === 'undefined') {
      return new Uint8Array(Buffer.from(clean, 'base64'));
    }
    const bin = atob(clean);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) {
      out[i] = bin.charCodeAt(i);
    }
    return out;
  }

  // RFC 4648 Base32 (tanpa padding, identik dengan LicenseService & tool/generate_keypair.dart)
  const B32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  function encodeBase32(bytes) {
    if (!bytes || bytes.length === 0) return '';
    let out = '';
    let buffer = 0;
    let bitsLeft = 0;
    for (let i = 0; i < bytes.length; i++) {
      buffer = (buffer << 8) | (bytes[i] & 0xff);
      bitsLeft += 8;
      while (bitsLeft >= 5) {
        const index = (buffer >> (bitsLeft - 5)) & 0x1f;
        bitsLeft -= 5;
        out += B32_ALPHABET[index];
      }
    }
    if (bitsLeft > 0) {
      const index = (buffer << (5 - bitsLeft)) & 0x1f;
      out += B32_ALPHABET[index];
    }
    return out;
  }

  function decodeBase32(str) {
    const clean = String(str || '').trim().toUpperCase().replace(/=+$/, '');
    const bytes = [];
    let buffer = 0;
    let bitsLeft = 0;
    for (let i = 0; i < clean.length; i++) {
      const idx = B32_ALPHABET.indexOf(clean[i]);
      if (idx < 0) {
        throw new Error('Karakter Base32 tidak valid: ' + clean[i]);
      }
      buffer = (buffer << 5) | idx;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bytes.push((buffer >> (bitsLeft - 8)) & 0xff);
        bitsLeft -= 8;
      }
    }
    return new Uint8Array(bytes);
  }

  function randomSeed32() {
    const seed = new Uint8Array(32);
    if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
      crypto.getRandomValues(seed);
      return seed;
    }
    if (typeof require === 'function') {
      const nodeCrypto = require('crypto');
      return new Uint8Array(nodeCrypto.randomBytes(32));
    }
    throw new Error('CSPRNG tidak tersedia.');
  }

  function generateKeyPair() {
    const seed = randomSeed32();
    const pub = publicKeyFromSeed(seed);
    return {
      seedBase64: bytesToBase64(seed),
      publicKeyBase64: bytesToBase64(pub),
    };
  }

  function publicKeyFromSeedBase64(seedBase64) {
    const seed = base64ToBytes(seedBase64);
    const pub = publicKeyFromSeed(seed);
    return bytesToBase64(pub);
  }

  function utf8Encode(str) {
    if (typeof TextEncoder !== 'undefined') {
      return new TextEncoder().encode(str);
    }
    return new Uint8Array(Buffer.from(str, 'utf8'));
  }

  function generateLicenseCode({ seedBase64, deviceId, tier, expiryEpochSec }) {
    const cleanDevice = String(deviceId || '').trim().toUpperCase().replace(/\|/g, '');
    const cleanTier = String(tier || 'YEARLY').trim().toUpperCase();
    if (!cleanDevice || cleanDevice.length < 4) {
      throw new Error('Device ID tidak valid.');
    }
    if (!['MONTHLY', 'YEARLY', 'LIFETIME'].includes(cleanTier)) {
      throw new Error('Tier lisensi harus MONTHLY, YEARLY, atau LIFETIME.');
    }
    const epoch = cleanTier === 'LIFETIME' ? 0 : Number(expiryEpochSec || 0);
    if (cleanTier !== 'LIFETIME' && (!Number.isFinite(epoch) || epoch <= 0)) {
      throw new Error('ExpiryEpochSec harus bernilai timestamp detik valid.');
    }

    const seedBytes = base64ToBytes(seedBase64);
    const pubBytes = publicKeyFromSeed(seedBytes);
    const payloadString = `${cleanDevice}|${cleanTier}|${Math.floor(epoch)}`;
    const payloadBytes = utf8Encode(payloadString);
    const sigBytes = signMessage(payloadBytes, seedBytes);
    const verified = verifySignature(payloadBytes, sigBytes, pubBytes);
    if (!verified) {
      throw new Error('Verifikasi internal tanda tangan Ed25519 gagal.');
    }

    const code = `KSPRO-${encodeBase32(payloadBytes)}-${encodeBase32(sigBytes)}`;
    return {
      code,
      payloadString,
      publicKeyBase64: bytesToBase64(pubBytes),
      verified,
    };
  }

  function verifyLicenseCode({ code, publicKeyBase64 }) {
    const clean = String(code || '').trim().toUpperCase().replace(/\s+/g, '');
    const parts = clean.split('-');
    if (parts.length !== 3 || parts[0] !== 'KSPRO') {
      return { valid: false, error: 'Format kode bukan KSPRO-<PAYLOAD>-<SIG>' };
    }
    const payloadBytes = decodeBase32(parts[1]);
    const sigBytes = decodeBase32(parts[2]);
    const pubBytes = base64ToBytes(publicKeyBase64);
    const valid = verifySignature(payloadBytes, sigBytes, pubBytes);
    const payloadString = typeof TextDecoder !== 'undefined'
      ? new TextDecoder().decode(payloadBytes)
      : Buffer.from(payloadBytes).toString('utf8');
    return { valid, payloadString };
  }

  function hexToBytes(hex) {
    const out = new Uint8Array(hex.length / 2);
    for (let i = 0; i < out.length; i++) {
      out[i] = parseInt(hex.substr(i * 2, 2), 16);
    }
    return out;
  }

  /**
   * RFC 8032 Section 7.1 TEST 1 verification:
   * Private Seed: 9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60
   * Expected Public Key: d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a
   * Base64: 11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=
   */
  function runSelfTest() {
    const rfcSeedHex = '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60';
    const expectedPubB64 = '11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=';
    const seed = hexToBytes(rfcSeedHex);
    const pubB64 = bytesToBase64(publicKeyFromSeed(seed));
    const gen = generateLicenseCode({
      seedBase64: bytesToBase64(seed),
      deviceId: 'KS-TEST1234',
      tier: 'YEARLY',
      expiryEpochSec: 1893456000,
    });
    const checked = verifyLicenseCode({
      code: gen.code,
      publicKeyBase64: pubB64,
    });
    const ok = pubB64 === expectedPubB64 && gen.verified && checked.valid;
    return {
      ok,
      pubB64,
      expectedPubB64,
      sampleCode: gen.code,
      payloadString: checked.payloadString,
    };
  }

  const api = {
    generateKeyPair,
    publicKeyFromSeedBase64,
    signMessage,
    verifySignature,
    encodeBase32,
    decodeBase32,
    generateLicenseCode,
    verifyLicenseCode,
    runSelfTest,
    sha512,
  };

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = api;
  }
  root.KasSantriEd25519 = api;
})(typeof window !== 'undefined' ? window : globalThis);
