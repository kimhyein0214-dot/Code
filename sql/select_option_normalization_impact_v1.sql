/*
  Option normalization impact SELECT draft.

  Purpose:
  - Diagnose whether option-name normalization can reduce Smartstore,
    MakeShop, and Ably manual review candidates.
  - Keep dictionary rules inside CTE VALUES.
  - Return summary counts by default.

  Safety:
  - SELECT-only.
  - Read-only.
  - No file output.
  - No temporary relation.
  - Diagnostic only; not an auto-confirm script.
*/

WITH review_channels AS (
  SELECT *
  FROM (
    VALUES
      ('smartstore'::text),
      ('makeshop'::text),
      ('ably'::text)
  ) AS c(source_channel)
),

normalization_dictionary AS (
  SELECT *
  FROM (
    VALUES
      ('color'::text, 'rose_gold'::text, '핑크골드'::text, 'contains'::text),
      ('color'::text, 'rose_gold'::text, '로즈골드'::text, 'contains'::text),
      ('color'::text, 'rose_gold'::text, 'rose gold'::text, 'contains'::text),
      ('color'::text, 'rose_gold'::text, 'RG'::text, 'token'::text),
      ('color'::text, 'yellow_gold'::text, '옐로우골드'::text, 'contains'::text),
      ('color'::text, 'yellow_gold'::text, '골드'::text, 'contains'::text),
      ('color'::text, 'yellow_gold'::text, 'yellow gold'::text, 'contains'::text),
      ('color'::text, 'yellow_gold'::text, 'YG'::text, 'token'::text),
      ('color'::text, 'silver'::text, '실버'::text, 'contains'::text),
      ('color'::text, 'silver'::text, '은색'::text, 'contains'::text),
      ('color'::text, 'silver'::text, 'silver'::text, 'contains'::text),
      ('color'::text, 'silver'::text, 'SV'::text, 'token'::text),
      ('color'::text, 'black'::text, '블랙'::text, 'contains'::text),
      ('color'::text, 'black'::text, '검정'::text, 'contains'::text),
      ('color'::text, 'black'::text, 'black'::text, 'contains'::text),
      ('color'::text, 'black'::text, 'BK'::text, 'token'::text),
      ('color'::text, 'white'::text, '화이트'::text, 'contains'::text),
      ('color'::text, 'white'::text, '흰색'::text, 'contains'::text),
      ('color'::text, 'white'::text, 'white'::text, 'contains'::text),
      ('color'::text, 'white'::text, 'WH'::text, 'token'::text),
      ('color'::text, 'clear'::text, '투명'::text, 'contains'::text),
      ('color'::text, 'clear'::text, '클리어'::text, 'contains'::text),
      ('color'::text, 'clear'::text, 'clear'::text, 'contains'::text),
      ('color'::text, 'crystal_ab'::text, '크리스탈AB'::text, 'contains'::text),
      ('color'::text, 'crystal_ab'::text, 'crystal AB'::text, 'contains'::text),
      ('color'::text, 'crystal_ab'::text, 'AB'::text, 'token'::text),
      ('color'::text, 'crystal_ab'::text, '오로라'::text, 'contains'::text),
      ('color'::text, 'crystal_ab'::text, 'aurora'::text, 'contains'::text),
      ('color'::text, 'crystal'::text, '크리스탈'::text, 'contains'::text),
      ('color'::text, 'crystal'::text, 'crystal'::text, 'contains'::text),
      ('color'::text, 'purple'::text, '바이올렛'::text, 'contains'::text),
      ('color'::text, 'purple'::text, '퍼플'::text, 'contains'::text),
      ('color'::text, 'purple'::text, '보라'::text, 'contains'::text),
      ('color'::text, 'purple'::text, 'purple'::text, 'contains'::text),
      ('color'::text, 'red'::text, '레드'::text, 'contains'::text),
      ('color'::text, 'red'::text, '빨강'::text, 'contains'::text),
      ('color'::text, 'red'::text, 'red'::text, 'contains'::text),
      ('color'::text, 'blue'::text, '블루'::text, 'contains'::text),
      ('color'::text, 'blue'::text, '파랑'::text, 'contains'::text),
      ('color'::text, 'blue'::text, 'blue'::text, 'contains'::text),
      ('color'::text, 'green'::text, '그린'::text, 'contains'::text),
      ('color'::text, 'green'::text, '초록'::text, 'contains'::text),
      ('color'::text, 'green'::text, 'green'::text, 'contains'::text),
      ('color'::text, 'ivory'::text, '아이보리'::text, 'contains'::text),
      ('color'::text, 'ivory'::text, 'ivory'::text, 'contains'::text),
      ('color'::text, 'brown'::text, '브라운'::text, 'contains'::text),
      ('color'::text, 'brown'::text, 'brown'::text, 'contains'::text),
      ('material'::text, 'surgical'::text, '써지컬'::text, 'contains'::text),
      ('material'::text, 'surgical'::text, '써지컬스틸'::text, 'contains'::text),
      ('material'::text, 'surgical'::text, 'surgical'::text, 'contains'::text),
      ('material'::text, 'surgical'::text, 'steel'::text, 'contains'::text),
      ('material'::text, '925_silver'::text, '925실버'::text, 'contains'::text),
      ('material'::text, '925_silver'::text, '실버925'::text, 'contains'::text),
      ('material'::text, '925_silver'::text, 'sterling silver'::text, 'contains'::text),
      ('material'::text, '14k'::text, '14K'::text, 'contains'::text),
      ('material'::text, '14k'::text, '14k골드'::text, 'contains'::text),
      ('material'::text, '14k'::text, 'gold 14k'::text, 'contains'::text),
      ('material'::text, 'acrylic'::text, '아크릴'::text, 'contains'::text),
      ('material'::text, 'acrylic'::text, 'acrylic'::text, 'contains'::text),
      ('material'::text, 'mother_of_pearl'::text, '자개'::text, 'contains'::text),
      ('material'::text, 'mother_of_pearl'::text, 'mother of pearl'::text, 'contains'::text),
      ('material'::text, 'mother_of_pearl'::text, 'mop'::text, 'token'::text),
      ('size'::text, 'xs'::text, 'XS'::text, 'token'::text),
      ('size'::text, 'xs'::text, '엑스스몰'::text, 'contains'::text),
      ('size'::text, 'xs'::text, 'extra small'::text, 'contains'::text),
      ('size'::text, 'small'::text, 'S'::text, 'token'::text),
      ('size'::text, 'small'::text, '스몰'::text, 'contains'::text),
      ('size'::text, 'small'::text, 'small'::text, 'contains'::text),
      ('size'::text, 'medium'::text, 'M'::text, 'token'::text),
      ('size'::text, 'medium'::text, '미디움'::text, 'contains'::text),
      ('size'::text, 'medium'::text, 'medium'::text, 'contains'::text),
      ('size'::text, 'large'::text, 'L'::text, 'token'::text),
      ('size'::text, 'large'::text, '라지'::text, 'contains'::text),
      ('size'::text, 'large'::text, 'large'::text, 'contains'::text),
      ('size'::text, 'xl'::text, 'XL'::text, 'token'::text),
      ('size'::text, 'xl'::text, '엑스라지'::text, 'contains'::text),
      ('size'::text, 'xl'::text, 'extra large'::text, 'contains'::text),
      ('size'::text, '6mm'::text, '6mm바'::text, 'contains'::text),
      ('size'::text, '6mm'::text, '6mm'::text, 'contains'::text),
      ('size'::text, '8mm'::text, '8mm바'::text, 'contains'::text),
      ('size'::text, '8mm'::text, '8mm'::text, 'contains'::text),
      ('quantity'::text, 'one_type'::text, '원타입'::text, 'contains'::text),
      ('quantity'::text, 'one_type'::text, '단일옵션'::text, 'contains'::text),
      ('quantity'::text, 'one_type'::text, 'one size'::text, 'contains'::text),
      ('quantity'::text, 'single'::text, '낱개'::text, 'contains'::text),
      ('quantity'::text, 'single'::text, '1개'::text, 'contains'::text),
      ('quantity'::text, 'single'::text, 'single'::text, 'contains'::text),
      ('quantity'::text, 'pair'::text, '한쌍'::text, 'contains'::text),
      ('quantity'::text, 'pair'::text, '2개'::text, 'contains'::text),
      ('quantity'::text, 'pair'::text, 'pair'::text, 'contains'::text),
      ('quantity'::text, 'set'::text, '세트'::text, 'contains'::text),
      ('quantity'::text, 'set'::text, 'set'::text, 'contains'::text),
      ('shape'::text, 'heart'::text, '하트'::text, 'contains'::text),
      ('shape'::text, 'heart'::text, 'heart'::text, 'contains'::text),
      ('shape'::text, 'flower'::text, '플라워'::text, 'contains'::text),
      ('shape'::text, 'flower'::text, '꽃'::text, 'contains'::text),
      ('shape'::text, 'flower'::text, 'flower'::text, 'contains'::text),
      ('shape'::text, 'star'::text, '스타'::text, 'contains'::text),
      ('shape'::text, 'star'::text, '별'::text, 'contains'::text),
      ('shape'::text, 'star'::text, 'star'::text, 'contains'::text),
      ('shape'::text, 'butterfly'::text, '나비'::text, 'contains'::text),
      ('shape'::text, 'butterfly'::text, 'butterfly'::text, 'contains'::text),
      ('shape'::text, 'cross'::text, '크로스'::text, 'contains'::text),
      ('shape'::text, 'cross'::text, '십자가'::text, 'contains'::text),
      ('shape'::text, 'cross'::text, 'cross'::text, 'contains'::text)
  ) AS d(normalization_category, normalization_rule, term, match_mode)
),

