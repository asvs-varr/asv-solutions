# 🌌 BANAAG STRATEGIC HORIZON VAULT
> **Repository of High-Value Product Ideas, Deferred Systems, and Architectural Upgrades**  
> *Locked and monitored via the `/horizon` skill command. These ideas are preserved to prevent loss while current situational constraints exist.*

---

## 📊 Horizon Status Matrix

| Category | Total Items | Primary Situational Constraint |
| :--- | :---: | :--- |
| **[STORE-BLOCKED]** | 2 | Google Play Console ($25) / Merchant Center verification |
| **[INFRA-BLOCKED]** | 3 | Dedicated Production Backend Server / Database / Cloud Auth |
| **[PARTNER-BLOCKED]** | 2 | Official B2B Supplier Agreements / Hardware APIs |
| **[HARDWARE-BLOCKED]** | 2 | Physical Metering Instruments (Bluetooth Megger, Thermal Camera) |
| **[LEGAL-BLOCKED]** | 1 | PRC Accredited CPE / Official Meralco Utility Portal API |

---

## 🧊 Vault Catalog of Deferred Items

### [HRZ-001] Google Play Integrity API & Anti-Tamper Attestation
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[STORE-BLOCKED]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Ultimate Android Anti-MOD Shield)
- **Technical Effort**: Medium
- **Why It's Blocked Today**: Nangangailangan ng aktibong **Google Play Console Account** ($25 fee) at naka-link na Google Cloud Project na may Play Integrity API enabled. Hindi ma-test ang attestation verdict sa sideloaded debug APKs nang walang Play Console setup.
- **Actionable Unblocking Steps**:
  1. Magparehistro sa Google Play Console gamit ang opisyal na Google account ng BANAAG.
  2. I-link ang app SHA-256 fingerprint sa Google Cloud Console credentials.
  3. I-integrate ang official `play_integrity` client call sa app startup.
- **Detailed Architectural Notes**:
  - Tumatanggap ng Play Integrity token mula sa Google servers.
  - Ibe-verify ng backend kung `MEETS_STRONG_INTEGRITY` (hindi rooted, official Play Store install, uncompromised binary).

---

### [HRZ-002] Live Google Play In-App Billing (IAP) & Subscription Flow
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[STORE-BLOCKED]`
- **Strategic / Business Impact**: High (Direct PRO monetization)
- **Technical Effort**: Medium
- **Why It's Blocked Today**: Walang live Google Merchant account para mag-process ng peso transactions (₱499/mo o ₱3,499/yr para sa Cosmetic & Prestige PRO).
- **Actionable Unblocking Steps**:
  1. I-setup ang Google Play Merchant profile at mag-submit ng tax/banking information sa Pilipinas.
  2. Gumawa ng SKU identifiers sa Play Console (`banaag_pro_monthly`, `banaag_pro_annual`).
  3. I-integrate ang package na `in_app_purchase` sa Flutter.
- **Detailed Architectural Notes**:
  - Matapos makumpirma ang purchase token mula sa Google Play, ipadadala ito sa remote backend upang mag-isyu ng cryptographically signed 30-day offline lease token.

---

### [HRZ-003] Multi-Device Cloud Sync & Realtime Team Collaboration
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[INFRA-BLOCKED]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Multi-electrician project sync)
- **Technical Effort**: High
- **Why It's Blocked Today**: Wala pa tayong naka-deploy na live backend (e.g. Supabase instance, Firebase Blaze, o custom PostgreSQL backend). Kasalukuyang local-first at stream-based cache pa lang ang repository.
- **Actionable Unblocking Steps**:
  1. Mag-deploy ng Supabase Project (PostgreSQL + PostGIS para sa project coordinates + Auth).
  2. Gumawa ng row-level security (RLS) tables para sa `projects`, `takeoffs`, `variation_orders`, at `photos`.
  3. I-integrate ang `supabase_flutter` na may offline-first local queue (PowerSync / WatermelonDB pattern).
- **Detailed Architectural Notes**:
  - Pag-aralan ang Conflict-Free Replicated Data Types (CRDTs) para sa sabay-sabay na pag-audit ng dalawang electrician sa parehong gusali nang walang overwrite.

---

### [HRZ-004] End-to-End Encrypted Pre-Cover Rough-In Photo Vault (S3 / R2 Bucket)
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[INFRA-BLOCKED]`
- **Strategic / Business Impact**: High (Legal protection laban sa backjob claims)
- **Technical Effort**: Medium
- **Why It's Blocked Today**: Nangangailangan ng cloud object storage bucket (e.g. Cloudflare R2 / AWS S3) para mag-store ng high-resolution photo audits nang hindi napupuno ang internal storage ng phone.
- **Actionable Unblocking Steps**:
  1. Mag-setup ng Cloudflare R2 bucket (zero egress fees) o Supabase Storage.
  2. Maglagay ng automated image compression (WebP) bago mag-upload.
  3. I-stamp ang GPS coordinates, timestamp, at project ID sa EXIF metadata ng litrato.
- **Detailed Architectural Notes**:
  - Bawat rough-in photo ay dapat i-hash (SHA-256) upang magsilbing immutable proof of compliance sakaling magkaroon ng sunog o kasuhan.

---

