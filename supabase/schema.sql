-- ═══════════════════════════════════════════════════════════════
-- IET ESTIMATION TOOL — SUPABASE DATABASE SCHEMA
-- Paste this into Supabase → SQL Editor → New Query → Run
-- ═══════════════════════════════════════════════════════════════

-- ── REFERENCE TABLES (populated by CSV import) ─────────────────

CREATE TABLE IF NOT EXISTS wbs_master (
  wbs_code                 TEXT PRIMARY KEY,
  depth                    INTEGER NOT NULL,
  parent_wbs_code          TEXT,
  level_1                  TEXT,
  level_2                  TEXT,
  level_3                  TEXT,
  level_4                  TEXT,
  level_5                  TEXT,
  level_6                  TEXT,
  description              TEXT NOT NULL,
  scope                    TEXT,
  default_resource_type    TEXT,
  default_delivery_method  TEXT,
  uom_ee                   TEXT,
  uom_copperleaf           TEXT,
  crew_size                NUMERIC,
  hrs_per_person           NUMERIC,
  total_hrs_per_unit       NUMERIC,
  install_wbs_codes        TEXT,
  commission_wbs_codes     TEXT,
  is_active                BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS resource_rates (
  resource_name            TEXT PRIMARY KEY,
  ee_internal_rate         NUMERIC,
  commercial_rate          NUMERIC,
  aer_code                 TEXT,
  erp_code                 TEXT,
  copperleaf_code          TEXT,
  copperleaf_unit_type     TEXT,
  ans_margin_pct           NUMERIC,
  ans_margin_dollar        NUMERIC
);

CREATE TABLE IF NOT EXISTS burden_margin_rates (
  id                       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  rate_type                TEXT,
  investment_type          TEXT,
  rate_pct                 NUMERIC,
  rate_decimal             NUMERIC,
  notes                    TEXT
);

CREATE TABLE IF NOT EXISTS aer_rate_classification (
  aer_code                 TEXT PRIMARY KEY,
  commercial_rate_hr       NUMERIC,
  erp_code                 TEXT,
  notes                    TEXT
);

CREATE TABLE IF NOT EXISTS scope_links (
  link_id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  supply_wbs_code          TEXT NOT NULL,
  supply_description       TEXT,
  install_l4               TEXT,
  install_wbs_codes        TEXT,
  commission_l4            TEXT,
  commission_wbs_codes     TEXT
);

CREATE TABLE IF NOT EXISTS standard_hours (
  wbs_code                 TEXT PRIMARY KEY,
  description              TEXT,
  scope                    TEXT,
  crew_size                NUMERIC,
  hrs_per_person           NUMERIC,
  total_hrs_per_unit       NUMERIC,
  default_resource_type    TEXT
);

CREATE TABLE IF NOT EXISTS period_contract_equipment (
  id                       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  wbs_code                 TEXT,
  family_voltage           TEXT,
  category                 TEXT,
  contract_number          TEXT,
  oracle_contract_id       TEXT,
  contract_item_no         TEXT,
  item_description         TEXT,
  make                     TEXT,
  model                    TEXT,
  rating_description       TEXT,
  drawing_number           TEXT,
  current_price_aud        NUMERIC,
  lead_time_weeks          TEXT,
  is_llt                   TEXT,
  price_comments           TEXT,
  comments                 TEXT
);

-- ── PEOPLE (managed via WBS Manager) ──────────────────────────────
CREATE TABLE IF NOT EXISTS iet_people (
  id                       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  display_name             TEXT NOT NULL,
  email                    TEXT,
  role                     TEXT,
  team                     TEXT,
  can_review               BOOLEAN DEFAULT FALSE,
  is_active                BOOLEAN DEFAULT TRUE,
  notes                    TEXT
);

-- Insert default people (update with your real team)
INSERT INTO iet_people (display_name, email, role, team, can_review) VALUES
  ('Daniel Lawrence',  'daniel.lawrence@yourdomain.com.au',  'Lead Estimator',  'Zone Substation',  TRUE),
  ('Sarah Chen',       'sarah.chen@yourdomain.com.au',       'Estimator',       'Zone Substation',  FALSE),
  ('Mark Thompson',    'mark.thompson@yourdomain.com.au',    'Estimator',       'Subtransmission',  FALSE),
  ('Priya Nair',       'priya.nair@yourdomain.com.au',       'Senior Estimator','Zone Substation',  TRUE),
  ('Michael Santos',   'michael.santos@yourdomain.com.au',   'Lead Estimator',  'Commissioning',    TRUE),
  ('Emma Blackwood',   'emma.blackwood@yourdomain.com.au',   'Project Manager', 'Zone Substation',  TRUE)
ON CONFLICT DO NOTHING;

-- ── INVESTMENTS ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS investments (
  id                              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  investment_name                 TEXT NOT NULL,
  investment_number               TEXT,
  wacs_number                     TEXT,
  investment_type                 TEXT DEFAULT 'Commercially Funded',
  estimate_class                  TEXT DEFAULT 'Class 4',
  revision                        TEXT DEFAULT 'A',
  status                          TEXT DEFAULT 'Draft',
  complexity                      TEXT,
  new_technology                  TEXT,
  spend_profile_type              TEXT DEFAULT 'Default (Automatic)',
  estimated_by                    TEXT,
  reviewed_by                     TEXT,
  planning_start_month            DATE,
  planning_duration_months        INTEGER DEFAULT 4,
  design_start_month              INTEGER DEFAULT 1,
  design_duration_months          INTEGER DEFAULT 9,
  construction_start_month        INTEGER DEFAULT 6,
  construction_duration_months    INTEGER DEFAULT 15,
  llt_mode                        TEXT DEFAULT 'Manual',
  contingency_pct                 NUMERIC DEFAULT 0.001,
  -- Escalation rates by stream and FY
  esc_ee_fy26                     NUMERIC DEFAULT 0.045,
  esc_ee_fy27                     NUMERIC DEFAULT 0.038,
  esc_ee_fy28                     NUMERIC DEFAULT 0.035,
  esc_ee_fy29                     NUMERIC DEFAULT 0.035,
  esc_con_fy26                    NUMERIC DEFAULT 0.049,
  esc_con_fy27                    NUMERIC DEFAULT 0.045,
  esc_con_fy28                    NUMERIC DEFAULT 0.040,
  esc_con_fy29                    NUMERIC DEFAULT 0.035,
  esc_mat_fy26                    NUMERIC DEFAULT 0.049,
  esc_mat_fy27                    NUMERIC DEFAULT 0.040,
  esc_mat_fy28                    NUMERIC DEFAULT 0.040,
  esc_mat_fy29                    NUMERIC DEFAULT 0.040,
  -- Audit
  estimate_date                   DATE DEFAULT CURRENT_DATE,
  created_at                      TIMESTAMPTZ DEFAULT NOW(),
  updated_at                      TIMESTAMPTZ DEFAULT NOW()
);

-- ── ESTIMATE LINES ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS estimate_lines (
  id                         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  investment_id              BIGINT NOT NULL REFERENCES investments(id) ON DELETE CASCADE,
  wbs_code                   TEXT NOT NULL,
  quantity                   NUMERIC DEFAULT 0,
  factor_multiplier          NUMERIC DEFAULT 1,
  delivery_method            TEXT DEFAULT 'EE Delivered',
  install_hrs_override       NUMERIC,           -- null = use standard hours
  contractor_unit_rate       NUMERIC,
  plant_cost                 NUMERIC DEFAULT 0,
  materials_cost             NUMERIC DEFAULT 0,
  comments                   TEXT,
  -- Calculated fields (stored for fast reporting)
  ee_labour_hours            NUMERIC DEFAULT 0,
  install_hours_total        NUMERIC DEFAULT 0,
  commission_hours_total     NUMERIC DEFAULT 0,
  ee_internal_total          NUMERIC DEFAULT 0,
  commercial_total           NUMERIC DEFAULT 0,
  -- Audit
  entered_at                 TIMESTAMPTZ DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ DEFAULT NOW(),
  -- Unique constraint: one line per WBS item per investment
  UNIQUE (investment_id, wbs_code)
);

-- ── INDEXES for performance ────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_wbs_parent         ON wbs_master (parent_wbs_code);
CREATE INDEX IF NOT EXISTS idx_wbs_depth          ON wbs_master (depth);
CREATE INDEX IF NOT EXISTS idx_wbs_scope          ON wbs_master (scope);
CREATE INDEX IF NOT EXISTS idx_wbs_level1         ON wbs_master (level_1);
CREATE INDEX IF NOT EXISTS idx_scope_links_supply ON scope_links (supply_wbs_code);
CREATE INDEX IF NOT EXISTS idx_est_lines_inv      ON estimate_lines (investment_id);
CREATE INDEX IF NOT EXISTS idx_est_lines_wbs      ON estimate_lines (wbs_code);
CREATE INDEX IF NOT EXISTS idx_pce_wbs            ON period_contract_equipment (wbs_code);

-- ── ROW LEVEL SECURITY (enable for production) ─────────────────────
-- By default, Supabase allows all operations with the anon key.
-- For a demo this is fine. Before going to production, enable RLS:
--
-- ALTER TABLE investments ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE estimate_lines ENABLE ROW LEVEL SECURITY;
-- -- Then add policies to restrict who can read/write each row.
-- -- See: supabase.com/docs/guides/database/row-level-security

-- ── UPDATED_AT TRIGGER ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER investments_updated_at
  BEFORE UPDATE ON investments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER estimate_lines_updated_at
  BEFORE UPDATE ON estimate_lines
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