dictionary_keys AS (
  SELECT
    normalization_category,
    normalization_rule,
    term,
    match_mode,
    lower(term) AS term_lower,
    regexp_replace(lower(term), '[^[:alnum:]가-힣]+', '', 'g') AS term_compact
  FROM normalization_dictionary
),

base_sku AS (
  SELECT
    v.sku_id,
    v.product_id,
    v.selfpia_sku_code,
    v.selfpia_product_code,
    v.selfpia_option_no,
    v.product_name,
    v.option_value
  FROM product_code.v_sku_canonical AS v
),

own_sku_alias AS (
  SELECT
    ca.target_id AS sku_id,
    MIN(ca.code_value) AS own_sku_code
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system = 'own_sku'
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),

smartstore_alias AS (
  SELECT
    ca.target_id AS sku_id,
    MIN(ca.code_value) FILTER (WHERE ca.code_system = 'smartstore_product_no_candidate') AS smartstore_candidate_product_no,
    MIN(ca.code_value) FILTER (WHERE ca.code_system = 'smartstore_option_no_candidate') AS smartstore_candidate_option_no,
    MIN(ca.code_value) FILTER (WHERE ca.code_system = 'smartstore_product_no') AS smartstore_product_no,
    MIN(ca.code_value) FILTER (WHERE ca.code_system = 'smartstore_option_no') AS smartstore_option_no
  FROM product_code.code_alias AS ca
  WHERE ca.target_type = 'SKU'
    AND ca.code_system IN (
      'smartstore_product_no_candidate',
      'smartstore_option_no_candidate',
      'smartstore_product_no',
      'smartstore_option_no'
    )
    AND NULLIF(btrim(ca.code_value), '') IS NOT NULL
  GROUP BY ca.target_id
),

