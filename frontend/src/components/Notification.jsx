/**
 * Notification — Toast-style notification overlay.
 */
import useStore from '../store/useStore';

const icons = { success: '✅', error: '❌', info: 'ℹ️', warning: '⚠️' };
const colors = {
    success: 'border-accent-500/50 bg-accent-500/10',
    error: 'border-red-500/50 bg-red-500/10',
    info: 'border-primary-500/50 bg-primary-500/10',
    warning: 'border-yellow-500/50 bg-yellow-500/10',
};

export default function Notification() {
    const notification = useStore((s) => s.notification);
    if (!notification) return null;

    return (
        <div className="fixed top-20 right-4 z-50 animate-slide-up">
            <div className={`glass-card border ${colors[notification.type] || colors.info} px-4 py-3 rounded-xl flex items-center gap-2 shadow-2xl max-w-sm`}>
                <span className="text-lg">{icons[notification.type] || icons.info}</span>
                <p className="text-sm text-dark-100">{notification.message}</p>
            </div>
        </div>
    );
}
