import QtQuick
import QtQuick.Shapes
import qs.Commons

// Bar icon drawn as vector shapes rather than a font glyph. The bar's icon
// font is a symbol font with a fixed codepoint set (see DropboxIcon.qml,
// TailscaleIcon.qml for the same pattern); a plain Unicode character like
// an arrow glyph has no guarantee of existing in it. Two filled arrow
// polygons (not strokes), the same filled-ShapePath technique DropboxIcon
// uses, since that's the one proven to render correctly in this shell.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize

  Shape {
    anchors.fill: parent
    antialiasing: true
    layer.enabled: true
    layer.samples: 4

    // Top arrow, pointing right.
    ShapePath {
      fillColor: root.color
      strokeWidth: 0
      startX: root.width * 0.14; startY: root.height * 0.30
      PathLine { x: root.width * 0.58; y: root.height * 0.30 }
      PathLine { x: root.width * 0.58; y: root.height * 0.18 }
      PathLine { x: root.width * 0.86; y: root.height * 0.36 }
      PathLine { x: root.width * 0.58; y: root.height * 0.54 }
      PathLine { x: root.width * 0.58; y: root.height * 0.42 }
      PathLine { x: root.width * 0.14; y: root.height * 0.42 }
    }

    // Bottom arrow, pointing left.
    ShapePath {
      fillColor: root.color
      strokeWidth: 0
      startX: root.width * 0.86; startY: root.height * 0.58
      PathLine { x: root.width * 0.42; y: root.height * 0.58 }
      PathLine { x: root.width * 0.42; y: root.height * 0.46 }
      PathLine { x: root.width * 0.14; y: root.height * 0.64 }
      PathLine { x: root.width * 0.42; y: root.height * 0.82 }
      PathLine { x: root.width * 0.42; y: root.height * 0.70 }
      PathLine { x: root.width * 0.86; y: root.height * 0.70 }
    }
  }
}