channel_mapping AS (
  SELECT DISTINCT ON (lower(scm.channel_code), scm.sku_id)
    lower(scm.channel_code) AS source_channel,
    scm.sku_id,
    scm.seller_product_code,
    scm.channel_sku_code,
    scm.own_sku_code,
    scm.is_primary,
    scm.raw_payload
  FROM product_code.sku_channel_mapping AS scm
  WHERE lower(scm.channel_code) IN (
    SELECT source_channel FROM review_channels
  )
  ORDER BY
    lower(scm.channel_code),
    scm.sku_id,
    scm.is_primary DESC,
    scm.channel_sku_code,
    scm.seller_product_code
),

review_candidates AS (
  SELECT
    rc.source_channel,
    bs.sku_id,
    bs.product_id,
    bs.selfpia_sku_code,
    bs.selfpia_product_code,
    bs.selfpia_option_no,
    bs.product_name,
    bs.option_value,
    COALESCE(cm.own_sku_code, osa.own_sku_code) AS own_sku_code,
    COALESCE(
      cm.seller_product_code,
      CASE WHEN rc.source_channel = 'smartstore' THEN sa.smartstore_product_no END
    ) AS seller_product_code,
    COALESCE(
      cm.channel_sku_code,
      CASE WHEN rc.source_channel = 'smartstore' THEN sa.smartstore_option_no END
    ) AS channel_sku_code,
    CASE WHEN rc.source_channel = 'smartstore'
      THEN sa.smartstore_candidate_product_no
      ELSE cm.seller_product_code
    END AS candidate_product_no,
    CASE WHEN rc.source_channel = 'smartstore'
      THEN sa.smartstore_candidate_option_no
      ELSE cm.channel_sku_code
    END AS candidate_option_no,
    COALESCE(
      NULLIF(cm.raw_payload ->> 'option_value', ''),
      NULLIF(cm.raw_payload ->> 'option_name', ''),
      NULLIF(cm.raw_payload ->> 'optionName', ''),
      NULLIF(cm.raw_payload ->> 'option_text', ''),
      NULLIF(cm.raw_payload ->> 'optionText', ''),
      NULLIF(cm.raw_payload ->> 'channel_option_name', ''),
      NULLIF(cm.raw_payload ->> 'channelOptionName', ''),
      NULLIF(cm.raw_payload ->> 'sku_option_name', ''),
      NULLIF(cm.raw_payload ->> 'skuOptionName', ''),
      NULLIF(cm.raw_payload ->> 'product_option', ''),
      NULLIF(cm.raw_payload ->> 'productOption', ''),
      cm.channel_sku_code
    ) AS channel_option_value
  FROM review_channels AS rc
  JOIN base_sku AS bs
    ON true
  LEFT JOIN channel_mapping AS cm
    ON cm.source_channel = rc.source_channel
   AND cm.sku_id = bs.sku_id
  LEFT JOIN own_sku_alias AS osa
    ON osa.sku_id = bs.sku_id
  LEFT JOIN smartstore_alias AS sa
    ON sa.sku_id = bs.sku_id
),

