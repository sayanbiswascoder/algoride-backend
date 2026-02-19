/**
 * RatingStars — Display star rating.
 */
export default function RatingStars({ rating = 0, size = 'md', onChange, interactive = false }) {
    const stars = [1, 2, 3, 4, 5];
    const sizeClasses = { sm: 'text-xs', md: 'text-sm', lg: 'text-xl' };

    return (
        <div className="flex items-center gap-0.5">
            {stars.map((star) => (
                <button
                    key={star}
                    type={interactive ? 'button' : undefined}
                    disabled={!interactive}
                    onClick={() => interactive && onChange?.(star)}
                    className={`${sizeClasses[size]} ${interactive ? 'cursor-pointer hover:scale-125 transition-transform' : 'cursor-default'
                        } ${star <= Math.round(rating) ? 'text-yellow-400' : 'text-dark-600'}`}
                >
                    ★
                </button>
            ))}
            {!interactive && (
                <span className={`ml-1 text-dark-400 ${size === 'sm' ? 'text-[10px]' : 'text-xs'}`}>
                    {rating > 0 ? rating.toFixed(1) : 'N/A'}
                </span>
            )}
        </div>
    );
}
