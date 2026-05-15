import React from 'react';

export function EmptyImagePlaceholder({ label = 'NO IMAGE' }) {
  return (
    <div className="image-placeholder" aria-label={label}>
      <svg viewBox="0 0 48 48" role="img" aria-hidden="true" focusable="false">
        <rect x="10" y="12" width="28" height="24" rx="4" />
        <circle cx="18" cy="20" r="3" />
        <path d="M13 32l8-8 6 6 4-4 4 6" />
      </svg>
      <span>{label}</span>
    </div>
  );
}