text_keys AS (
  SELECT
    rc.*,
    lower(COALESCE(rc.option_value, '')) AS base_text_lower,
    lower(COALESCE(rc.channel_option_value, '')) AS channel_text_lower,
    regexp_replace(lower(COALESCE(rc.option_value, '')), '[^[:alnum:]가-힣]+', '', 'g') AS base_text_compact,
    regexp_replace(lower(COALESCE(rc.channel_option_value, '')), '[^[:alnum:]가-힣]+', '', 'g') AS channel_text_compact,
    regexp_split_to_array(
      regexp_replace(lower(COALESCE(rc.option_value, '')), '[^[:alnum:]가-힣]+', ' ', 'g'),
      '\s+'
    ) AS base_tokens,
    regexp_split_to_array(
      regexp_replace(lower(COALESCE(rc.channel_option_value, '')), '[^[:alnum:]가-힣]+', ' ', 'g'),
      '\s+'
    ) AS channel_tokens
  FROM review_candidates AS rc
),

normalized_options AS (
  SELECT
    tk.*,
    base_rule.normalization_category AS base_normalization_category,
    base_rule.normalization_rule AS base_normalization_rule,
    channel_rule.normalization_category AS channel_normalization_category,
    channel_rule.normalization_rule AS channel_normalization_rule,
    COALESCE(base_rule.normalization_rule, NULLIF(tk.base_text_compact, '')) AS normalized_option_value,
    COALESCE(channel_rule.normalization_rule, NULLIF(tk.channel_text_compact, '')) AS normalized_channel_option_value
  FROM text_keys AS tk
  LEFT JOIN LATERAL (
    SELECT
      dk.normalization_category,
      dk.normalization_rule
    FROM dictionary_keys AS dk
    WHERE (
        dk.match_mode = 'contains'
        AND tk.base_text_compact LIKE '%' || dk.term_compact || '%'
      )
      OR (
        dk.match_mode = 'token'
        AND dk.term_lower = ANY(tk.base_tokens)
      )
    ORDER BY
      CASE WHEN dk.normalization_rule = 'crystal_ab' THEN 0 ELSE 1 END,
      length(dk.term_compact) DESC,
      dk.normalization_rule
    LIMIT 1
  ) AS base_rule
    ON true
  LEFT JOIN LATERAL (
    SELECT
      dk.normalization_category,
      dk.normalization_rule
    FROM dictionary_keys AS dk
    WHERE (
        dk.match_mode = 'contains'
        AND tk.channel_text_compact LIKE '%' || dk.term_compact || '%'
      )
      OR (
        dk.match_mode = 'token'
        AND dk.term_lower = ANY(tk.channel_tokens)
      )
    ORDER BY
      CASE WHEN dk.normalization_rule = 'crystal_ab' THEN 0 ELSE 1 END,
      length(dk.term_compact) DESC,
      dk.normalization_rule
    LIMIT 1
  ) AS channel_rule
    ON true
),

