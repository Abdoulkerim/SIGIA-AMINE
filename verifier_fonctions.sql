
SELECT
    p.proname AS fonction,
    CASE
        WHEN p.proname = 'create_purchase_order'
            THEN pg_get_functiondef(p.oid) LIKE '%v_total%'
        WHEN p.proname = 'receive_purchase_order'
            THEN pg_get_functiondef(p.oid) LIKE '%v_order_status%'
        WHEN p.proname = 'complete_stock_transfer'
            THEN pg_get_functiondef(p.oid) LIKE '%v_transfer_status%'
        WHEN p.proname = 'pay_purchase_invoice'
            THEN pg_get_functiondef(p.oid) LIKE '%v_invoice_status%'
    END AS correction_presente
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
      'create_purchase_order',
      'receive_purchase_order',
      'complete_stock_transfer',
      'pay_purchase_invoice'
  )
ORDER BY p.proname;
