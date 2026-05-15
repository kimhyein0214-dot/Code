import React, { useEffect, useState } from 'react';

import { EmptyImagePlaceholder } from './EmptyImagePlaceholder.jsx';

export function ProductThumbnail({ src, alt = '', size = 'md' }) {
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    setFailed(false);
  }, [src]);

  const hasImage = src && !failed;

  return (
    <div className={`product-thumbnail product-thumbnail-${size}`}>
      {hasImage ? (
        <img
          src={src}
          alt={alt}
          loading="lazy"
          onError={() => setFailed(true)}
        />
      ) : (
        <EmptyImagePlaceholder />
      )}
    </div>
  );
}