impact_base AS (
  SELECT
    no.source_channel,
    no.sku_id,
    no.product_id,
    no.selfpia_sku_code,
    no.selfpia_product_code,
    no.selfpia_option_no,
    no.product_name,
    no.option_value,
    no.channel_option_value,
    no.normalized_option_value,
    no.normalized_channel_option_value,
    COALESCE(no.base_normalization_category, no.channel_normalization_category, 'raw_text') AS normalization_category,
    CASE
      WHEN no.base_normalization_rule IS NOT NULL THEN no.base_normalization_rule
      WHEN no.channel_normalization_rule IS NOT NULL THEN no.channel_normalization_rule
      ELSE 'raw_text'
    END AS normalization_rule,
    no.seller_product_code,
    no.channel_sku_code,
    no.own_sku_code,
    no.candidate_product_no,
    no.candidate_option_no,
    (
      no.base_text_compact <> ''
      AND no.base_text_compact = no.channel_text_compact
    ) AS before_exact_match,
    (
      no.normalized_option_value IS NOT NULL
      AND no.normalized_option_value = no.normalized_channel_option_value
    ) AS after_normalized_match,
    (
      ('ab' = ANY(no.base_tokens) OR 'ab' = ANY(no.channel_tokens))
      AND no.base_text_compact !~ '(crystalab|크리스탈ab|오로라|aurora)'
      AND no.channel_text_compact !~ '(crystalab|크리스탈ab|오로라|aurora)'
    ) AS ab_token_only_review_needed,
    (
      no.base_text_compact ~ '(crystalab|크리스탈ab|오로라|aurora)'
      AND no.channel_normalization_rule = 'crystal'
    ) OR (
      no.channel_text_compact ~ '(crystalab|크리스탈ab|오로라|aurora)'
      AND no.base_normalization_rule = 'crystal'
    ) AS crystal_safety_mixed
  FROM normalized_options AS no
),

ambiguity_stats AS (
  SELECT
    source_channel,
    seller_product_code,
    normalized_channel_option_value,
    COUNT(*) AS normalized_row_count,
    COUNT(DISTINCT sku_id) AS normalized_sku_count,
    COUNT(DISTINCT channel_sku_code) FILTER (WHERE channel_sku_code IS NOT NULL) AS normalized_channel_option_code_count
  FROM impact_base
  WHERE after_normalized_match = true
    AND seller_product_code IS NOT NULL
    AND normalized_channel_option_value IS NOT NULL
  GROUP BY
    source_channel,
    seller_product_code,
    normalized_channel_option_value
),

impact_rows AS (
  SELECT
    ib.*,
    (
      ib.before_exact_match = false
      AND ib.after_normalized_match = true
      AND ib.normalization_rule <> 'raw_text'
    ) AS normalized_option_match_candidate,
    (
      ib.after_normalized_match = true
      AND (
        COALESCE(ast.normalized_sku_count, 0) > 1
        OR COALESCE(ast.normalized_channel_option_code_count, 0) > 1
        OR ib.crystal_safety_mixed = true
        OR ib.ab_token_only_review_needed = true
      )
    ) AS normalized_option_conflict_or_ambiguous,
    (
      ib.after_normalized_match = false
      OR ib.seller_product_code IS NULL
      OR ib.channel_sku_code IS NULL
      OR ib.own_sku_code IS NULL
    ) AS manual_review_still_required
  FROM impact_base AS ib
  LEFT JOIN ambiguity_stats AS ast
    ON ast.source_channel = ib.source_channel
   AND ast.seller_product_code = ib.seller_product_code
   AND ast.normalized_channel_option_value = ib.normalized_channel_option_value
),

