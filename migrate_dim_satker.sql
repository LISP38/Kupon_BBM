-- 1. Remove duplicate satker names (case-insensitive, trim)
DELETE FROM dim_satker
WHERE satker_id NOT IN (
  SELECT MIN(satker_id)
  FROM dim_satker
  GROUP BY LOWER(TRIM(nama_satker))
);

-- 2. Rename old table
ALTER TABLE dim_satker RENAME TO dim_satker_old;

-- 3. Create new table with UNIQUE constraint
CREATE TABLE dim_satker (
  satker_id INTEGER PRIMARY KEY,
  nama_satker TEXT NOT NULL UNIQUE
);

-- 4. Copy data back
INSERT INTO dim_satker (satker_id, nama_satker)
SELECT satker_id, nama_satker FROM dim_satker_old;

-- 5. Drop old table
DROP TABLE dim_satker_old;
