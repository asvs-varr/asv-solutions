# 🌌 BANAAG STRATEGIC HORIZON VAULT
> **Repository of High-Value Product Ideas, Deferred Systems, and Architectural Upgrades**  
> *Locked and monitored via the `/horizon` skill command. These ideas are preserved to prevent loss while current situational constraints exist.*

---

## 📊 Horizon Status Matrix

| Category | Total Items | Primary Situational Constraint |
| :--- | :---: | :--- |
| **[STORE-BLOCKED]** | 2 | Google Play Console ($25) / Merchant Center verification |
| **[INFRA-BLOCKED]** | 4 | Dedicated Production Backend Server / Database / Live Market Price Feed |
| **[PARTNER-BLOCKED]** | 3 | Official B2B Supplier Agreements / Autodesk AutoCAD APIs |
| **[HARDWARE-BLOCKED]** | 2 | Physical Metering Instruments (Bluetooth Megger, Thermal Camera) |
| **[LEGAL-BLOCKED]** | 1 | PRC Accredited CPE / Official Meralco Utility Portal API |
| **[UX/PRODUCT-EXPANSION]** | 4 | Multi-Brand BOM Matrix, Homeowner Mode, Multi-Panel UI, Built-in PEC Codebook |
| **[ELECTRICAL-EXPANSION]** | 1 | Three-Phase Commercial & Industrial Systems (400V/230V Wye & 230V Delta) |

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
- **Status**: ⏳ ARCHITECTURE READY / UNBLOCKING IN PROGRESS
- **Blocker Category**: `[INFRA-BLOCKED]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Multi-electrician project sync)
- **Technical Effort**: High
- **Current Progress**:
  - ✅ Naisulat na ang kumpletong `supabase_schema.sql` na may PostgreSQL Row-Level Security (RLS) para sa multi-tenant contractor isolation.
  - ✅ Binuo ang `CloudSyncService` (`lib/data/cloud_sync_service.dart`) na may seamless offline-first fallback.
  - ✅ Naidagdag ang Supabase Project Credentials modal configuration sa `banaag_pro_screen.dart`.
- **Remaining Step to Full Graduation**:
  1. Gumawa ng Libreng Project sa Supabase Dashboard (https://supabase.com).
  2. I-paste at i-run ang `supabase_schema.sql` sa SQL Editor.
  3. Ilagay ang Project URL at Anon Key sa BANAAG PRO screen!
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

### [HRZ-011] Modular Client Needs Analysis & Smart PEC/IESNA Lighting Sizer
- **Status**: ✅ GRADUATED & LIVE IN PRODUCTION (v1.0.0)
- **Blocker Category**: `[UX/ENGINEERING-DEFERRED] (RESOLVED)`
- **Strategic / Business Impact**: 🏆 Game-Changer (Professional contractor UX, custom dwelling modeling, automated lumen estimation)
- **Technical Effort**: Medium
- **Implementation Status**:
  - ✅ **Sleek Vertical List View**: Pinalitan ang masikip na 2-column grid ng high-density compact ListTiles.
  - ✅ **Zero-Default Initial State**: Malinis na 0 kVA by default, walang unsolicited auto-inserted presets.
  - ✅ **Custom Space Creator**: May 1-tap `+ Add Space` para gumawa ng kahit anong kwarto (Dirty Kitchen, Balcony, Home Office) na may $m^2$ area at ceiling height.
  - ✅ **Custom Appliance Dialog**: Dynamic modal na tumatanggap ng Appliance Name, VA rating, at `[x] Dedicated Circuit` flag.
  - ✅ **Smart Lighting Engine (`lighting_engine.dart`)**: Awtomatikong nagko-compute ng target lumens at nagrerekomenda ng bilang ng 12W LED Downlights ayon sa PEC/IESNA standards na may 1-tap `+ Add Light` action.

---

### [HRZ-012] Dynamic Multi-Panel Distribution Riser & Subpanel Management (MDP -> Subpanels)
- **Status**: ✅ GRADUATED & LIVE IN UI (v1.1.0)
- **Blocker Category**: `[UX/ARCHITECTURAL-EXPANSION] (RESOLVED)`
- **Strategic / Business Impact**: 🏆 Game-Changer (Unlocks commercial buildings, multi-storey apartments, schools, hospitals)
- **Technical Effort**: Medium
- **Current Technical Progress**:
  - ✅ **Engine Verified**: Binuo ang `InstitutionalBuildingPreset` at `MultiPanelInstitutionalRiser` sa `lib/domain/institutional_building_presets.dart` na nagko-compute ng buong hierarchy (LP-1, LP-2, at Main Distribution Panel MDP na may feeder cables at 4-rod grounding grid).
  - ✅ **Dynamic UI Switcher**: Naka-mount na ang dynamic Panel Switcher Bar sa `SingleLineDiagramScreen` (`[MDP (Main)]`, `[Panel LP-1]`, `[Panel LP-2]`, `[+ Subpanel]`).
  - ✅ **Interactive Subpanel Creation**: May 1-tap dynamic modal para magdagdag ng bagong subpanels (tulad ng `LP-2`, `PP-ACU`, `Sub-1`) kung saan awtomatikong lumilikha ng sub-feeder breaker sa Main Panel alinsunod sa PEC 2017 Article 2.15 & 4.08.
  - ✅ **Persistence**: Naka-save ang dynamic `panelboards` list sa bawat `Project` record gamit ang JSON serialization.

---

### [HRZ-013] Three-Phase Commercial & Industrial Systems Engine (400V/230V Wye & 230V Delta)
- **Status**: ⏳ ARCHITECTURE READY / UNBLOCKING CANDIDATE
- **Blocker Category**: `[ELECTRICAL-EXPANSION]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Unlocks factories, warehouses, restaurants, 3-phase commercial fit-outs, and high-end residential estates)
- **Technical Effort**: Medium
- **Why It's Deferred Today**: Ang kasalukuyang BANAAG core engine (`pec_engine.dart`, `sld_engine.dart`) ay naka-optimize para sa Single-Phase 2-Wire 230V ($I = \text{VA}/230$, $V_d = 2LIR$).
- **Actionable Unblocking Steps**:
  1. Magdagdag ng `phaseConfiguration` field sa `Project` model (`1P_230V`, `3P_400V_WYE`, `3P_230V_DELTA`).
  2. I-update ang `PecEngine`:
     - Three-phase balanced current: $I = \frac{\text{VA}}{\sqrt{3} \times V_L}$
     - Three-phase voltage drop: $V_d = \sqrt{3} \times L \times I \times R$
  3. Palawakin ang Smart Phase Balancer mula dual-phase ($A, B$) patungong tri-phase ($A, B, C$) na may unbalance percentage checker ($<10\%$).
  4. Suportahan ang 3-pole & 4-pole main circuit breakers at 4-wire ($3\Phi + 1N + 1G$) feeder wire sizing sa Single-Line Diagram.

