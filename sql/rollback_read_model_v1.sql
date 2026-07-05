/*
  rollback_read_model_v1.sql

  Purpose:
  - Remove read model v1 draft views if they were applied.

  Status:
  - Draft only.
  - Review before running.
*/

BEGIN;

DROP VIEW IF EXISTS public.product_code_search_v1;
DROP VIEW IF EXISTS public.mapping_matrix_summary_v1;
DROP VIEW IF EXISTS public.manual_review_queue_light_v1;
DROP VIEW IF EXISTS public.mapping_matrix_list_v1;

ROLLBACK;
