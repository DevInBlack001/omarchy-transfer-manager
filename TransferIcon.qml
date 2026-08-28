import QtQuick
import QtQuick.Shapes
import qs.Commons

// Bar icon drawn as vector shapes rather than a font glyph. The bar's icon
// font is a symbol font with a fixed codepoint set (see DropboxIcon.qml,
// TailscaleIcon.qml for the same pattern); a plain Unicode character like
// an arrow glyph has no guarantee of existing in it and can render as
// nothing at all. Two opposing arrows, drawn with strokes so they read
// clearly at bar-icon sizes.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize

  readonly property real strokeW: Math.max(1.4, iconSize * 0.11)

  Shape {
    anchors.fill: parent
    antialiasing: true
    layer.enabled: true
    layer.samples: 4

    // Top arrow, pointing right.
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: root.strokeW
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      startX: root.width * 0.16; startY: root.height * 0.36
      PathLine { x: root.width * 0.84; y: root.height * 0.36 }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: root.strokeW
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      startX: root.width * 0.62; startY: root.height * 0.16
      PathLine { x: root.width * 0.86; y: root.height * 0.36 }
      PathLine { x: root.width * 0.62; y: root.height * 0.56 }
    }

    // Bottom arrow, pointing left.
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: root.strokeW
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      startX: root.width * 0.84; startY: root.height * 0.64
      PathLine { x: root.width * 0.16; y: root.height * 0.64 }
    }
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.color
      strokeWidth: root.strokeW
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      startX: root.width * 0.38; startY: root.height * 0.84
      PathLine { x: root.width * 0.14; y: root.height * 0.64 }
      PathLine { x: root.width * 0.38; y: root.height * 0.44 }
    }
  }
}