---

### [HRZ-014] Direct AutoCAD / Autodesk Cloud Companion & Native `.DWG` Sync Bridge
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[PARTNER-BLOCKED]`
- **Strategic / Business Impact**: High (Seamless Desktop-to-Mobile CAD workflow; suggested by *John Omar*)
- **Technical Effort**: High
- **Why It's Blocked Today**: Ang native `.DWG` ay proprietary binary format ng Autodesk at ang direct AutoCAD cloud/plugin browsing ay nangangailangan ng **Autodesk Platform Services (APS / Forge) Developer API** credentials o AutoCAD desktop LISP/plugin companion.
- **Actionable Unblocking Steps**:
  1. Mag-register sa Autodesk Platform Services (APS) free tier para sa `.DWG` to `.DXF`/`.SVG` cloud translation API, O
  2. Gumawa ng lightweight **BANAAG AutoCAD LISP / Desktop Sync Companion** na nag-a-auto-export ng active AutoCAD drawing diretso sa BANAAG mobile app via local Wi-Fi / QR code!
- **Detailed Architectural Notes**:
  - Sa kasalukuyan, kaya na ng BANAAG mag-import at mag-export ng open-standard `.DXF` files. Ang companion plugin o APS bridge ang mag-aalis ng manual "Save As DXF" step sa AutoCAD.

---

### [HRZ-015] Live Philippine Electrical Market Price Feed & Dynamic BOM Auto-Updater
- **Status**: 🧊 DEFERRED
- **Blocker Category**: `[INFRA-BLOCKED]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Ensures BOM estimates match volatile copper/THHN and PVC hardware prices; suggested by *John Omar*)
- **Technical Effort**: Medium
- **Why It's Blocked Today**: Nangangailangan ng remote cloud JSON/Supabase endpoint o periodic scraper/curator index na nag-a-update ng presyo ng THHN wires, uPVC conduits, at circuit breakers base sa kasalukuyang Philippine retail/wholesale market.
- **Actionable Unblocking Steps**:
  1. Mag-host ng `market_price_index.json` sa Supabase o GitHub Raw CDN na may regional multiplier (NCR, Luzon, Visayas, Mindanao) at copper price index.
  2. Maglagay ng **"🔄 Sync Latest Market Prices"** button sa BOM screen na may offline cached fallback at "Last Updated: [Date]" badge.
  3. Payagan din ang contractor na mag-save ng sarili nilang custom local hardware price overrides.

