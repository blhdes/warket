import { Capacitor } from '@capacitor/core'
import { Haptics, ImpactStyle, NotificationType } from '@capacitor/haptics'

export const haptic = {
  light: () => { if (Capacitor.isNativePlatform()) Haptics.impact({ style: ImpactStyle.Light }) },
  medium: () => { if (Capacitor.isNativePlatform()) Haptics.impact({ style: ImpactStyle.Medium }) },
  success: () => { if (Capacitor.isNativePlatform()) Haptics.notification({ type: NotificationType.Success }) },
  warning: () => { if (Capacitor.isNativePlatform()) Haptics.notification({ type: NotificationType.Warning }) },
  error: () => { if (Capacitor.isNativePlatform()) Haptics.notification({ type: NotificationType.Error }) },
}
