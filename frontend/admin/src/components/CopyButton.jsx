import React, { useState } from 'react';

const RESET_MS = 1400;

export function CopyButton({ value, label = '복사', title }) {
  const [state, setState] = useState('idle');

  async function copy(event) {
    event.preventDefault();
    event.stopPropagation();
    if (value === undefined || value === null || value === '') {
      return;
    }
    const text = String(value);
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
      } else {
        const helper = document.createElement('textarea');
        helper.value = text;
        helper.setAttribute('readonly', '');
        helper.style.position = 'absolute';
        helper.style.left = '-9999px';
        document.body.appendChild(helper);
        helper.select();
        document.execCommand('copy');
        document.body.removeChild(helper);
      }
      setState('done');
    } catch (err) {
      setState('fail');
    }
    setTimeout(() => setState('idle'), RESET_MS);
  }

  const disabled = value === undefined || value === null || value === '';
  const className = `copy-button copy-button-${state}${disabled ? ' is-disabled' : ''}`;
  const displayLabel = state === 'done' ? '복사됨' : state === 'fail' ? '실패' : label;
  return (
    <button
      type="button"
      onClick={copy}
      disabled={disabled}
      title={title || (disabled ? '복사할 값 없음' : `복사: ${value}`)}
      className={className}
      aria-label={`${displayLabel} ${value || ''}`}
    >
      {displayLabel}
    </button>
  );
}
