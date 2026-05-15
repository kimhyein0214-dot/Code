export class AppError extends Error {
  constructor(statusCode, code, message) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
  }
}

export function notFound(code, message) {
  return new AppError(404, code, message);
}

export function badRequest(code, message) {
  return new AppError(400, code, message);
}