---

### [HRZ-016] Multi-Brand BOM Comparison Matrix ("Generic/Economy vs. Branded/Premium" + Brand Advantages)
- **Status**: ⏳ READY TO UNBLOCK (100% Offline-Capable UX Upgrade!)
- **Blocker Category**: `[UX/PRODUCT-EXPANSION]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Parang "Generic vs. Branded" sa gamot; sobrang bilis makapag-decide ni Client; suggested by *John Omar*)
- **Technical Effort**: Low-Medium
- **Why It's Deferred Today**: Walang external blocker! Maaari na itong i-code anumang oras sa loob ng `BomEngine` (`lib/domain/bom_engine.dart`) at Project Estimate / Proposal screen.
- **Actionable Unblocking Steps**:
  1. Magdagdag ng 3-Tier Brand Matrix sa `BomEngine`:
     - **Tier 1: Budget / Code-Minimum (PS/ICC Certified Economy)** — e.g., *Columbia / Philflex Basic*, *Royu / Omni*, *Moldflex PVC*.
     - **Tier 2: Contractor Standard (Balanced Reliability)** — e.g., *Phelps Dodge / Duraflex THHN*, *Koten / GE Breakers*, *20mm Thick-Wall Neltex/Emerald PVC*.
     - **Tier 3: Executive / Heavy-Duty Branded** — e.g., *Phelps Dodge Lead-Free + Heat-Guard*, *Schneider Electric / Square D / Mitsubishi Breakers*, *Panasonic Wide Series Devices*.
  2. Magpakita ng **Brand Advantage Cards** sa bawat item (hal. *"Phelps Dodge THHN: 99.99% Pure Electrolytic Copper, mas mababa ang init at voltage drop, 25+ yrs insulation lifespan vs ordinary wire"*).
  3. Hayaang makita ni Client ang side-by-side price difference at pumili ng tier bago i-export ang PDF Contract Proposal!

---

### [HRZ-017] Dual-Persona Mode ("Tatay / Homeowner Renovator" vs. "Pro Engineer") & Visual Electrical Glossary
- **Status**: ⏳ READY TO UNBLOCK (100% Offline-Capable UX Upgrade!)
- **Blocker Category**: `[UX/PRODUCT-EXPANSION]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Opens BANAAG to millions of Filipino homeowners & DIY renovators while keeping full PEC rigor for Engineers; suggested by *John Omar*)
- **Technical Effort**: Low-Medium
- **Why It's Deferred Today**: Walang external blocker! Maaari itong idagdag bilang toggleable mode at interactive reference guide sa loob ng app.
- **Actionable Unblocking Steps**:
  1. **Homeowner / Renovation Estimator Mode**:
     - Gumagamit ng madaling intindihin na Taglish guide (*"Ilang Aircon, Ilaw, at Saksakan ang idadagdag sa kwarto?"*) at nagbibigay agad ng **Budget Range (Materials + Labor Estimate)** at **Safety Checklist** nang hindi nakakalula ang engineering formulas.
  2. **Interactive Electrical Terminologies & Layman's Dictionary**:
     - Searchable Taglish glossary na may malinaw na paliwanag at larawan/halimbawa para sa:
       - **THHN / mm²** (*Kapal at klase ng tanso sa loob ng wire*)
       - **AT / Circuit Breaker** (*Automatic pamputol-kuryente kapag nag-overload o nag-short*)
       - **GFCI Outlet** (*Saksakan sa banyo/kusina na kusang namamatay sa loob ng milliseconds kapag nabasa para iwas-kuryente*)
       - **Dedicated Circuit / Home Run** (*Sariling linya ng kuryente diretso sa panelboard para sa malalakas kumain gaya ng Aircon at Water Heater*)
       - **Voltage Drop** (*Paghina ng boltahe kapag sobrang haba o sobrang nipis ng wire*)
       - **Conduit (PVC / EMT)** (*Tubong proteksyon ng wire sa loob ng pader o kisame*)

