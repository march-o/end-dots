import qs.modules.common
import qs.services
import QtQuick
import Quickshell.Services.Notifications

RippleButton {
    id: button
    property string buttonText
    property string urgency

    implicitHeight: 34
    leftPadding: 15
    rightPadding: 15
    buttonRadius: Appearance.rounding.small
    colBackground: (urgency == NotificationUrgency.Critical) ? ScopedColors.forItem(button).colSecondaryContainer : ScopedColors.forItem(button).colLayer4
    colBackgroundHover: (urgency == NotificationUrgency.Critical) ? ScopedColors.forItem(button).colSecondaryContainerHover : ScopedColors.forItem(button).colLayer4Hover
    colRipple: (urgency == NotificationUrgency.Critical) ? ScopedColors.forItem(button).colSecondaryContainerActive : ScopedColors.forItem(button).colLayer4Active

    contentItem: StyledText {
        horizontalAlignment: Text.AlignHCenter
        text: buttonText
        color: (urgency == NotificationUrgency.Critical) ? ScopedColors.m3ForItem(button).m3onSurfaceVariant : ScopedColors.m3ForItem(button).m3onSurface
    }
}