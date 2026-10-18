CREATE OR REPLACE VIEW quality_checks AS

-- 1. Invoice total equals the sum of its lines (exact, DECIMAL arithmetic)
SELECT
    'invoice_total_matches_lines'                      AS check_name,
    count(*) FILTER (WHERE i.total <> l.lines_total)   AS failed_rows,
    count(*)                                           AS checked_rows
FROM stg_invoice AS i
JOIN (
    SELECT invoice_id, sum(line_total) AS lines_total
    FROM stg_invoice_line
    GROUP BY invoice_id
) AS l USING (invoice_id)

UNION ALL
-- 2. Every invoice has at least one line 
SELECT
    'invoice_has_lines',
    count(*) FILTER (WHERE l.invoice_id IS NULL),
    count(*)
FROM stg_invoice AS i
LEFT JOIN (SELECT DISTINCT invoice_id FROM stg_invoice_line) AS l USING (invoice_id)

UNION ALL
-- 3. Every invoice line points to an existing invoice
SELECT
    'line_has_invoice',
    count(*) FILTER (WHERE i.invoice_id IS NULL),
    count(*)
FROM stg_invoice_line AS l
LEFT JOIN stg_invoice AS i USING (invoice_id)

UNION ALL
-- 4. Every invoice line points to an existing track
SELECT
    'line_has_track',
    count(*) FILTER (WHERE t.track_id IS NULL),
    count(*)
FROM stg_invoice_line AS l
LEFT JOIN stg_track AS t USING (track_id)

UNION ALL
-- 5. Every invoice belongs to an existing customer
SELECT
    'invoice_has_customer',
    count(*) FILTER (WHERE c.CustomerId IS NULL),
    count(*)
FROM stg_invoice AS i
LEFT JOIN raw_customer AS c ON c.CustomerId = i.customer_id

UNION ALL
-- 6. Every track has a genre
SELECT
    'track_has_genre',
    count(*) FILTER (WHERE genre_name IS NULL),
    count(*)
FROM stg_track

UNION ALL
-- 7. Primary keys are unique: invoice_id
SELECT
    'invoice_id_unique',
    count(*) - count(DISTINCT invoice_id),
    count(*)
FROM stg_invoice

UNION ALL
-- 8. Primary keys are unique: invoice_line_id
SELECT
    'invoice_line_id_unique',
    count(*) - count(DISTINCT invoice_line_id),
    count(*)
FROM stg_invoice_line

UNION ALL
-- 9. Primary keys are unique: track_id
SELECT
    'track_id_unique',
    count(*) - count(DISTINCT track_id),
    count(*)
FROM stg_track

UNION ALL
-- 10. Invoice date is present and not in the future
SELECT
    'invoice_date_valid',
    count(*) FILTER (WHERE invoice_ts IS NULL OR invoice_ts > current_timestamp),
    count(*)
FROM stg_invoice

UNION ALL
-- 11. Amounts are positive: unit price, quantity and invoice total
SELECT
    'amounts_positive',
    count(*) FILTER (WHERE unit_price <= 0 OR quantity <= 0),
    count(*)
FROM stg_invoice_line

UNION ALL
SELECT
    'invoice_total_positive',
    count(*) FILTER (WHERE total <= 0),
    count(*)
FROM stg_invoice

UNION ALL
-- 12. Billing country is filled in
SELECT
    'invoice_has_country',
    count(*) FILTER (WHERE billing_country IS NULL OR trim(billing_country) = ''),
    count(*)
FROM stg_invoice;


-- Readable summary: adds pass/fail status and the failure rate.
CREATE OR REPLACE VIEW quality_report AS
SELECT
    check_name,
    failed_rows,
    checked_rows,
    round(100.0 * failed_rows / nullif(checked_rows, 0), 2) AS failed_pct,
    CASE WHEN failed_rows = 0 THEN 'pass' ELSE 'FAIL' END   AS status
FROM quality_checks;