---

### [HRZ-018] Built-in 1,165-Page Verbatim PEC 2017 Knowledge Base, Offline FTS5 Codebook & AI/Rule Code Assistant ("Tanungan ng Bayan")
- **Status**: ⏳ READY TO UNBLOCK (100% Offline-Capable Feature!)
- **Blocker Category**: `[UX/PRODUCT-EXPANSION]`
- **Strategic / Business Impact**: 🏆 Game-Changer (Transforms BANAAG from an engineering tool into the Definitive Philippine Electrical Code Authority in every Electrician & Engineer's pocket)
- **Technical Effort**: Medium
- **Why It Was Deferred Initially**: Dati ay nakapokus tayo sa primary calculation tables ng `pec_engine.dart` (`Table 3.10.2.6(B)(16)`, `Sec. 2.40.1.4(D)`, Chapter 10 conduit tables). Ngayong nasa workspace na ang kumpletong 1,165-page `PEC Part 1 2017.pdf`, maaari na itong i-extract at i-index ng buo nang walang external dependency o API cost!
- **Actionable Unblocking Steps**:
  1. **Extraction & Indexing Pipeline**:
     - Gumamit ng Python extraction script para i-parse ang `PEC Part 1 2017.pdf` per Chapter (1 to 10), Article, Section, at Table.
     - I-compile ito sa isang lightweight offline **SQLite database na may Full-Text Search (FTS5)** o compressed JSON dictionary (~4MB hanggang 8MB lang ang bigat).
  2. **Dedicated "PEC 2017 Navigator & Codebook" Screen**:
     - Interactive Table of Contents na may search bar na sumasala ng keywords (e.g. "grounding rod", "conduit fill", "GFCI", "clearance").
     - Fast bookmarks at copy-citation button para sa field inspection reports sa LGU/OBO.
  3. **"Ask PEC" / In-App Rule Assistant ("Tanungan ng Bayan")**:
     - Search / Question bar na nagba-bracket ng inquiry (e.g. "Ilang mm² ang wire sa 30A?") at nagbibigay ng direct verbatim snippet + Table citation.
  4. **Contextual In-App Deep Links**:
     - Pag-tap sa kahit anong calculation card sa SLD o Calculator, may "📖 Read PEC Sec. X.XX.X" button na magbubukas ng verbatim code provision sa slide-over bottom sheet.
- **Detailed Architectural Notes**:
  - Walang internet o LLM token cost na kailangan. Lahat ay mabilis at gagana 100% offline sa liblib na construction site gamit ang SQLite FTS5 engine.

---

*Laging panatilihing updated ang file na ito gamit ang `/horizon` tuwing may bagong situational development o unblocked feature!*


