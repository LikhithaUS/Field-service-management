// Helpers shared by list endpoints.

const DEFAULT_LIMIT = 10;
const MAX_LIMIT = 100;

function parsePagination(query) {
  const page = Math.max(1, parseInt(query.page, 10) || 1);
  const limit = Math.min(MAX_LIMIT, Math.max(1, parseInt(query.limit, 10) || DEFAULT_LIMIT));
  return { page, limit, skip: (page - 1) * limit };
}

function paginationMeta({ page, limit }, total) {
  return { page, limit, total, totalPages: Math.max(1, Math.ceil(total / limit)) };
}

// User input goes into a RegExp, so special characters must be escaped
// (otherwise "a.*" would match everything, and some patterns can hang the server).
function escapeRegex(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

module.exports = { parsePagination, paginationMeta, escapeRegex, MAX_LIMIT };