### [HRZ-005] Remote License Verification Backend & Revocation Webhook
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[INFRA-BLOCKED]`
- **Strategic / Business Impact**: High (Zero-trust central kill-switch para sa refunded/chargebacked licenses)
- **Technical Effort**: Low
- **Why It's Blocked Today**: Ang ating `SecurityEngine` ay may complete cryptographic verification logic na, pero lokal pa lang na bumubuo ng token para sa testing dahil walang remote server endpoint.
- **Actionable Unblocking Steps**:
  1. Mag-host ng lightweight Node.js/Go backend o Cloudflare Worker.
  2. Itago ang Ed25519 Private Key sa server-side environment variables.
  3. Magbigay ng `/api/v1/license/renew` endpoint para sa silent 30-day lease extension.

---

### [HRZ-006] Direct 1-Click B2B Hardware Supplier RFQ Integration (Wilcon / CW / Local Coops)
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[PARTNER-BLOCKED]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Core B2B Monetization Engine - 1% to 3% material rebate)
- **Technical Effort**: High
- **Why It's Blocked Today**: Walang opisyal na corporate partnership, B2B wholesale API, o electronic purchase order integration sa mga local hardware chains (e.g., Wilcon Depot, CW Home Depot, regional electrical supply hubs).
- **Actionable Unblocking Steps**:
  1. Mag-prepare ng BANAAG B2B Pitch Deck na nagpapakita ng active contractor BOM volume.
  2. Makipag-ugnayan sa B2B Sales / Corporate Accounts division ng hardware chains.
  3. Bilang interim solution (semi-automated): I-export ang BOM bilang standardized Excel/PDF Purchase Order na may 1-tap "Share to Hardware Sales Rep via Viber/Email".
- **Detailed Architectural Notes**:
  - Mag-generate ng dynamic affiliate tracking code sa bawat order para ma-attribute ang commission pabalik sa BANAAG.

---

### [HRZ-007] Verified Manufacturer Material Shield & Anti-Counterfeit Verification
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[PARTNER-BLOCKED]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Safety + Manufacturer Listing Sponsorships)
- **Technical Effort**: Medium
- **Why It's Blocked Today**: Nangangailangan ng pakikipag-ugnayan sa mga electrical manufacturers (Phelps Dodge Philippines, Schneider Electric, Royu/Omni, Panasonic) para sa kanilang QR verification endpoints o serial registries.
- **Actionable Unblocking Steps**:
  1. Sumulat sa marketing/technical support ng Phelps Dodge o Royu ukol sa integration ng kanilang genuine product verification seals.
  2. Magdisenyo ng in-app camera scanner na nagba-validate ng manufacturer security holograms / QR codes sa wire spools bago maglatag sa conduit.

---

### [HRZ-008] Bluetooth Smart Clamp & Megger BLE Direct Telemetry Link
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[HARDWARE-BLOCKED]`
- **Strategic / Business Impact**: High (Automated PEC Commissioning & Megger Logs)
- **Technical Effort**: High
- **Why It's Blocked Today**: Nangangailangan ng physical Bluetooth-enabled digital clamp meter o insulation resistance tester (e.g. Fluke Connect / Uni-T Bluetooth) para mag-capture at mag-decode ng proprietary BLE GATT telemetry packets.
- **Actionable Unblocking Steps**:
  1. Mag-acquire ng affordable BLE clamp meter (e.g. Uni-T UT210E / UT139C with Bluetooth adapter).
  2. I-integrate ang package na `flutter_blue_plus`.
  3. Gumawa ng BLE protocol parser para sa live ampere, voltage drop, at insulation mega-ohm readings.
- **Detailed Architectural Notes**:
  - Kapag nag-test ng insulation resistance bago i-energize ang panelboard, 1-tap capture ng mega-ohm reading diretso sa Certificate of Final Electrical Inspection (CFEI) checklist nang walang manual typing!

---

### [HRZ-009] Thermal Camera & Flir One Infrared Hotspot Inspection Module
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[HARDWARE-BLOCKED]`
- **Strategic / Business Impact**: High (Preventive Maintenance & Commercial Audits)
- **Technical Effort**: High
- **Why It's Blocked Today**: Walang pisikal na mobile thermal camera dongle (e.g. FLIR ONE Pro o Seek Thermal) para subukan ang thermal image parsing sa main distribution panel.
- **Actionable Unblocking Steps**:
  1. Kumuha ng test unit o sample thermal imaging files mula sa partner electrical consultant.
  2. Magpatupad ng temperature threshold flagging (>75°C terminal lugs) batay sa PEC Table 3.10.2.6 temperature limitations.

---

### [HRZ-010] Meralco Net-Metering & OBO E-Permit Direct Submission Bridge
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[LEGAL-BLOCKED]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Zero-friction utility & building official approvals)
- **Technical Effort**: Massive
- **Why It's Blocked Today**: Ang mga LGU Office of the Building Official (OBO) at Distribution Utilities (Meralco, CANORECO, Davao Light) ay may kani-kanilang hiwalay na manual o legacy web portals at walang public REST API para sa third-party apps.
- **Actionable Unblocking Steps**:
  1. I-standardize ang output ng BANAAG para sa CFEI at Net-Metering applications sa eksaktong format na hinihingi ng Meralco at Department of Energy (DOE).
  2. Bumuo ng automated browser script / PDF form filler na pumupuno sa official Meralco Net-Metering checklist.
- **Detailed Architectural Notes**:
  - Matapos mapuno ang Solar PV calculator sa BANAAG, 1-click export ng kumpletong Annex forms (Distribution Impact Study request, Inverter Test Certs) para ipasa sa engineering office.

---

*Laging panatilihing updated ang file na ito gamit ang `/horizon` tuwing may bagong situational development o unblocked feature!*