summary_rows AS (
  SELECT
    'total_rows'::text AS summary_type,
    NULL::text AS source_channel,
    NULL::text AS normalization_category,
    NULL::text AS normalization_rule,
    COUNT(*)::bigint AS row_count,
    'Smartstore, MakeShop, Ably diagnostic row count.'::text AS safety_note
  FROM impact_rows

  UNION ALL

  SELECT
    'source_channel_count'::text AS summary_type,
    source_channel,
    NULL::text AS normalization_category,
    NULL::text AS normalization_rule,
    COUNT(*)::bigint AS row_count,
    'Count by source channel.'::text AS safety_note
  FROM impact_rows
  GROUP BY source_channel

  UNION ALL

  SELECT
    'normalization_category_count'::text AS summary_type,
    source_channel,
    normalization_category,
    NULL::text AS normalization_rule,
    COUNT(*)::bigint AS row_count,
    'Count by normalization category.'::text AS safety_note
  FROM impact_rows
  GROUP BY source_channel, normalization_category

  UNION ALL

  SELECT
    'normalization_rule_count'::text AS summary_type,
    source_channel,
    normalization_category,
    normalization_rule,
    COUNT(*)::bigint AS row_count,
    'Count by normalization rule.'::text AS safety_note
  FROM impact_rows
  GROUP BY source_channel, normalization_category, normalization_rule

  UNION ALL

  SELECT
    'crystal_crystal_ab_safety_count'::text AS summary_type,
    source_channel,
    'color'::text AS normalization_category,
    'crystal_vs_crystal_ab'::text AS normalization_rule,
    COUNT(*) FILTER (WHERE crystal_safety_mixed)::bigint AS row_count,
    'Rows where crystal and crystal_ab separation needs manual review.'::text AS safety_note
  FROM impact_rows
  GROUP BY source_channel

  UNION ALL

  SELECT
    'ab_false_positive_risk_count'::text AS summary_type,
    source_channel,
    'color'::text AS normalization_category,
    'crystal_ab'::text AS normalization_rule,
    COUNT(*) FILTER (WHERE ab_token_only_review_needed)::bigint AS row_count,
    'AB is counted only as an independent token; these rows still need review.'::text AS safety_note
  FROM impact_rows
  GROUP BY source_channel

  UNION ALL

  SELECT
    'normalized_option_match_candidate_count'::text AS summary_type,
    source_channel,
    normalization_category,
    normalization_rule,
    COUNT(*) FILTER (WHERE normalized_option_match_candidate)::bigint AS row_count,
    'Potential auto-confirm-ready candidates; not confirmed values.'::text AS safety_note
  FROM impact_rows
  GROUP BY source_channel, normalization_category, normalization_rule

  UNION ALL

  SELECT
    'normalized_option_conflict_or_ambiguous_count'::text AS summary_type,
    source_channel,
    normalization_category,
    normalization_rule,
    COUNT(*) FILTER (WHERE normalized_option_conflict_or_ambiguous)::bigint AS row_count,
    'Normalization matched but ambiguity or safety risk remains.'::text AS safety_note
  FROM impact_rows
  GROUP BY source_channel, normalization_category, normalization_rule

  UNION ALL

  SELECT
    'manual_review_still_required_count'::text AS summary_type,
    source_channel,
    normalization_category,
    normalization_rule,
    COUNT(*) FILTER (WHERE manual_review_still_required)::bigint AS row_count,
    'Rows still needing manual review after normalization.'::text AS safety_note
  FROM impact_rows
  GROUP BY source_channel, normalization_category, normalization_rule
)

SELECT
  summary_type,
  source_channel,
  normalization_category,
  normalization_rule,
  row_count,
  safety_note
FROM summary_rows
ORDER BY
  summary_type,
  source_channel NULLS FIRST,
  normalization_category NULLS FIRST,
  normalization_rule NULLS FIRST;

/*
Detailed row review template:

WITH ... same CTEs above ...
SELECT
  source_channel,
  sku_id,
  selfpia_sku_code,
  selfpia_product_code,
  selfpia_option_no,
  product_name,
  option_value,
  channel_option_value,
  normalized_option_value,
  normalized_channel_option_value,
  normalization_category,
  normalization_rule,
  seller_product_code,
  channel_sku_code,
  own_sku_code,
  candidate_product_no,
  candidate_option_no,
  before_exact_match,
  after_normalized_match,
  normalized_option_match_candidate,
  normalized_option_conflict_or_ambiguous,
  manual_review_still_required,
  ab_token_only_review_needed,
  crystal_safety_mixed
FROM impact_rows
WHERE normalized_option_match_candidate = true
   OR normalized_option_conflict_or_ambiguous = true
   OR ab_token_only_review_needed = true
   OR crystal_safety_mixed = true;
*/
