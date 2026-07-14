const config = window.SYSTEM_V1_CONFIG || {};

const statusEl = document.getElementById("connectionStatus");
const queueTableBody = document.querySelector("#queueTable tbody");
const queueTableHeadRow = document.querySelector("#queueTable thead tr");
const selectedSummary = document.getElementById("selectedSummary");
const candidateDetails = document.getElementById("candidateDetails");
const decisionBox = document.querySelector(".decision-box");
const channelFilter = document.getElementById("channelFilter");
const tierFilter = document.getElementById("tierFilter");
const searchInput = document.getElementById("searchInput");
const imageOnlyFilter = document.getElementById("imageOnlyFilter");
const batchSelect = document.getElementById("batchSelect");
const pageSizeSelect = document.getElementById("pageSizeSelect");
const firstPageButton = document.getElementById("firstPageButton");
const prevPageButton = document.getElementById("prevPageButton");
const nextPageButton = document.getElementById("nextPageButton");
const lastPageButton = document.getElementById("lastPageButton");
const pageIndicator = document.getElementById("pageIndicator");
const displayCountLabel = document.getElementById("displayCountLabel") || document.querySelector(".display-count strong");
const batchHelperText = document.getElementById("batchHelperText");
const channelVisibilityControls = document.getElementById("channelVisibilityControls");
const tagFilterChips = document.getElementById("tagFilterChips");
const detailTagSelect = document.getElementById("detailTagSelect");
const tagPicker = document.getElementById("tagPicker");
const tagMemoInput = document.getElementById("tagMemoInput");
const addTagButton = document.getElementById("addTagButton");
const selectedTagBadges = document.getElementById("selectedTagBadges");
const tagReviewerInput = document.getElementById("tagReviewerInput");
const newTagNameInput = document.getElementById("newTagNameInput");
const newTagColorInput = document.getElementById("newTagColorInput");
const createTagButton = document.getElementById("createTagButton");
const bulkTagSelect = document.getElementById("bulkTagSelect");
const bulkTagPreviewButton = document.getElementById("bulkTagPreviewButton");
const bulkTagSaveLockedButton = document.getElementById("bulkTagSaveLockedButton");
const bulkTagPreviewResult = document.getElementById("bulkTagPreviewResult");
const sellpiaTagTemplateButton = document.getElementById("sellpiaTagTemplateButton");
const sellpiaTagUploadInput = document.getElementById("sellpiaTagUploadInput");
const sellpiaTagAutoCreateInput = document.getElementById("sellpiaTagAutoCreateInput");
const sellpiaTagPreviewButton = document.getElementById("sellpiaTagPreviewButton");
const sellpiaTagSaveButton = document.getElementById("sellpiaTagSaveButton");
const sellpiaTagUploadStatus = document.getElementById("sellpiaTagUploadStatus");
const sellpiaTagPreviewResult = document.getElementById("sellpiaTagPreviewResult");
const reviewModeFilterInputs = [...document.querySelectorAll("input[name='reviewModeFilter']")];
const excludeExcludedRowsInput = document.getElementById("excludeExcludedRows");
const ablyExclusionFilterInput = document.getElementById("ablyExclusionFilter");
const filterResetButton = document.getElementById("filterResetButton");
const smartstoreOriginalInput = document.getElementById("smartstoreOriginalInput");
const smartstoreOriginalPreviewButton = document.getElementById("smartstoreOriginalPreviewButton");
const smartstoreOriginalStatus = document.getElementById("smartstoreOriginalStatus");
const smartstorePreviewPanel = document.getElementById("smartstorePreviewPanel");
const smartstorePreviewTableBody = document.querySelector("#smartstorePreviewTable tbody");
const smartstorePreviewExportButton = document.getElementById("smartstorePreviewExportButton");
const smartstorePreviewCsvButton = document.getElementById("smartstorePreviewCsvButton");
const smartstoreRiskReviewXlsxButton = document.getElementById("smartstoreRiskReviewXlsxButton");
const smartstoreTemplateExportButton = document.getElementById("smartstoreTemplateExportButton");
const smartstorePreviewBucketFilter = document.getElementById("smartstorePreviewBucketFilter");
const smartstoreUploadGatePanel = document.getElementById("smartstoreUploadGatePanel");
const smartstoreUploadGateStatus = document.getElementById("smartstoreUploadGateStatus");
const smartstoreUploadGateMetrics = document.getElementById("smartstoreUploadGateMetrics");
const smartstoreApplyScopeInputs = [...document.querySelectorAll("[data-smartstore-apply-scope]")];
const makeshopOriginalInput = document.getElementById("makeshopOriginalInput");
const makeshopOriginalPreviewButton = document.getElementById("makeshopOriginalPreviewButton");
const makeshopOriginalStatus = document.getElementById("makeshopOriginalStatus");
const makeshopPreviewPanel = document.getElementById("makeshopPreviewPanel");
const makeshopPreviewTableBody = document.querySelector("#makeshopPreviewTable tbody");
const makeshopPreviewExportButton = document.getElementById("makeshopPreviewExportButton");
const makeshopPreviewCsvButton = document.getElementById("makeshopPreviewCsvButton");
const makeshopTemplateExportButton = document.getElementById("makeshopTemplateExportButton");
const makeshopUploadGatePanel = document.getElementById("makeshopUploadGatePanel");
const makeshopUploadGateMetrics = document.getElementById("makeshopUploadGateMetrics");
const makeshopUploadGateStatus = document.getElementById("makeshopUploadGateStatus");
const ablyOriginalInput = document.getElementById("ablyOriginalInput");
const ablyOriginalPreviewButton = document.getElementById("ablyOriginalPreviewButton");
const ablyOriginalStatus = document.getElementById("ablyOriginalStatus");
const ablyPreviewPanel = document.getElementById("ablyPreviewPanel");
const ablyPreviewTableBody = document.querySelector("#ablyPreviewTable tbody");
const ablyPreviewExportButton = document.getElementById("ablyPreviewExportButton");
const ablyPreviewCsvButton = document.getElementById("ablyPreviewCsvButton");
const ablyTemplateExportButton = document.getElementById("ablyTemplateExportButton");
const ablyUploadGatePanel = document.getElementById("ablyUploadGatePanel");
const ablyUploadGateMetrics = document.getElementById("ablyUploadGateMetrics");
const ablyUploadGateStatus = document.getElementById("ablyUploadGateStatus");
const sellpiaStockInput = document.getElementById("sellpiaStockInput");
const sellpiaStockUploadButton = document.getElementById("sellpiaStockUploadButton");
const sellpiaStockLoadLatestButton = document.getElementById("sellpiaStockLoadLatestButton");
const sellpiaStockStatus = document.getElementById("sellpiaStockStatus");
const sellpiaStockLatestStatus = document.getElementById("sellpiaStockLatestStatus");
const sellpiaStockPreviewPanel = document.getElementById("sellpiaStockPreviewPanel");
const sellpiaStockPreviewTableBody = document.querySelector("#sellpiaStockPreviewTable tbody");
const sellerTemplateChannel = document.getElementById("sellerTemplateChannel");
const sellerTemplateInput = document.getElementById("sellerTemplateInput");
const sellerTemplateSaveButton = document.getElementById("sellerTemplateSaveButton");
const sellerTemplateLoadButton = document.getElementById("sellerTemplateLoadButton");
const sellerTemplateClearButton = document.getElementById("sellerTemplateClearButton");
const sellerTemplateStatus = document.getElementById("sellerTemplateStatus");
const sellerTemplatePreviewPanel = document.getElementById("sellerTemplatePreviewPanel");

const CHANNELS = ["sellpia", "smartstore", "makeshop", "ably", "coupang", "playauto"];
const SELLER_CHANNELS = CHANNELS.filter((channel) => channel !== "sellpia");
const APP_MODE = String(config.appMode || config.mode || "demo").toLowerCase();
const QUEUE_VIEW = config.queueView || "mapping_matrix_review_sample_v3";
const DETAILS_VIEW = config.detailsView || "match_candidate_details_sample";
const LOAD_ALL_ROWS = config.loadAllRows !== false;
const SUPABASE_PAGE_SIZE = Number(config.supabasePageSize || 1000);
const REQUIRE_AUTH_FOR_WRITES = config.requireAuthForWrites !== false;
const FULL_BATCH_IDS = [
  "full_channel_matching_20260619_v1_smartstore",
  "full_channel_matching_20260619_v1_makeshop",
  "full_channel_matching_20260619_v1_ably",
  "full_channel_matching_20260619_v1_coupang",
  "full_channel_matching_20260619_v1_playauto",
];
const SAMPLE_BATCH_IDS = [
  "sample_smartstore_500",
  "sample_makeshop_500",
  "sample_smartstore_1000",
  "sample_makeshop_1000",
  "sample_ably_500",
  "sample_coupang_500",
  "sample_playauto_500",
];
const ABLY_FINAL_EXCLUSION_URL = config.ablyFinalExclusionUrl || "data/ably_final_exclusion_20260624.json";
const IMAGE_ASSET_LOOKUP_BATCH_SIZE = 400;

let supabaseClient = null;
let authSession = null;
let authUser = null;
let authReady = false;
let reviewWriterAllowed = false;
let reviewWriterStatusMessage = "";
let queueRows = [];
let queueSummary = null;
let detailCache = new Map();
let imageMap = new Map();
let availableTags = [];
let selectedRow = null;
let activeBatchIds = [];
let currentPage = 1;
let pageSize = 100;
let queueLoadToken = 0;
let activeChannel = "sellpia";
let visibleChannels = new Set(
  Array.isArray(config.defaultVisibleChannels) && config.defaultVisibleChannels.length
    ? config.defaultVisibleChannels.filter((channel) => SELLER_CHANNELS.includes(channel))
    : SELLER_CHANNELS
);
let activeStockStatus = "";
let activeWorkflowFilter = "";
let activeTagNames = new Set();
let reviewModeFilter = "";
let excludeExcludedRows = false;
let ablyExclusionFilter = "";
let ablyFinalExclusionByProductCode = new Map();
let ablyFinalExclusionByOptionCode = new Map();
let ablyFinalKnownProductCodes = new Set();
let ablyFinalKnownOptionCodes = new Set();
let ablyFinalExclusionSummary = null;
let pendingTagIds = new Set();
let selectedQueueIds = new Set();
let lastSelectedPageIndex = null;
let sellpiaTagPreviewRows = [];
let sellpiaSharedTagsAvailable = true;
let smartstoreApplyRows = [];
let smartstoreApplyByKey = new Map();
let smartstoreOriginalWorkbook = null;
let smartstoreOriginalWorksheet = null;
let smartstoreOriginalFileName = "";
let smartstoreOriginalFileBuffer = null;
let smartstorePreviewRows = [];
let smartstoreStockColumnIndex = null;
let smartstoreDetectedColumns = null;
let activeSmartstorePreviewBucket = "";
let makeshopApplyRows = [];
let makeshopApplyByKey = new Map();
let makeshopCompareRows = [];
let makeshopCompareByKey = new Map();
let makeshopOriginalFileName = "";
let makeshopOriginalFileBuffer = null;
let makeshopDetectedColumns = null;
let makeshopPreviewRows = [];
let makeshopMissingApplyRows = [];
let ablyApplyRows = [];
let ablyApplyByKey = new Map();
let ablyOriginalFileName = "";
let ablyOriginalFileBuffer = null;
let ablyDetectedColumns = null;
let ablyPreviewRows = [];
let ablyMissingApplyRows = [];
let ablyExcludedRows = [];
let sellpiaStockRows = [];
let sellpiaStockBySku = new Map();
let sellpiaStockLatestSnapshot = null;
let sellpiaStockLastParse = null;
let activeCellEdit = null;
let activeLinkingMode = "link";
let linkingSearchTerm = "";
let linkingChannelFilter = "";
let linkingHideAblyExcluded = false;
let linkingSelectedQueueId = "";
let linkingCandidateTerm = "";
let manualReviewSearchTerm = "";
let manualReviewActiveFilter = "all";
let manualReviewSelectedQueueId = "";
const MANUAL_REVIEW_PAGE_SIZE = 300;
let manualReviewVisibleCount = MANUAL_REVIEW_PAGE_SIZE;
let queueRowsLoading = false;
let queueRowsFullyLoaded = false;

function setStatus(text, state = "") {
  statusEl.textContent = text;
  statusEl.dataset.state = state;
}

function appModeInfo() {
  if (APP_MODE === "review") {
    return {
      label: "REVIEW",
      text: "실사용 검수 모드 - 수동 결정 저장은 별도 승인된 환경에서만 허용됩니다.",
      state: "review",
    };
  }
  if (APP_MODE === "demo") {
    return {
      label: "READ-ONLY",
      text: "READ-ONLY 데모 - 저장/업로드/자동반영은 차단됩니다.",
      state: "demo",
    };
  }
  return {
    label: "LOCKED",
    text: "저장 비활성화 - 안전한 모드가 확인되지 않았습니다.",
    state: "locked",
  };
}

function renderAppModeBadges() {
  const mode = appModeInfo();
  document.body.dataset.appMode = mode.state;
  document.querySelectorAll(".readonly-banner").forEach((banner) => {
    const label = banner.querySelector("span");
    const text = banner.querySelector("p");
    if (label) label.textContent = mode.label;
    if (text && !text.id) text.textContent = mode.text;
  });
  document.querySelectorAll(".readonly-pill").forEach((pill) => {
    pill.textContent = mode.text;
  });
  document.querySelectorAll(".brand span").forEach((brandMode) => {
    brandMode.textContent = mode.label.toLowerCase();
  });
}

function relocateReviewWorkbooks() {
  const dashboard = document.getElementById("dashboardView");
  const workbookPanel = document.querySelector(".review-download-panel");
  if (!dashboard || !workbookPanel || workbookPanel.closest("#dashboardView")) return;
  workbookPanel.classList.add("is-dashboard-section");
  dashboard.appendChild(workbookPanel);
}

function relocateDetailPanel() {
  const filterPanel = document.querySelector(".filter-panel");
  const detailPanel = document.querySelector(".detail-panel");
  if (!filterPanel || !detailPanel || detailPanel.closest(".filter-detail-layout")) return;

  const wrap = document.createElement("div");
  wrap.className = "filter-detail-layout";
  filterPanel.parentNode.insertBefore(wrap, filterPanel);
  wrap.appendChild(filterPanel);
  wrap.appendChild(detailPanel);
}

function relocatePagerControls() {
  const resultPanel = document.querySelector(".result-panel");
  const pager = document.querySelector(".pager-controls");
  if (!resultPanel || !pager || pager.closest(".result-panel")) return;
  pager.classList.add("is-visible-pager");
  resultPanel.appendChild(pager);
}

function initMatrixScrollState() {
  const scroll = document.querySelector(".matrix-sheet-scroll");
  if (!scroll) return;
  const sync = () => {
    scroll.classList.toggle("is-scrolled", scroll.scrollLeft > 40);
  };
  scroll.addEventListener("scroll", sync, { passive: true });
  sync();
}

function initWorkflowKpiCards() {
  const mapping = [
    ["candidate", "workflowCandidateCount"],
    ["hold", "workflowHoldCount"],
    ["code_blank", "workflowCodeBlankCount"],
    ["no_match", "workflowNoMatchCount"],
    ["excluded", "workflowExcludedCount"],
    ["bundle", "workflowBundleCount"],
    ["suboption", "workflowSuboptionCount"],
    ["stock_match", "stockMatchCount"],
    ["stock_diff", "stockDiffCount"],
    ["stock_missing", "stockMissingCount"],
    ["hold", "stockHoldCount"],
  ];
  document.querySelectorAll(".kpi-grid .kpi-card").forEach((card, index) => {
    const [bucket, countId] = mapping[index] || [];
    if (!bucket) return;
    card.dataset.workflowFilter = bucket;
    card.setAttribute("role", "button");
    card.tabIndex = 0;
    card.title = `${workflowBucketLabel(bucket)} 필터`;
    const count = card.querySelector("strong");
    if (count && countId) count.id = countId;
  });
}

function requireConfig() {
  return Boolean(
    config.supabaseUrl &&
      config.supabaseAnonKey &&
      !config.supabaseAnonKey.includes("PASTE_")
  );
}

function initSupabase() {
  if (!requireConfig()) {
    setStatus("config.js에 Supabase publishable/anon key를 입력하세요.", "warn");
    return false;
  }
  supabaseClient = window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey);
  setStatus("Supabase 연결 준비 완료", "ok");
  return true;
}

function authEmail() {
  return authUser?.email || authSession?.user?.email || "";
}

function authInputEmail() {
  return authEmail() || String(config.reviewAuthDefaultEmail || "").trim();
}

function canWriteReview() {
  if (APP_MODE !== "review") return false;
  if (!REQUIRE_AUTH_FOR_WRITES) return true;
  return Boolean(authUser && reviewWriterAllowed);
}

function writeAccessMessage() {
  if (APP_MODE !== "review") return "현재 모드는 read-only입니다. 저장은 review 모드에서만 가능합니다.";
  if (!REQUIRE_AUTH_FOR_WRITES) return "";
  if (REQUIRE_AUTH_FOR_WRITES && !authUser) return "실사용 저장은 이메일 로그인 후 가능합니다. 로그인 링크를 받아 같은 브라우저에서 열어주세요.";
  if (REQUIRE_AUTH_FOR_WRITES && authUser && !reviewWriterAllowed) {
    return reviewWriterStatusMessage || "로그인 계정이 아직 수동검수 allowlist에 없습니다.";
  }
  return "";
}

function authRedirectUrl() {
  return config.authRedirectUrl || window.location.href.split("#")[0];
}

function renderWriteSensitiveViews() {
  renderAuthPanel();
  if (selectedRow) renderDecisionControls(selectedRow);
  if (document.getElementById("manualReviewView")?.classList.contains("is-active")) {
    renderManualReviewSelected();
  }
  if (document.getElementById("linkingView")?.classList.contains("is-active")) {
    renderLinkingView();
  }
}

function renderAuthPanel() {
  let panel = document.getElementById("reviewAuthPanel");
  const main = document.querySelector(".app-main");
  if (!main) return;
  if (!panel) {
    panel = document.createElement("section");
    panel.id = "reviewAuthPanel";
    panel.className = "auth-panel";
    main.insertBefore(panel, main.firstElementChild);
  }

  const email = authEmail();
  const inputEmail = authInputEmail();
  const writeMessage = writeAccessMessage();
  panel.dataset.state = canWriteReview() ? "ok" : "warn";
  if (!REQUIRE_AUTH_FOR_WRITES) {
    panel.innerHTML = `
      <div>
        <strong>DB 저장 가능</strong>
        <p>FULL_System 방식처럼 로그인 없이 공개 검수 화면에서 바로 저장합니다.</p>
      </div>
    `;
    return;
  }
  panel.innerHTML = `
    <div>
      <strong>${canWriteReview() ? "DB 저장 가능" : "DB 저장 잠금"}</strong>
      <p>${escapeHtml(email ? `${email} 로그인됨` : writeMessage || "로그인 상태 확인 중")}</p>
      ${email && !canWriteReview() ? `<p>${escapeHtml(writeMessage)}</p>` : ""}
    </div>
    <form id="reviewAuthForm" class="auth-form">
      <input id="reviewAuthEmail" type="email" autocomplete="email" placeholder="hi0559@naver.com" value="${escapeHtml(inputEmail)}" ${email ? "disabled" : ""} />
      ${email
        ? '<button type="button" id="reviewAuthSignOutButton">로그아웃</button>'
        : '<button type="submit">로그인 링크 보내기</button>'}
    </form>
  `;

  panel.querySelector("#reviewAuthForm")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const input = panel.querySelector("#reviewAuthEmail");
    const targetEmail = input?.value?.trim();
    if (!targetEmail || !supabaseClient?.auth) return;
    const { error } = await supabaseClient.auth.signInWithOtp({
      email: targetEmail,
      options: {
        emailRedirectTo: authRedirectUrl(),
      },
    });
    if (error) {
      setStatus(`로그인 링크 발송 실패: ${error.message}`, "warn");
      return;
    }
    setStatus("로그인 링크를 이메일로 보냈습니다. 받은 메일의 링크를 이 브라우저에서 열면 저장 버튼이 활성화됩니다.", "ok");
  });

  panel.querySelector("#reviewAuthSignOutButton")?.addEventListener("click", async () => {
    if (!supabaseClient?.auth) return;
    await supabaseClient.auth.signOut();
  });
}

async function refreshReviewWriterStatus() {
  reviewWriterAllowed = false;
  reviewWriterStatusMessage = "";
  if (!authUser || !supabaseClient?.rpc) return;

  const { data, error } = await supabaseClient.rpc("current_review_writer_status");
  if (error) {
    reviewWriterStatusMessage = `allowlist 확인 실패: ${error.message}`;
    return;
  }
  reviewWriterAllowed = Boolean(data?.allowed);
  if (!reviewWriterAllowed) {
    reviewWriterStatusMessage = "로그인은 되었지만 수동검수 allowlist에 등록되지 않았습니다.";
  }
}

async function setupAuth() {
  renderAuthPanel();
  if (!supabaseClient?.auth) {
    authReady = true;
    renderAuthPanel();
    return;
  }

  const { data, error } = await supabaseClient.auth.getSession();
  if (!error) {
    authSession = data?.session || null;
    authUser = authSession?.user || null;
  }
  authReady = true;
  await refreshReviewWriterStatus();
  renderWriteSensitiveViews();

  supabaseClient.auth.onAuthStateChange(async (_event, session) => {
    authSession = session || null;
    authUser = authSession?.user || null;
    authReady = true;
    await refreshReviewWriterStatus();
    renderWriteSensitiveViews();
  });
}

function ensureWriteAccess() {
  const message = writeAccessMessage();
  if (!message) return true;
  alert(message);
  return false;
}

function batchFilter() {
  if (activeBatchIds.length) {
    return activeBatchIds;
  }
  const configured = Array.isArray(config.defaultBatchIds) ? config.defaultBatchIds : [];
  if (configured.length && !LOAD_ALL_ROWS) {
    return configured;
  }
  if (configured.some((id) => String(id).endsWith("_500"))) {
    return configured;
  }
  return ["sample_smartstore_500", "sample_makeshop_500"];
}

function batchOptions() {
  const configured = Array.isArray(config.defaultBatchIds) ? config.defaultBatchIds : [];
  return [
    ...new Set([
      ...configured,
      ...FULL_BATCH_IDS,
      ...SAMPLE_BATCH_IDS,
    ].filter(Boolean)),
  ];
}

function initBatchSelector() {
  if (!batchSelect) return;
  const defaults = new Set(batchFilter());
  batchSelect.innerHTML = "";
  batchOptions().forEach((batchId) => {
    const option = document.createElement("option");
    option.value = batchId;
    option.textContent = batchId;
    option.selected = defaults.has(batchId);
    batchSelect.appendChild(option);
  });
  activeBatchIds = [...batchSelect.selectedOptions].map((option) => option.value);
  renderBatchHelper();
}

function selectedBatchIds() {
  if (!batchSelect) return batchFilter();
  const selected = [...batchSelect.selectedOptions].map((option) => option.value);
  return selected.length ? selected : batchFilter();
}

function renderBatchHelper() {
  if (!batchHelperText) return;
  if (LOAD_ALL_ROWS) {
    batchHelperText.textContent = "전체 full batch를 자동 조회합니다. 비개발자 검수 화면에서는 batch를 따로 선택하지 않습니다.";
    return;
  }
  batchHelperText.textContent = `${selectedBatchIds().join(", ")} 조회 중. 현재 필터 결과를 페이지 단위로 표시합니다.`;
}

function resetPagination() {
  currentPage = 1;
}

function pagedRows(rows) {
  const totalPages = Math.max(1, Math.ceil(rows.length / pageSize));
  currentPage = Math.max(1, Math.min(currentPage, totalPages));
  const start = (currentPage - 1) * pageSize;
  return {
    rows: rows.slice(start, start + pageSize),
    start,
    end: Math.min(start + pageSize, rows.length),
    total: rows.length,
    totalPages,
  };
}

function renderPager(page) {
  if (pageIndicator) {
    pageIndicator.textContent = `${page.currentPage || currentPage} / ${page.totalPages}`;
  }
  [firstPageButton, prevPageButton].forEach((button) => {
    if (button) button.disabled = currentPage <= 1;
  });
  [nextPageButton, lastPageButton].forEach((button) => {
    if (button) button.disabled = currentPage >= page.totalPages;
  });
  if (displayCountLabel) {
    displayCountLabel.textContent = `${pageSize.toLocaleString()}개 단위`;
  }
}

async function loadTags() {
  const { data, error } = await supabaseClient
    .from("product_tags")
    .select("tag_id,tag_name,tag_color,description")
    .order("tag_name", { ascending: true });
  if (error) {
    console.error(error);
    setStatus(`태그 조회 실패: ${error.message}`, "error");
    return;
  }
  availableTags = data || [];
  renderTagControls();
}

function numeric(value) {
  return Number(value || 0);
}

function summaryChannels() {
  if (!queueSummary?.by_channel) return null;
  return [...visibleChannels]
    .map((channel) => queueSummary.by_channel[channel])
    .filter(Boolean);
}

function sumSummaryField(field) {
  const channels = summaryChannels();
  if (!channels?.length) return null;
  return channels.reduce((sum, item) => sum + numeric(item[field]), 0);
}

async function loadQueueSummary() {
  if (!supabaseClient?.rpc) return;
  const { data, error } = await supabaseClient.rpc("review_queue_summary_v1");
  if (error) {
    console.error(error);
    queueSummary = null;
    setStatus(`전체 요약 조회 실패: ${error.message}`, "warn");
    return;
  }
  queueSummary = data || null;
}

async function loadQueueRows() {
  if (!supabaseClient) return;
  const loadToken = ++queueLoadToken;
  queueRowsLoading = true;
  queueRowsFullyLoaded = false;
  activeBatchIds = selectedBatchIds();
  detailCache = new Map();
  selectedRow = null;
  selectedQueueIds = new Set();
  lastSelectedPageIndex = null;
  resetPagination();
  setStatus("전체 검수 큐 조회 중...", "loading");

  const summaryPromise = loadQueueSummary();

  const result = await fetchQueueRows({
    onProgress: (rows, loadedCount) => {
      if (loadToken !== queueLoadToken || !rows.length) return;
      queueRows = rows.slice();
      renderBatchHelper();
      setStatus(`전체 검수 큐 조회 중... ${loadedCount.toLocaleString()}건 표시 가능`, "loading");
      renderDashboard();
      renderStockSummary();
      renderTable();
      if (document.getElementById("manualReviewView")?.classList.contains("is-active")) renderManualReviewView();
    },
  });
  if (loadToken !== queueLoadToken) return;
  if (result.error) {
    console.error(result.error);
    queueRowsLoading = false;
    setStatus(`검수 큐 조회 실패: ${result.error.message}`, "error");
    return;
  }

  queueRows = result.rows;
  queueRowsLoading = false;
  queueRowsFullyLoaded = true;
  await summaryPromise;
  await loadImageAssets(queueRows);
  await loadSellpiaSharedTagsForRows(queueRows);
  renderBatchHelper();
  const totalRows = numeric(queueSummary?.totals?.rows);
  setStatus(totalRows
    ? `${QUEUE_VIEW}: total ${totalRows.toLocaleString()} rows, loaded ${queueRows.length.toLocaleString()} rows for screen`
    : `${QUEUE_VIEW}: loaded ${queueRows.length.toLocaleString()} rows for screen`, "ok");
  renderDashboard();
  renderStockSummary();
  renderTable();
  if (document.getElementById("manualReviewView")?.classList.contains("is-active")) renderManualReviewView();
}

function queueSelectColumns() {
  return [
    "queue_id",
    "source_batch_id",
    "source_channel",
    "source_row_no",
    "channel_product_code",
    "channel_option_code",
    "channel_product_name",
    "channel_option_name",
    "channel_seller_code",
    "best_sellpia_product_code",
    "best_sellpia_sku_code",
    "best_sellpia_product_name",
    "best_sellpia_option_name",
    "match_tier",
    "match_score",
    "match_reason",
    "duplicate_candidate_count",
    "duplicate_risk",
    "review_required",
    "recommended_action",
    "evidence_json",
    "stock_compare_status",
    "auto_approval_tier",
    "sellpia_image_file_name",
    "sellpia_image_url",
    "has_sellpia_image",
    "manual_tags",
    "manual_tag_names",
    "manual_tag_count",
    "has_manual_tag",
  ].join(",");
}

function queueRestHeaders() {
  const token = authSession?.access_token || config.supabaseAnonKey;
  return {
    apikey: config.supabaseAnonKey,
    Authorization: `Bearer ${token}`,
    Accept: "application/json",
  };
}

async function fetchQueuePageViaRest(from, to) {
  const url = new URL(`${config.supabaseUrl}/rest/v1/${QUEUE_VIEW}`);
  url.searchParams.set("select", queueSelectColumns());
  url.searchParams.set("order", "review_required.desc,source_channel.asc,queue_id.asc");
  url.searchParams.set("limit", String(to - from + 1));
  url.searchParams.set("offset", String(from));
  if (!LOAD_ALL_ROWS) {
    url.searchParams.set("source_batch_id", `in.(${activeBatchIds.join(",")})`);
  }

  const response = await fetch(url.toString(), { headers: queueRestHeaders() });
  if (response.ok) return { data: await response.json(), error: null };

  let body = null;
  try {
    body = await response.json();
  } catch {
    body = { message: await response.text() };
  }
  return {
    data: null,
    error: {
      ...body,
      status: response.status,
      message: body?.message || `${response.status} ${response.statusText}`,
    },
  };
}

async function fetchQueueRows({ onProgress } = {}) {
  const rows = [];
  let from = 0;
  while (true) {
    const to = from + SUPABASE_PAGE_SIZE - 1;
    const { data, error } = await fetchQueuePageViaRest(from, to);
    if (error) return { rows, error };
    rows.push(...(data || []));
    if (typeof onProgress === "function" && rows.length) {
      onProgress(rows, rows.length);
      await new Promise((resolve) => setTimeout(resolve, 0));
    }

    if (!data || data.length < SUPABASE_PAGE_SIZE) {
      break;
    }
    from += SUPABASE_PAGE_SIZE;
    if (from % 10000 === 0) {
      setStatus(`전체 검수 큐 조회 중... ${from.toLocaleString()}건 이상`, "loading");
    }
  }
  return { rows, error: null };
}

function uniqueCompact(values) {
  return [...new Set(values.map((value) => String(value || "").trim()).filter(Boolean))];
}

function chunkArray(values, size = 400) {
  const chunks = [];
  for (let index = 0; index < values.length; index += size) {
    chunks.push(values.slice(index, index + size));
  }
  return chunks;
}

function sellpiaTagFromAssignment(row) {
  const tag = Array.isArray(row.product_tags) ? row.product_tags[0] : row.product_tags;
  return {
    assignment_id: row.assignment_id,
    tag_id: row.tag_id || tag?.tag_id,
    tag_name: tag?.tag_name || row.tag_name || "",
    tag_color: tag?.tag_color || "#E9D5FF",
    memo: row.memo || "",
    reviewer: row.reviewer || "",
    tag_scope: row.tag_scope || "option",
    sellpia_product_code: row.sellpia_product_code || "",
    sellpia_sku_code: row.sellpia_sku_code || "",
    is_sellpia_shared: true,
  };
}

function mergeTagLists(...lists) {
  const merged = [];
  const seen = new Set();
  lists.flat().filter(Boolean).forEach((tag) => {
    const key = `${tag.tag_id || tag.tag_name}|${tag.tag_scope || ""}|${tag.assignment_id || ""}`;
    if (seen.has(key)) return;
    seen.add(key);
    merged.push(tag);
  });
  return merged;
}

async function fetchSellpiaTagAssignmentsByField(field, values) {
  const rows = [];
  for (const chunk of chunkArray(uniqueCompact(values))) {
    const { data, error } = await supabaseClient
      .from("sellpia_tag_assignments")
      .select("assignment_id,tag_id,tag_scope,sellpia_product_code,sellpia_sku_code,memo,reviewer,product_tags(tag_id,tag_name,tag_color,description)")
      .eq("is_active", true)
      .in(field, chunk);
    if (error) throw error;
    rows.push(...(data || []));
  }
  return rows;
}

async function loadSellpiaSharedTagsForRows(rows) {
  rows.forEach((row) => {
    row.sellpia_tags = [];
  });
  if (!supabaseClient || !rows.length || !sellpiaSharedTagsAvailable) return;
  const productCodes = uniqueCompact(rows.map((row) => row.best_sellpia_product_code || sellpiaProductCodeFromSku(row.best_sellpia_sku_code)));
  const skuCodes = uniqueCompact(rows.map((row) => row.best_sellpia_sku_code));
  if (!productCodes.length && !skuCodes.length) return;

  try {
    const [productAssignments, skuAssignments] = await Promise.all([
      productCodes.length ? fetchSellpiaTagAssignmentsByField("sellpia_product_code", productCodes) : Promise.resolve([]),
      skuCodes.length ? fetchSellpiaTagAssignmentsByField("sellpia_sku_code", skuCodes) : Promise.resolve([]),
    ]);
    const byProduct = new Map();
    const bySku = new Map();
    productAssignments.forEach((row) => {
      const tag = sellpiaTagFromAssignment(row);
      const key = String(row.sellpia_product_code || "").trim();
      if (!key) return;
      byProduct.set(key, mergeTagLists(byProduct.get(key) || [], [tag]));
    });
    skuAssignments.forEach((row) => {
      const tag = sellpiaTagFromAssignment(row);
      const key = String(row.sellpia_sku_code || "").trim();
      if (!key) return;
      bySku.set(key, mergeTagLists(bySku.get(key) || [], [tag]));
    });
    rows.forEach((row) => {
      const productCode = String(row.best_sellpia_product_code || sellpiaProductCodeFromSku(row.best_sellpia_sku_code) || "").trim();
      const skuCode = String(row.best_sellpia_sku_code || "").trim();
      row.sellpia_tags = mergeTagLists(byProduct.get(productCode) || [], bySku.get(skuCode) || []);
    });
  } catch (error) {
    sellpiaSharedTagsAvailable = false;
    console.warn("셀피아 공유 태그 조회 비활성화", error);
    if (sellpiaTagUploadStatus) {
      sellpiaTagUploadStatus.textContent = "셀피아 공유 태그 테이블이 아직 적용되지 않았습니다. Supabase migration 적용 후 사용할 수 있습니다.";
    }
  }
}

async function loadSmartstoreApplyMap() {
  try {
    const response = await fetch("./data/smartstore_stock_apply_map_4251_v1.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const payload = await response.json();
    smartstoreApplyRows = payload.rows || [];
    smartstoreApplyByKey = new Map();
    smartstoreApplyRows.forEach((row) => {
      const productNo = String(row.smartstore_product_no || "").trim();
      const optionCode = String(row.smartstore_option_code || "").trim();
      if (!productNo || !optionCode) return;
      smartstoreApplyByKey.set(`${productNo}|${optionCode}`, row);
    });
    if (smartstoreOriginalStatus) {
      smartstoreOriginalStatus.textContent = `재고 apply map ${smartstoreApplyRows.length.toLocaleString()}건 준비됨. 원본양식 XLSX를 선택해 주세요.`;
    }
  } catch (error) {
    console.error(error);
    if (smartstoreOriginalStatus) {
      smartstoreOriginalStatus.textContent = `재고 apply map 로드 실패: ${error.message}`;
    }
  }
}

async function loadMakeshopApplyMap() {
  try {
    const response = await fetch("./data/makeshop_stock_apply_map_163_v1.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const payload = await response.json();
    makeshopApplyRows = payload.rows || [];
    makeshopApplyByKey = new Map();
    makeshopApplyRows.forEach((row) => {
      const productUid = String(row.makeshop_product_uid || "").trim();
      const stoId = String(row.makeshop_sto_id || "").trim();
      if (!productUid || !stoId) return;
      makeshopApplyByKey.set(`${productUid}|${stoId}`, row);
    });
    if (makeshopOriginalStatus) {
      makeshopOriginalStatus.textContent = `재고 apply map ${makeshopApplyRows.length.toLocaleString()}건 준비됨. MakeShop 원본양식 XLSX를 선택해 주세요.`;
    }
  } catch (error) {
    console.error(error);
    if (makeshopOriginalStatus) {
      makeshopOriginalStatus.textContent = `MakeShop 재고 apply map 로드 실패: ${error.message}`;
    }
  }
}

async function loadMakeshopCompareMap() {
  if (makeshopCompareByKey.size) return;
  try {
    const response = await fetch("./data/makeshop_stock_compare_map_v1.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const payload = await response.json();
    makeshopCompareRows = payload.rows || [];
    makeshopCompareByKey = new Map();
    makeshopCompareRows.forEach((row) => {
      const productUid = String(row.makeshop_product_uid || "").trim();
      const stoId = String(row.makeshop_sto_id || "").trim();
      if (!productUid || !stoId) return;
      makeshopCompareByKey.set(`${productUid}|${stoId}`, row);
    });
  } catch (error) {
    console.error(error);
    if (makeshopOriginalStatus) {
      makeshopOriginalStatus.textContent = `MakeShop 전체 대조 map 로드 실패: ${error.message}`;
    }
  }
}

async function loadAblyApplyMap() {
  try {
    const response = await fetch("./data/ably_stock_apply_map_existing_matched_v1.json", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const payload = await response.json();
    ablyApplyRows = payload.rows || [];
    ablyApplyByKey = new Map();
    ablyApplyRows.forEach((row) => {
      const productCode = String(row.ably_product_code || "").trim();
      const optionCode = String(row.ably_option_code || "").trim();
      if (!productCode || !optionCode) return;
      ablyApplyByKey.set(`${productCode}|${optionCode}`, row);
    });
    if (ablyOriginalStatus) {
      ablyOriginalStatus.textContent = `기존 매칭 apply map ${ablyApplyRows.length.toLocaleString()}건 준비됨. Ably 원본양식 XLSX를 선택해 주세요.`;
    }
  } catch (error) {
    console.error(error);
    if (ablyOriginalStatus) {
      ablyOriginalStatus.textContent = `Ably 재고 apply map 로드 실패: ${error.message}`;
    }
  }
}

function setSellpiaStockStatus(message, isError = false) {
  if (sellpiaStockStatus) sellpiaStockStatus.textContent = message;
  if (isError) console.error(message);
  else console.info(message);
}

function setSellpiaLatestStatus(message) {
  if (sellpiaStockLatestStatus) sellpiaStockLatestStatus.textContent = message;
}

function toIntegerOrNull(value) {
  const text = String(value ?? "").replace(/,/g, "").trim();
  if (!text) return null;
  const number = Number(text);
  return Number.isFinite(number) ? Math.trunc(number) : null;
}

function sellpiaProductCodeFromSku(sku) {
  const text = String(sku || "").trim();
  if (!text) return "";
  return text.includes("-") ? text.split("-")[0] : text;
}

function findSellpiaStockColumnsFromHeaders(headers) {
  const H = {
    sku: "\uc0c1\ud488\ucf54\ub4dc",
    ownSku: "\uc790\uc0ac\ucf54\ub4dc",
    productName: "\uc0c1\ud488\uba85",
    optionName: "\uc635\uc158\uba85",
    stock: "\uc7ac\uace0",
    availableStock: "\uac00\uc6a9\uc7ac\uace0",
    integratedAvailableStock: "\ud1b5\ud569\uac00\uc6a9\uc7ac\uace0",
    safetyStock: "\uc548\uc804\uc7ac\uace0",
    discontinued: "\ub2e8\uc885",
    soldOut: "\ud488\uc808",
  };
  const candidates = {
    sku: null,
    ownSku: null,
    productName: null,
    optionName: null,
    stock: null,
    availableStock: null,
    integratedAvailableStock: null,
    safetyStock: null,
    discontinued: null,
    soldOut: null,
  };
  headers.forEach((headerText, index) => {
    const header = normalizedHeader(headerText);
    if (!header) return;
    if (candidates.sku == null && (header === H.sku || header === "sellpiacode" || header === `sellpia${H.sku}`)) candidates.sku = index;
    if (candidates.ownSku == null && (header === H.ownSku || header === "ownsku" || header === "\uc790\uc0acsku")) candidates.ownSku = index;
    if (candidates.productName == null && (header === H.productName || header === "productname")) candidates.productName = index;
    if (candidates.optionName == null && (header === H.optionName || header === "optionname")) candidates.optionName = index;
    if (candidates.stock == null && (header === H.stock || header === "stock")) candidates.stock = index;
    if (candidates.availableStock == null && (header === H.availableStock || header === "availablestock")) candidates.availableStock = index;
    if (candidates.integratedAvailableStock == null && (header === H.integratedAvailableStock || header === "integratedavailablestock")) candidates.integratedAvailableStock = index;
    if (candidates.safetyStock == null && (header === H.safetyStock || header === "safetystock")) candidates.safetyStock = index;
    if (candidates.discontinued == null && header === H.discontinued) candidates.discontinued = index;
    if (candidates.soldOut == null && header === H.soldOut) candidates.soldOut = index;
  });
  return candidates;
}

function sellpiaStockRowFromValues(values, columns, sourceRowNo) {
  const get = (index) => (index == null ? "" : String(values[index] ?? "").trim());
  const sku = get(columns.sku);
  if (!sku) return null;
  return {
    sellpia_sku_code: sku,
    sellpia_product_code: sellpiaProductCodeFromSku(sku),
    sellpia_product_name: get(columns.productName),
    sellpia_option_name: get(columns.optionName),
    own_sku: get(columns.ownSku),
    stock: toIntegerOrNull(get(columns.stock)),
    available_stock: toIntegerOrNull(get(columns.availableStock)),
    integrated_available_stock: toIntegerOrNull(get(columns.integratedAvailableStock)),
    safety_stock: toIntegerOrNull(get(columns.safetyStock)),
    source_row_no: sourceRowNo,
    raw_payload: {
      discontinued: get(columns.discontinued),
      sold_out: get(columns.soldOut),
    },
  };
}

function parseCsvText(text) {
  const rows = [];
  let row = [];
  let value = "";
  let inQuotes = false;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];
    if (char === "\"") {
      if (inQuotes && next === "\"") {
        value += "\"";
        index += 1;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === "," && !inQuotes) {
      row.push(value);
      value = "";
    } else if ((char === "\n" || char === "\r") && !inQuotes) {
      if (char === "\r" && next === "\n") index += 1;
      row.push(value);
      if (row.some((cell) => String(cell).trim() !== "")) rows.push(row);
      row = [];
      value = "";
    } else {
      value += char;
    }
  }
  row.push(value);
  if (row.some((cell) => String(cell).trim() !== "")) rows.push(row);
  return rows;
}

async function parseSellpiaStockFile(file) {
  if (!file) throw new Error("셀피아 재고 파일을 먼저 선택해 주세요.");
  const extension = file.name.split(".").pop().toLowerCase();
  let headers = [];
  const rowsBySku = new Map();
  let sourceRowCount = 0;
  let invalidRowCount = 0;
  let duplicateRowCount = 0;

  if (extension === "csv") {
    const text = await file.text();
    const csvRows = parseCsvText(text.replace(/^\ufeff/, ""));
    headers = csvRows[0] || [];
    const columns = findSellpiaStockColumnsFromHeaders(headers);
    if (columns.sku == null) throw new Error(`필수 컬럼인 셀피아 상품코드를 찾지 못했습니다. 감지된 컬럼: ${headers.join(", ")}`);
    csvRows.slice(1).forEach((values, index) => {
      sourceRowCount += 1;
      const parsed = sellpiaStockRowFromValues(values, columns, index + 2);
      if (!parsed) {
        invalidRowCount += 1;
        return;
      }
      if (rowsBySku.has(parsed.sellpia_sku_code)) duplicateRowCount += 1;
      rowsBySku.set(parsed.sellpia_sku_code, parsed);
    });
  } else {
    if (!window.ExcelJS) throw new Error("엑셀 파서가 아직 로드되지 않았습니다. 새로고침 후 다시 시도해 주세요.");
    const workbook = new window.ExcelJS.Workbook();
    await workbook.xlsx.load(await file.arrayBuffer());
    const worksheet = workbook.worksheets[0];
    if (!worksheet) throw new Error("The workbook has no worksheet.");
    const headerRow = worksheet.getRow(1);
    const maxCol = worksheet.columnCount || 80;
    for (let col = 1; col <= maxCol; col += 1) headers.push(cellText(headerRow.getCell(col)).trim());
    const columns = findSellpiaStockColumnsFromHeaders(headers);
    if (columns.sku == null) throw new Error(`필수 컬럼인 셀피아 상품코드를 찾지 못했습니다. 감지된 컬럼: ${headers.filter(Boolean).join(", ")}`);
    for (let rowNo = 2; rowNo <= worksheet.rowCount; rowNo += 1) {
      const row = worksheet.getRow(rowNo);
      const values = headers.map((_, index) => cellText(row.getCell(index + 1)).trim());
      if (!values.some(Boolean)) continue;
      sourceRowCount += 1;
      const parsed = sellpiaStockRowFromValues(values, columns, rowNo);
      if (!parsed) {
        invalidRowCount += 1;
        continue;
      }
      if (rowsBySku.has(parsed.sellpia_sku_code)) duplicateRowCount += 1;
      rowsBySku.set(parsed.sellpia_sku_code, parsed);
    }
  }

  const rows = [...rowsBySku.values()];
  return {
    fileName: file.name,
    fileSize: file.size,
    headers: headers.filter(Boolean),
    sourceRowCount,
    validRowCount: rows.length,
    invalidRowCount: invalidRowCount + duplicateRowCount,
    duplicateRowCount,
    rows,
  };
}

function renderSellpiaStockPreview(parseResult, latestRows = sellpiaStockRows.length) {
  if (!sellpiaStockPreviewPanel) return;
  sellpiaStockPreviewPanel.hidden = false;
  document.getElementById("sellpiaStockSourceRows").textContent = (parseResult?.sourceRowCount || 0).toLocaleString();
  document.getElementById("sellpiaStockValidRows").textContent = (parseResult?.validRowCount || 0).toLocaleString();
  document.getElementById("sellpiaStockInvalidRows").textContent = (parseResult?.invalidRowCount || 0).toLocaleString();
  document.getElementById("sellpiaStockSnapshotRows").textContent = (latestRows || 0).toLocaleString();
  if (!sellpiaStockPreviewTableBody) return;
  const previewRows = (parseResult?.rows || sellpiaStockRows || []).slice(0, 80);
  sellpiaStockPreviewTableBody.innerHTML = "";
  previewRows.forEach((row) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${escapeHtml(row.source_row_no || "")}</td>
      <td>${escapeHtml(row.sellpia_sku_code || "")}</td>
      <td>${escapeHtml(row.sellpia_product_name || "")}</td>
      <td>${escapeHtml(row.sellpia_option_name || "")}</td>
      <td>${escapeHtml(row.stock ?? "")}</td>
      <td>${escapeHtml(row.available_stock ?? "")}</td>
      <td>${escapeHtml(row.integrated_available_stock ?? "")}</td>
      <td>${escapeHtml(row.safety_stock ?? "")}</td>
    `;
    sellpiaStockPreviewTableBody.appendChild(tr);
  });
}

async function uploadSellpiaStockToSupabase() {
  const file = sellpiaStockInput?.files?.[0];
  if (!file) {
    alert("셀피아 재고 XLSX/CSV 파일을 먼저 선택해 주세요.");
    return;
  }
  if (!supabaseClient && !initSupabase()) return;
  try {
    sellpiaStockUploadButton.disabled = true;
    setSellpiaStockStatus(`${file.name} 분석 중...`);
    const parsed = await parseSellpiaStockFile(file);
    sellpiaStockLastParse = parsed;
    renderSellpiaStockPreview(parsed, sellpiaStockRows.length);
    setSellpiaStockStatus(
      `${file.name} 분석 완료: 컬럼=${parsed.headers.join(", ")} / 전체 행=${parsed.sourceRowCount.toLocaleString()} / 유효 행=${parsed.validRowCount.toLocaleString()} / 제외 행=${parsed.invalidRowCount.toLocaleString()}`
    );

    const { data: snapshot, error: snapshotError } = await supabaseClient
      .from("sellpia_stock_snapshots")
      .insert({
        source_file_name: parsed.fileName,
        source_file_size: parsed.fileSize,
        source_row_count: parsed.sourceRowCount,
        valid_row_count: parsed.validRowCount,
        invalid_row_count: parsed.invalidRowCount,
        upload_status: "uploading",
        uploaded_by: "system_v1_frontend",
        upload_note: parsed.duplicateRowCount ? `중복 SKU ${parsed.duplicateRowCount}건은 마지막 행 기준으로 저장했습니다.` : null,
        metadata: { headers: parsed.headers.slice(0, 120) },
      })
      .select("snapshot_id,created_at,source_file_name")
      .single();
    if (snapshotError) throw snapshotError;

    const chunkSize = 500;
    for (let index = 0; index < parsed.rows.length; index += chunkSize) {
      const chunk = parsed.rows.slice(index, index + chunkSize).map((row) => ({
        ...row,
        snapshot_id: snapshot.snapshot_id,
      }));
      const { error: rowError } = await supabaseClient
        .from("sellpia_stock_snapshot_rows")
        .insert(chunk);
      if (rowError) throw rowError;
      setSellpiaStockStatus(`${file.name} 업로드 중: ${Math.min(index + chunk.length, parsed.rows.length).toLocaleString()} / ${parsed.rows.length.toLocaleString()}행...`);
      await new Promise((resolve) => setTimeout(resolve, 0));
    }

    const { error: readyError } = await supabaseClient
      .from("sellpia_stock_snapshots")
      .update({
        upload_status: "ready",
        completed_at: new Date().toISOString(),
      })
      .eq("snapshot_id", snapshot.snapshot_id);
    if (readyError) throw readyError;

    await loadLatestSellpiaStockSnapshot({ force: true });
    setSellpiaStockStatus(`Supabase 업로드 완료: ${file.name}에서 셀피아 재고 ${parsed.validRowCount.toLocaleString()}행 저장.`);
  } catch (error) {
    console.error(error);
    setSellpiaStockStatus(`셀피아 재고 업로드 실패: ${error.message}`, true);
    alert(`셀피아 재고 업로드 실패: ${error.message}`);
  } finally {
    if (sellpiaStockUploadButton) sellpiaStockUploadButton.disabled = false;
  }
}

async function loadLatestSellpiaStockSnapshot({ force = false, silent = false } = {}) {
  if (sellpiaStockRows.length && !force) return sellpiaStockRows;
  if (!supabaseClient && !initSupabase()) return [];
  try {
    if (!silent) setSellpiaLatestStatus("Supabase에서 최신 셀피아 재고를 불러오는 중...");
    const { data: snapshots, error: snapshotError } = await supabaseClient
      .from("sellpia_stock_snapshots")
      .select("snapshot_id,source_file_name,source_row_count,valid_row_count,invalid_row_count,created_at,completed_at")
      .eq("upload_status", "ready")
      .order("created_at", { ascending: false })
      .limit(1);
    if (snapshotError) throw snapshotError;
    const snapshot = snapshots?.[0];
    if (!snapshot) {
      if (!silent) setSellpiaLatestStatus("아직 Supabase에 준비된 셀피아 재고 저장본이 없습니다.");
      return [];
    }

    const rows = [];
    let from = 0;
    while (true) {
      const to = from + SUPABASE_PAGE_SIZE - 1;
      const { data, error } = await supabaseClient
        .from("sellpia_stock_snapshot_rows")
        .select("sellpia_sku_code,sellpia_product_code,sellpia_product_name,sellpia_option_name,own_sku,stock,available_stock,integrated_available_stock,safety_stock,source_row_no")
        .eq("snapshot_id", snapshot.snapshot_id)
        .order("sellpia_sku_code", { ascending: true })
        .range(from, to);
      if (error) throw error;
      rows.push(...(data || []));
      if (!data || data.length < SUPABASE_PAGE_SIZE) break;
      from += SUPABASE_PAGE_SIZE;
      if (!silent && rows.length % (SUPABASE_PAGE_SIZE * 10) === 0) {
        setSellpiaLatestStatus(`최신 셀피아 재고 불러오는 중: ${rows.length.toLocaleString()}행...`);
      }
    }

    sellpiaStockLatestSnapshot = snapshot;
    sellpiaStockRows = rows;
    sellpiaStockBySku = new Map(rows.map((row) => [String(row.sellpia_sku_code || "").trim(), row]).filter(([sku]) => sku));
    renderSellpiaStockPreview(sellpiaStockLastParse || {
      sourceRowCount: snapshot.source_row_count,
      validRowCount: snapshot.valid_row_count,
      invalidRowCount: snapshot.invalid_row_count,
      rows,
    }, rows.length);
    setSellpiaLatestStatus(`최신 셀피아 재고 불러오기 완료: ${snapshot.source_file_name} 기준 ${rows.length.toLocaleString()}행 (${new Date(snapshot.created_at).toLocaleString("ko-KR")}).`);
    return rows;
  } catch (error) {
    console.error(error);
    if (!silent) setSellpiaLatestStatus(`최신 셀피아 재고 불러오기 실패: ${error.message}`);
    return [];
  }
}

function sellpiaLatestStockForSku(sku) {
  const key = String(sku || "").trim();
  return key ? sellpiaStockBySku.get(key) : null;
}

function sellpiaStockCandidateValue(row) {
  if (!row) return "";
  const value = row.available_stock ?? row.integrated_available_stock ?? row.stock;
  return value == null ? "" : String(value);
}

const SELLER_TEMPLATE_DB_NAME = "product_ops_seller_templates_v1";
const SELLER_TEMPLATE_STORE_NAME = "templates";
const SELLER_TEMPLATE_CHANNELS = ["smartstore", "makeshop", "ably"];
const SELLER_BUILTIN_TEMPLATES = {
  smartstore: {
    fileName: "스마트스토어_ALL_변경양식.xlsx",
    url: "templates/smartstore_original_template.xlsx",
  },
  makeshop: {
    fileName: "메이크샵_ALL_변경양식.xlsx",
    url: "templates/makeshop_original_template.xlsx",
  },
  ably: {
    fileName: "0624 에이블리 리스트 last (체크용).xlsx",
    url: "templates/ably_original_template.xlsx",
  },
};

async function getBuiltinSellerTemplate(channel) {
  const template = SELLER_BUILTIN_TEMPLATES[channel];
  if (!template) return null;
  try {
    const response = await fetch(template.url, { cache: "no-store" });
    if (!response.ok) return null;
    const buffer = await response.arrayBuffer();
    return { channel, fileName: template.fileName, buffer };
  } catch (error) {
    console.warn("기본 원본양식 불러오기 실패", channel, error);
    return null;
  }
}

function setSellerTemplateStatus(message, isError = false) {
  if (!sellerTemplateStatus) return;
  sellerTemplateStatus.textContent = message;
  sellerTemplateStatus.classList.toggle("is-error", Boolean(isError));
}

function sellerTemplateChannelLabel(channel) {
  return {
    smartstore: "Smartstore",
    makeshop: "MakeShop",
    ably: "Ably",
  }[channel] || channel || "-";
}

function openSellerTemplateDb() {
  return new Promise((resolve, reject) => {
    if (!window.indexedDB) {
      reject(new Error("이 브라우저에서 IndexedDB 저장소를 사용할 수 없습니다."));
      return;
    }
    const request = indexedDB.open(SELLER_TEMPLATE_DB_NAME, 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(SELLER_TEMPLATE_STORE_NAME)) {
        db.createObjectStore(SELLER_TEMPLATE_STORE_NAME, { keyPath: "channel" });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error("템플릿 저장소를 열지 못했습니다."));
  });
}

async function sellerTemplateDbAction(mode, callback) {
  const db = await openSellerTemplateDb();
  try {
    return await new Promise((resolve, reject) => {
      const tx = db.transaction(SELLER_TEMPLATE_STORE_NAME, mode);
      const store = tx.objectStore(SELLER_TEMPLATE_STORE_NAME);
      let result;
      try {
        result = callback(store);
      } catch (error) {
        reject(error);
        return;
      }
      tx.oncomplete = () => resolve(result);
      tx.onerror = () => reject(tx.error || new Error("템플릿 저장소 작업에 실패했습니다."));
      tx.onabort = () => reject(tx.error || new Error("템플릿 저장소 작업이 중단되었습니다."));
    });
  } finally {
    db.close();
  }
}

function requestToPromise(request) {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error || new Error("저장소 요청에 실패했습니다."));
  });
}

async function getSellerTemplate(channel) {
  return sellerTemplateDbAction("readonly", (store) => requestToPromise(store.get(channel)));
}

async function listSellerTemplates() {
  return sellerTemplateDbAction("readonly", (store) => requestToPromise(store.getAll()));
}

async function putSellerTemplate(record) {
  return sellerTemplateDbAction("readwrite", (store) => requestToPromise(store.put(record)));
}

async function deleteSellerTemplate(channel) {
  return sellerTemplateDbAction("readwrite", (store) => requestToPromise(store.delete(channel)));
}

function sellerTemplateSummaryText(record) {
  if (!record) return "-";
  const dateText = record.savedAt ? new Date(record.savedAt).toLocaleDateString("ko-KR") : "";
  const rows = record.validation?.rowCount ? `${Number(record.validation.rowCount).toLocaleString()}행` : "";
  return [record.fileName, rows, dateText].filter(Boolean).join(" / ");
}

async function renderSellerTemplateSummary() {
  if (!sellerTemplatePreviewPanel) return;
  try {
    const rows = await listSellerTemplates();
    const byChannel = new Map((rows || []).map((row) => [row.channel, row]));
    SELLER_TEMPLATE_CHANNELS.forEach((channel) => {
      const id = {
        smartstore: "sellerTemplateSmartstore",
        makeshop: "sellerTemplateMakeshop",
        ably: "sellerTemplateAbly",
      }[channel];
      const el = document.getElementById(id);
      if (el) el.textContent = sellerTemplateSummaryText(byChannel.get(channel));
    });
    sellerTemplatePreviewPanel.hidden = false;
  } catch (error) {
    console.warn("seller template summary failed", error);
  }
}

async function validateSellerTemplate(channel, buffer) {
  if (!window.ExcelJS) {
    return { status: "WARN", message: "XLSX 파서를 아직 불러오지 못했습니다.", rowCount: 0, columnCount: 0 };
  }
  const workbook = new window.ExcelJS.Workbook();
  await workbook.xlsx.load(buffer.slice(0));
  const worksheet = workbook.worksheets[0];
  if (!worksheet) {
    return { status: "ERROR", message: "시트를 찾지 못했습니다.", rowCount: 0, columnCount: 0 };
  }
  let columns = {};
  if (channel === "smartstore") columns = findSmartstoreColumns(worksheet);
  if (channel === "makeshop") columns = findMakeshopColumns(worksheet);
  if (channel === "ably") columns = findAblyColumns(worksheet);
  const pass = channel === "smartstore"
    ? Boolean(columns.productNo && columns.optionCode && columns.optionStock)
    : channel === "makeshop"
      ? Boolean(columns.productUid && columns.stoId && columns.stoStock)
      : Boolean(columns.productCode && columns.optionCode && columns.stock);
  return {
    status: pass ? "PASS" : "WARN",
    message: pass ? "필수 컬럼 확인 완료" : "필수 컬럼 일부를 찾지 못했습니다. 저장은 가능하지만 자동 반영은 실패할 수 있습니다.",
    worksheetName: worksheet.name,
    rowCount: worksheet.rowCount,
    columnCount: worksheet.columnCount,
    columns,
  };
}

async function saveSellerTemplateFromInput() {
  const channel = sellerTemplateChannel?.value || "smartstore";
  const file = sellerTemplateInput?.files?.[0];
  if (!file) {
    alert("저장할 원본/템플릿 XLSX를 먼저 선택해 주세요.");
    return;
  }
  if (!SELLER_TEMPLATE_CHANNELS.includes(channel)) {
    alert("지원하지 않는 판매처입니다.");
    return;
  }
  try {
    if (sellerTemplateSaveButton) sellerTemplateSaveButton.disabled = true;
    setSellerTemplateStatus(`${sellerTemplateChannelLabel(channel)} 템플릿 분석 중...`);
    const buffer = await file.arrayBuffer();
    const validation = await validateSellerTemplate(channel, buffer);
    await putSellerTemplate({
      channel,
      fileName: file.name,
      fileSize: file.size,
      mimeType: file.type || "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      savedAt: new Date().toISOString(),
      validation,
      buffer,
    });
    await renderSellerTemplateSummary();
    setSellerTemplateStatus(
      `${sellerTemplateChannelLabel(channel)} 저장 완료: ${file.name} / ${validation.rowCount.toLocaleString()}행 / ${validation.message}`,
      validation.status === "ERROR"
    );
  } catch (error) {
    console.error(error);
    setSellerTemplateStatus(`템플릿 저장 실패: ${error.message}`, true);
    alert(`템플릿 저장 실패: ${error.message}`);
  } finally {
    if (sellerTemplateSaveButton) sellerTemplateSaveButton.disabled = false;
  }
}

async function showSelectedSellerTemplate() {
  const channel = sellerTemplateChannel?.value || "smartstore";
  try {
    const record = await getSellerTemplate(channel);
    await renderSellerTemplateSummary();
    if (!record) {
      setSellerTemplateStatus(`${sellerTemplateChannelLabel(channel)} 저장본이 없습니다.`);
      return;
    }
    setSellerTemplateStatus(
      `${sellerTemplateChannelLabel(channel)} 저장본: ${record.fileName} / ${Number(record.validation?.rowCount || 0).toLocaleString()}행 / 저장 ${new Date(record.savedAt).toLocaleString("ko-KR")}`
    );
  } catch (error) {
    setSellerTemplateStatus(`저장본 확인 실패: ${error.message}`, true);
  }
}

async function clearSelectedSellerTemplate() {
  const channel = sellerTemplateChannel?.value || "smartstore";
  await deleteSellerTemplate(channel);
  await renderSellerTemplateSummary();
  setSellerTemplateStatus(`${sellerTemplateChannelLabel(channel)} 저장본을 삭제했습니다.`);
}

function sellpiaStockOverrideFor(apply, compare) {
  const sku = String(apply?.sellpia_sku_code || compare?.sellpia_sku_code || "").trim();
  const latest = sellpiaLatestStockForSku(sku);
  if (!latest) return null;
  return {
    latest,
    proposedStock: sellpiaStockCandidateValue(latest),
    sellpiaProductCode: latest.sellpia_product_code || apply?.sellpia_product_code || compare?.sellpia_product_code || sellpiaProductCodeFromSku(sku),
    sellpiaSkuCode: sku,
    sellpiaProductName: latest.sellpia_product_name || apply?.sellpia_product_name || compare?.sellpia_product_name || "",
    sellpiaOptionName: latest.sellpia_option_name || apply?.sellpia_option_name || compare?.sellpia_option_name || "",
    sourceLabel: "supabase_latest_sellpia_stock",
  };
}

async function loadImageAssets(rows) {
  const codes = [
    ...new Set(rows.map((row) => row.best_sellpia_sku_code).filter(Boolean)),
  ];

  imageMap = new Map();
  if (!codes.length) return;

  for (const codeChunk of chunkArray(codes, IMAGE_ASSET_LOOKUP_BATCH_SIZE)) {
    const { data, error } = await supabaseClient
      .from("sellpia_product_images_public")
      .select("p_code,original_file_name,storage_public_url,source_image_url,upload_status")
      .in("p_code", codeChunk);

    if (error) {
      console.warn("image asset lookup failed", error);
      continue;
    }
    (data || []).forEach((row) => imageMap.set(row.p_code, row));
  }
}

async function loadDetails(queueId) {
  if (detailCache.has(queueId)) return detailCache.get(queueId);

  const { data, error } = await supabaseClient
    .from(DETAILS_VIEW)
    .select(
      "candidate_rank,sellpia_product_code,sellpia_sku_code,sellpia_product_name,sellpia_option_name,match_score,match_reason,risk_flags"
    )
    .eq("queue_id", queueId)
    .order("candidate_rank", { ascending: true })
    .limit(50);

  if (error) {
    console.error(error);
    return [];
  }
  detailCache.set(queueId, data || []);
  return data || [];
}

const EDITABLE_QUEUE_FIELDS = new Set([
  "channel_product_name",
  "channel_option_name",
  "best_sellpia_product_name",
  "best_sellpia_option_name",
]);

function fieldLabel(field) {
  return {
    channel_product_code: "판매처 상품코드",
    channel_option_code: "판매처 옵션코드",
    channel_product_name: "판매처 상품명",
    channel_option_name: "판매처 옵션명",
    best_sellpia_product_code: "Sellpia 상품코드",
    best_sellpia_sku_code: "Sellpia 옵션코드",
    best_sellpia_product_name: "Sellpia 상품명",
    best_sellpia_option_name: "Sellpia 옵션명",
    recommended_action: "판정/액션",
    match_reason: "매칭 사유",
  }[field] || field;
}

function evidenceArray(row, key) {
  const evidence = row?.evidence_json || {};
  const value = evidence[key];
  return Array.isArray(value) ? value : [];
}

function isFieldEdited(row, field) {
  return evidenceArray(row, "local_html_cell_edits").some((item) => item?.field_name === field);
}

function latestLinkDecision(row) {
  const decisions = evidenceArray(row, "local_html_link_decision");
  const discontinued = evidenceArray(row, "local_html_discontinue_decision");
  if (discontinued.length) return { ...discontinued[discontinued.length - 1], decision: "discontinue" };
  return decisions.length ? decisions[decisions.length - 1] : null;
}

function linkDecisionBadge(row) {
  const latest = latestLinkDecision(row);
  if (!latest?.decision) return "";
  const label = latest.decision === "discontinue"
    ? "단종/제외 처리됨"
    : latest.decision === "unlink"
      ? "연동 해제됨"
      : "수동 연동됨";
  const tone = latest.decision === "discontinue" || latest.decision === "unlink" ? "is-unlinked" : "is-linked";
  return `<em class="manual-decision-badge ${tone}">${escapeHtml(label)}</em>`;
}

function renderEditableValue(row, field, value, tagName = "span", extraClass = "") {
  if (!row?.queue_id || !EDITABLE_QUEUE_FIELDS.has(field)) {
    return `<${tagName} class="${extraClass}">${escapeHtml(value || "-")}</${tagName}>`;
  }
  const edited = isFieldEdited(row, field);
  return `
    <${tagName} class="editable-value ${extraClass} ${edited ? "is-edited" : ""}">
      <span class="editable-text">${escapeHtml(value || "-")}</span>
      ${edited ? "<em class=\"edited-badge\">수정됨</em>" : ""}
      <button
        type="button"
        class="cell-edit-button"
        title="${escapeHtml(fieldLabel(field))} 수정"
        data-edit-field="${escapeHtml(field)}"
        data-queue-id="${escapeHtml(row.queue_id)}"
        data-current-value="${escapeHtml(value || "")}"
      >수정</button>
    </${tagName}>
  `;
}

function editableMemoValue(row, field) {
  return String(row?.[field] ?? "");
}

function extractOwnCodes(value) {
  const text = String(value || "");
  return [...text.matchAll(/[A-Z]{1,5}-[0-9A-Z]+(?:-[0-9A-Z]+)*(?:_[0-9]+)?/g)]
    .map((match) => match[0])
    .filter(Boolean);
}

function ownCodeForRow(row) {
  const direct = String(row?.channel_seller_code || "").trim();
  if (direct) return direct;
  const sources = [
    row?.channel_option_name,
    row?.best_sellpia_option_name,
    row?.channel_product_name,
    row?.best_sellpia_product_name,
  ];
  for (const source of sources) {
    const codes = extractOwnCodes(source);
    if (codes.length) return codes[codes.length - 1];
  }
  return "";
}

function tierLabel(tier) {
  return {
    AUTO_APPROVE_CANDIDATE: "자동승인 후보",
    MATCH_CANDIDATE: "매칭 후보",
    FAST_REVIEW: "빠른검토",
    DUPLICATE_REVIEW: "중복검토",
    NO_MATCH: "매칭없음",
  }[tier] || tier || "-";
}

function stockStatusForRow(row) {
  return row.stock_compare_status || "";
}

function stockStatusLabel(status) {
  return {
    STOCK_MATCH: "재고 일치",
    STOCK_DIFF: "재고 불일치",
    STOCK_HOLD_REVIEW: "검토 보류",
    STOCK_SMARTSTORE_NOT_FOUND: "현재 옵션 없음",
  }[status] || "전체";
}

function workflowBucket(row) {
  const text = [
    row?.match_tier,
    row?.recommended_action,
    row?.match_reason,
    row?.duplicate_risk,
    row?.channel_product_name,
    row?.channel_option_name,
  ].join(" ").toLowerCase();

  if ((row?.match_tier || "").toUpperCase() === "NO_MATCH") return "no_match";
  if (/(단종|삭제|제외|excluded|discontinued|hidden)/i.test(text)) return "excluded";
  if (/(세트|조합|bundle|set\b)/i.test(text)) return "bundle";
  if (/(보조옵션|보조 옵션|하위옵션|suboption|추가상품)/i.test(text)) return "suboption";
  if (/(코드 근거|코드공란|코드 공란|자사코드 공란|code blank|blank code)/i.test(text)) return "code_blank";
  if (["AUTO_APPROVE_CANDIDATE", "FAST_REVIEW", "MANUAL_LINKED"].includes(row?.match_tier)) return "candidate";
  if (stockStatusForRow(row) === "STOCK_MATCH") return "stock_match";
  if (stockStatusForRow(row) === "STOCK_DIFF") return "stock_diff";
  if (stockStatusForRow(row) === "STOCK_SMARTSTORE_NOT_FOUND") return "stock_missing";
  if (row?.review_required || ["REVIEW", "FAST_REVIEW", "DUPLICATE_REVIEW"].includes(row?.match_tier)) return "hold";
  return "hold";
}

function workflowBucketLabel(bucket) {
  return {
    candidate: "확정 매핑 후보",
    hold: "확인 필요",
    code_blank: "코드 공란",
    no_match: "순수 미매칭",
    excluded: "단종/삭제 제외",
    bundle: "조합형/세트 후보",
    suboption: "보조 하위옵션",
    stock_match: "재고 일치",
    stock_diff: "재고 불일치",
    stock_missing: "미연결",
  }[bucket] || bucket || "확인 필요";
}

function groupWorkflowBucket(group) {
  const priority = ["excluded", "no_match", "bundle", "suboption", "code_blank", "stock_diff", "stock_missing", "hold", "candidate", "stock_match"];
  const rows = group?.rows?.length ? group.rows : [group?.primaryRow || group].filter(Boolean);
  const buckets = new Set(rows.map((row) => workflowBucket(row)));
  return priority.find((bucket) => buckets.has(bucket)) || "hold";
}

function workflowClass(rowOrGroup) {
  const bucket = rowOrGroup?.rows ? groupWorkflowBucket(rowOrGroup) : workflowBucket(rowOrGroup);
  return `workflow-${bucket}`;
}

function isBlankCellValue(value) {
  return value == null || String(value).trim() === "" || String(value).trim() === "-";
}

function hasChannelEvidence(row, fieldName = "") {
  if (!row) return false;
  const productEvidence = [
    row.channel_option_code,
    row.channel_product_name,
    row.channel_option_name,
    row.best_sellpia_product_code,
    row.best_sellpia_sku_code,
  ];
  const optionEvidence = [
    row.channel_product_code,
    row.channel_product_name,
    row.channel_option_name,
    row.best_sellpia_product_code,
    row.best_sellpia_sku_code,
  ];
  const allEvidence = [
    row.channel_product_code,
    row.channel_option_code,
    row.channel_product_name,
    row.channel_option_name,
    row.match_reason,
    row.recommended_action,
  ];
  const values = fieldName === "channel_product_code"
    ? productEvidence
    : fieldName === "channel_option_code"
      ? optionEvidence
      : allEvidence;
  return values.some((item) => !isBlankCellValue(item));
}

function codeCellClass(row, fieldName, value) {
  return isBlankCellValue(value) && hasChannelEvidence(row, fieldName) ? "code-blank-cell" : "";
}

function statusCellClass(row) {
  const bucket = workflowBucket(row);
  if (bucket === "excluded") return "excluded-cell";
  if (bucket === "no_match") return "unmatched-cell";
  if (bucket === "bundle") return "bundle-cell";
  if (bucket === "suboption") return "suboption-cell";
  if (bucket === "stock_diff") return "issue-cell";
  if (bucket === "stock_missing") return "stock-missing-cell";
  if (bucket === "hold") return "issue-cell";
  if (bucket === "candidate" || bucket === "stock_match") return "match-cell";
  return "";
}

function channelProblemClass(row, fieldName, value) {
  const bucket = workflowBucket(row);
  if (bucket === "excluded") return "excluded-cell";
  if (bucket === "no_match") return "unmatched-cell";
  if (bucket === "bundle") return "bundle-cell";
  if (bucket === "suboption") return "suboption-cell";
  return "";
}

function policyApprovalTier(row) {
  const duplicateCount = Number(row.duplicate_candidate_count || 0);
  const reason = String(row.match_reason || "");
  if (row.match_tier === "AUTO_APPROVE_CANDIDATE") {
    return {
      tier: "AUTO_APPROVE_CANDIDATE",
      label: "자동승인 후보",
      reason: "정규화 옵션/기존 승인 근거가 강하고 중복 후보가 없습니다.",
    };
  }
  if (
    row.match_tier === "FAST_REVIEW" &&
    duplicateCount <= 3 &&
    reason.includes("existing_auto_evidence") &&
    (reason.includes("normalized_option_exact") || reason.includes("normalized_option_contains"))
  ) {
    return {
      tier: "APPROVAL_CANDIDATE_CODE_EVIDENCE_WEAK",
      label: "승인후보(코드근거 약함)",
      reason: "코드 근거는 약하지만 옵션 정규화와 기존 자동승인 근거가 있어 승인후보로 검토 가능합니다.",
    };
  }
  if (row.match_tier === "FAST_REVIEW") {
    return {
      tier: "FAST_REVIEW_REQUIRED",
      label: "빠른검토",
      reason: "사람이 한 번 확인해야 하는 후보입니다.",
    };
  }
  return {
    tier: row.match_tier || "",
    label: tierLabel(row.match_tier),
    reason: row.match_reason || "",
  };
}

function filteredRows() {
  const channel = channelFilter?.value || "";
  const tier = tierFilter.value;
  const term = searchInput.value.trim().toLowerCase();
  const imageOnly = imageOnlyFilter.checked;

  return queueRows.filter((row) => {
    if (!visibleChannels.has(row.source_channel)) return false;
    if (channel && row.source_channel !== channel) return false;
    if (tier && row.match_tier !== tier) return false;
    if (activeStockStatus && stockStatusForRow(row) !== activeStockStatus) return false;
    if (activeWorkflowFilter) {
      if (activeWorkflowFilter.startsWith("stock_")) {
        const statusMap = {
          stock_match: "STOCK_MATCH",
          stock_diff: "STOCK_DIFF",
          stock_missing: "STOCK_SMARTSTORE_NOT_FOUND",
        };
        if (stockStatusForRow(row) !== statusMap[activeWorkflowFilter]) return false;
      } else if (workflowBucket(row) !== activeWorkflowFilter) {
        return false;
      }
    }
    const bucket = workflowBucket(row);
    if (excludeExcludedRows && bucket === "excluded") return false;
    const isAblyExcluded = rowHasAblyExclusion(row);
    if (ablyExclusionFilter === "hide" && isAblyExcluded) return false;
    if (ablyExclusionFilter === "only" && !isAblyExcluded) return false;
    if (reviewModeFilter === "problem" && ["candidate", "stock_match"].includes(bucket)) return false;
    if (reviewModeFilter === "candidate" && !["candidate", "stock_match"].includes(bucket)) return false;
    if (activeTagNames.size) {
      const rowTagNames = new Set(row.manual_tag_names || []);
      for (const tagName of activeTagNames) {
        if (!rowTagNames.has(tagName)) return false;
      }
    }
    if (imageOnly && !row.has_sellpia_image && !imageMap.has(row.best_sellpia_sku_code)) return false;
    if (!term) return true;
    const blob = [
      row.channel_product_code,
      row.channel_option_code,
      row.channel_product_name,
      row.channel_option_name,
      row.channel_seller_code,
      ownCodeForRow(row),
      row.best_sellpia_product_code,
      row.best_sellpia_sku_code,
      row.best_sellpia_product_name,
      row.best_sellpia_option_name,
    ].join(" ").toLowerCase();
    return blob.includes(term);
  });
}

function renderDashboard() {
  if (queueSummary?.totals && queueSummary?.by_channel) {
    document.getElementById("queueTotal").textContent = numeric(queueSummary.totals.rows).toLocaleString();
    document.getElementById("detailTotal").textContent = numeric(queueSummary.totals.duplicate_detail_estimate).toLocaleString();
    document.getElementById("reviewRequiredTotal").textContent = numeric(queueSummary.totals.manual_scope_rows).toLocaleString();
    document.getElementById("imageLinkedTotal").textContent = numeric(queueSummary.totals.image_linked_rows).toLocaleString();

    const summary = document.getElementById("channelSummary");
    summary.innerHTML = "";
    ["smartstore", "makeshop", "ably", "coupang", "playauto"].forEach((channel) => {
      const count = numeric(queueSummary.by_channel[channel]?.rows);
      const item = document.createElement("div");
      item.className = "summary-item";
      item.innerHTML = `<strong>${channelName(channel)}</strong><span>${count.toLocaleString()} rows</span>`;
      summary.appendChild(item);
    });
    return;
  }

  const channelCounts = new Map();
  let reviewRequired = 0;
  let duplicateDetailEstimate = 0;
  let imageLinked = 0;

  queueRows.forEach((row) => {
    channelCounts.set(row.source_channel, (channelCounts.get(row.source_channel) || 0) + 1);
    if (row.review_required) reviewRequired += 1;
    if (row.has_sellpia_image || imageMap.has(row.best_sellpia_sku_code)) imageLinked += 1;
    duplicateDetailEstimate += Number(row.duplicate_candidate_count || 0);
  });

  document.getElementById("queueTotal").textContent = queueRows.length.toLocaleString();
  document.getElementById("detailTotal").textContent = duplicateDetailEstimate.toLocaleString();
  document.getElementById("reviewRequiredTotal").textContent = reviewRequired.toLocaleString();
  document.getElementById("imageLinkedTotal").textContent = imageLinked.toLocaleString();

  const summary = document.getElementById("channelSummary");
  summary.innerHTML = "";
  ["smartstore", "makeshop", "ably", "coupang", "playauto"].forEach((channel) => {
    const count = channelCounts.get(channel) || 0;
    const item = document.createElement("div");
    item.className = "summary-item";
    item.innerHTML = `<strong>${channelName(channel)}</strong><span>${count.toLocaleString()} rows</span>`;
    summary.appendChild(item);
  });
}

function renderStockSummary() {
  const summaryValue = (field) => sumSummaryField(field);
  if (queueSummary?.totals && summaryChannels()?.length) {
    const setText = (id, value) => {
      const el = document.getElementById(id);
      if (el) el.textContent = Number(value || 0).toLocaleString();
    };
    setText("workflowCandidateCount", summaryValue("workflow_candidate_rows"));
    setText("workflowHoldCount", summaryValue("workflow_hold_rows"));
    setText("workflowCodeBlankCount", summaryValue("workflow_code_blank_rows"));
    setText("workflowNoMatchCount", summaryValue("workflow_no_match_rows"));
    setText("workflowExcludedCount", summaryValue("workflow_excluded_rows"));
    setText("workflowBundleCount", summaryValue("workflow_bundle_rows"));
    setText("workflowSuboptionCount", summaryValue("workflow_suboption_rows"));
    setText("stockAllCount", numeric(queueSummary.by_channel?.smartstore?.smartstore_rows));
    setText("stockMatchCount", numeric(queueSummary.by_channel?.smartstore?.stock_match_rows));
    setText("stockDiffCount", numeric(queueSummary.by_channel?.smartstore?.stock_diff_rows));
    setText("stockHoldCount", numeric(queueSummary.by_channel?.smartstore?.stock_hold_rows));
    setText("stockMissingCount", numeric(queueSummary.by_channel?.smartstore?.stock_missing_rows));

    document.querySelectorAll("[data-workflow-filter]").forEach((card) => {
      card.classList.toggle("is-active", card.dataset.workflowFilter === activeWorkflowFilter);
    });
    return;
  }

  const visibleRows = queueRows.filter((row) => visibleChannels.has(row.source_channel));
  const countGroupedRows = (predicate) => groupedMatrixRows(visibleRows.filter(predicate)).length;
  const workflowCounts = {
    candidate: countGroupedRows((row) => workflowBucket(row) === "candidate"),
    hold: countGroupedRows((row) => workflowBucket(row) === "hold"),
    code_blank: countGroupedRows((row) => workflowBucket(row) === "code_blank"),
    no_match: countGroupedRows((row) => workflowBucket(row) === "no_match"),
    excluded: countGroupedRows((row) => workflowBucket(row) === "excluded"),
    bundle: countGroupedRows((row) => workflowBucket(row) === "bundle"),
    suboption: countGroupedRows((row) => workflowBucket(row) === "suboption"),
  };
  const counts = {
    all: countGroupedRows((row) => row.source_channel === "smartstore"),
    STOCK_MATCH: countGroupedRows((row) => row.source_channel === "smartstore" && stockStatusForRow(row) === "STOCK_MATCH"),
    STOCK_DIFF: countGroupedRows((row) => row.source_channel === "smartstore" && stockStatusForRow(row) === "STOCK_DIFF"),
    STOCK_HOLD_REVIEW: countGroupedRows((row) => row.source_channel === "smartstore" && stockStatusForRow(row) === "STOCK_HOLD_REVIEW"),
    STOCK_SMARTSTORE_NOT_FOUND: countGroupedRows((row) => row.source_channel === "smartstore" && stockStatusForRow(row) === "STOCK_SMARTSTORE_NOT_FOUND"),
  };

  const setText = (id, value) => {
    const el = document.getElementById(id);
    if (el) el.textContent = Number(value || 0).toLocaleString();
  };
  setText("workflowCandidateCount", workflowCounts.candidate);
  setText("workflowHoldCount", workflowCounts.hold);
  setText("workflowCodeBlankCount", workflowCounts.code_blank);
  setText("workflowNoMatchCount", workflowCounts.no_match);
  setText("workflowExcludedCount", workflowCounts.excluded);
  setText("workflowBundleCount", workflowCounts.bundle);
  setText("workflowSuboptionCount", workflowCounts.suboption);
  setText("stockAllCount", counts.all);
  setText("stockMatchCount", counts.STOCK_MATCH);
  setText("stockDiffCount", counts.STOCK_DIFF);
  setText("stockHoldCount", counts.STOCK_HOLD_REVIEW);
  setText("stockMissingCount", counts.STOCK_SMARTSTORE_NOT_FOUND);

  document.querySelectorAll("[data-workflow-filter]").forEach((card) => {
    card.classList.toggle("is-active", card.dataset.workflowFilter === activeWorkflowFilter);
  });
}

function visibleChannelList() {
  return SELLER_CHANNELS.filter((channel) => visibleChannels.has(channel));
}

function queueIdSetForGroup(group) {
  const primaryId = group?.primaryRow?.queue_id;
  return new Set(primaryId ? [String(primaryId)] : []);
}

function groupHasSelectedRow(group) {
  const ids = queueIdSetForGroup(group);
  if (!ids.size) return false;
  for (const id of ids) {
    if (selectedQueueIds.has(id)) return true;
  }
  return false;
}

function getCurrentPageGroups() {
  return pagedRows(groupedMatrixRows(filteredRows())).rows;
}

function setGroupSelection(group, selected) {
  queueIdSetForGroup(group).forEach((id) => {
    if (selected) selectedQueueIds.add(id);
    else selectedQueueIds.delete(id);
  });
}

function syncSelectedRowFromSelection(row) {
  selectedRow = row || selectedRow;
  if (selectedRow?.queue_id && !selectedQueueIds.size) {
    selectedQueueIds.add(String(selectedRow.queue_id));
  }
}

function updateSelectionSummaryText() {
  const count = selectedQueueIds.size;
  const prefix = count > 1 ? `선택 ${count.toLocaleString()}개 · ` : "";
  const text = selectedSummary?.querySelector("strong");
  if (text && prefix && !text.textContent.startsWith("선택 ")) {
    text.textContent = `${prefix}${text.textContent}`;
  }
}

function clearSelectionIfRowsChanged() {
  const liveIds = new Set(queueRows.map((row) => String(row.queue_id)));
  selectedQueueIds = new Set([...selectedQueueIds].filter((id) => liveIds.has(id)));
  if (selectedRow?.queue_id && !liveIds.has(String(selectedRow.queue_id))) {
    selectedRow = null;
  }
}

async function selectRow(row, tr, options = {}) {
  const pageIndex = Number.isInteger(options.pageIndex)
    ? options.pageIndex
    : Number.parseInt(tr?.dataset?.pageIndex || "-1", 10);
  const group = options.group || (Number.isInteger(pageIndex) ? getCurrentPageGroups()[pageIndex] : null);
  const event = options.event;
  const isToggle = Boolean(event?.ctrlKey || event?.metaKey);
  const isRange = Boolean(event?.shiftKey && Number.isInteger(lastSelectedPageIndex) && lastSelectedPageIndex >= 0);

  selectedRow = row;
  pendingTagIds = new Set();
  if (isRange) {
    const pageGroups = getCurrentPageGroups();
    const start = Math.min(lastSelectedPageIndex, pageIndex);
    const end = Math.max(lastSelectedPageIndex, pageIndex);
    selectedQueueIds = new Set();
    pageGroups.slice(start, end + 1).forEach((item) => setGroupSelection(item, true));
  } else if (isToggle) {
    if (groupHasSelectedRow(group)) {
      setGroupSelection(group, false);
    } else {
      setGroupSelection(group, true);
    }
    lastSelectedPageIndex = pageIndex;
  } else {
    selectedQueueIds = new Set();
    setGroupSelection(group, true);
    lastSelectedPageIndex = pageIndex;
  }

  syncSelectedRowFromSelection(row);
  document.querySelectorAll("#queueTable tr.is-selected").forEach((el) => el.classList.remove("is-selected"));
  document.querySelectorAll("#queueTable tbody tr").forEach((rowEl) => {
    const index = Number.parseInt(rowEl.dataset.pageIndex || "-1", 10);
    const pageGroup = getCurrentPageGroups()[index];
    rowEl.classList.toggle("is-selected", groupHasSelectedRow(pageGroup));
  });

  const selectedImage = rowImage(row);
  const selectedCount = selectedQueueIds.size;
  selectedSummary.className = "selected-summary";
  selectedSummary.innerHTML = `
    <strong>${selectedCount > 1 ? `선택 ${selectedCount.toLocaleString()}개 · ` : ""}${escapeHtml(channelName(row.source_channel))} / ${escapeHtml(policyApprovalTier(row).label)}</strong>
    ${selectedCount > 1 ? "<p><b>다중 선택</b> Shift 범위 선택 / Ctrl·Meta 개별 선택 상태입니다. 태그 적용은 선택된 행 전체에 적용됩니다.</p>" : ""}
    ${renderImageAsset(selectedImage)}
    <p><b>판매처 상품</b> ${escapeHtml(row.channel_product_name || row.channel_product_code || "-")}</p>
    <p><b>판매처 옵션</b> ${escapeHtml(row.channel_option_name || row.channel_option_code || "-")}</p>
    <p><b>자사코드</b> ${escapeHtml(ownCodeForRow(row) || "-")}</p>
    <p><b>Sellpia</b> ${escapeHtml(row.best_sellpia_product_name || "-")} / ${escapeHtml(row.best_sellpia_option_name || "-")}</p>
    <p><b>Sellpia 코드</b> ${escapeHtml(row.best_sellpia_sku_code || row.best_sellpia_product_code || "-")}</p>
    <p><b>재고대조 상태</b> ${escapeHtml(stockStatusLabel(stockStatusForRow(row)))}</p>
    <p><b>중복 후보</b> ${Number(row.duplicate_candidate_count || 0).toLocaleString()}</p>
    <p><b>판정 근거</b> ${escapeHtml(policyApprovalTier(row).reason)}</p>
    ${linkDecisionBadge(row)}
  `;
  appendSelectedMeta(row);
  renderSelectedTags(row);
  if (addTagButton) addTagButton.disabled = pendingTagIds.size === 0;

  candidateDetails.innerHTML = "<p class='empty'>상세 후보 조회 중...</p>";
  const details = await loadDetails(row.queue_id);
  candidateDetails.innerHTML = "";
  renderDecisionControls(row, details);

  if (!details.length) {
    candidateDetails.innerHTML = `
      <p class='empty'>상세 후보가 없습니다. 오른쪽 결정 패널의 검색으로 현재 로드된 Sellpia 옵션을 찾아 연동할 수 있습니다.</p>
    `;
    return;
  }

  details.forEach((detail) => {
    const image = imageMap.get(detail.sellpia_sku_code);
    const canLinkCandidate = APP_MODE === "review";
    const item = document.createElement("div");
    item.className = "candidate-card";
    item.innerHTML = `
      <strong>#${detail.candidate_rank} ${escapeHtml(detail.sellpia_sku_code || "")}</strong>
      ${renderImageAsset(image)}
      <span>${Number(detail.match_score || 0).toLocaleString()}점</span>
      <p>${escapeHtml(detail.sellpia_product_name || "")}</p>
      <p>${escapeHtml(detail.sellpia_option_name || "")}</p>
      <small>${escapeHtml(detail.match_reason || "")} ${escapeHtml(detail.risk_flags || "")}</small>
      <button
        type="button"
        class="link-candidate-button"
        data-link-candidate="true"
        data-sellpia-product-code="${escapeHtml(detail.sellpia_product_code || "")}"
        data-sellpia-sku-code="${escapeHtml(detail.sellpia_sku_code || "")}"
        data-sellpia-product-name="${escapeHtml(detail.sellpia_product_name || "")}"
        data-sellpia-option-name="${escapeHtml(detail.sellpia_option_name || "")}"
        ${canLinkCandidate ? "" : "disabled"}
        title="${canLinkCandidate ? "Sellpia 옵션으로 연동" : "READ-ONLY 모드에서는 저장이 차단됩니다."}"
      >이 Sellpia 옵션으로 연동</button>
    `;
    candidateDetails.appendChild(item);
  });
}

function renderTableHeader() {
  if (!queueTableHeadRow) return;
  const sellerColumns = visibleChannelList()
    .map((channel) => `
      <th class="channel-group channel-start is-${channel}" data-channel="${channel}">${escapeHtml(channelName(channel))} 상품</th>
      <th class="channel-group is-${channel}" data-channel="${channel}">${escapeHtml(channelName(channel))} 옵션</th>
      <th class="channel-group channel-end is-${channel}" data-channel="${channel}">판정/액션</th>
    `)
    .join("");

  queueTableHeadRow.innerHTML = `
    <th class="sticky-col" data-channel="sellpia">Sellpia 코드</th>
    <th class="sellpia-col">Sellpia 상품명</th>
    <th class="sellpia-col">Sellpia 옵션명</th>
    <th>상태</th>
    ${sellerColumns}
    <th>이미지</th>
    <th>중복 후보</th>
  `;
}

function renderChannelCells(row) {
  const channelRows = row.channels || {};
  return visibleChannelList()
    .map((channel) => {
      const channelRow = channelRows[channel] || (row.source_channel === channel ? row : null);
      if (!channelRow) {
        return `
          <td class="channel-cell channel-start is-empty is-${channel}" data-channel="${channel}">-</td>
          <td class="channel-cell is-empty is-${channel}" data-channel="${channel}">-</td>
          <td class="channel-cell channel-end is-empty is-${channel}" data-channel="${channel}">-</td>
        `;
      }
      return `
        <td class="channel-cell channel-start is-${channel} ${channelProblemClass(channelRow, "channel_product_code", channelRow.channel_product_code)}" data-channel="${channel}" data-queue-id="${escapeHtml(channelRow.queue_id)}">
          <strong class="${codeCellClass(channelRow, "channel_product_code", channelRow.channel_product_code)}">${escapeHtml(channelRow.channel_product_code || "-")}</strong>
          <span>${escapeHtml(channelRow.channel_product_name || "")}</span>
        </td>
        <td class="channel-cell is-${channel} ${channelProblemClass(channelRow, "channel_option_code", channelRow.channel_option_code)}" data-channel="${channel}" data-queue-id="${escapeHtml(channelRow.queue_id)}">
          <strong class="${codeCellClass(channelRow, "channel_option_code", channelRow.channel_option_code)}">${escapeHtml(channelRow.channel_option_code || "-")}</strong>
          <span>${escapeHtml(channelRow.channel_option_name || "")}</span>
        </td>
        <td class="channel-cell channel-end is-${channel} ${statusCellClass(channelRow)}" data-channel="${channel}" data-queue-id="${escapeHtml(channelRow.queue_id)}">
          <strong>${escapeHtml(channelRow.recommended_action || stockStatusLabel(stockStatusForRow(channelRow)))}</strong>
          <span>${escapeHtml(channelRow.match_reason || "")}</span>
        </td>
      `;
    })
    .join("");
}

function sellpiaGroupKey(row) {
  return [
    row.best_sellpia_sku_code || row.best_sellpia_product_code || "no-sellpia",
    row.best_sellpia_option_name || "",
  ].join("::");
}

function groupedMatrixRows(rows) {
  const groups = new Map();
  rows.forEach((row) => {
    const key = sellpiaGroupKey(row);
    if (!groups.has(key)) {
      groups.set(key, {
        group_id: key,
        rows: [],
        channels: {},
        primaryRow: row,
        best_sellpia_sku_code: row.best_sellpia_sku_code,
        best_sellpia_product_code: row.best_sellpia_product_code,
        best_sellpia_product_name: row.best_sellpia_product_name,
        best_sellpia_option_name: row.best_sellpia_option_name,
        manual_tags: row.manual_tags || [],
        sellpia_tags: row.sellpia_tags || [],
        duplicate_candidate_count: 0,
        match_tier: row.match_tier,
        source_channel: row.source_channel,
      });
    }
    const group = groups.get(key);
    group.rows.push(row);
    group.channels[row.source_channel] = row;
    group.duplicate_candidate_count += Number(row.duplicate_candidate_count || 0);
    if (row.has_sellpia_image || !group.primaryRow?.has_sellpia_image) {
      group.primaryRow = row;
    }
    if ((row.manual_tags || []).length > (group.manual_tags || []).length) {
      group.manual_tags = row.manual_tags;
    }
    group.sellpia_tags = mergeTagLists(group.sellpia_tags || [], row.sellpia_tags || []);
  });
  return [...groups.values()];
}

function rowByQueueId(queueId) {
  return queueRows.find((row) => String(row.queue_id) === String(queueId));
}

function renderTable() {
  const rows = filteredRows();
  const matrixRows = groupedMatrixRows(rows);
  const page = pagedRows(matrixRows);
  renderTableHeader();
  const visibleCount = document.getElementById("visibleCount");
  if (visibleCount) {
    if (page.total) {
          visibleCount.textContent = `${(page.start + 1).toLocaleString()}-${page.end.toLocaleString()} / ${page.total.toLocaleString()}`;
    } else {
      visibleCount.textContent = "0";
    }
  }
  renderPager(page);
  queueTableBody.innerHTML = "";

  if (!page.rows.length) {
    const colSpan = 6 + visibleChannelList().length * 3;
    queueTableBody.innerHTML = `<tr><td colspan="${colSpan}">현재 필터에 맞는 행이 없습니다.</td></tr>`;
    return;
  }

  page.rows.forEach((group, pageIndex) => {
    const row = group.primaryRow;
    const image = rowImage(row);
    const approval = policyApprovalTier(row);
    const tr = document.createElement("tr");
    tr.dataset.tier = group.match_tier;
    tr.dataset.channel = row.source_channel;
    tr.dataset.workflowBucket = groupWorkflowBucket(group);
    tr.dataset.pageIndex = String(pageIndex);
    tr.innerHTML = `
      <td class="sticky-col">
        <strong>${escapeHtml(group.best_sellpia_sku_code || group.best_sellpia_product_code || "-")}</strong>
        ${renderTagBadges(group.manual_tags, "mini-tags")}
        ${renderTagBadges(group.sellpia_tags, "mini-tags sellpia-shared-tags")}
      </td>
      <td class="sellpia-col">${escapeHtml(group.best_sellpia_product_name || group.best_sellpia_product_code || "")}</td>
      <td class="sellpia-col">${escapeHtml(group.best_sellpia_option_name || group.best_sellpia_sku_code || "")}</td>
      <td><span class="tier">${escapeHtml(approval.label)}</span></td>
      ${renderChannelCells(group)}
      <td>${image ? renderImageThumb(image) : "<span class='muted'>없음</span>"}</td>
      <td>${Number(group.duplicate_candidate_count || 0).toLocaleString()}</td>
    `;
    tr.addEventListener("click", (event) => {
      const channelCell = event.target.closest("[data-queue-id]");
      const targetRow = channelCell ? rowByQueueId(channelCell.dataset.queueId) : row;
      selectRow(targetRow || row, tr);
    });
    if (group.rows.some((item) => selectedRow?.queue_id === item.queue_id)) {
      tr.classList.add("is-selected");
    }
    queueTableBody.appendChild(tr);
  });
}

async function selectRow(row, tr) {
  selectedRow = row;
  pendingTagIds = new Set();
  document.querySelectorAll("#queueTable tr.is-selected").forEach((el) => el.classList.remove("is-selected"));
  tr.classList.add("is-selected");

  const selectedImage = rowImage(row);
  selectedSummary.className = "selected-summary";
  selectedSummary.innerHTML = `
    <strong>${escapeHtml(channelName(row.source_channel))} / ${escapeHtml(policyApprovalTier(row).label)}</strong>
    ${renderImageAsset(selectedImage)}
    <p><b>판매처 상품</b> ${escapeHtml(row.channel_product_name || row.channel_product_code || "-")}</p>
    <p><b>판매처 옵션</b> ${escapeHtml(row.channel_option_name || row.channel_option_code || "-")}</p>
    <p><b>Sellpia</b> ${escapeHtml(row.best_sellpia_product_name || "-")} / ${escapeHtml(row.best_sellpia_option_name || "-")}</p>
    <p><b>Sellpia 코드</b> ${escapeHtml(row.best_sellpia_sku_code || "-")}</p>
    <p><b>재고대조 상태</b> ${escapeHtml(stockStatusLabel(stockStatusForRow(row)))}</p>
    <p><b>중복 후보</b> ${Number(row.duplicate_candidate_count || 0).toLocaleString()}</p>
    <p><b>정책 판단</b> ${escapeHtml(policyApprovalTier(row).reason)}</p>
  `;
  appendSelectedMeta(row);
  renderSelectedTags(row);
  if (addTagButton) addTagButton.disabled = pendingTagIds.size === 0;

  candidateDetails.innerHTML = "<p class='empty'>상세 후보 조회 중...</p>";
  const details = await loadDetails(row.queue_id);
  candidateDetails.innerHTML = "";

  if (!details.length) {
    candidateDetails.innerHTML = "<p class='empty'>상세 후보 없음</p>";
    return;
  }

  details.forEach((detail) => {
    const image = imageMap.get(detail.sellpia_sku_code);
    const item = document.createElement("div");
    item.className = "candidate-card";
    item.innerHTML = `
      <strong>#${detail.candidate_rank} ${escapeHtml(detail.sellpia_sku_code || "")}</strong>
      ${renderImageAsset(image)}
      <span>${Number(detail.match_score || 0).toLocaleString()}점</span>
      <p>${escapeHtml(detail.sellpia_product_name || "")}</p>
      <p>${escapeHtml(detail.sellpia_option_name || "")}</p>
      <small>${escapeHtml(detail.match_reason || "")} ${escapeHtml(detail.risk_flags || "")}</small>
    `;
    candidateDetails.appendChild(item);
  });
}

function renderTableHeader() {
  if (!queueTableHeadRow) return;
  const sellerColumns = visibleChannelList()
    .map((channel) => `
      <th class="channel-group channel-start is-${channel}" data-channel="${channel}">${escapeHtml(channelName(channel))} 상품</th>
      <th class="channel-group is-${channel}" data-channel="${channel}">${escapeHtml(channelName(channel))} 옵션</th>
      <th class="channel-group channel-end is-${channel}" data-channel="${channel}">판정/액션</th>
    `)
    .join("");

  queueTableHeadRow.innerHTML = `
    <th class="sticky-col sticky-sellpia-code" data-channel="sellpia">Sellpia 코드</th>
    <th class="sticky-col sticky-sellpia-product sellpia-col">Sellpia 상품명</th>
    <th class="sticky-col sticky-sellpia-option sellpia-col">Sellpia 옵션명</th>
    <th class="sticky-col sticky-sellpia-status">상태</th>
    ${sellerColumns}
    <th>이미지</th>
    <th>중복 후보</th>
  `;
}

function renderChannelCells(row) {
  const channelRows = row.channels || {};
  return visibleChannelList()
    .map((channel) => {
      const channelRow = channelRows[channel] || (row.source_channel === channel ? row : null);
      if (!channelRow) {
        return `
          <td class="channel-cell channel-start is-empty is-${channel}" data-channel="${channel}">-</td>
          <td class="channel-cell is-empty is-${channel}" data-channel="${channel}">-</td>
          <td class="channel-cell channel-end is-empty is-${channel}" data-channel="${channel}">-</td>
        `;
      }
      return `
        <td class="channel-cell channel-start is-${channel} ${channelProblemClass(channelRow, "channel_product_code", channelRow.channel_product_code)}" data-channel="${channel}" data-queue-id="${escapeHtml(channelRow.queue_id)}">
          ${renderEditableValue(channelRow, "channel_product_code", channelRow.channel_product_code || "-", "strong", codeCellClass(channelRow, "channel_product_code", channelRow.channel_product_code))}
          ${ownCodeForRow(channelRow) ? `<em class="own-code-badge">자사 ${escapeHtml(ownCodeForRow(channelRow))}</em>` : ""}
          ${renderEditableValue(channelRow, "channel_product_name", channelRow.channel_product_name || "", "span")}
        </td>
        <td class="channel-cell is-${channel} ${channelProblemClass(channelRow, "channel_option_code", channelRow.channel_option_code)}" data-channel="${channel}" data-queue-id="${escapeHtml(channelRow.queue_id)}">
          ${renderEditableValue(channelRow, "channel_option_code", channelRow.channel_option_code || "-", "strong", codeCellClass(channelRow, "channel_option_code", channelRow.channel_option_code))}
          ${ownCodeForRow(channelRow) ? `<em class="own-code-badge">자사 ${escapeHtml(ownCodeForRow(channelRow))}</em>` : ""}
          ${renderEditableValue(channelRow, "channel_option_name", channelRow.channel_option_name || "", "span")}
        </td>
        <td class="channel-cell channel-end is-${channel} ${statusCellClass(channelRow)}" data-channel="${channel}" data-queue-id="${escapeHtml(channelRow.queue_id)}">
          ${renderEditableValue(channelRow, "recommended_action", channelRow.recommended_action || stockStatusLabel(stockStatusForRow(channelRow)), "strong")}
          ${renderEditableValue(channelRow, "match_reason", channelRow.match_reason || "", "span")}
          ${linkDecisionBadge(channelRow)}
        </td>
      `;
    })
    .join("");
}

function renderTable() {
  const rows = filteredRows();
  const matrixRows = groupedMatrixRows(rows);
  const page = pagedRows(matrixRows);
  renderTableHeader();
  const visibleCount = document.getElementById("visibleCount");
  if (visibleCount) {
    visibleCount.textContent = page.total
      ? `${(page.start + 1).toLocaleString()}-${page.end.toLocaleString()} / ${page.total.toLocaleString()}`
      : "0";
  }
  renderPager(page);
  queueTableBody.innerHTML = "";

  if (!page.rows.length) {
    const colSpan = 6 + visibleChannelList().length * 3;
    queueTableBody.innerHTML = `<tr><td colspan="${colSpan}">현재 필터에 맞는 행이 없습니다.</td></tr>`;
    return;
  }

  page.rows.forEach((group, pageIndex) => {
    const row = group.primaryRow;
    const image = rowImage(row);
    const approval = policyApprovalTier(row);
    const tr = document.createElement("tr");
    tr.dataset.tier = group.match_tier;
    tr.dataset.channel = row.source_channel;
    tr.dataset.workflowBucket = groupWorkflowBucket(group);
    tr.dataset.pageIndex = String(pageIndex);
    tr.innerHTML = `
      <td class="sticky-col sticky-sellpia-image">
        ${image ? renderImageThumb(image) : "<span class='muted'>없음</span>"}
      </td>
      <td class="sticky-col sticky-sellpia-code">
        ${renderEditableValue(row, "best_sellpia_sku_code", group.best_sellpia_sku_code || group.best_sellpia_product_code || "-", "strong")}
        ${ownCodeForRow(row) ? `<em class="own-code-badge is-sellpia">자사 ${escapeHtml(ownCodeForRow(row))}</em>` : ""}
        ${group.best_sellpia_product_code && group.best_sellpia_product_code !== group.best_sellpia_sku_code
          ? renderEditableValue(row, "best_sellpia_product_code", group.best_sellpia_product_code, "span", "sellpia-sub-code")
          : ""}
        ${renderTagBadges(group.manual_tags, "mini-tags")}
        ${renderTagBadges(group.sellpia_tags, "mini-tags sellpia-shared-tags")}
      </td>
      <td class="sticky-col sticky-sellpia-product sellpia-col">
        ${renderEditableValue(row, "best_sellpia_product_name", group.best_sellpia_product_name || group.best_sellpia_product_code || "", "span")}
      </td>
      <td class="sticky-col sticky-sellpia-option sellpia-col">
        ${renderEditableValue(row, "best_sellpia_option_name", group.best_sellpia_option_name || group.best_sellpia_sku_code || "", "span")}
      </td>
      <td class="sticky-col sticky-sellpia-status">
        <span class="tier">${escapeHtml(approval.label)}</span>
        ${renderEditableValue(row, "recommended_action", row.recommended_action || "", "span", "status-action")}
        ${linkDecisionBadge(row)}
      </td>
      ${renderChannelCells(group)}
      <td>${Number(group.duplicate_candidate_count || 0).toLocaleString()}</td>
    `;
    tr.addEventListener("click", (event) => {
      if (event.target.closest(".cell-edit-button, .cell-edit-panel, [data-link-candidate]")) return;
      const channelCell = event.target.closest("[data-queue-id]");
      const targetRow = channelCell ? rowByQueueId(channelCell.dataset.queueId) : row;
      selectRow(targetRow || row, tr, { event, group, pageIndex });
    });
    if (groupHasSelectedRow(group)) {
      tr.classList.add("is-selected");
    }
    queueTableBody.appendChild(tr);
  });
}

async function selectRow(row, tr, options = {}) {
  const pageIndex = Number.isInteger(options.pageIndex)
    ? options.pageIndex
    : Number.parseInt(tr?.dataset?.pageIndex || "-1", 10);
  const group = options.group || (Number.isInteger(pageIndex) ? getCurrentPageGroups()[pageIndex] : null);
  const event = options.event;
  const isToggle = Boolean(event?.ctrlKey || event?.metaKey);
  const isRange = Boolean(event?.shiftKey && Number.isInteger(lastSelectedPageIndex) && lastSelectedPageIndex >= 0);

  selectedRow = row;
  pendingTagIds = new Set();
  if (isRange) {
    const pageGroups = getCurrentPageGroups();
    const start = Math.min(lastSelectedPageIndex, pageIndex);
    const end = Math.max(lastSelectedPageIndex, pageIndex);
    selectedQueueIds = new Set();
    pageGroups.slice(start, end + 1).forEach((item) => setGroupSelection(item, true));
  } else if (isToggle) {
    if (groupHasSelectedRow(group)) {
      setGroupSelection(group, false);
    } else {
      setGroupSelection(group, true);
    }
    lastSelectedPageIndex = pageIndex;
  } else {
    selectedQueueIds = new Set();
    setGroupSelection(group, true);
    lastSelectedPageIndex = pageIndex;
  }

  syncSelectedRowFromSelection(row);
  const pageGroupsForPaint = getCurrentPageGroups();
  document.querySelectorAll("#queueTable tr.is-selected").forEach((el) => el.classList.remove("is-selected"));
  document.querySelectorAll("#queueTable tbody tr").forEach((rowEl) => {
    const index = Number.parseInt(rowEl.dataset.pageIndex || "-1", 10);
    rowEl.classList.toggle("is-selected", groupHasSelectedRow(pageGroupsForPaint[index]));
  });

  const selectedImage = rowImage(row);
  const selectedCount = selectedQueueIds.size;
  selectedSummary.className = "selected-summary";
  selectedSummary.innerHTML = `
    <strong>${selectedCount > 1 ? `선택 ${selectedCount.toLocaleString()}개 · ` : ""}${escapeHtml(channelName(row.source_channel))} / ${escapeHtml(policyApprovalTier(row).label)}</strong>
    ${selectedCount > 1 ? "<p><b>다중 선택</b> Shift 범위 선택 / Ctrl·Meta 개별 선택 상태입니다. 태그 적용은 선택된 행 전체에 적용됩니다.</p>" : ""}
    ${renderImageAsset(selectedImage)}
    <p><b>판매처 상품</b> ${escapeHtml(row.channel_product_name || row.channel_product_code || "-")}</p>
    <p><b>판매처 옵션</b> ${escapeHtml(row.channel_option_name || row.channel_option_code || "-")}</p>
    <p><b>Sellpia</b> ${escapeHtml(row.best_sellpia_product_name || "-")} / ${escapeHtml(row.best_sellpia_option_name || "-")}</p>
    <p><b>Sellpia 코드</b> ${escapeHtml(row.best_sellpia_sku_code || row.best_sellpia_product_code || "-")}</p>
    <p><b>재고대조 상태</b> ${escapeHtml(stockStatusLabel(stockStatusForRow(row)))}</p>
    <p><b>중복 후보</b> ${Number(row.duplicate_candidate_count || 0).toLocaleString()}</p>
    <p><b>판정 근거</b> ${escapeHtml(policyApprovalTier(row).reason)}</p>
    ${linkDecisionBadge(row)}
  `;
  appendSelectedMeta(row);
  renderSelectedTags(row);
  if (addTagButton) addTagButton.disabled = pendingTagIds.size === 0;

  candidateDetails.innerHTML = "<p class='empty'>상세 후보 조회 중...</p>";
  const details = await loadDetails(row.queue_id);
  candidateDetails.innerHTML = "";
  renderDecisionControls(row, details);

  if (!details.length) {
    candidateDetails.innerHTML = `
      <p class='empty'>상세 후보가 없습니다. 오른쪽 결정 패널의 검색으로 현재 로드된 Sellpia 옵션을 찾아 연동할 수 있습니다.</p>
    `;
    return;
  }

  details.forEach((detail) => {
    const image = imageMap.get(detail.sellpia_sku_code);
    const item = document.createElement("div");
    item.className = "candidate-card";
    item.innerHTML = `
      <strong>#${detail.candidate_rank} ${escapeHtml(detail.sellpia_sku_code || "")}</strong>
      ${renderImageAsset(image)}
      <span>${Number(detail.match_score || 0).toLocaleString()}점</span>
      <p>${escapeHtml(detail.sellpia_product_name || "")}</p>
      <p>${escapeHtml(detail.sellpia_option_name || "")}</p>
      <small>${escapeHtml(detail.match_reason || "")} ${escapeHtml(detail.risk_flags || "")}</small>
      <button
        type="button"
        class="link-candidate-button"
        data-link-candidate="true"
        data-sellpia-product-code="${escapeHtml(detail.sellpia_product_code || "")}"
        data-sellpia-sku-code="${escapeHtml(detail.sellpia_sku_code || "")}"
        data-sellpia-product-name="${escapeHtml(detail.sellpia_product_name || "")}"
        data-sellpia-option-name="${escapeHtml(detail.sellpia_option_name || "")}"
      >이 Sellpia 옵션으로 연동</button>
    `;
    candidateDetails.appendChild(item);
  });
}

function currentReviewer() {
  return tagReviewerInput?.value?.trim() || String(config.defaultReviewerName || "public-review").trim();
}

function ensureReviewer() {
  const reviewer = currentReviewer();
  if (!reviewer) {
    alert("저장자 정보를 확인할 수 없습니다.");
    tagReviewerInput?.focus();
    return "";
  }
  return reviewer;
}

function renderDecisionControls(row) {
  if (!decisionBox) return;
  const hasSellpia = Boolean(row?.best_sellpia_product_code || row?.best_sellpia_sku_code);
  const canWrite = canWriteReview();
  const disabledReason = canWrite ? "" : `<p class='decision-warning'>${escapeHtml(writeAccessMessage())}</p>`;
  decisionBox.innerHTML = `
    <h3>옵션 연동 결정</h3>
    <p>원본 파일은 수정하지 않고 Supabase 검수 queue에만 수동 결정과 이력을 저장합니다.</p>
    ${disabledReason}
    <div class="decision-actions">
      <button type="button" data-unlink-selected="true" ${!hasSellpia || !canWrite ? "disabled" : ""}>연동 끊기</button>
      <button type="button" data-refresh-selected="true">새로고침</button>
    </div>
    <div class="link-search-box">
      <label>
        Sellpia 옵션 검색
        <input id="sellpiaLinkSearchInput" type="text" placeholder="Sellpia 코드, 상품명, 옵션명" ${!canWrite ? "disabled" : ""} />
      </label>
      <div id="sellpiaLinkSearchResults" class="link-search-results empty">현재 로드된 데이터 안에서 검색합니다.</div>
    </div>
  `;
}

function renderSellpiaSearchBox() {
  return `
    <div class="link-search-inline">
      <label>
        Sellpia 옵션 검색
        <input id="sellpiaLinkSearchInput" type="text" placeholder="Sellpia 코드, 상품명, 옵션명" ${!canWriteReview() ? "disabled" : ""} />
      </label>
      <div id="sellpiaLinkSearchResults" class="link-search-results empty">현재 로드된 데이터 안에서 검색합니다.</div>
    </div>
  `;
}

function sellpiaCandidatePool() {
  const seen = new Set();
  const pool = [];
  queueRows.forEach((row) => {
    const key = [row.best_sellpia_product_code || "", row.best_sellpia_sku_code || "", row.best_sellpia_option_name || ""].join("|");
    if (!row.best_sellpia_product_code && !row.best_sellpia_sku_code) return;
    if (seen.has(key)) return;
    seen.add(key);
    pool.push({
      sellpia_product_code: row.best_sellpia_product_code || "",
      sellpia_sku_code: row.best_sellpia_sku_code || "",
      sellpia_product_name: row.best_sellpia_product_name || "",
      sellpia_option_name: row.best_sellpia_option_name || "",
    });
  });
  return pool;
}

function renderSellpiaSearchResults(term) {
  const container = document.getElementById("sellpiaLinkSearchResults");
  if (!container) return;
  const keyword = String(term || "").trim().toLowerCase();
  if (!keyword) {
    container.className = "link-search-results empty";
    container.textContent = "검색어를 입력하면 현재 로드된 Sellpia 후보가 표시됩니다.";
    return;
  }
  const matches = sellpiaCandidatePool()
    .filter((item) => [
      item.sellpia_product_code,
      item.sellpia_sku_code,
      item.sellpia_product_name,
      item.sellpia_option_name,
    ].join(" ").toLowerCase().includes(keyword))
    .slice(0, 20);

  if (!matches.length) {
    container.className = "link-search-results empty";
    container.textContent = "현재 로드된 데이터에서 찾지 못했습니다.";
    return;
  }

  container.className = "link-search-results";
  container.innerHTML = matches.map((item) => `
    <button
      type="button"
      class="link-search-result"
      data-link-candidate="true"
      data-sellpia-product-code="${escapeHtml(item.sellpia_product_code)}"
      data-sellpia-sku-code="${escapeHtml(item.sellpia_sku_code)}"
      data-sellpia-product-name="${escapeHtml(item.sellpia_product_name)}"
      data-sellpia-option-name="${escapeHtml(item.sellpia_option_name)}"
    >
      <strong>${escapeHtml(item.sellpia_sku_code || item.sellpia_product_code)}</strong>
      <span>${escapeHtml(item.sellpia_product_name)}</span>
      <em>${escapeHtml(item.sellpia_option_name)}</em>
    </button>
  `).join("");
}

async function reloadAfterQueueMutation(queueId) {
  const targetId = String(queueId || selectedRow?.queue_id || "");
  await loadQueueRows();
  const refreshed = queueRows.find((row) => String(row.queue_id) === targetId);
  if (refreshed) {
    selectedRow = refreshed;
    const tr = [...document.querySelectorAll("#queueTable tbody tr")].find((rowEl) =>
      rowEl.querySelector(`[data-queue-id="${CSS.escape(targetId)}"]`)
    );
    await selectRow(refreshed, tr || document.querySelector("#queueTable tbody tr"));
  }
}

async function linkSelectedCandidate(payload) {
  if (!selectedRow || !supabaseClient) return;
  if (!ensureWriteAccess()) return;
  const reviewer = ensureReviewer();
  if (!reviewer) return;
  const memo = prompt("연동 메모를 입력하세요. 비워도 됩니다.", "") || null;
  const { error } = await supabaseClient.rpc("link_match_candidate_option", {
    queue_id: Number(selectedRow.queue_id),
    sellpia_product_code: payload.sellpiaProductCode || null,
    sellpia_sku_code: payload.sellpiaSkuCode || null,
    sellpia_product_name: payload.sellpiaProductName || null,
    sellpia_option_name: payload.sellpiaOptionName || null,
    reviewer,
    memo,
  });
  if (error) {
    console.error(error);
    alert(`연동 저장 실패: ${error.message}`);
    return;
  }
  setStatus("수동 연동을 저장했습니다.", "ok");
  await reloadAfterQueueMutation(selectedRow.queue_id);
}

async function unlinkSelectedRow() {
  if (!selectedRow || !supabaseClient) return;
  if (!ensureWriteAccess()) return;
  const reviewer = ensureReviewer();
  if (!reviewer) return;
  if (!confirm("현재 Sellpia 옵션 연결을 끊습니다. 원본 파일은 수정하지 않고 검수 queue에만 기록합니다.")) return;
  const memo = prompt("연동 해제 메모를 입력하세요. 비워도 됩니다.", "") || null;
  const { error } = await supabaseClient.rpc("unlink_match_candidate_option", {
    queue_id: Number(selectedRow.queue_id),
    reviewer,
    memo,
  });
  if (error) {
    console.error(error);
    alert(`연동 해제 실패: ${error.message}`);
    return;
  }
  setStatus("수동 연동 해제를 저장했습니다.", "ok");
  await reloadAfterQueueMutation(selectedRow.queue_id);
}

async function discontinueSelectedRow() {
  if (!selectedRow || !supabaseClient) return;
  if (!ensureWriteAccess()) return;
  const reviewer = ensureReviewer();
  if (!reviewer) return;
  const memo = prompt("단종/제외 처리 메모를 입력하세요. 비워도 됩니다.", "") || null;
  const { error } = await supabaseClient.rpc("mark_match_candidate_discontinued", {
    queue_id: Number(selectedRow.queue_id),
    reviewer,
    memo,
  });
  if (error) {
    console.error(error);
    alert(`단종/제외 저장 실패: ${error.message}`);
    return;
  }
  setStatus("단종/제외 처리를 저장했습니다.", "ok");
  await reloadAfterQueueMutation(selectedRow.queue_id);
}

function openCellEdit(button) {
  const queueId = button.dataset.queueId;
  const field = button.dataset.editField;
  const row = rowByQueueId(queueId);
  if (!row || !EDITABLE_QUEUE_FIELDS.has(field)) return;
  if (!ensureWriteAccess()) return;
  document.querySelectorAll(".cell-edit-panel").forEach((panel) => panel.remove());
  const wrapper = button.closest(".editable-value");
  if (!wrapper) return;
  activeCellEdit = { queueId, field };
  const panel = document.createElement("div");
  panel.className = "cell-edit-panel";
  panel.innerHTML = `
    <label>${escapeHtml(fieldLabel(field))}
      <textarea data-cell-edit-value rows="3">${escapeHtml(editableMemoValue(row, field))}</textarea>
    </label>
    <input data-cell-edit-memo type="text" placeholder="수정 메모 optional" />
    <div class="cell-edit-actions">
      <button type="button" data-cell-save="true">저장</button>
      <button type="button" data-cell-cancel="true">취소</button>
    </div>
  `;
  wrapper.appendChild(panel);
  panel.querySelector("textarea")?.focus();
}

async function saveActiveCellEdit() {
  if (!activeCellEdit || !supabaseClient) return;
  if (!ensureWriteAccess()) return;
  const reviewer = ensureReviewer();
  if (!reviewer) return;
  const panel = document.querySelector(".cell-edit-panel");
  const newValue = panel?.querySelector("[data-cell-edit-value]")?.value ?? "";
  const memo = panel?.querySelector("[data-cell-edit-memo]")?.value || null;
  const { error } = await supabaseClient.rpc("update_match_candidate_queue_cell", {
    queue_id: Number(activeCellEdit.queueId),
    field_name: activeCellEdit.field,
    new_value: newValue,
    reviewer,
    memo,
  });
  if (error) {
    console.error(error);
    alert(`셀 수정 실패: ${error.message}`);
    return;
  }
  setStatus(`${fieldLabel(activeCellEdit.field)} 수정 저장 완료`, "ok");
  const queueId = activeCellEdit.queueId;
  activeCellEdit = null;
  await reloadAfterQueueMutation(queueId);
}

function appendSelectedMeta(row) {
  const meta = document.createElement("div");
  meta.className = "detail-meta-grid";
  const entries = [
    ["Batch", row.source_batch_id || "-"],
    ["Queue ID", row.queue_id || "-"],
    ["Source row", row.source_row_no || "-"],
    ["Channel code", row.channel_product_code || "-"],
    ["Option code", row.channel_option_code || "-"],
    ["Match score", Number(row.match_score || 0).toLocaleString()],
    ["Auto tier", row.auto_approval_tier || "-"],
    ["Tags", Number(row.manual_tag_count || 0).toLocaleString()],
  ];
  meta.innerHTML = entries
    .map(([label, value]) => `<span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong>`)
    .join("");
  selectedSummary.appendChild(meta);
}

function renderTagControls() {
  if (tagFilterChips) {
    const grouped = groupTagsByCategory(availableTags);
    tagFilterChips.innerHTML = `
      <button class="chip ${activeTagNames.size ? "" : "is-active"}" type="button" data-tag-filter-clear="true">
        전체 태그
      </button>
      <span class="tag-filter-mode">선택한 태그 모두 포함</span>
    `;
    [...grouped.entries()].forEach(([category, tags]) => {
      const group = document.createElement("div");
      group.className = "tag-filter-category";
      group.innerHTML = `<strong>${escapeHtml(category)}</strong>`;
      const chips = document.createElement("div");
      chips.className = "chip-row";
      tags.forEach((tag) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = `chip tag-chip ${activeTagNames.has(tag.tag_name) ? "is-active" : ""}`;
        button.dataset.tagFilter = tag.tag_name;
        button.style.setProperty("--tag-color", tag.tag_color);
        button.textContent = `#${tag.tag_name}`;
        chips.appendChild(button);
      });
      group.appendChild(chips);
      tagFilterChips.appendChild(group);
    });
  }
  if (detailTagSelect) {
    detailTagSelect.innerHTML = "";
    availableTags.forEach((tag) => {
      const option = document.createElement("option");
      option.value = tag.tag_id;
      option.textContent = tag.tag_name;
      detailTagSelect.appendChild(option);
    });
  }
  renderTagPicker(selectedRow);
  if (bulkTagSelect) {
    const previousValue = bulkTagSelect.value;
    bulkTagSelect.innerHTML = "";
    availableTags.forEach((tag) => {
      const option = document.createElement("option");
      option.value = tag.tag_id;
      option.textContent = tag.tag_name;
      bulkTagSelect.appendChild(option);
    });
    if (previousValue && [...bulkTagSelect.options].some((option) => option.value === previousValue)) {
      bulkTagSelect.value = previousValue;
    }
  }
}

function groupTagsByCategory(tags) {
  return tags.reduce((acc, tag) => {
    const category = tagCategory(tag);
    if (!acc.has(category)) acc.set(category, []);
    acc.get(category).push(tag);
    return acc;
  }, new Map());
}

function tagCategory(tag) {
  const description = String(tag.description || "");
  const match = description.match(/category\s*:\s*([^;,\n]+)/i);
  if (match?.[1]) return match[1].trim();
  const name = String(tag.tag_name || "");
  if (name.includes(":")) return name.split(":")[0].trim();
  if (name.includes("/")) return name.split("/")[0].trim();
  return "기본";
}

function renderTagPicker(row) {
  if (!tagPicker) return;
  if (!availableTags.length) {
    tagPicker.className = "tag-picker empty";
    tagPicker.textContent = "아직 생성된 태그가 없습니다.";
    return;
  }

  const rowTagIds = new Set((row?.manual_tags || []).map((tag) => tag.tag_id).filter(Boolean));
  const grouped = availableTags.reduce((acc, tag) => {
    const category = tagCategory(tag);
    if (!acc.has(category)) acc.set(category, []);
    acc.get(category).push(tag);
    return acc;
  }, new Map());

  tagPicker.className = "tag-picker";
  tagPicker.innerHTML = [...grouped.entries()].map(([category, tags]) => `
    <div class="tag-category-group">
      <strong>${escapeHtml(category)}</strong>
      <div class="tag-picker-chips">
        ${tags.map((tag) => {
          const selected = pendingTagIds.has(tag.tag_id);
          const applied = rowTagIds.has(tag.tag_id);
          return `
            <button
              type="button"
              class="tag-pick-chip ${selected ? "is-selected" : ""} ${applied ? "is-applied" : ""}"
              data-pick-tag-id="${escapeHtml(tag.tag_id)}"
              style="--tag-color:${escapeHtml(tag.tag_color || "#e2e8f0")}"
              ${applied ? "aria-pressed=\"true\"" : ""}
            >
              #${escapeHtml(tag.tag_name)}
            </button>
          `;
        }).join("")}
      </div>
    </div>
  `).join("");
}

function togglePendingTag(tagId) {
  if (!tagId) return;
  if (pendingTagIds.has(tagId)) {
    pendingTagIds.delete(tagId);
  } else {
    pendingTagIds.add(tagId);
  }
  renderTagPicker(selectedRow);
  if (addTagButton) {
    addTagButton.disabled = !selectedRow || pendingTagIds.size === 0;
  }
}

function syncChannelVisibilityControls() {
  if (!channelVisibilityControls) return;
  channelVisibilityControls.querySelectorAll("input[type='checkbox']").forEach((input) => {
    input.checked = visibleChannels.has(input.value);
    input.closest("[data-channel-check]")?.classList.toggle("is-active", input.checked);
  });
}

function toggleVisibleChannel(channel, checked) {
  if (!SELLER_CHANNELS.includes(channel)) return;
  if (checked) {
    visibleChannels.add(channel);
  } else if (visibleChannels.size > 1) {
    visibleChannels.delete(channel);
  } else {
    alert("최소 한 개 판매처는 표시해야 합니다.");
  }
  syncChannelVisibilityControls();
  resetPagination();
  renderDashboard();
  renderTable();
}

function renderSelectedTags(row) {
  const tags = row?.manual_tags || [];
  const sharedTags = row?.sellpia_tags || [];
  if (!selectedTagBadges) return;
  renderTagPicker(row);
  if (addTagButton) {
    addTagButton.disabled = !row || pendingTagIds.size === 0;
  }
  if (!tags.length && !sharedTags.length) {
    selectedTagBadges.className = "tag-badge-row empty";
    selectedTagBadges.textContent = "아직 태그가 없습니다.";
    return;
  }
  selectedTagBadges.className = "tag-badge-row";
  selectedTagBadges.innerHTML = [
    ...sharedTags.map((tag) => `
    <span class="tag-badge is-sellpia-shared" style="--tag-color:${escapeHtml(tag.tag_color || "#E9D5FF")}" title="셀피아 공유 태그">
      ${escapeHtml(tag.tag_name)}
    </span>
  `),
    ...tags.map((tag) => `
    <span class="tag-badge" style="--tag-color:${escapeHtml(tag.tag_color || "#e2e8f0")}">
      ${escapeHtml(tag.tag_name)}
      <button type="button" data-remove-tag="${escapeHtml(tag.assignment_id)}" title="태그 제거">×</button>
    </span>
  `),
  ].join("");
}

function renderTagBadges(tags, className = "") {
  if (!tags || !tags.length) return "";
  return `<div class="tag-badge-row ${className}">${tags.map((tag) => `
    <span class="tag-badge ${tag.is_sellpia_shared ? "is-sellpia-shared" : ""}" style="--tag-color:${escapeHtml(tag.tag_color || "#e2e8f0")}" title="${tag.is_sellpia_shared ? "셀피아 공유 태그" : "검수 태그"}">${escapeHtml(tag.tag_name)}</span>
  `).join("")}</div>`;
}

async function addTagToSelectedRow() {
  if ((!selectedRow && !selectedQueueIds.size) || pendingTagIds.size === 0) return;
  const reviewer = currentReviewer();
  if (!reviewer) {
    alert("저장자 정보를 확인할 수 없습니다.");
    return;
  }

  const targetIds = selectedQueueIds.size
    ? new Set(selectedQueueIds)
    : new Set([String(selectedRow.queue_id)]);
  const targetRows = queueRows.filter((row) => targetIds.has(String(row.queue_id)));
  if (!targetRows.length) return;

  const payload = [];
  targetRows.forEach((row) => {
    const existingTagIds = new Set((row.manual_tags || []).map((tag) => tag.tag_id).filter(Boolean));
    [...pendingTagIds]
      .filter((tagId) => !existingTagIds.has(tagId))
      .forEach((tagId) => {
        payload.push({
          tag_id: tagId,
          source_batch_id: row.source_batch_id,
          source_channel: row.source_channel,
          queue_id: row.queue_id,
          sellpia_sku_code: row.best_sellpia_sku_code || null,
          channel_product_code: row.channel_product_code || null,
          channel_option_code: row.channel_option_code || null,
          reviewer,
          memo: tagMemoInput.value.trim() || null,
        });
      });
  });

  if (!payload.length) {
    alert("선택된 행에는 이미 붙어 있는 태그입니다.");
    pendingTagIds = new Set();
    renderTagPicker(selectedRow);
    addTagButton.disabled = true;
    return;
  }

  const { error } = await supabaseClient.from("product_tag_assignments").insert(payload);
  if (error) {
    if (error.code === "23505") {
      alert("이미 붙어 있는 태그입니다.");
      return;
    }
    console.error(error);
    alert(`태그 저장 실패: ${error.message}`);
    return;
  }
  const selectedQueueId = selectedRow?.queue_id;
  const selectedIdsBeforeReload = new Set(selectedQueueIds);
  tagMemoInput.value = "";
  pendingTagIds = new Set();
  detailCache.clear();
  await loadQueueRows();
  selectedQueueIds = new Set([...selectedIdsBeforeReload].filter((id) => queueRows.some((row) => String(row.queue_id) === id)));
  const refreshed = queueRows.find((row) => row.queue_id === selectedQueueId);
  if (refreshed) {
    selectedRow = refreshed;
    renderSelectedTags(refreshed);
    renderTagPicker(refreshed);
  }
  renderTable();
  if (addTagButton) addTagButton.disabled = true;
}

async function removeTagAssignment(assignmentId) {
  if (!assignmentId) return;
  const selectedQueueId = selectedRow?.queue_id;
  const { error } = await supabaseClient
    .from("product_tag_assignments")
    .update({ is_active: false, updated_at: new Date().toISOString() })
    .eq("assignment_id", assignmentId);
  if (error) {
    console.error(error);
    alert(`태그 제거 실패: ${error.message}`);
    return;
  }
  await loadQueueRows();
  const refreshed = queueRows.find((row) => row.queue_id === selectedQueueId);
  if (refreshed) {
    selectedRow = refreshed;
    renderSelectedTags(refreshed);
  }
}

async function createManualTag() {
  const tagName = newTagNameInput.value.trim();
  if (!tagName) {
    alert("새 태그명을 입력하세요.");
    return;
  }
  const color = newTagColorInput.value || "#DBEAFE";
  const { error } = await supabaseClient.from("product_tags").insert({
    tag_name: tagName,
    tag_color: color,
    created_by: currentReviewer() || "local_html",
  });
  if (error) {
    if (error.code === "23505") {
      alert("이미 있는 태그입니다.");
      return;
    }
    console.error(error);
    alert(`태그 생성 실패: ${error.message}`);
    return;
  }
  newTagNameInput.value = "";
  await loadTags();
}

function rowHasTag(row, tag) {
  const tags = Array.isArray(row.manual_tags) ? row.manual_tags : [];
  const names = Array.isArray(row.manual_tag_names) ? row.manual_tag_names : [];
  return tags.some((item) => item.tag_id === tag.tag_id || item.tag_name === tag.tag_name) ||
    names.includes(tag.tag_name);
}

function countBy(rows, getter) {
  return rows.reduce((acc, row) => {
    const key = getter(row) || "unknown";
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});
}

function renderBulkTagPreview() {
  if (!bulkTagSelect || !bulkTagPreviewResult) return;
  const tag = availableTags.find((item) => item.tag_id === bulkTagSelect.value);
  if (!tag) {
    bulkTagPreviewResult.textContent = "No tag selected.";
    return;
  }

  const rows = filteredRows();
  const alreadyTagged = rows.filter((row) => rowHasTag(row, tag));
  const targetRows = rows.filter((row) => !rowHasTag(row, tag));
  const channelCounts = countBy(targetRows, (row) => channelName(row.source_channel));
  const tierCounts = countBy(targetRows, (row) => policyApprovalTier(row).label);
  const samples = targetRows.slice(0, 8);

  const channelText = Object.entries(channelCounts)
    .map(([name, count]) => `${name}: ${count.toLocaleString()}`)
    .join(" / ") || "-";
  const tierText = Object.entries(tierCounts)
    .map(([name, count]) => `${name}: ${count.toLocaleString()}`)
    .join(" / ") || "-";
  const sampleHtml = samples.length
    ? `<ul>${samples.map((row) => `
        <li>
          <strong>${escapeHtml(row.best_sellpia_sku_code || row.best_sellpia_product_code || "-")}</strong>
          <span>${escapeHtml(channelName(row.source_channel))}</span>
          <span>${escapeHtml(row.channel_product_name || row.channel_product_code || "-")}</span>
          <span>${escapeHtml(row.channel_option_name || row.channel_option_code || "-")}</span>
        </li>
      `).join("")}</ul>`
    : "<p>No new target rows in the current filter.</p>";

  bulkTagPreviewResult.innerHTML = `
    <div class="bulk-tag-stats">
      <span>Current filter <strong>${rows.length.toLocaleString()}</strong></span>
      <span>Will tag <strong>${targetRows.length.toLocaleString()}</strong></span>
      <span>Already tagged <strong>${alreadyTagged.length.toLocaleString()}</strong></span>
    </div>
    <p><b>Target tag:</b> ${escapeHtml(tag.tag_name)} / <b>Channels:</b> ${escapeHtml(channelText)}</p>
    <p><b>Tiers:</b> ${escapeHtml(tierText)}</p>
    <p class="bulk-tag-warning">Preview only. No DB write is executed here. Bulk save remains locked until separately approved.</p>
    ${sampleHtml}
  `;
}

function sellpiaTagUploadHeaders() {
  return [
    "sellpia_product_code",
    "sellpia_sku_code",
    "tag_scope",
    "tags",
    "tag_name",
    "tag_color",
    "tag_memo",
    "reviewer",
    "action",
    "source_channel",
    "channel_product_code",
    "channel_option_code",
    "note",
  ];
}

async function downloadSellpiaTagUploadTemplate() {
  if (!window.ExcelJS) {
    const csv = `\ufeff${sellpiaTagUploadHeaders().join(",")}\r\n`;
    downloadBlob(new Blob([csv], { type: "text/csv;charset=utf-8" }), `sellpia_tag_upload_template_${formatTimestamp()}.csv`);
    return;
  }
  const workbook = new window.ExcelJS.Workbook();
  workbook.creator = "System v1";
  workbook.created = new Date();
  const guide = workbook.addWorksheet("안내");
  guide.columns = [
    { header: "항목", key: "name", width: 24 },
    { header: "내용", key: "value", width: 88 },
  ];
  guide.addRows([
    { name: "저장 기준", value: "태그는 판매처 행이 아니라 Sellpia 상품코드/옵션코드에 저장됩니다." },
    { name: "옵션 태그", value: "tag_scope=option, sellpia_sku_code 필수" },
    { name: "상품 태그", value: "tag_scope=product, sellpia_product_code 필수" },
    { name: "여러 태그", value: "tags 컬럼에 쉼표/세미콜론/줄바꿈으로 여러 태그를 넣을 수 있습니다." },
    { name: "미등록 태그", value: "업로드 화면에서 '미등록 태그 자동 생성'을 체크해야 저장됩니다." },
    { name: "지원 action", value: "현재는 add만 지원합니다." },
  ]);
  guide.getRow(1).font = { bold: true };
  guide.getColumn(2).alignment = { wrapText: true, vertical: "top" };

  const sheet = workbook.addWorksheet("태그업로드");
  sheet.columns = sellpiaTagUploadHeaders().map((header) => ({
    header,
    key: header,
    width: {
      sellpia_product_code: 18,
      sellpia_sku_code: 18,
      tags: 34,
      tag_name: 22,
      tag_memo: 34,
      note: 34,
    }[header] || 18,
  }));
  sheet.addRows([
    {
      sellpia_product_code: "10644",
      sellpia_sku_code: "10644-1",
      tag_scope: "option",
      tags: "에이블리제외, 14K확인",
      tag_color: "#E9D5FF",
      tag_memo: "예시: MD 체크 기준",
      reviewer: currentReviewer(),
      action: "add",
      note: "예시 행은 삭제 후 사용",
    },
    {
      sellpia_product_code: "10644",
      tag_scope: "product",
      tag_name: "상품명확인",
      tag_color: "#DBEAFE",
      tag_memo: "상품 전체에 공유되는 태그 예시",
      reviewer: currentReviewer(),
      action: "add",
      note: "상품 태그는 sellpia_sku_code를 비워도 됨",
    },
  ]);
  styleWorksheetHeader(sheet, sellpiaTagUploadHeaders());
  const buffer = await workbook.xlsx.writeBuffer();
  downloadBlob(
    new Blob([buffer], { type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" }),
    `sellpia_tag_upload_template_${formatTimestamp()}.xlsx`
  );
}

function tagUploadHeaderMap(worksheet) {
  const map = new Map();
  worksheet.getRow(1).eachCell({ includeEmpty: true }, (cell, columnNumber) => {
    const key = normalizedHeader(cellText(cell)).replace(/[^a-z0-9가-힣]/gi, "");
    if (!key) return;
    map.set(key, columnNumber);
  });
  return map;
}

function tagUploadValue(row, headerMap, names) {
  for (const name of names) {
    const key = normalizedHeader(name).replace(/[^a-z0-9가-힣]/gi, "");
    const column = headerMap.get(key);
    if (column) return cellText(row.getCell(column)).trim();
  }
  return "";
}

function splitTagNames(value) {
  return String(value || "")
    .split(/[,;\n\r]+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function normalizeTagScope(value, productCode, skuCode) {
  const text = String(value || "").trim().toLowerCase();
  if (["product", "상품", "상품태그"].includes(text)) return "product";
  if (["option", "sku", "옵션", "옵션태그"].includes(text)) return "option";
  return skuCode ? "option" : "product";
}

function tagByNameMap() {
  const map = new Map();
  availableTags.forEach((tag) => map.set(String(tag.tag_name || "").trim().toLowerCase(), tag));
  return map;
}

function existingSellpiaTagKey(tagId, scope, productCode, skuCode) {
  return [tagId || "", scope || "", productCode || "", skuCode || ""].join("|");
}

function existingSellpiaTagKeys() {
  const keys = new Set();
  queueRows.forEach((row) => {
    (row.sellpia_tags || []).forEach((tag) => {
      keys.add(existingSellpiaTagKey(
        tag.tag_id,
        tag.tag_scope,
        tag.sellpia_product_code || row.best_sellpia_product_code || sellpiaProductCodeFromSku(row.best_sellpia_sku_code),
        tag.sellpia_sku_code || row.best_sellpia_sku_code || ""
      ));
    });
  });
  return keys;
}

function resolveSellpiaTagUploadTarget({ productCode, skuCode, sourceChannel, channelProductCode, channelOptionCode }) {
  const normalizedSku = String(skuCode || "").trim();
  const normalizedProduct = String(productCode || sellpiaProductCodeFromSku(normalizedSku) || "").trim();
  if (normalizedSku || normalizedProduct) {
    return { productCode: normalizedProduct, skuCode: normalizedSku, matchStatus: "direct" };
  }
  const candidates = queueRows.filter((row) => {
    if (sourceChannel && String(row.source_channel || "").trim() !== sourceChannel) return false;
    if (channelProductCode && String(row.channel_product_code || "").trim() !== channelProductCode) return false;
    if (channelOptionCode && String(row.channel_option_code || "").trim() !== channelOptionCode) return false;
    return row.best_sellpia_product_code || row.best_sellpia_sku_code;
  });
  const targetKeys = new Map();
  candidates.forEach((row) => {
    const targetProduct = String(row.best_sellpia_product_code || sellpiaProductCodeFromSku(row.best_sellpia_sku_code) || "").trim();
    const targetSku = String(row.best_sellpia_sku_code || "").trim();
    targetKeys.set(`${targetProduct}|${targetSku}`, { productCode: targetProduct, skuCode: targetSku });
  });
  if (targetKeys.size === 1) return { ...[...targetKeys.values()][0], matchStatus: "seller_resolved" };
  if (targetKeys.size > 1) return { productCode: "", skuCode: "", matchStatus: "multiple_targets" };
  return { productCode: "", skuCode: "", matchStatus: "not_found" };
}

async function parseSellpiaTagUploadWorkbook(file) {
  if (!window.ExcelJS) throw new Error("XLSX 파서가 아직 로드되지 않았습니다.");
  const workbook = new window.ExcelJS.Workbook();
  await workbook.xlsx.load(await file.arrayBuffer());
  const worksheet = workbook.getWorksheet("태그업로드") || workbook.worksheets[0];
  if (!worksheet) throw new Error("엑셀 시트를 찾지 못했습니다.");
  const headerMap = tagUploadHeaderMap(worksheet);
  const parsed = [];
  for (let rowNumber = 2; rowNumber <= worksheet.rowCount; rowNumber += 1) {
    const row = worksheet.getRow(rowNumber);
    const productCode = tagUploadValue(row, headerMap, ["sellpia_product_code", "셀피아 상품코드", "상품코드"]);
    const skuCode = tagUploadValue(row, headerMap, ["sellpia_sku_code", "셀피아 옵션코드", "셀피아 코드", "옵션코드"]);
    const tagScopeRaw = tagUploadValue(row, headerMap, ["tag_scope", "태그범위", "scope"]);
    const tags = [
      ...splitTagNames(tagUploadValue(row, headerMap, ["tags", "태그들", "태그"])),
      ...splitTagNames(tagUploadValue(row, headerMap, ["tag_name", "태그명"])),
    ];
    const tagMemo = tagUploadValue(row, headerMap, ["tag_memo", "memo", "태그메모", "메모"]);
    const tagColor = tagUploadValue(row, headerMap, ["tag_color", "태그색상", "색상"]) || "#E9D5FF";
    const reviewer = tagUploadValue(row, headerMap, ["reviewer", "검수자", "작성자"]) || currentReviewer();
    const action = (tagUploadValue(row, headerMap, ["action", "작업"]) || "add").toLowerCase();
    const sourceChannel = tagUploadValue(row, headerMap, ["source_channel", "판매처"]);
    const channelProductCode = tagUploadValue(row, headerMap, ["channel_product_code", "판매처 상품코드"]);
    const channelOptionCode = tagUploadValue(row, headerMap, ["channel_option_code", "판매처 옵션코드"]);
    if (!productCode && !skuCode && !tags.length && !sourceChannel && !channelProductCode && !channelOptionCode) continue;
    tags.forEach((tagName) => {
      const target = resolveSellpiaTagUploadTarget({ productCode, skuCode, sourceChannel, channelProductCode, channelOptionCode });
      const scope = normalizeTagScope(tagScopeRaw, target.productCode, target.skuCode);
      parsed.push({
        source_row_no: rowNumber,
        sellpia_product_code: target.productCode,
        sellpia_sku_code: target.skuCode,
        tag_scope: scope,
        tag_name: tagName,
        tag_color: tagColor,
        memo: tagMemo,
        reviewer,
        action,
        source_channel: sourceChannel,
        channel_product_code: channelProductCode,
        channel_option_code: channelOptionCode,
        match_status: target.matchStatus,
      });
    });
  }
  return parsed;
}

async function previewSellpiaTagUpload() {
  const file = sellpiaTagUploadInput?.files?.[0];
  if (!file) {
    alert("태그 업로드 XLSX를 선택하세요.");
    return;
  }
  try {
    if (sellpiaTagUploadStatus) sellpiaTagUploadStatus.textContent = `${file.name} 분석 중...`;
    await loadTags();
    const rows = await parseSellpiaTagUploadWorkbook(file);
    const tagsByName = tagByNameMap();
    const existingKeys = existingSellpiaTagKeys();
    const seenInFile = new Set();
    sellpiaTagPreviewRows = rows.map((row) => {
      const tag = tagsByName.get(String(row.tag_name || "").trim().toLowerCase());
      const productCode = row.sellpia_product_code || sellpiaProductCodeFromSku(row.sellpia_sku_code);
      const key = existingSellpiaTagKey(tag?.tag_id || row.tag_name, row.tag_scope, productCode, row.sellpia_sku_code);
      let status = "저장 가능";
      let severity = "ok";
      if (row.action !== "add") {
        status = "지원하지 않는 action";
        severity = "error";
      } else if (!row.tag_name) {
        status = "태그명 누락";
        severity = "error";
      } else if (row.match_status === "multiple_targets") {
        status = "판매처 코드 복수 후보";
        severity = "error";
      } else if (row.match_status === "not_found") {
        status = "셀피아 코드 없음";
        severity = "error";
      } else if (row.tag_scope === "option" && !row.sellpia_sku_code) {
        status = "옵션 태그는 옵션코드 필요";
        severity = "error";
      } else if (row.tag_scope === "product" && !productCode) {
        status = "상품 태그는 상품코드 필요";
        severity = "error";
      } else if (!tag) {
        status = sellpiaTagAutoCreateInput?.checked ? "새 태그 생성 후 저장" : "미등록 태그";
        severity = sellpiaTagAutoCreateInput?.checked ? "warn" : "error";
      } else if (existingKeys.has(key)) {
        status = "이미 붙은 태그";
        severity = "warn";
      } else if (seenInFile.has(key)) {
        status = "파일 내 중복";
        severity = "warn";
      }
      seenInFile.add(key);
      return {
        ...row,
        tag_id: tag?.tag_id || null,
        resolved_product_code: productCode,
        status,
        severity,
        can_save: ["저장 가능", "새 태그 생성 후 저장"].includes(status),
      };
    });
    renderSellpiaTagUploadPreview(file.name);
  } catch (error) {
    console.error(error);
    sellpiaTagPreviewRows = [];
    if (sellpiaTagSaveButton) sellpiaTagSaveButton.disabled = true;
    if (sellpiaTagUploadStatus) sellpiaTagUploadStatus.textContent = `태그 업로드 미리보기 실패: ${error.message}`;
  }
}

function renderSellpiaTagUploadPreview(fileName = "") {
  if (!sellpiaTagPreviewResult) return;
  const total = sellpiaTagPreviewRows.length;
  const saveable = sellpiaTagPreviewRows.filter((row) => row.can_save).length;
  const errors = sellpiaTagPreviewRows.filter((row) => row.severity === "error").length;
  const warnings = sellpiaTagPreviewRows.filter((row) => row.severity === "warn").length;
  if (sellpiaTagUploadStatus) {
    sellpiaTagUploadStatus.textContent = `${fileName || "태그 엑셀"}: 전체 ${total.toLocaleString()}건, 저장 가능 ${saveable.toLocaleString()}건, 확인 필요 ${warnings.toLocaleString()}건, 오류 ${errors.toLocaleString()}건`;
  }
  if (sellpiaTagSaveButton) sellpiaTagSaveButton.disabled = saveable === 0;
  const sampleRows = sellpiaTagPreviewRows.slice(0, 80);
  sellpiaTagPreviewResult.innerHTML = `
    <div class="bulk-tag-stats">
      <span>전체 <strong>${total.toLocaleString()}</strong></span>
      <span>저장 가능 <strong>${saveable.toLocaleString()}</strong></span>
      <span>오류 <strong>${errors.toLocaleString()}</strong></span>
    </div>
    <table class="tag-preview-table">
      <thead>
        <tr>
          <th>상태</th>
          <th>행</th>
          <th>범위</th>
          <th>셀피아 코드</th>
          <th>태그</th>
          <th>메모</th>
        </tr>
      </thead>
      <tbody>
        ${sampleRows.map((row) => `
          <tr>
            <td class="tag-preview-status-${row.severity}">${escapeHtml(row.status)}</td>
            <td>${Number(row.source_row_no || 0).toLocaleString()}</td>
            <td>${escapeHtml(row.tag_scope)}</td>
            <td>${escapeHtml(row.tag_scope === "product" ? row.resolved_product_code : row.sellpia_sku_code)}</td>
            <td>${escapeHtml(row.tag_name)}</td>
            <td>${escapeHtml(row.memo || "")}</td>
          </tr>
        `).join("")}
      </tbody>
    </table>
    ${total > sampleRows.length ? `<p>${(total - sampleRows.length).toLocaleString()}건은 화면 표시에서 생략했습니다.</p>` : ""}
  `;
}

async function ensureSellpiaUploadTags(rows) {
  const tagsByName = tagByNameMap();
  const missingNames = uniqueCompact(rows.filter((row) => !row.tag_id).map((row) => row.tag_name));
  if (!missingNames.length) return tagsByName;
  if (!sellpiaTagAutoCreateInput?.checked) {
    throw new Error("미등록 태그가 있습니다. 자동 생성을 체크하거나 태그를 먼저 생성하세요.");
  }
  const payload = missingNames.map((tagName) => {
    const source = rows.find((row) => row.tag_name === tagName);
    return {
      tag_name: tagName,
      tag_color: source?.tag_color && /^#[0-9A-Fa-f]{6}$/.test(source.tag_color) ? source.tag_color : "#E9D5FF",
      description: "category:셀피아공유; 엑셀 업로드로 생성",
      created_by: source?.reviewer || tagReviewerInput?.value?.trim() || "sellpia_tag_upload",
    };
  });
  const { error } = await supabaseClient.from("product_tags").insert(payload);
  if (error && error.code !== "23505") throw error;
  await loadTags();
  return tagByNameMap();
}

async function saveSellpiaTagUpload() {
  const targetRows = sellpiaTagPreviewRows.filter((row) => row.can_save);
  if (!targetRows.length) {
    alert("저장 가능한 태그가 없습니다.");
    return;
  }
  if (!confirm(`${targetRows.length.toLocaleString()}건의 셀피아 공유 태그를 저장할까요?`)) return;
  try {
    if (sellpiaTagUploadStatus) sellpiaTagUploadStatus.textContent = "셀피아 공유 태그 저장 중...";
    const tagsByName = await ensureSellpiaUploadTags(targetRows);
    const fileName = sellpiaTagUploadInput?.files?.[0]?.name || null;
    const payload = [];
    const insertedKeys = new Set();
    targetRows.forEach((row) => {
      const tag = tagsByName.get(String(row.tag_name || "").trim().toLowerCase());
      if (!tag) return;
      const productCode = row.resolved_product_code || row.sellpia_product_code || sellpiaProductCodeFromSku(row.sellpia_sku_code);
      const skuCode = row.tag_scope === "option" ? row.sellpia_sku_code : null;
      const key = existingSellpiaTagKey(tag.tag_id, row.tag_scope, productCode, skuCode || "");
      if (insertedKeys.has(key)) return;
      insertedKeys.add(key);
      payload.push({
        tag_id: tag.tag_id,
        tag_scope: row.tag_scope,
        sellpia_product_code: productCode || null,
        sellpia_sku_code: skuCode || null,
        reviewer: row.reviewer || currentReviewer(),
        memo: row.memo || null,
        source_file_name: fileName,
        source_row_no: row.source_row_no || null,
      });
    });
    if (!payload.length) {
      alert("저장할 신규 태그가 없습니다.");
      return;
    }
    const { error } = await supabaseClient.from("sellpia_tag_assignments").insert(payload);
    if (error) throw error;
    sellpiaTagPreviewRows = [];
    if (sellpiaTagSaveButton) sellpiaTagSaveButton.disabled = true;
    if (sellpiaTagUploadStatus) sellpiaTagUploadStatus.textContent = `${payload.length.toLocaleString()}건 저장 완료. 화면 데이터를 다시 불러옵니다.`;
    sellpiaSharedTagsAvailable = true;
    await loadQueueRows();
  } catch (error) {
    console.error(error);
    if (sellpiaTagUploadStatus) sellpiaTagUploadStatus.textContent = `셀피아 공유 태그 저장 실패: ${error.message}`;
  }
}

function renderImageThumb(image) {
  return `<img class="table-thumb" src="${escapeHtml(image.storage_public_url)}" alt="${escapeHtml(image.original_file_name || "")}" />`;
}

function imageMissingLabel(row) {
  if (!row?.best_sellpia_product_code && !row?.best_sellpia_sku_code) return "Sellpia 코드 없음";
  return "이미지 없음";
}

function rowImage(row) {
  if (row.sellpia_image_url) {
    return {
      p_code: row.best_sellpia_sku_code,
      original_file_name: row.sellpia_image_file_name,
      storage_public_url: row.sellpia_image_url,
    };
  }
  return imageMap.get(row.best_sellpia_sku_code);
}

function renderImageAsset(image) {
  if (!image || !image.storage_public_url) return "";
  return `
    <div class="image-asset">
      <img src="${escapeHtml(image.storage_public_url)}" alt="${escapeHtml(image.original_file_name || "Sellpia image")}" />
      <span>${escapeHtml(image.original_file_name || image.p_code || "")}</span>
    </div>
  `;
}

function channelName(channel) {
  return {
    sellpia: "Sellpia",
    smartstore: "Smartstore",
    makeshop: "MakeShop",
    ably: "Ably",
    coupang: "Coupang",
    playauto: "PlayAuto",
  }[channel] || channel || "-";
}

function setActiveChannel(channel) {
  activeChannel = channel;
}

function setActiveStockStatus(status) {
  activeStockStatus = status || "";
  activeWorkflowFilter = "";
  document.querySelectorAll(".stock-card").forEach((card) => {
    card.classList.toggle("is-active", card.dataset.stockStatus === activeStockStatus);
  });
  if (activeStockStatus) {
    visibleChannels.add("smartstore");
    syncChannelVisibilityControls();
  }
  resetPagination();
  renderStockSummary();
  renderTable();
}

function setActiveWorkflowFilter(bucket) {
  activeWorkflowFilter = activeWorkflowFilter === bucket ? "" : bucket;
  activeStockStatus = "";
  document.querySelectorAll(".stock-card").forEach((card) => card.classList.remove("is-active"));
  resetPagination();
  renderStockSummary();
  renderTable();
}

function moveChannel(delta) {
  return;
}

function handleShortcut(event) {
  return;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatTimestamp(date = new Date()) {
  const pad = (value) => String(value).padStart(2, "0");
  return [
    date.getFullYear(),
    pad(date.getMonth() + 1),
    pad(date.getDate()),
    "_",
    pad(date.getHours()),
    pad(date.getMinutes()),
  ].join("");
}

function tagNames(row) {
  if (Array.isArray(row.manual_tag_names)) return row.manual_tag_names.join(", ");
  return (row.manual_tags || []).map((tag) => tag.tag_name).filter(Boolean).join(", ");
}

function tagMemos(row) {
  return (row.manual_tags || [])
    .map((tag) => [tag.tag_name, tag.memo].filter(Boolean).join(": "))
    .filter(Boolean)
    .join(" / ");
}

function reviewExportRows() {
  return filteredRows().map((row) => {
    const image = rowImage(row);
    const stockStatus = stockStatusForRow(row);
    const approval = policyApprovalTier(row);
    return {
      "판매처": channelName(row.source_channel),
      "소스 batch": row.source_batch_id || "",
      "원본 row no": row.source_row_no || "",
      "Sellpia 상품코드": row.best_sellpia_product_code || "",
      "Sellpia 옵션코드": row.best_sellpia_sku_code || "",
      "Sellpia 상품명": row.best_sellpia_product_name || "",
      "Sellpia 옵션명": row.best_sellpia_option_name || "",
      "판매처 상품코드": row.channel_product_code || "",
      "판매처 옵션코드": row.channel_option_code || "",
      "판매처 상품명": row.channel_product_name || "",
      "판매처 옵션명": row.channel_option_name || "",
      "매칭 등급": tierLabel(row.match_tier),
      "매칭 점수": Number(row.match_score || 0),
      "정책 승인후보": approval.label,
      "정책 판단 사유": approval.reason,
      "자동승인 등급": row.auto_approval_tier || "",
      "재고대조 상태": stockStatusLabel(stockStatus),
      "중복 후보 수": Number(row.duplicate_candidate_count || 0),
      "중복 위험": row.duplicate_risk ? "Y" : "N",
      "검토 필요": row.review_required ? "Y" : "N",
      "이미지 파일명": image?.original_file_name || row.sellpia_image_file_name || "",
      "이미지 URL": image?.storage_public_url || row.sellpia_image_url || "",
      "수동 태그": tagNames(row),
      "태그 메모": tagMemos(row),
      "권장 액션": row.recommended_action || stockStatusLabel(stockStatus),
      "매칭 근거": row.match_reason || "",
    };
  });
}

function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  URL.revokeObjectURL(url);
}

function csvEscape(value) {
  const text = String(value ?? "");
  if (/[",\r\n]/.test(text)) {
    return `"${text.replaceAll('"', '""')}"`;
  }
  return text;
}

function downloadReviewCsv() {
  const rows = reviewExportRows();
  if (!rows.length) {
    alert("현재 필터 결과가 없습니다.");
    return;
  }
  const headers = Object.keys(rows[0]);
  const lines = [
    headers.map(csvEscape).join(","),
    ...rows.map((row) => headers.map((header) => csvEscape(row[header])).join(",")),
  ];
  const csv = `\ufeff${lines.join("\r\n")}`;
  downloadBlob(
    new Blob([csv], { type: "text/csv;charset=utf-8" }),
    `mapping_matrix_review_${formatTimestamp()}.csv`
  );
}

function xlsxRowColor(row) {
  if (row["중복 위험"] === "Y") return "FFFFF7ED";
  if (row["매칭 등급"].includes("자동")) return "FFEAF7EA";
  if (row["매칭 등급"].includes("빠른")) return "FFFFF9DB";
  if (row["매칭 등급"].includes("없음")) return "FFFFE4E6";
  if (row["재고대조 상태"].includes("불일치")) return "FFFFE4E6";
  if (row["재고대조 상태"].includes("일치")) return "FFEAF7EA";
  return "FFFFFFFF";
}

function safeXlsxText(value) {
  return String(value ?? "");
}

function xlsxRowColorSafe(row) {
  const values = Object.values(row || {}).map((value) => safeXlsxText(value)).join(" ").toLowerCase();
  if (values.includes("y") && (values.includes("duplicate") || values.includes("중복") || values.includes("以묐났"))) return "FFFFF7ED";
  if (values.includes("auto") || values.includes("자동") || values.includes("candidate") || values.includes("확정") || values.includes("候補") || values.includes("?먮룞")) return "FFEAF7EA";
  if (values.includes("fast") || values.includes("빠른") || values.includes("review") || values.includes("鍮좊Ⅸ")) return "FFFFF9DB";
  if (values.includes("no match") || values.includes("nomatch") || values.includes("미매칭") || values.includes("없음") || values.includes("?놁쓬")) return "FFFFE4E6";
  if (values.includes("diff") || values.includes("불일치") || values.includes("遺덉씪")) return "FFFFE4E6";
  if (values.includes("match") || values.includes("일치") || values.includes("?쇱튂")) return "FFEAF7EA";
  return "FFFFFFFF";
}

const FALLBACK_XLSX_ROW_STYLES = {
  FFFFFFFF: 2,
  FFEAF7EA: 3,
  FFFFF9DB: 4,
  FFFFE4E6: 5,
  FFFFF7ED: 6,
};

function textBytes(text) {
  return new TextEncoder().encode(String(text));
}

const CRC32_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let index = 0; index < 256; index += 1) {
    let value = index;
    for (let bit = 0; bit < 8; bit += 1) {
      value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
    }
    table[index] = value >>> 0;
  }
  return table;
})();

function crc32(bytes) {
  let value = 0xffffffff;
  bytes.forEach((byte) => {
    value = CRC32_TABLE[(value ^ byte) & 0xff] ^ (value >>> 8);
  });
  return (value ^ 0xffffffff) >>> 0;
}

function pushUint16(target, value) {
  target.push(value & 0xff, (value >>> 8) & 0xff);
}

function pushUint32(target, value) {
  target.push(value & 0xff, (value >>> 8) & 0xff, (value >>> 16) & 0xff, (value >>> 24) & 0xff);
}

function makeZipBlob(files) {
  const localParts = [];
  const centralParts = [];
  let offset = 0;

  files.forEach((file) => {
    const nameBytes = textBytes(file.name);
    const contentBytes = typeof file.content === "string" ? textBytes(file.content) : file.content;
    const checksum = crc32(contentBytes);
    const local = [];
    pushUint32(local, 0x04034b50);
    pushUint16(local, 20);
    pushUint16(local, 0x0800);
    pushUint16(local, 0);
    pushUint16(local, 0);
    pushUint16(local, 0);
    pushUint32(local, checksum);
    pushUint32(local, contentBytes.length);
    pushUint32(local, contentBytes.length);
    pushUint16(local, nameBytes.length);
    pushUint16(local, 0);
    localParts.push(new Uint8Array(local), nameBytes, contentBytes);

    const central = [];
    pushUint32(central, 0x02014b50);
    pushUint16(central, 20);
    pushUint16(central, 20);
    pushUint16(central, 0x0800);
    pushUint16(central, 0);
    pushUint16(central, 0);
    pushUint16(central, 0);
    pushUint32(central, checksum);
    pushUint32(central, contentBytes.length);
    pushUint32(central, contentBytes.length);
    pushUint16(central, nameBytes.length);
    pushUint16(central, 0);
    pushUint16(central, 0);
    pushUint16(central, 0);
    pushUint16(central, 0);
    pushUint32(central, 0);
    pushUint32(central, offset);
    centralParts.push(new Uint8Array(central), nameBytes);

    offset += local.length + nameBytes.length + contentBytes.length;
  });

  const centralSize = centralParts.reduce((sum, part) => sum + part.length, 0);
  const end = [];
  pushUint32(end, 0x06054b50);
  pushUint16(end, 0);
  pushUint16(end, 0);
  pushUint16(end, files.length);
  pushUint16(end, files.length);
  pushUint32(end, centralSize);
  pushUint32(end, offset);
  pushUint16(end, 0);

  return new Blob([...localParts, ...centralParts, new Uint8Array(end)], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
}

function xmlEscape(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;");
}

function columnName(index) {
  let name = "";
  let value = index;
  while (value > 0) {
    const remainder = (value - 1) % 26;
    name = String.fromCharCode(65 + remainder) + name;
    value = Math.floor((value - remainder) / 26);
  }
  return name;
}

function fallbackSheetXml(headers, rows, options = {}) {
  const lastCol = columnName(headers.length);
  const totalRows = rows.length + 1;
  const cols = headers.map((header, index) => {
    const width = Math.max(10, Math.min(42, String(header || "").length + 8));
    return `<col min="${index + 1}" max="${index + 1}" width="${width}" customWidth="1"/>`;
  }).join("");
  const headerCells = headers.map((header, index) =>
    `<c r="${columnName(index + 1)}1" t="inlineStr" s="1"><is><t>${xmlEscape(header)}</t></is></c>`
  ).join("");
  const dataRows = rows.map((row, rowIndex) => {
    const rowNumber = rowIndex + 2;
    const styleId = FALLBACK_XLSX_ROW_STYLES[xlsxRowColorSafe(row)] || 2;
    const cells = headers.map((header, colIndex) =>
      `<c r="${columnName(colIndex + 1)}${rowNumber}" t="inlineStr" s="${styleId}"><is><t>${xmlEscape(row[header])}</t></is></c>`
    ).join("");
    return `<row r="${rowNumber}">${cells}</row>`;
  }).join("");
  const frozen = options.frozen === false ? "" : `
    <sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>`;
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <dimension ref="A1:${lastCol}${Math.max(totalRows, 1)}"/>
  ${frozen}
  <cols>${cols}</cols>
  <sheetData><row r="1">${headerCells}</row>${dataRows}</sheetData>
  <autoFilter ref="A1:${lastCol}${Math.max(totalRows, 1)}"/>
</worksheet>`;
}

function fallbackStylesXml() {
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2"><font><sz val="10"/><name val="Malgun Gothic"/></font><font><b/><sz val="10"/><color rgb="FFFFFFFF"/><name val="Malgun Gothic"/></font></fonts>
  <fills count="8"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF1F2937"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFFFFF"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFEAF7EA"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFF9DB"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFE4E6"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFF7ED"/><bgColor indexed="64"/></patternFill></fill></fills>
  <borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left/><right/><top/><bottom style="thin"><color rgb="FFE2E8F0"/></bottom><diagonal/></border></borders>
  <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
  <cellXfs count="7"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf><xf numFmtId="0" fontId="0" fillId="3" borderId="1" xfId="0" applyFill="1" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf><xf numFmtId="0" fontId="0" fillId="4" borderId="1" xfId="0" applyFill="1" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf><xf numFmtId="0" fontId="0" fillId="5" borderId="1" xfId="0" applyFill="1" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf><xf numFmtId="0" fontId="0" fillId="6" borderId="1" xfId="0" applyFill="1" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf><xf numFmtId="0" fontId="0" fillId="7" borderId="1" xfId="0" applyFill="1" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf></cellXfs>
  <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>`;
}

function downloadFallbackReviewXlsx(rows) {
  const headers = Object.keys(rows[0]);
  const noticeRows = [
    { "항목": "파일 목적", "내용": "검토용 XLSX입니다. 판매처 업로드용이 아니며 현재 화면 필터 결과만 담습니다." },
    { "항목": "생성 시각", "내용": new Date().toLocaleString("ko-KR") },
    { "항목": "행 수", "내용": rows.length.toLocaleString() },
  ];
  const files = [
    { name: "[Content_Types].xml", content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>` },
    { name: "_rels/.rels", content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>` },
    { name: "xl/workbook.xml", content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="안내" sheetId="1" r:id="rId1"/><sheet name="검토대상" sheetId="2" r:id="rId2"/></sheets></workbook>` },
    { name: "xl/_rels/workbook.xml.rels", content: `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>` },
    { name: "xl/styles.xml", content: fallbackStylesXml() },
    { name: "xl/worksheets/sheet1.xml", content: fallbackSheetXml(["항목", "내용"], noticeRows, { frozen: false }) },
    { name: "xl/worksheets/sheet2.xml", content: fallbackSheetXml(headers, rows) },
  ];
  downloadBlob(makeZipBlob(files), `mapping_matrix_review_${formatTimestamp()}.xlsx`);
}

function styleWorksheetHeader(worksheet, headers) {
  worksheet.views = [{ state: "frozen", ySplit: 1 }];
  worksheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: headers.length },
  };
  const headerRow = worksheet.getRow(1);
  headerRow.height = 24;
  headerRow.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF1F2937" } };
    cell.border = { bottom: { style: "thin", color: { argb: "FF94A3B8" } } };
  });
  worksheet.columns = headers.map((header) => {
    const widthMap = {
      "판매처": 12,
      "소스 batch": 24,
      "원본 row no": 12,
      "Sellpia 상품코드": 18,
      "Sellpia 옵션코드": 18,
      "Sellpia 상품명": 34,
      "Sellpia 옵션명": 28,
      "판매처 상품코드": 18,
      "판매처 옵션코드": 20,
      "판매처 상품명": 34,
      "판매처 옵션명": 28,
      "매칭 등급": 18,
      "매칭 점수": 12,
      "정책 승인후보": 24,
      "정책 판단 사유": 42,
      "자동승인 등급": 18,
      "재고대조 상태": 18,
      "중복 후보 수": 12,
      "중복 위험": 10,
      "검토 필요": 10,
      "이미지 파일명": 24,
      "이미지 URL": 42,
      "수동 태그": 24,
      "태그 메모": 32,
      "권장 액션": 28,
      "매칭 근거": 40,
    };
    return { header, key: header, width: widthMap[header] || 16 };
  });
}

async function downloadReviewXlsx() {
  const rows = reviewExportRows();
  if (!rows.length) {
    alert("현재 필터 결과가 없습니다.");
    return;
  }
  if (!window.ExcelJS) {
    downloadFallbackReviewXlsx(rows);
    return;
  }

  const workbook = new window.ExcelJS.Workbook();
  workbook.creator = "System v1 local review";
  workbook.created = new Date();

  const notice = workbook.addWorksheet("안내");
  notice.columns = [
    { header: "항목", key: "name", width: 22 },
    { header: "내용", key: "value", width: 90 },
  ];
  notice.addRows([
    { name: "파일 목적", value: "검토용 파일입니다. 판매처 업로드용이 아니며 원본 데이터나 판매처 재고를 수정하지 않습니다." },
    { name: "반영 범위", value: "현재 화면의 필터 결과만 내려받습니다." },
    { name: "태그", value: "수동 태그와 태그 메모를 함께 포함합니다." },
    { name: "주의", value: "재고/매칭 자동반영 전에는 사람이 샘플과 위험 태그를 확인해야 합니다." },
    { name: "생성 시각", value: new Date().toLocaleString("ko-KR") },
  ]);
  notice.getRow(1).font = { bold: true };
  notice.getColumn(2).alignment = { wrapText: true, vertical: "top" };

  const headers = Object.keys(rows[0]);
  const worksheet = workbook.addWorksheet("검토대상");
  styleWorksheetHeader(worksheet, headers);
  rows.forEach((row) => worksheet.addRow(row));

  worksheet.eachRow((excelRow, rowNumber) => {
    if (rowNumber === 1) return;
    const exportRow = rows[rowNumber - 2];
    const fillColor = xlsxRowColor(exportRow);
    excelRow.eachCell((cell, colNumber) => {
      cell.alignment = {
        vertical: "top",
        horizontal: typeof cell.value === "number" ? "right" : "left",
        wrapText: true,
      };
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: fillColor } };
      cell.border = { bottom: { style: "hair", color: { argb: "FFE2E8F0" } } };
      if (["중복 후보 수", "매칭 점수"].includes(headers[colNumber - 1]) && Number(cell.value || 0) > 0) {
        cell.numFmt = "#,##0";
      }
      if (exportRow["중복 위험"] === "Y" && ["중복 후보 수", "중복 위험"].includes(headers[colNumber - 1])) {
        cell.font = { bold: true, color: { argb: "FF9A3412" } };
      }
    });
  });

  const buffer = await workbook.xlsx.writeBuffer();
  downloadBlob(
    new Blob([buffer], {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    }),
    `mapping_matrix_review_${formatTimestamp()}.xlsx`
  );
}

function cellText(cell) {
  const value = cell?.value;
  if (value == null) return "";
  if (typeof value === "object") {
    if (Array.isArray(value.richText)) return value.richText.map((part) => part.text || "").join("");
    if ("text" in value) return String(value.text || "");
    if ("result" in value) return String(value.result || "");
    if ("hyperlink" in value && "text" in value) return String(value.text || "");
  }
  return String(value);
}

function splitCellLines(value) {
  return String(value ?? "")
    .replace(/\r\n/g, "\n")
    .replace(/\r/g, "\n")
    .split("\n")
    .map((item) => item.trim());
}

function normalizedHeader(value) {
  return String(value || "").replace(/\s+/g, "").toLowerCase();
}

function findSmartstoreColumns(worksheet) {
  const result = {
    headerRow: 1,
    productNo: null,
    optionCode: null,
    optionStock: null,
    productName: null,
    optionName: null,
    priceColumns: [],
  };
  const maxRows = Math.min(10, worksheet.rowCount || 10);
  const maxCols = Math.min(160, worksheet.columnCount || 160);

  for (let rowNumber = 1; rowNumber <= maxRows; rowNumber += 1) {
    const row = worksheet.getRow(rowNumber);
    const candidates = {};
    let fallbackStockColumn = null;
    for (let colNumber = 1; colNumber <= maxCols; colNumber += 1) {
      const header = normalizedHeader(cellText(row.getCell(colNumber)));
      if (!header) continue;
      if (!candidates.productNo && header.includes("상품번호")) candidates.productNo = colNumber;
      if (!candidates.productName && header === "상품명") candidates.productName = colNumber;
      if (!candidates.optionCode && (header.includes("옵션번호") || header.includes("옵션코드") || header.includes("옵션id"))) {
        candidates.optionCode = colNumber;
      }
      if (!candidates.optionName && (header.includes("옵션값") || header.includes("옵션명"))) {
        candidates.optionName = colNumber;
      }
      if (
        header.includes("재고수량") &&
        !header.includes("추가상품") &&
        !header.includes("상품재고")
      ) {
        if (header.includes("옵션")) {
          candidates.optionStock = colNumber;
        } else if (!fallbackStockColumn) {
          fallbackStockColumn = colNumber;
        }
      }
      if (
        header &&
        !header.includes("재고") &&
        !header.includes("배송") &&
        (
          header.includes("판매가") ||
          header.includes("상품가격") ||
          header.includes("옵션가") ||
          header.includes("옵션가격") ||
          header.includes("할인판매가") ||
          header.includes("최종가")
        )
      ) {
        if (!candidates.priceColumns) candidates.priceColumns = [];
        candidates.priceColumns.push({ column: colNumber, header });
      }
    }
    if (!candidates.optionStock && fallbackStockColumn) {
      candidates.optionStock = fallbackStockColumn;
    }
    if (candidates.productNo && candidates.optionCode && candidates.optionStock) {
      return { ...result, ...candidates, priceColumns: candidates.priceColumns || [], headerRow: rowNumber };
    }
  }

  return { ...result };
}

function setSmartstorePreviewStatus(message) {
  if (smartstoreOriginalStatus) smartstoreOriginalStatus.textContent = message;
}

function selectedSmartstoreApplyScopes() {
  const scopes = { stock: false, price: false, cellEdits: false };
  smartstoreApplyScopeInputs.forEach((input) => {
    scopes[input.dataset.smartstoreApplyScope] = Boolean(input.checked);
  });
  return scopes;
}

function smartstoreScopeLabel(scope) {
  return {
    stock: "재고수정",
    price: "가격수정",
    cellEdits: "상품명/옵션명",
    cell_edit: "상품명/옵션명",
  }[scope] || scope;
}

function selectedSmartstoreScopeNames(scopes = selectedSmartstoreApplyScopes()) {
  return Object.entries(scopes)
    .filter(([, enabled]) => enabled)
    .map(([scope]) => smartstoreScopeLabel(scope));
}

function smartstoreColumnHeader(worksheet, columns, columnNumber) {
  return cellText(worksheet.getRow(columns.headerRow).getCell(columnNumber)) || columnName(columnNumber);
}

function applyFill(cell, argb) {
  cell.style = cloneExcelStyle(cell.style);
  cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb } };
}

function clearApplyFill(cell) {
  cell.style = cloneExcelStyle(cell.style);
  cell.fill = { type: "pattern", pattern: "none" };
}

function normalizeOriginalSheetApplyFills(worksheet, records, { clearExistingYellow = false } = {}) {
  const changedCells = new Set(
    records
      .filter((record) => record.rowNumber && record.columnNumber)
      .map((record) => `${record.rowNumber}:${record.columnNumber}`)
  );
  const cellCount = worksheet.rowCount * worksheet.columnCount;
  const shouldClearExistingYellow = clearExistingYellow && cellCount <= 250000;
  if (shouldClearExistingYellow) {
    for (let rowNumber = 1; rowNumber <= worksheet.rowCount; rowNumber += 1) {
      const row = worksheet.getRow(rowNumber);
      for (let columnNumber = 1; columnNumber <= worksheet.columnCount; columnNumber += 1) {
        const cell = row.getCell(columnNumber);
        const fgColor = cell.fill?.fgColor;
        const rgb = fgColor?.type === "rgb" ? fgColor.rgb : "";
        if (rgb === "FFFFFF00" || rgb === "FFFF00") {
          clearApplyFill(cell);
        }
      }
    }
  }
  changedCells.forEach((key) => {
    const [rowNumber, columnNumber] = key.split(":").map(Number);
    applyFill(worksheet.getRow(rowNumber).getCell(columnNumber), "FFFFFF00");
  });
}

function addSmartstoreChangeRecord(records, {
  scope,
  rowNumber,
  columnNumber,
  columnHeader,
  productNo,
  optionCode,
  beforeValue,
  afterValue,
  riskBucket = "",
  source = "",
}) {
  records.push({
    scope,
    scopeLabel: smartstoreScopeLabel(scope),
    rowNumber,
    columnNumber,
    columnHeader,
    productNo,
    optionCode,
    beforeValue: String(beforeValue ?? ""),
    afterValue: String(afterValue ?? ""),
    riskBucket,
    source,
  });
}

function applySmartstoreStockChanges(worksheet, columns, records) {
  const rowsByOriginalRow = new Map();
  smartstorePreviewRows.forEach((preview) => {
    if (!rowsByOriginalRow.has(preview.rowNumber)) rowsByOriginalRow.set(preview.rowNumber, []);
    rowsByOriginalRow.get(preview.rowNumber).push(preview);
  });

  rowsByOriginalRow.forEach((previews, rowNumber) => {
    const row = worksheet.getRow(rowNumber);
    const stockCell = row.getCell(columns.optionStock);
    const stockLines = splitCellLines(cellText(stockCell));
    let changed = false;
    previews.forEach((preview) => {
      const index = preview.optionLineNo - 1;
      const beforeValue = stockLines[index] ?? "";
      if (beforeValue !== preview.proposedStock) {
        stockLines[index] = preview.proposedStock;
        changed = true;
        addSmartstoreChangeRecord(records, {
          scope: "stock",
          rowNumber,
          columnNumber: columns.optionStock,
          columnHeader: smartstoreColumnHeader(worksheet, columns, columns.optionStock),
          productNo: preview.productNo,
          optionCode: preview.optionCode,
          beforeValue,
          afterValue: preview.proposedStock,
          riskBucket: preview.riskBucket,
          source: preview.apply?.candidate_source || "smartstore_stock_apply_map",
        });
      }
    });
    if (changed) {
      stockCell.value = stockLines.join("\n");
      stockCell.alignment = { ...(stockCell.alignment || {}), wrapText: true, vertical: "top" };
      applyFill(stockCell, "FFFFFF00");
    }
  });
}

function cloneExcelStyle(style) {
  if (!style || typeof style !== "object") return {};
  try {
    return JSON.parse(JSON.stringify(style));
  } catch {
    return { ...style };
  }
}

function copySmartstoreWorksheetRow(sourceRow, targetRow, maxColumn) {
  targetRow.height = sourceRow.height;
  for (let columnNumber = 1; columnNumber <= maxColumn; columnNumber += 1) {
    const sourceCell = sourceRow.getCell(columnNumber);
    const targetCell = targetRow.getCell(columnNumber);
    targetCell.value = sourceCell.value;
    targetCell.style = cloneExcelStyle(sourceCell.style);
    if (sourceCell.numFmt) targetCell.numFmt = sourceCell.numFmt;
    if (sourceCell.alignment) targetCell.alignment = cloneExcelStyle(sourceCell.alignment);
  }
}

function changedStockPreviewRows() {
  return smartstorePreviewRows.filter((preview) => String(preview.currentStock ?? "") !== String(preview.proposedStock ?? ""));
}

function addSmartstoreStockCorrectionSheet(workbook, sourceWorksheet, columns) {
  const changedRows = changedStockPreviewRows();
  if (!changedRows.length) return;

  const sheetName = uniqueWorksheetName(workbook, "스마트스토어 재고수정");
  const correctionSheet = workbook.addWorksheet(sheetName);
  const maxColumn = Math.max(sourceWorksheet.columnCount || 0, 94);
  const firstDataRow = Math.min(...changedRows.map((preview) => preview.rowNumber));
  const headerEndRow = Math.max(columns.headerRow || 1, firstDataRow - 1);

  for (let columnNumber = 1; columnNumber <= maxColumn; columnNumber += 1) {
    const sourceColumn = sourceWorksheet.getColumn(columnNumber);
    const targetColumn = correctionSheet.getColumn(columnNumber);
    targetColumn.width = sourceColumn.width;
    targetColumn.hidden = sourceColumn.hidden;
    targetColumn.style = cloneExcelStyle(sourceColumn.style);
  }

  for (let rowNumber = 1; rowNumber <= headerEndRow; rowNumber += 1) {
    copySmartstoreWorksheetRow(sourceWorksheet.getRow(rowNumber), correctionSheet.getRow(rowNumber), maxColumn);
  }

  const rowsByOriginalRow = new Map();
  changedRows.forEach((preview) => {
    if (!rowsByOriginalRow.has(preview.rowNumber)) rowsByOriginalRow.set(preview.rowNumber, []);
    rowsByOriginalRow.get(preview.rowNumber).push(preview);
  });

  let targetRowNumber = headerEndRow + 1;
  rowsByOriginalRow.forEach((previews, sourceRowNumber) => {
    const targetRow = correctionSheet.getRow(targetRowNumber);
    copySmartstoreWorksheetRow(sourceWorksheet.getRow(sourceRowNumber), targetRow, maxColumn);

    const stockCell = targetRow.getCell(columns.optionStock);
    const stockLines = splitCellLines(cellText(stockCell));
    previews.forEach((preview) => {
      const index = preview.optionLineNo - 1;
      stockLines[index] = preview.proposedStock;
    });
    stockCell.value = stockLines.join("\n");
    stockCell.alignment = { ...(stockCell.alignment || {}), wrapText: true, vertical: "top" };

    applyFill(stockCell, "FFFFFF00");
    targetRow.commit?.();
    targetRowNumber += 1;
  });

  correctionSheet.views = [{ state: "frozen", ySplit: headerEndRow }];
  correctionSheet.autoFilter = {
    from: { row: columns.headerRow, column: 1 },
    to: { row: columns.headerRow, column: maxColumn },
  };
}

function priceCandidatesForHeader(header) {
  const normalized = normalizedHeader(header);
  if (normalized.includes("옵션")) {
    return ["proposed_option_price", "option_price", "sellpia_option_price"];
  }
  if (normalized.includes("할인") || normalized.includes("최종")) {
    return ["proposed_final_price", "proposed_discount_price", "final_price", "sellpia_final_price"];
  }
  return ["proposed_sale_price", "proposed_product_price", "sellpia_sale_price", "sellpia_price", "sale_price"];
}

function proposedPriceValue(apply, header) {
  const keys = priceCandidatesForHeader(header);
  for (const key of keys) {
    if (apply?.[key] != null && String(apply[key]).trim() !== "") return String(apply[key]).trim();
  }
  return "";
}

function applySmartstorePriceChanges(worksheet, columns, records, warnings) {
  const priceColumns = columns.priceColumns || [];
  if (!priceColumns.length) {
    warnings.push("가격수정: 원본양식에서 가격 컬럼을 찾지 못해 적용하지 않았습니다.");
    return;
  }

  let hasAnySource = false;
  smartstorePreviewRows.forEach((preview) => {
    const row = worksheet.getRow(preview.rowNumber);
    priceColumns.forEach(({ column, header }) => {
      const nextValue = proposedPriceValue(preview.apply, header);
      if (!nextValue) return;
      hasAnySource = true;
      const cell = row.getCell(column);
      const isLineBased = normalizedHeader(header).includes("옵션");
      const lineResult = isLineBased
        ? applyLineValue(cell, preview.optionLineNo, nextValue)
        : (() => {
          const beforeValue = cellText(cell);
          if (beforeValue === nextValue) return { changed: false, beforeValue };
          cell.value = nextValue;
          cell.alignment = { ...(cell.alignment || {}), wrapText: true, vertical: "top" };
          return { changed: true, beforeValue };
        })();
      if (!lineResult.changed) return;
      applyFill(cell, "FFE9D5FF");
      addSmartstoreChangeRecord(records, {
        scope: "price",
        rowNumber: preview.rowNumber,
        columnNumber: column,
        columnHeader: smartstoreColumnHeader(worksheet, columns, column),
        productNo: preview.productNo,
        optionCode: preview.optionCode,
        beforeValue: lineResult.beforeValue,
        afterValue: nextValue,
        riskBucket: preview.riskBucket,
        source: "price_apply_source",
      });
    });
  });

  if (!hasAnySource) {
    warnings.push("가격수정: apply map에 가격 변경 source 필드가 없어 적용 0건으로 처리했습니다.");
  }
}

function latestEditedValue(row, field) {
  const edits = evidenceArray(row, "local_html_cell_edits").filter((item) => item?.field_name === field);
  if (!edits.length) return null;
  const latest = edits[edits.length - 1];
  return latest?.new_value ?? latest?.value ?? null;
}

function smartstoreRowsByProductOption() {
  const map = new Map();
  queueRows.forEach((row) => {
    if (row.source_channel !== "smartstore") return;
    const productNo = String(row.channel_product_code || "").trim();
    const optionCode = String(row.channel_option_code || "").trim();
    if (!productNo || !optionCode) return;
    map.set(`${productNo}|${optionCode}`, row);
  });
  return map;
}

function applyLineValue(cell, lineNumber, nextValue) {
  const lines = splitCellLines(cellText(cell));
  const index = Math.max(0, Number(lineNumber || 1) - 1);
  const beforeValue = lines[index] ?? "";
  if (beforeValue === nextValue) return { changed: false, beforeValue };
  lines[index] = nextValue;
  cell.value = lines.join("\n");
  cell.alignment = { ...(cell.alignment || {}), wrapText: true, vertical: "top" };
  return { changed: true, beforeValue };
}

function applySmartstoreCellEdits(worksheet, columns, records, warnings) {
  const sourceRows = smartstoreRowsByProductOption();
  if (!sourceRows.size) {
    warnings.push("셀수정적용: 현재 로드된 Smartstore queue row가 없어 적용하지 않았습니다.");
    return;
  }

  const mapping = {
    channel_product_name: { columnKey: "productName", lineBased: false },
    channel_option_name: { columnKey: "optionName", lineBased: true },
  };
  let applied = 0;
  let skipped = 0;

  smartstorePreviewRows.forEach((preview) => {
    const sourceRow = sourceRows.get(`${preview.productNo}|${preview.optionCode}`);
    if (!sourceRow) return;
    Object.entries(mapping).forEach(([field, config]) => {
      const nextValue = latestEditedValue(sourceRow, field);
      if (nextValue == null || String(nextValue).trim() === "") return;
      const columnNumber = columns[config.columnKey];
      if (!columnNumber) {
        skipped += 1;
        return;
      }
      const row = worksheet.getRow(preview.rowNumber);
      const cell = row.getCell(columnNumber);
      const result = config.lineBased
        ? applyLineValue(cell, preview.optionLineNo, String(nextValue))
        : (() => {
          const beforeValue = cellText(cell);
          if (beforeValue === String(nextValue)) return { changed: false, beforeValue };
          cell.value = String(nextValue);
          cell.alignment = { ...(cell.alignment || {}), wrapText: true, vertical: "top" };
          return { changed: true, beforeValue };
        })();
      if (!result.changed) return;
      applyFill(cell, "FFD9EAF7");
      applied += 1;
      addSmartstoreChangeRecord(records, {
        scope: "cell_edit",
        rowNumber: preview.rowNumber,
        columnNumber,
        columnHeader: smartstoreColumnHeader(worksheet, columns, columnNumber),
        productNo: preview.productNo,
        optionCode: preview.optionCode,
        beforeValue: result.beforeValue,
        afterValue: nextValue,
        riskBucket: preview.riskBucket,
        source: `local_html_cell_edits.${field}`,
      });
    });
  });

  if (!applied) warnings.push("셀수정적용: 적용 가능한 프론트 셀 수정 이력이 없었습니다.");
  if (skipped) warnings.push(`셀수정적용: 원본양식 컬럼 매핑 실패 ${skipped.toLocaleString()}건`);
}

function uniqueWorksheetName(workbook, preferredName) {
  let name = preferredName;
  let index = 2;
  while (workbook.getWorksheet(name)) {
    name = `${preferredName}_${index}`;
    index += 1;
  }
  return name;
}

function addSmartstoreApplySummarySheets(workbook, records, warnings, scopes, stats = {}) {
  const bucketCounts = smartstorePreviewBucketCounts(smartstorePreviewRows);
  const summarySheet = workbook.addWorksheet(uniqueWorksheetName(workbook, "적용요약"));
  summarySheet.columns = [
    { header: "항목", key: "name", width: 28 },
    { header: "내용", key: "value", width: 88 },
  ];
  const countByScope = records.reduce((acc, record) => {
    acc[record.scope] = (acc[record.scope] || 0) + 1;
    return acc;
  }, {});
  summarySheet.addRows([
    { name: "파일 목적", value: "검토용 선택 적용 XLSX입니다. 판매처 업로드용 파일이 아니며 별도 승인 전 업로드하면 안 됩니다." },
    { name: "원본 파일", value: smartstoreOriginalFileName || "-" },
    { name: "생성 시각", value: new Date().toLocaleString("ko-KR") },
    { name: "선택 범위", value: selectedSmartstoreScopeNames(scopes).join(", ") || "없음" },
    { name: "전체 변경 셀", value: records.length },
    { name: "재고수정 변경 셀", value: countByScope.stock || 0 },
    { name: "가격수정 변경 셀", value: countByScope.price || 0 },
    { name: "상품명/옵션명 변경 셀", value: countByScope.cell_edit || 0 },
    { name: "preview matched", value: stats.matchedRows ?? smartstorePreviewRows.length },
    { name: "preview changed", value: stats.changedRows ?? smartstorePreviewRows.filter((row) => row.status === "CHANGE").length },
    { name: "ZERO_OUT", value: bucketCounts.ZERO_OUT || 0 },
    { name: "LARGE_DECREASE", value: bucketCounts.LARGE_DECREASE || 0 },
    { name: "RECHECK_REQUIRED", value: bucketCounts.RECHECK_REQUIRED || 0 },
    { name: "경고", value: warnings.length ? warnings.join("\n") : "없음" },
  ]);
  summarySheet.getRow(1).font = { bold: true };
  summarySheet.getColumn(2).alignment = { wrapText: true, vertical: "top" };

  const logSheet = workbook.addWorksheet(uniqueWorksheetName(workbook, "변경셀목록"));
  logSheet.columns = [
    { header: "scope", key: "scopeLabel", width: 14 },
    { header: "row", key: "rowNumber", width: 10 },
    { header: "column", key: "columnNumber", width: 10 },
    { header: "header", key: "columnHeader", width: 24 },
    { header: "productNo", key: "productNo", width: 18 },
    { header: "optionCode", key: "optionCode", width: 20 },
    { header: "before", key: "beforeValue", width: 24 },
    { header: "after", key: "afterValue", width: 24 },
    { header: "risk", key: "riskBucket", width: 18 },
    { header: "source", key: "source", width: 28 },
  ];
  if (records.length) {
    records.forEach((record) => logSheet.addRow(record));
  } else {
    logSheet.addRow({
      scopeLabel: "-",
      rowNumber: "",
      columnNumber: "",
      columnHeader: "변경 없음",
      beforeValue: "",
      afterValue: "",
      riskBucket: "",
      source: warnings.join(" / ") || "selected scopes produced no changes",
    });
  }
  logSheet.getRow(1).font = { bold: true };
  logSheet.views = [{ state: "frozen", ySplit: 1 }];
  logSheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: logSheet.columnCount },
  };
}

function smartstoreStockBucket(currentStock, proposedStock) {
  const current = Number(currentStock);
  const proposed = Number(proposedStock);
  if (!Number.isFinite(current) || !Number.isFinite(proposed)) {
    return { bucket: "RECHECK_REQUIRED", label: "재확인 필요", note: "재고값이 숫자로 해석되지 않습니다." };
  }
  const delta = proposed - current;
  const absDelta = Math.abs(delta);
  const relativeDecrease = current > 0 ? absDelta / current : 0;
  if (delta === 0) return { bucket: "NO_CHANGE", label: "동일", note: "재고 변경 없음" };
  if (proposed === 0 && current > 0) {
    return { bucket: "ZERO_OUT", label: "0으로 변경", note: "현재 재고가 0으로 바뀌므로 확인이 필요합니다." };
  }
  if (delta > 0) return { bucket: "INCREASE", label: "증가", note: "Sellpia 기준 재고가 현재 스마트스토어보다 큽니다." };
  if (absDelta >= 20 || relativeDecrease >= 0.5) {
    return { bucket: "LARGE_DECREASE", label: "큰 감소", note: "감소폭이 커서 샘플 확인이 필요합니다." };
  }
  return { bucket: "SMALL_DECREASE", label: "소폭 감소", note: "소폭 감소 후보입니다." };
}

function smartstorePreviewBucketCounts(rows) {
  return rows.reduce((acc, row) => {
    acc[row.riskBucket] = (acc[row.riskBucket] || 0) + 1;
    return acc;
  }, {});
}

function smartstoreRiskSuggestedTag(row) {
  if (row.riskBucket === "ZERO_OUT") return "재고주의, 0으로변경";
  if (row.riskBucket === "LARGE_DECREASE") return "재고주의, 큰감소";
  if (row.riskBucket === "RECHECK_REQUIRED") return "재고주의, 재확인필요";
  return "재고주의";
}

function smartstoreRiskReviewRows(rows) {
  return rows.map((row) => ({
    "위험 분류": row.riskLabel,
    "권장 태그": smartstoreRiskSuggestedTag(row),
    "검토 메모": row.riskNote,
    "원본 행": row.rowNumber,
    "옵션 line": row.optionLineNo,
    "상품번호": row.productNo,
    "옵션번호": row.optionCode,
    "옵션명": row.optionName,
    "현재 재고": row.currentStock,
    "변경 재고": row.proposedStock,
    "차이": row.stockDelta,
    "Sellpia 상품코드": row.sellpiaProductCode,
    "Sellpia 옵션코드": row.sellpiaSkuCode,
    "Sellpia 옵션명": row.sellpiaOptionName,
    "상태": row.statusLabel,
  }));
}

function filteredSmartstorePreviewRows() {
  if (!activeSmartstorePreviewBucket) return smartstorePreviewRows;
  return smartstorePreviewRows.filter((row) => row.riskBucket === activeSmartstorePreviewBucket);
}

function renderSmartstoreUploadGateMetrics(stats) {
  if (!smartstoreUploadGateMetrics) return;
  const zeroOut = stats.bucketCounts.ZERO_OUT || 0;
  const largeDecrease = stats.bucketCounts.LARGE_DECREASE || 0;
  const recheck = stats.bucketCounts.RECHECK_REQUIRED || 0;
  const blocked = zeroOut + largeDecrease + recheck;
  smartstoreUploadGateMetrics.innerHTML = `
    <span>Matched ${stats.matchedRows.toLocaleString()} / changed ${stats.changedRows.toLocaleString()}</span>
    <strong>${blocked.toLocaleString()} rows require review before upload-ready</strong>
    <small>ZERO_OUT ${zeroOut.toLocaleString()} · LARGE_DECREASE ${largeDecrease.toLocaleString()} · RECHECK_REQUIRED ${recheck.toLocaleString()}</small>
  `;
}

function uploadGateReviewCounts(stats = {}) {
  const bucketCounts = stats.bucketCounts || {};
  const zeroOut = bucketCounts.ZERO_OUT || 0;
  const largeDecrease = bucketCounts.LARGE_DECREASE || 0;
  const recheck = bucketCounts.RECHECK_REQUIRED || 0;
  const missing = stats.missingRows || 0;
  return {
    zeroOut,
    largeDecrease,
    recheck,
    missing,
    blocked: zeroOut + largeDecrease + recheck + missing,
  };
}

function renderChannelUploadGate({ panel, metricsEl, statusEl, channelName, stats, extraLine = "" }) {
  if (panel) panel.hidden = false;
  const counts = uploadGateReviewCounts(stats);
  if (metricsEl) {
    metricsEl.innerHTML = `
      <span>매칭 ${Number(stats.matchedRows || 0).toLocaleString()} / 변경 ${Number(stats.changedRows || 0).toLocaleString()}</span>
      <strong>${counts.blocked.toLocaleString()}건 업로드 전 검토 필요</strong>
      <small>0 변경 ${counts.zeroOut.toLocaleString()} · 큰 감소 ${counts.largeDecrease.toLocaleString()} · 재확인 ${counts.recheck.toLocaleString()} · 미발견 ${counts.missing.toLocaleString()}</small>
    `;
  }
  if (statusEl) {
    const riskText = counts.blocked
      ? `${channelName} 재고 반영 XLSX 생성 전 ${counts.blocked.toLocaleString()}건을 검토해야 합니다.`
      : `${channelName} 미리보기 기준 위험/미발견 건이 없습니다. 그래도 판매처 업로드 전 샘플 확인은 필요합니다.`;
    statusEl.textContent = extraLine ? `${riskText} ${extraLine}` : riskText;
  }
}

function renderSmartstorePreview(rows, stats) {
  if (!smartstorePreviewPanel || !smartstorePreviewTableBody) return;
  smartstorePreviewPanel.hidden = false;
  if (smartstoreUploadGatePanel) smartstoreUploadGatePanel.hidden = false;
  renderSmartstoreUploadGateMetrics(stats);
  document.getElementById("smartstorePreviewTotalRows").textContent = stats.totalRows.toLocaleString();
  document.getElementById("smartstorePreviewMatchedRows").textContent = stats.matchedRows.toLocaleString();
  document.getElementById("smartstorePreviewChangedRows").textContent = stats.changedRows.toLocaleString();
  document.getElementById("smartstorePreviewMissingRows").textContent = stats.missingRows.toLocaleString();
  document.getElementById("smartstorePreviewIncreaseRows").textContent = (stats.bucketCounts.INCREASE || 0).toLocaleString();
  document.getElementById("smartstorePreviewDecreaseRows").textContent = ((stats.bucketCounts.SMALL_DECREASE || 0) + (stats.bucketCounts.LARGE_DECREASE || 0)).toLocaleString();
  document.getElementById("smartstorePreviewZeroOutRows").textContent = (stats.bucketCounts.ZERO_OUT || 0).toLocaleString();
  document.getElementById("smartstorePreviewRecheckRows").textContent = (stats.bucketCounts.RECHECK_REQUIRED || 0).toLocaleString();
  if (smartstoreUploadGateStatus) {
    smartstoreUploadGateStatus.textContent = `업로드용 파일 생성 잠금: 재고 변경 ${stats.changedRows.toLocaleString()}개, 0 변경 ${(stats.bucketCounts.ZERO_OUT || 0).toLocaleString()}개, 큰 감소 ${(stats.bucketCounts.LARGE_DECREASE || 0).toLocaleString()}개를 먼저 확인해야 합니다.`;
  }

  const displayRows = filteredSmartstorePreviewRows();
  smartstorePreviewTableBody.innerHTML = "";
  displayRows.slice(0, 300).forEach((row) => {
    const tr = document.createElement("tr");
    tr.className = row.riskBucket === "ZERO_OUT" || row.riskBucket === "LARGE_DECREASE"
      ? "is-risk"
      : row.status === "CHANGE" ? "is-changed" : row.status === "NOT_FOUND" ? "is-missing" : "";
    tr.innerHTML = `
      <td>${escapeHtml(row.rowNumber)}</td>
      <td>${escapeHtml(row.productNo)}</td>
      <td>${escapeHtml(row.optionCode)}</td>
      <td>${escapeHtml(row.currentStock)}</td>
      <td>${escapeHtml(row.proposedStock)}</td>
      <td>${escapeHtml(row.stockDelta)}</td>
      <td>${escapeHtml(row.sellpiaSkuCode)}</td>
      <td>${escapeHtml(row.riskLabel)}</td>
      <td>${escapeHtml(row.statusLabel)}</td>
    `;
    smartstorePreviewTableBody.appendChild(tr);
  });
}

async function buildSmartstorePreviewFromBuffer(fileName, buffer, { statusPrefix = "원본양식" } = {}) {
  if (!window.ExcelJS) {
    alert("XLSX 파서가 아직 로드되지 않았습니다. 화면을 새로고침한 뒤 다시 시도해 주세요.");
    return false;
  }
  if (!smartstoreApplyByKey.size) {
    await loadSmartstoreApplyMap();
  }
  setSmartstorePreviewStatus(`${statusPrefix} XLSX 분석 중...`);

  const workbook = new window.ExcelJS.Workbook();
  await workbook.xlsx.load(buffer.slice(0));
  const worksheet = workbook.worksheets[0];
  const columns = findSmartstoreColumns(worksheet);
  if (!columns.productNo || !columns.optionCode || !columns.optionStock) {
    setSmartstorePreviewStatus("필수 컬럼을 찾지 못했습니다. 상품번호, 옵션번호/옵션코드, 재고수량 컬럼명이 필요합니다.");
    return false;
  }

  smartstoreOriginalWorkbook = workbook;
  smartstoreOriginalWorksheet = worksheet;
  smartstoreOriginalFileName = fileName;
  smartstoreOriginalFileBuffer = buffer.slice(0);
  smartstoreStockColumnIndex = columns.optionStock;
  smartstoreDetectedColumns = columns;
  smartstorePreviewRows = [];
  activeSmartstorePreviewBucket = "";
  smartstorePreviewBucketFilter?.querySelectorAll("[data-preview-bucket]").forEach((item) => {
    item.classList.toggle("is-active", item.dataset.previewBucket === "");
  });

  const seenApplyKeys = new Set();
  let totalRows = 0;
  let matchedRows = 0;
  let changedRows = 0;

  for (let rowNumber = columns.headerRow + 1; rowNumber <= worksheet.rowCount; rowNumber += 1) {
    const row = worksheet.getRow(rowNumber);
    const productNo = cellText(row.getCell(columns.productNo)).trim();
    if (!productNo) continue;
    totalRows += 1;

    const optionCodes = splitCellLines(cellText(row.getCell(columns.optionCode)));
    const optionStocks = splitCellLines(cellText(row.getCell(columns.optionStock)));
    const optionNames = columns.optionName ? splitCellLines(cellText(row.getCell(columns.optionName))) : [];

    optionCodes.forEach((optionCode, index) => {
      if (!optionCode) return;
      const key = `${productNo}|${optionCode}`;
      const apply = smartstoreApplyByKey.get(key);
      if (!apply) return;
      seenApplyKeys.add(key);
      matchedRows += 1;
      const currentStock = optionStocks[index] ?? "";
      const proposedStock = String(apply.proposed_option_stock ?? "");
      const currentNumber = Number(currentStock);
      const proposedNumber = Number(proposedStock);
      const changed = Number.isFinite(currentNumber) && Number.isFinite(proposedNumber)
        ? currentNumber !== proposedNumber
        : String(currentStock) !== proposedStock;
      if (changed) changedRows += 1;
      const bucket = smartstoreStockBucket(currentStock, proposedStock);
      const computedDelta = Number.isFinite(currentNumber) && Number.isFinite(proposedNumber)
        ? proposedNumber - currentNumber
        : apply.stock_delta ?? "";
      smartstorePreviewRows.push({
        rowNumber,
        optionLineNo: index + 1,
        productNo,
        optionCode,
        optionName: optionNames[index] || apply.smartstore_current_option_name || "",
        currentStock,
        proposedStock,
        stockDelta: computedDelta,
        sellpiaProductCode: apply.sellpia_product_code || "",
        sellpiaSkuCode: apply.sellpia_sku_code || "",
        sellpiaOptionName: apply.sellpia_option_name || "",
        riskBucket: bucket.bucket,
        riskLabel: bucket.label,
        riskNote: bucket.note,
        status: changed ? "CHANGE" : "NO_CHANGE",
        statusLabel: changed ? "변경" : "동일",
        apply,
      });
    });
  }

  const missingRows = smartstoreApplyRows.length - seenApplyKeys.size;
  const stats = { totalRows, matchedRows, changedRows, missingRows, bucketCounts: smartstorePreviewBucketCounts(smartstorePreviewRows) };
  renderSmartstorePreview(smartstorePreviewRows, stats);
  smartstorePreviewExportButton.disabled = !smartstorePreviewRows.length;
  smartstorePreviewCsvButton.disabled = !smartstorePreviewRows.length;
  smartstoreRiskReviewXlsxButton.disabled = !smartstorePreviewRows.some((row) => ["ZERO_OUT", "LARGE_DECREASE"].includes(row.riskBucket));
  setSmartstorePreviewStatus(
    `분석 완료: 원본 ${totalRows.toLocaleString()}행, 매칭 ${matchedRows.toLocaleString()}개, 재고 변경 ${changedRows.toLocaleString()}개, apply map 미발견 ${missingRows.toLocaleString()}개`
  );
  return true;
}

async function buildSmartstoreOriginalPreview() {
  const file = smartstoreOriginalInput?.files?.[0];
  if (!file) {
    alert("Smartstore 원본양식 XLSX를 먼저 선택해 주세요.");
    return;
  }
  await buildSmartstorePreviewFromBuffer(file.name, await file.arrayBuffer());
}

function downloadSmartstorePreviewCsv() {
  if (!smartstorePreviewRows.length) {
    alert("먼저 Smartstore 원본양식 preview를 생성해 주세요.");
    return;
  }
  const rows = smartstorePreviewRows.map((row) => ({
    "원본 행": row.rowNumber,
    "옵션 line": row.optionLineNo,
    "상품번호": row.productNo,
    "옵션번호": row.optionCode,
    "옵션명": row.optionName,
    "현재 재고": row.currentStock,
    "변경 재고": row.proposedStock,
    "차이": row.stockDelta,
    "위험 분류": row.riskLabel,
    "주의 메모": row.riskNote,
    "권장 태그": smartstoreRiskSuggestedTag(row),
    "Sellpia 상품코드": row.sellpiaProductCode,
    "Sellpia 옵션코드": row.sellpiaSkuCode,
    "Sellpia 옵션명": row.sellpiaOptionName,
    "상태": row.statusLabel,
  }));
  const headers = Object.keys(rows[0]);
  const csv = `\ufeff${[
    headers.map(csvEscape).join(","),
    ...rows.map((row) => headers.map((header) => csvEscape(row[header])).join(",")),
  ].join("\r\n")}`;
  downloadBlob(
    new Blob([csv], { type: "text/csv;charset=utf-8" }),
    `smartstore_stock_change_preview_${formatTimestamp()}.csv`
  );
}

async function downloadSmartstoreSelectedApplyXlsx() {
  if (!smartstoreOriginalFileBuffer || !smartstorePreviewRows.length) {
    alert("먼저 Smartstore 원본양식 preview를 생성해 주세요.");
    return;
  }
  if (!window.ExcelJS) {
    alert("XLSX 파서가 아직 로드되지 않았습니다. 화면을 새로고침한 뒤 다시 시도해 주세요.");
    return;
  }

  const scopes = selectedSmartstoreApplyScopes();
  if (!scopes.stock && !scopes.price && !scopes.cellEdits) {
    alert("적용할 항목을 하나 이상 선택해 주세요. 상품명/옵션명, 가격, 재고 중 선택 가능합니다.");
    return;
  }

  const workbook = new window.ExcelJS.Workbook();
  await workbook.xlsx.load(smartstoreOriginalFileBuffer.slice(0));
  const worksheet = workbook.worksheets[0];
  const columns = smartstoreDetectedColumns || findSmartstoreColumns(worksheet);
  const records = [];
  const warnings = [];

  if (scopes.stock) {
    applySmartstoreStockChanges(worksheet, columns, records);
    addSmartstoreStockCorrectionSheet(workbook, worksheet, columns);
  }
  if (scopes.price) {
    applySmartstorePriceChanges(worksheet, columns, records, warnings);
  }
  if (scopes.cellEdits) {
    applySmartstoreCellEdits(worksheet, columns, records, warnings);
  }

  addSmartstoreApplySummarySheets(workbook, records, warnings, scopes, {
    matchedRows: smartstorePreviewRows.length,
    changedRows: smartstorePreviewRows.filter((row) => row.status === "CHANGE").length,
  });
  normalizeOriginalSheetApplyFills(worksheet, records, { clearExistingYellow: true });

  const buffer = await workbook.xlsx.writeBuffer();
  const baseName = smartstoreOriginalFileName.replace(/\.[^.]+$/, "");
  const scopeSuffix = Object.entries(scopes)
    .filter(([, enabled]) => enabled)
    .map(([scope]) => scope === "cellEdits" ? "cell" : scope)
    .join("_") || "none";
  downloadBlob(
    new Blob([buffer], {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    }),
    `${baseName || "smartstore"}_selected_apply_${scopeSuffix}_${formatTimestamp()}.xlsx`
  );
}

async function downloadSmartstoreYellowFillXlsx() {
  if (!smartstoreOriginalWorkbook || !smartstoreOriginalWorksheet || !smartstorePreviewRows.length) {
    alert("먼저 Smartstore 원본양식 preview를 생성해 주세요.");
    return;
  }

  const rowsByOriginalRow = new Map();
  smartstorePreviewRows.forEach((preview) => {
    if (!rowsByOriginalRow.has(preview.rowNumber)) rowsByOriginalRow.set(preview.rowNumber, []);
    rowsByOriginalRow.get(preview.rowNumber).push(preview);
  });

  rowsByOriginalRow.forEach((previews, rowNumber) => {
    const row = smartstoreOriginalWorksheet.getRow(rowNumber);
    const stockCell = row.getCell(smartstoreStockColumnIndex);
    const stockLines = splitCellLines(cellText(stockCell));
    let changed = false;
    previews.forEach((preview) => {
      const index = preview.optionLineNo - 1;
      if (stockLines[index] !== preview.proposedStock) {
        stockLines[index] = preview.proposedStock;
        changed = true;
      }
    });
    if (changed) {
      stockCell.value = stockLines.join("\n");
      stockCell.alignment = { ...(stockCell.alignment || {}), wrapText: true, vertical: "top" };
      stockCell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FFFFFF00" } };
    }
  });

  const reviewSheet = smartstoreOriginalWorkbook.addWorksheet("검토요약");
  const bucketCounts = smartstorePreviewBucketCounts(smartstorePreviewRows);
  reviewSheet.columns = [
    { header: "항목", key: "name", width: 24 },
    { header: "내용", key: "value", width: 80 },
  ];
  reviewSheet.addRows([
    { name: "파일 목적", value: "검토용입니다. 판매처 업로드 전 사람이 변경 내용을 확인하기 위한 파일입니다." },
    { name: "원본 파일", value: smartstoreOriginalFileName },
    { name: "변경 후보", value: smartstorePreviewRows.length },
    { name: "증가", value: bucketCounts.INCREASE || 0 },
    { name: "소폭 감소", value: bucketCounts.SMALL_DECREASE || 0 },
    { name: "큰 감소", value: bucketCounts.LARGE_DECREASE || 0 },
    { name: "0으로 변경", value: bucketCounts.ZERO_OUT || 0 },
    { name: "재확인 필요", value: bucketCounts.RECHECK_REQUIRED || 0 },
    { name: "주의", value: "노란색 셀은 셀피아 기준 재고로 변경 preview가 적용된 셀입니다. 실제 판매처 업로드는 별도 승인 후 진행해야 합니다." },
    { name: "생성 시각", value: new Date().toLocaleString("ko-KR") },
  ]);
  reviewSheet.getRow(1).font = { bold: true };
  reviewSheet.getColumn(2).alignment = { wrapText: true, vertical: "top" };

  const buffer = await smartstoreOriginalWorkbook.xlsx.writeBuffer();
  const baseName = smartstoreOriginalFileName.replace(/\.[^.]+$/, "");
  downloadBlob(
    new Blob([buffer], {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    }),
    `${baseName || "smartstore"}_stock_preview_yellow_${formatTimestamp()}.xlsx`
  );
}

function addRiskReviewSheet(workbook, sheetName, rows, fillColor) {
  const worksheet = workbook.addWorksheet(sheetName);
  const exportRows = smartstoreRiskReviewRows(rows);
  const headers = exportRows.length
    ? Object.keys(exportRows[0])
    : ["위험 분류", "권장 태그", "검토 메모", "원본 행", "상품번호", "옵션번호", "현재 재고", "변경 재고", "차이"];
  worksheet.columns = headers.map((header) => ({
    header,
    key: header,
    width: {
      "위험 분류": 16,
      "권장 태그": 22,
      "검토 메모": 42,
      "원본 행": 10,
      "옵션 line": 10,
      "상품번호": 18,
      "옵션번호": 20,
      "옵션명": 28,
      "현재 재고": 12,
      "변경 재고": 12,
      "차이": 10,
      "Sellpia 상품코드": 16,
      "Sellpia 옵션코드": 16,
      "Sellpia 옵션명": 28,
      "상태": 10,
    }[header] || 18,
  }));
  exportRows.forEach((row) => worksheet.addRow(row));
  worksheet.views = [{ state: "frozen", ySplit: 1 }];
  worksheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: headers.length },
  };
  worksheet.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF111827" } };
  });
  worksheet.eachRow((row, rowNumber) => {
    if (rowNumber === 1) return;
    row.eachCell((cell) => {
      cell.alignment = { vertical: "top", horizontal: typeof cell.value === "number" ? "right" : "left", wrapText: true };
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: fillColor } };
      cell.border = { bottom: { style: "hair", color: { argb: "FFE2E8F0" } } };
    });
  });
  return worksheet;
}

async function downloadSmartstoreRiskReviewXlsx() {
  const zeroOutRows = smartstorePreviewRows.filter((row) => row.riskBucket === "ZERO_OUT");
  const largeDecreaseRows = smartstorePreviewRows.filter((row) => row.riskBucket === "LARGE_DECREASE");
  const recheckRows = smartstorePreviewRows.filter((row) => row.riskBucket === "RECHECK_REQUIRED");
  const riskRows = [...zeroOutRows, ...largeDecreaseRows, ...recheckRows];

  if (!riskRows.length) {
    alert("위험 변경 후보가 없습니다.");
    return;
  }
  if (!window.ExcelJS) {
    alert("XLSX 생성 라이브러리를 불러오지 못했습니다.");
    return;
  }

  const workbook = new window.ExcelJS.Workbook();
  workbook.creator = "System v1 local review";
  workbook.created = new Date();

  const summary = workbook.addWorksheet("요약");
  summary.columns = [
    { header: "항목", key: "name", width: 26 },
    { header: "값", key: "value", width: 72 },
  ];
  summary.addRows([
    { name: "파일 목적", value: "Smartstore 재고 변경 중 위험 후보만 따로 검토하기 위한 파일입니다. 판매처 업로드용이 아닙니다." },
    { name: "원본 파일", value: smartstoreOriginalFileName || "-" },
    { name: "0으로 변경", value: zeroOutRows.length },
    { name: "큰 감소", value: largeDecreaseRows.length },
    { name: "재확인 필요", value: recheckRows.length },
    { name: "권장 작업", value: "0으로 변경과 큰 감소는 업로드-ready 전 사람이 먼저 확인합니다. 문제가 있으면 화면에서 태그를 붙기거나 이후 연동끊기/보류로 처리합니다." },
    { name: "생성 시각", value: new Date().toLocaleString("ko-KR") },
  ]);
  summary.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF111827" } };
  });
  summary.getColumn(2).alignment = { wrapText: true, vertical: "top" };

  addRiskReviewSheet(workbook, "0으로 변경", zeroOutRows, "FFFFE4E6");
  addRiskReviewSheet(workbook, "큰 감소", largeDecreaseRows, "FFFFEDD5");
  addRiskReviewSheet(workbook, "재확인 필요", recheckRows, "FFFFF7ED");
  addRiskReviewSheet(workbook, "전체 위험 후보", riskRows, "FFFFF7ED");

  const buffer = await workbook.xlsx.writeBuffer();
  downloadBlob(
    new Blob([buffer], {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    }),
    `smartstore_stock_risk_review_${formatTimestamp()}.xlsx`
  );
}

function requireExcelJsForGeneratedExport() {
  if (!window.ExcelJS) {
    alert("XLSX 생성 라이브러리를 불러오지 못했습니다. 새로고침 후 다시 시도해 주세요.");
    return false;
  }
  return true;
}

function generatedExportCellFill(status, changed) {
  if (status === "재확인 필요") return "FFFEF3C7";
  if (status === "제외") return "FFE9D5FF";
  if (status === "미매칭") return "FFFFEDD5";
  if (changed) return "FFFFFF00";
  if (status === "재고일치" || status === "동일") return "FFE0F2FE";
  return "FFFFFFFF";
}

function styleGeneratedWorksheet(worksheet, stockHeader = "재고수량") {
  worksheet.views = [{ state: "frozen", ySplit: 1 }];
  worksheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: worksheet.columnCount },
  };
  worksheet.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF111827" } };
    cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
  });
  const stockColumn = worksheet.columns.findIndex((column) => column.header === stockHeader) + 1;
  worksheet.eachRow((row, rowNumber) => {
    if (rowNumber === 1) return;
    row.eachCell({ includeEmpty: true }, (cell, columnNumber) => {
      cell.alignment = { vertical: "top", wrapText: true };
      cell.border = { bottom: { style: "hair", color: { argb: "FFE2E8F0" } } };
      if (columnNumber === stockColumn) {
        const changed = String(row.getCell("변경여부").value || "") === "Y";
        const status = String(row.getCell("상태").value || "");
        cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: generatedExportCellFill(status, changed) } };
      }
    });
  });
}

function addGeneratedExportGuideSheet(workbook, channelName, rows, changedCount, warnings = []) {
  const guide = workbook.addWorksheet("안내");
  guide.columns = [
    { header: "항목", key: "name", width: 28 },
    { header: "내용", key: "value", width: 88 },
  ];
  guide.addRows([
    { name: "파일 목적", value: `${channelName} 현재 데이터 기준 빠른사용 XLSX입니다. 원본 파일을 업로드하지 않고 만든 파일이라 판매처 실제 업로드 전 샘플 확인이 필요합니다.` },
    { name: "생성 기준", value: "프론트에 포함된 apply map과 Supabase 최신 셀피아 재고를 사용했습니다." },
    { name: "수정 항목", value: "상품코드/옵션코드는 수정하지 않습니다. 현재 자동 생성은 재고 중심이며 상품명/옵션명/가격은 검토 컬럼으로만 보존합니다." },
    { name: "전체 행", value: rows.length },
    { name: "재고 변경 행", value: changedCount },
    { name: "주의", value: "판매처 원본양식 업로드 후 수정 방식이 가장 안전합니다. 이 파일은 빠른 확인과 일부 사용을 위한 원본형 생성 파일입니다." },
    { name: "경고", value: warnings.length ? warnings.join("\n") : "없음" },
    { name: "생성 시각", value: new Date().toLocaleString("ko-KR") },
  ]);
  guide.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF111827" } };
  });
  guide.getColumn(2).alignment = { wrapText: true, vertical: "top" };
}

function addGeneratedCompareSheet(workbook, rows) {
  const sheet = workbook.addWorksheet("대조표");
  const exportRows = rows.map((row) => ({
    "상태": row.status,
    "판매처": row.channel,
    "상품코드": row.productCode,
    "옵션코드": row.optionCode,
    "판매처 상품명": row.productName,
    "판매처 옵션명": row.optionName,
    "셀피아 상품코드": row.sellpiaProductCode,
    "셀피아 옵션코드": row.sellpiaSkuCode,
    "셀피아 상품명": row.sellpiaProductName,
    "셀피아 옵션명": row.sellpiaOptionName,
    "현재 재고": row.currentStock,
    "변경 재고": row.proposedStock,
    "차이": row.stockDelta,
    "변경여부": row.changed ? "Y" : "N",
    "메모": row.note,
  }));
  const headers = Object.keys(exportRows[0] || { "상태": "", "판매처": "", "상품코드": "", "옵션코드": "", "현재 재고": "", "변경 재고": "", "변경여부": "", "메모": "" });
  sheet.columns = headers.map((header) => ({
    header,
    key: header,
    width: {
      "판매처 상품명": 36,
      "판매처 옵션명": 32,
      "셀피아 상품명": 32,
      "셀피아 옵션명": 26,
      "메모": 42,
    }[header] || 16,
  }));
  exportRows.forEach((row) => sheet.addRow(row));
  styleGeneratedWorksheet(sheet, "변경 재고");
}

function stockCompareValues(currentStock, proposedStock, bucketFn) {
  const currentNumber = Number(currentStock);
  const proposedNumber = Number(proposedStock);
  const canCompare = Number.isFinite(currentNumber) && Number.isFinite(proposedNumber);
  const changed = canCompare ? currentNumber !== proposedNumber : String(currentStock ?? "") !== String(proposedStock ?? "");
  const delta = canCompare ? proposedNumber - currentNumber : "";
  const bucket = bucketFn(currentStock, proposedStock);
  return { changed, delta, bucket };
}

function addRowsWithPlainObjectColumns(worksheet, rows, widths = {}) {
  const headers = Object.keys(rows[0] || {});
  worksheet.columns = headers.map((header) => ({ header, key: header, width: widths[header] || 16 }));
  rows.forEach((row) => worksheet.addRow(row));
}

async function downloadSmartstoreGeneratedTemplateXlsx() {
  if (!requireExcelJsForGeneratedExport()) return;
  const savedTemplate = await getSellerTemplate("smartstore").catch(() => null);
  if (savedTemplate?.buffer) {
    const ok = await buildSmartstorePreviewFromBuffer(savedTemplate.fileName, savedTemplate.buffer, { statusPrefix: "저장된 Smartstore 원본양식" });
    if (ok) {
      setSellerTemplateStatus(`저장된 Smartstore 원본양식(${savedTemplate.fileName}) 기준으로 원본양식 기준 XLSX를 생성했습니다.`);
      await downloadSmartstoreSelectedApplyXlsx();
      return;
    }
  }
  const builtinTemplate = await getBuiltinSellerTemplate("smartstore");
  if (builtinTemplate?.buffer) {
    const ok = await buildSmartstorePreviewFromBuffer(builtinTemplate.fileName, builtinTemplate.buffer, { statusPrefix: "기본 Smartstore 원본양식" });
    if (ok) {
      setSellerTemplateStatus(`기본 Smartstore 원본양식(${builtinTemplate.fileName}) 기준으로 원본양식 기준 XLSX를 생성했습니다.`);
      await downloadSmartstoreSelectedApplyXlsx();
      return;
    }
  }
  alert("Smartstore 원본양식을 찾지 못했습니다. 먼저 템플릿 저장/관리에서 Smartstore 원본양식 XLSX를 저장해 주세요.");
}

async function downloadMakeshopGeneratedTemplateXlsx() {
  if (!requireExcelJsForGeneratedExport()) return;
  const savedTemplate = await getSellerTemplate("makeshop").catch(() => null);
  if (savedTemplate?.buffer) {
    const ok = await buildMakeshopPreviewFromBuffer(savedTemplate.fileName, savedTemplate.buffer, { statusPrefix: "저장된 MakeShop 원본양식" });
    if (ok) {
      setSellerTemplateStatus(`저장된 MakeShop 원본양식(${savedTemplate.fileName}) 기준으로 원본양식 기준 XLSX를 생성했습니다.`);
      await downloadMakeshopStockApplyXlsx();
      return;
    }
  }
  const builtinTemplate = await getBuiltinSellerTemplate("makeshop");
  if (builtinTemplate?.buffer) {
    const ok = await buildMakeshopPreviewFromBuffer(builtinTemplate.fileName, builtinTemplate.buffer, { statusPrefix: "기본 MakeShop 원본양식" });
    if (ok) {
      setSellerTemplateStatus(`기본 MakeShop 원본양식(${builtinTemplate.fileName}) 기준으로 원본양식 기준 XLSX를 생성했습니다.`);
      await downloadMakeshopStockApplyXlsx();
      return;
    }
  }
  alert("MakeShop 원본양식을 찾지 못했습니다. 먼저 템플릿 저장/관리에서 MakeShop 원본양식 XLSX를 저장해 주세요.");
}

async function downloadAblyGeneratedTemplateXlsx() {
  if (!requireExcelJsForGeneratedExport()) return;
  const savedTemplate = await getSellerTemplate("ably").catch(() => null);
  if (savedTemplate?.buffer) {
    const ok = await buildAblyPreviewFromBuffer(savedTemplate.fileName, savedTemplate.buffer, { statusPrefix: "저장된 Ably 원본양식" });
    if (ok) {
      setSellerTemplateStatus(`저장된 Ably 원본양식(${savedTemplate.fileName}) 기준으로 원본양식 기준 XLSX를 생성했습니다.`);
      await downloadAblyStockApplyXlsx();
      return;
    }
  }
  const builtinTemplate = await getBuiltinSellerTemplate("ably");
  if (builtinTemplate?.buffer) {
    const ok = await buildAblyPreviewFromBuffer(builtinTemplate.fileName, builtinTemplate.buffer, { statusPrefix: "기본 Ably 원본양식" });
    if (ok) {
      setSellerTemplateStatus(`기본 Ably 원본양식(${builtinTemplate.fileName}) 기준으로 원본양식 기준 XLSX를 생성했습니다.`);
      await downloadAblyStockApplyXlsx();
      return;
    }
  }
  alert("Ably 원본양식을 찾지 못했습니다. 먼저 템플릿 저장/관리에서 Ably 원본양식 XLSX를 저장해 주세요.");
}

function setMakeshopPreviewStatus(message) {
  if (makeshopOriginalStatus) makeshopOriginalStatus.textContent = message;
}

function findMakeshopColumns(worksheet) {
  const result = {
    headerRow: null,
    productUid: null,
    productName: null,
    optionValue: null,
    stoId: null,
    stoStock: null,
    stoState: null,
  };
  const maxRows = Math.min(8, worksheet.rowCount || 8);
  const maxCols = Math.min(180, worksheet.columnCount || 180);

  for (let rowNumber = 1; rowNumber <= maxRows; rowNumber += 1) {
    const row = worksheet.getRow(rowNumber);
    const candidates = {};
    for (let colNumber = 1; colNumber <= maxCols; colNumber += 1) {
      const header = normalizedHeader(cellText(row.getCell(colNumber)));
      if (!header) continue;
      if (header === "product_uid") candidates.productUid = colNumber;
      if (header === "product_name") candidates.productName = colNumber;
      if (header === "opt_values" || header === "opt_value") candidates.optionValue = colNumber;
      if (header === "sto_id") candidates.stoId = colNumber;
      if (header === "sto_stock") candidates.stoStock = colNumber;
      if (header === "sto_state") candidates.stoState = colNumber;
    }
    if (candidates.productUid && candidates.stoId && candidates.stoStock) {
      return { ...result, ...candidates, headerRow: rowNumber };
    }
  }

  return { ...result };
}

function makeshopColumnHeader(worksheet, columns, columnNumber) {
  return cellText(worksheet.getRow(columns.headerRow).getCell(columnNumber)) || columnName(columnNumber);
}

function stockCellValue(value) {
  const text = String(value ?? "").trim();
  if (text !== "" && Number.isFinite(Number(text))) return Number(text);
  return text;
}

function makeshopStockBucket(currentStock, proposedStock) {
  const current = Number(currentStock);
  const proposed = Number(proposedStock);
  if (!Number.isFinite(current) || !Number.isFinite(proposed)) {
    return { bucket: "RECHECK_REQUIRED", label: "재확인 필요", note: "재고값을 숫자로 해석할 수 없습니다." };
  }
  const delta = proposed - current;
  const absDelta = Math.abs(delta);
  const relativeDecrease = current > 0 ? absDelta / current : 0;
  if (delta === 0) return { bucket: "NO_CHANGE", label: "재고일치", note: "재고 변경 없음" };
  if (proposed === 0 && current > 0) return { bucket: "ZERO_OUT", label: "0으로 변경", note: "현재 재고가 0으로 바뀌므로 확인이 필요합니다." };
  if (delta > 0) return { bucket: "INCREASE", label: "증가", note: "Sellpia 기준 재고가 MakeShop보다 큽니다." };
  if (absDelta >= 20 || relativeDecrease >= 0.5) return { bucket: "LARGE_DECREASE", label: "큰 감소", note: "감소폭이 커서 샘플 확인이 필요합니다." };
  return { bucket: "SMALL_DECREASE", label: "소폭 감소", note: "소폭 감소 후보입니다." };
}

function makeshopPreviewBucketCounts(rows) {
  return rows.reduce((acc, row) => {
    acc[row.riskBucket] = (acc[row.riskBucket] || 0) + 1;
    return acc;
  }, {});
}

function renderMakeshopPreview(stats) {
  if (!makeshopPreviewPanel || !makeshopPreviewTableBody) return;
  makeshopPreviewPanel.hidden = false;
  renderChannelUploadGate({
    panel: makeshopUploadGatePanel,
    metricsEl: makeshopUploadGateMetrics,
    statusEl: makeshopUploadGateStatus,
    channelName: "MakeShop",
    stats,
    extraLine: "현재 버튼은 원본양식 기반 검토용 XLSX만 생성합니다.",
  });
  document.getElementById("makeshopPreviewTotalRows").textContent = stats.totalRows.toLocaleString();
  document.getElementById("makeshopPreviewMatchedRows").textContent = stats.matchedRows.toLocaleString();
  document.getElementById("makeshopPreviewChangedRows").textContent = stats.changedRows.toLocaleString();
  document.getElementById("makeshopPreviewMissingRows").textContent = stats.missingRows.toLocaleString();
  document.getElementById("makeshopPreviewIncreaseRows").textContent = (stats.bucketCounts.INCREASE || 0).toLocaleString();
  document.getElementById("makeshopPreviewDecreaseRows").textContent = ((stats.bucketCounts.SMALL_DECREASE || 0) + (stats.bucketCounts.LARGE_DECREASE || 0)).toLocaleString();
  document.getElementById("makeshopPreviewZeroOutRows").textContent = (stats.bucketCounts.ZERO_OUT || 0).toLocaleString();
  document.getElementById("makeshopPreviewRecheckRows").textContent = (stats.bucketCounts.RECHECK_REQUIRED || 0).toLocaleString();

  makeshopPreviewTableBody.innerHTML = "";
  makeshopPreviewRows.slice(0, 300).forEach((row) => {
    const tr = document.createElement("tr");
    tr.className = row.riskBucket === "ZERO_OUT" || row.riskBucket === "LARGE_DECREASE"
      ? "is-risk"
      : row.status === "CHANGE" ? "is-changed" : "";
    tr.innerHTML = `
      <td>${escapeHtml(row.rowNumber)}</td>
      <td>${escapeHtml(row.productUid)}</td>
      <td>${escapeHtml(row.stoId)}</td>
      <td>${escapeHtml(row.optionValue)}</td>
      <td>${escapeHtml(row.currentStock)}</td>
      <td>${escapeHtml(row.proposedStock)}</td>
      <td>${escapeHtml(row.stockDelta)}</td>
      <td>${escapeHtml(row.sellpiaSkuCode)}</td>
      <td>${escapeHtml(row.statusLabel)}</td>
    `;
    makeshopPreviewTableBody.appendChild(tr);
  });
}

async function buildMakeshopPreviewFromBuffer(fileName, buffer, { statusPrefix = "MakeShop 원본양식" } = {}) {
  if (!window.ExcelJS) {
    alert("XLSX 파서가 아직 로드되지 않았습니다. 화면을 새로고침한 뒤 다시 시도해 주세요.");
    return false;
  }
  if (!makeshopApplyByKey.size) {
    await loadMakeshopApplyMap();
  }
  if (!makeshopCompareByKey.size) {
    await loadMakeshopCompareMap();
  }
  await loadLatestSellpiaStockSnapshot({ silent: true });
  setMakeshopPreviewStatus(`${statusPrefix} XLSX 분석 중...`);

  const workbook = new window.ExcelJS.Workbook();
  await workbook.xlsx.load(buffer.slice(0));
  const worksheet = workbook.worksheets[0];
  const columns = findMakeshopColumns(worksheet);
  if (!columns.productUid || !columns.stoId || !columns.stoStock) {
    setMakeshopPreviewStatus("필수 컬럼을 찾지 못했습니다. product_uid, sto_id, sto_stock 컬럼이 있는 MakeShop 원본양식이 필요합니다.");
    return false;
  }

  makeshopOriginalFileName = fileName;
  makeshopOriginalFileBuffer = buffer.slice(0);
  makeshopDetectedColumns = columns;
  makeshopPreviewRows = [];
  makeshopMissingApplyRows = [];

  const seenApplyKeys = new Set();
  let currentProductUid = "";
  let currentProductName = "";
  let totalRows = 0;
  let matchedRows = 0;
  let changedRows = 0;

  for (let rowNumber = columns.headerRow + 1; rowNumber <= worksheet.rowCount; rowNumber += 1) {
    const row = worksheet.getRow(rowNumber);
    const rawProductUid = cellText(row.getCell(columns.productUid)).trim();
    const rawProductName = columns.productName ? cellText(row.getCell(columns.productName)).trim() : "";
    if (rawProductUid) currentProductUid = rawProductUid;
    if (rawProductName) currentProductName = rawProductName;
    const productUid = currentProductUid;
    const stoId = cellText(row.getCell(columns.stoId)).trim();
    if (!productUid || !stoId) continue;
    totalRows += 1;

    const key = `${productUid}|${stoId}`;
    const apply = makeshopApplyByKey.get(key);
    if (!apply) continue;
    const compare = makeshopCompareByKey.get(key);
    const stockOverride = sellpiaStockOverrideFor(apply, compare);
    seenApplyKeys.add(key);
    matchedRows += 1;

    const currentStock = cellText(row.getCell(columns.stoStock)).trim();
    const proposedStock = String(stockOverride?.proposedStock ?? apply.proposed_sto_stock ?? "").trim();
    const currentNumber = Number(currentStock);
    const proposedNumber = Number(proposedStock);
    const changed = Number.isFinite(currentNumber) && Number.isFinite(proposedNumber)
      ? currentNumber !== proposedNumber
      : currentStock !== proposedStock;
    if (changed) changedRows += 1;
    const bucket = makeshopStockBucket(currentStock, proposedStock);
    const computedDelta = Number.isFinite(currentNumber) && Number.isFinite(proposedNumber)
      ? proposedNumber - currentNumber
      : apply.stock_delta ?? "";

    makeshopPreviewRows.push({
      rowNumber,
      productUid,
      stoId,
      productName: currentProductName || apply.makeshop_product_name || "",
      optionValue: columns.optionValue ? cellText(row.getCell(columns.optionValue)).trim() : apply.makeshop_option_value || "",
      currentStock,
      proposedStock,
      stockDelta: computedDelta,
      sellpiaProductCode: stockOverride?.sellpiaProductCode || apply.sellpia_product_code || "",
      sellpiaSkuCode: stockOverride?.sellpiaSkuCode || apply.sellpia_sku_code || "",
      sellpiaProductName: stockOverride?.sellpiaProductName || apply.sellpia_product_name || "",
      sellpiaOptionName: stockOverride?.sellpiaOptionName || apply.sellpia_option_name || "",
      riskBucket: bucket.bucket,
      riskLabel: bucket.label,
      riskNote: bucket.note,
      status: changed ? "CHANGE" : "NO_CHANGE",
      statusLabel: changed ? "불일치" : "재고일치",
      stockSource: stockOverride?.sourceLabel || apply.candidate_source || "makeshop_stock_apply_map",
      apply,
    });
  }

  makeshopMissingApplyRows = makeshopApplyRows.filter((row) => {
    const key = `${String(row.makeshop_product_uid || "").trim()}|${String(row.makeshop_sto_id || "").trim()}`;
    return key !== "|" && !seenApplyKeys.has(key);
  });
  const stats = {
    totalRows,
    matchedRows,
    changedRows,
    missingRows: makeshopMissingApplyRows.length,
    bucketCounts: makeshopPreviewBucketCounts(makeshopPreviewRows),
  };
  renderMakeshopPreview(stats);
  makeshopPreviewExportButton.disabled = !makeshopPreviewRows.length;
  makeshopPreviewCsvButton.disabled = !makeshopPreviewRows.length;
  setMakeshopPreviewStatus(
    `분석 완료: 원본 옵션행 ${totalRows.toLocaleString()}개, 매칭 ${matchedRows.toLocaleString()}개, 재고 변경 ${changedRows.toLocaleString()}개, apply map 미발견 ${makeshopMissingApplyRows.length.toLocaleString()}개`
  );
  return true;
}

async function buildMakeshopOriginalPreview() {
  const file = makeshopOriginalInput?.files?.[0];
  if (!file) {
    alert("MakeShop 원본양식 XLSX를 먼저 선택해 주세요.");
    return;
  }
  await buildMakeshopPreviewFromBuffer(file.name, await file.arrayBuffer());
}

function changedMakeshopPreviewRows() {
  return makeshopPreviewRows.filter((preview) => String(preview.currentStock ?? "") !== String(preview.proposedStock ?? ""));
}

function applyMakeshopStockChanges(worksheet, columns, records) {
  changedMakeshopPreviewRows().forEach((preview) => {
    const row = worksheet.getRow(preview.rowNumber);
    const stockCell = row.getCell(columns.stoStock);
    const beforeValue = cellText(stockCell).trim();
    stockCell.value = stockCellValue(preview.proposedStock);
    stockCell.alignment = { ...(stockCell.alignment || {}), vertical: "top" };
    applyFill(stockCell, "FFFFFF00");
    records.push({
      scopeLabel: "재고수정",
      rowNumber: preview.rowNumber,
      columnNumber: columns.stoStock,
      columnHeader: makeshopColumnHeader(worksheet, columns, columns.stoStock),
      productUid: preview.productUid,
      stoId: preview.stoId,
      beforeValue,
      afterValue: preview.proposedStock,
      riskBucket: preview.riskBucket,
      source: preview.stockSource || preview.apply?.candidate_source || "makeshop_stock_apply_map",
    });
  });
}

function addMakeshopStockCorrectionSheet(workbook, sourceWorksheet, columns) {
  const changedRows = changedMakeshopPreviewRows();
  if (!changedRows.length) return;

  const correctionSheet = workbook.addWorksheet(uniqueWorksheetName(workbook, "메이크샵 재고수정"));
  const maxColumn = sourceWorksheet.columnCount || 28;
  const headerEndRow = columns.headerRow || 2;

  for (let columnNumber = 1; columnNumber <= maxColumn; columnNumber += 1) {
    const sourceColumn = sourceWorksheet.getColumn(columnNumber);
    const targetColumn = correctionSheet.getColumn(columnNumber);
    targetColumn.width = sourceColumn.width;
    targetColumn.hidden = sourceColumn.hidden;
    targetColumn.style = cloneExcelStyle(sourceColumn.style);
  }

  for (let rowNumber = 1; rowNumber <= headerEndRow; rowNumber += 1) {
    copySmartstoreWorksheetRow(sourceWorksheet.getRow(rowNumber), correctionSheet.getRow(rowNumber), maxColumn);
  }

  let targetRowNumber = headerEndRow + 1;
  changedRows.forEach((preview) => {
    const targetRow = correctionSheet.getRow(targetRowNumber);
    copySmartstoreWorksheetRow(sourceWorksheet.getRow(preview.rowNumber), targetRow, maxColumn);
    const stockCell = targetRow.getCell(columns.stoStock);
    stockCell.value = stockCellValue(preview.proposedStock);
    applyFill(stockCell, "FFFFFF00");
    targetRow.commit?.();
    targetRowNumber += 1;
  });

  correctionSheet.views = [{ state: "frozen", ySplit: headerEndRow }];
  correctionSheet.autoFilter = {
    from: { row: columns.headerRow, column: 1 },
    to: { row: columns.headerRow, column: maxColumn },
  };
}

function makeshopCompareStatusLabel(status) {
  return {
    STOCK_MATCH: "재고일치",
    STOCK_DIFF: "불일치",
    MAKESHOP_UNLIMITED_STOCK: "특수재고",
    MULTI_STAGE_MATCH: "중복매칭",
    STAGE_NOT_FOUND: "미매칭",
    DECISION_KEY_STOCK_MATCH: "승인키 재고일치",
    DECISION_KEY_STOCK_DIFF: "승인키 불일치",
    DECISION_KEY_SPECIAL_STOCK: "승인키 특수재고",
    AUTO_APPROVAL_STOCK_MATCH: "자동승인 재고일치",
    AUTO_APPROVAL_STOCK_DIFF: "자동승인 불일치",
    AUTO_APPROVAL_STOCK_RECHECK: "자동승인 재고확인",
  }[status] || status || "미매칭";
}

function makeshopCompareFill(status) {
  if (status === "불일치" || status === "STOCK_DIFF" || status === "승인키 불일치" || status === "자동승인 불일치") return "FFFFE4E6";
  if (status === "재고일치" || status === "STOCK_MATCH" || status === "승인키 재고일치" || status === "자동승인 재고일치") return "FFE0F2FE";
  if (status === "미매칭" || status === "STAGE_NOT_FOUND") return "FFFFEDD5";
  if (status === "중복매칭" || status === "MULTI_STAGE_MATCH") return "FFFFF7ED";
  if (status === "특수재고" || status === "MAKESHOP_UNLIMITED_STOCK" || status === "승인키 특수재고" || status === "자동승인 재고확인") return "FFFEF3C7";
  return "FFFFFFFF";
}

function addMakeshopStockCompareSheet(workbook, sourceWorksheet, columns) {
  const compareSheet = workbook.addWorksheet(uniqueWorksheetName(workbook, "대조표"));
  compareSheet.columns = [
    { header: "상태", key: "status", width: 14 },
    { header: "원본 행", key: "rowNumber", width: 10 },
    { header: "MakeShop 상품고유번호", key: "productUid", width: 18 },
    { header: "MakeShop 옵션번호", key: "stoId", width: 14 },
    { header: "MakeShop 상품명", key: "productName", width: 34 },
    { header: "MakeShop 옵션값", key: "optionValue", width: 30 },
    { header: "셀피아 재고", key: "sellpiaStock", width: 12 },
    { header: "MakeShop 재고수", key: "currentStock", width: 14 },
    { header: "변경 재고", key: "proposedStock", width: 12 },
    { header: "차이", key: "stockDelta", width: 10 },
    { header: "셀피아 상품코드", key: "sellpiaProductCode", width: 16 },
    { header: "셀피아 옵션코드", key: "sellpiaSkuCode", width: 16 },
    { header: "셀피아 상품명", key: "sellpiaProductName", width: 30 },
    { header: "셀피아 옵션명", key: "sellpiaOptionName", width: 24 },
    { header: "검토 메모", key: "note", width: 42 },
  ];

  let currentProductUid = "";
  let currentProductName = "";
  const seenCompareKeys = new Set();
  for (let rowNumber = columns.headerRow + 1; rowNumber <= sourceWorksheet.rowCount; rowNumber += 1) {
    const row = sourceWorksheet.getRow(rowNumber);
    const rawProductUid = cellText(row.getCell(columns.productUid)).trim();
    const rawProductName = columns.productName ? cellText(row.getCell(columns.productName)).trim() : "";
    if (rawProductUid) currentProductUid = rawProductUid;
    if (rawProductName) currentProductName = rawProductName;
    const stoId = cellText(row.getCell(columns.stoId)).trim();
    if (!currentProductUid || !stoId) continue;

    const key = `${currentProductUid}|${stoId}`;
    const compare = makeshopCompareByKey.get(key);
    const apply = makeshopApplyByKey.get(key);
    const stockOverride = sellpiaStockOverrideFor(apply, compare);
    const currentStock = compare?.makeshop_sto_stock || cellText(row.getCell(columns.stoStock)).trim();
    const proposedStock = stockOverride?.proposedStock || apply?.proposed_sto_stock || compare?.sellpia_available_stock || "";
    const numericDelta = Number(proposedStock) - Number(currentStock);
    const rawStatus = stockOverride && Number.isFinite(numericDelta)
      ? (numericDelta === 0 ? "STOCK_MATCH" : "STOCK_DIFF")
      : compare?.stock_compare_status || (apply ? "STOCK_DIFF" : "STAGE_NOT_FOUND");
    const status = makeshopCompareStatusLabel(rawStatus);
    seenCompareKeys.add(key);
    compareSheet.addRow({
      status,
      rowNumber,
      productUid: currentProductUid,
      stoId,
      productName: compare?.makeshop_product_name || currentProductName || "",
      optionValue: compare?.makeshop_option_value || (columns.optionValue ? cellText(row.getCell(columns.optionValue)).trim() : ""),
      sellpiaStock: stockOverride?.proposedStock || compare?.sellpia_available_stock || "",
      currentStock,
      proposedStock,
      stockDelta: Number.isFinite(numericDelta) ? numericDelta : compare?.stock_diff || "",
      sellpiaProductCode: stockOverride?.sellpiaProductCode || compare?.sellpia_product_code || apply?.sellpia_product_code || "",
      sellpiaSkuCode: stockOverride?.sellpiaSkuCode || compare?.sellpia_sku_code || apply?.sellpia_sku_code || "",
      sellpiaProductName: stockOverride?.sellpiaProductName || compare?.sellpia_product_name || apply?.sellpia_product_name || "",
      sellpiaOptionName: stockOverride?.sellpiaOptionName || compare?.sellpia_option_name || apply?.sellpia_option_name || "",
      note: compare?.recommended_action || compare?.note || (apply ? "재고수정 apply 대상" : "전체 대조 map에서 key를 찾지 못했습니다."),
    });
  }

  makeshopCompareRows.forEach((row) => {
    const key = `${String(row.makeshop_product_uid || "").trim()}|${String(row.makeshop_sto_id || "").trim()}`;
    if (!key || key === "|" || seenCompareKeys.has(key)) return;
    const stockOverride = sellpiaStockOverrideFor(null, row);
    const missingProposedStock = stockOverride?.proposedStock || row.sellpia_available_stock || "";
    const missingCurrentStock = row.makeshop_sto_stock || "";
    const missingDelta = Number(missingProposedStock) - Number(missingCurrentStock);
    compareSheet.addRow({
      status: "미매칭",
      rowNumber: "",
      productUid: row.makeshop_product_uid || "",
      stoId: row.makeshop_sto_id || "",
      productName: row.makeshop_product_name || "",
      optionValue: row.makeshop_option_value || "",
      sellpiaStock: missingProposedStock,
      currentStock: missingCurrentStock,
      proposedStock: missingProposedStock,
      stockDelta: Number.isFinite(missingDelta) ? missingDelta : row.stock_delta || "",
      sellpiaProductCode: stockOverride?.sellpiaProductCode || row.sellpia_product_code || "",
      sellpiaSkuCode: stockOverride?.sellpiaSkuCode || row.sellpia_sku_code || "",
      sellpiaProductName: stockOverride?.sellpiaProductName || row.sellpia_product_name || "",
      sellpiaOptionName: stockOverride?.sellpiaOptionName || row.sellpia_option_name || "",
      note: "업로드한 원본양식에서 product_uid+sto_id를 찾지 못했습니다.",
    });
  });

  compareSheet.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF111827" } };
    cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
  });
  compareSheet.eachRow((row, rowNumber) => {
    if (rowNumber === 1) return;
    const status = cellText(row.getCell(1));
    const fillColor = makeshopCompareFill(status);
    row.eachCell({ includeEmpty: true }, (cell) => {
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: fillColor } };
      cell.alignment = { vertical: "top", wrapText: true };
      cell.border = { bottom: { style: "hair", color: { argb: "FFE2E8F0" } } };
    });
  });
  compareSheet.views = [{ state: "frozen", ySplit: 1 }];
  compareSheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: compareSheet.columnCount },
  };
}

function addMakeshopApplySummarySheets(workbook, records, warnings) {
  const bucketCounts = makeshopPreviewBucketCounts(makeshopPreviewRows);
  const summarySheet = workbook.addWorksheet(uniqueWorksheetName(workbook, "적용요약"));
  summarySheet.columns = [
    { header: "항목", key: "name", width: 28 },
    { header: "내용", key: "value", width: 88 },
  ];
  summarySheet.addRows([
    { name: "파일 목적", value: "MakeShop 빠른사용 재고수정 XLSX입니다. 일부 상품을 먼저 확인하며 쓰기 위한 파일이고, 판매처 업로드 전 사람 검토가 필요합니다." },
    { name: "원본 파일", value: makeshopOriginalFileName || "-" },
    { name: "생성 시각", value: new Date().toLocaleString("ko-KR") },
    { name: "preview matched", value: makeshopPreviewRows.length },
    { name: "preview changed", value: changedMakeshopPreviewRows().length },
    { name: "apply map missing", value: makeshopMissingApplyRows.length },
    { name: "ZERO_OUT", value: bucketCounts.ZERO_OUT || 0 },
    { name: "LARGE_DECREASE", value: bucketCounts.LARGE_DECREASE || 0 },
    { name: "RECHECK_REQUIRED", value: bucketCounts.RECHECK_REQUIRED || 0 },
    { name: "경고", value: warnings.length ? warnings.join("\n") : "없음" },
  ]);
  summarySheet.getRow(1).font = { bold: true };
  summarySheet.getColumn(2).alignment = { wrapText: true, vertical: "top" };

  const logSheet = workbook.addWorksheet(uniqueWorksheetName(workbook, "변경셀목록"));
  logSheet.columns = [
    { header: "scope", key: "scopeLabel", width: 14 },
    { header: "row", key: "rowNumber", width: 10 },
    { header: "column", key: "columnNumber", width: 10 },
    { header: "header", key: "columnHeader", width: 24 },
    { header: "product_uid", key: "productUid", width: 18 },
    { header: "sto_id", key: "stoId", width: 14 },
    { header: "before", key: "beforeValue", width: 14 },
    { header: "after", key: "afterValue", width: 14 },
    { header: "risk", key: "riskBucket", width: 18 },
    { header: "source", key: "source", width: 32 },
  ];
  if (records.length) records.forEach((record) => logSheet.addRow(record));
  else logSheet.addRow({ scopeLabel: "-", columnHeader: "변경 없음", source: warnings.join(" / ") || "no changes" });
  logSheet.getRow(1).font = { bold: true };
  logSheet.views = [{ state: "frozen", ySplit: 1 }];
  logSheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: logSheet.columnCount },
  };
}

function makeshopPreviewExportRows() {
  return makeshopPreviewRows.map((row) => ({
    "상태": row.statusLabel,
    "원본 행": row.rowNumber,
    "상품고유번호": row.productUid,
    "옵션번호": row.stoId,
    "상품명": row.productName,
    "옵션값": row.optionValue,
    "현재 재고": row.currentStock,
    "변경 재고": row.proposedStock,
    "차이": row.stockDelta,
    "위험 분류": row.riskLabel,
    "주의 메모": row.riskNote,
    "Sellpia 상품코드": row.sellpiaProductCode,
    "Sellpia 옵션코드": row.sellpiaSkuCode,
    "Sellpia 상품명": row.sellpiaProductName,
    "Sellpia 옵션명": row.sellpiaOptionName,
  }));
}

function downloadMakeshopPreviewCsv() {
  if (!makeshopPreviewRows.length) {
    alert("먼저 MakeShop 원본양식 preview를 생성해 주세요.");
    return;
  }
  const rows = makeshopPreviewExportRows();
  const headers = Object.keys(rows[0]);
  const csv = `\ufeff${[
    headers.map(csvEscape).join(","),
    ...rows.map((row) => headers.map((header) => csvEscape(row[header])).join(",")),
  ].join("\r\n")}`;
  downloadBlob(
    new Blob([csv], { type: "text/csv;charset=utf-8" }),
    `makeshop_stock_change_preview_${formatTimestamp()}.csv`
  );
}

async function downloadMakeshopStockApplyXlsx() {
  if (!makeshopOriginalFileBuffer || !makeshopPreviewRows.length) {
    alert("먼저 MakeShop 원본양식 preview를 생성해 주세요.");
    return;
  }
  if (!window.ExcelJS) {
    alert("XLSX 생성 라이브러리를 불러오지 못했습니다.");
    return;
  }

  const workbook = new window.ExcelJS.Workbook();
  await workbook.xlsx.load(makeshopOriginalFileBuffer.slice(0));
  const worksheet = workbook.worksheets[0];
  const columns = makeshopDetectedColumns || findMakeshopColumns(worksheet);
  const records = [];
  const warnings = [];
  if (!columns.productUid || !columns.stoId || !columns.stoStock) {
    alert("MakeShop 필수 컬럼을 다시 찾지 못했습니다.");
    return;
  }
  if (!makeshopCompareByKey.size) {
    await loadMakeshopCompareMap();
  }

  addMakeshopStockCompareSheet(workbook, worksheet, columns);
  applyMakeshopStockChanges(worksheet, columns, records);
  addMakeshopStockCorrectionSheet(workbook, worksheet, columns);
  addMakeshopApplySummarySheets(workbook, records, warnings);
  normalizeOriginalSheetApplyFills(worksheet, records);

  const buffer = await workbook.xlsx.writeBuffer();
  const baseName = makeshopOriginalFileName.replace(/\.[^.]+$/, "");
  downloadBlob(
    new Blob([buffer], {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    }),
    `${baseName || "makeshop"}_stock_apply_${formatTimestamp()}.xlsx`
  );
}

function setAblyPreviewStatus(message) {
  if (ablyOriginalStatus) ablyOriginalStatus.textContent = message;
}

function findAblyColumns(worksheet) {
  const result = {
    headerRow: null,
    productCode: null,
    sellerProductCode: null,
    productName: null,
    optionCode: null,
    option1: null,
    option2: null,
    fullOptionName: null,
    stock: null,
    safetyStock: null,
    soldoutStatus: null,
    displayStatus: null,
  };
  const maxRows = Math.min(8, worksheet.rowCount || 8);
  const maxCols = Math.min(80, worksheet.columnCount || 80);
  for (let rowNumber = 1; rowNumber <= maxRows; rowNumber += 1) {
    const row = worksheet.getRow(rowNumber);
    const candidates = {};
    for (let colNumber = 1; colNumber <= maxCols; colNumber += 1) {
      const header = normalizedHeader(cellText(row.getCell(colNumber)));
      if (!header) continue;
      if (header === "상품번호") candidates.productCode = colNumber;
      if (header === "판매자상품코드") candidates.sellerProductCode = colNumber;
      if (header === "상품명") candidates.productName = colNumber;
      if (header === "옵션번호") candidates.optionCode = colNumber;
      if (header === "옵션1") candidates.option1 = colNumber;
      if (header === "옵션2") candidates.option2 = colNumber;
      if (header === "전체옵션명") candidates.fullOptionName = colNumber;
      if (header === "재고수량") candidates.stock = colNumber;
      if (header === "안전재고") candidates.safetyStock = colNumber;
      if (header === "품절상태") candidates.soldoutStatus = colNumber;
      if (header === "진열상태") candidates.displayStatus = colNumber;
    }
    if (candidates.productCode && candidates.optionCode && candidates.stock) {
      return { ...result, ...candidates, headerRow: rowNumber };
    }
  }
  return { ...result };
}

function ablyColumnHeader(worksheet, columns, columnNumber) {
  return cellText(worksheet.getRow(columns.headerRow).getCell(columnNumber)) || columnName(columnNumber);
}

function sellpiaStockOverrideForAbly(apply) {
  const sku = String(apply?.old_sellpia_sku_code || "").trim();
  if (!sku || sku.includes("\n")) return null;
  const latest = sellpiaLatestStockForSku(sku);
  if (!latest) return null;
  return {
    latest,
    proposedStock: sellpiaStockCandidateValue(latest),
    sellpiaProductCode: latest.sellpia_product_code || apply.old_sellpia_product_code || apply.candidate_sellpia_product_code || sellpiaProductCodeFromSku(sku),
    sellpiaSkuCode: sku,
    sellpiaProductName: latest.sellpia_product_name || apply.candidate_sellpia_product_name || "",
    sellpiaOptionName: latest.sellpia_option_name || apply.candidate_sellpia_option_name || "",
    sourceLabel: "supabase_latest_sellpia_stock",
  };
}

function ablyStockBucket(currentStock, proposedStock) {
  const current = Number(currentStock);
  const proposed = Number(proposedStock);
  if (!Number.isFinite(current) || !Number.isFinite(proposed)) {
    return { bucket: "RECHECK_REQUIRED", label: "재확인 필요", note: "재고값을 숫자로 해석할 수 없습니다." };
  }
  const delta = proposed - current;
  const absDelta = Math.abs(delta);
  const relativeDecrease = current > 0 ? absDelta / current : 0;
  if (delta === 0) return { bucket: "NO_CHANGE", label: "재고일치", note: "재고 변경 없음" };
  if (proposed === 0 && current > 0) return { bucket: "ZERO_OUT", label: "0으로 변경", note: "현재 재고가 0으로 바뀌므로 확인이 필요합니다." };
  if (delta > 0) return { bucket: "INCREASE", label: "증가", note: "Sellpia 기준 재고가 Ably보다 큽니다." };
  if (absDelta >= 20 || relativeDecrease >= 0.5) return { bucket: "LARGE_DECREASE", label: "큰 감소", note: "감소폭이 커서 샘플 확인이 필요합니다." };
  return { bucket: "SMALL_DECREASE", label: "소폭 감소", note: "소폭 감소 후보입니다." };
}

function ablyPreviewBucketCounts(rows) {
  return rows.reduce((acc, row) => {
    acc[row.riskBucket] = (acc[row.riskBucket] || 0) + 1;
    return acc;
  }, {});
}

function changedAblyPreviewRows() {
  return ablyPreviewRows.filter((preview) => preview.status === "CHANGE");
}

function renderAblyPreview(stats) {
  if (!ablyPreviewPanel || !ablyPreviewTableBody) return;
  ablyPreviewPanel.hidden = false;
  renderChannelUploadGate({
    panel: ablyUploadGatePanel,
    metricsEl: ablyUploadGateMetrics,
    statusEl: ablyUploadGateStatus,
    channelName: "Ably",
    stats,
    extraLine: `XX 제외 ${Number(stats.excludedRows || 0).toLocaleString()}건은 재고 반영 대상에서 제외됩니다.`,
  });
  document.getElementById("ablyPreviewTotalRows").textContent = stats.totalRows.toLocaleString();
  document.getElementById("ablyPreviewMatchedRows").textContent = stats.matchedRows.toLocaleString();
  document.getElementById("ablyPreviewChangedRows").textContent = stats.changedRows.toLocaleString();
  document.getElementById("ablyPreviewMissingRows").textContent = stats.missingRows.toLocaleString();
  document.getElementById("ablyPreviewExcludedRows").textContent = stats.excludedRows.toLocaleString();
  document.getElementById("ablyPreviewIncreaseRows").textContent = (stats.bucketCounts.INCREASE || 0).toLocaleString();
  document.getElementById("ablyPreviewDecreaseRows").textContent = ((stats.bucketCounts.SMALL_DECREASE || 0) + (stats.bucketCounts.LARGE_DECREASE || 0)).toLocaleString();
  document.getElementById("ablyPreviewZeroOutRows").textContent = (stats.bucketCounts.ZERO_OUT || 0).toLocaleString();
  document.getElementById("ablyPreviewRecheckRows").textContent = (stats.bucketCounts.RECHECK_REQUIRED || 0).toLocaleString();

  ablyPreviewTableBody.innerHTML = "";
  ablyPreviewRows.slice(0, 300).forEach((row) => {
    const tr = document.createElement("tr");
    tr.className = row.riskBucket === "ZERO_OUT" || row.riskBucket === "LARGE_DECREASE"
      ? "is-risk"
      : row.status === "CHANGE" ? "is-changed" : row.status === "RECHECK" ? "is-missing" : "";
    tr.innerHTML = `
      <td>${escapeHtml(row.rowNumber)}</td>
      <td>${escapeHtml(row.productCode)}</td>
      <td>${escapeHtml(row.optionCode)}</td>
      <td>${escapeHtml(row.optionName)}</td>
      <td>${escapeHtml(row.currentStock)}</td>
      <td>${escapeHtml(row.proposedStock)}</td>
      <td>${escapeHtml(row.stockDelta)}</td>
      <td>${escapeHtml(row.sellpiaSkuCode)}</td>
      <td>${escapeHtml(row.statusLabel)}</td>
    `;
    ablyPreviewTableBody.appendChild(tr);
  });
}

async function buildAblyPreviewFromBuffer(fileName, buffer, { statusPrefix = "Ably 원본양식" } = {}) {
  if (!window.ExcelJS) {
    alert("XLSX 파서가 아직 로드되지 않았습니다. 화면을 새로고침한 뒤 다시 시도해 주세요.");
    return false;
  }
  if (!ablyApplyByKey.size) {
    await loadAblyApplyMap();
  }
  await loadLatestSellpiaStockSnapshot({ silent: true });
  setAblyPreviewStatus(`${statusPrefix} XLSX 분석 중...`);

  const workbook = new window.ExcelJS.Workbook();
  await workbook.xlsx.load(buffer.slice(0));
  const worksheet = workbook.worksheets[0];
  const columns = findAblyColumns(worksheet);
  if (!columns.productCode || !columns.optionCode || !columns.stock) {
    setAblyPreviewStatus("필수 컬럼을 찾지 못했습니다. 상품 번호, 옵션 번호, 재고수량 컬럼이 있는 Ably 원본양식이 필요합니다.");
    return false;
  }

  ablyOriginalFileName = fileName;
  ablyOriginalFileBuffer = buffer.slice(0);
  ablyDetectedColumns = columns;
  ablyPreviewRows = [];
  ablyMissingApplyRows = [];
  ablyExcludedRows = [];

  const seenApplyKeys = new Set();
  let totalRows = 0;
  let matchedRows = 0;
  let changedRows = 0;
  let excludedRows = 0;

  for (let rowNumber = columns.headerRow + 1; rowNumber <= worksheet.rowCount; rowNumber += 1) {
    const row = worksheet.getRow(rowNumber);
    const productCode = cellText(row.getCell(columns.productCode)).trim();
    const optionCode = cellText(row.getCell(columns.optionCode)).trim();
    if (!productCode || !optionCode) continue;
    totalRows += 1;

    const sellerCode = columns.sellerProductCode ? cellText(row.getCell(columns.sellerProductCode)).trim() : "";
    const productName = columns.productName ? cellText(row.getCell(columns.productName)).trim() : "";
    const option1 = columns.option1 ? cellText(row.getCell(columns.option1)).trim() : "";
    const option2 = columns.option2 ? cellText(row.getCell(columns.option2)).trim() : "";
    const optionName = columns.fullOptionName
      ? cellText(row.getCell(columns.fullOptionName)).trim()
      : [option1, option2].filter(Boolean).join(", ");
    const currentStock = cellText(row.getCell(columns.stock)).trim();
    const key = `${productCode}|${optionCode}`;
    const apply = ablyApplyByKey.get(key);
    const isExcluded = is_xx_like(sellerCode, productName, option1, option2);
    if (isExcluded) {
      excludedRows += 1;
      ablyExcludedRows.push({ rowNumber, productCode, optionCode, sellerCode, productName, optionName });
      continue;
    }
    if (!apply) continue;
    seenApplyKeys.add(key);
    matchedRows += 1;

    const stockOverride = sellpiaStockOverrideForAbly(apply);
    const proposedStock = String(stockOverride?.proposedStock ?? "").trim();
    const bucket = stockOverride
      ? ablyStockBucket(currentStock, proposedStock)
      : { bucket: "RECHECK_REQUIRED", label: "재확인 필요", note: "Sellpia 최신 재고 또는 단일 SKU를 찾지 못했습니다." };
    const currentNumber = Number(currentStock);
    const proposedNumber = Number(proposedStock);
    const canCompare = stockOverride && Number.isFinite(currentNumber) && Number.isFinite(proposedNumber);
    const changed = canCompare ? currentNumber !== proposedNumber : false;
    if (changed) changedRows += 1;
    const computedDelta = canCompare ? proposedNumber - currentNumber : "";

    ablyPreviewRows.push({
      rowNumber,
      productCode,
      optionCode,
      sellerCode,
      productName: productName || apply.ably_product_name || "",
      optionName: optionName || apply.ably_full_option_name || "",
      currentStock,
      proposedStock,
      stockDelta: computedDelta,
      sellpiaProductCode: stockOverride?.sellpiaProductCode || apply.old_sellpia_product_code || "",
      sellpiaSkuCode: stockOverride?.sellpiaSkuCode || apply.old_sellpia_sku_code || "",
      sellpiaProductName: stockOverride?.sellpiaProductName || apply.candidate_sellpia_product_name || "",
      sellpiaOptionName: stockOverride?.sellpiaOptionName || apply.candidate_sellpia_option_name || "",
      riskBucket: bucket.bucket,
      riskLabel: bucket.label,
      riskNote: bucket.note,
      status: stockOverride ? (changed ? "CHANGE" : "NO_CHANGE") : "RECHECK",
      statusLabel: stockOverride ? (changed ? "불일치" : "재고일치") : "재확인 필요",
      stockSource: stockOverride?.sourceLabel || "sellpia_latest_stock_missing",
      apply,
    });
  }

  ablyMissingApplyRows = ablyApplyRows.filter((row) => {
    const key = `${String(row.ably_product_code || "").trim()}|${String(row.ably_option_code || "").trim()}`;
    return key !== "|" && !seenApplyKeys.has(key);
  });
  const stats = {
    totalRows,
    matchedRows,
    changedRows,
    missingRows: Math.max(0, totalRows - matchedRows - excludedRows),
    excludedRows,
    bucketCounts: ablyPreviewBucketCounts(ablyPreviewRows),
  };
  renderAblyPreview(stats);
  ablyPreviewExportButton.disabled = !ablyPreviewRows.length;
  ablyPreviewCsvButton.disabled = !ablyPreviewRows.length;
  setAblyPreviewStatus(
    `분석 완료: 원본 옵션행 ${totalRows.toLocaleString()}개, 기존 매칭 ${matchedRows.toLocaleString()}개, 재고 변경 ${changedRows.toLocaleString()}개, 제외 ${excludedRows.toLocaleString()}개, 미매칭 ${stats.missingRows.toLocaleString()}개`
  );
  return true;
}

async function buildAblyOriginalPreview() {
  const file = ablyOriginalInput?.files?.[0];
  if (!file) {
    alert("Ably 원본양식 XLSX를 먼저 선택해 주세요.");
    return;
  }
  await buildAblyPreviewFromBuffer(file.name, await file.arrayBuffer());
}

function is_xx_like(...values) {
  const text = values.filter(Boolean).join(" ");
  return /(^|[^A-Z0-9])XX([^A-Z0-9]|$)|XX/i.test(text);
}

function ablyPreviewExportRows() {
  return ablyPreviewRows.map((row) => ({
    "상태": row.statusLabel,
    "원본 행": row.rowNumber,
    "Ably 상품번호": row.productCode,
    "Ably 옵션번호": row.optionCode,
    "판매자 상품코드": row.sellerCode,
    "Ably 상품명": row.productName,
    "Ably 옵션명": row.optionName,
    "현재 재고": row.currentStock,
    "변경 재고": row.proposedStock,
    "차이": row.stockDelta,
    "위험 분류": row.riskLabel,
    "주의 메모": row.riskNote,
    "Sellpia 상품코드": row.sellpiaProductCode,
    "Sellpia 옵션코드": row.sellpiaSkuCode,
    "Sellpia 상품명": row.sellpiaProductName,
    "Sellpia 옵션명": row.sellpiaOptionName,
  }));
}

function downloadAblyPreviewCsv() {
  if (!ablyPreviewRows.length) {
    alert("먼저 Ably 원본양식 preview를 생성해 주세요.");
    return;
  }
  const rows = ablyPreviewExportRows();
  const headers = Object.keys(rows[0]);
  const csv = `\ufeff${[
    headers.map(csvEscape).join(","),
    ...rows.map((row) => headers.map((header) => csvEscape(row[header])).join(",")),
  ].join("\r\n")}`;
  downloadBlob(
    new Blob([csv], { type: "text/csv;charset=utf-8" }),
    `ably_stock_change_preview_${formatTimestamp()}.csv`
  );
}

function applyAblyStockChanges(worksheet, columns, records) {
  changedAblyPreviewRows().forEach((preview) => {
    const row = worksheet.getRow(preview.rowNumber);
    const stockCell = row.getCell(columns.stock);
    const beforeValue = cellText(stockCell).trim();
    stockCell.value = stockCellValue(preview.proposedStock);
    stockCell.alignment = { ...(stockCell.alignment || {}), vertical: "top" };
    applyFill(stockCell, "FFFFFF00");
    records.push({
      scopeLabel: "재고수정",
      rowNumber: preview.rowNumber,
      columnNumber: columns.stock,
      columnHeader: ablyColumnHeader(worksheet, columns, columns.stock),
      productCode: preview.productCode,
      optionCode: preview.optionCode,
      beforeValue,
      afterValue: preview.proposedStock,
      riskBucket: preview.riskBucket,
      source: preview.stockSource || "ably_existing_matched_apply_map",
    });
  });
}

function addAblyStockCorrectionSheet(workbook, sourceWorksheet, columns) {
  const changedRows = changedAblyPreviewRows();
  if (!changedRows.length) return;
  const correctionSheet = workbook.addWorksheet(uniqueWorksheetName(workbook, "에이블리 재고수정"));
  const maxColumn = sourceWorksheet.columnCount || 29;
  const headerEndRow = columns.headerRow || 1;
  for (let columnNumber = 1; columnNumber <= maxColumn; columnNumber += 1) {
    const sourceColumn = sourceWorksheet.getColumn(columnNumber);
    const targetColumn = correctionSheet.getColumn(columnNumber);
    targetColumn.width = sourceColumn.width;
    targetColumn.hidden = sourceColumn.hidden;
    targetColumn.style = cloneExcelStyle(sourceColumn.style);
  }
  for (let rowNumber = 1; rowNumber <= headerEndRow; rowNumber += 1) {
    copySmartstoreWorksheetRow(sourceWorksheet.getRow(rowNumber), correctionSheet.getRow(rowNumber), maxColumn);
  }
  let targetRowNumber = headerEndRow + 1;
  changedRows.forEach((preview) => {
    const targetRow = correctionSheet.getRow(targetRowNumber);
    copySmartstoreWorksheetRow(sourceWorksheet.getRow(preview.rowNumber), targetRow, maxColumn);
    const stockCell = targetRow.getCell(columns.stock);
    stockCell.value = stockCellValue(preview.proposedStock);
    applyFill(stockCell, "FFFFFF00");
    targetRow.commit?.();
    targetRowNumber += 1;
  });
  correctionSheet.views = [{ state: "frozen", ySplit: headerEndRow }];
  correctionSheet.autoFilter = {
    from: { row: columns.headerRow, column: 1 },
    to: { row: columns.headerRow, column: maxColumn },
  };
}

function ablyCompareStatusLabel(row, compareRow) {
  if (compareRow?.excluded) return "제외";
  if (!row) return "미매칭";
  if (row.status === "RECHECK") return "재확인 필요";
  return row.statusLabel;
}

function ablyCompareFill(status) {
  if (status === "불일치") return "FFFFE4E6";
  if (status === "재고일치") return "FFE0F2FE";
  if (status === "미매칭") return "FFFFEDD5";
  if (status === "제외") return "FFE9D5FF";
  if (status === "재확인 필요") return "FFFEF3C7";
  return "FFFFFFFF";
}

function addAblyStockCompareSheet(workbook, sourceWorksheet, columns) {
  const compareSheet = workbook.addWorksheet(uniqueWorksheetName(workbook, "대조표"));
  compareSheet.columns = [
    { header: "상태", key: "status", width: 14 },
    { header: "원본 행", key: "rowNumber", width: 10 },
    { header: "Ably 상품번호", key: "productCode", width: 16 },
    { header: "Ably 옵션번호", key: "optionCode", width: 16 },
    { header: "판매자 상품코드", key: "sellerCode", width: 16 },
    { header: "Ably 상품명", key: "productName", width: 34 },
    { header: "Ably 옵션명", key: "optionName", width: 30 },
    { header: "셀피아 재고", key: "sellpiaStock", width: 12 },
    { header: "Ably 재고수", key: "currentStock", width: 12 },
    { header: "변경 재고", key: "proposedStock", width: 12 },
    { header: "차이", key: "stockDelta", width: 10 },
    { header: "셀피아 상품코드", key: "sellpiaProductCode", width: 16 },
    { header: "셀피아 옵션코드", key: "sellpiaSkuCode", width: 16 },
    { header: "셀피아 상품명", key: "sellpiaProductName", width: 30 },
    { header: "셀피아 옵션명", key: "sellpiaOptionName", width: 24 },
    { header: "검토 메모", key: "note", width: 42 },
  ];
  const previewByKey = new Map(ablyPreviewRows.map((row) => [`${row.productCode}|${row.optionCode}`, row]));
  const excludedByKey = new Map(ablyExcludedRows.map((row) => [`${row.productCode}|${row.optionCode}`, { ...row, excluded: true }]));
  const seenKeys = new Set();
  for (let rowNumber = columns.headerRow + 1; rowNumber <= sourceWorksheet.rowCount; rowNumber += 1) {
    const row = sourceWorksheet.getRow(rowNumber);
    const productCode = cellText(row.getCell(columns.productCode)).trim();
    const optionCode = cellText(row.getCell(columns.optionCode)).trim();
    if (!productCode || !optionCode) continue;
    const key = `${productCode}|${optionCode}`;
    const preview = previewByKey.get(key);
    const excluded = excludedByKey.get(key);
    seenKeys.add(key);
    const sellerCode = columns.sellerProductCode ? cellText(row.getCell(columns.sellerProductCode)).trim() : "";
    const productName = columns.productName ? cellText(row.getCell(columns.productName)).trim() : "";
    const optionName = columns.fullOptionName ? cellText(row.getCell(columns.fullOptionName)).trim() : "";
    const status = ablyCompareStatusLabel(preview, excluded);
    compareSheet.addRow({
      status,
      rowNumber,
      productCode,
      optionCode,
      sellerCode,
      productName: preview?.productName || productName,
      optionName: preview?.optionName || optionName,
      sellpiaStock: preview?.proposedStock || "",
      currentStock: preview?.currentStock || cellText(row.getCell(columns.stock)).trim(),
      proposedStock: preview?.proposedStock || "",
      stockDelta: preview?.stockDelta || "",
      sellpiaProductCode: preview?.sellpiaProductCode || "",
      sellpiaSkuCode: preview?.sellpiaSkuCode || "",
      sellpiaProductName: preview?.sellpiaProductName || "",
      sellpiaOptionName: preview?.sellpiaOptionName || "",
      note: excluded ? "XX 제외 대상입니다." : preview?.riskNote || "기존 매칭 apply map에서 key를 찾지 못했습니다.",
    });
  }
  ablyApplyRows.forEach((row) => {
    const key = `${String(row.ably_product_code || "").trim()}|${String(row.ably_option_code || "").trim()}`;
    if (!key || key === "|" || seenKeys.has(key)) return;
    compareSheet.addRow({
      status: "미매칭",
      rowNumber: "",
      productCode: row.ably_product_code || "",
      optionCode: row.ably_option_code || "",
      sellerCode: row.ably_seller_product_code || "",
      productName: row.ably_product_name || "",
      optionName: row.ably_full_option_name || "",
      sellpiaProductCode: row.old_sellpia_product_code || "",
      sellpiaSkuCode: row.old_sellpia_sku_code || "",
      note: "업로드한 원본양식에서 상품번호+옵션번호를 찾지 못했습니다.",
    });
  });
  compareSheet.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF111827" } };
    cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
  });
  compareSheet.eachRow((row, rowNumber) => {
    if (rowNumber === 1) return;
    const status = cellText(row.getCell(1));
    const fillColor = ablyCompareFill(status);
    row.eachCell({ includeEmpty: true }, (cell) => {
      cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: fillColor } };
      cell.alignment = { vertical: "top", wrapText: true };
      cell.border = { bottom: { style: "hair", color: { argb: "FFE2E8F0" } } };
    });
  });
  compareSheet.views = [{ state: "frozen", ySplit: 1 }];
  compareSheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: compareSheet.columnCount },
  };
}

function addAblyApplySummarySheets(workbook, records, warnings) {
  const bucketCounts = ablyPreviewBucketCounts(ablyPreviewRows);
  const summarySheet = workbook.addWorksheet(uniqueWorksheetName(workbook, "적용요약"));
  summarySheet.columns = [
    { header: "항목", key: "name", width: 28 },
    { header: "내용", key: "value", width: 88 },
  ];
  summarySheet.addRows([
    { name: "파일 목적", value: "Ably 기존 매칭 기반 재고수정 XLSX입니다. 상품/옵션 코드는 수정하지 않고 재고수량만 변경합니다." },
    { name: "원본 파일", value: ablyOriginalFileName || "-" },
    { name: "생성 시각", value: new Date().toLocaleString("ko-KR") },
    { name: "preview matched", value: ablyPreviewRows.length },
    { name: "preview changed", value: changedAblyPreviewRows().length },
    { name: "apply map missing", value: ablyMissingApplyRows.length },
    { name: "excluded", value: ablyExcludedRows.length },
    { name: "ZERO_OUT", value: bucketCounts.ZERO_OUT || 0 },
    { name: "LARGE_DECREASE", value: bucketCounts.LARGE_DECREASE || 0 },
    { name: "RECHECK_REQUIRED", value: bucketCounts.RECHECK_REQUIRED || 0 },
    { name: "경고", value: warnings.length ? warnings.join("\n") : "없음" },
  ]);
  summarySheet.getRow(1).font = { bold: true };
  summarySheet.getColumn(2).alignment = { wrapText: true, vertical: "top" };

  const logSheet = workbook.addWorksheet(uniqueWorksheetName(workbook, "변경셀목록"));
  logSheet.columns = [
    { header: "scope", key: "scopeLabel", width: 14 },
    { header: "row", key: "rowNumber", width: 10 },
    { header: "column", key: "columnNumber", width: 10 },
    { header: "header", key: "columnHeader", width: 24 },
    { header: "ably_product_code", key: "productCode", width: 18 },
    { header: "ably_option_code", key: "optionCode", width: 18 },
    { header: "before", key: "beforeValue", width: 14 },
    { header: "after", key: "afterValue", width: 14 },
    { header: "risk", key: "riskBucket", width: 18 },
    { header: "source", key: "source", width: 32 },
  ];
  if (records.length) records.forEach((record) => logSheet.addRow(record));
  else logSheet.addRow({ scopeLabel: "-", columnHeader: "변경 없음", source: warnings.join(" / ") || "no changes" });
  logSheet.getRow(1).font = { bold: true };
  logSheet.views = [{ state: "frozen", ySplit: 1 }];
  logSheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: logSheet.columnCount },
  };
}

async function downloadAblyStockApplyXlsx() {
  if (!ablyOriginalFileBuffer || !ablyPreviewRows.length) {
    alert("먼저 Ably 원본양식 preview를 생성해 주세요.");
    return;
  }
  if (!window.ExcelJS) {
    alert("XLSX 생성 라이브러리를 불러오지 못했습니다.");
    return;
  }
  const workbook = new window.ExcelJS.Workbook();
  await workbook.xlsx.load(ablyOriginalFileBuffer.slice(0));
  const worksheet = workbook.worksheets[0];
  const columns = ablyDetectedColumns || findAblyColumns(worksheet);
  if (!columns.productCode || !columns.optionCode || !columns.stock) {
    alert("Ably 필수 컬럼을 다시 찾지 못했습니다.");
    return;
  }
  const records = [];
  const warnings = [];
  if (!changedAblyPreviewRows().length) warnings.push("변경 대상 재고 셀이 없습니다.");
  addAblyStockCompareSheet(workbook, worksheet, columns);
  applyAblyStockChanges(worksheet, columns, records);
  addAblyStockCorrectionSheet(workbook, worksheet, columns);
  addAblyApplySummarySheets(workbook, records, warnings);
  normalizeOriginalSheetApplyFills(worksheet, records);

  const buffer = await workbook.xlsx.writeBuffer();
  const baseName = ablyOriginalFileName.replace(/\.[^.]+$/, "");
  downloadBlob(
    new Blob([buffer], {
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    }),
    `${baseName || "ably"}_stock_apply_${formatTimestamp()}.xlsx`
  );
}

function linkingElements() {
  return {
    view: document.getElementById("linkingView"),
    list: document.getElementById("linkingList"),
    selected: document.getElementById("linkingSelectedSummary"),
    connected: document.getElementById("linkingConnectedChannels"),
    candidateResults: document.getElementById("linkingCandidateResults"),
    unlinkButton: document.getElementById("linkingUnlinkButton"),
  };
}

function rowHasSellpiaLink(row) {
  return Boolean(row?.best_sellpia_product_code || row?.best_sellpia_sku_code);
}

function rowIsManuallyUnlinked(row) {
  return latestLinkDecision(row)?.decision === "unlink";
}

function rowNeedsLinking(row) {
  const bucket = workflowBucket(row);
  return (
    rowIsManuallyUnlinked(row) ||
    !rowHasSellpiaLink(row) ||
    bucket === "no_match" ||
    bucket === "code_blank" ||
    bucket === "stock_missing"
  );
}

function rowMatchesLinkingSearch(row, keyword) {
  if (!keyword) return true;
  return [
    row.queue_id,
    row.source_channel,
    channelName(row.source_channel),
    row.channel_product_code,
    row.channel_option_code,
    row.channel_product_name,
    row.channel_option_name,
    row.channel_seller_code,
    row.best_sellpia_product_code,
    row.best_sellpia_sku_code,
    row.best_sellpia_product_name,
    row.best_sellpia_option_name,
    row.match_tier,
    row.match_reason,
    row.recommended_action,
    stockStatusLabel(stockStatusForRow(row)),
    workflowBucketLabel(workflowBucket(row)),
  ].join(" ").toLowerCase().includes(keyword);
}

function linkingBaseRows() {
  const keyword = String(linkingSearchTerm || "").trim().toLowerCase();
  return queueRows.filter((row) => {
    if (!row?.queue_id) return false;
    if (!visibleChannels.has(row.source_channel)) return false;
    if (linkingChannelFilter && row.source_channel !== linkingChannelFilter) return false;
    if (linkingHideAblyExcluded && rowHasAblyExclusion(row)) return false;
    if (!rowMatchesLinkingSearch(row, keyword)) return false;
    if (activeLinkingMode === "link") return rowNeedsLinking(row);
    if (activeLinkingMode === "unlink") return rowHasSellpiaLink(row) && !rowIsManuallyUnlinked(row);
    return true;
  });
}

function updateTextById(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = Number(value || 0).toLocaleString();
}

function renderLinkingSummary() {
  if (queueSummary?.totals && summaryChannels()?.length) {
    updateTextById("linkingTotalCount", sumSummaryField("manual_scope_rows"));
    updateTextById("linkingUnmatchedCount", sumSummaryField("needs_linking_rows"));
    updateTextById("linkingLinkedCount", sumSummaryField("linked_rows"));
    updateTextById("linkingUnlinkedCount", sumSummaryField("manually_unlinked_rows"));
    updateTextById("linkingCodeBlankCount", sumSummaryField("workflow_code_blank_rows"));
    updateTextById("linkingAblyExcludedCount", queueSummary.by_channel?.ably?.workflow_excluded_rows || 0);
    return;
  }

  const visibleRows = queueRows.filter((row) => row?.queue_id && visibleChannels.has(row.source_channel));
  updateTextById("linkingTotalCount", linkingBaseRows().length);
  updateTextById("linkingUnmatchedCount", visibleRows.filter((row) => rowNeedsLinking(row)).length);
  updateTextById("linkingLinkedCount", visibleRows.filter((row) => rowHasSellpiaLink(row) && !rowIsManuallyUnlinked(row)).length);
  updateTextById("linkingUnlinkedCount", visibleRows.filter(rowIsManuallyUnlinked).length);
  updateTextById("linkingCodeBlankCount", visibleRows.filter((row) => workflowBucket(row) === "code_blank").length);
  updateTextById("linkingAblyExcludedCount", visibleRows.filter(rowHasAblyExclusion).length);
}

function linkingStatusBadges(row) {
  const badges = [
    `<span class="linking-status-badge">${escapeHtml(workflowBucketLabel(workflowBucket(row)))}</span>`,
    `<span class="linking-status-badge is-channel">${escapeHtml(channelName(row.source_channel))}</span>`,
  ];
  if (rowIsManuallyUnlinked(row)) badges.push("<span class=\"linking-status-badge is-danger\">연동 해제됨</span>");
  if (rowHasAblyExclusion(row)) badges.push("<span class=\"linking-status-badge is-purple\">에이블리 제외</span>");
  if (stockStatusForRow(row)) badges.push(`<span class="linking-status-badge is-muted">${escapeHtml(stockStatusLabel(stockStatusForRow(row)))}</span>`);
  return badges.join("");
}

function renderLinkingList() {
  const els = linkingElements();
  if (!els.list) return;
  const rows = linkingBaseRows();
  if (!rows.length) {
    linkingSelectedQueueId = "";
    els.list.className = "linking-list empty";
    els.list.textContent = "현재 조건에 맞는 작업 대상이 없습니다.";
    return;
  }

  if (!rows.some((row) => String(row.queue_id) === String(linkingSelectedQueueId))) {
    linkingSelectedQueueId = String(rows[0].queue_id);
  }

  els.list.className = "linking-list";
  els.list.innerHTML = rows.slice(0, 250).map((row) => {
    const selected = String(row.queue_id) === String(linkingSelectedQueueId);
    return `
      <button type="button" class="linking-row ${selected ? "is-selected" : ""}" data-linking-row="${escapeHtml(row.queue_id)}">
        <span class="linking-row-top">
          <strong>${escapeHtml(row.channel_product_code || row.channel_seller_code || row.queue_id)}</strong>
          <em>${escapeHtml(row.best_sellpia_sku_code || row.best_sellpia_product_code || "Sellpia 미지정")}</em>
        </span>
        <span class="linking-row-title">${escapeHtml(row.channel_product_name || "-")}</span>
        <span class="linking-row-option">${escapeHtml(row.channel_option_name || "-")}</span>
        <span class="linking-row-badges">${linkingStatusBadges(row)}</span>
      </button>
    `;
  }).join("");
  if (rows.length > 250) {
    els.list.insertAdjacentHTML("beforeend", `<p class="linking-list-limit">상위 250개만 표시 중입니다. 검색어를 더 좁혀주세요.</p>`);
  }
}

function selectedLinkingRow() {
  return rowByQueueId(linkingSelectedQueueId) || null;
}

function renderLinkingSelected() {
  const els = linkingElements();
  const row = selectedLinkingRow();
  if (!els.selected) return;
  if (!row) {
    els.selected.className = "linking-selected empty";
    els.selected.textContent = "왼쪽 목록에서 행을 선택하세요.";
    if (els.unlinkButton) els.unlinkButton.disabled = true;
    return;
  }
  selectedRow = row;
  selectedQueueIds = new Set([String(row.queue_id)]);
  const image = rowImage(row);
  els.selected.className = "linking-selected";
  els.selected.innerHTML = `
    <div class="linking-selected-title">
      <strong>${escapeHtml(channelName(row.source_channel))}</strong>
      ${linkingStatusBadges(row)}
    </div>
    ${renderImageAsset(image)}
    <dl class="linking-mini-grid">
      <dt>판매처 상품코드</dt><dd>${escapeHtml(row.channel_product_code || "-")}</dd>
      <dt>판매처 옵션코드</dt><dd>${escapeHtml(row.channel_option_code || "-")}</dd>
      <dt>판매처 상품명</dt><dd>${escapeHtml(row.channel_product_name || "-")}</dd>
      <dt>판매처 옵션명</dt><dd>${escapeHtml(row.channel_option_name || "-")}</dd>
      <dt>자사코드</dt><dd>${escapeHtml(ownCodeForRow(row) || "-")}</dd>
      <dt>Sellpia 상품</dt><dd>${escapeHtml(row.best_sellpia_product_name || "-")}</dd>
      <dt>Sellpia 옵션</dt><dd>${escapeHtml(row.best_sellpia_option_name || "-")}</dd>
      <dt>Sellpia 코드</dt><dd>${escapeHtml(row.best_sellpia_sku_code || row.best_sellpia_product_code || "-")}</dd>
      <dt>판정 사유</dt><dd>${escapeHtml(row.match_reason || row.recommended_action || "-")}</dd>
    </dl>
    ${linkDecisionBadge(row)}
  `;
  if (els.unlinkButton) els.unlinkButton.disabled = !rowHasSellpiaLink(row) || rowIsManuallyUnlinked(row);
}

function connectedRowsForSellpia(row) {
  if (!row) return [];
  const productCode = String(row.best_sellpia_product_code || "").trim();
  const skuCode = String(row.best_sellpia_sku_code || "").trim();
  if (!productCode && !skuCode) return [];
  return queueRows
    .filter((item) => {
      if (!item?.queue_id || String(item.queue_id) === String(row.queue_id)) return false;
      const sameSku = skuCode && String(item.best_sellpia_sku_code || "").trim() === skuCode;
      const sameProduct = productCode && String(item.best_sellpia_product_code || "").trim() === productCode;
      return sameSku || sameProduct;
    })
    .slice(0, 80);
}

function renderLinkingConnectedChannels() {
  const els = linkingElements();
  if (!els.connected) return;
  const row = selectedLinkingRow();
  const connected = connectedRowsForSellpia(row);
  if (!row || !connected.length) {
    els.connected.className = "linking-connected-list empty";
    els.connected.textContent = row ? "같은 Sellpia 코드로 연결된 다른 판매처 행이 없습니다." : "셀피아 코드 기준 연결 정보를 표시합니다.";
    return;
  }
  els.connected.className = "linking-connected-list";
  els.connected.innerHTML = connected.map((item) => `
    <article class="linking-connected-row">
      <strong>${escapeHtml(channelName(item.source_channel))}</strong>
      <span>${escapeHtml(item.channel_product_code || "-")} / ${escapeHtml(item.channel_option_code || "-")}</span>
      <p>${escapeHtml(item.channel_product_name || "-")}</p>
      <em>${escapeHtml(item.channel_option_name || "-")}</em>
    </article>
  `).join("");
}

function inferredCandidateTerm(row) {
  if (linkingCandidateTerm.trim()) return linkingCandidateTerm.trim();
  if (!row) return "";
  return [
    ownCodeForRow(row),
    row.channel_option_name,
    row.channel_product_name,
    row.best_sellpia_sku_code,
    row.best_sellpia_product_code,
  ].filter(Boolean)[0] || "";
}

function renderLinkingCandidateResults() {
  const els = linkingElements();
  if (!els.candidateResults) return;
  const row = selectedLinkingRow();
  const term = inferredCandidateTerm(row);
  const keyword = String(term || "").trim().toLowerCase();
  if (!keyword) {
    els.candidateResults.className = "linking-candidate-results empty";
    els.candidateResults.textContent = "검색어를 입력하거나 왼쪽에서 행을 선택하면 후보가 표시됩니다.";
    return;
  }
  const matches = sellpiaCandidatePool()
    .filter((item) => [
      item.sellpia_product_code,
      item.sellpia_sku_code,
      item.sellpia_product_name,
      item.sellpia_option_name,
    ].join(" ").toLowerCase().includes(keyword))
    .slice(0, 30);

  if (!matches.length) {
    els.candidateResults.className = "linking-candidate-results empty";
    els.candidateResults.innerHTML = `
      <strong>현재 로드된 데이터에서 후보를 찾지 못했습니다.</strong>
      <span>검색어: ${escapeHtml(term)}</span>
    `;
    return;
  }

  els.candidateResults.className = "linking-candidate-results";
  els.candidateResults.innerHTML = matches.map((item) => `
    <button
      type="button"
      class="linking-candidate-card"
      data-linking-link-candidate="true"
      data-sellpia-product-code="${escapeHtml(item.sellpia_product_code)}"
      data-sellpia-sku-code="${escapeHtml(item.sellpia_sku_code)}"
      data-sellpia-product-name="${escapeHtml(item.sellpia_product_name)}"
      data-sellpia-option-name="${escapeHtml(item.sellpia_option_name)}"
    >
      <strong>${escapeHtml(item.sellpia_sku_code || item.sellpia_product_code)}</strong>
      <span>${escapeHtml(item.sellpia_product_name || "-")}</span>
      <em>${escapeHtml(item.sellpia_option_name || "-")}</em>
    </button>
  `).join("");
}

function renderLinkingView() {
  const els = linkingElements();
  if (!els.view) return;
  renderLinkingSummary();
  renderLinkingList();
  renderLinkingSelected();
  renderLinkingConnectedChannels();
  renderLinkingCandidateResults();
}

function manualReviewElements() {
  return {
    view: document.getElementById("manualReviewView"),
    list: document.getElementById("manualReviewList"),
    sellerCard: document.getElementById("manualReviewSellerCard"),
    sellpiaCard: document.getElementById("manualReviewSellpiaCard"),
    evidenceList: document.getElementById("manualReviewEvidenceList"),
    recommendation: document.getElementById("manualReviewRecommendation"),
    autoApproveButton: document.getElementById("manualAutoApproveButton"),
    linkButton: document.getElementById("manualLinkButton"),
    unlinkButton: document.getElementById("manualUnlinkButton"),
    discontinueButton: document.getElementById("manualDiscontinueButton"),
    impactBox: document.getElementById("manualReviewImpactBox"),
    writeStatus: document.getElementById("manualReviewWriteStatus"),
  };
}

function manualReviewSearchText(row) {
  return [
    row.queue_id,
    row.source_channel,
    channelName(row.source_channel),
    row.channel_product_code,
    row.channel_option_code,
    row.channel_product_name,
    row.channel_option_name,
    row.channel_seller_code,
    row.best_sellpia_product_code,
    row.best_sellpia_sku_code,
    row.best_sellpia_product_name,
    row.best_sellpia_option_name,
    row.match_tier,
    row.match_reason,
    row.recommended_action,
    workflowBucketLabel(workflowBucket(row)),
    stockStatusLabel(stockStatusForRow(row)),
  ].join(" ").toLowerCase();
}

function isAutoApprovalCandidate(row) {
  const policy = policyApprovalTier(row);
  return (
    row?.match_tier === "AUTO_APPROVE_CANDIDATE" ||
    row?.match_tier === "FAST_REVIEW" ||
    policy?.tier === "AUTO_APPROVE_CANDIDATE" ||
    policy?.tier === "APPROVAL_CANDIDATE_CODE_EVIDENCE_WEAK" ||
    policy?.tier === "FAST_REVIEW_REQUIRED" ||
    /자동승인|auto.?approve/i.test([policy?.label, row?.recommended_action, row?.match_reason].join(" "))
  );
}

function isFastReviewCandidate(row) {
  const policy = policyApprovalTier(row);
  return (
    row?.match_tier === "FAST_REVIEW" ||
    policy?.tier === "FAST_REVIEW_REQUIRED" ||
    /빠른검토|fast.?review/i.test([policy?.label, row?.recommended_action, row?.match_reason].join(" "))
  );
}

function isConflictReviewRow(row) {
  const duplicateCount = Number(row?.duplicate_candidate_count || 0);
  const text = [row?.duplicate_risk, row?.match_reason, row?.recommended_action, row?.match_tier].join(" ");
  return duplicateCount > 1 || /중복|충돌|duplicate|conflict/i.test(text);
}

function isAblyDiscontinueCandidate(row) {
  return row?.source_channel === "ably" && rowHasAblyExclusion(row);
}

function isManualReviewPending(row) {
  if (!row?.queue_id) return false;
  if (rowIsManuallyUnlinked(row)) return false;
  if (isAblyDiscontinueCandidate(row)) return false;
  if (isConflictReviewRow(row)) return true;
  if (rowNeedsLinking(row)) return true;
  if (row.review_required) return true;
  return !isAutoApprovalCandidate(row);
}

function manualReviewBaseRows() {
  const keyword = String(manualReviewSearchTerm || "").trim().toLowerCase();
  return queueRows.filter((row) => {
    if (!row?.queue_id) return false;
    if (!visibleChannels.has(row.source_channel)) return false;
    if (keyword && !manualReviewSearchText(row).includes(keyword)) return false;
    if (manualReviewActiveFilter === "ably_discontinue") return isAblyDiscontinueCandidate(row);
    if (isAblyDiscontinueCandidate(row)) return false;
    if (manualReviewActiveFilter === "auto") return isAutoApprovalCandidate(row);
    if (manualReviewActiveFilter === "conflict") return isConflictReviewRow(row);
    if (manualReviewActiveFilter === "unmatched") return rowNeedsLinking(row);
    if (manualReviewActiveFilter === "hold") return workflowBucket(row) === "hold" || row.review_required || stockStatusForRow(row) === "STOCK_HOLD_REVIEW";
    return isManualReviewPending(row) || isAutoApprovalCandidate(row);
  });
}

function renderManualReviewSummary() {
  if (queueSummary?.totals && summaryChannels()?.length) {
    updateTextById("manualAutoCandidateCount", sumSummaryField("auto_candidate_rows") + sumSummaryField("fast_review_rows"));
    updateTextById("manualFastReviewCount", sumSummaryField("fast_review_rows"));
    updateTextById("manualConflictCount", sumSummaryField("conflict_rows"));
    updateTextById("manualAblyDiscontinueCount", queueSummary.by_channel?.ably?.workflow_excluded_rows || 0);
    updateTextById("manualPendingCount", sumSummaryField("manual_scope_rows"));
    return;
  }

  const visibleRows = queueRows.filter((row) => row?.queue_id && visibleChannels.has(row.source_channel));
  updateTextById("manualAutoCandidateCount", visibleRows.filter(isAutoApprovalCandidate).length);
  updateTextById("manualFastReviewCount", visibleRows.filter(isFastReviewCandidate).length);
  updateTextById("manualConflictCount", visibleRows.filter(isConflictReviewRow).length);
  updateTextById("manualAblyDiscontinueCount", visibleRows.filter(isAblyDiscontinueCandidate).length);
  updateTextById("manualPendingCount", visibleRows.filter(isManualReviewPending).length);
}

function manualReviewBadges(row) {
  const badges = [
    `<span class="linking-status-badge is-channel">${escapeHtml(channelName(row.source_channel))}</span>`,
    `<span class="linking-status-badge">${escapeHtml(workflowBucketLabel(workflowBucket(row)))}</span>`,
  ];
  if (isAutoApprovalCandidate(row)) badges.push("<span class=\"linking-status-badge is-auto\">자동승인 후보</span>");
  if (isConflictReviewRow(row)) badges.push("<span class=\"linking-status-badge is-warning\">충돌</span>");
  if (isAblyDiscontinueCandidate(row)) badges.push("<span class=\"linking-status-badge is-purple\">에이블리 제외</span>");
  if (rowIsManuallyUnlinked(row)) badges.push("<span class=\"linking-status-badge is-danger\">연동 해제됨</span>");
  return badges.join("");
}

function manualReviewRowHtml(row) {
  const selected = String(row.queue_id) === String(manualReviewSelectedQueueId);
  const policy = policyApprovalTier(row);
  const image = rowImage(row);
  return `
    <button type="button" class="manual-review-row ${selected ? "is-selected" : ""}" data-manual-review-row="${escapeHtml(row.queue_id)}">
      <span class="manual-review-row-thumb">
        ${image ? renderImageThumb(image) : `<span class='muted'>${escapeHtml(imageMissingLabel(row))}</span>`}
      </span>
      <span class="manual-review-row-top">
        <strong>${escapeHtml(row.channel_product_code || row.channel_seller_code || row.queue_id)}</strong>
        <em>${escapeHtml(row.best_sellpia_sku_code || row.best_sellpia_product_code || "Sellpia 미지정")}</em>
      </span>
      <span class="manual-review-row-title">${escapeHtml(row.channel_product_name || "-")}</span>
      <span class="manual-review-row-option">${escapeHtml(row.channel_option_name || "-")}</span>
      <span class="manual-review-row-policy">${escapeHtml(policy.label || "-")}</span>
      <span class="manual-review-row-badges">${manualReviewBadges(row)}</span>
    </button>
  `;
}

function resetManualReviewVisibleCount() {
  manualReviewVisibleCount = MANUAL_REVIEW_PAGE_SIZE;
}

function renderManualReviewList() {
  const els = manualReviewElements();
  if (!els.list) return;
  const rows = manualReviewBaseRows();
  if (!rows.length) {
    manualReviewSelectedQueueId = "";
    els.list.className = "manual-review-list empty";
    els.list.textContent = queueRowsLoading && !queueRowsFullyLoaded
      ? "현재 조건의 검수 데이터를 불러오는 중입니다. 잠시만 기다려주세요."
      : "현재 조건에 맞는 검수 대상이 없습니다.";
    return;
  }
  if (!rows.some((row) => String(row.queue_id) === String(manualReviewSelectedQueueId))) {
    manualReviewSelectedQueueId = String(rows[0].queue_id);
  }
  const previousScrollTop = els.list.scrollTop || 0;
  const visibleCount = Math.min(Math.max(manualReviewVisibleCount, MANUAL_REVIEW_PAGE_SIZE), rows.length);
  manualReviewVisibleCount = visibleCount;
  els.list.className = "manual-review-list";
  els.list.innerHTML = rows.slice(0, visibleCount).map(manualReviewRowHtml).join("");
  if (rows.length > visibleCount) {
    els.list.insertAdjacentHTML(
      "beforeend",
      `<button type="button" class="manual-review-load-more" data-manual-review-load-more="true">${visibleCount.toLocaleString()} / ${rows.length.toLocaleString()}개 표시 중 - 더 보기</button>`
    );
  } else {
    els.list.insertAdjacentHTML("beforeend", `<p class="linking-list-limit">전체 ${rows.length.toLocaleString()}개를 표시 중입니다.</p>`);
  }
  els.list.scrollTop = previousScrollTop;
}

function loadMoreManualReviewRows() {
  const rows = manualReviewBaseRows();
  if (manualReviewVisibleCount >= rows.length) return;
  manualReviewVisibleCount = Math.min(manualReviewVisibleCount + MANUAL_REVIEW_PAGE_SIZE, rows.length);
  renderManualReviewList();
}

function selectedManualReviewRow() {
  return rowByQueueId(manualReviewSelectedQueueId) || null;
}

function currentRowSellpiaPayload(row) {
  if (!row) return null;
  if (!row.best_sellpia_product_code && !row.best_sellpia_sku_code) return null;
  return {
    sellpiaProductCode: row.best_sellpia_product_code || "",
    sellpiaSkuCode: row.best_sellpia_sku_code || "",
    sellpiaProductName: row.best_sellpia_product_name || "",
    sellpiaOptionName: row.best_sellpia_option_name || "",
  };
}

function manualCardFields(fields) {
  return `
    <dl class="manual-card-grid">
      ${fields.map(([label, value]) => `
        <dt>${escapeHtml(label)}</dt>
        <dd>${escapeHtml(value || "-")}</dd>
      `).join("")}
    </dl>
  `;
}

function renderManualReviewSelected() {
  const els = manualReviewElements();
  const row = selectedManualReviewRow();
  if (!row) {
    ["sellerCard", "sellpiaCard", "evidenceList", "recommendation", "impactBox"].forEach((key) => {
      if (!els[key]) return;
      els[key].classList.add("empty");
      els[key].textContent = "왼쪽 검수 큐에서 행을 선택하세요.";
    });
    [els.autoApproveButton, els.linkButton, els.unlinkButton, els.discontinueButton].forEach((button) => {
      if (button) button.disabled = true;
    });
    return;
  }

  selectedRow = row;
  selectedQueueIds = new Set([String(row.queue_id)]);
  const canWrite = canWriteReview();
  const hasSellpia = Boolean(currentRowSellpiaPayload(row));
  const policy = policyApprovalTier(row);
  const ablyDiscontinue = isAblyDiscontinueCandidate(row);
  const image = rowImage(row);

  if (els.sellerCard) {
    els.sellerCard.className = "manual-card";
    els.sellerCard.innerHTML = `
      <div class="manual-card-title">
        <strong>${escapeHtml(channelName(row.source_channel))}</strong>
        ${manualReviewBadges(row)}
      </div>
      ${manualCardFields([
        ["판매처 상품코드", row.channel_product_code],
        ["판매처 옵션코드", row.channel_option_code],
        ["판매처 상품명", row.channel_product_name],
        ["판매처 옵션명", row.channel_option_name],
        ["자사코드", ownCodeForRow(row)],
      ])}
    `;
  }

  if (els.sellpiaCard) {
    els.sellpiaCard.className = `manual-card ${hasSellpia ? "" : "empty"}`;
    els.sellpiaCard.innerHTML = hasSellpia ? `
      <div class="manual-card-title">
        <strong>Sellpia 후보</strong>
        <span class="linking-status-badge is-auto">${escapeHtml(policy.label || "-")}</span>
      </div>
      ${renderImageAsset(image)}
      ${manualCardFields([
        ["Sellpia 상품코드", row.best_sellpia_product_code],
        ["Sellpia 옵션코드", row.best_sellpia_sku_code],
        ["Sellpia 상품명", row.best_sellpia_product_name],
        ["Sellpia 옵션명", row.best_sellpia_option_name],
        ["매칭 점수", row.match_score],
      ])}
      ${linkDecisionBadge(row)}
    ` : `
      <div class="manual-card-title">
        <strong>Sellpia 후보 없음</strong>
        <span class="linking-status-badge">수동 검색 필요</span>
      </div>
      <p>현재 행에는 Sellpia 후보 코드가 없습니다. 아래에서 후보를 검색해 바로 연동하세요.</p>
      ${renderSellpiaSearchBox()}
    `;
  }

  if (els.evidenceList) {
    const evidenceRows = [
      ["추천 액션", row.recommended_action || "-"],
      ["매칭 등급", tierLabel(row.match_tier)],
      ["승인 분류", policy.label],
      ["판정 사유", row.match_reason || policy.reason || "-"],
      ["중복 후보", Number(row.duplicate_candidate_count || 0).toLocaleString()],
      ["중복 위험", row.duplicate_risk || "-"],
      ["재고 상태", stockStatusLabel(stockStatusForRow(row))],
      ["에이블리 제외", ablyDiscontinue ? ablyExclusionReasons(row, "ably").join(" / ") : "-"],
    ];
    els.evidenceList.className = "manual-evidence-list";
    els.evidenceList.innerHTML = evidenceRows.map(([label, value]) => `
      <div class="manual-evidence-row">
        <span>${escapeHtml(label)}</span>
        <strong>${escapeHtml(value || "-")}</strong>
      </div>
    `).join("");
  }

  if (els.recommendation) {
    const recommendation = ablyDiscontinue
      ? "에이블리 제외 근거가 있어 단종 처리 후보입니다. 실제 저장 전 상품코드 XX/노랑/주황 근거를 한 번 확인하세요."
      : isAutoApprovalCandidate(row)
        ? "자동승인 후보입니다. 판매처 상품/옵션과 Sellpia 후보가 맞으면 확정할 수 있습니다."
        : isConflictReviewRow(row)
          ? "중복 또는 충돌 가능성이 있습니다. 연결된 타 판매처 정보를 비교한 뒤 수동 결정하세요."
          : "담당자가 상품명, 옵션명, 자사코드를 확인한 뒤 처리하세요.";
    els.recommendation.className = "manual-recommendation";
    els.recommendation.innerHTML = `<strong>추천 판단</strong><p>${escapeHtml(recommendation)}</p>`;
  }

  if (els.impactBox) {
    const decisionHint = !canWrite
      ? "현재 읽기 전용 모드라 저장 버튼이 잠겨 있습니다."
      : !hasSellpia
        ? "Sellpia 후보가 없는 행입니다. 수동 연동은 후보 검색 후 결과를 선택하면 저장됩니다."
        : "현재 저장 가능한 review 모드입니다.";
    els.impactBox.className = "manual-impact-box";
    els.impactBox.innerHTML = `
      <strong>처리 영향</strong>
      <p>연동/해제 저장은 Supabase 검수 큐 이력에 기록됩니다. 원본 엑셀 파일은 직접 수정하지 않습니다.</p>
      <p>${escapeHtml(decisionHint)}</p>
    `;
  }

  if (els.autoApproveButton) els.autoApproveButton.disabled = !canWrite || !hasSellpia || !isAutoApprovalCandidate(row);
  if (els.linkButton) els.linkButton.disabled = !canWrite;
  if (els.unlinkButton) els.unlinkButton.disabled = !canWrite || !rowHasSellpiaLink(row) || rowIsManuallyUnlinked(row);
  if (els.discontinueButton) els.discontinueButton.disabled = !canWrite || !ablyDiscontinue;
}

function renderManualReviewView() {
  const els = manualReviewElements();
  if (!els.view) return;
  renderManualReviewSummary();
  renderManualReviewList();
  renderManualReviewSelected();
}

document.querySelectorAll(".tab").forEach((button) => {
  button.addEventListener("click", () => {
    if (!button.dataset.view) return;
    const targetView = document.getElementById(`${button.dataset.view}View`);
    if (!targetView) return;
    document.querySelectorAll(".tab").forEach((tab) => tab.classList.remove("is-active"));
    document.querySelectorAll(".view").forEach((view) => view.classList.remove("is-active"));
    button.classList.add("is-active");
    targetView.classList.add("is-active");
    if (button.dataset.view === "linking") renderLinkingView();
    if (button.dataset.view === "manualReview") renderManualReviewView();
  });
});

document.getElementById("linkingModeControls")?.addEventListener("click", (event) => {
  const button = event.target.closest("[data-linking-mode]");
  if (!button) return;
  activeLinkingMode = button.dataset.linkingMode || "link";
  document.querySelectorAll("[data-linking-mode]").forEach((item) => item.classList.toggle("is-active", item === button));
  renderLinkingView();
});

document.getElementById("linkingSearchInput")?.addEventListener("input", (event) => {
  linkingSearchTerm = event.target.value || "";
  renderLinkingView();
});

document.getElementById("linkingChannelFilter")?.addEventListener("change", (event) => {
  linkingChannelFilter = event.target.value || "";
  renderLinkingView();
});

document.getElementById("linkingHideAblyExcluded")?.addEventListener("change", (event) => {
  linkingHideAblyExcluded = Boolean(event.target.checked);
  renderLinkingView();
});

document.getElementById("linkingList")?.addEventListener("click", (event) => {
  const button = event.target.closest("[data-linking-row]");
  if (!button) return;
  linkingSelectedQueueId = String(button.dataset.linkingRow || "");
  linkingCandidateTerm = "";
  const input = document.getElementById("linkingCandidateSearchInput");
  if (input) input.value = "";
  renderLinkingView();
});

document.getElementById("linkingCandidateSearchInput")?.addEventListener("input", (event) => {
  linkingCandidateTerm = event.target.value || "";
  renderLinkingCandidateResults();
});

document.getElementById("linkingCandidateResults")?.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-linking-link-candidate]");
  if (!button) return;
  const row = selectedLinkingRow();
  if (!row) {
    alert("먼저 왼쪽 작업 목록에서 행을 선택하세요.");
    return;
  }
  selectedRow = row;
  await linkSelectedCandidate({
    sellpiaProductCode: button.dataset.sellpiaProductCode || "",
    sellpiaSkuCode: button.dataset.sellpiaSkuCode || "",
    sellpiaProductName: button.dataset.sellpiaProductName || "",
    sellpiaOptionName: button.dataset.sellpiaOptionName || "",
  });
  linkingSelectedQueueId = String(row.queue_id);
  renderLinkingView();
});

document.getElementById("linkingUnlinkButton")?.addEventListener("click", async () => {
  const row = selectedLinkingRow();
  if (!row) {
    alert("먼저 왼쪽 작업 목록에서 행을 선택하세요.");
    return;
  }
  selectedRow = row;
  await unlinkSelectedRow();
  linkingSelectedQueueId = String(row.queue_id);
  renderLinkingView();
});

document.getElementById("linkingRefreshButton")?.addEventListener("click", async () => {
  await loadQueueRows();
  renderLinkingView();
});

document.getElementById("manualReviewSearchInput")?.addEventListener("input", (event) => {
  manualReviewSearchTerm = event.target.value || "";
  resetManualReviewVisibleCount();
  renderManualReviewView();
});

document.getElementById("manualReviewFilterControls")?.addEventListener("click", (event) => {
  const button = event.target.closest("[data-manual-filter]");
  if (!button) return;
  manualReviewActiveFilter = button.dataset.manualFilter || "all";
  resetManualReviewVisibleCount();
  document.querySelectorAll("[data-manual-filter]").forEach((item) => item.classList.toggle("is-active", item === button));
  renderManualReviewView();
});

document.getElementById("manualReviewList")?.addEventListener("click", (event) => {
  if (event.target.closest("[data-manual-review-load-more]")) {
    loadMoreManualReviewRows();
    return;
  }
  const button = event.target.closest("[data-manual-review-row]");
  if (!button) return;
  manualReviewSelectedQueueId = String(button.dataset.manualReviewRow || "");
  renderManualReviewView();
});

document.getElementById("manualReviewList")?.addEventListener("scroll", (event) => {
  const list = event.currentTarget;
  if (!list || list.classList.contains("empty")) return;
  if (list.scrollTop + list.clientHeight < list.scrollHeight - 120) return;
  loadMoreManualReviewRows();
});

document.getElementById("manualReviewRefreshButton")?.addEventListener("click", async () => {
  await loadQueueRows();
  resetManualReviewVisibleCount();
  renderManualReviewView();
});

document.getElementById("manualAutoApproveButton")?.addEventListener("click", async () => {
  const row = selectedManualReviewRow();
  const payload = currentRowSellpiaPayload(row);
  if (!row || !payload) {
    alert("확정할 Sellpia 후보가 없습니다.");
    return;
  }
  if (!isAutoApprovalCandidate(row)) {
    alert("자동승인 후보로 분류된 행만 이 버튼으로 확정할 수 있습니다.");
    return;
  }
  selectedRow = row;
  await linkSelectedCandidate(payload);
  manualReviewSelectedQueueId = String(row.queue_id);
  const els = manualReviewElements();
  if (els.writeStatus) els.writeStatus.textContent = "자동승인 후보 확정 요청을 저장했습니다.";
  renderManualReviewView();
});

document.getElementById("manualLinkButton")?.addEventListener("click", async () => {
  const row = selectedManualReviewRow();
  const payload = currentRowSellpiaPayload(row);
  if (!row || !payload) {
    const searchInput = document.getElementById("sellpiaLinkSearchInput");
    searchInput?.focus();
    alert("수동 연동할 Sellpia 후보를 먼저 검색해서 선택하세요.");
    return;
  }
  selectedRow = row;
  await linkSelectedCandidate(payload);
  manualReviewSelectedQueueId = String(row.queue_id);
  const els = manualReviewElements();
  if (els.writeStatus) els.writeStatus.textContent = "수동 연동 요청을 저장했습니다.";
  renderManualReviewView();
});

document.getElementById("manualUnlinkButton")?.addEventListener("click", async () => {
  const row = selectedManualReviewRow();
  if (!row) {
    alert("먼저 검수 큐에서 행을 선택하세요.");
    return;
  }
  selectedRow = row;
  await unlinkSelectedRow();
  manualReviewSelectedQueueId = String(row.queue_id);
  const els = manualReviewElements();
  if (els.writeStatus) els.writeStatus.textContent = "연동 끊기 요청을 저장했습니다.";
  renderManualReviewView();
});

document.getElementById("manualDiscontinueButton")?.addEventListener("click", async () => {
  const row = selectedManualReviewRow();
  if (!row || !isAblyDiscontinueCandidate(row)) {
    alert("에이블리 제외 근거가 있는 행만 단종 후보로 처리할 수 있습니다.");
    return;
  }
  const ok = confirm("에이블리 제외 근거가 있는 행입니다. 기존 단종/제외 데이터와 같은 방식으로 검수 큐에 제외 처리합니다. 계속할까요?");
  if (!ok) return;
  selectedRow = row;
  await discontinueSelectedRow();
  manualReviewSelectedQueueId = String(row.queue_id);
  const els = manualReviewElements();
  if (els.writeStatus) els.writeStatus.textContent = "단종/제외 처리 요청을 저장했습니다.";
  renderManualReviewView();
});

tagReviewerInput?.addEventListener("input", () => {
  if (document.getElementById("manualReviewView")?.classList.contains("is-active")) renderManualReviewSelected();
});

reviewModeFilterInputs.forEach((input) => {
  input.addEventListener("change", () => {
    reviewModeFilter = reviewModeFilterInputs.find((item) => item.checked)?.value || "";
    resetPagination();
    renderTable();
  });
});

excludeExcludedRowsInput?.addEventListener("change", () => {
  excludeExcludedRows = Boolean(excludeExcludedRowsInput.checked);
  resetPagination();
  renderTable();
});

ablyExclusionFilterInput?.addEventListener("change", () => {
  ablyExclusionFilter = ablyExclusionFilterInput.value || "";
  resetPagination();
  renderTable();
});

filterResetButton?.addEventListener("click", () => {
  activeStockStatus = "";
  activeWorkflowFilter = "";
  activeTagNames = new Set();
  reviewModeFilter = "";
  excludeExcludedRows = false;
  ablyExclusionFilter = "";
  if (channelFilter) channelFilter.value = "";
  if (tierFilter) tierFilter.value = "";
  if (searchInput) searchInput.value = "";
  if (imageOnlyFilter) imageOnlyFilter.checked = false;
  reviewModeFilterInputs.forEach((input) => {
    input.checked = input.value === "";
  });
  if (excludeExcludedRowsInput) excludeExcludedRowsInput.checked = false;
  if (ablyExclusionFilterInput) ablyExclusionFilterInput.value = "";
  resetPagination();
  renderTagControls();
  renderStockSummary();
  renderTable();
});

channelVisibilityControls?.addEventListener("change", (event) => {
  const input = event.target.closest("input[type='checkbox'][value]");
  if (!input) return;
  toggleVisibleChannel(input.value, input.checked);
});

document.querySelectorAll(".stock-card").forEach((button) => {
  button.addEventListener("click", () => setActiveStockStatus(button.dataset.stockStatus));
});

document.querySelector(".kpi-grid")?.addEventListener("click", (event) => {
  const card = event.target.closest("[data-workflow-filter]");
  if (!card) return;
  setActiveWorkflowFilter(card.dataset.workflowFilter || "");
});

document.querySelector(".kpi-grid")?.addEventListener("keydown", (event) => {
  const card = event.target.closest("[data-workflow-filter]");
  if (!card || !["Enter", " "].includes(event.key)) return;
  event.preventDefault();
  setActiveWorkflowFilter(card.dataset.workflowFilter || "");
});

tagFilterChips?.addEventListener("click", (event) => {
  const clearButton = event.target.closest("[data-tag-filter-clear]");
  if (clearButton) {
    activeTagNames = new Set();
    resetPagination();
    renderTagControls();
    renderTable();
    return;
  }
  const button = event.target.closest("[data-tag-filter]");
  if (!button) return;
  const tagName = button.dataset.tagFilter || "";
  if (activeTagNames.has(tagName)) {
    activeTagNames.delete(tagName);
  } else {
    activeTagNames.add(tagName);
  }
  resetPagination();
  renderTagControls();
  renderTable();
});

selectedTagBadges?.addEventListener("click", (event) => {
  const button = event.target.closest("[data-remove-tag]");
  if (!button) return;
  removeTagAssignment(button.dataset.removeTag);
});

tagPicker?.addEventListener("click", (event) => {
  const button = event.target.closest("[data-pick-tag-id]");
  if (!button) return;
  if (button.classList.contains("is-applied")) return;
  togglePendingTag(button.dataset.pickTagId);
});

[channelFilter, tierFilter, searchInput, imageOnlyFilter].filter(Boolean).forEach((el) => {
  el.addEventListener("input", () => {
    if (el === channelFilter) {
      activeChannel = channelFilter?.value || "sellpia";
    }
    resetPagination();
    renderTable();
  });
});

batchSelect?.addEventListener("change", () => {
  activeBatchIds = selectedBatchIds();
  renderBatchHelper();
  loadQueueRows();
});

pageSizeSelect?.addEventListener("change", () => {
  pageSize = Number(pageSizeSelect.value || 100);
  resetPagination();
  renderTable();
});

firstPageButton?.addEventListener("click", () => {
  currentPage = 1;
  renderTable();
});

prevPageButton?.addEventListener("click", () => {
  currentPage -= 1;
  renderTable();
});

nextPageButton?.addEventListener("click", () => {
  currentPage += 1;
  renderTable();
});

lastPageButton?.addEventListener("click", () => {
  const totalPages = Math.max(1, Math.ceil(filteredRows().length / pageSize));
  currentPage = totalPages;
  renderTable();
});

document.getElementById("refreshButton").addEventListener("click", loadQueueRows);
addTagButton?.addEventListener("click", addTagToSelectedRow);
createTagButton?.addEventListener("click", createManualTag);
bulkTagPreviewButton?.addEventListener("click", renderBulkTagPreview);
bulkTagSaveLockedButton?.addEventListener("click", () => {
  alert("Bulk tag save is locked in this step. This preview does not write to DB.");
});
sellpiaTagTemplateButton?.addEventListener("click", downloadSellpiaTagUploadTemplate);
sellpiaTagPreviewButton?.addEventListener("click", previewSellpiaTagUpload);
sellpiaTagSaveButton?.addEventListener("click", saveSellpiaTagUpload);
sellpiaTagUploadInput?.addEventListener("change", () => {
  const file = sellpiaTagUploadInput.files?.[0];
  sellpiaTagPreviewRows = [];
  if (sellpiaTagSaveButton) sellpiaTagSaveButton.disabled = true;
  if (sellpiaTagUploadStatus) sellpiaTagUploadStatus.textContent = file ? `${file.name} 선택됨. 업로드 미리보기를 눌러 검증하세요.` : "엑셀을 선택한 뒤 미리보기를 생성하세요.";
  if (sellpiaTagPreviewResult) sellpiaTagPreviewResult.textContent = "아직 미리보기 결과가 없습니다.";
});
sellpiaTagAutoCreateInput?.addEventListener("change", () => {
  if (sellpiaTagUploadInput?.files?.[0]) previewSellpiaTagUpload();
});
document.getElementById("csvButton").addEventListener("click", downloadReviewCsv);
document.getElementById("xlsxButton").addEventListener("click", downloadReviewXlsx);
smartstoreOriginalPreviewButton?.addEventListener("click", buildSmartstoreOriginalPreview);
smartstoreOriginalInput?.addEventListener("change", () => {
  if (smartstoreOriginalInput.files?.[0]) {
    setSmartstorePreviewStatus(`${smartstoreOriginalInput.files[0].name} 선택됨. 원본양식 업로드/검증을 눌러 preview를 생성하세요.`);
  }
});
smartstorePreviewCsvButton?.addEventListener("click", downloadSmartstorePreviewCsv);
smartstorePreviewExportButton?.addEventListener("click", downloadSmartstoreSelectedApplyXlsx);
smartstoreRiskReviewXlsxButton?.addEventListener("click", downloadSmartstoreRiskReviewXlsx);
smartstoreTemplateExportButton?.addEventListener("click", downloadSmartstoreGeneratedTemplateXlsx);
sellpiaStockUploadButton?.addEventListener("click", uploadSellpiaStockToSupabase);
sellpiaStockLoadLatestButton?.addEventListener("click", () => loadLatestSellpiaStockSnapshot({ force: true }));
sellpiaStockInput?.addEventListener("change", () => {
  const file = sellpiaStockInput.files?.[0];
  if (file) setSellpiaStockStatus(`${file.name} 선택됨. Supabase에 업로드 버튼을 눌러 주세요.`);
});
sellerTemplateSaveButton?.addEventListener("click", saveSellerTemplateFromInput);
sellerTemplateLoadButton?.addEventListener("click", showSelectedSellerTemplate);
sellerTemplateClearButton?.addEventListener("click", clearSelectedSellerTemplate);
sellerTemplateInput?.addEventListener("change", () => {
  const file = sellerTemplateInput.files?.[0];
  if (file) setSellerTemplateStatus(`${sellerTemplateChannelLabel(sellerTemplateChannel?.value)} 템플릿 파일 선택됨: ${file.name}`);
});
sellerTemplateChannel?.addEventListener("change", showSelectedSellerTemplate);
makeshopOriginalPreviewButton?.addEventListener("click", buildMakeshopOriginalPreview);
makeshopOriginalInput?.addEventListener("change", () => {
  if (makeshopOriginalInput.files?.[0]) {
    setMakeshopPreviewStatus(`${makeshopOriginalInput.files[0].name} 선택됨. MakeShop 업로드/검증을 눌러 preview를 생성하세요.`);
  }
});
makeshopPreviewCsvButton?.addEventListener("click", downloadMakeshopPreviewCsv);
makeshopPreviewExportButton?.addEventListener("click", downloadMakeshopStockApplyXlsx);
makeshopTemplateExportButton?.addEventListener("click", downloadMakeshopGeneratedTemplateXlsx);
ablyOriginalPreviewButton?.addEventListener("click", buildAblyOriginalPreview);
ablyOriginalInput?.addEventListener("change", () => {
  if (ablyOriginalInput.files?.[0]) {
    setAblyPreviewStatus(`${ablyOriginalInput.files[0].name} 선택됨. Ably 업로드/검증을 눌러 preview를 생성하세요.`);
  }
});
ablyPreviewCsvButton?.addEventListener("click", downloadAblyPreviewCsv);
ablyPreviewExportButton?.addEventListener("click", downloadAblyStockApplyXlsx);
ablyTemplateExportButton?.addEventListener("click", downloadAblyGeneratedTemplateXlsx);
smartstorePreviewBucketFilter?.addEventListener("click", (event) => {
  const button = event.target.closest("[data-preview-bucket]");
  if (!button) return;
  activeSmartstorePreviewBucket = button.dataset.previewBucket || "";
  smartstorePreviewBucketFilter.querySelectorAll("[data-preview-bucket]").forEach((item) => {
    item.classList.toggle("is-active", item === button);
  });
  if (smartstorePreviewRows.length) {
    const stats = {
      totalRows: Number(document.getElementById("smartstorePreviewTotalRows").textContent.replace(/,/g, "")) || 0,
      matchedRows: smartstorePreviewRows.length,
      changedRows: smartstorePreviewRows.filter((row) => row.status === "CHANGE").length,
      missingRows: Number(document.getElementById("smartstorePreviewMissingRows").textContent.replace(/,/g, "")) || 0,
      bucketCounts: smartstorePreviewBucketCounts(smartstorePreviewRows),
    };
    renderSmartstorePreview(smartstorePreviewRows, stats);
  }
});
document.getElementById("smartstoreUploadReadyLockedButton")?.addEventListener("click", () => {
  alert("업로드용 파일 생성은 별도 승인 전까지 잠금 상태입니다. 현재는 검토용 preview와 노란색 XLSX만 사용할 수 있습니다.");
});
document.addEventListener("click", (event) => {
  const editButton = event.target.closest("[data-edit-field]");
  if (editButton) {
    event.preventDefault();
    event.stopPropagation();
    openCellEdit(editButton);
    return;
  }

  if (event.target.closest("[data-cell-save]")) {
    event.preventDefault();
    event.stopPropagation();
    saveActiveCellEdit();
    return;
  }

  if (event.target.closest("[data-cell-cancel]")) {
    event.preventDefault();
    event.stopPropagation();
    activeCellEdit = null;
    document.querySelectorAll(".cell-edit-panel").forEach((panel) => panel.remove());
    return;
  }

  const linkButton = event.target.closest("[data-link-candidate]");
  if (linkButton) {
    event.preventDefault();
    event.stopPropagation();
    if (linkButton.disabled || !canWriteReview()) return;
    linkSelectedCandidate({
      sellpiaProductCode: linkButton.dataset.sellpiaProductCode,
      sellpiaSkuCode: linkButton.dataset.sellpiaSkuCode,
      sellpiaProductName: linkButton.dataset.sellpiaProductName,
      sellpiaOptionName: linkButton.dataset.sellpiaOptionName,
    });
    return;
  }

  if (event.target.closest("[data-unlink-selected]")) {
    event.preventDefault();
    event.stopPropagation();
    unlinkSelectedRow();
    return;
  }

  if (event.target.closest("[data-refresh-selected]")) {
    event.preventDefault();
    event.stopPropagation();
    reloadAfterQueueMutation(selectedRow?.queue_id);
  }
});
document.addEventListener("input", (event) => {
  const search = event.target.closest("#sellpiaLinkSearchInput");
  if (!search) return;
  renderSellpiaSearchResults(search.value);
});
document.addEventListener("keydown", handleShortcut);

function fieldLabel(field) {
  return {
    channel_product_code: "판매처 상품코드",
    channel_option_code: "판매처 옵션코드",
    channel_product_name: "판매처 상품명",
    channel_option_name: "판매처 옵션명",
    best_sellpia_product_code: "Sellpia 상품코드",
    best_sellpia_sku_code: "Sellpia 옵션코드",
    best_sellpia_product_name: "Sellpia 상품명",
    best_sellpia_option_name: "Sellpia 옵션명",
    recommended_action: "판정/액션",
    match_reason: "매칭 사유",
  }[field] || field;
}

function tierLabel(tier) {
  return {
    AUTO_APPROVE_CANDIDATE: "확정 후보",
    MATCH_CANDIDATE: "매칭 후보",
    MANUAL_LINKED: "수동 연동",
    FAST_REVIEW: "빠른검토",
    DUPLICATE_REVIEW: "중복검토",
    NO_MATCH: "미매칭",
  }[tier] || tier || "-";
}

function stockStatusLabel(status) {
  return {
    STOCK_MATCH: "재고 일치",
    STOCK_DIFF: "재고 불일치",
    STOCK_HOLD_REVIEW: "검토 보류",
    STOCK_SMARTSTORE_NOT_FOUND: "현재 옵션 없음",
    STOCK_SELLPIA_MISSING: "Sellpia 재고 없음",
    STOCK_EXCLUDED: "단종/제외",
    STOCK_BUNDLE: "세트/조합",
    STOCK_SUBOPTION: "보조옵션",
  }[status] || "전체";
}

function workflowBucketLabel(bucket) {
  return {
    candidate: "확정 매칭 후보",
    hold: "확인 필요",
    code_blank: "코드 공란",
    no_match: "순수 미매칭",
    excluded: "단종/삭제 제외",
    bundle: "조합형/세트 후보",
    suboption: "보조 하위옵션",
    stock_match: "재고 일치",
    stock_diff: "재고 불일치",
    stock_missing: "미연결",
  }[bucket] || bucket || "확인 필요";
}

function linkDecisionBadge(row) {
  const latest = latestLinkDecision(row);
  if (!latest?.decision) return "";
  const label = latest.decision === "unlink" ? "연동 해제됨" : "수동 연동됨";
  const tone = latest.decision === "unlink" ? "is-unlinked" : "is-linked";
  return `<em class="manual-decision-badge ${tone}">${escapeHtml(label)}</em>`;
}

function initWorkflowKpiCards() {
  const mapping = [
    ["candidate", "workflowCandidateCount", "확정 매칭 후보"],
    ["hold", "workflowHoldCount", "확인 필요"],
    ["code_blank", "workflowCodeBlankCount", "코드 공란"],
    ["no_match", "workflowNoMatchCount", "순수 미매칭"],
    ["excluded", "workflowExcludedCount", "단종/삭제 제외"],
    ["bundle", "workflowBundleCount", "조합형/세트 후보"],
    ["suboption", "workflowSuboptionCount", "보조 하위옵션"],
    ["stock_match", "stockMatchCount", "재고 일치"],
    ["stock_diff", "stockDiffCount", "재고 불일치"],
    ["stock_missing", "stockMissingCount", "미연결"],
    ["hold", "stockHoldCount", "보류"],
  ];
  document.querySelectorAll(".kpi-grid .kpi-card").forEach((card, index) => {
    const [bucket, countId, label] = mapping[index] || [];
    if (!bucket) return;
    card.dataset.workflowFilter = bucket;
    card.setAttribute("role", "button");
    card.tabIndex = 0;
    card.title = `${label} 필터`;
    const labelEl = card.querySelector("span");
    const count = card.querySelector("strong");
    if (labelEl) labelEl.textContent = label;
    if (count && countId) count.id = countId;
  });
}

function renderEditableValue(row, field, value, tagName = "span", extraClass = "") {
  if (!row?.queue_id || !EDITABLE_QUEUE_FIELDS.has(field)) {
    return `<${tagName} class="${extraClass}">${escapeHtml(value || "-")}</${tagName}>`;
  }
  const edited = isFieldEdited(row, field);
  return `
    <${tagName} class="editable-value ${extraClass} ${edited ? "is-edited" : ""}">
      <span class="editable-text">${escapeHtml(value || "-")}</span>
      ${edited ? "<em class=\"edited-badge\">수정됨</em>" : ""}
      <button
        type="button"
        class="cell-edit-button"
        title="${escapeHtml(fieldLabel(field))} 수정"
        data-edit-field="${escapeHtml(field)}"
        data-queue-id="${escapeHtml(row.queue_id)}"
        data-current-value="${escapeHtml(value || "")}"
      >수정</button>
    </${tagName}>
  `;
}

function channelProblemClass() {
  return "";
}

function normalizeFlagText(value) {
  if (value == null) return "";
  if (Array.isArray(value)) return value.map(normalizeFlagText).join(" ");
  if (typeof value === "object") {
    return Object.entries(value)
      .map(([key, item]) => `${key} ${normalizeFlagText(item)}`)
      .join(" ");
  }
  return String(value).trim().toLowerCase();
}

function normalizeCodeKey(value) {
  if (value == null) return "";
  const text = String(value).trim();
  if (!text) return "";
  return text.replace(/\.0$/, "").toUpperCase();
}

function buildAblyFinalExclusionMaps(data = {}) {
  const rows = Array.isArray(data.rows) ? data.rows : [];
  const lookup = data.lookup || {};
  ablyFinalExclusionByProductCode = new Map();
  ablyFinalExclusionByOptionCode = new Map();
  ablyFinalKnownProductCodes = new Set((lookup.allProductCodes || []).map(normalizeCodeKey).filter(Boolean));
  ablyFinalKnownOptionCodes = new Set((lookup.allOptionCodes || []).map(normalizeCodeKey).filter(Boolean));
  rows.forEach((row) => {
    const entry = {
      productCode: normalizeCodeKey(row.productCode),
      optionCode: normalizeCodeKey(row.optionCode),
      sellerProductCode: normalizeCodeKey(row.sellerProductCode),
      productName: row.productName || "",
      optionName: row.optionName || "",
      reasons: Array.isArray(row.reasons) && row.reasons.length ? row.reasons : ["explicit"],
    };
    if (entry.productCode) ablyFinalExclusionByProductCode.set(entry.productCode, entry);
    if (entry.optionCode) ablyFinalExclusionByOptionCode.set(entry.optionCode, entry);
  });
  ablyFinalExclusionSummary = data.summary || null;
}

async function loadAblyFinalExclusionMap() {
  if (!ABLY_FINAL_EXCLUSION_URL) return;
  try {
    const response = await fetch(ABLY_FINAL_EXCLUSION_URL, { cache: "no-store" });
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    const data = await response.json();
    buildAblyFinalExclusionMaps(data);
    console.info(
      "Ably final exclusion data loaded",
      data.sourceFile || ABLY_FINAL_EXCLUSION_URL,
      ablyFinalExclusionByOptionCode.size,
      ablyFinalExclusionSummary
    );
  } catch (error) {
    buildAblyFinalExclusionMaps();
    console.warn("Ably final exclusion data could not be loaded", error);
  }
}

function ablyFinalExclusionReasons(row = {}, channel = "") {
  if (channel !== "ably" && row.source_channel !== "ably") return [];
  const productCodes = [
    row.channel_product_code,
    row.productCode,
    row.product_code,
    row.raw?.productCode,
    row.raw?.product_code,
  ].map(normalizeCodeKey).filter(Boolean);
  const optionCodes = [
    row.channel_option_code,
    row.optionCode,
    row.option_code,
    row.raw?.optionCode,
    row.raw?.option_code,
  ].map(normalizeCodeKey).filter(Boolean);

  const matchedRows = [
    ...productCodes.map((code) => ablyFinalExclusionByProductCode.get(code)),
    ...optionCodes.map((code) => ablyFinalExclusionByOptionCode.get(code)),
  ].filter(Boolean);
  return [...new Set(matchedRows.flatMap((entry) => entry.reasons || ["explicit"]))];
}

function ablyFinalWorkbookHasRow(row = {}, channel = "") {
  if (channel !== "ably" && row.source_channel !== "ably") return false;
  const productCodes = [
    row.channel_product_code,
    row.productCode,
    row.product_code,
    row.raw?.productCode,
    row.raw?.product_code,
  ].map(normalizeCodeKey).filter(Boolean);
  const optionCodes = [
    row.channel_option_code,
    row.optionCode,
    row.option_code,
    row.raw?.optionCode,
    row.raw?.option_code,
  ].map(normalizeCodeKey).filter(Boolean);
  if (optionCodes.some((code) => ablyFinalKnownOptionCodes.has(code))) return true;
  return productCodes.some((code) => ablyFinalKnownProductCodes.has(code));
}

function ablySellerCodeText(row = {}) {
  return [
    row.channel_product_code,
    row.channel_seller_code,
    row.productCode,
    row.product_code,
    row.sellerProductCode,
    row.seller_product_code,
  ].filter(Boolean).join(" ");
}

function collectAblyExclusionHints(row = {}) {
  const rawFlags = row.raw?.flags || {};
  const rowFlags = row.flags || {};
  const channelFlags = row.channel_flags || {};
  return [
    row.ablyExcluded,
    row.ably_excluded,
    row.mdExcluded,
    row.md_excluded,
    row.excludedByMd,
    row.excluded_by_md,
    rawFlags.ably_excluded,
    rowFlags.ably_excluded,
    channelFlags.ably_excluded,
    row.mdColor,
    row.md_color,
    row.rowColor,
    row.row_color,
    row.rowColorFlag,
    row.row_color_flag,
    row.color,
    row.fillColor,
    row.fill_color,
    row.style,
    row.cellStyle,
    row.cell_style,
    rawFlags.cell_style_flags,
    rowFlags.cell_style_flags,
    channelFlags.cell_style_flags,
    rawFlags.ably_color,
    rowFlags.ably_color,
    channelFlags.ably_color,
    rawFlags.ably_exclusion,
    rowFlags.ably_exclusion,
    channelFlags.ably_exclusion,
  ].map(normalizeFlagText).join(" ");
}

function collectAblyExplicitExclusionHints(row = {}) {
  const rawFlags = row.raw?.flags || {};
  const rowFlags = row.flags || {};
  const channelFlags = row.channel_flags || {};
  return [
    row.ablyExcluded,
    row.ably_excluded,
    row.mdExcluded,
    row.md_excluded,
    row.excludedByMd,
    row.excluded_by_md,
    rawFlags.ably_excluded,
    rowFlags.ably_excluded,
    channelFlags.ably_excluded,
    rawFlags.ably_exclusion,
    rowFlags.ably_exclusion,
    channelFlags.ably_exclusion,
  ].map(normalizeFlagText).join(" ");
}

function ablyExclusionReasons(row = {}, channel = "") {
  if (channel !== "ably" && row.source_channel !== "ably") return [];
  const reasons = [];
  const finalReasons = ablyFinalExclusionReasons(row, channel);
  finalReasons.forEach((reason) => reasons.push(reason));
  if (ablyFinalWorkbookHasRow(row, channel)) {
    return [...new Set(reasons)];
  }
  const codeText = ablySellerCodeText(row);
  const productText = [row.channel_product_name, row.productName, row.product_name].filter(Boolean).join(" ");
  const hintText = collectAblyExclusionHints(row);
  const explicitHintText = collectAblyExplicitExclusionHints(row);

  if (/(^|[^a-z0-9])xx([^a-z0-9]|$)/i.test(codeText) || /^\s*\[?xx\]?/i.test(productText)) {
    reasons.push("xx");
  }
  if (/orange|주황|ffc000|ff9900|ff7a00/.test(hintText)) {
    reasons.push("orange");
  }
  if (/yellow|노랑|노란|ffff00|ffe65a/.test(hintText)) {
    reasons.push("yellow");
  }
  if (/(^|\s)(true|1|yes|y|exclude|excluded|md_excluded|ably_excluded)(\s|$)/.test(explicitHintText) && !reasons.length) {
    reasons.push("explicit");
  }
  return [...new Set(reasons)];
}

function ablyExclusionClass(row = {}, channel = "") {
  const reasons = ablyExclusionReasons(row, channel);
  if (!reasons.length) return "";
  return ["ably-excluded-cell", ...reasons.map((reason) => `is-ably-${reason}`)].join(" ");
}

function rowHasAblyExclusion(row = {}) {
  if (row.channels?.ably && ablyExclusionReasons(row.channels.ably, "ably").length) return true;
  return ablyExclusionReasons(row, row.source_channel || "").length > 0;
}

function renderAblyExclusionBadge(row = {}, channel = "") {
  const labels = {
    xx: "XX 단종",
    orange: "주황 제외",
    yellow: "노랑 제외",
    explicit: "에이블리 제외",
  };
  const reasons = ablyExclusionReasons(row, channel);
  if (!reasons.length) return "";
  const label = reasons.map((reason) => labels[reason] || reason).join(" / ");
  return `<em class="ably-exclusion-badge" title="${escapeHtml(label)}">에이블리 제외: ${escapeHtml(label)}</em>`;
}

function renderTableHeader() {
  if (!queueTableHeadRow) return;
  const sellerColumns = visibleChannelList()
    .map((channel) => `
      <th class="channel-group channel-start is-${channel}" data-channel="${channel}">${escapeHtml(channelName(channel))} 상품</th>
      <th class="channel-group is-${channel}" data-channel="${channel}">${escapeHtml(channelName(channel))} 옵션</th>
      <th class="channel-group channel-end is-${channel}" data-channel="${channel}">판정/액션</th>
    `)
    .join("");

  queueTableHeadRow.innerHTML = `
    <th class="sticky-col sticky-sellpia-image" data-channel="sellpia">이미지</th>
    <th class="sticky-col sticky-sellpia-code" data-channel="sellpia">Sellpia 코드</th>
    <th class="sticky-col sticky-sellpia-product sellpia-col">Sellpia 상품명</th>
    <th class="sticky-col sticky-sellpia-option sellpia-col">Sellpia 옵션명</th>
    <th class="sticky-col sticky-sellpia-status">상태</th>
    ${sellerColumns}
    <th>중복 후보</th>
  `;
}

function renderChannelCells(row) {
  const channelRows = row.channels || {};
  return visibleChannelList()
    .map((channel) => {
      const channelRow = channelRows[channel] || (row.source_channel === channel ? row : null);
      if (!channelRow) {
        return `
          <td class="channel-cell channel-start is-empty is-${channel}" data-channel="${channel}">-</td>
          <td class="channel-cell is-empty is-${channel}" data-channel="${channel}">-</td>
          <td class="channel-cell channel-end is-empty is-${channel}" data-channel="${channel}">-</td>
        `;
      }
      const ownCode = ownCodeForRow(channelRow);
      const ablyExcludedClass = ablyExclusionClass(channelRow, channel);
      return `
        <td class="channel-cell channel-start is-${channel} ${ablyExcludedClass}" data-channel="${channel}" data-queue-id="${escapeHtml(channelRow.queue_id)}">
          ${renderEditableValue(channelRow, "channel_product_code", channelRow.channel_product_code || "-", "strong", codeCellClass(channelRow, "channel_product_code", channelRow.channel_product_code))}
          ${ownCode ? `<em class="own-code-badge">자사 ${escapeHtml(ownCode)}</em>` : ""}
          ${renderAblyExclusionBadge(channelRow, channel)}
          ${renderEditableValue(channelRow, "channel_product_name", channelRow.channel_product_name || "", "span")}
        </td>
        <td class="channel-cell is-${channel} ${ablyExcludedClass}" data-channel="${channel}" data-queue-id="${escapeHtml(channelRow.queue_id)}">
          ${renderEditableValue(channelRow, "channel_option_code", channelRow.channel_option_code || "-", "strong", codeCellClass(channelRow, "channel_option_code", channelRow.channel_option_code))}
          ${ownCode ? `<em class="own-code-badge">자사 ${escapeHtml(ownCode)}</em>` : ""}
          ${renderEditableValue(channelRow, "channel_option_name", channelRow.channel_option_name || "", "span")}
        </td>
        <td class="channel-cell channel-end is-${channel} ${ablyExcludedClass || statusCellClass(channelRow)}" data-channel="${channel}" data-queue-id="${escapeHtml(channelRow.queue_id)}">
          ${renderEditableValue(channelRow, "recommended_action", channelRow.recommended_action || stockStatusLabel(stockStatusForRow(channelRow)), "strong")}
          ${renderEditableValue(channelRow, "match_reason", channelRow.match_reason || "", "span")}
          ${linkDecisionBadge(channelRow)}
        </td>
      `;
    })
    .join("");
}

function renderDecisionControls(row) {
  if (!decisionBox) return;
  const hasSellpia = Boolean(row?.best_sellpia_product_code || row?.best_sellpia_sku_code);
  const canWrite = canWriteReview();
  const disabledReason = canWrite ? "" : `<p class='decision-warning'>${escapeHtml(writeAccessMessage())}</p>`;
  decisionBox.innerHTML = `
    <h3>옵션 연동 결정</h3>
    <p>원본 파일은 수정하지 않고 Supabase 검수 queue에만 수동 결정과 이력을 저장합니다.</p>
    ${disabledReason}
    <div class="decision-actions">
      <button type="button" data-unlink-selected="true" ${!hasSellpia || !canWrite ? "disabled" : ""}>연동 끊기</button>
      <button type="button" data-refresh-selected="true">새로고침</button>
    </div>
    <div class="link-search-box">
      <label>
        Sellpia 옵션 검색
        <input id="sellpiaLinkSearchInput" type="text" placeholder="Sellpia 코드, 상품명, 옵션명" ${!canWrite ? "disabled" : ""} />
      </label>
      <div id="sellpiaLinkSearchResults" class="link-search-results empty">현재 로드된 데이터 안에서 검색합니다.</div>
    </div>
  `;
}

async function selectRow(row, tr, options = {}) {
  const pageIndex = Number.isInteger(options.pageIndex)
    ? options.pageIndex
    : Number.parseInt(tr?.dataset?.pageIndex || "-1", 10);
  const group = options.group || (Number.isInteger(pageIndex) ? getCurrentPageGroups()[pageIndex] : null);
  const event = options.event;
  const isToggle = Boolean(event?.ctrlKey || event?.metaKey);
  const isRange = Boolean(event?.shiftKey && Number.isInteger(lastSelectedPageIndex) && lastSelectedPageIndex >= 0);

  selectedRow = row;
  pendingTagIds = new Set();
  if (isRange) {
    const pageGroups = getCurrentPageGroups();
    const start = Math.min(lastSelectedPageIndex, pageIndex);
    const end = Math.max(lastSelectedPageIndex, pageIndex);
    selectedQueueIds = new Set();
    pageGroups.slice(start, end + 1).forEach((item) => setGroupSelection(item, true));
  } else if (isToggle) {
    if (groupHasSelectedRow(group)) {
      setGroupSelection(group, false);
    } else {
      setGroupSelection(group, true);
    }
    lastSelectedPageIndex = pageIndex;
  } else {
    selectedQueueIds = new Set();
    setGroupSelection(group, true);
    lastSelectedPageIndex = pageIndex;
  }

  syncSelectedRowFromSelection(row);
  const pageGroupsForPaint = getCurrentPageGroups();
  document.querySelectorAll("#queueTable tr.is-selected").forEach((el) => el.classList.remove("is-selected"));
  document.querySelectorAll("#queueTable tbody tr").forEach((rowEl) => {
    const index = Number.parseInt(rowEl.dataset.pageIndex || "-1", 10);
    rowEl.classList.toggle("is-selected", groupHasSelectedRow(pageGroupsForPaint[index]));
  });

  const selectedImage = rowImage(row);
  const selectedCount = selectedQueueIds.size;
  selectedSummary.className = "selected-summary";
  selectedSummary.innerHTML = `
    <strong>${selectedCount > 1 ? `선택 ${selectedCount.toLocaleString()}개 · ` : ""}${escapeHtml(channelName(row.source_channel))} / ${escapeHtml(policyApprovalTier(row).label)}</strong>
    ${selectedCount > 1 ? "<p><b>다중 선택</b> Shift 범위 선택 / Ctrl·Meta 개별 선택 상태입니다. 태그 적용은 선택된 행 전체에 적용됩니다.</p>" : ""}
    ${renderImageAsset(selectedImage)}
    <p><b>판매처 상품</b> ${escapeHtml(row.channel_product_name || row.channel_product_code || "-")}</p>
    <p><b>판매처 옵션</b> ${escapeHtml(row.channel_option_name || row.channel_option_code || "-")}</p>
    <p><b>자사코드</b> ${escapeHtml(ownCodeForRow(row) || "-")}</p>
    <p><b>Sellpia</b> ${escapeHtml(row.best_sellpia_product_name || "-")} / ${escapeHtml(row.best_sellpia_option_name || "-")}</p>
    <p><b>Sellpia 코드</b> ${escapeHtml(row.best_sellpia_sku_code || row.best_sellpia_product_code || "-")}</p>
    <p><b>재고대조 상태</b> ${escapeHtml(stockStatusLabel(stockStatusForRow(row)))}</p>
    <p><b>중복 후보</b> ${Number(row.duplicate_candidate_count || 0).toLocaleString()}</p>
    <p><b>판정 근거</b> ${escapeHtml(policyApprovalTier(row).reason)}</p>
    ${linkDecisionBadge(row)}
  `;
  appendSelectedMeta(row);
  renderSelectedTags(row);
  if (addTagButton) addTagButton.disabled = pendingTagIds.size === 0;

  candidateDetails.innerHTML = "<p class='empty'>상세 정보 조회 중...</p>";
  const details = await loadDetails(row.queue_id);
  candidateDetails.innerHTML = "";
  renderDecisionControls(row, details);

  if (!details.length) {
    candidateDetails.innerHTML = `
      <p class='empty'>상세 후보가 없습니다. 오른쪽 결정 패널의 검색으로 현재 로드된 Sellpia 옵션을 찾아 연동할 수 있습니다.</p>
    `;
    return;
  }

  details.forEach((detail) => {
    const image = imageMap.get(detail.sellpia_sku_code);
    const item = document.createElement("div");
    item.className = "candidate-card";
    item.innerHTML = `
      <strong>#${detail.candidate_rank} ${escapeHtml(detail.sellpia_sku_code || "")}</strong>
      ${renderImageAsset(image)}
      <span>${Number(detail.match_score || 0).toLocaleString()}점</span>
      <p>${escapeHtml(detail.sellpia_product_name || "")}</p>
      <p>${escapeHtml(detail.sellpia_option_name || "")}</p>
      <small>${escapeHtml(detail.match_reason || "")} ${escapeHtml(detail.risk_flags || "")}</small>
      <button
        type="button"
        class="link-candidate-button"
        data-link-candidate="true"
        data-sellpia-product-code="${escapeHtml(detail.sellpia_product_code || "")}"
        data-sellpia-sku-code="${escapeHtml(detail.sellpia_sku_code || "")}"
        data-sellpia-product-name="${escapeHtml(detail.sellpia_product_name || "")}"
        data-sellpia-option-name="${escapeHtml(detail.sellpia_option_name || "")}"
      >이 Sellpia 옵션으로 연동</button>
    `;
    candidateDetails.appendChild(item);
  });
}

relocateReviewWorkbooks();
relocateDetailPanel();
relocatePagerControls();
initMatrixScrollState();
initWorkflowKpiCards();
renderAppModeBadges();
initBatchSelector();
syncChannelVisibilityControls();
if (pageSizeSelect) {
  pageSize = Number(pageSizeSelect.value || 100);
}
renderSellerTemplateSummary();

if (initSupabase()) {
  setupAuth();
  loadSmartstoreApplyMap();
  loadMakeshopApplyMap();
  loadAblyApplyMap();
  loadAblyFinalExclusionMap().finally(() => {
    loadTags().then(loadQueueRows);
  });
}
